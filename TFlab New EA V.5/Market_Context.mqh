#ifndef __TFLAB_MARKET_CONTEXT_MQH__
#define __TFLAB_MARKET_CONTEXT_MQH__

//+------------------------------------------------------------------+
//|                      Market_Context.mqh                          |
//|                      TFlab New EA V.5                                |
//|                                                                  |
//| مسئولیت: توصیف محیط جاری بازار                                  |
//| - وضعیت قیمت در تایم‌فریم Context                                 |
//| - نوسان و ATR                                                     |
//| - دامنه روز جاری                                                  |
//| - فاصله از سقف/کف روز                                             |
//|                                                                  |
//| v2.1 - نرم‌تر کردن آستانه‌ها + استفاده از Day Position            |
//+------------------------------------------------------------------+
#ifndef __MARKET_CONTEXT_MQH__
#define __MARKET_CONTEXT_MQH__

#property strict

//====================================================================
// وضعیت ساده محیط بازار
//====================================================================
enum ENUM_MARKET_CONTEXT_STATE
  {
   MARKET_CONTEXT_UNKNOWN = 0,
   MARKET_CONTEXT_BULLISH_PRESSURE,
   MARKET_CONTEXT_BEARISH_PRESSURE,
   MARKET_CONTEXT_BALANCED,
   MARKET_CONTEXT_COMPRESSED,
   MARKET_CONTEXT_EXPANDING,
   MARKET_CONTEXT_UNCERTAIN
  };

//====================================================================
// ساختار داده Context
//====================================================================
struct MarketContextSnapshot
  {
   bool                         valid;
   string                       symbol;
   ENUM_TIMEFRAMES              timeframe;
   datetime                     analysis_time;
   datetime                     current_bar_time;

   double                       bid;
   double                       ask;
   double                       spread_points;

   double                       current_price;
   double                       previous_close;
   double                       change_points;
   double                       change_percent;

   double                       atr_points;
   double                       current_range_points;
   double                       average_range_points;

   double                       day_high;
   double                       day_low;
   double                       day_range_points;
   double                       distance_to_day_high_points;
   double                       distance_to_day_low_points;
   double                       day_position_percent;

   long                         current_volume;
   long                         average_volume;

   ENUM_MARKET_CONTEXT_STATE    state;
   double                       state_strength;
   string                       state_reason;
  };

//====================================================================
// توابع کمکی
//====================================================================
void MarketContext_Reset(MarketContextSnapshot &snapshot)
  {
   ZeroMemory(snapshot);
   snapshot.state = MARKET_CONTEXT_UNKNOWN;
   snapshot.state_strength = 0.0;
  }

string MarketContext_ToPersian(const ENUM_MARKET_CONTEXT_STATE state)
  {
   switch(state)
     {
      case MARKET_CONTEXT_BULLISH_PRESSURE: return "فشار صعودی";
      case MARKET_CONTEXT_BEARISH_PRESSURE: return "فشار نزولی";
      case MARKET_CONTEXT_BALANCED:         return "متعادل";
      case MARKET_CONTEXT_COMPRESSED:       return "فشردگی";
      case MARKET_CONTEXT_EXPANDING:        return "در حال گسترش";
      case MARKET_CONTEXT_UNCERTAIN:        return "نامطمئن";
      default:                              return "نامشخص";
     }
  }

string MarketContext_ToCode(const ENUM_MARKET_CONTEXT_STATE state)
  {
   switch(state)
     {
      case MARKET_CONTEXT_BULLISH_PRESSURE: return "BULLISH_PRESSURE";
      case MARKET_CONTEXT_BEARISH_PRESSURE: return "BEARISH_PRESSURE";
      case MARKET_CONTEXT_BALANCED:         return "BALANCED";
      case MARKET_CONTEXT_COMPRESSED:       return "COMPRESSED";
      case MARKET_CONTEXT_EXPANDING:        return "EXPANDING";
      case MARKET_CONTEXT_UNCERTAIN:        return "UNCERTAIN";
      default:                              return "UNKNOWN";
     }
  }

