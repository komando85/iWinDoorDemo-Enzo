#ifndef __TFLAB_AI_DATA_MQH__
#define __TFLAB_AI_DATA_MQH__

//+------------------------------------------------------------------+
//|                          AI_Data.mqh                             |
//|                          TFlab New EA V.5                            |
//|                                                                  |
//| مسئولیت: لایه داده هوش مصنوعی                                   |
//|                                                                  |
//| این فایل فقط برای جمع‌آوری، نگهداری و آماده‌سازی داده‌های مورد   |
//| نیاز سیستم یادگیری است.                                          |
//| هیچ تصمیم معاملاتی، اجرای سفارش یا تغییر منطق ربات انجام نمی‌دهد.|
//|                                                                  |
//| v2.1 - Fixed TimeLocal + Average calc + Fee field + لاگ        |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// نوع رکورد داده AI
//====================================================================
enum ENUM_AI_DATA_TYPE
  {
   AI_DATA_UNKNOWN = 0,
   AI_DATA_MARKET_OBSERVATION,
   AI_DATA_TRADE_REAL,
   AI_DATA_TRADE_VIRTUAL,
   AI_DATA_REJECTED_OPPORTUNITY,
   AI_DATA_SCENARIO,
   AI_DATA_DECISION,
   AI_DATA_OUTCOME
  };

//====================================================================
// جهت
//====================================================================
enum ENUM_AI_DIRECTION
  {
   AI_DIRECTION_NONE = 0,
   AI_DIRECTION_BUY,
   AI_DIRECTION_SELL,
   AI_DIRECTION_NEUTRAL
  };

//====================================================================
// وضعیت نتیجه
//====================================================================
enum ENUM_AI_OUTCOME_STATE
  {
   AI_OUTCOME_UNKNOWN = 0,
   AI_OUTCOME_PENDING,
   AI_OUTCOME_WIN,
   AI_OUTCOME_LOSS,
   AI_OUTCOME_BREAKEVEN,
   AI_OUTCOME_CANCELLED,
   AI_OUTCOME_EXPIRED
  };

//====================================================================
// وضعیت رکورد
//====================================================================
enum ENUM_AI_RECORD_STATE
  {
   AI_RECORD_NEW = 0,
   AI_RECORD_OPEN,
   AI_RECORD_CLOSED,
   AI_RECORD_FINALIZED
  };

//====================================================================
// اطلاعات عمومی وضعیت بازار در لحظه ثبت داده
//====================================================================
struct AI_MarketSnapshot
  {
   double bid;
   double ask;
   double spread_points;

   double atr;
   double volatility;

   double trend_value;
   double structure_value;
   double momentum_value;

   string market_regime;
   string market_context;
   string market_structure;

   datetime time;
  };

//====================================================================
// اطلاعات سناریو در لحظه ثبت داده
//====================================================================
struct AI_ScenarioSnapshot
  {
   ulong    scenario_id;
   int      direction;

   string   status;
   string   type;

   double   zone_low;
   double   zone_high;
   double   entry_price;
   double   invalidation_price;
   double   target_1;
   double   target_2;
   double   target_3;

   double   confidence;
   double   score;

   string   reason;

   datetime created_time;
   datetime updated_time;
  };

//====================================================================
// اطلاعات تصمیم ربات اصلی
//====================================================================
struct AI_DecisionSnapshot
  {
   bool     trade_candidate;
   bool     approved;

   int      direction;
   int      entry_mode;

   double   entry_price;
   double   stop_loss;
   double   take_profit;
   double   lot_size;

   double   risk_percent;
   double   risk_money;
   double   reward_money;
   double   risk_reward;

   string   decision;
   string   reason;

   datetime decision_time;
  };

//====================================================================
// نتیجه یک معامله
// [اصلاح] افزودن فیلد fee
//====================================================================
struct AI_TradeOutcome
  {
   ENUM_AI_OUTCOME_STATE state;

   double gross_profit;
   double commission;
   double swap;
   double fee;              // [جدید] کارمزد اضافی
   double net_profit;

   double max_favorable_excursion;
   double max_adverse_excursion;

   int partial_close_count;

   datetime entry_time;
   datetime exit_time;

   int duration_seconds;
   int time_to_first_profit_seconds;
  };

