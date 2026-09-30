#ifndef __TFLAB_DIVERGENCE_DETECTOR_MQH__
#define __TFLAB_DIVERGENCE_DETECTOR_MQH__

//+------------------------------------------------------------------+
//|                   Divergence_Detector.mqh                        |
//|                   TFlab New EA V.5                                   |
//|                                                                  |
//| مسئولیت: تشخیص واگرایی RSI نسبت به Swing های ساختار بازار        |
//|                                                                  |
//| v2.2 - Fixed static array compilation error                      |
//+------------------------------------------------------------------+
#property strict
#include "Market_Structure.mqh"

//====================================================================
// انواع واگرایی
//====================================================================
enum ENUM_DIVERGENCE_TYPE
  {
   DIVERGENCE_NONE = 0,
   DIVERGENCE_BULLISH,           // واگرایی صعودی معمولی
   DIVERGENCE_BEARISH,           // واگرایی نزولی معمولی
   DIVERGENCE_HIDDEN_BULLISH,    // واگرایی صعودی پنهان
   DIVERGENCE_HIDDEN_BEARISH     // واگرایی نزولی پنهان
  };

//====================================================================
// تبدیل نوع واگرایی به متن فارسی
//====================================================================
string DivergenceTypeToPersian(const ENUM_DIVERGENCE_TYPE d)
  {
   switch(d)
     {
      case DIVERGENCE_BULLISH:        return "واگرایی صعودی معمولی";
      case DIVERGENCE_BEARISH:        return "واگرایی نزولی معمولی";
      case DIVERGENCE_HIDDEN_BULLISH: return "واگرایی صعودی پنهان";
      case DIVERGENCE_HIDDEN_BEARISH: return "واگرایی نزولی پنهان";
      default:                        return "بدون واگرایی";
     }
  }

//====================================================================
// تبدیل نوع واگرایی به کد انگلیسی برای لاگ
//====================================================================
string DivergenceTypeToCode(const ENUM_DIVERGENCE_TYPE d)
  {
   switch(d)
     {
      case DIVERGENCE_BULLISH:        return "BULLISH";
      case DIVERGENCE_BEARISH:        return "BEARISH";
      case DIVERGENCE_HIDDEN_BULLISH: return "HIDDEN_BULL";
      case DIVERGENCE_HIDDEN_BEARISH: return "HIDDEN_BEAR";
      default:                        return "NONE";
     }
  }

