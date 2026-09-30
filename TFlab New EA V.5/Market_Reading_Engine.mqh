#ifndef __TFLAB_MARKET_READING_ENGINE_MQH__
#define __TFLAB_MARKET_READING_ENGINE_MQH__

//+------------------------------------------------------------------+
//|                  Market_Reading_Engine.mqh                       |
//|                  TFlab New EA V.5                                    |
//|                                                                  |
//| مسئولیت: خوانش سه‌لایه بازار (گذشته + حال + آینده) و تولید      |
//|          Opportunity اولیه                                       |
//|                                                                  |
//| v2.1 - رفع باگ امتیازدهی + softening Opportunity + لاگ کامل    |
//+------------------------------------------------------------------+
#property strict

#include "EA_Inputs.mqh"
#include "Market_Truth_Engine.mqh"
#include "Market_Structure.mqh"

//====================================================================
// جهت خوانش بازار
//====================================================================
enum ENUM_MARKET_READING_DIRECTION
  {
   READING_DIRECTION_NONE = 0,
   READING_DIRECTION_BUY  = 1,
   READING_DIRECTION_SELL = -1
  };

//====================================================================
// موقعیت قیمت در دامنه
//====================================================================
enum ENUM_MARKET_LOCATION
  {
   MARKET_LOCATION_UNKNOWN = 0,
   MARKET_LOCATION_LOW,
   MARKET_LOCATION_MIDDLE,
   MARKET_LOCATION_HIGH
  };

//====================================================================
// سوگیری آینده
//====================================================================
enum ENUM_FUTURE_BIAS
  {
   FUTURE_BIAS_UNKNOWN = 0,
   FUTURE_BIAS_CONTINUATION,
   FUTURE_BIAS_REVERSAL,
   FUTURE_BIAS_RANGE
  };

//====================================================================
// Snapshot خوانش بازار
//====================================================================
struct MarketReadingSnapshot
  {
   bool valid;
   datetime time;
   double current_price;

   //--- گذشته
   ENUM_MARKET_READING_DIRECTION past_direction;
   double past_start_price;
   double past_end_price;
   double past_net_move;
   double past_range_high;
   double past_range_low;
   double past_slope;
   int past_bars;
   string past_state;

   //--- حال
   double candle_open;
   double candle_high;
   double candle_low;
   double candle_body;
   double candle_range;
   double candle_body_ratio;
   double current_from_open;
   ENUM_MARKET_LOCATION location;
   bool current_up_pressure;
   bool current_down_pressure;
   string now_state;

   //--- آینده
   ENUM_FUTURE_BIAS future_bias;
   double continuation_score;
   double reversal_score;
   double range_score;
   string future_state;

   bool opportunity_buy;
   bool opportunity_sell;
   string reason;
  };

//====================================================================
// مقداردهی اولیه
// [اصلاح] مقداردهی دستی فیلدهای رشته‌ای به جای ZeroMemory
//====================================================================
void MarketReading_Reset(MarketReadingSnapshot &r)
  {
   r.valid              = false;
   r.time               = 0;
   r.current_price      = 0.0;

   r.past_direction     = READING_DIRECTION_NONE;
   r.past_start_price   = 0.0;
   r.past_end_price     = 0.0;
   r.past_net_move      = 0.0;
   r.past_range_high    = 0.0;
   r.past_range_low     = 0.0;
   r.past_slope         = 0.0;
   r.past_bars          = 0;
   r.past_state         = "";

   r.candle_open        = 0.0;
   r.candle_high        = 0.0;
   r.candle_low         = 0.0;
   r.candle_body        = 0.0;
   r.candle_range       = 0.0;
   r.candle_body_ratio  = 0.0;
   r.current_from_open  = 0.0;
   r.location           = MARKET_LOCATION_UNKNOWN;
   r.current_up_pressure   = false;
   r.current_down_pressure = false;
   r.now_state          = "";

   r.future_bias        = FUTURE_BIAS_UNKNOWN;
   r.continuation_score = 0.0;
   r.reversal_score     = 0.0;
   r.range_score        = 0.0;
   r.future_state       = "";

   r.opportunity_buy    = false;
   r.opportunity_sell   = false;
   r.reason             = "";
  }

//====================================================================
// توابع کمکی تبدیل
//====================================================================
string MarketReading_DirectionToPersian(const ENUM_MARKET_READING_DIRECTION d)
  {
   if(d == READING_DIRECTION_BUY) return "خرید";
   if(d == READING_DIRECTION_SELL) return "فروش";
   return "خنثی";
  }

