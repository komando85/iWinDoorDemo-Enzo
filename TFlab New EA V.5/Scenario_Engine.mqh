//+------------------------------------------------------------------+
//|                    Scenario_Engine.mqh                           |
//|                    TFlab New EA V.5                              |
//|                                                                  |
//| مسئولیت: ساخت و مدیریت سناریوهای معاملاتی                        |
//| بدون اجرای سفارش، مدیریت ریسک یا اجرای Entry                     |
//|                                                                  |
//| SCENARIO ENGINE v2.30                                            |
//| اصلاح: Pullback مخالف جهت به عنوان Correction معتبر             |
//+------------------------------------------------------------------+
#ifndef __SCENARIO_ENGINE_MQH__
#define __SCENARIO_ENGINE_MQH__

#property strict

#include "EA_Inputs.mqh"
#include "Market_Regime.mqh"
#include "Market_HigherTimeframe.mqh"
#include "Market_Context.mqh"
#include "Market_Structure.mqh"
#include "Impulse_Correction.mqh"
#include "Zone_Engine.mqh"
#include "Market_Truth_Engine.mqh"

//====================================================================
// ENUMS
//====================================================================
enum ENUM_SCENARIO_DIRECTION
  {
   SCENARIO_DIRECTION_NONE = 0,
   SCENARIO_DIRECTION_BUY,
   SCENARIO_DIRECTION_SELL
  };

enum ENUM_SCENARIO_STATUS
  {
   SCENARIO_STATUS_NONE = 0,
   SCENARIO_STATUS_FORMING,
   SCENARIO_STATUS_VALID,
   SCENARIO_STATUS_ARMED,
   SCENARIO_STATUS_TRIGGERED,
   SCENARIO_STATUS_EXECUTED,
   SCENARIO_STATUS_INVALID,
   SCENARIO_STATUS_EXPIRED,
   SCENARIO_STATUS_CANCELLED
  };

enum ENUM_SCENARIO_ACTIVATION_TYPE
  {
   SCENARIO_ACTIVATION_NONE = 0,
   SCENARIO_ACTIVATION_ZONE_TOUCH,
   SCENARIO_ACTIVATION_REACTION,
   SCENARIO_ACTIVATION_BREAK,
   SCENARIO_ACTIVATION_CONFIRMATION,
   SCENARIO_ACTIVATION_CUSTOM
  };

//====================================================================
// SCENARIO STRUCTURE
//====================================================================
struct TradingScenario
  {
   ulong                           id;
   ENUM_SCENARIO_DIRECTION         direction;
   ENUM_SCENARIO_STATUS            status;
   ENUM_SCENARIO_ACTIVATION_TYPE   activation_type;

   string                          symbol;

   ENUM_MARKET_REGIME              market_regime;
   ENUM_MARKET_CONTEXT_STATE       context_state;
   ENUM_STRUCTURE_STATE             structure_state;
   ENUM_MOVE_STATE                  move_state;

   ulong                           zone_id;
   ENUM_ZONE_TYPE                  zone_type;
   double                          zone_lower;
   double                          zone_upper;

   double                          entry_price;
   double                          invalidation_price;
   double                          target_1;
   double                          target_2;
   double                          target_3;

   datetime                        created_time;
   datetime                        updated_time;
   datetime                        expiry_time;

   int                             source_timeframe;
   int                             setup_timeframe;

   bool                            structure_valid;
   bool                            impulse_valid;
   bool                            correction_valid;
   bool                            zone_valid;
   bool                            activation_ready;
   bool                            background_aligned;
   bool                            conflict_present;
   bool                            regime_aligned;

   double                          quality_value;
   double                          alignment_value;

   string                          structure_reason;
   string                          impulse_reason;
   string                          correction_reason;
   string                          zone_reason;
   string                          activation_reason;
   string                          invalidation_reason;
   string                          conflict_reason;
   string                          general_reason;
  };

TradingScenario g_scenario_book[];
int             g_scenario_count    = 0;
ulong           g_scenario_next_id  = 1;

//====================================================================
// TEXT HELPERS
//====================================================================
string ScenarioDirectionToPersian(const ENUM_SCENARIO_DIRECTION direction)
  {
   switch(direction)
     {
      case SCENARIO_DIRECTION_BUY:
         return "خرید";

      case SCENARIO_DIRECTION_SELL:
         return "فروش";

      default:
         return "بدون جهت";
     }
  }

string ScenarioStatusToPersian(const ENUM_SCENARIO_STATUS status)
  {
   switch(status)
     {
      case SCENARIO_STATUS_FORMING:
         return "در حال تشکیل";

      case SCENARIO_STATUS_VALID:
         return "معتبر";

      case SCENARIO_STATUS_ARMED:
         return "مسلح";

      case SCENARIO_STATUS_TRIGGERED:
         return "فعال شده";

      case SCENARIO_STATUS_EXECUTED:
         return "اجرا شده";

      case SCENARIO_STATUS_INVALID:
         return "باطل";

      case SCENARIO_STATUS_EXPIRED:
         return "منقضی";

      case SCENARIO_STATUS_CANCELLED:
         return "لغو شده";

      default:
         return "نامشخص";
     }
  }

string ScenarioActivationToPersian(const ENUM_SCENARIO_ACTIVATION_TYPE type)
  {
   switch(type)
     {
      case SCENARIO_ACTIVATION_ZONE_TOUCH:
         return "تماس با ناحیه";

      case SCENARIO_ACTIVATION_REACTION:
         return "واکنش";

      case SCENARIO_ACTIVATION_BREAK:
         return "شکست";

      case SCENARIO_ACTIVATION_CONFIRMATION:
         return "تأیید";

      case SCENARIO_ACTIVATION_CUSTOM:
         return "اختصاصی";

      default:
         return "بدون فعال‌سازی";
     }
  }

