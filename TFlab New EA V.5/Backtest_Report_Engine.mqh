#ifndef __TFLAB_BACKTEST_REPORT_ENGINE_MQH__
#define __TFLAB_BACKTEST_REPORT_ENGINE_MQH__

//+------------------------------------------------------------------+
//|                Backtest_Report_Engine.mqh                       |
//| گزارش‌های اختصاصی Strategy Tester در همان فضای فایل تست          |
//+------------------------------------------------------------------+
#property strict

#include "Performance_Report.mqh"

struct BacktestReportState
  {
   bool      enabled;
   bool      initialized;
   datetime  last_equity_time;
   string    equity_file;
   string    trades_file;
   string    summary_file;
   string    management_file;
  };

void BacktestReport_InitState(BacktestReportState &state)
  {
   ZeroMemory(state);
   state.enabled=false;
   state.initialized=false;
   state.last_equity_time=0;
   state.equity_file="TFlab_BACKTEST_Equity.csv";
   state.trades_file="TFlab_BACKTEST_Trades.csv";
   state.summary_file="TFlab_BACKTEST_Summary.csv";
   state.management_file="TFlab_BACKTEST_Trade_Management.csv";
  }

string BacktestReport_Escape(const string value)
  {
   string s=value;
   StringReplace(s,"\"","\"\"");
   return "\""+s+"\"";
  }

bool BacktestReport_OpenAppend(const string filename,int &handle,const string header)
  {
   handle=FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(handle==INVALID_HANDLE)
      return false;

   if(FileSize(handle)==0 && header!="")
      FileWriteString(handle,header+"\r\n");
   FileSeek(handle,0,SEEK_END);
   return true;
  }

void BacktestReport_Init(BacktestReportState &state)
  {
   state.enabled = (MQLInfoInteger(MQL_TESTER) && Inp_Enable_Performance_Report);
   if(!state.enabled)
      return;

   state.initialized=true;

   int h=INVALID_HANDLE;
   if(BacktestReport_OpenAppend(state.equity_file,h,"زمان;Balance;Equity;OpenProfit;OpenTrades;DrawdownMoney;DrawdownPercent"))
      FileClose(h);
   if(BacktestReport_OpenAppend(state.trades_file,h,"PositionID;Symbol;Magic;Direction;EntryTime;ExitTime;EntryVolume;ExitVolume;EntryPrice;ExitPrice;Profit;Swap;Commission;Net;DurationMinutes;CloseReason"))
      FileClose(h);
   if(BacktestReport_OpenAppend(state.summary_file,h,"زمان;TotalTrades;Wins;Losses;Breakeven;WinRate;GrossProfit;GrossLoss;NetProfit;ProfitFactor;Balance;Equity;MaxDDMoney;MaxDDPercent"))
      FileClose(h);
   if(BacktestReport_OpenAppend(state.management_file,h,"زمان;PositionID;Ticket;Direction;Entry;Current;SL;TP;Profit;ContinuationScore;ReversalScore;Action;Reason"))
      FileClose(h);

   Print("[BACKTEST REPORT] فعال شد | خروجی‌ها در پوشه داخلی Strategy Tester ساخته می‌شوند");
  }

void BacktestReport_WriteEquity(BacktestReportState &state,const PerformanceReportState &report,const datetime now)
  {
   if(!state.enabled || !state.initialized)
      return;

   if(now==state.last_equity_time)
      return;

   int h=INVALID_HANDLE;
   if(!BacktestReport_OpenAppend(state.equity_file,h,""))
      return;

   FileWrite(h,
      TimeToString(now,TIME_DATE|TIME_SECONDS),
      DoubleToString(report.current_balance,2),
      DoubleToString(report.current_equity,2),
      DoubleToString(report.open_profit,2),
      IntegerToString(report.open_trades),
      DoubleToString(report.current_drawdown_money,2),
      DoubleToString(report.current_drawdown_percent,2));

   FileClose(h);
   state.last_equity_time=now;
  }

void BacktestReport_WriteManagementSnapshot(
   BacktestReportState &state,
   const datetime now,
   const ulong position_id,
   const ulong ticket,
   const string direction,
   const double entry,
   const double current,
   const double sl,
   const double tp,
   const double profit,
   const double continuation_score,
   const double reversal_score,
   const string action,
   const string reason)
  {
   if(!state.enabled || !state.initialized)
      return;

   int h=INVALID_HANDLE;
   if(!BacktestReport_OpenAppend(state.management_file,h,""))
      return;

   FileWrite(h,
      TimeToString(now,TIME_DATE|TIME_SECONDS),
      (string)position_id,
      (string)ticket,
      BacktestReport_Escape(direction),
      DoubleToString(entry,_Digits),
      DoubleToString(current,_Digits),
      DoubleToString(sl,_Digits),
      DoubleToString(tp,_Digits),
      DoubleToString(profit,2),
      DoubleToString(continuation_score,1),
      DoubleToString(reversal_score,1),
      BacktestReport_Escape(action),
      BacktestReport_Escape(reason));

   FileClose(h);
  }

