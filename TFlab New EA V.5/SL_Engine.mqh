#ifndef __TFLAB_SL_ENGINE_MQH__
#define __TFLAB_SL_ENGINE_MQH__

//+------------------------------------------------------------------+
//|                         SL_Engine.mqh                            |
//|                         TFlab New EA V.5                         |
//|                                                                  |
//| مسئولیت: محاسبه و اعتبارسنجی حد ضرر + حد ضرر پلکانی             |
//| v2.2 - توابع کمکی داخلی + Staged SL مستقل                        |
//+------------------------------------------------------------------+
#property strict

#include "EA_Inputs.mqh"
#include "Market_Structure.mqh"

//====================================================================
// توابع کمکی داخلی (مستقل از EA_Main)
//====================================================================

//------------------------------------------------------------------
// نرمال‌سازی حجم
//------------------------------------------------------------------
double SL_NormalizeVolume(const double volume)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0.0)
      return volume;
   double v = MathRound(volume / step) * step;
   if(v < minv) v = minv;
   if(v > maxv) v = maxv;
   return NormalizeDouble(v, 8);
  }

//------------------------------------------------------------------
// بررسی فاصله مجاز SL از قیمت جاری
bool SL_IsBrokerValidForPosition(const ulong ticket,
                                 const string symbol,
                                 const double new_sl)
  {
   if(ticket == 0 || symbol == "" || new_sl <= 0.0)
      return false;

   if(!PositionSelectByTicket(ticket))
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return false;

   long stops_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freeze_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double min_distance = (double)MathMax(stops_level, freeze_level) * _Point;
   if(min_distance < 2.0 * _Point)
      min_distance = 2.0 * _Point;

   bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);

   if(is_buy)
      return new_sl < tick.bid - min_distance;

   return new_sl > tick.ask + min_distance;
  }

//------------------------------------------------------------------
// اصلاح SL/TP معامله
//------------------------------------------------------------------
bool SL_ModifyPositionSLTP(
   const ulong ticket,
   const string symbol,
   const double new_sl,
   const double new_tp)
  {
   if(ticket == 0)
      return false;

   double sl = NormalizeDouble(new_sl, _Digits);
   double tp = NormalizeDouble(new_tp, _Digits);

   if(sl <= 0.0 && tp <= 0.0)
      return false;

   if(sl > 0.0 && !SL_IsBrokerValidForPosition(ticket, symbol, sl))
     {
      Print("[SL_MODIFY BLOCKED] فاصله حد ضرر از قیمت جاری مجاز نیست | Ticket=", ticket,
            " | NewSL=", DoubleToString(sl, _Digits));
      return false;
     }

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action   = TRADE_ACTION_SLTP;
   req.position = ticket;
   req.symbol   = symbol;
   req.sl       = sl;
   req.tp       = tp;

   ResetLastError();
   if(!OrderSend(req, res))
     {
      Print("[SL_MODIFY FAIL] OrderSend=false | Ticket=", ticket,
            " | Error=", GetLastError(), " | Retcode=", res.retcode);
      return false;
     }

   bool ok = (res.retcode == TRADE_RETCODE_DONE ||
              res.retcode == TRADE_RETCODE_DONE_PARTIAL);
   if(!ok)
      Print("[SL_MODIFY FAIL] Ticket=", ticket, " | Retcode=", res.retcode);

   return ok;
  }

