#ifndef __TFLAB_STRATEGY_ENGINE_MQH__
#define __TFLAB_STRATEGY_ENGINE_MQH__

//+------------------------------------------------------------------+
//|                    Strategy_Engine.mqh                           |
//|                    TFlab New EA V.5                              |
//|                                                                  |
//| مسئولیت: تشخیص Strategy / Setup                                  |
//|                                                                  |
//| Strategy Engine v2.2                                             |
//| اصلاح: Pullback Continuation برای BUY/SELL                       |
//+------------------------------------------------------------------+
#property strict

#include "EA_Inputs.mqh"
#include "Market_Regime.mqh"
#include "Market_Context.mqh"
#include "Market_Structure.mqh"
#include "Impulse_Correction.mqh"
#include "Zone_Engine.mqh"
#include "Scenario_Engine.mqh"
#include "AI_Independent_Analysis.mqh"

//====================================================================
// نوع Strategy
//====================================================================
enum ENUM_STRATEGY_TYPE
  {
   STRATEGY_NONE = 0,
   STRATEGY_BUY_CONTINUATION,
   STRATEGY_SELL_CONTINUATION,
   STRATEGY_BUY_REVERSAL,
   STRATEGY_SELL_REVERSAL,
   STRATEGY_BREAKOUT
  };

//====================================================================
// نتیجه Strategy
//====================================================================
struct StrategyResult
  {
   bool                        valid;
   ENUM_STRATEGY_TYPE          type;
   ENUM_SCENARIO_DIRECTION     direction;

   double                      quality;
   double                      confidence;

   ulong                       zone_id;

   string                      reason;
   string                      failure_reason;
  };

//====================================================================
// Strategy -> فارسی
//====================================================================
string StrategyTypeToPersian(const ENUM_STRATEGY_TYPE type)
  {
   switch(type)
     {
      case STRATEGY_BUY_CONTINUATION:
         return "ادامه روند خرید";

      case STRATEGY_SELL_CONTINUATION:
         return "ادامه روند فروش";

      case STRATEGY_BUY_REVERSAL:
         return "برگشت خرید";

      case STRATEGY_SELL_REVERSAL:
         return "برگشت فروش";

      case STRATEGY_BREAKOUT:
         return "شکست";

      default:
         return "بدون استراتژی";
     }
  }

//====================================================================
// Reset
//====================================================================
void Strategy_Reset(StrategyResult &result)
  {
   ZeroMemory(result);

   result.valid          = false;
   result.type           = STRATEGY_NONE;
   result.direction      = SCENARIO_DIRECTION_NONE;
   result.quality        = 0.0;
   result.confidence     = 0.0;
   result.zone_id        = 0;
   result.reason         = "";
   result.failure_reason = "";
  }

//====================================================================
// BUY CONTINUATION
//====================================================================
bool Strategy_IsBuyContinuation(
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &zone,
   string &reason)
  {
   reason = "";

   if(!MarketStructure_IsValid(structure))
     {
      reason = "ساختار بازار معتبر نیست";
      return false;
     }

   if(MarketRegime_IsValid(regime) &&
      regime.regime == MARKET_REGIME_DOWNTREND)
     {
      reason = "Regime نزولی با BUY Continuation تضاد دارد";
      return false;
     }

   //--- اجازه Transition
   if(structure.state != STRUCTURE_STATE_BULLISH &&
      structure.state != STRUCTURE_STATE_BALANCED)
     {
      if(structure.state == STRUCTURE_STATE_TRANSITION &&
         Inp_Allow_Transition_Strategy)
        {
         Print(
            "[STRATEGY] BUY Continuation | "
            "ساختار در حال تغییر - با شرایط سخت‌تر اجازه داده می‌شود");
        }
      else
        {
         reason =
            "ساختار فعلی صعودی یا متعادل نیست | State=" +
            MarketStructure_StateToCode(structure.state);

         return false;
        }
     }

   bool has_sequence =
      structure.bullish_sequence;

   if(!move.valid)
     {
      reason = "Snapshot حرکت معتبر نیست";
      return false;
     }

   if(!move.impulse_valid)
     {
      reason = "Impulse معتبر نیست";
      return false;
     }

   //===============================================================
   // BUY CONTINUATION
   //===============================================================
   // در بک‌تست جاری چهار BUY زیان‌ده از مسیر Impulse مستقیم عبور
   // کرده‌اند؛ حالت پیش‌فرض Pullback معتبر را الزامی می‌کند.
   bool buy_move_ok = false;
   bool buy_pullback = false;

   if(Inp_Buy_Continuation_Require_Pullback)
     {
      if(move.impulse_direction < 0 &&
         move.correction_valid &&
         move.correction_direction < 0 &&
         structure.state == STRUCTURE_STATE_BULLISH &&
         structure.bullish_sequence)
        {
         buy_move_ok = true;
         buy_pullback = true;
        }
     }
   else
     {
      // حالت آزاد برای مقایسه A/B با منطق قبلی
      if(move.impulse_direction > 0)
         buy_move_ok = true;
      else
      if(move.impulse_direction < 0 &&
         move.correction_valid &&
         structure.state == STRUCTURE_STATE_BULLISH &&
         structure.bullish_sequence)
        {
         buy_move_ok = true;
         buy_pullback = true;
        }

      if(buy_move_ok)
        {
         bool strong_impulse =
            (move.impulse_atr_multiple >= 2.0);

         if(!move.correction_valid &&
            !strong_impulse &&
            !buy_pullback)
           {
            reason =
               "Correction معتبر تشکیل نشده و Impulse به اندازه کافی قوی نیست | ATRx=" +
               DoubleToString(move.impulse_atr_multiple, 2);
            return false;
           }

         if(!buy_pullback &&
            move.correction_valid &&
            move.correction_direction >= 0)
           {
            reason =
               "Correction هم‌جهت با Impulse است (باید مخالف باشد)";
            return false;
           }
        }
     }

   if(!buy_move_ok)
     {
      reason =
         "BUY Continuation شرایط حرکت کافی ندارد | ImpulseDir=" +
         (string)move.impulse_direction +
         " | CorrectionValid=" +
         (move.correction_valid ? "YES" : "NO") +
         " | CorrectionDir=" +
         (string)move.correction_direction +
         " | PullbackRequired=" +
         (Inp_Buy_Continuation_Require_Pullback ? "YES" : "NO");
      return false;
     }

   if(Inp_Max_Correction_Ratio > 0.0 &&
      move.correction_valid &&
      move.correction_ratio > Inp_Max_Correction_Ratio)
     {
      reason =
         "نسبت اصلاح از حد مجاز بیشتر است | Ratio=" +
         DoubleToString(move.correction_ratio, 3) +
         " | Max=" +
         DoubleToString(Inp_Max_Correction_Ratio, 3);

      return false;
     }

   if(!Zone_IsValid(zone))
     {
      reason = "BUY Zone معتبر نیست";
      return false;
     }

   if(zone.direction != ZONE_DIRECTION_BUY)
     {
      reason = "Zone انتخاب‌شده BUY نیست";
      return false;
     }

   //===============================================================
   // REASON
   //===============================================================
   reason =
      "ساختار " +
      MarketStructure_StateToCode(structure.state);

   if(has_sequence)
      reason += " + HH/HL";

   if(buy_pullback)
      reason += " + Pullback نزولی معتبر برای BUY";

   reason += " + BUY Zone";

   return true;
  }

