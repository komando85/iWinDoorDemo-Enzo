#ifndef __TFLAB_TRADE_MANAGER_MQH__
#define __TFLAB_TRADE_MANAGER_MQH__

//+------------------------------------------------------------------+
//|                         Trade_Manager.mqh                        |
//|                         TFlab New EA V.5                             |
//|                                                                  |
//| مسئولیت: مدیریت معاملات باز پس از اجرا                           |
//|                                                                  |
//| این فایل مسئول پایش معامله، Partial Close، انتقال SL و           |
//| وضعیت مدیریت معامله است.                                         |
//| اجرای مستقیم سفارش در Execution_Engine انجام خواهد شد.          |
//|                                                                  |
//| v2.1 - Fixed Stage1SL + Improved SL calculation + لاگ کامل     |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// وضعیت کلی مدیریت معامله
//====================================================================
enum ENUM_TRADE_MANAGEMENT_STATE
  {
   TRADE_MGMT_UNKNOWN = 0,
   TRADE_MGMT_ACTIVE,
   TRADE_MGMT_PARTIAL_DONE,
   TRADE_MGMT_BREAK_EVEN,
   TRADE_MGMT_PROTECTING_PROFIT,
   TRADE_MGMT_EXIT_READY,
   TRADE_MGMT_CLOSED,
   TRADE_MGMT_ERROR
  };

//====================================================================
// نوع رویداد مدیریت
//====================================================================
enum ENUM_TRADE_MANAGEMENT_EVENT
  {
   TRADE_EVENT_NONE = 0,
   TRADE_EVENT_DETECTED,
   TRADE_EVENT_PARTIAL_CLOSE_REQUESTED,
   TRADE_EVENT_PARTIAL_CLOSE_DONE,
   TRADE_EVENT_MOVE_SL_TO_ENTRY,
   TRADE_EVENT_MOVE_SL_TO_PROFIT,
   TRADE_EVENT_TARGET_REACHED,
   TRADE_EVENT_INVALIDATION,
   TRADE_EVENT_EXIT_REQUESTED,
   TRADE_EVENT_CLOSED,
   TRADE_EVENT_ERROR
  };

//====================================================================
// اطلاعات یک معامله برای مدیریت
//====================================================================
struct ManagedTrade
  {
   ulong                         ticket;
   ulong                         position_id;
   long                          magic;

   string                        symbol;
   bool                          is_buy;

   double                        open_price;
   double                        current_price;
   double                        volume;
   double                        initial_volume;
   double                        current_sl;
   double                        current_tp;

   double                        entry_price;
   double                        invalidation_price;
   double                        target_price;
   double                        target_1;
   double                        target_2;
   double                        target_3;
   bool                          sl_stage_1_done;
   bool                          sl_stage_2_done;
   bool                          sl_stage_3_done;

   double                        profit;
   double                        swap;
   double                        commission;

   datetime                      open_time;
   datetime                      last_update_time;

   ENUM_TRADE_MANAGEMENT_STATE   state;
   bool                          partial_done;
   bool                          break_even_done;
   bool                          profit_protection_done;

   string                        last_reason;
  };

//====================================================================
// خروجی تصمیم مدیریتی
//====================================================================
struct TradeManagementDecision
  {
   bool                           valid;
   bool                           request_partial_close;
   bool                           request_move_sl;
   bool                           request_exit;

   double                         partial_close_volume;
   double                         new_sl;

   ENUM_TRADE_MANAGEMENT_EVENT    event;
   string                         reason;
  };

//------------------------------------------------------------------
// تبدیل وضعیت به فارسی
//------------------------------------------------------------------
string TradeManagementStateToPersian(const ENUM_TRADE_MANAGEMENT_STATE state)
  {
   switch(state)
     {
      case TRADE_MGMT_ACTIVE:            return "فعال";
      case TRADE_MGMT_PARTIAL_DONE:      return "خروج بخشی انجام شد";
      case TRADE_MGMT_BREAK_EVEN:        return "حد ضرر روی نقطه ورود";
      case TRADE_MGMT_PROTECTING_PROFIT: return "حفاظت از سود";
      case TRADE_MGMT_EXIT_READY:        return "آماده خروج";
      case TRADE_MGMT_CLOSED:            return "بسته شده";
      case TRADE_MGMT_ERROR:             return "خطا";
      default:                           return "نامشخص";
     }
  }

