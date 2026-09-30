#ifndef __TFLAB_AI_ADVISOR_MQH__
#define __TFLAB_AI_ADVISOR_MQH__

//+------------------------------------------------------------------+
//|                         AI_Advisor.mqh                           |
//|                         TFlab New EA V.5                             |
//|                                                                  |
//| مسئولیت: تبدیل نتایج تحلیل و یادگیری AI به پیشنهاد قابل فهم     |
//|                                                                  |
//| این فایل:                                                        |
//| - پیشنهاد AI را تولید و قالب‌بندی می‌کند                         |
//| - دلیل و میزان اطمینان را نگه می‌دارد                            |
//| - نتیجه مقایسه ربات واقعی و AI مجازی را گزارش می‌کند             |
//| - هرگز معامله واقعی اجرا نمی‌کند                                 |
//| - هرگز منطق اصلی ربات را تغییر نمی‌دهد                           |
//|                                                                  |
//| v2.1 - Priority + Expiration + Chart Display + لاگ تشخیصی      |
//+------------------------------------------------------------------+
#property strict

#include "EA_Inputs.mqh"
#include "Detailed_Logger.mqh"

//====================================================================
// نوع پیشنهاد
//====================================================================
enum ENUM_AI_ADVICE_TYPE
  {
   AI_ADVICE_NONE = 0,
   AI_ADVICE_WAIT,
   AI_ADVICE_ALLOW,
   AI_ADVICE_AVOID,
   AI_ADVICE_REVIEW,
   AI_ADVICE_INFORMATION
  };

//====================================================================
// سطح اطمینان
//====================================================================
enum ENUM_AI_ADVICE_CONFIDENCE
  {
   AI_CONFIDENCE_NONE = 0,
   AI_CONFIDENCE_LOW,
   AI_CONFIDENCE_MEDIUM,
   AI_CONFIDENCE_HIGH
  };

//====================================================================
// اولویت پیشنهاد
//====================================================================
enum ENUM_AI_ADVICE_PRIORITY
  {
   AI_PRIORITY_LOW = 0,
   AI_PRIORITY_NORMAL,
   AI_PRIORITY_HIGH,
   AI_PRIORITY_CRITICAL
  };

//====================================================================
// ساختار پیشنهاد AI
//====================================================================
struct AIAdvisorMessage
  {
   datetime                  created_time;
   datetime                  expiration_time;    // [جدید] زمان انقضا
   ENUM_AI_ADVICE_TYPE       type;
   ENUM_AI_ADVICE_CONFIDENCE confidence_level;
   ENUM_AI_ADVICE_PRIORITY   priority;           // [جدید] اولویت

   double                    confidence_percent;
   int                       sample_count;
   string                    pattern_key;        // [جدید] کلید الگو

   double                    real_profit;
   double                    virtual_profit;
   double                    real_win_rate;
   double                    virtual_win_rate;
   double                    profit_difference;  // [جدید] تفاوت سود
   double                    winrate_difference; // [جدید] تفاوت نرخ برد

   bool                      actionable;
   bool                      popup_requested;
   bool                      displayed;          // [جدید] آیا نمایش داده شده؟

   string                    title;
   string                    message;
   string                    reason;
   string                    comparison;
   string                    source;             // [جدید] منبع پیشنهاد
  };

//====================================================================
// Threshold های اطمینان
//====================================================================
struct AIAdvisorThresholds
  {
   double high_confidence;
   double medium_confidence;
   double low_confidence;
   int    high_priority_samples;
   int    normal_priority_samples;
  };

//------------------------------------------------------------------
// مقداردهی Threshold ها
//------------------------------------------------------------------
void AIAdvisor_ThresholdsInit(AIAdvisorThresholds &thresholds)
  {
   thresholds.high_confidence        = 75.0;
   thresholds.medium_confidence      = 55.0;
   thresholds.low_confidence         = 25.0;
   thresholds.high_priority_samples  = 50;
   thresholds.normal_priority_samples = 20;
  }

//------------------------------------------------------------------
// تبدیل نوع پیشنهاد به فارسی
//------------------------------------------------------------------
string AI_AdvisorTypeToPersian(const ENUM_AI_ADVICE_TYPE type)
  {
   switch(type)
     {
      case AI_ADVICE_WAIT:        return "صبر";
      case AI_ADVICE_ALLOW:       return "موافقت تحلیلی";
      case AI_ADVICE_AVOID:       return "پرهیز";
      case AI_ADVICE_REVIEW:      return "نیاز به بررسی";
      case AI_ADVICE_INFORMATION: return "اطلاع‌رسانی";
      default:                    return "بدون پیشنهاد";
     }
  }

