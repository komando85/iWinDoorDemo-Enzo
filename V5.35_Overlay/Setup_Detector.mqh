#ifndef __TFLAB_SETUP_DETECTOR_MQH__
#define __TFLAB_SETUP_DETECTOR_MQH__

//+------------------------------------------------------------------+
//|                     Setup_Detector.mqh                           |
//|                     TFlab New EA V.5                                 |
//|                                                                  |
//| مسئولیت: تشخیص آماده بودن Setup برای اجرای سناریو                |
//| بدون اجرای سفارش، محاسبه حجم، SL، TP یا مدیریت معامله             |
//|                                                                  |
//| v2.1 - رفع باگ بزرگ TRIGGERED (ورود Market) + بهبود تشخیص       |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// وضعیت آماده‌سازی Setup
//====================================================================
enum ENUM_SETUP_STATE
  {
   SETUP_STATE_NONE = 0,
   SETUP_STATE_WAITING,
   SETUP_STATE_WATCHING,
   SETUP_STATE_READY,
   SETUP_STATE_TRIGGERED,
   SETUP_STATE_INVALID,
   SETUP_STATE_EXPIRED
  };

//====================================================================
// دلیل وضعیت Setup
//====================================================================
enum ENUM_SETUP_REASON
  {
   SETUP_REASON_NONE = 0,
   SETUP_REASON_SCENARIO_NOT_VALID,
   SETUP_REASON_ZONE_NOT_VALID,
   SETUP_REASON_WAITING_FOR_ZONE,
   SETUP_REASON_WAITING_FOR_TRIGGER,
   SETUP_REASON_PRICE_IN_ZONE,
   SETUP_REASON_TRIGGER_CONFIRMED,
   SETUP_REASON_INVALIDATION_REACHED,
   SETUP_REASON_EXPIRED
  };

//====================================================================
// ساختار اطلاعات Setup
//====================================================================
struct SetupState
  {
   ENUM_SETUP_STATE  state;
   ENUM_SETUP_REASON reason;

   bool              scenario_valid;
   bool              zone_valid;
   bool              price_in_zone;
   bool              trigger_confirmed;
   bool              invalidated;
   bool              expired;
   bool              recent_zone_touch;
   bool              reaction_confirmed;
   datetime          confirmation_bar_time;

   double            current_price;
   double            trigger_price;
   double            zone_lower;
   double            zone_upper;
   double            invalidation_price;

   datetime          analysis_time;
   string            direction;
   string            message;
  };

//------------------------------------------------------------------
// تبدیل وضعیت Setup به فارسی
//------------------------------------------------------------------
string SetupStateToPersian(const ENUM_SETUP_STATE state)
  {
   switch(state)
     {
      case SETUP_STATE_WAITING:   return "در انتظار";
      case SETUP_STATE_WATCHING:  return "در حال پایش";
      case SETUP_STATE_READY:     return "آماده ورود";
      case SETUP_STATE_TRIGGERED: return "فعال شده";
      case SETUP_STATE_INVALID:   return "باطل";
      case SETUP_STATE_EXPIRED:   return "منقضی";
      default:                    return "نامشخص";
     }
  }

//------------------------------------------------------------------
// تبدیل دلیل Setup به فارسی
//------------------------------------------------------------------
string SetupReasonToPersian(const ENUM_SETUP_REASON reason)
  {
   switch(reason)
     {
      case SETUP_REASON_SCENARIO_NOT_VALID:    return "سناریو معتبر نیست";
      case SETUP_REASON_ZONE_NOT_VALID:        return "ناحیه معتبر نیست";
      case SETUP_REASON_WAITING_FOR_ZONE:      return "در انتظار رسیدن قیمت به ناحیه";
      case SETUP_REASON_WAITING_FOR_TRIGGER:   return "در انتظار شرط فعال‌سازی";
      case SETUP_REASON_PRICE_IN_ZONE:         return "قیمت داخل ناحیه قرار دارد";
      case SETUP_REASON_TRIGGER_CONFIRMED:     return "شرط فعال‌سازی تأیید شده است";
      case SETUP_REASON_INVALIDATION_REACHED:  return "سطح ابطال شکسته شده است";
      case SETUP_REASON_EXPIRED:               return "زمان Setup به پایان رسیده است";
      default:                                 return "بدون دلیل مشخص";
     }
  }

