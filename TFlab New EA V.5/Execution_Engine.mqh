#ifndef __TFLAB_EXECUTION_ENGINE_MQH__
#define __TFLAB_EXECUTION_ENGINE_MQH__

//+------------------------------------------------------------------+
//|                    Execution_Engine.mqh                          |
//|                    TFlab New EA V.5                                  |
//|                                                                  |
//| مسئولیت: اجرای سفارش‌های تأییدشده                               |
//|                                                                  |
//| این فایل فقط لایه اجرای سفارش است.                               |
//| تحلیل بازار، سناریو، Entry، SL، TP و Risk در فایل‌های مستقل     |
//| انجام می‌شوند.                                                   |
//|                                                                  |
//| v2.2 - Fixed extern inside function error                        |
//+------------------------------------------------------------------+
#property strict
#include "EA_Inputs.mqh"

//====================================================================
// نوع اجرای سفارش
//====================================================================
enum ENUM_EXECUTION_ORDER_TYPE
  {
   EXECUTION_NONE = 0,
   EXECUTION_BUY_MARKET,
   EXECUTION_SELL_MARKET,
   EXECUTION_BUY_LIMIT,
   EXECUTION_SELL_LIMIT,
   EXECUTION_BUY_STOP,
   EXECUTION_SELL_STOP
  };

//====================================================================
// وضعیت اجرای سفارش
//====================================================================
enum ENUM_EXECUTION_STATUS
  {
   EXECUTION_STATUS_NONE = 0,
   EXECUTION_STATUS_READY,
   EXECUTION_STATUS_SENT,
   EXECUTION_STATUS_FILLED,
   EXECUTION_STATUS_PLACED,
   EXECUTION_STATUS_REJECTED,
   EXECUTION_STATUS_CANCELLED,
   EXECUTION_STATUS_FAILED
  };

//====================================================================
// اطلاعات درخواست اجرا
//====================================================================
struct ExecutionRequest
  {
   string                       symbol;
   ulong                        magic;
   ulong                        scenario_id;
   ulong                        signal_id;

   ENUM_EXECUTION_ORDER_TYPE   order_type;
   double                       volume;
   double                       price;
   double                       stop_loss;
   double                       take_profit;
   datetime                     expiration;

   string                       comment;
   string                       reason;
  };

//====================================================================
// نتیجه اجرای سفارش
//====================================================================
struct ExecutionResult
  {
   bool                         success;
   ENUM_EXECUTION_STATUS        status;

   ulong                        order_ticket;
   ulong                        deal_ticket;
   double                       executed_price;
   double                       executed_volume;

   int                          retcode;
   string                       retcode_text;
   string                       reason;
  };

//------------------------------------------------------------------
// تبدیل نوع سفارش به فارسی
//------------------------------------------------------------------
string ExecutionOrderTypeToPersian(const ENUM_EXECUTION_ORDER_TYPE type)
  {
   switch(type)
     {
      case EXECUTION_BUY_MARKET:  return "خرید بازار";
      case EXECUTION_SELL_MARKET: return "فروش بازار";
      case EXECUTION_BUY_LIMIT:   return "خرید لیمیت";
      case EXECUTION_SELL_LIMIT:  return "فروش لیمیت";
      case EXECUTION_BUY_STOP:    return "خرید استاپ";
      case EXECUTION_SELL_STOP:   return "فروش استاپ";
      default:                    return "بدون سفارش";
     }
  }

//------------------------------------------------------------------
// تبدیل وضعیت اجرا به فارسی
//------------------------------------------------------------------
string ExecutionStatusToPersian(const ENUM_EXECUTION_STATUS status)
  {
   switch(status)
     {
      case EXECUTION_STATUS_READY:     return "آماده اجرا";
      case EXECUTION_STATUS_SENT:      return "ارسال شد";
      case EXECUTION_STATUS_FILLED:    return "اجرا شد";
      case EXECUTION_STATUS_PLACED:    return "سفارش ثبت شد";
      case EXECUTION_STATUS_REJECTED:  return "رد شد";
      case EXECUTION_STATUS_CANCELLED: return "لغو شد";
      case EXECUTION_STATUS_FAILED:    return "ناموفق";
      default:                         return "بدون وضعیت";
     }
  }