//------------------------------------------------------------------
// تبدیل سطح اطمینان به فارسی
//------------------------------------------------------------------
string AI_AdvisorConfidenceToPersian(const ENUM_AI_ADVICE_CONFIDENCE level)
  {
   switch(level)
     {
      case AI_CONFIDENCE_LOW:    return "کم";
      case AI_CONFIDENCE_MEDIUM: return "متوسط";
      case AI_CONFIDENCE_HIGH:   return "زیاد";
      default:                   return "نامشخص";
     }
  }

//------------------------------------------------------------------
// تبدیل اولویت به فارسی
//------------------------------------------------------------------
string AI_AdvisorPriorityToPersian(const ENUM_AI_ADVICE_PRIORITY priority)
  {
   switch(priority)
     {
      case AI_PRIORITY_LOW:      return "کم";
      case AI_PRIORITY_NORMAL:   return "عادی";
      case AI_PRIORITY_HIGH:     return "بالا";
      case AI_PRIORITY_CRITICAL: return "بحرانی";
      default:                   return "نامشخص";
     }
  }

//------------------------------------------------------------------
// تبدیل اولویت به کد انگلیسی برای لاگ
//------------------------------------------------------------------
string AI_AdvisorPriorityToCode(const ENUM_AI_ADVICE_PRIORITY priority)
  {
   switch(priority)
     {
      case AI_PRIORITY_LOW:      return "LOW";
      case AI_PRIORITY_NORMAL:   return "NORMAL";
      case AI_PRIORITY_HIGH:     return "HIGH";
      case AI_PRIORITY_CRITICAL: return "CRITICAL";
      default:                   return "UNKNOWN";
     }
  }

//------------------------------------------------------------------
// مقداردهی پیام
//------------------------------------------------------------------
void AI_AdvisorInit(AIAdvisorMessage &advice)
  {
   advice.created_time        = 0;
   advice.expiration_time     = 0;
   advice.type                = AI_ADVICE_NONE;
   advice.confidence_level    = AI_CONFIDENCE_NONE;
   advice.priority            = AI_PRIORITY_NORMAL;

   advice.confidence_percent  = 0.0;
   advice.sample_count        = 0;
   advice.pattern_key         = "";

   advice.real_profit         = 0.0;
   advice.virtual_profit      = 0.0;
   advice.real_win_rate       = 0.0;
   advice.virtual_win_rate    = 0.0;
   advice.profit_difference   = 0.0;
   advice.winrate_difference  = 0.0;

   advice.actionable          = false;
   advice.popup_requested     = false;
   advice.displayed           = false;

   advice.title               = "";
   advice.message             = "";
   advice.reason              = "";
   advice.comparison          = "";
   advice.source              = "";
  }

//------------------------------------------------------------------
// تعیین سطح اطمینان بر اساس درصد
// [اصلاح] استفاده از Threshold های قابل تنظیم
//------------------------------------------------------------------
ENUM_AI_ADVICE_CONFIDENCE AI_AdvisorGetConfidenceLevel(
   const double percent,
   const AIAdvisorThresholds &thresholds)
  {
   if(percent >= thresholds.high_confidence)
      return AI_CONFIDENCE_HIGH;

   if(percent >= thresholds.medium_confidence)
      return AI_CONFIDENCE_MEDIUM;

   if(percent >= thresholds.low_confidence)
      return AI_CONFIDENCE_LOW;

   return AI_CONFIDENCE_NONE;
  }

//------------------------------------------------------------------
// [جدید] تعیین اولویت بر اساس تعداد نمونه و اطمینان
//------------------------------------------------------------------
ENUM_AI_ADVICE_PRIORITY AI_AdvisorGetPriority(
   const double confidence_percent,
   const int sample_count,
   const AIAdvisorThresholds &thresholds)
  {
   //--- Critical: اطمینان بالا + نمونه زیاد
   if(confidence_percent >= thresholds.high_confidence &&
      sample_count >= thresholds.high_priority_samples)
      return AI_PRIORITY_CRITICAL;
   
   //--- High: اطمینان بالا یا نمونه زیاد
   if(confidence_percent >= thresholds.high_confidence ||
      sample_count >= thresholds.high_priority_samples)
      return AI_PRIORITY_HIGH;
   
   //--- Normal: اطمینان متوسط یا نمونه کافی
   if(confidence_percent >= thresholds.medium_confidence ||
      sample_count >= thresholds.normal_priority_samples)
      return AI_PRIORITY_NORMAL;
   
   return AI_PRIORITY_LOW;
  }