string MarketReading_DirectionToCode(const ENUM_MARKET_READING_DIRECTION d)
  {
   if(d == READING_DIRECTION_BUY) return "BUY";
   if(d == READING_DIRECTION_SELL) return "SELL";
   return "NONE";
  }

string MarketReading_LocationToPersian(const ENUM_MARKET_LOCATION p)
  {
   if(p == MARKET_LOCATION_LOW) return "نزدیک کف";
   if(p == MARKET_LOCATION_HIGH) return "نزدیک سقف";
   if(p == MARKET_LOCATION_MIDDLE) return "میانه بازار";
   return "نامشخص";
  }

string MarketReading_LocationToCode(const ENUM_MARKET_LOCATION p)
  {
   if(p == MARKET_LOCATION_LOW) return "LOW";
   if(p == MARKET_LOCATION_HIGH) return "HIGH";
   if(p == MARKET_LOCATION_MIDDLE) return "MID";
   return "UNKNOWN";
  }

string MarketReading_FutureToPersian(const ENUM_FUTURE_BIAS b)
  {
   if(b == FUTURE_BIAS_CONTINUATION) return "احتمال ادامه حرکت";
   if(b == FUTURE_BIAS_REVERSAL) return "احتمال برگشت";
   if(b == FUTURE_BIAS_RANGE) return "احتمال رنج";
   return "نامشخص";
  }

string MarketReading_FutureToCode(const ENUM_FUTURE_BIAS b)
  {
   if(b == FUTURE_BIAS_CONTINUATION) return "CONT";
   if(b == FUTURE_BIAS_REVERSAL) return "REV";
   if(b == FUTURE_BIAS_RANGE) return "RANGE";
   return "UNKNOWN";
  }

