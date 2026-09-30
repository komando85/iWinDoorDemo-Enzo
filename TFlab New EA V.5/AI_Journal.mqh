#ifndef __TFLAB_AI_JOURNAL_MQH__
#define __TFLAB_AI_JOURNAL_MQH__
#property strict

#include "EA_Inputs.mqh"
#include "Market_Regime.mqh"
#include "Market_Structure.mqh"
#include "Divergence_Detector.mqh"
#include "Report_Word_Engine.mqh"

//+------------------------------------------------------------------+
//|                        AI_Journal.mqh                            |
//|                        TFlab New EA V.5                          |
//|                                                                  |
//| مسئولیت: ثبت ریزبه‌ریز هر تصمیم تحلیلی (چه اجرا شده چه رد شده)   |
//| با تمام امتیازهای فیلترها، و به‌روزرسانی آن با نتیجه نهایی      |
//| معامله.                                                          |
//|                                                                  |
//| خروجی‌ها:                                                        |
//| 1) CSV دائمی برای تحلیل بلندمدت                                  |
//| 2) CSV روزانه Unicode برای Excel                                |
//|                                                                  |
//| نکته: گزارش روزانه قبلاً RTF بود و برای فارسی قابل‌خواندن نبود.  |
//| اکنون مستقیماً CSV Unicode تولید می‌شود.                        |
//+------------------------------------------------------------------+

enum ENUM_AI_JOURNAL_DECISION
  {
   AI_JOURNAL_FORMED = 0,           // سناریو با موفقیت ساخته شد
   AI_JOURNAL_EXECUTED,             // معامله واقعی/مجازی اجرا شد
   AI_JOURNAL_REJECTED_CANDIDATE,   // حتی نامزد اولیه هم شکل نگرفت
   AI_JOURNAL_REJECTED_STRATEGY,    // نامزد بود اما Strategy Engine نتوانست بسازد
   AI_JOURNAL_REJECTED_QUALITY,     // ساخته شد اما کیفیت کافی نبود
   AI_JOURNAL_REJECTED_RISK,        // آماده اجرا بود اما ریسک تأیید نشد
   AI_JOURNAL_REJECTED_NEWS,        // به دلیل خبر مهم رد شد
   AI_JOURNAL_REJECTED_OTHER        // سایر موارد
  };

//+------------------------------------------------------------------+
//| ساختار یک رکورد ژورنال                                            |
//+------------------------------------------------------------------+
struct AIJournalEntry
  {
   ulong    scenario_id;
   datetime decision_time;
   string   direction;

   double   entry_price;

   //--- امتیاز و وضعیت فیلترها در لحظه تصمیم
   string   regime_state;
   double   regime_confidence;
   bool     regime_exhausted;

   string   structure_state;
   int      swing_streak;

   bool     htf_aligned;
   string   divergence;

   double   confluence_score;
   double   quality_score;

   ENUM_AI_JOURNAL_DECISION decision;
   string   decision_reason;

   //--- نتیجه نهایی
   bool     closed;
   datetime close_time;
   double   close_price;
   double   profit;
   string   close_reason;
  };

//+------------------------------------------------------------------+
//| حافظه ژورنال                                                      |
//+------------------------------------------------------------------+
AIJournalEntry g_ai_journal[];

int g_ai_journal_max_entries = 3000;

//+------------------------------------------------------------------+
//| متن فارسی نوع تصمیم                                               |
//+------------------------------------------------------------------+
string AIJournal_DecisionToPersian(
   const ENUM_AI_JOURNAL_DECISION d)
  {
   switch(d)
     {
      case AI_JOURNAL_FORMED:
         return "سناریو تشکیل شد";

      case AI_JOURNAL_EXECUTED:
         return "اجرا شد";

      case AI_JOURNAL_REJECTED_CANDIDATE:
         return "رد شد (نامزد اولیه)";

      case AI_JOURNAL_REJECTED_STRATEGY:
         return "رد شد (Strategy)";

      case AI_JOURNAL_REJECTED_QUALITY:
         return "رد شد (کیفیت)";

      case AI_JOURNAL_REJECTED_RISK:
         return "رد شد (ریسک)";

      case AI_JOURNAL_REJECTED_NEWS:
         return "رد شد (خبر)";

      default:
         return "رد شد (سایر)";
     }
  }

//+------------------------------------------------------------------+
//| مسیر فایل CSV دائمی                                               |
//+------------------------------------------------------------------+
string AIJournal_CSVFileName()
  {
   return "TFlab_AI_Journal.csv";
  }