//------------------------------------------------------------------
// ساخت پیشنهاد پایه
// [اصلاح] افزودن priority + expiration + لاگ
//------------------------------------------------------------------
bool AI_AdvisorCreate(const ENUM_AI_ADVICE_TYPE type,
                      const double confidence_percent,
                      const int sample_count,
                      const string title,
                      const string message,
                      const string reason,
                      AIAdvisorMessage &advice,
                      const string pattern_key = "",
                      const int expiration_minutes = 60,
                      const string source = "AI Advisor")
  {
   AI_AdvisorInit(advice);

   if(type == AI_ADVICE_NONE)
      return false;

   if(confidence_percent < 0.0 || confidence_percent > 100.0)
      return false;

   if(sample_count < 0)
      return false;

   //--- استفاده از Threshold های پیش‌فرض
   AIAdvisorThresholds thresholds;
   AIAdvisor_ThresholdsInit(thresholds);

   advice.created_time        = TimeCurrent();
   advice.type                = type;
   advice.confidence_percent  = confidence_percent;
   advice.confidence_level    = AI_AdvisorGetConfidenceLevel(confidence_percent, thresholds);
   advice.sample_count        = sample_count;
   advice.pattern_key         = pattern_key;
   advice.source              = source;
   
   //--- [جدید] محاسبه اولویت
   advice.priority            = AI_AdvisorGetPriority(confidence_percent, sample_count, thresholds);
   
   //--- [جدید] محاسبه زمان انقضا
   if(expiration_minutes > 0)
      advice.expiration_time = TimeCurrent() + expiration_minutes * 60;

   advice.actionable          = (type == AI_ADVICE_ALLOW ||
                                 type == AI_ADVICE_AVOID ||
                                 type == AI_ADVICE_WAIT);

   advice.popup_requested     = advice.actionable;

   advice.title               = title;
   advice.message             = message;
   advice.reason              = reason;

   //--- [جدید] لاگ تشخیصی
   Print(
      "[AI ADVISOR] CREATED",
      " | Type=", AI_AdvisorTypeToPersian(type),
      " | Priority=", AI_AdvisorPriorityToCode(advice.priority),
      " | Confidence=", DoubleToString(confidence_percent, 1), "%",
      " | Samples=", sample_count,
      " | Pattern=", (pattern_key != "" ? pattern_key : "N/A"),
      " | Title=", title
   );

   return true;
  }

//------------------------------------------------------------------
// ثبت مقایسه ربات واقعی و AI مجازی
// [اصلاح] فرمت‌دهی بهتر + محاسبه تفاوت‌ها
//------------------------------------------------------------------
void AI_AdvisorSetComparison(AIAdvisorMessage &advice,
                             const double real_profit,
                             const double virtual_profit,
                             const double real_win_rate,
                             const double virtual_win_rate)
  {
   advice.real_profit         = real_profit;
   advice.virtual_profit      = virtual_profit;
   advice.real_win_rate       = real_win_rate;
   advice.virtual_win_rate    = virtual_win_rate;
   advice.profit_difference   = virtual_profit - real_profit;
   advice.winrate_difference  = virtual_win_rate - real_win_rate;

   advice.comparison = "";
   
   //--- [اصلاح] فرمت‌دهی بهتر
   advice.comparison += "━━━━━ مقایسه عملکرد ━━━━━\n";
   advice.comparison += "ربات واقعی: سود " + DoubleToString(real_profit, 2);
   advice.comparison += " | نرخ برد " + DoubleToString(real_win_rate, 1) + "%\n";
   advice.comparison += "AI مجازی:   سود " + DoubleToString(virtual_profit, 2);
   advice.comparison += " | نرخ برد " + DoubleToString(virtual_win_rate, 1) + "%\n";
   advice.comparison += "━━━━━━━━━━━━━━━━━━━━━\n";
   
   //--- [جدید] تحلیل تفاوت
   if(MathAbs(advice.profit_difference) > 0.01)
     {
      if(advice.profit_difference > 0.0)
         advice.comparison += "AI مجازی بهتر عمل کرده | اختلاف: +" + 
                              DoubleToString(advice.profit_difference, 2) + "\n";
      else
         advice.comparison += "ربات واقعی بهتر عمل کرده | اختلاف: " + 
                              DoubleToString(advice.profit_difference, 2) + "\n";
     }
   
   if(MathAbs(advice.winrate_difference) > 0.5)
     {
      if(advice.winrate_difference > 0.0)
         advice.comparison += "AI مجازی نرخ برد بالاتر | اختلاف: +" + 
                              DoubleToString(advice.winrate_difference, 1) + "%\n";
      else
         advice.comparison += "ربات واقعی نرخ برد بالاتر | اختلاف: " + 
                              DoubleToString(advice.winrate_difference, 1) + "%\n";
     }
  }

