#ifndef __TFLAB_NEWS_FILTER_MQH__
#define __TFLAB_NEWS_FILTER_MQH__

//+------------------------------------------------------------------+
//|                     News_Filter.mqh                              |
//|                     TFlab New EA V.5                                 |
//|                                                                  |
//| مسئولیت: فیلتر کردن ورود در زمان رویدادهای اقتصادی             |
//|                                                                  |
//| منطق:                                                            |
//| - استفاده از تقویم اقتصادی متاتریدر (CalendarValueHistory)       |
//| - بررسی زمان رویداد در بازه زمانی مشخص                          |
//| - در بک‌تست به‌صورت خودکار غیرفعال می‌شود                        |
//|                                                                  |
//| v2.3 - نسخه نهایی بدون وابستگی به فیلدهای خاص                  |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// بررسی نزدیکی رویدادهای اقتصادی
//====================================================================
bool NewsFilter_IsHighImpactNear(
   const string symbol,
   const int minutes_before,
   const int minutes_after,
   string &reason)
  {
   reason = "";

   //=================================================================
   // در بک‌تست، تقویم اقتصادی در دسترس نیست
   //=================================================================
   if(MQLInfoInteger(MQL_TESTER))
     {
      reason = "فیلتر خبر در بک‌تست غیرفعال است";
      return false;
     }

   //=================================================================
   // بازه زمانی: از minutes_before قبل تا minutes_after بعد
   //=================================================================
   datetime from = TimeCurrent() - (datetime)(minutes_before * 60);
   datetime to   = TimeCurrent() + (datetime)(minutes_after * 60);

   //=================================================================
   // خواندن تقویم اقتصادی
   //=================================================================
   MqlCalendarValue values[];
   ArrayResize(values, 0);

   int count = CalendarValueHistory(values, from, to);

   if(count <= 0)
     {
      reason = "داده خبر در دسترس نیست یا تقویم اقتصادی خالی است";
      return false;
     }

   //=================================================================
   // بررسی رویدادها در بازه زمانی
   //=================================================================
   for(int i = 0; i < count; i++)
     {
      long minutes_to_news = (long)((values[i].time - TimeCurrent()) / 60);

      reason = "رویداد اقتصادی در بازه زمانی شناسایی شد"
               + " | زمان=" + TimeToString(values[i].time, TIME_DATE | TIME_MINUTES)
               + " | دقیقه تا خبر=" + IntegerToString(minutes_to_news);

      Print("[NEWS_FILTER] BLOCK"
            + " | Time=" + TimeToString(values[i].time, TIME_DATE | TIME_MINUTES)
            + " | MinutesToNews=" + IntegerToString(minutes_to_news));

      return true;
     }

   reason = "رویداد اقتصادی در بازه زمانی پیدا نشد";
   return false;
  }

#endif // __TFLAB_NEWS_FILTER_MQH__