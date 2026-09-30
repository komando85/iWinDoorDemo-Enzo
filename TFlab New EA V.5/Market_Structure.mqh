#ifndef __TFLAB_MARKET_STRUCTURE_MQH__
#define __TFLAB_MARKET_STRUCTURE_MQH__

//+------------------------------------------------------------------+
//|                    Market_Structure.mqh                          |
//|                    TFlab New EA V.5                                  |
//|                                                                  |
//| مسئولیت: استخراج ساختار بازار از Swingهای تایم‌فریم انتخابی      |
//| این فایل هیچ تصمیم ورود، خروج، ریسک یا اجرای سفارش ندارد.         |
//|                                                                  |
//| خروجی اصلی:                                                       |
//| - Swing High / Swing Low                                          |
//| - HH / HL / LH / LL                                               |
//| - وضعیت ساختار صعودی / نزولی / خنثی / انتقالی                    |
//| - آخرین سطوح ساختاری مهم                                          |
//| - Streak واقعی HH/HL و LH/LL                                      |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// نوع Swing
//====================================================================
enum ENUM_STRUCTURE_SWING_TYPE
  {
   STRUCTURE_SWING_NONE = 0,
   STRUCTURE_SWING_HIGH,
   STRUCTURE_SWING_LOW
  };

//====================================================================
// برچسب ساختاری Swing
//====================================================================
enum ENUM_STRUCTURE_LABEL
  {
   STRUCTURE_LABEL_NONE = 0,
   STRUCTURE_LABEL_HH,
   STRUCTURE_LABEL_HL,
   STRUCTURE_LABEL_LH,
   STRUCTURE_LABEL_LL
  };

//====================================================================
// وضعیت کلی ساختار
//====================================================================
enum ENUM_STRUCTURE_STATE
  {
   STRUCTURE_STATE_UNKNOWN = 0,
   STRUCTURE_STATE_BULLISH,
   STRUCTURE_STATE_BEARISH,
   STRUCTURE_STATE_BALANCED,
   STRUCTURE_STATE_TRANSITION,
   STRUCTURE_STATE_UNCERTAIN
  };

//====================================================================
// یک Swing
//====================================================================
struct MarketSwing
  {
   bool                        valid;
   ENUM_STRUCTURE_SWING_TYPE   type;
   ENUM_STRUCTURE_LABEL        label;
   int                         shift;
   datetime                    time;
   double                      price;
   double                      comparison_price;
  };

//====================================================================
// Snapshot ساختار بازار
//====================================================================
struct MarketStructureSnapshot
  {
   bool                      valid;
   string                    symbol;
   ENUM_TIMEFRAMES           timeframe;
   datetime                  analysis_time;

   int                       bars_used;
   int                       swing_count;

   MarketSwing               last_high;
   MarketSwing               previous_high;
   MarketSwing               last_low;
   MarketSwing               previous_low;

   ENUM_STRUCTURE_LABEL      latest_high_label;
   ENUM_STRUCTURE_LABEL      latest_low_label;
   ENUM_STRUCTURE_STATE      state;

   double                    structural_high;
   double                    structural_low;
   double                    structure_range_points;

   bool                      bullish_sequence;
   bool                      bearish_sequence;
   int                       bullish_swing_streak;
   int                       bearish_swing_streak;
   string                    reason;
  };

//====================================================================
// تبدیل نوع Swing به فارسی
//====================================================================
string MarketStructure_SwingTypeToPersian(const ENUM_STRUCTURE_SWING_TYPE type)
  {
   switch(type)
     {
      case STRUCTURE_SWING_HIGH: return "سقف نوسانی";
      case STRUCTURE_SWING_LOW:  return "کف نوسانی";
      default:                   return "بدون نوع";
     }
  }

//====================================================================
// تبدیل برچسب ساختاری به فارسی
//====================================================================
string MarketStructure_LabelToPersian(const ENUM_STRUCTURE_LABEL label)
  {
   switch(label)
     {
      case STRUCTURE_LABEL_HH: return "HH - سقف بالاتر";
      case STRUCTURE_LABEL_HL: return "HL - کف بالاتر";
      case STRUCTURE_LABEL_LH: return "LH - سقف پایین‌تر";
      case STRUCTURE_LABEL_LL: return "LL - کف پایین‌تر";
      default:                 return "بدون برچسب";
     }
  }

