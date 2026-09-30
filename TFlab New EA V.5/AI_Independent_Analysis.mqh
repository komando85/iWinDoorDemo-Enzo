#ifndef __TFLAB_AI_INDEPENDENT_ANALYSIS_MQH__
#define __TFLAB_AI_INDEPENDENT_ANALYSIS_MQH__
#property strict

#include "EA_Inputs.mqh"
#include "Market_Structure.mqh"
#include "AI_Suggestion_Engine.mqh"

//+------------------------------------------------------------------+
//|              AI_Independent_Analysis.mqh                         |
//|              TFlab New EA V.5                                    |
//|                                                                  |
//| مسئولیت: تحلیل کاملاً مستقل بازار توسط هوش مصنوعی - با تایم‌فریم و |
//| اندیکاتورهای جداگانه از ربات اصلی (نه صرفاً کپی نتیجه ربات) - تا  |
//| بتوان بعداً تصمیم AI را با تصمیم واقعی ربات مقایسه کرد و نقاط     |
//| کور ربات را پیدا کرد.                                             |
//|                                                                  |
//| [نسخه پایه/زیرساخت - فاز ۱]                                       |
//| این نسخه:                                                        |
//|   ✓ ساختار بازار را مستقلاً (با تایم‌فریم/حساسیت متفاوت) می‌خواند  |
//|   ✓ رژیم بازار را مستقلاً (با Handleهای اندیکاتور جداگانه) می‌سنجد|
//|   ✓ یک نظر مستقل (جهت + اطمینان + دلیل) تولید می‌کند              |
//|   ✓ این نظر را کنار تصمیم واقعی ربات در یک CSV مقایسه‌ای ثبت می‌کند|
//| این نسخه هنوز:                                                   |
//|   ✗ معامله مجازی مستقل انجام نمی‌دهد (فاز بعدی)                   |
//|   ✗ پیشنهاد خودکار بر اساس عملکرد خودش نمی‌دهد (فاز بعدی)         |
//+------------------------------------------------------------------+

//====================================================================
// وضعیت نظر مستقل AI
//====================================================================
struct AIIndependentOpinion
  {
   bool     valid;
   datetime time;
   string   direction;       // "BUY" / "SELL" / "NEUTRAL"
   double   confidence;      // 0..100
   string   reasoning;

   //--- جزئیات پایه (برای شفافیت و بررسی بعدی)
   string   structure_state;
   string   regime_state;
   double   regime_confidence;
   double   adx_value;
   double   rsi_value;
  };

AIIndependentOpinion g_ai_independent_opinion;

//--- Handleهای اختصاصی AI مستقل (کاملاً جدا از Handleهای Market_Regime.mqh اصلی)
int g_ai_ind_adx_handle = INVALID_HANDLE;
int g_ai_ind_rsi_handle = INVALID_HANDLE;
int g_ai_ind_ema_handle = INVALID_HANDLE;

MarketStructureSnapshot g_ai_independent_structure;

//+------------------------------------------------------------------+
//| مقداردهی اولیه Handleهای اختصاصی AI مستقل                        |
//+------------------------------------------------------------------+
bool AIIndependent_EnsureHandles()
  {
   if(g_ai_ind_adx_handle == INVALID_HANDLE)
      g_ai_ind_adx_handle = iADX(_Symbol, Inp_AI_Independent_Timeframe, Inp_AI_Independent_ADX_Period);

   if(g_ai_ind_rsi_handle == INVALID_HANDLE)
      g_ai_ind_rsi_handle = iRSI(_Symbol, Inp_AI_Independent_Timeframe, Inp_AI_Independent_RSI_Period, PRICE_CLOSE);

   if(g_ai_ind_ema_handle == INVALID_HANDLE)
      g_ai_ind_ema_handle = iMA(_Symbol, Inp_AI_Independent_Timeframe, Inp_AI_Independent_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);

   return (g_ai_ind_adx_handle != INVALID_HANDLE &&
           g_ai_ind_rsi_handle != INVALID_HANDLE &&
           g_ai_ind_ema_handle != INVALID_HANDLE);
  }

