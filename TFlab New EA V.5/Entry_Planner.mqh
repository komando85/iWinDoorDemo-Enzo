//+------------------------------------------------------------------+
//|                        Entry_Planner.mqh                         |
//|                        TFlab New EA V.5                              |
//|                                                                  |
//| مسئولیت: تبدیل سناریوی معتبر و Setup آماده به برنامه ورود        |
//| بدون اجرای سفارش، محاسبه حجم، SL، TP یا مدیریت معامله             |
//|                                                                  |
//| v2.1 - Fixed entry_reachable initialization + Better diagnostics |
//+------------------------------------------------------------------+
#property strict

#include "EA_Inputs.mqh"
#include "Scenario_Engine.mqh"
#include "Setup_Detector.mqh"

//====================================================================
// روش واقعی برنامه‌ریزی ورود
//====================================================================
enum ENUM_ENTRY_PLAN_TYPE
  {
   ENTRY_PLAN_NONE = 0,
   ENTRY_PLAN_WAIT,
   ENTRY_PLAN_MARKET,
   ENTRY_PLAN_LIMIT,
   ENTRY_PLAN_STOP,
   ENTRY_PLAN_NO_ENTRY,
   ENTRY_PLAN_INVALID,
   ENTRY_PLAN_EXPIRED
  };

//====================================================================
// وضعیت برنامه ورود
//====================================================================
enum ENUM_ENTRY_PLAN_STATUS
  {
   ENTRY_PLAN_STATUS_NONE = 0,
   ENTRY_PLAN_STATUS_PLANNED,
   ENTRY_PLAN_STATUS_READY,
   ENTRY_PLAN_STATUS_SENT,
   ENTRY_PLAN_STATUS_FILLED,
   ENTRY_PLAN_STATUS_CANCELLED,
   ENTRY_PLAN_STATUS_EXPIRED,
   ENTRY_PLAN_STATUS_INVALID
  };

//====================================================================
// ساختار برنامه ورود
//====================================================================
struct EntryPlan
  {
   ulong                    scenario_id;
   ENUM_SCENARIO_DIRECTION  direction;
   ENUM_ENTRY_PLAN_TYPE     type;
   ENUM_ENTRY_PLAN_STATUS   status;

   string                   symbol;

   double                   current_price;
   double                   entry_price;
   double                   zone_lower;
   double                   zone_upper;
   double                   invalidation_price;

   datetime                 created_time;
   datetime                 expiry_time;

   bool                     pending_allowed;
   bool                     executable;
   bool                     entry_currently_available;
   bool                     entry_reachable;

   string                   reason;
  };

//====================================================================
// متن فارسی نوع برنامه ورود
//====================================================================
string EntryPlanTypeToPersian(const ENUM_ENTRY_PLAN_TYPE type)
  {
   switch(type)
     {
      case ENTRY_PLAN_WAIT:       return "انتظار";
      case ENTRY_PLAN_MARKET:     return "ورود لحظه‌ای";
      case ENTRY_PLAN_LIMIT:      return "سفارش Limit";
      case ENTRY_PLAN_STOP:       return "سفارش Stop";
      case ENTRY_PLAN_NO_ENTRY:   return "بدون ورود";
      case ENTRY_PLAN_INVALID:    return "نامعتبر";
      case ENTRY_PLAN_EXPIRED:    return "منقضی";
      default:                    return "بدون برنامه";
     }
  }

//====================================================================
// متن فارسی وضعیت برنامه
//====================================================================
string EntryPlanStatusToPersian(const ENUM_ENTRY_PLAN_STATUS status)
  {
   switch(status)
     {
      case ENTRY_PLAN_STATUS_PLANNED:   return "برنامه‌ریزی شده";
      case ENTRY_PLAN_STATUS_READY:     return "آماده اجرا";
      case ENTRY_PLAN_STATUS_SENT:      return "ارسال شده";
      case ENTRY_PLAN_STATUS_FILLED:    return "اجرا شده";
      case ENTRY_PLAN_STATUS_CANCELLED: return "لغو شده";
      case ENTRY_PLAN_STATUS_EXPIRED:   return "منقضی";
      case ENTRY_PLAN_STATUS_INVALID:   return "باطل";
      default:                          return "نامشخص";
     }
  }

