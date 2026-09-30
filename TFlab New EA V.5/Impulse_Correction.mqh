//+------------------------------------------------------------------+
//|                 Impulse_Correction.mqh                          |
//|                 TFlab New EA V.5                                     |
//|                                                                  |
//| مسئولیت: تشخیص حرکت اصلی (Impulse) و اصلاح (Correction)         |
//| بر پایه ساختار بازار و اندازه حرکت قیمت                         |
//|                                                                  |
//| این فایل:                                                        |
//| - هیچ معامله‌ای ایجاد نمی‌کند                                    |
//| - Entry / SL / TP / Risk / Execution ندارد                      |
//| - فقط وضعیت حرکت و اصلاح را تولید می‌کند                        |
//|                                                                  |
//| نکته مهم: کندل جاری برای تصمیم ساختاری استفاده نمی‌شود.         |
//+------------------------------------------------------------------+
#ifndef __IMPULSE_CORRECTION_MQH__
#define __IMPULSE_CORRECTION_MQH__

#property strict

#include "EA_Inputs.mqh"
#include "Market_Structure.mqh"
#include "Market_Truth_Engine.mqh"

//====================================================================
// وضعیت حرکت
//====================================================================
enum ENUM_MOVE_STATE
  {
   MOVE_STATE_UNKNOWN = 0,
   MOVE_STATE_NONE,
   MOVE_STATE_IMPULSE_UP,
   MOVE_STATE_IMPULSE_DOWN,
   MOVE_STATE_CORRECTION_UP,
   MOVE_STATE_CORRECTION_DOWN,
   MOVE_STATE_TRANSITION,
   MOVE_STATE_INVALID
  };

//====================================================================
// Snapshot حرکت و اصلاح
//====================================================================
struct ImpulseCorrectionSnapshot
  {
   bool              valid;
   string            symbol;
   ENUM_TIMEFRAMES   timeframe;
   datetime          analysis_time;

   ENUM_MOVE_STATE   state;

   bool              impulse_valid;
   bool              correction_valid;
   int               impulse_direction;       // +1 = صعودی، -1 = نزولی، 0 = ندارد
   int               correction_direction;   // +1 = صعودی، -1 = نزولی، 0 = ندارد

   double            impulse_start_price;
   double            impulse_end_price;
   double            impulse_size_points;
   int               impulse_bars;
   double            impulse_atr;
   double            impulse_atr_multiple;

   double            correction_start_price;
   double            correction_end_price;
   double            correction_size_points;
   double            correction_ratio;
   double            correction_extreme_price; // [جدید] بیشترین عمق اصلاح
   
   //--- [جدید] آیا اصلاح قبلاً بیش از حد مجاز رفته و برگشته؟
   bool              correction_recovered;

   datetime          impulse_start_time;
   datetime          impulse_end_time;
   datetime          correction_start_time;
   datetime          correction_end_time;

   string            reason;
  };

//====================================================================
// تبدیل وضعیت به فارسی
//====================================================================
string ImpulseCorrection_StateToPersian(const ENUM_MOVE_STATE state)
  {
   switch(state)
     {
      case MOVE_STATE_NONE:             return "بدون حرکت معتبر";
      case MOVE_STATE_IMPULSE_UP:       return "حرکت اصلی صعودی";
      case MOVE_STATE_IMPULSE_DOWN:     return "حرکت اصلی نزولی";
      case MOVE_STATE_CORRECTION_UP:    return "اصلاح صعودی";
      case MOVE_STATE_CORRECTION_DOWN:  return "اصلاح نزولی";
      case MOVE_STATE_TRANSITION:       return "در حال تغییر";
      case MOVE_STATE_INVALID:          return "نامعتبر";
      default:                          return "نامشخص";
     }
  }

//====================================================================
// مقداردهی اولیه
//====================================================================
void ImpulseCorrection_Reset(ImpulseCorrectionSnapshot &snapshot)
  {
   ZeroMemory(snapshot);
   snapshot.valid = false;
   snapshot.state = MOVE_STATE_UNKNOWN;
   snapshot.symbol = "";
   snapshot.timeframe = PERIOD_CURRENT;
   snapshot.analysis_time = 0;
   snapshot.reason = "";
   snapshot.correction_recovered = false;
   snapshot.correction_extreme_price = 0.0;
  }

