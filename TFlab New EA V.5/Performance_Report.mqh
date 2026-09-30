//+------------------------------------------------------------------+
//|                   Performance_Report.mqh                         |
//|                    TFlab New EA V.5                              |
//|                    Fixed: History + Diagnostics                  |
//+------------------------------------------------------------------+
#ifndef __TFLAB_PERFORMANCE_REPORT_MQH__
#define __TFLAB_PERFORMANCE_REPORT_MQH__

#property strict

//====================================================================
// وضعیت گزارش
//====================================================================
struct PerformanceReportState
  {
   bool      initialized;
   datetime  created_time;
   datetime  last_update_time;
   datetime  next_update_time;
   ulong     update_count;

   int       total_trades;
   int       winning_trades;
   int       losing_trades;
   int       breakeven_trades;

   double    gross_profit;
   double    gross_loss;
   double    net_profit;
   double    profit_factor;

   double    current_balance;
   double    current_equity;
   double    peak_equity;

   double    current_drawdown_money;
   double    current_drawdown_percent;

   double    maximum_drawdown_money;
   double    maximum_drawdown_percent;

   int       open_trades;
   double    open_profit;

   int       total_pending_orders;
   int       active_pending_orders;

   int       partial_close_count;
   double    partial_close_profit;

   string    status;
   string    last_note;
  };

//====================================================================
// Init
//====================================================================
void PerformanceReport_Init(
   PerformanceReportState &report)
  {
   ZeroMemory(report);

   report.initialized              = false;
   report.created_time             = 0;
   report.last_update_time         = 0;
   report.next_update_time         = 0;
   report.update_count             = 0;

   report.total_trades             = 0;
   report.winning_trades           = 0;
   report.losing_trades            = 0;
   report.breakeven_trades         = 0;

   report.gross_profit             = 0.0;
   report.gross_loss               = 0.0;
   report.net_profit               = 0.0;
   report.profit_factor            = 0.0;

   report.current_balance          = 0.0;
   report.current_equity           = 0.0;
   report.peak_equity              = 0.0;

   report.current_drawdown_money   = 0.0;
   report.current_drawdown_percent = 0.0;

   report.maximum_drawdown_money   = 0.0;
   report.maximum_drawdown_percent = 0.0;

   report.open_trades              = 0;
   report.open_profit              = 0.0;

   report.total_pending_orders     = 0;
   report.active_pending_orders    = 0;

   report.partial_close_count      = 0;
   report.partial_close_profit     = 0.0;

   report.status                   = "آماده نشده";
   report.last_note                = "";
  }

//====================================================================
// Start
//====================================================================
void PerformanceReport_Start(
   PerformanceReportState &report)
  {
   if(report.initialized)
      return;

   const datetime now = TimeCurrent();

   report.initialized      = true;
   report.created_time     = now;
   report.last_update_time = 0;
   report.next_update_time = now;
   report.update_count     = 0;

   report.current_balance =
      AccountInfoDouble(ACCOUNT_BALANCE);

   report.current_equity =
      AccountInfoDouble(ACCOUNT_EQUITY);

   report.peak_equity = report.current_equity;

   report.status   = "فعال";
   report.last_note = "گزارش عملکرد شروع شد";
  }

