#ifndef __TFLAB_MARKET_REGIME_MQH__
#define __TFLAB_MARKET_REGIME_MQH__

//+------------------------------------------------------------------+
//|                    Market_Regime.mqh                             |
//|                    TFlab New EA V.5                                  |
//|                                                                  |
//| مسئولیت: تشخیص وضعیت کلی بازار                                  |
//| منطق: ADX (قدرت روند) + EMA (جهت) + RSI (اشباع) + ATR (نوسان)    |
//| هیچ منطق ورود، خروج، ریسک یا اجرای سفارش در این فایل نیست.       |
//+------------------------------------------------------------------+
#property strict

//--- وضعیت کلی بازار
enum ENUM_MARKET_REGIME
  {
   MARKET_REGIME_UNKNOWN = 0,
   MARKET_REGIME_UPTREND,
   MARKET_REGIME_DOWNTREND,
   MARKET_REGIME_RANGE,
   MARKET_REGIME_TRANSITION,
   MARKET_REGIME_UNCERTAIN
  };

//--- اطلاعات وضعیت بازار
struct MarketRegimeState
  {
   ENUM_MARKET_REGIME regime;
   double             confidence;
   datetime           analysis_time;
   string             reason;
   bool               valid;
   
   //--- داده‌های تشخیصی برای دیباگ
   double             adx_value;
   double             di_plus;
   double             di_minus;
   double             rsi_value;
   double             ema_value;
   double             current_price;
   double             price_ema_distance_atr;
   double             atr_value;
  };

//+------------------------------------------------------------------+
//| تبدیل وضعیت بازار به متن فارسی                                   |
//+------------------------------------------------------------------+
string MarketRegime_ToPersian(const ENUM_MARKET_REGIME regime)
  {
   switch(regime)
     {
      case MARKET_REGIME_UPTREND:
         return "روند صعودی";
      case MARKET_REGIME_DOWNTREND:
         return "روند نزولی";
      case MARKET_REGIME_RANGE:
         return "رنج";
      case MARKET_REGIME_TRANSITION:
         return "در حال تغییر";
      case MARKET_REGIME_UNCERTAIN:
         return "نامطمئن";
      default:
         return "نامشخص";
     }
  }

//+------------------------------------------------------------------+
//| مقداردهی اولیه وضعیت بازار                                       |
//+------------------------------------------------------------------+
void MarketRegime_Reset(MarketRegimeState &state)
  {
   state.regime        = MARKET_REGIME_UNKNOWN;
   state.confidence    = 0.0;
   state.analysis_time = 0;
   state.reason        = "";
   state.valid         = false;
   
   state.adx_value     = 0.0;
   state.di_plus       = 0.0;
   state.di_minus      = 0.0;
   state.rsi_value     = 0.0;
   state.ema_value     = 0.0;
   state.current_price = 0.0;
   state.price_ema_distance_atr = 0.0;
   state.atr_value     = 0.0;
  }

//+------------------------------------------------------------------+
//| مقداردهی اولیه موتور                                              |
//+------------------------------------------------------------------+
void MarketRegime_Init(MarketRegimeState &state)
  {
   MarketRegime_Reset(state);
  }