//------------------------------------------------------------------
// بستن حجم معامله
//------------------------------------------------------------------
bool SL_ClosePositionVolume(
   const ulong ticket,
   const string symbol,
   const bool is_buy,
   const double volume,
   const string comment)
  {
   if(ticket == 0)
      return false;

   double close_volume = SL_NormalizeVolume(volume);
   if(close_volume <= 0.0)
      return false;

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return false;

   req.action      = TRADE_ACTION_DEAL;
   req.position    = ticket;
   req.symbol      = symbol;
   req.volume      = close_volume;
   req.type        = (is_buy ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
   req.price       = (is_buy ? tick.bid : tick.ask);
   req.deviation   = (ulong)Inp_MaxSlippagePoints;
   req.magic       = Inp_MagicNumber;
   req.comment     = comment;

   //--- تعیین نوع پرکردن سفارش
   long fill_policy = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((fill_policy & SYMBOL_FILLING_FOK) != 0)
      req.type_filling = ORDER_FILLING_FOK;
   else if((fill_policy & SYMBOL_FILLING_IOC) != 0)
      req.type_filling = ORDER_FILLING_IOC;
   else
      req.type_filling = ORDER_FILLING_RETURN;

   ResetLastError();
   if(!OrderSend(req, res))
     {
      Print("[SL_CLOSE FAIL] OrderSend=false | Ticket=", ticket,
            " | Error=", GetLastError(), " | Vol=", DoubleToString(close_volume, 8));
      return false;
     }

   bool ok = (res.retcode == TRADE_RETCODE_DONE ||
              res.retcode == TRADE_RETCODE_DONE_PARTIAL);
   if(!ok)
      Print("[SL_CLOSE FAIL] Ticket=", ticket, " | Retcode=", res.retcode);

   return ok;
  }

//====================================================================
// روش تعیین حد ضرر
//====================================================================
enum ENUM_SL_METHOD
  {
   SL_METHOD_STRUCTURE = 0,
   SL_METHOD_ZONE,
   SL_METHOD_FIXED,
   SL_METHOD_ATR,
   SL_METHOD_SWING
  };

//====================================================================
// وضعیت نتیجه SL
//====================================================================
enum ENUM_SL_STATUS
  {
   SL_STATUS_UNKNOWN = 0,
   SL_STATUS_VALID,
   SL_STATUS_INVALID
  };

//====================================================================
// جهت معامله برای محاسبه SL
//====================================================================
enum ENUM_SL_DIRECTION
  {
   SL_DIRECTION_NONE = 0,
   SL_DIRECTION_BUY,
   SL_DIRECTION_SELL
  };

//====================================================================
// منبع مرجع SL
//====================================================================
enum ENUM_SL_REFERENCE_SOURCE
  {
   SL_REFERENCE_NONE = 0,
   SL_REFERENCE_STRUCTURAL,
   SL_REFERENCE_SWING,
   SL_REFERENCE_ZONE,
   SL_REFERENCE_ATR,
   SL_REFERENCE_FIXED
  };

//====================================================================
// اطلاعات کامل حد ضرر
//====================================================================
struct SLPlan
  {
   ENUM_SL_METHOD              method;
   ENUM_SL_DIRECTION           direction;
   ENUM_SL_STATUS              status;
   ENUM_SL_REFERENCE_SOURCE    reference_source_type;

   double                      entry_price;
   double                      reference_price;
   double                      stop_price;
   double                      distance_price;
   double                      distance_points;
   double                      buffer_price;
   string                      reference_source;
   double                      minimum_required_distance;

   double                      atr_value;
   double                      atr_multiplier;

   datetime                    created_time;
   string                      reason;
  };

//------------------------------------------------------------------
// تبدیل روش SL به فارسی
//------------------------------------------------------------------
string SLMethodToPersian(const ENUM_SL_METHOD method)
  {
   switch(method)
     {
      case SL_METHOD_STRUCTURE: return "ساختاری";
      case SL_METHOD_ZONE:      return "ناحیه";
      case SL_METHOD_FIXED:     return "ثابت";
      case SL_METHOD_ATR:       return "ATR";
      case SL_METHOD_SWING:     return "Swing";
      default:                  return "نامشخص";
     }
  }

//------------------------------------------------------------------
// تبدیل جهت SL به فارسی
//------------------------------------------------------------------
string SLDirectionToPersian(const ENUM_SL_DIRECTION direction)
  {
   switch(direction)
     {
      case SL_DIRECTION_BUY:  return "خرید";
      case SL_DIRECTION_SELL: return "فروش";
      default:                return "بدون جهت";
     }
  }

//------------------------------------------------------------------
// تبدیل وضعیت SL به فارسی
//------------------------------------------------------------------
string SLStatusToPersian(const ENUM_SL_STATUS status)
  {
   switch(status)
     {
      case SL_STATUS_VALID:   return "معتبر";
      case SL_STATUS_INVALID: return "نامعتبر";
      default:                return "نامشخص";
     }
  }

//------------------------------------------------------------------
// تبدیل منبع مرجع به فارسی
//------------------------------------------------------------------
string SLReferenceToPersian(const string source)
  {
   if(source == "STRUCTURE" || source == "STRUCTURAL") return "ساختاری";
   if(source == "SWING")      return "Swing محلی";
   if(source == "ATR")        return "ATR";
   if(source == "ZONE")       return "ناحیه";
   if(source == "FIXED")      return "ثابت";
   return source == "" ? "نامشخص" : source;
  }

//------------------------------------------------------------------
// تبدیل enum منبع مرجع به فارسی
//------------------------------------------------------------------
string SLReferenceSourceToPersian(const ENUM_SL_REFERENCE_SOURCE source)
  {
   switch(source)
     {
      case SL_REFERENCE_STRUCTURAL: return "ساختاری";
      case SL_REFERENCE_SWING:      return "Swing محلی";
      case SL_REFERENCE_ZONE:       return "ناحیه";
      case SL_REFERENCE_ATR:        return "ATR";
      case SL_REFERENCE_FIXED:      return "ثابت";
      default:                      return "نامشخص";
     }
  }

//------------------------------------------------------------------
// مقداردهی اولیه
//------------------------------------------------------------------
void SL_Init(SLPlan &plan)
  {
   plan.method                    = SL_METHOD_STRUCTURE;
   plan.direction                 = SL_DIRECTION_NONE;
   plan.status                    = SL_STATUS_UNKNOWN;
   plan.reference_source_type     = SL_REFERENCE_NONE;

   plan.entry_price               = 0.0;
   plan.reference_price           = 0.0;
   plan.stop_price                = 0.0;
   plan.distance_price            = 0.0;
   plan.distance_points           = 0.0;
   plan.buffer_price              = 0.0;
   plan.reference_source          = "";
   plan.minimum_required_distance = 0.0;

   plan.atr_value                 = 0.0;
   plan.atr_multiplier            = 0.0;

   plan.created_time              = 0;
   plan.reason                    = "";
  }

//------------------------------------------------------------------
// اعتبارسنجی پایه حد ضرر
//------------------------------------------------------------------
bool SL_IsValid(const SLPlan &plan)
  {
   if(plan.direction == SL_DIRECTION_NONE)
      return false;
   if(plan.entry_price <= 0.0)
      return false;
   if(plan.stop_price <= 0.0)
      return false;
   if(plan.direction == SL_DIRECTION_BUY && plan.stop_price >= plan.entry_price)
      return false;
   if(plan.direction == SL_DIRECTION_SELL && plan.stop_price <= plan.entry_price)
      return false;
   if(plan.distance_price <= 0.0)
      return false;
   return true;
  }

//------------------------------------------------------------------
// تعیین فاصله حد ضرر
//------------------------------------------------------------------
void SL_UpdateDistance(SLPlan &plan, const double point_size)
  {
   if(plan.entry_price <= 0.0 || plan.stop_price <= 0.0)
     {
      plan.distance_price  = 0.0;
      plan.distance_points = 0.0;
      return;
     }
   plan.distance_price = MathAbs(plan.entry_price - plan.stop_price);
   if(point_size > 0.0)
      plan.distance_points = plan.distance_price / point_size;
   else
      plan.distance_points = 0.0;
  }

//------------------------------------------------------------------
// ساخت SL از روی قیمت مرجع ساختاری
//------------------------------------------------------------------
bool SL_FromReference(const ENUM_SL_DIRECTION direction,
                      const double entry_price,
                      const double reference_price,
                      const double buffer_price,
                      const double point_size,
                      SLPlan &plan)
  {
   SL_Init(plan);
   if(entry_price <= 0.0 || reference_price <= 0.0)
      return false;
   if(buffer_price < 0.0)
      return false;

   plan.method          = SL_METHOD_STRUCTURE;
   plan.direction       = direction;
   plan.entry_price     = entry_price;
   plan.reference_price = reference_price;
   plan.buffer_price    = buffer_price;
   plan.created_time    = TimeCurrent();

   if(direction == SL_DIRECTION_BUY)
     {
      if(reference_price >= entry_price)
        {
         plan.reason = "مرجع ساختاری برای BUY بالای قیمت ورود است";
         plan.status = SL_STATUS_INVALID;
         return false;
        }
      plan.stop_price = reference_price - buffer_price;
      plan.reason = "حد ضرر بر اساس مرجع ساختاری زیر نقطه مرجع قرار گرفت";
     }
   else if(direction == SL_DIRECTION_SELL)
     {
      if(reference_price <= entry_price)
        {
         plan.reason = "مرجع ساختاری برای SELL زیر قیمت ورود است";
         plan.status = SL_STATUS_INVALID;
         return false;
        }
      plan.stop_price = reference_price + buffer_price;
      plan.reason = "حد ضرر بر اساس مرجع ساختاری بالای نقطه مرجع قرار گرفت";
     }
   else
     {
      plan.reason = "جهت معامله برای تعیین حد ضرر مشخص نیست";
      plan.status = SL_STATUS_INVALID;
      return false;
     }

   SL_UpdateDistance(plan, point_size);
   plan.status = (SL_IsValid(plan) ? SL_STATUS_VALID : SL_STATUS_INVALID);
   return (plan.status == SL_STATUS_VALID);
  }

//------------------------------------------------------------------
// ساخت SL از روی مرز Zone
//------------------------------------------------------------------
bool SL_FromZone(const ENUM_SL_DIRECTION direction,
                 const double entry_price,
                 const double zone_boundary,
                 const double buffer_price,
                 const double point_size,
                 SLPlan &plan)
  {
   SL_Init(plan);
   if(entry_price <= 0.0 || zone_boundary <= 0.0)
      return false;
   if(buffer_price < 0.0)
      return false;

   plan.method          = SL_METHOD_ZONE;
   plan.direction       = direction;
   plan.entry_price     = entry_price;
   plan.reference_price = zone_boundary;
   plan.buffer_price    = buffer_price;
   plan.created_time    = TimeCurrent();

   if(direction == SL_DIRECTION_BUY)
     {
      plan.stop_price = zone_boundary - buffer_price;
      plan.reason = "حد ضرر بر اساس مرز ناحیه و بافر تعیین شد";
     }
   else if(direction == SL_DIRECTION_SELL)
     {
      plan.stop_price = zone_boundary + buffer_price;
      plan.reason = "حد ضرر بر اساس مرز ناحیه و بافر تعیین شد";
     }
   else
     {
      plan.reason = "جهت معامله برای تعیین حد ضرر مشخص نیست";
      plan.status = SL_STATUS_INVALID;
      return false;
     }

   SL_UpdateDistance(plan, point_size);
   plan.status = (SL_IsValid(plan) ? SL_STATUS_VALID : SL_STATUS_INVALID);
   return (plan.status == SL_STATUS_VALID);
  }

//------------------------------------------------------------------
// ساخت SL با فاصله ثابت قیمت
//------------------------------------------------------------------
bool SL_FromFixedDistance(const ENUM_SL_DIRECTION direction,
                          const double entry_price,
                          const double distance_price,
                          const double point_size,
                          SLPlan &plan)
  {
   SL_Init(plan);
   if(entry_price <= 0.0 || distance_price <= 0.0)
      return false;

   plan.method         = SL_METHOD_FIXED;
   plan.direction      = direction;
   plan.entry_price    = entry_price;
   plan.distance_price = distance_price;
   plan.created_time   = TimeCurrent();

   if(direction == SL_DIRECTION_BUY)
     {
      plan.stop_price = entry_price - distance_price;
      plan.reason = "حد ضرر با فاصله ثابت قیمت تعیین شد";
     }
   else if(direction == SL_DIRECTION_SELL)
     {
      plan.stop_price = entry_price + distance_price;
      plan.reason = "حد ضرر با فاصله ثابت قیمت تعیین شد";
     }
   else
     {
      plan.reason = "جهت معامله برای تعیین حد ضرر مشخص نیست";
      plan.status = SL_STATUS_INVALID;
      return false;
     }

   SL_UpdateDistance(plan, point_size);
   plan.status = (SL_IsValid(plan) ? SL_STATUS_VALID : SL_STATUS_INVALID);
   return (plan.status == SL_STATUS_VALID);
  }

//------------------------------------------------------------------
// ساخت SL بر اساس ATR
//------------------------------------------------------------------
bool SL_FromATR(const ENUM_SL_DIRECTION direction,
                const double entry_price,
                const double atr_value,
                const double atr_multiplier,
                const double point_size,
                SLPlan &plan)
  {
   SL_Init(plan);
   if(entry_price <= 0.0 || atr_value <= 0.0 || atr_multiplier <= 0.0)
      return false;

   plan.method         = SL_METHOD_ATR;
   plan.direction      = direction;
   plan.entry_price    = entry_price;
   plan.atr_value      = atr_value;
   plan.atr_multiplier = atr_multiplier;
   plan.distance_price = atr_value * atr_multiplier;
   plan.created_time   = TimeCurrent();

   if(direction == SL_DIRECTION_BUY)
     {
      plan.stop_price = entry_price - plan.distance_price;
      plan.reason = "حد ضرر بر اساس ATR تعیین شد";
     }
   else if(direction == SL_DIRECTION_SELL)
     {
      plan.stop_price = entry_price + plan.distance_price;
      plan.reason = "حد ضرر بر اساس ATR تعیین شد";
     }
   else
     {
      plan.reason = "جهت معامله برای تعیین حد ضرر مشخص نیست";
      plan.status = SL_STATUS_INVALID;
      return false;
     }

   SL_UpdateDistance(plan, point_size);
   plan.status = (SL_IsValid(plan) ? SL_STATUS_VALID : SL_STATUS_INVALID);
   return (plan.status == SL_STATUS_VALID);
  }

//------------------------------------------------------------------
// ساخت SL از روی Swing محلی
//------------------------------------------------------------------
bool SL_FromSwing(const ENUM_SL_DIRECTION direction,
                  const double entry_price,
                  const double swing_price,
                  const double buffer_price,
                  const double point_size,
                  SLPlan &plan)
  {
   SL_Init(plan);
   if(entry_price <= 0.0 || swing_price <= 0.0)
      return false;

   plan.method               = SL_METHOD_SWING;
   plan.direction            = direction;
   plan.entry_price          = entry_price;
   plan.reference_price      = swing_price;
   plan.buffer_price         = buffer_price;
   plan.reference_source_type = SL_REFERENCE_SWING;
   plan.reference_source     = "SWING";
   plan.created_time         = TimeCurrent();

   if(direction == SL_DIRECTION_BUY)
     {
      if(swing_price >= entry_price)
         return false;
      plan.stop_price = swing_price - buffer_price;
      plan.reason = "حد ضرر بر اساس Swing Low محلی";
     }
   else if(direction == SL_DIRECTION_SELL)
     {
      if(swing_price <= entry_price)
         return false;
      plan.stop_price = swing_price + buffer_price;
      plan.reason = "حد ضرر بر اساس Swing High محلی";
     }
   else
      return false;

   SL_UpdateDistance(plan, point_size);
   plan.status = (SL_IsValid(plan) ? SL_STATUS_VALID : SL_STATUS_INVALID);
   return (plan.status == SL_STATUS_VALID);
  }

//------------------------------------------------------------------
// بررسی حداقل فاصله
//------------------------------------------------------------------
bool SL_CheckMinimumDistance(const SLPlan &plan, const double minimum_distance)
  {
   if(!SL_IsValid(plan)) return false;
   if(minimum_distance <= 0.0) return true;
   return (plan.distance_price >= minimum_distance);
  }

//------------------------------------------------------------------
// بررسی حداکثر فاصله
//------------------------------------------------------------------
bool SL_CheckMaximumDistance(const SLPlan &plan, const double maximum_distance)
  {
   if(!SL_IsValid(plan)) return false;
   if(maximum_distance <= 0.0) return true;
   return (plan.distance_price <= maximum_distance);
  }

//------------------------------------------------------------------
// بررسی کامل محدودیت‌های فاصله
//------------------------------------------------------------------
bool SL_CheckDistanceLimits(const SLPlan &plan,
                            const double minimum_distance,
                            const double maximum_distance)
  {
   if(!SL_IsValid(plan)) return false;
   if(!SL_CheckMinimumDistance(plan, minimum_distance)) return false;
   if(!SL_CheckMaximumDistance(plan, maximum_distance)) return false;
   return true;
  }

//------------------------------------------------------------------
// نرمال‌سازی قیمت SL
//------------------------------------------------------------------
double SL_NormalizePrice(const double price, const int digits)
  {
   if(price <= 0.0) return 0.0;
   return NormalizeDouble(price, digits);
  }

//------------------------------------------------------------------
// محاسبه SL و بازگرداندن قیمت نهایی
//------------------------------------------------------------------
bool SL_GetPrice(const SLPlan &plan, const int digits, double &stop_price)
  {
   stop_price = 0.0;
   if(!SL_IsValid(plan)) return false;
   stop_price = SL_NormalizePrice(plan.stop_price, digits);
   if(stop_price <= 0.0) return false;
   if(plan.direction == SL_DIRECTION_BUY && stop_price >= plan.entry_price) return false;
   if(plan.direction == SL_DIRECTION_SELL && stop_price <= plan.entry_price) return false;
   return true;
  }

//------------------------------------------------------------------
// متن کامل برای گزارش
//------------------------------------------------------------------
string SL_ToText(const SLPlan &plan, const int digits)
  {
   string text = "";
   text += "روش: " + SLMethodToPersian(plan.method);
   text += " | جهت: " + SLDirectionToPersian(plan.direction);
   text += " | وضعیت: " + SLStatusToPersian(plan.status);
   text += " | ورود: " + DoubleToString(plan.entry_price, digits);
   text += " | مرجع: " + DoubleToString(plan.reference_price, digits);
   text += " | SL: " + DoubleToString(plan.stop_price, digits);
   text += " | فاصله: " + DoubleToString(plan.distance_price, digits);
   if(plan.buffer_price > 0.0)
      text += " | بافر: " + DoubleToString(plan.buffer_price, digits);
   if(plan.atr_value > 0.0)
      text += " | ATR: " + DoubleToString(plan.atr_value, digits);
   if(plan.atr_multiplier > 0.0)
      text += " | ضریب ATR: " + DoubleToString(plan.atr_multiplier, 2);
   if(plan.reason != "")
      text += " | دلیل: " + plan.reason;
   return text;
  }

//------------------------------------------------------------------
// محاسبه SL از مراجع بازار
//------------------------------------------------------------------
bool SL_FromMarketReferences(const string symbol,
                             const ENUM_SL_DIRECTION direction,
                             const double entry_price,
                             const MarketStructureSnapshot &structure,
                             const double atr_value,
                             const double point_size,
                             SLPlan &plan)
  {
   SL_Init(plan);

   if(symbol == "" || entry_price <= 0.0 || point_size <= 0.0)
     {
      plan.reason = "ورودی‌های SL_FromMarketReferences نامعتبر است";
      return false;
     }

   double buffer = MathMax(
      point_size * 5.0,
      atr_value > 0.0 ? atr_value * Inp_Invalidation_Buffer_ATR_Multiplier : point_size * 5.0);

   if(buffer <= 0.0)
      buffer = point_size * 5.0;

   double min_sl_points = Inp_Min_SL_Distance_Points;
   if(min_sl_points <= 0.0)
      min_sl_points = 20.0;

   double minimum_required_distance =
      MathMax(min_sl_points * point_size,
              atr_value > 0.0 ? atr_value * 0.50 : 0.0);

   double maximum_allowed_distance = 0.0;
   if(Inp_Max_SL_Distance_Points > 0.0)
      maximum_allowed_distance = Inp_Max_SL_Distance_Points * point_size;

   bool ok = false;
   double reference = 0.0;

   //--- Smart SL: ابتدا ساختار/Swing فعلی بازار
   if(Inp_Enable_Smart_SL && MarketStructure_IsValid(structure))
     {
      if(direction == SL_DIRECTION_BUY)
         reference = structure.structural_low;
      else if(direction == SL_DIRECTION_SELL)
         reference = structure.structural_high;

      if(reference > 0.0)
        {
         ok = SL_FromReference(
            direction,
            entry_price,
            reference,
            buffer,
            point_size,
            plan);

         if(ok)
           {
            plan.reference_source = "STRUCTURE";
            plan.reference_source_type = SL_REFERENCE_STRUCTURAL;
           }
        }

      if(!ok)
        {
         double swing_ref = 0.0;

         if(direction == SL_DIRECTION_BUY && structure.last_low.valid)
            swing_ref = structure.last_low.price;
         else if(direction == SL_DIRECTION_SELL && structure.last_high.valid)
            swing_ref = structure.last_high.price;

         if(swing_ref > 0.0)
           {
            ok = SL_FromSwing(
               direction,
               entry_price,
               swing_ref,
               buffer,
               point_size,
               plan);

            if(ok)
              {
               plan.reference_source = "SWING";
               plan.reference_source_type = SL_REFERENCE_SWING;
              }
           }
        }
     }

   //--- ساختار خیلی نزدیک است؛ در صورت مجاز بودن، ATR به عنوان پشتیبان
   if(ok && minimum_required_distance > 0.0 &&
      plan.distance_price < minimum_required_distance)
     {
      plan.reason = "فاصله SL ساختاری کمتر از حداقل فاصله منطقی است";
      ok = false;
     }

   if(ok && maximum_allowed_distance > 0.0 &&
      plan.distance_price > maximum_allowed_distance)
     {
      plan.reason = "فاصله SL ساختاری از حداکثر مجاز بیشتر است";
      ok = false;
     }

   //--- ATR fallback فقط وقتی Input آن فعال است
   if(!ok && Inp_Enable_ATR_SL_Fallback && atr_value > 0.0)
     {
      double atr_multiplier = Inp_ATR_SL_Multiplier;
      if(atr_multiplier <= 0.0)
         atr_multiplier = 1.50;
      if(atr_multiplier < 1.0)
         atr_multiplier = 1.0;

      ok = SL_FromATR(
         direction,
         entry_price,
         atr_value,
         atr_multiplier,
         point_size,
         plan);

      if(ok)
        {
         plan.reference_source = "ATR";
         plan.reference_source_type = SL_REFERENCE_ATR;
        }
     }

   if(!ok)
     {
      plan.reason =
         (Inp_Enable_Smart_SL || Inp_Enable_ATR_SL_Fallback)
         ? "تمام روش‌های مجاز ساخت SL ناموفق بودند"
         : "هیچ روش محاسبه SL فعال نیست";

      plan.status = SL_STATUS_INVALID;
      return false;
     }

   //--- کنترل نهایی حداقل/حداکثر فاصله
   plan.minimum_required_distance = minimum_required_distance;
   plan.atr_value = atr_value;
   plan.atr_multiplier = Inp_ATR_SL_Multiplier;

   if(minimum_required_distance > 0.0 &&
      plan.distance_price < minimum_required_distance)
     {
      plan.reason = "فاصله SL نهایی از حداقل فاصله منطقی کمتر است";
      plan.status = SL_STATUS_INVALID;
      return false;
     }

   if(maximum_allowed_distance > 0.0 &&
      plan.distance_price > maximum_allowed_distance)
     {
      plan.reason = "فاصله SL نهایی از حداکثر فاصله مجاز بیشتر است";
      plan.status = SL_STATUS_INVALID;
      return false;
     }

   plan.status = SL_STATUS_VALID;
   plan.distance_points = plan.distance_price / point_size;

   if(plan.reason == "")
      plan.reason =
         (plan.reference_source_type == SL_REFERENCE_ATR
          ? "SL با ATR پشتیبان محاسبه شد"
          : "SL با ساختار/آخرین Swing معتبر محاسبه شد");

   return true;
  }

//+------------------------------------------------------------------+
//|                    حد ضرر پلکانی (3 مرحله‌ای)                    |
//|                                                                  |
//| مرحله 1: قیمت >= ورود + 50% فاصله تا حد سود اول                |
//|          → حد ضرر = ورود + 10% فاصله (سود کم)                  |
//|                                                                  |
//| مرحله 2: قیمت >= حد سود اول                                     |
//|          → 50% حجم خروج + حد ضرر = نیمه ورود و حد سود اول      |
//|          → حد سود دوم فعال شود                                  |
//|                                                                  |
//| مرحله 3: قیمت >= حد سود اول + 50% فاصله تا حد سود دوم           |
//|          → حد ضرر = حد سود اول                                   |
//+------------------------------------------------------------------+

//====================================================================
// ساختار وضعیت حد ضرر پلکانی برای هر معامله
//====================================================================
struct StagedSLState
  {
   ulong     ticket;
   bool      is_buy;
   double    entry_price;
   double    tp1;
   double    tp2;
   double    current_sl;
   bool      stage1_done;
   bool      stage2_done;
   bool      stage3_done;
   bool      partial_done;
   double    initial_volume;
   datetime  open_time;
  };

//====================================================================
// مقداردهی اولیه ساختار
//====================================================================
void StagedSL_Init(StagedSLState &state)
  {
   state.ticket = 0;
   state.is_buy = true;
   state.entry_price = 0.0;
   state.tp1 = 0.0;
   state.tp2 = 0.0;
   state.current_sl = 0.0;
   state.stage1_done = false;
   state.stage2_done = false;
   state.stage3_done = false;
   state.partial_done = false;
   state.initial_volume = 0.0;
   state.open_time = 0;
  }

//====================================================================
// پر کردن ساختار از اطلاعات معامله باز
//====================================================================
void StagedSL_FillFromPosition(
   StagedSLState &state,
   const ulong ticket,
   const double tp1,
   const double tp2,
   const double initial_volume)
  {
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return;

   state.ticket = ticket;
   state.is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   state.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
   state.current_sl = PositionGetDouble(POSITION_SL);
   state.tp1 = tp1;
   state.tp2 = tp2;
   state.initial_volume = initial_volume;
   state.open_time = (datetime)PositionGetInteger(POSITION_TIME);

   double current_vol = PositionGetDouble(POSITION_VOLUME);
   double vol_step = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_VOLUME_STEP);

   if(state.initial_volume > 0.0 &&
      current_vol < state.initial_volume - MathMax(vol_step, state.initial_volume * 0.10))
     {
      state.partial_done = true;
      state.stage2_done = true;
     }

   double dist_to_tp1 = MathAbs(state.tp1 - state.entry_price);
   double stage1_sl_target = state.is_buy
      ? state.entry_price + dist_to_tp1 * 0.10
      : state.entry_price - dist_to_tp1 * 0.10;

   if(state.is_buy && state.current_sl >= stage1_sl_target - 2.0 * _Point)
      state.stage1_done = true;
   else if(!state.is_buy && state.current_sl > 0.0 &&
           state.current_sl <= stage1_sl_target + 2.0 * _Point)
      state.stage1_done = true;

   if(state.tp1 > 0.0 && state.current_sl > 0.0)
     {
      if(state.is_buy && state.current_sl >= state.tp1 - 2.0 * _Point)
        { state.stage3_done = true; state.stage2_done = true; }
      else if(!state.is_buy && state.current_sl <= state.tp1 + 2.0 * _Point)
        { state.stage3_done = true; state.stage2_done = true; }
     }
  }