//====================================================================
// SELL CONTINUATION
//====================================================================
bool Strategy_IsSellContinuation(
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &zone,
   string &reason)
  {
   reason = "";

   if(!MarketStructure_IsValid(structure))
     {
      reason = "ساختار بازار معتبر نیست";
      return false;
     }

   if(MarketRegime_IsValid(regime) &&
      regime.regime == MARKET_REGIME_UPTREND)
     {
      reason =
         "Regime صعودی با SELL Continuation تضاد دارد";

      return false;
     }

   //===============================================================
   // STRUCTURE
   //===============================================================
   if(structure.state != STRUCTURE_STATE_BEARISH &&
      structure.state != STRUCTURE_STATE_BALANCED)
     {
      if(structure.state == STRUCTURE_STATE_TRANSITION &&
         Inp_Allow_Transition_Strategy)
        {
         Print(
            "[STRATEGY] SELL Continuation | "
            "ساختار در حال تغییر - با شرایط سخت‌تر اجازه داده می‌شود");
        }
      else
        {
         reason =
            "ساختار فعلی نزولی یا متعادل نیست | State=" +
            MarketStructure_StateToCode(structure.state);

         return false;
        }
     }

   bool has_sequence =
      structure.bearish_sequence;

   if(!move.valid)
     {
      reason = "Snapshot حرکت معتبر نیست";
      return false;
     }

   if(!move.impulse_valid)
     {
      reason = "Impulse معتبر نیست";
      return false;
     }

   //===============================================================
   // SELL DIRECT / PULLBACK
   //===============================================================
   bool sell_move_ok = false;
   bool sell_pullback = false;

   //--- حالت اول: ادامه مستقیم نزولی
   if(move.impulse_direction < 0)
     {
      sell_move_ok = true;
     }

   //--- حالت دوم:
//    حرکت صعودی داخل ساختار نزولی = Pullback برای SELL
//
//    دو حالت قابل قبول:
//    1) Correction معتبر توسط موتور حرکت تشخیص داده شده
//    2) CorrectionValid=NO اما حرکت صعودی بسیار قوی است
//       و ساختار اصلی همچنان کاملاً نزولی است.
//       در این حالت خود Impulse صعودی به عنوان Pullback ساختاری
//       در نظر گرفته می‌شود.
//
//    هدف:
//    در روند نزولی قوی، یک Counter-Move بزرگ نباید فقط به خاطر
//    CorrectionValid=NO باعث حذف SELL شود.
else
if(move.impulse_direction > 0 &&
   structure.state == STRUCTURE_STATE_BEARISH &&
   structure.bearish_sequence)
  {
   const bool structural_pullback =
      (move.correction_valid ||
       move.impulse_atr_multiple >= 2.0);

   if(structural_pullback)
     {
      sell_move_ok = true;
      sell_pullback = true;

      Print(
         "[STRATEGY] SELL Continuation | "
         "PULLBACK MODE | "
         "Impulse=UP | "
         "Correction=",
         (move.correction_valid ? "YES" : "NO"),
         " | ImpulseATRx=",
         DoubleToString(move.impulse_atr_multiple, 2),
         " | Structure=BEARISH | "
         "Sequence=YES");
     }
  }

   if(!sell_move_ok)
     {
      reason =
         "حرکت برای SELL Continuation معتبر نیست | Direction=" +
         (string)move.impulse_direction +
         " | CorrectionValid=" +
         (move.correction_valid ? "YES" : "NO");

      return false;
     }

   bool strong_impulse =
      (move.impulse_atr_multiple >= 2.0);

   /*
      در Pullback، نیازی نیست Impulse نزولی باشد؛
      چون خود حرکت UP نقش اصلاح را دارد.
   */
   if(!move.correction_valid &&
      !strong_impulse &&
      !sell_pullback)
     {
      reason =
         "Correction معتبر تشکیل نشده و Impulse به اندازه کافی قوی نیست | ATRx=" +
         DoubleToString(move.impulse_atr_multiple, 2);

      return false;
     }

   /*
      در حالت مستقیم SELL:
      اگر Correction وجود داشته باشد باید خلاف Impulse باشد.

      در حالت Pullback:
      خود حرکت UP، Pullback محسوب شده و دیگر شرط قبلی
      نباید آن را رد کند.
   */
   if(!sell_pullback &&
      move.correction_valid &&
      move.correction_direction <= 0)
     {
      reason =
         "Correction هم‌جهت با Impulse است (باید مخالف باشد)";

      return false;
     }

   if(Inp_Max_Correction_Ratio > 0.0 &&
      move.correction_valid &&
      move.correction_ratio > Inp_Max_Correction_Ratio)
     {
      reason =
         "نسبت اصلاح از حد مجاز بیشتر است | Ratio=" +
         DoubleToString(move.correction_ratio, 3) +
         " | Max=" +
         DoubleToString(Inp_Max_Correction_Ratio, 3);

      return false;
     }

   if(!Zone_IsValid(zone))
     {
      reason = "SELL Zone معتبر نیست";
      return false;
     }

   if(zone.direction != ZONE_DIRECTION_SELL)
     {
      reason = "Zone انتخاب‌شده SELL نیست";
      return false;
     }

   //===============================================================
   // REASON
   //===============================================================
   reason =
      "ساختار " +
      MarketStructure_StateToCode(structure.state);

   if(has_sequence)
      reason += " + LH/LL";

   if(sell_pullback)
     {
      reason +=
         " + Pullback صعودی معتبر برای SELL";
     }
   else
     {
      reason +=
         " + Impulse نزولی (ATRx=" +
         DoubleToString(move.impulse_atr_multiple, 2) +
         ")";
     }

   reason += " + SELL Zone";

   return true;
  }

