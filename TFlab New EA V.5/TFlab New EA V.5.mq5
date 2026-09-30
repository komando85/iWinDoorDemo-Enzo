//+------------------------------------------------------------------+
//|                         EA_Main.mq5                               |
//|                    TFlab New EA V.5- Orchestrator                |
//+------------------------------------------------------------------+
#property strict
#property version   "5.12"
#property description "TFlab New EA V5.12 | Dynamic TP + Confirmed Reversal + Signal Audit"

#include "EA_Inputs.mqh"
#include "Market_HigherTimeframe.mqh"
#include "Market_Context.mqh"
#include "Market_Regime.mqh"
#include "Market_Structure.mqh"
#include "Divergence_Detector.mqh"
#include "Candle_Confirmation.mqh"
#include "News_Filter.mqh"
#include "Confluence_Engine.mqh"
#include "Impulse_Correction.mqh"
#include "Market_Truth_Engine.mqh"
#include "Market_Reading_Engine.mqh"
#include "Filter_Audit.mqh"
#include "Report_Word_Engine.mqh"
#include "AI_Journal.mqh"
#include "AI_Suggestion_Engine.mqh"
#include "AI_Independent_Analysis.mqh"
#include "M5_Movement_Metrics.mqh"
#include "M5_Zone_Quality_Analyzer.mqh"
#include "Zone_Engine.mqh"
#include "Strategy_Engine.mqh"
#include "Scenario_Engine.mqh"
#include "Invalidation_Engine.mqh"
#include "Setup_Detector.mqh"
#include "Entry_Planner.mqh"
#include "Target_Engine.mqh"
#include "SL_Engine.mqh"
#include "TP_Engine.mqh"
#include "Risk_Engine.mqh"
#include "Execution_Engine.mqh"
#include "Trade_Signal_Label.mqh"
#include "Pending_Order_Manager.mqh"
#include "Trade_Manager.mqh"
#include "Trade_Logger.mqh"
#include "Detailed_Logger.mqh"
#include "Performance_Report.mqh"
#include "AI_Data.mqh"
#include "AI_Learning.mqh"
#include "AI_Analyzer.mqh"
#include "AI_VirtualTrader.mqh"
#include "AI_Advisor.mqh"
#include "Chart_Panel.mqh"
#include "Test_Report_Logger.mqh"
#include "Scenario_VirtualTester.mqh"
#include "Backtest_Report_Engine.mqh"
#include "Signal_Audit_Engine.mqh"



//====================================================================
// متغیرهای سراسری AI
//====================================================================
AIVirtualEngineState   g_ai_virtual_engine;
AIVirtualTrade         g_virtual_trades[];
ulong                  g_virtual_scenario_id = 0;
AIAdvisorMessage       g_ai_advice;
AIPatternKnowledge     g_ai_pattern_knowledge;
AILearningSummary      g_ai_learning_summary;
ENUM_STRATEGY_TYPE      g_last_strategy_type = STRATEGY_NONE;
double                   g_last_strategy_confidence = 0.0;

//====================================================================
// وضعیت اصلی EA
//====================================================================
struct EAMainState
{
   bool      initialized;
   bool      trading_enabled;
   datetime  start_time;
   datetime  last_tick_time;
   datetime  last_monitor_time;
   datetime  last_analysis_time;
   datetime  last_analysis_bar;
   string    last_error;
};

//====================================================================
// متغیرهای سراسری
//====================================================================
EAMainState                g_main_state;
MarketContextSnapshot      g_context;
MarketRegimeState          g_regime;
MarketStructureSnapshot    g_structure;
ImpulseCorrectionSnapshot  g_move;
MarketTruthSnapshot        g_market_truth;
MarketReadingSnapshot      g_market_reading;
FilterAuditState           g_filter_audit;
ZoneInfo                   g_buy_zone;
ZoneInfo                   g_sell_zone;
M5MovementMetrics          g_m5_metrics;
M5ZoneQualitySnapshot      g_m5_zone_quality;
TradingScenario            g_scenario;
SetupState                 g_setup;
EntryPlan                  g_entry_plan;
SLPlan                     g_sl_plan;
TP_Result                  g_tp_result;
TargetInfo                 g_target;
RiskLimits                 g_risk_limits;
RiskAccountState           g_risk_account;
RiskResult                 g_risk_result;
PendingOrderRecord         g_pending;

//====================================================================
// سهمیه Pending برای هر Scenario
//====================================================================
#define TFLAB_PENDING_TRACK_LIMIT 20
PendingOrderRecord         g_pending_pool[];
ChartPanelState            g_panel;
PerformanceReportState     g_performance;
DetailedLoggerConfig       g_detailed_config;
DetailedLoggerState        g_detailed_state;
TestReportLoggerState      g_test_logger;
BacktestReportState        g_backtest_report;
SignalAuditState            g_signal_audit;

//====================================================================
// رصد دقیقه‌ای بازار برای مدیریت TP و برگشت قطعی
//====================================================================
struct MinuteMarketMonitorState
{
   bool                valid;
   datetime            analysis_time;
   MarketRegimeState   m1_regime;
   MarketTruthSnapshot m5_truth;
   double              buy_continuation;
   double              sell_continuation;
   double              buy_reversal;
   double              sell_reversal;
};

MinuteMarketMonitorState g_minute_monitor;

struct DynamicTPTrackerState
{
   ulong    position_id;
   ulong    ticket;
   double   entry_price;
   double   initial_tp;
   datetime first_seen;
   datetime last_seen;
};

DynamicTPTrackerState g_dynamic_tp_tracker[];

//====================================================================
// شناسه‌ها و حالت‌های ویژه
//====================================================================
datetime  g_last_m5_closed_bar        = 0;
string    g_last_scenario_diagnostic  = "";
ulong     g_last_executed_scenario_id = 0;
bool      g_is_transition_mode        = false;
string    g_risk_block_reason         = "";

//====================================================================
// دریافت قیمت جاری
//====================================================================
bool GetCurrentPrices(double &bid, double &ask, double &mid)
{
   bid = 0.0;
   ask = 0.0;
   mid = 0.0;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return false;

   bid = tick.bid;
   ask = tick.ask;
   mid = (tick.bid + tick.ask) * 0.5;

   return (bid > 0.0 && ask > 0.0);
}

//====================================================================
// تعداد معاملات باز
//====================================================================
int CountOpenPositions()
{
   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC) != Inp_MagicNumber)
         continue;

      count++;
   }

   return count;
}

//====================================================================
// تعداد سفارش‌های Pending فعال این ربات
//====================================================================
int CountPendingOrders()
{
   int count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;

      if((ulong)OrderGetInteger(ORDER_MAGIC) != Inp_MagicNumber)
         continue;

      count++;
   }

   return count;
}

//====================================================================
// تعداد کل موقعیت‌ها
//====================================================================
int CountTotalExposure()
{
   return CountOpenPositions() + CountPendingOrders();
}

//====================================================================
// سود معاملات باز
//====================================================================
double OpenProfit()
{
   double value = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(!Inp_Show_All_Trades_In_Panel)
      {
         if((ulong)PositionGetInteger(POSITION_MAGIC) != Inp_MagicNumber)
            continue;
      }

      value += PositionGetDouble(POSITION_PROFIT);
      value += PositionGetDouble(POSITION_SWAP);
   }

   return value;
}

//====================================================================
// بررسی سریع تعلق Deal به همین EA
//====================================================================
bool IsEAHistoryDealTicket(const ulong deal_ticket)
{
   if(deal_ticket == 0)
      return false;

   if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
      return false;

   if((ulong)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) ==
      (ulong)Inp_MagicNumber)
      return true;

   ulong order_ticket =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);

   if(order_ticket > 0 && HistoryOrderSelect(order_ticket))
   {
      if((ulong)HistoryOrderGetInteger(order_ticket, ORDER_MAGIC) ==
         (ulong)Inp_MagicNumber)
         return true;
   }

   return false;
}

//====================================================================
// بررسی کامل تعلق Deal به همین EA
//====================================================================
bool DealBelongsToEA(const ulong deal_ticket)
{
   if(deal_ticket == 0)
      return false;

   if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
      return false;

   if((ulong)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) ==
      (ulong)Inp_MagicNumber)
      return true;

   ulong order_ticket =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_ORDER);

   if(order_ticket > 0 && HistoryOrderSelect(order_ticket))
   {
      if((ulong)HistoryOrderGetInteger(order_ticket, ORDER_MAGIC) ==
         (ulong)Inp_MagicNumber)
         return true;
   }

   ulong position_id =
      (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);

   if(position_id == 0)
      return false;

   uint total = (uint)HistoryDealsTotal();

   for(uint i = 0; i < total; i++)
   {
      ulong related = HistoryDealGetTicket(i);

      if(related == 0)
         continue;

      if((ulong)HistoryDealGetInteger(
            related, DEAL_POSITION_ID) != position_id)
         continue;

      if((ulong)HistoryDealGetInteger(
            related, DEAL_MAGIC) == (ulong)Inp_MagicNumber)
         return true;

      ulong related_order =
         (ulong)HistoryDealGetInteger(related, DEAL_ORDER);

      if(related_order > 0 && HistoryOrderSelect(related_order))
      {
         if((ulong)HistoryOrderGetInteger(
               related_order, ORDER_MAGIC) ==
            (ulong)Inp_MagicNumber)
            return true;
      }
   }

   return false;
}

//====================================================================
// نرمال‌سازی حجم
//====================================================================
double NormalizeVolume(const double volume)
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(step <= 0.0)
      return volume;

   double v = MathRound(volume / step) * step;

   if(v < minv)
      v = minv;

   if(v > maxv)
      v = maxv;

   return NormalizeDouble(v, 8);
}

//====================================================================
// ساخت کامنت استاندارد سناریو
//====================================================================
string MakeScenarioComment(
   const ulong scenario_id,
   const double tp1,
   const double tp2,
   const double sl_price = 0.0)
{
   string comment =
      "TFlab S#" + (string)scenario_id +
      " | TP1=" + DoubleToString(tp1, _Digits) +
      " | TP2=" + DoubleToString(tp2, _Digits);

   if(sl_price > 0.0)
      comment += " | SL=" + DoubleToString(sl_price, _Digits);

   return comment;
}

//====================================================================
// استخراج ScenarioID از کامنت
//====================================================================
ulong FindScenarioIdByPositionId(const ulong position_id)
{
   if(position_id == 0)
      return 0;

   if(!HistorySelect(0, TimeCurrent()))
      return 0;

   int total = HistoryDealsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);

      if(ticket == 0)
         continue;

      if((ulong)HistoryDealGetInteger(
            ticket, DEAL_POSITION_ID) != position_id)
         continue;

      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(
            ticket, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;

      string comment =
         HistoryDealGetString(ticket, DEAL_COMMENT);

      int p1 = StringFind(comment, "S#");

      if(p1 < 0)
         continue;

      p1 += 2;

      int p2 = StringFind(comment, " ", p1);

      string id_str =
         (p2 > p1
          ? StringSubstr(comment, p1, p2 - p1)
          : StringSubstr(comment, p1));

      return (ulong)StringToInteger(id_str);
   }

   return 0;
}

//====================================================================
// سود/ضرر بسته‌شده امروز
//====================================================================
double TodayClosedProfit()
{
   datetime day_start =
      StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   if(!HistorySelect(day_start, TimeCurrent()))
      return 0.0;

   double value = 0.0;
   int counted_ea = 0;
   int counted_manual = 0;

   uint total = (uint)HistoryDealsTotal();

   for(uint i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);

      if(ticket == 0)
         continue;

      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;

      ENUM_DEAL_ENTRY entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);

      if(entry != DEAL_ENTRY_OUT &&
         entry != DEAL_ENTRY_OUT_BY &&
         entry != DEAL_ENTRY_INOUT)
         continue;

      if(!Inp_Show_All_Trades_In_Panel)
      {
         if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) !=
            (ulong)Inp_MagicNumber)
            continue;
      }
      else
      {
         if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) ==
            (ulong)Inp_MagicNumber)
            counted_ea++;
         else
            counted_manual++;
      }

      value += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      value += HistoryDealGetDouble(ticket, DEAL_SWAP);
      value += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      value += HistoryDealGetDouble(ticket, DEAL_FEE);
   }

   if(Inp_Show_All_Trades_In_Panel)
   {
      static datetime last_log = 0;

      if(TimeCurrent() - last_log > 60)
      {
         Print("[PROFIT CALC] Mode=ALL | EA Trades=", counted_ea,
               " | Manual Trades=", counted_manual,
               " | Total=", DoubleToString(value, 2), "$");

         last_log = TimeCurrent();
      }
   }

   return value;
}

//====================================================================
// سود/ضرر امروز
//====================================================================
double TodayTotalProfit()
{
   return TodayClosedProfit() + OpenProfit();
}

//====================================================================
// ریست Metrics گزارش
//====================================================================
void ResetReportMetrics()
{
   M5MovementMetrics_Reset(g_m5_metrics);
   M5ZoneQuality_Reset(g_m5_zone_quality);
}

//====================================================================
// به‌روزرسانی Metrics گزارش
//====================================================================
void UpdateReportMetrics(const double current_price)
{
   ResetReportMetrics();

   bool metrics_ok =
      M5MovementMetrics_Analyze(
         _Symbol,
         PERIOD_M5,
         20,
         0.0,
         Inp_ATR_Period,
         g_m5_metrics);

   if(!metrics_ok ||
      !M5MovementMetrics_IsValid(g_m5_metrics))
   {
      Print("[M5 Metrics] گزارش | FAILED | ",
            g_m5_metrics.reason);
      return;
   }

   bool zone_quality_ok =
      M5ZoneQuality_Analyze(
         g_m5_metrics,
         g_buy_zone,
         g_sell_zone,
         current_price,
         g_m5_zone_quality);

   if(!zone_quality_ok ||
      !M5ZoneQuality_IsValid(g_m5_zone_quality))
   {
      Print("[M5 Zone Quality] گزارش | FAILED | ",
            g_m5_zone_quality.reason);
      return;
   }

   Print("[M5 Zone Quality] Snapshot",
      " | MovementQuality=",
      DoubleToString(
         g_m5_zone_quality.movement_quality_score, 2),
      " | ZoneQuality=",
      DoubleToString(
         g_m5_zone_quality.zone_quality_score, 2),
      " | Proximity=",
      DoubleToString(
         g_m5_zone_quality.proximity_score, 2),
      " | Alignment=",
      DoubleToString(
         g_m5_zone_quality.movement_alignment_score, 2),
      " | Combined=",
      DoubleToString(
         g_m5_zone_quality.combined_quality_score, 2),
      " | NearestDistance=",
      DoubleToString(
         g_m5_zone_quality.nearest_zone_distance_points, 1),
      " | NearestStrength=",
      DoubleToString(
         g_m5_zone_quality.nearest_zone_strength, 2),
      " | Position=",
      M5ZoneQuality_PositionToPersian(
         g_m5_zone_quality.zone_position));
}

//====================================================================
// اعتبارسنجی Inputs
//====================================================================
bool ValidateInputs()
{
   if(Inp_MaxOpenTrades < 1)
      return false;

   if(Inp_Simultaneous_Trades < 1)
      return false;

   if(Inp_Max_Active_Zones < 1)
      return false;

   if(Inp_Max_Active_Scenarios < 1)
      return false;

   if(Inp_Monitor_Update_Seconds < 1)
      return false;

   if(Inp_Monitor_Confirm_Minutes < 1)
      return false;

   if(Inp_Risk_Per_Trade_Percent <= 0.0 ||
      Inp_Risk_Per_Trade_Percent >
      Inp_Max_Risk_Per_Trade_Percent)
      return false;

   if(Inp_Max_Portfolio_Risk_Percent <= 0.0 ||
      Inp_Max_Directional_Risk_Percent <= 0.0)
      return false;

   if(Inp_Min_RR <= 0.0 ||
      Inp_Max_RR < Inp_Min_RR)
      return false;

   if(Inp_Partial_Close_Mode == PARTIAL_CLOSE_PERCENT &&
      (Inp_Partial_Close_Percent <= 0.0 ||
       Inp_Partial_Close_Percent > 100.0))
      return false;

   if(Inp_Breakeven_Offset_Points < 0.0)
      return false;

   if(Inp_AI_Minimum_Samples < 1)
      return false;

   if(Inp_Use_Manual_TP &&
      Inp_Manual_TP_Profit_Money <= 0.0)
      return false;

   return true;
}

//====================================================================
// ساخت BUY Zone
//====================================================================
bool BuildBuyZone(
   const MarketStructureSnapshot &structure,
   const double atr_price,
   ZoneInfo &zone)
{
   Zone_Init(zone);

   if(!structure.last_low.valid ||
      structure.last_low.price <= 0.0 ||
      atr_price <= 0.0)
      return false;

   double width =
      MathMax(atr_price * 0.35, _Point * 10.0);

   double lower = structure.last_low.price;
   double upper = lower + width;

   double invalidation =
      lower - MathMax(
         atr_price * 0.15,
         _Point * 2.0);

   return Zone_Create(
      1,
      ZONE_TYPE_STRUCTURE,
      ZONE_DIRECTION_BUY,
      lower,
      upper,
      invalidation,
      TimeCurrent(),
      0,
      Inp_TF_Structure_M15,
      MathMax(
         1.0,
         structure.structure_range_points),
      "MarketStructure",
      "ساخت Zone خرید از آخرین Swing Low",
      zone);
}

//====================================================================
// ساخت SELL Zone
//====================================================================
bool BuildSellZone(
   const MarketStructureSnapshot &structure,
   const double atr_price,
   ZoneInfo &zone)
{
   Zone_Init(zone);

   if(!structure.last_high.valid ||
      structure.last_high.price <= 0.0 ||
      atr_price <= 0.0)
      return false;

   double width =
      MathMax(atr_price * 0.35, _Point * 10.0);

   double upper = structure.last_high.price;
   double lower = upper - width;

   double invalidation =
      upper + MathMax(
         atr_price * 0.15,
         _Point * 2.0);

   return Zone_Create(
      2,
      ZONE_TYPE_STRUCTURE,
      ZONE_DIRECTION_SELL,
      lower,
      upper,
      invalidation,
      TimeCurrent(),
      0,
      Inp_TF_Structure_M15,
      MathMax(
         1.0,
         structure.structure_range_points),
      "MarketStructure",
      "ساخت Zone فروش از آخرین Swing High",
      zone);
}

//====================================================================
// لاگ چرخه
//====================================================================
void LogCycle(
   const string stage,
   const string message,
   const double v1 = 0.0,
   const double v2 = 0.0)
{
   if(!Inp_Enable_Detailed_Log ||
      !g_detailed_state.initialized)
      return;

   DetailedLogger_Log(
      DLOG_LEVEL_INFO,
      DLOG_CATEGORY_SYSTEM,
      "CYCLE",
      stage,
      g_panel.direction,
      g_panel.scenario,
      message,
      _Symbol,
      (ENUM_TIMEFRAMES)_Period,
      v1,
      v2,
      0.0,
      0.0,
      0.0,
      0.0,
      g_sl_plan.stop_price,
      g_scenario.target_1,
      g_scenario.id,
      g_pending.ticket,
      0,
      g_detailed_config,
      g_detailed_state);
}

//====================================================================
// ثبت Diagnostic سناریو
//====================================================================
void SetScenarioDiagnostic(const string reason)
{
   g_last_scenario_diagnostic = reason;

   Print("[SCENARIO DIAGNOSTIC] ", reason);

   if(Inp_Enable_Detailed_Log &&
      g_detailed_state.initialized)
      LogCycle("SCENARIO_DIAGNOSTIC", reason);
}

//====================================================================
// لغو Pending فعال
//====================================================================
void CancelActivePending(const string reason)
{
   if(g_pending.ticket == 0 ||
      !g_pending.active)
      return;

   if(Inp_Cancel_Pending_On_Invalid)
      PendingOrder_Cancel(
         g_pending,
         reason,
         TimeCurrent());
}

//====================================================================
// ریست کامل State سناریوی فعال
//====================================================================
void ResetActiveScenarioState(const string reason)
{
   if(g_scenario.id > 0)
      CancelPendingOrdersForScenario(g_scenario.id, reason);

   if(g_pending.ticket > 0 &&
      g_pending.active)
   {
      CancelActivePending(reason);
   }

   PendingOrder_Init(g_pending);

   Scenario_Init(g_scenario);

   ZeroMemory(g_sl_plan);

   TP_Init(g_tp_result);

   Target_Init(g_target);

   EntryPlan_Init(g_entry_plan);

   g_last_executed_scenario_id = 0;
   g_virtual_scenario_id        = 0;
   g_is_transition_mode         = false;
   g_risk_block_reason          = "";

   Print("[SCENARIO RESET] کامل انجام شد | Reason=", reason);
}

//====================================================================
// اتصال سناریوی معتبر به Virtual Tester
//====================================================================
void RegisterCurrentScenarioForVirtualTester()
{
   if(g_scenario.id <= 0 ||
      !Scenario_IsValid(g_scenario) ||
      g_scenario.direction == SCENARIO_DIRECTION_NONE ||
      g_scenario.entry_price <= 0.0 ||
      g_scenario.target_1 <= 0.0 ||
      g_scenario.target_2 <= 0.0)
   {
      return;
   }

   if(!g_test_logger.initialized &&
      !g_svt_state.initialized)
      return;

   double bid = 0.0;
   double ask = 0.0;
   double mid = 0.0;

   if(!GetCurrentPrices(bid, ask, mid))
      return;

   double virtual_sl = g_sl_plan.stop_price;

   if(virtual_sl <= 0.0)
      virtual_sl = g_scenario.invalidation_price;

   if(virtual_sl <= 0.0)
      return;

   TradingScenario virtual_scenario = g_scenario;
   virtual_scenario.invalidation_price = virtual_sl;

   if(ScenarioVirtualTester_AutoRegister(
      virtual_scenario,
      bid,
      ask))
   {
      Print(
         "[SCENARIO VIRTUAL] LINK | ID=",
         g_scenario.id,
         " | Direction=",
         ScenarioDirectionToPersian(
            g_scenario.direction),
         " | Current=",
         DoubleToString(mid, _Digits),
         " | Entry=",
         DoubleToString(
            g_scenario.entry_price, _Digits),
         " | RealSL=",
         DoubleToString(
            virtual_sl, _Digits),
         " | TP1=",
         DoubleToString(
            g_scenario.target_1, _Digits),
         " | TP2=",
         DoubleToString(
            g_scenario.target_2, _Digits));
   }
}

//====================================================================
// بافر هوشمند ابطال
//====================================================================
double GetSmartInvalidationBuffer(
   double current_atr_points)
{
   if(current_atr_points <= 0.0)
      return Inp_Invalidation_Min_Buffer_Points;

   double smart_buffer =
      current_atr_points *
      Inp_Invalidation_Buffer_ATR_Multiplier;

   if(smart_buffer <
      Inp_Invalidation_Min_Buffer_Points)
      smart_buffer =
         Inp_Invalidation_Min_Buffer_Points;

   if(smart_buffer >
      Inp_Invalidation_Max_Buffer_Points)
      smart_buffer =
         Inp_Invalidation_Max_Buffer_Points;

   return smart_buffer;
}

//====================================================================
// به‌روزرسانی Virtual Tester
//====================================================================
void UpdateScenarioVirtualTester()
{
   if(!g_svt_state.initialized)
      return;

   double bid = 0.0;
   double ask = 0.0;
   double mid = 0.0;

   if(!GetCurrentPrices(bid, ask, mid))
      return;

   ScenarioVirtualTester_Update(
      bid,
      ask,
      TimeCurrent());
}

//====================================================================
// حفاظت حداقل RR
//====================================================================
bool EnsureTargetMeetsMinimumRR(
   const ENUM_SCENARIO_DIRECTION direction,
   const double entry_price,
   const double stop_price,
   double &target_price,
   const double atr_price)
{
   if(entry_price <= 0.0 ||
      stop_price <= 0.0 ||
      target_price <= 0.0)
      return false;

   if(Inp_Min_RR <= 0.0)
      return true;

   const double stop_distance =
      MathAbs(entry_price - stop_price);

   if(stop_distance <= 0.0)
      return false;

   const double required_reward =
      stop_distance * Inp_Min_RR;

   const double old_target =
      target_price;

   double required_target = 0.0;

   if(direction == SCENARIO_DIRECTION_BUY)
      required_target =
         entry_price + required_reward;
   else if(direction == SCENARIO_DIRECTION_SELL)
      required_target =
         entry_price - required_reward;
   else
      return false;

   bool changed = false;

   if(direction == SCENARIO_DIRECTION_BUY &&
      target_price < required_target)
   {
      target_price = required_target;
      changed = true;
   }
   else
   if(direction == SCENARIO_DIRECTION_SELL &&
      target_price > required_target)
   {
      target_price = required_target;
      changed = true;
   }

   if(changed && atr_price > 0.0)
   {
      const double rr_buffer =
         atr_price * 0.10;

      if(direction == SCENARIO_DIRECTION_BUY)
         target_price += rr_buffer;
      else
         target_price -= rr_buffer;
   }

   target_price =
      NormalizeDouble(
         target_price,
         (int)SymbolInfoInteger(
            _Symbol,
            SYMBOL_DIGITS));

   if(changed)
   {
      Print(
         "[TARGET RR PROTECTION] | Direction=",
         ScenarioDirectionToPersian(direction),
         " | Entry=",
         DoubleToString(entry_price, _Digits),
         " | SL=",
         DoubleToString(stop_price, _Digits),
         " | OldTarget=",
         DoubleToString(old_target, _Digits),
         " | NewTarget=",
         DoubleToString(target_price, _Digits),
         " | MinRR=",
         DoubleToString(Inp_Min_RR, 2));
   }

   return true;
}

//====================================================================
// محاسبه حد سود دستی بر اساس مبلغ سود هدف
//====================================================================
bool CalculateManualTPPrice(
   const ENUM_SCENARIO_DIRECTION direction,
   const double entry_price,
   const double volume,
   double &tp_price)
{
   tp_price = 0.0;

   if(!Inp_Use_Manual_TP)
      return false;

   if(entry_price <= 0.0 ||
      volume <= 0.0 ||
      Inp_Manual_TP_Profit_Money <= 0.0)
      return false;

   double tick_size =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_TRADE_TICK_SIZE);

   double tick_value =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_TRADE_TICK_VALUE_PROFIT);

   if(tick_value <= 0.0)
      tick_value =
         SymbolInfoDouble(
            _Symbol,
            SYMBOL_TRADE_TICK_VALUE);

   if(tick_size <= 0.0 ||
      tick_value <= 0.0)
      return false;

   const double price_distance =
      (Inp_Manual_TP_Profit_Money /
       (tick_value * volume)) *
      tick_size;

   if(price_distance <= 0.0)
      return false;

   if(direction == SCENARIO_DIRECTION_BUY)
      tp_price = entry_price + price_distance;
   else
   if(direction == SCENARIO_DIRECTION_SELL)
      tp_price = entry_price - price_distance;
   else
      return false;

   const int digits =
      (int)SymbolInfoInteger(
         _Symbol,
         SYMBOL_DIGITS);

   tp_price =
      NormalizeDouble(
         tp_price,
         digits);

   long stops_level_points =
      SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_STOPS_LEVEL);

   const double min_distance =
      (double)stops_level_points * _Point;

   if(min_distance > 0.0 &&
      direction == SCENARIO_DIRECTION_BUY &&
      (tp_price - entry_price) < min_distance)
      return false;

   if(min_distance > 0.0 &&
      direction == SCENARIO_DIRECTION_SELL &&
      (entry_price - tp_price) < min_distance)
      return false;

   return true;
}

//====================================================================
// تعیین حد سود واقعی: دستی یا سیستمی
//====================================================================
bool ResolveRealTakeProfit(
   const ENUM_SCENARIO_DIRECTION direction,
   const double entry_price,
   const double volume,
   const double system_tp,
   double &real_tp)
{
   real_tp = system_tp;

   if(!Inp_Use_Manual_TP)
      return (real_tp > 0.0);

   if(!CalculateManualTPPrice(
      direction,
      entry_price,
      volume,
      real_tp))
   {
      Print(
         "[MANUAL TP] FAILED | مبلغ=",
         DoubleToString(
            Inp_Manual_TP_Profit_Money,
            2),
         " | Entry=",
         DoubleToString(
            entry_price,
            _Digits),
         " | Volume=",
         DoubleToString(
            volume,
            4));

      return false;
   }

   Print(
      "[MANUAL TP] ACTIVE | مبلغ هدف=",
      DoubleToString(
         Inp_Manual_TP_Profit_Money,
         2),
      " | Entry=",
      DoubleToString(
         entry_price,
         _Digits),
      " | TP=",
      DoubleToString(
         real_tp,
         _Digits),
      " | Volume=",
      DoubleToString(
         volume,
         4));

   return true;
}

//====================================================================
// اجازه اجرای واقعی
//====================================================================
bool IsRealTradingAllowed()
{
   if(!Inp_EnableTrading)
      return false;

   if(!TerminalInfoInteger(
      TERMINAL_CONNECTED))
      return false;

   if(!MQLInfoInteger(
      MQL_TRADE_ALLOWED))
      return false;

   if(!AccountInfoInteger(
      ACCOUNT_TRADE_ALLOWED))
      return false;

   if(!AccountInfoInteger(
      ACCOUNT_TRADE_EXPERT))
      return false;

   return true;
}

//====================================================================
// بررسی اسپرد
//====================================================================
bool IsSpreadAcceptable(string &reason)
{
   reason = "";

   if(!Inp_Reject_If_Spread_High)
      return true;

   double bid =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_BID);

   double ask =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_ASK);

   if(bid <= 0.0 || ask <= 0.0)
      return true;

   double spread_points =
      (ask - bid) / _Point;

   if(Inp_Max_Spread_Points > 0.0 &&
      spread_points >
      Inp_Max_Spread_Points)
   {
      reason =
         "اسپرد لحظه‌ای=" +
         DoubleToString(
            spread_points, 1) +
         "pts > حداکثر مجاز=" +
         DoubleToString(
            Inp_Max_Spread_Points, 1) +
         "pts";

      return false;
   }

   return true;
}

//====================================================================
// سقف واقعی معاملات همزمان
//====================================================================
int GetEffectiveMaxOpenTrades()
{
   // Inp_Simultaneous_Trades مالک سهمیه هر Scenario است.
   // وقتی کاربر بیشتر از یک معامله برای هر سیگنال خواسته است،
   // قفل قدیمی Inp_AllowMultipleTrades نباید سهمیه Scenario را به 1 محدود کند.
   const int requested = MathMax(1, Inp_Simultaneous_Trades);

   if(requested > 1)
      return MathMax(Inp_MaxOpenTrades, requested);

   if(!Inp_AllowMultipleTrades)
      return 1;

   return MathMax(1, Inp_MaxOpenTrades);
}