//====================================================================
// مقداردهی اولیه
// [اصلاح] افزودن entry_reachable = false
//====================================================================
void EntryPlan_Init(EntryPlan &plan)
  {
   plan.scenario_id        = 0;
   plan.direction          = SCENARIO_DIRECTION_NONE;
   plan.type               = ENTRY_PLAN_NONE;
   plan.status             = ENTRY_PLAN_STATUS_NONE;
   plan.symbol             = "";

   plan.current_price      = 0.0;
   plan.entry_price        = 0.0;
   plan.zone_lower         = 0.0;
   plan.zone_upper         = 0.0;
   plan.invalidation_price = 0.0;

   plan.created_time       = 0;
   plan.expiry_time        = 0;

   plan.pending_allowed    = false;
   plan.executable         = false;
   plan.entry_currently_available = false;
   plan.entry_reachable    = false;  // [اصلاح] مقداردهی اولیه
   plan.reason             = "";
  }

//====================================================================
// بررسی کامل بودن حداقل داده‌های برنامه ورود
//====================================================================
bool EntryPlan_HasMinimumData(const EntryPlan &plan)
  {
   if(plan.scenario_id == 0)
      return false;

   if(plan.symbol == "")
      return false;

   if(plan.direction == SCENARIO_DIRECTION_NONE)
      return false;

   if(plan.type == ENTRY_PLAN_NONE)
      return false;

   return true;
  }

//====================================================================
// اعتبارسنجی فاصله ورود از قیمت جاری
//====================================================================
bool EntryPlan_IsWithinDeviation(const string symbol,
                                 const double current_price,
                                 const double planned_entry,
                                 const double max_deviation_points)
  {
   if(symbol == "" || current_price <= 0.0 || planned_entry <= 0.0)
      return false;

   if(max_deviation_points < 0.0)
      return false;

   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double deviation = MathAbs(current_price - planned_entry) / point;
   return (deviation <= max_deviation_points);
  }

//====================================================================
// تعیین اینکه قیمت از نظر جهت برای Limit مناسب است
//====================================================================
bool EntryPlan_IsValidLimitPrice(const ENUM_SCENARIO_DIRECTION direction,
                                 const double current_price,
                                 const double entry_price)
  {
   if(current_price <= 0.0 || entry_price <= 0.0)
      return false;

   if(direction == SCENARIO_DIRECTION_BUY)
      return (entry_price < current_price);

   if(direction == SCENARIO_DIRECTION_SELL)
      return (entry_price > current_price);

   return false;
  }

//====================================================================
// تعیین اینکه قیمت از نظر جهت برای Stop مناسب است
//====================================================================
bool EntryPlan_IsValidStopPrice(const ENUM_SCENARIO_DIRECTION direction,
                                const double current_price,
                                const double entry_price)
  {
   if(current_price <= 0.0 || entry_price <= 0.0)
      return false;

   if(direction == SCENARIO_DIRECTION_BUY)
      return (entry_price > current_price);

   if(direction == SCENARIO_DIRECTION_SELL)
      return (entry_price < current_price);

   return false;
  }

//====================================================================
// انتخاب Market
//====================================================================
bool EntryPlan_CanUseMarket(const TradingScenario &scenario,
                            const SetupState &setup,
                            const double current_price,
                            string &reject_reason)
  {
   reject_reason = "";
   
   if(!Inp_Allow_Market_Entry)
     {
      reject_reason = "Market Entry در تنظیمات غیرفعال است";
      return false;
     }

   if(!Scenario_IsValid(scenario))
     {
      reject_reason = "سناریو معتبر نیست";
      return false;
     }

   if(!Setup_IsReadyForEntry(setup))
     {
      reject_reason = "Setup آماده ورود نیست";
      return false;
     }

   if(current_price <= 0.0)
     {
      reject_reason = "قیمت جاری معتبر نیست";
      return false;
     }

   if(!Setup_IsTriggered(setup))
     {
      reject_reason = "Setup هنوز Trigger نشده است";
      return false;
     }

   return true;
  }

