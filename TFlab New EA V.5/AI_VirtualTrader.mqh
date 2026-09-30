#ifndef __TFLAB_AI_VIRTUALTRADER_MQH__
#define __TFLAB_AI_VIRTUALTRADER_MQH__

//+------------------------------------------------------------------+
//|                     AI_VirtualTrader.mqh                         |
//|                     TFlab New EA V.5                                 |
//|                                                                  |
//| مسئولیت: شبیه‌سازی معاملات پیشنهادی AI                           |
//|                                                                  |
//| این فایل فقط معاملات مجازی AI را مدیریت می‌کند.                  |
//| هیچ سفارش واقعی ارسال نمی‌کند و به Execution دسترسی ندارد.       |
//|                                                                  |
//| v2.1 - Fixed profit calc + Expiration + لاگ تشخیصی             |
//+------------------------------------------------------------------+
#property strict

#include "EA_Inputs.mqh"

//====================================================================
// وضعیت معامله مجازی
//====================================================================
enum ENUM_AI_VIRTUAL_STATUS
  {
   AI_VIRTUAL_NONE = 0,
   AI_VIRTUAL_PLANNED,
   AI_VIRTUAL_OPEN,
   AI_VIRTUAL_PARTIAL,
   AI_VIRTUAL_CLOSED,
   AI_VIRTUAL_STOPPED,
   AI_VIRTUAL_TARGETED,
   AI_VIRTUAL_CANCELLED,
   AI_VIRTUAL_EXPIRED
  };

//====================================================================
// جهت معامله مجازی
//====================================================================
enum ENUM_AI_VIRTUAL_DIRECTION
  {
   AI_VIRTUAL_DIRECTION_NONE = 0,
   AI_VIRTUAL_DIRECTION_BUY,
   AI_VIRTUAL_DIRECTION_SELL
  };

//====================================================================
// علت پایان
//====================================================================
enum ENUM_AI_VIRTUAL_EXIT_REASON
  {
   AI_VIRTUAL_EXIT_NONE = 0,
   AI_VIRTUAL_EXIT_STOP,
   AI_VIRTUAL_EXIT_TARGET,
   AI_VIRTUAL_EXIT_PARTIAL,
   AI_VIRTUAL_EXIT_MANUAL_RULE,
   AI_VIRTUAL_EXIT_SCENARIO_INVALID,
   AI_VIRTUAL_EXIT_EXPIRED,
   AI_VIRTUAL_EXIT_CANCELLED,
   AI_VIRTUAL_EXIT_REVERSAL
  };

//====================================================================
// معامله مجازی
//====================================================================
struct AIVirtualTrade
  {
   ulong                        id;
   ulong                        source_signal_id;
   string                       symbol;                 // [جدید] نماد معامله
   datetime                     decision_time;
   datetime                     open_time;
   datetime                     close_time;
   datetime                     expiration_time;        // [جدید] زمان انقضا

   ENUM_AI_VIRTUAL_DIRECTION    direction;
   ENUM_AI_VIRTUAL_STATUS       status;
   ENUM_AI_VIRTUAL_EXIT_REASON  exit_reason;

   double                       planned_entry;
   double                       entry_price;
   double                       sl_price;
   double                       tp_price;
   double                       quantity;

   double                       initial_quantity;
   double                       remaining_quantity;
   double                       partial_close_quantity;
   double                       partial_close_price;

   double                       exit_price;
   double                       gross_profit;
   double                       net_profit;
   double                       maximum_favorable_excursion;
   double                       maximum_adverse_excursion;  // [اصلاح] همیشه مثبت (مطلق)

   double                       spread_at_decision;
   double                       spread_at_entry;
   double                       estimated_cost;
   
   double                       tick_value;             // [جدید] ارزش هر تیک
   double                       tick_size;              // [جدید] اندازه هر تیک
   double                       contract_size;          // [جدید] اندازه قرارداد

   int                          entry_delay_seconds;
   int                          duration_seconds;
   int                          bars_held;
   int                          max_duration_minutes;   // [جدید] حداکثر مدت مجاز

   string                       model_name;
   string                       entry_reason;
   string                       exit_reason_text;
   string                       notes;
  };