//+------------------------------------------------------------------+
//| تحلیل مستقل کامل بازار توسط AI                                    |
//| این تابع عمداً از g_structure/g_regime اصلی ربات استفاده نمی‌کند -|
//| تایم‌فریم و پارامترهای اندیکاتور جداگانه دارد تا نظر واقعاً مستقل  |
//| باشد، نه بازتاب تحلیل خود ربات.                                   |
//+------------------------------------------------------------------+
bool AIIndependent_Analyze(AIIndependentOpinion &opinion)
  {
   ZeroMemory(opinion);
   opinion.valid = false;
   opinion.direction = "NEUTRAL";
   opinion.time = TimeCurrent();

   if(!AIIndependent_EnsureHandles())
     {
      opinion.reasoning = "Handle اندیکاتورهای مستقل AI ساخته نشد";
      return false;
     }

   //--- ۱) ساختار مستقل (تایم‌فریم و حساسیت متفاوت از ربات اصلی)
   MarketStructure_Analyze(_Symbol, Inp_AI_Independent_Timeframe,
      Inp_AI_Independent_Structure_Bars, Inp_AI_Independent_Pivot_Left,
      Inp_AI_Independent_Pivot_Right, 5.0, g_ai_independent_structure);

   //--- ۲) رژیم مستقل (ADX/RSI/EMA با Handleهای جداگانه)
   double adx_buf[], rsi_buf[], ema_buf[];
   ArraySetAsSeries(adx_buf, true);
   ArraySetAsSeries(rsi_buf, true);
   ArraySetAsSeries(ema_buf, true);

   if(CopyBuffer(g_ai_ind_adx_handle, 0, 1, 3, adx_buf) < 3 ||
      CopyBuffer(g_ai_ind_rsi_handle, 0, 1, 2, rsi_buf) < 2 ||
      CopyBuffer(g_ai_ind_ema_handle, 0, 1, 3, ema_buf) < 3)
     {
      opinion.reasoning = "داده کافی برای تحلیل مستقل AI دریافت نشد";
      return false;
     }

   double adx_value = adx_buf[0];
   double rsi_value = rsi_buf[0];
   double close_1 = iClose(_Symbol, Inp_AI_Independent_Timeframe, 1);
   double ema_slope = ema_buf[0] - ema_buf[2];

   bool regime_trending = (adx_value >= Inp_AI_Independent_ADX_Min_Trend);
   bool regime_bullish = (regime_trending && close_1 > ema_buf[0] && ema_slope > 0.0);
   bool regime_bearish = (regime_trending && close_1 < ema_buf[0] && ema_slope < 0.0);

   opinion.adx_value = adx_value;
   opinion.rsi_value = rsi_value;
   opinion.regime_state = (regime_bullish ? "UPTREND" : (regime_bearish ? "DOWNTREND" : "RANGE"));
   opinion.regime_confidence = MathMin(100.0, adx_value * 2.0);
   opinion.structure_state = MarketStructure_StateToCode(g_ai_independent_structure.state);

   //--- ۳) ترکیب ساختار مستقل + رژیم مستقل برای یک نظر واحد
   int bull_votes = 0, bear_votes = 0;

   if(g_ai_independent_structure.state == STRUCTURE_STATE_BULLISH) bull_votes++;
   else if(g_ai_independent_structure.state == STRUCTURE_STATE_BEARISH) bear_votes++;

   if(regime_bullish) bull_votes++;
   else if(regime_bearish) bear_votes++;

   if(rsi_value > 55.0) bull_votes++;
   else if(rsi_value < 45.0) bear_votes++;

   if(bull_votes >= 2 && bull_votes > bear_votes)
     {
      opinion.direction = "BUY";
      opinion.confidence = MathMin(100.0, 40.0 + bull_votes * 15.0);
      opinion.reasoning = "ساختار مستقل=" + opinion.structure_state +
         " | رژیم مستقل=" + opinion.regime_state +
         " | RSI=" + DoubleToString(rsi_value, 1) +
         " | رأی صعودی=" + IntegerToString(bull_votes) + "/3";
     }
   else if(bear_votes >= 2 && bear_votes > bull_votes)
     {
      opinion.direction = "SELL";
      opinion.confidence = MathMin(100.0, 40.0 + bear_votes * 15.0);
      opinion.reasoning = "ساختار مستقل=" + opinion.structure_state +
         " | رژیم مستقل=" + opinion.regime_state +
         " | RSI=" + DoubleToString(rsi_value, 1) +
         " | رأی نزولی=" + IntegerToString(bear_votes) + "/3";
     }
   else
     {
      opinion.direction = "NEUTRAL";
      opinion.confidence = 30.0;
      opinion.reasoning = "سیگنال‌های مستقل هم‌جهت نیستند یا کافی نیستند";
     }

   opinion.valid = true;
   return true;
  }