//------------------------------------------------------------------
// تبدیل Retcode به متن قابل فهم
//------------------------------------------------------------------
string Execution_RetcodeToText(const int retcode)
  {
   switch(retcode)
     {
      case TRADE_RETCODE_REQUOTE:         return "Requote";
      case TRADE_RETCODE_REJECT:          return "Reject";
      case TRADE_RETCODE_CANCEL:          return "Cancel";
      case TRADE_RETCODE_PLACED:          return "Placed";
      case TRADE_RETCODE_DONE:            return "Done";
      case TRADE_RETCODE_DONE_PARTIAL:    return "Partial";
      case TRADE_RETCODE_ERROR:           return "Error";
      case TRADE_RETCODE_TIMEOUT:         return "Timeout";
      case TRADE_RETCODE_INVALID:         return "Invalid Request";
      case TRADE_RETCODE_INVALID_VOLUME:  return "Invalid Volume";
      case TRADE_RETCODE_INVALID_PRICE:   return "Invalid Price";
      case TRADE_RETCODE_INVALID_STOPS:   return "Invalid Stops";
      case TRADE_RETCODE_TRADE_DISABLED:  return "Trade Disabled";
      case TRADE_RETCODE_MARKET_CLOSED:   return "Market Closed";
      case TRADE_RETCODE_NO_MONEY:        return "No Money";
      case TRADE_RETCODE_PRICE_CHANGED:   return "Price Changed";
      case TRADE_RETCODE_PRICE_OFF:       return "No Quotes";
      case TRADE_RETCODE_INVALID_EXPIRATION: return "Invalid Expiration";
      case TRADE_RETCODE_ORDER_CHANGED:   return "Order Changed";
      case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too Many Requests";
      default:                            return "Unknown (" + IntegerToString(retcode) + ")";
     }
  }

//------------------------------------------------------------------
// مقداردهی درخواست
//------------------------------------------------------------------
void Execution_InitRequest(ExecutionRequest &request)
  {
   request.symbol      = "";
   request.magic       = 0;
   request.scenario_id = 0;
   request.signal_id   = 0;

   request.order_type  = EXECUTION_NONE;
   request.volume      = 0.0;
   request.price       = 0.0;
   request.stop_loss   = 0.0;
   request.take_profit = 0.0;
   request.expiration  = 0;

   request.comment     = "";
   request.reason      = "";
  }

//------------------------------------------------------------------
// مقداردهی نتیجه
//------------------------------------------------------------------
void Execution_InitResult(ExecutionResult &result)
  {
   result.success         = false;
   result.status          = EXECUTION_STATUS_NONE;

   result.order_ticket    = 0;
   result.deal_ticket     = 0;
   result.executed_price  = 0.0;
   result.executed_volume = 0.0;

   result.retcode         = 0;
   result.retcode_text    = "";
   result.reason          = "";
  }

//------------------------------------------------------------------
// بررسی نوع Market
//------------------------------------------------------------------
bool Execution_IsMarketOrder(const ENUM_EXECUTION_ORDER_TYPE type)
  {
   return (type == EXECUTION_BUY_MARKET ||
           type == EXECUTION_SELL_MARKET);
  }

//------------------------------------------------------------------
// بررسی نوع Pending
//------------------------------------------------------------------
bool Execution_IsPendingOrder(const ENUM_EXECUTION_ORDER_TYPE type)
  {
   return (type == EXECUTION_BUY_LIMIT ||
           type == EXECUTION_SELL_LIMIT ||
           type == EXECUTION_BUY_STOP ||
           type == EXECUTION_SELL_STOP);
  }

//------------------------------------------------------------------
// بررسی خرید
//------------------------------------------------------------------
bool Execution_IsBuy(const ENUM_EXECUTION_ORDER_TYPE type)
  {
   return (type == EXECUTION_BUY_MARKET ||
           type == EXECUTION_BUY_LIMIT ||
           type == EXECUTION_BUY_STOP);
  }

//------------------------------------------------------------------
// بررسی فروش
//------------------------------------------------------------------
bool Execution_IsSell(const ENUM_EXECUTION_ORDER_TYPE type)
  {
   return (type == EXECUTION_SELL_MARKET ||
           type == EXECUTION_SELL_LIMIT ||
           type == EXECUTION_SELL_STOP);
  }