//====================================================================
// وضعیت خلاصه موتور
//====================================================================
struct AIVirtualEngineState
  {
   bool     initialized;
   ulong    next_trade_id;
   int      total_planned;
   int      total_opened;
   int      total_closed;
   int      total_wins;
   int      total_losses;
   int      total_breakeven;
   int      total_cancelled;
   int      total_expired;
   
   double   total_profit;
   double   total_loss;
   double   net_profit;
   double   win_rate;
   double   profit_factor;
   double   average_win;
   double   average_loss;
   
   datetime last_update;
  };

//------------------------------------------------------------------
// متن فارسی وضعیت
//------------------------------------------------------------------
string AIVirtualStatusToPersian(const ENUM_AI_VIRTUAL_STATUS status)
  {
   switch(status)
     {
      case AI_VIRTUAL_PLANNED:   return "برنامه‌ریزی شده";
      case AI_VIRTUAL_OPEN:      return "باز";
      case AI_VIRTUAL_PARTIAL:   return "خروج بخشی";
      case AI_VIRTUAL_CLOSED:    return "بسته شده";
      case AI_VIRTUAL_STOPPED:   return "حد ضرر";
      case AI_VIRTUAL_TARGETED:  return "هدف";
      case AI_VIRTUAL_CANCELLED: return "لغو شده";
      case AI_VIRTUAL_EXPIRED:   return "منقضی شده";
      default:                   return "نامشخص";
     }
  }

//------------------------------------------------------------------
// متن فارسی جهت
//------------------------------------------------------------------
string AIVirtualDirectionToPersian(const ENUM_AI_VIRTUAL_DIRECTION direction)
  {
   switch(direction)
     {
      case AI_VIRTUAL_DIRECTION_BUY:  return "خرید";
      case AI_VIRTUAL_DIRECTION_SELL: return "فروش";
      default:                        return "بدون جهت";
     }
  }

//------------------------------------------------------------------
// متن فارسی علت خروج
//------------------------------------------------------------------
string AIVirtualExitReasonToPersian(const ENUM_AI_VIRTUAL_EXIT_REASON reason)
  {
   switch(reason)
     {
      case AI_VIRTUAL_EXIT_STOP:             return "حد ضرر";
      case AI_VIRTUAL_EXIT_TARGET:            return "حد سود";
      case AI_VIRTUAL_EXIT_PARTIAL:           return "خروج بخشی";
      case AI_VIRTUAL_EXIT_MANUAL_RULE:      return "قانون مدل";
      case AI_VIRTUAL_EXIT_SCENARIO_INVALID: return "ابطال سناریو";
      case AI_VIRTUAL_EXIT_EXPIRED:          return "انقضا";
      case AI_VIRTUAL_EXIT_CANCELLED:        return "لغو";
      case AI_VIRTUAL_EXIT_REVERSAL:         return "بازگشت روند";
      default:                               return "نامشخص";
     }
  }

//------------------------------------------------------------------
// مقداردهی معامله مجازی
//------------------------------------------------------------------
void AIVirtualTradeInit(AIVirtualTrade &trade)
  {
   trade.id                          = 0;
   trade.source_signal_id            = 0;
   trade.symbol                      = "";
   trade.decision_time               = 0;
   trade.open_time                   = 0;
   trade.close_time                  = 0;
   trade.expiration_time             = 0;
   
   trade.direction                   = AI_VIRTUAL_DIRECTION_NONE;
   trade.status                      = AI_VIRTUAL_NONE;
   trade.exit_reason                 = AI_VIRTUAL_EXIT_NONE;
   
   trade.planned_entry               = 0.0;
   trade.entry_price                 = 0.0;
   trade.sl_price                    = 0.0;
   trade.tp_price                    = 0.0;
   trade.quantity                    = 0.0;
   
   trade.initial_quantity            = 0.0;
   trade.remaining_quantity          = 0.0;
   trade.partial_close_quantity      = 0.0;
   trade.partial_close_price         = 0.0;
   
   trade.exit_price                  = 0.0;
   trade.gross_profit                = 0.0;
   trade.net_profit                  = 0.0;
   trade.maximum_favorable_excursion = 0.0;
   trade.maximum_adverse_excursion   = 0.0;
   
   trade.spread_at_decision          = 0.0;
   trade.spread_at_entry             = 0.0;
   trade.estimated_cost              = 0.0;
   
   trade.tick_value                  = 0.0;
   trade.tick_size                   = 0.0;
   trade.contract_size               = 0.0;
   
   trade.entry_delay_seconds         = 0;
   trade.duration_seconds            = 0;
   trade.bars_held                   = 0;
   trade.max_duration_minutes        = 0;
   
   trade.model_name                  = "";
   trade.entry_reason                = "";
   trade.exit_reason_text            = "";
   trade.notes                       = "";
  }

