#ifndef __TFLAB_PENDING_ORDER_MANAGER_MQH__
#define __TFLAB_PENDING_ORDER_MANAGER_MQH__

//+------------------------------------------------------------------+
//|                  Pending_Order_Manager.mqh                       |
//|                  TFlab New EA V.5                                |
//|                                                                  |
//| مسئولیت: مدیریت چرخه عمر سفارش‌های Pending                      |
//| بدون تحلیل بازار، ساخت سناریو، محاسبه Risk، SL یا TP             |
//|                                                                  |
//| v2.3 - Duplicate Pending Protection (full signature)             |
//|       + account scan                                              |
//|       + duplicate ticket diagnostics                              |
//+------------------------------------------------------------------+
#property strict

#include "EA_Inputs.mqh"
#include "Entry_Planner.mqh"
#include "Scenario_Engine.mqh"

//====================================================================
// وضعیت سفارش Pending
//====================================================================
enum ENUM_PENDING_ORDER_STATE
  {
   PENDING_STATE_NONE = 0,
   PENDING_STATE_PLANNED,
   PENDING_STATE_PLACED,
   PENDING_STATE_ACTIVE,
   PENDING_STATE_TRIGGERED,
   PENDING_STATE_CANCELLED,
   PENDING_STATE_EXPIRED,
   PENDING_STATE_REJECTED,
   PENDING_STATE_INVALID
  };

//====================================================================
// ساختار سفارش Pending
//====================================================================
struct PendingOrderRecord
  {
   ulong                    local_id;
   ulong                    scenario_id;
   ulong                    ticket;

   string                   symbol;
   ENUM_SCENARIO_DIRECTION  direction;
   ENUM_ENTRY_PLAN_TYPE     plan_type;
   ENUM_PENDING_ORDER_STATE state;

   double                   volume;
   double                   price;
   double                   stop_loss;
   double                   take_profit;

   datetime                 created_time;
   datetime                 placed_time;
   datetime                 expiry_time;
   datetime                 last_update_time;

   bool                     active;
   bool                     cancellation_requested;

   string                   reason;
   string                   broker_comment;
  };

//====================================================================
// تبدیل وضعیت Pending به فارسی
//====================================================================
string PendingStateToPersian(const ENUM_PENDING_ORDER_STATE state)
  {
   switch(state)
     {
      case PENDING_STATE_PLANNED:    return "برنامه‌ریزی شده";
      case PENDING_STATE_PLACED:     return "ثبت شده";
      case PENDING_STATE_ACTIVE:     return "فعال";
      case PENDING_STATE_TRIGGERED:  return "فعال شده و تبدیل به معامله شده";
      case PENDING_STATE_CANCELLED:  return "لغو شده";
      case PENDING_STATE_EXPIRED:    return "منقضی شده";
      case PENDING_STATE_REJECTED:   return "رد شده";
      case PENDING_STATE_INVALID:    return "نامعتبر";
      default:                       return "نامشخص";
     }
  }

//====================================================================
// تبدیل Retcode به متن قابل فهم
//====================================================================
string PendingOrder_RetcodeToText(const int retcode)
  {
   switch(retcode)
     {
      case TRADE_RETCODE_REQUOTE:            return "Requote";
      case TRADE_RETCODE_REJECT:             return "Reject";
      case TRADE_RETCODE_CANCEL:             return "Cancel";
      case TRADE_RETCODE_PLACED:             return "Placed";
      case TRADE_RETCODE_DONE:               return "Done";
      case TRADE_RETCODE_DONE_PARTIAL:       return "Partial";
      case TRADE_RETCODE_ERROR:              return "Error";
      case TRADE_RETCODE_TIMEOUT:            return "Timeout";
      case TRADE_RETCODE_INVALID:            return "Invalid Request";
      case TRADE_RETCODE_INVALID_VOLUME:     return "Invalid Volume";
      case TRADE_RETCODE_INVALID_PRICE:      return "Invalid Price";
      case TRADE_RETCODE_INVALID_STOPS:      return "Invalid Stops";
      case TRADE_RETCODE_TRADE_DISABLED:     return "Trade Disabled";
      case TRADE_RETCODE_MARKET_CLOSED:      return "Market Closed";
      case TRADE_RETCODE_NO_MONEY:           return "No Money";
      case TRADE_RETCODE_PRICE_CHANGED:      return "Price Changed";
      case TRADE_RETCODE_PRICE_OFF:          return "No Quotes";
      case TRADE_RETCODE_INVALID_EXPIRATION: return "Invalid Expiration";
      case TRADE_RETCODE_ORDER_CHANGED:      return "Order Changed";
      case TRADE_RETCODE_TOO_MANY_REQUESTS:  return "Too Many Requests";
      default:                               return "Unknown (" + IntegerToString(retcode) + ")";
     }
  }