//====================================================================
// اجرای مرحله 1: حد ضرر به سود کم
//====================================================================
bool StagedSL_ExecuteStage1(StagedSLState &state, const double current_price)
  {
   if(state.stage1_done || state.tp1 <= 0.0)
      return false;

   double dist_to_tp1 = MathAbs(state.tp1 - state.entry_price);
   double trigger_price = state.is_buy
      ? state.entry_price + dist_to_tp1 * 0.50
      : state.entry_price - dist_to_tp1 * 0.50;

   bool triggered = state.is_buy
      ? (current_price >= trigger_price)
      : (current_price <= trigger_price);

   if(!triggered)
      return false;

   double new_sl = state.is_buy
      ? state.entry_price + dist_to_tp1 * 0.10
      : state.entry_price - dist_to_tp1 * 0.10;
   new_sl = NormalizeDouble(new_sl, _Digits);

   if(!SL_ModifyPositionSLTP(state.ticket, PositionGetString(POSITION_SYMBOL),
      new_sl, PositionGetDouble(POSITION_TP)))
      return false;

   state.current_sl = new_sl;
   state.stage1_done = true;

   Print("[STAGED SL] Stage 1 | حد ضرر به سود کم منتقل شد",
      " | Ticket=", state.ticket,
      " | قیمت=", DoubleToString(current_price, _Digits),
      " | SL=", DoubleToString(new_sl, _Digits),
      " | TP1=", DoubleToString(state.tp1, _Digits));
   return true;
  }