//------------------------------------------------------------------
// مقداردهی موتور
//------------------------------------------------------------------
void AIVirtualEngine_Init(AIVirtualEngineState &state)
  {
   state.initialized    = true;
   state.next_trade_id  = 1;
   state.total_planned  = 0;
   state.total_opened   = 0;
   state.total_closed   = 0;
   state.total_wins     = 0;
   state.total_losses   = 0;
   state.total_breakeven= 0;
   state.total_cancelled= 0;
   state.total_expired  = 0;
   state.total_profit   = 0.0;
   state.total_loss     = 0.0;
   state.net_profit     = 0.0;
   state.win_rate       = 0.0;
   state.profit_factor  = 0.0;
   state.average_win    = 0.0;
   state.average_loss   = 0.0;
   state.last_update    = TimeCurrent();
  }

//------------------------------------------------------------------
// [جدید] بارگذاری اطلاعات نماد برای محاسبه سود
//------------------------------------------------------------------
bool AIVirtual_LoadSymbolInfo(const string symbol, AIVirtualTrade &trade)
  {
   if(symbol == "")
      return false;
   
   trade.symbol         = symbol;
   trade.tick_value     = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   trade.tick_size      = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   trade.contract_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   
   //--- fallback برای مقادیر نامعتبر
   if(trade.tick_value <= 0.0) trade.tick_value = 10.0;
   if(trade.tick_size <= 0.0)  trade.tick_size = 0.0001;
   if(trade.contract_size <= 0.0) trade.contract_size = 100000.0;
   
   return (trade.tick_value > 0.0 && trade.tick_size > 0.0);
  }

//------------------------------------------------------------------
// اعتبار ورودی‌های پایه
//------------------------------------------------------------------
bool AIVirtualValidatePlan(const ENUM_AI_VIRTUAL_DIRECTION direction,
                           const double entry_price,
                           const double sl_price,
                           const double tp_price,
                           const double quantity)
  {
   if(direction == AI_VIRTUAL_DIRECTION_NONE)
      return false;

   if(entry_price <= 0.0 || sl_price <= 0.0 || tp_price <= 0.0)
      return false;

   if(quantity <= 0.0)
      return false;

   if(direction == AI_VIRTUAL_DIRECTION_BUY)
     {
      if(sl_price >= entry_price) return false;
      if(tp_price <= entry_price) return false;
     }
   else if(direction == AI_VIRTUAL_DIRECTION_SELL)
     {
      if(sl_price <= entry_price) return false;
      if(tp_price >= entry_price) return false;
     }

   return true;
  }