//====================================================================
// مقداردهی اولیه رکورد
//====================================================================
void PendingOrder_Init(PendingOrderRecord &record)
  {
   record.local_id                 = 0;
   record.scenario_id              = 0;
   record.ticket                   = 0;

   record.symbol                   = "";
   record.direction                = SCENARIO_DIRECTION_NONE;
   record.plan_type                = ENTRY_PLAN_NONE;
   record.state                    = PENDING_STATE_NONE;

   record.volume                   = 0.0;
   record.price                    = 0.0;
   record.stop_loss                = 0.0;
   record.take_profit              = 0.0;

   record.created_time             = 0;
   record.placed_time              = 0;
   record.expiry_time              = 0;
   record.last_update_time         = 0;

   record.active                   = false;
   record.cancellation_requested   = false;

   record.reason                   = "";
   record.broker_comment           = "";
  }

//====================================================================
// تبدیل Entry Plan به نوع Pending سفارش متاتریدر
//====================================================================
bool PendingOrder_GetMqlType(const EntryPlan &plan,
                             ENUM_ORDER_TYPE &order_type)
  {
   order_type = ORDER_TYPE_BUY_LIMIT;

   if(plan.direction == SCENARIO_DIRECTION_BUY &&
      plan.type == ENTRY_PLAN_LIMIT)
     {
      order_type = ORDER_TYPE_BUY_LIMIT;
      return true;
     }

   if(plan.direction == SCENARIO_DIRECTION_SELL &&
      plan.type == ENTRY_PLAN_LIMIT)
     {
      order_type = ORDER_TYPE_SELL_LIMIT;
      return true;
     }

   if(plan.direction == SCENARIO_DIRECTION_BUY &&
      plan.type == ENTRY_PLAN_STOP)
     {
      order_type = ORDER_TYPE_BUY_STOP;
      return true;
     }

   if(plan.direction == SCENARIO_DIRECTION_SELL &&
      plan.type == ENTRY_PLAN_STOP)
     {
      order_type = ORDER_TYPE_SELL_STOP;
      return true;
     }

   return false;
  }

//====================================================================
// نرمال‌سازی قیمت
//====================================================================
double PendingOrder_NormalizePrice(const string symbol,
                                   const double price)
  {
   if(symbol == "" || price <= 0.0)
      return 0.0;

   const int digits =
      (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   return NormalizeDouble(price, digits);
  }

//====================================================================
// نرمال‌سازی حجم به سمت ریسک کمتر
//====================================================================
double PendingOrder_NormalizeVolumeDown(const string symbol,
                                        const double volume)
  {
   if(symbol == "" || volume <= 0.0)
      return 0.0;

   const double min_volume =
      SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

   const double max_volume =
      SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

   const double step =
      SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(min_volume <= 0.0 ||
      max_volume <= 0.0 ||
      step <= 0.0)
      return 0.0;

   double result =
      MathMin(volume, max_volume);

   result =
      MathFloor((result + 1e-12) / step) * step;

   result =
      NormalizeDouble(result, 8);

   if(result < min_volume)
      return 0.0;

   return result;
  }

//====================================================================
// بررسی مجاز بودن نوع سفارش در نماد
//====================================================================
bool PendingOrder_IsTypeAllowed(const string symbol,
                                const ENUM_ORDER_TYPE order_type)
  {
   if(symbol == "")
      return false;

   const long order_mask =
      SymbolInfoInteger(symbol, SYMBOL_ORDER_MODE);

   if(order_type == ORDER_TYPE_BUY_LIMIT ||
      order_type == ORDER_TYPE_SELL_LIMIT)
     {
      if((order_mask & SYMBOL_ORDER_LIMIT) == 0)
         return false;
     }

   if(order_type == ORDER_TYPE_BUY_STOP ||
      order_type == ORDER_TYPE_SELL_STOP)
     {
      if((order_mask & SYMBOL_ORDER_STOP) == 0)
         return false;
     }

   return true;
  }

//====================================================================
// دریافت فاصله حداقل مجاز بروکر برای Pending
//====================================================================
bool PendingOrder_CheckStopsLevel(const string symbol,
                                  const ENUM_ORDER_TYPE order_type,
                                  const double price)
  {
   if(symbol == "" || price <= 0.0)
      return false;

   const double point =
      SymbolInfoDouble(symbol, SYMBOL_POINT);

   if(point <= 0.0)
      return false;

   const long stops_level =
      SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);

   const double min_distance =
      (double)stops_level * point;

   if(min_distance <= 0.0)
      return true;

   MqlTick tick;

   if(!SymbolInfoTick(symbol, tick))
      return false;

   if(order_type == ORDER_TYPE_BUY_LIMIT ||
      order_type == ORDER_TYPE_BUY_STOP)
     {
      if(order_type == ORDER_TYPE_BUY_LIMIT)
         return ((tick.ask - price) >= min_distance);

      return ((price - tick.ask) >= min_distance);
     }

   if(order_type == ORDER_TYPE_SELL_LIMIT)
      return ((price - tick.bid) >= min_distance);

   if(order_type == ORDER_TYPE_SELL_STOP)
      return ((tick.bid - price) >= min_distance);

   return false;
  }

