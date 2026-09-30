#ifndef __TFLAB_TARGET_ENGINE_MQH__
#define __TFLAB_TARGET_ENGINE_MQH__

//+------------------------------------------------------------------+
//|                         Target_Engine.mqh                        |
//|                         TFlab New EA V.5                             |
//|                                                                  |
//| مسئولیت: شناسایی و مدیریت اهداف قیمتی سناریو                    |
//| بدون اجرای سفارش، مدیریت ریسک، SL یا TP اجرایی                  |
//|                                                                  |
//| v2.1 - لاگ تشخیصی + حفظ وضعیت VALID + حداقل فاصله ATR         |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// نوع هدف
// هدف فقط یک مقصد تحلیلی است؛ نحوه خروج اجرایی در TP/Trade Manager است.
//====================================================================
enum ENUM_TARGET_TYPE
  {
   TARGET_TYPE_NONE = 0,
   TARGET_TYPE_STRUCTURE,
   TARGET_TYPE_LIQUIDITY,
   TARGET_TYPE_ZONE,
   TARGET_TYPE_EXPANSION
  };

//====================================================================
// وضعیت هدف
//====================================================================
enum ENUM_TARGET_STATUS
  {
   TARGET_STATUS_UNKNOWN = 0,
   TARGET_STATUS_CANDIDATE,
   TARGET_STATUS_VALID,
   TARGET_STATUS_BLOCKED,
   TARGET_STATUS_REACHED,
   TARGET_STATUS_INVALID,
   TARGET_STATUS_EXPIRED
  };

//====================================================================
// اولویت هدف
//====================================================================
enum ENUM_TARGET_PRIORITY
  {
   TARGET_PRIORITY_NONE = 0,
   TARGET_PRIORITY_CONSERVATIVE,
   TARGET_PRIORITY_PRIMARY,
   TARGET_PRIORITY_EXTENDED
  };

//====================================================================
// اطلاعات هدف
//====================================================================
struct TargetInfo
  {
   ulong                  id;
   ENUM_TARGET_TYPE       type;
   ENUM_TARGET_STATUS     status;
   ENUM_TARGET_PRIORITY   priority;

   double                 price;
   double                 zone_low;
   double                 zone_high;
   double                 distance_from_entry;

   datetime               created_time;
   datetime               updated_time;
   datetime               expiration_time;

   double                 strength;
   string                 source;
   string                 reason;
  };

//------------------------------------------------------------------
// متن فارسی نوع هدف
//------------------------------------------------------------------
string TargetTypeToPersian(const ENUM_TARGET_TYPE type)
  {
   switch(type)
     {
      case TARGET_TYPE_STRUCTURE:  return "ساختاری";
      case TARGET_TYPE_LIQUIDITY:  return "نقدینگی";
      case TARGET_TYPE_ZONE:       return "ناحیه";
      case TARGET_TYPE_EXPANSION:  return "توسعه‌ای";
      default:                     return "نامشخص";
     }
  }

//------------------------------------------------------------------
// متن فارسی وضعیت هدف
//------------------------------------------------------------------
string TargetStatusToPersian(const ENUM_TARGET_STATUS status)
  {
   switch(status)
     {
      case TARGET_STATUS_CANDIDATE: return "کاندیدا";
      case TARGET_STATUS_VALID:     return "معتبر";
      case TARGET_STATUS_BLOCKED:   return "مسدود";
      case TARGET_STATUS_REACHED:   return "دستیابی‌شده";
      case TARGET_STATUS_INVALID:   return "باطل";
      case TARGET_STATUS_EXPIRED:   return "منقضی";
      default:                      return "نامشخص";
     }
  }

//------------------------------------------------------------------
// کد انگلیسی وضعیت هدف برای لاگ
//------------------------------------------------------------------
string TargetStatusToCode(const ENUM_TARGET_STATUS status)
  {
   switch(status)
     {
      case TARGET_STATUS_CANDIDATE: return "CANDIDATE";
      case TARGET_STATUS_VALID:     return "VALID";
      case TARGET_STATUS_BLOCKED:   return "BLOCKED";
      case TARGET_STATUS_REACHED:   return "REACHED";
      case TARGET_STATUS_INVALID:   return "INVALID";
      case TARGET_STATUS_EXPIRED:   return "EXPIRED";
      default:                      return "UNKNOWN";
     }
  }

