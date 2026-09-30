#ifndef __TFLAB_REPORT_WORD_ENGINE_MQH__
#define __TFLAB_REPORT_WORD_ENGINE_MQH__

//+------------------------------------------------------------------+
//|                  Report_Word_Engine.mqh                          |
//|                  TFlab New EA V.5 - Professional Edition         |
//|                                                                  |
//| مسئولیت: تولید گزارش Daily و Overall به صورت RTF/Word          |
//|                                                                  |
//| ویژگی‌های نسخه جدید:                                             |
//| - ظاهر حرفه‌ای و خوانا                                          |
//| - KPIهای برجسته                                                  |
//| - جدول‌های رنگی و منظم                                           |
//| - تفکیک واضح معاملات واقعی و AI/Virtual                          |
//| - حفظ منطق آماری قبلی                                            |
//| - اتصال آمار AI مستقل بدون تغییر هسته Virtual                    |
//| - فونت گزارش: B Nazanin                                          |
//| - اندازه فونت‌ها برای خوانایی بهتر                              |
//+------------------------------------------------------------------+
#property strict

#include "EA_Inputs.mqh"
#include "Performance_Report.mqh"
#include "Filter_Audit.mqh"
#include "AI_VirtualTrader.mqh"
#include "AI_Independent_Analysis.mqh"

input double Inp_Report_InitialBalance = 200.0;

//====================================================================
// ساختارهای آماری
//====================================================================
struct DirectionalStats
  {
   int    trades;
   int    wins;
   int    losses;
   double profit;
   double best_trade;
   double worst_trade;
  };

struct AIJournalStats
  {
   int real_decisions;
   int rejected_decisions;
   int real_wins;
   int real_losses;
   int rejected_if_win;
   int rejected_if_loss;
  };

//====================================================================
// آمار معاملات مجازی AI
//====================================================================
struct AIVirtualReportStats
  {
   int    planned;
   int    opened;
   int    closed;
   int    wins;
   int    losses;
   int    breakeven;

   double gross_profit;
   double gross_loss;
   double net_profit;
   double win_rate;
   double profit_factor;
  };

//====================================================================
// آمار معاملات مجازی AI مستقل
//====================================================================
struct AIIndependentReportStats
  {
   int    opened;
   int    open_now;
   int    closed;
   int    wins;
   int    losses;
   int    breakeven;

   double total_profit_r;
   double total_loss_r;
   double net_r;
   double win_rate;
   double profit_factor;

   int    agree_with_bot;
   int    disagree_with_bot;
  };

//====================================================================
// محاسبه آمار AI از آرایه معاملات مجازی
//====================================================================
void ReportWord_ComputeAIStats(
   const AIVirtualTrade &trades[],
   const int trade_count,
   const datetime from,
   const datetime to,
   AIVirtualReportStats &stats)
  {
   stats.planned       = 0;
   stats.opened        = 0;
   stats.closed        = 0;
   stats.wins          = 0;
   stats.losses        = 0;
   stats.breakeven     = 0;
   stats.gross_profit  = 0.0;
   stats.gross_loss    = 0.0;
   stats.net_profit    = 0.0;
   stats.win_rate      = 0.0;
   stats.profit_factor = 0.0;

   for(int i=0; i<trade_count; i++)
     {
      if(trades[i].decision_time >= from &&
         trades[i].decision_time <= to)
         stats.planned++;

      if(trades[i].open_time >= from &&
         trades[i].open_time <= to)
         stats.opened++;

      if(trades[i].close_time >= from &&
         trades[i].close_time <= to)
        {
         stats.closed++;

         double pnl = trades[i].net_profit;

         stats.net_profit += pnl;

         if(pnl > 0.0)
           {
            stats.wins++;
            stats.gross_profit += pnl;
           }
         else
         if(pnl < 0.0)
           {
            stats.losses++;
            stats.gross_loss += MathAbs(pnl);
           }
         else
           {
            stats.breakeven++;
           }
        }
     }

   if(stats.closed > 0)
      stats.win_rate =
         100.0 * (double)stats.wins /
         (double)stats.closed;

   if(stats.gross_loss > 0.0)
      stats.profit_factor =
         stats.gross_profit /
         stats.gross_loss;
   else
   if(stats.gross_profit > 0.0)
      stats.profit_factor = 9999.0;
   else
      stats.profit_factor = 0.0;
  }

//====================================================================
// محاسبه آمار AI مستقل
//
// آمار مستقیماً از آرایه سراسری g_ai_ind_trades خوانده می‌شود.
// سود/ضرر با واحد R گزارش می‌شود.
//====================================================================
void ReportWord_ComputeAIIndependentStats(
   const datetime from,
   const datetime to,
   const bool filter_by_period,
   AIIndependentReportStats &stats)
  {
   stats.opened             = 0;
   stats.open_now           = 0;
   stats.closed             = 0;
   stats.wins               = 0;
   stats.losses             = 0;
   stats.breakeven          = 0;

   stats.total_profit_r     = 0.0;
   stats.total_loss_r       = 0.0;
   stats.net_r              = 0.0;
   stats.win_rate           = 0.0;
   stats.profit_factor      = 0.0;

   stats.agree_with_bot     = 0;
   stats.disagree_with_bot  = 0;

   const int trade_count =
      ArraySize(g_ai_ind_trades);

   //===============================================================
   // پیمایش معاملات AI مستقل
   //===============================================================
   for(int i=0; i<trade_count; i++)
     {
      bool in_open =
         (g_ai_ind_trades[i].open_time > 0 &&
          g_ai_ind_trades[i].open_time >= from &&
          g_ai_ind_trades[i].open_time <= to);

      bool in_close =
         (g_ai_ind_trades[i].close_time > 0 &&
          g_ai_ind_trades[i].close_time >= from &&
          g_ai_ind_trades[i].close_time <= to);

      bool in_any =
         in_open || in_close;

      if(filter_by_period && !in_any)
         continue;

      //============================================================
      // OPEN
      //============================================================
      if(in_open)
         stats.opened++;

      //============================================================
      // OPEN NOW
      //============================================================
      if(!g_ai_ind_trades[i].closed &&
         g_ai_ind_trades[i].open_time > 0)
        {
         if(!filter_by_period || in_open)
            stats.open_now++;
        }

      //============================================================
      // توافق با جهت ربات در زمان ورود
      //============================================================
      if(g_ai_ind_trades[i].open_time > 0)
        {
         if(g_ai_ind_trades[i].bot_direction_at_entry == "BUY" ||
            g_ai_ind_trades[i].bot_direction_at_entry == "SELL")
           {
            if(g_ai_ind_trades[i].bot_direction_at_entry ==
               g_ai_ind_trades[i].direction)
               stats.agree_with_bot++;
            else
               stats.disagree_with_bot++;
           }
         else
           {
            stats.disagree_with_bot++;
           }
        }

      //============================================================
      // فقط معاملات بسته‌شده
      //============================================================
      if(!g_ai_ind_trades[i].closed)
         continue;

      if(!in_close && filter_by_period)
         continue;

      stats.closed++;

      double r =
         g_ai_ind_trades[i].result_r;

      stats.net_r += r;

      if(r > 0.0)
        {
         stats.wins++;
         stats.total_profit_r += r;
        }
      else
      if(r < 0.0)
        {
         stats.losses++;
         stats.total_loss_r += MathAbs(r);
        }
      else
        {
         stats.breakeven++;
        }
     }

   //===============================================================
   // Win Rate
   //===============================================================
   int outcomes =
      stats.wins +
      stats.losses +
      stats.breakeven;

   if(outcomes > 0)
      stats.win_rate =
         100.0 *
         (double)stats.wins /
         (double)outcomes;

   //===============================================================
   // Profit Factor
   //===============================================================
   if(stats.total_loss_r > 0.0)
      stats.profit_factor =
         stats.total_profit_r /
         stats.total_loss_r;
   else
   if(stats.total_profit_r > 0.0)
      stats.profit_factor =
         9999.0;
   else
      stats.profit_factor =
         0.0;
  }