//+------------------------------------------------------------------+
//| افزودن یک ردیف به CSV دائمی                                       |
//+------------------------------------------------------------------+
void AIJournal_AppendCSVRow(
   const AIJournalEntry &e)
  {
   ResetLastError();

   int h = FileOpen(
      AIJournal_CSVFileName(),
      FILE_READ |
      FILE_WRITE |
      FILE_CSV |
      FILE_SHARE_READ |
      FILE_SHARE_WRITE,
      ';'
   );

   if(h == INVALID_HANDLE)
     {
      Print(
         "[AI JOURNAL] ERROR | Cannot open CSV | Error=",
         GetLastError()
      );
      return;
     }

   bool is_new = (FileSize(h) == 0);

   FileSeek(
      h,
      0,
      SEEK_END
   );

   if(is_new)
     {
      FileWrite(
         h,
         "ScenarioID",
         "DecisionTime",
         "Direction",
         "Entry",
         "RegimeState",
         "RegimeConfidence",
         "RegimeExhausted",
         "StructureState",
         "SwingStreak",
         "HTFAligned",
         "Divergence",
         "ConfluenceScore",
         "QualityScore",
         "Decision",
         "DecisionReason",
         "Closed",
         "CloseTime",
         "ClosePrice",
         "Profit",
         "CloseReason"
      );
     }

   FileWrite(
      h,

      (string)e.scenario_id,

      TimeToString(
         e.decision_time,
         TIME_DATE | TIME_SECONDS
      ),

      e.direction,

      DoubleToString(
         e.entry_price,
         _Digits
      ),

      e.regime_state,

      DoubleToString(
         e.regime_confidence,
         1
      ),

      (e.regime_exhausted ? "YES" : "NO"),

      e.structure_state,

      (string)e.swing_streak,

      (e.htf_aligned ? "YES" : "NO"),

      e.divergence,

      DoubleToString(
         e.confluence_score,
         1
      ),

      DoubleToString(
         e.quality_score,
         1
      ),

      AIJournal_DecisionToPersian(
         e.decision
      ),

      e.decision_reason,

      (e.closed ? "YES" : "NO"),

      (e.closed
       ? TimeToString(
            e.close_time,
            TIME_DATE | TIME_SECONDS
         )
       : ""),

      (e.closed
       ? DoubleToString(
            e.close_price,
            _Digits
         )
       : ""),

      (e.closed
       ? DoubleToString(
            e.profit,
            2
         )
       : ""),

      (e.closed
       ? e.close_reason
       : "")
   );

   FileClose(h);
  }

//+------------------------------------------------------------------+
//| Escape متن برای CSV                                              |
//| برای فایل روزانه Excel                                           |
//+------------------------------------------------------------------+
string AIJournal_CSVEscape(
   const string value)
  {
   string s = value;

   //--- جلوگیری از شکستن CSV در صورت وجود "
   StringReplace(
      s,
      "\"",
      "\"\""
   );

   return "\"" + s + "\"";
  }

//+------------------------------------------------------------------+
//| ثبت یک تصمیم جدید                                                 |
//| مقدار بازگشتی = اندیس ثبت‌شده                                    |
//+------------------------------------------------------------------+
int AIJournal_LogDecision(
   const ulong scenario_id,
   const string direction,
   const double entry_price,
   const ENUM_MARKET_REGIME regime_state,
   const double regime_confidence,
   const bool regime_exhausted,
   const ENUM_STRUCTURE_STATE structure_state,
   const int swing_streak,
   const bool htf_aligned,
   const ENUM_DIVERGENCE_TYPE divergence,
   const double confluence_score,
   const double quality_score,
   const ENUM_AI_JOURNAL_DECISION decision,
   const string decision_reason)
  {
   int n = ArraySize(
      g_ai_journal
   );

   //--- کنترل سقف حافظه
   if(n >= g_ai_journal_max_entries)
     {
      int drop =
         g_ai_journal_max_entries / 5;

      for(int i = 0; i < n - drop; i++)
         g_ai_journal[i] =
            g_ai_journal[i + drop];

      ArrayResize(
         g_ai_journal,
         n - drop
      );

      n = ArraySize(
         g_ai_journal
      );
     }

   ArrayResize(
      g_ai_journal,
      n + 1
   );

   AIJournalEntry e;

   e.scenario_id      = scenario_id;
   e.decision_time    = TimeCurrent();
   e.direction        = direction;
   e.entry_price      = entry_price;

   e.regime_state     =
      MarketRegime_ToCode(
         regime_state
      );

   e.regime_confidence =
      regime_confidence;

   e.regime_exhausted =
      regime_exhausted;

   e.structure_state =
      MarketStructure_StateToCode(
         structure_state
      );

   e.swing_streak =
      swing_streak;

   e.htf_aligned =
      htf_aligned;

   e.divergence =
      DivergenceTypeToPersian(
         divergence
      );

   e.confluence_score =
      confluence_score;

   e.quality_score =
      quality_score;

   e.decision =
      decision;

   e.decision_reason =
      decision_reason;

   e.closed =
      false;

   e.close_time =
      0;

   e.close_price =
      0.0;

   e.profit =
      0.0;

   e.close_reason =
      "";

   g_ai_journal[n] =
      e;

   //--- ثبت در CSV دائمی
   AIJournal_AppendCSVRow(
      e
   );

   return n;
  }

