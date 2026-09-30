#ifndef __TFLAB_TRADE_LOGGER_MQH__
#define __TFLAB_TRADE_LOGGER_MQH__

//+------------------------------------------------------------------+
//|                         Trade_Logger.mqh                         |
//|                         TFlab New EA V.5                             |
//|                                                                  |
//| مسئولیت: ثبت کامل معاملات واقعی                                  |
//|                                                                  |
//| این فایل فقط اطلاعات معاملات واقعی را ثبت و مدیریت می‌کند.       |
//| منطق تحلیل، تصمیم‌گیری، Risk، اجرای سفارش و AI در فایل‌های دیگر  |
//| قرار دارند.                                                       |
//|                                                                  |
//| v2.1 - Fixed max_floating_loss + Breakeven logic + لاگ تشخیصی  |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// وضعیت معامله در سیستم ثبت گزارش
//====================================================================
enum ENUM_TRADE_LOG_STATUS
  {
   TRADE_LOG_UNKNOWN = 0,
   TRADE_LOG_OPEN,
   TRADE_LOG_PARTIAL,
   TRADE_LOG_CLOSED,
   TRADE_LOG_CANCELLED,
   TRADE_LOG_REJECTED
  };

//====================================================================
// علت ورود
//====================================================================
enum ENUM_TRADE_ENTRY_REASON
  {
   TRADE_ENTRY_REASON_UNKNOWN = 0,
   TRADE_ENTRY_REASON_MARKET,
   TRADE_ENTRY_REASON_LIMIT,
   TRADE_ENTRY_REASON_STOP,
   TRADE_ENTRY_REASON_MANUAL,
   TRADE_ENTRY_REASON_OTHER
  };

//====================================================================
// علت خروج
//====================================================================
enum ENUM_TRADE_EXIT_REASON
  {
   TRADE_EXIT_REASON_UNKNOWN = 0,
   TRADE_EXIT_REASON_TP,
   TRADE_EXIT_REASON_SL,
   TRADE_EXIT_REASON_PARTIAL,
   TRADE_EXIT_REASON_MANUAL,
   TRADE_EXIT_REASON_INVALIDATION,
   TRADE_EXIT_REASON_REVERSAL,
   TRADE_EXIT_REASON_TIME_EXIT,
   TRADE_EXIT_REASON_OTHER
  };

//====================================================================
// اطلاعات اصلی یک معامله واقعی
//====================================================================
struct TradeLogRecord
  {
   ulong                     ticket;
   ulong                     position_id;
   ulong                     magic;
   string                    symbol;

   ENUM_TRADE_LOG_STATUS     status;
   ENUM_TRADE_ENTRY_REASON   entry_reason;
   ENUM_TRADE_EXIT_REASON    exit_reason;

   ENUM_ORDER_TYPE           order_type;
   ENUM_POSITION_TYPE        position_type;

   datetime                  signal_time;
   datetime                  order_time;
   datetime                  open_time;
   datetime                  last_update_time;
   datetime                  close_time;

   double                    planned_entry;
   double                    actual_entry;
   double                    initial_sl;
   double                    initial_tp;
   double                    current_sl;
   double                    current_tp;
   double                    close_price;

   double                    initial_volume;
   double                    current_volume;
   double                    closed_volume;

   double                    gross_profit;
   double                    commission;
   double                    swap;
   double                    fee;
   double                    net_profit;

   double                    max_floating_profit;
   double                    max_floating_loss;

   double                    risk_money;
   double                    risk_percent;

   double                    target_distance;
   double                    sl_distance;
   double                    rr_planned;

   datetime                  first_profit_time;
   datetime                  first_breakeven_time;
   datetime                  partial_close_time;

   long                      seconds_to_first_profit;
   long                      seconds_in_trade;

   string                    scenario_id;
   string                    scenario_direction;
   string                    scenario_reason;
   string                    entry_condition;
   string                    management_summary;
   string                    exit_reason_text;
   string                    notes;
  };

//-------------------------------------------------------------------------
// تبدیل وضعیت به فارسی
//-------------------------------------------------------------------------
string TradeLogStatusToPersian(const ENUM_TRADE_LOG_STATUS status)
  {
   switch(status)
     {
      case TRADE_LOG_OPEN:      return "باز";
      case TRADE_LOG_PARTIAL:   return "خروج بخشی";
      case TRADE_LOG_CLOSED:    return "بسته شده";
      case TRADE_LOG_CANCELLED: return "لغو شده";
      case TRADE_LOG_REJECTED:  return "رد شده";
      default:                  return "نامشخص";
     }
  }