//====================================================================
// INIT
//====================================================================
void Scenario_Init(TradingScenario &scenario)
  {
   ZeroMemory(scenario);

   scenario.id                   = 0;
   scenario.direction            = SCENARIO_DIRECTION_NONE;
   scenario.status               = SCENARIO_STATUS_NONE;
   scenario.activation_type      = SCENARIO_ACTIVATION_NONE;

   scenario.symbol               = "";

   scenario.market_regime        = MARKET_REGIME_UNKNOWN;
   scenario.context_state        = MARKET_CONTEXT_UNKNOWN;
   scenario.structure_state      = STRUCTURE_STATE_UNKNOWN;
   scenario.move_state           = MOVE_STATE_UNKNOWN;

   scenario.zone_id              = 0;
   scenario.zone_type            = ZONE_TYPE_NONE;

   scenario.source_timeframe     = 0;
   scenario.setup_timeframe      = 0;

   scenario.structure_valid      = false;
   scenario.impulse_valid        = false;
   scenario.correction_valid     = false;
   scenario.zone_valid           = false;
   scenario.activation_ready     = false;
   scenario.background_aligned   = false;
   scenario.conflict_present     = false;
   scenario.regime_aligned       = true;

   scenario.quality_value        = 0.0;
   scenario.alignment_value      = 0.0;
  }

ulong Scenario_NextID()
  {
   return g_scenario_next_id++;
  }

//====================================================================
// REGIME ALIGNMENT
//====================================================================
bool Scenario_CheckRegimeAlignment(const ENUM_SCENARIO_DIRECTION direction,
                                   const MarketRegimeState &regime,
                                   string &reason)
  {
   if(!Inp_Enable_Regime_Filter)
     {
      reason = "فیلتر رژیم غیرفعال";
      return true;
     }

   /*
      نکته:
      Confidence پایین نباید سناریو را مسدود کند.
      در این حالت فقط به صورت اطلاع‌رسانی ادامه می‌دهیم.
   */
   if(regime.confidence < Inp_Min_Regime_Confidence)
     {
      reason = "اطمینان رژیم پایین (" +
               DoubleToString(regime.confidence,1) + "%)";
      return true;
     }

   if(direction == SCENARIO_DIRECTION_BUY)
     {
      if(regime.regime == MARKET_REGIME_DOWNTREND)
        {
         reason = "خرید در بازار نزولی (اطمینان=" +
                  DoubleToString(regime.confidence,1) + "%) رد شد";

         Print("[SCENARIO REGIME FILTER] BLOCKED | ",reason);
         return false;
        }
     }
   else
   if(direction == SCENARIO_DIRECTION_SELL)
     {
      if(regime.regime == MARKET_REGIME_UPTREND)
        {
         reason = "فروش در بازار صعودی (اطمینان=" +
                  DoubleToString(regime.confidence,1) + "%) رد شد";

         Print("[SCENARIO REGIME FILTER] BLOCKED | ",reason);
         return false;
        }
     }

   if(regime.regime == MARKET_REGIME_TRANSITION)
     {
      reason = "رژیم Transition | سناریو مجاز است";
      return true;
     }

   reason = "هم‌جهت با رژیم";
   return true;
  }

//====================================================================
// CORE DATA
//====================================================================
bool Scenario_HasCoreData(const TradingScenario &scenario)
  {
   if(scenario.id == 0)
      return false;

   if(scenario.direction == SCENARIO_DIRECTION_NONE)
      return false;

   if(scenario.symbol == "")
      return false;

   if(!scenario.zone_valid)
      return false;

   if(scenario.zone_lower <= 0.0)
      return false;

   if(scenario.zone_upper <= scenario.zone_lower)
      return false;

   if(scenario.invalidation_price <= 0.0)
      return false;

   /*
      حداقل یکی از این دو بخش باید معتبر باشد:
      Structure یا Impulse
   */
   if(!scenario.structure_valid && !scenario.impulse_valid)
      return false;

   return true;
  }

//====================================================================
// VALIDITY
//====================================================================
bool Scenario_IsValid(const TradingScenario &scenario,
                      const bool strict = false)
  {
   if(!Scenario_HasCoreData(scenario))
      return false;

   if(scenario.status == SCENARIO_STATUS_INVALID ||
      scenario.status == SCENARIO_STATUS_EXPIRED ||
      scenario.status == SCENARIO_STATUS_CANCELLED)
      return false;

   if(strict && scenario.quality_value < 30.0)
      return false;

   return true;
  }

//====================================================================
// HIGHER TIMEFRAME BACKGROUND
//====================================================================
int Scenario_GetBackgroundDirection()
  {
   ENUM_HTF_DIRECTION d = GetHigherTimeframeDirection();

   if(d == HTF_DIRECTION_BULLISH)
      return 1;

   if(d == HTF_DIRECTION_BEARISH)
      return -1;

   return 0;
  }

bool Scenario_BackgroundAllows(const ENUM_SCENARIO_DIRECTION direction)
  {
   if(Inp_Allow_Contrary_Background)
      return true;

   int bg = Scenario_GetBackgroundDirection();

   if(bg == 0)
      return true;

   if(direction == SCENARIO_DIRECTION_BUY && bg > 0)
      return true;

   if(direction == SCENARIO_DIRECTION_SELL && bg < 0)
      return true;

   return false;
  }