//====================================================================
// رکورد اصلی Dataset
//====================================================================
struct AI_DataRecord
  {
   ulong                   record_id;
   ulong                   parent_record_id;

   ENUM_AI_DATA_TYPE       data_type;
   ENUM_AI_RECORD_STATE    state;

   string                  symbol;
   ENUM_TIMEFRAMES         timeframe;

   datetime                timestamp;

   AI_MarketSnapshot       market;
   AI_ScenarioSnapshot     scenario;
   AI_DecisionSnapshot     decision;
   AI_TradeOutcome         outcome;

   bool                    has_market;
   bool                    has_scenario;
   bool                    has_decision;
   bool                    has_outcome;

   string                  note;
   string                  source;
  };

//====================================================================
// آمار پایه Dataset
//====================================================================
struct AI_DataStatistics
  {
   long total_records;
   long market_records;
   long scenario_records;
   long decision_records;
   long real_trade_records;
   long virtual_trade_records;
   long rejected_opportunity_records;
   long finalized_outcome_records;

   long wins;
   long losses;
   long breakeven;

   double total_net_profit;
   double average_net_profit;

   datetime first_record_time;
   datetime last_record_time;
  };

//------------------------------------------------------------------
// تبدیل جهت به فارسی
//------------------------------------------------------------------
string AI_DirectionToPersian(const int direction)
  {
   switch(direction)
     {
      case AI_DIRECTION_BUY:     return "خرید";
      case AI_DIRECTION_SELL:    return "فروش";
      case AI_DIRECTION_NEUTRAL: return "خنثی";
      default:                   return "بدون جهت";
     }
  }

//------------------------------------------------------------------
// تبدیل نوع داده به فارسی
//------------------------------------------------------------------
string AI_DataTypeToPersian(const ENUM_AI_DATA_TYPE type)
  {
   switch(type)
     {
      case AI_DATA_MARKET_OBSERVATION:    return "مشاهده بازار";
      case AI_DATA_TRADE_REAL:            return "معامله واقعی";
      case AI_DATA_TRADE_VIRTUAL:         return "معامله مجازی";
      case AI_DATA_REJECTED_OPPORTUNITY:  return "فرصت ردشده";
      case AI_DATA_SCENARIO:              return "سناریو";
      case AI_DATA_DECISION:              return "تصمیم";
      case AI_DATA_OUTCOME:               return "نتیجه";
      default:                            return "نامشخص";
     }
  }

//------------------------------------------------------------------
// تبدیل وضعیت نتیجه به فارسی
//------------------------------------------------------------------
string AI_OutcomeToPersian(const ENUM_AI_OUTCOME_STATE state)
  {
   switch(state)
     {
      case AI_OUTCOME_PENDING:    return "در انتظار نتیجه";
      case AI_OUTCOME_WIN:        return "سودده";
      case AI_OUTCOME_LOSS:       return "زیان‌ده";
      case AI_OUTCOME_BREAKEVEN:  return "سر‌به‌سر";
      case AI_OUTCOME_CANCELLED:  return "لغوشده";
      case AI_OUTCOME_EXPIRED:    return "منقضی";
      default:                    return "نامشخص";
     }
  }

//------------------------------------------------------------------
// مقداردهی Market Snapshot
//------------------------------------------------------------------
void AI_MarketSnapshotInit(AI_MarketSnapshot &market)
  {
   market.bid              = 0.0;
   market.ask              = 0.0;
   market.spread_points    = 0.0;
   market.atr              = 0.0;
   market.volatility       = 0.0;
   market.trend_value      = 0.0;
   market.structure_value  = 0.0;
   market.momentum_value   = 0.0;

   market.market_regime    = "";
   market.market_context   = "";
   market.market_structure = "";

   market.time             = 0;
  }

//------------------------------------------------------------------
// مقداردهی Scenario Snapshot
//------------------------------------------------------------------
void AI_ScenarioSnapshotInit(AI_ScenarioSnapshot &scenario)
  {
   scenario.scenario_id        = 0;
   scenario.direction          = AI_DIRECTION_NONE;
   scenario.status             = "";
   scenario.type               = "";

   scenario.zone_low           = 0.0;
   scenario.zone_high          = 0.0;
   scenario.entry_price        = 0.0;
   scenario.invalidation_price = 0.0;
   scenario.target_1           = 0.0;
   scenario.target_2           = 0.0;
   scenario.target_3           = 0.0;

   scenario.confidence         = 0.0;
   scenario.score              = 0.0;
   scenario.reason             = "";

   scenario.created_time       = 0;
   scenario.updated_time       = 0;
  }

