#ifndef __TFLAB_AI_SUGGESTION_ENGINE_MQH__
#define __TFLAB_AI_SUGGESTION_ENGINE_MQH__
#property strict

#include "EA_Inputs.mqh"
#include "AI_Journal.mqh"
#include "AI_Independent_Analysis.mqh"

//+------------------------------------------------------------------+
//| AI Suggestion Engine v3.1                                       |
//| - پشتیبانی از متن چندخطی                                       |
//| - دو نوع پاپ‌آپ: معامله + پارامتر                              |
//| - پیشنهاد معامله: تایید / رد / بستن                            |
//| - کلیک تایید معامله به EA_Main تحویل داده می‌شود               |
//+------------------------------------------------------------------+

#define AI_SUGGEST_PREFIX "TFLAB_AIPOP_"

// تابع اجرای واقعی که در EA_Main تعریف می‌شود
void ExecuteConfirmedAISuggestion(const string direction,
                                  const double entry,
                                  const double sl,
                                  const double tp,
                                  const double confidence,
                                  const string reason);

//====================================================================
// نوع پاپ‌آپ
//====================================================================
enum ENUM_AI_POPUP_TYPE
  {
   AI_POPUP_NONE = 0,
   AI_POPUP_TRADE,
   AI_POPUP_PARAM
  };

//====================================================================
// نتیجه اقدام کاربر روی پیشنهاد معامله
//====================================================================
enum ENUM_AI_TRADE_ACTION
  {
   AI_TRADE_ACTION_NONE = 0,
   AI_TRADE_ACTION_CONFIRM,
   AI_TRADE_ACTION_REJECT
  };

//====================================================================
// وضعیت فعلی پاپ‌آپ
//====================================================================
struct AIPopupState
  {
   ENUM_AI_POPUP_TYPE type;

   //--- برای پیشنهاد معامله
   string trade_direction;
   double trade_entry;
   double trade_sl;
   double trade_tp;
   double trade_confidence;
   string trade_reason;

   //--- برای پیشنهاد پارامتر
   string param_name;
   string param_display_name;
   double param_current;
   double param_suggested;
   string param_reason;

   //--- عمومی
   datetime show_time;
   bool     visible;
  };

AIPopupState g_ai_popup;
ENUM_AI_TRADE_ACTION g_ai_trade_action = AI_TRADE_ACTION_NONE;

//====================================================================
// مقداردهی اولیه
//====================================================================
void AIPopup_Reset()
  {
   ZeroMemory(g_ai_popup);
   g_ai_popup.type = AI_POPUP_NONE;
   g_ai_popup.visible = false;
   g_ai_trade_action = AI_TRADE_ACTION_NONE;
  }

//====================================================================
// حذف تمام اجزای پاپ‌آپ از چارت
//====================================================================
void AIPopup_Destroy()
  {
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, AI_SUGGEST_PREFIX) == 0)
         ObjectDelete(0, name);
     }
   g_ai_popup.visible = false;
   ChartRedraw(0);
  }

//====================================================================
// ساخت یک خط متنی روی چارت
//====================================================================
void AIPopup_CreateLabel(const string id, int x, int y,
                         const string text, color clr,
                         int font_size = 10, string font = "Tahoma")
  {
   string full_name = AI_SUGGEST_PREFIX + id;
   if(ObjectFind(0, full_name) < 0)
      ObjectCreate(0, full_name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, full_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, full_name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, full_name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, full_name, OBJPROP_TEXT, text);
   ObjectSetString(0, full_name, OBJPROP_FONT, font);
   ObjectSetInteger(0, full_name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, full_name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, full_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, full_name, OBJPROP_HIDDEN, true);
  }

//====================================================================
// ساخت دکمه
//====================================================================
void AIPopup_CreateButton(const string id, int x, int y, int w, int h,
                          const string text, color text_clr, color bg_clr)
  {
   string full_name = AI_SUGGEST_PREFIX + id;
   if(ObjectFind(0, full_name) < 0)
      ObjectCreate(0, full_name, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, full_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, full_name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, full_name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, full_name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, full_name, OBJPROP_YSIZE, h);
   ObjectSetString(0, full_name, OBJPROP_TEXT, text);
   ObjectSetString(0, full_name, OBJPROP_FONT, "Tahoma Bold");
   ObjectSetInteger(0, full_name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, full_name, OBJPROP_COLOR, text_clr);
   ObjectSetInteger(0, full_name, OBJPROP_BGCOLOR, bg_clr);
   ObjectSetInteger(0, full_name, OBJPROP_BORDER_COLOR, clrWhite);
   ObjectSetInteger(0, full_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, full_name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, full_name, OBJPROP_ZORDER, 100);
  }