//====================================================================
// ATR به واحد Point
//====================================================================
double MarketContext_CalculateATRPoints(const string symbol,
                                        const ENUM_TIMEFRAMES timeframe,
                                        const int period,
                                        const int shift)
  {
   if(symbol == "" || timeframe == PERIOD_CURRENT || period <= 0)
      return 0.0;

   int handle = iATR(symbol, timeframe, period);
   if(handle == INVALID_HANDLE)
      return 0.0;

   double buffer[];
   ArraySetAsSeries(buffer, true);

   double value = 0.0;
   if(CopyBuffer(handle, 0, shift, 1, buffer) == 1)
      value = buffer[0];

   IndicatorRelease(handle);

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   return value / point;
  }

//====================================================================
// میانگین دامنه کندل‌ها
//====================================================================
double MarketContext_CalculateAverageRangePoints(const MqlRates &rates[],
                                                 const int total,
                                                 const int start_shift,
                                                 const int count)
  {
   if(total <= 0 || count <= 0 || start_shift < 0 || start_shift >= total)
      return 0.0;

   int end_index = MathMin(total - 1, start_shift + count - 1);
   double sum = 0.0;
   int used = 0;

   for(int i = start_shift; i <= end_index; i++)
     {
      double range = rates[i].high - rates[i].low;
      if(range < 0.0)
         continue;

      sum += range;
      used++;
     }

   if(used == 0)
      return 0.0;

   return sum / used;
  }

//====================================================================
// تعیین وضعیت Context بر اساس رفتار قیمت و دامنه
// [اصلاح] نرم‌تر کردن آستانه‌ها و استفاده از Day Position
//====================================================================
ENUM_MARKET_CONTEXT_STATE MarketContext_DetectState(
   const double current_close,
   const double previous_close,
   const double current_range_points,
   const double average_range_points,
   const double atr_points,
   const double day_position_percent,
   double &strength,
   string &reason)
  {
   strength = 0.0;
   reason = "";

   if(current_close <= 0.0 || previous_close <= 0.0)
     {
      reason = "قیمت کافی نیست";
      return MARKET_CONTEXT_UNKNOWN;
     }

   double change = current_close - previous_close;
   double abs_change = MathAbs(change);

   double range_ratio = 0.0;
   if(average_range_points > 0.0)
      range_ratio = current_range_points / average_range_points;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      point = 0.00000001;

   double change_points = abs_change / point;

   //=================================================================
   // [اصلاح] فشردگی: آستانه نرم‌تر از 0.55 به 0.70
   //=================================================================
   if(average_range_points > 0.0 && range_ratio <= 0.70)
     {
      strength = MathMin(100.0, (0.70 - range_ratio) / 0.70 * 100.0);
      reason = "دامنه جاری از میانگین کوچک‌تر است | Ratio=" + 
               DoubleToString(range_ratio, 2);
      return MARKET_CONTEXT_COMPRESSED;
     }

   //=================================================================
   // [اصلاح] گسترش: آستانه نرم‌تر از 1.60 به 1.40
   //=================================================================
   if(average_range_points > 0.0 && range_ratio >= 1.40)
     {
      strength = MathMin(100.0, 50.0 + (range_ratio - 1.40) / 0.60 * 50.0);
      reason = "دامنه جاری از میانگین بزرگ‌تر است | Ratio=" + 
               DoubleToString(range_ratio, 2);
      return MARKET_CONTEXT_EXPANDING;
     }

   //=================================================================
   // [اصلاح] افزایش آستانه تغییر حداقل از 5% به 10% ATR
   //=================================================================
   double minimum_directional_change = 0.0;
   if(atr_points > 0.0)
      minimum_directional_change = atr_points * 0.10;
   else if(average_range_points > 0.0)
      minimum_directional_change = average_range_points * 0.10;
   else
      minimum_directional_change = 2.0;

   if(change_points <= minimum_directional_change)
     {
      strength = 30.0;
      reason = "تغییر جهت‌دار فعلی ضعیف است | Change=" + 
               DoubleToString(change_points, 1) + " pts | MinReq=" +
               DoubleToString(minimum_directional_change, 1) + " pts";
      return MARKET_CONTEXT_BALANCED;
     }

   //=================================================================
   // [جدید] استفاده از موقعیت روز برای تقویت تشخیص
   //=================================================================
   bool near_day_high = (day_position_percent >= 80.0);
   bool near_day_low = (day_position_percent <= 20.0);

   //=================================================================
   // فشار صعودی
   //=================================================================
   if(change > 0.0)
     {
      double ratio = 0.0;
      if(atr_points > 0.0)
         ratio = change_points / atr_points;
      else if(average_range_points > 0.0)
         ratio = change_points / average_range_points;

      strength = MathMin(100.0, 30.0 + ratio * 40.0);

      // تقویت اگر نزدیک سقف روز باشد
      if(near_day_high)
         strength = MathMin(100.0, strength + 15.0);

      reason = "قیمت نسبت به بسته‌شدن قبلی بالاتر است | Change=" + 
               DoubleToString(change_points, 1) + " pts | DayPos=" + 
               DoubleToString(day_position_percent, 1) + "%" +
               (near_day_high ? " [نزدیک سقف روز]" : "");
      return MARKET_CONTEXT_BULLISH_PRESSURE;
     }

   //=================================================================
   // فشار نزولی
   //=================================================================
   if(change < 0.0)
     {
      double ratio = 0.0;
      if(atr_points > 0.0)
         ratio = change_points / atr_points;
      else if(average_range_points > 0.0)
         ratio = change_points / average_range_points;

      strength = MathMin(100.0, 30.0 + ratio * 40.0);

      // تقویت اگر نزدیک کف روز باشد
      if(near_day_low)
         strength = MathMin(100.0, strength + 15.0);

      reason = "قیمت نسبت به بسته‌شدن قبلی پایین‌تر است | Change=" + 
               DoubleToString(change_points, 1) + " pts | DayPos=" + 
               DoubleToString(day_position_percent, 1) + "%" +
               (near_day_low ? " [نزدیک کف روز]" : "");
      return MARKET_CONTEXT_BEARISH_PRESSURE;
     }

   reason = "شرایط جهت‌دار کافی نیست";
   return MARKET_CONTEXT_UNCERTAIN;
  }