//------------------------------------------------------------------
// مقداردهی Decision Snapshot
//------------------------------------------------------------------
void AI_DecisionSnapshotInit(AI_DecisionSnapshot &decision)
  {
   decision.trade_candidate = false;
   decision.approved        = false;

   decision.direction       = AI_DIRECTION_NONE;
   decision.entry_mode      = 0;

   decision.entry_price     = 0.0;
   decision.stop_loss       = 0.0;
   decision.take_profit     = 0.0;
   decision.lot_size        = 0.0;

   decision.risk_percent    = 0.0;
   decision.risk_money      = 0.0;
   decision.reward_money    = 0.0;
   decision.risk_reward     = 0.0;

   decision.decision        = "";
   decision.reason          = "";
   decision.decision_time   = 0;
  }

//------------------------------------------------------------------
// مقداردهی Outcome
// [اصلاح] افزودن fee
//------------------------------------------------------------------
void AI_TradeOutcomeInit(AI_TradeOutcome &outcome)
  {
   outcome.state                        = AI_OUTCOME_UNKNOWN;
   outcome.gross_profit                 = 0.0;
   outcome.commission                   = 0.0;
   outcome.swap                         = 0.0;
   outcome.fee                          = 0.0;
   outcome.net_profit                   = 0.0;
   outcome.max_favorable_excursion      = 0.0;
   outcome.max_adverse_excursion        = 0.0;
   outcome.partial_close_count          = 0;
   outcome.entry_time                   = 0;
   outcome.exit_time                    = 0;
   outcome.duration_seconds             = 0;
   outcome.time_to_first_profit_seconds = 0;
  }

//------------------------------------------------------------------
// مقداردهی رکورد اصلی
//------------------------------------------------------------------
void AI_DataRecordInit(AI_DataRecord &record)
  {
   record.record_id        = 0;
   record.parent_record_id = 0;

   record.data_type        = AI_DATA_UNKNOWN;
   record.state            = AI_RECORD_NEW;

   record.symbol           = "";
   record.timeframe        = PERIOD_CURRENT;
   record.timestamp        = 0;

   AI_MarketSnapshotInit(record.market);
   AI_ScenarioSnapshotInit(record.scenario);
   AI_DecisionSnapshotInit(record.decision);
   AI_TradeOutcomeInit(record.outcome);

   record.has_market       = false;
   record.has_scenario     = false;
   record.has_decision     = false;
   record.has_outcome      = false;

   record.note             = "";
   record.source           = "";
  }

//------------------------------------------------------------------
// مقداردهی آمار Dataset
//------------------------------------------------------------------
void AI_DataStatisticsInit(AI_DataStatistics &stats)
  {
   stats.total_records                 = 0;
   stats.market_records                = 0;
   stats.scenario_records              = 0;
   stats.decision_records              = 0;
   stats.real_trade_records            = 0;
   stats.virtual_trade_records         = 0;
   stats.rejected_opportunity_records  = 0;
   stats.finalized_outcome_records     = 0;

   stats.wins                          = 0;
   stats.losses                        = 0;
   stats.breakeven                     = 0;

   stats.total_net_profit              = 0.0;
   stats.average_net_profit            = 0.0;

   stats.first_record_time             = 0;
   stats.last_record_time              = 0;
  }

//------------------------------------------------------------------
// ساخت یک ID یکتا برای رکورد
// [اصلاح] استفاده از TimeCurrent به جای TimeLocal برای بک‌تست
//------------------------------------------------------------------
ulong AI_GenerateRecordID()
  {
   static ulong sequence = 0;
   sequence++;

   //--- [اصلاح] استفاده از TimeCurrent برای سازگاری با بک‌تست
   return ((ulong)TimeCurrent() * 1000ULL) + sequence;
  }

//------------------------------------------------------------------
// آماده‌سازی رکورد جدید
//------------------------------------------------------------------
bool AI_PrepareRecord(AI_DataRecord &record,
                      const string symbol,
                      const ENUM_TIMEFRAMES timeframe,
                      const ENUM_AI_DATA_TYPE data_type,
                      const string source)
  {
   AI_DataRecordInit(record);

   if(symbol == "")
      return false;

   record.record_id  = AI_GenerateRecordID();
   record.data_type  = data_type;
   record.state      = AI_RECORD_NEW;
   record.symbol     = symbol;
   record.timeframe  = timeframe;
   record.timestamp  = TimeCurrent();
   record.source     = source;

   return true;
  }