//====================================================================
// میانگین True Range از کندل‌های بسته‌شده
//====================================================================
double ImpulseCorrection_CalculateATR(const MqlRates &rates[],
                                      const int total,
                                      const int period)
  {
   if(total < 3 || period < 1)
      return 0.0;

   int count = MathMin(period, total - 1);
   if(count < 1)
      return 0.0;

   double sum = 0.0;

   for(int shift = 1; shift <= count; shift++)
     {
      int prev_shift = shift + 1;
      if(prev_shift >= total)
         break;

      double high      = rates[shift].high;
      double low       = rates[shift].low;
      double prevClose = rates[prev_shift].close;

      double tr1 = high - low;
      double tr2 = MathAbs(high - prevClose);
      double tr3 = MathAbs(low  - prevClose);
      double tr  = MathMax(tr1, MathMax(tr2, tr3));

      if(tr > 0.0)
         sum += tr;
     }

   if(sum <= 0.0)
      return 0.0;

   return sum / count;
  }

//====================================================================
// یافتن شروع تقریبی حرکت اصلی از روی ساختار
//====================================================================
bool ImpulseCorrection_FindImpulse(const MqlRates &rates[],
                                   const int total,
                                   const MarketStructureSnapshot &structure,
                                   double &start_price,
                                   double &end_price,
                                   int &direction,
                                   int &bars_count,
                                   datetime &start_time,
                                   datetime &end_time)
  {
   start_price = 0.0;
   end_price   = 0.0;
   direction   = 0;
   bars_count  = 0;
   start_time  = 0;
   end_time    = 0;

   if(!MarketStructure_IsValid(structure))
     {
      Print("[IMPULSE DIAGNOSTIC] IMPULSE_FAIL | STRUCTURE_INVALID");
      return false;
     }

   if(total < 10)
     {
      Print("[IMPULSE DIAGNOSTIC] IMPULSE_FAIL | DATA_COUNT | Total=", total);
      return false;
     }

   bool low_available =
      structure.last_low.valid &&
      structure.last_low.price > 0.0 &&
      structure.last_low.time > 0 &&
      structure.last_low.shift > 0;

   bool high_available =
      structure.last_high.valid &&
      structure.last_high.price > 0.0 &&
      structure.last_high.time > 0 &&
      structure.last_high.shift > 0;

   if(!low_available || !high_available)
     {
      Print(
         "[IMPULSE DIAGNOSTIC] IMPULSE_FAIL | SWING_DATA | ",
         "LastLowValid=", low_available ? "YES" : "NO",
         " | LastHighValid=", high_available ? "YES" : "NO"
      );
      return false;
     }

   //==============================================================
   // صعودی: کف آخرین معتبر قبل از سقف آخرین معتبر
   //==============================================================
   if(structure.last_low.time < structure.last_high.time &&
      structure.last_low.price < structure.last_high.price)
     {
      start_price = structure.last_low.price;
      end_price   = structure.last_high.price;
      direction   = 1;

      int start_shift = structure.last_low.shift;
      int end_shift   = structure.last_high.shift;

      if(start_shift > 0 && end_shift > 0)
        {
         bars_count = MathAbs(start_shift - end_shift) + 1;
         start_time = structure.last_low.time;
         end_time   = structure.last_high.time;

         Print(
            "[IMPULSE DIAGNOSTIC] IMPULSE_WINDOW | BUY | ",
            "Sequence=", structure.bullish_sequence ? "YES" : "NO",
            " | Start=", DoubleToString(start_price, _Digits),
            " | End=", DoubleToString(end_price, _Digits),
            " | Bars=", bars_count
         );

         return true;
        }
     }

   //==============================================================
   // نزولی: سقف آخرین معتبر قبل از کف آخرین معتبر
   //==============================================================
   if(structure.last_high.time < structure.last_low.time &&
      structure.last_high.price > structure.last_low.price)
     {
      start_price = structure.last_high.price;
      end_price   = structure.last_low.price;
      direction   = -1;

      int start_shift = structure.last_high.shift;
      int end_shift   = structure.last_low.shift;

      if(start_shift > 0 && end_shift > 0)
        {
         bars_count = MathAbs(start_shift - end_shift) + 1;
         start_time = structure.last_high.time;
         end_time   = structure.last_low.time;

         Print(
            "[IMPULSE DIAGNOSTIC] IMPULSE_WINDOW | SELL | ",
            "Sequence=", structure.bearish_sequence ? "YES" : "NO",
            " | Start=", DoubleToString(start_price, _Digits),
            " | End=", DoubleToString(end_price, _Digits),
            " | Bars=", bars_count
         );

         return true;
        }
     }

   Print(
      "[IMPULSE DIAGNOSTIC] IMPULSE_FAIL | SWING_ORDER_PRICE | ",
      "LowTime=", TimeToString(structure.last_low.time, TIME_DATE | TIME_MINUTES),
      " | HighTime=", TimeToString(structure.last_high.time, TIME_DATE | TIME_MINUTES),
      " | LowPrice=", DoubleToString(structure.last_low.price, _Digits),
      " | HighPrice=", DoubleToString(structure.last_high.price, _Digits)
   );

   return false;
  }