//------------------------------------------------------------------
// تبدیل رویداد به فارسی
//------------------------------------------------------------------
string TradeManagementEventToPersian(const ENUM_TRADE_MANAGEMENT_EVENT event)
  {
   switch(event)
     {
      case TRADE_EVENT_DETECTED:                return "شناسایی معامله";
      case TRADE_EVENT_PARTIAL_CLOSE_REQUESTED: return "درخواست خروج بخشی";
      case TRADE_EVENT_PARTIAL_CLOSE_DONE:      return "خروج بخشی انجام شد";
      case TRADE_EVENT_MOVE_SL_TO_ENTRY:        return "انتقال حد ضرر به نقطه ورود";
      case TRADE_EVENT_MOVE_SL_TO_PROFIT:       return "انتقال حد ضرر به ناحیه سود";
      case TRADE_EVENT_TARGET_REACHED:          return "هدف محقق شد";
      case TRADE_EVENT_INVALIDATION:            return "ابطال سناریو";
      case TRADE_EVENT_EXIT_REQUESTED:          return "درخواست خروج";
      case TRADE_EVENT_CLOSED:                  return "معامله بسته شد";
      case TRADE_EVENT_ERROR:                   return "خطا";
      default:                                  return "بدون رویداد";
     }
  }

//------------------------------------------------------------------
// مقداردهی معامله
//------------------------------------------------------------------
void TradeManager_Init(ManagedTrade &trade)
  {
   trade.ticket                    = 0;
   trade.position_id               = 0;
   trade.magic                     = 0;
   trade.symbol                    = "";
   trade.is_buy                    = false;

   trade.open_price                = 0.0;
   trade.current_price             = 0.0;
   trade.volume                    = 0.0;
   trade.initial_volume            = 0.0;
   trade.current_sl                = 0.0;
   trade.current_tp                = 0.0;

   trade.entry_price               = 0.0;
   trade.invalidation_price        = 0.0;
   trade.target_price              = 0.0;
   trade.target_1                  = 0.0;
   trade.target_2                  = 0.0;
   trade.target_3                  = 0.0;
   trade.sl_stage_1_done           = false;
   trade.sl_stage_2_done           = false;
   trade.sl_stage_3_done           = false;

   trade.profit                    = 0.0;
   trade.swap                      = 0.0;
   trade.commission                = 0.0;

   trade.open_time                 = 0;
   trade.last_update_time          = 0;

   trade.state                     = TRADE_MGMT_UNKNOWN;
   trade.partial_done              = false;
   trade.break_even_done           = false;
   trade.profit_protection_done    = false;

   trade.last_reason               = "";
  }

//------------------------------------------------------------------
// مقداردهی تصمیم
//------------------------------------------------------------------
void TradeManager_InitDecision(TradeManagementDecision &decision)
  {
   decision.valid                   = false;
   decision.request_partial_close   = false;
   decision.request_move_sl         = false;
   decision.request_exit            = false;
   decision.partial_close_volume    = 0.0;
   decision.new_sl                  = 0.0;
   decision.event                   = TRADE_EVENT_NONE;
   decision.reason                  = "";
  }

//------------------------------------------------------------------
// اعتبارسنجی حجم جزئی
// [اصلاح] بهبود بررسی‌ها
//------------------------------------------------------------------
bool TradeManager_IsPartialVolumeValid(const double current_volume,
                                       const double partial_volume,
                                       const double min_volume)
  {
   if(current_volume <= 0.0)
      return false;

   if(partial_volume <= 0.0)
      return false;

   if(partial_volume >= current_volume)
      return false;

   //--- [اصلاح] بررسی اینکه حجم باقی‌مانده حداقل min_volume باشد
   if(min_volume > 0.0 && (current_volume - partial_volume) < min_volume)
      return false;

   return true;
  }