//------------------------------------------------------------------
// متن فارسی اولویت هدف
//------------------------------------------------------------------
string TargetPriorityToPersian(const ENUM_TARGET_PRIORITY priority)
  {
   switch(priority)
     {
      case TARGET_PRIORITY_CONSERVATIVE: return "محافظه‌کارانه";
      case TARGET_PRIORITY_PRIMARY:      return "اصلی";
      case TARGET_PRIORITY_EXTENDED:     return "گسترش‌یافته";
      default:                           return "بدون اولویت";
     }
  }

//------------------------------------------------------------------
// مقداردهی اولیه
//------------------------------------------------------------------
void Target_Init(TargetInfo &target)
  {
   target.id                   = 0;
   target.type                 = TARGET_TYPE_NONE;
   target.status               = TARGET_STATUS_UNKNOWN;
   target.priority             = TARGET_PRIORITY_NONE;

   target.price                = 0.0;
   target.zone_low             = 0.0;
   target.zone_high            = 0.0;
   target.distance_from_entry  = 0.0;

   target.created_time         = 0;
   target.updated_time         = 0;
   target.expiration_time      = 0;

   target.strength             = 0.0;
   target.source               = "";
   target.reason               = "";
  }

//------------------------------------------------------------------
// اعتبارسنجی پایه هدف
//------------------------------------------------------------------
bool Target_IsValid(const TargetInfo &target)
  {
   if(target.type == TARGET_TYPE_NONE)
      return false;

   if(target.price <= 0.0)
      return false;

   if(target.priority == TARGET_PRIORITY_NONE)
      return false;

   //--- [اصلاح] وضعیت INVALID, BLOCKED, EXPIRED معتبر نیستند
   if(target.status == TARGET_STATUS_INVALID ||
      target.status == TARGET_STATUS_BLOCKED ||
      target.status == TARGET_STATUS_EXPIRED)
      return false;

   return true;
  }

//------------------------------------------------------------------
// بررسی اعتبار بازه هدف Zone
//------------------------------------------------------------------
bool Target_HasValidZone(const TargetInfo &target)
  {
   return (target.zone_low > 0.0 &&
           target.zone_high > 0.0 &&
           target.zone_high >= target.zone_low);
  }

//------------------------------------------------------------------
// ایجاد هدف
//------------------------------------------------------------------
bool Target_Create(const ulong id,
                   const ENUM_TARGET_TYPE type,
                   const ENUM_TARGET_PRIORITY priority,
                   const double price,
                   const double zone_low,
                   const double zone_high,
                   const datetime created_time,
                   const datetime expiration_time,
                   const double strength,
                   const string source,
                   const string reason,
                   TargetInfo &target)
  {
   Target_Init(target);

   if(id == 0 || type == TARGET_TYPE_NONE || priority == TARGET_PRIORITY_NONE)
     {
      Print(
         "[TARGET ENGINE] CREATE FAIL",
         " | ID=", id,
         " | Type=", TargetTypeToPersian(type),
         " | Priority=", TargetPriorityToPersian(priority),
         " | Price=", DoubleToString(price, _Digits)
      );
      return false;
     }

   if(price <= 0.0)
     {
      Print("[TARGET ENGINE] CREATE FAIL | قیمت نامعتبر | Price=", DoubleToString(price, _Digits));
      return false;
     }

   if((zone_low > 0.0 || zone_high > 0.0) && zone_high < zone_low)
     {
      Print(
         "[TARGET ENGINE] CREATE FAIL | Zone نامعتبر",
         " | Low=", DoubleToString(zone_low, _Digits),
         " | High=", DoubleToString(zone_high, _Digits)
      );
      return false;
     }

   target.id              = id;
   target.type            = type;
   target.status          = TARGET_STATUS_CANDIDATE;
   target.priority        = priority;
   target.price           = price;
   target.zone_low        = zone_low;
   target.zone_high       = zone_high;
   target.created_time    = created_time;
   target.updated_time    = created_time;
   target.expiration_time = expiration_time;
   target.strength        = strength;
   target.source          = source;
   target.reason          = reason;

   Print(
      "[TARGET ENGINE] CREATED",
      " | ID=", id,
      " | Type=", TargetTypeToPersian(type),
      " | Priority=", TargetPriorityToPersian(priority),
      " | Price=", DoubleToString(price, _Digits),
      " | Strength=", DoubleToString(strength, 2),
      " | Source=", source
   );

   return true;
  }

