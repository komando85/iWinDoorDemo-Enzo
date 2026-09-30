//+------------------------------------------------------------------+
//| Pending_Thesis_Revalidation_Manager_CURRENT.mqh                   |
//| TFlab New EA V.5                                                 |
//|                                                                  |
//| وظیفه: اعتبارسنجی مجدد Thesis برای Pending واقعی                  |
//| و حذف Pending قبل از فعال‌شدن در صورت برگشت معتبر بازار.          |
//+------------------------------------------------------------------+
#ifndef __TFLAB_PENDING_THESIS_REVALIDATION_MANAGER_CURRENT_MQH__
#define __TFLAB_PENDING_THESIS_REVALIDATION_MANAGER_CURRENT_MQH__

#property strict

//====================================================================
// رأی‌های لازم برای حذف Pending
//====================================================================
#define TFLAB_PTRM_MIN_CONFLICT_VOTES 2
#define TFLAB_PTRM_MIN_CONTEXT_STRENGTH 55.0
#define TFLAB_PTRM_MIN_HTF_STRENGTH     60.0

//====================================================================
// تشخیص جهت مخالف در هر لایه
//====================================================================
bool PTRM_RegimeConflicts(
   const PendingOrderRecord &pending)
{
   if(!g_regime.valid)
      return false;

   if(pending.direction == SCENARIO_DIRECTION_SELL)
      return (
         g_regime.regime == MARKET_REGIME_UPTREND &&
         g_regime.confidence >= Inp_Min_Regime_Confidence
      );

   if(pending.direction == SCENARIO_DIRECTION_BUY)
      return (
         g_regime.regime == MARKET_REGIME_DOWNTREND &&
         g_regime.confidence >= Inp_Min_Regime_Confidence
      );

   return false;
}

//====================================================================
bool PTRM_StructureConflicts(
   const PendingOrderRecord &pending)
{
   if(!g_structure.valid)
      return false;

   if(pending.direction == SCENARIO_DIRECTION_SELL)
      return (
         g_structure.state == STRUCTURE_STATE_BULLISH &&
         g_structure.bullish_sequence
      );

   if(pending.direction == SCENARIO_DIRECTION_BUY)
      return (
         g_structure.state == STRUCTURE_STATE_BEARISH &&
         g_structure.bearish_sequence
      );

   return false;
}

//====================================================================
bool PTRM_ContextConflicts(
   const PendingOrderRecord &pending)
{
   if(!g_context.valid)
      return false;

   if(g_context.state_strength < TFLAB_PTRM_MIN_CONTEXT_STRENGTH)
      return false;

   if(pending.direction == SCENARIO_DIRECTION_SELL)
      return (g_context.state == MARKET_CONTEXT_BULLISH_PRESSURE);

   if(pending.direction == SCENARIO_DIRECTION_BUY)
      return (g_context.state == MARKET_CONTEXT_BEARISH_PRESSURE);

   return false;
}

//====================================================================
bool PTRM_HTFConflicts(
   const PendingOrderRecord &pending)
{
   if(!g_higher_tf_context.valid)
      return false;

   if(g_higher_tf_context.combined_strength < TFLAB_PTRM_MIN_HTF_STRENGTH)
      return false;

   if(pending.direction == SCENARIO_DIRECTION_SELL)
      return (
         g_higher_tf_context.combined_direction ==
         HTF_DIRECTION_BULLISH
      );

   if(pending.direction == SCENARIO_DIRECTION_BUY)
      return (
         g_higher_tf_context.combined_direction ==
         HTF_DIRECTION_BEARISH
      );

   return false;
}

//====================================================================
// ساخت دلیل دقیق حذف
//====================================================================
string PTRM_BuildReason(
   const int regime_conflict,
   const int structure_conflict,
   const int context_conflict,
   const int htf_conflict,
   const int votes)
{
   string reason = "Thesis Pending معتبر نیست | Votes=" +
                   IntegerToString(votes);

   if(regime_conflict)
      reason += " | Regime مخالف";

   if(structure_conflict)
      reason += " | Structure مخالف";

   if(context_conflict)
      reason += " | Context مخالف";

   if(htf_conflict)
      reason += " | HTF مخالف";

   return reason;
}