//------------------------------------------------------------------
// بررسی اجازه ترید واقعی
//------------------------------------------------------------------
bool Execution_IsRealTradingAllowed(string &error_text)
  {
   error_text = "";

   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
     {
      error_text = "ترمینال متصل نیست";
      return false;
     }

   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      error_text = "ترید خودکار در متاتریدر غیرفعال است";
      return false;
     }

   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
     {
      error_text = "ترید در حساب غیرفعال است";
      return false;
     }

   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     {
      error_text = "ترید با EA در حساب غیرفعال است";
      return false;
     }

   return true;
  }

//------------------------------------------------------------------
// اعتبارسنجی پایه درخواست
//------------------------------------------------------------------
bool Execution_ValidateRequest(const ExecutionRequest &request,
                               string &error_text)
  {
   error_text = "";

   if(request.symbol == "")
     {
      error_text = "نماد معاملاتی مشخص نشده است";
      return false;
     }

   if(request.magic == 0)
     {
      error_text = "مجیک نامبر مشخص نشده است";
      return false;
     }

   if(request.order_type == EXECUTION_NONE)
     {
      error_text = "نوع سفارش مشخص نشده است";
      return false;
     }

   if(request.volume <= 0.0)
     {
      error_text = "حجم سفارش معتبر نیست";
      return false;
     }

   if(Execution_IsPendingOrder(request.order_type) && request.price <= 0.0)
     {
      error_text = "قیمت سفارش معلق مشخص نشده است";
      return false;
     }

   if(request.stop_loss < 0.0 || request.take_profit < 0.0)
     {
      error_text = "قیمت حد ضرر یا حد سود نامعتبر است";
      return false;
     }

   return true;
  }

//------------------------------------------------------------------
// نرمال‌سازی حجم بر اساس مشخصات نماد
//------------------------------------------------------------------
bool Execution_NormalizeVolume(const string symbol,
                               const double requested_volume,
                               double &normalized_volume,
                               string &error_text)
  {
   normalized_volume = 0.0;
   error_text = "";

   if(requested_volume <= 0.0)
     {
      error_text = "حجم درخواستی معتبر نیست";
      return false;
     }

   double min_volume  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_volume  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(min_volume <= 0.0 || max_volume <= 0.0 || volume_step <= 0.0)
     {
      error_text = "مشخصات حجم نماد قابل دریافت نیست";
      return false;
     }

   double volume = MathMin(requested_volume, max_volume);

   //--- گرد کردن رو به پایین
   volume = MathFloor((volume + 1e-12) / volume_step) * volume_step;

   if(volume < min_volume)
     {
      error_text = "حجم محاسبه‌شده از حداقل حجم نماد کمتر است | " +
                   "Calculated=" + DoubleToString(volume, 4) +
                   " | Min=" + DoubleToString(min_volume, 4);
      return false;
     }

   int digits = 0;
   double step_test = volume_step;

   while(digits < 8 && MathAbs(step_test - MathRound(step_test)) > 1e-9)
     {
      step_test *= 10.0;
      digits++;
     }

   normalized_volume = NormalizeDouble(volume, digits);
   return (normalized_volume >= min_volume && normalized_volume <= max_volume);
  }

//------------------------------------------------------------------
// نرمال‌سازی قیمت بر اساس Digits نماد
//------------------------------------------------------------------
bool Execution_NormalizePrice(const string symbol,
                              const double requested_price,
                              double &normalized_price)
  {
   normalized_price = 0.0;

   if(requested_price <= 0.0)
      return false;

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   normalized_price = NormalizeDouble(requested_price, digits);

   return (normalized_price > 0.0);
  }

