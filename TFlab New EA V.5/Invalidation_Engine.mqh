#ifndef __TFLAB_INVALIDATION_ENGINE_MQH__
#define __TFLAB_INVALIDATION_ENGINE_MQH__

//+------------------------------------------------------------------+
//|                  Invalidation_Engine.mqh                         |
//|                  TFlab New EA V.5                                |
//+------------------------------------------------------------------+
#property strict

#include "EA_Inputs.mqh"
#include "Scenario_Engine.mqh"

//====================================================================
// نوع بطلان
//====================================================================
enum ENUM_INVALIDATION_TYPE
  {
   INVALIDATION_NONE = 0,
   INVALIDATION_STRUCTURAL,
   INVALIDATION_ZONE,
   INVALIDATION_SCENARIO,
   INVALIDATION_PRICE,
   INVALIDATION_TIME,
   INVALIDATION_MANUAL
  };

//====================================================================
// وضعیت نتیجه بررسی ابطال
//====================================================================
enum ENUM_INVALIDATION_STATE
  {
   INVALIDATION_STATE_UNKNOWN = 0,
   INVALIDATION_STATE_VALID,
   INVALIDATION_STATE_INVALID,
   INVALIDATION_STATE_EXPIRED
  };

//====================================================================
// نتیجه بررسی ابطال
//====================================================================
struct InvalidationResult
  {
   ENUM_INVALIDATION_STATE state;
   ENUM_INVALIDATION_TYPE  type;

   double                  reference_price;
   double                  invalidation_price;
   double                  buffer_points;        
   bool                    candle_confirmed;     
   datetime                checked_time;

   string                  reason;
  };

//====================================================================
// تبدیل نوع ابطال به فارسی
//====================================================================
string InvalidationTypeToPersian(const ENUM_INVALIDATION_TYPE type)
  {
   switch(type)
     {
      case INVALIDATION_STRUCTURAL: return "ساختاری";
      case INVALIDATION_ZONE:       return "ناحیه";
      case INVALIDATION_SCENARIO:   return "سناریو";
      case INVALIDATION_PRICE:      return "قیمتی";
      case INVALIDATION_TIME:       return "زمانی";
      case INVALIDATION_MANUAL:     return "دستی";
      default:                      return "بدون ابطال";
     }
  }

//====================================================================
// تبدیل وضعیت به فارسی
//====================================================================
string InvalidationStateToPersian(const ENUM_INVALIDATION_STATE state)
  {
   switch(state)
     {
      case INVALIDATION_STATE_VALID:   return "معتبر";
      case INVALIDATION_STATE_INVALID: return "باطل";
      case INVALIDATION_STATE_EXPIRED: return "منقضی";
      default:                         return "نامشخص";
     }
  }

//====================================================================
// مقداردهی اولیه نتیجه
//====================================================================
void Invalidation_Init(InvalidationResult &result)
  {
   result.state              = INVALIDATION_STATE_UNKNOWN;
   result.type               = INVALIDATION_NONE;
   result.reference_price    = 0.0;
   result.invalidation_price = 0.0;
   result.buffer_points      = 0.0;
   result.candle_confirmed   = false;
   result.checked_time       = 0;
   result.reason             = "";
  }

//====================================================================
// بررسی صحت اطلاعات Invalidation سناریو
//====================================================================
bool Invalidation_HasValidLevel(const TradingScenario &scenario)
  {
   if(scenario.direction == SCENARIO_DIRECTION_NONE)
      return false;

   if(scenario.invalidation_price <= 0.0)
      return false;

   return true;
  }

//====================================================================
// بررسی ابطال قیمتی با Buffer و Candle Confirmation
//====================================================================
//====================================================================
// [جدید] Handle اختصاصی ATR برای محاسبه بافر ابطال (Cache شده)
//====================================================================
int Invalidation_GetATRHandle()
  {
   static int handle = INVALID_HANDLE;
   static ENUM_TIMEFRAMES cached_tf = PERIOD_CURRENT;
   static int cached_period = 0;

   if(handle == INVALID_HANDLE || cached_tf != PERIOD_M5 || cached_period != Inp_Invalidation_ATR_Period)
     {
      if(handle != INVALID_HANDLE)
         IndicatorRelease(handle);
      handle = iATR(_Symbol, PERIOD_M5, Inp_Invalidation_ATR_Period);
      cached_tf = PERIOD_M5;
      cached_period = Inp_Invalidation_ATR_Period;
     }

   return handle;
  }