//------------------------------------------------------------------
// محاسبه حجم خروج بخشی به درصد
// [اصلاح] جلوگیری از volume منفی
//------------------------------------------------------------------
double TradeManager_CalculatePartialVolume(const double current_volume,
                                           const double percent,
                                           const double volume_step,
                                           const double min_volume)
  {
   if(current_volume <= 0.0 || percent <= 0.0)
      return 0.0;

   double close_volume = current_volume * percent / 100.0;

   if(volume_step > 0.0)
      close_volume = MathFloor(close_volume / volume_step) * volume_step;

   if(min_volume > 0.0 && close_volume < min_volume)
      close_volume = min_volume;

   if(close_volume >= current_volume)
     {
      //--- [اصلاح] جلوگیری از volume منفی
      if(volume_step > 0.0 && current_volume > volume_step)
         close_volume = current_volume - volume_step;
      else if(current_volume > min_volume)
         close_volume = current_volume - min_volume;
      else
         close_volume = current_volume * 0.5;
     }

   if(close_volume <= 0.0)
      return 0.0;

   return close_volume;
  }

//------------------------------------------------------------------
// بررسی اینکه حد ضرر جدید واقعاً سود را محافظت می‌کند
//------------------------------------------------------------------
bool TradeManager_IsProfitProtectingSL(const ManagedTrade &trade,
                                       const double new_sl,
                                       const double min_profit_distance)
  {
   if(new_sl <= 0.0 || trade.entry_price <= 0.0)
      return false;

   if(trade.is_buy)
     {
      if(new_sl <= trade.entry_price)
         return false;

      if(min_profit_distance > 0.0 &&
         (new_sl - trade.entry_price) < min_profit_distance)
         return false;

      return true;
     }

   if(new_sl >= trade.entry_price)
      return false;

   if(min_profit_distance > 0.0 &&
      (trade.entry_price - new_sl) < min_profit_distance)
      return false;

   return true;
  }

//------------------------------------------------------------------
// انتقال SL به نقطه ورود
//------------------------------------------------------------------
bool TradeManager_PrepareBreakEven(const ManagedTrade &trade,
                                   const double buffer,
                                   TradeManagementDecision &decision)
  {
   TradeManager_InitDecision(decision);

   if(trade.entry_price <= 0.0)
     {
      decision.reason = "قیمت ورود معتبر نیست";
      return false;
     }

   double new_sl = trade.entry_price;

   if(trade.is_buy)
      new_sl = trade.entry_price + MathMax(0.0, buffer);
   else
      new_sl = trade.entry_price - MathMax(0.0, buffer);

   if(trade.is_buy && trade.current_sl > 0.0 && new_sl <= trade.current_sl)
     {
      decision.reason = "حد ضرر جدید برای خرید بهتر نیست";
      return false;
     }

   if(!trade.is_buy && trade.current_sl > 0.0 && new_sl >= trade.current_sl)
     {
      decision.reason = "حد ضرر جدید برای فروش بهتر نیست";
      return false;
     }

   decision.valid         = true;
   decision.request_move_sl = true;
   decision.new_sl        = new_sl;
   decision.event         = TRADE_EVENT_MOVE_SL_TO_ENTRY;
   decision.reason        = "شرایط انتقال حد ضرر به نقطه ورود فراهم شده است";

   return true;
  }