//+------------------------------------------------------------------+
//| ثبت مقایسه نظر مستقل AI با تصمیم واقعی ربات در یک CSV جداگانه     |
//| [جدید] این فایل پایه تحلیل «کجا ربات با AI اختلاف نظر دارد» است   |
//+------------------------------------------------------------------+
void AIIndependent_LogComparison(const AIIndependentOpinion &ai_opinion,
   const string bot_direction, const string bot_decision)
  {
   string fn = "TFlab_AI_Independent_vs_Bot.csv";
   int h = FileOpen(fn, FILE_READ | FILE_WRITE | FILE_CSV | FILE_SHARE_READ | FILE_SHARE_WRITE, ';');
   if(h == INVALID_HANDLE) return;

   bool is_new = (FileSize(h) == 0);
   FileSeek(h, 0, SEEK_END);

   if(is_new)
      FileWrite(h, "Time", "AI_Direction", "AI_Confidence", "AI_Reasoning",
         "Bot_Direction", "Bot_Decision", "Agreement");

   bool agree = (ai_opinion.direction == bot_direction) ||
      (ai_opinion.direction == "NEUTRAL" && bot_direction == "NONE");

   FileWrite(h,
      TimeToString(ai_opinion.time, TIME_DATE | TIME_MINUTES),
      ai_opinion.direction,
      DoubleToString(ai_opinion.confidence, 1),
      ai_opinion.reasoning,
      bot_direction,
      bot_decision,
      (agree ? "YES" : "NO"));

   FileClose(h);
  }

//====================================================================
// [جدید - فاز ۲] معامله مجازی مستقل AI
// این بخش باعث می‌شود AI بر اساس تحلیل خودش (نه سناریوی ربات) واقعاً
// یک معامله مجازی باز کند، آن را دنبال کند و نتیجه را ثبت کند - دقیقاً
// همان چیزی که فلسفه اصلی AI مستقل بود: یادگیری از تحلیل خودش.
//====================================================================
struct AIIndependentVirtualTrade
  {
   ulong    id;
   string   direction;
   double   entry_price;
   double   sl_price;
   double   tp_price;
   datetime open_time;
   datetime close_time;
   bool     closed;
   double   result_r;        // نتیجه به واحد R (چند برابر ریسک اولیه) - مستقل از حجم واقعی
   string   close_reason;
   double   confidence_at_entry;
   double   adx_at_entry;
   string   bot_direction_at_entry; // برای مقایسه بعدی
  };

AIIndependentVirtualTrade g_ai_ind_trades[];
bool                      g_ai_ind_has_open_trade = false;
int                       g_ai_ind_open_index = -1;

