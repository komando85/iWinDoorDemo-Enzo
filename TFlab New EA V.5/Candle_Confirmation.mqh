#ifndef __TFLAB_CANDLE_CONFIRMATION_MQH__
#define __TFLAB_CANDLE_CONFIRMATION_MQH__

//+------------------------------------------------------------------+
//|                  Candle_Confirmation.mqh                         |
//|                  TFlab New EA V.5                                    |
//|                                                                  |
//| مسئولیت: تأیید جهت ورود با الگوهای کندلی                        |
//|                                                                  |
//| الگوهای تشخیص:                                                    |
//| - جهت بدنه قوی (حداقل 30% محدوده)                                |
//| - پین بار / چکش (شدو بلند در جهت مخالف)                          |
//| - انگالفینگ (پوشای کامل بدنه قبلی)                               |
//| - ماروبوزو (بدنه بالای 80%)                                      |
//|                                                                  |
//| v2.1 - رفع باگ CopyRates + الگوهای جدید + لاگ تشخیصی            |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// تأیید جهت با الگوهای کندلی
//====================================================================
bool CandleConfirmation_ConfirmsDirection(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const double min_wick_ratio,
   const bool buy,
   string &reason)
  {
   reason = "";

   //=================================================================
   // [اصلاح] یکبار کپی 3 کندل به جای دو بار کپی جداگانه
   //=================================================================
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int copied = CopyRates(symbol, timeframe, 1, 3, r);

   if(copied < 2)
     {
      reason = "داده کندل کافی نیست | Copied=" + IntegerToString(copied);
      return false;
     }

   //--- کندل اصلی (آخرین بسته شده)
   double o = r[0].open;
   double c = r[0].close;
   double h = r[0].high;
   double l = r[0].low;

   double body = MathAbs(c - o);
   double range = h - l;

   if(range <= 0.0)
     {
      reason = "محدوده کندل معتبر نیست";
      return false;
     }

   double upper = h - MathMax(o, c);
   double lower = MathMin(o, c) - l;

   //--- نسبت بدنه به کل محدوده
   double body_ratio = body / range;

   //--- شدو غالب و نسبت آن
   double dominant_wick = buy ? lower : upper;
   double wick_ratio = dominant_wick / MathMax(body, _Point);

   string confirm_reason = "";
   int confirm_count = 0;

   //=================================================================
   // 1. جهت بدنه کندل
   //    [اصلاح] برای تأیید، بدنه باید حداقل 30% محدوده باشد
   //=================================================================
   bool body_dir = buy ? (c > o) : (c < o);
   if(body_dir && body_ratio >= 0.30)
     {
      confirm_count++;
      confirm_reason += "BodyDir ";
     }

   //=================================================================
   // 2. پین بار / چکش
   //    شدو بلند در جهت مخالف + بدنه کوچک‌تر از شدو
   //=================================================================
   if(wick_ratio >= min_wick_ratio && dominant_wick > body)
     {
      confirm_count++;
      confirm_reason += "PinBar ";
     }

   //=================================================================
   // 3. انگالفینگ (پوشای کامل)
   //    [اصلاح] استفاده از r[1] که حالا واقعاً کندل 2 است
   //=================================================================
   bool engulf = false;
   if(copied >= 2)
     {
      double prev_o = r[1].open;
      double prev_c = r[1].close;

      if(buy)
        {
         //--- کندل صعودی که بدنه قبلی را کاملاً می‌پوشاند
         engulf = (c > o) &&
                  (c > MathMax(prev_o, prev_c)) &&
                  (o < MathMin(prev_o, prev_c));
        }
      else
        {
         //--- کندل نزولی که بدنه قبلی را کاملاً می‌پوشاند
         engulf = (c < o) &&
                  (c < MathMin(prev_o, prev_c)) &&
                  (o > MathMax(prev_o, prev_c));
        }

      if(engulf)
        {
         confirm_count++;
         confirm_reason += "Engulf ";
        }
     }

   //=================================================================
   // 4. ماروبوزو
   //    بدنه بسیار بزرگ (بالای 80%) و هم‌جهت
   //=================================================================
   if(body_dir && body_ratio >= 0.80)
     {
      confirm_count++;
      confirm_reason += "Marubozu ";
     }

   //=================================================================
   // تصمیم نهایی: حداقل یک تأیید لازم است
   //=================================================================
   if(confirm_count > 0)
     {
      reason = "تأیید کندلی (" + confirm_reason +
               ") | BodyRatio=" + DoubleToString(body_ratio * 100.0, 1) +
               "% | WickRatio=" + DoubleToString(wick_ratio, 2);

      Print(
         "[CANDLE_CONFIRM] PASS",
         " | Dir=", (buy ? "BUY" : "SELL"),
         " | Patterns=", confirm_reason,
         " | BodyRatio=", DoubleToString(body_ratio * 100.0, 1), "%",
         " | WickRatio=", DoubleToString(wick_ratio, 2)
      );

      return true;
     }

   //--- رد شد
   reason = "جهت کندل تأیید نشده است | BodyRatio=" +
            DoubleToString(body_ratio * 100.0, 1) +
            "% | WickRatio=" + DoubleToString(wick_ratio, 2) +
            " | BodyDir=" + (body_dir ? "YES" : "NO");

   Print(
      "[CANDLE_CONFIRM] FAIL",
      " | Dir=", (buy ? "BUY" : "SELL"),
      " | BodyRatio=", DoubleToString(body_ratio * 100.0, 1), "%",
      " | WickRatio=", DoubleToString(wick_ratio, 2),
      " | BodyDir=", (body_dir ? "YES" : "NO"),
      " | Engulf=", (engulf ? "YES" : "NO")
   );

   return false;
  }

#endif // __TFLAB_CANDLE_CONFIRMATION_MQH__