//====================================================================
// انتخاب Limit
//====================================================================
bool EntryPlan_CanUseLimit(const TradingScenario &scenario,
                           const SetupState &setup,
                           const double current_price,
                           string &reject_reason)
  {
   reject_reason = "";
   
   if(!Inp_Allow_Limit_Entry || !Inp_AllowPendingOrders)
     {
      reject_reason = "Limit Entry یا Pending Orders غیرفعال است";
      return false;
     }

   if(!Scenario_IsValid(scenario))
     {
      reject_reason = "سناریو معتبر نیست";
      return false;
     }

   if(current_price <= 0.0 || scenario.entry_price <= 0.0)
     {
      reject_reason = "قیمت جاری یا قیمت ورود معتبر نیست";
      return false;
     }

   if(setup.state == SETUP_STATE_INVALID ||
      setup.state == SETUP_STATE_EXPIRED)
     {
      reject_reason = "Setup باطل یا منقضی شده است";
      return false;
     }

   if(scenario.direction == SCENARIO_DIRECTION_BUY ||
      scenario.direction == SCENARIO_DIRECTION_SELL)
     {
      if(!EntryPlan_IsValidLimitPrice(scenario.direction, current_price, scenario.entry_price))
        {
         reject_reason = "قیمت Limit برای جهت سناریو مناسب نیست";
         return false;
        }
     }
   else
     {
      reject_reason = "جهت سناریو نامعتبر است";
      return false;
     }

   return true;
  }

//====================================================================
// انتخاب Stop
//====================================================================
bool EntryPlan_CanUseStop(const TradingScenario &scenario,
                          const SetupState &setup,
                          const double current_price,
                          string &reject_reason)
  {
   reject_reason = "";
   
   if(!Inp_Allow_Stop_Entry || !Inp_AllowPendingOrders)
     {
      reject_reason = "Stop Entry یا Pending Orders غیرفعال است";
      return false;
     }

   if(!Scenario_IsValid(scenario))
     {
      reject_reason = "سناریو معتبر نیست";
      return false;
     }

   if(current_price <= 0.0 || scenario.entry_price <= 0.0)
     {
      reject_reason = "قیمت جاری یا قیمت ورود معتبر نیست";
      return false;
     }

   if(setup.state == SETUP_STATE_INVALID ||
      setup.state == SETUP_STATE_EXPIRED)
     {
      reject_reason = "Setup باطل یا منقضی شده است";
      return false;
     }

   if(!EntryPlan_IsValidStopPrice(scenario.direction, current_price, scenario.entry_price))
     {
      reject_reason = "قیمت Stop برای جهت سناریو مناسب نیست";
      return false;
     }

   return true;
  }