//====================================================================
// بررسی تعلق Deal به EA
//
// نکته:
// در این تابع از HistoryDealSelect برای Deal جاری استفاده نمی‌کنیم.
// Deal جاری از قبل توسط HistoryDealGetTicket() در حلقه انتخاب شده است.
// در صورت نیاز فقط Position History با HistorySelectByPosition بررسی
// می‌شود و در پایان History اصلی دوباره restore می‌شود.
//====================================================================
bool PerformanceReport_DealBelongsToEA(
   const ulong deal_ticket,
   const ulong magic_number)
  {
   if(deal_ticket == 0)
      return false;

   //============================================================
   // 1) بررسی Magic مستقیم Deal
   //============================================================
   const ulong deal_magic =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);

   if(deal_magic == magic_number)
      return true;

   //============================================================
   // 2) بررسی Magic مربوط به Order
   //============================================================
   const ulong order_ticket =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);

   if(order_ticket > 0)
     {
      if(HistoryOrderSelect(order_ticket))
        {
         const ulong order_magic =
            (ulong)HistoryOrderGetInteger(order_ticket, ORDER_MAGIC);

         if(order_magic == magic_number)
            return true;
        }
     }

   //============================================================
   // 3) بررسی سایر Dealهای همان Position
   //============================================================
   const ulong position_id =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

   if(position_id == 0)
      return false;

   bool found = false;

   if(HistorySelectByPosition(position_id))
     {
      const int position_deals_total = HistoryDealsTotal();

      for(int i = 0; i < position_deals_total; i++)
        {
         const ulong related_deal =
            HistoryDealGetTicket(i);

         if(related_deal == 0)
            continue;

         //--- Magic مستقیم Deal مرتبط
         const ulong related_magic =
            (ulong)HistoryDealGetInteger(related_deal, DEAL_MAGIC);

         if(related_magic == magic_number)
           {
            found = true;
            break;
           }

         //--- Magic Order مرتبط
         const ulong related_order =
            (ulong)HistoryDealGetInteger(related_deal, DEAL_ORDER);

         if(related_order > 0)
           {
            if(HistoryOrderSelect(related_order))
              {
               const ulong related_order_magic =
                  (ulong)HistoryOrderGetInteger(
                     related_order,
                     ORDER_MAGIC);

               if(related_order_magic == magic_number)
                 {
                  found = true;
                  break;
                 }
              }
           }
        }
     }

   //============================================================
   // بازگرداندن History اصلی برای حلقه اصلی
   //============================================================
   HistorySelect(0, TimeCurrent());

   return found;
  }

//====================================================================
// Profit Factor
//====================================================================
double PerformanceReport_CalculateProfitFactor(
   const PerformanceReportState &report)
  {
   if(report.gross_loss < 0.0)
     {
      const double loss = MathAbs(report.gross_loss);

      if(loss <= 0.00000001)
         return 0.0;

      return(report.gross_profit / loss);
     }

   if(report.gross_profit > 0.0)
      return DBL_MAX;

   return 0.0;
  }

//====================================================================
// Equity / Drawdown
//====================================================================
void PerformanceReport_UpdateEquity(
   PerformanceReportState &report)
  {
   report.current_balance =
      AccountInfoDouble(ACCOUNT_BALANCE);

   report.current_equity =
      AccountInfoDouble(ACCOUNT_EQUITY);

   if(report.current_equity > report.peak_equity)
      report.peak_equity = report.current_equity;

   report.current_drawdown_money =
      report.peak_equity - report.current_equity;

   if(report.peak_equity > 0.0)
     {
      report.current_drawdown_percent =
         (report.current_drawdown_money /
          report.peak_equity) * 100.0;
     }
   else
     {
      report.current_drawdown_percent = 0.0;
     }

   if(report.current_drawdown_money >
      report.maximum_drawdown_money)
     {
      report.maximum_drawdown_money =
         report.current_drawdown_money;
     }

   if(report.current_drawdown_percent >
      report.maximum_drawdown_percent)
     {
      report.maximum_drawdown_percent =
         report.current_drawdown_percent;
     }
  }