//------------------------------------------------------------------
// انتخاب Filling Mode مناسب نماد
//------------------------------------------------------------------
ENUM_ORDER_TYPE_FILLING Execution_GetFillingType(const string symbol)
  {
   long filling_mode = 0;

   if(!SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE, filling_mode))
      return ORDER_FILLING_FOK;

   if((filling_mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;

   if((filling_mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;

   return ORDER_FILLING_RETURN;
  }

//------------------------------------------------------------------
// بررسی StopLevel و FreezeLevel برای Pending Orders
//------------------------------------------------------------------
bool Execution_CheckPendingDistance(const string symbol,
                                    const ENUM_EXECUTION_ORDER_TYPE order_type,
                                    const double pending_price,
                                    const double current_price,
                                    string &error_text)
  {
   error_text = "";

   if(pending_price <= 0.0 || current_price <= 0.0)
     {
      error_text = "قیمت‌ها معتبر نیستند";
      return false;
     }

   long stop_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freeze_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);

   long min_distance = MathMax(stop_level, freeze_level);
   if(min_distance <= 0) min_distance = 10; // پیش‌فرض 10 point

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
     {
      error_text = "Point نماد معتبر نیست";
      return false;
     }

   double min_distance_price = min_distance * point;
   double distance = MathAbs(pending_price - current_price);

   if(distance < min_distance_price)
     {
      error_text = "فاصله Pending از قیمت جاری کمتر از حداقل مجاز است | " +
                   "Distance=" + DoubleToString(distance / point, 1) + " pts" +
                   " | MinRequired=" + DoubleToString(min_distance, 0) + " pts";
      return false;
     }

   //--- بررسی جهت صحیح
   if(order_type == EXECUTION_BUY_LIMIT && pending_price >= current_price)
     {
      error_text = "Buy Limit باید زیر قیمت جاری باشد";
      return false;
     }

   if(order_type == EXECUTION_SELL_LIMIT && pending_price <= current_price)
     {
      error_text = "Sell Limit باید بالای قیمت جاری باشد";
      return false;
     }

   if(order_type == EXECUTION_BUY_STOP && pending_price <= current_price)
     {
      error_text = "Buy Stop باید بالای قیمت جاری باشد";
      return false;
     }

   if(order_type == EXECUTION_SELL_STOP && pending_price >= current_price)
     {
      error_text = "Sell Stop باید زیر قیمت جاری باشد";
      return false;
     }

   return true;
  }

//------------------------------------------------------------------
// تبدیل نوع داخلی به نوع MQL5
//------------------------------------------------------------------
bool Execution_MapOrderType(const ENUM_EXECUTION_ORDER_TYPE source,
                            ENUM_ORDER_TYPE &destination)
  {
   switch(source)
     {
      case EXECUTION_BUY_MARKET:  destination = ORDER_TYPE_BUY; return true;
      case EXECUTION_SELL_MARKET: destination = ORDER_TYPE_SELL; return true;
      case EXECUTION_BUY_LIMIT:   destination = ORDER_TYPE_BUY_LIMIT; return true;
      case EXECUTION_SELL_LIMIT:  destination = ORDER_TYPE_SELL_LIMIT; return true;
      case EXECUTION_BUY_STOP:    destination = ORDER_TYPE_BUY_STOP; return true;
      case EXECUTION_SELL_STOP:   destination = ORDER_TYPE_SELL_STOP; return true;
      default:                    return false;
     }
  }

//------------------------------------------------------------------
// ارسال سفارش Market
//------------------------------------------------------------------
bool Execution_SendMarket(const ExecutionRequest &request,
                          ExecutionResult &result)
  {
   Execution_InitResult(result);

   //--- بررسی اجازه ترید
   string trading_error = "";
   if(!Execution_IsRealTradingAllowed(trading_error))
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = "ترید مجاز نیست | " + trading_error;
      Print("[EXECUTION] BLOCKED | ", result.reason);
      return false;
     }

   string error_text = "";
   if(!Execution_ValidateRequest(request, error_text))
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = error_text;
      Print("[EXECUTION] FAIL | ", error_text);
      return false;
     }

   if(!Execution_IsMarketOrder(request.order_type))
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = "نوع سفارش برای اجرای بازار مناسب نیست";
      Print("[EXECUTION] FAIL | ", result.reason);
      return false;
     }

   double volume = 0.0;
   if(!Execution_NormalizeVolume(request.symbol, request.volume, volume, error_text))
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = error_text;
      Print("[EXECUTION] FAIL | ", error_text);
      return false;
     }

   ENUM_ORDER_TYPE order_type;
   if(!Execution_MapOrderType(request.order_type, order_type))
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = "نوع سفارش قابل تبدیل نیست";
      Print("[EXECUTION] FAIL | ", result.reason);
      return false;
     }

   MqlTradeRequest trade_request;
   MqlTradeResult  trade_result;

   ZeroMemory(trade_request);
   ZeroMemory(trade_result);

   trade_request.action       = TRADE_ACTION_DEAL;
   trade_request.symbol       = request.symbol;
   trade_request.magic        = request.magic;
   trade_request.type         = order_type;
   trade_request.volume       = volume;
   trade_request.sl           = request.stop_loss;
   trade_request.tp           = request.take_profit;
   
   //--- [اصلاح] استفاده مستقیم از Inp_MaxSlippagePoints که در EA_Inputs تعریف شده است
   trade_request.deviation    = (ulong)Inp_MaxSlippagePoints;
   
   trade_request.type_filling = Execution_GetFillingType(request.symbol);
   trade_request.comment      = request.comment;

   MqlTick tick;
   if(!SymbolInfoTick(request.symbol, tick))
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = "قیمت لحظه‌ای نماد دریافت نشد";
      Print("[EXECUTION] FAIL | ", result.reason);
      return false;
     }

   trade_request.price = (order_type == ORDER_TYPE_BUY ? tick.ask : tick.bid);

   result.status = EXECUTION_STATUS_SENT;

   Print(
      "[EXECUTION] SENDING MARKET",
      " | Type=", ExecutionOrderTypeToPersian(request.order_type),
      " | Volume=", DoubleToString(volume, 4),
      " | Price=", DoubleToString(trade_request.price, _Digits),
      " | SL=", DoubleToString(request.stop_loss, _Digits),
      " | TP=", DoubleToString(request.take_profit, _Digits),
      " | Scenario=", request.scenario_id,
      " | Filling=", EnumToString(trade_request.type_filling)
   );

   if(!OrderSend(trade_request, trade_result))
     {
      result.status       = EXECUTION_STATUS_FAILED;
      result.retcode      = (int)trade_result.retcode;
      result.retcode_text = trade_result.comment;
      result.reason       = "ارسال سفارش بازار ناموفق بود";
      
      Print(
         "[EXECUTION] MARKET FAIL",
         " | Retcode=", result.retcode,
         " | RetcodeText=", Execution_RetcodeToText(result.retcode),
         " | Comment=", result.retcode_text,
         " | Error=", GetLastError()
      );
      return false;
     }

   result.retcode         = (int)trade_result.retcode;
   result.retcode_text    = trade_result.comment;
   result.order_ticket    = trade_result.order;
   result.deal_ticket     = trade_result.deal;
   result.executed_price  = trade_result.price;
   result.executed_volume = trade_result.volume;

   if(trade_result.retcode == TRADE_RETCODE_DONE ||
      trade_result.retcode == TRADE_RETCODE_DONE_PARTIAL)
     {
      result.success = true;
      result.status  = EXECUTION_STATUS_FILLED;
      result.reason  = "سفارش بازار با موفقیت اجرا شد";
      
      Print(
         "[EXECUTION] MARKET SUCCESS",
         " | Ticket=", result.order_ticket,
         " | Deal=", result.deal_ticket,
         " | Price=", DoubleToString(result.executed_price, _Digits),
         " | Volume=", DoubleToString(result.executed_volume, 4),
         " | Retcode=", Execution_RetcodeToText(result.retcode)
      );
      return true;
     }

   result.status = EXECUTION_STATUS_REJECTED;
   result.reason = "کارگزار سفارش بازار را تأیید نکرد | " + 
                   Execution_RetcodeToText(result.retcode);
   
   Print(
      "[EXECUTION] MARKET REJECTED",
      " | Retcode=", result.retcode,
      " | RetcodeText=", Execution_RetcodeToText(result.retcode),
      " | Comment=", result.retcode_text
   );
   return false;
  }