//====================================================================
// تشخیص واگرایی RSI نسبت به Swing های ساختار
//====================================================================
ENUM_DIVERGENCE_TYPE Divergence_Detect(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int rsi_period,
   const MarketStructureSnapshot &structure,
   string &reason)
  {
   reason = "بدون واگرایی معتبر";

   if(!MarketStructure_IsValid(structure))
     {
      reason = "ساختار بازار معتبر نیست";
      return DIVERGENCE_NONE;
     }

   //--- ایجاد هندل RSI
   int rsi_handle = iRSI(symbol, timeframe, rsi_period, PRICE_CLOSE);
   if(rsi_handle == INVALID_HANDLE)
     {
      reason = "خطا در ایجاد هندل RSI";
      return DIVERGENCE_NONE;
     }

   //--- حداقل اختلاف RSI برای تشخیص واگرایی (جلوگیری از نویز)
   const double rsi_tolerance = 2.0;

   //=================================================================
   // بررسی واگرایی روی سقف‌ها (Bearish / Hidden Bearish)
   //=================================================================
   if(structure.last_high.valid &&
      structure.previous_high.valid &&
      structure.latest_high_label != STRUCTURE_LABEL_NONE)
     {
      double rsi_last = 0.0, rsi_prev = 0.0;
      double buffer[]; // [اصلاح] تغییر به آرایه داینامیک
      ArraySetAsSeries(buffer, true);

      if(CopyBuffer(rsi_handle, 0, structure.last_high.shift, 1, buffer) == 1)
         rsi_last = buffer[0];

      if(CopyBuffer(rsi_handle, 0, structure.previous_high.shift, 1, buffer) == 1)
         rsi_prev = buffer[0];

      if(rsi_last > 0.0 && rsi_prev > 0.0)
        {
         //--- Regular Bearish: Price HH, RSI LH
         if(structure.latest_high_label == STRUCTURE_LABEL_HH &&
            rsi_last < rsi_prev - rsi_tolerance)
           {
            IndicatorRelease(rsi_handle);
            reason = "واگرایی نزولی معمولی | Price=HH | RSI=LH (" +
                     DoubleToString(rsi_prev, 1) + " -> " +
                     DoubleToString(rsi_last, 1) + ")";
            Print("[DIVERGENCE] BEARISH | ", reason);
            return DIVERGENCE_BEARISH;
           }

         //--- Hidden Bearish: Price LH, RSI HH
         if(structure.latest_high_label == STRUCTURE_LABEL_LH &&
            rsi_last > rsi_prev + rsi_tolerance)
           {
            IndicatorRelease(rsi_handle);
            reason = "واگرایی نزولی پنهان | Price=LH | RSI=HH (" +
                     DoubleToString(rsi_prev, 1) + " -> " +
                     DoubleToString(rsi_last, 1) + ")";
            Print("[DIVERGENCE] HIDDEN_BEAR | ", reason);
            return DIVERGENCE_HIDDEN_BEARISH;
           }
        }
     }

   //=================================================================
   // بررسی واگرایی روی کف‌ها (Bullish / Hidden Bullish)
   //=================================================================
   if(structure.last_low.valid &&
      structure.previous_low.valid &&
      structure.latest_low_label != STRUCTURE_LABEL_NONE)
     {
      double rsi_last = 0.0, rsi_prev = 0.0;
      double buffer[]; // [اصلاح] تغییر به آرایه داینامیک
      ArraySetAsSeries(buffer, true);

      if(CopyBuffer(rsi_handle, 0, structure.last_low.shift, 1, buffer) == 1)
         rsi_last = buffer[0];

      if(CopyBuffer(rsi_handle, 0, structure.previous_low.shift, 1, buffer) == 1)
         rsi_prev = buffer[0];

      if(rsi_last > 0.0 && rsi_prev > 0.0)
        {
         //--- Regular Bullish: Price LL, RSI HL
         if(structure.latest_low_label == STRUCTURE_LABEL_LL &&
            rsi_last > rsi_prev + rsi_tolerance)
           {
            IndicatorRelease(rsi_handle);
            reason = "واگرایی صعودی معمولی | Price=LL | RSI=HL (" +
                     DoubleToString(rsi_prev, 1) + " -> " +
                     DoubleToString(rsi_last, 1) + ")";
            Print("[DIVERGENCE] BULLISH | ", reason);
            return DIVERGENCE_BULLISH;
           }

         //--- Hidden Bullish: Price HL, RSI LL
         if(structure.latest_low_label == STRUCTURE_LABEL_HL &&
            rsi_last < rsi_prev - rsi_tolerance)
           {
            IndicatorRelease(rsi_handle);
            reason = "واگرایی صعودی پنهان | Price=HL | RSI=LL (" +
                     DoubleToString(rsi_prev, 1) + " -> " +
                     DoubleToString(rsi_last, 1) + ")";
            Print("[DIVERGENCE] HIDDEN_BULL | ", reason);
            return DIVERGENCE_HIDDEN_BULLISH;
           }
        }
     }

   IndicatorRelease(rsi_handle);
   
   //--- لاگ تشخیصی برای حالت بدون واگرایی
   Print(
      "[DIVERGENCE] NONE | HighLabel=", MarketStructure_LabelToCode(structure.latest_high_label),
      " | LowLabel=", MarketStructure_LabelToCode(structure.latest_low_label)
   );
   
   return DIVERGENCE_NONE;
  }

//====================================================================
// آیا واگرایی خلاف جهت معامله است؟ (باعث رد معامله می‌شود)
//====================================================================
bool Divergence_IsAgainstDirection(const ENUM_DIVERGENCE_TYPE d, const bool buy)
  {
   if(buy)
      return (d == DIVERGENCE_BEARISH);
   else
      return (d == DIVERGENCE_BULLISH);
  }

//====================================================================
// آیا واگرایی از جهت معامله حمایت می‌کند؟
//====================================================================
bool Divergence_SupportsDirection(const ENUM_DIVERGENCE_TYPE d, const bool buy)
  {
   if(buy)
      return (d == DIVERGENCE_BULLISH || d == DIVERGENCE_HIDDEN_BULLISH);
   else
      return (d == DIVERGENCE_BEARISH || d == DIVERGENCE_HIDDEN_BEARISH);
  }

#endif // __TFLAB_DIVERGENCE_DETECTOR_MQH__