//+------------------------------------------------------------------+
//| باز کردن معامله مجازی مستقل بر اساس نظر AI (نه سناریوی ربات)      |
//+------------------------------------------------------------------+
void AIIndependent_OpenVirtualTrade(const AIIndependentOpinion &opinion, const string bot_direction)
  {
   if(g_ai_ind_has_open_trade) return;
   if(opinion.direction == "NEUTRAL") return;
   if(opinion.confidence < Inp_AI_Independent_Min_Confidence_To_Trade) return;

   bool is_buy = (opinion.direction == "BUY");
   double price = SymbolInfoDouble(_Symbol, is_buy ? SYMBOL_ASK : SYMBOL_BID);
   if(price <= 0.0) return;

   //--- SL بر اساس ساختار مستقل خودش (نه SL ربات)
   double sl_ref = is_buy ? g_ai_independent_structure.structural_low
                          : g_ai_independent_structure.structural_high;
   if(sl_ref <= 0.0) return;

   double sl_distance = MathAbs(price - sl_ref);
   if(sl_distance <= 0.0) return;

   double sl_price = is_buy ? price - sl_distance : price + sl_distance;
   double tp_price = is_buy ? price + sl_distance * Inp_AI_Independent_RR_Target
                            : price - sl_distance * Inp_AI_Independent_RR_Target;

   AIIndependentVirtualTrade t;
   t.id = (ulong)TimeCurrent();
   t.direction = opinion.direction;
   t.entry_price = price;
   t.sl_price = sl_price;
   t.tp_price = tp_price;
   t.open_time = TimeCurrent();
   t.close_time = 0;
   t.closed = false;
   t.result_r = 0.0;
   t.close_reason = "";
   t.confidence_at_entry = opinion.confidence;
   t.adx_at_entry = opinion.adx_value;
   t.bot_direction_at_entry = bot_direction;

   int n = ArraySize(g_ai_ind_trades);
   ArrayResize(g_ai_ind_trades, n + 1);
   g_ai_ind_trades[n] = t;
   g_ai_ind_has_open_trade = true;
   g_ai_ind_open_index = n;

   Print("[AI INDEPENDENT VIRTUAL] OPENED | Direction=", t.direction,
         " | Entry=", DoubleToString(t.entry_price, _Digits),
         " | SL=", DoubleToString(t.sl_price, _Digits),
         " | TP=", DoubleToString(t.tp_price, _Digits),
         " | Confidence=", DoubleToString(t.confidence_at_entry, 1),
         " | BotDirection=", bot_direction,
         (bot_direction != t.direction ? " (اختلاف نظر با ربات)" : " (هم‌جهت با ربات)"));
  }

//+------------------------------------------------------------------+
//| بررسی رسیدن به SL/TP معامله مجازی مستقل باز                       |
//+------------------------------------------------------------------+
void AIIndependent_MonitorVirtualTrade()
  {
   if(!g_ai_ind_has_open_trade || g_ai_ind_open_index < 0) return;
   if(g_ai_ind_open_index >= ArraySize(g_ai_ind_trades)) { g_ai_ind_has_open_trade = false; return; }

   AIIndependentVirtualTrade t = g_ai_ind_trades[g_ai_ind_open_index];
   bool is_buy = (t.direction == "BUY");
   double price = SymbolInfoDouble(_Symbol, is_buy ? SYMBOL_BID : SYMBOL_ASK);
   if(price <= 0.0) return;

   double sl_distance = MathAbs(t.entry_price - t.sl_price);
   if(sl_distance <= 0.0) return;

   bool hit_sl = is_buy ? (price <= t.sl_price) : (price >= t.sl_price);
   bool hit_tp = is_buy ? (price >= t.tp_price) : (price <= t.tp_price);

   //--- انقضای زمانی: اگر خیلی طولانی باز ماند (بیش از 3 برابر تایم‌فریم مستقل ضربدر 50 کندل تقریبی)
   bool expired = (TimeCurrent() - t.open_time) > (PeriodSeconds(Inp_AI_Independent_Timeframe) * 100);

   if(!hit_sl && !hit_tp && !expired) return;

   double raw_move = is_buy ? (price - t.entry_price) : (t.entry_price - price);
   double result_r = raw_move / sl_distance;

   g_ai_ind_trades[g_ai_ind_open_index].closed = true;
   g_ai_ind_trades[g_ai_ind_open_index].close_time = TimeCurrent();
   g_ai_ind_trades[g_ai_ind_open_index].result_r = result_r;
   g_ai_ind_trades[g_ai_ind_open_index].close_reason =
      (hit_tp ? "TP" : (hit_sl ? "SL" : "زمان (Expired)"));

   Print("[AI INDEPENDENT VIRTUAL] CLOSED | Direction=", t.direction,
         " | Reason=", g_ai_ind_trades[g_ai_ind_open_index].close_reason,
         " | ResultR=", DoubleToString(result_r, 2));

   g_ai_ind_has_open_trade = false;
   g_ai_ind_open_index = -1;
  }