//====================================================================
// ساخت برنامه ورود
// [اصلاح] افزودن لاگ تشخیصی برای فهمیدن دلیل رد شدن هر روش
//====================================================================
bool EntryPlan_Build(const TradingScenario &scenario,
                     const SetupState &setup,
                     const double current_price,
                     const datetime current_time,
                     EntryPlan &plan)
  {
   EntryPlan_Init(plan);

   plan.scenario_id        = scenario.id;
   plan.direction          = scenario.direction;
   plan.symbol             = scenario.symbol;
   plan.current_price      = current_price;
   plan.entry_price        = scenario.entry_price;
   plan.zone_lower         = scenario.zone_lower;
   plan.zone_upper         = scenario.zone_upper;
   plan.invalidation_price = scenario.invalidation_price;
   plan.created_time       = current_time;
   plan.expiry_time        = scenario.expiry_time;
   plan.pending_allowed    = (Inp_AllowPendingOrders && Inp_Allow_Limit_Entry && Inp_Allow_Stop_Entry);
   plan.executable         = false;
   plan.entry_reachable    = true;  // [اصلاح] فرض می‌کنیم قابل دسترسی است
   plan.status             = ENTRY_PLAN_STATUS_PLANNED;

   if(!Scenario_IsValid(scenario))
     {
      plan.type   = ENTRY_PLAN_INVALID;
      plan.status = ENTRY_PLAN_STATUS_INVALID;
      plan.reason = "سناریو برای برنامه‌ریزی ورود معتبر نیست";
      plan.entry_reachable = false;
      return false;
     }

   if(setup.state == SETUP_STATE_INVALID)
     {
      plan.type   = ENTRY_PLAN_INVALID;
      plan.status = ENTRY_PLAN_STATUS_INVALID;
      plan.reason = "Setup باطل شده است";
      plan.entry_reachable = false;
      return false;
     }

   if(setup.state == SETUP_STATE_EXPIRED)
     {
      plan.type   = ENTRY_PLAN_EXPIRED;
      plan.status = ENTRY_PLAN_STATUS_EXPIRED;
      plan.reason = "Setup منقضی شده است";
      plan.entry_reachable = false;
      return false;
     }

   if(current_price <= 0.0)
     {
      plan.type   = ENTRY_PLAN_NO_ENTRY;
      plan.reason = "قیمت جاری معتبر نیست";
      plan.entry_reachable = false;
      return false;
     }

   if(scenario.entry_price <= 0.0)
     {
      plan.type   = ENTRY_PLAN_WAIT;
      plan.reason = "قیمت ورود هنوز مشخص نشده است";
      plan.entry_reachable = false;
      return true;
     }

   //--- [جدید] لاگ تشخیصی برای ردیابی تصمیم‌گیری
   string market_reason = "";
   string limit_reason = "";
   string stop_reason = "";

   // در حالت AUTO، اولویت با Market در صورت Trigger شدن Setup است.
   if(Inp_Entry_Preference == ENTRY_AUTO)
     {
      if(EntryPlan_CanUseMarket(scenario, setup, current_price, market_reason))
        {
         plan.type        = ENTRY_PLAN_MARKET;
         plan.status      = ENTRY_PLAN_STATUS_READY;
         plan.executable  = true;
         plan.entry_price = current_price;
         plan.entry_reachable = true;
         plan.reason      = "شرط فعال‌سازی برقرار است؛ ورود لحظه‌ای مجاز است";
         return true;
        }

      if(EntryPlan_CanUseLimit(scenario, setup, current_price, limit_reason))
        {
         plan.type        = ENTRY_PLAN_LIMIT;
         plan.status      = ENTRY_PLAN_STATUS_READY;
         plan.executable  = true;
         plan.entry_reachable = true;
         plan.reason      = "سناریو معتبر است و قیمت ورود در قالب Limit قابل برنامه‌ریزی است";
         return true;
        }

      if(EntryPlan_CanUseStop(scenario, setup, current_price, stop_reason))
        {
         plan.type        = ENTRY_PLAN_STOP;
         plan.status      = ENTRY_PLAN_STATUS_READY;
         plan.executable  = true;
         plan.entry_reachable = true;
         plan.reason      = "سناریو معتبر است و قیمت ورود در قالب Stop قابل برنامه‌ریزی است";
         return true;
        }

      plan.type   = ENTRY_PLAN_WAIT;
      plan.entry_reachable = false;
      plan.reason = "هنوز روش ورود معتبر و قابل اجرا وجود ندارد | " +
                    "Market=" + market_reason + " | Limit=" + limit_reason + " | Stop=" + stop_reason;
      return true;
     }

   if(Inp_Entry_Preference == ENTRY_MARKET)
     {
      if(EntryPlan_CanUseMarket(scenario, setup, current_price, market_reason))
        {
         plan.type       = ENTRY_PLAN_MARKET;
         plan.status     = ENTRY_PLAN_STATUS_READY;
         plan.executable = true;
         plan.entry_reachable = true;
         plan.entry_price= current_price;
         plan.reason     = "ورود Market طبق تنظیمات مجاز است";
         return true;
        }

      plan.type   = ENTRY_PLAN_WAIT;
      plan.entry_reachable = false;
      plan.reason = "شرایط ورود Market هنوز برقرار نیست | " + market_reason;
      return true;
     }

   if(Inp_Entry_Preference == ENTRY_LIMIT)
     {
      if(EntryPlan_CanUseLimit(scenario, setup, current_price, limit_reason))
        {
         plan.type       = ENTRY_PLAN_LIMIT;
         plan.status     = ENTRY_PLAN_STATUS_READY;
         plan.executable = true;
         plan.entry_reachable = true;
         plan.reason     = "سفارش Limit طبق تنظیمات قابل برنامه‌ریزی است";
         return true;
        }

      plan.type   = ENTRY_PLAN_WAIT;
      plan.entry_reachable = false;
      plan.reason = "قیمت یا شرایط لازم برای Limit برقرار نیست | " + limit_reason;
      return true;
     }

   if(Inp_Entry_Preference == ENTRY_STOP)
     {
      if(EntryPlan_CanUseStop(scenario, setup, current_price, stop_reason))
        {
         plan.type       = ENTRY_PLAN_STOP;
         plan.status     = ENTRY_PLAN_STATUS_READY;
         plan.executable = true;
         plan.entry_reachable = true;
         plan.reason     = "سفارش Stop طبق تنظیمات قابل برنامه‌ریزی است";
         return true;
        }

      plan.type   = ENTRY_PLAN_WAIT;
      plan.entry_reachable = false;
      plan.reason = "قیمت یا شرایط لازم برای Stop برقرار نیست | " + stop_reason;
      return true;
     }

   plan.type   = ENTRY_PLAN_NO_ENTRY;
   plan.entry_reachable = false;
   plan.reason = "روش ورود معتبر مشخص نشد";
   return false;
  }