//====================================================================
// کد کوتاه برچسب برای لاگ
//====================================================================
string MarketStructure_LabelToCode(const ENUM_STRUCTURE_LABEL label)
  {
   switch(label)
     {
      case STRUCTURE_LABEL_HH: return "HH";
      case STRUCTURE_LABEL_HL: return "HL";
      case STRUCTURE_LABEL_LH: return "LH";
      case STRUCTURE_LABEL_LL: return "LL";
      default:                 return "NONE";
     }
  }

//====================================================================
// تبدیل وضعیت ساختار به فارسی
//====================================================================
string MarketStructure_StateToPersian(const ENUM_STRUCTURE_STATE state)
  {
   switch(state)
     {
      case STRUCTURE_STATE_BULLISH:    return "ساختار صعودی";
      case STRUCTURE_STATE_BEARISH:    return "ساختار نزولی";
      case STRUCTURE_STATE_BALANCED:   return "ساختار متعادل";
      case STRUCTURE_STATE_TRANSITION: return "در حال تغییر";
      case STRUCTURE_STATE_UNCERTAIN:  return "نامطمئن";
      default:                         return "نامشخص";
     }
  }

//====================================================================
// کد داخلی انگلیسی برای لاگ
//====================================================================
string MarketStructure_StateToCode(const ENUM_STRUCTURE_STATE state)
  {
   switch(state)
     {
      case STRUCTURE_STATE_BULLISH:    return "BULLISH";
      case STRUCTURE_STATE_BEARISH:    return "BEARISH";
      case STRUCTURE_STATE_BALANCED:   return "BALANCED";
      case STRUCTURE_STATE_TRANSITION: return "TRANSITION";
      case STRUCTURE_STATE_UNCERTAIN:  return "UNCERTAIN";
      default:                         return "UNKNOWN";
     }
  }

//====================================================================
// ریست Swing
//====================================================================
void MarketStructure_ResetSwing(MarketSwing &swing)
  {
   ZeroMemory(swing);
   swing.type  = STRUCTURE_SWING_NONE;
   swing.label = STRUCTURE_LABEL_NONE;
  }

//====================================================================
// ریست Snapshot
//====================================================================
void MarketStructure_Reset(MarketStructureSnapshot &snapshot)
  {
   ZeroMemory(snapshot);
   snapshot.timeframe         = PERIOD_CURRENT;
   snapshot.latest_high_label = STRUCTURE_LABEL_NONE;
   snapshot.latest_low_label  = STRUCTURE_LABEL_NONE;
   snapshot.state             = STRUCTURE_STATE_UNKNOWN;

   MarketStructure_ResetSwing(snapshot.last_high);
   MarketStructure_ResetSwing(snapshot.previous_high);
   MarketStructure_ResetSwing(snapshot.last_low);
   MarketStructure_ResetSwing(snapshot.previous_low);
  }

//====================================================================
// اعتبارسنجی آرایه قیمت
//====================================================================
bool MarketStructure_IsUsableRates(const MqlRates &rates[], const int total)
  {
   return (total >= 7);
  }

//====================================================================
// تشخیص Pivot High
// [اصلاح] تقارن در مقایسه‌ها برای جلوگیری از دست رفتن Pivotها
//====================================================================
bool MarketStructure_IsPivotHigh(const MqlRates &rates[],
                                 const int total,
                                 const int shift,
                                 const int left_bars,
                                 const int right_bars)
  {
   if(!MarketStructure_IsUsableRates(rates, total))
      return false;

   if(shift < right_bars || shift + left_bars >= total)
      return false;

   const double pivot = rates[shift].high;

   // سمت راست (کندل‌های جدیدتر)
   for(int i = 1; i <= right_bars; i++)
     {
      if(pivot < rates[shift - i].high)
         return false;
     }

   // سمت چپ (کندل‌های قدیمی‌تر)
   for(int i = 1; i <= left_bars; i++)
     {
      if(pivot < rates[shift + i].high)
         return false;
     }

   return true;
  }