//------------------------------------------------------------------
// محاسبه فاصله هدف از Entry
//------------------------------------------------------------------
double Target_CalculateDistance(const ENUM_ORDER_TYPE direction,
                                const double entry_price,
                                const double target_price)
  {
   if(entry_price <= 0.0 || target_price <= 0.0)
      return 0.0;

   if(direction == ORDER_TYPE_BUY || direction == ORDER_TYPE_BUY_LIMIT || direction == ORDER_TYPE_BUY_STOP)
      return target_price - entry_price;

   if(direction == ORDER_TYPE_SELL || direction == ORDER_TYPE_SELL_LIMIT || direction == ORDER_TYPE_SELL_STOP)
      return entry_price - target_price;

   return 0.0;
  }

//------------------------------------------------------------------
// بررسی اینکه هدف در جهت درست معامله قرار دارد
//------------------------------------------------------------------
bool Target_IsDirectionallyValid(const ENUM_ORDER_TYPE direction,
                                 const double entry_price,
                                 const double target_price)
  {
   const double distance = Target_CalculateDistance(direction, entry_price, target_price);

   return (distance > 0.0);
  }

//------------------------------------------------------------------
// ثبت فاصله هدف از Entry
// [اصلاح] افزودن بررسی حداقل فاصله
//------------------------------------------------------------------
bool Target_SetEntryDistance(TargetInfo &target,
                             const ENUM_ORDER_TYPE direction,
                             const double entry_price,
                             const double min_distance_points = 0.0)
  {
   if(!Target_IsValid(target))
      return false;

   target.distance_from_entry =
      Target_CalculateDistance(direction, entry_price, target.price);

   if(target.distance_from_entry <= 0.0)
     {
      target.status = TARGET_STATUS_INVALID;
      target.reason = "هدف در سمت صحیح معامله قرار ندارد";
      Print(
         "[TARGET ENGINE] INVALID | Direction mismatch",
         " | ID=", target.id,
         " | Entry=", DoubleToString(entry_price, _Digits),
         " | Target=", DoubleToString(target.price, _Digits),
         " | Direction=", (direction == ORDER_TYPE_BUY ? "BUY" : "SELL")
      );
      return false;
     }

   //--- [جدید] بررسی حداقل فاصله
   if(min_distance_points > 0.0)
     {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double min_distance_price = min_distance_points * point;

      if(target.distance_from_entry < min_distance_price)
        {
         target.status = TARGET_STATUS_INVALID;
         target.reason = "فاصله هدف از ورود کمتر از حداقل مجاز است | " +
                         "Distance=" + DoubleToString(target.distance_from_entry / point, 1) +
                         " pts | MinRequired=" + DoubleToString(min_distance_points, 1) + " pts";
         Print(
            "[TARGET ENGINE] INVALID | Too close to entry",
            " | ID=", target.id,
            " | Distance=", DoubleToString(target.distance_from_entry / point, 1), " pts",
            " | MinRequired=", DoubleToString(min_distance_points, 1), " pts"
         );
         return false;
        }
     }

   return true;
  }

//------------------------------------------------------------------
// بررسی عبور قیمت از هدف
//------------------------------------------------------------------
bool Target_IsReached(const ENUM_ORDER_TYPE direction,
                      const double current_price,
                      const double target_price)
  {
   if(current_price <= 0.0 || target_price <= 0.0)
      return false;

   if(direction == ORDER_TYPE_BUY || direction == ORDER_TYPE_BUY_LIMIT || direction == ORDER_TYPE_BUY_STOP)
      return current_price >= target_price;

   if(direction == ORDER_TYPE_SELL || direction == ORDER_TYPE_SELL_LIMIT || direction == ORDER_TYPE_SELL_STOP)
      return current_price <= target_price;

   return false;
  }