//------------------------------------------------------------------
// ساخت معامله مجازی در حالت برنامه‌ریزی
// [اصلاح] افزودن symbol + بارگذاری اطلاعات نماد + expiration
//------------------------------------------------------------------
bool AIVirtualCreatePlan(AIVirtualEngineState &engine,
                         const ulong source_signal_id,
                         const string symbol,
                         const datetime decision_time,
                         const ENUM_AI_VIRTUAL_DIRECTION direction,
                         const double planned_entry,
                         const double sl_price,
                         const double tp_price,
                         const double quantity,
                         const double spread_at_decision,
                         const string model_name,
                         const string entry_reason,
                         const int max_duration_minutes,
                         AIVirtualTrade &trade)
  {
   AIVirtualTradeInit(trade);

   if(!AIVirtualValidatePlan(direction, planned_entry, sl_price, tp_price, quantity))
     {
      Print("[AI VIRTUAL] PLAN FAIL | Invalid parameters | Direction=",
            EnumToString(direction),
            " | Entry=", DoubleToString(planned_entry, _Digits),
            " | SL=", DoubleToString(sl_price, _Digits),
            " | TP=", DoubleToString(tp_price, _Digits),
            " | Quantity=", DoubleToString(quantity, 2));
      return false;
     }

   if(!engine.initialized)
      AIVirtualEngine_Init(engine);

   //--- [جدید] بارگذاری اطلاعات نماد
   if(!AIVirtual_LoadSymbolInfo(symbol, trade))
     {
      Print("[AI VIRTUAL] PLAN FAIL | Cannot load symbol info for ", symbol);
      return false;
     }

   trade.id                  = engine.next_trade_id++;
   trade.source_signal_id    = source_signal_id;
   trade.decision_time       = decision_time;
   trade.direction           = direction;
   trade.status              = AI_VIRTUAL_PLANNED;
   trade.planned_entry       = planned_entry;
   trade.sl_price            = sl_price;
   trade.tp_price            = tp_price;
   trade.quantity            = quantity;
   trade.initial_quantity    = quantity;
   trade.remaining_quantity  = quantity;
   trade.spread_at_decision  = spread_at_decision;
   trade.model_name          = model_name;
   trade.entry_reason        = entry_reason;
   trade.max_duration_minutes = max_duration_minutes;
   
   //--- [جدید] محاسبه زمان انقضا
   if(max_duration_minutes > 0)
      trade.expiration_time = decision_time + max_duration_minutes * 60;

   engine.total_planned++;
   engine.last_update = decision_time;

   Print(
      "[AI VIRTUAL] PLAN CREATED",
      " | ID=", trade.id,
      " | Dir=", AIVirtualDirectionToPersian(direction),
      " | Entry=", DoubleToString(planned_entry, _Digits),
      " | SL=", DoubleToString(sl_price, _Digits),
      " | TP=", DoubleToString(tp_price, _Digits),
      " | Vol=", DoubleToString(quantity, 4),
      " | Model=", model_name
   );

   return true;
  }

//------------------------------------------------------------------
// فعال کردن معامله مجازی در قیمت مشخص
// [اصلاح] افزودن لاگ تشخیصی
//------------------------------------------------------------------
bool AIVirtualOpen(AIVirtualEngineState &engine,
                   AIVirtualTrade &trade,
                   const datetime open_time,
                   const double actual_entry,
                   const double spread_at_entry)
  {
   if(trade.status != AI_VIRTUAL_PLANNED)
     {
      Print("[AI VIRTUAL] OPEN FAIL | Status=", AIVirtualStatusToPersian(trade.status));
      return false;
     }

   if(actual_entry <= 0.0)
      return false;

   //--- [جدید] بررسی انقضا قبل از باز شدن
   if(trade.expiration_time > 0 && open_time >= trade.expiration_time)
     {
      trade.status = AI_VIRTUAL_EXPIRED;
      trade.exit_reason = AI_VIRTUAL_EXIT_EXPIRED;
      trade.exit_reason_text = "معامله قبل از فعال شدن منقضی شد";
      trade.close_time = open_time;
      engine.total_expired++;
      Print("[AI VIRTUAL] EXPIRED BEFORE OPEN | ID=", trade.id);
      return false;
     }

   trade.status              = AI_VIRTUAL_OPEN;
   trade.open_time           = open_time;
   trade.entry_price         = actual_entry;
   trade.spread_at_entry     = spread_at_entry;
   trade.entry_delay_seconds = (int)(open_time - trade.decision_time);

   engine.total_opened++;
   engine.last_update = open_time;

   Print(
      "[AI VIRTUAL] OPENED",
      " | ID=", trade.id,
      " | Price=", DoubleToString(actual_entry, _Digits),
      " | Delay=", trade.entry_delay_seconds, "s"
   );

   return true;
  }