//====================================================================
// تشخیص Pivot Low
// [اصلاح] تقارن در مقایسه‌ها
//====================================================================
bool MarketStructure_IsPivotLow(const MqlRates &rates[],
                                const int total,
                                const int shift,
                                const int left_bars,
                                const int right_bars)
  {
   if(!MarketStructure_IsUsableRates(rates, total))
      return false;

   if(shift < right_bars || shift + left_bars >= total)
      return false;

   const double pivot = rates[shift].low;

   for(int i = 1; i <= right_bars; i++)
     {
      if(pivot > rates[shift - i].low)
         return false;
     }

   for(int i = 1; i <= left_bars; i++)
     {
      if(pivot > rates[shift + i].low)
         return false;
     }

   return true;
  }

//====================================================================
// ساخت Swing High
//====================================================================
MarketSwing MarketStructure_MakeHigh(const MqlRates &rates[], const int shift)
  {
   MarketSwing swing;
   MarketStructure_ResetSwing(swing);

   if(shift < 0)
      return swing;

   swing.valid = true;
   swing.type  = STRUCTURE_SWING_HIGH;
   swing.shift = shift;
   swing.time  = rates[shift].time;
   swing.price = rates[shift].high;
   return swing;
  }

//====================================================================
// ساخت Swing Low
//====================================================================
MarketSwing MarketStructure_MakeLow(const MqlRates &rates[], const int shift)
  {
   MarketSwing swing;
   MarketStructure_ResetSwing(swing);

   if(shift < 0)
      return swing;

   swing.valid = true;
   swing.type  = STRUCTURE_SWING_LOW;
   swing.shift = shift;
   swing.time  = rates[shift].time;
   swing.price = rates[shift].low;
   return swing;
  }

//====================================================================
// برچسب‌گذاری دو سقف متوالی
//====================================================================
ENUM_STRUCTURE_LABEL MarketStructure_LabelHigh(const double current_high,
                                               const double previous_high,
                                               const double tolerance_points,
                                               const double point)
  {
   if(current_high <= 0.0 || previous_high <= 0.0)
      return STRUCTURE_LABEL_NONE;

   const double tolerance =
      MathMax(0.0, tolerance_points) * MathMax(point, 0.00000001);

   if(current_high > previous_high + tolerance)
      return STRUCTURE_LABEL_HH;

   if(current_high < previous_high - tolerance)
      return STRUCTURE_LABEL_LH;

   return STRUCTURE_LABEL_NONE;
  }

//====================================================================
// برچسب‌گذاری دو کف متوالی
//====================================================================
ENUM_STRUCTURE_LABEL MarketStructure_LabelLow(const double current_low,
                                              const double previous_low,
                                              const double tolerance_points,
                                              const double point)
  {
   if(current_low <= 0.0 || previous_low <= 0.0)
      return STRUCTURE_LABEL_NONE;

   const double tolerance =
      MathMax(0.0, tolerance_points) * MathMax(point, 0.00000001);

   if(current_low > previous_low + tolerance)
      return STRUCTURE_LABEL_HL;

   if(current_low < previous_low - tolerance)
      return STRUCTURE_LABEL_LL;

   return STRUCTURE_LABEL_NONE;
  }

//====================================================================
// [جدید] برچسب‌گذاری کل آرایه Swing High
// آرایه highs از جدیدترین (index 0) به قدیمی‌ترین مرتب است.
// برای هر swing، آن را با swing قبلی (قدیمی‌تر) مقایسه می‌کنیم.
//====================================================================
void MarketStructure_LabelHighArray(MarketSwing &highs[],
                                    const double tolerance_points,
                                    const double point)
  {
   const int count = ArraySize(highs);

   // از جدیدترین به قدیمی‌ترین: index 0 جدیدترین است
   // مقایسه index i با index i+1 (قدیمی‌تر)
   for(int i = 0; i < count - 1; i++)
     {
      highs[i].label = MarketStructure_LabelHigh(
         highs[i].price,
         highs[i + 1].price,
         tolerance_points,
         point);
      highs[i].comparison_price = highs[i + 1].price;
     }

   // قدیمی‌ترین swing برچسب ندارد
   if(count > 0)
     {
      highs[count - 1].label = STRUCTURE_LABEL_NONE;
      highs[count - 1].comparison_price = 0.0;
     }
  }