//====================================================================
// ساخت پس‌زمینه
//====================================================================
void AIPopup_CreateBG(int x, int y, int w, int h)
  {
   string bg = AI_SUGGEST_PREFIX + "BG";
   if(ObjectFind(0, bg) < 0)
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'25, 35, 55');
   ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, bg, OBJPROP_ZORDER, 0);
  }

//====================================================================
// [نوع A] نمایش پیشنهاد معامله لحظه‌ای
//====================================================================
void AIPopup_ShowTradeSuggestion(
   const string direction,
   const double entry,
   const double sl,
   const double tp,
   const double confidence,
   const string reason)
  {
   AIPopup_Destroy();
   g_ai_trade_action = AI_TRADE_ACTION_NONE;

   //--- ذخیره وضعیت
   g_ai_popup.type = AI_POPUP_TRADE;
   g_ai_popup.trade_direction = direction;
   g_ai_popup.trade_entry = entry;
   g_ai_popup.trade_sl = sl;
   g_ai_popup.trade_tp = tp;
   g_ai_popup.trade_confidence = confidence;
   g_ai_popup.trade_reason = reason;
   g_ai_popup.show_time = TimeCurrent();
   g_ai_popup.visible = true;

   //--- موقعیت
   int x = 20, y = 40, w = 400, h = 450;

   AIPopup_CreateBG(x, y, w, h);

   AIPopup_CreateLabel("Title", x+15, y+12,
      "🎯 پیشنهاد هوش مصنوعی", clrGold, 10, "Tahoma Bold");

   string dir_fa = (direction == "BUY" ? "خرید 🟢" : "فروش 🔴");
   AIPopup_CreateLabel("L1", x+15, y+50, "جهت:", clrWhite, 10);
   AIPopup_CreateLabel("V1", x+220, y+50, dir_fa,
      (direction == "BUY" ? clrLime : clrRed), 11, "Tahoma Bold");

   AIPopup_CreateLabel("L2", x+15, y+100, "قیمت ورود:", clrWhite, 10);
   AIPopup_CreateLabel("V2", x+220, y+100,
      DoubleToString(entry, _Digits), clrAqua, 10, "Tahoma Bold");

   AIPopup_CreateLabel("L3", x+15, y+150, "حد ضرر (SL):", clrWhite, 10);
   AIPopup_CreateLabel("V3", x+220, y+150,
      DoubleToString(sl, _Digits), clrOrangeRed, 10, "Tahoma Bold");

   AIPopup_CreateLabel("L4", x+15, y+200, "حد سود (TP):", clrWhite, 10);
   AIPopup_CreateLabel("V4", x+220, y+200,
      DoubleToString(tp, _Digits), clrLimeGreen, 10, "Tahoma Bold");

   AIPopup_CreateLabel("L5", x+15, y+250, "اطمینان:", clrWhite, 10);
   AIPopup_CreateLabel("V5", x+220, y+250,
      DoubleToString(confidence, 1) + "%", clrGold, 10, "Tahoma Bold");

   double rr = (MathAbs(entry - sl) > 0 ?
      MathAbs(tp - entry) / MathAbs(entry - sl) : 0);
   AIPopup_CreateLabel("L6", x+15, y+300, "نسبت RR:", clrWhite, 10);
   AIPopup_CreateLabel("V6", x+220, y+300,
      "1:" + DoubleToString(rr, 2), clrAqua, 10, "Tahoma Bold");

   //--- دکمه‌های معامله
   AIPopup_CreateButton("ConfirmTrade", x+20, y+345, 165, 40,
      "✓ تائید", clrWhite, C'30,140,60');

   AIPopup_CreateButton("RejectTrade", x+205, y+345, 165, 40,
      "✗ رد", clrWhite, C'160,40,40');

   //--- بستن
   AIPopup_CreateButton("Close", x+w-30, y+5, 25, 25,
      "×", clrWhite, C'180,40,40');

   ChartRedraw(0);
   Alert("🎯 پیشنهاد ", dir_fa, " | Entry=", entry,
         " | SL=", sl, " | TP=", tp);

   Print("[AI POPUP] TRADE | ", direction,
         " | Entry=", entry, " | SL=", sl,
         " | TP=", tp, " | Conf=", confidence, "%");
  }