//====================================================================
// تشخیص اینکه دو قیمت برای Duplicate یکسان محسوب می‌شوند یا نه
//====================================================================
bool PendingOrder_IsSamePrice(const string symbol,
                               const double price_a,
                               const double price_b)
  {
   if(symbol == "" ||
      price_a <= 0.0 ||
      price_b <= 0.0)
      return false;

   const double point =
      SymbolInfoDouble(symbol, SYMBOL_POINT);

   const double tick_size =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

   double tolerance = point;

   if(tick_size > tolerance)
      tolerance = tick_size;

   if(tolerance <= 0.0)
      tolerance = 0.00000001;

   return (MathAbs(price_a - price_b) <= tolerance * 0.5);
  }

//====================================================================
// تشخیص یکسان بودن حجم
//====================================================================
bool PendingOrder_IsSameVolume(const string symbol,
                               const double volume_a,
                               const double volume_b)
  {
   if(symbol == "" ||
      volume_a <= 0.0 ||
      volume_b <= 0.0)
      return false;

   const double step =
      SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   double tolerance = 1e-8;

   if(step > 0.0)
      tolerance =
         MathMax(step * 0.5, 1e-8);

   return (MathAbs(volume_a - volume_b) <= tolerance);
  }

//====================================================================
// تشخیص یکسان بودن SL / TP
//
// مقدار صفر با صفر برابر است.
//====================================================================
bool PendingOrder_IsSameStopValue(const string symbol,
                                  const double value_a,
                                  const double value_b)
  {
   if(symbol == "")
      return false;

   if(value_a <= 0.0 && value_b <= 0.0)
      return true;

   if(value_a <= 0.0 || value_b <= 0.0)
      return false;

   return PendingOrder_IsSamePrice(
      symbol,
      value_a,
      value_b
   );
  }

//====================================================================
// تشخیص نوع Pending معتبر
//====================================================================
bool PendingOrder_IsPendingType(const ENUM_ORDER_TYPE order_type)
  {
   return
      (order_type == ORDER_TYPE_BUY_LIMIT ||
       order_type == ORDER_TYPE_SELL_LIMIT ||
       order_type == ORDER_TYPE_BUY_STOP ||
       order_type == ORDER_TYPE_SELL_STOP);
  }

//====================================================================
// بررسی کامل Signature دو سفارش
//
// کلید Duplicate:
// Symbol + Magic + OrderType + Price + Volume + SL + TP
//
// ScenarioID عمداً در Signature نیست.
// چون Duplicate بودن یک سفارش وابسته به مشخصات واقعی سفارش است، نه
// شماره سناریوی داخلی.
//====================================================================
bool PendingOrder_IsSameOrderSignature(
   const string existing_symbol,
   const ulong existing_magic,
   const ENUM_ORDER_TYPE existing_type,
   const double existing_price,
   const double existing_volume,
   const double existing_sl,
   const double existing_tp,
   const string requested_symbol,
   const ulong requested_magic,
   const ENUM_ORDER_TYPE requested_type,
   const double requested_price,
   const double requested_volume,
   const double requested_sl,
   const double requested_tp)
  {
   if(existing_symbol != requested_symbol)
      return false;

   if(existing_magic != requested_magic)
      return false;

   if(existing_type != requested_type)
      return false;

   if(!PendingOrder_IsSamePrice(
         requested_symbol,
         existing_price,
         requested_price))
      return false;

   if(!PendingOrder_IsSameVolume(
         requested_symbol,
         existing_volume,
         requested_volume))
      return false;

   if(!PendingOrder_IsSameStopValue(
         requested_symbol,
         existing_sl,
         requested_sl))
      return false;

   if(!PendingOrder_IsSameStopValue(
         requested_symbol,
         existing_tp,
         requested_tp))
      return false;

   return true;
  }

