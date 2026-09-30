#ifndef __TFLAB_TP_ENGINE_MQH__
#define __TFLAB_TP_ENGINE_MQH__

//+------------------------------------------------------------------+
//|                         TP_Engine.mqh                            |
//|                         TFlab New EA V.5                             |
//|                                                                  |
//| مسئولیت: تعیین، اعتبارسنجی و پایش اهداف قیمتی                   |
//|                                                                  |
//| این فایل فقط مسئول TP است.                                      |
//| منطق ورود، Invalidation، SL، Risk و Execution در فایل‌های دیگر  |
//| قرار دارد.                                                       |
//|                                                                  |
//| v2.1 - بهبود SelectPrimary + Min Distance + لاگ تشخیصی         |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// نوع هدف
//====================================================================
enum ENUM_TP_TARGET_TYPE
  {
   TP_TARGET_NONE = 0,
   TP_TARGET_STRUCTURE,
   TP_TARGET_LIQUIDITY,
   TP_TARGET_ZONE,
   TP_TARGET_EXPANSION,
   TP_TARGET_CUSTOM
  };

//====================================================================
// وضعیت هدف
//====================================================================
enum ENUM_TP_STATUS
  {
   TP_STATUS_UNKNOWN = 0,
   TP_STATUS_CANDIDATE,
   TP_STATUS_VALID,
   TP_STATUS_REACHED,
   TP_STATUS_BLOCKED,
   TP_STATUS_INVALID
  };

//====================================================================
// ساختار یک هدف
//====================================================================
struct TP_Target
  {
   int                  level;
   ENUM_TP_TARGET_TYPE  type;
   ENUM_TP_STATUS       status;

   double               price;
   double               strength;

   string               reason;
   string               source;
  };

//====================================================================
// نتیجه موتور TP
//====================================================================
struct TP_Result
  {
   bool        valid;

   double      conservative_target;
   double      primary_target;
   double      extended_target;

   TP_Target  t1;
   TP_Target  t2;
   TP_Target  t3;

   string      reason;
  };

//====================================================================
// تبدیل نوع هدف به فارسی
//====================================================================
string TP_TargetTypeToPersian(const ENUM_TP_TARGET_TYPE type)
  {
   switch(type)
     {
      case TP_TARGET_STRUCTURE:  return "ساختاری";
      case TP_TARGET_LIQUIDITY:  return "نقدینگی";
      case TP_TARGET_ZONE:       return "ناحیه‌ای";
      case TP_TARGET_EXPANSION:  return "گسترشی";
      case TP_TARGET_CUSTOM:     return "اختصاصی";
      default:                   return "نامشخص";
     }
  }

//====================================================================
// تبدیل وضعیت هدف به فارسی
//====================================================================
string TP_StatusToPersian(const ENUM_TP_STATUS status)
  {
   switch(status)
     {
      case TP_STATUS_CANDIDATE: return "کاندیدا";
      case TP_STATUS_VALID:     return "معتبر";
      case TP_STATUS_REACHED:   return "تحقق یافته";
      case TP_STATUS_BLOCKED:   return "مسدود";
      case TP_STATUS_INVALID:   return "باطل";
      default:                  return "نامشخص";
     }
  }

//====================================================================
// مقداردهی اولیه Target
//====================================================================
void TP_TargetInit(TP_Target &target)
  {
   target.level    = 0;
   target.type     = TP_TARGET_NONE;
   target.status   = TP_STATUS_UNKNOWN;
   target.price    = 0.0;
   target.strength = 0.0;
   target.reason   = "";
   target.source   = "";
  }

//====================================================================
// مقداردهی اولیه نتیجه
//====================================================================
void TP_Init(TP_Result &result)
  {
   result.valid               = false;
   result.conservative_target = 0.0;
   result.primary_target      = 0.0;
   result.extended_target     = 0.0;
   result.reason              = "";

   TP_TargetInit(result.t1);
   TP_TargetInit(result.t2);
   TP_TargetInit(result.t3);
  }

//====================================================================
// بررسی پایه Target
//====================================================================
bool TP_IsTargetValid(const TP_Target &target)
  {
   if(target.type == TP_TARGET_NONE)
      return false;

   if(target.price <= 0.0)
      return false;

   if(target.status == TP_STATUS_INVALID ||
      target.status == TP_STATUS_BLOCKED)
      return false;

   return true;
  }

//====================================================================
// بررسی جهت صحیح Target نسبت به Entry
//====================================================================
bool TP_IsDirectionValid(const bool is_buy,
                         const double entry_price,
                         const double target_price)
  {
   if(entry_price <= 0.0 || target_price <= 0.0)
      return false;

   if(is_buy)
      return (target_price > entry_price);

   return (target_price < entry_price);
  }