//====================================================================
// ابزارهای عمومی RTF
//====================================================================
string RTF_EscapeFa(const string text)
  {
   string res = "";
   int len = StringLen(text);

   for(int i = 0; i < len; i++)
     {
      int c = StringGetCharacter(text, i);

      if(c == 92)
         res += "\\\\";
      else
      if(c == 123)
         res += "\\{";
      else
      if(c == 125)
         res += "\\}";
      else
      if(c == 13 || c == 10)
        {
         if(c == 10)
            res += "\\par ";
        }
      else
      if(c >= 32 && c <= 126)
         res += ShortToString((ushort)c);
      else
        {
         int unicode_value = c;

         if(unicode_value > 32767)
            unicode_value -= 65536;

         res +=
            "\\u" +
            IntegerToString(unicode_value) +
            "?";
        }
     }

   return res;
  }

string RTF_Num(
   const double v,
   const int d=2)
  {
   return DoubleToString(v,d);
  }

//====================================================================
// رنگ‌ها
//====================================================================
string RTF_ColorTable()
  {
   return "{\\colortbl;"
          "\\red0\\green0\\blue0;"
          "\\red39\\green174\\blue96;"
          "\\red192\\green57\\blue43;"
          "\\red255\\green255\\blue255;"
          "\\red244\\green246\\blue248;"
          "\\red35\\green55\\blue75;"
          "\\red52\\green152\\blue219;"
          "\\red46\\green204\\blue113;"
          "\\red231\\green76\\blue60;"
          "\\red255\\green247\\blue230;"
          "\\red230\\green239\\blue249;"
          "\\red235\\green248\\blue239;"
          "\\red252\\green237\\blue237;"
          "\\red236\\green236\\blue236;"
          "}";
  }

//====================================================================
// رنگ متن برای عدد
//====================================================================
string RTF_NumberColor(
   const double v)
  {
   if(v > 0.0)
      return "\\cf2 ";

   if(v < 0.0)
      return "\\cf3 ";

   return "\\cf1 ";
  }

string RTF_ColoredNum(
   const double v,
   const int d=2)
  {
   return
      RTF_NumberColor(v) +
      "\\b " +
      RTF_Num(v,d) +
      "\\b0\\cf1 ";
  }

//====================================================================
// هدر اصلی
//====================================================================
string RTF_MainHeader(
   string title,
   string subtitle)
  {
   string date_text =
      TimeToString(TimeCurrent(),TIME_DATE);

   string time_text =
      TimeToString(TimeCurrent(),TIME_MINUTES);

   string body = "";

   // عنوان اصلی: 20pt
   body +=
      "\\pard\\rtlpar\\qc"
      "\\cbpat6\\cf4\\b\\f1\\fs40 "
      +
      RTF_EscapeFa(title)
      +
      "\\b0\\fs24\\par ";

   // زیرعنوان: 14pt
   body +=
      "\\pard\\rtlpar\\qc"
      "\\cbpat6\\cf4\\f1\\fs28 "
      +
      RTF_EscapeFa(subtitle)
      +
      "\\par ";

   // تاریخ/ساعت: 12pt
   body +=
      "\\pard\\rtlpar\\qc"
      "\\cbpat6\\cf4\\f1\\fs24 "
      +
      RTF_EscapeFa(
         "تاریخ گزارش: " +
         date_text +
         "    |    ساعت: " +
         time_text +
         "    |    MagicNumber: " +
         IntegerToString(Inp_MagicNumber)
      )
      +
      "\\par ";

   // نام سیستم: 11pt
   body +=
      "\\pard\\rtlpar\\qc"
      "\\cbpat6\\cf4\\f1\\fs22 "
      +
      RTF_EscapeFa(
         "TFlab New EA V.5 Professional"
      )
      +
      "\\par\\par ";

   return body;
  }

//====================================================================
// عنوان بخش
//====================================================================
string RTF_SectionHeader(
   string title)
  {
   // 15pt
   return
      "\\pard\\rtlpar\\qr"
      "\\cbpat5\\cf6\\b\\f1\\fs30 "
      +
      RTF_EscapeFa(title)
      +
      "\\b0\\cf1\\f1\\fs24\\par ";
  }

//====================================================================
// زیرعنوان
//====================================================================
string RTF_SubSection(
   string title)
  {
   // 13pt
   return
      "\\pard\\rtlpar\\qr"
      "\\cf7\\b\\f1\\fs26 "
      +
      RTF_EscapeFa(title)
      +
      "\\b0\\cf1\\f1\\fs24\\par ";
  }

//====================================================================
// جعبه اطلاع‌رسانی
//====================================================================
string RTF_InfoBox(
   string text)
  {
   // 12pt
   return
      "\\pard\\rtlpar\\qr"
      "\\cbpat11\\cf6\\b\\f1\\fs24 "
      +
      RTF_EscapeFa(text)
      +
      "\\b0\\cf1\\f1\\fs24\\par\\par ";
  }

//====================================================================
// جعبه موفقیت
//====================================================================
string RTF_SuccessBox(
   string text)
  {
   // 12pt
   return
      "\\pard\\rtlpar\\qr"
      "\\cbpat12\\cf2\\b\\f1\\fs24 "
      +
      RTF_EscapeFa(text)
      +
      "\\b0\\cf1\\f1\\fs24\\par\\par ";
  }

//====================================================================
// جعبه هشدار
//====================================================================
string RTF_WarningBox(
   string text)
  {
   // 12pt
   return
      "\\pard\\rtlpar\\qr"
      "\\cbpat10\\cf3\\b\\f1\\fs24 "
      +
      RTF_EscapeFa(text)
      +
      "\\b0\\cf1\\f1\\fs24\\par\\par ";
  }

//====================================================================
// جداکننده
//====================================================================
string RTF_Separator()
  {
   return
      "\\pard\\rtlpar\\qr"
      "\\f1\\fs8 "
      "\\par ";
  }

//====================================================================
// توابع سازگاری مورد استفاده در AI_Journal
//====================================================================
string RTF_Section(
   const string title)
  {
   return RTF_SectionHeader(title);
  }

string RTF_Line(
   const string key,
   const string value_rtf)
  {
   string val = value_rtf;

   if(
      StringLen(val) == 0 ||
      StringGetCharacter(val,0) != 92
   )
      val = RTF_EscapeFa(val);

   return RTF_Table2ColRaw(
      key,
      val
   );
  }

//====================================================================
// جدول دو ستونی
//====================================================================
string RTF_Table2ColRaw(
   const string key,
   const string val_rtf,
   const string key_color="\\cf6 ")
  {
   string row =
      "\\trowd\\trautofit1\\rtlrow"
      "\\trrh440"
      "\\clbrdrt\\brdrs\\clbrdrb\\brdrs\\clbrdrl\\brdrs\\clbrdrr\\brdrs"
      "\\clcbpat5\\cellx3900"
      "\\clbrdrt\\brdrs\\clbrdrb\\brdrs\\clbrdrl\\brdrs\\clbrdrr\\brdrs"
      "\\clcbpat4\\cellx8500";

   // متن کلید: 12pt
   row +=
      "\\pard\\intbl\\rtlpar\\qr"
      "\\f1\\fs24 "
      +
      key_color +
      "\\b "
      +
      RTF_EscapeFa(key)
      +
      "\\b0\\cf1\\cell ";

   // مقدار: 12pt
   row +=
      "\\pard\\intbl\\rtlpar\\qr"
      "\\f1\\fs24 "
      +
      val_rtf +
      "\\cell ";

   row += "\\row ";

   return row;
  }