//====================================================================
// بازسازی آمار از History
//====================================================================
bool PerformanceReport_RebuildFromHistory(
   PerformanceReportState &report,
   const ulong magic_number)
  {
   //============================================================
   // انتخاب کل History
   //============================================================
   ResetLastError();

   if(!HistorySelect(0, TimeCurrent()))
     {
      const int error_code = GetLastError();

      Print(
         "[Performance Report] HistorySelect FAILED",
         " | Error=", error_code
      );

      return false;
     }

   //============================================================
   // ریست آمار
   //============================================================
   report.total_trades         = 0;
   report.winning_trades       = 0;
   report.losing_trades        = 0;
   report.breakeven_trades     = 0;

   report.gross_profit         = 0.0;
   report.gross_loss           = 0.0;
   report.net_profit           = 0.0;
   report.profit_factor        = 0.0;

   report.partial_close_count  = 0;
   report.partial_close_profit = 0.0;

   //============================================================
   // آرایه Positionها
   //============================================================
   ulong  position_ids[];
   double position_results[];
   int    position_exit_count[];

   ArrayResize(position_ids,0);
   ArrayResize(position_results,0);
   ArrayResize(position_exit_count,0);

   //============================================================
   // آمار تشخیصی
   //============================================================
   int all_deals         = 0;
   int symbol_deals      = 0;
   int symbol_exit_deals = 0;
   int magic_exit_deals  = 0;

   const int history_total = HistoryDealsTotal();

   int diagnostic_printed = 0;
   const int MAX_DIAGNOSTIC_LOGS = 10;

   //============================================================
   // پیمایش Dealها
   //
   // نکته مهم:
   // از HistoryDealGetTicket(i) استفاده می‌کنیم و داخل حلقه
   // دوباره HistoryDealSelect(deal_ticket) انجام نمی‌دهیم.
   //============================================================
   for(int i = 0; i < history_total; i++)
     {
      const ulong deal_ticket =
         HistoryDealGetTicket(i);

      if(deal_ticket == 0)
         continue;

      all_deals++;

      //=========================================================
      // Symbol
      //=========================================================
      string deal_symbol =
         HistoryDealGetString(
            deal_ticket,
            DEAL_SYMBOL
         );

      //=========================================================
      // اگر Deal Symbol خالی بود:
      // از Order مرتبط به عنوان fallback استفاده می‌کنیم.
      //=========================================================
      if(StringLen(deal_symbol) == 0)
        {
         const ulong fallback_order =
            (ulong)HistoryDealGetInteger(
               deal_ticket,
               DEAL_ORDER
            );

         if(fallback_order > 0)
           {
            if(HistoryOrderSelect(fallback_order))
              {
               deal_symbol =
                  HistoryOrderGetString(
                     fallback_order,
                     ORDER_SYMBOL
                  );
              }

            // restore
            HistorySelect(0, TimeCurrent());
           }
        }

      //=========================================================
      // Symbol ناشناخته
      //=========================================================
      if(StringLen(deal_symbol) == 0)
        {
         if(diagnostic_printed < MAX_DIAGNOSTIC_LOGS)
           {
            const ulong diag_magic =
               (ulong)HistoryDealGetInteger(
                  deal_ticket,
                  DEAL_MAGIC
               );

            const ulong diag_order =
               (ulong)HistoryDealGetInteger(
                  deal_ticket,
                  DEAL_ORDER
               );

            const ulong diag_posid =
               (ulong)HistoryDealGetInteger(
                  deal_ticket,
                  DEAL_POSITION_ID
               );

            const long diag_entry =
               HistoryDealGetInteger(
                  deal_ticket,
                  DEAL_ENTRY
               );

            Print(
               "[Performance Report] DIAG",
               " | Deal=", deal_ticket,
               " | DealSymbol=EMPTY",
               " | ExpectedSymbol=", _Symbol,
               " | Magic=", diag_magic,
               " | Order=", diag_order,
               " | PosID=", diag_posid,
               " | Entry=", diag_entry,
               " | Skipped=SYMBOL_UNKNOWN"
            );

            diagnostic_printed++;
           }

         continue;
        }

      //=========================================================
      // Symbol mismatch
      //=========================================================
      if(StringCompare(
            deal_symbol,
            _Symbol,
            false) != 0)
        {
         if(diagnostic_printed < MAX_DIAGNOSTIC_LOGS)
           {
            Print(
               "[Performance Report] DIAG",
               " | Deal=", deal_ticket,
               " | DealSymbol=", deal_symbol,
               " | ExpectedSymbol=", _Symbol,
               " | Skipped=SYMBOL_MISMATCH"
            );

            diagnostic_printed++;
           }

         continue;
        }

      symbol_deals++;

      //=========================================================
      // Entry
      //=========================================================
      const long deal_entry =
         HistoryDealGetInteger(
            deal_ticket,
            DEAL_ENTRY
         );

      //=========================================================
      // فقط Dealهای خروجی
      //=========================================================
      if(deal_entry != DEAL_ENTRY_OUT &&
         deal_entry != DEAL_ENTRY_OUT_BY &&
         deal_entry != DEAL_ENTRY_INOUT)
         continue;

      symbol_exit_deals++;

      //=========================================================
      // اطلاعات Deal
      //=========================================================
      const ulong deal_magic =
         (ulong)HistoryDealGetInteger(
            deal_ticket,
            DEAL_MAGIC
         );

      const ulong deal_order =
         (ulong)HistoryDealGetInteger(
            deal_ticket,
            DEAL_ORDER
         );

      const ulong deal_posid =
         (ulong)HistoryDealGetInteger(
            deal_ticket,
            DEAL_POSITION_ID
         );

      const long deal_type =
         HistoryDealGetInteger(
            deal_ticket,
            DEAL_TYPE
         );

      const double deal_profit =
         HistoryDealGetDouble(
            deal_ticket,
            DEAL_PROFIT
         );

      //=========================================================
      // مالکیت EA
      //=========================================================
      const bool belongs =
         PerformanceReport_DealBelongsToEA(
            deal_ticket,
            magic_number
         );

      if(belongs)
        {
         magic_exit_deals++;
        }
      else
        {
         //======================================================
         // تشخیص Magic mismatch
         //======================================================
         if(diagnostic_printed < MAX_DIAGNOSTIC_LOGS)
           {
            ulong order_magic = 0;

            if(deal_order > 0)
              {
               if(HistoryOrderSelect(deal_order))
                 {
                  order_magic =
                     (ulong)HistoryOrderGetInteger(
                        deal_order,
                        ORDER_MAGIC
                     );
                 }

               // restore
               HistorySelect(0, TimeCurrent());
              }

            Print(
               "[Performance Report] DIAG",
               " | ExitDeal=", deal_ticket,
               " | Symbol=", deal_symbol,
               " | DealMagic=", deal_magic,
               " | OrderMagic=", order_magic,
               " | Order=", deal_order,
               " | PosID=", deal_posid,
               " | Type=",
               EnumToString(
                  (ENUM_DEAL_TYPE)deal_type
               ),
               " | Profit=",
               DoubleToString(
                  deal_profit,
                  2
               ),
               " | RequiredMagic=",
               magic_number,
               " | Skipped=MAGIC_MISMATCH"
            );

            diagnostic_printed++;
           }

         continue;
        }

      //=========================================================
      // Position ID معتبر
      //=========================================================
      if(deal_posid == 0)
         continue;

      //=========================================================
      // نتیجه واقعی Deal
      //
      // شامل:
      // Profit
      // Swap
      // Commission
      // Fee
      //=========================================================
      const double result =
         HistoryDealGetDouble(
            deal_ticket,
            DEAL_PROFIT
         )
         +
         HistoryDealGetDouble(
            deal_ticket,
            DEAL_SWAP
         )
         +
         HistoryDealGetDouble(
            deal_ticket,
            DEAL_COMMISSION
         )
         +
         HistoryDealGetDouble(
            deal_ticket,
            DEAL_FEE
         );

      //=========================================================
      // یافتن Position در آرایه
      //=========================================================
      int index = -1;

      const int known =
         ArraySize(position_ids);

      for(int k = 0; k < known; k++)
        {
         if(position_ids[k] == deal_posid)
           {
            index = k;
            break;
           }
        }

      //=========================================================
      // Position جدید
      //=========================================================
      if(index < 0)
        {
         index = ArraySize(position_ids);

         ArrayResize(
            position_ids,
            index + 1
         );

         ArrayResize(
            position_results,
            index + 1
         );

         ArrayResize(
            position_exit_count,
            index + 1
         );

         position_ids[index] =
            deal_posid;

         position_results[index] =
            0.0;

         position_exit_count[index] =
            0;
        }

      //=========================================================
      // تجمیع نتیجه
      //=========================================================
      position_results[index] += result;
      position_exit_count[index]++;
     }

   //=============================================================
   // تبدیل Position به Trade
   //=============================================================
   const int position_count =
      ArraySize(position_ids);

   for(int i = 0; i < position_count; i++)
     {
      if(position_exit_count[i] <= 0)
         continue;

      const double trade_result =
         position_results[i];

      report.total_trades++;

      report.net_profit +=
         trade_result;

      //=========================================================
      // Partial Close
      //=========================================================
      if(position_exit_count[i] > 1)
        {
         report.partial_close_count +=
            (position_exit_count[i] - 1);
        }

      //=========================================================
      // برد
      //=========================================================
      if(trade_result > 0.0)
        {
         report.winning_trades++;

         report.gross_profit +=
            trade_result;
        }
      //=========================================================
      // باخت
      //=========================================================
      else
      if(trade_result < 0.0)
        {
         report.losing_trades++;

         report.gross_loss +=
            trade_result;
        }
      //=========================================================
      // سر به سر
      //=========================================================
      else
        {
         report.breakeven_trades++;
        }
     }

   //=============================================================
   // Profit Factor
   //=============================================================
   report.profit_factor =
      PerformanceReport_CalculateProfitFactor(
         report
      );

   //=============================================================
   // Diagnostic نهایی
   //=============================================================
   Print(
      "[Performance Report] HISTORY CHECK",
      " | Symbol=", _Symbol,
      " | Magic=", (string)magic_number,
      " | AllHistoryDeals=", history_total,
      " | AllSymbolDeals=", symbol_deals,
      " | SymbolExitDeals=", symbol_exit_deals,
      " | MatchingEAExitDeals=", magic_exit_deals,
      " | Positions=", position_count,
      " | Trades=", report.total_trades,
      " | Wins=", report.winning_trades,
      " | Losses=", report.losing_trades,
      " | BE=", report.breakeven_trades,
      " | Net=", DoubleToString(
         report.net_profit,
         2
      ),
      " | PF=", DoubleToString(
         report.profit_factor,
         2
      )
   );

   //=============================================================
   // هشدار Magic
   //=============================================================
   if(symbol_exit_deals > 0 &&
      magic_exit_deals == 0)
     {
      Print(
         "[Performance Report] WARNING | ",
         symbol_exit_deals,
         " معامله خروجی روی ",
         _Symbol,
         " وجود دارد اما هیچ‌کدام با Magic=",
         magic_number,
         " تطبیق ندارند. "
         "لطفاً DIAG را بررسی کنید."
      );
     }

   return true;
  }