//------------------------------------------------------------------
// محاسبه سود خام بر اساس قیمت خروج
// [اصلاح حیاتی] استفاده از tick_value و contract_size
//------------------------------------------------------------------
double AIVirtualCalculateGrossProfit(const AIVirtualTrade &trade,
                                      const double exit_price,
                                      const double quantity)
  {
   if(trade.entry_price <= 0.0 || exit_price <= 0.0 || quantity <= 0.0)
      return 0.0;

   double price_diff = 0.0;
   if(trade.direction == AI_VIRTUAL_DIRECTION_BUY)
      price_diff = exit_price - trade.entry_price;
   else if(trade.direction == AI_VIRTUAL_DIRECTION_SELL)
      price_diff = trade.entry_price - exit_price;
   else
      return 0.0;

   //--- [اصلاح] محاسبه واقعی سود با tick_value و tick_size
   if(trade.tick_value > 0.0 && trade.tick_size > 0.0)
     {
      double ticks = price_diff / trade.tick_size;
      return ticks * trade.tick_value * quantity;
     }
   
   //--- fallback: محاسبه ساده (کمتر دقیق)
   return price_diff * quantity * trade.contract_size;
  }

//------------------------------------------------------------------
// به‌روزرسانی MFE / MAE بر اساس قیمت لحظه‌ای
// [اصلاح] ذخیره MAE به صورت مثبت (مطلق) برای سازگاری
//------------------------------------------------------------------
void AIVirtualUpdateExcursion(AIVirtualTrade &trade,
                              const double current_price)
  {
   if(trade.status != AI_VIRTUAL_OPEN &&
      trade.status != AI_VIRTUAL_PARTIAL)
      return;

   const double move = AIVirtualCalculateGrossProfit(trade, current_price, 1.0);

   //--- MFE (بهترین حرکت به نفع)
   if(move > trade.maximum_favorable_excursion)
      trade.maximum_favorable_excursion = move;

   //--- [اصلاح] MAE (بدترین حرکت علیه) به صورت مثبت (مطلق)
   if(move < 0.0)
     {
      double abs_loss = MathAbs(move);
      if(abs_loss > trade.maximum_adverse_excursion)
         trade.maximum_adverse_excursion = abs_loss;
     }
  }

//------------------------------------------------------------------
// بررسی برخورد به SL/TP
//------------------------------------------------------------------
bool AIVirtualCheckExit(const AIVirtualTrade &trade,
                        const double bid,
                        const double ask,
                        ENUM_AI_VIRTUAL_EXIT_REASON &reason,
                        double &exit_price)
  {
   reason = AI_VIRTUAL_EXIT_NONE;
   exit_price = 0.0;

   if(trade.status != AI_VIRTUAL_OPEN &&
      trade.status != AI_VIRTUAL_PARTIAL)
      return false;

   if(trade.direction == AI_VIRTUAL_DIRECTION_BUY)
     {
      if(bid <= trade.sl_price)
        {
         reason = AI_VIRTUAL_EXIT_STOP;
         exit_price = trade.sl_price;
         return true;
        }

      if(bid >= trade.tp_price)
        {
         reason = AI_VIRTUAL_EXIT_TARGET;
         exit_price = trade.tp_price;
         return true;
        }
     }
   else if(trade.direction == AI_VIRTUAL_DIRECTION_SELL)
     {
      if(ask >= trade.sl_price)
        {
         reason = AI_VIRTUAL_EXIT_STOP;
         exit_price = trade.sl_price;
         return true;
        }

      if(ask <= trade.tp_price)
        {
         reason = AI_VIRTUAL_EXIT_TARGET;
         exit_price = trade.tp_price;
         return true;
        }
     }

   return false;
  }

//------------------------------------------------------------------
// [جدید] بررسی انقضای زمانی
//------------------------------------------------------------------
bool AIVirtualCheckExpiration(const AIVirtualTrade &trade,
                              const datetime current_time)
  {
   if(trade.status != AI_VIRTUAL_OPEN &&
      trade.status != AI_VIRTUAL_PARTIAL)
      return false;
   
   if(trade.expiration_time <= 0)
      return false;
   
   return (current_time >= trade.expiration_time);
  }