//------------------------------------------------------------------
// انتقال SL به ناحیه سود
// [اصلاح] افزودن min_profit_distance
//------------------------------------------------------------------
bool TradeManager_PrepareProfitProtection(const ManagedTrade &trade,
                                          const double protected_price,
                                          TradeManagementDecision &decision,
                                          const double min_profit_distance = 0.0)
  {
   TradeManager_InitDecision(decision);

   if(!TradeManager_IsProfitProtectingSL(trade, protected_price, min_profit_distance))
     {
      decision.reason = "قیمت جدید حد ضرر سود معامله را به‌درستی محافظت نمی‌کند";
      return false;
     }

   if(trade.is_buy && trade.current_sl > 0.0 && protected_price <= trade.current_sl)
     {
      decision.reason = "حد ضرر جدید برای خرید بهبود محسوسی ندارد";
      return false;
     }

   if(!trade.is_buy && trade.current_sl > 0.0 && protected_price >= trade.current_sl)
     {
      decision.reason = "حد ضرر جدید برای فروش بهبود محسوسی ندارد";
      return false;
     }

   decision.valid          = true;
   decision.request_move_sl= true;
   decision.new_sl         = protected_price;
   decision.event          = TRADE_EVENT_MOVE_SL_TO_PROFIT;
   decision.reason         = "حد ضرر برای حفاظت از سود آماده انتقال است";

   return true;
  }

//------------------------------------------------------------------
// آماده‌سازی Partial Close
//------------------------------------------------------------------
bool TradeManager_PreparePartialClose(const ManagedTrade &trade,
                                      const double percent,
                                      const double volume_step,
                                      const double min_volume,
                                      TradeManagementDecision &decision)
  {
   TradeManager_InitDecision(decision);

   if(trade.partial_done)
     {
      decision.reason = "خروج بخشی قبلاً انجام شده است";
      return false;
     }

   double close_volume = TradeManager_CalculatePartialVolume(trade.volume,
                                                               percent,
                                                               volume_step,
                                                               min_volume);

   if(!TradeManager_IsPartialVolumeValid(trade.volume, close_volume, min_volume))
     {
      decision.reason = "حجم خروج بخشی معتبر نیست | " +
                        "Current=" + DoubleToString(trade.volume, 4) +
                        " | Calculated=" + DoubleToString(close_volume, 4) +
                        " | Min=" + DoubleToString(min_volume, 4);
      return false;
     }

   decision.valid                    = true;
   decision.request_partial_close    = true;
   decision.partial_close_volume     = close_volume;
   decision.event                    = TRADE_EVENT_PARTIAL_CLOSE_REQUESTED;
   decision.reason                   = "حجم مناسب برای خروج بخشی محاسبه شد";

   return true;
  }

//------------------------------------------------------------------
// ثبت موفقیت Partial Close
//------------------------------------------------------------------
void TradeManager_MarkPartialCloseDone(ManagedTrade &trade,
                                       const datetime current_time,
                                       const string reason)
  {
   trade.partial_done   = true;
   trade.state          = TRADE_MGMT_PARTIAL_DONE;
   trade.last_update_time = current_time;
   trade.last_reason    = reason;
   
   Print(
      "[TRADE MANAGER] PARTIAL DONE",
      " | Ticket=", trade.ticket,
      " | Reason=", reason
   );
  }

//------------------------------------------------------------------
// ثبت موفقیت Break Even
//------------------------------------------------------------------
void TradeManager_MarkBreakEvenDone(ManagedTrade &trade,
                                    const datetime current_time,
                                    const double new_sl,
                                    const string reason)
  {
   trade.break_even_done = true;
   trade.current_sl      = new_sl;
   trade.state            = TRADE_MGMT_BREAK_EVEN;
   trade.last_update_time = current_time;
   trade.last_reason      = reason;
   
   Print(
      "[TRADE MANAGER] BREAK EVEN",
      " | Ticket=", trade.ticket,
      " | NewSL=", DoubleToString(new_sl, _Digits),
      " | Reason=", reason
   );
  }

//------------------------------------------------------------------
// ثبت حفاظت از سود
//------------------------------------------------------------------
void TradeManager_MarkProfitProtectionDone(ManagedTrade &trade,
                                           const datetime current_time,
                                           const double new_sl,
                                           const string reason)
  {
   trade.profit_protection_done = true;
   trade.current_sl              = new_sl;
   trade.state                   = TRADE_MGMT_PROTECTING_PROFIT;
   trade.last_update_time        = current_time;
   trade.last_reason             = reason;
   
   Print(
      "[TRADE MANAGER] PROFIT PROTECTION",
      " | Ticket=", trade.ticket,
      " | NewSL=", DoubleToString(new_sl, _Digits),
      " | Reason=", reason
   );
  }