//====================================================================
// NEW: MOVE COMPATIBILITY
//
// نکته کلیدی:
// حرکت خلاف جهت سناریو می‌تواند Pullback/Correction باشد.
//
// SELL + IMPULSE_UP + CorrectionValid = Pullback معتبر برای SELL
// BUY  + IMPULSE_DOWN + CorrectionValid = Pullback معتبر برای BUY
//====================================================================
bool Scenario_MoveSupportsDirection(const ENUM_SCENARIO_DIRECTION direction,
                                    const ENUM_STRUCTURE_STATE structure_state,
                                    const ImpulseCorrectionSnapshot &move,
                                    string &reason)
  {
   reason = "";

   if(direction == SCENARIO_DIRECTION_NONE)
     {
      reason = "جهت سناریو مشخص نیست";
      return false;
     }

   //--- حرکت هم‌جهت مستقیم
   if(direction == SCENARIO_DIRECTION_BUY)
     {
      if(move.state == MOVE_STATE_IMPULSE_UP ||
         move.state == MOVE_STATE_CORRECTION_UP)
        {
         reason = "حرکت هم‌جهت BUY";
         return true;
        }

      /*
         اگر ساختار صعودی نیست ولی اصلاح نزولی معتبر داریم،
         می‌تواند فرصت بازگشت به BUY Zone باشد.
      */
      if(move.correction_valid &&
         (move.state == MOVE_STATE_IMPULSE_DOWN ||
          move.state == MOVE_STATE_CORRECTION_DOWN))
        {
         reason = "حرکت مخالف ولی به عنوان Pullback معتبر برای BUY";
         return true;
        }
     }

   if(direction == SCENARIO_DIRECTION_SELL)
     {
      if(move.state == MOVE_STATE_IMPULSE_DOWN ||
         move.state == MOVE_STATE_CORRECTION_DOWN)
        {
         reason = "حرکت هم‌جهت SELL";
         return true;
        }

      /*
         اصلاح بسیار مهم:
         در ساختار نزولی، حرکت صعودی می‌تواند Pullback باشد.
         بنابراین SELL نباید صرفاً به خاطر ImpulseDir=UP رد شود.
      */
      if(move.correction_valid &&
         (move.state == MOVE_STATE_IMPULSE_UP ||
          move.state == MOVE_STATE_CORRECTION_UP))
        {
         if(structure_state == STRUCTURE_STATE_BEARISH ||
            structure_state == STRUCTURE_STATE_TRANSITION ||
            structure_state == STRUCTURE_STATE_BALANCED)
           {
            reason = "حرکت صعودی مخالف ولی Pullback معتبر برای SELL";
            return true;
           }
        }
     }

   /*
      Transition:
      در صورت معتبر بودن Correction، فرصت را مسدود نمی‌کنیم.
   */
   if(move.correction_valid)
     {
      reason = "حرکت Transition با Correction معتبر";
      return true;
     }

   reason = "حرکت برای جهت سناریو سازگار نیست";
   return false;
  }

//====================================================================
// ALIGNMENT SCORE
//====================================================================
double Scenario_CalculateAlignment(const ENUM_SCENARIO_DIRECTION direction,
                                   const MarketRegimeState &regime,
                                   const MarketContextSnapshot &context,
                                   const MarketStructureSnapshot &structure,
                                   const ImpulseCorrectionSnapshot &move,
                                   const ZoneInfo &zone)
  {
   double value = 0.0;

   int dir = (direction == SCENARIO_DIRECTION_BUY ? 1 : -1);

   //=================================================================
   // REGIME
   //=================================================================
   if((dir > 0 && regime.regime == MARKET_REGIME_UPTREND) ||
      (dir < 0 && regime.regime == MARKET_REGIME_DOWNTREND))
     {
      value += 20.0;
     }
   else
   if(regime.regime == MARKET_REGIME_TRANSITION)
     {
      value += 10.0;
     }
   else
   if(regime.regime == MARKET_REGIME_RANGE)
     {
      value += 8.0;
     }
   else
   if(regime.regime == MARKET_REGIME_UNCERTAIN)
     {
      value += 5.0;
     }

   //=================================================================
   // CONTEXT
   //=================================================================
   if((dir > 0 && context.state == MARKET_CONTEXT_BULLISH_PRESSURE) ||
      (dir < 0 && context.state == MARKET_CONTEXT_BEARISH_PRESSURE))
     {
      value += 15.0;
     }
   else
   if(context.state == MARKET_CONTEXT_EXPANDING)
     {
      value += 8.0;
     }

   //=================================================================
   // STRUCTURE
   //=================================================================
   if((dir > 0 && structure.state == STRUCTURE_STATE_BULLISH) ||
      (dir < 0 && structure.state == STRUCTURE_STATE_BEARISH))
     {
      value += 25.0;
     }
   else
   if(structure.state == STRUCTURE_STATE_BALANCED)
     {
      value += 15.0;
     }
   else
   if(structure.state == STRUCTURE_STATE_TRANSITION)
     {
      value += 10.0;
     }

   //=================================================================
   // MOVE
   //
   // نکته کلیدی:
   // حرکت Pullback مخالف جهت نیز امتیاز می‌گیرد.
   //=================================================================
   if(direction == SCENARIO_DIRECTION_BUY)
     {
      if(move.state == MOVE_STATE_IMPULSE_UP ||
         move.state == MOVE_STATE_CORRECTION_UP)
        {
         value += 20.0;
        }
      else
      if(move.correction_valid &&
         (move.state == MOVE_STATE_IMPULSE_DOWN ||
          move.state == MOVE_STATE_CORRECTION_DOWN))
        {
         value += 16.0;
        }
     }
   else
   if(direction == SCENARIO_DIRECTION_SELL)
     {
      if(move.state == MOVE_STATE_IMPULSE_DOWN ||
         move.state == MOVE_STATE_CORRECTION_DOWN)
        {
         value += 20.0;
        }
      else
      if(move.correction_valid &&
         (move.state == MOVE_STATE_IMPULSE_UP ||
          move.state == MOVE_STATE_CORRECTION_UP))
        {
         /*
            Pullback صعودی داخل ساختار نزولی:
            امتیاز کمتر از حرکت نزولی مستقیم،
            اما همچنان معتبر.
         */
         value += 18.0;
        }
     }

   //=================================================================
   // ZONE
   //=================================================================
   if(zone.direction == (dir > 0 ?
                        ZONE_DIRECTION_BUY :
                        ZONE_DIRECTION_SELL))
     {
      value += 20.0;
     }

   return MathMin(100.0,value);
  }