//------------------------------------------------------------------
// مقداردهی اولیه Setup
//------------------------------------------------------------------
void Setup_Init(SetupState &setup)
  {
   setup.state              = SETUP_STATE_NONE;
   setup.reason             = SETUP_REASON_NONE;

   setup.scenario_valid     = false;
   setup.zone_valid         = false;
   setup.price_in_zone      = false;
   setup.trigger_confirmed  = false;
   setup.invalidated        = false;
   setup.expired            = false;
   setup.recent_zone_touch   = false;
   setup.reaction_confirmed  = false;
   setup.confirmation_bar_time = 0;

   setup.current_price      = 0.0;
   setup.trigger_price      = 0.0;
   setup.zone_lower         = 0.0;
   setup.zone_upper         = 0.0;
   setup.invalidation_price = 0.0;

   setup.analysis_time      = 0;
   setup.direction          = "";
   setup.message            = "";
  }

//------------------------------------------------------------------
// تنظیم اطلاعات پایه Setup
//------------------------------------------------------------------
bool Setup_SetBase(SetupState &setup,
                   const bool scenario_valid,
                   const bool zone_valid,
                   const bool invalidated,
                   const bool expired,
                   const string direction,
                   const double current_price,
                   const double zone_lower,
                   const double zone_upper,
                   const double invalidation_price,
                   const double trigger_price,
                   const datetime analysis_time)
  {
   Setup_Init(setup);

   setup.scenario_valid     = scenario_valid;
   setup.zone_valid         = zone_valid;
   setup.invalidated        = invalidated;
   setup.expired            = expired;
   setup.direction          = direction;
   setup.current_price      = current_price;
   setup.zone_lower         = zone_lower;
   setup.zone_upper         = zone_upper;
   setup.invalidation_price = invalidation_price;
   setup.trigger_price      = trigger_price;
   setup.analysis_time      = analysis_time;

   if(expired)
     {
      setup.state   = SETUP_STATE_EXPIRED;
      setup.reason  = SETUP_REASON_EXPIRED;
      setup.message = SetupReasonToPersian(setup.reason);
      return true;
     }

   if(invalidated)
     {
      setup.state   = SETUP_STATE_INVALID;
      setup.reason  = SETUP_REASON_INVALIDATION_REACHED;
      setup.message = SetupReasonToPersian(setup.reason);
      return true;
     }

   return true;
  }

//------------------------------------------------------------------
// بررسی قرار گرفتن قیمت داخل ناحیه
//------------------------------------------------------------------
bool Setup_IsPriceInZone(const double price,
                         const double zone_lower,
                         const double zone_upper)
  {
   if(price <= 0.0)
      return false;

   if(zone_lower <= 0.0 || zone_upper <= 0.0)
      return false;

   if(zone_upper < zone_lower)
      return false;

   return (price >= zone_lower && price <= zone_upper);
  }

//------------------------------------------------------------------
// ارزیابی پایه Setup
// [اصلاح حیاتی] رفع باگ TRIGGERED برای ورودهای Market
//------------------------------------------------------------------
//====================================================================
// V5.35 - لمس معتبر Zone در کندل‌های بسته قبلی
//====================================================================
bool Setup_HasPriorZoneTouch(const SetupState &setup,
                              const int lookback_bars)
  {
   if(setup.zone_lower <= 0.0 || setup.zone_upper <= setup.zone_lower)
      return false;

   const int bars = MathMax(1, MathMin(6, lookback_bars));

   // کندل 1 عمداً حذف شده است؛ ابتدا باید لمس در کندل قبلی رخ داده باشد.
   for(int i = 2; i <= bars + 1; i++)
     {
      const double high = iHigh(_Symbol, PERIOD_M5, i);
      const double low  = iLow(_Symbol, PERIOD_M5, i);

      if(high <= 0.0 || low <= 0.0)
         continue;

      if(high >= setup.zone_lower && low <= setup.zone_upper)
         return true;
     }

   return false;
  }