//------------------------------------------------------------------
// پیشنهاد صبر
//------------------------------------------------------------------
bool AI_AdvisorCreateWait(const string reason,
                          const double confidence_percent,
                          const int sample_count,
                          AIAdvisorMessage &advice,
                          const string pattern_key = "",
                          const int expiration_minutes = 30)
  {
   string message = "پیشنهاد AI: فعلاً صبر شود.";
   string title = "پیشنهاد تحلیلگر هوشمند";

   return AI_AdvisorCreate(AI_ADVICE_WAIT,
                           confidence_percent,
                           sample_count,
                           title,
                           message,
                           reason,
                           advice,
                           pattern_key,
                           expiration_minutes,
                           "AI Learning");
  }

//------------------------------------------------------------------
// پیشنهاد پرهیز
//------------------------------------------------------------------
bool AI_AdvisorCreateAvoid(const string reason,
                           const double confidence_percent,
                           const int sample_count,
                           AIAdvisorMessage &advice,
                           const string pattern_key = "",
                           const int expiration_minutes = 60)
  {
   string message = "پیشنهاد AI: در شرایط فعلی از این معامله صرف‌نظر شود.";
   string title = "⚠️ هشدار تحلیلگر هوشمند";

   return AI_AdvisorCreate(AI_ADVICE_AVOID,
                           confidence_percent,
                           sample_count,
                           title,
                           message,
                           reason,
                           advice,
                           pattern_key,
                           expiration_minutes,
                           "AI Learning");
  }

//------------------------------------------------------------------
// پیشنهاد بررسی/اجازه
//------------------------------------------------------------------
bool AI_AdvisorCreateAllow(const string reason,
                           const double confidence_percent,
                           const int sample_count,
                           AIAdvisorMessage &advice,
                           const string pattern_key = "",
                           const int expiration_minutes = 60)
  {
   string message = "پیشنهاد AI: شرایط فعلی برای بررسی معامله مناسب‌تر است.";
   string title = "✅ پیشنهاد تحلیلگر هوشمند";

   return AI_AdvisorCreate(AI_ADVICE_ALLOW,
                           confidence_percent,
                           sample_count,
                           title,
                           message,
                           reason,
                           advice,
                           pattern_key,
                           expiration_minutes,
                           "AI Learning");
  }

//------------------------------------------------------------------
// پیشنهاد اطلاعاتی
//------------------------------------------------------------------
bool AI_AdvisorCreateInformation(const string title,
                                 const string message,
                                 const string reason,
                                 AIAdvisorMessage &advice,
                                 const string source = "AI System")
  {
   return AI_AdvisorCreate(AI_ADVICE_INFORMATION,
                           0.0,
                           0,
                           title,
                           message,
                           reason,
                           advice,
                           "",
                           120,
                           source);
  }

//------------------------------------------------------------------
// [جدید] بررسی انقضای پیشنهاد
//------------------------------------------------------------------
bool AI_Advisor_IsExpired(const AIAdvisorMessage &advice,
                          const datetime current_time = 0)
  {
   if(advice.expiration_time <= 0)
      return false;
   
   datetime now = (current_time > 0 ? current_time : TimeCurrent());
   return (now >= advice.expiration_time);
  }

//------------------------------------------------------------------
// [جدید] دریافت سن پیشنهاد بر حسب دقیقه
//------------------------------------------------------------------
int AI_Advisor_GetAgeMinutes(const AIAdvisorMessage &advice,
                             const datetime current_time = 0)
  {
   if(advice.created_time <= 0)
      return 0;
   
   datetime now = (current_time > 0 ? current_time : TimeCurrent());
   return (int)((now - advice.created_time) / 60);
  }

