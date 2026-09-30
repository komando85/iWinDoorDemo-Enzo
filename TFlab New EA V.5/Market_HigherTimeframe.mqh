//+------------------------------------------------------------------+
//|                  Market_HigherTimeframe.mqh                     |
//|                 New EA - Higher Timeframe Context                |
//|                                                                  |
//| H4 / H1 فقط برای شناخت زمینه بزرگ‌تر بازار.                     |
//| این موتور هیچ تصمیم ورود، معامله، سفارش یا ریسک صادر نمی‌کند.   |
//|                                                                  |
//| v2.1 - بهبود تشخیص با EMA + وزن‌دهی H4 + لاگ تشخیصی           |
//+------------------------------------------------------------------+
#ifndef __MARKET_HIGHER_TIMEFRAME_MQH__
#define __MARKET_HIGHER_TIMEFRAME_MQH__

#include "EA_Inputs.mqh"

//====================================================================
// جهت زمینه بازار در این موتور
//====================================================================
enum ENUM_HTF_DIRECTION
  {
   HTF_DIRECTION_UNKNOWN = 0,
   HTF_DIRECTION_BULLISH = 1,
   HTF_DIRECTION_BEARISH = -1,
   HTF_DIRECTION_NEUTRAL = 2
  };

//====================================================================
// وضعیت یک تایم‌فریم بالاتر
//====================================================================
struct HigherTimeframeSnapshot
  {
   ENUM_TIMEFRAMES timeframe;
   bool             enabled;
   bool             data_valid;
   datetime         last_closed_bar_time;
   double           last_closed_price;
   double           previous_closed_price;
   double           price_change;
   double           range_points;
   double           atr_points;
   double           ema_value;
   double           direction_strength;
   ENUM_HTF_DIRECTION direction;
   string           direction_reason;
  };

//====================================================================
// خروجی موتور زمینه H4 / H1
//====================================================================
struct HigherTimeframeContext
  {
   HigherTimeframeSnapshot h4;
   HigherTimeframeSnapshot h1;

   ENUM_HTF_DIRECTION combined_direction;
   double              combined_strength;
   bool                valid;

   datetime             analysis_time;
  };

HigherTimeframeContext g_higher_tf_context;

//====================================================================
// توابع داخلی
//====================================================================

void ResetHigherTimeframeSnapshot(HigherTimeframeSnapshot &snapshot)
  {
   snapshot.timeframe             = PERIOD_CURRENT;
   snapshot.enabled               = false;
   snapshot.data_valid            = false;
   snapshot.last_closed_bar_time  = 0;
   snapshot.last_closed_price     = 0.0;
   snapshot.previous_closed_price = 0.0;
   snapshot.price_change          = 0.0;
   snapshot.range_points          = 0.0;
   snapshot.atr_points            = 0.0;
   snapshot.ema_value             = 0.0;
   snapshot.direction_strength    = 0.0;
   snapshot.direction             = HTF_DIRECTION_UNKNOWN;
   snapshot.direction_reason      = "";
  }

void ResetHigherTimeframeContext()
  {
   ZeroMemory(g_higher_tf_context);
   ResetHigherTimeframeSnapshot(g_higher_tf_context.h4);
   ResetHigherTimeframeSnapshot(g_higher_tf_context.h1);
   g_higher_tf_context.combined_direction = HTF_DIRECTION_UNKNOWN;
   g_higher_tf_context.combined_strength  = 0.0;
   g_higher_tf_context.valid               = false;
   g_higher_tf_context.analysis_time       = 0;
  }

//--------------------------------------------------------------------
// محاسبه ATR به‌صورت داخلی برای شناخت شدت حرکت.
//--------------------------------------------------------------------
bool CalculateATRPoints(const ENUM_TIMEFRAMES timeframe,
                        const int period,
                        double &atr_points)
  {
   atr_points = 0.0;

   if(period < 1)
      return false;

   int handle = iATR(_Symbol, timeframe, period);
   if(handle == INVALID_HANDLE)
      return false;

   double buffer[];
   ArraySetAsSeries(buffer, true);

   int copied = CopyBuffer(handle, 0, 1, 1, buffer);
   IndicatorRelease(handle);

   if(copied != 1)
      return false;

   if(buffer[0] <= 0.0)
      return false;

   atr_points = buffer[0] / _Point;
   return true;
  }