//------------------------------------------------------------------
// به‌روزرسانی وضعیت معامله
//------------------------------------------------------------------
void TradeManager_UpdateTrade(ManagedTrade &trade,
                              const double current_price,
                              const double profit,
                              const double swap,
                              const double commission,
                              const datetime current_time)
  {
   trade.current_price     = current_price;
   trade.profit            = profit;
   trade.swap              = swap;
   trade.commission        = commission;
   trade.last_update_time  = current_time;

   if(trade.state == TRADE_MGMT_UNKNOWN)
      trade.state = TRADE_MGMT_ACTIVE;

   if(trade.partial_done && trade.profit_protection_done)
      trade.state = TRADE_MGMT_PROTECTING_PROFIT;
   else
   if(trade.partial_done && trade.break_even_done)
      trade.state = TRADE_MGMT_BREAK_EVEN;
   else
   if(trade.partial_done)
      trade.state = TRADE_MGMT_PARTIAL_DONE;
  }

//------------------------------------------------------------------
// بررسی رسیدن قیمت به Target
//------------------------------------------------------------------
bool TradeManager_IsTargetReached(const ManagedTrade &trade)
  {
   if(trade.target_price <= 0.0 || trade.current_price <= 0.0)
      return false;

   if(trade.is_buy)
      return (trade.current_price >= trade.target_price);

   return (trade.current_price <= trade.target_price);
  }

//------------------------------------------------------------------
// بررسی فعال شدن Invalidation
//------------------------------------------------------------------
bool TradeManager_IsInvalidationReached(const ManagedTrade &trade)
  {
   if(trade.invalidation_price <= 0.0 || trade.current_price <= 0.0)
      return false;

   if(trade.is_buy)
      return (trade.current_price <= trade.invalidation_price);

   return (trade.current_price >= trade.invalidation_price);
  }

//------------------------------------------------------------------
// ایجاد تصمیم خروج به دلیل Target
//------------------------------------------------------------------
bool TradeManager_PrepareTargetExit(const ManagedTrade &trade,
                                    TradeManagementDecision &decision)
  {
   TradeManager_InitDecision(decision);

   if(!TradeManager_IsTargetReached(trade))
     {
      decision.reason = "هدف هنوز محقق نشده است";
      return false;
     }

   decision.valid         = true;
   decision.request_exit = true;
   decision.event         = TRADE_EVENT_TARGET_REACHED;
   decision.reason        = "قیمت به هدف تعیین‌شده رسیده است";

   return true;
  }

//------------------------------------------------------------------
// ایجاد تصمیم خروج به دلیل Invalidation
//------------------------------------------------------------------
bool TradeManager_PrepareInvalidationExit(const ManagedTrade &trade,
                                          TradeManagementDecision &decision)
  {
   TradeManager_InitDecision(decision);

   if(!TradeManager_IsInvalidationReached(trade))
     {
      decision.reason = "ابطال سناریو فعال نشده است";
      return false;
     }

   decision.valid         = true;
   decision.request_exit  = true;
   decision.event         = TRADE_EVENT_INVALIDATION;
   decision.reason        = "شرایط ابطال سناریو برقرار شده است";

   return true;
  }

//------------------------------------------------------------------
// علامت‌گذاری بسته شدن معامله
//------------------------------------------------------------------
void TradeManager_MarkClosed(ManagedTrade &trade,
                             const datetime current_time,
                             const string reason)
  {
   trade.state            = TRADE_MGMT_CLOSED;
   trade.last_update_time = current_time;
   trade.last_reason      = reason;
   
   Print(
      "[TRADE MANAGER] CLOSED",
      " | Ticket=", trade.ticket,
      " | Reason=", reason
   );
  }

//------------------------------------------------------------------
// علامت‌گذاری خطا
//------------------------------------------------------------------
void TradeManager_MarkError(ManagedTrade &trade,
                            const datetime current_time,
                            const string reason)
  {
   trade.state            = TRADE_MGMT_ERROR;
   trade.last_update_time = current_time;
   trade.last_reason      = reason;
   
   Print(
      "[TRADE MANAGER] ERROR",
      " | Ticket=", trade.ticket,
      " | Reason=", reason
   );
  }