//====================================================================
// ثبت دستی معامله
//====================================================================
void PerformanceReport_RegisterClosedTrade(
   PerformanceReportState &report,
   const double net_profit)
  {
   report.total_trades++;

   report.net_profit +=
      net_profit;

   if(net_profit > 0.0)
     {
      report.winning_trades++;

      report.gross_profit +=
         net_profit;
     }
   else
   if(net_profit < 0.0)
     {
      report.losing_trades++;

      report.gross_loss +=
         net_profit;
     }
   else
     {
      report.breakeven_trades++;
     }

   report.profit_factor =
      PerformanceReport_CalculateProfitFactor(
         report
      );
  }

//====================================================================
// Partial Close
//====================================================================
void PerformanceReport_RegisterPartialClose(
   PerformanceReportState &report,
   const double net_profit)
  {
   report.partial_close_count++;

   report.partial_close_profit +=
      net_profit;
  }

//====================================================================
// معاملات باز
//====================================================================
void PerformanceReport_SetOpenTrades(
   PerformanceReportState &report,
   const int count,
   const double profit)
  {
   report.open_trades =
      MathMax(0, count);

   report.open_profit =
      profit;
  }

//====================================================================
// Pending
//====================================================================
void PerformanceReport_SetPendingOrders(
   PerformanceReportState &report,
   const int total,
   const int active)
  {
   report.total_pending_orders =
      MathMax(0, total);

   report.active_pending_orders =
      MathMax(0, active);
  }