//------------------------------------------------------------------
// اعمال وضعیت دستیابی به هدف
// [اصلاح] افزودن لاگ
//------------------------------------------------------------------
bool Target_ApplyReached(TargetInfo &target,
                         const datetime current_time)
  {
   if(!Target_IsValid(target))
      return false;

   //--- اگر قبلاً REACHED است، دوباره لاگ نزن
   if(target.status == TARGET_STATUS_REACHED)
      return true;

   target.status = TARGET_STATUS_REACHED;
   target.updated_time = current_time;

   Print(
      "[TARGET ENGINE] REACHED",
      " | ID=", target.id,
      " | Type=", TargetTypeToPersian(target.type),
      " | Price=", DoubleToString(target.price, _Digits),
      " | Priority=", TargetPriorityToPersian(target.priority)
   );

   return true;
  }

//------------------------------------------------------------------
// بررسی انقضای زمانی هدف
//------------------------------------------------------------------
bool Target_IsExpiredByTime(const TargetInfo &target,
                            const datetime current_time)
  {
   if(target.expiration_time <= 0)
      return false;

   return (current_time >= target.expiration_time);
  }

//------------------------------------------------------------------
// به‌روزرسانی وضعیت زمانی هدف
// [اصلاح] حفظ وضعیت VALID و REACHED
//------------------------------------------------------------------
bool Target_UpdateStatus(TargetInfo &target,
                         const datetime current_time)
  {
   //--- [اصلاح] وضعیت‌های نهایی تغییر نمی‌کنند
   if(target.status == TARGET_STATUS_REACHED ||
      target.status == TARGET_STATUS_INVALID)
     {
      target.updated_time = current_time;
      return true;
     }

   if(Target_IsExpiredByTime(target, current_time))
     {
      target.status = TARGET_STATUS_EXPIRED;
      target.updated_time = current_time;
      Print(
         "[TARGET ENGINE] EXPIRED",
         " | ID=", target.id,
         " | Price=", DoubleToString(target.price, _Digits),
         " | Expiry=", TimeToString(target.expiration_time, TIME_DATE | TIME_MINUTES)
      );
      return true;
     }

   if(!Target_IsValid(target))
     {
      target.status = TARGET_STATUS_INVALID;
      target.updated_time = current_time;
      return false;
     }

   //--- [اصلاح] فقط اگر UNKNOWN باشد، به CANDIDATE تغییر می‌دهد
   if(target.status == TARGET_STATUS_UNKNOWN)
      target.status = TARGET_STATUS_CANDIDATE;

   //--- وضعیت VALID, BLOCKED, CANDIDATE حفظ می‌شوند
   target.updated_time = current_time;
   return true;
  }

//------------------------------------------------------------------
// مسدود کردن هدف به دلیل مانع مسیر
// [اصلاح] افزودن لاگ
//------------------------------------------------------------------
bool Target_MarkBlocked(TargetInfo &target,
                        const string &reason,
                        const datetime current_time)
  {
   if(!Target_IsValid(target) && target.status != TARGET_STATUS_CANDIDATE)
      return false;

   target.status = TARGET_STATUS_BLOCKED;
   target.reason = reason;
   target.updated_time = current_time;

   Print(
      "[TARGET ENGINE] BLOCKED",
      " | ID=", target.id,
      " | Price=", DoubleToString(target.price, _Digits),
      " | Reason=", reason
   );

   return true;
  }

//------------------------------------------------------------------
// معتبر کردن هدف
// [اصلاح] افزودن بررسی جهت + لاگ
//------------------------------------------------------------------
bool Target_MarkValid(TargetInfo &target,
                      const string &reason,
                      const datetime current_time,
                      const ENUM_ORDER_TYPE direction = ORDER_TYPE_BUY,
                      const double entry_price = 0.0)
  {
   if(target.price <= 0.0 || target.type == TARGET_TYPE_NONE)
      return false;

   //--- [جدید] بررسی جهت در صورت ارائه Entry
   if(entry_price > 0.0)
     {
      if(!Target_IsDirectionallyValid(direction, entry_price, target.price))
        {
         target.status = TARGET_STATUS_INVALID;
         target.reason = "هدف در جهت صحیح معامله نیست";
         Print(
            "[TARGET ENGINE] INVALID | Direction mismatch during MarkValid",
            " | ID=", target.id,
            " | Entry=", DoubleToString(entry_price, _Digits),
            " | Target=", DoubleToString(target.price, _Digits),
            " | Direction=", (direction == ORDER_TYPE_BUY ? "BUY" : "SELL")
         );
         return false;
        }
     }

   target.status = TARGET_STATUS_VALID;
   if(reason != "")
      target.reason = reason;
   target.updated_time = current_time;

   Print(
      "[TARGET ENGINE] VALID",
      " | ID=", target.id,
      " | Type=", TargetTypeToPersian(target.type),
      " | Price=", DoubleToString(target.price, _Digits),
      " | Priority=", TargetPriorityToPersian(target.priority),
      " | Reason=", (reason != "" ? reason : target.reason)
   );

   return true;
  }