//====================================================================
// بررسی بازار
//====================================================================
bool IsMarketOpenForSymbol(string &reason)
{
   reason = "";

   if(!Inp_Reject_If_Market_Closed)
      return true;

   ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)
      SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE);

   if(trade_mode ==
      SYMBOL_TRADE_MODE_DISABLED)
   {
      reason =
         "معامله روی این نماد کاملاً غیرفعال است";
      return false;
   }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   datetime today_start =
      TimeCurrent() -
      (dt.hour * 3600 +
       dt.min * 60 +
       dt.sec);

   datetime now_seconds_from_midnight =
      TimeCurrent() - today_start;

   bool in_any_session = false;

   for(int s = 0; s < 5; s++)
   {
      datetime from1, to1;

      if(!SymbolInfoSessionTrade(
         _Symbol,
         (ENUM_DAY_OF_WEEK)dt.day_of_week,
         s,
         from1,
         to1))
         break;

      if(now_seconds_from_midnight >= from1 &&
         now_seconds_from_midnight <= to1)
      {
         in_any_session = true;
         break;
      }
   }

   if(!in_any_session)
   {
      reason =
         "بازار برای این نماد در حال حاضر بسته است (خارج از Session معاملاتی)";
      return false;
   }

   return true;
}

//====================================================================
// امتیاز جهت بازار
//====================================================================
void CalculateDirectionalScores(
   const ENUM_HTF_DIRECTION htf,
   const bool has_buy,
   const bool has_sell,
   const bool htf_allows_buy,
   const bool htf_allows_sell,
   const bool regime_allows_buy,
   const bool regime_allows_sell,
   const bool streak_allows_buy,
   const bool streak_allows_sell,
   const bool divergence_blocks_buy,
   const bool divergence_blocks_sell,
   double &buy_score,
   double &sell_score)
{
   buy_score = 0.0;
   sell_score = 0.0;

   if(g_structure.state ==
      STRUCTURE_STATE_BULLISH)
      buy_score += 25.0;

   if(g_structure.state ==
      STRUCTURE_STATE_BEARISH)
      sell_score += 25.0;

   if(g_structure.bullish_sequence)
      buy_score += 20.0;

   if(g_structure.bearish_sequence)
      sell_score += 20.0;

   if(g_regime.valid &&
      g_regime.regime ==
      MARKET_REGIME_UPTREND)
      buy_score += 20.0;

   if(g_regime.valid &&
      g_regime.regime ==
      MARKET_REGIME_DOWNTREND)
      sell_score += 20.0;

   if(htf ==
      HTF_DIRECTION_BULLISH)
      buy_score += 15.0;

   if(htf ==
      HTF_DIRECTION_BEARISH)
      sell_score += 15.0;

   if(g_move.impulse_valid &&
      g_move.impulse_direction > 0)
      buy_score += 10.0;

   if(g_move.impulse_valid &&
      g_move.impulse_direction < 0)
      sell_score += 10.0;

   if(has_buy &&
      Zone_IsValid(g_buy_zone))
      buy_score += 10.0;

   if(has_sell &&
      Zone_IsValid(g_sell_zone))
      sell_score += 10.0;

   if(!htf_allows_buy)
      buy_score *= 0.70;

   if(!htf_allows_sell)
      sell_score *= 0.70;

   if(!regime_allows_buy)
      buy_score *= 0.80;

   if(!regime_allows_sell)
      sell_score *= 0.80;

   if(!streak_allows_buy)
      buy_score *= 0.90;

   if(!streak_allows_sell)
      sell_score *= 0.90;

   if(divergence_blocks_buy)
      buy_score *= 0.50;

   if(divergence_blocks_sell)
      sell_score *= 0.50;

   buy_score =
      MathMin(100.0,
      MathMax(0.0, buy_score));

   sell_score =
      MathMin(100.0,
      MathMax(0.0, sell_score));
}

//====================================================================
// قفل جهت مخالف روند قوی
//====================================================================
bool StrongDirectionalLockAllows(
   const ENUM_SCENARIO_DIRECTION direction,
   const ENUM_HTF_DIRECTION htf)
{
   const bool strong_bearish =
      g_regime.valid &&
      g_regime.regime ==
      MARKET_REGIME_DOWNTREND &&
      (g_structure.state ==
         STRUCTURE_STATE_BEARISH ||
       htf ==
         HTF_DIRECTION_BEARISH);

   const bool strong_bullish =
      g_regime.valid &&
      g_regime.regime ==
      MARKET_REGIME_UPTREND &&
      (g_structure.state ==
         STRUCTURE_STATE_BULLISH ||
       htf ==
         HTF_DIRECTION_BULLISH);

   if(strong_bearish &&
      direction ==
      SCENARIO_DIRECTION_BUY)
      return false;

   if(strong_bullish &&
      direction ==
      SCENARIO_DIRECTION_SELL)
      return false;

   return true;
}

//====================================================================
// گیت تصمیم ورود در سطح Scenario / Strategy
// این گیت فقط Continuation را کنترل می‌کند و Reversal را محدود نمی‌کند.
//====================================================================
bool EntryGate_IsContinuationStrategy(
   const ENUM_STRATEGY_TYPE strategy_type)
{
   return
      strategy_type == STRATEGY_BUY_CONTINUATION ||
      strategy_type == STRATEGY_SELL_CONTINUATION;
}

//====================================================================
// اعتبارسنجی Continuation در لحظه ساخت سیگنال
//====================================================================
bool EntryGate_AllowsContinuationAtSignal(
   const ENUM_SCENARIO_DIRECTION direction,
   const ENUM_STRATEGY_TYPE strategy_type,
   string &reason)
{
   reason = "";

   if(!Inp_Enable_Entry_Decision_Gate ||
      !EntryGate_IsContinuationStrategy(strategy_type))
      return true;

   const bool is_buy =
      (direction == SCENARIO_DIRECTION_BUY);

   if(Inp_Use_Market_Truth &&
      g_market_truth.valid)
   {
      if(is_buy &&
         g_market_truth.direction == MARKET_TRUTH_SELL &&
         g_market_truth.strong_market_move &&
         g_market_truth.continuation_ready)
      {
         reason =
            "BUY Continuation با حقیقت قیمت مخالف است | Truth=SELL | MoveATR=" +
            DoubleToString(
               g_market_truth.move_atr_multiple,
               2);
         return false;
      }

      if(!is_buy &&
         g_market_truth.direction == MARKET_TRUTH_BUY &&
         g_market_truth.strong_market_move &&
         g_market_truth.continuation_ready)
      {
         reason =
            "SELL Continuation با حقیقت قیمت مخالف است | Truth=BUY | MoveATR=" +
            DoubleToString(
               g_market_truth.move_atr_multiple,
               2);
         return false;
      }
   }

   // ورود مستقیم پس از حرکت بسیار کشیده و بدون اصلاح معتبر ممنوع است.
   // Continuation دارای Pullback معتبر از این گیت عبور می‌کند.
   if(g_move.valid &&
      g_move.impulse_valid &&
      !g_move.correction_valid &&
      g_move.impulse_atr_multiple >=
         Inp_Direct_Continuation_Max_ATR)
   {
      const int expected_direction =
         (is_buy ? 1 : -1);

      // برای جلوگیری از حذف بی‌دلیل معاملات سالم، کشیدگی باید
      // هم در موتور حرکت و هم در Truth بازار دیده شود.
      const bool truth_same_direction =
         g_market_truth.valid &&
         ((is_buy &&
           g_market_truth.direction == MARKET_TRUTH_BUY) ||
          (!is_buy &&
           g_market_truth.direction == MARKET_TRUTH_SELL));

      if(g_move.impulse_direction == expected_direction &&
         truth_same_direction &&
         g_market_truth.move_atr_multiple >=
            Inp_Direct_Continuation_Max_ATR)
      {
         reason =
            (is_buy
             ? "BUY Continuation پس از حرکت مستقیم و کشیده بدون اصلاح معتبر متوقف شد"
             : "SELL Continuation پس از حرکت مستقیم و کشیده بدون اصلاح معتبر متوقف شد") +
            " | ImpulseATRx=" +
            DoubleToString(
               g_move.impulse_atr_multiple,
               2) +
            " | TruthMoveATRx=" +
            DoubleToString(
               g_market_truth.move_atr_multiple,
               2) +
            " | حد=" +
            DoubleToString(
               Inp_Direct_Continuation_Max_ATR,
               2);
         return false;
      }
   }

   return true;
}

//====================================================================
// بازاعتبارسنجی شرایط درست پیش از اجرای Market
//====================================================================
bool EntryGate_RevalidateBeforeExecution(
   const ENUM_SCENARIO_DIRECTION direction,
   const double live_price,
   string &reason)
{
   reason = "";

   if(!Inp_Enable_Entry_Revalidation ||
      !Inp_Enable_Entry_Decision_Gate)
      return true;

   if(live_price <= 0.0)
   {
      reason = "قیمت لحظه اجرای ورود معتبر نیست";
      return false;
   }

   // ابتدا Invalidaton خود Scenario را در قیمت واقعی بررسی می‌کنیم.
   if(g_scenario.invalidation_price > 0.0)
   {
      if(direction == SCENARIO_DIRECTION_BUY &&
         live_price <= g_scenario.invalidation_price)
      {
         reason = "قیمت لحظه اجرا به محدوده ابطال BUY رسیده است";
         return false;
      }

      if(direction == SCENARIO_DIRECTION_SELL &&
         live_price >= g_scenario.invalidation_price)
      {
         reason = "قیمت لحظه اجرا به محدوده ابطال SELL رسیده است";
         return false;
      }
   }

   ZoneInfo live_zone;
   Zone_Init(live_zone);

   if(direction == SCENARIO_DIRECTION_BUY)
      live_zone = g_buy_zone;
   else
   if(direction == SCENARIO_DIRECTION_SELL)
      live_zone = g_sell_zone;

   if(Zone_IsValid(live_zone) &&
      Zone_CheckInvalidation(live_zone, live_price))
   {
      reason =
         (direction == SCENARIO_DIRECTION_BUY
          ? "Zone خرید در لحظه اجرا دیگر معتبر نیست"
          : "Zone فروش در لحظه اجرا دیگر معتبر نیست");
      return false;
   }

   const bool is_continuation =
      EntryGate_IsContinuationStrategy(
         g_last_strategy_type);

   // Truth باید در همان لحظه اجرا دوباره خوانده شود.
   if(Inp_Use_Market_Truth)
   {
      MarketTruthSnapshot live_truth;
      MarketTruth_Reset(live_truth);

      const bool truth_ok =
         MarketTruth_Analyze(
            _Symbol,
            Inp_TF_Setup_M5,
            Inp_Market_Truth_Lookback,
            live_truth);

      if(!truth_ok || !live_truth.valid)
      {
         reason = "بازاعتبارسنجی Truth پیش از اجرا ناموفق بود";
         return false;
      }

      if(is_continuation)
      {
         if(direction == SCENARIO_DIRECTION_BUY &&
            live_truth.direction == MARKET_TRUTH_SELL &&
            live_truth.strong_market_move &&
            live_truth.continuation_ready)
         {
            reason =
               "Truth در لحظه اجرا SELL است و BUY Continuation دیگر معتبر نیست";
            return false;
         }

         if(direction == SCENARIO_DIRECTION_SELL &&
            live_truth.direction == MARKET_TRUTH_BUY &&
            live_truth.strong_market_move &&
            live_truth.continuation_ready)
         {
            reason =
               "Truth در لحظه اجرا BUY است و SELL Continuation دیگر معتبر نیست";
            return false;
         }
      }
   }

   if(!is_continuation)
      return true;

   // Regime در لحظه Fill دوباره بررسی می‌شود؛ Range/Transition
   // صرفاً به خاطر نامشان مسدود نمی‌شوند، فقط تضاد صریح با جهت مهم است.
   MarketRegimeState live_regime;
   MarketRegime_Reset(live_regime);

   const bool regime_ok =
      MarketRegime_Analyze(
         _Symbol,
         Inp_TF_Context_M30,
         Inp_ADX_Period,
         Inp_RSI_Period,
         Inp_EMA_Trend_Period,
         Inp_ATR_Period,
         Inp_ADX_Min_Trend,
         Inp_ADX_Exhaustion_Level,
         Inp_RSI_Overbought,
         Inp_RSI_Oversold,
         Inp_Max_Price_EMA_ATR_Distance,
         live_regime);

   if(!regime_ok || !live_regime.valid)
   {
      reason = "بازاعتبارسنجی Regime پیش از اجرا ناموفق بود";
      return false;
   }

   if(live_regime.confidence >= Inp_Min_Regime_Confidence)
   {
      if(direction == SCENARIO_DIRECTION_BUY &&
         live_regime.regime == MARKET_REGIME_DOWNTREND)
      {
         reason =
            "Regime در لحظه اجرا نزولی شده و BUY Continuation متوقف شد";
         return false;
      }

      if(direction == SCENARIO_DIRECTION_SELL &&
         live_regime.regime == MARKET_REGIME_UPTREND)
      {
         reason =
            "Regime در لحظه اجرا صعودی شده و SELL Continuation متوقف شد";
         return false;
      }
   }

   MarketStructureSnapshot live_structure;
   MarketStructure_Reset(live_structure);

   const bool structure_ok =
      MarketStructure_Analyze(
         _Symbol,
         Inp_TF_Structure_M15,
         120,
         2,
         2,
         20.0,
         live_structure);

   if(!structure_ok || !live_structure.valid)
   {
      reason = "بازاعتبارسنجی Structure پیش از اجرا ناموفق بود";
      return false;
   }

   if(direction == SCENARIO_DIRECTION_BUY &&
      live_structure.state == STRUCTURE_STATE_BEARISH)
   {
      reason =
         "Structure در لحظه اجرا نزولی شده و BUY Continuation متوقف شد";
      return false;
   }

   if(direction == SCENARIO_DIRECTION_SELL &&
      live_structure.state == STRUCTURE_STATE_BULLISH)
   {
      reason =
         "Structure در لحظه اجرا صعودی شده و SELL Continuation متوقف شد";
      return false;
   }

   ImpulseCorrectionSnapshot live_move;
   ImpulseCorrection_Reset(live_move);

   const bool move_ok =
      ImpulseCorrection_Analyze(
         _Symbol,
         Inp_TF_Setup_M5,
         120,
         2,
         2,
         20.0,
         live_move);

   if(!move_ok || !live_move.valid)
   {
      reason = "بازاعتبارسنجی حرکت پیش از اجرا ناموفق بود";
      return false;
   }

   if(live_move.impulse_valid &&
      live_move.impulse_direction ==
         (direction == SCENARIO_DIRECTION_BUY ? -1 : 1) &&
      !live_move.correction_valid)
   {
      reason =
         "جهت حرکت M5 در لحظه اجرا مخالف Continuation است و اصلاح معتبر هم وجود ندارد";
      return false;
   }

   return true;
}

//====================================================================
// ساخت سناریوی ادامه روند قوی
//====================================================================
bool BuildStrongTrendContinuationScenario(
   const ENUM_SCENARIO_DIRECTION direction,
   const ZoneInfo &zone,
   const double current_price,
   TradingScenario &scenario,
   StrategyResult &strategy_result)
{
   Scenario_Init(scenario);
   Strategy_Reset(strategy_result);

   if(!Zone_IsValid(zone) ||
      current_price <= 0.0)
      return false;

   if(direction ==
      SCENARIO_DIRECTION_SELL)
   {
      if(g_structure.state !=
            STRUCTURE_STATE_BEARISH ||
         !g_structure.bearish_sequence ||
         !g_regime.valid ||
         g_regime.regime !=
            MARKET_REGIME_DOWNTREND ||
         !g_move.impulse_valid ||
         g_move.impulse_direction >= 0 ||
         zone.direction !=
            ZONE_DIRECTION_SELL)
         return false;
   }
   else
   if(direction ==
      SCENARIO_DIRECTION_BUY)
   {
      if(g_structure.state !=
            STRUCTURE_STATE_BULLISH ||
         !g_structure.bullish_sequence ||
         !g_regime.valid ||
         g_regime.regime !=
            MARKET_REGIME_UPTREND ||
         !g_move.impulse_valid ||
         g_move.impulse_direction <= 0 ||
         zone.direction !=
            ZONE_DIRECTION_BUY)
         return false;
   }
   else
      return false;

   if(!Scenario_CreateFromEvidence(
      _Symbol,
      direction,
      g_regime,
      g_context,
      g_structure,
      g_move,
      zone,
      scenario))
      return false;

   scenario.quality_value = 100.0;

   scenario.general_reason =
      (direction ==
         SCENARIO_DIRECTION_SELL
       ?
         "Continuation نزولی قوی | Structure + Regime + Impulse + SELL Zone"
       :
         "Continuation صعودی قوی | Structure + Regime + Impulse + BUY Zone");

   strategy_result.valid = true;

   strategy_result.type =
      (direction ==
         SCENARIO_DIRECTION_SELL
       ?
         STRATEGY_SELL_CONTINUATION
       :
         STRATEGY_BUY_CONTINUATION);

   strategy_result.direction =
      direction;

   strategy_result.quality =
      scenario.quality_value;

   strategy_result.confidence =
      scenario.quality_value;

   strategy_result.zone_id =
      zone.id;

   strategy_result.reason =
      scenario.general_reason;

   return Scenario_IsValid(
      scenario);
}

//====================================================================
// ساخت سناریوی Transition
//====================================================================
bool BuildTransitionScenario(
   const ENUM_SCENARIO_DIRECTION direction,
   const ZoneInfo &zone,
   const double current_price,
   TradingScenario &scenario,
   StrategyResult &strategy_result)
{
   Scenario_Init(scenario);
   Strategy_Reset(strategy_result);

   if(!Zone_IsValid(zone) ||
      current_price <= 0.0)
      return false;

   if(direction ==
      SCENARIO_DIRECTION_SELL)
   {
      if(g_structure.state !=
            STRUCTURE_STATE_BEARISH ||
         !g_structure.bearish_sequence ||
         !g_move.impulse_valid ||
         g_move.impulse_direction >= 0 ||
         zone.direction !=
            ZONE_DIRECTION_SELL)
      {
         strategy_result.failure_reason =
            "شرایط Transition SELL برقرار نیست";
         return false;
      }
   }
   else
   if(direction ==
      SCENARIO_DIRECTION_BUY)
   {
      if(g_structure.state !=
            STRUCTURE_STATE_BULLISH ||
         !g_structure.bullish_sequence ||
         !g_move.impulse_valid ||
         g_move.impulse_direction <= 0 ||
         zone.direction !=
            ZONE_DIRECTION_BUY)
      {
         strategy_result.failure_reason =
            "شرایط Transition BUY برقرار نیست";
         return false;
      }
   }
   else
      return false;

   if(!Scenario_CreateFromEvidence(
      _Symbol,
      direction,
      g_regime,
      g_context,
      g_structure,
      g_move,
      zone,
      scenario))
   {
      strategy_result.failure_reason =
         "ساخت سناریوی Transition ناموفق بود";
      return false;
   }

   scenario.quality_value = 80.0;

   scenario.general_reason =
      (direction ==
         SCENARIO_DIRECTION_SELL
       ?
         "Transition SELL | Truth+HTF+Impulse+Structure هم‌جهت | ریسک کاهش‌یافته 50%"
       :
         "Transition BUY | Truth+HTF+Impulse+Structure هم‌جهت | ریسک کاهش‌یافته 50%");

   strategy_result.valid = true;
   strategy_result.type =
      (direction ==
         SCENARIO_DIRECTION_SELL
       ?
         STRATEGY_SELL_CONTINUATION
       :
         STRATEGY_BUY_CONTINUATION);

   strategy_result.direction = direction;
   strategy_result.quality =
      scenario.quality_value;
   strategy_result.confidence =
      scenario.quality_value;
   strategy_result.zone_id = zone.id;
   strategy_result.reason =
      scenario.general_reason;

   return Scenario_IsValid(
      scenario);
}

//====================================================================
// ساخت EOC SELL
//====================================================================
bool CreateEndOfCorrectionSellScenario(
   const double current_price,
   const double quality,
   const string reason,
   TradingScenario &scenario,
   StrategyResult &strategy_result)
{
   Scenario_Init(scenario);
   Strategy_Reset(strategy_result);

   if(current_price <= 0.0 ||
      !Zone_IsValid(g_sell_zone))
      return false;

   const ulong scenario_id =
      Scenario_NextID();

   const datetime now =
      TimeCurrent();

   datetime expiry = 0;

   if(Inp_Scenario_Max_Age_Minutes > 0)
      expiry =
         datetime(
            (long)now +
            (long)Inp_Scenario_Max_Age_Minutes *
            60);

   const double invalidation =
      g_sell_zone.invalidation_price;

   if(invalidation <= 0.0)
      return false;

   if(!Scenario_Create(
      scenario_id,
      _Symbol,
      SCENARIO_DIRECTION_SELL,
      g_regime.regime,
      g_sell_zone,
      true,
      true,
      true,
      SCENARIO_ACTIVATION_CONFIRMATION,
      invalidation,
      now,
      expiry,
      (int)Inp_TF_Structure_M15,
      (int)Inp_TF_Setup_M5,
      g_structure.reason,
      "Impulse صعودی M5 به‌عنوان Correction ساختار نزولی شناسایی شد",
      "Correction نزولی/پایان اصلاح برای ادامه روند SELL تأیید شد",
      g_sell_zone.reason,
      "End-of-Correction SELL | ساختار نزولی + اصلاح M5 + تأیید شکست + SELL Zone",
      scenario))
      return false;

   const double entry =
      Zone_Midpoint(g_sell_zone);

   if(entry <= 0.0)
      return false;

   if(!Scenario_SetEntryPrice(
      scenario,
      entry,
      now,
      "Entry پیشنهادی در میانه SELL Zone برای End-of-Correction"))
      return false;

   scenario.activation_type =
      SCENARIO_ACTIVATION_CONFIRMATION;

   scenario.quality_value =
      MathMin(
         100.0,
         MathMax(0.0, quality));

   scenario.general_reason = reason;
   scenario.activation_ready = true;

   scenario.activation_reason =
      "Candle + Break Confirmation برای EOC تأیید شد";

   strategy_result.valid = true;
   strategy_result.type =
      STRATEGY_SELL_CONTINUATION;

   strategy_result.direction =
      SCENARIO_DIRECTION_SELL;

   strategy_result.zone_id =
      g_sell_zone.id;

   strategy_result.quality =
      scenario.quality_value;

   strategy_result.confidence =
      scenario.quality_value;

   strategy_result.reason =
      reason;

   return Scenario_IsValid(
      scenario);
}

//====================================================================
// تشخیص EOC SELL
//====================================================================
bool DetectEndOfCorrectionSell(
   const double current_price,
   const bool htf_allows_sell,
   const bool regime_allows_sell,
   const bool streak_allows_sell,
   const bool divergence_blocks_sell,
   const ENUM_DIVERGENCE_TYPE divergence,
   ConfluenceResult &confluence,
   double &quality,
   string &reason)
{
   Confluence_Init(confluence);
   quality = 0.0;
   reason = "";

   if(g_structure.state !=
         STRUCTURE_STATE_BEARISH ||
      !g_structure.bearish_sequence)
   {
      reason =
         "Structure برای End-of-Correction SELL مناسب نیست";
      return false;
   }

   if(!g_move.impulse_valid ||
      g_move.impulse_direction <= 0)
   {
      reason =
         "حرکت اصلاحی صعودی معتبر در M5 شناسایی نشد";
      return false;
   }

   if(!g_move.correction_valid ||
      g_move.correction_direction >= 0)
   {
      reason =
         "پایان Correction برای ادامه SELL تأیید نشده است";
      return false;
   }

   if(Inp_Max_Correction_Ratio > 0.0 &&
      g_move.correction_ratio >
      Inp_Max_Correction_Ratio)
   {
      reason =
         "Correction بیش از حد مجاز است | Ratio=" +
         DoubleToString(
            g_move.correction_ratio, 3) +
         " | Max=" +
         DoubleToString(
            Inp_Max_Correction_Ratio, 3);

      return false;
   }

   if(!Zone_IsValid(g_sell_zone))
   {
      reason =
         "SELL Zone معتبر نیست";
      return false;
   }

   if(!Zone_ContainsPrice(
      g_sell_zone,
      current_price))
   {
      reason =
         "قیمت هنوز داخل SELL Zone نیست";
      return false;
   }

   string candle_reason = "";

   if(!CandleConfirmation_ConfirmsDirection(
      _Symbol,
      Inp_TF_Setup_M5,
      Inp_PinBar_Min_Wick_Ratio,
      false,
      candle_reason))
   {
      reason =
         "کندل تأییدی نزولی وجود ندارد | " +
         candle_reason;
      return false;
   }

   const double close_1 =
      iClose(_Symbol, PERIOD_M5, 1);

   const double open_1 =
      iOpen(_Symbol, PERIOD_M5, 1);

   const double low_2 =
      iLow(_Symbol, PERIOD_M5, 2);

   if(close_1 <= 0.0 ||
      open_1 <= 0.0 ||
      low_2 <= 0.0)
   {
      reason =
         "داده کندل برای Break Confirmation معتبر نیست";
      return false;
   }

   const bool bearish_close =
      (close_1 < open_1);

   const bool bearish_break =
      (close_1 < low_2);

   if(!bearish_close ||
      !bearish_break)
   {
      reason =
         "پایان اصلاح هنوز با Break نزولی تأیید نشده است" +
         " | BearishClose=" +
         (bearish_close ? "YES" : "NO") +
         " | BreakPreviousLow=" +
         (bearish_break ? "YES" : "NO");

      return false;
   }

   Confluence_CalculateContinuation(
      htf_allows_sell,
      regime_allows_sell,
      g_regime.confidence,
      streak_allows_sell,
      true,
      g_move.correction_ratio,
      Inp_Max_Correction_Ratio,
      divergence_blocks_sell,
      Divergence_SupportsDirection(
         divergence,
         false),
      confluence);

   quality = confluence.score;

   if(quality <
      Inp_Min_Confluence_Score)
   {
      reason =
         "Confluence End-of-Correction کافی نیست | Score=" +
         DoubleToString(
            quality, 1) +
         " | Minimum=" +
         DoubleToString(
            Inp_Min_Confluence_Score, 1);

      return false;
   }

   reason =
      "End-of-Correction SELL تأیید شد | CorrectionRatio=" +
      DoubleToString(
         g_move.correction_ratio, 3) +
      " | Confluence=" +
      DoubleToString(
         quality, 1) +
      " | Candle=" +
      candle_reason +
      " | BreakPreviousLow=YES";

   return true;
}

//====================================================================
// ساخت EOC BUY
//====================================================================
bool CreateEndOfCorrectionBuyScenario(
   const double current_price,
   const double quality,
   const string reason,
   TradingScenario &scenario,
   StrategyResult &strategy_result)
{
   Scenario_Init(scenario);
   Strategy_Reset(strategy_result);

   if(current_price <= 0.0 ||
      !Zone_IsValid(g_buy_zone))
      return false;

   const ulong scenario_id =
      Scenario_NextID();

   const datetime now =
      TimeCurrent();

   datetime expiry = 0;

   if(Inp_Scenario_Max_Age_Minutes > 0)
      expiry =
         datetime(
            (long)now +
            (long)Inp_Scenario_Max_Age_Minutes *
            60);

   const double invalidation =
      g_buy_zone.invalidation_price;

   if(invalidation <= 0.0)
      return false;

   if(!Scenario_Create(
      scenario_id,
      _Symbol,
      SCENARIO_DIRECTION_BUY,
      g_regime.regime,
      g_buy_zone,
      true,
      true,
      true,
      SCENARIO_ACTIVATION_CONFIRMATION,
      invalidation,
      now,
      expiry,
      (int)Inp_TF_Structure_M15,
      (int)Inp_TF_Setup_M5,
      g_structure.reason,
      "Impulse نزولی M5 به‌عنوان Correction ساختار صعودی شناسایی شد",
      "Correction صعودی/پایان اصلاح برای ادامه روند BUY تأیید شد",
      g_buy_zone.reason,
      "End-of-Correction BUY | ساختار صعودی + اصلاح M5 + تأیید شکست + BUY Zone",
      scenario))
      return false;

   const double entry =
      Zone_Midpoint(g_buy_zone);

   if(entry <= 0.0)
      return false;

   if(!Scenario_SetEntryPrice(
      scenario,
      entry,
      now,
      "Entry پیشنهادی در میانه BUY Zone برای End-of-Correction"))
      return false;

   scenario.activation_type =
      SCENARIO_ACTIVATION_CONFIRMATION;

   scenario.quality_value =
      MathMin(
         100.0,
         MathMax(0.0, quality));

   scenario.general_reason = reason;
   scenario.activation_ready = true;

   scenario.activation_reason =
      "Candle + Break Confirmation برای EOC تأیید شد";

   strategy_result.valid = true;
   strategy_result.type =
      STRATEGY_BUY_CONTINUATION;

   strategy_result.direction =
      SCENARIO_DIRECTION_BUY;

   strategy_result.zone_id =
      g_buy_zone.id;

   strategy_result.quality =
      scenario.quality_value;

   strategy_result.confidence =
      scenario.quality_value;

   strategy_result.reason =
      reason;

   return Scenario_IsValid(
      scenario);
}