//====================================================================
// جدول دو ستونی معمولی
//====================================================================
string RTF_Table2Col(
   string key,
   string val,
   string val_color="\\cf1 ")
  {
   return
      RTF_Table2ColRaw(
         key,
         val_color +
         RTF_EscapeFa(val) +
         "\\cf1 "
      );
  }

//====================================================================
// کارت KPI
//====================================================================
string RTF_KPICard(
   const string title,
   const string value,
   const string color_rtf="\\cf7 ")
  {
   string row =
      "\\trowd\\trautofit1\\rtlrow"
      "\\trrh700"
      "\\clbrdrt\\brdrs\\clbrdrb\\brdrs\\clbrdrl\\brdrs\\clbrdrr\\brdrs"
      "\\clcbpat5\\cellx2800"
      "\\clbrdrt\\brdrs\\clbrdrb\\brdrs\\clbrdrl\\brdrs\\clbrdrr\\brdrs"
      "\\clcbpat4\\cellx8500";

   // عنوان KPI: 12pt
   row +=
      "\\pard\\intbl\\rtlpar\\qc"
      "\\f1\\fs24\\cf6\\b "
      +
      RTF_EscapeFa(title)
      +
      "\\b0\\cell ";

   // مقدار KPI: 17pt
   row +=
      "\\pard\\intbl\\rtlpar\\qc"
      "\\f1\\fs34 "
      +
      color_rtf +
      "\\b "
      +
      RTF_EscapeFa(value)
      +
      "\\b0\\cf1\\cell ";

   row += "\\row ";

   return row;
  }

//====================================================================
// جدول چند ستونی
//====================================================================
string RTF_TableRow(
   string c1,
   string c2,
   string c3,
   string c4,
   string c5,
   string c6,
   bool is_header)
  {
   string bg  =
      is_header
      ? "\\clcbpat6"
      : "\\clcbpat4";

   string txt =
      is_header
      ? "\\cf4\\b "
      : "\\cf1 ";

   string row =
      "\\trowd\\trautofit1\\rtlrow"
      "\\trrh400"

      "\\clbrdrt\\brdrs\\clbrdrb\\brdrs\\clbrdrl\\brdrs\\clbrdrr\\brdrs"
      + bg + "\\cellx1400"

      "\\clbrdrt\\brdrs\\clbrdrb\\brdrs\\clbrdrl\\brdrs\\clbrdrr\\brdrs"
      + bg + "\\cellx2800"

      "\\clbrdrt\\brdrs\\clbrdrb\\brdrs\\clbrdrl\\brdrs\\clbrdrr\\brdrs"
      + bg + "\\cellx4200"

      "\\clbrdrt\\brdrs\\clbrdrb\\brdrs\\clbrdrl\\brdrs\\clbrdrr\\brdrs"
      + bg + "\\cellx5600"

      "\\clbrdrt\\brdrs\\clbrdrb\\brdrs\\clbrdrl\\brdrs\\clbrdrr\\brdrs"
      + bg + "\\cellx7000"

      "\\clbrdrt\\brdrs\\clbrdrb\\brdrs\\clbrdrl\\brdrs\\clbrdrr\\brdrs"
      + bg + "\\cellx8500"

      "\\pard\\intbl\\rtlpar\\qc\\f1\\fs22 ";

   row +=
      txt +
      RTF_EscapeFa(c1) +
      "\\cell ";

   row +=
      "\\pard\\intbl\\rtlpar\\qc\\f1\\fs22 " +
      txt +
      RTF_EscapeFa(c2) +
      "\\cell ";

   row +=
      "\\pard\\intbl\\rtlpar\\qc\\f1\\fs22 " +
      txt +
      RTF_EscapeFa(c3) +
      "\\cell ";

   row +=
      "\\pard\\intbl\\rtlpar\\qc\\f1\\fs22 " +
      txt +
      RTF_EscapeFa(c4) +
      "\\cell ";

   row +=
      "\\pard\\intbl\\rtlpar\\qc\\f1\\fs22 " +
      txt +
      RTF_EscapeFa(c5) +
      "\\cell ";

   row +=
      "\\pard\\intbl\\rtlpar\\qc\\f1\\fs22 " +
      txt +
      RTF_EscapeFa(c6) +
      "\\cell ";

   row += "\\row ";

   return row;
  }

//====================================================================
// پیدا کردن Position
//====================================================================
int ReportWord_FindPositionIndex(
   const ulong &position_ids[],
   const int count,
   const ulong position_id)
  {
   for(int i=0; i<count; i++)
     {
      if(position_ids[i] == position_id)
         return i;
     }

   return -1;
  }