//====================================================================
// [نوع B] نمایش پیشنهاد تغییر پارامتر
//====================================================================
void AIPopup_ShowParamSuggestion(
   const string param_name,
   const string display_name,
   const double current_value,
   const double suggested_value,
   const string reason)
  {
   AIPopup_Destroy();
   g_ai_trade_action = AI_TRADE_ACTION_NONE;

   g_ai_popup.type = AI_POPUP_PARAM;
   g_ai_popup.param_name = param_name;
   g_ai_popup.param_display_name = display_name;
   g_ai_popup.param_current = current_value;
   g_ai_popup.param_suggested = suggested_value;
   g_ai_popup.param_reason = reason;
   g_ai_popup.show_time = TimeCurrent();
   g_ai_popup.visible = true;

   int x = 20, y = 40, w = 420, h = 260;
   AIPopup_CreateBG(x, y, w, h);

   AIPopup_CreateLabel("Title", x+15, y+12,
      "⚙️ پیشنهاد بهبود تنظیمات ربات", clrGold, 12, "Tahoma Bold");

   AIPopup_CreateLabel("L1", x+15, y+50, "پارامتر:", clrWhite, 10);
   AIPopup_CreateLabel("V1", x+140, y+50, display_name, clrAqua, 10, "Tahoma Bold");

   AIPopup_CreateLabel("L2", x+15, y+80, "مقدار فعلی:", clrWhite, 10);
   AIPopup_CreateLabel("V2", x+140, y+80,
      DoubleToString(current_value, 2), clrOrange, 10, "Tahoma Bold");

   AIPopup_CreateLabel("L3", x+15, y+110, "مقدار پیشنهادی:", clrWhite, 10);
   AIPopup_CreateLabel("V3", x+140, y+110,
      DoubleToString(suggested_value, 2), clrLime, 11, "Tahoma Bold");

   AIPopup_CreateLabel("L4", x+15, y+145, "دلیل:", clrWhite, 10);
   AIPopup_CreateLabel("V4", x+140, y+145, reason, clrWhiteSmoke, 9);

   AIPopup_CreateButton("Confirm", x+20, y+h-50, 150, 35,
      "✓ تایید و اعمال", clrWhite, C'30,140,60');

   AIPopup_CreateButton("Reject", x+w-170, y+h-50, 150, 35,
      "✗ صرف‌نظر", clrWhite, C'160,40,40');

   AIPopup_CreateButton("Close", x+w-30, y+5, 25, 25,
      "×", clrWhite, C'180,40,40');

   ChartRedraw(0);

   Print("[AI POPUP] PARAM | ", display_name, " | ", current_value,
         " → ", suggested_value, " | Reason=", reason);
  }

//====================================================================
// خروجی اقدام تأیید/رد برای EA_Main
//====================================================================
bool AISuggestion_ConsumeTradeAction(bool &confirmed,
                                      bool &rejected,
                                      string &direction,
                                      double &entry,
                                      double &sl,
                                      double &tp,
                                      double &confidence,
                                      string &reason)
  {
   confirmed = false;
   rejected = false;
   direction = "";
   entry = 0.0;
   sl = 0.0;
   tp = 0.0;
   confidence = 0.0;
   reason = "";

   if(g_ai_trade_action == AI_TRADE_ACTION_NONE)
      return false;

   if(g_ai_popup.type != AI_POPUP_TRADE)
     {
      g_ai_trade_action = AI_TRADE_ACTION_NONE;
      return false;
     }

   direction = g_ai_popup.trade_direction;
   entry = g_ai_popup.trade_entry;
   sl = g_ai_popup.trade_sl;
   tp = g_ai_popup.trade_tp;
   confidence = g_ai_popup.trade_confidence;
   reason = g_ai_popup.trade_reason;

   confirmed = (g_ai_trade_action == AI_TRADE_ACTION_CONFIRM);
   rejected = (g_ai_trade_action == AI_TRADE_ACTION_REJECT);

   g_ai_trade_action = AI_TRADE_ACTION_NONE;
   return true;
  }