//====================================================================
// [جدید] برچسب‌گذاری کل آرایه Swing Low
//====================================================================
void MarketStructure_LabelLowArray(MarketSwing &lows[],
                                   const double tolerance_points,
                                   const double point)
  {
   const int count = ArraySize(lows);

   for(int i = 0; i < count - 1; i++)
     {
      lows[i].label = MarketStructure_LabelLow(
         lows[i].price,
         lows[i + 1].price,
         tolerance_points,
         point);
      lows[i].comparison_price = lows[i + 1].price;
     }

   if(count > 0)
     {
      lows[count - 1].label = STRUCTURE_LABEL_NONE;
      lows[count - 1].comparison_price = 0.0;
     }
  }

//====================================================================
// [جدید] شمارش Streak واقعی صعودی (HH متوالی)
// از جدیدترین swing شروع می‌کنیم و تا جایی که HH است می‌شماریم.
//====================================================================
int MarketStructure_CountBullishHighStreak(const MarketSwing &highs[])
  {
   const int count = ArraySize(highs);
   int streak = 0;

   for(int i = 0; i < count; i++)
     {
      if(highs[i].label == STRUCTURE_LABEL_HH)
         streak++;
      else
         break;
     }

   return streak;
  }

//====================================================================
// [جدید] شمارش Streak واقعی نزولی (LH متوالی)
//====================================================================
int MarketStructure_CountBearishHighStreak(const MarketSwing &highs[])
  {
   const int count = ArraySize(highs);
   int streak = 0;

   for(int i = 0; i < count; i++)
     {
      if(highs[i].label == STRUCTURE_LABEL_LH)
         streak++;
      else
         break;
     }

   return streak;
  }

//====================================================================
// [جدید] شمارش Streak واقعی صعودی کف‌ها (HL متوالی)
//====================================================================
int MarketStructure_CountBullishLowStreak(const MarketSwing &lows[])
  {
   const int count = ArraySize(lows);
   int streak = 0;

   for(int i = 0; i < count; i++)
     {
      if(lows[i].label == STRUCTURE_LABEL_HL)
         streak++;
      else
         break;
     }

   return streak;
  }

//====================================================================
// [جدید] شمارش Streak واقعی نزولی کف‌ها (LL متوالی)
//====================================================================
int MarketStructure_CountBearishLowStreak(const MarketSwing &lows[])
  {
   const int count = ArraySize(lows);
   int streak = 0;

   for(int i = 0; i < count; i++)
     {
      if(lows[i].label == STRUCTURE_LABEL_LL)
         streak++;
      else
         break;
     }

   return streak;
  }