//+------------------------------------------------------------------+
//| علامت‌گذاری سناریو به‌عنوان اجراشده                               |
//+------------------------------------------------------------------+
void AIJournal_MarkExecuted(
   const ulong scenario_id)
  {
   int n =
      ArraySize(
         g_ai_journal
      );

   for(int i = n - 1; i >= 0; i--)
     {
      if(g_ai_journal[i].scenario_id == scenario_id &&
         !g_ai_journal[i].closed)
        {
         g_ai_journal[i].decision =
            AI_JOURNAL_EXECUTED;

         AIJournal_AppendCSVRow(
            g_ai_journal[i]
         );

         return;
        }
     }
  }

//+------------------------------------------------------------------+
//| ثبت نتیجه نهایی سناریو                                           |
//+------------------------------------------------------------------+
void AIJournal_MarkClosed(
   const ulong scenario_id,
   const double close_price,
   const double profit,
   const string close_reason)
  {
   int n =
      ArraySize(
         g_ai_journal
      );

   for(int i = n - 1; i >= 0; i--)
     {
      if(g_ai_journal[i].scenario_id == scenario_id &&
         !g_ai_journal[i].closed)
        {
         g_ai_journal[i].closed =
            true;

         g_ai_journal[i].close_time =
            TimeCurrent();

         g_ai_journal[i].close_price =
            close_price;

         g_ai_journal[i].profit =
            profit;

         g_ai_journal[i].close_reason =
            close_reason;

         AIJournal_AppendCSVRow(
            g_ai_journal[i]
         );

         return;
        }
     }
  }

//+------------------------------------------------------------------+
//| ساخت گزارش روزانه AI Journal برای Excel                          |
//| خروجی: CSV Unicode                                                |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ساخت یک بلوک RTF برای یک ورودی ژورنال (جزئیات کامل یک تصمیم)     |
//| [بازگردانده شد] این تابع قبلاً حذف شده بود و جزئیات ریزبه‌ریز      |
//| دیگر هیچ‌جا نمایش داده نمی‌شد - طبق درخواست کاربر بازسازی شد.      |
//+------------------------------------------------------------------+
string AIJournal_BuildEntryRTF(const AIJournalEntry &e)
  {
   string result_txt = "-";
   if(e.closed)
      result_txt = RTF_ColoredNum(e.profit, 2) + " (" + RTF_EscapeFa(e.close_reason) + ")";
   else if(e.decision == AI_JOURNAL_EXECUTED)
      result_txt = "\\cf4 در حال اجرا \\cf1 ";

   string dir_fa = (e.direction == "BUY" ? "خرید" : (e.direction == "SELL" ? "فروش" : e.direction));

   string row = RTF_Section(
      TimeToString(e.decision_time, TIME_DATE | TIME_MINUTES) +
      " | " + dir_fa + " | " + AIJournal_DecisionToPersian(e.decision));

   row += RTF_Line("Entry", RTF_Num(e.entry_price, _Digits));
   row += RTF_Line("رژیم بازار", RTF_EscapeFa(e.regime_state) +
      " (اطمینان " + RTF_Num(e.regime_confidence, 1) + "%" +
      (e.regime_exhausted ? " - خسته" : "") + ")");
   row += RTF_Line("ساختار", RTF_EscapeFa(e.structure_state) +
      " | Streak=" + IntegerToString(e.swing_streak));
   row += RTF_Line("هم‌جهتی HTF", (e.htf_aligned ? "بله" : "خیر"));
   row += RTF_Line("واگرایی RSI", RTF_EscapeFa(e.divergence));
   row += RTF_Line("امتیاز Confluence", RTF_Num(e.confluence_score, 1));
   row += RTF_Line("امتیاز کیفیت نهایی", RTF_Num(e.quality_score, 1));
   row += RTF_Line("دلیل تصمیم", RTF_EscapeFa(e.decision_reason));
   row += RTF_Line("نتیجه", result_txt);
   row += "\\pard\\par ";
   row += RTF_Separator();

   return row;
  }