//====================================================================
// مدیریت کلیک دکمه‌ها
//====================================================================
void AISuggestion_OnChartEvent(const int id, const long &lparam,
                               const double &dparam, const string &sparam)
  {
   if(id != CHARTEVENT_OBJECT_CLICK) return;
   if(StringFind(sparam, AI_SUGGEST_PREFIX) != 0) return;

   string btn_id = StringSubstr(sparam, StringLen(AI_SUGGEST_PREFIX));
   Print("[AI POPUP] Button clicked: ", btn_id);

   if(btn_id == "Close")
     {
      g_ai_trade_action = AI_TRADE_ACTION_NONE;
      AIPopup_Destroy();
      return;
     }

   //--- تأیید پیشنهاد معامله
   if(btn_id == "ConfirmTrade" && g_ai_popup.type == AI_POPUP_TRADE)
     {
      // اجرای واقعی مستقیماً در لحظه کلیک انجام می‌شود.
      // دیگر وابسته به چرخه بعدی OnTick/OnTimer نیستیم.
      string direction = g_ai_popup.trade_direction;
      double entry = g_ai_popup.trade_entry;
      double sl = g_ai_popup.trade_sl;
      double tp = g_ai_popup.trade_tp;
      double confidence = g_ai_popup.trade_confidence;
      string reason = g_ai_popup.trade_reason;

      Print("[AI POPUP] CONFIRMED TRADE | ", direction,
            " | Entry=", DoubleToString(entry,_Digits),
            " | SL=", DoubleToString(sl,_Digits),
            " | TP=", DoubleToString(tp,_Digits));

      AIPopup_Destroy();
      g_ai_trade_action = AI_TRADE_ACTION_NONE;

      ExecuteConfirmedAISuggestion(direction, entry, sl, tp, confidence, reason);
      return;
     }

   //--- رد پیشنهاد معامله
   if(btn_id == "RejectTrade" && g_ai_popup.type == AI_POPUP_TRADE)
     {
      g_ai_trade_action = AI_TRADE_ACTION_REJECT;
      Print("[AI POPUP] REJECTED TRADE | ", g_ai_popup.trade_direction,
            " | Entry=", DoubleToString(g_ai_popup.trade_entry,_Digits),
            " | SL=", DoubleToString(g_ai_popup.trade_sl,_Digits),
            " | TP=", DoubleToString(g_ai_popup.trade_tp,_Digits));
      AIPopup_Destroy();
      return;
     }

   //--- تایید پیشنهاد پارامتر
   if(btn_id == "Confirm" && g_ai_popup.type == AI_POPUP_PARAM)
     {
      Print("[AI POPUP] CONFIRMED | ", g_ai_popup.param_display_name,
            " = ", g_ai_popup.param_suggested);
      Alert("✓ تغییر ", g_ai_popup.param_display_name,
            " به ", DoubleToString(g_ai_popup.param_suggested, 2), " اعمال شد");
      Print("[AI POPUP] NOTE: برای اعمال واقعی پارامتر باید از منطق runtime مربوطه استفاده شود.");
      AIPopup_Destroy();
      return;
     }

   //--- رد پیشنهاد پارامتر
   if(btn_id == "Reject" && g_ai_popup.type == AI_POPUP_PARAM)
     {
      Print("[AI POPUP] REJECTED | کاربر صرف‌نظر کرد");
      AIPopup_Destroy();
      return;
     }
  }

//====================================================================
// پاکسازی خودکار پاپ‌آپ‌های قدیمی
//====================================================================
void AISuggestion_Cleanup()
  {
   if(!g_ai_popup.visible) return;
   if(TimeCurrent() - g_ai_popup.show_time > 300)
     {
      g_ai_trade_action = AI_TRADE_ACTION_NONE;
      AIPopup_Destroy();
     }
  }

//====================================================================
// سازگاری
//====================================================================
void AISuggestion_HidePopup() { AIPopup_Destroy(); }
void AISuggestion_ShowPopup(const string text)
  {
   AIPopup_Destroy();
   g_ai_trade_action = AI_TRADE_ACTION_NONE;
   int x = 20, y = 40, w = 400, h = 200;
   AIPopup_CreateBG(x, y, w, h);
   AIPopup_CreateLabel("Title", x+15, y+12, "📢 پیام", clrGold, 11, "Tahoma Bold");
   AIPopup_CreateLabel("Msg", x+15, y+50, text, clrWhite, 9);
   AIPopup_CreateButton("Close", x+w-30, y+5, 25, 25, "×", clrWhite, C'180,40,40');
   g_ai_popup.visible = true;
   g_ai_popup.show_time = TimeCurrent();
   ChartRedraw(0);
  }

void AISuggestion_AnalyzeConfluenceThreshold() { /* ... */ }
void AISuggestion_AnalyzeIndependentPerformance() { /* ... */ }

void AISuggestion_Update()
  {
   AISuggestion_Cleanup();

   static datetime last_check = 0;
   if(TimeCurrent() - last_check < 900) return;
   last_check = TimeCurrent();

   AISuggestion_AnalyzeConfluenceThreshold();
   AISuggestion_AnalyzeIndependentPerformance();
  }

#endif // __TFLAB_AI_SUGGESTION_ENGINE_MQH__