//------------------------------------------------------------------
// بستن کامل معامله مجازی
// [اصلاح] به‌روزرسانی statistics موتور + لاگ تشخیصی
//------------------------------------------------------------------
bool AIVirtualClose(AIVirtualEngineState &engine,
                    AIVirtualTrade &trade,
                    const datetime close_time,
                    const double exit_price,
                    const ENUM_AI_VIRTUAL_EXIT_REASON reason,
                    const double estimated_cost,
                    const string reason_text)
  {
   if(trade.status != AI_VIRTUAL_OPEN &&
      trade.status != AI_VIRTUAL_PARTIAL)
      return false;

   if(exit_price <= 0.0 || trade.remaining_quantity <= 0.0)
      return false;

   trade.exit_price       = exit_price;
   trade.close_time       = close_time;
   trade.exit_reason      = reason;
   trade.exit_reason_text = reason_text;
   trade.estimated_cost  += estimated_cost;
   trade.gross_profit    += AIVirtualCalculateGrossProfit(trade, exit_price, trade.remaining_quantity);
   trade.net_profit       = trade.gross_profit - trade.estimated_cost;
   trade.duration_seconds = (int)(close_time - trade.open_time);
   trade.remaining_quantity = 0.0;
   trade.quantity           = 0.0;

   if(reason == AI_VIRTUAL_EXIT_STOP)
      trade.status = AI_VIRTUAL_STOPPED;
   else if(reason == AI_VIRTUAL_EXIT_TARGET)
      trade.status = AI_VIRTUAL_TARGETED;
   else
      trade.status = AI_VIRTUAL_CLOSED;

   engine.total_closed++;

   //--- [اصلاح] به‌روزرسانی دقیق آمار
   const double breakeven_tolerance = 0.50;  // کمتر از 50 سنت = سربه‌سر
   
   if(trade.net_profit > breakeven_tolerance)
     {
      engine.total_wins++;
      engine.total_profit += trade.net_profit;
     }
   else if(trade.net_profit < -breakeven_tolerance)
     {
      engine.total_losses++;
      engine.total_loss += MathAbs(trade.net_profit);
     }
   else
     {
      engine.total_breakeven++;
     }

   engine.net_profit += trade.net_profit;
   engine.last_update = close_time;
   
   //--- به‌روزرسانی آمار مشتق
   AIVirtual_UpdateEngineStatistics(engine);

   Print(
      "[AI VIRTUAL] CLOSED",
      " | ID=", trade.id,
      " | Reason=", AIVirtualExitReasonToPersian(reason),
      " | ExitPrice=", DoubleToString(exit_price, _Digits),
      " | Gross=", DoubleToString(trade.gross_profit, 2),
      " | Net=", DoubleToString(trade.net_profit, 2),
      " | Duration=", trade.duration_seconds, "s"
   );

   return true;
  }

//------------------------------------------------------------------
// Partial Close مجازی
// [اصلاح] به‌روزرسانی statistics موتور
//------------------------------------------------------------------
bool AIVirtualPartialClose(AIVirtualTrade &trade,
                           const datetime time,
                           const double close_price,
                           const double close_quantity,
                           const double estimated_cost,
                           const string reason_text)
  {
   if(trade.status != AI_VIRTUAL_OPEN &&
      trade.status != AI_VIRTUAL_PARTIAL)
      return false;

   if(close_quantity <= 0.0 || close_price <= 0.0)
      return false;

   if(close_quantity >= trade.remaining_quantity)
      return false;

   const double partial_profit = AIVirtualCalculateGrossProfit(trade, close_price, close_quantity);

   trade.partial_close_quantity += close_quantity;
   trade.partial_close_price     = close_price;
   trade.gross_profit            += partial_profit;
   trade.estimated_cost         += estimated_cost;
   trade.net_profit              = trade.gross_profit - trade.estimated_cost;
   trade.remaining_quantity     -= close_quantity;
   trade.quantity                = trade.remaining_quantity;
   trade.status                  = AI_VIRTUAL_PARTIAL;
   trade.exit_reason_text        = reason_text;
   trade.notes                  += " | خروج بخشی در " + DoubleToString(close_price, _Digits);

   Print(
      "[AI VIRTUAL] PARTIAL CLOSE",
      " | ID=", trade.id,
      " | Price=", DoubleToString(close_price, _Digits),
      " | ClosedQty=", DoubleToString(close_quantity, 4),
      " | PartialProfit=", DoubleToString(partial_profit, 2)
   );

   return true;
  }