//====================================================================
// کیفیت BUY Continuation
//====================================================================
double Strategy_CalculateBuyContinuationQuality(
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &zone)
  {
   double quality = 0.0;

   if(MarketStructure_IsValid(structure))
     {
      if(structure.state == STRUCTURE_STATE_BULLISH)
         quality += 30.0;
      else
      if(structure.state == STRUCTURE_STATE_BALANCED)
         quality += 15.0;
      else
      if(structure.state == STRUCTURE_STATE_TRANSITION)
         quality += 5.0;
     }

   if(structure.bullish_sequence)
      quality += 15.0;

   //--- حرکت مستقیم BUY
   if(move.valid &&
      move.impulse_valid &&
      move.impulse_direction > 0)
     {
      quality += 20.0;

      if(move.impulse_atr_multiple >= 2.0)
         quality += 5.0;

      if(move.impulse_atr_multiple >= 3.0)
         quality += 5.0;
     }
   //--- Pullback نزولی برای BUY
   else
   if(move.valid &&
      move.impulse_valid &&
      move.impulse_direction < 0 &&
      move.correction_valid &&
      structure.state == STRUCTURE_STATE_BULLISH)
     {
      quality += 18.0;
     }

   if(move.correction_valid &&
      move.correction_direction < 0)
     {
      quality += 10.0;

      if(move.correction_ratio >= 0.30 &&
         move.correction_ratio <= 0.70)
         quality += 5.0;
     }

   if(Zone_IsValid(zone) &&
      zone.direction == ZONE_DIRECTION_BUY)
     {
      quality += 10.0;

      if(zone.strength >= 70.0)
         quality += 5.0;
     }

   if(MarketRegime_IsValid(regime))
     {
      if(regime.regime == MARKET_REGIME_UPTREND)
         quality += 10.0;
      else
      if(regime.regime == MARKET_REGIME_TRANSITION)
         quality += 3.0;
     }

   if(context.valid &&
      context.state == MARKET_CONTEXT_BULLISH_PRESSURE)
      quality += 5.0;

   if(structure.state ==
      STRUCTURE_STATE_TRANSITION)
      quality -= 10.0;

   if(g_ai_independent_opinion.valid &&
      g_ai_independent_opinion.direction == "BUY" &&
      g_ai_independent_opinion.confidence >=
      Inp_AI_Boost_Min_Confidence)
     {
      quality += Inp_AI_Boost_Quality;

      Print(
         "[STRATEGY] AI BOOST | کیفیت BUY Continuation +",
         DoubleToString(
            Inp_AI_Boost_Quality,
            1),
         " | AI=",
         DoubleToString(
            g_ai_independent_opinion.confidence,
            1),
         "%");
     }

   return MathMin(
      100.0,
      MathMax(
         0.0,
         quality));
  }

//====================================================================
// کیفیت SELL Continuation
//====================================================================
double Strategy_CalculateSellContinuationQuality(
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &zone)
  {
   double quality = 0.0;

   if(MarketStructure_IsValid(structure))
     {
      if(structure.state == STRUCTURE_STATE_BEARISH)
         quality += 30.0;
      else
      if(structure.state == STRUCTURE_STATE_BALANCED)
         quality += 15.0;
      else
      if(structure.state == STRUCTURE_STATE_TRANSITION)
         quality += 5.0;
     }

   if(structure.bearish_sequence)
      quality += 15.0;

   //===============================================================
   // SELL DIRECT
   //===============================================================
   if(move.valid &&
      move.impulse_valid &&
      move.impulse_direction < 0)
     {
      quality += 20.0;

      if(move.impulse_atr_multiple >= 2.0)
         quality += 5.0;

      if(move.impulse_atr_multiple >= 3.0)
         quality += 5.0;
     }
   //===============================================================
   // SELL PULLBACK
   //===============================================================
   else
   if(move.valid &&
      move.impulse_valid &&
      move.impulse_direction > 0 &&
      move.correction_valid &&
      structure.state == STRUCTURE_STATE_BEARISH &&
      structure.bearish_sequence)
     {
      /*
         کمی پایین‌تر از Impulse مستقیم،
         اما کاملاً معتبر.
      */
      quality += 18.0;

      //--- Pullback قوی
      if(move.impulse_atr_multiple >= 2.0)
         quality += 3.0;

      if(move.impulse_atr_multiple >= 3.0)
         quality += 3.0;
     }

   //===============================================================
   // CORRECTION
   //===============================================================
   if(move.correction_valid)
     {
      /*
         در SELL مستقیم:
         correction_direction > 0
         یعنی اصلاح صعودی.

         در Pullback:
         خود ImpulseDirection > 0 نقش Pullback دارد.
         بنابراین فقط معتبر بودن Correction کافی است.
      */
      if(move.correction_direction > 0)
        {
         quality += 10.0;

         if(move.correction_ratio >= 0.30 &&
            move.correction_ratio <= 0.70)
            quality += 5.0;
        }
      else
      if(move.impulse_direction > 0 &&
         structure.state == STRUCTURE_STATE_BEARISH)
        {
         quality += 10.0;

         if(move.correction_ratio >= 0.30 &&
            move.correction_ratio <= 0.70)
            quality += 5.0;
        }
     }

   //===============================================================
   // SELL ZONE
   //===============================================================
   if(Zone_IsValid(zone) &&
      zone.direction == ZONE_DIRECTION_SELL)
     {
      quality += 10.0;

      if(zone.strength >= 70.0)
         quality += 5.0;
     }

   //===============================================================
   // REGIME
   //===============================================================
   if(MarketRegime_IsValid(regime))
     {
      if(regime.regime == MARKET_REGIME_DOWNTREND)
         quality += 10.0;
      else
      if(regime.regime == MARKET_REGIME_TRANSITION)
         quality += 3.0;
     }

   //===============================================================
   // CONTEXT
   //===============================================================
   if(context.valid &&
      context.state == MARKET_CONTEXT_BEARISH_PRESSURE)
      quality += 5.0;

   //===============================================================
   // TRANSITION PENALTY
   //===============================================================
   if(structure.state ==
      STRUCTURE_STATE_TRANSITION)
      quality -= 10.0;

   //===============================================================
   // AI BOOST
   //===============================================================
   if(g_ai_independent_opinion.valid &&
      g_ai_independent_opinion.direction == "SELL" &&
      g_ai_independent_opinion.confidence >=
      Inp_AI_Boost_Min_Confidence)
     {
      quality += Inp_AI_Boost_Quality;

      Print(
         "[STRATEGY] AI BOOST | کیفیت SELL Continuation +",
         DoubleToString(
            Inp_AI_Boost_Quality,
            1),
         " | AI=",
         DoubleToString(
            g_ai_independent_opinion.confidence,
            1),
         "%");
     }

   return MathMin(
      100.0,
      MathMax(
         0.0,
         quality));
  }