//====================================================================
// فاصله مثبت Entry تا Target
//====================================================================
double TP_Distance(const bool is_buy,
                   const double entry_price,
                   const double target_price)
  {
   if(entry_price <= 0.0 || target_price <= 0.0)
      return 0.0;

   if(is_buy)
      return (target_price - entry_price);

   return (entry_price - target_price);
  }

//====================================================================
// محاسبه R/R
// [اصلاح] بررسی جهت صحیح SL
//====================================================================
double TP_CalculateRR(const bool is_buy,
                      const double entry_price,
                      const double sl_price,
                      const double target_price)
  {
   //--- [اصلاح] بررسی جهت SL
   if(is_buy)
     {
      if(sl_price >= entry_price)
         return 0.0;  // SL باید زیر entry باشد
     }
   else
     {
      if(sl_price <= entry_price)
         return 0.0;  // SL باید بالای entry باشد
     }

   double risk_distance   = MathAbs(entry_price - sl_price);
   double reward_distance = MathAbs(target_price - entry_price);

   if(risk_distance <= 0.0 || reward_distance <= 0.0)
      return 0.0;

   return (reward_distance / risk_distance);
  }

//====================================================================
// ساخت Target
// [اصلاح] بررسی strength >= 0
//====================================================================
bool TP_CreateTarget(const int level,
                     const ENUM_TP_TARGET_TYPE type,
                     const ENUM_TP_STATUS status,
                     const double price,
                     const double strength,
                     const string reason,
                     const string source,
                     TP_Target &target)
  {
   TP_TargetInit(target);

   if(level < 1 || level > 3)
      return false;

   if(type == TP_TARGET_NONE)
      return false;

   if(price <= 0.0)
      return false;

   //--- [اصلاح] strength نباید منفی باشد
   if(strength < 0.0)
      return false;

   target.level    = level;
   target.type     = type;
   target.status   = status;
   target.price    = price;
   target.strength = strength;
   target.reason   = reason;
   target.source   = source;

   return true;
  }

//====================================================================
// قرار دادن Target در نتیجه
//====================================================================
bool TP_SetTarget(TP_Result &result,
                  const int level,
                  const TP_Target &target)
  {
   if(!TP_IsTargetValid(target))
      return false;

   switch(level)
     {
      case 1:
         result.t1 = target;
         return true;

      case 2:
         result.t2 = target;
         return true;

      case 3:
         result.t3 = target;
         return true;
     }

   return false;
  }

//====================================================================
// اعتبارسنجی Targetها نسبت به Entry
// [اصلاح] افزودن بررسی حداقل فاصله + لاگ تشخیصی
//====================================================================
bool TP_ValidateTargets(const bool is_buy,
                        const double entry_price,
                        TP_Result &result,
                        const double min_distance_points = 0.0)
  {
   bool has_valid_target = false;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double min_distance_price = min_distance_points * point;

   //--- بررسی T1
   if(TP_IsTargetValid(result.t1))
     {
      if(!TP_IsDirectionValid(is_buy, entry_price, result.t1.price))
        {
         result.t1.status = TP_STATUS_INVALID;
         result.t1.reason = "جهت هدف با جهت معامله هم‌خوانی ندارد";
        }
      else if(min_distance_price > 0.0 &&
              TP_Distance(is_buy, entry_price, result.t1.price) < min_distance_price)
        {
         result.t1.status = TP_STATUS_INVALID;
         result.t1.reason = "فاصله هدف از ورود کمتر از حداقل مجاز است";
        }
      else
        {
         has_valid_target = true;
        }
     }

   //--- بررسی T2
   if(TP_IsTargetValid(result.t2))
     {
      if(!TP_IsDirectionValid(is_buy, entry_price, result.t2.price))
        {
         result.t2.status = TP_STATUS_INVALID;
         result.t2.reason = "جهت هدف با جهت معامله هم‌خوانی ندارد";
        }
      else if(min_distance_price > 0.0 &&
              TP_Distance(is_buy, entry_price, result.t2.price) < min_distance_price)
        {
         result.t2.status = TP_STATUS_INVALID;
         result.t2.reason = "فاصله هدف از ورود کمتر از حداقل مجاز است";
        }
      else
        {
         has_valid_target = true;
        }
     }

   //--- بررسی T3
   if(TP_IsTargetValid(result.t3))
     {
      if(!TP_IsDirectionValid(is_buy, entry_price, result.t3.price))
        {
         result.t3.status = TP_STATUS_INVALID;
         result.t3.reason = "جهت هدف با جهت معامله هم‌خوانی ندارد";
        }
      else if(min_distance_price > 0.0 &&
              TP_Distance(is_buy, entry_price, result.t3.price) < min_distance_price)
        {
         result.t3.status = TP_STATUS_INVALID;
         result.t3.reason = "فاصله هدف از ورود کمتر از حداقل مجاز است";
        }
      else
        {
         has_valid_target = true;
        }
     }

   result.valid = has_valid_target;

   if(!has_valid_target)
     {
      result.reason = "هیچ هدف معتبری در جهت معامله وجود ندارد";
      Print(
         "[TP ENGINE] VALIDATION FAIL",
         " | Direction=", (is_buy ? "BUY" : "SELL"),
         " | Entry=", DoubleToString(entry_price, _Digits),
         " | MinDistance=", DoubleToString(min_distance_points, 1), " pts",
         " | T1=", (TP_IsTargetValid(result.t1) ? DoubleToString(result.t1.price, _Digits) : "NONE"),
         " | T2=", (TP_IsTargetValid(result.t2) ? DoubleToString(result.t2.price, _Digits) : "NONE"),
         " | T3=", (TP_IsTargetValid(result.t3) ? DoubleToString(result.t3.price, _Digits) : "NONE")
      );
     }

   return has_valid_target;
  }