//====================================================================
// استخراج آمار واقعی معاملات EA بر اساس Position ID
//====================================================================
void ComputeTradeStats(
   datetime from,
   datetime to,
   DirectionalStats &buy_stats,
   DirectionalStats &sell_stats,
   double &total_profit,
   double &best,
   double &worst)
  {
   buy_stats.trades      = 0;
   buy_stats.wins        = 0;
   buy_stats.losses      = 0;
   buy_stats.profit      = 0.0;
   buy_stats.best_trade  = 0.0;
   buy_stats.worst_trade = 0.0;

   sell_stats.trades      = 0;
   sell_stats.wins        = 0;
   sell_stats.losses      = 0;
   sell_stats.profit      = 0.0;
   sell_stats.best_trade  = 0.0;
   sell_stats.worst_trade = 0.0;

   total_profit = 0.0;
   best         = 0.0;
   worst        = 0.0;

   if(!HistorySelect(0,to))
      return;

   ulong  position_ids[];
   int    position_direction[];
   double position_profit[];
   bool   position_has_exit[];

   int position_count = 0;

   int total =
      HistoryDealsTotal();

   //===============================================================
   // مرحله 1: پیدا کردن Positionهایی که توسط EA باز شده‌اند
   //===============================================================
   for(int i=0; i<total; i++)
     {
      ulong ticket =
         HistoryDealGetTicket(i);

      if(ticket == 0)
         continue;

      if(
         HistoryDealGetString(
            ticket,
            DEAL_SYMBOL
         ) != _Symbol
      )
         continue;

      ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)
         HistoryDealGetInteger(
            ticket,
            DEAL_ENTRY
         );

      if(entry != DEAL_ENTRY_IN)
         continue;

      ulong magic =
         (ulong)
         HistoryDealGetInteger(
            ticket,
            DEAL_MAGIC
         );

      if(magic != (ulong)Inp_MagicNumber)
         continue;

      ulong position_id =
         (ulong)
         HistoryDealGetInteger(
            ticket,
            DEAL_POSITION_ID
         );

      if(position_id == 0)
         continue;

      if(
         ReportWord_FindPositionIndex(
            position_ids,
            position_count,
            position_id
         ) >= 0
      )
         continue;

      ArrayResize(
         position_ids,
         position_count+1
      );

      ArrayResize(
         position_direction,
         position_count+1
      );

      ArrayResize(
         position_profit,
         position_count+1
      );

      ArrayResize(
         position_has_exit,
         position_count+1
      );

      position_ids[position_count] =
         position_id;

      position_profit[position_count] =
         0.0;

      position_has_exit[position_count] =
         false;

      ENUM_DEAL_TYPE entry_type =
         (ENUM_DEAL_TYPE)
         HistoryDealGetInteger(
            ticket,
            DEAL_TYPE
         );

      if(entry_type == DEAL_TYPE_BUY)
         position_direction[position_count] = 1;
      else
      if(entry_type == DEAL_TYPE_SELL)
         position_direction[position_count] = -1;
      else
         position_direction[position_count] = 0;

      position_count++;
     }

   //===============================================================
   // مرحله 2: خروج‌های همان Position
   //===============================================================
   for(int i=0; i<total; i++)
     {
      ulong ticket =
         HistoryDealGetTicket(i);

      if(ticket == 0)
         continue;

      if(
         HistoryDealGetString(
            ticket,
            DEAL_SYMBOL
         ) != _Symbol
      )
         continue;

      ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)
         HistoryDealGetInteger(
            ticket,
            DEAL_ENTRY
         );

      if(
         entry != DEAL_ENTRY_OUT &&
         entry != DEAL_ENTRY_OUT_BY &&
         entry != DEAL_ENTRY_INOUT
      )
         continue;

      datetime deal_time =
         (datetime)
         HistoryDealGetInteger(
            ticket,
            DEAL_TIME
         );

      if(
         deal_time < from ||
         deal_time > to
      )
         continue;

      ulong position_id =
         (ulong)
         HistoryDealGetInteger(
            ticket,
            DEAL_POSITION_ID
         );

      if(position_id == 0)
         continue;

      int idx =
         ReportWord_FindPositionIndex(
            position_ids,
            position_count,
            position_id
         );

      if(idx < 0)
         continue;

      double pnl =
         HistoryDealGetDouble(
            ticket,
            DEAL_PROFIT
         )
         +
         HistoryDealGetDouble(
            ticket,
            DEAL_SWAP
         )
         +
         HistoryDealGetDouble(
            ticket,
            DEAL_COMMISSION
         )
         +
         HistoryDealGetDouble(
            ticket,
            DEAL_FEE
         );

      position_profit[idx] += pnl;
      position_has_exit[idx] = true;
     }

   //===============================================================
   // مرحله 3: محاسبه Positionهای بسته‌شده
   //===============================================================
   bool first = true;

   for(int i=0; i<position_count; i++)
     {
      if(!position_has_exit[i])
         continue;

      double pnl =
         position_profit[i];

      total_profit += pnl;

      if(first)
        {
         best  = pnl;
         worst = pnl;
         first = false;
        }
      else
        {
         if(pnl > best)
            best = pnl;

         if(pnl < worst)
            worst = pnl;
        }

      if(position_direction[i] > 0)
        {
         buy_stats.trades++;
         buy_stats.profit += pnl;

         if(pnl > 0.0)
            buy_stats.wins++;
         else
         if(pnl < 0.0)
            buy_stats.losses++;

         if(buy_stats.trades == 1)
           {
            buy_stats.best_trade  = pnl;
            buy_stats.worst_trade = pnl;
           }
         else
           {
            if(pnl > buy_stats.best_trade)
               buy_stats.best_trade = pnl;

            if(pnl < buy_stats.worst_trade)
               buy_stats.worst_trade = pnl;
           }
        }
      else
      if(position_direction[i] < 0)
        {
         sell_stats.trades++;
         sell_stats.profit += pnl;

         if(pnl > 0.0)
            sell_stats.wins++;
         else
         if(pnl < 0.0)
            sell_stats.losses++;

         if(sell_stats.trades == 1)
           {
            sell_stats.best_trade  = pnl;
            sell_stats.worst_trade = pnl;
           }
         else
           {
            if(pnl > sell_stats.best_trade)
               sell_stats.best_trade = pnl;

            if(pnl < sell_stats.worst_trade)
               sell_stats.worst_trade = pnl;
           }
        }
     }
  }

//====================================================================
// محاسبه Gross Profit / Gross Loss
//====================================================================
void ComputeGrossTradeStats(
   datetime from,
   datetime to,
   double &gross_profit,
   double &gross_loss)
  {
   gross_profit = 0.0;
   gross_loss   = 0.0;

   if(!HistorySelect(0,to))
      return;

   ulong  position_ids[];
   double position_profit[];
   bool   position_has_exit[];

   int position_count = 0;

   int total =
      HistoryDealsTotal();

   for(int i=0; i<total; i++)
     {
      ulong ticket =
         HistoryDealGetTicket(i);

      if(ticket == 0)
         continue;

      if(
         HistoryDealGetString(
            ticket,
            DEAL_SYMBOL
         ) != _Symbol
      )
         continue;

      ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)
         HistoryDealGetInteger(
            ticket,
            DEAL_ENTRY
         );

      if(entry != DEAL_ENTRY_IN)
         continue;

      ulong magic =
         (ulong)
         HistoryDealGetInteger(
            ticket,
            DEAL_MAGIC
         );

      if(magic != (ulong)Inp_MagicNumber)
         continue;

      ulong position_id =
         (ulong)
         HistoryDealGetInteger(
            ticket,
            DEAL_POSITION_ID
         );

      if(position_id == 0)
         continue;

      if(
         ReportWord_FindPositionIndex(
            position_ids,
            position_count,
            position_id
         ) >= 0
      )
         continue;

      ArrayResize(
         position_ids,
         position_count+1
      );

      ArrayResize(
         position_profit,
         position_count+1
      );

      ArrayResize(
         position_has_exit,
         position_count+1
      );

      position_ids[position_count] =
         position_id;

      position_profit[position_count] =
         0.0;

      position_has_exit[position_count] =
         false;

      position_count++;
     }

   for(int i=0; i<total; i++)
     {
      ulong ticket =
         HistoryDealGetTicket(i);

      if(ticket == 0)
         continue;

      if(
         HistoryDealGetString(
            ticket,
            DEAL_SYMBOL
         ) != _Symbol
      )
         continue;

      ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)
         HistoryDealGetInteger(
            ticket,
            DEAL_ENTRY
         );

      if(
         entry != DEAL_ENTRY_OUT &&
         entry != DEAL_ENTRY_OUT_BY &&
         entry != DEAL_ENTRY_INOUT
      )
         continue;

      datetime deal_time =
         (datetime)
         HistoryDealGetInteger(
            ticket,
            DEAL_TIME
         );

      if(
         deal_time < from ||
         deal_time > to
      )
         continue;

      ulong position_id =
         (ulong)
         HistoryDealGetInteger(
            ticket,
            DEAL_POSITION_ID
         );

      if(position_id == 0)
         continue;

      int idx =
         ReportWord_FindPositionIndex(
            position_ids,
            position_count,
            position_id
         );

      if(idx < 0)
         continue;

      double pnl =
         HistoryDealGetDouble(
            ticket,
            DEAL_PROFIT
         )
         +
         HistoryDealGetDouble(
            ticket,
            DEAL_SWAP
         )
         +
         HistoryDealGetDouble(
            ticket,
            DEAL_COMMISSION
         )
         +
         HistoryDealGetDouble(
            ticket,
            DEAL_FEE
         );

      position_profit[idx] += pnl;
      position_has_exit[idx] = true;
     }

   for(int i=0; i<position_count; i++)
     {
      if(!position_has_exit[i])
         continue;

      double pnl =
         position_profit[i];

      if(pnl > 0.0)
         gross_profit += pnl;
      else
      if(pnl < 0.0)
         gross_loss += MathAbs(pnl);
     }
  }