//====================================================================
// CREATE SCENARIO
//====================================================================
bool Scenario_Create(
   const ulong scenario_id,
   const string symbol,
   const ENUM_SCENARIO_DIRECTION direction,
   const ENUM_MARKET_REGIME regime,
   const ZoneInfo &zone,
   const bool structure_valid,
   const bool impulse_valid,
   const bool correction_valid,
   const ENUM_SCENARIO_ACTIVATION_TYPE activation_type,
   const double invalidation_price,
   const datetime created_time,
   const datetime expiry_time,
   const int source_timeframe,
   const int setup_timeframe,
   const string structure_reason,
   const string impulse_reason,
   const string correction_reason,
   const string zone_reason,
   const string general_reason,
   TradingScenario &scenario)
  {
   Scenario_Init(scenario);

   if(symbol == "" ||
      direction == SCENARIO_DIRECTION_NONE ||
      !Zone_IsValid(zone))
      return false;

   scenario.id                  = scenario_id;
   scenario.direction           = direction;
   scenario.status              = SCENARIO_STATUS_FORMING;
   scenario.activation_type     = activation_type;
   scenario.symbol              = symbol;
   scenario.market_regime       = regime;

   scenario.context_state       = MARKET_CONTEXT_UNKNOWN;
   scenario.structure_state     = STRUCTURE_STATE_UNKNOWN;

   scenario.move_state =
      (direction == SCENARIO_DIRECTION_BUY ?
       MOVE_STATE_IMPULSE_UP :
       MOVE_STATE_IMPULSE_DOWN);

   scenario.zone_id             = zone.id;
   scenario.zone_type           = zone.type;
   scenario.zone_lower          = zone.lower_price;
   scenario.zone_upper          = zone.upper_price;

   scenario.entry_price =
      Zone_Midpoint(zone);

   scenario.invalidation_price =
      invalidation_price > 0.0 ?
      invalidation_price :
      zone.invalidation_price;

   scenario.created_time =
      created_time > 0 ?
      created_time :
      TimeCurrent();

   scenario.updated_time =
      scenario.created_time;

   scenario.expiry_time         = expiry_time;

   scenario.source_timeframe    = source_timeframe;
   scenario.setup_timeframe     = setup_timeframe;

   scenario.structure_valid     = structure_valid;
   scenario.impulse_valid       = impulse_valid;
   scenario.correction_valid    = correction_valid;
   scenario.zone_valid          = true;

   scenario.structure_reason    = structure_reason;
   scenario.impulse_reason      = impulse_reason;
   scenario.correction_reason   = correction_reason;
   scenario.zone_reason         = zone_reason;
   scenario.general_reason      = general_reason;

   scenario.background_aligned  =
      Scenario_BackgroundAllows(direction);

   scenario.alignment_value     = 0.0;
   scenario.quality_value       = 0.0;
   scenario.regime_aligned      = true;

   if(!scenario.background_aligned)
     {
      scenario.conflict_present = true;

      scenario.conflict_reason =
         "جهت سناریو با زمینه H4/H1 هم‌راستا نیست";
     }

   if(Scenario_HasCoreData(scenario) &&
      scenario.background_aligned)
     {
      scenario.status = SCENARIO_STATUS_VALID;
     }

   return true;
  }

//====================================================================
// BOOK INIT
//====================================================================
void ScenarioBook_Init()
  {
   ArrayResize(g_scenario_book,0);

   g_scenario_count   = 0;
   g_scenario_next_id = 1;
  }