//====================================================================
// اجرای مرحله 2: 50% خروج + حد ضرر به نیمه
//====================================================================
bool StagedSL_ExecuteStage2(StagedSLState &state, const double current_price,
                             const double partial_percent)
  {
   if(state.stage2_done || state.tp1 <= 0.0)
      return false;

   bool tp1_reached = state.is_buy
      ? (current_price >= state.tp1)
      : (current_price <= state.tp1);
   if(!tp1_reached)
      return false;

   double current_vol = PositionGetDouble(POSITION_VOLUME);
   double min_vol = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_VOLUME_MIN);
   double step = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_VOLUME_STEP);
   double requested_percent = MathMax(0.0, MathMin(100.0, partial_percent));
   double close_volume = SL_NormalizeVolume(current_vol * (requested_percent / 100.0));
   bool request_full_close = (requested_percent >= 99.999);
   bool partial_is_possible =
      (close_volume >= min_vol &&
       close_volume < current_vol - MathMax(step, 0.00000001) &&
       (current_vol - close_volume) >= min_vol - MathMax(step * 0.25, 0.00000001));

   if(request_full_close)
     {
      if(SL_ClosePositionVolume(state.ticket, PositionGetString(POSITION_SYMBOL),
         state.is_buy, current_vol, "TFlab TP1 Full Close"))
        {
         state.partial_done = true;
         state.stage2_done = true;
         Print("[STAGED SL] Stage 2 | خروج کامل طبق تنظیم درصد خروج",
            " | Ticket=", state.ticket,
            " | Volume=", DoubleToString(current_vol, 4));
         return true;
        }
      return false;
     }

   if(partial_is_possible)
     {
      if(!SL_ClosePositionVolume(state.ticket, PositionGetString(POSITION_SYMBOL),
         state.is_buy, close_volume, "TFlab TP1 Partial"))
         return false;
      state.partial_done = true;

      // پس از خروج جزئی، اطلاعات Position باید دوباره خوانده شود.
      if(!PositionSelectByTicket(state.ticket))
         return false;
     }
   else
     {
      // در حجم حداقل بروکر (مثلاً 0.01) تقسیم 50 درصدی ممکن نیست.
      // معامله را باز نگه می‌داریم و SL/TP را مدیریت می‌کنیم تا فرصت TP2 حفظ شود.
      Print("[STAGED SL] Stage 2 | حجم برای Partial کافی نیست؛ خروج انجام نشد و مدیریت SL/TP ادامه می‌یابد",
         " | Ticket=", state.ticket,
         " | Volume=", DoubleToString(current_vol, 4),
         " | MinVolume=", DoubleToString(min_vol, 4));
     }

   double new_sl = state.is_buy
      ? state.entry_price + MathAbs(state.tp1 - state.entry_price) * 0.50
      : state.entry_price - MathAbs(state.tp1 - state.entry_price) * 0.50;
   new_sl = NormalizeDouble(new_sl, _Digits);

   double new_tp = (state.tp2 > 0.0) ? state.tp2 : state.tp1;

   if(!SL_ModifyPositionSLTP(state.ticket, PositionGetString(POSITION_SYMBOL),
      new_sl, new_tp))
      return false;

   state.current_sl = new_sl;
   state.stage2_done = true;

   Print("[STAGED SL] Stage 2 | 50% خروج + SL به نیمه",
      " | Ticket=", state.ticket,
      " | SL=", DoubleToString(new_sl, _Digits),
      " | TP2=", DoubleToString(new_tp, _Digits));
   return true;
  }