//+------------------------------------------------------------------+
//| آمار عملکرد معاملات مجازی مستقل AI                                |
//+------------------------------------------------------------------+
struct AIIndependentStats
  {
   int    planned;
   int    opened;
   int    open_now;
   int    closed;
   int    wins;
   int    losses;
   int    breakeven;

   double total_profit_r;
   double total_loss_r;
   double net_r;
   double win_rate;
   double profit_factor;

   int    agree_with_bot;
   int    disagree_with_bot;
  };
  
void AIIndependent_GetStats(AIIndependentStats &stats)
  {
   ZeroMemory(stats);

   int n = ArraySize(g_ai_ind_trades);

   for(int i = 0; i < n; i++)
     {
      if(g_ai_ind_trades[i].id == 0)
         continue;

      stats.planned++;
      stats.opened++;

      if(!g_ai_ind_trades[i].closed)
        {
         stats.open_now++;
         continue;
        }

      stats.closed++;

      double r = g_ai_ind_trades[i].result_r;

      if(r > 0.0)
        {
         stats.wins++;
         stats.total_profit_r += r;
        }
      else
      if(r < 0.0)
        {
         stats.losses++;
         stats.total_loss_r += MathAbs(r);
        }
      else
        {
         stats.breakeven++;
        }

      stats.net_r += r;

      if(g_ai_ind_trades[i].bot_direction_at_entry ==
         g_ai_ind_trades[i].direction)
         stats.agree_with_bot++;
      else
         stats.disagree_with_bot++;
     }

   int decisive = stats.wins + stats.losses;

   stats.win_rate =
      (decisive > 0
       ? 100.0 * stats.wins / decisive
       : 0.0);

   stats.profit_factor =
      (stats.total_loss_r > 0.0
       ? stats.total_profit_r / stats.total_loss_r
       : (stats.total_profit_r > 0.0 ? 9999.0 : 0.0));
  }