//====================================================================
// Update
//====================================================================
bool PerformanceReport_Update(
   PerformanceReportState &report,
   const datetime current_time,
   const ulong magic_number)
  {
   if(!report.initialized)
      PerformanceReport_Start(report);

   //============================================================
   // Equity
   //============================================================
   PerformanceReport_UpdateEquity(
      report
   );

   //============================================================
   // History
   //============================================================
   const bool history_ok =
      PerformanceReport_RebuildFromHistory(
         report,
         magic_number
      );

   //============================================================
   // وضعیت
   //============================================================
   report.status =
      "فعال";

   report.last_update_time =
      current_time;

   report.next_update_time =
      current_time + 3600;

   report.update_count++;

   if(history_ok)
     {
      report.last_note =
         "آمار از History واقعی بازسازی شد";
     }
   else
     {
      report.last_note =
         "بازسازی History ناموفق بود";
     }

   return history_ok;
  }

//====================================================================
// Win Rate
//====================================================================
double PerformanceReport_WinRate(
   const PerformanceReportState &report)
  {
   if(report.total_trades <= 0)
      return 0.0;

   return(
      ((double)report.winning_trades /
       (double)report.total_trades)
      * 100.0
   );
  }

//====================================================================
// Average Profit
//====================================================================
double PerformanceReport_AverageProfit(
   const PerformanceReportState &report)
  {
   if(report.total_trades <= 0)
      return 0.0;

   return(
      report.net_profit /
      (double)report.total_trades
   );
  }