//====================================================================
// تشخیص EOC BUY
//====================================================================
bool DetectEndOfCorrectionBuy(
   const double current_price,
   const bool htf_allows_buy,
   const bool regime_allows_buy,
   const bool streak_allows_buy,
   const bool divergence_blocks_buy,
   const ENUM_DIVERGENCE_TYPE divergence,
   ConfluenceResult &confluence,
   double &quality,
   string &reason)
{
   Confluence_Init(confluence);
   quality = 0.0;
   reason = "";

   if(g_structure.state !=
         STRUCTURE_STATE_BULLISH ||
      !g_structure.bullish_sequence)
   {
      reason =
         "Structure برای End-of-Correction BUY مناسب نیست";
      return false;
   }

   if(!g_move.impulse_valid ||
      g_move.impulse_direction >= 0)
   {
      reason =
         "حرکت اصلاحی نزولی معتبر در M5 شناسایی نشد";
      return false;
   }

   if(!g_move.correction_valid ||
      g_move.correction_direction <= 0)
   {
      reason =
         "پایان Correction برای ادامه BUY تأیید نشده است";
      return false;
   }

   if(Inp_Max_Correction_Ratio > 0.0 &&
      g_move.correction_ratio >
      Inp_Max_Correction_Ratio)
   {
      reason =
         "Correction بیش از حد مجاز است | Ratio=" +
         DoubleToString(
            g_move.correction_ratio, 3) +
         " | Max=" +
         DoubleToString(
            Inp_Max_Correction_Ratio, 3);

      return false;
   }

   if(!Zone_IsValid(g_buy_zone))
   {
      reason =
         "BUY Zone معتبر نیست";
      return false;
   }

   if(!Zone_ContainsPrice(
      g_buy_zone,
      current_price))
   {
      reason =
         "قیمت هنوز داخل BUY Zone نیست";
      return false;
   }

   string candle_reason = "";

   if(!CandleConfirmation_ConfirmsDirection(
      _Symbol,
      Inp_TF_Setup_M5,
      Inp_PinBar_Min_Wick_Ratio,
      true,
      candle_reason))
   {
      reason =
         "کندل تأییدی صعودی وجود ندارد | " +
         candle_reason;
      return false;
   }

   const double close_1 =
      iClose(_Symbol, PERIOD_M5, 1);

   const double open_1 =
      iOpen(_Symbol, PERIOD_M5, 1);

   const double high_2 =
      iHigh(_Symbol, PERIOD_M5, 2);

   if(close_1 <= 0.0 ||
      open_1 <= 0.0 ||
      high_2 <= 0.0)
   {
      reason =
         "داده کندل برای Break Confirmation معتبر نیست";
      return false;
   }

   const bool bullish_close =
      (close_1 > open_1);

   const bool bullish_break =
      (close_1 > high_2);

   if(!bullish_close ||
      !bullish_break)
   {
      reason =
         "پایان اصلاح هنوز با Break صعودی تأیید نشده است" +
         " | BullishClose=" +
         (bullish_close ? "YES" : "NO") +
         " | BreakPreviousHigh=" +
         (bullish_break ? "YES" : "NO");

      return false;
   }

   Confluence_CalculateContinuation(
      htf_allows_buy,
      regime_allows_buy,
      g_regime.confidence,
      streak_allows_buy,
      true,
      g_move.correction_ratio,
      Inp_Max_Correction_Ratio,
      divergence_blocks_buy,
      Divergence_SupportsDirection(
         divergence,
         true),
      confluence);

   quality = confluence.score;

   if(quality <
      Inp_Min_Confluence_Score)
   {
      reason =
         "Confluence End-of-Correction کافی نیست | Score=" +
         DoubleToString(
            quality, 1) +
         " | Minimum=" +
         DoubleToString(
            Inp_Min_Confluence_Score, 1);

      return false;
   }

   reason =
      "End-of-Correction BUY تأیید شد | CorrectionRatio=" +
      DoubleToString(
         g_move.correction_ratio, 3) +
      " | Confluence=" +
      DoubleToString(
         quality, 1) +
      " | Candle=" +
      candle_reason +
      " | BreakPreviousHigh=YES";

   return true;
}

//====================================================================
// ممیزی فیلترها
//====================================================================
void RunFilterAudit(
   const bool context_ok,
   const bool regime_ok,
   const bool structure_ok,
   const bool move_ok,
   const bool market_truth_ok,
   const bool has_buy_zone,
   const bool has_sell_zone,
   const bool correction_ok,
   const bool divergence_blocks_buy,
   const bool divergence_blocks_sell)
{
   FilterAudit_Reset(g_filter_audit);
   FilterAudit_ResetTotals();
   g_filter_audit.time = TimeCurrent();

   FilterAudit_Add(
      g_filter_audit,
      "محیط بازار",
      context_ok ? AUDIT_PASS : AUDIT_BLOCK,
      context_ok
      ? "داده محیط بازار معتبر است"
      : "محیط بازار کامل نیست");

   bool regime_pass = (!g_regime.valid || g_regime.regime == MARKET_REGIME_UPTREND ||
g_regime.regime == MARKET_REGIME_DOWNTREND || g_regime.regime == MARKET_REGIME_TRANSITION);

bool regime_uncertain = (g_regime.valid && g_regime.regime == MARKET_REGIME_UNCERTAIN);

if(regime_uncertain)
{
   FilterAudit_Add(g_filter_audit, "رژیم بازار", AUDIT_INFO,
   "رژیم نامشخص است - ضریب اطمینان سناریو 30% کاهش می‌یابد");
}
else
{
   FilterAudit_Add(g_filter_audit, "رژیم بازار",
   regime_pass ? AUDIT_PASS : AUDIT_BLOCK,
   regime_pass ? "رژیم مانع Opportunity نیست" : "رژیم نامشخص است");
}
   FilterAudit_Add(
      g_filter_audit,
      "ساختار",
      structure_ok
      ? AUDIT_PASS
      : AUDIT_BLOCK,
      structure_ok
      ? MarketStructure_StateToPersian(
           g_structure.state)
      : "ساختار کافی نیست");

   bool movement_pass =
      move_ok ||
      (g_market_truth.valid &&
       g_market_truth.strong_market_move);

   FilterAudit_Add(
      g_filter_audit,
      "حرکت قیمت",
      movement_pass
      ? AUDIT_PASS
      : AUDIT_BLOCK,
      movement_pass
      ? "حرکت قابل استفاده شناسایی شد"
      : "حرکت معنی‌دار کافی نیست");

   bool truth_pass =
      market_truth_ok &&
      g_market_truth.direction !=
         MARKET_TRUTH_NONE;

   FilterAudit_Add(
      g_filter_audit,
      "حقیقت قیمت",
      truth_pass
      ? AUDIT_PASS
      : AUDIT_BLOCK,
      truth_pass
      ? g_market_truth.reason
      : "خوانش مستقل قیمت معتبر نیست");

   bool zone_pass =
      has_buy_zone ||
      has_sell_zone;

   FilterAudit_Add(
      g_filter_audit,
      "Zone",
      zone_pass
      ? AUDIT_PASS
      : AUDIT_BLOCK,
      zone_pass
      ? "حداقل یک ناحیه شناخته شد"
      : "Zone ساختاری فعال در دسترس نیست");

   FilterAudit_Add(
      g_filter_audit,
      "Correction",
      correction_ok
      ? AUDIT_PASS
      : AUDIT_INFO,
      correction_ok
      ? "اصلاح معتبر وجود دارد"
      : "اصلاح کامل نیست");

   bool div_block =
      (g_market_truth.direction ==
         MARKET_TRUTH_BUY
       ? divergence_blocks_buy
       :
       (g_market_truth.direction ==
          MARKET_TRUTH_SELL
        ? divergence_blocks_sell
        : false));

   FilterAudit_Add(
      g_filter_audit,
      "واگرایی",
      div_block
      ? AUDIT_BLOCK
      : AUDIT_PASS,
      div_block
      ? "واگرایی مخالف جهت شناسایی شد"
      : "مانع واگرایی فعال نیست");

   FilterAudit_Add(
      g_filter_audit,
      "تأیید کندل",
      AUDIT_INFO,
      "تأیید کندل فقط برای مرحله اجرای واقعی است و ممیزی را متوقف نمی‌کند");

   FilterAudit_Add(
      g_filter_audit,
      "فاصله Entry",
      AUDIT_PASS,
      "گیت ثابت 300 Point حذف شده است؛ فاصله توسط منطق Entry سنجیده می‌شود");

   FilterAudit_Print(g_filter_audit);
}