//====================================================================
// ساخت بخش AI Learning
//====================================================================
string ReportWord_BuildAILearningSection(
   const AIVirtualReportStats &ai)
  {
   string body = "";

   body +=
      RTF_SectionHeader(
         "عملکرد هوش مصنوعی مستقل و معاملات مجازی"
      );

   body +=
      RTF_InfoBox(
         "آمار این بخش از معاملات مجازی سناریوهای معتبر استخراج می‌شود و عملکرد AI مستقل را نشان نمی‌دهد."
      );

   body +=
      RTF_Table2Col(
         "معاملات برنامه‌ریزی‌شده",
         IntegerToString(ai.planned)
      );

   body +=
      RTF_Table2Col(
         "معاملات بازشده",
         IntegerToString(ai.opened)
      );

   body +=
      RTF_Table2Col(
         "معاملات بسته‌شده",
         IntegerToString(ai.closed)
      );

   body +=
      RTF_Table2Col(
         "برد مجازی",
         IntegerToString(ai.wins),
         "\\cf2 "
      );

   body +=
      RTF_Table2Col(
         "باخت مجازی",
         IntegerToString(ai.losses),
         "\\cf3 "
      );

   body +=
      RTF_Table2Col(
         "سر به سر",
         IntegerToString(ai.breakeven)
      );

   body +=
      RTF_Table2Col(
         "درصد موفقیت مجازی",
         RTF_Num(ai.win_rate,2) + "%",
         "\\cf7 "
      );

   body +=
      RTF_Table2ColRaw(
         "مجموع سود مجازی",
         "\\cf2\\b " +
         RTF_Num(ai.gross_profit,2) +
         "$\\b0\\cf1 "
      );

   body +=
      RTF_Table2ColRaw(
         "مجموع ضرر مجازی",
         "\\cf3\\b -" +
         RTF_Num(ai.gross_loss,2) +
         "$\\b0\\cf1 "
      );

   body +=
      RTF_Table2ColRaw(
         "سود / ضرر خالص مجازی",
         RTF_ColoredNum(ai.net_profit,2) +
         "$"
      );

   body +=
      RTF_Table2Col(
         "Profit Factor مجازی",
         (
            ai.profit_factor >= 9999.0
            ? "∞"
            : RTF_Num(ai.profit_factor,2)
         ),
         "\\cf7 "
      );

   body += RTF_Separator();

   return body;
  }

//====================================================================
// ساخت بخش AI مستقل
//====================================================================
string ReportWord_BuildAIIndependentSection(
   const AIIndependentReportStats &stats,
   const string title)
  {
   string body = "";

   body +=
      RTF_SectionHeader(
         title
      );

   body +=
      RTF_InfoBox(
         "این بخش مستقیماً از معاملات مجازی AI مستقل استخراج شده است. مقادیر سود و ضرر با واحد R نمایش داده می‌شوند."
      );

   body +=
      RTF_Table2Col(
         "معاملات بازشده",
         IntegerToString(stats.opened)
      );

   body +=
      RTF_Table2Col(
         "معاملات باز فعلی",
         IntegerToString(stats.open_now)
      );

   body +=
      RTF_Table2Col(
         "معاملات بسته‌شده",
         IntegerToString(stats.closed)
      );

   body +=
      RTF_Table2Col(
         "برد",
         IntegerToString(stats.wins),
         "\\cf2 "
      );

   body +=
      RTF_Table2Col(
         "باخت",
         IntegerToString(stats.losses),
         "\\cf3 "
      );

   body +=
      RTF_Table2Col(
         "سر به سر",
         IntegerToString(stats.breakeven)
      );

   body +=
      RTF_Table2Col(
         "درصد موفقیت",
         RTF_Num(stats.win_rate,2) + "%",
         "\\cf7 "
      );

   body +=
      RTF_Table2ColRaw(
         "مجموع سود (R)",
         "\\cf2\\b " +
         RTF_Num(stats.total_profit_r,2) +
         "\\b0\\cf1 "
      );

   body +=
      RTF_Table2ColRaw(
         "مجموع ضرر (R)",
         "\\cf3\\b -" +
         RTF_Num(stats.total_loss_r,2) +
         "\\b0\\cf1 "
      );

   body +=
      RTF_Table2ColRaw(
         "سود / ضرر خالص (R)",
         RTF_ColoredNum(stats.net_r,2)
      );

   body +=
      RTF_Table2Col(
         "Profit Factor",
         (
            stats.profit_factor >= 9999.0
            ? "∞"
            : RTF_Num(stats.profit_factor,2)
         ),
         "\\cf7 "
      );

   body += RTF_Separator();

   body +=
      RTF_SubSection(
         "مقایسه با جهت ربات"
      );

   body +=
      RTF_Table2Col(
         "هم‌جهت با ربات",
         IntegerToString(stats.agree_with_bot),
         "\\cf2 "
      );

   body +=
      RTF_Table2Col(
         "اختلاف با ربات",
         IntegerToString(stats.disagree_with_bot),
         "\\cf3 "
      );

   body += RTF_Separator();

   return body;
  }

//====================================================================
// نوشتن فایل
//====================================================================
void ReportWord_WriteFile(
   const string filename,
   const string title,
   const string body)
  {
   ResetLastError();

   int h =
      FileOpen(
         filename,
         FILE_WRITE |
         FILE_TXT   |
         FILE_ANSI
      );

   if(h == INVALID_HANDLE)
     {
      Print(
         "[REPORT WORD] ERROR | Failed to create file: ",
         filename,
         " | Error=",
         GetLastError()
      );

      return;
     }

   //=================================================================
   // تنظیم فونت اصلی گزارش
   // f0 = B Nazanin
   // f1 = B Nazanin
   //=================================================================
   string header =
      "{\\rtf1\\ansi\\deff0"
      "{\\fonttbl"
      "{\\f0 B Nazanin;}"
      "{\\f1 B Nazanin;}"
      "}"
      +
      RTF_ColorTable() +
      "\\viewkind4"
      "\\uc1"
      "\\f1"
      "\\fs24"
      "\\cf1"
      "\\rtlch ";

   FileWriteString(
      h,
      header +
      body +
      "}"
   );

   FileClose(h);

   Print(
      "[REPORT WORD] GENERATED | File=",
      filename
   );
  }