//====================================================================
// CREATE FROM EVIDENCE
//====================================================================
bool Scenario_CreateFromEvidence(const string symbol,
                                 const ENUM_SCENARIO_DIRECTION direction,
                                 const MarketRegimeState &regime,
                                 const MarketContextSnapshot &context,
                                 const MarketStructureSnapshot &structure,
                                 const ImpulseCorrectionSnapshot &move,
                                 const ZoneInfo &zone,
                                 TradingScenario &scenario)
  {
   Scenario_Init(scenario);

   if(!Inp_Enable_Scenarios)
      return false;

   if(symbol == "" ||
      direction == SCENARIO_DIRECTION_NONE)
      return false;

   if(!Zone_IsValid(zone))
      return false;

   //=================================================================
   // REGIME FILTER
   //=================================================================
   string regime_reason = "";

   if(!Scenario_CheckRegimeAlignment(direction,
                                     regime,
                                     regime_reason))
     {
      Print("[SCENARIO] REJECTED | ",
            regime_reason,
            " | جهت=",
            ScenarioDirectionToPersian(direction),
            " | Regime=",
            MarketRegime_ToPersian(regime.regime));

      return false;
     }

   //=================================================================
   // MOVE COMPATIBILITY
   //=================================================================
   string move_reason = "";

   bool move_supported =
      Scenario_MoveSupportsDirection(direction,
                                     structure.state,
                                     move,
                                     move_reason);

   /*
      نکته:
      عدم سازگاری Move به تنهایی سناریو را رد نمی‌کند،
      زیرا Structure + Zone + Background می‌توانند همچنان
      سناریوی معتبر بسازند.

      اینجا فقط Diagnostic ثبت می‌شود.
   */
   if(!move_supported)
     {
      Print("[SCENARIO MOVE] INFO | جهت=",
            ScenarioDirectionToPersian(direction),
            " | Move=",
            ImpulseCorrection_StateToPersian(move.state),
            " | CorrectionValid=",
            move.correction_valid,
            " | دلیل=",
            move_reason);
     }
   else
     {
      Print("[SCENARIO MOVE] ACCEPTED | جهت=",
            ScenarioDirectionToPersian(direction),
            " | Move=",
            ImpulseCorrection_StateToPersian(move.state),
            " | CorrectionValid=",
            move.correction_valid,
            " | دلیل=",
            move_reason);
     }

   //=================================================================
   // INITIALIZE SCENARIO
   //=================================================================
   scenario.id =
      g_scenario_next_id++;

   scenario.direction =
      direction;

   scenario.status =
      SCENARIO_STATUS_FORMING;

   scenario.activation_type =
      SCENARIO_ACTIVATION_ZONE_TOUCH;

   scenario.symbol =
      symbol;

   scenario.market_regime =
      regime.regime;

   scenario.context_state =
      context.state;

   scenario.structure_state =
      structure.state;

   /*
      بسیار مهم:
      دیگر جهت سناریو را کورکورانه به حرکت تبدیل نمی‌کنیم.
      حرکت واقعی از Snapshot حفظ می‌شود.
   */
   scenario.move_state =
      move.state;

   scenario.zone_id =
      zone.id;

   scenario.zone_type =
      zone.type;

   scenario.zone_lower =
      zone.lower_price;

   scenario.zone_upper =
      zone.upper_price;

   scenario.entry_price =
      Zone_Midpoint(zone);

   scenario.invalidation_price =
      zone.invalidation_price;

   scenario.created_time =
      TimeCurrent();

   scenario.updated_time =
      scenario.created_time;

   scenario.expiry_time =
      datetime((long)scenario.created_time +
               (long)Inp_Scenario_Max_Age_Minutes * 60);

   scenario.source_timeframe =
      (int)Inp_TF_Context_M30;

   scenario.setup_timeframe =
      (int)Inp_TF_Setup_M5;

   scenario.structure_valid =
      MarketStructure_IsValid(structure);

   scenario.impulse_valid =
      move.impulse_valid;

   scenario.correction_valid =
      move.correction_valid;

   scenario.zone_valid =
      Zone_IsValid(zone);

   scenario.structure_reason =
      structure.reason;

   scenario.impulse_reason =
      move.reason;

   scenario.correction_reason =
      move.correction_valid ?
      "اصلاح معتبر" :
      "اصلاح مستقل تأیید نشده";

   scenario.zone_reason =
      zone.reason;

   scenario.background_aligned =
      Scenario_BackgroundAllows(direction);

   scenario.alignment_value =
      Scenario_CalculateAlignment(direction,
                                  regime,
                                  context,
                                  structure,
                                  move,
                                  zone);

   /*
      اگر Pullback مخالف جهت وجود دارد، امتیاز تکمیلی
      اضافه می‌شود اما از ساختار بالاتر نمی‌رود.
   */
   if(move_supported &&
      move.correction_valid)
     {
      if(direction == SCENARIO_DIRECTION_SELL &&
         structure.state == STRUCTURE_STATE_BEARISH &&
         (move.state == MOVE_STATE_IMPULSE_UP ||
          move.state == MOVE_STATE_CORRECTION_UP))
        {
         scenario.alignment_value =
            MathMin(100.0,
                    scenario.alignment_value + 5.0);

         scenario.general_reason =
            "ساختار نزولی + Pullback صعودی معتبر برای SELL";
        }

      if(direction == SCENARIO_DIRECTION_BUY &&
         structure.state == STRUCTURE_STATE_BULLISH &&
         (move.state == MOVE_STATE_IMPULSE_DOWN ||
          move.state == MOVE_STATE_CORRECTION_DOWN))
        {
         scenario.alignment_value =
            MathMin(100.0,
                    scenario.alignment_value + 5.0);

         scenario.general_reason =
            "ساختار صعودی + Pullback نزولی معتبر برای BUY";
        }
     }

   scenario.quality_value =
      scenario.alignment_value;

   scenario.regime_aligned =
      true;

   //=================================================================
   // BACKGROUND CONFLICT
   //=================================================================
   if(!scenario.background_aligned)
     {
      scenario.conflict_present =
         true;

      scenario.conflict_reason =
         "جهت سناریو با زمینه H4/H1 هم‌راستا نیست";
     }

   //=================================================================
   // CORE VALIDATION
   //=================================================================
   if(Scenario_HasCoreData(scenario) &&
      scenario.background_aligned)
     {
      scenario.status =
         SCENARIO_STATUS_VALID;

      if(scenario.general_reason == "")
        {
         scenario.general_reason =
            "ساختار، حرکت و Zone برای سناریو هم‌زمان معتبر هستند";
        }
     }
   else
     {
      scenario.status =
         SCENARIO_STATUS_FORMING;

      if(scenario.general_reason == "")
        {
         scenario.general_reason =
            "سناریو تشکیل شده ولی هنوز کامل یا هم‌راستا نیست";
        }
     }

   //=================================================================
   // DETAILED DIAGNOSTIC
   //=================================================================
   Print("[SCENARIO EVIDENCE] ",
         ScenarioDirectionToPersian(direction),
         " | Structure=",
         scenario.structure_valid,
         " | Impulse=",
         scenario.impulse_valid,
         " | Correction=",
         scenario.correction_valid,
         " | MoveSupport=",
         move_supported,
         " | Background=",
         scenario.background_aligned,
         " | Alignment=",
         DoubleToString(scenario.alignment_value,1),
         " | Status=",
         ScenarioStatusToPersian(scenario.status));

   return true;
  }