//------------------------------------------------------------------
// ثبت Market Snapshot
//------------------------------------------------------------------
void AI_SetMarketSnapshot(AI_DataRecord &record,
                          const AI_MarketSnapshot &market)
  {
   record.market = market;
   record.has_market = true;
  }

//------------------------------------------------------------------
// ثبت Scenario Snapshot
//------------------------------------------------------------------
void AI_SetScenarioSnapshot(AI_DataRecord &record,
                            const AI_ScenarioSnapshot &scenario)
  {
   record.scenario = scenario;
   record.has_scenario = true;
  }

//------------------------------------------------------------------
// ثبت Decision Snapshot
//------------------------------------------------------------------
void AI_SetDecisionSnapshot(AI_DataRecord &record,
                            const AI_DecisionSnapshot &decision)
  {
   record.decision = decision;
   record.has_decision = true;
  }

//------------------------------------------------------------------
// ثبت Outcome
//------------------------------------------------------------------
void AI_SetOutcome(AI_DataRecord &record,
                   const AI_TradeOutcome &outcome)
  {
   record.outcome = outcome;
   record.has_outcome = true;
   record.state = AI_RECORD_FINALIZED;
  }

//------------------------------------------------------------------
// تعیین رکورد به عنوان باز
//------------------------------------------------------------------
void AI_MarkRecordOpen(AI_DataRecord &record)
  {
   record.state = AI_RECORD_OPEN;
  }

//------------------------------------------------------------------
// تعیین رکورد به عنوان بسته
//------------------------------------------------------------------
void AI_MarkRecordClosed(AI_DataRecord &record)
  {
   record.state = AI_RECORD_CLOSED;
  }

//------------------------------------------------------------------
// بررسی کامل بودن رکورد
// [اصلاح] بررسی فیلدهای محتوایی بر اساس نوع داده
//------------------------------------------------------------------
bool AI_IsRecordComplete(const AI_DataRecord &record)
  {
   if(record.record_id == 0)
      return false;

   if(record.symbol == "")
      return false;

   if(record.timestamp <= 0)
      return false;

   //--- بررسی فیلدهای خاص بر اساس نوع داده
   switch(record.data_type)
     {
      case AI_DATA_MARKET_OBSERVATION:
         return record.has_market;

      case AI_DATA_SCENARIO:
         return record.has_scenario;

      case AI_DATA_DECISION:
         return record.has_decision;

      case AI_DATA_TRADE_REAL:
      case AI_DATA_TRADE_VIRTUAL:
         return record.has_decision && record.has_outcome;

      case AI_DATA_REJECTED_OPPORTUNITY:
         return record.has_decision || record.has_scenario;

      default:
         return true;
     }
  }

//------------------------------------------------------------------
// تعیین اینکه رکورد برای یادگیری نهایی آماده است
//------------------------------------------------------------------
bool AI_IsLearningReady(const AI_DataRecord &record)
  {
   if(!AI_IsRecordComplete(record))
      return false;

   if(record.state != AI_RECORD_FINALIZED)
      return false;

   if(!record.has_outcome)
      return false;

   if(record.outcome.state == AI_OUTCOME_PENDING ||
      record.outcome.state == AI_OUTCOME_UNKNOWN)
      return false;

   return true;
  }

//------------------------------------------------------------------
// به‌روزرسانی آمار Dataset با یک رکورد
// [اصلاح] محاسبه صحیح میانگین بر اساس finalized_outcome_records
//------------------------------------------------------------------
void AI_StatisticsAddRecord(AI_DataStatistics &stats,
                            const AI_DataRecord &record)
  {
   stats.total_records++;

   switch(record.data_type)
     {
      case AI_DATA_MARKET_OBSERVATION:
         stats.market_records++;
         break;

      case AI_DATA_SCENARIO:
         stats.scenario_records++;
         break;

      case AI_DATA_DECISION:
         stats.decision_records++;
         break;

      case AI_DATA_TRADE_REAL:
         stats.real_trade_records++;
         break;

      case AI_DATA_TRADE_VIRTUAL:
         stats.virtual_trade_records++;
         break;

      case AI_DATA_REJECTED_OPPORTUNITY:
         stats.rejected_opportunity_records++;
         break;

      default:
         break;
     }

   if(record.has_outcome)
     {
      if(record.state == AI_RECORD_FINALIZED)
         stats.finalized_outcome_records++;

      switch(record.outcome.state)
        {
         case AI_OUTCOME_WIN:
            stats.wins++;
            break;

         case AI_OUTCOME_LOSS:
            stats.losses++;
            break;

         case AI_OUTCOME_BREAKEVEN:
            stats.breakeven++;
            break;

         default:
            break;
        }

      stats.total_net_profit += record.outcome.net_profit;
     }

   //--- [اصلاح] محاسبه میانگین بر اساس finalized_outcome_records
   if(stats.finalized_outcome_records > 0)
      stats.average_net_profit =
         stats.total_net_profit / (double)stats.finalized_outcome_records;

   if(record.timestamp > 0)
     {
      if(stats.first_record_time == 0 ||
         record.timestamp < stats.first_record_time)
         stats.first_record_time = record.timestamp;

      if(record.timestamp > stats.last_record_time)
         stats.last_record_time = record.timestamp;
     }
  }