//====================================================================
// بررسی اینکه Pending باید حذف شود یا نه
//====================================================================
bool PTRM_ShouldCancel(
   const PendingOrderRecord &pending,
   const TradingScenario &scenario,
   string &reason)
{
   reason = "";

   if(!pending.active || pending.ticket == 0)
      return false;

   //--- اگر Scenario وابسته قبلاً Invalid/Expired/Cancelled شده
   if(
      scenario.id == pending.scenario_id &&
      (
         scenario.status == SCENARIO_STATUS_INVALID ||
         scenario.status == SCENARIO_STATUS_EXPIRED ||
         scenario.status == SCENARIO_STATUS_CANCELLED
      )
   )
   {
      reason = "Scenario وابسته دیگر معتبر نیست";
      return true;
   }

   //--- اگر Scenario فعلی عوض شده و Pending متعلق به آن نیست،
   //--- Pending قدیمی نباید زنده بماند.
   if(
      scenario.id > 0 &&
      pending.scenario_id > 0 &&
      scenario.id != pending.scenario_id
   )
   {
      reason = "Pending متعلق به Scenario قدیمی است";
      return true;
   }

   const bool regime_conflict =
      PTRM_RegimeConflicts(pending);

   const bool structure_conflict =
      PTRM_StructureConflicts(pending);

   const bool context_conflict =
      PTRM_ContextConflicts(pending);

   const bool htf_conflict =
      PTRM_HTFConflicts(pending);

   int votes = 0;

   if(regime_conflict)    votes++;
   if(structure_conflict) votes++;
   if(context_conflict)   votes++;
   if(htf_conflict)       votes++;

   //--- دو لایه مستقل مخالف = Thesis شکست خورده.
   if(votes >= TFLAB_PTRM_MIN_CONFLICT_VOTES)
   {
      reason = PTRM_BuildReason(
         regime_conflict ? 1 : 0,
         structure_conflict ? 1 : 0,
         context_conflict ? 1 : 0,
         htf_conflict ? 1 : 0,
         votes
      );

      return true;
   }

   //--- حتی یک Structure + Regime قوی نیز کافی است.
   if(structure_conflict && regime_conflict)
   {
      reason = "Structure و Regime علیه Pending برگشته‌اند";
      return true;
   }

   //--- Context + Regime نیز در برگشت واقعی کافی است.
   if(context_conflict && regime_conflict)
   {
      reason = "Context و Regime علیه Pending برگشته‌اند";
      return true;
   }

   //--- منطق Reversal قبلی را به عنوان لایه تکمیلی حفظ می‌کنیم.
   if(
      Inp_Enable_Reversal_Pending_Cancel &&
      g_regime.valid &&
      MarketRegime_IsReversalAgainstPosition(
         g_regime,
         pending.direction == SCENARIO_DIRECTION_BUY,
         Inp_Reversal_Exit_Min_Confidence
      )
   )
   {
      reason = "بازگشت روند علیه Pending توسط Regime تأیید شد";
      return true;
   }

   return false;
}

//====================================================================
// مدیریت Pending واقعی
//====================================================================
bool PTRM_ManagePending()
{
   if(
      g_pending.ticket == 0 ||
      !g_pending.active
   )
      return false;

   const datetime now = TimeCurrent();

   string reason = "";

   if(
      !PTRM_ShouldCancel(
         g_pending,
         g_scenario,
         reason
      )
   )
      return false;

   const ulong ticket = g_pending.ticket;
   const ulong scenario_id = g_pending.scenario_id;
   const ENUM_SCENARIO_DIRECTION direction =
      g_pending.direction;

   //--- اول Pending واقعی را از بروکر حذف کن.
   if(
      !PendingOrder_Cancel(
         g_pending,
         reason,
         now
      )
   )
   {
      Print(
         "[PENDING THESIS PROTECTION] DELETE FAILED",
         " | Ticket=", ticket,
         " | Scenario=", scenario_id,
         " | Direction=",
         ScenarioDirectionToPersian(direction),
         " | Reason=", reason
      );

      return false;
   }

   //--- بعد از حذف موفق، Scenario همان سفارش را Invalid کن.
   if(
      g_scenario.id == scenario_id &&
      g_scenario.id > 0
   )
   {
      Scenario_Invalidate(
         g_scenario,
         now,
         reason
      );

   }

   //--- State قدیمی نباید دوباره حفظ شود.
   PendingOrder_Init(g_pending);

   Print(
      "[PENDING THESIS PROTECTION] DELETED",
      " | Ticket=", ticket,
      " | Scenario=", scenario_id,
      " | Direction=",
      ScenarioDirectionToPersian(direction),
      " | Reason=", reason
   );

   LogCycle(
      "PENDING_THESIS",
      "Pending واقعی به دلیل شکست Thesis حذف شد | Ticket=" +
      (string)ticket +
      " | Scenario=" +
      (string)scenario_id +
      " | Reason=" +
      reason
   );

   return true;
}

#endif