//====================================================================
// تعیین وضعیت ساختار از آخرین برچسب‌های سقف و کف
// [اصلاح] منطق دقیق‌تر برای BALANCED / TRANSITION
//====================================================================
ENUM_STRUCTURE_STATE MarketStructure_DetectState(const ENUM_STRUCTURE_LABEL high_label,
                                                 const ENUM_STRUCTURE_LABEL low_label,
                                                 const int bullish_high_streak,
                                                 const int bullish_low_streak,
                                                 const int bearish_high_streak,
                                                 const int bearish_low_streak,
                                                 bool &bullish_sequence,
                                                 bool &bearish_sequence,
                                                 string &reason)
  {
   bullish_sequence = false;
   bearish_sequence = false;
   reason = "";

   //---------------------------------------------------------------
   // 1. روند صعودی: HH + HL
   //---------------------------------------------------------------
   if(high_label == STRUCTURE_LABEL_HH && low_label == STRUCTURE_LABEL_HL)
     {
      bullish_sequence = true;
      reason = "HH + HL | توالی صعودی کامل سقف و کف";
      return STRUCTURE_STATE_BULLISH;
     }

   //---------------------------------------------------------------
   // 2. روند نزولی: LH + LL
   //---------------------------------------------------------------
   if(high_label == STRUCTURE_LABEL_LH && low_label == STRUCTURE_LABEL_LL)
     {
      bearish_sequence = true;
      reason = "LH + LL | توالی نزولی کامل سقف و کف";
      return STRUCTURE_STATE_BEARISH;
     }

   //---------------------------------------------------------------
   // 3. صعودی ضعیف: فقط HH یا فقط HL (نه هر دو)
   //    اگر streak صعودی قابل توجه باشد، همچنان صعودی فرض می‌شود.
   //---------------------------------------------------------------
   if((high_label == STRUCTURE_LABEL_HH && low_label == STRUCTURE_LABEL_NONE) ||
      (high_label == STRUCTURE_LABEL_NONE && low_label == STRUCTURE_LABEL_HL))
     {
      const int bull_streak = MathMax(bullish_high_streak, bullish_low_streak);

      if(bull_streak >= 1)
        {
         bullish_sequence = true;
         reason = "توالی صعودی جزئی | HighLabel=" +
                  MarketStructure_LabelToCode(high_label) +
                  " | LowLabel=" +
                  MarketStructure_LabelToCode(low_label) +
                  " | BullStreak=" + IntegerToString(bull_streak);
         return STRUCTURE_STATE_BULLISH;
        }
     }

   //---------------------------------------------------------------
   // 4. نزولی ضعیف: فقط LH یا فقط LL
   //---------------------------------------------------------------
   if((high_label == STRUCTURE_LABEL_LH && low_label == STRUCTURE_LABEL_NONE) ||
      (high_label == STRUCTURE_LABEL_NONE && low_label == STRUCTURE_LABEL_LL))
     {
      const int bear_streak = MathMax(bearish_high_streak, bearish_low_streak);

      if(bear_streak >= 1)
        {
         bearish_sequence = true;
         reason = "توالی نزولی جزئی | HighLabel=" +
                  MarketStructure_LabelToCode(high_label) +
                  " | LowLabel=" +
                  MarketStructure_LabelToCode(low_label) +
                  " | BearStreak=" + IntegerToString(bear_streak);
         return STRUCTURE_STATE_BEARISH;
        }
     }

   //---------------------------------------------------------------
   // 5. ساختار گسترشی: HH + LL (سقف بالاتر، کف پایین‌تر)
   //---------------------------------------------------------------
   if(high_label == STRUCTURE_LABEL_HH && low_label == STRUCTURE_LABEL_LL)
     {
      reason = "ساختار گسترشی (Expanding) | HH + LL | جهت نامشخص";
      return STRUCTURE_STATE_BALANCED;
     }

   //---------------------------------------------------------------
   // 6. ساختار فشرده: LH + HL (سقف پایین‌تر، کف بالاتر)
   //---------------------------------------------------------------
   if(high_label == STRUCTURE_LABEL_LH && low_label == STRUCTURE_LABEL_HL)
     {
      reason = "ساختار فشرده (Contracting) | LH + HL | احتمال تغییر روند";
      return STRUCTURE_STATE_TRANSITION;
     }

   //---------------------------------------------------------------
   // 7. تضاد جهت: HH + LH یا HL + LL (غیرممکن در حالت عادی)
   //---------------------------------------------------------------
   if((high_label == STRUCTURE_LABEL_HH && low_label == STRUCTURE_LABEL_LH) ||
      (high_label == STRUCTURE_LABEL_HL && low_label == STRUCTURE_LABEL_LL))
     {
      reason = "برچسب‌های متناقض | احتمال تغییر ساختار";
      return STRUCTURE_STATE_TRANSITION;
     }

   //---------------------------------------------------------------
   // 8. هر دو NONE: داده ناکافی
   //---------------------------------------------------------------
   if(high_label == STRUCTURE_LABEL_NONE && low_label == STRUCTURE_LABEL_NONE)
     {
      reason = "برای تعیین ساختار، توالی کافی از Swingها وجود ندارد";
      return STRUCTURE_STATE_UNCERTAIN;
     }

   //---------------------------------------------------------------
   // 9. حالت پیش‌فرض
   //---------------------------------------------------------------
   reason = "ساختار ترکیبی یا بدون جهت مشخص | HighLabel=" +
            MarketStructure_LabelToCode(high_label) +
            " | LowLabel=" +
            MarketStructure_LabelToCode(low_label);
   return STRUCTURE_STATE_BALANCED;
  }