//====================================================================
// محاسبه اندازه اصلاح فعلی نسبت به Impulse
// [اصلاح مهم] بررسی عمق واقعی اصلاح با اسکن تمام کندل‌های پس از Impulse
//====================================================================
bool ImpulseCorrection_FindCorrection(const MqlRates &rates[],
                                      const int total,
                                      const double impulse_start,
                                      const double impulse_end,
                                      const int impulse_direction,
                                      const datetime impulse_end_time,
                                      const double point,
                                      double &correction_start,
                                      double &correction_end,
                                      double &correction_size_points,
                                      double &correction_ratio,
                                      int &correction_direction,
                                      double &correction_extreme_price,
                                      bool &correction_recovered,
                                      datetime &correction_start_time,
                                      datetime &correction_end_time)
  {
   correction_start        = 0.0;
   correction_end          = 0.0;
   correction_size_points  = 0.0;
   correction_ratio        = 0.0;
   correction_direction    = 0;
   correction_extreme_price = 0.0;
   correction_recovered    = false;
   correction_start_time   = 0;
   correction_end_time     = 0;

   if(total < 4 || point <= 0.0 || impulse_direction == 0)
      return false;

   double impulse_size = MathAbs(impulse_end - impulse_start);
   if(impulse_size <= point)
      return false;

   correction_start = impulse_end;
   correction_start_time = impulse_end_time;

   //--- یافتن کندل شروع اصلاح (اولین کندل پس از پایان Impulse)
   int correction_start_shift = -1;
   for(int shift = 1; shift < total; shift++)
     {
      if(rates[shift].time <= impulse_end_time)
        {
         correction_start_shift = shift;
         break;
        }
     }

   if(correction_start_shift < 1)
     {
      // Impulse همین الان تمام شده یا هنوز تمام نشده
      return false;
     }

   //--- اسکن تمام کندل‌های پس از Impulse برای یافتن Extreme اصلاح
   double extreme_price = impulse_end;
   datetime extreme_time = impulse_end_time;

   for(int shift = 1; shift <= correction_start_shift; shift++)
     {
      if(impulse_direction > 0)
        {
         // Impulse صعودی: اصلاح یعنی کاهش قیمت
         if(rates[shift].low < extreme_price)
           {
            extreme_price = rates[shift].low;
            extreme_time = rates[shift].time;
           }
        }
      else
        {
         // Impulse نزولی: اصلاح یعنی افزایش قیمت
         if(rates[shift].high > extreme_price)
           {
            extreme_price = rates[shift].high;
            extreme_time = rates[shift].time;
           }
        }
     }

   //--- قیمت بسته‌شدن آخرین کندل
   double current_close = rates[1].close;
   datetime current_time = rates[1].time;

   correction_extreme_price = extreme_price;
   correction_end = current_close;
   correction_end_time = current_time;

   //--- محاسبه اندازه اصلاح بر اساس Extreme (نه فقط close)
   double correction_depth = MathAbs(impulse_end - extreme_price);
   correction_size_points = correction_depth / point;
   correction_ratio = (impulse_size > 0.0) ? (correction_depth / impulse_size) : 0.0;

   //--- جهت اصلاح
   if(impulse_direction > 0)
     {
      // اصلاح باید نزولی باشد (کاهش قیمت پس از صعود)
      if(extreme_price >= impulse_end - point)
        {
         // هنوز اصلاحی شروع نشده
         return false;
        }
      correction_direction = -1;
     }
   else
     {
      // اصلاح باید صعودی باشد (افزایش قیمت پس از نزول)
      if(extreme_price <= impulse_end + point)
        {
         // هنوز اصلاحی شروع نشده
         return false;
        }
      correction_direction = 1;
     }

   //--- [جدید] تشخیص Recovery: آیا اصلاح بیش از حد مجاز رفته و برگشته؟
   if(Inp_Max_Correction_Ratio > 0.0)
     {
      double extreme_ratio = correction_ratio;
      
      // بررسی وضعیت فعلی
      double current_correction_depth = MathAbs(impulse_end - current_close);
      double current_ratio = (impulse_size > 0.0) ? (current_correction_depth / impulse_size) : 0.0;
      
      // اگر در گذشته اصلاح بیش از حد رفته ولی الان برگشته
      if(extreme_ratio > Inp_Max_Correction_Ratio && 
         current_ratio <= Inp_Max_Correction_Ratio)
        {
         correction_recovered = true;
        }
     }

   return (correction_size_points > 0.0);
  }