//====================================================================
// مرتب‌سازی اهداف از نزدیک به دور
//====================================================================
void TP_SortTargets(const bool is_buy,
                    const double entry_price,
                    TP_Target &targets[],
                    const int count)
  {
   if(count <= 1)
      return;

   for(int i = 0; i < count - 1; i++)
     {
      for(int j = i + 1; j < count; j++)
        {
         double d1 = TP_Distance(is_buy, entry_price, targets[i].price);
         double d2 = TP_Distance(is_buy, entry_price, targets[j].price);

         if(d2 < d1)
           {
            TP_Target temp = targets[i];
            targets[i] = targets[j];
            targets[j] = temp;
           }
        }
     }
  }

//====================================================================
// انتخاب هدف محافظه‌کارانه، اصلی و توسعه‌ای
// [اصلاح] بهبود حالت count == 2
//====================================================================
bool TP_SelectPrimaryTargets(const bool is_buy,
                             const double entry_price,
                             TP_Result &result)
  {
   TP_Target candidates[3];
   int count = 0;

   if(TP_IsTargetValid(result.t1) &&
      TP_IsDirectionValid(is_buy, entry_price, result.t1.price))
      candidates[count++] = result.t1;

   if(TP_IsTargetValid(result.t2) &&
      TP_IsDirectionValid(is_buy, entry_price, result.t2.price))
      candidates[count++] = result.t2;

   if(TP_IsTargetValid(result.t3) &&
      TP_IsDirectionValid(is_buy, entry_price, result.t3.price))
      candidates[count++] = result.t3;

   if(count == 0)
     {
      result.valid = false;
      result.reason = "هدف معتبر برای انتخاب وجود ندارد";
      Print("[TP ENGINE] SELECT FAIL | No valid targets");
      return false;
     }

   TP_SortTargets(is_buy, entry_price, candidates, count);

   //--- conservative = نزدیک‌ترین
   result.conservative_target = candidates[0].price;

   if(count == 1)
     {
      result.primary_target  = candidates[0].price;
      result.extended_target = candidates[0].price;
     }
   else if(count == 2)
     {
      //--- [اصلاح] primary = دورتر، extended = همان دورتر
      result.primary_target  = candidates[1].price;
      result.extended_target = candidates[1].price;
     }
   else  // count == 3
     {
      result.primary_target  = candidates[1].price;
      result.extended_target = candidates[2].price;
     }

   result.valid = true;
   result.reason = "اهداف معتبر بر اساس فاصله از ورود مرتب شدند";

   Print(
      "[TP ENGINE] SELECTED",
      " | Conservative=", DoubleToString(result.conservative_target, _Digits),
      " | Primary=", DoubleToString(result.primary_target, _Digits),
      " | Extended=", DoubleToString(result.extended_target, _Digits),
      " | Count=", count
   );

   return true;
  }

//====================================================================
// بررسی رسیدن قیمت به Target
//====================================================================
bool TP_IsReached(const bool is_buy,
                  const double current_price,
                  const double target_price)
  {
   if(current_price <= 0.0 || target_price <= 0.0)
      return false;

   if(is_buy)
      return (current_price >= target_price);

   return (current_price <= target_price);
  }

