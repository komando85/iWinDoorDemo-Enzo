#ifndef __TFLAB_MARKET_TRUTH_ENGINE_MQH__
#define __TFLAB_MARKET_TRUTH_ENGINE_MQH__

//+------------------------------------------------------------------+
//|                  Market_Truth_Engine.mqh                         |
//|                    TFlab New EA V.5                                  |
//|                                                                  |
//| این ماژول فقط رفتار واقعی قیمت را می‌سنجد و هیچ امتیاز رباتی     |
//| را به عنوان حقیقت بازار استفاده نمی‌کند.                        |
//|                                                                  |
//| v2.1 - بهبود excursion با High/Low + اصلاح slope + لاگ بهتر    |
//+------------------------------------------------------------------+
#property strict

#include "EA_Inputs.mqh"

enum ENUM_MARKET_TRUTH_DIRECTION
  {
   MARKET_TRUTH_NONE = 0,
   MARKET_TRUTH_BUY  = 1,
   MARKET_TRUTH_SELL = -1
  };

enum ENUM_MARKET_TRUTH_PHASE
  {
   MARKET_TRUTH_PHASE_UNKNOWN = 0,
   MARKET_TRUTH_PHASE_EXPANSION,
   MARKET_TRUTH_PHASE_PULLBACK,
   MARKET_TRUTH_PHASE_COMPRESSION,
   MARKET_TRUTH_PHASE_REVERSAL
  };

struct MarketTruthSnapshot
  {
   bool                         valid;
   ENUM_MARKET_TRUTH_DIRECTION  direction;
   ENUM_MARKET_TRUTH_PHASE      phase;
   double                       current_price;
   double                       reference_price;
   double                       move_size;
   double                       move_atr_multiple;
   double                       slope;
   double                       range_high;
   double                       range_low;
   int                          bars_analyzed;
   int                          directional_bars;
   double                       directional_ratio;  // [جدید]
   bool                         expansion;
   bool                         pullback;
   bool                         continuation_ready;
   bool                         reversal_candidate;
   bool                         strong_market_move;
   string                       reason;
  };

void MarketTruth_Reset(MarketTruthSnapshot &s)
  {
   ZeroMemory(s);
   s.valid = false;
   s.direction = MARKET_TRUTH_NONE;
   s.phase = MARKET_TRUTH_PHASE_UNKNOWN;
   s.reason = "";
   s.directional_ratio = 0.0;
  }

string MarketTruth_DirectionToString(const ENUM_MARKET_TRUTH_DIRECTION d)
  {
   if(d == MARKET_TRUTH_BUY) return "BUY";
   if(d == MARKET_TRUTH_SELL) return "SELL";
   return "NONE";
  }

string MarketTruth_PhaseToString(const ENUM_MARKET_TRUTH_PHASE p)
  {
   switch(p)
     {
      case MARKET_TRUTH_PHASE_EXPANSION:   return "EXPANSION";
      case MARKET_TRUTH_PHASE_PULLBACK:    return "PULLBACK";
      case MARKET_TRUTH_PHASE_COMPRESSION: return "COMPRESSION";
      case MARKET_TRUTH_PHASE_REVERSAL:    return "REVERSAL";
      default:                             return "UNKNOWN";
     }
  }

//====================================================================
// ATR ساده و مستقل از handle
//====================================================================
double MarketTruth_ATR(const MqlRates &r[], const int count)
  {
   if(count < 3) return 0.0;
   int n = MathMin(count - 1, 14);
   double sum = 0.0;
   int used = 0;
   for(int i = 0; i < n; i++)
     {
      double prev_close = r[i + 1].close;
      double tr1 = r[i].high - r[i].low;
      double tr2 = MathAbs(r[i].high - prev_close);
      double tr3 = MathAbs(r[i].low - prev_close);
      double tr = MathMax(tr1, MathMax(tr2, tr3));
      if(tr > 0.0) { sum += tr; used++; }
     }
   return (used > 0 ? sum / used : 0.0);
  }

//====================================================================
// شیب خطی Close با محور زمانی ترتیبی
//====================================================================
double MarketTruth_RegressionSlope(const MqlRates &r[], const int count)
  {
   if(count < 3) return 0.0;
   int n = MathMin(count, 24);
   double sx = 0, sy = 0, sxy = 0, sxx = 0;
   for(int i = 0; i < n; i++)
     {
      double x = (double)(n - 1 - i);
      double y = r[i].close;
      sx += x; sy += y; sxy += x * y; sxx += x * x;
     }
   double den = n * sxx - sx * sx;
   if(MathAbs(den) < 1e-9) return 0.0;
   return (n * sxy - sx * sy) / den;
  }