//====================================================================
// BUY Reversal
//====================================================================
bool Strategy_IsBuyReversal(
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &zone,
   string &reason)
  {
   reason = "";

   if(!MarketStructure_IsValid(structure))
     {
      reason = "ساختار بازار معتبر نیست";
      return false;
     }

   if(structure.state != STRUCTURE_STATE_BEARISH)
     {
      reason =
         "ساختار پایه برای برگشت خرید نزولی نیست";
      return false;
     }

   if(!move.valid ||
      !move.impulse_valid)
     {
      reason =
         "Impulse معتبر برای برگشت خرید وجود ندارد";
      return false;
     }

   if(move.impulse_direction <= 0)
     {
      reason =
         "حرکت مخالف ساختار نزولی، صعودی نیست";
      return false;
     }

   if(move.impulse_atr_multiple < 1.5)
     {
      reason =
         "Impulse برای Reversal به اندازه کافی قوی نیست | ATRx=" +
         DoubleToString(
            move.impulse_atr_multiple,
            2);

      return false;
     }

   if(!Zone_IsValid(zone))
     {
      reason =
         "BUY Zone برای Reversal معتبر نیست";
      return false;
     }

   if(zone.direction != ZONE_DIRECTION_BUY)
     {
      reason =
         "Zone انتخاب‌شده BUY نیست";
      return false;
     }

   reason =
      "ساختار نزولی + حرکت صعودی خلاف ساختار (ATRx=" +
      DoubleToString(
         move.impulse_atr_multiple,
         2) +
      ") + BUY Zone";

   return true;
  }

//====================================================================
// SELL Reversal
//====================================================================
bool Strategy_IsSellReversal(
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &zone,
   string &reason)
  {
   reason = "";

   if(!MarketStructure_IsValid(structure))
     {
      reason = "ساختار بازار معتبر نیست";
      return false;
     }

   if(structure.state != STRUCTURE_STATE_BULLISH)
     {
      reason =
         "ساختار پایه برای برگشت فروش صعودی نیست";
      return false;
     }

   if(!move.valid ||
      !move.impulse_valid)
     {
      reason =
         "Impulse معتبر برای برگشت فروش وجود ندارد";
      return false;
     }

   if(move.impulse_direction >= 0)
     {
      reason =
         "حرکت مخالف ساختار صعودی، نزولی نیست";
      return false;
     }

   if(move.impulse_atr_multiple < 1.5)
     {
      reason =
         "Impulse برای Reversal به اندازه کافی قوی نیست | ATRx=" +
         DoubleToString(
            move.impulse_atr_multiple,
            2);

      return false;
     }

   if(!Zone_IsValid(zone))
     {
      reason =
         "SELL Zone برای Reversal معتبر نیست";
      return false;
     }

   if(zone.direction != ZONE_DIRECTION_SELL)
     {
      reason =
         "Zone انتخاب‌شده SELL نیست";
      return false;
     }

   reason =
      "ساختار صعودی + حرکت نزولی خلاف ساختار (ATRx=" +
      DoubleToString(
         move.impulse_atr_multiple,
         2) +
      ") + SELL Zone";

   return true;
  }

//====================================================================
// کیفیت BUY Reversal
//====================================================================
double Strategy_CalculateBuyReversalQuality(
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &zone)
  {
   double quality = 0.0;

   if(MarketStructure_IsValid(structure) &&
      structure.state == STRUCTURE_STATE_BEARISH)
      quality += 25.0;

   if(move.valid &&
      move.impulse_valid &&
      move.impulse_direction > 0)
     {
      quality += 25.0;

      if(move.impulse_atr_multiple >= 2.0)
         quality += 10.0;

      if(move.impulse_atr_multiple >= 3.0)
         quality += 10.0;
     }

   if(move.correction_valid &&
      move.correction_direction < 0)
      quality += 10.0;

   if(Zone_IsValid(zone) &&
      zone.direction == ZONE_DIRECTION_BUY)
     {
      quality += 15.0;

      if(zone.strength >= 70.0)
         quality += 5.0;
     }

   if(MarketRegime_IsValid(regime) &&
      (regime.regime == MARKET_REGIME_UPTREND ||
       regime.regime == MARKET_REGIME_RANGE ||
       regime.regime == MARKET_REGIME_TRANSITION))
      quality += 5.0;

   if(context.valid &&
      context.state == MARKET_CONTEXT_BULLISH_PRESSURE)
      quality += 5.0;

   if(g_ai_independent_opinion.valid &&
      g_ai_independent_opinion.direction == "BUY" &&
      g_ai_independent_opinion.confidence >=
      Inp_AI_Boost_Min_Confidence)
     {
      quality += Inp_AI_Boost_Quality;
     }

   if(g_ai_independent_opinion.valid &&
      g_ai_independent_opinion.direction == "SELL" &&
      g_ai_independent_opinion.confidence >=
      Inp_AI_Boost_Min_Confidence)
     {
      quality += Inp_AI_Boost_Quality;
     }

   return MathMin(
      100.0,
      MathMax(
         0.0,
         quality));
  }