//====================================================================
// BOOK ADD
//====================================================================
bool ScenarioBook_Add(const TradingScenario &scenario)
  {
   if(!Scenario_HasCoreData(scenario))
      return false;

   for(int i = 0; i < g_scenario_count; i++)
     {
      if(g_scenario_book[i].status == SCENARIO_STATUS_INVALID ||
         g_scenario_book[i].status == SCENARIO_STATUS_EXPIRED ||
         g_scenario_book[i].status == SCENARIO_STATUS_CANCELLED)
         continue;

      bool same_key =
         g_scenario_book[i].symbol ==
         scenario.symbol &&
         g_scenario_book[i].direction ==
         scenario.direction &&
         g_scenario_book[i].zone_id ==
         scenario.zone_id;

      if(same_key)
        {
         ulong preserved_id =
            g_scenario_book[i].id;

         datetime preserved_created =
            g_scenario_book[i].created_time;

         g_scenario_book[i] =
            scenario;

         g_scenario_book[i].id =
            preserved_id;

         if(preserved_created > 0)
            g_scenario_book[i].created_time =
               preserved_created;

         g_scenario_book[i].updated_time =
            TimeCurrent();

         g_scenario_book[i].general_reason +=
            " | فرصت هم‌کلید Repriced/Updated شد";

         return true;
        }
     }

   if(g_scenario_count >=
      Inp_Max_Active_Scenarios)
      return false;

   int n =
      g_scenario_count + 1;

   if(ArrayResize(g_scenario_book,n) != n)
      return false;

   g_scenario_book[g_scenario_count] =
      scenario;

   g_scenario_count =
      n;

   return true;
  }

//====================================================================
// REMOVE DEAD
//====================================================================
void ScenarioBook_RemoveDead()
  {
   int w = 0;

   for(int i = 0; i < g_scenario_count; i++)
     {
      TradingScenario s =
         g_scenario_book[i];

      if(s.status == SCENARIO_STATUS_INVALID ||
         s.status == SCENARIO_STATUS_EXPIRED ||
         s.status == SCENARIO_STATUS_CANCELLED)
         continue;

      if(w != i)
         g_scenario_book[w] = s;

      w++;
     }

   if(w != g_scenario_count)
      ArrayResize(g_scenario_book,w);

   g_scenario_count = w;
  }

//====================================================================
// PRICE INSIDE ZONE
//====================================================================
bool Scenario_PriceInsideZone(const TradingScenario &scenario,
                              const double price)
  {
   if(!Scenario_IsValid(scenario))
      return false;

   return
      (price >= scenario.zone_lower &&
       price <= scenario.zone_upper);
  }

//====================================================================
// INVALIDATION
//====================================================================
bool Scenario_PriceInvalidated(const TradingScenario &scenario,
                               const double price)
  {
   if(!Scenario_HasCoreData(scenario) ||
      price <= 0.0)
      return false;

   if(scenario.direction ==
      SCENARIO_DIRECTION_BUY &&
      price < scenario.invalidation_price)
      return true;

   if(scenario.direction ==
      SCENARIO_DIRECTION_SELL &&
      price > scenario.invalidation_price)
      return true;

   return false;
  }

//====================================================================
// ARM
//====================================================================
bool Scenario_Arm(TradingScenario &scenario,
                  const double price,
                  const datetime now,
                  const string reason)
  {
   if(!Scenario_IsValid(scenario) ||
      !Scenario_PriceInsideZone(scenario,price))
      return false;

   scenario.status =
      SCENARIO_STATUS_ARMED;

   scenario.activation_ready =
      true;

   scenario.updated_time =
      now;

   scenario.activation_reason =
      reason;

   return true;
  }

//====================================================================
// TRIGGER
//====================================================================
bool Scenario_Trigger(TradingScenario &scenario,
                      const double price,
                      const datetime now,
                      const string reason)
  {
   if(scenario.status !=
      SCENARIO_STATUS_ARMED ||
      price <= 0.0)
      return false;

   scenario.status =
      SCENARIO_STATUS_TRIGGERED;

   scenario.activation_ready =
      false;

   scenario.updated_time =
      now;

   scenario.activation_reason =
      reason;

   return true;
  }

//====================================================================
// INVALIDATE
//====================================================================
bool Scenario_Invalidate(TradingScenario &scenario,
                         const datetime now,
                         const string reason)
  {
   if(scenario.status ==
      SCENARIO_STATUS_EXECUTED ||
      scenario.status ==
      SCENARIO_STATUS_INVALID)
      return false;

   scenario.status =
      SCENARIO_STATUS_INVALID;

   scenario.updated_time =
      now;

   scenario.invalidation_reason =
      reason;

   scenario.activation_ready =
      false;

   return true;
  }

//====================================================================
// EXPIRE
//====================================================================
bool Scenario_Expire(TradingScenario &scenario,
                     const datetime now,
                     const string reason)
  {
   if(scenario.status ==
      SCENARIO_STATUS_EXECUTED ||
      scenario.status ==
      SCENARIO_STATUS_INVALID ||
      scenario.status ==
      SCENARIO_STATUS_EXPIRED)
      return false;

   scenario.status =
      SCENARIO_STATUS_EXPIRED;

   scenario.updated_time =
      now;

   scenario.general_reason =
      reason;

   scenario.activation_ready =
      false;

   return true;
  }

//====================================================================
// CANCEL
//====================================================================
bool Scenario_Cancel(TradingScenario &scenario,
                     const datetime now,
                     const string reason)
  {
   if(scenario.status ==
      SCENARIO_STATUS_EXECUTED ||
      scenario.status ==
      SCENARIO_STATUS_INVALID ||
      scenario.status ==
      SCENARIO_STATUS_EXPIRED ||
      scenario.status ==
      SCENARIO_STATUS_CANCELLED)
      return false;

   scenario.status =
      SCENARIO_STATUS_CANCELLED;

   scenario.updated_time =
      now;

   scenario.general_reason =
      reason;

   scenario.activation_ready =
      false;

   return true;
  }