//====================================================================
// گزارش روزانه
//====================================================================
void ReportWord_WriteDaily(
   const PerformanceReportState &p,
   const FilterAuditState &a,
   const AIVirtualEngineState &ai,
   const AIVirtualTrade &virtual_trades[],
   const int virtual_trade_count)
  {
   MqlDateTime dt;

   TimeToStruct(
      TimeCurrent(),
      dt
   );

   string fn =
      (MQLInfoInteger(MQL_TESTER) ? "TFlab_BACKTEST_Report_Daily_" : "TFlab_Report_Daily_") +
      IntegerToString(dt.year) +
      "_" +
      StringFormat("%02d",dt.mon) +
      "_" +
      StringFormat("%02d",dt.day) +
      ".rtf";

   MqlDateTime day;

   TimeToStruct(
      TimeCurrent(),
      day
   );

   day.hour = 0;
   day.min  = 0;
   day.sec  = 0;

   datetime start =
      StructToTime(day);

   DirectionalStats buy_stats;
   DirectionalStats sell_stats;

   double total_profit = 0.0;
   double best = 0.0;
   double worst = 0.0;

   ComputeTradeStats(
      start,
      TimeCurrent(),
      buy_stats,
      sell_stats,
      total_profit,
      best,
      worst
   );

   //===============================================================
   // AI Virtual اصلی
   //===============================================================
   AIVirtualReportStats ai_stats;

   ReportWord_ComputeAIStats(
      virtual_trades,
      virtual_trade_count,
      start,
      TimeCurrent(),
      ai_stats
   );

   //===============================================================
   // AI مستقل
   //===============================================================
   AIIndependentReportStats ai_independent_stats;

   ReportWord_ComputeAIIndependentStats(
      start,
      TimeCurrent(),
      true,
      ai_independent_stats
   );

   int total_trades =
      buy_stats.trades +
      sell_stats.trades;

   int total_wins =
      buy_stats.wins +
      sell_stats.wins;

   int total_losses =
      buy_stats.losses +
      sell_stats.losses;

   double win_rate =
      (
         total_trades > 0
         ?
         100.0 *
         (double)total_wins /
         (double)total_trades
         :
         0.0
      );

   double gross_profit = 0.0;
   double gross_loss   = 0.0;

   ComputeGrossTradeStats(
      start,
      TimeCurrent(),
      gross_profit,
      gross_loss
   );

   double profit_factor =
      (
         gross_loss > 0.0
         ?
         gross_profit / gross_loss
         :
         (
            gross_profit > 0.0
            ?
            9999.0
            :
            0.0
         )
      );

   double buy_wr =
      (
         buy_stats.trades > 0
         ?
         100.0 *
         (double)buy_stats.wins /
         (double)buy_stats.trades
         :
         0.0
      );

   double sell_wr =
      (
         sell_stats.trades > 0
         ?
         100.0 *
         (double)sell_stats.wins /
         (double)sell_stats.trades
         :
         0.0
      );

   string body = "";

   //=================================================================
   // Header
   //=================================================================
   body +=
      RTF_MainHeader(
         "TFlab New EA V.5 PROFESSIONAL",
         "گزارش حرفه‌ای روزانه سود و زیان"
      );

   body +=
      RTF_InfoBox(
         "خلاصه عملکرد ربات در روز جاری — اطلاعات واقعی از History حساب استخراج شده است."
      );

   //=================================================================
   // KPI
   //=================================================================
   body +=
      RTF_SectionHeader(
         "خلاصه عملکرد امروز"
      );

   body +=
      RTF_KPICard(
         "تعداد معاملات",
         IntegerToString(total_trades),
         "\\cf7 "
      );

   body +=
      RTF_KPICard(
         "Win Rate",
         RTF_Num(win_rate,2) + "%",
         "\\cf7 "
      );

   body +=
      RTF_KPICard(
         "سود / ضرر خالص",
         RTF_Num(total_profit,2) + "$",
         RTF_NumberColor(total_profit)
      );

   body +=
      RTF_KPICard(
         "Profit Factor",
         (
            profit_factor >= 9999.0
            ?
            "∞"
            :
            RTF_Num(profit_factor,2)
         ),
         "\\cf7 "
      );

   body += RTF_Separator();

   //=================================================================
   // آمار اصلی
   //=================================================================
   body +=
      RTF_SectionHeader(
         "آمار واقعی معاملات"
      );

   body +=
      RTF_Table2Col(
         "معاملات سودده",
         IntegerToString(total_wins),
         "\\cf2 "
      );

   body +=
      RTF_Table2Col(
         "معاملات ضررده",
         IntegerToString(total_losses),
         "\\cf3 "
      );

   body +=
      RTF_Table2ColRaw(
         "مجموع سود",
         RTF_NumberColor(gross_profit) +
         "\\b " +
         RTF_Num(gross_profit,2) +
         "$\\b0\\cf1 "
      );

   body +=
      RTF_Table2ColRaw(
         "مجموع ضرر",
         "\\cf3 \\b -" +
         RTF_Num(gross_loss,2) +
         "$\\b0\\cf1 "
      );

   body +=
      RTF_Table2ColRaw(
         "سود خالص",
         RTF_ColoredNum(total_profit) +
         "$"
      );

   body +=
      RTF_Table2ColRaw(
         "بهترین معامله",
         RTF_ColoredNum(best) +
         "$"
      );

   body +=
      RTF_Table2ColRaw(
         "بدترین معامله",
         RTF_ColoredNum(worst) +
         "$"
      );

   body += RTF_Separator();

   //=================================================================
   // تفکیک BUY / SELL
   //=================================================================
   body +=
      RTF_SectionHeader(
         "تفکیک جهت معاملات"
      );

   body +=
      RTF_TableRow(
         "جهت",
         "تعداد",
         "برد",
         "باخت",
         "Win Rate",
         "سود / ضرر",
         true
      );

   body +=
      RTF_TableRow(
         "BUY",
         IntegerToString(buy_stats.trades),
         IntegerToString(buy_stats.wins),
         IntegerToString(buy_stats.losses),
         RTF_Num(buy_wr,1) + "%",
         RTF_Num(buy_stats.profit,2) + "$",
         false
      );

   body +=
      RTF_TableRow(
         "SELL",
         IntegerToString(sell_stats.trades),
         IntegerToString(sell_stats.wins),
         IntegerToString(sell_stats.losses),
         RTF_Num(sell_wr,1) + "%",
         RTF_Num(sell_stats.profit,2) + "$",
         false
      );

   body += RTF_Separator();

   //=================================================================
   // AI Virtual اصلی
   //=================================================================
   body +=
      RTF_SectionHeader(
         "عملکرد معاملات مجازی سناریو"
      );

   body +=
      RTF_Table2Col(
         "معاملات برنامه‌ریزی‌شده",
         IntegerToString(ai_stats.planned)
      );

   body +=
      RTF_Table2Col(
         "تعداد معاملات مجازی",
         IntegerToString(ai_stats.opened)
      );

   body +=
      RTF_Table2Col(
         "معاملات بسته‌شده",
         IntegerToString(ai_stats.closed)
      );

   body +=
      RTF_Table2Col(
         "برد مجازی",
         IntegerToString(ai_stats.wins),
         "\\cf2 "
      );

   body +=
      RTF_Table2Col(
         "باخت مجازی",
         IntegerToString(ai_stats.losses),
         "\\cf3 "
      );

   body +=
      RTF_Table2Col(
         "درصد موفقیت مجازی",
         RTF_Num(ai_stats.win_rate,2) + "%",
         "\\cf7 "
      );

   body +=
      RTF_Table2ColRaw(
         "سود / ضرر خالص مجازی",
         RTF_ColoredNum(ai_stats.net_profit,2) +
         "$"
      );

   body +=
      RTF_Table2Col(
         "Profit Factor مجازی",
         (
            ai_stats.profit_factor >= 9999.0
            ?
            "∞"
            :
            RTF_Num(ai_stats.profit_factor,2)
         ),
         "\\cf7 "
      );

   body += RTF_Separator();

   //=================================================================
   // AI مستقل
   //=================================================================
   body +=
      ReportWord_BuildAIIndependentSection(
         ai_independent_stats,
         "عملکرد AI مستقل - امروز"
      );

   //=================================================================
   // Filter Audit
   //=================================================================
   body +=
      RTF_SectionHeader(
         "ممیزی فیلترها"
      );

   body +=
      RTF_Table2Col(
         "تایید تجمعی",
         IntegerToString(
            g_filter_audit_totals.pass_count
         ),
         "\\cf2 "
      );

   body +=
      RTF_Table2Col(
         "مسدود تجمعی",
         IntegerToString(
            g_filter_audit_totals.block_count
         ),
         "\\cf3 "
      );

   body +=
      RTF_Table2Col(
         "اطلاعاتی تجمعی",
         IntegerToString(
            g_filter_audit_totals.info_count
         ),
         "\\cf7 "
      );

   body += RTF_Separator();

   //=================================================================
   // AI Learning
   //=================================================================
   body +=
      ReportWord_BuildAILearningSection(
         ai_stats
      );

   //=================================================================
   // جمع‌بندی
   //=================================================================
   if(total_profit > 0.0)
     {
      body +=
         RTF_SuccessBox(
            "نتیجه روز: عملکرد خالص امروز مثبت است."
         );
     }
   else
   if(total_profit < 0.0)
     {
      body +=
         RTF_WarningBox(
            "نتیجه روز: عملکرد خالص امروز منفی است."
         );
     }
   else
     {
      body +=
         RTF_InfoBox(
            "نتیجه روز: امروز سود یا زیان خالصی ثبت نشده است."
         );
     }

   body +=
      RTF_Table2Col(
         "وضعیت",
         "گزارش با موفقیت تولید شد."
      );

   body +=
      RTF_Table2Col(
         "حیطه گزارش",
         "آمار معاملات واقعی از History حساب استخراج شده و معاملات مجازی AI و AI مستقل جداگانه گزارش می‌شوند."
      );

   ReportWord_WriteFile(
      fn,
      "گزارش روزانه",
      body
   );

   Print(
      "[REPORT WORD] DAILY REPORT GENERATED | Trades=",
      total_trades,
      " | Profit=",
      RTF_Num(total_profit,2),
      " | PF=",
      (
         profit_factor >= 9999.0
         ?
         "INF"
         :
         RTF_Num(profit_factor,2)
      ),
      " | AIIndependentClosed=",
      ai_independent_stats.closed,
      " | AIIndependentNetR=",
      RTF_Num(ai_independent_stats.net_r,2)
   );
  }