//------------------------------------------------------------------
// تولید متن گزارش معامله
//------------------------------------------------------------------
string TradeManager_ToText(const ManagedTrade &trade)
  {
   string direction = trade.is_buy ? "خرید" : "فروش";

   string text = "";
   text += "تیکت: " + IntegerToString((long)trade.ticket);
   text += " | نماد: " + trade.symbol;
   text += " | جهت: " + direction;
   text += " | حجم: " + DoubleToString(trade.volume, 2);
   text += " | ورود: " + DoubleToString(trade.entry_price, _Digits);
   text += " | قیمت فعلی: " + DoubleToString(trade.current_price, _Digits);
   text += " | SL: " + DoubleToString(trade.current_sl, _Digits);
   text += " | TP: " + DoubleToString(trade.current_tp, _Digits);
   text += " | سود: " + DoubleToString(trade.profit, 2);
   text += " | Swap: " + DoubleToString(trade.swap, 2);
   text += " | کمیسیون: " + DoubleToString(trade.commission, 2);
   text += " | وضعیت: " + TradeManagementStateToPersian(trade.state);
   text += " | خروج بخشی: " + (trade.partial_done ? "بله" : "خیر");
   text += " | نقطه ورود: " + DoubleToString(trade.entry_price, _Digits);
   text += " | هدف: " + DoubleToString(trade.target_price, _Digits);
   text += " | ابطال: " + DoubleToString(trade.invalidation_price, _Digits);

   if(trade.last_reason != "")
      text += " | دلیل آخرین وضعیت: " + trade.last_reason;

   return text;
  }

//------------------------------------------------------------------
// آیا SL جدید بهبود است؟
//------------------------------------------------------------------
bool TradeManager_IsSLImprovement(const ManagedTrade &trade, const double new_sl)
  {
   if(new_sl <= 0.0) return false;
   if(trade.current_sl <= 0.0) return true;
   return trade.is_buy ? (new_sl > trade.current_sl) : (new_sl < trade.current_sl);
  }

//------------------------------------------------------------------
// آیا SL جدید در سمت صحیح قیمت است؟
//------------------------------------------------------------------
bool TradeManager_IsSLOnCorrectSideOfPrice(const ManagedTrade &trade, const double new_sl)
  {
   if(new_sl <= 0.0 || trade.current_price <= 0.0) return false;
   return trade.is_buy ? (new_sl < trade.current_price) : (new_sl > trade.current_price);
  }

//------------------------------------------------------------------
// آیا TP1 رسیده است؟
//------------------------------------------------------------------
bool TradeManager_IsTP1Reached(const ManagedTrade &trade)
  {
   if(trade.target_1 <= 0.0 || trade.current_price <= 0.0) return false;
   return trade.is_buy ? (trade.current_price >= trade.target_1) : (trade.current_price <= trade.target_1);
  }

//------------------------------------------------------------------
// [اصلاح حیاتی] محاسبه SL مرحله 1
// SL مرحله 1 = نیمه مسیر Entry تا TP1
//------------------------------------------------------------------
double TradeManager_GetStage1SL(const ManagedTrade &trade)
  {
   if(trade.target_1 <= 0.0 || trade.entry_price <= 0.0)
      return 0.0;

   double distance = MathAbs(trade.target_1 - trade.entry_price);
   double half_distance = distance * 0.50;

   if(trade.is_buy)
      return trade.entry_price + half_distance;
   else
      return trade.entry_price - half_distance;
  }

