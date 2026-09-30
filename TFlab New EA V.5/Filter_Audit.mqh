#ifndef __TFLAB_FILTER_AUDIT_MQH__
#define __TFLAB_FILTER_AUDIT_MQH__

//+------------------------------------------------------------------+
//|                     Filter_Audit.mqh                             |
//|                     TFlab New EA V.5                                 |
//|                                                                  |
//| مسئولیت: ثبت و گزارش‌دهی وضعیت فیلترهای تحلیل بازار              |
//|                                                                  |
//| v2.1 - افزایش ظرفیت + مقداردهی ایمن + لاگ زمان                  |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// نتیجه ممیزی هر فیلتر
//====================================================================
enum ENUM_AUDIT_RESULT
  {
   AUDIT_INFO  = 0,
   AUDIT_PASS  = 1,
   AUDIT_BLOCK = -1
  };

//====================================================================
// یک آیتم ممیزی
//====================================================================
struct FilterAuditItem
  {
   string              name;
   ENUM_AUDIT_RESULT   result;
   string              reason;
  };

//====================================================================
// وضعیت کلی ممیزی
// [اصلاح] افزایش ظرفیت آرایه به 16
//====================================================================
struct FilterAuditState
  {
   datetime            time;
   FilterAuditItem     items[16];
   int                 count;
   int                 pass_count;
   int                 block_count;
   int                 info_count;
   string              blockers;
  };

//====================================================================
// آمار تجمعی ممیزی‌ها
//====================================================================
struct FilterAuditTotals
  {
   ulong               cycles;
   ulong               pass_count;
   ulong               block_count;
   ulong               info_count;
  };

FilterAuditTotals g_filter_audit_totals;

//====================================================================
// مقداردهی اولیه
// [اصلاح] مقداردهی دستی فیلدهای رشته‌ای به جای ZeroMemory
//====================================================================
void FilterAudit_Reset(FilterAuditState &a)
  {
   a.time        = 0;
   a.count       = 0;
   a.pass_count  = 0;
   a.block_count = 0;
   a.info_count  = 0;
   a.blockers    = "";

   for(int i = 0; i < 16; i++)
     {
      a.items[i].name   = "";
      a.items[i].result = AUDIT_INFO;
      a.items[i].reason = "";
     }
  }

void FilterAudit_ResetTotals()
  {
   ZeroMemory(g_filter_audit_totals);
  }

//====================================================================
// تبدیل نتیجه به متن فارسی
//====================================================================
string FilterAudit_ResultText(const ENUM_AUDIT_RESULT r)
  {
   if(r == AUDIT_PASS)  return "تأیید";
   if(r == AUDIT_BLOCK) return "مسدود";
   return "اطلاعاتی";
  }

//====================================================================
// افزودن یک فیلتر به ممیزی
// [اصلاح] هشدار در صورت پر شدن ظرفیت
//====================================================================
void FilterAudit_Add(
   FilterAuditState &a,
   const string name,
   const ENUM_AUDIT_RESULT r,
   const string reason)
  {
   //--- بررسی ظرفیت آرایه
   if(a.count >= 16)
     {
      Print(
         "[FILTER_AUDIT] هشدار | ظرفیت آرایه ممیزی پر شده است | ",
         "نام فیلتر رد شده=", name,
         " | ظرفیت=", 16
      );
      return;
     }

   a.items[a.count].name   = name;
   a.items[a.count].result = r;
   a.items[a.count].reason = reason;
   a.count++;

   if(r == AUDIT_PASS)
     {
      a.pass_count++;
      g_filter_audit_totals.pass_count++;
     }
   else if(r == AUDIT_BLOCK)
     {
      a.block_count++;
      g_filter_audit_totals.block_count++;

      if(a.blockers != "")
         a.blockers += " | ";
      a.blockers += name;
     }
   else
     {
      a.info_count++;
      g_filter_audit_totals.info_count++;
     }
  }

//====================================================================
// خلاصه ممیزی
//====================================================================
string FilterAudit_Summary(const FilterAuditState &a)
  {
   string text = "فیلترها: " +
                 IntegerToString(a.pass_count) + " تأیید | " +
                 IntegerToString(a.block_count) + " مسدود | " +
                 IntegerToString(a.info_count) + " اطلاعاتی";

   if(a.blockers != "")
      text += " | مسدودکننده‌ها: " + a.blockers;
   else
      text += " | بدون مسدودکننده";

   return text;
  }

//====================================================================
// چاپ کامل ممیزی
// [اصلاح] افزودن زمان ممیزی به خروجی
//====================================================================
void FilterAudit_Print(const FilterAuditState &a)
  {
   g_filter_audit_totals.cycles++;

   Print("========== ممیزی کامل فیلترها ==========");

   //--- [جدید] چاپ زمان ممیزی
   if(a.time > 0)
      Print(
         "[ممیزی] زمان=",
         TimeToString(a.time, TIME_DATE | TIME_SECONDS)
      );

   for(int i = 0; i < a.count; i++)
     {
      Print(
         "[ممیزی] ",
         a.items[i].name,
         " = ",
         FilterAudit_ResultText(a.items[i].result),
         " | ",
         a.items[i].reason
      );
     }

   Print("[ممیزی نهایی] ", FilterAudit_Summary(a));

   Print(
      "[ممیزی تجمعی] چرخه=",
      (string)g_filter_audit_totals.cycles,
      " | تأیید=",
      (string)g_filter_audit_totals.pass_count,
      " | مسدود=",
      (string)g_filter_audit_totals.block_count,
      " | اطلاعاتی=",
      (string)g_filter_audit_totals.info_count
   );

   Print("=======================================");
  }

#endif // __TFLAB_FILTER_AUDIT_MQH__