//====================================================================
// تحلیل بازار و ساخت سناریو
//====================================================================
bool AnalyzeMarket(
   TradingScenario &new_scenario,
   SLPlan &new_sl_plan,
   TP_Result &new_tp_result,
   TargetInfo &new_target)
{
   Scenario_Init(new_scenario);
   Target_Init(new_target);
   TP_Init(new_tp_result);
   ZeroMemory(new_sl_plan);

   g_is_transition_mode = false;
   g_last_strategy_type = STRATEGY_NONE;
   g_last_strategy_confidence = 0.0;

   double bid, ask, current_price;

   if(!GetCurrentPrices(
      bid,
      ask,
      current_price))
   {
      SetScenarioDiagnostic(
         "PRICE_FAIL | دریافت Bid/Ask ناموفق بود");
      return false;
   }

   if(!RefreshHigherTimeframeContext())
   {
      SetScenarioDiagnostic(
         "HTF_FAIL | به‌روزرسانی زمینه H4/H1 ناموفق بود");
      return false;
   }

   bool context_ok =
      MarketContext_Analyze(
         _Symbol,
         Inp_TF_Context_M30,
         Inp_ATR_Period,
         20,
         g_context);

   bool regime_ok =
      MarketRegime_Analyze(
         _Symbol,
         Inp_TF_Context_M30,
         Inp_ADX_Period,
         Inp_RSI_Period,
         Inp_EMA_Trend_Period,
         Inp_ATR_Period,
         Inp_ADX_Min_Trend,
         Inp_ADX_Exhaustion_Level,
         Inp_RSI_Overbought,
         Inp_RSI_Oversold,
         Inp_Max_Price_EMA_ATR_Distance,
         g_regime);

   bool structure_ok =
      MarketStructure_Analyze(
         _Symbol,
         Inp_TF_Structure_M15,
         120,
         2,
         2,
         20.0,
         g_structure);

   bool move_ok =
      ImpulseCorrection_Analyze(
         _Symbol,
         Inp_TF_Setup_M5,
         120,
         2,
         2,
         20.0,
         g_move);

   bool market_truth_ok =
      Inp_Use_Market_Truth &&
      MarketTruth_Analyze(
         _Symbol,
         Inp_TF_Setup_M5,
         Inp_Market_Truth_Lookback,
         g_market_truth);

   Print(
      "[MARKET_TRUTH] ",
      market_truth_ok ? "VALID" : "FAIL",
      " | ",
      g_market_truth.reason,
      " | Direction=",
      MarketTruth_DirectionToString(
         g_market_truth.direction),
      " | Phase=",
      MarketTruth_PhaseToString(
         g_market_truth.phase),
      " | Continuation=",
      g_market_truth.continuation_ready
      ? "YES"
      : "NO");

   bool market_reading_ok =
      MarketReading_Analyze(
         _Symbol,
         Inp_TF_Setup_M5,
         g_market_truth,
         g_structure,
         g_market_reading);

   if(market_reading_ok)
   {
      Print(
         "[خوانش بازار] گذشته | ",
         g_market_reading.past_state);

      Print(
         "[خوانش بازار] حال | ",
         g_market_reading.now_state);

      Print(
         "[خوانش بازار] آینده مشروط | ",
         g_market_reading.future_state);
   }

   if(!context_ok ||
      !regime_ok ||
      !structure_ok ||
      !move_ok)
   {
      SetScenarioDiagnostic(
         "ANALYSIS_FAIL | Context=" +
         (context_ok ? "PASS" : "FAIL") +
         " | Regime=" +
         (regime_ok ? "PASS" : "FAIL") +
         " | Structure=" +
         (structure_ok ? "PASS" : "FAIL") +
         " | Move=" +
         (move_ok ? "PASS" : "FAIL"));

      return false;
   }

   double atr_price =
      g_context.atr_points *
      _Point;

   if(atr_price <= 0.0)
   {
      atr_price =
         MathMax(
            _Point * 20.0,
            g_structure.structure_range_points *
            _Point *
            0.10);
   }

   if(atr_price <= 0.0)
   {
      SetScenarioDiagnostic(
         "ATR_FAIL | مقدار ATR معتبر نیست");
      return false;
   }

   ZoneInfo buy_zone;
   ZoneInfo sell_zone;

   Zone_Init(buy_zone);
   Zone_Init(sell_zone);

   bool has_buy =
      BuildBuyZone(
         g_structure,
         atr_price,
         buy_zone);

   bool has_sell =
      BuildSellZone(
         g_structure,
         atr_price,
         sell_zone);

   if(has_buy)
      g_buy_zone = buy_zone;

   if(has_sell)
      g_sell_zone = sell_zone;

   if(Inp_Use_Market_Truth &&
      market_truth_ok)
   {
      int truth_dir =
         (g_market_truth.direction ==
            MARKET_TRUTH_BUY
          ? 1
          :
          (g_market_truth.direction ==
             MARKET_TRUTH_SELL
           ? -1
           : 0));

      int structure_dir =
         (g_structure.state ==
            STRUCTURE_STATE_BULLISH
          ? 1
          :
          (g_structure.state ==
             STRUCTURE_STATE_BEARISH
           ? -1
           : 0));

      if(truth_dir != 0 &&
         structure_dir == truth_dir)
      {
         Print(
            "[MARKET_TRUTH_OVERLAP] Price/Structure هم‌جهت");
      }
      else
      if(truth_dir != 0 &&
         structure_dir != 0 &&
         truth_dir != structure_dir)
      {
         Print(
            "[MARKET_TRUTH_DIVERGENCE] Price با Structure ربات اختلاف دارد | Truth=",
            MarketTruth_DirectionToString(
               g_market_truth.direction),
            " | Structure=",
            (structure_dir > 0
             ? "BUY"
             : "SELL"));
      }

      if(g_market_truth.continuation_ready &&
         ((truth_dir < 0 && !has_sell) ||
          (truth_dir > 0 && !has_buy)))
      {
         Print(
            "[FIRST_MISS] Opportunity بالقوه وجود دارد ولی Zone هم‌جهت نیست");
      }
   }

   if(!has_buy && !has_sell)
      SetScenarioDiagnostic(
         "ZONE_INFO | Zone ساختاری فعال نیست");

   ENUM_HTF_DIRECTION htf =
      GetHigherTimeframeDirection();

   bool htf_allows_buy =
      Inp_Allow_Contrary_Background ||
      (htf != HTF_DIRECTION_BEARISH);

   bool htf_allows_sell =
      Inp_Allow_Contrary_Background ||
      (htf != HTF_DIRECTION_BULLISH);

   bool regime_allows_buy =
      MarketRegime_SupportsDirection(
         g_regime,
         true,
         Inp_Min_Regime_Confidence);

   bool regime_allows_sell =
      MarketRegime_SupportsDirection(
         g_regime,
         false,
         Inp_Min_Regime_Confidence);

   if(!g_regime.valid)
   {
      regime_allows_buy = true;
      regime_allows_sell = true;
   }

   bool streak_allows_buy =
      (g_structure.bullish_swing_streak <=
       Inp_Max_Consecutive_Swings);

   bool streak_allows_sell =
      (g_structure.bearish_swing_streak <=
       Inp_Max_Consecutive_Swings);

   ENUM_DIVERGENCE_TYPE divergence =
      DIVERGENCE_NONE;

   string divergence_reason = "";

   if(Inp_Enable_Divergence_Filter)
   {
      divergence =
         Divergence_Detect(
            _Symbol,
            Inp_TF_Structure_M15,
            Inp_RSI_Period,
            g_structure,
            divergence_reason);
   }

   bool divergence_blocks_buy =
      Inp_Reject_On_Against_Divergence &&
      Divergence_IsAgainstDirection(
         divergence,
         true);

   bool divergence_blocks_sell =
      Inp_Reject_On_Against_Divergence &&
      Divergence_IsAgainstDirection(
         divergence,
         false);

   RunFilterAudit(
      context_ok,
      regime_ok,
      structure_ok,
      move_ok,
      market_truth_ok,
      has_buy,
      has_sell,
      g_move.correction_valid,
      divergence_blocks_buy,
      divergence_blocks_sell);

   bool truth_buy_setup =
      market_truth_ok &&
      MarketTruth_SupportsDirection(
         g_market_truth,
         true);

   bool truth_sell_setup =
      market_truth_ok &&
      MarketTruth_SupportsDirection(
         g_market_truth,
         false);

   bool base_buy_setup =
      has_buy &&
      g_structure.state ==
         STRUCTURE_STATE_BULLISH &&
      ((g_move.impulse_valid &&
        g_move.impulse_direction > 0) ||
       truth_buy_setup);

   bool base_sell_setup =
      has_sell &&
      g_structure.state ==
         STRUCTURE_STATE_BEARISH &&
      ((g_move.impulse_valid &&
        g_move.impulse_direction < 0) ||
       truth_sell_setup);

   if(!base_buy_setup &&
      !base_sell_setup)
   {
      base_buy_setup =
         has_buy &&
         (htf ==
            HTF_DIRECTION_BULLISH) &&
         g_move.impulse_valid &&
         g_move.impulse_direction > 0;

      base_sell_setup =
         has_sell &&
         (htf ==
            HTF_DIRECTION_BEARISH) &&
         g_move.impulse_valid &&
         g_move.impulse_direction < 0;
   }

   ConfluenceResult buy_confluence;
   ConfluenceResult sell_confluence;

   Confluence_Init(buy_confluence);
   Confluence_Init(sell_confluence);

   bool buy_candidate = false;
   bool sell_candidate = false;

   if(Inp_Use_Confluence_Scoring)
   {
      if(base_buy_setup &&
         !divergence_blocks_buy)
      {
         Confluence_Calculate(
            htf_allows_buy,
            regime_allows_buy,
            g_regime.confidence,
            streak_allows_buy,
            divergence_blocks_buy,
            Divergence_SupportsDirection(
               divergence,
               true),
            buy_confluence);

         buy_candidate =
            (buy_confluence.score >=
             Inp_Min_Confluence_Score);
      }

      if(base_sell_setup &&
         !divergence_blocks_sell)
      {
         Confluence_Calculate(
            htf_allows_sell,
            regime_allows_sell,
            g_regime.confidence,
            streak_allows_sell,
            divergence_blocks_sell,
            Divergence_SupportsDirection(
               divergence,
               false),
            sell_confluence);

         sell_candidate =
            (sell_confluence.score >=
             Inp_Min_Confluence_Score);
      }
   }
   else
   {
      buy_candidate =
         base_buy_setup &&
         htf_allows_buy &&
         regime_allows_buy &&
         streak_allows_buy &&
         !divergence_blocks_buy;

      sell_candidate =
         base_sell_setup &&
         htf_allows_sell &&
         regime_allows_sell &&
         streak_allows_sell &&
         !divergence_blocks_sell;
   }

   bool impulse_is_correction = false;

   if(g_move.impulse_valid)
   {
      if(g_structure.state ==
            STRUCTURE_STATE_BULLISH &&
         g_move.impulse_direction < 0)
      {
         impulse_is_correction =
            g_move.correction_valid;
      }
      else
      if(g_structure.state ==
            STRUCTURE_STATE_BEARISH &&
         g_move.impulse_direction > 0)
      {
         impulse_is_correction =
            g_move.correction_valid;
      }
   }

   if(g_move.impulse_valid &&
      !impulse_is_correction)
   {
      if(g_structure.state ==
            STRUCTURE_STATE_BULLISH &&
         g_move.impulse_direction > 0)
      {
         sell_candidate = false;
      }
      else
      if(g_structure.state ==
            STRUCTURE_STATE_BEARISH &&
         g_move.impulse_direction < 0)
      {
         buy_candidate = false;
      }
   }

   double buy_direction_score = 0.0;
   double sell_direction_score = 0.0;

   CalculateDirectionalScores(
      htf,
      has_buy,
      has_sell,
      htf_allows_buy,
      htf_allows_sell,
      regime_allows_buy,
      regime_allows_sell,
      streak_allows_buy,
      streak_allows_sell,
      divergence_blocks_buy,
      divergence_blocks_sell,
      buy_direction_score,
      sell_direction_score);

   if(Inp_Use_Confluence_Scoring)
   {
      buy_direction_score +=
         MathMin(
            10.0,
            buy_confluence.score *
            0.10);

      sell_direction_score +=
         MathMin(
            10.0,
            sell_confluence.score *
            0.10);
   }

   const bool strong_sell_candidate =
      has_sell &&
      g_structure.state ==
         STRUCTURE_STATE_BEARISH &&
      g_structure.bearish_sequence &&
      g_regime.valid &&
      g_regime.regime ==
         MARKET_REGIME_DOWNTREND &&
      g_move.impulse_valid &&
      g_move.impulse_direction < 0 &&
      Zone_IsValid(sell_zone) &&
      sell_direction_score >= 60.0 &&
      !divergence_blocks_sell;

   const bool strong_buy_candidate =
      has_buy &&
      g_structure.state ==
         STRUCTURE_STATE_BULLISH &&
      g_structure.bullish_sequence &&
      g_regime.valid &&
      g_regime.regime ==
         MARKET_REGIME_UPTREND &&
      g_move.impulse_valid &&
      g_move.impulse_direction > 0 &&
      Zone_IsValid(buy_zone) &&
      buy_direction_score >= 60.0 &&
      !divergence_blocks_buy;

   if(strong_sell_candidate)
      sell_candidate = true;

   if(strong_buy_candidate)
      buy_candidate = true;

   if(truth_sell_setup &&
      has_sell &&
      g_structure.state ==
         STRUCTURE_STATE_BEARISH &&
      !divergence_blocks_sell)
   {
      sell_candidate = true;
   }

   if(truth_buy_setup &&
      has_buy &&
      g_structure.state ==
         STRUCTURE_STATE_BULLISH &&
      !divergence_blocks_buy)
   {
      buy_candidate = true;
   }

   if(!StrongDirectionalLockAllows(
      SCENARIO_DIRECTION_BUY,
      htf))
      buy_candidate = false;

   if(!StrongDirectionalLockAllows(
      SCENARIO_DIRECTION_SELL,
      htf))
      sell_candidate = false;

   //===============================================================
   // Transition + Pullback Continuation
   //===============================================================
   bool transition_sell = false;
   bool transition_buy  = false;

   /*
      Pullback Continuation:
      اگر ساختار و HTF نزولی باشند و قیمت در حال اصلاح صعودی باشد،
      حرکت UP الزاماً BUY Setup نیست.

      در این حالت:
      Structure = BEARISH
      HTF       = BEARISH
      CorrectionValid = YES
      ImpulseDir = UP

      می‌تواند یک Pullback برای SELL Continuation باشد.
   */
   bool pullback_sell_candidate = false;
   bool pullback_buy_candidate  = false;

   if(Inp_Use_Market_Truth &&
      market_truth_ok &&
      g_move.impulse_valid)
   {
      const double MIN_TRANSITION_ATR = 2.0;
      const double MIN_PULLBACK_ATR   = 2.0;

      //============================================================
      // SELL TRANSITION
      // حالت قدیمی: فقط وقتی خود Truth هم SELL باشد.
      //============================================================
      if(truth_sell_setup &&
         htf == HTF_DIRECTION_BEARISH &&
         g_move.impulse_direction < 0 &&
         g_move.impulse_atr_multiple >=
            MIN_TRANSITION_ATR)
      {
         bool regime_against =
            (g_regime.valid &&
             g_regime.regime ==
                MARKET_REGIME_UPTREND);

         bool structure_against =
            (g_structure.state ==
             STRUCTURE_STATE_BULLISH);

         if(regime_against != structure_against)
         {
            transition_sell = true;

            Print(
               "[TRANSITION MODE] SELL | Truth=SELL | HTF=BEARISH | Impulse=DOWN (ATRx=",
               DoubleToString(
                  g_move.impulse_atr_multiple,
                  2),
               ") | OpposingLayer=",
               regime_against
               ? "Regime"
               : "Structure",
               " | کاهش ریسک به 50%");
         }
      }

      //============================================================
      // BUY TRANSITION
      //============================================================
      if(truth_buy_setup &&
         htf == HTF_DIRECTION_BULLISH &&
         g_move.impulse_direction > 0 &&
         g_move.impulse_atr_multiple >=
            MIN_TRANSITION_ATR)
      {
         bool regime_against =
            (g_regime.valid &&
             g_regime.regime ==
                MARKET_REGIME_DOWNTREND);

         bool structure_against =
            (g_structure.state ==
             STRUCTURE_STATE_BEARISH);

         if(regime_against != structure_against)
         {
            transition_buy = true;

            Print(
               "[TRANSITION MODE] BUY | Truth=BUY | HTF=BULLISH | Impulse=UP (ATRx=",
               DoubleToString(
                  g_move.impulse_atr_multiple,
                  2),
               ") | OpposingLayer=",
               regime_against
               ? "Regime"
               : "Structure",
               " | کاهش ریسک به 50%");
         }
      }

      //============================================================
      // NEW: SELL PULLBACK CONTINUATION
      //============================================================
      if(htf == HTF_DIRECTION_BEARISH &&
         g_move.impulse_direction > 0 &&
         g_move.impulse_atr_multiple >=
            MIN_PULLBACK_ATR &&
         g_move.correction_valid &&
         g_structure.bearish_sequence &&
         g_structure.state ==
            STRUCTURE_STATE_BEARISH)
      {
         pullback_sell_candidate = true;

         Print(
            "[PULLBACK CONTINUATION] SELL | "
            "HTF=BEARISH"
            " | Structure=BEARISH"
            " | Impulse=UP"
            " | Correction=YES"
            " | ATRx=",
            DoubleToString(
               g_move.impulse_atr_multiple,
               2),
            " | TruthDir=",
            MarketTruth_DirectionToString(
               g_market_truth.direction),
            " | TruthPhase=",
            MarketTruth_PhaseToString(
               g_market_truth.phase),
            " | SELL Continuation Candidate=YES");
      }

      //============================================================
      // NEW: BUY PULLBACK CONTINUATION
      //============================================================
      if(htf == HTF_DIRECTION_BULLISH &&
         g_move.impulse_direction < 0 &&
         g_move.impulse_atr_multiple >=
            MIN_PULLBACK_ATR &&
         g_move.correction_valid &&
         g_structure.bullish_sequence &&
         g_structure.state ==
            STRUCTURE_STATE_BULLISH)
      {
         pullback_buy_candidate = true;

         Print(
            "[PULLBACK CONTINUATION] BUY | "
            "HTF=BULLISH"
            " | Structure=BULLISH"
            " | Impulse=DOWN"
            " | Correction=YES"
            " | ATRx=",
            DoubleToString(
               g_move.impulse_atr_multiple,
               2),
            " | TruthDir=",
            MarketTruth_DirectionToString(
               g_market_truth.direction),
            " | TruthPhase=",
            MarketTruth_PhaseToString(
               g_market_truth.phase),
            " | BUY Continuation Candidate=YES");
      }
   }

   //===============================================================
   // APPLY TRANSITION CANDIDATES
   //===============================================================
   if(transition_sell &&
      !sell_candidate)
   {
      sell_candidate = true;
      g_is_transition_mode = true;
   }

   if(transition_buy &&
      !buy_candidate)
   {
      buy_candidate = true;
      g_is_transition_mode = true;
   }

   //===============================================================
   // APPLY PULLBACK CONTINUATION CANDIDATES
   //
   // مهم:
   // این بخش Transition نیست؛ بنابراین g_is_transition_mode
   // به صورت مصنوعی فعال نمی‌شود و کاهش ریسک 50٪ اعمال نمی‌گردد.
   //===============================================================
   if(pullback_sell_candidate &&
      !sell_candidate)
   {
      sell_candidate = true;

      Print(
         "[SCENARIO CANDIDATE] SELL=PASS | "
         "Reason=Bearish Structure + Bearish HTF + Valid Bullish Pullback");
   }

   if(pullback_buy_candidate &&
      !buy_candidate)
   {
      buy_candidate = true;

      Print(
         "[SCENARIO CANDIDATE] BUY=PASS | "
         "Reason=Bullish Structure + Bullish HTF + Valid Bearish Pullback");
   }

   //===============================================================
   // END OF CORRECTION
   //
   // EOC فقط زمانی بررسی شود که هیچ Candidate پایه‌ای وجود ندارد.
   //===============================================================
   bool end_of_correction_sell_candidate = false;
   double end_of_correction_sell_quality = 0.0;
   string end_of_correction_sell_reason = "";

   ConfluenceResult end_of_correction_sell_confluence;
   Confluence_Init(
      end_of_correction_sell_confluence);

   bool end_of_correction_buy_candidate = false;
   double end_of_correction_buy_quality = 0.0;
   string end_of_correction_buy_reason = "";

   ConfluenceResult end_of_correction_buy_confluence;
   Confluence_Init(
      end_of_correction_buy_confluence);

   if(!buy_candidate &&
      !sell_candidate &&
      impulse_is_correction)
   {
      end_of_correction_sell_candidate =
         DetectEndOfCorrectionSell(
            current_price,
            htf_allows_sell,
            regime_allows_sell,
            streak_allows_sell,
            divergence_blocks_sell,
            divergence,
            end_of_correction_sell_confluence,
            end_of_correction_sell_quality,
            end_of_correction_sell_reason);

      Print(
         "[EOC SELL DIAGNOSTIC] | Candidate=",
         end_of_correction_sell_candidate
         ? "YES"
         : "NO",
         " | Score=",
         DoubleToString(
            end_of_correction_sell_quality,
            1),
         " | Reason=",
         end_of_correction_sell_reason);

      if(end_of_correction_sell_candidate)
         sell_candidate = true;

      if(!end_of_correction_sell_candidate)
      {
         end_of_correction_buy_candidate =
            DetectEndOfCorrectionBuy(
               current_price,
               htf_allows_buy,
               regime_allows_buy,
               streak_allows_buy,
               divergence_blocks_buy,
               divergence,
               end_of_correction_buy_confluence,
               end_of_correction_buy_quality,
               end_of_correction_buy_reason);

         Print(
            "[EOC BUY DIAGNOSTIC] | Candidate=",
            end_of_correction_buy_candidate
            ? "YES"
            : "NO",
            " | Score=",
            DoubleToString(
               end_of_correction_buy_quality,
               1),
            " | Reason=",
            end_of_correction_buy_reason);

         if(end_of_correction_buy_candidate)
            buy_candidate = true;
      }
   }

   //===============================================================
   // EXTRA CANDIDATE DIAGNOSTIC
   //===============================================================
   Print(
      "[SCENARIO CANDIDATE DIAGNOSTIC]"
      " | BaseBUY=",
      base_buy_setup
      ? "PASS"
      : "FAIL",
      " | BaseSELL=",
      base_sell_setup
      ? "PASS"
      : "FAIL",
      " | PullbackBUY=",
      pullback_buy_candidate
      ? "PASS"
      : "NO",
      " | PullbackSELL=",
      pullback_sell_candidate
      ? "PASS"
      : "NO",
      " | TransitionBUY=",
      transition_buy
      ? "YES"
      : "NO",
      " | TransitionSELL=",
      transition_sell
      ? "YES"
      : "NO",
      " | FinalBUY=",
      buy_candidate
      ? "PASS"
      : "FAIL",
      " | FinalSELL=",
      sell_candidate
      ? "PASS"
      : "FAIL");

   //===============================================================
   // DIRECTION SCORE DIAGNOSTIC
   //===============================================================
   SetScenarioDiagnostic(
      "DIRECTION_SCORE | BUY=" +
      DoubleToString(
         buy_direction_score, 1) +
      " | SELL=" +
      DoubleToString(
         sell_direction_score, 1) +
      " | StrongBUY=" +
      (strong_buy_candidate
       ? "YES"
       : "NO") +
      " | StrongSELL=" +
      (strong_sell_candidate
       ? "YES"
       : "NO") +
      " | Structure=" +
      MarketStructure_StateToCode(
         g_structure.state) +
      " | Regime=" +
      MarketRegime_ToCode(
         g_regime.regime) +
      " | HTF=" +
      EnumToString(htf));

   //===============================================================
   // FINAL CANDIDATE FAIL
   //===============================================================
   if(!buy_candidate &&
      !sell_candidate &&
      !end_of_correction_sell_candidate &&
      !end_of_correction_buy_candidate)
   {
      SetScenarioDiagnostic(
         "CANDIDATE_FAIL | Structure=" +
         MarketStructure_StateToCode(
            g_structure.state) +
         " | BullSeq=" +
         (g_structure.bullish_sequence
          ? "YES"
          : "NO") +
         " | BearSeq=" +
         (g_structure.bearish_sequence
          ? "YES"
          : "NO") +
         " | BaseBUY=" +
         (base_buy_setup
          ? "PASS"
          : "FAIL") +
         " | BaseSELL=" +
         (base_sell_setup
          ? "PASS"
          : "FAIL") +
         " | PullbackBUY=" +
         (pullback_buy_candidate
          ? "PASS"
          : "NO") +
         " | PullbackSELL=" +
         (pullback_sell_candidate
          ? "PASS"
          : "NO") +
         " | BUY=" +
         (buy_candidate
          ? "PASS"
          : "FAIL") +
         " | SELL=" +
         (sell_candidate
          ? "PASS"
          : "FAIL") +
         " | BuyConf=" +
         DoubleToString(
            buy_confluence.score, 1) +
         " | SellConf=" +
         DoubleToString(
            sell_confluence.score, 1) +
         " | Regime=" +
         MarketRegime_ToCode(
            g_regime.regime) +
         " | HTF=" +
         EnumToString(htf) +
         " | ImpulseDir=" +
         (g_move.impulse_direction > 0
          ? "UP"
          :
          (g_move.impulse_direction < 0
           ? "DOWN"
           : "NONE")) +
         " | CorrectionValid=" +
         (g_move.correction_valid
          ? "YES"
          : "NO") +
         " | TruthDir=" +
         MarketTruth_DirectionToString(
            g_market_truth.direction) +
         " | TruthPhase=" +
         MarketTruth_PhaseToString(
            g_market_truth.phase) +
         " | TruthMoveATR=" +
         DoubleToString(
            g_market_truth.move_atr_multiple,
            2));

      AIJournal_LogDecision(
         0,
         "NONE",
         current_price,
         g_regime.regime,
         g_regime.confidence,
         false,
         g_structure.state,
         MathMax(
            g_structure.bullish_swing_streak,
            g_structure.bearish_swing_streak),
         false,
         divergence,
         MathMax(
            buy_confluence.score,
            sell_confluence.score),
         0.0,
         AI_JOURNAL_REJECTED_CANDIDATE,
         "نامزد اولیه (Candidate) شکل نگرفت - نه ساختار نه Pullback/EOC تأیید نشد");

      return false;
   }

   SetScenarioDiagnostic(
      "DIRECTION_SCORE | BUY=" +
      DoubleToString(
         buy_direction_score, 1) +
      " | SELL=" +
      DoubleToString(
         sell_direction_score, 1) +
      " | StrongBUY=" +
      (strong_buy_candidate
       ? "YES"
       : "NO") +
      " | StrongSELL=" +
      (strong_sell_candidate
       ? "YES"
       : "NO") +
      " | Structure=" +
      MarketStructure_StateToCode(
         g_structure.state) +
      " | Regime=" +
      MarketRegime_ToCode(
         g_regime.regime) +
      " | HTF=" +
      EnumToString(htf));

   if(!buy_candidate &&
      !sell_candidate &&
      !end_of_correction_sell_candidate &&
      !end_of_correction_buy_candidate)
   {
      SetScenarioDiagnostic(
         "CANDIDATE_FAIL | Structure=" +
         MarketStructure_StateToCode(
            g_structure.state) +
         " | BullSeq=" +
         (g_structure.bullish_sequence
          ? "YES"
          : "NO") +
         " | BearSeq=" +
         (g_structure.bearish_sequence
          ? "YES"
          : "NO") +
         " | BaseBUY=" +
         (base_buy_setup
          ? "PASS"
          : "FAIL") +
         " | BaseSELL=" +
         (base_sell_setup
          ? "PASS"
          : "FAIL") +
         " | BUY=" +
         (buy_candidate
          ? "PASS"
          : "FAIL") +
         " | SELL=" +
         (sell_candidate
          ? "PASS"
          : "FAIL") +
         " | BuyConf=" +
         DoubleToString(
            buy_confluence.score, 1) +
         " | SellConf=" +
         DoubleToString(
            sell_confluence.score, 1) +
         " | Regime=" +
         MarketRegime_ToCode(
            g_regime.regime) +
         " | HTF=" +
         EnumToString(htf) +
         " | ImpulseDir=" +
         (g_move.impulse_direction > 0
          ? "UP"
          :
          (g_move.impulse_direction < 0
           ? "DOWN"
           : "NONE")) +
         " | CorrectionValid=" +
         (g_move.correction_valid
          ? "YES"
          : "NO") +
         " | TruthDir=" +
         MarketTruth_DirectionToString(
            g_market_truth.direction) +
         " | TruthPhase=" +
         MarketTruth_PhaseToString(
            g_market_truth.phase) +
         " | TruthMoveATR=" +
         DoubleToString(
            g_market_truth.move_atr_multiple,
            2));

      AIJournal_LogDecision(
         0,
         "NONE",
         current_price,
         g_regime.regime,
         g_regime.confidence,
         false,
         g_structure.state,
         MathMax(
            g_structure.bullish_swing_streak,
            g_structure.bearish_swing_streak),
         false,
         divergence,
         MathMax(
            buy_confluence.score,
            sell_confluence.score),
         0.0,
         AI_JOURNAL_REJECTED_CANDIDATE,
         "نامزد اولیه (Candidate) شکل نگرفت - نه ساختار نه EOC تأیید نشد");

      return false;
   }

   if(Inp_Enable_News_Filter)
   {
      string news_reason = "";

      if(NewsFilter_IsHighImpactNear(
         _Symbol,
         Inp_News_Minutes_Before,
         Inp_News_Minutes_After,
         news_reason))
      {
         SetScenarioDiagnostic(
            "NEWS_BLOCK | " +
            news_reason);

         return false;
      }
   }

   ENUM_SCENARIO_DIRECTION direction =
      SCENARIO_DIRECTION_NONE;

   if(end_of_correction_sell_candidate)
      direction =
         SCENARIO_DIRECTION_SELL;
   else
   if(end_of_correction_buy_candidate)
      direction =
         SCENARIO_DIRECTION_BUY;
   else
   if(buy_candidate &&
      g_structure.state ==
         STRUCTURE_STATE_BULLISH &&
      impulse_is_correction)
      direction =
         SCENARIO_DIRECTION_BUY;
   else
   if(sell_candidate &&
      g_structure.state ==
         STRUCTURE_STATE_BEARISH &&
      impulse_is_correction)
      direction =
         SCENARIO_DIRECTION_SELL;
   else
   if(g_move.impulse_valid &&
      g_move.impulse_direction > 0 &&
      buy_candidate)
      direction =
         SCENARIO_DIRECTION_BUY;
   else
   if(g_move.impulse_valid &&
      g_move.impulse_direction < 0 &&
      sell_candidate)
      direction =
         SCENARIO_DIRECTION_SELL;
   else
   if(buy_candidate &&
      sell_candidate)
   {
      double buy_score = 50.0;
      double sell_score = 50.0;

      if(g_structure.bullish_sequence)
         buy_score += 20.0;

      if(g_structure.bearish_sequence)
         sell_score += 20.0;

      if(htf ==
         HTF_DIRECTION_BULLISH)
         buy_score += 10.0;

      if(htf ==
         HTF_DIRECTION_BEARISH)
         sell_score += 10.0;

      if(Inp_Use_Confluence_Scoring)
      {
         buy_score +=
            buy_confluence.score * 0.3;

         sell_score +=
            sell_confluence.score * 0.3;
      }

      direction =
         (buy_score >= sell_score
          ? SCENARIO_DIRECTION_BUY
          : SCENARIO_DIRECTION_SELL);
   }
   else
   if(buy_candidate)
      direction =
         SCENARIO_DIRECTION_BUY;
   else
   if(sell_candidate)
      direction =
         SCENARIO_DIRECTION_SELL;

   if(direction ==
      SCENARIO_DIRECTION_NONE)
   {
      SetScenarioDiagnostic(
         "DIRECTION_FAIL | جهت نهایی تعیین نشد");
      return false;
   }

   //--- جلوگیری از ساخت Scenario مخالف قفل شدید
   if(!StrongDirectionalLockAllows(
      direction,
      htf))
   {
      SetScenarioDiagnostic(
         "DIRECTION_BLOCKED | جهت توسط قفل روند شدید مسدود شد | Direction=" +
         ScenarioDirectionToPersian(direction));

      return false;
   }

   ZoneInfo selected_zone;
   Zone_Init(selected_zone);

   if(direction ==
      SCENARIO_DIRECTION_BUY)
      selected_zone = buy_zone;
   else
      selected_zone = sell_zone;

   if(!Zone_IsValid(selected_zone))
   {
      double half =
         MathMax(
            atr_price * 0.35,
            _Point * 20.0);

      Zone_Create(
         900000 +
         (ulong)TimeCurrent(),
         ZONE_TYPE_STRUCTURE,
         direction ==
            SCENARIO_DIRECTION_BUY
         ? ZONE_DIRECTION_BUY
         : ZONE_DIRECTION_SELL,
         current_price - half,
         current_price + half,
         direction ==
            SCENARIO_DIRECTION_BUY
         ? current_price - atr_price
         : current_price + atr_price,
         TimeCurrent(),
         0,
         Inp_TF_Setup_M5,
         45.0,
         "MarketReading",
         "ناحیه مرجع موقت برای Opportunity بازار",
         selected_zone);
   }

   //===============================================================
   // Strategy Engine
   //===============================================================
   StrategyResult strategy_result;
   Strategy_Reset(strategy_result);

   bool strategy_created = false;

   if(direction ==
         SCENARIO_DIRECTION_SELL &&
      end_of_correction_sell_candidate)
   {
      strategy_created =
         CreateEndOfCorrectionSellScenario(
            current_price,
            end_of_correction_sell_quality,
            end_of_correction_sell_reason,
            new_scenario,
            strategy_result);

      if(!strategy_created)
         strategy_result.failure_reason =
            "ساخت Scenario برای EOC SELL ناموفق بود";
   }
   else
   if(direction ==
         SCENARIO_DIRECTION_BUY &&
      end_of_correction_buy_candidate)
   {
      strategy_created =
         CreateEndOfCorrectionBuyScenario(
            current_price,
            end_of_correction_buy_quality,
            end_of_correction_buy_reason,
            new_scenario,
            strategy_result);

      if(!strategy_created)
         strategy_result.failure_reason =
            "ساخت Scenario برای EOC BUY ناموفق بود";
   }
   else
   if(direction ==
         SCENARIO_DIRECTION_BUY)
   {
      strategy_created =
         StrategyEngine_AnalyzeBuyContinuation(
            _Symbol,
            g_regime,
            g_context,
            g_structure,
            g_move,
            buy_zone,
            current_price,
            new_scenario,
            strategy_result);
   }
   else
   if(direction ==
         SCENARIO_DIRECTION_SELL)
   {
      strategy_created =
         StrategyEngine_AnalyzeSellContinuation(
            _Symbol,
            g_regime,
            g_context,
            g_structure,
            g_move,
            sell_zone,
            current_price,
            new_scenario,
            strategy_result);
   }

   //===============================================================
   // Fallback
   //===============================================================
   if(!strategy_created)
   {
      bool fallback_created = false;

      if(!end_of_correction_sell_candidate &&
         direction ==
            SCENARIO_DIRECTION_SELL &&
         strong_sell_candidate)
      {
         fallback_created =
            BuildStrongTrendContinuationScenario(
               direction,
               sell_zone,
               current_price,
               new_scenario,
               strategy_result);
      }
      else
      if(!end_of_correction_buy_candidate &&
         direction ==
            SCENARIO_DIRECTION_BUY &&
         strong_buy_candidate)
      {
         fallback_created =
            BuildStrongTrendContinuationScenario(
               direction,
               buy_zone,
               current_price,
               new_scenario,
               strategy_result);
      }

      if(!fallback_created &&
         g_is_transition_mode)
      {
         fallback_created =
            BuildTransitionScenario(
               direction,
               selected_zone,
               current_price,
               new_scenario,
               strategy_result);

         if(fallback_created)
         {
            Print(
               "[TRANSITION SCENARIO] CREATED | Direction=",
               ScenarioDirectionToPersian(
                  direction),
               " | Quality=",
               DoubleToString(
                  strategy_result.quality,
                  1),
               " | Risk=50%");
         }
      }

      //=============================================================
      // Reversal fallback عمداً غیرفعال است
      //=============================================================
      if(!fallback_created)
      {
         SetScenarioDiagnostic(
            "STRATEGY_FAIL | " +
            (end_of_correction_sell_candidate
             ? "EOC SELL"
             :
             (end_of_correction_buy_candidate
              ? "EOC BUY"
              :
              (direction ==
                  SCENARIO_DIRECTION_BUY
               ? "BUY Continuation"
               : "SELL Continuation"))) +
            " | " +
            (strategy_result.failure_reason != ""
             ? strategy_result.failure_reason
             : "Strategy معتبر ساخته نشد"));

         AIJournal_LogDecision(
            0,
            ScenarioDirectionToPersian(
               direction),
            current_price,
            g_regime.regime,
            g_regime.confidence,
            false,
            g_structure.state,
            MathMax(
               g_structure.bullish_swing_streak,
               g_structure.bearish_swing_streak),
            (direction ==
               SCENARIO_DIRECTION_BUY
             ? htf_allows_buy
             : htf_allows_sell),
            divergence,
            (direction ==
               SCENARIO_DIRECTION_BUY
             ? buy_confluence.score
             : sell_confluence.score),
            0.0,
            AI_JOURNAL_REJECTED_STRATEGY,
            (strategy_result.failure_reason != ""
             ? strategy_result.failure_reason
             : "Strategy معتبر ساخته نشد"));

         return false;
      }

      SetScenarioDiagnostic(
         "STRATEGY_FALLBACK | " +
         StrategyTypeToPersian(
            strategy_result.type) +
         " | جهت=" +
         ScenarioDirectionToPersian(
            direction));
   }

   if(new_scenario.id <= 0 ||
      !Scenario_IsValid(
         new_scenario))
   {
      SetScenarioDiagnostic(
         "STRATEGY_SCENARIO_INVALID | " +
         StrategyTypeToPersian(
            strategy_result.type));

      return false;
   }

   if(strategy_result.quality <
      Inp_Min_Scenario_Quality)
   {
      SetScenarioDiagnostic(
         "STRATEGY_QUALITY_FAIL | Quality=" +
         DoubleToString(
            strategy_result.quality,
            1) +
         " | Min=" +
         DoubleToString(
            Inp_Min_Scenario_Quality,
            1));

      AIJournal_LogDecision(
         new_scenario.id,
         ScenarioDirectionToPersian(
            direction),
         current_price,
         g_regime.regime,
         g_regime.confidence,
         false,
         g_structure.state,
         MathMax(
            g_structure.bullish_swing_streak,
            g_structure.bearish_swing_streak),
         (direction ==
            SCENARIO_DIRECTION_BUY
          ? htf_allows_buy
          : htf_allows_sell),
         divergence,
         (direction ==
            SCENARIO_DIRECTION_BUY
          ? buy_confluence.score
          : sell_confluence.score),
         strategy_result.quality,
         AI_JOURNAL_REJECTED_QUALITY,
         "کیفیت Scenario کمتر از حداقل مجاز است");

      return false;
   }

   if(new_scenario.direction !=
      direction)
   {
      SetScenarioDiagnostic(
         "DIRECTION_MISMATCH | جهت Scenario با جهت نهایی یکی نیست");

      return false;
   }

   if(new_scenario.entry_price <= 0.0)
   {
      SetScenarioDiagnostic(
         "ENTRY_FAIL | Entry سناریو نامعتبر است");

      return false;
   }

   string entry_gate_reason = "";

   if(!EntryGate_AllowsContinuationAtSignal(
      direction,
      strategy_result.type,
      entry_gate_reason))
   {
      SetScenarioDiagnostic(
         "ENTRY_GATE_BLOCKED | " +
         entry_gate_reason +
         " | Strategy=" +
         StrategyTypeToPersian(strategy_result.type) +
         " | Direction=" +
         ScenarioDirectionToPersian(direction));

      Print(
         "[ENTRY GATE] سیگنال پیش از ایجاد معامله متوقف شد | ",
         entry_gate_reason,
         " | Strategy=",
         StrategyTypeToPersian(strategy_result.type),
         " | Direction=",
         ScenarioDirectionToPersian(direction));

      return false;
   }

   g_last_strategy_type = strategy_result.type;
   g_last_strategy_confidence = strategy_result.confidence;

   SetScenarioDiagnostic(
      "STRATEGY_SUCCESS | " +
      StrategyTypeToPersian(
         strategy_result.type) +
      " | ID=" +
      (string)new_scenario.id +
      " | Direction=" +
      ScenarioDirectionToPersian(
         new_scenario.direction) +
      " | Quality=" +
      DoubleToString(
         strategy_result.quality,
         1) +
      " | Entry=" +
      DoubleToString(
         new_scenario.entry_price,
         _Digits));

   AIJournal_LogDecision(
      new_scenario.id,
      ScenarioDirectionToPersian(
         direction),
      new_scenario.entry_price,
      g_regime.regime,
      g_regime.confidence,
      false,
      g_structure.state,
      MathMax(
         g_structure.bullish_swing_streak,
         g_structure.bearish_swing_streak),
      (direction ==
         SCENARIO_DIRECTION_BUY
       ? htf_allows_buy
       : htf_allows_sell),
      divergence,
      (direction ==
         SCENARIO_DIRECTION_BUY
       ? buy_confluence.score
       : sell_confluence.score),
      strategy_result.quality,
      AI_JOURNAL_FORMED,
      "سناریو با موفقیت ساخته شد");

   ENUM_ORDER_TYPE ord_dir =
      (direction ==
         SCENARIO_DIRECTION_BUY
       ? ORDER_TYPE_BUY
       : ORDER_TYPE_SELL);

   double target = 0.0;

   if(direction ==
      SCENARIO_DIRECTION_BUY &&
      g_structure.structural_high >
      new_scenario.entry_price)
   {
      target =
         g_structure.structural_high;
   }

   if(direction ==
      SCENARIO_DIRECTION_SELL &&
      g_structure.structural_low > 0.0 &&
      g_structure.structural_low <
      new_scenario.entry_price)
   {
      target =
         g_structure.structural_low;
   }

   if(target <= 0.0)
   {
      target =
         (direction ==
            SCENARIO_DIRECTION_BUY
          ?
            new_scenario.entry_price +
            atr_price * 2.0
          :
            new_scenario.entry_price -
            atr_price * 2.0);
   }

   if(!Scenario_SetTargets(
      new_scenario,
      target,
      0.0,
      0.0,
      TimeCurrent()))
   {
      SetScenarioDiagnostic(
         "SCENARIO_TARGET_SET_FAIL");
      return false;
   }

   if(!Target_Create(
      100000 + new_scenario.id,
      TARGET_TYPE_STRUCTURE,
      TARGET_PRIORITY_PRIMARY,
      target,
      0.0,
      0.0,
      TimeCurrent(),
      new_scenario.expiry_time,
      new_scenario.quality_value,
      "MarketStructure",
      "هدف ساختاری سناریو",
      new_target))
   {
      SetScenarioDiagnostic(
         "TARGET_ENGINE_CREATE_FAIL");
      return false;
   }

   if(!Target_SetEntryDistance(
      new_target,
      ord_dir,
      new_scenario.entry_price))
   {
      SetScenarioDiagnostic(
         "TARGET_ENTRY_DISTANCE_FAIL");
      return false;
   }

   if(!Target_UpdateStatus(
      new_target,
      TimeCurrent()))
   {
      SetScenarioDiagnostic(
         "TARGET_STATUS_FAIL");
      return false;
   }

   ENUM_SL_DIRECTION sl_dir =
      (direction ==
         SCENARIO_DIRECTION_BUY
       ? SL_DIRECTION_BUY
       : SL_DIRECTION_SELL);

   if(!SL_FromMarketReferences(
      _Symbol,
      sl_dir,
      new_scenario.entry_price,
      g_structure,
      atr_price,
      _Point,
      new_sl_plan))
   {
      SetScenarioDiagnostic(
         "SL_FAIL | " +
         (new_sl_plan.reason != ""
          ? new_sl_plan.reason
          : "SL Engine نتوانست Reference مناسب ایجاد کند"));

      return false;
   }

   if(!SL_IsValid(new_sl_plan))
   {
      SetScenarioDiagnostic(
         "SL_VALIDATION_FAIL | SL=" +
         DoubleToString(
            new_sl_plan.stop_price,
            _Digits));

      return false;
   }

   Print(
      "[SL READY] | Reference=",
      SLReferenceToPersian(
         new_sl_plan.reference_source),
      " | Entry=",
      DoubleToString(
         new_sl_plan.entry_price,
         _Digits),
      " | SL=",
      DoubleToString(
         new_sl_plan.stop_price,
         _Digits),
      " | Distance=",
      DoubleToString(
         new_sl_plan.distance_price,
         _Digits),
      " | ATR=",
      DoubleToString(
         new_sl_plan.atr_value,
         _Digits));

   if(!EnsureTargetMeetsMinimumRR(
      direction,
      new_scenario.entry_price,
      new_sl_plan.stop_price,
      target,
      atr_price))
   {
      SetScenarioDiagnostic(
         "TARGET_RR_PROTECTION_FAIL");
      return false;
   }

   double system_target = target;
   double tp2_price = system_target;

   double min_reward =
      MathAbs(
         new_scenario.entry_price -
         new_sl_plan.stop_price);

   double tp1_price = 0.0;

   if(direction ==
      SCENARIO_DIRECTION_BUY)
      tp1_price =
         new_scenario.entry_price +
         min_reward;
   else
      tp1_price =
         new_scenario.entry_price -
         min_reward;

   double half_tp =
      new_scenario.entry_price +
      (system_target -
       new_scenario.entry_price) *
      0.50;

   if(direction ==
         SCENARIO_DIRECTION_BUY &&
      half_tp > tp1_price)
      tp1_price = half_tp;
   else
   if(direction ==
         SCENARIO_DIRECTION_SELL &&
      half_tp < tp1_price)
      tp1_price = half_tp;

   if(!Scenario_SetTargets(
      new_scenario,
      tp1_price,
      tp2_price,
      0.0,
      TimeCurrent()))
   {
      SetScenarioDiagnostic(
         "SCENARIO_TARGET_SPLIT_FAIL");
      return false;
   }

   if(direction ==
         SCENARIO_DIRECTION_BUY &&
      target <=
      new_scenario.entry_price)
   {
      SetScenarioDiagnostic(
         "TP1_DIRECTION_FAIL | TP1 باید بالاتر از Entry باشد");
      return false;
   }

   if(direction ==
         SCENARIO_DIRECTION_SELL &&
      target >=
      new_scenario.entry_price)
   {
      SetScenarioDiagnostic(
         "TP1_DIRECTION_FAIL | TP1 باید پایین‌تر از Entry باشد");
      return false;
   }

   TP_Target tp_target;
   TP_TargetInit(tp_target);

   if(!TP_CreateTarget(
      1,
      TP_TARGET_STRUCTURE,
      TP_STATUS_VALID,
      tp1_price,
      new_scenario.quality_value,
      "هدف ساختاری سناریو",
      "MarketStructure",
      tp_target))
   {
      SetScenarioDiagnostic(
         "TP_CREATE_FAIL");
      return false;
   }

   TP_SetTarget(
      new_tp_result,
      1,
      tp_target);

   TP_ValidateTargets(
      direction ==
         SCENARIO_DIRECTION_BUY,
      new_scenario.entry_price,
      new_tp_result);

   new_tp_result.valid =
      TP_HasValidTarget(
         new_tp_result);

   if(!new_tp_result.valid)
   {
      SetScenarioDiagnostic(
         "TP_VALIDATION_FAIL");
      return false;
   }

   if(!Scenario_SetTargets(
      new_scenario,
      tp1_price,
      tp2_price,
      0.0,
      TimeCurrent()))
   {
      SetScenarioDiagnostic(
         "FINAL_TARGET_ASSIGN_FAIL");
      return false;
   }

   Print(
      "[TARGET DIAGNOSTIC] | Entry=",
      DoubleToString(
         new_scenario.entry_price,
         _Digits),
      " | SL=",
      DoubleToString(
         new_sl_plan.stop_price,
         _Digits),
      " | TP1=",
      DoubleToString(
         new_scenario.target_1,
         _Digits),
      " | RR=",
      DoubleToString(
         MathAbs(
            new_scenario.target_1 -
            new_scenario.entry_price) /
         MathMax(
            MathAbs(
               new_scenario.entry_price -
               new_sl_plan.stop_price),
            _Point),
         2),
      " | TP2=",
      DoubleToString(
         new_scenario.target_2,
         _Digits));

   if(!Scenario_IsValid(
      new_scenario))
   {
      SetScenarioDiagnostic(
         "FINAL_SCENARIO_VALIDATION_FAIL");
      return false;
   }

//--- [جدید] کاهش ضریب اطمینان در رژیم نامشخص
if(g_regime.valid && g_regime.regime == MARKET_REGIME_UNCERTAIN)
{
   new_scenario.quality_value *= 0.70;
   Print("[REGIME UNCERTAIN] ضریب اطمینان سناریو 30% کاهش یافت | Quality=", 
         DoubleToString(new_scenario.quality_value, 1));
}

   SetScenarioDiagnostic(
      "SCENARIO_SUCCESS | ID=" +
      (string)new_scenario.id +
      (g_is_transition_mode
       ? " | TRANSITION_MODE"
       : "") +
      " | Strategy=" +
      StrategyTypeToPersian(
         strategy_result.type) +
      " | Direction=" +
      ScenarioDirectionToPersian(
         new_scenario.direction) +
      " | Quality=" +
      DoubleToString(
         new_scenario.quality_value,
         1) +
      " | Entry=" +
      DoubleToString(
         new_scenario.entry_price,
         _Digits) +
      " | Target=" +
      DoubleToString(
         new_scenario.target_1,
         _Digits) +
      " | SL=" +
      DoubleToString(
         new_sl_plan.stop_price,
         _Digits));

   return true;
}

//====================================================================
// بررسی یکسان بودن دو سناریو
//====================================================================
bool IsSameScenario(
   const TradingScenario &old_scenario,
   const TradingScenario &new_scenario)
{
   if(old_scenario.id == 0 ||
      new_scenario.id == 0)
      return false;

   if(old_scenario.direction !=
      new_scenario.direction)
      return false;

   if(MathAbs(
      old_scenario.entry_price -
      new_scenario.entry_price) > 2.0)
      return false;

   if(MathAbs(
      old_scenario.invalidation_price -
      new_scenario.invalidation_price) > 2.0)
      return false;

   if(MathAbs(
      old_scenario.target_1 -
      new_scenario.target_1) > 2.0)
      return false;

   return true;
}

//====================================================================
// یافتن معامله باز مربوط به Scenario
//====================================================================
bool HasOpenPositionForScenario(
   const ulong scenario_id)
{
   if(scenario_id == 0)
      return false;

   const string tag =
      "TFlab S#" +
      (string)scenario_id +
      " |";

   for(int i = 0;
       i < PositionsTotal();
       i++)
   {
      const ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0 ||
         !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(
            POSITION_SYMBOL) != _Symbol)
         continue;

      if((ulong)PositionGetInteger(
            POSITION_MAGIC) !=
         Inp_MagicNumber)
         continue;

      if(StringFind(
         PositionGetString(
            POSITION_COMMENT),
         tag) >= 0)
         return true;
   }

   return false;
}

//====================================================================
// استخراج ScenarioID از Comment
//====================================================================
ulong ExtractScenarioIdFromComment(const string comment)
{
   int p1 = StringFind(comment, "TFlab S#");
   if(p1 < 0)
      return 0;

   p1 += 8;

   int p2 = StringFind(comment, " ", p1);
   string id_str =
      (p2 > p1
       ? StringSubstr(comment, p1, p2 - p1)
       : StringSubstr(comment, p1));

   if(id_str == "")
      return 0;

   return (ulong)StringToInteger(id_str);
}

//====================================================================
// استخراج قیمت از برچسب داخل Comment
//====================================================================
double ExtractPriceTagFromComment(const string comment, const string tag)
{
   if(comment == "" || tag == "")
      return 0.0;

   int start = StringFind(comment, tag);
   if(start < 0)
      return 0.0;

   start += StringLen(tag);
   int end = StringFind(comment, " ", start);
   if(end < 0)
      end = StringFind(comment, "|", start);

   string value = (end > start
                   ? StringSubstr(comment, start, end - start)
                   : StringSubstr(comment, start));

   if(value == "")
      return 0.0;

   return StringToDouble(value);
}

void ExtractOriginalScenarioTargets(const string comment,
                                    double &tp1,
                                    double &tp2)
{
   tp1 = ExtractPriceTagFromComment(comment, "TP1=");
   tp2 = ExtractPriceTagFromComment(comment, "TP2=");
}

//====================================================================
// استخراج حد ضرر اولیه سناریو از Comment
//====================================================================
double ExtractOriginalScenarioSL(const string comment)
{
   return ExtractPriceTagFromComment(comment, "SL=");
}

//====================================================================
// دریافت ATR جاری بر حسب قیمت
//====================================================================
double GetCurrentATRPrice()
{
   double atr_price = g_move.impulse_atr;

   if(atr_price <= 0.0 && g_context.atr_points > 0.0)
      atr_price = g_context.atr_points * _Point;

   if(atr_price <= 0.0 && g_m5_metrics.atr_points > 0.0)
      atr_price = g_m5_metrics.atr_points * _Point;

   return atr_price;
}

//====================================================================
// تعداد معاملات باز مربوط به یک Scenario
//====================================================================
int CountOpenPositionsForScenario(const ulong scenario_id)
{
   if(scenario_id == 0)
      return 0;

   int count = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if((ulong)PositionGetInteger(POSITION_MAGIC) != Inp_MagicNumber)
         continue;

      ulong sid = ExtractScenarioIdFromComment(
         PositionGetString(POSITION_COMMENT));

      if(sid == scenario_id)
         count++;
   }

   return count;
}