//====================================================================
// اجرای مرحله 3: حد ضرر به حد سود اول
//====================================================================
bool StagedSL_ExecuteStage3(StagedSLState &state, const double current_price)
  {
   if(state.stage3_done || state.tp1 <= 0.0 || state.tp2 <= 0.0)
      return false;

   double dist_tp1_to_tp2 = MathAbs(state.tp2 - state.tp1);
   double trigger_price = state.is_buy
      ? state.tp1 + dist_tp1_to_tp2 * 0.50
      : state.tp1 - dist_tp1_to_tp2 * 0.50;

   bool triggered = state.is_buy
      ? (current_price >= trigger_price)
      : (current_price <= trigger_price);
   if(!triggered)
      return false;

   double new_sl = NormalizeDouble(state.tp1, _Digits);

   if(!SL_ModifyPositionSLTP(state.ticket, PositionGetString(POSITION_SYMBOL),
      new_sl, state.tp2))
      return false;

   state.current_sl = new_sl;
   state.stage3_done = true;

   Print("[STAGED SL] Stage 3 | SL به TP1 منتقل شد",
      " | Ticket=", state.ticket,
      " | SL=", DoubleToString(new_sl, _Digits),
      " | TP2=", DoubleToString(state.tp2, _Digits));
   return true;
  }

//====================================================================
// تابع اصلی: بررسی و اجرای تمام مراحل
//====================================================================
void StagedSL_Process(StagedSLState &state, const double current_price,
                      const double partial_percent)
  {
   if(state.ticket == 0) return;
   if(!PositionSelectByTicket(state.ticket)) return;

   if(!state.stage1_done)
     { StagedSL_ExecuteStage1(state, current_price); return; }
   if(!state.stage2_done)
     { StagedSL_ExecuteStage2(state, current_price, partial_percent); return; }
   if(!state.stage3_done)
     { StagedSL_ExecuteStage3(state, current_price); }
  }

//====================================================================
// بررسی آیا معامله به حد سود دوم رسیده است
//====================================================================
bool StagedSL_IsTP2Reached(const StagedSLState &state, const double current_price)
  {
   if(state.tp2 <= 0.0) return false;
   if(state.is_buy) return (current_price >= state.tp2);
   else return (current_price <= state.tp2);
  }

//+------------------------------------------------------------------+
#endif // __TFLAB_SL_ENGINE_MQH__