//====================================================================
// کیفیت SELL Reversal
//====================================================================
double Strategy_CalculateSellReversalQuality(
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &zone)
  {
   double quality = 0.0;

   if(MarketStructure_IsValid(structure) &&
      structure.state == STRUCTURE_STATE_BULLISH)
      quality += 25.0;

   if(move.valid &&
      move.impulse_valid &&
      move.impulse_direction < 0)
     {
      quality += 25.0;

      if(move.impulse_atr_multiple >= 2.0)
         quality += 10.0;

      if(move.impulse_atr_multiple >= 3.0)
         quality += 10.0;
     }

   if(move.correction_valid &&
      move.correction_direction > 0)
      quality += 10.0;

   if(Zone_IsValid(zone) &&
      zone.direction == ZONE_DIRECTION_SELL)
     {
      quality += 15.0;

      if(zone.strength >= 70.0)
         quality += 5.0;
     }

   if(MarketRegime_IsValid(regime) &&
      (regime.regime == MARKET_REGIME_DOWNTREND ||
       regime.regime == MARKET_REGIME_RANGE ||
       regime.regime == MARKET_REGIME_TRANSITION))
      quality += 5.0;

   if(context.valid &&
      context.state == MARKET_CONTEXT_BEARISH_PRESSURE)
      quality += 5.0;

   return MathMin(
      100.0,
      MathMax(
         0.0,
         quality));
  }

//====================================================================
// ساخت BUY Continuation Scenario
//====================================================================
bool Strategy_CreateBuyContinuationScenario(
   const string symbol,
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &zone,
   TradingScenario &scenario,
   StrategyResult &result)
  {
   Strategy_Reset(result);
   Scenario_Init(scenario);

   if(symbol == "")
     {
      result.failure_reason =
         "Symbol معتبر نیست";
      return false;
     }

   string reason = "";

   if(!Strategy_IsBuyContinuation(
         regime,
         context,
         structure,
         move,
         zone,
         reason))
     {
      result.failure_reason =
         reason;

      Print(
         "[STRATEGY] BUY Continuation FAIL | ",
         reason);

      return false;
     }

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

   string correction_reason =
      move.correction_valid ?
      "Correction / Pullback نزولی" :
      "Impulse قوی بدون Correction";

   ENUM_MARKET_REGIME regime_value =
      MarketRegime_IsValid(regime) ?
      regime.regime :
      MARKET_REGIME_UNKNOWN;

   if(!Scenario_Create(
         scenario_id,
         symbol,
         SCENARIO_DIRECTION_BUY,
         regime_value,
         zone,
         true,
         true,
         move.correction_valid,
         SCENARIO_ACTIVATION_ZONE_TOUCH,
         zone.invalidation_price,
         now,
         expiry,
         (int)Inp_TF_Context_M30,
         (int)Inp_TF_Setup_M5,
         structure.reason,
         move.reason,
         correction_reason,
         zone.reason,
         "سناریو از شواهد ساختار، حرکت و BUY Zone ایجاد شد",
         scenario))
     {
      result.failure_reason =
         "ساخت Scenario برای BUY Continuation ناموفق بود";

      return false;
     }

   const double entry_price =
      Zone_Midpoint(zone);

   if(entry_price <= 0.0)
     {
      Scenario_Cancel(
         scenario,
         now,
         "قیمت میانی BUY Zone معتبر نیست");

      result.failure_reason =
         "Entry پیشنهادی معتبر نیست";

      return false;
     }

   if(!Scenario_SetEntryPrice(
         scenario,
         entry_price,
         now,
         "Entry پیشنهادی در میانه BUY Zone تعیین شد"))
     {
      result.failure_reason =
         "ثبت Entry پیشنهادی ناموفق بود";

      return false;
     }

   Scenario_UpdateQuality(
      scenario);

   const double strategy_quality =
      Strategy_CalculateBuyContinuationQuality(
         regime,
         context,
         structure,
         move,
         zone);

   scenario.quality_value =
      MathMin(
         100.0,
         MathMax(
            scenario.quality_value,
            strategy_quality));

   result.valid =
      true;

   result.type =
      STRATEGY_BUY_CONTINUATION;

   result.direction =
      SCENARIO_DIRECTION_BUY;

   result.zone_id =
      zone.id;

   result.quality =
      scenario.quality_value;

   result.confidence =
      scenario.quality_value;

   result.reason =
      reason;

   scenario.general_reason =
      reason;

   Print(
      "[STRATEGY] BUY Continuation OK | Quality=",
      DoubleToString(
         scenario.quality_value,
         1),
      " | ",
      reason);

   return true;
  }