//------------------------------------------------------------------
// لغو معامله مجازی برنامه‌ریزی شده
// [اصلاح] به‌روزرسانی statistics موتور + لاگ
//------------------------------------------------------------------
bool AIVirtualCancel(AIVirtualEngineState &engine,
                     AIVirtualTrade &trade,
                     const datetime time,
                     const ENUM_AI_VIRTUAL_EXIT_REASON reason,
                     const string reason_text)
  {
   if(trade.status != AI_VIRTUAL_PLANNED &&
      trade.status != AI_VIRTUAL_OPEN &&
      trade.status != AI_VIRTUAL_PARTIAL)
      return false;

   ENUM_AI_VIRTUAL_STATUS new_status = AI_VIRTUAL_CANCELLED;
   
   if(reason == AI_VIRTUAL_EXIT_EXPIRED)
      new_status = AI_VIRTUAL_EXPIRED;
   
   trade.status           = new_status;
   trade.exit_reason      = reason;
   trade.exit_reason_text = reason_text;
   trade.close_time       = time;

   if(new_status == AI_VIRTUAL_EXPIRED)
      engine.total_expired++;
   else
      engine.total_cancelled++;

   engine.last_update = time;

   Print(
      "[AI VIRTUAL] ",
      (new_status == AI_VIRTUAL_EXPIRED ? "EXPIRED" : "CANCELLED"),
      " | ID=", trade.id,
      " | Reason=", reason_text
   );

   return true;
  }

//------------------------------------------------------------------
// [جدید] به‌روزرسانی آمار موتور
//------------------------------------------------------------------
void AIVirtual_UpdateEngineStatistics(AIVirtualEngineState &engine)
  {
   int total_outcomes = engine.total_wins + engine.total_losses + engine.total_breakeven;
   
   engine.win_rate = (total_outcomes > 0 ?
      (double)engine.total_wins / (double)total_outcomes * 100.0 : 0.0);
   
   if(engine.total_wins > 0)
      engine.average_win = engine.total_profit / (double)engine.total_wins;
   else
      engine.average_win = 0.0;
   
   if(engine.total_losses > 0)
      engine.average_loss = engine.total_loss / (double)engine.total_losses;
   else
      engine.average_loss = 0.0;
   
   if(engine.total_loss > 0.0000001)
      engine.profit_factor = engine.total_profit / engine.total_loss;
   else
      engine.profit_factor = (engine.total_profit > 0.0 ? 9999.0 : 0.0);
  }

//------------------------------------------------------------------
// [جدید] به‌روزرسانی معامله مجازی در هر تیک
//------------------------------------------------------------------
bool AIVirtualUpdate(AIVirtualTrade &trade,
                     const datetime current_time,
                     const double bid,
                     const double ask,
                     const int bars_passed,
                     AIVirtualEngineState &engine)
  {
   if(trade.status == AI_VIRTUAL_PLANNED)
     {
      //--- [جدید] بررسی انقضای plan قبل از اجرا
      if(trade.expiration_time > 0 && current_time >= trade.expiration_time)
        {
         AIVirtualCancel(engine, trade, current_time, AI_VIRTUAL_EXIT_EXPIRED,
                        "معامله برنامه‌ریزی شده قبل از اجرا منقضی شد");
         return false;
        }
     }
   
   if(trade.status == AI_VIRTUAL_OPEN || trade.status == AI_VIRTUAL_PARTIAL)
     {
      double mid_price = (bid + ask) * 0.5;
      
      //--- [جدید] به‌روزرسانی bars_held
      trade.bars_held += bars_passed;
      
      //--- به‌روزرسانی MFE/MAE
      AIVirtualUpdateExcursion(trade, mid_price);
      
      //--- [جدید] بررسی انقضای زمانی
      if(AIVirtualCheckExpiration(trade, current_time))
        {
         AIVirtualClose(engine, trade, current_time, mid_price,
                        AI_VIRTUAL_EXIT_EXPIRED, 0.0, "انقضای زمانی معامله مجازی");
         return true;
        }
      
      //--- بررسی SL/TP
      ENUM_AI_VIRTUAL_EXIT_REASON exit_reason;
      double exit_price;
      if(AIVirtualCheckExit(trade, bid, ask, exit_reason, exit_price))
        {
         AIVirtualClose(engine, trade, current_time, exit_price,
                        exit_reason, 0.0, AIVirtualExitReasonToPersian(exit_reason));
         return true;
        }
     }
   
   return false;
  }