//------------------------------------------------------------------
// آماده‌سازی SL مرحله 1
// [اصلاح] استفاده از نیمه مسیر Entry تا TP1 به جای مقدار ثابت 1.0
// [اصلاح] افزودن بررسی sl_stage_1_done
//------------------------------------------------------------------
bool TradeManager_PrepareSLStage1(const ManagedTrade &trade, TradeManagementDecision &decision)
  {
   TradeManager_InitDecision(decision);

   //--- [اصلاح] بررسی اینکه Stage 1 قبلاً انجام نشده
   if(trade.sl_stage_1_done)
     {
      decision.reason = "Stage 1 SL قبلاً انجام شده است";
      return false;
     }

   if(trade.target_1 <= 0.0 || trade.entry_price <= 0.0)
     {
      decision.reason = "Target 1 یا Entry معتبر نیست";
      return false;
     }

   //--- [اصلاح] SL مرحله 1 = نیمه مسیر Entry تا TP1
   double new_sl = TradeManager_GetStage1SL(trade);

   if(new_sl <= 0.0)
     {
      decision.reason = "محاسبه SL مرحله 1 ناموفق بود";
      return false;
     }

   if(!TradeManager_IsSLOnCorrectSideOfPrice(trade, new_sl) ||
      !TradeManager_IsSLImprovement(trade, new_sl))
     {
      decision.reason = "SL مرحله 1 بهبود نیست یا در سمت اشتباه قیمت است";
      return false;
     }

   decision.valid = true;
   decision.request_move_sl = true;
   decision.new_sl = new_sl;
   decision.event = TRADE_EVENT_MOVE_SL_TO_PROFIT;
   decision.reason = "Stage 1: انتقال SL به نیمه مسیر Entry تا TP1";

   Print(
      "[TRADE MANAGER] STAGE 1 PREPARED",
      " | Ticket=", trade.ticket,
      " | Entry=", DoubleToString(trade.entry_price, _Digits),
      " | TP1=", DoubleToString(trade.target_1, _Digits),
      " | NewSL=", DoubleToString(new_sl, _Digits)
   );

   return true;
  }

//------------------------------------------------------------------
// آماده‌سازی Partial Close در TP1
//------------------------------------------------------------------
bool TradeManager_PrepareTP1PartialClose(const ManagedTrade &trade, const double percent,
                                         const double volume_step, const double min_volume,
                                         TradeManagementDecision &decision)
  {
   return TradeManager_PreparePartialClose(trade, percent, volume_step, min_volume, decision);
  }

//------------------------------------------------------------------
// آماده‌سازی SL مرحله 3
// [اصلاح] افزودن بررسی sl_stage_3_done
//------------------------------------------------------------------
bool TradeManager_PrepareSLStage3(const ManagedTrade &trade, TradeManagementDecision &decision)
  {
   TradeManager_InitDecision(decision);

   //--- [اصلاح] بررسی اینکه Stage 3 قبلاً انجام نشده
   if(trade.sl_stage_3_done)
     {
      decision.reason = "Stage 3 SL قبلاً انجام شده است";
      return false;
     }

   if(trade.target_1 <= 0.0 || trade.target_2 <= 0.0 || trade.current_price <= 0.0)
     {
      decision.reason = "Target 1, Target 2 یا قیمت جاری معتبر نیست";
      return false;
     }

   if(!TradeManager_IsTP1Reached(trade))
     {
      decision.reason = "TP1 هنوز نرسیده است";
      return false;
     }

   double new_sl = trade.target_1;

   if(!TradeManager_IsSLOnCorrectSideOfPrice(trade, new_sl) ||
      !TradeManager_IsSLImprovement(trade, new_sl))
     {
      decision.reason = "SL مرحله 3 بهبود نیست یا در سمت اشتباه قیمت است";
      return false;
     }

   decision.valid = true;
   decision.request_move_sl = true;
   decision.new_sl = new_sl;
   decision.event = TRADE_EVENT_MOVE_SL_TO_PROFIT;
   decision.reason = "Stage 3: انتقال SL به TP1 پس از پیشروی قیمت";

   Print(
      "[TRADE MANAGER] STAGE 3 PREPARED",
      " | Ticket=", trade.ticket,
      " | TP1=", DoubleToString(trade.target_1, _Digits),
      " | NewSL=", DoubleToString(new_sl, _Digits)
   );

   return true;
  }

//+------------------------------------------------------------------+

#endif // __TFLAB_TRADE_MANAGER_MQH__