//====================================================================
// UPDATE
//====================================================================
bool Scenario_Update(TradingScenario &scenario,
                     const double current_price,
                     const datetime now)
  {
   if(scenario.status ==
      SCENARIO_STATUS_INVALID ||
      scenario.status ==
      SCENARIO_STATUS_EXPIRED ||
      scenario.status ==
      SCENARIO_STATUS_CANCELLED)
      return false;

   if(now <= 0)
      return false;

   scenario.updated_time =
      now;

   if(scenario.expiry_time > 0 &&
      now >= scenario.expiry_time)
     {
      return Scenario_Expire(
         scenario,
         now,
         "زمان اعتبار سناریو پایان یافت");
     }

   if(Scenario_PriceInvalidated(
         scenario,
         current_price))
     {
      return Scenario_Invalidate(
         scenario,
         now,
         "قیمت از سطح ابطال عبور کرد");
     }

   if((scenario.status ==
       SCENARIO_STATUS_VALID ||
       scenario.status ==
       SCENARIO_STATUS_FORMING) &&
      Scenario_PriceInsideZone(
         scenario,
         current_price))
     {
      return Scenario_Arm(
         scenario,
         current_price,
         now,
         "قیمت وارد Zone سناریو شد");
     }

   return true;
  }

//====================================================================
// QUALITY
//====================================================================
double Scenario_CalculateQuality(
   const TradingScenario &scenario)
  {
   if(!Scenario_HasCoreData(scenario))
      return 0.0;

   double value = 0.0;

   if(scenario.structure_valid)
      value += 25.0;

   if(scenario.impulse_valid)
      value += 25.0;

   if(scenario.correction_valid)
      value += 15.0;

   if(scenario.zone_valid)
      value += 25.0;

   if(scenario.background_aligned)
      value += 10.0;

   return MathMin(100.0,value);
  }

void Scenario_UpdateQuality(
   TradingScenario &scenario)
  {
   scenario.quality_value =
      Scenario_CalculateQuality(scenario);
  }

//====================================================================
// ENTRY PRICE
//====================================================================
bool Scenario_SetEntryPrice(
   TradingScenario &scenario,
   const double entry_price,
   const datetime now,
   const string reason)
  {
   if(entry_price <= 0.0)
      return false;

   if(scenario.status ==
      SCENARIO_STATUS_INVALID ||
      scenario.status ==
      SCENARIO_STATUS_EXPIRED ||
      scenario.status ==
      SCENARIO_STATUS_CANCELLED ||
      scenario.status ==
      SCENARIO_STATUS_EXECUTED)
      return false;

   scenario.entry_price =
      entry_price;

   scenario.updated_time =
      now;

   if(reason != "")
      scenario.general_reason =
         reason;

   return true;
  }

//====================================================================
// TARGETS
//====================================================================
bool Scenario_SetTargets(
   TradingScenario &scenario,
   const double t1,
   const double t2,
   const double t3,
   const datetime now)
  {
   if(t1 <= 0.0)
      return false;

   scenario.target_1 =
      t1;

   scenario.target_2 =
      t2;

   scenario.target_3 =
      t3;

   scenario.updated_time =
      now;

   return true;
  }

//====================================================================
// TARGET DIRECTION
//====================================================================
bool Scenario_ValidateTargetDirection(
   const TradingScenario &scenario,
   const double target)
  {
   if(target <= 0.0 ||
      scenario.entry_price <= 0.0)
      return false;

   if(scenario.direction ==
      SCENARIO_DIRECTION_BUY)
      return target > scenario.entry_price;

   if(scenario.direction ==
      SCENARIO_DIRECTION_SELL)
      return target < scenario.entry_price;

   return false;
  }

//====================================================================
// MARK EXECUTED
//====================================================================
bool Scenario_MarkExecuted(
   TradingScenario &scenario,
   const datetime now,
   const string reason)
  {
   if(scenario.status !=
      SCENARIO_STATUS_TRIGGERED)
      return false;

   scenario.status =
      SCENARIO_STATUS_EXECUTED;

   scenario.updated_time =
      now;

   if(reason != "")
      scenario.general_reason =
         reason;

   return true;
  }