//====================================================================
// گزارش کلی / Overall
//====================================================================
void ReportWord_WriteOverall(
   const PerformanceReportState &p,
   const FilterAuditState &a,
   const AIVirtualEngineState &ai,
   const AIVirtualTrade &virtual_trades[],
   const int virtual_trade_count)
  {
   DirectionalStats buy_stats;
   DirectionalStats sell_stats;

   double total_profit = 0.0;
   double best = 0.0;
   double worst = 0.0;

   ComputeTradeStats(
      0,
      TimeCurrent(),
      buy_stats,
      sell_stats,
      total_profit,
      best,
      worst
   );

   //===============================================================
   // AI Virtual اصلی
   //===============================================================
   AIVirtualReportStats ai_stats;

   ReportWord_ComputeAIStats(
      virtual_trades,
      virtual_trade_count,
      0,
      TimeCurrent(),
      ai_stats
   );

   //===============================================================
   // AI مستقل
   //===============================================================
   AIIndependentReportStats ai_independent_stats;

   ReportWord_ComputeAIIndependentStats(
      0,
      TimeCurrent(),
      false,
      ai_independent_stats
   );

   int total_trades =
      buy_stats.trades +
      sell_stats.trades;

   int total_wins =
      buy_stats.wins +
      sell_stats.wins;

   int total_losses =
      buy_stats.losses +
      sell_stats.losses;

   double win_rate =
      (
         total_trades > 0
         ?
         100.0 *
         (double)total_wins /
         (double)total_trades
         :
         0.0
      );

   double gross_profit = 0.0;
   double gross_loss   = 0.0;

   if(HistorySelect(0,TimeCurrent()))
     {
      int deals =
         HistoryDealsTotal();

      for(int i=0; i<deals; i++)
        {
         ulong ticket =
            HistoryDealGetTicket(i);

         if(ticket == 0)
            continue;

         if(
            HistoryDealGetString(
               ticket,
               DEAL_SYMBOL
            ) != _Symbol
         )
            continue;

         if(
            (ulong)
            HistoryDealGetInteger(
               ticket,
               DEAL_MAGIC
            )
            !=
            (ulong)Inp_MagicNumber
         )
            continue;

         if(
            (ENUM_DEAL_ENTRY)
            HistoryDealGetInteger(
               ticket,
               DEAL_ENTRY
            )
            != DEAL_ENTRY_OUT
         )
            continue;

         double v =
            HistoryDealGetDouble(
               ticket,
               DEAL_PROFIT
            )
            +
            HistoryDealGetDouble(
               ticket,
               DEAL_SWAP
            )
            +
            HistoryDealGetDouble(
               ticket,
               DEAL_COMMISSION
            )
            +
            HistoryDealGetDouble(
               ticket,
               DEAL_FEE
            );

         if(v > 0.0)
            gross_profit += v;

         if(v < 0.0)
            gross_loss += MathAbs(v);
        }
     }

   double profit_factor =
      (
         gross_loss > 0.0
         ?
         gross_profit / gross_loss
         :
         (
            gross_profit > 0.0
            ?
            9999.0
            :
            0.0
         )
      );

   double b_wr =
      (
         buy_stats.trades > 0
         ?
         100.0 *
         (double)buy_stats.wins /
         (double)buy_stats.trades
         :
         0.0
      );

   double s_wr =
      (
         sell_stats.trades > 0
         ?
         100.0 *
         (double)sell_stats.wins /
         (double)sell_stats.trades
         :
         0.0
      );

   double max_dd =
      p.maximum_drawdown_percent;

   string body = "";

   double current_balance =
      AccountInfoDouble(
         ACCOUNT_BALANCE
      );

   double current_equity =
      AccountInfoDouble(
         ACCOUNT_EQUITY
      );

   double account_net_profit =
      current_balance -
      Inp_Report_InitialBalance;

   double account_net_percent =
      (
         Inp_Report_InitialBalance > 0.0
         ?
         (
            account_net_profit /
            Inp_Report_InitialBalance
         ) *
         100.0
         :
         0.0
      );

   //=================================================================
   // Header
   //=================================================================
   body +=
      RTF_MainHeader(
         "TFlab New EA V.5 PROFESSIONAL",
         "گزارش جامع و تاریخی کل دوره"
      );

   body +=
      RTF_InfoBox(
         "گزارش Overall شامل عملکرد واقعی حساب، تفکیک BUY/SELL، عملکرد معاملات مجازی سناریو، هوش مصنوعی مستقل و وضعیت ممیزی فیلترها است."
      );

   //=================================================================
   // حساب
   //=================================================================
   body +=
      RTF_SectionHeader(
         "وضعیت کلی حساب"
      );

   body +=
      RTF_KPICard(
         "Balance",
         RTF_Num(
            current_balance,
            2
         ) + "$",
         "\\cf7 "
      );

   body +=
      RTF_KPICard(
         "Equity",
         RTF_Num(
            current_equity,
            2
         ) + "$",
         "\\cf7 "
      );

   body +=
      RTF_KPICard(
         "سود خالص حساب",
         RTF_Num(
            account_net_profit,
            2
         ) + "$",
         RTF_NumberColor(account_net_profit)
      );

   body +=
      RTF_Table2ColRaw(
         "سرمایه اولیه",
         RTF_ColoredNum(
            Inp_Report_InitialBalance,
            2
         ) +
         "$"
      );

   body +=
      RTF_Table2ColRaw(
         "موجودی فعلی",
         RTF_ColoredNum(
            current_balance,
            2
         ) +
         "$"
      );

   body +=
      RTF_Table2ColRaw(
         "رشد حساب",
         RTF_ColoredNum(
            account_net_profit,
            2
         ) +
         "$"
      );

   body +=
      RTF_Table2Col(
         "درصد رشد حساب",
         RTF_Num(
            account_net_percent,
            2
         ) +
         "%",
         RTF_NumberColor(account_net_profit)
      );

   body +=
      RTF_Table2ColRaw(
         "سود خالص معاملات EA",
         RTF_ColoredNum(
            total_profit,
            2
         ) +
         "$"
      );

   body +=
      RTF_KPICard(
         "Drawdown",
         RTF_Num(
            max_dd,
            2
         ) + "%",
         "\\cf3 "
      );

   body += RTF_Separator();

   //=================================================================
   // آمار معاملات
   //=================================================================
   body +=
      RTF_SectionHeader(
         "آمار معاملات واقعی کل دوره"
      );

   body +=
      RTF_Table2Col(
         "تعداد کل معاملات",
         IntegerToString(
            total_trades
         )
      );

   body +=
      RTF_Table2Col(
         "معاملات سودده",
         IntegerToString(
            total_wins
         ),
         "\\cf2 "
      );

   body +=
      RTF_Table2Col(
         "معاملات ضررده",
         IntegerToString(
            total_losses
         ),
         "\\cf3 "
      );

   body +=
      RTF_Table2Col(
         "درصد موفقیت",
         RTF_Num(
            win_rate,
            2
         ) +
         "%",
         "\\cf7 "
      );

   body +=
      RTF_Table2ColRaw(
         "مجموع سود",
         "\\cf2\\b " +
         RTF_Num(
            gross_profit,
            2
         ) +
         "$\\b0\\cf1 "
      );

   body +=
      RTF_Table2ColRaw(
         "مجموع ضرر",
         "\\cf3\\b -" +
         RTF_Num(
            gross_loss,
            2
         ) +
         "$\\b0\\cf1 "
      );

   body +=
      RTF_Table2ColRaw(
         "سود خالص کل",
         RTF_ColoredNum(
            total_profit
         ) +
         "$"
      );

   body +=
      RTF_Table2Col(
         "Profit Factor",
         (
            profit_factor >= 9999.0
            ?
            "∞"
            :
            RTF_Num(
               profit_factor,
               2
            )
         ),
         "\\cf7 "
      );

   body +=
      RTF_Table2ColRaw(
         "بهترین معامله",
         RTF_ColoredNum(
            best
         ) +
         "$"
      );

   body +=
      RTF_Table2ColRaw(
         "بدترین معامله",
         RTF_ColoredNum(
            worst
         ) +
         "$"
      );

   body += RTF_Separator();

   //=================================================================
   // BUY / SELL
   //=================================================================
   body +=
      RTF_SectionHeader(
         "تفکیک عملکرد BUY و SELL"
      );

   body +=
      RTF_TableRow(
         "جهت",
         "تعداد",
         "برد",
         "باخت",
         "Win Rate",
         "سود / ضرر",
         true
      );

   body +=
      RTF_TableRow(
         "BUY",
         IntegerToString(
            buy_stats.trades
         ),
         IntegerToString(
            buy_stats.wins
         ),
         IntegerToString(
            buy_stats.losses
         ),
         RTF_Num(
            b_wr,
            1
         ) + "%",
         RTF_Num(
            buy_stats.profit,
            2
         ) + "$",
         false
      );

   body +=
      RTF_TableRow(
         "SELL",
         IntegerToString(
            sell_stats.trades
         ),
         IntegerToString(
            sell_stats.wins
         ),
         IntegerToString(
            sell_stats.losses
         ),
         RTF_Num(
            s_wr,
            1
         ) + "%",
         RTF_Num(
            sell_stats.profit,
            2
         ) + "$",
         false
      );

   body += RTF_Separator();

   //=================================================================
   // AI Virtual اصلی
   //=================================================================
   body +=
      RTF_SectionHeader(
         "عملکرد معاملات مجازی سناریو"
      );

   body +=
      RTF_Table2Col(
         "تعداد معاملات برنامه‌ریزی‌شده",
         IntegerToString(
            ai_stats.planned
         )
      );

   body +=
      RTF_Table2Col(
         "تعداد معاملات بازشده",
         IntegerToString(
            ai_stats.opened
         )
      );

   body +=
      RTF_Table2Col(
         "تعداد معاملات بسته‌شده",
         IntegerToString(
            ai_stats.closed
         )
      );

   body +=
      RTF_Table2Col(
         "برد مجازی",
         IntegerToString(
            ai_stats.wins
         ),
         "\\cf2 "
      );

   body +=
      RTF_Table2Col(
         "باخت مجازی",
         IntegerToString(
            ai_stats.losses
         ),
         "\\cf3 "
      );

   body +=
      RTF_Table2Col(
         "سر به سر",
         IntegerToString(
            ai_stats.breakeven
         )
      );

   body +=
      RTF_Table2Col(
         "درصد موفقیت مجازی",
         RTF_Num(
            ai_stats.win_rate,
            2
         ) + "%",
         "\\cf7 "
      );

   body +=
      RTF_Table2ColRaw(
         "مجموع سود مجازی",
         "\\cf2\\b " +
         RTF_Num(
            ai_stats.gross_profit,
            2
         ) +
         "$\\b0\\cf1 "
      );

   body +=
      RTF_Table2ColRaw(
         "مجموع ضرر مجازی",
         "\\cf3\\b -" +
         RTF_Num(
            ai_stats.gross_loss,
            2
         ) +
         "$\\b0\\cf1 "
      );

   body +=
      RTF_Table2ColRaw(
         "سود / ضرر خالص مجازی",
         RTF_ColoredNum(
            ai_stats.net_profit
         ) +
         "$"
      );

   body +=
      RTF_Table2Col(
         "Profit Factor مجازی",
         (
            ai_stats.profit_factor >= 9999.0
            ?
            "∞"
            :
            RTF_Num(
               ai_stats.profit_factor,
               2
            )
         ),
         "\\cf7 "
      );

   body += RTF_Separator();

   //=================================================================
   // AI مستقل
   //=================================================================
   body +=
      ReportWord_BuildAIIndependentSection(
         ai_independent_stats,
         "عملکرد کلی AI مستقل"
      );

   //=================================================================
   // Filter Audit
   //=================================================================
   body +=
      RTF_SectionHeader(
         "ممیزی فیلترها در کل دوره"
      );

   body +=
      RTF_Table2Col(
         "تایید تجمعی",
         IntegerToString(
            g_filter_audit_totals.pass_count
         ),
         "\\cf2 "
      );

   body +=
      RTF_Table2Col(
         "مسدود تجمعی",
         IntegerToString(
            g_filter_audit_totals.block_count
         ),
         "\\cf3 "
      );

   body +=
      RTF_Table2Col(
         "اطلاعاتی تجمعی",
         IntegerToString(
            g_filter_audit_totals.info_count
         ),
         "\\cf7 "
      );

   body += RTF_Separator();

   //=================================================================
   // AI Learning
   //=================================================================
   body +=
      ReportWord_BuildAILearningSection(
         ai_stats
      );

   //=================================================================
   // جمع‌بندی نهایی
   //=================================================================
   body +=
      RTF_SectionHeader(
         "جمع‌بندی عملکرد"
      );

   if(total_profit > 0.0)
     {
      body +=
         RTF_SuccessBox(
            "عملکرد کل دوره از نظر سود خالص مثبت است."
         );
     }
   else
   if(total_profit < 0.0)
     {
      body +=
         RTF_WarningBox(
            "عملکرد کل دوره از نظر سود خالص منفی است و نیاز به بررسی دارد."
         );
     }
   else
     {
      body +=
         RTF_InfoBox(
            "در کل دوره سود یا زیان خالصی ثبت نشده است."
         );
     }

   body +=
      RTF_Table2Col(
         "تعداد کل معاملات",
         IntegerToString(
            total_trades
         )
      );

   body +=
      RTF_Table2Col(
         "Win Rate",
         RTF_Num(
            win_rate,
            2
         ) +
         "%"
      );

   body +=
      RTF_Table2Col(
         "Profit Factor",
         (
            profit_factor >= 9999.0
            ?
            "∞"
            :
            RTF_Num(
               profit_factor,
               2
            )
         )
      );

   body +=
      RTF_Table2Col(
         "Drawdown",
         RTF_Num(
            max_dd,
            2
         ) +
         "%"
      );

   body +=
      RTF_Table2Col(
         "وضعیت گزارش",
         "گزارش جامع با موفقیت تولید شد."
      );

   ReportWord_WriteFile(
      (MQLInfoInteger(MQL_TESTER) ? "TFlab_BACKTEST_Report_Overall.rtf" : "TFlab_Report_Overall.rtf"),
      "گزارش کلی",
      body
   );

   Print(
      "[REPORT WORD] OVERALL REPORT GENERATED | TotalTrades=",
      total_trades,
      " | NetProfit=",
      RTF_Num(total_profit,2),
      " | PF=",
      (
         profit_factor >= 9999.0
         ?
         "INF"
         :
         RTF_Num(profit_factor,2)
      ),
      " | AIIndependentClosed=",
      ai_independent_stats.closed,
      " | AIIndependentNetR=",
      RTF_Num(
         ai_independent_stats.net_r,
         2
      )
   );
  }

#endif // __TFLAB_REPORT_WORD_ENGINE_MQH__