//------------------------------------------------------------------
// [جدید] محاسبه امتیاز اولویت برای مرتب‌سازی
//------------------------------------------------------------------
int AI_Advisor_GetPriorityScore(const AIAdvisorMessage &advice)
  {
   int score = 0;
   
   //--- اولویت: 0-40
   score += (int)advice.priority * 10;
   
   //--- اطمینان: 0-30
   score += (int)(advice.confidence_percent * 0.30);
   
   //--- نوع پیشنهاد: 0-20
   if(advice.type == AI_ADVICE_AVOID)
      score += 20;
   else if(advice.type == AI_ADVICE_ALLOW)
      score += 15;
   else if(advice.type == AI_ADVICE_WAIT)
      score += 10;
   
   //--- Actionable: 0-10
   if(advice.actionable)
      score += 10;
   
   return score;
  }

//------------------------------------------------------------------
// تبدیل پیشنهاد به متن فارسی برای لاگ/پنل
//------------------------------------------------------------------
string AI_AdvisorToText(const AIAdvisorMessage &advice)
  {
   string text = "";

   text += "عنوان: " + advice.title;
   text += " | نوع: " + AI_AdvisorTypeToPersian(advice.type);
   text += " | اولویت: " + AI_AdvisorPriorityToPersian(advice.priority);
   text += " | اطمینان: " + DoubleToString(advice.confidence_percent, 1) + "%";
   text += " | سطح: " + AI_AdvisorConfidenceToPersian(advice.confidence_level);
   text += " | نمونه: " + IntegerToString(advice.sample_count);
   
   if(advice.pattern_key != "")
      text += " | الگو: " + advice.pattern_key;

   if(advice.message != "")
      text += " | پیام: " + advice.message;

   if(advice.reason != "")
      text += " | دلیل: " + advice.reason;

   if(advice.comparison != "")
      text += " | مقایسه: " + advice.comparison;
   
   text += " | منبع: " + advice.source;
   text += " | سن: " + IntegerToString(AI_Advisor_GetAgeMinutes(advice)) + " دقیقه";
   text += " | منقضی: " + (AI_Advisor_IsExpired(advice) ? "بله" : "خیر");

   return text;
  }

//------------------------------------------------------------------
// تبدیل پیشنهاد به متن Popup
//------------------------------------------------------------------
string AI_AdvisorToPopupText(const AIAdvisorMessage &advice)
  {
   string text = "";

   text += advice.title + "\n\n";
   text += advice.message + "\n\n";

   if(advice.reason != "")
      text += "دلیل: " + advice.reason + "\n\n";

   text += "━━━━━━━━━━━━━━━━━━━━━\n";
   text += "اطمینان: " + DoubleToString(advice.confidence_percent, 1) + "%\n";
   text += "سطح: " + AI_AdvisorConfidenceToPersian(advice.confidence_level) + "\n";
   text += "اولویت: " + AI_AdvisorPriorityToPersian(advice.priority) + "\n";
   text += "تعداد نمونه: " + IntegerToString(advice.sample_count) + "\n";
   
   if(advice.pattern_key != "")
      text += "الگو: " + advice.pattern_key + "\n";

   if(advice.comparison != "")
      text += "\n" + advice.comparison;

   return text;
  }

