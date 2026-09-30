#ifndef __TFLAB_SCENARIO_VIRTUAL_TESTER_MQH__
#define __TFLAB_SCENARIO_VIRTUAL_TESTER_MQH__

//+------------------------------------------------------------------+
//|                Scenario_VirtualTester.mqh                        |
//|                TFlab New EA V.5                                      |
//|                                                                  |
//| مسئولیت: ساختار پایه برای تست مجازی سناریوها                    |
//|                                                                  |
//| این فایل یک رابط (interface) است. منطق تست مجازی سناریوها       |
//| می‌تواند در آینده توسعه یابد.                                    |
//|                                                                  |
//| در حال حاضر فقط ساختار و لاگ‌های پایه را فراهم می‌کند.           |
//+------------------------------------------------------------------+
#property strict

#include "Scenario_Engine.mqh"

//====================================================================
// وضعیت تستر مجازی سناریو
//====================================================================
struct ScenarioVirtualTesterState
  {
   bool      initialized;
   int       registered_count;
   int       update_count;
   datetime  last_register_time;
   datetime  last_update_time;
   ulong     last_registered_scenario_id;
  };

//====================================================================
// متغیر سراسری وضعیت
//====================================================================
ScenarioVirtualTesterState g_svt_state;

//====================================================================
// مقداردهی اولیه تستر مجازی
//====================================================================
bool ScenarioVirtualTester_Init()
  {
   g_svt_state.initialized               = true;
   g_svt_state.registered_count          = 0;
   g_svt_state.update_count              = 0;
   g_svt_state.last_register_time        = 0;
   g_svt_state.last_update_time          = 0;
   g_svt_state.last_registered_scenario_id = 0;
   
   return true;
  }

//====================================================================
// ثبت خودکار سناریو برای تست مجازی
// [اصلاح] افزودن لاگ تشخیصی + شمارنده
//====================================================================
bool ScenarioVirtualTester_AutoRegister(
   const TradingScenario &s,
   const double bid,
   const double ask)
  {
   if(!g_svt_state.initialized)
      return false;
   
   //--- بررسی اولیه سناریو
   if(s.id == 0 || !Scenario_IsValid(s))
      return false;
   
   //--- [جدید] شمارش و لاگ
   g_svt_state.registered_count++;
   g_svt_state.last_register_time = TimeCurrent();
   g_svt_state.last_registered_scenario_id = s.id;
   
   Print(
      "[SCENARIO VIRTUAL TESTER] REGISTERED",
      " | ScenarioID=", s.id,
      " | Direction=", ScenarioDirectionToPersian(s.direction),
      " | Bid=", DoubleToString(bid, _Digits),
      " | Ask=", DoubleToString(ask, _Digits),
      " | Count=", g_svt_state.registered_count
   );
   
   //--- در آینده می‌توان منطق تست مجازی را اینجا اضافه کرد
   //--- برای مثال: ذخیره سناریو در یک آرایه، شبیه‌سازی قیمت، و غیره
   
   return true;
  }

//====================================================================
// به‌روزرسانی تستر مجازی در هر تیک/تایمر
// [اصلاح] افزودن شمارنده
//====================================================================
void ScenarioVirtualTester_Update(
   const double bid,
   const double ask,
   const datetime now)
  {
   if(!g_svt_state.initialized)
      return;
   
   g_svt_state.update_count++;
   g_svt_state.last_update_time = now;
   
   //--- در آینده می‌توان منطق به‌روزرسانی تست مجازی را اینجا اضافه کرد
   //--- برای مثال: بررسی اینکه آیا سناریوها به اهداف خود رسیده‌اند یا نه
  }

//====================================================================
// [جدید] دریافت تعداد سناریوهای ثبت‌شده
//====================================================================
int ScenarioVirtualTester_GetRegisteredCount()
  {
   return g_svt_state.registered_count;
  }

//====================================================================
// [جدید] دریافت تعداد به‌روزرسانی‌ها
//====================================================================
int ScenarioVirtualTester_GetUpdateCount()
  {
   return g_svt_state.update_count;
  }

//====================================================================
// [جدید] دریافت وضعیت تستر به صورت متن
//====================================================================
string ScenarioVirtualTester_StatusText()
  {
   if(!g_svt_state.initialized)
      return "تستر مجازی غیرفعال";
   
   string text = "تستر مجازی فعال";
   text += " | ثبت‌شده: " + IntegerToString(g_svt_state.registered_count);
   text += " | به‌روزرسانی: " + IntegerToString(g_svt_state.update_count);
   
   if(g_svt_state.last_registered_scenario_id > 0)
      text += " | آخرین سناریو: " + (string)g_svt_state.last_registered_scenario_id;
   
   return text;
  }

//====================================================================
// [جدید] بررسی فعال بودن تستر
//====================================================================
bool ScenarioVirtualTester_IsInitialized()
  {
   return g_svt_state.initialized;
  }

#endif // __TFLAB_SCENARIO_VIRTUAL_TESTER_MQH__