bool Invalidation_IsPriceBroken(
   const TradingScenario &scenario,
   const double price,
   double &buffer_points,
   bool &candle_confirmed)
  {
   buffer_points = 0.0;
   candle_confirmed = false;

   if(!Invalidation_HasValidLevel(scenario))
      return false;

   if(price <= 0.0)
      return false;

   //=================================================================
   // [اصلاح] بافر حالا واقعاً بر اساس ATR و ورودی‌های قابل‌تنظیم محاسبه
   // می‌شود (قبلاً این ورودی‌ها ساخته شده بودند ولی هیچ‌جا استفاده
   // نمی‌شدند و یک قانون ثابت 5 پوینت/5٪ به‌جایشان اجرا می‌شد).
   //=================================================================
   double atr_buffer_points = 0.0;
   int atr_handle = Invalidation_GetATRHandle();

   if(atr_handle != INVALID_HANDLE)
     {
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(atr_handle, 0, 1, 1, atr_buf) == 1 && atr_buf[0] > 0.0)
         atr_buffer_points = (atr_buf[0] / _Point) * Inp_Invalidation_Buffer_ATR_Multiplier;
     }

   double min_buffer = atr_buffer_points;

   //--- در صورت نبودن داده ATR، به همون قانون قدیمی (فاصله Entry) برگرد تا سیستم متوقف نشود
   if(min_buffer <= 0.0 && scenario.entry_price > 0.0)
     {
      double distance = MathAbs(scenario.entry_price - scenario.invalidation_price);
      min_buffer = distance * 0.05;
     }

   min_buffer = MathMax(min_buffer, Inp_Invalidation_Min_Buffer_Points);
   min_buffer = MathMin(min_buffer, Inp_Invalidation_Max_Buffer_Points);

   buffer_points = min_buffer;
   double buffer_price = min_buffer * _Point;

   //=================================================================
   // بررسی بسته شدن کندل برای تأیید شکست
   //=================================================================
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M5, 1, 1, r) == 1)
     {
      double last_close = r[0].close;

      if(scenario.direction == SCENARIO_DIRECTION_BUY)
        {
         if(last_close < scenario.invalidation_price - buffer_price)
            candle_confirmed = true;
        }
      else if(scenario.direction == SCENARIO_DIRECTION_SELL)
        {
         if(last_close > scenario.invalidation_price + buffer_price)
            candle_confirmed = true;
        }
     }

   //=================================================================
   // قیمت جاری + buffer
   //=================================================================
   if(scenario.direction == SCENARIO_DIRECTION_BUY)
      return (price < scenario.invalidation_price - buffer_price);

   if(scenario.direction == SCENARIO_DIRECTION_SELL)
      return (price > scenario.invalidation_price + buffer_price);

   return false;
  }

//====================================================================
// بررسی انقضای زمانی
//====================================================================
bool Invalidation_IsExpiredByTime(const TradingScenario &scenario,
                                  const datetime current_time)
  {
   if(scenario.expiry_time <= 0)
      return false;

   return (current_time >= scenario.expiry_time);
  }