//====================================================================
// جستجوی Duplicate واقعی در حساب
//
// این تابع Ticket سفارش موجود را نیز برمی‌گرداند تا لاگ دقیق باشد.
//====================================================================
bool PendingOrder_FindDuplicateOnAccount(
   const string symbol,
   const ENUM_ORDER_TYPE order_type,
   const double price,
   const double volume,
   const double stop_loss,
   const double take_profit,
   const ulong magic,
   const ulong exclude_ticket,
   ulong &existing_ticket)
  {
   existing_ticket = 0;

   if(symbol == "" ||
      price <= 0.0 ||
      volume <= 0.0)
      return false;

   if(!PendingOrder_IsPendingType(order_type))
      return false;

   const int total_orders =
      OrdersTotal();

   if(total_orders <= 0)
      return false;

   for(int i = 0; i < total_orders; i++)
     {
      const ulong ticket =
         OrderGetTicket(i);

      if(ticket == 0)
         continue;

      if(exclude_ticket > 0 &&
         ticket == exclude_ticket)
         continue;

      const string existing_symbol =
         OrderGetString(ORDER_SYMBOL);

      if(existing_symbol != symbol)
         continue;

      const ulong existing_magic =
         (ulong)OrderGetInteger(ORDER_MAGIC);

      if(existing_magic != magic)
         continue;

      const ENUM_ORDER_TYPE existing_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(!PendingOrder_IsPendingType(existing_type))
         continue;

      if(existing_type != order_type)
         continue;

      const double existing_price =
         OrderGetDouble(ORDER_PRICE_OPEN);

      const double existing_volume =
         OrderGetDouble(ORDER_VOLUME_CURRENT);

      const double existing_sl =
         OrderGetDouble(ORDER_SL);

      const double existing_tp =
         OrderGetDouble(ORDER_TP);

      if(!PendingOrder_IsSameOrderSignature(
            existing_symbol,
            existing_magic,
            existing_type,
            existing_price,
            existing_volume,
            existing_sl,
            existing_tp,
            symbol,
            magic,
            order_type,
            price,
            volume,
            stop_loss,
            take_profit))
         continue;

      existing_ticket = ticket;

      const int digits =
         (int)SymbolInfoInteger(
            symbol,
            SYMBOL_DIGITS
         );

      Print(
         "[PENDING] DUPLICATE FOUND",
         " | ExistingTicket=", existing_ticket,
         " | Symbol=", existing_symbol,
         " | Magic=", existing_magic,
         " | Type=", EnumToString(existing_type),
         " | Price=",
         DoubleToString(existing_price, digits),
         " | Volume=",
         DoubleToString(existing_volume, 4),
         " | SL=",
         DoubleToString(existing_sl, digits),
         " | TP=",
         DoubleToString(existing_tp, digits)
      );

      return true;
     }

   return false;
  }

//====================================================================
// Wrapper ساده برای بررسی Duplicate
//====================================================================
bool PendingOrder_IsDuplicateOnAccount(
   const string symbol,
   const ENUM_ORDER_TYPE order_type,
   const double price,
   const double volume,
   const double stop_loss,
   const double take_profit,
   const ulong magic,
   const ulong exclude_ticket = 0)
  {
   ulong existing_ticket = 0;

   return PendingOrder_FindDuplicateOnAccount(
      symbol,
      order_type,
      price,
      volume,
      stop_loss,
      take_profit,
      magic,
      exclude_ticket,
      existing_ticket
   );
  }