//------------------------------------------------------------------
// ثبت سفارش Pending
//------------------------------------------------------------------
bool Execution_PlacePending(const ExecutionRequest &request,
                            ExecutionResult &result)
  {
   Execution_InitResult(result);

   //--- بررسی اجازه ترید
   string trading_error = "";
   if(!Execution_IsRealTradingAllowed(trading_error))
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = "ترید مجاز نیست | " + trading_error;
      Print("[EXECUTION] BLOCKED | ", result.reason);
      return false;
     }

   string error_text = "";
   if(!Execution_ValidateRequest(request, error_text))
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = error_text;
      Print("[EXECUTION] FAIL | ", error_text);
      return false;
     }

   if(!Execution_IsPendingOrder(request.order_type))
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = "نوع سفارش برای Pending مناسب نیست";
      Print("[EXECUTION] FAIL | ", result.reason);
      return false;
     }

   double volume = 0.0;
   if(!Execution_NormalizeVolume(request.symbol, request.volume, volume, error_text))
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = error_text;
      Print("[EXECUTION] FAIL | ", error_text);
      return false;
     }

   ENUM_ORDER_TYPE order_type;
   if(!Execution_MapOrderType(request.order_type, order_type))
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = "نوع سفارش Pending قابل تبدیل نیست";
      Print("[EXECUTION] FAIL | ", result.reason);
      return false;
     }

   double price = 0.0;
   if(!Execution_NormalizePrice(request.symbol, request.price, price))
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = "قیمت Pending معتبر نیست";
      Print("[EXECUTION] FAIL | ", result.reason);
      return false;
     }

   //--- بررسی StopLevel و FreezeLevel
   MqlTick tick;
   if(!SymbolInfoTick(request.symbol, tick))
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = "قیمت لحظه‌ای نماد دریافت نشد";
      Print("[EXECUTION] FAIL | ", result.reason);
      return false;
     }

   double current_price = (tick.bid + tick.ask) * 0.5;
   string pending_error = "";
   if(!Execution_CheckPendingDistance(request.symbol, request.order_type, price, current_price, pending_error))
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = pending_error;
      Print("[EXECUTION] FAIL | ", pending_error);
      return false;
     }

   MqlTradeRequest trade_request;
   MqlTradeResult  trade_result;

   ZeroMemory(trade_request);
   ZeroMemory(trade_result);

   trade_request.action       = TRADE_ACTION_PENDING;
   trade_request.symbol       = request.symbol;
   trade_request.magic        = request.magic;
   trade_request.type         = order_type;
   trade_request.volume       = volume;
   trade_request.price        = price;
   trade_request.sl           = request.stop_loss;
   trade_request.tp           = request.take_profit;
   
   trade_request.type_filling = Execution_GetFillingType(request.symbol);
   trade_request.comment      = request.comment;

   if(request.expiration > 0)
     {
      trade_request.type_time  = ORDER_TIME_SPECIFIED;
      trade_request.expiration = request.expiration;
     }
   else
     {
      trade_request.type_time = ORDER_TIME_GTC;
     }

   result.status = EXECUTION_STATUS_SENT;

   Print(
      "[EXECUTION] SENDING PENDING",
      " | Type=", ExecutionOrderTypeToPersian(request.order_type),
      " | Volume=", DoubleToString(volume, 4),
      " | Price=", DoubleToString(price, _Digits),
      " | Current=", DoubleToString(current_price, _Digits),
      " | SL=", DoubleToString(request.stop_loss, _Digits),
      " | TP=", DoubleToString(request.take_profit, _Digits),
      " | Scenario=", request.scenario_id,
      " | Filling=", EnumToString(trade_request.type_filling)
   );

   if(!OrderSend(trade_request, trade_result))
     {
      result.status       = EXECUTION_STATUS_FAILED;
      result.retcode      = (int)trade_result.retcode;
      result.retcode_text = trade_result.comment;
      result.reason       = "ثبت سفارش Pending ناموفق بود";
      
      Print(
         "[EXECUTION] PENDING FAIL",
         " | Retcode=", result.retcode,
         " | RetcodeText=", Execution_RetcodeToText(result.retcode),
         " | Comment=", result.retcode_text,
         " | Error=", GetLastError()
      );
      return false;
     }

   result.retcode         = (int)trade_result.retcode;
   result.retcode_text    = trade_result.comment;
   result.order_ticket    = trade_result.order;
   result.deal_ticket     = trade_result.deal;
   result.executed_price  = trade_result.price;
   result.executed_volume = trade_result.volume;

   if(trade_result.retcode == TRADE_RETCODE_PLACED ||
      trade_result.retcode == TRADE_RETCODE_DONE)
     {
      result.success = true;
      result.status  = EXECUTION_STATUS_PLACED;
      result.reason  = "سفارش Pending با موفقیت ثبت شد";
      
      Print(
         "[EXECUTION] PENDING SUCCESS",
         " | Ticket=", result.order_ticket,
         " | Price=", DoubleToString(price, _Digits),
         " | Volume=", DoubleToString(volume, 4),
         " | Retcode=", Execution_RetcodeToText(result.retcode)
      );
      return true;
     }

   result.status = EXECUTION_STATUS_REJECTED;
   result.reason = "کارگزار سفارش Pending را تأیید نکرد | " + 
                   Execution_RetcodeToText(result.retcode);
   
   Print(
      "[EXECUTION] PENDING REJECTED",
      " | Retcode=", result.retcode,
      " | RetcodeText=", Execution_RetcodeToText(result.retcode),
      " | Comment=", result.retcode_text
   );
   return false;
  }