//====================================================================
// ارزیابی کامل پایه
//====================================================================
bool Invalidation_Evaluate(
   const TradingScenario &scenario,
   const double current_price,
   const datetime current_time,
   InvalidationResult &result)
  {
   Invalidation_Init(result);

   result.reference_price    = current_price;
   result.invalidation_price = scenario.invalidation_price;
   result.checked_time       = current_time;

   if(scenario.status == SCENARIO_STATUS_INVALID)
     {
      result.state  = INVALIDATION_STATE_INVALID;
      result.type   = INVALIDATION_SCENARIO;
      result.reason = "سناریو قبلاً باطل شده است";
      return true;
     }

   if(scenario.status == SCENARIO_STATUS_EXPIRED)
     {
      result.state  = INVALIDATION_STATE_EXPIRED;
      result.type   = INVALIDATION_TIME;
      result.reason = "سناریو قبلاً منقضی شده است";
      return true;
     }

   if(!Invalidation_HasValidLevel(scenario))
     {
      result.state  = INVALIDATION_STATE_UNKNOWN;
      result.type   = INVALIDATION_NONE;
      result.reason = "سطح ابطال سناریو معتبر یا کامل نیست";
      return false;
     }

   if(Invalidation_IsExpiredByTime(scenario, current_time))
     {
      result.state  = INVALIDATION_STATE_EXPIRED;
      result.type   = INVALIDATION_TIME;
      result.reason = "زمان اعتبار سناریو به پایان رسیده است | Expiry=" +
                      TimeToString(scenario.expiry_time, TIME_DATE | TIME_MINUTES);
      return true;
     }

   double buffer_pts = 0.0;
   bool candle_conf = false;
   bool price_broken = Invalidation_IsPriceBroken(
      scenario, current_price, buffer_pts, candle_conf);

   result.buffer_points = buffer_pts;
   result.candle_confirmed = candle_conf;

   if(price_broken)
     {
      result.state = INVALIDATION_STATE_INVALID;
      result.type  = INVALIDATION_PRICE;

      string dir_text = (scenario.direction == SCENARIO_DIRECTION_BUY ? "خرید" : "فروش");
      
      result.reason = "قیمت سطح ابطال سناریوی " + dir_text + " را شکست" +
                      " | Price=" + DoubleToString(current_price, _Digits) +
                      " | Invalidation=" + DoubleToString(scenario.invalidation_price, _Digits) +
                      " | Buffer=" + DoubleToString(buffer_pts, 1) + " pts" +
                      " | CandleConfirmed=" + (candle_conf ? "YES" : "NO");

      return true;
     }

   result.state  = INVALIDATION_STATE_VALID;
   result.type   = INVALIDATION_NONE;
   result.reason = "سطح ابطال سناریو شکسته نشده است";

   return true;
  }

//====================================================================
// ابطال مستقیم سناریو
//====================================================================
bool Invalidation_InvalidateScenario(
   TradingScenario &scenario,
   const ENUM_INVALIDATION_TYPE type,
   const string reason,
   const datetime current_time)
  {
   if(type == INVALIDATION_NONE)
      return false;

   scenario.status              = SCENARIO_STATUS_INVALID;
   scenario.updated_time        = current_time;
   scenario.invalidation_reason = reason;

   Print(
      "[INVALIDATION] INVALIDATED",
      " | ID=", scenario.id,
      " | Type=", InvalidationTypeToPersian(type),
      " | Direction=", ScenarioDirectionToPersian(scenario.direction),
      " | Reason=", reason
   );

   return true;
  }

//====================================================================
// منقضی کردن سناریو
//====================================================================
bool Invalidation_ExpireScenario(
   TradingScenario &scenario,
   const string reason,
   const datetime current_time)
  {
   scenario.status              = SCENARIO_STATUS_EXPIRED;
   scenario.updated_time        = current_time;
   scenario.invalidation_reason = reason;

   Print(
      "[INVALIDATION] EXPIRED",
      " | ID=", scenario.id,
      " | Direction=", ScenarioDirectionToPersian(scenario.direction),
      " | Expiry=", TimeToString(scenario.expiry_time, TIME_DATE | TIME_MINUTES),
      " | Reason=", reason
   );

   return true;
  }