//+------------------------------------------------------------------+
//| ساخت بخش ژورنال ریزبه‌ریز برای الحاق مستقیم به گزارش روزانه Word  |
//| [جدید] طبق درخواست کاربر: این بخش دیگر فایل جدا نیست، مستقیماً    |
//| داخل همان فایل TFlab_Report_Daily_*.rtf قرار می‌گیرد.              |
//+------------------------------------------------------------------+
string AIJournal_BuildWordSection()
  {
   MqlDateTime day;
   TimeToStruct(TimeCurrent(), day);
   day.hour = 0; day.min = 0; day.sec = 0;
   datetime start_of_day = StructToTime(day);

   int n = ArraySize(g_ai_journal);
   int today_count = 0, executed_count = 0, rejected_count = 0;
   double today_net = 0.0;

   for(int i = 0; i < n; i++)
     {
      if(g_ai_journal[i].decision_time < start_of_day) continue;
      today_count++;
      if(g_ai_journal[i].decision == AI_JOURNAL_EXECUTED) executed_count++;
      else rejected_count++;
      if(g_ai_journal[i].closed) today_net += g_ai_journal[i].profit;
     }

   string body = "";
   body += RTF_Section("ژورنال ریزبه‌ریز تصمیمات هوش مصنوعی (امروز)");
   body += RTF_Line("تعداد کل تصمیمات امروز", IntegerToString(today_count));
   body += RTF_Line("اجرا شده", IntegerToString(executed_count));
   body += RTF_Line("رد شده", IntegerToString(rejected_count));
   body += RTF_Line("سود/ضرر معاملات بسته‌شده امروز", RTF_ColoredNum(today_net, 2));
   body += "\\pard\\par ";
   body += RTF_Separator();

   //--- جدیدترین‌ها اول، حداکثر ۴۰ مورد برای حجم منطقی فایل
   int shown = 0;
   for(int i = n - 1; i >= 0 && shown < 40; i--)
     {
      if(g_ai_journal[i].decision_time < start_of_day) continue;
      body += AIJournal_BuildEntryRTF(g_ai_journal[i]);
      shown++;
     }

   if(shown == 0)
      body += RTF_Line("وضعیت", "هنوز هیچ تصمیمی امروز ثبت نشده است");

   if(today_count > shown)
      body += RTF_Line("توجه", IntegerToString(today_count - shown) +
         " تصمیم دیگر امروز ثبت شده که برای کوتاه ماندن فایل نمایش داده نشد (فایل CSV کامل را ببینید)");

   return body;
  }