//------------------------------------------------------------------
// حذف سفارش Pending بر اساس Ticket
//------------------------------------------------------------------
bool Execution_DeletePending(const ulong order_ticket,
                             ExecutionResult &result)
  {
   Execution_InitResult(result);

   if(order_ticket == 0)
     {
      result.status = EXECUTION_STATUS_FAILED;
      result.reason = "تیکت سفارش معتبر نیست";
      return false;
     }

   MqlTradeRequest trade_request;
   MqlTradeResult  trade_result;

   ZeroMemory(trade_request);
   ZeroMemory(trade_result);

   trade_request.action = TRADE_ACTION_REMOVE;
   trade_request.order  = order_ticket;

   result.status = EXECUTION_STATUS_SENT;

   Print("[EXECUTION] DELETING PENDING | Ticket=", order_ticket);

   if(!OrderSend(trade_request, trade_result))
     {
      result.status       = EXECUTION_STATUS_FAILED;
      result.retcode      = (int)trade_result.retcode;
      result.retcode_text = trade_result.comment;
      result.reason       = "لغو سفارش Pending ناموفق بود";
      
      Print(
         "[EXECUTION] DELETE FAIL",
         " | Ticket=", order_ticket,
         " | Retcode=", result.retcode,
         " | RetcodeText=", Execution_RetcodeToText(result.retcode)
      );
      return false;
     }

   result.retcode      = (int)trade_result.retcode;
   result.retcode_text = trade_result.comment;
   result.order_ticket = order_ticket;

   if(trade_result.retcode == TRADE_RETCODE_DONE)
     {
      result.success = true;
      result.status  = EXECUTION_STATUS_CANCELLED;
      result.reason  = "سفارش Pending لغو شد";
      Print("[EXECUTION] DELETE SUCCESS | Ticket=", order_ticket);
      return true;
     }

   result.status = EXECUTION_STATUS_REJECTED;
   result.reason = "لغو سفارش توسط کارگزار تأیید نشد";
   return false;
  }