//====================================================================
// MAIN ANALYSIS
//====================================================================
bool ScenarioEngine_Analyze(
   const string symbol,
   const MarketRegimeState &regime,
   const MarketContextSnapshot &context,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const double current_price,
   TradingScenario &best_scenario)
  {
   Scenario_Init(best_scenario);

   if(!Inp_Enable_Scenarios)
      return false;

   ScenarioBook_RemoveDead();

   //=================================================================
   // ZONES
   //=================================================================
   ZoneInfo buy_zone;
   ZoneInfo sell_zone;

   Zone_Init(buy_zone);
   Zone_Init(sell_zone);

   bool has_buy =
      ZoneEngine_GetNearestBuy(buy_zone);

   bool has_sell =
      ZoneEngine_GetNearestSell(sell_zone);

   //=================================================================
   // CANDIDATES
   //=================================================================
   TradingScenario buy_candidate;
   TradingScenario sell_candidate;

   Scenario_Init(buy_candidate);
   Scenario_Init(sell_candidate);

   double buy_quality  = -1.0;
   double sell_quality = -1.0;

   //=================================================================
   // REGIME DIAGNOSTIC
   //=================================================================
   Print("[SCENARIO] Regime=",
         MarketRegime_ToPersian(regime.regime),
         " | Confidence=",
         DoubleToString(regime.confidence,1),
         "%",
         " | has_buy=",
         has_buy,
         " | has_sell=",
         has_sell);

   //=================================================================
   // BUY
   //=================================================================
   if(has_buy)
     {
      if(Scenario_CreateFromEvidence(
            symbol,
            SCENARIO_DIRECTION_BUY,
            regime,
            context,
            structure,
            move,
            buy_zone,
            buy_candidate))
        {
         if(Scenario_HasCoreData(buy_candidate))
           {
            buy_quality =
               buy_candidate.alignment_value;
           }
        }
      else
        {
         Print("[SCENARIO BUY] Candidate creation failed");
        }
     }

   //=================================================================
   // SELL
   //=================================================================
   if(has_sell)
     {
      if(Scenario_CreateFromEvidence(
            symbol,
            SCENARIO_DIRECTION_SELL,
            regime,
            context,
            structure,
            move,
            sell_zone,
            sell_candidate))
        {
         if(Scenario_HasCoreData(sell_candidate))
           {
            sell_quality =
               sell_candidate.alignment_value;
           }
        }
      else
        {
         Print("[SCENARIO SELL] Candidate creation failed");
        }
     }

   //=================================================================
   // CANDIDATE DIAGNOSTIC
   //=================================================================
   Print("[SCENARIO CANDIDATE] BUY=",
         (buy_quality >= 0.0 ? "PASS" : "FAIL"),
         " | Score=",
         DoubleToString(
            buy_quality >= 0.0 ?
            buy_quality : 0.0,
            1),
         " | SELL=",
         (sell_quality >= 0.0 ? "PASS" : "FAIL"),
         " | Score=",
         DoubleToString(
            sell_quality >= 0.0 ?
            sell_quality : 0.0,
            1),
         " | Structure=",
         MarketStructure_StateToPersian(
            structure.state),
         " | Move=",
         ImpulseCorrection_StateToPersian(
            move.state),
         " | Correction=",
         move.correction_valid);

   //=================================================================
   // NOTHING VALID
   //=================================================================
   if(buy_quality < 0.0 &&
      sell_quality < 0.0)
     {
      Print("[SCENARIO] هیچ سناریوی معتبری ساخته نشد");

      return false;
     }

   //=================================================================
   // BEST SCENARIO
   //=================================================================
   if(buy_quality >= sell_quality)
     {
      best_scenario =
         buy_candidate;
     }
   else
     {
      best_scenario =
         sell_candidate;
     }

   //=================================================================
   // CORE
   //=================================================================
   if(Scenario_HasCoreData(
         best_scenario))
     {
      Scenario_UpdateQuality(
         best_scenario);

      Scenario_Update(
         best_scenario,
         current_price,
         TimeCurrent());

      ScenarioBook_Add(
         best_scenario);

      Print("[SCENARIO] بهترین سناریو: ",
            ScenarioDirectionToPersian(
               best_scenario.direction),
            " | کیفیت=",
            DoubleToString(
               best_scenario.quality_value,
               1),
            " | Alignment=",
            DoubleToString(
               best_scenario.alignment_value,
               1),
            " | Status=",
            ScenarioStatusToPersian(
               best_scenario.status));

      return true;
     }

   return false;
  }

//====================================================================
// TEXT
//====================================================================
string Scenario_ToText(
   const TradingScenario &scenario)
  {
   int digits =
      (int)SymbolInfoInteger(
         scenario.symbol,
         SYMBOL_DIGITS);

   string text =
      "Scenario Engine v2.30";

   text +=
      " | شناسه=" +
      (string)scenario.id;

   text +=
      " | جهت=" +
      ScenarioDirectionToPersian(
         scenario.direction);

   text +=
      " | وضعیت=" +
      ScenarioStatusToPersian(
         scenario.status);

   text +=
      " | Regime=" +
      MarketRegime_ToPersian(
         scenario.market_regime);

   text +=
      " | Context=" +
      MarketContext_ToPersian(
         scenario.context_state);

   text +=
      " | ساختار=" +
      MarketStructure_StateToPersian(
         scenario.structure_state);

   text +=
      " | حرکت=" +
      ImpulseCorrection_StateToPersian(
         scenario.move_state);

   text +=
      " | Zone=" +
      (string)scenario.zone_id;

   text +=
      " | نوع Zone=" +
      ZoneTypeToPersian(
         scenario.zone_type);

   text +=
      " | ناحیه=" +
      DoubleToString(
         scenario.zone_lower,
         digits) +
      " تا " +
      DoubleToString(
         scenario.zone_upper,
         digits);

   text +=
      " | ورود پیشنهادی=" +
      DoubleToString(
         scenario.entry_price,
         digits);

   text +=
      " | ابطال=" +
      DoubleToString(
         scenario.invalidation_price,
         digits);

   text +=
      " | کیفیت=" +
      DoubleToString(
         scenario.quality_value,
         1);

   text +=
      " | هم‌راستایی=" +
      DoubleToString(
         scenario.alignment_value,
         1);

   text +=
      " | زمینه=" +
      (scenario.background_aligned ?
       "هم‌راستا" :
       "متعارض");

   if(scenario.general_reason != "")
      text +=
         " | دلیل=" +
         scenario.general_reason;

   if(scenario.conflict_reason != "")
      text +=
         " | تعارض=" +
         scenario.conflict_reason;

   return text;
  }

//====================================================================
// SUMMARY
//====================================================================
string ScenarioEngine_BuildSummary(
   const TradingScenario &scenario)
  {
   if(!Scenario_HasCoreData(scenario))
      return "Scenario Engine | سناریوی کامل وجود ندارد";

   return Scenario_ToText(scenario);
  }

//====================================================================
// ACTIVE COUNT
//====================================================================
int ScenarioEngine_CountActive()
  {
   int count = 0;

   for(int i = 0;
       i < g_scenario_count;
       i++)
     {
      TradingScenario s =
         g_scenario_book[i];

      if(Scenario_IsValid(s))
         count++;
     }

   return count;
  }

//====================================================================
#endif
//====================================================================