//====================================================================
// تعداد Pendingهای مربوط به یک Scenario در خود حساب
// این تابع به State داخلی وابسته نیست؛ بعد از ری‌استارت هم درست می‌خواند.
//====================================================================
int CountPendingOrdersForScenario(const ulong scenario_id)
{
   if(scenario_id == 0)
      return 0;

   int count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;

      if((ulong)OrderGetInteger(ORDER_MAGIC) != Inp_MagicNumber)
         continue;

      ENUM_ORDER_TYPE type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(type != ORDER_TYPE_BUY_LIMIT  &&
         type != ORDER_TYPE_SELL_LIMIT &&
         type != ORDER_TYPE_BUY_STOP   &&
         type != ORDER_TYPE_SELL_STOP)
         continue;

      ulong sid = ExtractScenarioIdFromComment(
         OrderGetString(ORDER_COMMENT));

      if(sid == scenario_id)
         count++;
   }

   return count;
}

//====================================================================
// تعداد Exposure واقعی یک Scenario
// Market + Pending
//====================================================================
int CountScenarioExposure(const ulong scenario_id)
{
   return CountOpenPositionsForScenario(scenario_id) +
          CountPendingOrdersForScenario(scenario_id);
}

//====================================================================
// آماده‌سازی Pool داخلی Pending
//====================================================================
void PendingPool_Init()
{
   ArrayResize(g_pending_pool, TFLAB_PENDING_TRACK_LIMIT);

   for(int i = 0; i < ArraySize(g_pending_pool); i++)
      PendingOrder_Init(g_pending_pool[i]);

   PendingOrder_Init(g_pending);
}

//====================================================================
// ذخیره یک Pending اضافه در Pool
//====================================================================
bool PendingPool_Store(const PendingOrderRecord &record)
{
   if(record.ticket == 0 || !record.active)
      return false;

   for(int i = 0; i < ArraySize(g_pending_pool); i++)
   {
      if(g_pending_pool[i].ticket == record.ticket)
      {
         g_pending_pool[i] = record;
         return true;
      }
   }

   for(int i = 0; i < ArraySize(g_pending_pool); i++)
   {
      if(g_pending_pool[i].ticket == 0 || !g_pending_pool[i].active)
      {
         g_pending_pool[i] = record;
         return true;
      }
   }

   Print("[PENDING POOL] ظرفیت داخلی Pool پر است | Ticket=",
         record.ticket);
   return false;
}

//====================================================================
// حذف رکورد تمام‌شده از Pool
//====================================================================
void PendingPool_Clean()
{
   for(int i = 0; i < ArraySize(g_pending_pool); i++)
   {
      if(g_pending_pool[i].ticket == 0)
         continue;

      if(g_pending_pool[i].active)
         continue;

      PendingOrder_Init(g_pending_pool[i]);
   }
}

//====================================================================
// ساخت Comment یکتا برای هر عضو سهمیه
//====================================================================
string MakeSignalTradeComment(const int index,
                              const int total,
                              const string suffix = "")
{
   string base = MakeScenarioComment(
      g_scenario.id,
      g_scenario.target_1,
      g_scenario.target_2,
      g_sl_plan.stop_price);

   string c = base + " | STrade=" +
              IntegerToString(index) + "/" +
              IntegerToString(total);

   if(suffix != "")
      c += " | " + suffix;

   return c;
}

//====================================================================
// لغو مستقیم یک Pending واقعی بر اساس Ticket
// برای سفارش‌هایی که State داخلی ندارند نیز کار می‌کند.
//====================================================================
bool RemovePendingTicket(const ulong ticket,
                         const string reason)
{
   if(ticket == 0)
      return false;

   if(!OrderSelect(ticket))
      return true;

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action = TRADE_ACTION_REMOVE;
   req.order  = ticket;
   req.magic  = Inp_MagicNumber;
   req.symbol = _Symbol;

   ResetLastError();

   if(!OrderSend(req, res))
   {
      Print("[PENDING REMOVE FAIL] Ticket=", ticket,
            " | Error=", GetLastError(),
            " | Reason=", reason,
            " | Retcode=", res.retcode);
      return false;
   }

   if(res.retcode == TRADE_RETCODE_DONE ||
      res.retcode == TRADE_RETCODE_PLACED)
   {
      Print("[PENDING REMOVE] Ticket=", ticket,
            " | Reason=", reason);
      return true;
   }

   Print("[PENDING REMOVE REJECTED] Ticket=", ticket,
         " | Reason=", reason,
         " | Retcode=", res.retcode);
   return false;
}

//====================================================================
// لغو تمام Pendingهای یک Scenario
//====================================================================
void CancelPendingOrdersForScenario(const ulong scenario_id,
                                    const string reason)
{
   if(scenario_id == 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;

      if((ulong)OrderGetInteger(ORDER_MAGIC) != Inp_MagicNumber)
         continue;

      ENUM_ORDER_TYPE type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(type != ORDER_TYPE_BUY_LIMIT  &&
         type != ORDER_TYPE_SELL_LIMIT &&
         type != ORDER_TYPE_BUY_STOP   &&
         type != ORDER_TYPE_SELL_STOP)
         continue;

      ulong sid = ExtractScenarioIdFromComment(
         OrderGetString(ORDER_COMMENT));

      if(sid != scenario_id)
         continue;

      RemovePendingTicket(ticket, reason);
   }

   PendingPool_Clean();
}

//====================================================================
// انتخاب یک Pending اصلی برای Legacy State
//====================================================================
void SyncPrimaryPendingState()
{
   if(g_pending.active && g_pending.ticket > 0)
      return;

   for(int i = 0; i < ArraySize(g_pending_pool); i++)
   {
      if(g_pending_pool[i].active &&
         g_pending_pool[i].ticket > 0)
      {
         g_pending = g_pending_pool[i];
         return;
      }
   }

   //--- اگر State داخلی خالی است، از سفارش واقعی حساب یک رکورد بساز.
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;

      if((ulong)OrderGetInteger(ORDER_MAGIC) != Inp_MagicNumber)
         continue;

      ENUM_ORDER_TYPE type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(type != ORDER_TYPE_BUY_LIMIT  &&
         type != ORDER_TYPE_SELL_LIMIT &&
         type != ORDER_TYPE_BUY_STOP   &&
         type != ORDER_TYPE_SELL_STOP)
         continue;

      ulong sid = ExtractScenarioIdFromComment(
         OrderGetString(ORDER_COMMENT));

      if(sid == 0)
         continue;

      PendingOrder_Init(g_pending);
      g_pending.local_id       = ticket;
      g_pending.scenario_id    = sid;
      g_pending.ticket         = ticket;
      g_pending.symbol         = OrderGetString(ORDER_SYMBOL);
      g_pending.volume         = OrderGetDouble(ORDER_VOLUME_CURRENT);
      g_pending.price          = OrderGetDouble(ORDER_PRICE_OPEN);
      g_pending.stop_loss      = OrderGetDouble(ORDER_SL);
      g_pending.take_profit    = OrderGetDouble(ORDER_TP);
      g_pending.created_time   = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      g_pending.placed_time    = g_pending.created_time;
      g_pending.expiry_time    = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
      g_pending.last_update_time = TimeCurrent();
      g_pending.active         = true;
      g_pending.state          = PENDING_STATE_ACTIVE;
      g_pending.broker_comment = OrderGetString(ORDER_COMMENT);

      if(type == ORDER_TYPE_BUY_LIMIT ||
         type == ORDER_TYPE_SELL_LIMIT)
         g_pending.plan_type = ENTRY_PLAN_LIMIT;
      else
         g_pending.plan_type = ENTRY_PLAN_STOP;

      g_pending.direction =
         (type == ORDER_TYPE_BUY_LIMIT ||
          type == ORDER_TYPE_BUY_STOP)
         ? SCENARIO_DIRECTION_BUY
         : SCENARIO_DIRECTION_SELL;

      return;
   }
}

//====================================================================
// نگه‌داری State اصلی قبل/بعد از هر چرخه
//====================================================================
void RefreshPendingPoolStates()
{
   for(int i = 0; i < ArraySize(g_pending_pool); i++)
   {
      if(g_pending_pool[i].ticket == 0)
         continue;

      PendingOrder_UpdateState(
         g_pending_pool[i],
         TimeCurrent());
   }

   if(g_pending.ticket > 0)
      PendingOrder_UpdateState(
         g_pending,
         TimeCurrent());

   PendingPool_Clean();
   SyncPrimaryPendingState();
}

//====================================================================
// اصلاح SL/TP معامله
//====================================================================
bool ModifyPositionSLTP(
   const ulong ticket,
   const string symbol,
   const double new_sl,
   const double new_tp)
{
   if(ticket == 0)
      return false;

   double sl =
      NormalizeDouble(
         new_sl,
         _Digits);

   double tp =
      NormalizeDouble(
         new_tp,
         _Digits);

   if(sl <= 0.0 &&
      tp <= 0.0)
      return false;

   MqlTradeRequest req;
   MqlTradeResult res;

   ZeroMemory(req);
   ZeroMemory(res);

   req.action =
      TRADE_ACTION_SLTP;

   req.position = ticket;
   req.symbol = symbol;
   req.sl = sl;
   req.tp = tp;

   ResetLastError();

   if(!OrderSend(req, res))
   {
      Print(
         "[SLTP MODIFY FAIL] | Ticket=",
         ticket,
         " | Error=",
         GetLastError(),
         " | Retcode=",
         res.retcode);

      return false;
   }

   return
      (res.retcode ==
         TRADE_RETCODE_DONE ||
       res.retcode ==
         TRADE_RETCODE_DONE_PARTIAL);
}

//====================================================================
// بستن حجم معامله
//====================================================================
bool ClosePositionVolume(
   const ulong ticket,
   const string symbol,
   const bool is_buy,
   const double volume,
   const string comment)
{
   if(ticket == 0)
      return false;

   double close_volume =
      NormalizeVolume(volume);

   if(close_volume <= 0.0)
      return false;

   MqlTradeRequest req;
   MqlTradeResult res;

   ZeroMemory(req);
   ZeroMemory(res);

   MqlTick tick;

   if(!SymbolInfoTick(
      symbol,
      tick))
      return false;

   req.action =
      TRADE_ACTION_DEAL;

   req.position = ticket;
   req.symbol = symbol;
   req.volume = close_volume;

   req.type =
      (is_buy
       ? ORDER_TYPE_SELL
       : ORDER_TYPE_BUY);

   req.price =
      (is_buy
       ? tick.bid
       : tick.ask);

   req.deviation =
      (ulong)Inp_MaxSlippagePoints;

   req.magic =
      Inp_MagicNumber;

   req.comment =
      comment;

   req.type_filling =
      Execution_GetFillingType(
         symbol);

   ResetLastError();

   if(!OrderSend(req, res))
   {
      Print(
         "[CLOSE POSITION FAIL] | Ticket=",
         ticket,
         " | Error=",
         GetLastError());

      return false;
   }

   return
      (res.retcode ==
         TRADE_RETCODE_DONE ||
       res.retcode ==
         TRADE_RETCODE_DONE_PARTIAL);
}

//====================================================================
// بستن معاملات باز مخالف جهت
//====================================================================
void CloseOppositePositions(
   ENUM_SCENARIO_DIRECTION new_direction)
{
   if(!Inp_Close_Opposite_On_Reverse)
      return;

   if(new_direction ==
      SCENARIO_DIRECTION_NONE)
      return;

   for(int i =
      PositionsTotal() - 1;
      i >= 0;
      i--)
   {
      ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(
         ticket))
         continue;

      if(PositionGetString(
            POSITION_SYMBOL) != _Symbol)
         continue;

      if((ulong)PositionGetInteger(
            POSITION_MAGIC) !=
         Inp_MagicNumber)
         continue;

      long pos_type =
         PositionGetInteger(
            POSITION_TYPE);

      bool is_buy =
         (pos_type ==
            POSITION_TYPE_BUY);

      bool is_sell =
         (pos_type ==
            POSITION_TYPE_SELL);

      if((new_direction ==
            SCENARIO_DIRECTION_BUY &&
          is_sell) ||
         (new_direction ==
            SCENARIO_DIRECTION_SELL &&
          is_buy))
      {
         double vol =
            PositionGetDouble(
               POSITION_VOLUME);

         string comment =
            "TFlab Reverse Close (New Scenario)";

         if(ClosePositionVolume(
            ticket,
            _Symbol,
            is_buy,
            vol,
            comment))
         {
            Print(
               "[REVERSE CLOSE] معامله مخالف بسته شد | Ticket=",
               ticket,
               " | جهت قبلی=",
               (is_buy
                ? "BUY"
                : "SELL"),
               " | سناریوی جدید=",
               ScenarioDirectionToPersian(
                  new_direction));
         }
      }
   }
}

//====================================================================
// تعداد پوزیشن‌های باز در یک جهت
//====================================================================
int CountOpenPositionsByDirection(
   const ENUM_SCENARIO_DIRECTION direction)
{
   int count = 0;

   for(int i = 0;
       i < PositionsTotal();
       i++)
   {
      ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(
         ticket))
         continue;

      if(PositionGetString(
            POSITION_SYMBOL) != _Symbol)
         continue;

      if((ulong)PositionGetInteger(
            POSITION_MAGIC) !=
         Inp_MagicNumber)
         continue;

      ENUM_POSITION_TYPE pos_type =
         (ENUM_POSITION_TYPE)
         PositionGetInteger(
            POSITION_TYPE);

      if(direction ==
            SCENARIO_DIRECTION_BUY &&
         pos_type ==
            POSITION_TYPE_BUY)
      {
         count++;
      }
      else
      if(direction ==
            SCENARIO_DIRECTION_SELL &&
         pos_type ==
            POSITION_TYPE_SELL)
      {
         count++;
      }
   }

   return count;
}

//====================================================================
// بستن معاملات مخالف و Verify
//====================================================================
bool CloseOppositePositionsAndVerify(
   const ENUM_SCENARIO_DIRECTION new_direction)
{
   if(new_direction ==
      SCENARIO_DIRECTION_NONE)
      return false;

   ENUM_SCENARIO_DIRECTION opposite_direction =
      (new_direction ==
         SCENARIO_DIRECTION_BUY
       ?
         SCENARIO_DIRECTION_SELL
       :
         SCENARIO_DIRECTION_BUY);

   if(CountOpenPositionsByDirection(
      opposite_direction) == 0)
      return true;

   CloseOppositePositions(
      new_direction);

   for(int attempt = 0;
       attempt < 5;
       attempt++)
   {
      Sleep(100);

      if(CountOpenPositionsByDirection(
         opposite_direction) == 0)
      {
         Print(
            "[REVERSE VERIFY] معامله مخالف کاملاً بسته شد | NewDirection=",
            ScenarioDirectionToPersian(
               new_direction));

         return true;
      }
   }

   int remaining =
      CountOpenPositionsByDirection(
         opposite_direction);

   Print(
      "[REVERSE BLOCKED] معامله مخالف هنوز باز است | Remaining=",
      remaining,
      " | NewDirection=",
      ScenarioDirectionToPersian(
         new_direction));

   return false;
}

//====================================================================
// محاسبه TP2 پویا
//====================================================================
bool CalculateDynamicTP2(
   const bool is_buy,
   const double current_price,
   const double tp1,
   double &tp2,
   string &reason)
{
   tp2 = 0.0;
   reason = "";

   if(current_price <= 0.0 ||
      tp1 <= 0.0)
      return false;

   MarketStructureSnapshot fresh_structure;
   MarketStructure_Reset(
      fresh_structure);

   bool structure_ok =
      MarketStructure_Analyze(
         _Symbol,
         Inp_TF_Structure_M15,
         120,
         2,
         2,
         20.0,
         fresh_structure);

   double atr_price =
      g_move.impulse_atr;

   if(atr_price <= 0.0)
      atr_price =
         g_context.atr_points *
         _Point;

   if(atr_price <= 0.0)
      atr_price =
         _Point * 20.0;

   if(structure_ok)
   {
      if(is_buy &&
         fresh_structure.structural_high >
            tp1 &&
         fresh_structure.structural_high >
            current_price)
      {
         tp2 =
            fresh_structure.structural_high;

         reason =
            "TP2 بر اساس ساختار تازه M15";
      }
      else
      if(!is_buy &&
         fresh_structure.structural_low > 0.0 &&
         fresh_structure.structural_low < tp1 &&
         fresh_structure.structural_low < current_price)
      {
         tp2 =
            fresh_structure.structural_low;

         reason =
            "TP2 بر اساس ساختار تازه M15";
      }
   }

   if(tp2 <= 0.0)
   {
      if(is_buy)
         tp2 =
            tp1 + atr_price;
      else
         tp2 =
            tp1 - atr_price;

      reason =
         "TP2 بر اساس ATR تازه";
   }

   tp2 =
      NormalizeDouble(
         tp2,
         (int)SymbolInfoInteger(
            _Symbol,
            SYMBOL_DIGITS));

   return
      (is_buy
       ? tp2 > tp1
       : tp2 < tp1);
}

//====================================================================
// قفل داخلی Pending
//====================================================================
void LockEntryPlanToActivePending()
{
   if(!g_pending.active ||
      g_pending.ticket == 0)
      return;

   if(g_pending.scenario_id !=
      g_scenario.id)
      return;

   g_entry_plan.type =
      g_pending.plan_type;

   g_entry_plan.status =
      ENTRY_PLAN_STATUS_SENT;

   g_entry_plan.executable =
      false;

   g_entry_plan.entry_currently_available =
      false;

   g_entry_plan.entry_reachable =
      true;

   g_entry_plan.reason =
      "Pending واقعی فعال است؛ مسیر ورود قفل شد | Ticket=" +
      (string)g_pending.ticket;
}

//====================================================================
// مدیریت Scenario و Entry
//====================================================================
void ManageScenarioAndEntry()
{
   double bid, ask, current_price;

   if(!GetCurrentPrices(bid, ask, current_price))
      return;

   datetime now = TimeCurrent();

   RefreshPendingPoolStates();

   if(g_scenario.id <= 0 || !Scenario_IsValid(g_scenario))
   {
      g_entry_plan.type = ENTRY_PLAN_WAIT;
      g_entry_plan.status = ENTRY_PLAN_STATUS_PLANNED;
      g_entry_plan.executable = false;
      return;
   }

   InvalidationResult inv;

   if(!Invalidation_UpdateScenario(
      g_scenario,
      current_price,
      now,
      inv))
   {
      g_main_state.last_error = "ارزیابی Invalidation ناموفق بود";
      return;
   }

   if(g_scenario.status == SCENARIO_STATUS_INVALID ||
      g_scenario.status == SCENARIO_STATUS_EXPIRED)
   {
      Print(
         "[SCENARIO BLOCKED] سناریو دیگر معتبر نیست | ID=",
         g_scenario.id,
         " | Direction=",
         ScenarioDirectionToPersian(g_scenario.direction));

      CancelPendingOrdersForScenario(
         g_scenario.id,
         "Scenario Invalid/Expired");

      ResetActiveScenarioState(
         g_scenario.status == SCENARIO_STATUS_INVALID
         ? "Scenario Invalidated"
         : "Scenario Expired");

      return;
   }

   Setup_SetBase(
      g_setup,
      Scenario_IsValid(g_scenario),
      g_scenario.zone_valid,
      false,
      false,
      ScenarioDirectionToPersian(g_scenario.direction),
      current_price,
      g_scenario.zone_lower,
      g_scenario.zone_upper,
      g_scenario.invalidation_price,
      g_scenario.entry_price,
      now);

   Setup_CheckInvalidation(g_setup);
   Setup_Evaluate(g_setup);

   if(!EntryPlan_Build(
      g_scenario,
      g_setup,
      current_price,
      now,
      g_entry_plan))
      return;

   //=================================================================
   // Pendingهای Scenario قبلی باید مستقل از Scenario جدید بمانند/لغو شوند.
   // برای جلوگیری از مصرف اشتباه سهمیه، Pending قدیمی به Scenario جدید
   // Relink نمی‌شود؛ اگر Scenario عوض شده باشد Pending قبلی لغو می‌شود.
   //=================================================================
   if(g_pending.active && g_pending.ticket > 0 &&
      g_pending.scenario_id != g_scenario.id)
   {
      CancelPendingOrdersForScenario(
         g_pending.scenario_id,
         "Scenario تغییر کرده است؛ Pending قدیمی لغو شد");

      PendingOrder_Init(g_pending);
      RefreshPendingPoolStates();
   }

   //=================================================================
   // Early Market
   // Pending اصلی حفظ می‌شود و سهمیه Scenario را مصرف می‌کند.
   //=================================================================

   const int trades_requested =
      MathMax(1, Inp_Simultaneous_Trades);

   const int scenario_exposure_before =
      CountScenarioExposure(g_scenario.id);

   Print(
      "[SIGNAL QUOTA] Scenario=",
      g_scenario.id,
      " | Requested=",
      trades_requested,
      " | ExistingExposure=",
      scenario_exposure_before,
      " | Open=",
      CountOpenPositionsForScenario(g_scenario.id),
      " | Pending=",
      CountPendingOrdersForScenario(g_scenario.id));

   // اگر این سناریو واقعاً جهت را برگردانده، قبل از باز کردن جهت جدید
   // تمام معاملات جهت قدیمی بسته می‌شوند؛ در غیر این صورت ورود معکوس متوقف می‌شود.
   if(!CloseOldSideBeforeReverseEntry())
   {
      if(HasOppositeOpenPositionForScenarioDirection(g_scenario.direction))
      {
         LogCycle("REVERSE","ورود معکوس تا بسته‌شدن کامل معاملات جهت قبلی متوقف شد");
         return;
      }
   }

   //=================================================================
   // Pending
   //=================================================================
   if(g_entry_plan.type == ENTRY_PLAN_LIMIT ||
      g_entry_plan.type == ENTRY_PLAN_STOP)
   {
      if(!Inp_AllowPendingOrders)
         return;

      if(!IsRealTradingAllowed())
         return;

      string market_reason = "";
      if(!IsMarketOpenForSymbol(market_reason))
      {
         LogCycle(
            "MARKET_CLOSED",
            "ورود Pending لغو شد | " + market_reason);
         return;
      }

      string spread_reason = "";
      if(!IsSpreadAcceptable(spread_reason))
      {
         LogCycle(
            "SPREAD",
            "ورود Pending به دلیل اسپرد بالا لغو شد | " + spread_reason);
         return;
      }

      if(!g_risk_result.approved ||
         g_risk_result.position_volume <= 0.0)
      {
         LogCycle(
            "RISK",
            "ورود Pending به دلیل عدم تأیید ریسک لغو شد");
         return;
      }

      string pending_revalidation_reason = "";

      if(!EntryGate_RevalidateBeforeExecution(
         g_scenario.direction,
         current_price,
         pending_revalidation_reason))
      {
         LogCycle(
            "ENTRY_REVALIDATION",
            "ثبت Pending در لحظه آماده‌سازی متوقف شد | " +
            pending_revalidation_reason);

         Print(
            "[ENTRY REVALIDATION] Pending متوقف شد | Scenario=",
            g_scenario.id,
            " | Direction=",
            ScenarioDirectionToPersian(g_scenario.direction),
            " | Price=",
            DoubleToString(current_price, _Digits),
            " | Reason=",
            pending_revalidation_reason);

         return;
      }

      int existing_scenario_exposure =
         CountScenarioExposure(g_scenario.id);

      int quota_remaining =
         MathMax(0, trades_requested - existing_scenario_exposure);

      if(quota_remaining <= 0)
      {
         LogCycle(
            "SIGNAL_QUOTA",
            "سهمیه این Scenario قبلاً تکمیل شده است | Exposure=" +
            IntegerToString(existing_scenario_exposure) +
            " | Requested=" +
            IntegerToString(trades_requested));
         return;
      }

      const int max_allowed =
         GetEffectiveMaxOpenTrades();

      const int global_exposure =
         Inp_Count_Pending_As_Risk
         ? CountTotalExposure()
         : CountOpenPositions();

      int global_slots =
         MathMax(0, max_allowed - global_exposure);

      if(global_slots <= 0)
      {
         LogCycle(
            "ENTRY",
            "ورود Pending لغو شد | ظرفیت کلی معاملات پر است");
         return;
      }

      const int pending_total = CountPendingOrders();
      const int max_pending =
         MathMax(
            TFLAB_PENDING_TRACK_LIMIT,
            MathMax(Inp_MaxOpenTrades, trades_requested));

      int pending_slots =
         MathMax(0, max_pending - pending_total);

      int orders_to_place =
         MathMin(
            quota_remaining,
            MathMin(global_slots, pending_slots));

      if(orders_to_place <= 0)
      {
         LogCycle(
            "SIGNAL_QUOTA",
            "فضای کافی برای Pendingهای سهمیه این Scenario وجود ندارد");
         return;
      }

      double real_tp_pending = 0.0;

      if(!ResolveRealTakeProfit(
         g_scenario.direction,
         g_scenario.entry_price,
         g_risk_result.position_volume,
         g_scenario.target_2,
         real_tp_pending))
      {
         LogCycle(
            "TP",
            "ساخت Pending لغو شد | حد سود نهایی قابل محاسبه نیست");
         return;
      }

      if(!CloseOppositePositionsAndVerify(
         g_scenario.direction))
      {
         LogCycle(
            "REVERSE",
            "Pending متوقف شد | معامله مخالف هنوز بسته نشده است");
         return;
      }

      int successful_pending = 0;

      for(int order_no = 0;
          order_no < orders_to_place;
          order_no++)
      {
         //--- ظرفیت در هر تکرار دوباره بررسی می‌شود.
         const int live_open = CountOpenPositions();
         const int live_pending = CountPendingOrders();
         const int live_global_exposure =
            Inp_Count_Pending_As_Risk
            ? CountTotalExposure()
            : live_open;

         if(live_global_exposure >= max_allowed ||
            live_pending >= max_pending)
            break;

         PendingOrderRecord record;
         PendingOrder_Init(record);

         if(!PendingOrder_Prepare(
            g_entry_plan,
            g_risk_result.position_volume,
            g_sl_plan.stop_price,
            real_tp_pending,
            now,
            record))
         {
            Print(
               "[MULTI PENDING] Prepare شکست خورد | شماره=",
               order_no + 1,
               " | Reason=",
               record.reason);
            continue;
         }

         string pending_comment =
            MakeSignalTradeComment(
               scenario_exposure_before + successful_pending + 1,
               trades_requested,
               "PENDING");

          bool pending_placed =
             PendingOrder_Place(
                record,
                pending_comment,
                now);

          // Retry فقط برای سفارش دوم: اگر سرور قیمت کاملاً تکراری را رد کند،
          // Entry دوم با یک فاصله بسیار کوچک و در همان سمت معتبر دوباره ارسال می‌شود.
          if(!pending_placed && order_no > 0)
          {
             const double point =
                SymbolInfoDouble(_Symbol, SYMBOL_POINT);

             const long stops_level =
                SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

             const double retry_step =
                MathMax(point,
                        (double)MathMax(1, stops_level) * point * 0.25);

             if(g_scenario.direction == SCENARIO_DIRECTION_BUY)
                record.price -= retry_step;
             else
                record.price += retry_step;

             record.price = NormalizeDouble(record.price, _Digits);
             record.state = PENDING_STATE_PLANNED;
             record.active = false;
             record.ticket = 0;

             Print("[MULTI PENDING] Retry معامله دوم | Entry جدید=",
                   DoubleToString(record.price,_Digits));

             pending_placed =
                PendingOrder_Place(
                   record,
                   pending_comment,
                   now);
          }

          if(!pending_placed)
          {
             Print(
                "[MULTI PENDING] Place شکست خورد | شماره=",
                order_no + 1,
                " | Reason=",
                record.reason,
                " | Broker=",
                record.broker_comment);
             continue;
          }

         successful_pending++;

         //--- رکورد اول در Legacy State، بقیه در Pool نگه‌داری می‌شوند.
         if(g_pending.ticket == 0 || !g_pending.active)
            g_pending = record;
         else
            PendingPool_Store(record);

         Print(
            "[MULTI PENDING] معامله ",
            successful_pending,
            "/",
            orders_to_place,
            " ثبت شد | Scenario=",
            g_scenario.id,
            " | Ticket=",
            record.ticket,
            " | Price=",
            DoubleToString(record.price, _Digits),
            " | Type=",
            EntryPlanTypeToPersian(record.plan_type));
      }

      SyncPrimaryPendingState();

      if(successful_pending > 0)
      {

         const int pending_exposure_after =
            CountScenarioExposure(g_scenario.id);
         const bool pending_quota_complete =
            (pending_exposure_after >= trades_requested);

         // فقط پس از تکمیل سهمیه، EntryPlan قفل می‌شود.
         if(pending_quota_complete)
            EntryPlan_MarkSent(g_entry_plan);

         Print(
            "[SIGNAL QUOTA] Pendingهای ثبت‌شده=",
            successful_pending,
            " | ExposureAfter=",
            pending_exposure_after,
            " | Scenario=",
            g_scenario.id,
            " | سهمیه هدف=",
            trades_requested,
            " | کامل=",
            (pending_quota_complete ? "YES" : "NO"));
      }

      return;
   }

   //=================================================================
   // Market
   //=================================================================
   if(g_entry_plan.type == ENTRY_PLAN_MARKET &&
      Inp_EnableTrading &&
      ((g_scenario.direction == SCENARIO_DIRECTION_BUY && Inp_AllowBuy) ||
       (g_scenario.direction == SCENARIO_DIRECTION_SELL && Inp_AllowSell)))
   {
      string market_reason2 = "";

      if(!IsMarketOpenForSymbol(market_reason2))
      {
         LogCycle(
            "MARKET_CLOSED",
            "ورود Market لغو شد | " + market_reason2);
         return;
      }

      if(!g_risk_result.approved ||
         g_risk_result.position_volume <= 0.0)
      {
         LogCycle(
            "RISK",
            "ورود Market به دلیل عدم تأیید ریسک لغو شد");
         return;
      }

      string market_spread_reason = "";

      if(!IsSpreadAcceptable(market_spread_reason))
      {
         LogCycle(
            "SPREAD",
            "ورود Market به دلیل اسپرد بالا لغو شد | " + market_spread_reason);
         return;
      }

      if(!IsRealTradingAllowed())
      {
         LogCycle(
            "EXECUTION",
            "شرایط معاملاتی غیرفعال");
         return;
      }

      bool candle_ok = true;
      string candle_reason = "";

      if(Inp_Require_Candle_Confirmation)
      {
         candle_ok =
            CandleConfirmation_ConfirmsDirection(
               _Symbol,
               Inp_TF_Setup_M5,
               Inp_PinBar_Min_Wick_Ratio,
               g_scenario.direction == SCENARIO_DIRECTION_BUY,
               candle_reason);

         if(!candle_ok)
         {
            LogCycle(
               "CANDLE_CONFIRM",
               "ورود Market به تعویق افتاد: " + candle_reason);

            if(Inp_Candle_Confirm_Timeout_Minutes > 0 &&
               g_scenario.created_time > 0)
            {
               int waited_minutes =
                  (int)((now - g_scenario.created_time) / 60);

               if(waited_minutes >= Inp_Candle_Confirm_Timeout_Minutes)
               {
                  candle_ok = true;

                  LogCycle(
                     "CANDLE_CONFIRM",
                     "مهلت انتظار کندل تأییدی تمام شد - ورود بدون تأیید کندلی انجام می‌شود");
               }
            }
         }
      }

      if(!candle_ok)
         return;

      if(!CloseOppositePositionsAndVerify(
         g_scenario.direction))
      {
         LogCycle(
            "REVERSE",
            "Market متوقف شد | معامله مخالف هنوز بسته نشده است");
         return;
      }

      const int requested =
         MathMax(1, Inp_Simultaneous_Trades);

      int current_scenario_exposure =
         CountScenarioExposure(g_scenario.id);

      int quota_remaining =
         MathMax(0, requested - current_scenario_exposure);

      if(quota_remaining <= 0)
      {
         LogCycle(
            "SIGNAL_QUOTA",
            "سهمیه Market این Scenario تکمیل شده است");
         return;
      }

      const int max_allowed = GetEffectiveMaxOpenTrades();
      int current_global_exposure =
         Inp_Count_Pending_As_Risk
         ? CountTotalExposure()
         : CountOpenPositions();

      int global_slots =
         MathMax(0, max_allowed - current_global_exposure);

      int trades_to_open =
         MathMin(quota_remaining, global_slots);

      if(trades_to_open <= 0)
      {
         LogCycle(
            "ENTRY",
            "Market متوقف شد | ظرفیت کلی معاملات پر است");
         return;
      }

      //--- TP بر اساس قیمت واقعی Market هر معامله محاسبه می‌شود.
      int successful_trades = 0;

      for(int trade_no = 0;
          trade_no < trades_to_open;
          trade_no++)
      {
         if((Inp_Count_Pending_As_Risk
             ? CountTotalExposure()
             : CountOpenPositions()) >= max_allowed)
            break;

         double live_bid = 0.0;
         double live_ask = 0.0;
         double live_current = 0.0;

         if(!GetCurrentPrices(
            live_bid,
            live_ask,
            live_current))
            break;

         string entry_revalidation_reason = "";

         if(!EntryGate_RevalidateBeforeExecution(
            g_scenario.direction,
            live_current,
            entry_revalidation_reason))
         {
            LogCycle(
               "ENTRY_REVALIDATION",
               "ورود Market در لحظه اجرا متوقف شد | " +
               entry_revalidation_reason);

            Print(
               "[ENTRY REVALIDATION] ورود متوقف شد | Scenario=",
               g_scenario.id,
               " | Direction=",
               ScenarioDirectionToPersian(g_scenario.direction),
               " | Price=",
               DoubleToString(live_current, _Digits),
               " | Reason=",
               entry_revalidation_reason);

            break;
         }

         ExecutionRequest req;
         ExecutionResult res;

         Execution_InitRequest(req);

         req.symbol = _Symbol;
         req.magic = Inp_MagicNumber;
         req.scenario_id = g_scenario.id;
         req.signal_id = g_scenario.id;
         req.order_type =
            (g_scenario.direction == SCENARIO_DIRECTION_BUY
             ? EXECUTION_BUY_MARKET
             : EXECUTION_SELL_MARKET);
         req.volume = g_risk_result.position_volume;
         req.price = live_current;
         req.stop_loss = g_sl_plan.stop_price;

         double system_tp_market =
            (g_scenario.target_2 > 0.0
             ? g_scenario.target_2
             : g_scenario.target_1);

         double real_tp_market = 0.0;

         if(!ResolveRealTakeProfit(
            g_scenario.direction,
            live_current,
            req.volume,
            system_tp_market,
            real_tp_market))
         {
            LogCycle(
               "TP",
               "ورود Market لغو شد | TP واقعی قابل محاسبه نیست");
            break;
         }

         req.take_profit = real_tp_market;
         req.comment =
            MakeSignalTradeComment(
               current_scenario_exposure + successful_trades + 1,
               requested,
               "MARKET");
         req.reason =
            "Strategy/Scenario/Setup فعال شدند | Multi-Signal Quota";

         if(Execution_SendMarket(req, res))
         {
            successful_trades++;

            Print(
               "[MULTI ENTRY] معامله ",
               successful_trades,
               "/",
               trades_to_open,
               " اجرا شد | Scenario=",
               g_scenario.id,
               " | Entry=",
               DoubleToString(live_current, _Digits),
               " | Volume=",
               DoubleToString(req.volume, 4));
         }
         else
         {
            Print(
               "[MULTI ENTRY] معامله ",
               trade_no + 1,
               " ناموفق بود | Reason=",
               res.reason);
            continue;
         }
      }

      if(successful_trades > 0)
      {
         const int market_exposure_after =
            CountScenarioExposure(g_scenario.id);
         const bool market_quota_complete =
            (market_exposure_after >= requested);

         // سناریو فقط پس از تکمیل سهمیه Executed می‌شود.
         if(market_quota_complete)
         {
            g_last_executed_scenario_id = g_scenario.id;
            EntryPlan_MarkSent(g_entry_plan);

            Scenario_Trigger(
               g_scenario,
               current_price,
               now,
               "ورود Market اجرا شد");

            Scenario_MarkExecuted(
               g_scenario,
               now,
               "معاملات Market اجرا شد | تعداد=" +
               IntegerToString(successful_trades));

            AIJournal_MarkExecuted(g_scenario.id);
         }

         Print(
            "[SIGNAL QUOTA] مجموع Market اجراشده=",
            successful_trades,
            " | ExposureAfter=",
            market_exposure_after,
            " | Scenario=",
            g_scenario.id,
            " | سهمیه هدف=",
            requested,
            " | کامل=",
            (market_quota_complete ? "YES" : "NO"));
      }
   }
}