//-------------------------------------------------------------------------
// تبدیل علت ورود به فارسی
//-------------------------------------------------------------------------
string TradeLogEntryReasonToPersian(const ENUM_TRADE_ENTRY_REASON reason)
  {
   switch(reason)
     {
      case TRADE_ENTRY_REASON_MARKET: return "ورود مستقیم";
      case TRADE_ENTRY_REASON_LIMIT:  return "لیمیت";
      case TRADE_ENTRY_REASON_STOP:   return "استاپ";
      case TRADE_ENTRY_REASON_MANUAL: return "دستی";
      case TRADE_ENTRY_REASON_OTHER:  return "سایر";
      default:                        return "نامشخص";
     }
  }

//-------------------------------------------------------------------------
// تبدیل علت خروج به فارسی
//-------------------------------------------------------------------------
string TradeLogExitReasonToPersian(const ENUM_TRADE_EXIT_REASON reason)
  {
   switch(reason)
     {
      case TRADE_EXIT_REASON_TP:           return "حد سود";
      case TRADE_EXIT_REASON_SL:           return "حد ضرر";
      case TRADE_EXIT_REASON_PARTIAL:      return "خروج بخشی";
      case TRADE_EXIT_REASON_MANUAL:       return "دستی";
      case TRADE_EXIT_REASON_INVALIDATION: return "ابطال سناریو";
      case TRADE_EXIT_REASON_REVERSAL:     return "بازگشت روند";
      case TRADE_EXIT_REASON_TIME_EXIT:    return "اتمام زمان";
      case TRADE_EXIT_REASON_OTHER:        return "سایر";
      default:                             return "نامشخص";
     }
  }

//-------------------------------------------------------------------------
// تبدیل نوع Position به فارسی
//-------------------------------------------------------------------------
string TradeLogPositionTypeToPersian(const ENUM_POSITION_TYPE type)
  {
   switch(type)
     {
      case POSITION_TYPE_BUY:  return "خرید";
      case POSITION_TYPE_SELL: return "فروش";
      default:                 return "نامشخص";
     }
  }

//-------------------------------------------------------------------------
// مقداردهی اولیه رکورد
//-------------------------------------------------------------------------
void TradeLog_Init(TradeLogRecord &record)
  {
   record.ticket                  = 0;
   record.position_id             = 0;
   record.magic                   = 0;
   record.symbol                  = "";

   record.status                  = TRADE_LOG_UNKNOWN;
   record.entry_reason            = TRADE_ENTRY_REASON_UNKNOWN;
   record.exit_reason             = TRADE_EXIT_REASON_UNKNOWN;

   record.order_type              = ORDER_TYPE_BUY;
   record.position_type           = POSITION_TYPE_BUY;

   record.signal_time             = 0;
   record.order_time              = 0;
   record.open_time               = 0;
   record.last_update_time        = 0;
   record.close_time              = 0;

   record.planned_entry           = 0.0;
   record.actual_entry            = 0.0;
   record.initial_sl              = 0.0;
   record.initial_tp              = 0.0;
   record.current_sl              = 0.0;
   record.current_tp              = 0.0;
   record.close_price             = 0.0;

   record.initial_volume          = 0.0;
   record.current_volume          = 0.0;
   record.closed_volume           = 0.0;

   record.gross_profit            = 0.0;
   record.commission              = 0.0;
   record.swap                    = 0.0;
   record.fee                     = 0.0;
   record.net_profit              = 0.0;

   record.max_floating_profit     = 0.0;
   record.max_floating_loss       = 0.0;

   record.risk_money              = 0.0;
   record.risk_percent            = 0.0;

   record.target_distance         = 0.0;
   record.sl_distance             = 0.0;
   record.rr_planned              = 0.0;

   record.first_profit_time       = 0;
   record.first_breakeven_time    = 0;
   record.partial_close_time      = 0;

   record.seconds_to_first_profit = 0;
   record.seconds_in_trade        = 0;

   record.scenario_id             = "";
   record.scenario_direction      = "";
   record.scenario_reason         = "";
   record.entry_condition         = "";
   record.management_summary      = "";
   record.exit_reason_text        = "";
   record.notes                   = "";
  }