//====================================================================
// بررسی و اعمال ابطال پایه روی سناریو
//====================================================================
bool Invalidation_UpdateScenario(
   TradingScenario &scenario,
   const double current_price,
   const datetime current_time,
   InvalidationResult &result)
  {
   if(!Invalidation_Evaluate(scenario, current_price, current_time, result))
      return false;

   if(result.state == INVALIDATION_STATE_INVALID)
     {
      Invalidation_InvalidateScenario(
         scenario,
         result.type,
         result.reason,
         current_time);
      return true;
     }

   if(result.state == INVALIDATION_STATE_EXPIRED)
     {
      Invalidation_ExpireScenario(
         scenario,
         result.reason,
         current_time);
      return true;
     }

   return true;
  }

//====================================================================
// بررسی رابطه Entry و Invalidation
//====================================================================
bool Invalidation_IsDirectionallyCorrect(const TradingScenario &scenario)
  {
   if(!Invalidation_HasValidLevel(scenario))
      return false;

   if(scenario.entry_price <= 0.0)
      return (scenario.invalidation_price > 0.0);

   if(scenario.direction == SCENARIO_DIRECTION_BUY)
      return (scenario.invalidation_price < scenario.entry_price);

   if(scenario.direction == SCENARIO_DIRECTION_SELL)
      return (scenario.invalidation_price > scenario.entry_price);

   return false;
  }

//====================================================================
// فاصله Entry تا Invalidation
//====================================================================
double Invalidation_Distance(const TradingScenario &scenario)
  {
   if(!Invalidation_HasValidLevel(scenario))
      return 0.0;

   if(scenario.entry_price <= 0.0)
      return 0.0;

   return MathAbs(scenario.entry_price - scenario.invalidation_price);
  }

//====================================================================
// بررسی اینکه سناریو باید در وضعیت موجود قابل معامله باشد یا خیر
//====================================================================
bool Invalidation_CanRemainActive(
   const TradingScenario &scenario,
   const double current_price,
   const datetime current_time,
   string &reason)
  {
   reason = "";

   if(!Invalidation_HasValidLevel(scenario))
     {
      reason = "اطلاعات ابطال سناریو ناقص است";
      return false;
     }

   if(scenario.status == SCENARIO_STATUS_INVALID)
     {
      reason = "سناریو باطل شده است";
      return false;
     }

   if(scenario.status == SCENARIO_STATUS_EXPIRED)
     {
      reason = "سناریو منقضی شده است";
      return false;
     }

   if(Invalidation_IsExpiredByTime(scenario, current_time))
     {
      reason = "زمان اعتبار سناریو به پایان رسیده است";
      return false;
     }

   double buffer_pts = 0.0;
   bool candle_conf = false;
   if(Invalidation_IsPriceBroken(scenario, current_price, buffer_pts, candle_conf))
     {
      if(scenario.direction == SCENARIO_DIRECTION_BUY)
         reason = "قیمت زیر سطح ابطال خرید قرار گرفته است";
      else
         reason = "قیمت بالای سطح ابطال فروش قرار گرفته است";

      reason += " | Buffer=" + DoubleToString(buffer_pts, 1) + " pts";
      return false;
     }

   if(!Invalidation_IsDirectionallyCorrect(scenario))
     {
      reason = "رابطه قیمت ورود و سطح ابطال نادرست است";
      return false;
     }

   reason = "سناریو از نظر Invalidation هنوز معتبر است";
   return true;
  }

//====================================================================
// تبدیل نتیجه به متن برای گزارش تفصیلی
//====================================================================
string Invalidation_ToText(const InvalidationResult &result)
  {
   string text = "";

   text += "وضعیت ابطال: " + InvalidationStateToPersian(result.state);
   text += " | نوع: " + InvalidationTypeToPersian(result.type);
   text += " | قیمت بررسی: " + DoubleToString(result.reference_price, _Digits);
   text += " | سطح ابطال: " + DoubleToString(result.invalidation_price, _Digits);
   text += " | Buffer: " + DoubleToString(result.buffer_points, 1) + " pts";
   text += " | Candle: " + (result.candle_confirmed ? "تأیید" : "نامشخص");

   if(result.reason != "")
      text += " | دلیل: " + result.reason;

   return text;
  }

//+------------------------------------------------------------------+
#endif // __TFLAB_INVALIDATION_ENGINE_MQH__