//====================================================================
// محاسبه برد/باخت متوالی
//====================================================================
void CalculateRecentStreak(
   int &consecutive_losses,
   int &consecutive_wins)
{
   consecutive_losses = 0;
   consecutive_wins = 0;

   if(!HistorySelect(
      0,
      TimeCurrent()))
      return;

   int total =
      HistoryDealsTotal();

   if(total <= 0)
      return;

   double results[];
   datetime times[];

   ArrayResize(results, 0);
   ArrayResize(times, 0);

   for(int i = 0;
       i < total;
       i++)
   {
      ulong ticket =
         HistoryDealGetTicket(i);

      if(ticket == 0)
         continue;

      if(HistoryDealGetString(
            ticket,
            DEAL_SYMBOL) !=
         _Symbol)
         continue;

      if((ulong)HistoryDealGetInteger(
            ticket,
            DEAL_MAGIC) !=
         Inp_MagicNumber)
         continue;

      if((ENUM_DEAL_ENTRY)
         HistoryDealGetInteger(
            ticket,
            DEAL_ENTRY) !=
         DEAL_ENTRY_OUT)
         continue;

      double v =
         HistoryDealGetDouble(
            ticket,
            DEAL_PROFIT) +
         HistoryDealGetDouble(
            ticket,
            DEAL_SWAP) +
         HistoryDealGetDouble(
            ticket,
            DEAL_COMMISSION);

      int n =
         ArraySize(results);

      ArrayResize(
         results,
         n + 1);

      ArrayResize(
         times,
         n + 1);

      results[n] = v;

      times[n] =
         (datetime)
         HistoryDealGetInteger(
            ticket,
            DEAL_TIME);
   }

   int count =
      ArraySize(results);

   if(count == 0)
      return;

   for(int i = 0;
       i < count - 1;
       i++)
   {
      for(int j = 0;
          j < count - 1 - i;
          j++)
      {
         if(times[j] >
            times[j + 1])
         {
            datetime tt =
               times[j];

            times[j] =
               times[j + 1];

            times[j + 1] =
               tt;

            double rr =
               results[j];

            results[j] =
               results[j + 1];

            results[j + 1] =
               rr;
         }
      }
   }

   bool streak_is_loss = false;
   bool streak_started = false;
   int streak_count = 0;

   for(int i = count - 1;
       i >= 0;
       i--)
   {
      if(results[i] == 0.0)
         continue;

      bool is_loss =
         (results[i] < 0.0);

      if(!streak_started)
      {
         streak_started = true;
         streak_is_loss =
            is_loss;

         streak_count = 1;
      }
      else
      if(is_loss ==
         streak_is_loss)
      {
         streak_count++;
      }
      else
      {
         break;
      }
   }

   if(streak_is_loss)
      consecutive_losses =
         streak_count;
   else
      consecutive_wins =
         streak_count;
}

//====================================================================
// به‌روزرسانی ریسک
//====================================================================
void UpdateRisk()
{
   Risk_InitLimits(
      g_risk_limits);

   g_risk_limits.risk_percent_per_trade =
      Inp_Risk_Per_Trade_Percent;

   g_risk_limits.max_risk_percent_per_trade =
      Inp_Max_Risk_Per_Trade_Percent;

   g_risk_limits.min_financial_risk_percent =
      0.1;

   g_risk_limits.max_financial_risk_percent =
      50.0;

   g_risk_limits.min_trade_probability_percent =
      65.0;

   g_risk_limits.probability_at_min_financial_risk =
      65.0;

   g_risk_limits.probability_at_max_financial_risk =
      85.0;

   g_risk_limits.max_total_financial_risk_percent =
      30.0;

   g_risk_limits.max_directional_financial_risk_percent =
      20.0;

   g_risk_limits.max_total_open_risk_percent =
      Inp_Max_Portfolio_Risk_Percent;

   g_risk_limits.max_directional_risk_percent =
      Inp_Max_Directional_Risk_Percent;

   g_risk_limits.min_rr =
      Inp_Min_RR;

   g_risk_limits.max_sl_distance_points =
      Inp_Max_SL_Distance_Points;

   g_risk_limits.min_sl_distance_points =
      Inp_Min_SL_Distance_Points;

   g_risk_limits.daily_loss_limit_percent =
      Inp_Daily_Loss_Limit_Percent;

   g_risk_limits.max_drawdown_percent =
      Inp_Max_Drawdown_Percent;

   g_risk_limits.block_after_daily_loss =
      Inp_Block_After_Daily_Loss;

   g_risk_limits.block_after_drawdown =
      Inp_Block_After_Drawdown;

   g_risk_limits.ignore_capital_size_for_min_volume =
      Inp_Ignore_Capital_Size_For_Min_Volume;

   g_risk_limits.max_consecutive_losses =
      Inp_Max_Consecutive_Losses;

   g_risk_limits.use_fixed_lot =
      Inp_Use_Fixed_Lot;

   g_risk_limits.fixed_lot_size =
      Inp_Fixed_Lot_Size;

   g_risk_limits.enable_adaptive_risk =
      Inp_Enable_Adaptive_Risk;

   g_risk_limits.adaptive_reduction_per_loss_percent =
      Inp_Adaptive_Reduction_Per_Loss_Percent;

   g_risk_limits.adaptive_increase_per_win_percent =
      Inp_Adaptive_Increase_Per_Win_Percent;

   g_risk_limits.adaptive_min_multiplier =
      Inp_Adaptive_Risk_Min_Multiplier;

   g_risk_limits.adaptive_max_multiplier =
      Inp_Adaptive_Risk_Max_Multiplier;

   Risk_UpdateEquityState(
      g_risk_account,
      AccountInfoDouble(
         ACCOUNT_BALANCE),
      AccountInfoDouble(
         ACCOUNT_EQUITY));

   Risk_CalculateOpenRiskFromPositions(
      _Symbol,
      Inp_MagicNumber,
      g_risk_account);

   Risk_UpdateDailyLoss(
      g_risk_account,
      MathMax(
         0.0,
         -TodayClosedProfit()));

   int real_consecutive_losses = 0;
   int real_consecutive_wins = 0;

   CalculateRecentStreak(
      real_consecutive_losses,
      real_consecutive_wins);

   Risk_SetConsecutiveLosses(
      g_risk_account,
      real_consecutive_losses);

   Risk_SetConsecutiveWins(
      g_risk_account,
      real_consecutive_wins);

   if(g_scenario.id == 0 ||
      !Scenario_IsValid(
         g_scenario) ||
      g_sl_plan.stop_price <= 0.0 ||
      g_scenario.target_1 <= 0.0)
   {
      Risk_InitResult(
         g_risk_result);

      return;
   }

   RiskTradeInput risk_input;

   risk_input.is_buy =
      (g_scenario.direction ==
       SCENARIO_DIRECTION_BUY);

   risk_input.entry_price =
      g_scenario.entry_price;

   risk_input.sl_price =
      g_sl_plan.stop_price;

   risk_input.target_price =
      (g_scenario.target_2 > 0.0
       ?
        g_scenario.target_2
       :
        g_scenario.target_1);

   double effective_risk_percent =
      Inp_Risk_Per_Trade_Percent;

   if(g_is_transition_mode)
   {
      effective_risk_percent *=
         0.50;

      Print(
         "[RISK] حالت گذار: ریسک از ",
         DoubleToString(
            Inp_Risk_Per_Trade_Percent,
            2),
         "% به ",
         DoubleToString(
            effective_risk_percent,
            2),
         "% کاهش یافت");
   }

   risk_input.risk_percent_requested =
      effective_risk_percent;

   risk_input.estimated_cost_money =
      0.0;

   Risk_EvaluateTrade(
      _Symbol,
      g_risk_limits,
      g_risk_account,
      risk_input,
      _Point,
      g_risk_result);

   g_risk_block_reason = "";

   if(!g_risk_result.approved)
   {
      if(g_risk_limits.max_consecutive_losses > 0 &&
         g_risk_account.consecutive_losses >=
         g_risk_limits.max_consecutive_losses)
      {
         g_risk_block_reason =
            "ضرر متوالی (" +
            IntegerToString(
               g_risk_account.consecutive_losses) +
            "/" +
            IntegerToString(
               g_risk_limits.max_consecutive_losses) +
            ")";
      }
      else
      if(g_risk_limits.block_after_daily_loss &&
         g_risk_limits.daily_loss_limit_percent > 0.0 &&
         g_risk_account.daily_loss_percent >=
         g_risk_limits.daily_loss_limit_percent)
      {
         g_risk_block_reason =
            "ضرر روزانه (" +
            DoubleToString(
               g_risk_account.daily_loss_percent,
               1) +
            "%)";
      }
      else
      if(g_risk_limits.block_after_drawdown &&
         g_risk_limits.max_drawdown_percent > 0.0 &&
         g_risk_account.peak_equity > 0.0)
      {
         double drawdown_percent =
            ((g_risk_account.peak_equity -
              g_risk_account.equity) /
             g_risk_account.peak_equity) *
            100.0;

         if(drawdown_percent >=
            g_risk_limits.max_drawdown_percent)
         {
            g_risk_block_reason =
               "افت سرمایه (" +
               DoubleToString(
                  drawdown_percent,
                  1) +
               "%)";
         }
      }

      if(g_risk_block_reason == "")
      {
         double directional_risk = 0.0;

         if(risk_input.is_buy)
         {
            directional_risk =
               Risk_MoneyToPercent(
                  g_risk_account.buy_risk_money,
                  g_risk_account.equity);
         }
         else
         {
            directional_risk =
               Risk_MoneyToPercent(
                  g_risk_account.sell_risk_money,
                  g_risk_account.equity);
         }

         if(directional_risk +
            g_risk_result.risk_percent >
            g_risk_limits.max_directional_risk_percent)
         {
            g_risk_block_reason =
               "ریسک هم‌جهت (" +
               DoubleToString(
                  directional_risk, 1) +
               "%+" +
               DoubleToString(
                  g_risk_result.risk_percent,
                  1) +
               "%>" +
               DoubleToString(
                  g_risk_limits.max_directional_risk_percent,
                  1) +
               "%)";
         }
         else
         {
            g_risk_block_reason =
               g_risk_result.reason;

            if(g_risk_block_reason == "")
               g_risk_block_reason =
                  "ریسک (نامشخص)";
         }
      }
   }
}

//====================================================================
// حجم اولیه پوزیشن
//====================================================================
double GetPositionInitialVolume(
   const ulong position_id,
   const double fallback)
{
   if(position_id == 0 ||
      !HistorySelectByPosition(
         position_id))
      return fallback;

   double volume = 0.0;

   uint total =
      (uint)HistoryDealsTotal();

   for(uint i = 0;
       i < total;
       i++)
   {
      const ulong deal =
         HistoryDealGetTicket(i);

      if(deal == 0)
         continue;

      if(HistoryDealGetInteger(
            deal,
            DEAL_ENTRY) ==
         DEAL_ENTRY_IN)
      {
         volume +=
            HistoryDealGetDouble(
               deal,
               DEAL_VOLUME);
      }
   }

   return
      (volume > 0.0
       ? volume
       : fallback);
}

//====================================================================
// ابزارهای مدیریت دقیقه‌ای
//====================================================================
int DynamicTP_FindState(const ulong position_id)
{
   for(int i=0;i<ArraySize(g_dynamic_tp_tracker);i++)
      if(g_dynamic_tp_tracker[i].position_id==position_id)
         return i;
   return -1;
}

int DynamicTP_GetOrCreateState(const ulong position_id,
                               const ulong ticket,
                               const double entry_price,
                               const double current_tp)
{
   if(position_id==0)
      return -1;

   int idx=DynamicTP_FindState(position_id);
   if(idx>=0)
   {
      g_dynamic_tp_tracker[idx].ticket=ticket;
      g_dynamic_tp_tracker[idx].last_seen=TimeCurrent();
      return idx;
   }

   if(current_tp<=0.0)
      return -1;

   int n=ArraySize(g_dynamic_tp_tracker);
   ArrayResize(g_dynamic_tp_tracker,n+1);
   g_dynamic_tp_tracker[n].position_id=position_id;
   g_dynamic_tp_tracker[n].ticket=ticket;
   g_dynamic_tp_tracker[n].entry_price=entry_price;
   g_dynamic_tp_tracker[n].initial_tp=current_tp;
   g_dynamic_tp_tracker[n].first_seen=TimeCurrent();
   g_dynamic_tp_tracker[n].last_seen=TimeCurrent();

   return n;
}

void DynamicTP_Cleanup()
{
   datetime now=TimeCurrent();
   for(int i=ArraySize(g_dynamic_tp_tracker)-1;i>=0;i--)
   {
      bool found=false;
      for(int j=0;j<PositionsTotal();j++)
      {
         ulong ticket=PositionGetTicket(j);
         if(ticket==0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
            continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC)!=Inp_MagicNumber)
            continue;
         if((ulong)PositionGetInteger(POSITION_IDENTIFIER)==g_dynamic_tp_tracker[i].position_id)
         { found=true; break; }
      }
      if(!found && (now-g_dynamic_tp_tracker[i].last_seen)>120)
      {
         int last=ArraySize(g_dynamic_tp_tracker)-1;
         if(i!=last)
            g_dynamic_tp_tracker[i]=g_dynamic_tp_tracker[last];
         ArrayResize(g_dynamic_tp_tracker,last);
      }
   }
}

double ClampScore(const double value)
{
   return MathMax(0.0,MathMin(100.0,value));
}

void CalculateMinuteScores()
{
   g_minute_monitor.valid=false;
   g_minute_monitor.analysis_time=TimeCurrent();
   MarketRegime_Reset(g_minute_monitor.m1_regime);
   MarketTruth_Reset(g_minute_monitor.m5_truth);
   g_minute_monitor.buy_continuation=50.0;
   g_minute_monitor.sell_continuation=50.0;
   g_minute_monitor.buy_reversal=0.0;
   g_minute_monitor.sell_reversal=0.0;

   bool regime_ok=false;
   if(Inp_Use_M1_Monitor)
      regime_ok=MarketRegime_Analyze(_Symbol,Inp_TF_Monitor_M1,g_minute_monitor.m1_regime);

   bool truth_ok=false;
   if(Inp_Use_Market_Truth)
      truth_ok=MarketTruth_Analyze(_Symbol,Inp_TF_Setup_M5,Inp_Market_Truth_Lookback,g_minute_monitor.m5_truth);

   if(!regime_ok && !truth_ok)
      return;

   double buy=50.0;
   double sell=50.0;

   if(regime_ok && g_minute_monitor.m1_regime.valid)
   {
      if(g_minute_monitor.m1_regime.regime==MARKET_REGIME_UPTREND)
      {
         buy += MathMin(30.0,g_minute_monitor.m1_regime.confidence*0.35);
         sell -= MathMin(35.0,g_minute_monitor.m1_regime.confidence*0.35);
      }
      else if(g_minute_monitor.m1_regime.regime==MARKET_REGIME_DOWNTREND)
      {
         sell += MathMin(30.0,g_minute_monitor.m1_regime.confidence*0.35);
         buy -= MathMin(35.0,g_minute_monitor.m1_regime.confidence*0.35);
      }
      else if(g_minute_monitor.m1_regime.regime==MARKET_REGIME_TRANSITION)
      {
         buy -= 5.0;
         sell -= 5.0;
      }
   }

   if(truth_ok && g_minute_monitor.m5_truth.valid)
   {
      if(g_minute_monitor.m5_truth.direction==MARKET_TRUTH_BUY)
      {
         buy += 18.0;
         sell -= 18.0;
      }
      else if(g_minute_monitor.m5_truth.direction==MARKET_TRUTH_SELL)
      {
         sell += 18.0;
         buy -= 18.0;
      }

      if(g_minute_monitor.m5_truth.reversal_candidate)
      {
         if(g_minute_monitor.m5_truth.direction==MARKET_TRUTH_BUY)
            sell += 10.0;
         else if(g_minute_monitor.m5_truth.direction==MARKET_TRUTH_SELL)
            buy += 10.0;
      }
   }

   g_minute_monitor.buy_continuation=ClampScore(buy);
   g_minute_monitor.sell_continuation=ClampScore(sell);

   g_minute_monitor.buy_reversal=ClampScore(100.0-buy);
   g_minute_monitor.sell_reversal=ClampScore(100.0-sell);

   // اگر M30 اصلی سناریو جهت مخالف معامله را تأیید کرده باشد، امتیاز برگشت قوی‌تر می‌شود.
   if(g_regime.valid)
   {
      if(g_regime.regime==MARKET_REGIME_DOWNTREND)
         g_minute_monitor.buy_reversal=ClampScore(g_minute_monitor.buy_reversal+20.0*(g_regime.confidence/100.0));
      if(g_regime.regime==MARKET_REGIME_UPTREND)
         g_minute_monitor.sell_reversal=ClampScore(g_minute_monitor.sell_reversal+20.0*(g_regime.confidence/100.0));
   }

   g_minute_monitor.valid=true;
}

bool EnsureMinuteMarketMonitorFresh()
{
   if(!Inp_Use_M1_Monitor && !Inp_Use_Market_Truth)
      return false;

   if(!g_minute_monitor.valid ||
      (TimeCurrent()-g_minute_monitor.analysis_time)>=MathMax(1,Inp_Monitor_Update_Seconds))
      CalculateMinuteScores();

   return g_minute_monitor.valid;
}

double MinuteContinuationScore(const bool is_buy)
{
   return is_buy ? g_minute_monitor.buy_continuation : g_minute_monitor.sell_continuation;
}

double MinuteReversalScore(const bool is_buy)
{
   return is_buy ? g_minute_monitor.buy_reversal : g_minute_monitor.sell_reversal;
}

bool NewScenarioConfirmsReverseFromPosition(const bool old_is_buy)
{
   if(g_scenario.id<=0) return false;
   if(g_scenario.direction==SCENARIO_DIRECTION_NONE) return false;

   bool new_is_buy=(g_scenario.direction==SCENARIO_DIRECTION_BUY);
   if(old_is_buy==new_is_buy)
      return false;

   if(!EnsureMinuteMarketMonitorFresh())
      return false;

   double score=MinuteReversalScore(old_is_buy);

   // سناریوی جدید باید واقعاً خلاف معامله موجود باشد و امتیاز برگشت به آستانه برسد.
   if(score < Inp_Reversal_Exit_Min_Confidence)
      return false;

   bool truth_support=true;
   if(g_minute_monitor.m5_truth.valid)
   {
      if(old_is_buy && g_minute_monitor.m5_truth.direction!=MARKET_TRUTH_SELL)
         truth_support=false;
      if(!old_is_buy && g_minute_monitor.m5_truth.direction!=MARKET_TRUTH_BUY)
         truth_support=false;
   }

   return truth_support;
}

bool CloseAllPositionsOppositeToScenario(const ENUM_SCENARIO_DIRECTION new_direction)
{
   bool new_is_buy=(new_direction==SCENARIO_DIRECTION_BUY);
   bool all_ok=true;
   int closed=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=Inp_MagicNumber)
         continue;

      bool pos_is_buy=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      if(pos_is_buy==new_is_buy)
         continue;

      double volume=PositionGetDouble(POSITION_VOLUME);
      if(volume<=0.0)
         continue;

      if(IsRealTradingAllowed() &&
         ClosePositionVolume(ticket,_Symbol,pos_is_buy,volume,"TFlab Confirmed Reversal Close"))
      {
         closed++;
         Print("[REVERSAL CLOSE] تمام معاملات جهت قبلی بسته شد | Ticket=",ticket," | NewDirection=",ScenarioDirectionToPersian(new_direction));
      }
      else
      {
         all_ok=false;
      }
   }

   Print("[REVERSAL CLOSE] نتیجه | Closed=",closed," | AllOK=",(all_ok?"YES":"NO"));
   return all_ok && CountOpenPositionsByDirection(new_is_buy ? SCENARIO_DIRECTION_SELL : SCENARIO_DIRECTION_BUY)==0;
}

bool HasOppositeOpenPositionForScenarioDirection(const ENUM_SCENARIO_DIRECTION new_direction)
{
   bool new_is_buy=(new_direction==SCENARIO_DIRECTION_BUY);
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=Inp_MagicNumber) continue;
      bool pos_is_buy=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      if(pos_is_buy!=new_is_buy) return true;
   }
   return false;
}

bool CloseOldSideBeforeReverseEntry()
{
   if(!Inp_Enable_Confirmed_Reversal_Close)
      return true;

   if(g_scenario.id<=0 || !Scenario_IsValid(g_scenario))
      return true;

   // فقط وقتی ربات واقعاً برنامه ورود جدید دارد، معاملات جهت قبلی بسته می‌شوند.
   if(!g_entry_plan.executable ||
      g_entry_plan.direction!=g_scenario.direction)
      return true;

   bool new_is_buy=(g_scenario.direction==SCENARIO_DIRECTION_BUY);
   bool has_old=false;

   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=Inp_MagicNumber) continue;
      bool pos_is_buy=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      if(pos_is_buy!=new_is_buy) { has_old=true; break; }
   }

   if(!has_old)
      return true;

   if(!EnsureMinuteMarketMonitorFresh())
      return false;

   bool confirmed_for_at_least_one=false;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=Inp_MagicNumber) continue;
      bool pos_is_buy=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      if(pos_is_buy==new_is_buy) continue;
      if(NewScenarioConfirmsReverseFromPosition(pos_is_buy))
      { confirmed_for_at_least_one=true; break; }
   }

   if(!confirmed_for_at_least_one)
   {
      LogCycle("REVERSE","سیگنال معکوس وجود دارد اما اطمینان برگشت هنوز به حد لازم نرسیده است");
      return false;
   }

   return CloseAllPositionsOppositeToScenario(g_scenario.direction);
}

double DynamicTP_ComputeNewTarget(const bool is_buy,const double entry,const double initial_tp,const double score)
{
   if(entry<=0.0 || initial_tp<=0.0)
      return 0.0;

   double initial_distance=MathAbs(initial_tp-entry);
   if(initial_distance<=0.0)
      return 0.0;

   double ratio=1.0;
   if(score < Inp_Dynamic_TP_Min_Confidence)
      ratio=0.60;
   else if(score < 75.0)
      ratio=0.75;
   else
      ratio=1.0;

   double min_ratio=MathMax(0.05,MathMin(1.0,Inp_Dynamic_TP_Min_Remaining_Ratio));
   ratio=MathMax(min_ratio,MathMin(1.0,ratio));

   double target=is_buy
      ? entry+initial_distance*ratio
      : entry-initial_distance*ratio;

   return NormalizeDouble(target,_Digits);
}

bool DynamicTP_IsBrokerValid(const bool is_buy,const double target)
{
   double bid=0.0,ask=0.0,mid=0.0;
   if(!GetCurrentPrices(bid,ask,mid)) return false;

   long stops=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freeze=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   double min_dist=(double)MathMax(stops,freeze)*_Point;
   if(min_dist<2.0*_Point) min_dist=2.0*_Point;

   if(is_buy)
      return target > ask+min_dist;
   return target < bid-min_dist;
}

//====================================================================
// محافظت از سود قبل از برگشت
//====================================================================
bool TryProfitProtection(const ulong ticket,
                         const bool is_buy,
                         const double entry,
                         const double current,
                         const double current_sl,
                         const double original_sl)
{
   if(!Inp_Enable_Profit_Protection)
      return false;

   if(ticket == 0 || entry <= 0.0 || current <= 0.0)
      return false;

   double atr = GetCurrentATRPrice();
   if(atr <= 0.0)
      return false;

   double favorable_move = is_buy
      ? MathMax(0.0, current - entry)
      : MathMax(0.0, entry - current);

   double risk_distance = original_sl > 0.0
      ? MathAbs(entry - original_sl)
      : MathAbs(entry - current_sl);

   if(risk_distance <= 0.0)
      risk_distance = atr;

   double trigger = MathMax(
      atr * Inp_Profit_Protection_ATR_Trigger,
      risk_distance * Inp_Profit_Protection_Risk_Fraction);

   if(favorable_move < trigger)
      return false;

   double lock_distance = MathMax(
      atr * Inp_Profit_Protection_Lock_ATR,
      risk_distance * Inp_Profit_Protection_Lock_Risk_Fraction);

   double new_sl = is_buy
      ? entry + lock_distance
      : entry - lock_distance;

   new_sl = NormalizeDouble(new_sl, _Digits);

   bool improvement = is_buy
      ? (current_sl <= 0.0 || new_sl > current_sl + _Point)
      : (current_sl <= 0.0 || new_sl < current_sl - _Point);

   if(!improvement)
      return false;

   if(!SL_IsBrokerValidForPosition(ticket, _Symbol, new_sl))
      return false;

   if(!IsRealTradingAllowed())
      return false;

   double current_tp = PositionGetDouble(POSITION_TP);
   if(!SL_ModifyPositionSLTP(ticket, _Symbol, new_sl, current_tp))
      return false;

   Print("[PROFIT PROTECTION] حد ضرر به ناحیه سود منتقل شد",
         " | Ticket=", ticket,
         " | FavorableMove=", DoubleToString(favorable_move, _Digits),
         " | Trigger=", DoubleToString(trigger, _Digits),
         " | NewSL=", DoubleToString(new_sl, _Digits));

   return true;
}