//-------------------------------------------------------------------------
// اعتبارسنجی حداقل اطلاعات رکورد
//-------------------------------------------------------------------------
bool TradeLog_IsValid(const TradeLogRecord &record)
  {
   if(record.ticket == 0 && record.position_id == 0)
      return false;

   if(record.symbol == "")
      return false;

   return true;
  }

//-------------------------------------------------------------------------
// ثبت باز شدن معامله
// [اصلاح] ست کردن order_type + لاگ تشخیصی
//-------------------------------------------------------------------------
bool TradeLog_RecordOpen(TradeLogRecord &record,
                         const ulong ticket,
                         const ulong position_id,
                         const ulong magic,
                         const string symbol,
                         const ENUM_POSITION_TYPE position_type,
                         const ENUM_TRADE_ENTRY_REASON entry_reason,
                         const datetime signal_time,
                         const datetime open_time,
                         const double planned_entry,
                         const double actual_entry,
                         const double initial_sl,
                         const double initial_tp,
                         const double volume,
                         const double risk_money,
                         const double risk_percent,
                         const string scenario_id,
                         const string scenario_direction,
                         const string scenario_reason,
                         const string entry_condition)
  {
   TradeLog_Init(record);

   if(ticket == 0 && position_id == 0)
      return false;

   if(symbol == "")
      return false;

   record.ticket           = ticket;
   record.position_id      = position_id;
   record.magic            = magic;
   record.symbol           = symbol;

   record.status           = TRADE_LOG_OPEN;
   record.entry_reason     = entry_reason;
   record.position_type    = position_type;
   
   //--- [اصلاح] ست کردن صحیح order_type بر اساس position_type
   record.order_type       = (position_type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   record.signal_time      = signal_time;
   record.order_time       = open_time;
   record.open_time        = open_time;
   record.last_update_time = open_time;

   record.planned_entry    = planned_entry;
   record.actual_entry     = actual_entry;
   record.initial_sl       = initial_sl;
   record.initial_tp       = initial_tp;
   record.current_sl       = initial_sl;
   record.current_tp       = initial_tp;

   record.initial_volume   = volume;
   record.current_volume   = volume;

   record.risk_money       = risk_money;
   record.risk_percent     = risk_percent;

   if(actual_entry > 0.0 && initial_sl > 0.0)
      record.sl_distance = MathAbs(actual_entry - initial_sl);

   if(actual_entry > 0.0 && initial_tp > 0.0 && record.sl_distance > 0.0)
      record.rr_planned = MathAbs(initial_tp - actual_entry) / record.sl_distance;

   if(actual_entry > 0.0 && initial_tp > 0.0)
      record.target_distance = MathAbs(initial_tp - actual_entry);

   record.scenario_id        = scenario_id;
   record.scenario_direction = scenario_direction;
   record.scenario_reason    = scenario_reason;
   record.entry_condition    = entry_condition;

   //--- [جدید] لاگ تشخیصی
   Print(
      "[TRADE LOGGER] OPEN",
      " | Ticket=", record.ticket,
      " | PosID=", record.position_id,
      " | Dir=", TradeLogPositionTypeToPersian(record.position_type),
      " | Vol=", DoubleToString(record.initial_volume, 2),
      " | Entry=", DoubleToString(record.actual_entry, _Digits),
      " | SL=", DoubleToString(record.initial_sl, _Digits),
      " | TP=", DoubleToString(record.initial_tp, _Digits),
      " | Scenario=", record.scenario_id
   );

   return true;
  }

//-------------------------------------------------------------------------
// به‌روزرسانی وضعیت معامله باز
// [اصلاح] منطق max_floating_loss + Breakeven
//-------------------------------------------------------------------------
bool TradeLog_UpdateOpen(TradeLogRecord &record,
                         const datetime current_time,
                         const double current_price,
                         const double current_volume,
                         const double current_sl,
                         const double current_tp,
                         const double floating_profit)
  {
   if(!TradeLog_IsValid(record))
      return false;

   record.last_update_time = current_time;
   record.current_volume   = current_volume;
   record.current_sl       = current_sl;
   record.current_tp       = current_tp;

   if(floating_profit > record.max_floating_profit)
      record.max_floating_profit = floating_profit;

   //--- [اصلاح] max_floating_loss باید حداکثر ضرر مطلق (عدد مثبت) باشد
   double current_loss = -floating_profit;
   if(current_loss > record.max_floating_loss)
      record.max_floating_loss = current_loss;

   if(record.first_profit_time == 0 && floating_profit > 0.0)
     {
      record.first_profit_time = current_time;
      if(record.open_time > 0)
         record.seconds_to_first_profit = (long)(current_time - record.open_time);
     }

   //--- [اصلاح] تشخیص Breakeven بر اساس عبور قیمت از نقطه ورود
   if(record.first_breakeven_time == 0 && record.actual_entry > 0.0)
     {
      bool crossed_entry = false;
      if(record.position_type == POSITION_TYPE_BUY && current_price >= record.actual_entry)
         crossed_entry = true;
      else if(record.position_type == POSITION_TYPE_SELL && current_price <= record.actual_entry)
         crossed_entry = true;
         
      if(crossed_entry && floating_profit >= 0.0)
         record.first_breakeven_time = current_time;
     }

   return true;
  }

//-------------------------------------------------------------------------
// ثبت Partial Close
// [اصلاح] افزودن لاگ تشخیصی
//-------------------------------------------------------------------------
bool TradeLog_RecordPartialClose(TradeLogRecord &record,
                                 const datetime current_time,
                                 const double closed_volume,
                                 const double remaining_volume,
                                 const double realized_profit,
                                 const string reason)
  {
   if(!TradeLog_IsValid(record))
      return false;

   if(closed_volume <= 0.0)
      return false;

   record.status               = TRADE_LOG_PARTIAL;
   record.partial_close_time   = current_time;
   record.closed_volume       += closed_volume;
   record.current_volume       = remaining_volume;
   record.gross_profit        += realized_profit;
   record.last_update_time     = current_time;

   if(record.management_summary == "")
      record.management_summary = "خروج بخشی: " + reason;
   else
      record.management_summary += " | خروج بخشی: " + reason;

   Print(
      "[TRADE LOGGER] PARTIAL CLOSE",
      " | Ticket=", record.ticket,
      " | ClosedVol=", DoubleToString(closed_volume, 2),
      " | RemainVol=", DoubleToString(remaining_volume, 2),
      " | RealizedProfit=", DoubleToString(realized_profit, 2),
      " | Reason=", reason
   );

   return true;
  }

//-------------------------------------------------------------------------
// ثبت تغییر SL
//-------------------------------------------------------------------------
bool TradeLog_RecordSLChange(TradeLogRecord &record,
                             const datetime current_time,
                             const double new_sl,
                             const string reason)
  {
   if(!TradeLog_IsValid(record))
      return false;

   record.current_sl       = new_sl;
   record.last_update_time = current_time;

   if(record.management_summary == "")
      record.management_summary = "تغییر حد ضرر: " + reason;
   else
      record.management_summary += " | تغییر حد ضرر: " + reason;

   return true;
  }

//-------------------------------------------------------------------------
// ثبت تغییر TP
//-------------------------------------------------------------------------
bool TradeLog_RecordTPChange(TradeLogRecord &record,
                             const datetime current_time,
                             const double new_tp,
                             const string reason)
  {
   if(!TradeLog_IsValid(record))
      return false;

   record.current_tp       = new_tp;
   record.last_update_time = current_time;

   if(record.management_summary == "")
      record.management_summary = "تغییر حد سود: " + reason;
   else
      record.management_summary += " | تغییر حد سود: " + reason;

   return true;
  }

//-------------------------------------------------------------------------
// ثبت بسته شدن کامل معامله
// [اصلاح] افزودن Fee + لاگ تشخیصی
//-------------------------------------------------------------------------
bool TradeLog_RecordClose(TradeLogRecord &record,
                          const datetime close_time,
                          const double close_price,
                          const double closed_volume,
                          const double gross_profit,
                          const double commission,
                          const double swap,
                          const double fee,
                          const ENUM_TRADE_EXIT_REASON exit_reason,
                          const string exit_reason_text)
  {
   if(!TradeLog_IsValid(record))
      return false;

   record.status             = TRADE_LOG_CLOSED;
   record.close_time         = close_time;
   record.close_price        = close_price;
   record.closed_volume     += closed_volume;
   record.current_volume     = 0.0;

   record.gross_profit      += gross_profit;
   record.commission        += commission;
   record.swap              += swap;
   record.fee               += fee;
   record.net_profit         = record.gross_profit + record.commission + record.swap + record.fee;

   record.exit_reason        = exit_reason;
   record.exit_reason_text   = exit_reason_text;
   record.last_update_time   = close_time;

   if(record.open_time > 0)
      record.seconds_in_trade = (long)(close_time - record.open_time);

   if(record.first_profit_time > 0 && record.seconds_to_first_profit == 0)
      record.seconds_to_first_profit = (long)(record.first_profit_time - record.open_time);

   Print(
      "[TRADE LOGGER] CLOSE",
      " | Ticket=", record.ticket,
      " | Reason=", TradeLogExitReasonToPersian(record.exit_reason),
      " | Gross=", DoubleToString(record.gross_profit, 2),
      " | Net=", DoubleToString(record.net_profit, 2),
      " | Duration=", TradeLog_FormatDuration(record.seconds_in_trade)
   );

   return true;
  }

//-------------------------------------------------------------------------
// لغو Pending که هنوز معامله نشده است
//-------------------------------------------------------------------------
bool TradeLog_RecordCancelled(TradeLogRecord &record,
                              const datetime cancel_time,
                              const ENUM_TRADE_EXIT_REASON reason,
                              const string reason_text)
  {
   if(!TradeLog_IsValid(record))
      return false;

   record.status           = TRADE_LOG_CANCELLED;
   record.close_time       = cancel_time;
   record.exit_reason      = reason;
   record.exit_reason_text = reason_text;
   record.last_update_time = cancel_time;

   return true;
  }

//-------------------------------------------------------------------------
// علامت‌گذاری رد شدن سفارش
//-------------------------------------------------------------------------
bool TradeLog_RecordRejected(TradeLogRecord &record,
                             const datetime rejection_time,
                             const string reason_text)
  {
   if(!TradeLog_IsValid(record))
      return false;

   record.status           = TRADE_LOG_REJECTED;
   record.close_time       = rejection_time;
   record.exit_reason_text = reason_text;
   record.last_update_time = rejection_time;

   return true;
  }

//-------------------------------------------------------------------------
// محاسبه سود/زیان خالص
//-------------------------------------------------------------------------
double TradeLog_NetProfit(const TradeLogRecord &record)
  {
   return (record.gross_profit + record.commission + record.swap + record.fee);
  }

//-------------------------------------------------------------------------
// مدت معامله بر حسب ثانیه
//-------------------------------------------------------------------------
long TradeLog_DurationSeconds(const TradeLogRecord &record)
  {
   if(record.open_time <= 0)
      return 0;

   datetime end_time = record.close_time;
   if(end_time <= 0)
      end_time = TimeCurrent();

   if(end_time < record.open_time)
      return 0;

   return (long)(end_time - record.open_time);
  }

//-------------------------------------------------------------------------
// فرمت مدت زمان برای گزارش
//-------------------------------------------------------------------------
string TradeLog_FormatDuration(const long seconds)
  {
   if(seconds <= 0)
      return "0 ثانیه";

   long days    = seconds / 86400;
   long remain  = seconds % 86400;
   long hours   = remain / 3600;
   remain       = remain % 3600;
   long minutes = remain / 60;
   long secs    = remain % 60;

   string text = "";

   if(days > 0)
      text += IntegerToString(days) + " روز ";
   if(hours > 0)
      text += IntegerToString(hours) + " ساعت ";
   if(minutes > 0)
      text += IntegerToString(minutes) + " دقیقه ";
   if(secs > 0 || text == "")
      text += IntegerToString(secs) + " ثانیه";

   return text;
  }

//-------------------------------------------------------------------------
// تبدیل رکورد به متن خوانا برای گزارش
//-------------------------------------------------------------------------
string TradeLog_ToText(const TradeLogRecord &record)
  {
   string text = "";

   text += "شناسه معامله: " + (string)record.ticket;
   text += " | پوزیشن: " + (string)record.position_id;
   text += " | نماد: " + record.symbol;
   text += " | جهت: " + TradeLogPositionTypeToPersian(record.position_type);
   text += " | وضعیت: " + TradeLogStatusToPersian(record.status);

   text += " | ورود: " + TradeLogEntryReasonToPersian(record.entry_reason);
   text += " | علت خروج: " + TradeLogExitReasonToPersian(record.exit_reason);

   text += " | زمان ورود: " + (record.open_time > 0 ? TimeToString(record.open_time,TIME_DATE|TIME_SECONDS) : "-");
   text += " | زمان خروج: " + (record.close_time > 0 ? TimeToString(record.close_time,TIME_DATE|TIME_SECONDS) : "-");

   text += " | قیمت برنامه‌ریزی‌شده: " + DoubleToString(record.planned_entry,_Digits);
   text += " | قیمت واقعی: " + DoubleToString(record.actual_entry,_Digits);
   text += " | SL اولیه: " + DoubleToString(record.initial_sl,_Digits);
   text += " | TP اولیه: " + DoubleToString(record.initial_tp,_Digits);
   text += " | SL فعلی: " + DoubleToString(record.current_sl,_Digits);
   text += " | TP فعلی: " + DoubleToString(record.current_tp,_Digits);
   text += " | قیمت خروج: " + DoubleToString(record.close_price,_Digits);

   text += " | حجم اولیه: " + DoubleToString(record.initial_volume,2);
   text += " | حجم بسته‌شده: " + DoubleToString(record.closed_volume,2);

   text += " | سود ناخالص: " + DoubleToString(record.gross_profit,2);
   text += " | کمیسیون: " + DoubleToString(record.commission,2);
   text += " | سواپ: " + DoubleToString(record.swap,2);
   text += " | کارمزد: " + DoubleToString(record.fee,2);
   text += " | سود خالص: " + DoubleToString(TradeLog_NetProfit(record),2);

   text += " | ریسک دلاری: " + DoubleToString(record.risk_money,2);
   text += " | ریسک درصدی: " + DoubleToString(record.risk_percent,2) + "%";
   text += " | RR برنامه‌ریزی‌شده: " + DoubleToString(record.rr_planned,2);

   text += " | رسیدن به اولین سود: " + TradeLog_FormatDuration(record.seconds_to_first_profit);
   text += " | مدت معامله: " + TradeLog_FormatDuration(TradeLog_DurationSeconds(record));

   if(record.scenario_id != "")
      text += " | سناریو: " + record.scenario_id;
   if(record.scenario_direction != "")
      text += " | جهت سناریو: " + record.scenario_direction;
   if(record.scenario_reason != "")
      text += " | دلیل سناریو: " + record.scenario_reason;
   if(record.entry_condition != "")
      text += " | شرط ورود: " + record.entry_condition;
   if(record.management_summary != "")
      text += " | مدیریت: " + record.management_summary;
   if(record.exit_reason_text != "")
      text += " | توضیح خروج: " + record.exit_reason_text;
   if(record.notes != "")
      text += " | یادداشت: " + record.notes;

   return text;
  }

//-------------------------------------------------------------------------
// خلاصه کوتاه برای نمایش روی پنل/لاگ
//-------------------------------------------------------------------------
string TradeLog_ToShortText(const TradeLogRecord &record)
  {
   string direction = TradeLogPositionTypeToPersian(record.position_type);
   string status    = TradeLogStatusToPersian(record.status);
   double net       = TradeLog_NetProfit(record);

   return "معامله " + (string)record.ticket +
          " | " + direction +
          " | " + status +
          " | سود خالص: " + DoubleToString(net,2);
  }

//-------------------------------------------------------------------------
// ثبت یادداشت
//-------------------------------------------------------------------------
void TradeLog_AddNote(TradeLogRecord &record,
                      const string note)
  {
   if(note == "")
      return;

   if(record.notes == "")
      record.notes = note;
   else
      record.notes += " | " + note;
  }

//-------------------------------------------------------------------------
// ثبت نتیجه نهایی محاسبات
//-------------------------------------------------------------------------
void TradeLog_Finalize(TradeLogRecord &record)
  {
   record.net_profit = TradeLog_NetProfit(record);

   if(record.open_time > 0 && record.close_time > 0)
      record.seconds_in_trade = (long)(record.close_time - record.open_time);
  }

//+------------------------------------------------------------------+

#endif // __TFLAB_TRADE_LOGGER_MQH__