//====================================================================
// V5.35 - تأیید واکنش + شکست میکروساختار M5
//====================================================================
bool Setup_ConfirmReactionBreak(const SetupState &setup,
                                 double &confirmation_price,
                                 string &confirmation_reason)
  {
   confirmation_price = 0.0;
   confirmation_reason = "";

   if(!Setup_HasPriorZoneTouch(setup, 3))
     {
      confirmation_reason = "لمس معتبر Zone در کندل بسته قبلی وجود ندارد";
      return false;
     }

   const double open1  = iOpen(_Symbol, PERIOD_M5, 1);
   const double high1  = iHigh(_Symbol, PERIOD_M5, 1);
   const double low1   = iLow(_Symbol, PERIOD_M5, 1);
   const double close1 = iClose(_Symbol, PERIOD_M5, 1);
   const double high2  = iHigh(_Symbol, PERIOD_M5, 2);
   const double low2   = iLow(_Symbol, PERIOD_M5, 2);

   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 ||
      high2 <= 0.0 || low2 <= 0.0 || high1 <= low1)
     {
      confirmation_reason = "داده کندل تأییدی کامل نیست";
      return false;
     }

   const double range1 = high1 - low1;
   const double body1 = MathAbs(close1 - open1);
   const double body_ratio = body1 / range1;

   if(body_ratio < 0.30)
     {
      confirmation_reason = "بدنه کندل تأییدی ضعیف است | BodyRatio=" +
                            DoubleToString(body_ratio * 100.0, 1) + "%";
      return false;
     }

   const bool is_buy =
      (setup.direction == "BUY" || setup.direction == "خرید" ||
       StringFind(setup.direction, "BUY") >= 0 ||
       StringFind(setup.direction, "خرید") >= 0);

   const bool is_sell =
      (setup.direction == "SELL" || setup.direction == "فروش" ||
       StringFind(setup.direction, "SELL") >= 0 ||
       StringFind(setup.direction, "فروش") >= 0);

   if(is_buy)
     {
      if(close1 <= open1)
        {
         confirmation_reason = "کندل آخر صعودی نیست؛ واکنش BUY تأیید نشده است";
         return false;
        }

      if(close1 <= high2)
        {
         confirmation_reason = "شکست میکروساختار BUY هنوز رخ نداده است";
         return false;
        }

      confirmation_price = close1;
      confirmation_reason = "واکنش BUY تأیید شد | لمس Zone قبلی + کندل صعودی + شکست High کندل قبل";
      return true;
     }

   if(is_sell)
     {
      if(close1 >= open1)
        {
         confirmation_reason = "کندل آخر نزولی نیست؛ واکنش SELL تأیید نشده است";
         return false;
        }

      if(close1 >= low2)
        {
         confirmation_reason = "شکست میکروساختار SELL هنوز رخ نداده است";
         return false;
        }

      confirmation_price = close1;
      confirmation_reason = "واکنش SELL تأیید شد | لمس Zone قبلی + کندل نزولی + شکست Low کندل قبل";
      return true;
     }

   confirmation_reason = "جهت Setup برای تأیید واکنش مشخص نیست";
   return false;
  }

bool Setup_Evaluate(SetupState &setup)
  {
   if(setup.expired)
     {
      setup.state=SETUP_STATE_EXPIRED; setup.reason=SETUP_REASON_EXPIRED;
      setup.message=SetupReasonToPersian(setup.reason); return false;
     }
   if(setup.invalidated)
     {
      setup.state=SETUP_STATE_INVALID; setup.reason=SETUP_REASON_INVALIDATION_REACHED;
      setup.message=SetupReasonToPersian(setup.reason); return false;
     }
   if(!setup.scenario_valid)
     {
      setup.state=SETUP_STATE_WAITING; setup.reason=SETUP_REASON_SCENARIO_NOT_VALID;
      setup.message=SetupReasonToPersian(setup.reason); return false;
     }
   if(!setup.zone_valid)
     {
      setup.state=SETUP_STATE_WAITING; setup.reason=SETUP_REASON_ZONE_NOT_VALID;
      setup.message=SetupReasonToPersian(setup.reason); return false;
     }

   setup.price_in_zone = Setup_IsPriceInZone(setup.current_price, setup.zone_lower, setup.zone_upper);
   setup.recent_zone_touch = Setup_HasPriorZoneTouch(setup, 3);

   // لمس Zone به‌تنهایی Trigger نیست.
   if(!setup.recent_zone_touch)
     {
      setup.trigger_confirmed=false;
      setup.reaction_confirmed=false;
      setup.state=SETUP_STATE_WATCHING;
      setup.reason=SETUP_REASON_WAITING_FOR_ZONE;
      setup.message=SetupReasonToPersian(setup.reason);
      return true;
     }

   double confirmation_price=0.0;
   string confirmation_reason="";
   if(!Setup_ConfirmReactionBreak(setup, confirmation_price, confirmation_reason))
     {
      setup.trigger_confirmed=false;
      setup.reaction_confirmed=false;
      setup.state=SETUP_STATE_WATCHING;
      setup.reason=SETUP_REASON_WAITING_FOR_TRIGGER;
      setup.message=confirmation_reason;
      Print("[SETUP V5.35] WAIT | Direction=",setup.direction,
            " | Price=",DoubleToString(setup.current_price,_Digits),
            " | Reason=",confirmation_reason);
      return true;
     }

   setup.trigger_confirmed=true;
   setup.reaction_confirmed=true;
   setup.trigger_price=confirmation_price;
   setup.confirmation_bar_time=iTime(_Symbol,PERIOD_M5,1);
   setup.state=SETUP_STATE_TRIGGERED;
   setup.reason=SETUP_REASON_TRIGGER_CONFIRMED;
   setup.message=confirmation_reason+" | ورود فقط بعد از تأیید واکنش و شکست میکروساختار مجاز شد";

   Print("[SETUP V5.35] TRIGGERED | Direction=",setup.direction,
         " | Confirm=",DoubleToString(confirmation_price,_Digits),
         " | Reason=",confirmation_reason);
   return true;
  }