//====================================================================
// کنترل زیان شناور و جلوگیری از مصرف کامل SL بزرگ
//====================================================================
bool TryAdaptiveLossProtection(const ulong ticket,
                                const bool is_buy,
                                const double entry,
                                const double current,
                                const double current_sl,
                                const double original_sl,
                                const double continuation,
                                const double reversal)
{
   if(!Inp_Enable_Adaptive_Loss_Protection)
      return false;

   if(ticket == 0 || entry <= 0.0 || current <= 0.0)
      return false;

   double atr = GetCurrentATRPrice();
   if(atr <= 0.0)
      return false;

   double adverse_move = is_buy
      ? MathMax(0.0, entry - current)
      : MathMax(0.0, current - entry);

   if(adverse_move <= 0.0)
      return false;

   double risk_distance = original_sl > 0.0
      ? MathAbs(entry - original_sl)
      : MathAbs(entry - current_sl);

   if(risk_distance <= 0.0)
      risk_distance = atr;

   double soft_trigger = MathMax(
      atr * Inp_Adverse_Move_ATR_Trigger,
      risk_distance * Inp_Adverse_Move_Risk_Fraction);

   double hard_trigger = MathMax(
      atr * Inp_Adverse_Move_Hard_ATR_Trigger,
      risk_distance * Inp_Adverse_Move_Hard_Risk_Fraction);

   bool truth_reverse = false;
   if(g_minute_monitor.m5_truth.valid)
   {
      truth_reverse =
         (is_buy && g_minute_monitor.m5_truth.direction == MARKET_TRUTH_SELL) ||
         (!is_buy && g_minute_monitor.m5_truth.direction == MARKET_TRUTH_BUY);
   }

   bool soft_confirmed =
      truth_reverse ||
      (reversal >= Inp_Adverse_Move_Min_Reversal_Confidence &&
       continuation <= Inp_Adverse_Move_Max_Continuation);

   bool should_close =
      (adverse_move >= hard_trigger) ||
      (adverse_move >= soft_trigger && soft_confirmed);

   if(!should_close || !IsRealTradingAllowed())
      return false;

   double volume = PositionGetDouble(POSITION_VOLUME);
   if(volume <= 0.0)
      return false;

   if(ClosePositionVolume(ticket, _Symbol, is_buy, volume,
                          "TFlab Adaptive Loss Protection"))
   {
      Print("[ADAPTIVE LOSS] معامله قبل از مصرف SL بزرگ بسته شد",
            " | Ticket=", ticket,
            " | AdverseMove=", DoubleToString(adverse_move, _Digits),
            " | Soft=", DoubleToString(soft_trigger, _Digits),
            " | Hard=", DoubleToString(hard_trigger, _Digits),
            " | Continuation=", DoubleToString(continuation, 1),
            " | Reversal=", DoubleToString(reversal, 1),
            " | TruthReverse=", (truth_reverse ? "YES" : "NO"));
      return true;
   }

   return false;
}

bool TryProtectiveReversalExit(const ulong ticket,
                               const bool is_buy,
                               const double entry,
                               const double current,
                               const double continuation,
                               const double reversal)
{
   if(!Inp_Enable_Reversal_Exit)
      return false;

   if(ticket == 0 || entry <= 0.0 || current <= 0.0)
      return false;

   if(reversal < Inp_Reversal_Exit_Min_Confidence)
      return false;

   // برگشت باید از ادامه روند برتری مشخص داشته باشد.
   if(reversal < continuation + Inp_Reversal_Exit_Min_Score_Lead)
      return false;

   if(!g_minute_monitor.m5_truth.valid)
      return false;

   bool truth_reverse =
      (is_buy && g_minute_monitor.m5_truth.direction == MARKET_TRUTH_SELL) ||
      (!is_buy && g_minute_monitor.m5_truth.direction == MARKET_TRUTH_BUY);

   if(!truth_reverse)
      return false;

   // در برگشت خیلی قوی، منتظر رسیدن معامله به زیان نمی‌مانیم.
   // در حالت ضعیف‌تر، حداقل حرکت خلاف جهت لازم است.
   double move_against = is_buy
      ? MathMax(0.0, entry - current)
      : MathMax(0.0, current - entry);

   // min_ATR در این مسیر، قدرت حرکت مخالف بازار را می‌سنجد؛
   // برای تشخیص فشار خلاف جهت معامله از move_atr_multiple استفاده می‌کنیم.
   bool strong_reversal =
      (reversal >= MathMax(Inp_Reversal_Exit_Min_Confidence, 85.0) &&
       g_minute_monitor.m5_truth.move_atr_multiple >=
         MathMax(0.50, Inp_Reversal_Exit_Min_ATR_Multiple));

   double point_threshold =
      MathMax(0.0, Inp_Reversal_Exit_Min_Points) * _Point;

   double atr_threshold =
      GetCurrentATRPrice() * MathMax(0.0, Inp_Reversal_Exit_Min_ATR_Multiple);

   double required_move = MathMax(point_threshold, atr_threshold);
   bool moved_against = (move_against >= required_move);

   if(!strong_reversal && !moved_against)
      return false;

   if(!IsRealTradingAllowed())
      return false;

   double volume = PositionGetDouble(POSITION_VOLUME);
   if(volume <= 0.0)
      return false;

   if(ClosePositionVolume(ticket, _Symbol, is_buy, volume,
                          "TFlab Protective Reversal Exit"))
   {
      Print("[PROTECTIVE REVERSAL] معامله بسته شد",
            " | Ticket=", ticket,
            " | Reversal=", DoubleToString(reversal, 1),
            " | Continuation=", DoubleToString(continuation, 1),
            " | Truth=", MarketTruth_DirectionToString(g_minute_monitor.m5_truth.direction),
            " | TruthMoveATR=", DoubleToString(g_minute_monitor.m5_truth.move_atr_multiple, 2),
            " | MoveAgainst=", DoubleToString(move_against, _Digits));
      return true;
   }

   return false;
}

void ProcessMinuteTradeManagement()
{
   if(!Inp_Enable_Trade_Management)
      return;

   if(!EnsureMinuteMarketMonitorFresh())
      return;

   DynamicTP_Cleanup();
   datetime now=TimeCurrent();

   //--- ثبت وضعیت دقیقه‌ای و Dynamic TP
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC)!=Inp_MagicNumber) continue;

      bool is_buy=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      ulong position_id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double current=is_buy ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=PositionGetDouble(POSITION_SL);
      double current_tp=PositionGetDouble(POSITION_TP);
      double profit=PositionGetDouble(POSITION_PROFIT);
      double continuation=MinuteContinuationScore(is_buy);
      double reversal=MinuteReversalScore(is_buy);
      string position_comment=PositionGetString(POSITION_COMMENT);
      double original_sl=ExtractOriginalScenarioSL(position_comment);
      if(original_sl <= 0.0)
         original_sl = sl;
      string action="NONE";
      string reason="بررسی دقیقه‌ای";

      int idx=DynamicTP_GetOrCreateState(position_id,ticket,entry,current_tp);

      if(TryAdaptiveLossProtection(ticket,is_buy,entry,current,sl,original_sl,continuation,reversal))
      {
         BacktestReport_WriteManagementSnapshot(g_backtest_report,now,position_id,ticket,is_buy?"BUY":"SELL",entry,current,sl,current_tp,profit,continuation,reversal,"CLOSED_ADAPTIVE_LOSS","حرکت خلاف جهت از حد مجاز عبور کرد");
         continue;
      }

      if(TryProtectiveReversalExit(ticket,is_buy,entry,current,continuation,reversal))
      {
         BacktestReport_WriteManagementSnapshot(g_backtest_report,now,position_id,ticket,is_buy?"BUY":"SELL",entry,current,sl,current_tp,profit,continuation,reversal,"CLOSED_REVERSAL_PROTECT","برگشت قوی بازار علیه معامله تأیید شد");
         continue;
      }

      if(TryProfitProtection(ticket,is_buy,entry,current,sl,original_sl))
      {
         if(PositionSelectByTicket(ticket))
            sl=PositionGetDouble(POSITION_SL);
         action="PROFIT_LOCK";
         reason="حرکت مطلوب کافی شد و بخشی از سود قفل شد";
      }

      if(Inp_Enable_Dynamic_TP && idx>=0)
      {
         double initial_tp=g_dynamic_tp_tracker[idx].initial_tp;
         double desired=DynamicTP_ComputeNewTarget(is_buy,entry,initial_tp,continuation);

         bool closer=(is_buy ? (desired<current_tp) : (desired>current_tp));
         double move_points=MathAbs(current_tp-desired)/_Point;

         if(closer && move_points>=MathMax(1.0,Inp_Dynamic_TP_Min_Move_Points))
         {
            if(DynamicTP_IsBrokerValid(is_buy,desired))
            {
               if(IsRealTradingAllowed() && SL_ModifyPositionSLTP(ticket,_Symbol,sl,desired))
               {
                  action="TP_MOVED";
                  reason="کاهش قدرت ادامه روند؛ TP فقط به سمت Entry نزدیک شد";
                  g_dynamic_tp_tracker[idx].last_seen=now;
                  current_tp=desired;
               }
            }
            else
            {
               action="TP_SKIP";
               reason="TP جدید از حداقل فاصله مجاز بروکر نزدیک‌تر است";
            }
         }

         // اگر ضعف شدید شده و قیمت از TP پیشنهادی عبور کرده، برای جلوگیری از تبدیل سود به زیان خارج می‌شویم.
         if(continuation<=Inp_Dynamic_TP_Close_Confidence)
         {
            bool passed=is_buy ? (current>=desired && desired>entry) : (current<=desired && desired<entry);
            if(passed && IsRealTradingAllowed())
            {
               if(ClosePositionVolume(ticket,_Symbol,is_buy,PositionGetDouble(POSITION_VOLUME),"TFlab Dynamic TP Exit"))
               {
                  action="CLOSED_DYNAMIC_TP";
                  reason="قدرت ادامه روند پایین و قیمت به محدوده TP محافظتی رسید";
                  BacktestReport_WriteManagementSnapshot(g_backtest_report,now,position_id,ticket,is_buy?"BUY":"SELL",entry,current,sl,current_tp,profit,continuation,reversal,action,reason);
                  continue;
               }
            }
         }
      }

      BacktestReport_WriteManagementSnapshot(g_backtest_report,now,position_id,ticket,is_buy?"BUY":"SELL",entry,current,sl,current_tp,profit,continuation,reversal,action,reason);
   }

   //--- قبل از ورود معکوس: فقط اگر برگشت تأیید شده، تمام معاملات جهت قدیم بسته شوند.
   if(g_scenario.id>0 && Scenario_IsValid(g_scenario))
      CloseOldSideBeforeReverseEntry();
}

//====================================================================
// رصد معاملات باز
//====================================================================
void MonitorOpenTrades()
{
   if(!Inp_Enable_Trade_Management)
      return;

   const datetime now =
      TimeCurrent();

   for(int i =
      PositionsTotal() - 1;
      i >= 0;
      i--)
   {
      const ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0 ||
         !PositionSelectByTicket(
            ticket))
         continue;

      if(PositionGetString(
            POSITION_SYMBOL) !=
         _Symbol)
         continue;

      if((ulong)PositionGetInteger(
            POSITION_MAGIC) !=
         Inp_MagicNumber)
         continue;

      bool is_buy =
         (PositionGetInteger(
            POSITION_TYPE) ==
          POSITION_TYPE_BUY);

      double current_price =
         is_buy
         ?
            SymbolInfoDouble(
               _Symbol,
               SYMBOL_BID)
         :
            SymbolInfoDouble(
               _Symbol,
               SYMBOL_ASK);

      double volume =
         PositionGetDouble(
            POSITION_VOLUME);

      datetime open_time =
         (datetime)
         PositionGetInteger(
            POSITION_TIME);

      ulong position_id =
         (ulong)
         PositionGetInteger(
            POSITION_IDENTIFIER);

      double tp1 = PositionGetDouble(POSITION_TP);
      double tp2 = 0.0;
      string position_comment = PositionGetString(POSITION_COMMENT);
      double original_tp1 = 0.0;
      double original_tp2 = 0.0;
      ExtractOriginalScenarioTargets(position_comment, original_tp1, original_tp2);

      // TPهای اصلی سناریو باید مستقل از Dynamic TP حفظ شوند؛
      // در غیر این صورت آستانه Stage دائماً جابه‌جا می‌شود.
      if(original_tp1 > 0.0)
         tp1 = original_tp1;
      if(original_tp2 > 0.0)
         tp2 = original_tp2;

      //=============================================================
      // خروج بازگشت روند
      //=============================================================
      // خروج به علت برگشت فقط در مدیریت دقیقه‌ای و همزمان با
      // تأیید قصد ورود معکوس انجام می‌شود؛ اینجا عمداً حذف شده است.

      //=============================================================
      // خروج زمانی
      //=============================================================
      if(Inp_Allow_Time_Exit &&
         Inp_Max_Trade_Duration_Minutes > 0 &&
         open_time > 0)
      {
         if((int)
            ((now - open_time) / 60) >=
            Inp_Max_Trade_Duration_Minutes)
         {
            if(IsRealTradingAllowed() &&
               ClosePositionVolume(
                  ticket,
                  _Symbol,
                  is_buy,
                  volume,
                  "TFlab Time Exit"))
            {
               LogCycle(
                  "TRADE_MGMT",
                  "خروج به دلیل اتمام مدت مجاز");

               continue;
            }
         }
      }

      // Staged SL بخشی از مدیریت پایه معامله است و نباید به سه
      // گزینهٔ فرعی دیگر وابسته باشد؛ در بک‌تست قبلی به همین دلیل
      // stage1/2/3 در تمام معاملات صفر مانده بود.
      if(tp1 > 0.0)
      {
         StagedSLState sl_state;

         StagedSL_Init(
            sl_state);

         double initial_vol =
            GetPositionInitialVolume(
               position_id,
               volume);

         StagedSL_FillFromPosition(
            sl_state,
            ticket,
            tp1,
            tp2,
            initial_vol);

         StagedSL_Process(
            sl_state,
            current_price,
            Inp_Partial_Close_Percent);

         if(StagedSL_IsTP2Reached(
            sl_state,
            current_price))
         {
            LogCycle(
               "TRADE_MGMT",
               "TP2 لمس شد");
         }
      }
   }
}

//====================================================================
// رصد Pending
//====================================================================
void MonitorPending()
{
   if(g_pending.ticket > 0)
   {
      const datetime now = TimeCurrent();
      const ulong pending_scenario_id = g_pending.scenario_id;

      PendingOrder_UpdateState(g_pending, now);

      if(!g_pending.active &&
         g_pending.state == PENDING_STATE_TRIGGERED)
      {
         if(HasOpenPositionForScenario(pending_scenario_id))
         {
            g_last_executed_scenario_id = pending_scenario_id;

            if(g_scenario.id == pending_scenario_id)
            {
               Scenario_Trigger(
                  g_scenario,
                  g_pending.price,
                  now,
                  "Pending فعال شد");

               Scenario_MarkExecuted(
                  g_scenario,
                  now,
                  "معامله از Pending اجرا شد");

               AIJournal_MarkExecuted(g_scenario.id);
               EntryPlan_MarkFilled(g_entry_plan);
            }

            LogCycle(
               "PENDING_TRIGGER",
               "Pending به معامله تبدیل شد | Ticket=" +
               (string)g_pending.ticket);
         }

         PendingOrder_Init(g_pending);
      }
   }

   RefreshPendingPoolStates();

   //=================================================================
   // کنترل مستقیم تمام Pendingهای ربات، نه فقط g_pending
   //=================================================================
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;

      if((ulong)OrderGetInteger(ORDER_MAGIC) != Inp_MagicNumber)
         continue;

      ENUM_ORDER_TYPE type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(type != ORDER_TYPE_BUY_LIMIT  &&
         type != ORDER_TYPE_SELL_LIMIT &&
         type != ORDER_TYPE_BUY_STOP   &&
         type != ORDER_TYPE_SELL_STOP)
         continue;

      const string comment =
         OrderGetString(ORDER_COMMENT);

      const ulong scenario_id =
         ExtractScenarioIdFromComment(comment);

      if(scenario_id == 0)
         continue;

      bool is_buy =
         (type == ORDER_TYPE_BUY_LIMIT ||
          type == ORDER_TYPE_BUY_STOP);

      double order_sl = OrderGetDouble(ORDER_SL);
      double order_price = OrderGetDouble(ORDER_PRICE_OPEN);

      bool cancel = false;
      string cancel_reason = "";

      if(g_scenario.id == scenario_id &&
         (g_scenario.status == SCENARIO_STATUS_INVALID ||
          g_scenario.status == SCENARIO_STATUS_EXPIRED) &&
         Inp_Cancel_Pending_On_Invalid)
      {
         cancel = true;
         cancel_reason = "ابطال/انقضای Scenario";
      }
      else
      if(Inp_Enable_Reversal_Pending_Cancel &&
         g_regime.valid &&
         MarketRegime_IsReversalAgainstPosition(
            g_regime,
            is_buy,
            Inp_Reversal_Exit_Min_Confidence))
      {
         cancel = true;
         cancel_reason = "بازگشت روند قبل از فعال شدن سفارش";
      }
      else
      if(Inp_Cancel_Pending_On_SL_Breach &&
         order_sl > 0.0)
      {
         double bid_now = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask_now = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         if((!is_buy && bid_now >= order_sl) ||
            (is_buy && ask_now <= order_sl))
         {
            cancel = true;
            cancel_reason = "عبور قیمت از حد ضرر قبل از فعال شدن";
         }
      }

      if(cancel)
         RemovePendingTicket(ticket, cancel_reason);
   }

   RefreshPendingPoolStates();
}

//====================================================================
// به‌روزرسانی AI
//====================================================================
void UpdateAI()
{
   if(!Inp_Enable_AI)
      return;

   if(g_scenario.id > 0 &&
      Scenario_IsValid(
         g_scenario) &&
      g_scenario.entry_price > 0.0 &&
      g_scenario.target_1 > 0.0 &&
      g_scenario.target_2 > 0.0 &&
      g_sl_plan.stop_price > 0.0)
   {
      if(g_tp_result.valid &&
         Inp_AI_Use_Virtual_Trading &&
         g_virtual_scenario_id !=
         g_scenario.id)
      {
         ulong signal_id =
            g_scenario.id;

         datetime decision_time =
            TimeCurrent();

         ENUM_AI_VIRTUAL_DIRECTION direction =
            (g_scenario.direction ==
               SCENARIO_DIRECTION_BUY
             ?
               AI_VIRTUAL_DIRECTION_BUY
             :
               AI_VIRTUAL_DIRECTION_SELL);

         double planned_entry =
            g_scenario.entry_price;

         double sl_price =
            g_sl_plan.stop_price;

         double tp_price =
            (g_scenario.target_2 > 0.0
             ?
               g_scenario.target_2
             :
               g_scenario.target_1);

         double quantity =
            (g_risk_result.position_volume > 0.0
             ?
               g_risk_result.position_volume
             :
               Inp_AI_Virtual_Initial_Lot);

         if(quantity <= 0.0)
            quantity =
               Inp_AI_Virtual_Initial_Lot;

         double spread =
            SymbolInfoDouble(
               _Symbol,
               SYMBOL_ASK) -
            SymbolInfoDouble(
               _Symbol,
               SYMBOL_BID);

         AIVirtualTrade virtual_trade;

         if(AIVirtualCreatePlan(
            g_ai_virtual_engine,
            signal_id,
            _Symbol,
            decision_time,
            direction,
            planned_entry,
            sl_price,
            tp_price,
            quantity,
            spread,
            "TFlab_Scenario_Virtual",
            "سناریوی معتبر با Confluence بالا",
            Inp_Max_Trade_Duration_Minutes,
            virtual_trade))
         {
            int idx =
               ArraySize(
                  g_virtual_trades);

            ArrayResize(
               g_virtual_trades,
               idx + 1);

            g_virtual_trades[idx] =
               virtual_trade;

            g_virtual_scenario_id =
               g_scenario.id;

            if(AIVirtualOpen(
               g_ai_virtual_engine,
               g_virtual_trades[idx],
               TimeCurrent(),
               planned_entry,
               spread / _Point))
            {
               Print(
                  "[AI VIRTUAL OPENED] | ID=",
                  g_virtual_trades[idx].id,
                  " | Direction=",
                  AIVirtualDirectionToPersian(
                     g_virtual_trades[idx].direction));
            }
         }
         else
         {
            Print(
               "[AI VIRTUAL CREATE FAILED] | Scenario=",
               g_scenario.id);
         }
      }

      AI_AdvisorCreateAllow(
         "سناریوی معتبر برای بررسی ایجاد شده است",
         MathMin(
            100.0,
            MathMax(
               0.0,
               g_scenario.quality_value)),
         0,
         g_ai_advice);
   }
   else
   {
      AI_AdvisorCreateWait(
         "سناریوی کامل و معتبر هنوز تشکیل نشده است",
         0.0,
         0,
         g_ai_advice);
   }

   if(Inp_AI_Use_Virtual_Trading &&
      ArraySize(
         g_virtual_trades) > 0)
   {
      double bid =
         SymbolInfoDouble(
            _Symbol,
            SYMBOL_BID);

      double ask =
         SymbolInfoDouble(
            _Symbol,
            SYMBOL_ASK);

      for(int i =
         ArraySize(
            g_virtual_trades) - 1;
         i >= 0;
         i--)
      {
         if(g_virtual_trades[i].status ==
               AI_VIRTUAL_OPEN ||
            g_virtual_trades[i].status ==
               AI_VIRTUAL_PARTIAL)
         {
            if(AIVirtualUpdate(
               g_virtual_trades[i],
               TimeCurrent(),
               bid,
               ask,
               0,
               g_ai_virtual_engine))
            {
               if(g_virtual_trades[i].status ==
                     AI_VIRTUAL_STOPPED ||
                  g_virtual_trades[i].status ==
                     AI_VIRTUAL_TARGETED ||
                  g_virtual_trades[i].status ==
                     AI_VIRTUAL_CLOSED ||
                  g_virtual_trades[i].status ==
                     AI_VIRTUAL_EXPIRED)
               {
                  Print(
                     "[AI] Virtual Trade Closed | ID=",
                     g_virtual_trades[i].id,
                     " | Net=",
                     DoubleToString(
                        g_virtual_trades[i].net_profit,
                        2));
               }
            }
         }
      }
   }
}

//====================================================================
// جهت نهایی پنل
//====================================================================
string GetFinalPanelDirection()
{
   if(g_scenario.id > 0 &&
      Scenario_IsValid(
         g_scenario))
   {
      if(g_scenario.direction ==
         SCENARIO_DIRECTION_BUY)
         return "خرید";

      if(g_scenario.direction ==
         SCENARIO_DIRECTION_SELL)
         return "فروش";
   }

   return "خنثی";
}

//====================================================================
// به‌روزرسانی پنل
//====================================================================
void UpdatePanel()
{
   if(!Inp_Enable_Chart_Panel)
      return;

   string location_text =
      MarketReading_LocationToPersian(
         g_market_reading.location);

   if(g_market_reading.valid)
   {
      g_panel.market_status =
         "حال: " +
         location_text;

      g_panel.direction =
         GetFinalPanelDirection();

      g_panel.structure =
         MarketStructure_StateToPersian(
            g_structure.state);

      if(g_scenario.id > 0 &&
         Scenario_IsValid(
            g_scenario))
      {
         g_panel.scenario =
            "سناریوی معتبر " +
            ScenarioDirectionToPersian(
               g_scenario.direction);
      }
      else
      {
         g_panel.scenario =
            "بدون سناریوی معتبر";
      }

      if(g_market_reading.future_bias ==
         FUTURE_BIAS_CONTINUATION)
      {
         g_panel.entry_status =
            "ادامه حرکت";
      }
      else
      if(g_market_reading.future_bias ==
         FUTURE_BIAS_REVERSAL)
      {
         g_panel.entry_status =
            "احتمال برگشت";
      }
      else
      {
         g_panel.entry_status =
            "احتمال رنج";
      }
   }
   else
   {
      g_panel.market_status =
         "در حال بررسی";

      g_panel.direction =
         "خنثی";

      g_panel.structure =
         MarketStructure_StateToPersian(
            g_structure.state);

      g_panel.scenario =
         "بدون سناریوی معتبر";

      g_panel.entry_status =
         "در انتظار تحلیل";
   }

   string bot_status_text =
      "فعال";

   if(!g_risk_result.approved)
   {
      if(g_risk_block_reason != "")
         bot_status_text =
            "🔴 بلاک (" +
            g_risk_block_reason +
            ")";
      else
         bot_status_text =
            "🔴 بلاک (ریسک)";
   }
   else
   if(g_risk_result.risk_percent >
      Inp_Max_Risk_Per_Trade_Percent)
   {
      bot_status_text =
         "⚠️ ریسک بالا (" +
         DoubleToString(
            g_risk_result.risk_percent,
            1) +
         "%)";
   }

   g_panel.bot_status =
      bot_status_text +
      " | " +
      FilterAudit_Summary(
         g_filter_audit);

   g_panel.current_risk_percent =
      g_risk_result.risk_percent;

   g_panel.open_trades =
      CountOpenPositions();

   g_panel.pending_orders =
      CountPendingOrders();

   g_panel.open_profit =
      OpenProfit();

   g_panel.today_profit =
      TodayTotalProfit();

   g_panel.overall_profit =
      ChartPanel_CalculateOverallProfit(
         _Symbol);

   g_panel.account_balance =
      ChartPanel_GetAccountBalance();

   ChartPanel_SetUpdatedTime(
      g_panel,
      TimeCurrent());

   ChartPanel_Update(
      ChartID(),
      g_panel);
}

//====================================================================
// گزارش‌ها
//====================================================================
void UpdateReports()
{
   static datetime last_report_write = 0;

   PerformanceReport_SetOpenTrades(
      g_performance,
      CountOpenPositions(),
      OpenProfit());

   int pending_count = CountPendingOrders();

   PerformanceReport_SetPendingOrders(
      g_performance,
      pending_count,
      pending_count);

   if(PerformanceReport_Update(
         g_performance,
         TimeCurrent(),
         Inp_MagicNumber) ||
      TimeCurrent() -
      last_report_write >= 300)
   {
      ReportWord_WriteDaily(
         g_performance,
         g_filter_audit,
         g_ai_virtual_engine,
         g_virtual_trades,
         ArraySize(
            g_virtual_trades));

      ReportWord_WriteOverall(
         g_performance,
         g_filter_audit,
         g_ai_virtual_engine,
         g_virtual_trades,
         ArraySize(
            g_virtual_trades));

      last_report_write =
         TimeCurrent();
   }

   BacktestReport_WriteEquity(
      g_backtest_report,
      g_performance,
      TimeCurrent());
}