//====================================================================
// به‌روزرسانی وضعیت Targetها
// [اصلاح] افزودن لاگ وقتی target به REACHED می‌رسد
//====================================================================
void TP_UpdateTargets(const bool is_buy,
                      const double current_price,
                      TP_Result &result)
  {
   if(TP_IsTargetValid(result.t1) &&
      result.t1.status != TP_STATUS_REACHED &&
      TP_IsReached(is_buy, current_price, result.t1.price))
     {
      result.t1.status = TP_STATUS_REACHED;
      Print(
         "[TP ENGINE] T1 REACHED",
         " | Target=", DoubleToString(result.t1.price, _Digits),
         " | Current=", DoubleToString(current_price, _Digits)
      );
     }

   if(TP_IsTargetValid(result.t2) &&
      result.t2.status != TP_STATUS_REACHED &&
      TP_IsReached(is_buy, current_price, result.t2.price))
     {
      result.t2.status = TP_STATUS_REACHED;
      Print(
         "[TP ENGINE] T2 REACHED",
         " | Target=", DoubleToString(result.t2.price, _Digits),
         " | Current=", DoubleToString(current_price, _Digits)
      );
     }

   if(TP_IsTargetValid(result.t3) &&
      result.t3.status != TP_STATUS_REACHED &&
      TP_IsReached(is_buy, current_price, result.t3.price))
     {
      result.t3.status = TP_STATUS_REACHED;
      Print(
         "[TP ENGINE] T3 REACHED",
         " | Target=", DoubleToString(result.t3.price, _Digits),
         " | Current=", DoubleToString(current_price, _Digits)
      );
     }
  }

//====================================================================
// علامت‌گذاری Target به عنوان معتبر
//====================================================================
void TP_ValidateTarget(TP_Target &target,
                       const string reason)
  {
   target.status = TP_STATUS_VALID;
   target.reason = reason;
  }

//====================================================================
// علامت‌گذاری Target به عنوان مسدود
//====================================================================
void TP_BlockTarget(TP_Target &target,
                    const string reason)
  {
   target.status = TP_STATUS_BLOCKED;
   target.reason = reason;
  }

//====================================================================
// علامت‌گذاری Target به عنوان نامعتبر
//====================================================================
void TP_InvalidateTarget(TP_Target &target,
                         const string reason)
  {
   target.status = TP_STATUS_INVALID;
   target.reason = reason;
  }

//====================================================================
// علامت‌گذاری Target به عنوان تحقق‌یافته
//====================================================================
void TP_MarkReached(TP_Target &target,
                    const string reason)
  {
   target.status = TP_STATUS_REACHED;
   target.reason = reason;
  }

//====================================================================
// تبدیل Target به متن فارسی
//====================================================================
string TP_TargetToText(const TP_Target &target)
  {
   string text = "";

   text += "سطح: " + IntegerToString(target.level);
   text += " | نوع: " + TP_TargetTypeToPersian(target.type);
   text += " | وضعیت: " + TP_StatusToPersian(target.status);
   text += " | قیمت: " + DoubleToString(target.price, _Digits);
   text += " | قدرت: " + DoubleToString(target.strength, 2);

   if(target.reason != "")
      text += " | دلیل: " + target.reason;

   if(target.source != "")
      text += " | منبع: " + target.source;

   return text;
  }

//====================================================================
// تبدیل نتیجه TP به متن فارسی
//====================================================================
string TP_ResultToText(const TP_Result &result)
  {
   string text = "";

   text += "اعتبار: " + (result.valid ? "معتبر" : "نامعتبر");
   text += " | هدف محافظه‌کارانه: " +
           DoubleToString(result.conservative_target, _Digits);
   text += " | هدف اصلی: " +
           DoubleToString(result.primary_target, _Digits);
   text += " | هدف توسعه‌ای: " +
           DoubleToString(result.extended_target, _Digits);

   if(result.reason != "")
      text += " | توضیح: " + result.reason;

   return text;
  }

//====================================================================
// آیا حداقل یک Target معتبر وجود دارد؟
//====================================================================
bool TP_HasValidTarget(const TP_Result &result)
  {
   return (TP_IsTargetValid(result.t1) ||
           TP_IsTargetValid(result.t2) ||
           TP_IsTargetValid(result.t3));
  }

//====================================================================
// تعداد Targetهای معتبر
//====================================================================
int TP_CountValidTargets(const TP_Result &result)
  {
   int count = 0;

   if(TP_IsTargetValid(result.t1)) count++;
   if(TP_IsTargetValid(result.t2)) count++;
   if(TP_IsTargetValid(result.t3)) count++;

   return count;
  }

//+------------------------------------------------------------------+

#endif // __TFLAB_TP_ENGINE_MQH__