//------------------------------------------------------------------
// [جدید] محاسبه سن رکورد بر حسب ثانیه
//------------------------------------------------------------------
long AI_GetRecordAgeSeconds(const AI_DataRecord &record)
  {
   if(record.timestamp <= 0)
      return 0;
   
   datetime now = TimeCurrent();
   if(now < record.timestamp)
      return 0;
   
   return (long)(now - record.timestamp);
  }

//------------------------------------------------------------------
// [جدید] بررسی معتبر بودن رکورد
//------------------------------------------------------------------
bool AI_IsRecordValid(const AI_DataRecord &record)
  {
   if(record.record_id == 0)
      return false;
   
   if(record.data_type == AI_DATA_UNKNOWN)
      return false;
   
   if(record.symbol == "")
      return false;
   
   return true;
  }

//------------------------------------------------------------------
// ساخت متن خلاصه رکورد برای گزارش
//------------------------------------------------------------------
string AI_RecordToText(const AI_DataRecord &record)
  {
   string text = "";

   text += "شناسه داده: " + (string)record.record_id;
   text += " | نوع: " + AI_DataTypeToPersian(record.data_type);
   text += " | نماد: " + record.symbol;
   text += " | زمان: " + TimeToString(record.timestamp, TIME_DATE|TIME_SECONDS);

   if(record.has_market)
     {
      text += " | قیمت خرید: " + DoubleToString(record.market.bid, _Digits);
      text += " | قیمت فروش: " + DoubleToString(record.market.ask, _Digits);
      text += " | اسپرد: " + DoubleToString(record.market.spread_points, 1);
     }

   if(record.has_scenario)
     {
      text += " | سناریو: " + record.scenario.status;
      text += " | جهت: " + AI_DirectionToPersian(record.scenario.direction);
      text += " | امتیاز: " + DoubleToString(record.scenario.score, 2);
      text += " | اطمینان: " + DoubleToString(record.scenario.confidence, 2);
     }

   if(record.has_decision)
     {
      text += " | تصمیم: " + record.decision.decision;
      text += " | مجاز: " + (record.decision.approved ? "بله" : "خیر");
     }

   if(record.has_outcome)
     {
      text += " | نتیجه: " + AI_OutcomeToPersian(record.outcome.state);
      text += " | سود/ضرر خالص: " + DoubleToString(record.outcome.net_profit, 2);
     }

   if(record.note != "")
      text += " | یادداشت: " + record.note;

   return text;
  }

//------------------------------------------------------------------
// [جدید] ساخت متن خلاصه آمار Dataset
//------------------------------------------------------------------
string AI_StatisticsToText(const AI_DataStatistics &stats)
  {
   string text = "";
   
   text += "کل رکوردها: " + (string)stats.total_records;
   text += " | مشاهده بازار: " + (string)stats.market_records;
   text += " | سناریو: " + (string)stats.scenario_records;
   text += " | تصمیم: " + (string)stats.decision_records;
   text += " | معامله واقعی: " + (string)stats.real_trade_records;
   text += " | معامله مجازی: " + (string)stats.virtual_trade_records;
   text += " | فرصت ردشده: " + (string)stats.rejected_opportunity_records;
   text += " | نتیجه نهایی: " + (string)stats.finalized_outcome_records;
   text += " | برد: " + (string)stats.wins;
   text += " | باخت: " + (string)stats.losses;
   text += " | سر‌به‌سر: " + (string)stats.breakeven;
   text += " | سود کل: " + DoubleToString(stats.total_net_profit, 2);
   text += " | میانگین سود: " + DoubleToString(stats.average_net_profit, 2);
   
   return text;
  }

//+------------------------------------------------------------------+

#endif // __TFLAB_AI_DATA_MQH__