//====================================================================
// Average Win
//====================================================================
double PerformanceReport_AverageWin(
   const PerformanceReportState &report)
  {
   if(report.winning_trades <= 0)
      return 0.0;

   return(
      report.gross_profit /
      (double)report.winning_trades
   );
  }

//====================================================================
// Average Loss
//====================================================================
double PerformanceReport_AverageLoss(
   const PerformanceReportState &report)
  {
   if(report.losing_trades <= 0)
      return 0.0;

   return(
      report.gross_loss /
      (double)report.losing_trades
   );
  }

//====================================================================
// خلاصه فارسی
//====================================================================
string PerformanceReport_ToPersian(
   const PerformanceReportState &report)
  {
   string text = "";

   text +=
      "وضعیت گزارش: " +
      report.status;

   text +=
      " | تعداد معاملات: " +
      IntegerToString(
         report.total_trades
      );

   text +=
      " | برد: " +
      IntegerToString(
         report.winning_trades
      );

   text +=
      " | باخت: " +
      IntegerToString(
         report.losing_trades
      );

   text +=
      " | سر به سر: " +
      IntegerToString(
         report.breakeven_trades
      );

   text +=
      " | نرخ برد: " +
      DoubleToString(
         PerformanceReport_WinRate(report),
         2
      ) +
      "%";

   text +=
      " | سود خالص: " +
      DoubleToString(
         report.net_profit,
         2
      );

   text +=
      " | سود ناخالص: " +
      DoubleToString(
         report.gross_profit,
         2
      );

   text +=
      " | زیان ناخالص: " +
      DoubleToString(
         report.gross_loss,
         2
      );

   text +=
      " | Profit Factor: " +
      DoubleToString(
         report.profit_factor,
         2
      );

   text +=
      " | معاملات باز: " +
      IntegerToString(
         report.open_trades
      );

   text +=
      " | سود/ضرر باز: " +
      DoubleToString(
         report.open_profit,
         2
      );

   text +=
      " | Drawdown فعلی: " +
      DoubleToString(
         report.current_drawdown_percent,
         2
      ) +
      "%";

   text +=
      " | بیشترین Drawdown: " +
      DoubleToString(
         report.maximum_drawdown_percent,
         2
      ) +
      "%";

   text +=
      " | Pending فعال: " +
      IntegerToString(
         report.active_pending_orders
      );

   return text;
  }

//====================================================================
// اطلاعات تکمیلی
//====================================================================
string PerformanceReport_ToDetailedSummary(
   const PerformanceReportState &report)
  {
   string text = "";

   text +=
      "میانگین سود هر معامله: " +
      DoubleToString(
         PerformanceReport_AverageProfit(report),
         2
      );

   text +=
      " | میانگین معاملات برنده: " +
      DoubleToString(
         PerformanceReport_AverageWin(report),
         2
      );

   text +=
      " | میانگین معاملات بازنده: " +
      DoubleToString(
         PerformanceReport_AverageLoss(report),
         2
      );

   text +=
      " | Partial Close: " +
      IntegerToString(
         report.partial_close_count
      );

   text +=
      " | سود Partial Close: " +
      DoubleToString(
         report.partial_close_profit,
         2
      );

   text +=
      " | موجودی: " +
      DoubleToString(
         report.current_balance,
         2
      );

   text +=
      " | Equity: " +
      DoubleToString(
         report.current_equity,
         2
      );

   text +=
      " | Peak Equity: " +
      DoubleToString(
         report.peak_equity,
         2
      );

   text +=
      " | بیشترین Drawdown دلاری: " +
      DoubleToString(
         report.maximum_drawdown_money,
         2
      );

   return text;
  }

//====================================================================
// Note
//====================================================================
void PerformanceReport_SetNote(
   PerformanceReportState &report,
   const string note)
  {
   report.last_note =
      note;
  }

//====================================================================
// زمان باقی‌مانده
//====================================================================
int PerformanceReport_SecondsToNextUpdate(
   const PerformanceReportState &report,
   const datetime current_time)
  {
   if(report.next_update_time <= 0)
      return 0;

   const long remaining =
      (long)report.next_update_time -
      (long)current_time;

   if(remaining <= 0)
      return 0;

   if(remaining > 2147483647)
      return 2147483647;

   return (int)remaining;
  }

//====================================================================
// End
//====================================================================
#endif