//====================================================================
// ساخت SELL Continuation Scenario
//====================================================================
bool Strategy_CreateSellContinuationScenario(
   const string symbol,
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &zone,
   TradingScenario &scenario,
   StrategyResult &result)
  {
   Strategy_Reset(result);
   Scenario_Init(scenario);

   if(symbol == "")
     {
      result.failure_reason =
         "Symbol معتبر نیست";
      return false;
     }

   string reason = "";

   if(!Strategy_IsSellContinuation(
         regime,
         context,
         structure,
         move,
         zone,
         reason))
     {
      result.failure_reason =
         reason;

      Print(
         "[STRATEGY] SELL Continuation FAIL | ",
         reason);

      return false;
     }

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

   string correction_reason = "";

   if(move.impulse_direction > 0 &&
      move.correction_valid &&
      structure.state == STRUCTURE_STATE_BEARISH)
     {
      correction_reason =
         "Pullback صعودی داخل ساختار نزولی";
     }
   else
   if(move.correction_valid)
     {
      correction_reason =
         "Correction صعودی بعد از Impulse نزولی";
     }
   else
     {
      correction_reason =
         "Impulse قوی بدون Correction";
     }

   ENUM_MARKET_REGIME regime_value =
      MarketRegime_IsValid(regime) ?
      regime.regime :
      MARKET_REGIME_UNKNOWN;

   if(!Scenario_Create(
         scenario_id,
         symbol,
         SCENARIO_DIRECTION_SELL,
         regime_value,
         zone,
         true,
         true,
         move.correction_valid,
         SCENARIO_ACTIVATION_ZONE_TOUCH,
         zone.invalidation_price,
         now,
         expiry,
         (int)Inp_TF_Context_M30,
         (int)Inp_TF_Setup_M5,
         structure.reason,
         move.reason,
         correction_reason,
         zone.reason,
         "سناریو از شواهد ساختار، حرکت و SELL Zone ایجاد شد",
         scenario))
     {
      result.failure_reason =
         "ساخت Scenario برای SELL Continuation ناموفق بود";

      return false;
     }

   const double entry_price =
      Zone_Midpoint(zone);

   if(entry_price <= 0.0)
     {
      Scenario_Cancel(
         scenario,
         now,
         "قیمت میانی SELL Zone معتبر نیست");

      result.failure_reason =
         "Entry پیشنهادی معتبر نیست";

      return false;
     }

   if(!Scenario_SetEntryPrice(
         scenario,
         entry_price,
         now,
         "Entry پیشنهادی در میانه SELL Zone تعیین شد"))
     {
      result.failure_reason =
         "ثبت Entry پیشنهادی ناموفق بود";

      return false;
     }

   Scenario_UpdateQuality(
      scenario);

   const double strategy_quality =
      Strategy_CalculateSellContinuationQuality(
         regime,
         context,
         structure,
         move,
         zone);

   scenario.quality_value =
      MathMin(
         100.0,
         MathMax(
            scenario.quality_value,
            strategy_quality));

   result.valid =
      true;

   result.type =
      STRATEGY_SELL_CONTINUATION;

   result.direction =
      SCENARIO_DIRECTION_SELL;

   result.zone_id =
      zone.id;

   result.quality =
      scenario.quality_value;

   result.confidence =
      scenario.quality_value;

   result.reason =
      reason;

   scenario.general_reason =
      reason;

   Print(
      "[STRATEGY] SELL Continuation OK | Quality=",
      DoubleToString(
         scenario.quality_value,
         1),
      " | ",
      reason);

   return true;
  }

//====================================================================
// ساخت BUY Reversal Scenario
//====================================================================
bool Strategy_CreateBuyReversalScenario(
   const string symbol,
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &zone,
   TradingScenario &scenario,
   StrategyResult &result)
  {
   Strategy_Reset(result);
   Scenario_Init(scenario);

   if(symbol == "")
     {
      result.failure_reason =
         "Symbol معتبر نیست";
      return false;
     }

   string reason = "";

   if(!Strategy_IsBuyReversal(
         regime,
         context,
         structure,
         move,
         zone,
         reason))
     {
      result.failure_reason =
         reason;

      Print(
         "[STRATEGY] BUY Reversal FAIL | ",
         reason);

      return false;
     }

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

   string correction_reason =
      move.correction_valid ?
      "Correction مشاهده شد" :
      "Correction برای Reversal الزام نیست";

   ENUM_MARKET_REGIME regime_value =
      MarketRegime_IsValid(regime) ?
      regime.regime :
      MARKET_REGIME_UNKNOWN;

   if(!Scenario_Create(
         scenario_id,
         symbol,
         SCENARIO_DIRECTION_BUY,
         regime_value,
         zone,
         true,
         true,
         move.correction_valid,
         SCENARIO_ACTIVATION_REACTION,
         zone.invalidation_price,
         now,
         expiry,
         (int)Inp_TF_Context_M30,
         (int)Inp_TF_Setup_M5,
         structure.reason,
         move.reason,
         correction_reason,
         zone.reason,
         "سناریوی برگشت خرید از ساختار نزولی و حرکت صعودی خلاف ساختار",
         scenario))
     {
      result.failure_reason =
         "ساخت Scenario برای BUY Reversal ناموفق بود";

      return false;
     }

   const double entry_price =
      Zone_Midpoint(zone);

   if(entry_price <= 0.0)
     {
      Scenario_Cancel(
         scenario,
         now,
         "قیمت میانی BUY Zone معتبر نیست");

      result.failure_reason =
         "Entry پیشنهادی معتبر نیست";

      return false;
     }

   if(!Scenario_SetEntryPrice(
         scenario,
         entry_price,
         now,
         "Entry پیشنهادی BUY Reversal در میانه Zone تعیین شد"))
     {
      result.failure_reason =
         "ثبت Entry پیشنهادی BUY Reversal ناموفق بود";

      return false;
     }

   Scenario_UpdateQuality(
      scenario);

   const double strategy_quality =
      Strategy_CalculateBuyReversalQuality(
         regime,
         context,
         structure,
         move,
         zone);

   scenario.quality_value =
      MathMin(
         100.0,
         MathMax(
            scenario.quality_value,
            strategy_quality));

   result.valid =
      true;

   result.type =
      STRATEGY_BUY_REVERSAL;

   result.direction =
      SCENARIO_DIRECTION_BUY;

   result.zone_id =
      zone.id;

   result.quality =
      scenario.quality_value;

   result.confidence =
      scenario.quality_value;

   result.reason =
      reason;

   scenario.general_reason =
      reason;

   Print(
      "[STRATEGY] BUY Reversal OK | Quality=",
      DoubleToString(
         scenario.quality_value,
         1),
      " | ",
      reason);

   return true;
  }