//====================================================================
// بررسی Duplicate بر اساس رکورد جاری
//
// این تابع نیز Signature کامل را بررسی می‌کند.
//====================================================================
bool PendingOrder_IsDuplicateRecord(
   const PendingOrderRecord &record)
  {
   if(record.ticket == 0)
      return false;

   if(record.state != PENDING_STATE_PLACED &&
      record.state != PENDING_STATE_ACTIVE)
      return false;

   if(!OrderSelect(record.ticket))
      return false;

   const string symbol =
      OrderGetString(ORDER_SYMBOL);

   const ulong magic =
      (ulong)OrderGetInteger(ORDER_MAGIC);

   const ENUM_ORDER_TYPE existing_type =
      (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

   const double existing_price =
      OrderGetDouble(ORDER_PRICE_OPEN);

   const double existing_volume =
      OrderGetDouble(ORDER_VOLUME_CURRENT);

   const double existing_sl =
      OrderGetDouble(ORDER_SL);

   const double existing_tp =
      OrderGetDouble(ORDER_TP);

   ENUM_ORDER_TYPE requested_type;

   if(record.plan_type == ENTRY_PLAN_LIMIT)
     {
      if(record.direction == SCENARIO_DIRECTION_BUY)
         requested_type = ORDER_TYPE_BUY_LIMIT;
      else
      if(record.direction == SCENARIO_DIRECTION_SELL)
         requested_type = ORDER_TYPE_SELL_LIMIT;
      else
         return false;
     }
   else
   if(record.plan_type == ENTRY_PLAN_STOP)
     {
      if(record.direction == SCENARIO_DIRECTION_BUY)
         requested_type = ORDER_TYPE_BUY_STOP;
      else
      if(record.direction == SCENARIO_DIRECTION_SELL)
         requested_type = ORDER_TYPE_SELL_STOP;
      else
         return false;
     }
   else
      return false;

   return PendingOrder_IsSameOrderSignature(
      symbol,
      magic,
      existing_type,
      existing_price,
      existing_volume,
      existing_sl,
      existing_tp,
      record.symbol,
      (ulong)Inp_MagicNumber,
      requested_type,
      record.price,
      record.volume,
      record.stop_loss,
      record.take_profit
   );
  }

//====================================================================
// ایجاد رکورد برنامه‌ریزی‌شده
//====================================================================
bool PendingOrder_Prepare(const EntryPlan &plan,
                          const double volume,
                          const double stop_loss,
                          const double take_profit,
                          const datetime current_time,
                          PendingOrderRecord &record)
  {
   PendingOrder_Init(record);

   if(!Inp_AllowPendingOrders)
      return false;

   if(plan.type != ENTRY_PLAN_LIMIT &&
      plan.type != ENTRY_PLAN_STOP)
      return false;

   if(!plan.executable)
      return false;

   if(plan.symbol == "")
      return false;

   if(plan.entry_price <= 0.0)
      return false;

   if(volume <= 0.0)
      return false;

   ENUM_ORDER_TYPE order_type;

   if(!PendingOrder_GetMqlType(
         plan,
         order_type))
      return false;

   record.scenario_id =
      plan.scenario_id;

   record.symbol =
      plan.symbol;

   record.direction =
      plan.direction;

   record.plan_type =
      plan.type;

   record.state =
      PENDING_STATE_PLANNED;

   record.volume =
      PendingOrder_NormalizeVolumeDown(
         plan.symbol,
         volume
      );

   record.price =
      PendingOrder_NormalizePrice(
         plan.symbol,
         plan.entry_price
      );

   record.stop_loss =
      (stop_loss > 0.0
       ? PendingOrder_NormalizePrice(
            plan.symbol,
            stop_loss)
       : 0.0);

   record.take_profit =
      (take_profit > 0.0
       ? PendingOrder_NormalizePrice(
            plan.symbol,
            take_profit)
       : 0.0);

   record.created_time =
      current_time;

   record.last_update_time =
      current_time;

   if(Inp_Pending_Expiration_Minutes > 0)
      record.expiry_time =
         current_time +
         (Inp_Pending_Expiration_Minutes * 60);
   else
      record.expiry_time = 0;

   record.active =
      false;

   record.reason =
      "سفارش Pending برای ارسال آماده شده است";

   if(record.volume <= 0.0)
     {
      record.state =
         PENDING_STATE_INVALID;

      record.reason =
         "حجم Pending پس از نرمال‌سازی معتبر نیست";

      return false;
     }

   if(record.price <= 0.0)
     {
      record.state =
         PENDING_STATE_INVALID;

      record.reason =
         "قیمت Pending معتبر نیست";

      return false;
     }

   if(!PendingOrder_IsTypeAllowed(
         plan.symbol,
         order_type))
     {
      record.state =
         PENDING_STATE_INVALID;

      record.reason =
         "نوع سفارش Pending توسط نماد مجاز نیست";

      return false;
     }

   return true;
  }

//====================================================================
// ارسال سفارش Pending
//
// قبل از OrderSend() سفارش‌های واقعی حساب برای Duplicate کامل
// بررسی می‌شوند.
//====================================================================
bool PendingOrder_Place(PendingOrderRecord &record,
                        const string comment,
                        const datetime current_time)
  {
   if(record.state != PENDING_STATE_PLANNED)
      return false;

   if(record.symbol == "" ||
      record.volume <= 0.0 ||
      record.price <= 0.0)
      return false;

   if(record.expiry_time > 0 &&
      current_time >= record.expiry_time)
     {
      record.state =
         PENDING_STATE_EXPIRED;

      record.active =
         false;

      record.last_update_time =
         current_time;

      record.reason =
         "عمر سفارش قبل از ارسال به پایان رسیده است";

      Print(
         "[PENDING] EXPIRED BEFORE PLACE | ",
         record.reason
      );

      return false;
     }

   ENUM_ORDER_TYPE order_type;

   if(record.plan_type == ENTRY_PLAN_LIMIT)
     {
      if(record.direction == SCENARIO_DIRECTION_BUY)
         order_type = ORDER_TYPE_BUY_LIMIT;
      else
      if(record.direction == SCENARIO_DIRECTION_SELL)
         order_type = ORDER_TYPE_SELL_LIMIT;
      else
         return false;
     }
   else
   if(record.plan_type == ENTRY_PLAN_STOP)
     {
      if(record.direction == SCENARIO_DIRECTION_BUY)
         order_type = ORDER_TYPE_BUY_STOP;
      else
      if(record.direction == SCENARIO_DIRECTION_SELL)
         order_type = ORDER_TYPE_SELL_STOP;
      else
         return false;
     }
   else
      return false;

   //===============================================================
   // Duplicate Protection - بررسی مستقیم سفارش‌های واقعی حساب
   //===============================================================
   ulong existing_duplicate_ticket = 0;

   if(PendingOrder_FindDuplicateOnAccount(
         record.symbol,
         order_type,
         record.price,
         record.volume,
         record.stop_loss,
         record.take_profit,
         (ulong)Inp_MagicNumber,
         0,
         existing_duplicate_ticket))
     {
      record.ticket =
         existing_duplicate_ticket;

      record.state =
         PENDING_STATE_REJECTED;

      record.active =
         false;

      record.last_update_time =
         current_time;

      record.reason =
         "سفارش Pending کاملاً یکسان از قبل در حساب وجود دارد";

      const int digits =
         (int)SymbolInfoInteger(
            record.symbol,
            SYMBOL_DIGITS
         );

      Print(
         "[PENDING] DUPLICATE BLOCKED",
         " | ExistingTicket=",
         existing_duplicate_ticket,
         " | Symbol=",
         record.symbol,
         " | Magic=",
         Inp_MagicNumber,
         " | Type=",
         EnumToString(order_type),
         " | Price=",
         DoubleToString(
            record.price,
            digits
         ),
         " | Volume=",
         DoubleToString(
            record.volume,
            4
         ),
         " | SL=",
         DoubleToString(
            record.stop_loss,
            digits
         ),
         " | TP=",
         DoubleToString(
            record.take_profit,
            digits
         ),
         " | Scenario=",
         record.scenario_id,
         " | Reason=",
         record.reason
      );

      return false;
     }

   //===============================================================
   // بررسی فاصله مجاز Pending
   //===============================================================
   if(!PendingOrder_CheckStopsLevel(
         record.symbol,
         order_type,
         record.price))
     {
      record.state =
         PENDING_STATE_REJECTED;

      record.active =
         false;

      record.last_update_time =
         current_time;

      record.reason =
         "فاصله قیمت Pending با قیمت فعلی از حداقل مجاز نماد کمتر است";

      Print(
         "[PENDING] REJECTED | ",
         record.reason
      );

      return false;
     }

   MqlTradeRequest request;
   MqlTradeResult  result;

   ZeroMemory(request);
   ZeroMemory(result);

   request.action =
      TRADE_ACTION_PENDING;

   request.magic =
      Inp_MagicNumber;

   request.symbol =
      record.symbol;

   request.volume =
      record.volume;

   request.type =
      order_type;

   request.price =
      record.price;

   request.sl =
      record.stop_loss;

   request.tp =
      record.take_profit;

   //===============================================================
   // Expiration
   //===============================================================
   if(record.expiry_time > 0 &&
      record.expiry_time > current_time)
     {
      request.type_time =
         ORDER_TIME_SPECIFIED;

      request.expiration =
         record.expiry_time;
     }
   else
     {
      request.type_time =
         ORDER_TIME_GTC;

      request.expiration =
         0;
     }

   request.type_filling =
      ORDER_FILLING_RETURN;

   request.deviation =
      (ulong)MathMax(
         0,
         Inp_MaxSlippagePoints
      );

   if(comment != "")
      request.comment =
         comment;
   else
      request.comment =
         "TFlab Pending";

   const int digits =
      (int)SymbolInfoInteger(
         record.symbol,
         SYMBOL_DIGITS
      );

   Print(
      "[PENDING] SENDING",
      " | Type=",
      EnumToString(order_type),
      " | Volume=",
      DoubleToString(
         record.volume,
         4
      ),
      " | Price=",
      DoubleToString(
         record.price,
         digits
      ),
      " | SL=",
      DoubleToString(
         record.stop_loss,
         digits
      ),
      " | TP=",
      DoubleToString(
         record.take_profit,
         digits
      ),
      " | Scenario=",
      record.scenario_id,
      " | Expiry=",
      (
         record.expiry_time > 0
         ? TimeToString(
              record.expiry_time,
              TIME_DATE | TIME_MINUTES
           )
         : "GTC"
      )
   );

   ResetLastError();

   if(!OrderSend(
         request,
         result))
     {
      const int last_error =
         GetLastError();

      record.state =
         PENDING_STATE_REJECTED;

      record.active =
         false;

      record.last_update_time =
         current_time;

      record.reason =
         "ارسال سفارش Pending توسط پلتفرم ناموفق بود";

      Print(
         "[PENDING] PLACE FAIL",
         " | Retcode=",
         result.retcode,
         " | RetcodeText=",
         PendingOrder_RetcodeToText(
            result.retcode
         ),
         " | Comment=",
         result.comment,
         " | Error=",
         last_error
      );

      return false;
     }

   if(result.retcode != TRADE_RETCODE_DONE &&
      result.retcode != TRADE_RETCODE_PLACED &&
      result.retcode != TRADE_RETCODE_DONE_PARTIAL)
     {
      record.state =
         PENDING_STATE_REJECTED;

      record.active =
         false;

      record.last_update_time =
         current_time;

      record.reason =
         "بروکر سفارش Pending را نپذیرفت";

      Print(
         "[PENDING] PLACE REJECTED",
         " | Retcode=",
         result.retcode,
         " | RetcodeText=",
         PendingOrder_RetcodeToText(
            result.retcode
         ),
         " | Comment=",
         result.comment
      );

      return false;
     }

   record.ticket =
      result.order;

   record.placed_time =
      current_time;

   record.last_update_time =
      current_time;

   record.state =
      PENDING_STATE_PLACED;

   record.active =
      true;

   record.broker_comment =
      comment;

   record.reason =
      "سفارش Pending با موفقیت ثبت شد";

   Print(
      "[PENDING] PLACE SUCCESS",
      " | Ticket=",
      record.ticket,
      " | Price=",
      DoubleToString(
         record.price,
         digits
      ),
      " | Volume=",
      DoubleToString(
         record.volume,
         4
      ),
      " | Retcode=",
      PendingOrder_RetcodeToText(
         result.retcode
      )
   );

   return true;
  }

//====================================================================
// بررسی وجود سفارش Pending در حساب بر اساس Ticket
//====================================================================
bool PendingOrder_IsStillExisting(
   const ulong ticket)
  {
   if(ticket == 0)
      return false;

   if(OrderSelect(ticket))
      return true;

   return false;
  }

//====================================================================
// بررسی وضعیت سفارش Pending در بازار
//====================================================================
bool PendingOrder_UpdateState(
   PendingOrderRecord &record,
   const datetime current_time)
  {
   if(record.ticket == 0)
      return false;

   if(record.state != PENDING_STATE_PLACED &&
      record.state != PENDING_STATE_ACTIVE)
      return false;

   record.last_update_time =
      current_time;

   if(record.expiry_time > 0 &&
      current_time >= record.expiry_time)
     {
      record.state =
         PENDING_STATE_EXPIRED;

      record.active =
         false;

      record.reason =
         "عمر سفارش Pending به پایان رسیده است";

      Print(
         "[PENDING] EXPIRED",
         " | Ticket=",
         record.ticket,
         " | ",
         record.reason
      );

      return true;
     }

   if(OrderSelect(record.ticket))
     {
      record.state =
         PENDING_STATE_ACTIVE;

      record.active =
         true;

      record.reason =
         "سفارش Pending همچنان در حساب فعال است";

      return true;
     }

   //=================================================================
   // نبودن سفارش می‌تواند به معنی Trigger شدن، لغو یا حذف باشد
   //=================================================================
   record.state =
      PENDING_STATE_TRIGGERED;

   record.active =
      false;

   record.reason =
      "سفارش Pending دیگر در لیست سفارش‌ها وجود ندارد؛ نتیجه نهایی باید از تاریخچه بررسی شود";

   Print(
      "[PENDING] TRIGGERED OR REMOVED",
      " | Ticket=",
      record.ticket,
      " | Scenario=",
      record.scenario_id,
      " | ",
      record.reason
   );

   return true;
  }

//====================================================================
// لغو Pending
//====================================================================
bool PendingOrder_Cancel(
   PendingOrderRecord &record,
   const string reason,
   const datetime current_time)
  {
   if(record.ticket == 0)
      return false;

   if(record.state != PENDING_STATE_PLACED &&
      record.state != PENDING_STATE_ACTIVE)
      return false;

   MqlTradeRequest request;
   MqlTradeResult  result;

   ZeroMemory(request);
   ZeroMemory(result);

   request.action =
      TRADE_ACTION_REMOVE;

   request.order =
      record.ticket;

   Print(
      "[PENDING] CANCELING",
      " | Ticket=",
      record.ticket,
      " | Reason=",
      reason
   );

   ResetLastError();

   if(!OrderSend(
         request,
         result))
     {
      const int last_error =
         GetLastError();

      record.reason =
         "لغو Pending توسط پلتفرم ناموفق بود";

      record.last_update_time =
         current_time;

      Print(
         "[PENDING] CANCEL FAIL",
         " | Ticket=",
         record.ticket,
         " | Retcode=",
         result.retcode,
         " | RetcodeText=",
         PendingOrder_RetcodeToText(
            result.retcode
         ),
         " | Error=",
         last_error
      );

      return false;
     }

   if(result.retcode != TRADE_RETCODE_DONE)
     {
      record.reason =
         "بروکر لغو سفارش Pending را تأیید نکرد";

      record.last_update_time =
         current_time;

      Print(
         "[PENDING] CANCEL REJECTED",
         " | Ticket=",
         record.ticket,
         " | Retcode=",
         result.retcode,
         " | RetcodeText=",
         PendingOrder_RetcodeToText(
            result.retcode
         )
      );

      return false;
     }

   record.state =
      PENDING_STATE_CANCELLED;

   record.active =
      false;

   record.cancellation_requested =
      true;

   record.last_update_time =
      current_time;

   record.reason =
      (
         reason != ""
         ? reason
         : "سفارش Pending لغو شد"
      );

   Print(
      "[PENDING] CANCEL SUCCESS",
      " | Ticket=",
      record.ticket,
      " | ",
      record.reason
   );

   return true;
  }

//====================================================================
// بررسی و لغو خودکار در صورت Invalid شدن سناریو
//====================================================================
bool PendingOrder_HandleScenarioInvalidation(
   PendingOrderRecord &record,
   const TradingScenario &scenario,
   const datetime current_time)
  {
   if(!Inp_Cancel_Pending_On_Invalid)
      return false;

   if(record.state != PENDING_STATE_PLACED &&
      record.state != PENDING_STATE_ACTIVE)
      return false;

   if(record.scenario_id == 0 ||
      record.scenario_id != scenario.id)
      return false;

   if(scenario.status != SCENARIO_STATUS_INVALID &&
      scenario.status != SCENARIO_STATUS_EXPIRED &&
      scenario.status != SCENARIO_STATUS_CANCELLED)
      return false;

   return PendingOrder_Cancel(
      record,
      "سناریوی وابسته دیگر معتبر نیست",
      current_time
   );
  }

//====================================================================
// شمارش Pendingهای فعال از آرایه رکوردها
//====================================================================
int PendingOrder_CountActive(
   const PendingOrderRecord &records[],
   const int total_records)
  {
   if(total_records <= 0)
      return 0;

   int count = 0;

   for(int i = 0; i < total_records; i++)
     {
      if(records[i].active &&
         (records[i].state == PENDING_STATE_PLACED ||
          records[i].state == PENDING_STATE_ACTIVE))
         count++;
     }

   return count;
  }

//====================================================================
// تولید متن فارسی برای گزارش
//====================================================================
string PendingOrder_ToText(
   const PendingOrderRecord &record)
  {
   string text = "";

   text +=
      "شناسه داخلی: " +
      (string)record.local_id;

   text +=
      " | شناسه سناریو: " +
      (string)record.scenario_id;

   text +=
      " | Ticket: " +
      (string)record.ticket;

   text +=
      " | نماد: " +
      record.symbol;

   text +=
      " | جهت: " +
      ScenarioDirectionToPersian(
         record.direction
      );

   text +=
      " | روش: " +
      EntryPlanTypeToPersian(
         record.plan_type
      );

   text +=
      " | وضعیت: " +
      PendingStateToPersian(
         record.state
      );

   text +=
      " | حجم: " +
      DoubleToString(
         record.volume,
         2
      );

   text +=
      " | قیمت: " +
      DoubleToString(
         record.price,
         (int)SymbolInfoInteger(
            record.symbol,
            SYMBOL_DIGITS
         )
      );

   if(record.stop_loss > 0.0)
      text +=
         " | SL: " +
         DoubleToString(
            record.stop_loss,
            (int)SymbolInfoInteger(
               record.symbol,
               SYMBOL_DIGITS
            )
         );

   if(record.take_profit > 0.0)
      text +=
         " | TP: " +
         DoubleToString(
            record.take_profit,
            (int)SymbolInfoInteger(
               record.symbol,
               SYMBOL_DIGITS
            )
         );

   if(record.reason != "")
      text +=
         " | دلیل: " +
         record.reason;

   return text;
  }

//+------------------------------------------------------------------+

#endif // __TFLAB_PENDING_ORDER_MANAGER_MQH__