//====================================================================
// تحلیل ساختار بازار
//====================================================================
bool MarketStructure_Analyze(const string symbol,
                             const ENUM_TIMEFRAMES timeframe,
                             const int bars_to_scan,
                             const int left_bars,
                             const int right_bars,
                             const double tolerance_points,
                             MarketStructureSnapshot &snapshot)
  {
   MarketStructure_Reset(snapshot);

   if(symbol == "" || timeframe == PERIOD_CURRENT)
     {
      snapshot.reason = "نماد یا تایم‌فریم معتبر نیست";
      return false;
     }

   if(bars_to_scan < 10 || left_bars < 1 || right_bars < 1)
     {
      snapshot.reason = "پارامترهای تحلیل ساختار معتبر نیستند";
      return false;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   const int copied = CopyRates(symbol, timeframe, 0, bars_to_scan, rates);

   if(copied < 10)
     {
      snapshot.reason = "داده کافی برای تحلیل ساختار دریافت نشد";
      return false;
     }

   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   if(point <= 0.0)
     {
      snapshot.reason = "Point نماد معتبر نیست";
      return false;
     }

   MarketSwing highs[];
   MarketSwing lows[];
   ArrayResize(highs, 0);
   ArrayResize(lows, 0);

   // از کندل بسته‌شده شماره 1 شروع می‌کنیم.
   const int first_shift = MathMax(right_bars, 1);
   const int last_shift  = copied - left_bars - 1;

   for(int shift = first_shift; shift <= last_shift; shift++)
     {
      if(MarketStructure_IsPivotHigh(rates, copied, shift, left_bars, right_bars))
        {
         const int n = ArraySize(highs);
         ArrayResize(highs, n + 1);
         highs[n] = MarketStructure_MakeHigh(rates, shift);
        }

      if(MarketStructure_IsPivotLow(rates, copied, shift, left_bars, right_bars))
        {
         const int n = ArraySize(lows);
         ArrayResize(lows, n + 1);
         lows[n] = MarketStructure_MakeLow(rates, shift);
        }
     }

   const int high_count = ArraySize(highs);
   const int low_count  = ArraySize(lows);

   snapshot.valid         = true;
   snapshot.symbol        = symbol;
   snapshot.timeframe     = timeframe;
   snapshot.analysis_time = TimeCurrent();
   snapshot.bars_used     = copied;
   snapshot.swing_count   = high_count + low_count;

   //---------------------------------------------------------------
   // ذخیره آخرین Swingها
   //---------------------------------------------------------------
   if(high_count >= 1)
     {
      snapshot.last_high       = highs[0];
      snapshot.structural_high = highs[0].price;
     }

   if(high_count >= 2)
      snapshot.previous_high = highs[1];

   if(low_count >= 1)
     {
      snapshot.last_low       = lows[0];
      snapshot.structural_low = lows[0].price;
     }

   if(low_count >= 2)
      snapshot.previous_low = lows[1];

   //---------------------------------------------------------------
   // [جدید] برچسب‌گذاری کل آرایه‌ها برای محاسبه Streak واقعی
   //---------------------------------------------------------------
   MarketStructure_LabelHighArray(highs, tolerance_points, point);
   MarketStructure_LabelLowArray(lows, tolerance_points, point);

   //---------------------------------------------------------------
   // به‌روزرسانی label آخرین Swingها از آرایه برچسب‌گذاری‌شده
   //---------------------------------------------------------------
   if(high_count >= 1)
     {
      snapshot.latest_high_label = highs[0].label;
      snapshot.last_high.label   = highs[0].label;
      snapshot.last_high.comparison_price = highs[0].comparison_price;
     }

   if(low_count >= 1)
     {
      snapshot.latest_low_label = lows[0].label;
      snapshot.last_low.label   = lows[0].label;
      snapshot.last_low.comparison_price = lows[0].comparison_price;
     }

   //---------------------------------------------------------------
   // [جدید] محاسبه Streak واقعی
   //---------------------------------------------------------------
   const int bullish_high_streak = MarketStructure_CountBullishHighStreak(highs);
   const int bullish_low_streak  = MarketStructure_CountBullishLowStreak(lows);
   const int bearish_high_streak = MarketStructure_CountBearishHighStreak(highs);
   const int bearish_low_streak  = MarketStructure_CountBearishLowStreak(lows);

   // Streak صعودی = حداقلِ streak سقف‌ها و کف‌های صعودی
   // اگر یکی صفر باشد، از دیگری استفاده می‌کنیم.
   int bull_streak = 0;
   int bear_streak = 0;

   if(bullish_high_streak > 0 && bullish_low_streak > 0)
      bull_streak = MathMin(bullish_high_streak, bullish_low_streak);
   else
      bull_streak = MathMax(bullish_high_streak, bullish_low_streak);

   if(bearish_high_streak > 0 && bearish_low_streak > 0)
      bear_streak = MathMin(bearish_high_streak, bearish_low_streak);
   else
      bear_streak = MathMax(bearish_high_streak, bearish_low_streak);

   snapshot.bullish_swing_streak = bull_streak;
   snapshot.bearish_swing_streak = bear_streak;

   //---------------------------------------------------------------
   // تعیین وضعیت ساختار
   //---------------------------------------------------------------
   snapshot.state = MarketStructure_DetectState(
      snapshot.latest_high_label,
      snapshot.latest_low_label,
      bullish_high_streak,
      bullish_low_streak,
      bearish_high_streak,
      bearish_low_streak,
      snapshot.bullish_sequence,
      snapshot.bearish_sequence,
      snapshot.reason);

   //---------------------------------------------------------------
   // محدوده ساختاری
   //---------------------------------------------------------------
   if(snapshot.structural_high > 0.0 && snapshot.structural_low > 0.0)
      snapshot.structure_range_points =
         (snapshot.structural_high - snapshot.structural_low) / point;

   //---------------------------------------------------------------
   // اعتبار نهایی
   //---------------------------------------------------------------
   if(high_count < 2 && low_count < 2)
     {
      snapshot.valid = false;
      snapshot.state = STRUCTURE_STATE_UNCERTAIN;
      snapshot.reason = "حداقل دو Swing قابل مقایسه در سقف و کف وجود ندارد";

      Print(
         "[MARKET_STRUCTURE] FAIL | Insufficient Swings",
         " | Highs=", high_count,
         " | Lows=", low_count
      );

      return false;
     }

   //---------------------------------------------------------------
   // لاگ تشخیصی
   //---------------------------------------------------------------
   Print(
      "[MARKET_STRUCTURE] ",
      MarketStructure_StateToCode(snapshot.state),
      " | HighLabel=", MarketStructure_LabelToCode(snapshot.latest_high_label),
      " | LowLabel=", MarketStructure_LabelToCode(snapshot.latest_low_label),
      " | BullSeq=", (snapshot.bullish_sequence ? "YES" : "NO"),
      " | BearSeq=", (snapshot.bearish_sequence ? "YES" : "NO"),
      " | BullStreak=", bull_streak,
      " | BearStreak=", bear_streak,
      " | Highs=", high_count,
      " | Lows=", low_count,
      " | Range=", DoubleToString(snapshot.structure_range_points, 1),
      " | ", snapshot.reason
   );

   return true;
  }

//====================================================================
// بررسی آماده بودن Snapshot
//====================================================================
bool MarketStructure_IsValid(const MarketStructureSnapshot &snapshot)
  {
   if(!snapshot.valid)
      return false;

   if(snapshot.analysis_time <= 0)
      return false;

   if(snapshot.symbol == "")
      return false;

   if(snapshot.timeframe == PERIOD_CURRENT)
      return false;

   return true;
  }

#endif // __TFLAB_MARKET_STRUCTURE_MQH__