//------------------------------------------------------------------
// آماده‌سازی درخواست برای گزارش
//------------------------------------------------------------------
string Execution_RequestToText(const ExecutionRequest &request)
  {
   string text = "";

   text += "نماد: " + request.symbol;
   text += " | نوع: " + ExecutionOrderTypeToPersian(request.order_type);
   text += " | حجم: " + DoubleToString(request.volume, 8);
   text += " | قیمت: " + DoubleToString(request.price, _Digits);
   text += " | SL: " + DoubleToString(request.stop_loss, _Digits);
   text += " | TP: " + DoubleToString(request.take_profit, _Digits);
   text += " | سناریو: " + (string)request.scenario_id;
   text += " | سیگنال: " + (string)request.signal_id;

   if(request.comment != "")
      text += " | توضیح: " + request.comment;

   if(request.reason != "")
      text += " | دلیل: " + request.reason;

   return text;
  }

//------------------------------------------------------------------
// آماده‌سازی نتیجه برای گزارش
//------------------------------------------------------------------
string Execution_ResultToText(const ExecutionResult &result)
  {
   string text = "";

   text += "وضعیت: " + ExecutionStatusToPersian(result.status);
   text += " | موفق: " + (result.success ? "بله" : "خیر");
   text += " | سفارش: " + (string)result.order_ticket;
   text += " | معامله: " + (string)result.deal_ticket;
   text += " | قیمت اجرا: " + DoubleToString(result.executed_price, _Digits);
   text += " | حجم اجرا: " + DoubleToString(result.executed_volume, 8);
   text += " | کد: " + (string)result.retcode;

   if(result.retcode_text != "")
      text += " | پاسخ: " + result.retcode_text;

   if(result.reason != "")
      text += " | توضیح: " + result.reason;

   return text;
  }

//+------------------------------------------------------------------+

#endif // __TFLAB_EXECUTION_ENGINE_MQH__