//====================================================================
// Snapshot
//====================================================================
void WriteAnalysisSnapshot(
   const datetime analysis_bar_time,
   const string cycle_result)
{
   if(!g_test_logger.initialized)
      return;

   double bid = 0.0;
   double ask = 0.0;
   double mid = 0.0;

   if(!GetCurrentPrices(
      bid,
      ask,
      mid))
      return;

   UpdateReportMetrics(
      mid);

   ENUM_HTF_DIRECTION htf =
      GetHigherTimeframeDirection();

   string htf_text =
      "خنثی";

   if(htf ==
      HTF_DIRECTION_BULLISH)
      htf_text = "صعودی";
   else
   if(htf ==
      HTF_DIRECTION_BEARISH)
      htf_text = "نزولی";

   string scenario_direction =
      "نامشخص";

   if(g_scenario.direction ==
      SCENARIO_DIRECTION_BUY)
      scenario_direction =
         "خرید";
   else
   if(g_scenario.direction ==
      SCENARIO_DIRECTION_SELL)
      scenario_direction =
         "فروش";

   string m5_direction =
      "خنثی";

   if(g_move.impulse_direction > 0)
      m5_direction = "صعودی";
   else
   if(g_move.impulse_direction < 0)
      m5_direction = "نزولی";

   string m5_state =
      ImpulseCorrection_StateToPersian(
         g_move.state);

   string m5_correction_state =
      (g_move.correction_valid
       ? "معتبر"
       : "ندارد/نامعتبر");

   string scenario_state =
      (g_scenario.id > 0
       ? ScenarioStatusToPersian(
            g_scenario.status)
       : "بدون سناریو");

   string scenario_reason =
      g_last_scenario_diagnostic;

   if(scenario_reason == "")
      scenario_reason =
         (cycle_result ==
            "سناریوی معتبر تشکیل نشد"
          ?
            "شرایط کافی برای ساخت سناریو وجود ندارد"
          :
            "چرخه تحلیل و تصمیم اجرا شد");

   double m5_atr_points =
      (g_move.impulse_atr > 0.0
       ?
         g_move.impulse_atr /
         _Point
       :
         g_context.atr_points);

   double m5_impulse_size_points =
      g_move.impulse_size_points;

   int m5_impulse_bars =
      g_move.impulse_bars;

   double m5_atr_multiple =
      g_move.impulse_atr_multiple;

   double m5_correction_ratio =
      g_move.correction_ratio;

   double m5_directional_ratio = 0.0;
   double m5_continuity_ratio = 0.0;
   double m5_efficiency_ratio = 0.0;
   double m5_momentum_score = 0.0;

   if(M5MovementMetrics_IsValid(
      g_m5_metrics))
   {
      m5_directional_ratio =
         g_m5_metrics.directional_ratio;

      m5_continuity_ratio =
         g_m5_metrics.continuity_ratio;

      m5_efficiency_ratio =
         g_m5_metrics.efficiency_ratio;

      m5_momentum_score =
         g_m5_metrics.momentum_score;
   }

   double buy_zone_distance_points = 0.0;
   double sell_zone_distance_points = 0.0;

   if(Zone_IsValid(
      g_buy_zone))
   {
      double buy_mid =
         Zone_Midpoint(
            g_buy_zone);

      if(buy_mid > 0.0)
         buy_zone_distance_points =
            MathAbs(
               mid - buy_mid) /
            _Point;
   }

   if(Zone_IsValid(
      g_sell_zone))
   {
      double sell_mid =
         Zone_Midpoint(
            g_sell_zone);

      if(sell_mid > 0.0)
         sell_zone_distance_points =
            MathAbs(
               mid - sell_mid) /
            _Point;
   }

   double buy_zone_strength =
      (Zone_IsValid(
         g_buy_zone)
       ?
         g_buy_zone.strength
       :
         0.0);

   double sell_zone_strength =
      (Zone_IsValid(
         g_sell_zone)
       ?
         g_sell_zone.strength
       :
         0.0);

   string zone_position =
      "خارج از Zone";

   bool inside_buy =
      Zone_IsValid(
         g_buy_zone) &&
      Zone_ContainsPrice(
         g_buy_zone,
         mid);

   bool inside_sell =
      Zone_IsValid(
         g_sell_zone) &&
      Zone_ContainsPrice(
         g_sell_zone,
         mid);

   if(inside_buy &&
      inside_sell)
      zone_position =
         "داخل BUY و SELL Zone";
   else
   if(inside_buy)
      zone_position =
         "داخل BUY Zone";
   else
   if(inside_sell)
      zone_position =
         "داخل SELL Zone";
   else
   {
      bool buy_valid =
         Zone_IsValid(
            g_buy_zone);

      bool sell_valid =
         Zone_IsValid(
            g_sell_zone);

      if(buy_valid &&
         sell_valid)
      {
         if(buy_zone_distance_points <
            sell_zone_distance_points)
            zone_position =
               "نزدیک BUY Zone";
         else
         if(sell_zone_distance_points <
            buy_zone_distance_points)
            zone_position =
               "نزدیک SELL Zone";
         else
            zone_position =
               "فاصله برابر از Zoneها";
      }
      else
      if(buy_valid)
         zone_position =
            "نزدیک BUY Zone";
      else
      if(sell_valid)
         zone_position =
            "نزدیک SELL Zone";
   }

   string context_state =
      (g_context.valid
       ?
         MarketContext_ToPersian(
            g_context.state)
       :
         "نامشخص");

   string regime_text =
      EnumToString(
         g_regime.regime);

   string setup_state =
      "نامشخص";

   string setup_direction =
      "";

   string setup_reason =
      "داده مستقیم دلیل Setup در ساختار فعلی موجود نیست";

   if(g_scenario.id > 0)
   {
      setup_state =
         Scenario_IsValid(
            g_scenario)
         ? "سناریوی معتبر"
         : "نامعتبر";

      setup_direction =
         ScenarioDirectionToPersian(
            g_scenario.direction);

      if(cycle_result ==
         "سناریوی معتبر تشکیل نشد")
      {
         setup_state =
            "در انتظار";

         setup_direction =
            "";

         setup_reason =
            "سناریوی معتبر برای Setup تشکیل نشد";
      }
   }
   else
   {
      setup_state =
         "بدون سناریو";

      setup_direction =
         "";

      setup_reason =
         "سناریوی معتبری برای ارزیابی Setup وجود ندارد";
   }

   double movement_quality = 0.0;
   double zone_quality = 0.0;
   double proximity = 0.0;
   double alignment = 0.0;
   double combined_quality = 0.0;

   if(M5ZoneQuality_IsValid(
      g_m5_zone_quality))
   {
      movement_quality =
         g_m5_zone_quality.movement_quality_score;

      zone_quality =
         g_m5_zone_quality.zone_quality_score;

      proximity =
         g_m5_zone_quality.proximity_score;

      alignment =
         g_m5_zone_quality.movement_alignment_score;

      combined_quality =
         g_m5_zone_quality.combined_quality_score;
   }

   TestReportLogger_WriteSnapshot(
      g_test_logger,
      TimeCurrent(),
      _Symbol,
      (ENUM_TIMEFRAMES)_Period,
      analysis_bar_time,
      bid,
      ask,
      g_context.spread_points,
      htf_text,
      htf_text,
      context_state,
      regime_text,
      context_state,
      g_regime.confidence,
      0.0,
      MarketStructure_StateToPersian(
         g_structure.state),
      m5_state,
      m5_direction,
      g_move.impulse_valid,
      m5_impulse_size_points,
      m5_impulse_bars,
      m5_atr_points,
      m5_atr_multiple,
      m5_directional_ratio,
      m5_continuity_ratio,
      m5_efficiency_ratio,
      m5_momentum_score,
      m5_correction_state,
      m5_correction_ratio,
      buy_zone_distance_points,
      sell_zone_distance_points,
      buy_zone_strength,
      sell_zone_strength,
      zone_position,
      scenario_state,
      scenario_direction,
      g_scenario.quality_value,
      0.0,
      scenario_reason,
      setup_state,
      setup_direction,
      setup_reason,
      cycle_result);
}

//====================================================================
// اجرای چرخه تحلیل
//====================================================================
void RunAnalysisCycle()
{
   datetime bar =
      iTime(
         _Symbol,
         Inp_TF_Setup_M5,
         1);

   if(bar <= 0 ||
      bar ==
      g_last_m5_closed_bar)
      return;

   TradingScenario new_scenario;
   SLPlan new_sl_plan;
   TP_Result new_tp_result;
   TargetInfo new_target;

   //===============================================================
   // تحلیل جدید شکست خورد:
   // سناریوی قبلی دیگر حفظ نمی‌شود.
   //===============================================================
   if(!AnalyzeMarket(
      new_scenario,
      new_sl_plan,
      new_tp_result,
      new_target))
   {
      g_last_m5_closed_bar =
         bar;

      g_main_state.last_analysis_bar =
         bar;

      g_main_state.last_analysis_time =
         TimeCurrent();

      ResetActiveScenarioState(
         "تحلیل جدید سناریوی معتبر تولید نکرد");

      g_entry_plan.type =
         ENTRY_PLAN_WAIT;

      g_entry_plan.status =
         ENTRY_PLAN_STATUS_PLANNED;

      g_entry_plan.executable =
         false;

      g_entry_plan.entry_currently_available =
         false;

      g_entry_plan.entry_reachable =
         false;

      g_entry_plan.reason =
         "سناریوی معتبر جدید تشکیل نشد";

      UpdateRisk();
      UpdatePanel();

      LogCycle(
         "ANALYSIS",
         "سناریوی معتبر جدید تشکیل نشد | سناریوی قبلی نیز حفظ نشد");

      WriteAnalysisSnapshot(
         bar,
         "سناریوی معتبر تشکیل نشد | State قبلی پاک شد");

      return;
   }

   //===============================================================
   // بررسی تغییر Scenario
   //===============================================================
   if(g_scenario.id > 0 &&
      new_scenario.id > 0)
   {
      bool direction_changed =
         (g_scenario.direction !=
             SCENARIO_DIRECTION_NONE &&
          new_scenario.direction !=
             SCENARIO_DIRECTION_NONE &&
          g_scenario.direction !=
             new_scenario.direction);

      bool scenario_changed =
         !IsSameScenario(
            g_scenario,
            new_scenario);

      if(direction_changed ||
         scenario_changed)
      {
         if(direction_changed)
         {
            Print(
               "[SCENARIO] DIRECTION CHANGED | Direction=",
               ScenarioDirectionToPersian(
                  g_scenario.direction),
               "→",
               ScenarioDirectionToPersian(
                  new_scenario.direction));
         }
         else
         {
            Print(
               "[SCENARIO] CHANGED | Direction=",
               ScenarioDirectionToPersian(
                  g_scenario.direction),
               "→",
               ScenarioDirectionToPersian(
                  new_scenario.direction));
         }

         CancelActivePending(
            "سناریو یا جهت تغییر کرده است");

         PendingOrder_Init(
            g_pending);
      }
      else
      {
         new_scenario.id =
            g_scenario.id;

         Print(
            "[SCENARIO] UNCHANGED | ID=",
            g_scenario.id,
            " | Pending حفظ شد | Ticket=",
            g_pending.ticket);
      }
   }

   // ممیزی سیگنال فقط ثبت می‌کند و هیچ حقی برای جلوگیری از معامله ندارد.
   SignalAudit_Register(
      g_signal_audit,
      new_scenario,
      g_last_strategy_type,
      g_last_strategy_confidence,
      g_regime,
      g_structure,
      g_move,
      g_market_truth,
      g_higher_tf_context);

   g_scenario =
      new_scenario;

   g_sl_plan =
      new_sl_plan;

   g_tp_result =
      new_tp_result;

   g_target =
      new_target;

   g_last_m5_closed_bar =
      bar;

   g_main_state.last_analysis_bar =
      bar;

   g_main_state.last_analysis_time =
      TimeCurrent();

   UpdateRisk();

   ManageScenarioAndEntry();

   RegisterCurrentScenarioForVirtualTester();

   UpdateAI();

   UpdatePanel();

   LogCycle(
      "ANALYSIS",
      "چرخه تحلیل، Strategy و Scenario اجرا شد",
      g_scenario.quality_value,
      g_risk_result.rr);

   WriteAnalysisSnapshot(
      bar,
      "چرخه تحلیل، Strategy و Scenario اجرا شد");
}

//====================================================================
// OnInit
//====================================================================
int OnInit()
{
   ZeroMemory(
      g_main_state);

   Scenario_Init(
      g_scenario);

   MarketReading_Reset(
      g_market_reading);

   FilterAudit_Reset(
      g_filter_audit);

   Setup_Init(
      g_setup);

   EntryPlan_Init(
      g_entry_plan);

   PendingPool_Init();

   Zone_Init(
      g_buy_zone);

   Zone_Init(
      g_sell_zone);

   ResetReportMetrics();

   Risk_InitLimits(
      g_risk_limits);

   Risk_InitAccountState(
      g_risk_account);

   Risk_InitResult(
      g_risk_result);

   g_is_transition_mode =
      false;

   AIVirtualEngine_Init(
      g_ai_virtual_engine);

   ChartPanel_InitState(
      g_panel);

   PerformanceReport_Init(
      g_performance);

   ArrayResize(
      g_virtual_trades,
      0);

   g_virtual_scenario_id =
      0;

   AI_AdvisorInit(
      g_ai_advice);

   DetailedLogger_ConfigInit(
      g_detailed_config);

   DetailedLogger_StateInit(
      g_detailed_state);

   TestReportLogger_InitState(
      g_test_logger);

   BacktestReport_InitState(g_backtest_report);
   SignalAudit_InitState(g_signal_audit);

   if(!ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   if(!InitializeHigherTimeframeEngine())
      Print(
         "EA جدید | هشدار | Higher Timeframe Engine آماده نشد");

   if(!DetailedLogger_Init(
      _Symbol,
      g_detailed_config,
      g_detailed_state))
   {
      Print(
         "EA جدید | هشدار | Detailed Logger آماده نشد");
   }

   PerformanceReport_Start(
      g_performance);

   TestReportLogger_Init(
      g_test_logger,
      _Symbol);

   BacktestReport_Init(g_backtest_report);
   SignalAudit_Init(g_signal_audit);

   ScenarioVirtualTester_Init();

   if(Inp_Enable_Chart_Panel)
      ChartPanel_Create(
         ChartID());

   EventSetTimer(1);

   g_main_state.initialized =
      true;

   // نمایش BUY/SELL برای معاملات قبلی و فعلی موجود در History
   DrawHistoricalTradeSignalLabels();

   g_main_state.trading_enabled =
      Inp_EnableTrading;

   g_main_state.start_time =
      TimeCurrent();

   g_main_state.last_monitor_time =
      g_main_state.start_time;

   g_main_state.last_tick_time =
      g_main_state.start_time;

   Print(
      "================================================");

   Print(
      "EA جدید | هسته یکپارچه راه‌اندازی شد");

   Print(
      "نماد: ",
      _Symbol);

   Print(
      "تایم‌فریم: ",
      EnumToString(
         (ENUM_TIMEFRAMES)_Period));

   Print(
      "تحلیل MTF: فعال");

   Print(
      "Strategy Engine: فعال | BUY Continuation + SELL Continuation + End-of-Correction BUY/SELL");

   Print(
      "AI Independent Analysis: ",
      (Inp_AI_Independent_Enable
       ? "فعال"
       : "غیرفعال"),
      " | تایم‌فریم=",
      EnumToString(
         Inp_AI_Independent_Timeframe));

   Print(
      "AI Suggestion Popup: فعال | تحلیل هر ۱۵ دقیقه");

   Print(
      "Scenario: ",
      Inp_Enable_Scenarios
      ? "فعال"
      : "غیرفعال");

   Print(
      "Pending: ",
      Inp_AllowPendingOrders
      ? "فعال"
      : "غیرفعال");

   Print(
      "M1 Monitoring: ",
      Inp_Use_M1_Monitor
      ? "فعال"
      : "غیرفعال");

   Print(
      "AI: ",
      Inp_Enable_AI
      ? "فعال"
      : "غیرفعال");

   Print(
      "AI Auto Trade: ",
      (Inp_AI_Can_Trade_Real
       ? "فعال"
       : "غیرفعال"));

   Print(
      "Take Profit Mode: ",
      (Inp_Use_Manual_TP
       ? "دستی | هدف=" + DoubleToString(Inp_Manual_TP_Profit_Money, 2) + " حساب"
       : "سیستمی"));
Print(
      "Chart Panel: ",
      Inp_Enable_Chart_Panel
      ? "فعال"
      : "غیرفعال");

   Print(
      "M5 Movement Metrics: فعال | فقط گزارش‌گیری");

   Print(
      "M5 Zone Quality Analyzer: فعال | فقط گزارش‌گیری");

   Print(
      "Scenario Virtual Tester: ",
      g_svt_state.initialized
      ? "فعال"
      : "غیرفعال");

   Print(
      "Virtual Models: FIXED + WIDE_SL + PARTIAL_TP2_TRAIL");

   Print(
      "Virtual SL = SL واقعی سناریو");

   Print(
      "Scenario Invalidation = SL Reference");

   Print(
      "================================================");

   UpdatePanel();

   return INIT_SUCCEEDED;
}

//====================================================================
// OnDeinit
//====================================================================
void OnDeinit(
   const int reason)
{
   EventKillTimer();

   // پایان تست/اجرای EA: یک بار گزارش نهایی و خروجی‌های Strategy Tester نوشته شود.
   if(g_main_state.initialized)
   {
      UpdateReports();
      BacktestReport_Finalize(g_backtest_report,g_performance);
      SignalAudit_Finalize(g_signal_audit);
   }

   if(ArraySize(
      g_virtual_trades) > 0)
   {
      ArrayFree(
         g_virtual_trades);

      Print(
         "[AI] Virtual Trades Cleaned Up");
   }

   g_virtual_scenario_id =
      0;

   g_svt_state.initialized =
      false;

   DetailedLogger_Shutdown(
      g_detailed_state);

   TestReportLogger_Shutdown(
      g_test_logger);

   if(Inp_Enable_Chart_Panel)
      ChartPanel_Destroy(
         ChartID());

   AISuggestion_HidePopup();

   g_main_state.initialized =
      false;

   Print(
      "EA جدید | هسته یکپارچه متوقف شد | دلیل: ",
      reason);
}

//====================================================================
// اجرای خودکار پیشنهاد معامله AI
//====================================================================
void ProcessAutoAISuggestion()
{
   if(!Inp_Enable_AI ||
      !Inp_AI_Can_Trade_Real)
      return;

   if(!g_main_state.initialized)
      return;

   if(!g_ai_popup.visible ||
      g_ai_popup.type != AI_POPUP_TRADE)
      return;

   // هر پاپ‌آپ فقط یک بار برای اجرای خودکار بررسی می‌شود.
   static datetime last_auto_show_time = 0;

   if(g_ai_popup.show_time <= 0 ||
      g_ai_popup.show_time == last_auto_show_time)
      return;

   last_auto_show_time =
      g_ai_popup.show_time;

   Print(
      "[AI AUTO] پیشنهاد معامله شناسایی شد | Direction=",
      g_ai_popup.trade_direction,
      " | Entry=",
      DoubleToString(
         g_ai_popup.trade_entry,
         _Digits),
      " | SL=",
      DoubleToString(
         g_ai_popup.trade_sl,
         _Digits),
      " | TP=",
      DoubleToString(
         g_ai_popup.trade_tp,
         _Digits),
      " | Confidence=",
      DoubleToString(
         g_ai_popup.trade_confidence,
         1),
      "%");

   ExecuteConfirmedAISuggestion(
      g_ai_popup.trade_direction,
      g_ai_popup.trade_entry,
      g_ai_popup.trade_sl,
      g_ai_popup.trade_tp,
      g_ai_popup.trade_confidence,
      g_ai_popup.trade_reason);
}

//====================================================================
// OnChartEvent
//====================================================================
void OnChartEvent(
   const int id,
   const long &lparam,
   const double &dparam,
   const string &sparam)
{
   AISuggestion_OnChartEvent(
      id,
      lparam,
      dparam,
      sparam);

   string ai_direction = "";

   double ai_entry = 0.0;
   double ai_sl = 0.0;
   double ai_tp = 0.0;
   double ai_confidence = 0.0;

   string ai_reason = "";

   bool ai_confirmed = false;
   bool ai_rejected = false;

   if(AISuggestion_ConsumeTradeAction(
      ai_confirmed,
      ai_rejected,
      ai_direction,
      ai_entry,
      ai_sl,
      ai_tp,
      ai_confidence,
      ai_reason))
   {
      if(ai_confirmed)
      {
         ExecuteConfirmedAISuggestion(
            ai_direction,
            ai_entry,
            ai_sl,
            ai_tp,
            ai_confidence,
            ai_reason);
      }
      else
      if(ai_rejected)
      {
         Print(
            "[AI MANUAL] REJECTED | Direction=",
            ai_direction);
      }
   }
}

//====================================================================
// اجرای دستی AI
//====================================================================
void ExecuteConfirmedAISuggestion(
   const string direction,
   const double entry,
   const double sl,
   const double tp,
   const double confidence,
   const string reason)
{
   Print(
      "[AI MANUAL] CONFIRM RECEIVED | Direction=",
      direction,
      " | Entry=",
      DoubleToString(entry,_Digits),
      " | SL=",
      DoubleToString(sl,_Digits),
      " | TP=",
      DoubleToString(tp,_Digits),
      " | Conf=",
      DoubleToString(
         confidence,
         1),
      "%");

   if(!g_main_state.initialized)
   {
      Alert(
         "⛔ معامله AI اجرا نشد | EA هنوز آماده نیست");

      return;
   }

   if(!IsRealTradingAllowed())
   {
      Alert(
         "⛔ معامله AI اجرا نشد | مجوز معامله واقعی فعال نیست");

      return;
   }

   const bool is_buy =
      (direction == "BUY");

   if(direction != "BUY" &&
      direction != "SELL")
   {
      Alert(
         "⛔ معامله AI اجرا نشد | جهت پیشنهاد نامعتبر است");

      return;
   }

   //--- AI دستی حق دور زدن Scenario را ندارد
   if(g_scenario.id <= 0 ||
      !Scenario_IsValid(
         g_scenario))
   {
      Alert(
         "⛔ معامله AI اجرا نشد | سناریوی معتبر وجود ندارد");

      Print(
         "[AI MANUAL] BLOCKED | Scenario معتبر نیست");

      return;
   }

   string scenario_direction =
      (g_scenario.direction ==
         SCENARIO_DIRECTION_BUY
       ?
         "BUY"
       :
       (g_scenario.direction ==
          SCENARIO_DIRECTION_SELL
        ?
         "SELL"
        :
         "NONE"));

   if(direction !=
      scenario_direction)
   {
      Alert(
         "⛔ معامله AI اجرا نشد | جهت AI با Scenario یکی نیست");

      Print(
         "[AI MANUAL] BLOCKED | AI=",
         direction,
         " | Scenario=",
         scenario_direction);

      return;
   }

   if(entry <= 0.0 ||
      sl <= 0.0 ||
      tp <= 0.0)
   {
      Alert(
         "⛔ معامله AI اجرا نشد | Entry/SL/TP نامعتبر است");

      return;
   }

   if(g_risk_result.position_volume <= 0.0 ||
      !g_risk_result.approved)
   {
      Alert(
         "⛔ معامله AI اجرا نشد | ریسک تأیید نشده است");

      return;
   }

   if(MathAbs(
      entry -
      g_scenario.entry_price) > 2.0 ||
      MathAbs(
      sl -
      g_sl_plan.stop_price) > 2.0)
   {
      Alert(
         "⛔ معامله AI اجرا نشد | سطوح AI با Scenario منطبق نیستند");

      return;
   }

   if((is_buy &&
       !Inp_AllowBuy) ||
      (!is_buy &&
       !Inp_AllowSell))
   {
      Alert(
         "⛔ معامله AI اجرا نشد | این جهت مجاز نیست");

      return;
   }

   string market_reason = "";

   if(!IsMarketOpenForSymbol(
      market_reason))
   {
      Alert(
         "⛔ معامله AI اجرا نشد | ",
         market_reason);

      return;
   }

   string spread_reason = "";

   if(!IsSpreadAcceptable(
      spread_reason))
   {
      Alert(
         "⛔ معامله AI اجرا نشد | ",
         spread_reason);

      return;
   }

   if(!CloseOppositePositionsAndVerify(
      is_buy
      ? SCENARIO_DIRECTION_BUY
      : SCENARIO_DIRECTION_SELL))
   {
      Alert(
         "⛔ معامله AI اجرا نشد | معامله مخالف بسته نشده است");

      return;
   }

   double bid = 0.0;
   double ask = 0.0;
   double current_price = 0.0;

   if(!GetCurrentPrices(
      bid,
      ask,
      current_price))
   {
      Alert(
         "⛔ معامله AI اجرا نشد | قیمت لحظه‌ای دریافت نشد");

      return;
   }

   ExecutionRequest req;
   ExecutionResult res;

   Execution_InitRequest(
      req);

   req.symbol =
      _Symbol;

   req.magic =
      Inp_MagicNumber;

   req.scenario_id =
      g_scenario.id;

   req.signal_id =
      g_scenario.id;

   req.volume =
      g_risk_result.position_volume;

   req.price =
      NormalizeDouble(
         entry,
         _Digits);

   req.stop_loss =

      NormalizeDouble(

         sl,

         _Digits);

   double real_ai_tp = 0.0;

   if(!ResolveRealTakeProfit(

      is_buy

      ? SCENARIO_DIRECTION_BUY

      : SCENARIO_DIRECTION_SELL,

      entry,

      req.volume,

      tp,

      real_ai_tp))

   {

      Alert(

         "⛔ معامله AI اجرا نشد | حد سود نهایی قابل محاسبه نیست");

      return;

   }

   req.take_profit =

      NormalizeDouble(

         real_ai_tp,

         _Digits);

   req.expiration =
      TimeCurrent() +
      (Inp_Pending_Expiration_Minutes *
       60);

   req.comment =
      MakeScenarioComment(
         g_scenario.id,
         g_scenario.target_1,
         g_scenario.target_2);

   req.reason =
      reason;

   const double spread_price =
      MathMax(
         ask - bid,
         _Point);

   const double tolerance =
      MathMax(
         _Point * 2.0,
         spread_price * 1.5);

   if(MathAbs(
      (is_buy ? ask : bid) -
      entry) <=
      tolerance)
   {
      req.order_type =
         (is_buy
          ?
           EXECUTION_BUY_MARKET
          :
           EXECUTION_SELL_MARKET);

      req.price =
         current_price;

      if(!Execution_SendMarket(
         req,
         res))
      {
         Alert(
            "⛔ اجرای معامله AI ناموفق بود");

         return;
      }

      g_last_executed_scenario_id =
         g_scenario.id;

      Alert(
         "✅ معامله AI تأیید و اجرا شد | ",
         direction);

      return;
   }

   if(!Inp_AllowPendingOrders)
   {
      Alert(
         "⛔ معامله AI اجرا نشد | Pending غیرفعال است");

      return;
   }

   if(is_buy)
   {
      req.order_type =
         (entry < ask
          ?
           EXECUTION_BUY_LIMIT
          :
           EXECUTION_BUY_STOP);
   }
   else
   {
      req.order_type =
         (entry > bid
          ?
           EXECUTION_SELL_LIMIT
          :
           EXECUTION_SELL_STOP);
   }

   if(!Execution_PlacePending(
      req,
      res))
   {
      Alert(
         "⛔ ثبت Pending معامله AI ناموفق بود");

      return;
   }

   Alert(
      "✅ پیشنهاد AI تأیید شد | Pending ثبت شد");
}

//====================================================================
// OnTick
//====================================================================
void OnTick()
{
   if(!g_main_state.initialized)
      return;

   g_main_state.last_tick_time =
      TimeCurrent();

   RunAnalysisCycle();

   double audit_bid=0.0, audit_ask=0.0, audit_mid=0.0;
   if(GetCurrentPrices(audit_bid,audit_ask,audit_mid))
      SignalAudit_Update(g_signal_audit,TimeCurrent(),audit_bid,audit_ask);

   UpdateScenarioVirtualTester();

   MonitorPending();

   MonitorOpenTrades();

   UpdatePanel();
}

//====================================================================
// OnTimer
//====================================================================
void OnTimer()
{
   if(!g_main_state.initialized)
      return;

   datetime now =
      TimeCurrent();

   if((now -
       g_main_state.last_monitor_time) <
      Inp_Monitor_Update_Seconds)
      return;

   g_main_state.last_monitor_time =
      now;

   if(Inp_Use_H4_Background ||
      Inp_Use_H1_Background)
   {
      RefreshHigherTimeframeContext();
   }

   if(g_scenario.id > 0)
   {
      double bid = 0.0;
      double ask = 0.0;
      double mid = 0.0;

      if(GetCurrentPrices(
         bid,
         ask,
         mid))
      {
         InvalidationResult inv;

         Invalidation_UpdateScenario(
            g_scenario,
            mid,
            now,
            inv);
      }
   }

   double audit_bid=0.0, audit_ask=0.0, audit_mid=0.0;
   if(GetCurrentPrices(audit_bid,audit_ask,audit_mid))
      SignalAudit_Update(g_signal_audit,now,audit_bid,audit_ask);

   UpdateScenarioVirtualTester();

   MonitorPending();

   MonitorOpenTrades();

   // مدیریت TP و تأیید برگشت دقیقاً در چرخه دقیقه‌ای
   ProcessMinuteTradeManagement();

   UpdateRisk();

   ManageScenarioAndEntry();

   RegisterCurrentScenarioForVirtualTester();

   //===============================================================
   // AI Independent فقط یک بار
   //===============================================================
   {
      string bot_dir =
         (g_scenario.id > 0 &&
          Scenario_IsValid(
             g_scenario) &&
          g_scenario.direction ==
             SCENARIO_DIRECTION_BUY
          ?
            "BUY"
          :
          (g_scenario.id > 0 &&
           Scenario_IsValid(
              g_scenario) &&
           g_scenario.direction ==
              SCENARIO_DIRECTION_SELL
           ?
             "SELL"
           :
             "NONE"));

      string bot_dec =
         (g_scenario.id > 0 &&
          Scenario_IsValid(
             g_scenario)
          ?
            ScenarioStatusToPersian(
               g_scenario.status)
          :
            "بدون سناریوی معتبر");

      AIIndependent_Update(
         bot_dir,
         bot_dec);
   }

   UpdateAI();

   UpdateReports();

   AISuggestion_Update();

   ProcessAutoAISuggestion();

   UpdatePanel();

   LogCycle(
      "MONITOR",
      "رصد دوره‌ای انجام شد");
}

//====================================================================
// OnTradeTransaction
//====================================================================
void OnTradeTransaction(
   const MqlTradeTransaction &trans,
   const MqlTradeRequest &request,
   const MqlTradeResult &result)
{
   if(!g_main_state.initialized)
      return;

   if(trans.symbol != "" &&
      trans.symbol != _Symbol)
      return;

   if(trans.type ==
      TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong deal_ticket =
         trans.deal;

      if(deal_ticket > 0 &&
         HistorySelect(
            0,
            TimeCurrent()) &&
         HistoryDealSelect(
            deal_ticket))
      {
         string deal_symbol =
            HistoryDealGetString(
               deal_ticket,
               DEAL_SYMBOL);

         long deal_magic =
            HistoryDealGetInteger(
               deal_ticket,
               DEAL_MAGIC);

         long deal_entry =
            HistoryDealGetInteger(
               deal_ticket,
               DEAL_ENTRY);

         if(deal_symbol ==
               _Symbol &&
            deal_magic ==
               Inp_MagicNumber &&
            deal_entry ==
               DEAL_ENTRY_IN)
         {
            int open_count =
               CountOpenPositions();

            int max_allowed =
               GetEffectiveMaxOpenTrades();

            if(open_count >
               max_allowed)
            {
               Print(
                  "[OVERFLOW] معامله اضافی شناسایی شد! باز=",
                  open_count,
                  " | سقف=",
                  max_allowed);

               for(int i =
                  PositionsTotal() - 1;
                  i >= 0;
                  i--)
               {
                  ulong pos_ticket =
                     PositionGetTicket(i);

                  if(pos_ticket == 0)
                     continue;

                  if(!PositionSelectByTicket(
                     pos_ticket))
                     continue;

                  if(PositionGetString(
                        POSITION_SYMBOL) !=
                     _Symbol)
                     continue;

                  if((ulong)
                     PositionGetInteger(
                        POSITION_MAGIC) !=
                     Inp_MagicNumber)
                     continue;

                  bool is_buy =
                     (PositionGetInteger(
                        POSITION_TYPE) ==
                      POSITION_TYPE_BUY);

                  double vol =
                     PositionGetDouble(
                        POSITION_VOLUME);

                  if(ClosePositionVolume(
                     pos_ticket,
                     _Symbol,
                     is_buy,
                     vol,
                     "TFlab سقف معاملات"))
                  {
                     Print(
                        "[OVERFLOW FIXED] معامله اضافی بسته شد | Ticket=",
                        pos_ticket);

                     break;
                  }
               }
            }
         }
      }
   }

   // برچسب BUY/SELL باید مستقل از Detailed Log باشد
   HandleTradeSignalTransaction(trans);

   if(Inp_Enable_Detailed_Log &&
      g_detailed_state.initialized)
   {
      DetailedLogger_Log(
         DLOG_LEVEL_INFO,
         DLOG_CATEGORY_TRADE,
         "TRADE_TRANSACTION",
         "EXECUTION",
         g_panel.direction,
         g_panel.scenario,
         "تغییر وضعیت معامله/سفارش دریافت شد",
         _Symbol,
         (ENUM_TIMEFRAMES)_Period,
         (double)result.retcode,
         (double)result.order,
         (double)result.deal,
         0.0,
         result.price,
         result.volume,
         request.sl,
         request.tp,
         g_scenario.id,
         result.order,
         trans.position,
         g_detailed_config,
         g_detailed_state);
   }
}

//+------------------------------------------------------------------+
//| پایان فایل                                                       |
//+------------------------------------------------------------------+