//------------------------------------------------------------------
// باطل کردن هدف
// [اصلاح] افزودن لاگ
//------------------------------------------------------------------
bool Target_MarkInvalid(TargetInfo &target,
                        const string &reason,
                        const datetime current_time)
  {
   target.status = TARGET_STATUS_INVALID;
   if(reason != "")
      target.reason = reason;
   target.updated_time = current_time;

   Print(
      "[TARGET ENGINE] INVALIDATED",
      " | ID=", target.id,
      " | Price=", DoubleToString(target.price, _Digits),
      " | Reason=", (reason != "" ? reason : target.reason)
   );

   return true;
  }

//------------------------------------------------------------------
// مقایسه کیفیت دو هدف
//------------------------------------------------------------------
int Target_CompareStrength(const TargetInfo &first,
                           const TargetInfo &second)
  {
   if(first.strength > second.strength)
      return 1;

   if(first.strength < second.strength)
      return -1;

   return 0;
  }

//------------------------------------------------------------------
// تعیین اینکه هدف در سمت صحیح بازار است
//------------------------------------------------------------------
bool Target_ValidateDirection(const TargetInfo &target,
                              const ENUM_ORDER_TYPE direction,
                              const double entry_price)
  {
   if(!Target_IsValid(target))
      return false;

   return Target_IsDirectionallyValid(direction, entry_price, target.price);
  }

//------------------------------------------------------------------
// انتخاب قیمت هدف از Zone بر اساس جهت معامله
//------------------------------------------------------------------
bool Target_GetDirectionalZonePrice(const ENUM_ORDER_TYPE direction,
                                    const double entry_price,
                                    const double zone_low,
                                    const double zone_high,
                                    double &target_price)
  {
   target_price = 0.0;

   if(entry_price <= 0.0 || zone_low <= 0.0 || zone_high < zone_low)
      return false;

   if(direction == ORDER_TYPE_BUY ||
      direction == ORDER_TYPE_BUY_LIMIT ||
      direction == ORDER_TYPE_BUY_STOP)
     {
      if(zone_high > entry_price)
        {
         target_price = zone_high;
         return true;
        }

      return false;
     }

   if(direction == ORDER_TYPE_SELL ||
      direction == ORDER_TYPE_SELL_LIMIT ||
      direction == ORDER_TYPE_SELL_STOP)
     {
      if(zone_low < entry_price)
        {
         target_price = zone_low;
         return true;
        }

      return false;
     }

   return false;
  }

//------------------------------------------------------------------
// تولید متن گزارش فارسی
//------------------------------------------------------------------
string Target_ToText(const TargetInfo &target)
  {
   string text = "";

   text += "شناسه: " + (string)target.id;
   text += " | نوع: " + TargetTypeToPersian(target.type);
   text += " | وضعیت: " + TargetStatusToPersian(target.status);
   text += " | اولویت: " + TargetPriorityToPersian(target.priority);
   text += " | قیمت: " + DoubleToString(target.price, _Digits);

   if(Target_HasValidZone(target))
     {
      text += " | کف ناحیه: " + DoubleToString(target.zone_low, _Digits);
      text += " | سقف ناحیه: " + DoubleToString(target.zone_high, _Digits);
     }

   text += " | فاصله از ورود: " + DoubleToString(target.distance_from_entry, _Digits);
   text += " | قدرت: " + DoubleToString(target.strength, 2);

   if(target.source != "")
      text += " | منبع: " + target.source;

   if(target.reason != "")
      text += " | دلیل: " + target.reason;

   return text;
  }

//+------------------------------------------------------------------+

#endif // __TFLAB_TARGET_ENGINE_MQH__