//--------------------------------------------------------------------
// محاسبه EMA
//--------------------------------------------------------------------
bool CalculateEMA(const ENUM_TIMEFRAMES timeframe,
                  const int period,
                  double &ema_value)
  {
   ema_value = 0.0;

   if(period < 1)
      return false;

   int handle = iMA(_Symbol, timeframe, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return false;

   double buffer[];
   ArraySetAsSeries(buffer, true);

   int copied = CopyBuffer(handle, 0, 1, 1, buffer);
   IndicatorRelease(handle);

   if(copied != 1)
      return false;

   if(buffer[0] <= 0.0)
      return false;

   ema_value = buffer[0];
   return true;
  }

//--------------------------------------------------------------------
// تعیین جهت با استفاده از EMA + Price Change + ATR
// [اصلاح] استفاده از EMA 50 به جای فقط دو کندل
//--------------------------------------------------------------------
ENUM_HTF_DIRECTION DetermineBasicDirection(const ENUM_TIMEFRAMES timeframe,
                                           const double current_close,
                                           const double previous_close,
                                           const double ema_value,
                                           const double atr_points,
                                           double &strength,
                                           string &reason)
  {
   strength = 0.0;
   reason = "";

   if(current_close <= 0.0 || previous_close <= 0.0)
      return HTF_DIRECTION_UNKNOWN;

   double change_points = MathAbs(current_close - previous_close) / _Point;
   double change_direction = (current_close > previous_close) ? 1.0 : -1.0;

   //--- [جدید] استفاده از EMA برای تشخیص جهت اصلی
   bool price_above_ema = (current_close > ema_value && ema_value > 0.0);
   bool price_below_ema = (current_close < ema_value && ema_value > 0.0);

   //--- محاسبه strength نسبی بر اساس ATR
   double relative_strength = 0.0;
   if(atr_points > 0.0)
      relative_strength = change_points / atr_points;

   //=================================================================
   // حالت 1: EMA و Price Change هم‌جهت هستند (قوی‌ترین سیگنال)
   //=================================================================
   if(price_above_ema && change_direction > 0)
     {
      strength = MathMin(100.0, 50.0 + relative_strength * 30.0);
      reason = "Price > EMA + Bullish Close | ATRx=" + 
               DoubleToString(relative_strength, 2);
      return HTF_DIRECTION_BULLISH;
     }

   if(price_below_ema && change_direction < 0)
     {
      strength = MathMin(100.0, 50.0 + relative_strength * 30.0);
      reason = "Price < EMA + Bearish Close | ATRx=" + 
               DoubleToString(relative_strength, 2);
      return HTF_DIRECTION_BEARISH;
     }

   //=================================================================
   // حالت 2: EMA جهت مشخص دارد ولی Price Change مخالف است (اصلاح)
   //=================================================================
   if(price_above_ema && change_direction <= 0)
     {
      // اصلاح در روند صعودی - همچنان صعودی است
      strength = MathMin(100.0, 35.0 + relative_strength * 15.0);
      reason = "Price > EMA but Bearish Close (Correction) | ATRx=" + 
               DoubleToString(relative_strength, 2);
      return HTF_DIRECTION_BULLISH;
     }

   if(price_below_ema && change_direction >= 0)
     {
      // اصلاح در روند نزولی - همچنان نزولی است
      strength = MathMin(100.0, 35.0 + relative_strength * 15.0);
      reason = "Price < EMA but Bullish Close (Correction) | ATRx=" + 
               DoubleToString(relative_strength, 2);
      return HTF_DIRECTION_BEARISH;
     }

   //=================================================================
   // حالت 3: EMA معتبر نیست، فقط از Price Change استفاده می‌کنیم
   //=================================================================
   if(ema_value <= 0.0)
     {
      if(change_points < 5.0) // کمتر از 5 point
        {
         strength = 10.0;
         reason = "EMA invalid + Small Change | Change=" + 
                  DoubleToString(change_points, 1) + " pts";
         return HTF_DIRECTION_NEUTRAL;
        }

      strength = MathMin(100.0, 30.0 + relative_strength * 20.0);
      reason = "EMA invalid, using Price Change only | ATRx=" + 
               DoubleToString(relative_strength, 2);

      if(change_direction > 0)
         return HTF_DIRECTION_BULLISH;
      if(change_direction < 0)
         return HTF_DIRECTION_BEARISH;
     }

   //=================================================================
   // حالت 4: تغییر خیلی کوچک (خنثی)
   //=================================================================
   if(change_points < 3.0)
     {
      strength = 15.0;
      reason = "Very Small Change | Change=" + 
               DoubleToString(change_points, 1) + " pts";
      return HTF_DIRECTION_NEUTRAL;
     }

   reason = "Unable to determine direction";
   return HTF_DIRECTION_UNKNOWN;
  }

//--------------------------------------------------------------------
// خواندن وضعیت یک تایم‌فریم
// [اصلاح] افزودن EMA و لاگ تشخیصی
//--------------------------------------------------------------------
bool ReadHigherTimeframe(const ENUM_TIMEFRAMES timeframe,
                         const bool enabled,
                         HigherTimeframeSnapshot &snapshot)
  {
   ResetHigherTimeframeSnapshot(snapshot);
   snapshot.timeframe = timeframe;
   snapshot.enabled   = enabled;

   if(!enabled)
      return true;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(_Symbol, timeframe, 1, 3, rates);
   if(copied < 2)
      return false;

   snapshot.last_closed_bar_time  = rates[0].time;
   snapshot.last_closed_price     = rates[0].close;
   snapshot.previous_closed_price = rates[1].close;
   snapshot.price_change          = rates[0].close - rates[1].close;
   snapshot.range_points          = (rates[0].high - rates[0].low) / _Point;

   //--- محاسبه ATR
   CalculateATRPoints(timeframe, Inp_ATR_Period, snapshot.atr_points);

   //--- [جدید] محاسبه EMA 50
   CalculateEMA(timeframe, 50, snapshot.ema_value);

   //--- [اصلاح] تشخیص جهت با متد بهبود یافته
   double strength = 0.0;
   string reason = "";
   snapshot.direction = DetermineBasicDirection(timeframe,
                                                rates[0].close,
                                                rates[1].close,
                                                snapshot.ema_value,
                                                snapshot.atr_points,
                                                strength,
                                                reason);
   snapshot.direction_strength = strength;
   snapshot.direction_reason = reason;

   snapshot.data_valid = true;
   return true;
  }

//--------------------------------------------------------------------
// ترکیب H4 و H1 با وزن‌دهی
// [اصلاح] H4 وزن 2 برابر H1 دارد
//--------------------------------------------------------------------
ENUM_HTF_DIRECTION CombineDirections(const HigherTimeframeSnapshot &h4,
                                     const HigherTimeframeSnapshot &h1,
                                     double &combined_strength)
  {
   combined_strength = 0.0;

   double bullish_score = 0.0;
   double bearish_score = 0.0;

   //--- H4 وزن 2 برابر دارد
   const double h4_weight = 2.0;
   const double h1_weight = 1.0;

   if(h4.enabled && h4.data_valid)
     {
      if(h4.direction == HTF_DIRECTION_BULLISH)
        {
         bullish_score += h4.direction_strength * h4_weight;
        }
      else if(h4.direction == HTF_DIRECTION_BEARISH)
        {
         bearish_score += h4.direction_strength * h4_weight;
        }
     }

   if(h1.enabled && h1.data_valid)
     {
      if(h1.direction == HTF_DIRECTION_BULLISH)
        {
         bullish_score += h1.direction_strength * h1_weight;
        }
      else if(h1.direction == HTF_DIRECTION_BEARISH)
        {
         bearish_score += h1.direction_strength * h1_weight;
        }
     }

   //--- اگر هیچ تایم‌فریمی enabled نباشد
   if(bullish_score == 0.0 && bearish_score == 0.0)
      return HTF_DIRECTION_UNKNOWN;

   //--- محاسبه قدرت نسبی
   double total_score = bullish_score + bearish_score;
   if(total_score <= 0.0)
      return HTF_DIRECTION_UNKNOWN;

   double bullish_ratio = bullish_score / total_score;
   double bearish_ratio = bearish_score / total_score;

   //--- [اصلاح] نرم‌تر کردن شرط NEUTRAL
   // اگر اختلاف کمتر از 15% باشد، NEUTRAL است
   const double neutral_threshold = 0.15;

   if(MathAbs(bullish_ratio - bearish_ratio) < neutral_threshold)
     {
      combined_strength = MathMin(100.0, (bullish_score + bearish_score) / 2.0);
      return HTF_DIRECTION_NEUTRAL;
     }

   if(bullish_score > bearish_score)
     {
      combined_strength = MathMin(100.0, bullish_score / (h4_weight + h1_weight));
      return HTF_DIRECTION_BULLISH;
     }

   if(bearish_score > bullish_score)
     {
      combined_strength = MathMin(100.0, bearish_score / (h4_weight + h1_weight));
      return HTF_DIRECTION_BEARISH;
     }

   return HTF_DIRECTION_NEUTRAL;
  }

//====================================================================
// API عمومی موتور
//====================================================================

bool InitializeHigherTimeframeEngine()
  {
   ResetHigherTimeframeContext();

   if(!Inp_Use_H4_Background && !Inp_Use_H1_Background)
     {
      g_higher_tf_context.valid = true;
      g_higher_tf_context.analysis_time = TimeCurrent();
      return true;
     }

   return RefreshHigherTimeframeContext();
  }

bool RefreshHigherTimeframeContext()
  {
   ResetHigherTimeframeContext();

   bool h4_ok = ReadHigherTimeframe(Inp_TF_Background_H4,
                                    Inp_Use_H4_Background,
                                    g_higher_tf_context.h4);

   bool h1_ok = ReadHigherTimeframe(Inp_TF_Background_H1,
                                    Inp_Use_H1_Background,
                                    g_higher_tf_context.h1);

   if(Inp_Use_H4_Background && !h4_ok)
      return false;

   if(Inp_Use_H1_Background && !h1_ok)
      return false;

   g_higher_tf_context.combined_direction =
      CombineDirections(g_higher_tf_context.h4,
                        g_higher_tf_context.h1,
                        g_higher_tf_context.combined_strength);

   g_higher_tf_context.analysis_time = TimeCurrent();
   g_higher_tf_context.valid = true;

   //=================================================================
   // [جدید] لاگ تشخیصی کامل
   //=================================================================
   string h4_dir_text = HigherTimeframeDirectionToText(g_higher_tf_context.h4.direction);
   string h1_dir_text = HigherTimeframeDirectionToText(g_higher_tf_context.h1.direction);
   string combined_dir_text = HigherTimeframeDirectionToText(g_higher_tf_context.combined_direction);

   Print(
      "[HTF CONTEXT] Combined=", combined_dir_text,
      " | Strength=", DoubleToString(g_higher_tf_context.combined_strength, 1),
      " | H4=", (Inp_Use_H4_Background ? h4_dir_text : "DISABLED"),
      " (", DoubleToString(g_higher_tf_context.h4.direction_strength, 1), ")",
      " | H1=", (Inp_Use_H1_Background ? h1_dir_text : "DISABLED"),
      " (", DoubleToString(g_higher_tf_context.h1.direction_strength, 1), ")"
   );

   if(Inp_Use_H4_Background && g_higher_tf_context.h4.data_valid)
     {
      Print(
         "[HTF H4] Direction=", h4_dir_text,
         " | EMA=", DoubleToString(g_higher_tf_context.h4.ema_value, _Digits),
         " | Price=", DoubleToString(g_higher_tf_context.h4.last_closed_price, _Digits),
         " | ATR=", DoubleToString(g_higher_tf_context.h4.atr_points, 1),
         " | ", g_higher_tf_context.h4.direction_reason
      );
     }

   if(Inp_Use_H1_Background && g_higher_tf_context.h1.data_valid)
     {
      Print(
         "[HTF H1] Direction=", h1_dir_text,
         " | EMA=", DoubleToString(g_higher_tf_context.h1.ema_value, _Digits),
         " | Price=", DoubleToString(g_higher_tf_context.h1.last_closed_price, _Digits),
         " | ATR=", DoubleToString(g_higher_tf_context.h1.atr_points, 1),
         " | ", g_higher_tf_context.h1.direction_reason
      );
     }

   return true;
  }

HigherTimeframeContext GetHigherTimeframeContext()
  {
   return g_higher_tf_context;
  }

ENUM_HTF_DIRECTION GetHigherTimeframeDirection()
  {
   return g_higher_tf_context.combined_direction;
  }

string HigherTimeframeDirectionToText(const ENUM_HTF_DIRECTION direction)
  {
   switch(direction)
     {
      case HTF_DIRECTION_BULLISH:
         return "صعودی";

      case HTF_DIRECTION_BEARISH:
         return "نزولی";

      case HTF_DIRECTION_NEUTRAL:
         return "خنثی";

      default:
         return "نامشخص";
     }
  }

//====================================================================
// گزارش ساده برای Logger آینده
//====================================================================
string BuildHigherTimeframeSummary()
  {
   string text = "شناخت تایم‌فریم‌های بالاتر | ";

   if(Inp_Use_H4_Background)
      text += "H4=" + HigherTimeframeDirectionToText(g_higher_tf_context.h4.direction);
   else
      text += "H4=غیرفعال";

   text += " | ";

   if(Inp_Use_H1_Background)
      text += "H1=" + HigherTimeframeDirectionToText(g_higher_tf_context.h1.direction);
   else
      text += "H1=غیرفعال";

   text += " | زمینه کلی=" + HigherTimeframeDirectionToText(g_higher_tf_context.combined_direction);

   return text;
  }

#endif // __MARKET_HIGHER_TIMEFRAME_MQH__
//+------------------------------------------------------------------+