//====================================================================
// تحلیل خوانش بازار
// [اصلاح] رفع باگ امتیازدهی + softening Opportunity + لاگ کامل
//====================================================================
bool MarketReading_Analyze(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const MarketTruthSnapshot &truth,
   const MarketStructureSnapshot &structure,
   MarketReadingSnapshot &out)
  {
   MarketReading_Reset(out);

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(symbol, timeframe, 1, MathMax(12, MathMin(Inp_Market_Truth_Lookback, 72)), r);

   if(n < 8)
     {
      out.reason = "داده کافی برای خوانش بازار وجود ندارد | Copied=" + IntegerToString(n);
      return false;
     }

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double current = (bid > 0.0 && ask > 0.0) ? (bid + ask) / 2.0 : r[0].close;

   double hi = r[0].high, lo = r[0].low;
   for(int i = 0; i < n; i++)
     {
      hi = MathMax(hi, r[i].high);
      lo = MathMin(lo, r[i].low);
     }

   //=================================================================
   // گذشته
   //=================================================================
   out.valid = true;
   out.time = TimeCurrent();
   out.current_price = current;
   out.past_start_price = r[n - 1].open;
   out.past_end_price = r[0].close;
   out.past_net_move = out.past_end_price - out.past_start_price;
   out.past_range_high = hi;
   out.past_range_low = lo;
   out.past_bars = n;
   out.past_slope = truth.slope;
   out.past_direction = (out.past_net_move > 0.0 ? READING_DIRECTION_BUY :
                         (out.past_net_move < 0.0 ? READING_DIRECTION_SELL : READING_DIRECTION_NONE));

   if(truth.valid)
      out.past_direction = (truth.direction == MARKET_TRUTH_BUY ? READING_DIRECTION_BUY :
                            (truth.direction == MARKET_TRUTH_SELL ? READING_DIRECTION_SELL : out.past_direction));

   out.past_state = "حرکت گذشته: " + MarketReading_DirectionToPersian(out.past_direction) +
                    " | شروع=" + DoubleToString(out.past_start_price, _Digits) +
                    " | پایان=" + DoubleToString(out.past_end_price, _Digits) +
                    " | دامنه=" + DoubleToString(hi - lo, _Digits);

   //=================================================================
   // حال
   //=================================================================
   double o = iOpen(symbol, timeframe, 0);
   double h = iHigh(symbol, timeframe, 0);
   double l = iLow(symbol, timeframe, 0);

   if(o <= 0.0) o = r[0].close;
   if(h <= 0.0) h = MathMax(o, current);
   if(l <= 0.0) l = MathMin(o, current);

   out.candle_open = o;
   out.candle_high = MathMax(h, current);
   out.candle_low = MathMin(l, current);
   out.candle_range = MathMax(out.candle_high - out.candle_low, _Point);
   out.candle_body = MathAbs(current - o);
   out.candle_body_ratio = out.candle_body / out.candle_range;
   out.current_from_open = current - o;
   out.current_up_pressure = (current > o);
   out.current_down_pressure = (current < o);

   double pos = (current - lo) / MathMax(hi - lo, _Point);
   if(pos <= 0.25) out.location = MARKET_LOCATION_LOW;
   else if(pos >= 0.75) out.location = MARKET_LOCATION_HIGH;
   else out.location = MARKET_LOCATION_MIDDLE;

   out.now_state = "حال: " + (out.current_up_pressure ? "فشار صعودی" :
                               (out.current_down_pressure ? "فشار نزولی" : "بدون فشار مشخص")) +
                   " | " + MarketReading_LocationToPersian(out.location) +
                   " | قیمت=" + DoubleToString(current, _Digits) +
                   " | شروع کندل=" + DoubleToString(o, _Digits);

   //=================================================================
   // آینده - امتیازدهی
   // [اصلاح] امتیازدهی بر اساس جهت ساختار
   //=================================================================
   double cont = 0.0, rev = 0.0, range = 0.0;

   if(truth.valid)
     {
      if(truth.continuation_ready) cont += 45.0;
      if(truth.expansion) cont += 25.0;
      if(truth.strong_market_move) cont += 20.0;
      if(truth.reversal_candidate) rev += 60.0;
     }

   //=================================================================
   // [اصلاح حیاتی] امتیاز ساختار باید جهت‌دار باشد
   //=================================================================
   if(structure.valid)
     {
      //--- اگر ساختار BULLISH است، فقط به continuation BUY کمک می‌کند
      if(structure.state == STRUCTURE_STATE_BULLISH || structure.bullish_sequence)
        {
         if(out.past_direction == READING_DIRECTION_BUY)
            cont += 10.0;
         else if(out.past_direction == READING_DIRECTION_SELL)
            rev += 10.0;  // ساختار صعودی ولی قیمت نزولی = احتمال برگشت
        }

      //--- اگر ساختار BEARISH است، فقط به continuation SELL کمک می‌کند
      if(structure.state == STRUCTURE_STATE_BEARISH || structure.bearish_sequence)
        {
         if(out.past_direction == READING_DIRECTION_SELL)
            cont += 10.0;
         else if(out.past_direction == READING_DIRECTION_BUY)
            rev += 10.0;  // ساختار نزولی ولی قیمت صعودی = احتمال برگشت
        }
     }

   //--- رنج
   if(MathAbs(out.past_net_move) <= MathMax((hi - lo) * 0.15, _Point * 20.0))
      range += 45.0;

   if(out.location == MARKET_LOCATION_MIDDLE && !out.current_up_pressure && !out.current_down_pressure)
      range += 25.0;

   if(truth.valid && truth.phase == MARKET_TRUTH_PHASE_COMPRESSION)
      range += 30.0;

   //--- تأیید ادامه با فشار فعلی
   if(out.past_direction == READING_DIRECTION_BUY && out.current_up_pressure)
      cont += 15.0;

   if(out.past_direction == READING_DIRECTION_SELL && out.current_down_pressure)
      cont += 15.0;

   //--- سیگنال برگشت با فشار مخالف
   if(out.past_direction == READING_DIRECTION_SELL && out.current_up_pressure)
      rev += 20.0;

   if(out.past_direction == READING_DIRECTION_BUY && out.current_down_pressure)
      rev += 20.0;

   out.continuation_score = MathMin(100.0, cont);
   out.reversal_score = MathMin(100.0, rev);
   out.range_score = MathMin(100.0, range);

   //=================================================================
   // تعیین future_bias
   //=================================================================
   if(out.reversal_score >= out.continuation_score &&
      out.reversal_score >= out.range_score &&
      out.reversal_score >= 55.0)
      out.future_bias = FUTURE_BIAS_REVERSAL;
   else if(out.continuation_score >= out.range_score && out.continuation_score >= 50.0)
      out.future_bias = FUTURE_BIAS_CONTINUATION;
   else
      out.future_bias = FUTURE_BIAS_RANGE;

   out.future_state = "آینده مشروط: " + MarketReading_FutureToPersian(out.future_bias) +
                      " | ادامه=" + DoubleToString(out.continuation_score, 1) +
                      " | برگشت=" + DoubleToString(out.reversal_score, 1) +
                      " | رنج=" + DoubleToString(out.range_score, 1);

   //=================================================================
   // تشخیص Opportunity
   // [اصلاح] softening شرط‌ها + تشخیص reversal opportunity
   //=================================================================
   out.opportunity_buy = false;
   out.opportunity_sell = false;

   //--- Continuation Opportunity
   bool strong_continuation = (truth.valid && truth.strong_market_move);
   bool moderate_continuation = (truth.valid && truth.continuation_ready);

   if(strong_continuation && truth.direction == MARKET_TRUTH_BUY)
     {
      if(out.past_direction == READING_DIRECTION_BUY ||
         (structure.valid && structure.state == STRUCTURE_STATE_BULLISH))
         out.opportunity_buy = true;
     }

   if(strong_continuation && truth.direction == MARKET_TRUTH_SELL)
     {
      if(out.past_direction == READING_DIRECTION_SELL ||
         (structure.valid && structure.state == STRUCTURE_STATE_BEARISH))
         out.opportunity_sell = true;
     }

   //--- [جدید] Reversal Opportunity
   if(truth.valid && truth.reversal_candidate)
     {
      //--- اگر reversal BUY تشخیص داده شده
      if(truth.direction == MARKET_TRUTH_SELL && out.past_direction == READING_DIRECTION_SELL)
        {
         // گذشته نزولی + reversal = فرصت خرید
         if(out.current_up_pressure)
            out.opportunity_buy = true;
        }

      //--- اگر reversal SELL تشخیص داده شده
      if(truth.direction == MARKET_TRUTH_BUY && out.past_direction == READING_DIRECTION_BUY)
        {
         // گذشته صعودی + reversal = فرصت فروش
         if(out.current_down_pressure)
            out.opportunity_sell = true;
        }
     }

   //--- Transition Opportunity (fallback)
   if(!out.opportunity_buy && truth.valid && truth.direction == MARKET_TRUTH_BUY &&
      strong_continuation && out.current_up_pressure)
      out.opportunity_buy = true;

   if(!out.opportunity_sell && truth.valid && truth.direction == MARKET_TRUTH_SELL &&
      strong_continuation && out.current_down_pressure)
      out.opportunity_sell = true;

   //--- Moderate Continuation (softening)
   if(!out.opportunity_buy && moderate_continuation && truth.direction == MARKET_TRUTH_BUY &&
      out.current_up_pressure && out.location == MARKET_LOCATION_LOW)
      out.opportunity_buy = true;

   if(!out.opportunity_sell && moderate_continuation && truth.direction == MARKET_TRUTH_SELL &&
      out.current_down_pressure && out.location == MARKET_LOCATION_HIGH)
      out.opportunity_sell = true;

   out.reason = out.past_state + " | " + out.now_state + " | " + out.future_state;

   //=================================================================
   // [جدید] لاگ تشخیصی کامل
   //=================================================================
   Print(
      "[MARKET_READING] PastDir=", MarketReading_DirectionToCode(out.past_direction),
      " | Location=", MarketReading_LocationToCode(out.location),
      " | FutureBias=", MarketReading_FutureToCode(out.future_bias),
      " | Cont=", DoubleToString(out.continuation_score, 1),
      " | Rev=", DoubleToString(out.reversal_score, 1),
      " | Range=", DoubleToString(out.range_score, 1),
      " | OppBUY=", (out.opportunity_buy ? "YES" : "NO"),
      " | OppSELL=", (out.opportunity_sell ? "YES" : "NO")
   );

   if(out.opportunity_buy || out.opportunity_sell)
     {
      Print(
         "[MARKET_READING] OPPORTUNITY DETECTED",
         " | Direction=", (out.opportunity_buy ? "BUY" : "SELL"),
         " | TruthDir=", (truth.valid ? MarketTruth_DirectionToString(truth.direction) : "NONE"),
         " | Structure=", (structure.valid ? MarketStructure_StateToCode(structure.state) : "NONE"),
         " | FutureBias=", MarketReading_FutureToCode(out.future_bias)
      );
     }

   return true;
  }

#endif // __TFLAB_MARKET_READING_ENGINE_MQH__