//====================================================================
// تحلیل روز جاری
//====================================================================
bool MarketContext_ReadDayRange(const string symbol,
                                double &day_high,
                                double &day_low)
  {
   day_high = 0.0;
   day_low = 0.0;

   MqlRates daily[];
   ArraySetAsSeries(daily, true);

   if(CopyRates(symbol, PERIOD_D1, 0, 1, daily) != 1)
      return false;

   day_high = daily[0].high;
   day_low = daily[0].low;

   return (day_high > 0.0 && day_low > 0.0 && day_high >= day_low);
  }

//====================================================================
// تحلیل Context
//====================================================================
bool MarketContext_Analyze(const string symbol,
                           const ENUM_TIMEFRAMES timeframe,
                           const int atr_period,
                           const int average_range_bars,
                           MarketContextSnapshot &snapshot)
  {
   MarketContext_Reset(snapshot);
   snapshot.symbol = symbol;
   snapshot.timeframe = timeframe;
   snapshot.analysis_time = TimeCurrent();

   if(symbol == "")
     {
      snapshot.state_reason = "نماد معاملاتی مشخص نشده است";
      return false;
     }

   if(timeframe == PERIOD_CURRENT)
     {
      snapshot.state_reason = "تایم‌فریم معتبر نیست";
      return false;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int requested = MathMax(average_range_bars + 3, 10);
   int copied = CopyRates(symbol, timeframe, 0, requested, rates);
   if(copied < 3)
     {
      snapshot.state_reason = "داده کافی برای تحلیل Context وجود ندارد";
      return false;
     }

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
     {
      snapshot.state_reason = "دریافت قیمت جاری ناموفق بود";
      return false;
     }

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
     {
      snapshot.state_reason = "Point نماد معتبر نیست";
      return false;
     }

   snapshot.current_bar_time = rates[0].time;
   snapshot.bid = tick.bid;
   snapshot.ask = tick.ask;
   snapshot.spread_points = (tick.ask - tick.bid) / point;

   snapshot.current_price = (tick.bid > 0.0 ? tick.bid : rates[0].close);
   snapshot.previous_close = rates[1].close;
   snapshot.change_points = (snapshot.current_price - snapshot.previous_close) / point;
   if(snapshot.previous_close != 0.0)
      snapshot.change_percent = ((snapshot.current_price - snapshot.previous_close) /
                                 snapshot.previous_close) * 100.0;

   snapshot.current_range_points = (rates[0].high - rates[0].low) / point;
   snapshot.average_range_points = MarketContext_CalculateAverageRangePoints(
                                    rates,
                                    copied,
                                    1,
                                    average_range_bars);

   snapshot.atr_points = MarketContext_CalculateATRPoints(
                                    symbol,
                                    timeframe,
                                    atr_period,
                                    1);

   if(snapshot.average_range_points <= 0.0 && snapshot.atr_points > 0.0)
      snapshot.average_range_points = snapshot.atr_points;

   snapshot.current_volume = (long)rates[0].tick_volume;

   long volume_sum = 0;
   int volume_count = 0;
   int volume_end = MathMin(copied - 1, average_range_bars);
   for(int i = 1; i <= volume_end; i++)
     {
      volume_sum += (long)rates[i].tick_volume;
      volume_count++;
     }

   if(volume_count > 0)
      snapshot.average_volume = volume_sum / volume_count;

   MarketContext_ReadDayRange(symbol,
                              snapshot.day_high,
                              snapshot.day_low);

   if(snapshot.day_high > 0.0 && snapshot.day_low > 0.0)
     {
      snapshot.day_range_points = (snapshot.day_high - snapshot.day_low) / point;
      snapshot.distance_to_day_high_points = (snapshot.day_high - snapshot.current_price) / point;
      snapshot.distance_to_day_low_points = (snapshot.current_price - snapshot.day_low) / point;

      if(snapshot.day_high > snapshot.day_low)
        {
         snapshot.day_position_percent =
            ((snapshot.current_price - snapshot.day_low) /
             (snapshot.day_high - snapshot.day_low)) * 100.0;
         snapshot.day_position_percent = MathMax(0.0,
                                           MathMin(100.0, snapshot.day_position_percent));
        }
     }

   //=================================================================
   // [اصلاح] پاس دادن day_position_percent به DetectState
   //=================================================================
   snapshot.state = MarketContext_DetectState(
                              rates[0].close,
                              rates[1].close,
                              snapshot.current_range_points,
                              snapshot.average_range_points,
                              snapshot.atr_points,
                              snapshot.day_position_percent,
                              snapshot.state_strength,
                              snapshot.state_reason);

   snapshot.valid = true;

   //=================================================================
   // [جدید] لاگ تشخیصی کامل
   //=================================================================
   double range_ratio = (snapshot.average_range_points > 0.0) ?
      (snapshot.current_range_points / snapshot.average_range_points) : 0.0;

   Print(
      "[MARKET_CONTEXT] State=", MarketContext_ToCode(snapshot.state),
      " | Strength=", DoubleToString(snapshot.state_strength, 1),
      " | Change=", DoubleToString(snapshot.change_points, 1), " pts",
      " | RangeRatio=", DoubleToString(range_ratio, 2),
      " | ATR=", DoubleToString(snapshot.atr_points, 1),
      " | DayPos=", DoubleToString(snapshot.day_position_percent, 1), "%",
      " | ", snapshot.state_reason
   );

   return true;
  }

//====================================================================
// بررسی اعتبار Snapshot
//====================================================================
bool MarketContext_IsValid(const MarketContextSnapshot &snapshot)
  {
   if(!snapshot.valid)
      return false;

   if(snapshot.symbol == "")
      return false;

   if(snapshot.analysis_time <= 0)
      return false;

   if(snapshot.current_price <= 0.0)
      return false;

   return true;
  }

//====================================================================
// خلاصه فارسی برای Logger آینده
//====================================================================
string MarketContext_BuildSummary(const MarketContextSnapshot &snapshot)
  {
   if(!MarketContext_IsValid(snapshot))
      return "وضعیت Context معتبر نیست";

   int digits = (int)SymbolInfoInteger(snapshot.symbol, SYMBOL_DIGITS);
   string text = "Context | ";
   text += "وضعیت=" + MarketContext_ToPersian(snapshot.state);
   text += " | قیمت=" + DoubleToString(snapshot.current_price, digits);
   text += " | تغییر=" + DoubleToString(snapshot.change_points, 1) + " Point";
   text += " | ATR=" + DoubleToString(snapshot.atr_points, 1) + " Point";
   text += " | دامنه روز=" + DoubleToString(snapshot.day_range_points, 1) + " Point";
   text += " | موقعیت روز=" + DoubleToString(snapshot.day_position_percent, 1) + "%";
   text += " | قدرت=" + DoubleToString(snapshot.state_strength, 1) + "%";
   return text;
  }

#endif // __MARKET_CONTEXT_MQH__
//+------------------------------------------------------------------+

#endif // __TFLAB_MARKET_CONTEXT_MQH__