//====================================================================
// ثبت ارسال برنامه
//====================================================================
bool EntryPlan_MarkSent(EntryPlan &plan)
  {
   if(!plan.executable)
      return false;

   if(plan.status != ENTRY_PLAN_STATUS_READY)
      return false;

   plan.status = ENTRY_PLAN_STATUS_SENT;
   return true;
  }

//====================================================================
// ثبت اجرای واقعی
//====================================================================
bool EntryPlan_MarkFilled(EntryPlan &plan)
  {
   if(plan.status != ENTRY_PLAN_STATUS_SENT &&
      plan.status != ENTRY_PLAN_STATUS_READY)
      return false;

   plan.status = ENTRY_PLAN_STATUS_FILLED;
   return true;
  }

//====================================================================
// لغو برنامه
//====================================================================
bool EntryPlan_Cancel(EntryPlan &plan,
                      const string reason)
  {
   plan.status = ENTRY_PLAN_STATUS_CANCELLED;
   plan.executable = false;
   plan.entry_reachable = false;
   plan.reason = reason;
   return true;
  }

//====================================================================
// انقضای برنامه
//====================================================================
bool EntryPlan_Expire(EntryPlan &plan,
                      const string reason)
  {
   plan.status = ENTRY_PLAN_STATUS_EXPIRED;
   plan.type = ENTRY_PLAN_EXPIRED;
   plan.executable = false;
   plan.entry_reachable = false;
   plan.reason = reason;
   return true;
  }

//====================================================================
// تبدیل برنامه ورود به متن فارسی
//====================================================================
string EntryPlan_ToText(const EntryPlan &plan)
  {
   string text = "";

   text += "شناسه سناریو: " + (string)plan.scenario_id;
   text += " | نماد: " + plan.symbol;
   text += " | جهت: " + ScenarioDirectionToPersian(plan.direction);
   text += " | روش: " + EntryPlanTypeToPersian(plan.type);
   text += " | وضعیت: " + EntryPlanStatusToPersian(plan.status);
   text += " | قیمت جاری: " + DoubleToString(plan.current_price, _Digits);
   text += " | قیمت ورود: " + DoubleToString(plan.entry_price, _Digits);
   text += " | ابطال: " + DoubleToString(plan.invalidation_price, _Digits);
   text += " | قابل دسترسی: " + (plan.entry_reachable ? "بله" : "خیر");

   if(plan.reason != "")
      text += " | دلیل: " + plan.reason;

   return text;
  }

//+------------------------------------------------------------------+