void AIJournal_WriteDailyReport()
  {
   //===============================================================
   // تاریخ
   //===============================================================

   MqlDateTime dt;

   TimeToStruct(
      TimeCurrent(),
      dt
   );

   string fn =
      "TFlab_AI_Journal_Daily_" +
      IntegerToString(dt.year) +
      "_" +
      StringFormat(
         "%02d",
         dt.mon
      ) +
      "_" +
      StringFormat(
         "%02d",
         dt.day
      ) +
      ".csv";

   //===============================================================
   // شروع روز
   //===============================================================

   MqlDateTime day;

   TimeToStruct(
      TimeCurrent(),
      day
   );

   day.hour = 0;
   day.min  = 0;
   day.sec  = 0;

   datetime start_of_day =
      StructToTime(
         day
      );

   //===============================================================
   // آمار امروز
   //===============================================================

   int n =
      ArraySize(
         g_ai_journal
      );

   int today_count    = 0;
   int executed_count = 0;
   int rejected_count = 0;

   double today_net = 0.0;

   for(int i = 0; i < n; i++)
     {
      if(g_ai_journal[i].decision_time <
         start_of_day)
         continue;

      today_count++;

      if(g_ai_journal[i].decision ==
         AI_JOURNAL_EXECUTED)
         executed_count++;
      else
         rejected_count++;

      if(g_ai_journal[i].closed)
         today_net +=
            g_ai_journal[i].profit;
     }

   //===============================================================
   // ایجاد فایل Unicode برای Excel
   //===============================================================

   ResetLastError();

   int h =
      FileOpen(
         fn,
         FILE_WRITE |
         FILE_CSV |
         FILE_UNICODE |
         FILE_SHARE_READ |
         FILE_SHARE_WRITE,
         ';'
      );

   if(h == INVALID_HANDLE)
     {
      Print(
         "[AI JOURNAL] ERROR | Cannot create daily Excel CSV | File=",
         fn,
         " | Error=",
         GetLastError()
      );

      return;
     }

   //===============================================================
   // عنوان گزارش
   //===============================================================

   FileWrite(
      h,
      "ژورنال ریزبه‌ریز تصمیمات هوش مصنوعی - روزانه"
   );

   FileWrite(
      h,
      "تاریخ تولید",
      TimeToString(
         TimeCurrent(),
         TIME_DATE | TIME_MINUTES
      )
   );

   FileWrite(
      h,
      ""
   );

   //===============================================================
   // خلاصه امروز
   //===============================================================

   FileWrite(
      h,
      "خلاصه امروز"
   );

   FileWrite(
      h,
      "تعداد کل تصمیمات امروز",
      today_count
   );

   FileWrite(
      h,
      "اجرا شده",
      executed_count
   );

   FileWrite(
      h,
      "رد شده",
      rejected_count
   );

   FileWrite(
      h,
      "سود/ضرر معاملات بسته‌شده امروز",
      DoubleToString(
         today_net,
         2
      )
   );

   FileWrite(
      h,
      ""
   );

   //===============================================================
   // هدر جدول جزئیات
   //===============================================================

   FileWrite(
      h,

      "ScenarioID",
      "زمان تصمیم",
      "جهت",
      "Entry",
      "رژیم بازار",
      "اطمینان رژیم",
      "خستگی رژیم",
      "ساختار",
      "Streak",
      "هم‌جهتی HTF",
      "واگرایی",
      "Confluence",
      "Quality",
      "تصمیم",
      "دلیل تصمیم",
      "بسته شد",
      "زمان بسته‌شدن",
      "قیمت بسته‌شدن",
      "سود/ضرر",
      "دلیل بسته‌شدن"
   );

   //===============================================================
   // جزئیات؛ جدیدترین تصمیم اول
   //===============================================================

   int shown = 0;

   for(int i = n - 1;
       i >= 0 && shown < 150;
       i--)
     {
      AIJournalEntry e =
         g_ai_journal[i];

      if(e.decision_time <
         start_of_day)
         continue;

      FileWrite(
         h,

         (string)e.scenario_id,

         TimeToString(
            e.decision_time,
            TIME_DATE | TIME_MINUTES
         ),

         AIJournal_CSVEscape(
            e.direction
         ),

         DoubleToString(
            e.entry_price,
            _Digits
         ),

         AIJournal_CSVEscape(
            e.regime_state
         ),

         DoubleToString(
            e.regime_confidence,
            1
         ),

         (e.regime_exhausted
          ? "بله"
          : "خیر"),

         AIJournal_CSVEscape(
            e.structure_state
         ),

         e.swing_streak,

         (e.htf_aligned
          ? "بله"
          : "خیر"),

         AIJournal_CSVEscape(
            e.divergence
         ),

         DoubleToString(
            e.confluence_score,
            1
         ),

         DoubleToString(
            e.quality_score,
            1
         ),

         AIJournal_CSVEscape(
            AIJournal_DecisionToPersian(
               e.decision
            )
         ),

         AIJournal_CSVEscape(
            e.decision_reason
         ),

         (e.closed
          ? "بله"
          : "خیر"),

         (e.closed
          ? TimeToString(
               e.close_time,
               TIME_DATE | TIME_MINUTES
            )
          : ""),

         (e.closed
          ? DoubleToString(
               e.close_price,
               _Digits
            )
          : ""),

         (e.closed
          ? DoubleToString(
               e.profit,
               2
            )
          : ""),

         (e.closed
          ? AIJournal_CSVEscape(
               e.close_reason
            )
          : "")
      );

      shown++;
     }

   //===============================================================
   // هیچ تصمیمی ثبت نشده
   //===============================================================

   if(shown == 0)
     {
      FileWrite(
         h,
         "امروز هنوز هیچ تصمیمی ثبت نشده است"
      );
     }

   //===============================================================
   // بستن فایل
   //===============================================================

   FileClose(
      h
   );

   Print(
      "[AI JOURNAL] DAILY EXCEL CSV CREATED | File=",
      fn,
      " | Decisions=",
      today_count,
      " | Executed=",
      executed_count,
      " | Rejected=",
      rejected_count
   );
  }

#endif // __TFLAB_AI_JOURNAL_MQH__