//====================================================================
// ساخت SELL Reversal Scenario
//====================================================================
bool Strategy_CreateSellReversalScenario(
   const string symbol,
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &zone,
   TradingScenario &scenario,
   StrategyResult &result)
  {
   Strategy_Reset(result);
   Scenario_Init(scenario);

   if(symbol == "")
     {
      result.failure_reason =
         "Symbol معتبر نیست";
      return false;
     }

   string reason = "";

   if(!Strategy_IsSellReversal(
         regime,
         context,
         structure,
         move,
         zone,
         reason))
     {
      result.failure_reason =
         reason;

      Print(
         "[STRATEGY] SELL Reversal FAIL | ",
         reason);

      return false;
     }

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

   string correction_reason =
      move.correction_valid ?
      "Correction مشاهده شد" :
      "Correction برای Reversal الزام نیست";

   ENUM_MARKET_REGIME regime_value =
      MarketRegime_IsValid(regime) ?
      regime.regime :
      MARKET_REGIME_UNKNOWN;

   if(!Scenario_Create(
         scenario_id,
         symbol,
         SCENARIO_DIRECTION_SELL,
         regime_value,
         zone,
         true,
         true,
         move.correction_valid,
         SCENARIO_ACTIVATION_REACTION,
         zone.invalidation_price,
         now,
         expiry,
         (int)Inp_TF_Context_M30,
         (int)Inp_TF_Setup_M5,
         structure.reason,
         move.reason,
         correction_reason,
         zone.reason,
         "سناریوی برگشت فروش از ساختار صعودی و حرکت نزولی خلاف ساختار",
         scenario))
     {
      result.failure_reason =
         "ساخت Scenario برای SELL Reversal ناموفق بود";

      return false;
     }

   const double entry_price =
      Zone_Midpoint(zone);

   if(entry_price <= 0.0)
     {
      Scenario_Cancel(
         scenario,
         now,
         "قیمت میانی SELL Zone معتبر نیست");

      result.failure_reason =
         "Entry پیشنهادی معتبر نیست";

      return false;
     }

   if(!Scenario_SetEntryPrice(
         scenario,
         entry_price,
         now,
         "Entry پیشنهادی SELL Reversal در میانه Zone تعیین شد"))
     {
      result.failure_reason =
         "ثبت Entry پیشنهادی SELL Reversal ناموفق بود";

      return false;
     }

   Scenario_UpdateQuality(
      scenario);

   const double strategy_quality =
      Strategy_CalculateSellReversalQuality(
         regime,
         context,
         structure,
         move,
         zone);

   scenario.quality_value =
      MathMin(
         100.0,
         MathMax(
            scenario.quality_value,
            strategy_quality));

   result.valid =
      true;

   result.type =
      STRATEGY_SELL_REVERSAL;

   result.direction =
      SCENARIO_DIRECTION_SELL;

   result.zone_id =
      zone.id;

   result.quality =
      scenario.quality_value;

   result.confidence =
      scenario.quality_value;

   result.reason =
      reason;

   scenario.general_reason =
      reason;

   Print(
      "[STRATEGY] SELL Reversal OK | Quality=",
      DoubleToString(
         scenario.quality_value,
         1),
      " | ",
      reason);

   return true;
  }

//====================================================================
// API اصلی BUY Continuation
//====================================================================
bool StrategyEngine_AnalyzeBuyContinuation(
   const string symbol,
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &buy_zone,
   const double current_price,
   TradingScenario &scenario,
   StrategyResult &result)
  {
   Strategy_Reset(result);
   Scenario_Init(scenario);

   if(!Inp_Enable_Scenarios)
     {
      result.failure_reason =
         "Scenario Engine غیرفعال است";
      return false;
     }

   if(symbol == "")
     {
      result.failure_reason =
         "Symbol معتبر نیست";
      return false;
     }

   if(current_price <= 0.0)
     {
      result.failure_reason =
         "قیمت جاری معتبر نیست";
      return false;
     }

   if(!Zone_IsValid(buy_zone))
     {
      result.failure_reason =
         "BUY Zone دریافتی معتبر نیست";
      return false;
     }

   if(buy_zone.direction !=
      ZONE_DIRECTION_BUY)
     {
      result.failure_reason =
         "Zone دریافتی BUY نیست";
      return false;
     }

   if(!Strategy_CreateBuyContinuationScenario(
         symbol,
         regime,
         context,
         structure,
         move,
         buy_zone,
         scenario,
         result))
      return false;

   if(!Scenario_Update(
         scenario,
         current_price,
         TimeCurrent()))
     {
      result.valid = false;
      result.failure_reason =
         "به‌روزرسانی وضعیت Scenario ناموفق بود";
      return false;
     }

   if(scenario.status ==
         SCENARIO_STATUS_INVALID ||
      scenario.status ==
         SCENARIO_STATUS_EXPIRED ||
      scenario.status ==
         SCENARIO_STATUS_CANCELLED)
     {
      result.valid = false;

      result.failure_reason =
         scenario.invalidation_reason;

      if(result.failure_reason == "")
         result.failure_reason =
            scenario.general_reason;

      if(result.failure_reason == "")
         result.failure_reason =
            "Scenario پس از بررسی قیمت معتبر باقی نماند";

      Print(
         "[STRATEGY] BUY Continuation INVALID | ",
         result.failure_reason);

      return false;
     }

   result.valid =
      true;

   result.type =
      STRATEGY_BUY_CONTINUATION;

   result.direction =
      SCENARIO_DIRECTION_BUY;

   result.zone_id =
      buy_zone.id;

   result.quality =
      scenario.quality_value;

   result.confidence =
      scenario.quality_value;

   return true;
  }

//====================================================================
// API اصلی SELL Continuation
//====================================================================
bool StrategyEngine_AnalyzeSellContinuation(
   const string symbol,
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &sell_zone,
   const double current_price,
   TradingScenario &scenario,
   StrategyResult &result)
  {
   Strategy_Reset(result);
   Scenario_Init(scenario);

   if(!Inp_Enable_Scenarios)
     {
      result.failure_reason =
         "Scenario Engine غیرفعال است";
      return false;
     }

   if(symbol == "")
     {
      result.failure_reason =
         "Symbol معتبر نیست";
      return false;
     }

   if(current_price <= 0.0)
     {
      result.failure_reason =
         "قیمت جاری معتبر نیست";
      return false;
     }

   if(!Zone_IsValid(sell_zone))
     {
      result.failure_reason =
         "SELL Zone دریافتی معتبر نیست";
      return false;
     }

   if(sell_zone.direction !=
      ZONE_DIRECTION_SELL)
     {
      result.failure_reason =
         "Zone دریافتی SELL نیست";
      return false;
     }

   if(!Strategy_CreateSellContinuationScenario(
         symbol,
         regime,
         context,
         structure,
         move,
         sell_zone,
         scenario,
         result))
      return false;

   if(!Scenario_Update(
         scenario,
         current_price,
         TimeCurrent()))
     {
      result.valid = false;
      result.failure_reason =
         "به‌روزرسانی وضعیت Scenario ناموفق بود";
      return false;
     }

   if(scenario.status ==
         SCENARIO_STATUS_INVALID ||
      scenario.status ==
         SCENARIO_STATUS_EXPIRED ||
      scenario.status ==
         SCENARIO_STATUS_CANCELLED)
     {
      result.valid = false;

      result.failure_reason =
         scenario.invalidation_reason;

      if(result.failure_reason == "")
         result.failure_reason =
            scenario.general_reason;

      if(result.failure_reason == "")
         result.failure_reason =
            "Scenario پس از بررسی قیمت معتبر باقی نماند";

      Print(
         "[STRATEGY] SELL Continuation INVALID | ",
         result.failure_reason);

      return false;
     }

   result.valid =
      true;

   result.type =
      STRATEGY_SELL_CONTINUATION;

   result.direction =
      SCENARIO_DIRECTION_SELL;

   result.zone_id =
      sell_zone.id;

   result.quality =
      scenario.quality_value;

   result.confidence =
      scenario.quality_value;

   return true;
  }