//====================================================================
// تحلیل اصلی
// [اصلاح] بهبود excursion با High/Low + اصلاح slope + لاگ بهتر
//====================================================================
bool MarketTruth_Analyze(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   MarketTruthSnapshot &out)
  {
   MarketTruth_Reset(out);

   int requested = MathMax(24, MathMin(lookback, 96));
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int copied = CopyRates(symbol, timeframe, 1, requested, r);
   if(copied < 12)
     {
      out.reason = "داده کافی برای تحلیل مستقل قیمت وجود ندارد | Copied=" +
                   IntegerToString(copied) + " | Required=12";
      return false;
     }

   double atr = MarketTruth_ATR(r, copied);
   if(atr <= 0.0)
     {
      out.reason = "ATR مستقل بازار معتبر نیست";
      return false;
     }

   double current = r[0].close;
   //--- [اصلاح] استفاده از کندل دورتر برای مرجع اگر موجود باشد
   int ref_index = MathMin(copied - 1, 23);
   double ref = r[ref_index].close;
   double net = current - ref;
   double slope = MarketTruth_RegressionSlope(r, copied);

   double hi = r[0].high;
   double lo = r[0].low;
   int bull = 0, bear = 0;
   for(int i = 0; i < copied; i++)
     {
      hi = MathMax(hi, r[i].high);
      lo = MathMin(lo, r[i].low);
      if(r[i].close > r[i].open) bull++;
      else if(r[i].close < r[i].open) bear++;
     }

   //--- [اصلاح] directional_ratio: نسبت کندل‌های جهت‌دار
   double directional_ratio = 0.0;
   if(copied > 0)
     {
      directional_ratio = (double)MathMax(bull, bear) / (double)copied;
     }

   //=================================================================
   // [اصلاح] excursion با استفاده از High/Low برای حرکات واقعی
   // بهترین excursion صعودی: بالاترین high از current low
   // بهترین excursion نزولی: پایین‌ترین low از current high
   //=================================================================
   double best_up = 0.0;
   double best_down = 0.0;
   int best_up_i = 0, best_down_i = 0;

   for(int j = 4; j < MathMin(copied, 72); j++)
     {
      //--- [اصلاح] استفاده از High برای upward excursion
      double up_delta = r[j].high - r[0].low;
      if(up_delta > best_up)
        {
         best_up = up_delta;
         best_up_i = j;
        }

      //--- [اصلاح] استفاده از Low برای downward excursion
      double down_delta = r[0].high - r[j].low;
      if(down_delta > best_down)
        {
         best_down = down_delta;
         best_down_i = j;
        }
     }

   double best_move = MathMax(best_up, best_down);
   ENUM_MARKET_TRUTH_DIRECTION dir = MARKET_TRUTH_NONE;

   if(best_up > best_down * 1.10)
      dir = MARKET_TRUTH_BUY;
   else if(best_down > best_up * 1.10)
      dir = MARKET_TRUTH_SELL;
   else
     {
      //--- Fallback به net movement
      if(net > 0.0) dir = MARKET_TRUTH_BUY;
      else if(net < 0.0) dir = MARKET_TRUTH_SELL;
     }

   double recent_net = r[0].close - r[MathMin(copied - 1, 5)].close;
   double recent3 = r[0].close - r[MathMin(copied - 1, 3)].close;
   bool recent_up = (recent3 > 0.0);
   bool recent_down = (recent3 < 0.0);

   double excursion_atr = best_move / atr;
   double net_atr = MathAbs(net) / atr;

   //--- [اصلاح] slope باید با تعداد کندل‌ها ضرب شود تا معنای فیزیکی داشته باشد
   // slope بر حسب قیمت/کندل است، پس slope * 24 = تغییر قیمت در 24 کندل
   double slope_move = slope * MathMin(copied, 24);
   double slope_atr = MathAbs(slope_move) / atr;

   //=================================================================
   // [اصلاح] نرم‌تر کردن شرط strong_market_move
   //=================================================================
   double min_move_atr = Inp_Market_Truth_Min_Move_ATR;
   if(min_move_atr <= 0.0) min_move_atr = 1.50;

   out.strong_market_move =
      (excursion_atr >= min_move_atr) ||
      (net_atr >= min_move_atr) ||
      (slope_atr >= 0.50);  // [اصلاح] از 0.18 به 0.50

   out.expansion = (recent_net != 0.0 && MathAbs(recent_net) / atr >= 0.50);  // [اصلاح] از 0.60 به 0.50

   //--- pullback: جهت غالب از excursion می‌آید، ولی حرکت کوتاه‌مدت خلاف آن است
   out.pullback = false;
   if(dir == MARKET_TRUTH_BUY && recent_down) out.pullback = true;
   if(dir == MARKET_TRUTH_SELL && recent_up) out.pullback = true;

   //=================================================================
   // [اصلاح] نرم‌تر کردن continuation_ready
   //=================================================================
   out.continuation_ready =
      out.strong_market_move &&
      (out.expansion ||
       out.pullback ||
       MathAbs(net_atr) >= 0.60 ||      // [اصلاح] از 0.80 به 0.60
       directional_ratio >= 0.65);      // [جدید] یا اگر 65% کندل‌ها هم‌جهت باشند

   //--- reversal فقط زمانی مطرح است که حرکت کوتاه‌مدت خلاف excursion غالب،
   //--- خودش حداقل حدود 1 ATR باشد
   out.reversal_candidate = false;
   if(dir == MARKET_TRUTH_SELL && recent_net > 0.0 && MathAbs(recent_net) / atr >= 1.00)
      out.reversal_candidate = true;
   if(dir == MARKET_TRUTH_BUY && recent_net < 0.0 && MathAbs(recent_net) / atr >= 1.00)
      out.reversal_candidate = true;

   if(out.reversal_candidate)
      out.phase = MARKET_TRUTH_PHASE_REVERSAL;
   else if(out.pullback)
      out.phase = MARKET_TRUTH_PHASE_PULLBACK;
   else if(out.expansion)
      out.phase = MARKET_TRUTH_PHASE_EXPANSION;
   else if(MathAbs(net_atr) < 0.50)
      out.phase = MARKET_TRUTH_PHASE_COMPRESSION;
   else
      out.phase = MARKET_TRUTH_PHASE_EXPANSION;

   out.valid = true;
   out.direction = dir;
   out.current_price = current;
   out.reference_price = ref;
   out.move_size = best_move;
   out.move_atr_multiple = excursion_atr;
   out.slope = slope;
   out.range_high = hi;
   out.range_low = lo;
   out.bars_analyzed = copied;
   out.directional_bars = MathMax(bull, bear);
   out.directional_ratio = directional_ratio;

   //=================================================================
   // [اصلاح] لاگ تشخیصی کامل‌تر
   //=================================================================
   out.reason =
      "PriceFirst"
      " | Dir=" + MarketTruth_DirectionToString(dir) +
      " | Move=" + DoubleToString(best_move, _Digits) +
      " | MoveATR=" + DoubleToString(excursion_atr, 2) +
      " | NetATR=" + DoubleToString(net_atr, 2) +
      " | SlopeATR=" + DoubleToString(slope_atr, 2) +
      " | DirRatio=" + DoubleToString(directional_ratio * 100.0, 1) + "%" +
      " | Phase=" + MarketTruth_PhaseToString(out.phase) +
      " | Strong=" + (out.strong_market_move ? "YES" : "NO") +
      " | ContReady=" + (out.continuation_ready ? "YES" : "NO");

   //--- لاگ به Print
   Print(
      "[MARKET_TRUTH] Dir=", MarketTruth_DirectionToString(dir),
      " | MoveATR=", DoubleToString(excursion_atr, 2),
      " | NetATR=", DoubleToString(net_atr, 2),
      " | SlopeATR=", DoubleToString(slope_atr, 2),
      " | DirRatio=", DoubleToString(directional_ratio * 100.0, 1), "%",
      " | Phase=", MarketTruth_PhaseToString(out.phase),
      " | Strong=", (out.strong_market_move ? "YES" : "NO"),
      " | ContReady=", (out.continuation_ready ? "YES" : "NO")
   );

   return true;
  }

//====================================================================
// آیا Truth از جهت حمایت می‌کند؟
//====================================================================
bool MarketTruth_SupportsDirection(
   const MarketTruthSnapshot &truth,
   const bool buy)
  {
   if(!truth.valid) return false;
   if(buy)
      return truth.direction == MARKET_TRUTH_BUY && truth.continuation_ready;
   return truth.direction == MARKET_TRUTH_SELL && truth.continuation_ready;
  }

#endif // __TFLAB_MARKET_TRUTH_ENGINE_MQH__