//------------------------------------------------------------------
// [جدید] نمایش پیشنهاد روی چارت
//------------------------------------------------------------------
bool AI_Advisor_DisplayOnChart(const AIAdvisorMessage &advice,
                               const long chart_id = 0,
                               const string prefix = "AI_ADVICE_")
  {
   if(!AI_AdvisorCanDisplay(advice))
      return false;
   
   if(AI_Advisor_IsExpired(advice))
      return false;
   
   string obj_name = prefix + IntegerToString(advice.created_time);
   
   //--- ایجاد label روی چارت
   if(ObjectFind(chart_id, obj_name) < 0)
     {
      if(!ObjectCreate(chart_id, obj_name, OBJ_LABEL, 0, 0, 0))
         return false;
     }
   
   //--- تنظیم موقعیت
   ObjectSetInteger(chart_id, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chart_id, obj_name, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(chart_id, obj_name, OBJPROP_YDISTANCE, 100);
   
   //--- تنظیم رنگ بر اساس اولویت
   color text_color = clrWhite;
   switch(advice.priority)
     {
      case AI_PRIORITY_CRITICAL: text_color = clrRed; break;
      case AI_PRIORITY_HIGH:     text_color = clrOrange; break;
      case AI_PRIORITY_NORMAL:   text_color = clrYellow; break;
      case AI_PRIORITY_LOW:      text_color = clrLightGray; break;
     }
   
   ObjectSetInteger(chart_id, obj_name, OBJPROP_COLOR, text_color);
   ObjectSetInteger(chart_id, obj_name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(chart_id, obj_name, OBJPROP_FONT, "Arial Bold");
   ObjectSetString(chart_id, obj_name, OBJPROP_TEXT, advice.title + " | " + advice.message);
   ObjectSetInteger(chart_id, obj_name, OBJPROP_HIDDEN, false);
   
   ChartRedraw(chart_id);
   
   return true;
  }

//------------------------------------------------------------------
// [جدید] ثبت پیشنهاد در Detailed Logger
//------------------------------------------------------------------
bool AI_Advisor_Log(const AIAdvisorMessage &advice,
                    DetailedLoggerConfig &log_config,
                    DetailedLoggerState &log_state)
  {
   if(!AI_AdvisorCanDisplay(advice))
      return false;
   
   ENUM_DETAILED_LOG_LEVEL level = DLOG_LEVEL_INFO;
   if(advice.type == AI_ADVICE_AVOID)
      level = DLOG_LEVEL_WARNING;
   else if(advice.priority == AI_PRIORITY_CRITICAL)
      level = DLOG_LEVEL_WARNING;
   
   return DetailedLogger_Log(
      level,
      DLOG_CATEGORY_AI,
      "AI_ADVICE",
      "پیشنهاد هوشمند",
      "",
      AI_AdvisorTypeToPersian(advice.type),
      AI_AdvisorToText(advice),
      _Symbol,
      PERIOD_CURRENT,
      advice.confidence_percent,
      (double)advice.sample_count,
      (double)advice.priority,
      0.0,
      0.0, 0.0, 0.0, 0.0,
      0, 0, 0,
      log_config,
      log_state
   );
  }

//------------------------------------------------------------------
// بررسی اینکه پیشنهاد قابل نمایش است یا نه
//------------------------------------------------------------------
bool AI_AdvisorCanDisplay(const AIAdvisorMessage &advice)
  {
   if(advice.type == AI_ADVICE_NONE)
      return false;

   if(advice.title == "" && advice.message == "")
      return false;
   
   //--- [جدید] بررسی انقضا
   if(AI_Advisor_IsExpired(advice))
      return false;

   return true;
  }

//------------------------------------------------------------------
// فعال/غیرفعال کردن درخواست Popup
//------------------------------------------------------------------
void AI_AdvisorSetPopup(AIAdvisorMessage &advice,
                        const bool enabled)
  {
   advice.popup_requested = enabled;
  }

//------------------------------------------------------------------
// علامت‌گذاری به عنوان نمایش داده شده
//------------------------------------------------------------------
void AI_Advisor_MarkDisplayed(AIAdvisorMessage &advice)
  {
   advice.displayed = true;
  }

//------------------------------------------------------------------
// پاک کردن پیشنهاد
//------------------------------------------------------------------
void AI_AdvisorReset(AIAdvisorMessage &advice)
  {
   AI_AdvisorInit(advice);
  }

//------------------------------------------------------------------
// [جدید] مقایسه دو پیشنهاد برای مرتب‌سازی
//------------------------------------------------------------------
bool AI_Advisor_IsBetter(const AIAdvisorMessage &a,
                         const AIAdvisorMessage &b)
  {
   return (AI_Advisor_GetPriorityScore(a) > AI_Advisor_GetPriorityScore(b));
  }

//------------------------------------------------------------------
// [جدید] خلاصه وضعیت Advisor
//------------------------------------------------------------------
string AI_Advisor_Summary(const AIAdvisorMessage &advice)
  {
   if(advice.type == AI_ADVICE_NONE)
      return "بدون پیشنهاد";
   
   string summary = AI_AdvisorTypeToPersian(advice.type);
   summary += " | " + DoubleToString(advice.confidence_percent, 1) + "%";
   summary += " | " + AI_AdvisorPriorityToPersian(advice.priority);
   
   if(advice.pattern_key != "")
      summary += " | " + advice.pattern_key;
   
   return summary;
  }

//+------------------------------------------------------------------+

#endif // __TFLAB_AI_ADVISOR_MQH__