//+------------------------------------------------------------------+
//| نقطه ورود اصلی - باید یک‌بار در هر چرخه تحلیل (بسته‌شدن کندل      |
//| اصلی ربات) صدا زده شود                                            |
//+------------------------------------------------------------------+
void AIIndependent_Update(const string bot_direction, const string bot_decision)
  {
   if(!Inp_AI_Independent_Enable) return;

   //--- [جدید] پایش معامله مجازی باز مستقل در هر چرخه (نه فقط کندل جدید)
   AIIndependent_MonitorVirtualTrade();

   static datetime last_bar = 0;
   datetime cur_bar = iTime(_Symbol, Inp_AI_Independent_Timeframe, 0);
   if(cur_bar == last_bar) return;
   last_bar = cur_bar;

   AIIndependentOpinion opinion;
   if(!AIIndependent_Analyze(opinion)) return;

   g_ai_independent_opinion = opinion;

   Print("[AI INDEPENDENT] Direction=", opinion.direction,
         " | Confidence=", DoubleToString(opinion.confidence, 1),
         " | Bot=", bot_direction, "/", bot_decision,
         " | ", opinion.reasoning);

   AIIndependent_LogComparison(opinion, bot_direction, bot_decision);

         //--- [جدید v3.0] پاپ‌آپ معامله لحظه‌ای
   if(Inp_AI_Advisor_Popup && Inp_AI_Advisor_Enable &&
      opinion.confidence >= Inp_AI_Realtime_Popup_Min_Confidence &&
      opinion.direction != "NEUTRAL")
     {
      //--- محاسبه Entry/SL/TP بر اساس تحلیل AI
      double entry = SymbolInfoDouble(_Symbol, 
         (opinion.direction == "BUY" ? SYMBOL_ASK : SYMBOL_BID));
      
      double sl_ref = (opinion.direction == "BUY" ? 
         g_ai_independent_structure.structural_low :
         g_ai_independent_structure.structural_high);
      
      if(sl_ref <= 0.0) sl_ref = (opinion.direction == "BUY" ?
         entry - 1000 * _Point : entry + 1000 * _Point);
      
      double sl_distance = MathAbs(entry - sl_ref);
      double sl = (opinion.direction == "BUY" ? entry - sl_distance : entry + sl_distance);
      double tp = (opinion.direction == "BUY" ? 
         entry + sl_distance * 2.0 : entry - sl_distance * 2.0);
      
      AIPopup_ShowTradeSuggestion(
         opinion.direction, entry, sl, tp, 
         opinion.confidence, opinion.reasoning);
     }
   //--- [جدید] تلاش برای باز کردن معامله مجازی مستقل بر اساس همین نظر
   AIIndependent_OpenVirtualTrade(opinion, bot_direction);
  }
//+------------------------------------------------------------------+
//| [جدید v3] پاپ‌آپ لحظه‌ای برای پیشنهاد قوی AI مستقل                |
//+------------------------------------------------------------------+
void AISuggestion_ShowRealtimeAIAdvice(
   const string direction_text,
   const double confidence,
   const string reason,
   const string bot_direction)
  {
   //--- بررسی حداقل اطمینان
   if(confidence < Inp_AI_Realtime_Popup_Min_Confidence) return;
   
   //--- خنثی را نمایش نده
   if(direction_text == "NEUTRAL" || direction_text == "خنثی") return;
   
   //--- جلوگیری از تکرار پشت سر هم (هر ۶۰ ثانیه یکبار)
   static datetime last_realtime_popup = 0;
   if(TimeCurrent() - last_realtime_popup < 60) return;
   last_realtime_popup = TimeCurrent();
   
   //--- ساخت پیام
   string emoji = (direction_text == "BUY") ? "🟢" : "🔴";
   string dir_fa = direction_text;
   if(dir_fa == "BUY")  dir_fa = "خرید";
   if(dir_fa == "SELL") dir_fa = "فروش";
   
   string bot_fa = bot_direction;
   if(bot_fa == "BUY")  bot_fa = "خرید";
   if(bot_fa == "SELL") bot_fa = "فروش";
   if(bot_fa == "NONE") bot_fa = "بدون جهت";
   
   string msg = emoji + " پیشنهاد لحظه‌ای هوش مصنوعی مستقل\n" +
                "━━━━━━━━━━━━━━━━━━━━━━━\n" +
                "جهت: " + dir_fa + "\n" +
                "اطمینان: " + DoubleToString(confidence, 1) + "٪\n" +
                "ربات اصلی: " + bot_fa + "\n" +
                "━━━━━━━━━━━━━━━━━━━━━━━\n" +
                "دلیل: " + reason;
   
   //--- نمایش پاپ‌آپ روی چارت
   AISuggestion_ShowPopup(msg);
   
   //--- Alert متاتریدر (اگر فعال باشد)
   if(Inp_AI_Realtime_Popup_Alert)
     {
      Alert("🧠 AI ", dir_fa, " | اطمینان: ", DoubleToString(confidence, 0), "%");
     }
   
   Print("[AI POPUP] REALTIME | ", dir_fa, " | ", DoubleToString(confidence, 1),
         "% | ", reason);
  }

#endif // __TFLAB_AI_INDEPENDENT_ANALYSIS_MQH__