//------------------------------------------------------------------
// تبدیل معامله مجازی به متن گزارش
//------------------------------------------------------------------
string AIVirtualTradeToText(const AIVirtualTrade &trade)
  {
   string text = "";

   text += "شناسه: " + (string)trade.id;
   text += " | نماد: " + trade.symbol;
   text += " | شناسه سیگنال: " + (string)trade.source_signal_id;
   text += " | مدل: " + trade.model_name;
   text += " | جهت: " + AIVirtualDirectionToPersian(trade.direction);
   text += " | وضعیت: " + AIVirtualStatusToPersian(trade.status);
   text += " | ورود: " + DoubleToString(trade.entry_price, _Digits);
   text += " | SL: " + DoubleToString(trade.sl_price, _Digits);
   text += " | TP: " + DoubleToString(trade.tp_price, _Digits);
   text += " | حجم: " + DoubleToString(trade.initial_quantity, 4);
   text += " | سود خالص: " + DoubleToString(trade.net_profit, 2);
   text += " | MFE: " + DoubleToString(trade.maximum_favorable_excursion, 2);
   text += " | MAE: " + DoubleToString(trade.maximum_adverse_excursion, 2);
   text += " | مدت: " + IntegerToString(trade.duration_seconds) + "s";
   text += " | Bars: " + IntegerToString(trade.bars_held);
   text += " | علت خروج: " + AIVirtualExitReasonToPersian(trade.exit_reason);

   return text;
  }

//------------------------------------------------------------------
// [جدید] تبدیل وضعیت موتور به متن گزارش
//------------------------------------------------------------------
string AIVirtualEngineToText(const AIVirtualEngineState &engine)
  {
   string text = "";
   
   text += "AI Virtual Trader Engine";
   text += " | Planned: " + IntegerToString(engine.total_planned);
   text += " | Opened: " + IntegerToString(engine.total_opened);
   text += " | Closed: " + IntegerToString(engine.total_closed);
   text += " | Wins: " + IntegerToString(engine.total_wins);
   text += " | Losses: " + IntegerToString(engine.total_losses);
   text += " | Breakeven: " + IntegerToString(engine.total_breakeven);
   text += " | Cancelled: " + IntegerToString(engine.total_cancelled);
   text += " | Expired: " + IntegerToString(engine.total_expired);
   text += " | Win Rate: " + DoubleToString(engine.win_rate, 2) + "%";
   text += " | PF: " + DoubleToString(engine.profit_factor, 2);
   text += " | AvgWin: " + DoubleToString(engine.average_win, 2);
   text += " | AvgLoss: " + DoubleToString(engine.average_loss, 2);
   text += " | Net: " + DoubleToString(engine.net_profit, 2);
   
   return text;
  }

//------------------------------------------------------------------
// [جدید] آیا موتور داده کافی برای یادگیری دارد؟
//------------------------------------------------------------------
bool AIVirtualEngine_HasEnoughData(const AIVirtualEngineState &engine,
                                   const int minimum_samples = 30)
  {
   return (engine.total_closed >= minimum_samples);
  }

//------------------------------------------------------------------
// [جدید] دریافت آمار برای AI Learning
//------------------------------------------------------------------
bool AIVirtualEngine_GetLearningStats(const AIVirtualEngineState &engine,
                                      int &wins, int &losses, int &breakeven,
                                      double &win_rate, double &profit_factor,
                                      double &total_profit, double &avg_win,
                                      double &avg_loss)
  {
   wins          = engine.total_wins;
   losses        = engine.total_losses;
   breakeven     = engine.total_breakeven;
   win_rate      = engine.win_rate;
   profit_factor = engine.profit_factor;
   total_profit  = engine.net_profit;
   avg_win       = engine.average_win;
   avg_loss      = engine.average_loss;
   
   return (engine.total_closed > 0);
  }

//+------------------------------------------------------------------+

#endif // __TFLAB_AI_VIRTUALTRADER_MQH__