//====================================================================
// API اصلی BUY Reversal
//====================================================================
bool StrategyEngine_AnalyzeBuyReversal(
   const string symbol,
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &buy_zone,
   const double current_price,
   TradingScenario &scenario,
   StrategyResult &result)
  {
   Strategy_Reset(result);
   Scenario_Init(scenario);

   if(!Inp_Enable_Scenarios)
     {
      result.failure_reason =
         "Scenario Engine غیرفعال است";
      return false;
     }

   if(symbol == "")
     {
      result.failure_reason =
         "Symbol معتبر نیست";
      return false;
     }

   if(current_price <= 0.0)
     {
      result.failure_reason =
         "قیمت جاری معتبر نیست";
      return false;
     }

   if(!Zone_IsValid(buy_zone))
     {
      result.failure_reason =
         "BUY Zone دریافتی برای Reversal معتبر نیست";
      return false;
     }

   if(buy_zone.direction !=
      ZONE_DIRECTION_BUY)
     {
      result.failure_reason =
         "Zone دریافتی BUY نیست";
      return false;
     }

   if(!Strategy_CreateBuyReversalScenario(
         symbol,
         regime,
         context,
         structure,
         move,
         buy_zone,
         scenario,
         result))
      return false;

   if(!Scenario_Update(
         scenario,
         current_price,
         TimeCurrent()))
     {
      result.valid = false;
      result.failure_reason =
         "به‌روزرسانی وضعیت Scenario ناموفق بود";
      return false;
     }

   if(scenario.status ==
         SCENARIO_STATUS_INVALID ||
      scenario.status ==
         SCENARIO_STATUS_EXPIRED ||
      scenario.status ==
         SCENARIO_STATUS_CANCELLED)
     {
      result.valid = false;

      result.failure_reason =
         scenario.invalidation_reason;

      if(result.failure_reason == "")
         result.failure_reason =
            scenario.general_reason;

      if(result.failure_reason == "")
         result.failure_reason =
            "Scenario پس از بررسی قیمت معتبر باقی نماند";

      return false;
     }

   result.valid =
      true;

   result.type =
      STRATEGY_BUY_REVERSAL;

   result.direction =
      SCENARIO_DIRECTION_BUY;

   result.zone_id =
      buy_zone.id;

   result.quality =
      scenario.quality_value;

   result.confidence =
      scenario.quality_value;

   return true;
  }

//====================================================================
// API اصلی SELL Reversal
//====================================================================
bool StrategyEngine_AnalyzeSellReversal(
   const string symbol,
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const ZoneInfo &sell_zone,
   const double current_price,
   TradingScenario &scenario,
   StrategyResult &result)
  {
   Strategy_Reset(result);
   Scenario_Init(scenario);

   if(!Inp_Enable_Scenarios)
     {
      result.failure_reason =
         "Scenario Engine غیرفعال است";
      return false;
     }

   if(symbol == "")
     {
      result.failure_reason =
         "Symbol معتبر نیست";
      return false;
     }

   if(current_price <= 0.0)
     {
      result.failure_reason =
         "قیمت جاری معتبر نیست";
      return false;
     }

   if(!Zone_IsValid(sell_zone))
     {
      result.failure_reason =
         "SELL Zone دریافتی برای Reversal معتبر نیست";
      return false;
     }

   if(sell_zone.direction !=
      ZONE_DIRECTION_SELL)
     {
      result.failure_reason =
         "Zone دریافتی SELL نیست";
      return false;
     }

   if(!Strategy_CreateSellReversalScenario(
         symbol,
         regime,
         context,
         structure,
         move,
         sell_zone,
         scenario,
         result))
      return false;

   if(!Scenario_Update(
         scenario,
         current_price,
         TimeCurrent()))
     {
      result.valid = false;
      result.failure_reason =
         "به‌روزرسانی وضعیت Scenario ناموفق بود";
      return false;
     }

   if(scenario.status ==
         SCENARIO_STATUS_INVALID ||
      scenario.status ==
         SCENARIO_STATUS_EXPIRED ||
      scenario.status ==
         SCENARIO_STATUS_CANCELLED)
     {
      result.valid = false;

      result.failure_reason =
         scenario.invalidation_reason;

      if(result.failure_reason == "")
         result.failure_reason =
            scenario.general_reason;

      if(result.failure_reason == "")
         result.failure_reason =
            "Scenario پس از بررسی قیمت معتبر باقی نماند";

      return false;
     }

   result.valid =
      true;

   result.type =
      STRATEGY_SELL_REVERSAL;

   result.direction =
      SCENARIO_DIRECTION_SELL;

   result.zone_id =
      sell_zone.id;

   result.quality =
      scenario.quality_value;

   result.confidence =
      scenario.quality_value;

   return true;
  }

//====================================================================
// خلاصه Strategy
//====================================================================
string StrategyEngine_BuildSummary(
   const StrategyResult &result)
  {
   string text = "";

   text +=
      "Strategy=" +
      StrategyTypeToPersian(
         result.type);

   text +=
      " | جهت=" +
      ScenarioDirectionToPersian(
         result.direction);

   text +=
      " | Zone=" +
      (string)result.zone_id;

   text +=
      " | کیفیت=" +
      DoubleToString(
         result.quality,
         1);

   text +=
      " | اطمینان=" +
      DoubleToString(
         result.confidence,
         1) +
      "%";

   text +=
      " | وضعیت=" +
      (result.valid ?
       "معتبر" :
       "نامعتبر");

   if(result.reason != "")
      text +=
         " | دلیل=" +
         result.reason;

   if(result.failure_reason != "")
      text +=
         " | خطا=" +
         result.failure_reason;

   return text;
  }

#endif