void BacktestReport_WriteTrades(BacktestReportState &state)
  {
   if(!state.enabled || !state.initialized)
      return;

   int h=INVALID_HANDLE;
   if(!BacktestReport_OpenAppend(state.trades_file,h,""))
      return;

   if(!HistorySelect(0,TimeCurrent()))
     {
      FileClose(h);
      return;
     }

   long seen_ids[];
   ArrayResize(seen_ids,0);

   int deals=HistoryDealsTotal();
   for(int i=0;i<deals;i++)
     {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0)
         continue;

      if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol)
         continue;
      if((ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=Inp_MagicNumber)
         continue;

      long pos_id=HistoryDealGetInteger(deal,DEAL_POSITION_ID);
      if(pos_id<=0)
         continue;

      bool already=false;
      for(int j=0;j<ArraySize(seen_ids);j++)
         if(seen_ids[j]==pos_id) { already=true; break; }
      if(already)
         continue;

      int n=ArraySize(seen_ids);
      ArrayResize(seen_ids,n+1);
      seen_ids[n]=pos_id;

      if(!HistorySelectByPosition((ulong)pos_id))
         continue;

      int pd=HistoryDealsTotal();
      datetime entry_time=0, exit_time=0;
      double entry_vol=0.0, exit_vol=0.0;
      double entry_pv=0.0, exit_pv=0.0;
      double profit=0.0, swap=0.0, commission=0.0;
      string direction="";
      string reason="";

      for(int k=0;k<pd;k++)
        {
         ulong d=HistoryDealGetTicket(k);
         if(d==0) continue;

         ENUM_DEAL_ENTRY de=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);
         ENUM_DEAL_TYPE  dt=(ENUM_DEAL_TYPE)HistoryDealGetInteger(d,DEAL_TYPE);
         double vol=HistoryDealGetDouble(d,DEAL_VOLUME);
         double price=HistoryDealGetDouble(d,DEAL_PRICE);
         datetime t=(datetime)HistoryDealGetInteger(d,DEAL_TIME);

         profit+=HistoryDealGetDouble(d,DEAL_PROFIT);
         swap+=HistoryDealGetDouble(d,DEAL_SWAP);
         commission+=HistoryDealGetDouble(d,DEAL_COMMISSION);

         if(de==DEAL_ENTRY_IN)
           {
            if(entry_time==0 || t<entry_time) entry_time=t;
            entry_vol+=vol;
            entry_pv+=price*vol;
            if(direction=="")
               direction=(dt==DEAL_TYPE_BUY ? "BUY" : "SELL");
           }
         else if(de==DEAL_ENTRY_OUT || de==DEAL_ENTRY_OUT_BY)
           {
            if(exit_time==0 || t>exit_time) exit_time=t;
            exit_vol+=vol;
            exit_pv+=price*vol;
            string c=HistoryDealGetString(d,DEAL_COMMENT);
            if(c!="") reason=c;
           }
        }

      double entry_price=(entry_vol>0.0 ? entry_pv/entry_vol : 0.0);
      double exit_price=(exit_vol>0.0 ? exit_pv/exit_vol : 0.0);
      double net=profit+swap+commission;
      double duration=(entry_time>0 && exit_time>0 ? (double)(exit_time-entry_time)/60.0 : 0.0);

      FileWrite(h,
         (string)pos_id,
         BacktestReport_Escape(_Symbol),
         (string)Inp_MagicNumber,
         BacktestReport_Escape(direction),
         TimeToString(entry_time,TIME_DATE|TIME_SECONDS),
         TimeToString(exit_time,TIME_DATE|TIME_SECONDS),
         DoubleToString(entry_vol,4),
         DoubleToString(exit_vol,4),
         DoubleToString(entry_price,_Digits),
         DoubleToString(exit_price,_Digits),
         DoubleToString(profit,2),
         DoubleToString(swap,2),
         DoubleToString(commission,2),
         DoubleToString(net,2),
         DoubleToString(duration,1),
         BacktestReport_Escape(reason));

      // HistorySelectByPosition را برای حلقه بعدی بازیابی می‌کنیم
      HistorySelect(0,TimeCurrent());
     }

   FileClose(h);
  }

void BacktestReport_WriteSummary(BacktestReportState &state,const PerformanceReportState &report,const datetime now)
  {
   if(!state.enabled || !state.initialized)
      return;

   int h=INVALID_HANDLE;
   if(!BacktestReport_OpenAppend(state.summary_file,h,""))
      return;

   FileWrite(h,
      TimeToString(now,TIME_DATE|TIME_SECONDS),
      IntegerToString(report.total_trades),
      IntegerToString(report.winning_trades),
      IntegerToString(report.losing_trades),
      IntegerToString(report.breakeven_trades),
      DoubleToString(report.total_trades>0 ? 100.0*report.winning_trades/report.total_trades : 0.0,2),
      DoubleToString(report.gross_profit,2),
      DoubleToString(report.gross_loss,2),
      DoubleToString(report.net_profit,2),
      DoubleToString(report.profit_factor,2),
      DoubleToString(report.current_balance,2),
      DoubleToString(report.current_equity,2),
      DoubleToString(report.maximum_drawdown_money,2),
      DoubleToString(report.maximum_drawdown_percent,2));

   FileClose(h);
  }

void BacktestReport_Finalize(BacktestReportState &state,PerformanceReportState &report)
  {
   if(!state.enabled || !state.initialized)
      return;

   PerformanceReport_Update(report,TimeCurrent(),Inp_MagicNumber);
   BacktestReport_WriteEquity(state,report,TimeCurrent());
   BacktestReport_WriteSummary(state,report,TimeCurrent());
   BacktestReport_WriteTrades(state);

   Print("[BACKTEST REPORT] نهایی شد | Summary + Equity + Trades + Management + Word/RTF");
  }

#endif // __TFLAB_BACKTEST_REPORT_ENGINE_MQH__