//+------------------------------------------------------------------+
//| بررسی معتبر بودن تایم‌فریم                                        |
//+------------------------------------------------------------------+
bool MarketRegime_IsTimeframeValid(const ENUM_TIMEFRAMES timeframe)
  {
   if(timeframe == PERIOD_CURRENT)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//| محاسبه اندیکاتورها                                                |
//+------------------------------------------------------------------+
bool MarketRegime_CalculateIndicators(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int adx_period,
   const int rsi_period,
   const int ema_period,
   const int atr_period,
   MarketRegimeState &state)
  {
   //--- ADX
   int adx_handle = iADX(symbol, timeframe, adx_period);
   if(adx_handle == INVALID_HANDLE)
     {
      state.reason = "خطا در ایجاد هندل ADX";
      return false;
     }

   double adx_buffer[3], di_plus_buffer[3], di_minus_buffer[3];
   if(CopyBuffer(adx_handle, 0, 0, 3, adx_buffer) < 3 ||
      CopyBuffer(adx_handle, 1, 0, 3, di_plus_buffer) < 3 ||
      CopyBuffer(adx_handle, 2, 0, 3, di_minus_buffer) < 3)
     {
      IndicatorRelease(adx_handle);
      state.reason = "خطا در خواندن مقادیر ADX";
      return false;
     }
   IndicatorRelease(adx_handle);

   state.adx_value = adx_buffer[0];
   state.di_plus   = di_plus_buffer[0];
   state.di_minus  = di_minus_buffer[0];

   //--- RSI
   int rsi_handle = iRSI(symbol, timeframe, rsi_period, PRICE_CLOSE);
   if(rsi_handle == INVALID_HANDLE)
     {
      state.reason = "خطا در ایجاد هندل RSI";
      return false;
     }

   double rsi_buffer[3];
   if(CopyBuffer(rsi_handle, 0, 0, 3, rsi_buffer) < 3)
     {
      IndicatorRelease(rsi_handle);
      state.reason = "خطا در خواندن مقادیر RSI";
      return false;
     }
   IndicatorRelease(rsi_handle);
   state.rsi_value = rsi_buffer[0];

   //--- EMA
   int ema_handle = iMA(symbol, timeframe, ema_period, 0, MODE_EMA, PRICE_CLOSE);
   if(ema_handle == INVALID_HANDLE)
     {
      state.reason = "خطا در ایجاد هندل EMA";
      return false;
     }

   double ema_buffer[3];
   if(CopyBuffer(ema_handle, 0, 0, 3, ema_buffer) < 3)
     {
      IndicatorRelease(ema_handle);
      state.reason = "خطا در خواندن مقادیر EMA";
      return false;
     }
   IndicatorRelease(ema_handle);
   state.ema_value = ema_buffer[0];

   //--- ATR
   int atr_handle = iATR(symbol, timeframe, atr_period);
   if(atr_handle == INVALID_HANDLE)
     {
      state.reason = "خطا در ایجاد هندل ATR";
      return false;
     }

   double atr_buffer[3];
   if(CopyBuffer(atr_handle, 0, 0, 3, atr_buffer) < 3)
     {
      IndicatorRelease(atr_handle);
      state.reason = "خطا در خواندن مقادیر ATR";
      return false;
     }
   IndicatorRelease(atr_handle);
   state.atr_value = atr_buffer[0];

   //--- قیمت جاری
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
     {
      state.reason = "خطا در دریافت قیمت";
      return false;
     }
   state.current_price = (tick.bid + tick.ask) * 0.5;

   //--- فاصله قیمت از EMA بر حسب ATR
   if(state.atr_value > 0.0)
      state.price_ema_distance_atr = (state.current_price - state.ema_value) / state.atr_value;
   else
      state.price_ema_distance_atr = 0.0;

   return true;
  }

//+------------------------------------------------------------------+
//| تحلیل وضعیت کلی بازار                                             |
//|                                                                  |
//| منطق:                                                             |
//| - UPTREND:   Price > EMA + ADX بالا + DI+ > DI-                   |
//| - DOWNTREND: Price < EMA + ADX بالا + DI- > DI+                   |
//| - RANGE:     ADX پایین + Price نزدیک EMA                          |
//| - TRANSITION: تغییر جهت EMA یا DI                                 |
//| - UNCERTAIN: سیگنال‌های متناقض یا داده ناکافی                     |
//+------------------------------------------------------------------+
bool MarketRegime_Analyze(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int adx_period,
   const int rsi_period,
   const int ema_period,
   const int atr_period,
   const double adx_min_trend,
   const double adx_exhaustion_level,
   const double rsi_overbought,
   const double rsi_oversold,
   const double max_price_ema_atr_distance,
   MarketRegimeState &state)
  {
   MarketRegime_Reset(state);

   if(symbol == "")
     {
      state.reason = "نماد معاملاتی مشخص نشده است";
      state.analysis_time = TimeCurrent();
      return false;
     }

   if(!MarketRegime_IsTimeframeValid(timeframe))
     {
      state.reason = "تایم‌فریم معتبر نیست";
      state.analysis_time = TimeCurrent();
      return false;
     }

   //--- محاسبه اندیکاتورها
   if(!MarketRegime_CalculateIndicators(
         symbol, timeframe,
         adx_period, rsi_period, ema_period, atr_period,
         state))
     {
      state.analysis_time = TimeCurrent();
      return false;
     }

   //--- آستانه‌های پیش‌فرض در صورت صفر بودن ورودی
   double min_trend_adx = (adx_min_trend > 0.0 ? adx_min_trend : 20.0);
   double exhaustion_adx = (adx_exhaustion_level > 0.0 ? adx_exhaustion_level : 40.0);
   double rsi_ob = (rsi_overbought > 0.0 ? rsi_overbought : 70.0);
   double rsi_os = (rsi_oversold > 0.0 ? rsi_oversold : 30.0);
   double max_distance = (max_price_ema_atr_distance > 0.0 ? max_price_ema_atr_distance : 3.0);

   //--- متغیرهای تشخیصی
   bool price_above_ema = (state.current_price > state.ema_value);
   bool price_below_ema = (state.current_price < state.ema_value);
   bool strong_adx = (state.adx_value >= min_trend_adx);
   bool weak_adx = (state.adx_value < min_trend_adx);
   bool exhausted_adx = (state.adx_value >= exhaustion_adx);
   bool di_plus_dominant = (state.di_plus > state.di_minus);
   bool di_minus_dominant = (state.di_minus > state.di_plus);
   bool rsi_overbought_zone = (state.rsi_value >= rsi_ob);
   bool rsi_oversold_zone = (state.rsi_value <= rsi_os);
   bool rsi_neutral = (!rsi_overbought_zone && !rsi_oversold_zone);
   bool price_near_ema = (MathAbs(state.price_ema_distance_atr) < 0.5);
   bool price_extended = (MathAbs(state.price_ema_distance_atr) > max_distance);

   //--- محاسبه Confidence و Regime
   double confidence = 0.0;
   ENUM_MARKET_REGIME regime = MARKET_REGIME_UNCERTAIN;
   string reason_parts = "";

   //=============================================================
   // 1. UPTREND: روند صعودی قوی
   //=============================================================
   if(price_above_ema && strong_adx && di_plus_dominant)
     {
      regime = MARKET_REGIME_UPTREND;
      confidence = 50.0;

      //--- تقویت با قدرت ADX
      if(state.adx_value >= 30.0) confidence += 15.0;
      if(state.adx_value >= 40.0) confidence += 10.0;

      //--- تقویت با DI+ قوی‌تر
      if(state.di_plus > state.di_minus + 5.0) confidence += 10.0;

      //--- تقویت با فاصله مناسب از EMA
      if(!price_extended && !price_near_ema) confidence += 10.0;

      //--- تقویت با RSI خنثی
      if(rsi_neutral) confidence += 5.0;

      //--- جریمه برای اشباع خرید
      if(rsi_overbought_zone)
        {
         confidence -= 15.0;
         reason_parts += " [هشدار RSI اشباع]";
         
         // اگر اشباع شدید باشد، رژیم را به TRANSITION تغییر می‌دهیم
         if(state.rsi_value >= 80.0 && exhausted_adx)
           {
            regime = MARKET_REGIME_TRANSITION;
            reason_parts += " [احتمال برگشت]";
           }
        }

      reason_parts = "روند صعودی | ADX=" + DoubleToString(state.adx_value,1) +
                     " | DI+=" + DoubleToString(state.di_plus,1) +
                     " | DI-=" + DoubleToString(state.di_minus,1) +
                     " | RSI=" + DoubleToString(state.rsi_value,1) +
                     " | Price>EMA" + reason_parts;
     }

   //=============================================================
   // 2. DOWNTREND: روند نزولی قوی
   //=============================================================
   else if(price_below_ema && strong_adx && di_minus_dominant)
     {
      regime = MARKET_REGIME_DOWNTREND;
      confidence = 50.0;

      if(state.adx_value >= 30.0) confidence += 15.0;
      if(state.adx_value >= 40.0) confidence += 10.0;
      if(state.di_minus > state.di_plus + 5.0) confidence += 10.0;
      if(!price_extended && !price_near_ema) confidence += 10.0;
      if(rsi_neutral) confidence += 5.0;

      if(rsi_oversold_zone)
        {
         confidence -= 15.0;
         reason_parts += " [هشدار RSI اشباع]";
         
         if(state.rsi_value <= 20.0 && exhausted_adx)
           {
            regime = MARKET_REGIME_TRANSITION;
            reason_parts += " [احتمال برگشت]";
           }
        }

      reason_parts = "روند نزولی | ADX=" + DoubleToString(state.adx_value,1) +
                     " | DI-=" + DoubleToString(state.di_minus,1) +
                     " | DI+=" + DoubleToString(state.di_plus,1) +
                     " | RSI=" + DoubleToString(state.rsi_value,1) +
                     " | Price<EMA" + reason_parts;
     }

   //=============================================================
   // 3. RANGE: بازار رنج
   //=============================================================
   else if(weak_adx && price_near_ema)
     {
      regime = MARKET_REGIME_RANGE;
      confidence = 40.0;

      if(state.adx_value < 15.0) confidence += 15.0;
      if(MathAbs(state.price_ema_distance_atr) < 0.3) confidence += 10.0;

      reason_parts = "بازار رنج | ADX ضعیف=" + DoubleToString(state.adx_value,1) +
                     " | Price نزدیک EMA | DI+=" + DoubleToString(state.di_plus,1) +
                     " | DI-=" + DoubleToString(state.di_minus,1);
     }

   //=============================================================
   // 4. TRANSITION: در حال تغییر روند
   //=============================================================
   else if((price_above_ema && di_minus_dominant) ||
           (price_below_ema && di_plus_dominant) ||
           (exhausted_adx && (rsi_overbought_zone || rsi_oversold_zone)))
     {
      regime = MARKET_REGIME_TRANSITION;
      confidence = 30.0;

      if(price_above_ema && di_minus_dominant)
        {
         confidence += 10.0;
         reason_parts = "تغییر احتمالی به نزولی | Price>EMA اما DI->DI+";
        }
      else if(price_below_ema && di_plus_dominant)
        {
         confidence += 10.0;
         reason_parts = "تغییر احتمالی به صعودی | Price<EMA اما DI+>DI-";
        }
      else
        {
         reason_parts = "احتمال خستگی روند | ADX بالا + RSI اشباع";
        }

      reason_parts += " | ADX=" + DoubleToString(state.adx_value,1) +
                      " | RSI=" + DoubleToString(state.rsi_value,1);
     }

   //=============================================================
   // 5. UNCERTAIN: عدم قطعیت
   //=============================================================
   else
     {
      regime = MARKET_REGIME_UNCERTAIN;
      confidence = 15.0;
      reason_parts = "سیگنال‌های متناقض یا ضعیف | ADX=" + DoubleToString(state.adx_value,1) +
                     " | RSI=" + DoubleToString(state.rsi_value,1) +
                     " | Price-EMA=" + DoubleToString(state.price_ema_distance_atr,2) + " ATR";
     }

   //--- محدود کردن Confidence بین 0 تا 100
   confidence = MathMin(100.0, MathMax(0.0, confidence));

   //--- ذخیره نتیجه
   state.regime = regime;
   state.confidence = confidence;
   state.reason = reason_parts;
   state.analysis_time = TimeCurrent();
   state.valid = true;

   //--- لاگ تشخیصی
   Print(
      "[MARKET_REGIME] ",
      MarketRegime_ToCode(regime),
      " | Confidence=", DoubleToString(confidence, 1),
      " | ", reason_parts
   );

   return true;
  }

//+------------------------------------------------------------------+
//| Overload ساده برای سازگاری با فراخوانی‌های قدیمی                  |
//+------------------------------------------------------------------+
bool MarketRegime_Analyze(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   MarketRegimeState &state)
  {
   // مقادیر پیش‌فرض برای سازگاری عقب‌رو
   return MarketRegime_Analyze(
      symbol, timeframe,
      14,    // adx_period
      14,    // rsi_period
      50,    // ema_period
      14,    // atr_period
      20.0,  // adx_min_trend
      40.0,  // adx_exhaustion_level
      70.0,  // rsi_overbought
      30.0,  // rsi_oversold
      3.0,   // max_price_ema_atr_distance
      state
   );
  }

//+------------------------------------------------------------------+
//| آیا رژیم از جهت حمایت می‌کند؟                                    |
//+------------------------------------------------------------------+
bool MarketRegime_SupportsDirection(
   const MarketRegimeState &state,
   const bool buy,
   const double minimum_confidence)
  {
   if(!state.valid)
      return false;

   //--- در حالت‌های نامشخص/رنج/گذار، سخت‌گیری کمتر
   if(state.regime == MARKET_REGIME_RANGE ||
      state.regime == MARKET_REGIME_TRANSITION ||
      state.regime == MARKET_REGIME_UNCERTAIN)
     {
      // اگر confidence خیلی پایین باشد، همچنان مسدود کن
      if(state.confidence < minimum_confidence * 0.5)
         return false;
      return true;
     }

   //--- در حالت‌های روندی، confidence باید کافی باشد
   if(state.confidence < minimum_confidence)
      return false;

   if(state.regime == MARKET_REGIME_UPTREND)
      return buy;

   if(state.regime == MARKET_REGIME_DOWNTREND)
      return !buy;

   return false;
  }

//+------------------------------------------------------------------+
//| آیا رژیم خلاف جهت معامله باز است؟                                |
//+------------------------------------------------------------------+
bool MarketRegime_IsReversalAgainstPosition(
   const MarketRegimeState &state,
   const bool position_is_buy,
   const double minimum_confidence)
  {
   if(!state.valid || state.confidence < minimum_confidence)
      return false;

   if(position_is_buy)
      return (state.regime == MARKET_REGIME_DOWNTREND);
   else
      return (state.regime == MARKET_REGIME_UPTREND);
  }

//+------------------------------------------------------------------+
//| بررسی معتبر بودن نتیجه تحلیل                                      |
//+------------------------------------------------------------------+
bool MarketRegime_IsValid(const MarketRegimeState &state)
  {
   if(!state.valid)
      return false;

   if(state.analysis_time <= 0)
      return false;

   if(state.regime == MARKET_REGIME_UNKNOWN)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| نام کوتاه انگلیسی برای لاگ داخلی                                 |
//+------------------------------------------------------------------+
string MarketRegime_ToCode(const ENUM_MARKET_REGIME regime)
  {
   switch(regime)
     {
      case MARKET_REGIME_UPTREND:
         return "UPTREND";
      case MARKET_REGIME_DOWNTREND:
         return "DOWNTREND";
      case MARKET_REGIME_RANGE:
         return "RANGE";
      case MARKET_REGIME_TRANSITION:
         return "TRANSITION";
      case MARKET_REGIME_UNCERTAIN:
         return "UNCERTAIN";
      default:
         return "UNKNOWN";
     }
  }

#endif // __TFLAB_MARKET_REGIME_MQH__