//====================================================================
// تحلیل اصلی
//====================================================================
bool ImpulseCorrection_Analyze(const string symbol,
                               const ENUM_TIMEFRAMES timeframe,
                               const int bars_to_scan,
                               const int left_bars,
                               const int right_bars,
                               const double structure_tolerance_points,
                               ImpulseCorrectionSnapshot &snapshot)
  {
   ImpulseCorrection_Reset(snapshot);

   if(symbol == "" || timeframe == PERIOD_CURRENT)
     {
      snapshot.reason = "نماد یا تایم‌فریم معتبر نیست";
      return false;
     }

   if(!Inp_Use_Impulse_Correction)
     {
      snapshot.valid = true;
      snapshot.symbol = symbol;
      snapshot.timeframe = timeframe;
      snapshot.analysis_time = TimeCurrent();
      snapshot.state = MOVE_STATE_NONE;
      snapshot.reason = "تشخیص حرکت و اصلاح در تنظیمات غیرفعال است";
      return true;
     }

   if(bars_to_scan < 20 || left_bars < 1 || right_bars < 1)
     {
      snapshot.reason = "پارامترهای تحلیل برای حرکت و اصلاح کافی نیستند";
      return false;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(symbol, timeframe, 0, bars_to_scan, rates);
   if(copied < 20)
     {
      snapshot.reason = "داده کافی برای تحلیل حرکت و اصلاح دریافت نشد";
      return false;
     }

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
     {
      snapshot.reason = "Point نماد معتبر نیست";
      return false;
     }

   MarketStructureSnapshot structure;
   MarketStructure_Reset(structure);

   if(!MarketStructure_Analyze(symbol,
                               timeframe,
                               bars_to_scan,
                               left_bars,
                               right_bars,
                               structure_tolerance_points,
                               structure))
     {
      snapshot.reason = "ساختار معتبر برای تشخیص حرکت اصلی پیدا نشد";
      return false;
     }

   double start_price, end_price;
   int direction, bars_count;
   datetime start_time, end_time;

   if(!ImpulseCorrection_FindImpulse(rates,
                                     copied,
                                     structure,
                                     start_price,
                                     end_price,
                                     direction,
                                     bars_count,
                                     start_time,
                                     end_time))
     {
      snapshot.valid = true;
      snapshot.symbol = symbol;
      snapshot.timeframe = timeframe;
      snapshot.analysis_time = TimeCurrent();
      snapshot.state = MOVE_STATE_NONE;
      snapshot.impulse_valid = false;

      // PriceFirst fallback
      if(Inp_Use_Market_Truth)
        {
         MarketTruthSnapshot truth;
         if(MarketTruth_Analyze(symbol, timeframe, Inp_Market_Truth_Lookback, truth) &&
            truth.strong_market_move)
           {
            snapshot.impulse_valid = true;
            snapshot.impulse_direction = (truth.direction == MARKET_TRUTH_BUY ? 1 : -1);
            snapshot.impulse_start_price = truth.reference_price;
            snapshot.impulse_end_price = truth.current_price;
            snapshot.impulse_size_points = MathAbs(truth.current_price - truth.reference_price) / point;
            snapshot.impulse_bars = MathMin(bars_to_scan, 24);
            snapshot.impulse_atr = (truth.move_atr_multiple > 0.0 ?
               MathAbs(truth.current_price - truth.reference_price) / truth.move_atr_multiple : 0.0);
            snapshot.impulse_atr_multiple = truth.move_atr_multiple;
            snapshot.state = (snapshot.impulse_direction > 0 ? MOVE_STATE_IMPULSE_UP : MOVE_STATE_IMPULSE_DOWN);
            snapshot.reason = "MARKET_TRUTH_FALLBACK | " + truth.reason;
            Print("[IMPULSE MARKET TRUTH] ", snapshot.reason);
            return true;
           }
        }

      snapshot.reason =
         "IMPULSE_FAIL | STRUCTURE_PATTERN"
         + " | BullishSequence=" + (structure.bullish_sequence ? "YES" : "NO")
         + " | BearishSequence=" + (structure.bearish_sequence ? "YES" : "NO")
         + " | LastLowValid=" + (structure.last_low.valid ? "YES" : "NO")
         + " | LastHighValid=" + (structure.last_high.valid ? "YES" : "NO")
         + " | LowPrice=" + DoubleToString(structure.last_low.price, _Digits)
         + " | HighPrice=" + DoubleToString(structure.last_high.price, _Digits);

      Print("[IMPULSE DIAGNOSTIC] ", snapshot.reason);
      return true;
     }

   double impulse_size_points = MathAbs(end_price - start_price) / point;
   double atr = ImpulseCorrection_CalculateATR(rates, copied, Inp_ATR_Period);
   double atr_multiple = 0.0;
   if(atr > 0.0)
      atr_multiple = MathAbs(end_price - start_price) / atr;

   //--- [اصلاح] نرم کردن شرط‌ها: اگر Sequence کامل است، ATR کمتری قبول می‌شود
   double effective_min_atr = Inp_Min_Impulse_ATR_Multiple;
   bool has_full_sequence = (direction > 0 ? structure.bullish_sequence : structure.bearish_sequence);
   
   if(has_full_sequence && Inp_Min_Impulse_ATR_Multiple > 1.0)
     {
      // در صورت توالی کامل، 30% از آستانه ATR کم می‌شود
      effective_min_atr = Inp_Min_Impulse_ATR_Multiple * 0.70;
     }

   bool impulse_length_ok = (bars_count >= Inp_Min_Impulse_Bars &&
                             bars_count <= Inp_Max_Impulse_Bars);
   bool impulse_size_ok   = (atr > 0.0 && atr_multiple >= effective_min_atr);

   snapshot.valid = true;
   snapshot.symbol = symbol;
   snapshot.timeframe = timeframe;
   snapshot.analysis_time = TimeCurrent();
   snapshot.impulse_direction = direction;
   snapshot.impulse_start_price = start_price;
   snapshot.impulse_end_price = end_price;
   snapshot.impulse_size_points = impulse_size_points;
   snapshot.impulse_bars = bars_count;
   snapshot.impulse_atr = atr;
   snapshot.impulse_atr_multiple = atr_multiple;
   snapshot.impulse_start_time = start_time;
   snapshot.impulse_end_time = end_time;

   if(!impulse_length_ok || !impulse_size_ok)
     {
      snapshot.state = MOVE_STATE_NONE;
      snapshot.impulse_valid = false;

      snapshot.reason =
         "IMPULSE_FAIL | CRITERIA"
         + " | Direction=" + (direction > 0 ? "UP" : direction < 0 ? "DOWN" : "NONE")
         + " | Bars=" + IntegerToString(bars_count)
         + " | MinBars=" + IntegerToString(Inp_Min_Impulse_Bars)
         + " | MaxBars=" + IntegerToString(Inp_Max_Impulse_Bars)
         + " | ATRMultiple=" + DoubleToString(atr_multiple, 2)
         + " | MinATRMultiple=" + DoubleToString(effective_min_atr, 2)
         + " | Length=" + (impulse_length_ok ? "PASS" : "FAIL")
         + " | Size=" + (impulse_size_ok ? "PASS" : "FAIL")
         + " | FullSequence=" + (has_full_sequence ? "YES" : "NO");

      // Market Truth fallback
      if(Inp_Use_Market_Truth)
        {
         MarketTruthSnapshot truth;
         if(MarketTruth_Analyze(symbol, timeframe, Inp_Market_Truth_Lookback, truth) &&
            truth.strong_market_move)
           {
            snapshot.impulse_valid = true;
            snapshot.impulse_direction = (truth.direction == MARKET_TRUTH_BUY ? 1 : -1);
            snapshot.impulse_start_price = truth.reference_price;
            snapshot.impulse_end_price = truth.current_price;
            snapshot.impulse_size_points = MathAbs(truth.current_price - truth.reference_price) / point;
            snapshot.impulse_bars = MathMin(bars_to_scan, 24);
            snapshot.impulse_atr = (truth.move_atr_multiple > 0.0 ?
               MathAbs(truth.current_price - truth.reference_price) / truth.move_atr_multiple : atr);
            snapshot.impulse_atr_multiple = truth.move_atr_multiple;
            snapshot.state = (snapshot.impulse_direction > 0 ? MOVE_STATE_IMPULSE_UP : MOVE_STATE_IMPULSE_DOWN);
            snapshot.reason = "MARKET_TRUTH_FALLBACK | معیار Impulse رد شد اما حرکت واقعی بازار معتبر است | " + truth.reason;
            Print("[IMPULSE MARKET TRUTH] ", snapshot.reason);
            return true;
           }
        }

      Print("[IMPULSE DIAGNOSTIC] ", snapshot.reason);
      return true;
     }

   snapshot.impulse_valid = true;
   snapshot.state = (direction > 0 ? MOVE_STATE_IMPULSE_UP : MOVE_STATE_IMPULSE_DOWN);
   snapshot.reason =
      "IMPULSE_PASS"
      + " | Direction=" + (direction > 0 ? "UP" : "DOWN")
      + " | Bars=" + IntegerToString(bars_count)
      + " | ATRMultiple=" + DoubleToString(atr_multiple, 2)
      + " | SizePoints=" + DoubleToString(impulse_size_points, 1);

   Print("[IMPULSE DIAGNOSTIC] ", snapshot.reason);

   //--- بررسی اصلاح با روش بهبود یافته
   double correction_start, correction_end;
   double correction_size_points, correction_ratio;
   double correction_extreme_price;
   bool correction_recovered;
   int correction_direction;
   datetime correction_start_time, correction_end_time;

   if(ImpulseCorrection_FindCorrection(rates,
                                        copied,
                                        start_price,
                                        end_price,
                                        direction,
                                        end_time,
                                        point,
                                        correction_start,
                                        correction_end,
                                        correction_size_points,
                                        correction_ratio,
                                        correction_direction,
                                        correction_extreme_price,
                                        correction_recovered,
                                        correction_start_time,
                                        correction_end_time))
     {
      snapshot.correction_start_price = correction_start;
      snapshot.correction_end_price = correction_end;
      snapshot.correction_size_points = correction_size_points;
      snapshot.correction_ratio = correction_ratio;
      snapshot.correction_extreme_price = correction_extreme_price;
      snapshot.correction_recovered = correction_recovered;
      snapshot.correction_direction = correction_direction;
      snapshot.correction_start_time = correction_start_time;
      snapshot.correction_end_time = correction_end_time;

      if(correction_ratio > 0.0 && correction_ratio <= Inp_Max_Correction_Ratio)
        {
         snapshot.correction_valid = true;
         snapshot.state = (direction > 0 ? MOVE_STATE_CORRECTION_DOWN : MOVE_STATE_CORRECTION_UP);
         snapshot.reason = "Impulse معتبر است و اصلاح فعلی در محدوده مجاز قرار دارد" +
            " | Ratio=" + DoubleToString(correction_ratio, 3) +
            " | Extreme=" + DoubleToString(correction_extreme_price, _Digits);
        }
      else if(correction_recovered)
        {
         // [جدید] اصلاح قبلاً بیش از حد رفته ولی برگشته - معتبر تلقی می‌شود
         snapshot.correction_valid = true;
         snapshot.state = (direction > 0 ? MOVE_STATE_CORRECTION_DOWN : MOVE_STATE_CORRECTION_UP);
         snapshot.reason = "اصلاح قبلاً بیش از حد رفته ولی به محدوده مجاز برگشته | " +
            "MaxRatio=" + DoubleToString(correction_ratio, 3) +
            " | Recovered=YES";
        }
      else
        {
         snapshot.correction_valid = false;
         snapshot.state = (direction > 0 ? MOVE_STATE_IMPULSE_UP : MOVE_STATE_IMPULSE_DOWN);
         snapshot.reason = "حرکت اصلی معتبر است اما اصلاح فعلی بیش از محدوده مجاز است | " +
            "Ratio=" + DoubleToString(correction_ratio, 3) +
            " | Max=" + DoubleToString(Inp_Max_Correction_Ratio, 3);
        }
     }

   return true;
  }

//====================================================================
// بررسی اعتبار Snapshot
//====================================================================
bool ImpulseCorrection_IsValid(const ImpulseCorrectionSnapshot &snapshot)
  {
   if(!snapshot.valid)
      return false;

   if(snapshot.analysis_time <= 0)
      return false;

   if(snapshot.symbol == "" || snapshot.timeframe == PERIOD_CURRENT)
      return false;

   return true;
  }

#endif // __IMPULSE_CORRECTION_MQH__
//+------------------------------------------------------------------+