bool Setup_SetTriggerConfirmed(SetupState &setup,
                               const bool confirmed,
                               const datetime analysis_time)
  {
   setup.trigger_confirmed = false;
   setup.reaction_confirmed = false;
   setup.analysis_time = analysis_time;

   return Setup_Evaluate(setup);
  }

//------------------------------------------------------------------
// بررسی عبور قیمت از Invalidation
//------------------------------------------------------------------
void Setup_CheckInvalidation(SetupState &setup)
  {
   if(setup.invalidation_price <= 0.0)
      return;

   // بررسی جهت بر اساس متن فارسی یا انگلیسی
   bool is_buy = (setup.direction == "BUY" || 
                  setup.direction == "خرید" || 
                  StringFind(setup.direction, "BUY") >= 0 || 
                  StringFind(setup.direction, "خرید") >= 0);
                  
   bool is_sell = (setup.direction == "SELL" || 
                   setup.direction == "فروش" || 
                   StringFind(setup.direction, "SELL") >= 0 || 
                   StringFind(setup.direction, "فروش") >= 0);

   if(is_buy)
     {
      if(setup.current_price < setup.invalidation_price)
         setup.invalidated = true;
     }
   else if(is_sell)
     {
      if(setup.current_price > setup.invalidation_price)
         setup.invalidated = true;
     }

   if(setup.invalidated)
     {
      setup.state   = SETUP_STATE_INVALID;
      setup.reason  = SETUP_REASON_INVALIDATION_REACHED;
      setup.message = SetupReasonToPersian(setup.reason);
     }
  }

//------------------------------------------------------------------
// مشخص کردن انقضا
//------------------------------------------------------------------
void Setup_SetExpired(SetupState &setup,
                      const bool expired,
                      const datetime analysis_time)
  {
   setup.expired       = expired;
   setup.analysis_time = analysis_time;

   if(expired)
     {
      setup.state   = SETUP_STATE_EXPIRED;
      setup.reason  = SETUP_REASON_EXPIRED;
      setup.message = SetupReasonToPersian(setup.reason);
     }
  }

//------------------------------------------------------------------
// بررسی آماده بودن برای Entry
//------------------------------------------------------------------
bool Setup_IsReadyForEntry(const SetupState &setup)
  {
   return (setup.state == SETUP_STATE_READY ||
           setup.state == SETUP_STATE_TRIGGERED);
  }

//------------------------------------------------------------------
// بررسی فعال شدن واقعی Setup
//------------------------------------------------------------------
bool Setup_IsTriggered(const SetupState &setup)
  {
   return (setup.state == SETUP_STATE_TRIGGERED);
  }

//------------------------------------------------------------------
// تبدیل Setup به متن گزارش
//------------------------------------------------------------------
string Setup_ToText(const SetupState &setup)
  {
   string text = "";

   text += "وضعیت Setup: " + SetupStateToPersian(setup.state);
   text += " | دلیل: " + SetupReasonToPersian(setup.reason);
   text += " | جهت: " + setup.direction;
   text += " | قیمت: " + DoubleToString(setup.current_price, _Digits);
   text += " | ناحیه: " + DoubleToString(setup.zone_lower, _Digits);
   text += " - " + DoubleToString(setup.zone_upper, _Digits);
   text += " | Trigger: " + DoubleToString(setup.trigger_price, _Digits);
   text += " | ابطال: " + DoubleToString(setup.invalidation_price, _Digits);
   text += " | لمس قبلی Zone: " + (setup.recent_zone_touch ? "بله" : "خیر");
   text += " | واکنش تأییدشده: " + (setup.reaction_confirmed ? "بله" : "خیر");

   return text;
  }

//+------------------------------------------------------------------+

#endif // __TFLAB_SETUP_DETECTOR_MQH__