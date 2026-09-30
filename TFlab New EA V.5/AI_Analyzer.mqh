#ifndef __TFLAB_AI_ANALYZER_MQH__
#define __TFLAB_AI_ANALYZER_MQH__

//+------------------------------------------------------------------+
//|                         AI_Analyzer.mqh                          |
//|                         TFlab New EA V.5                             |
//|                                                                  |
//| مسئولیت: تحلیل داده‌های ثبت‌شده برای سیستم یادگیری AI           |
//| بدون اجرای معامله واقعی و بدون تغییر منطق هسته ربات             |
//|                                                                  |
//| v2.1 - Fixed average calc + Profit Factor + Expectancy + لاگ  |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// نتیجه یک تحلیل آماری
// [اصلاح] افزودن average_win و expectancy
//====================================================================
struct AIAnalysisResult
  {
   bool     valid;
   int      sample_count;
   int      win_count;
   int      loss_count;
   int      breakeven_count;
   
   double   win_rate;
   double   loss_rate;
   
   double   total_profit;
   double   gross_profit;
   double   gross_loss;
   
   double   average_win;          // [جدید] میانگین سود معاملات برنده
   double   average_loss;         // [اصلاح] میانگین ضرر معاملات بازنده (مثبت)
   double   average_trade;        // [جدید] میانگین هر معامله
   double   expectancy;           // [جدید] امید ریاضی
   double   profit_factor;
   
   string   conclusion;
  };

//====================================================================
// یک الگوی قابل شناسایی
//====================================================================
struct AIPattern
  {
   ulong    pattern_id;
   string   description;
   
   int      sample_count;
   int      win_count;
   int      loss_count;
   int      breakeven_count;
   
   double   win_rate;
   double   total_profit;
   double   gross_profit;
   double   gross_loss;
   double   average_win;
   double   average_loss;
   double   average_result;
   double   expectancy;
   double   profit_factor;
   
   bool     statistically_ready;
   double   quality_score;        // [جدید] امتیاز کیفیت کلی
   
   datetime first_seen;
   datetime last_seen;
  };

//------------------------------------------------------------------
// مقداردهی اولیه نتیجه تحلیل
//------------------------------------------------------------------
void AIAnalyzer_InitResult(AIAnalysisResult &result)
  {
   result.valid           = false;
   result.sample_count    = 0;
   result.win_count       = 0;
   result.loss_count      = 0;
   result.breakeven_count = 0;
   
   result.win_rate        = 0.0;
   result.loss_rate       = 0.0;
   
   result.total_profit    = 0.0;
   result.gross_profit    = 0.0;
   result.gross_loss      = 0.0;
   
   result.average_win     = 0.0;
   result.average_loss    = 0.0;
   result.average_trade   = 0.0;
   result.expectancy      = 0.0;
   result.profit_factor   = 0.0;
   
   result.conclusion      = "";
  }

//------------------------------------------------------------------
// مقداردهی اولیه الگو
//------------------------------------------------------------------
void AIAnalyzer_InitPattern(AIPattern &pattern)
  {
   pattern.pattern_id          = 0;
   pattern.description         = "";
   
   pattern.sample_count        = 0;
   pattern.win_count           = 0;
   pattern.loss_count          = 0;
   pattern.breakeven_count     = 0;
   
   pattern.win_rate            = 0.0;
   pattern.total_profit        = 0.0;
   pattern.gross_profit        = 0.0;
   pattern.gross_loss          = 0.0;
   pattern.average_win         = 0.0;
   pattern.average_loss        = 0.0;
   pattern.average_result      = 0.0;
   pattern.expectancy          = 0.0;
   pattern.profit_factor       = 0.0;
   
   pattern.statistically_ready = false;
   pattern.quality_score       = 0.0;
   
   pattern.first_seen          = 0;
   pattern.last_seen           = 0;
  }

//------------------------------------------------------------------
// محاسبه Win Rate
//------------------------------------------------------------------
double AIAnalyzer_WinRate(const int wins, const int samples)
  {
   if(samples <= 0)
      return 0.0;

   return ((double)wins / (double)samples) * 100.0;
  }

//------------------------------------------------------------------
// محاسبه Profit Factor
// [اصلاح] هندل کردن gross_loss مثبت و منفی
//------------------------------------------------------------------
double AIAnalyzer_ProfitFactor(const double gross_profit,
                               const double gross_loss)
  {
   //--- gross_loss ممکن است مثبت یا منفی پاس داده شود
   double abs_loss = MathAbs(gross_loss);
   
   if(abs_loss < 0.0000001)
      return (gross_profit > 0.0 ? 9999.0 : 0.0);  // بدون ضرر: عدد بسیار بزرگ

   double abs_profit = MathAbs(gross_profit);
   return abs_profit / abs_loss;
  }

//------------------------------------------------------------------
// محاسبه Expectancy (امید ریاضی)
// [جدید] Expectancy = (WR * AvgWin) - (LR * AvgLoss)
//------------------------------------------------------------------
double AIAnalyzer_Expectancy(const double win_rate_percent,
                             const double avg_win,
                             const double avg_loss)
  {
   double wr = win_rate_percent / 100.0;
   double lr = 1.0 - wr;
   
   return (wr * MathAbs(avg_win)) - (lr * MathAbs(avg_loss));
  }

//------------------------------------------------------------------
// بررسی اینکه نمونه آماری برای نتیجه‌گیری کافی است یا نه
//------------------------------------------------------------------
bool AIAnalyzer_HasEnoughSamples(const int sample_count,
                                  const int minimum_samples)
  {
   if(minimum_samples <= 0)
      return (sample_count > 0);

   return (sample_count >= minimum_samples);
  }

//------------------------------------------------------------------
// ساخت نتیجه آماری پایه
// [اصلاح] محاسبه صحیح تمام معیارها
//------------------------------------------------------------------
bool AIAnalyzer_BuildResult(const int sample_count,
                            const int win_count,
                            const int loss_count,
                            const int breakeven_count,
                            const double gross_profit,
                            const double gross_loss,
                            const int minimum_samples,
                            AIAnalysisResult &result)
  {
   AIAnalyzer_InitResult(result);

   if(sample_count < 0 || win_count < 0 || loss_count < 0)
      return false;

   int total_outcomes = win_count + loss_count + breakeven_count;
   if(total_outcomes > sample_count)
      return false;

   result.sample_count    = sample_count;
   result.win_count       = win_count;
   result.loss_count      = loss_count;
   result.breakeven_count = breakeven_count;
   
   result.gross_profit    = MathAbs(gross_profit);
   result.gross_loss      = MathAbs(gross_loss);
   result.total_profit    = result.gross_profit - result.gross_loss;
   
   result.win_rate        = AIAnalyzer_WinRate(win_count, sample_count);
   result.loss_rate       = AIAnalyzer_WinRate(loss_count, sample_count);

   //--- [اصلاح] محاسبه صحیح average_win و average_loss
   result.average_win  = (win_count > 0 ? result.gross_profit / (double)win_count : 0.0);
   result.average_loss = (loss_count > 0 ? result.gross_loss / (double)loss_count : 0.0);
   
   //--- میانگین هر معامله
   result.average_trade = (sample_count > 0 ? result.total_profit / (double)sample_count : 0.0);
   
   //--- [جدید] محاسبه Expectancy
   result.expectancy = AIAnalyzer_Expectancy(result.win_rate, result.average_win, result.average_loss);
   
   //--- Profit Factor
   result.profit_factor = AIAnalyzer_ProfitFactor(result.gross_profit, result.gross_loss);
   
   result.valid = (sample_count > 0);

   if(!AIAnalyzer_HasEnoughSamples(sample_count, minimum_samples))
     {
      result.conclusion = "نمونه کافی برای نتیجه‌گیری وجود ندارد | Samples=" + 
                          IntegerToString(sample_count) + " | MinRequired=" + 
                          IntegerToString(minimum_samples);
      return true;
     }

   //--- نتیجه‌گیری هوشمند
   if(result.profit_factor >= 1.5 && result.win_rate >= 55.0)
      result.conclusion = "نتیجه آماری قوی و قابل اتکا";
   else if(result.total_profit > 0.0 && result.profit_factor >= 1.0)
      result.conclusion = "نتیجه آماری مثبت";
   else if(MathAbs(result.total_profit) < 0.0000001)
      result.conclusion = "نتیجه آماری خنثی (سر به سر)";
   else
      result.conclusion = "نتیجه آماری منفی";

   return true;
  }

//------------------------------------------------------------------
// تشخیص آماده بودن الگو
//------------------------------------------------------------------
bool AIAnalyzer_IsPatternReady(const int sample_count,
                               const int minimum_samples)
  {
   return AIAnalyzer_HasEnoughSamples(sample_count, minimum_samples);
  }

//------------------------------------------------------------------
// ارزیابی کیفیت پایه الگو
// [اصلاح] محاسبه expectancy و profit_factor و quality_score
//------------------------------------------------------------------
bool AIAnalyzer_EvaluatePattern(AIPattern &pattern,
                                const int minimum_samples,
                                const double minimum_win_rate,
                                const double minimum_profit_factor)
  {
   if(pattern.sample_count <= 0)
     {
      pattern.statistically_ready = false;
      return false;
     }

   pattern.win_rate        = AIAnalyzer_WinRate(pattern.win_count, pattern.sample_count);
   pattern.average_result  = pattern.total_profit / (double)pattern.sample_count;
   pattern.average_win     = (pattern.win_count > 0 ? pattern.gross_profit / (double)pattern.win_count : 0.0);
   pattern.average_loss    = (pattern.loss_count > 0 ? MathAbs(pattern.gross_loss) / (double)pattern.loss_count : 0.0);
   pattern.expectancy      = AIAnalyzer_Expectancy(pattern.win_rate, pattern.average_win, pattern.average_loss);
   pattern.profit_factor   = AIAnalyzer_ProfitFactor(pattern.gross_profit, pattern.gross_loss);

   pattern.statistically_ready = AIAnalyzer_IsPatternReady(pattern.sample_count, minimum_samples);

   if(!pattern.statistically_ready)
     {
      //--- حتی اگر آماده نیست، quality_score را محاسبه می‌کنیم
      pattern.quality_score = AIAnalyzer_CalculateQualityScore(pattern);
      return true;
     }

   bool win_rate_ok = (pattern.win_rate >= minimum_win_rate);
   bool pf_ok = (minimum_profit_factor <= 0.0 || pattern.profit_factor >= minimum_profit_factor);

   pattern.statistically_ready = (win_rate_ok && pf_ok);
   pattern.quality_score = AIAnalyzer_CalculateQualityScore(pattern);
   
   return true;
  }

//------------------------------------------------------------------
// [جدید] محاسبه امتیاز کیفیت الگو (0 تا 100)
//------------------------------------------------------------------
double AIAnalyzer_CalculateQualityScore(const AIPattern &pattern)
  {
   if(pattern.sample_count <= 0)
      return 0.0;
   
   double score = 0.0;
   
   //--- Win Rate (حداکثر 30 امتیاز)
   score += MathMin(30.0, pattern.win_rate * 0.30);
   
   //--- Profit Factor (حداکثر 30 امتیاز)
   if(pattern.profit_factor >= 1.0)
      score += MathMin(30.0, (pattern.profit_factor - 1.0) * 15.0);
   
   //--- Expectancy (حداکثر 20 امتیاز)
   if(pattern.expectancy > 0.0)
      score += MathMin(20.0, pattern.expectancy * 10.0);
   
   //--- تعداد نمونه (حداکثر 20 امتیاز)
   score += MathMin(20.0, pattern.sample_count * 0.5);
   
   return MathMin(100.0, score);
  }

//------------------------------------------------------------------
// مقایسه دو نتیجه آماری
// [اصلاح] امتیازدهی بهتر با weight های مختلف
//------------------------------------------------------------------
int AIAnalyzer_Compare(const AIAnalysisResult &first,
                       const AIAnalysisResult &second)
  {
   //--- اولویت اول: تعداد نمونه (نمونه بیشتر = قابل اتکاتر)
   if(first.sample_count > second.sample_count * 2)
      return 1;
   if(second.sample_count > first.sample_count * 2)
      return -1;
   
   //--- اولویت دوم: Profit Factor (معیار اصلی کیفیت)
   if(first.profit_factor > second.profit_factor + 0.1)
      return 1;
   if(second.profit_factor > first.profit_factor + 0.1)
      return -1;
   
   //--- اولویت سوم: Expectancy
   if(first.expectancy > second.expectancy + 0.01)
      return 1;
   if(second.expectancy > first.expectancy + 0.01)
      return -1;
   
   //--- اولویت چهارم: Win Rate
   if(first.win_rate > second.win_rate + 1.0)
      return 1;
   if(second.win_rate > first.win_rate + 1.0)
      return -1;
   
   //--- اولویت آخر: Total Profit
   if(first.total_profit > second.total_profit)
      return 1;
   if(first.total_profit < second.total_profit)
      return -1;

   return 0;
  }

//------------------------------------------------------------------
// مقایسه دو الگو
//------------------------------------------------------------------
int AIAnalyzer_ComparePatterns(const AIPattern &first,
                               const AIPattern &second)
  {
   //--- اولویت اول: کیفیت
   if(first.quality_score > second.quality_score + 1.0)
      return 1;
   if(second.quality_score > first.quality_score + 1.0)
      return -1;
   
   //--- اولویت دوم: تعداد نمونه
   if(first.sample_count > second.sample_count)
      return 1;
   if(first.sample_count < second.sample_count)
      return -1;
   
   return 0;
  }

//------------------------------------------------------------------
// متن فارسی نتیجه تحلیل
// [اصلاح] نمایش expectancy و average_win/loss
//------------------------------------------------------------------
string AIAnalyzer_ResultToText(const AIAnalysisResult &result)
  {
   string text = "";

   text += "نمونه‌ها: " + IntegerToString(result.sample_count);
   text += " | برد: " + IntegerToString(result.win_count);
   text += " | باخت: " + IntegerToString(result.loss_count);
   text += " | سربه‌سر: " + IntegerToString(result.breakeven_count);
   text += " | Win Rate: " + DoubleToString(result.win_rate, 2) + "%";
   text += " | Total: " + DoubleToString(result.total_profit, 2);
   text += " | AvgWin: " + DoubleToString(result.average_win, 2);
   text += " | AvgLoss: " + DoubleToString(result.average_loss, 2);
   text += " | Expectancy: " + DoubleToString(result.expectancy, 3);
   text += " | PF: " + DoubleToString(result.profit_factor, 2);
   text += " | نتیجه: " + result.conclusion;

   return text;
  }

//------------------------------------------------------------------
// متن فارسی الگو
// [اصلاح] نمایش expectancy و quality_score
//------------------------------------------------------------------
string AIAnalyzer_PatternToText(const AIPattern &pattern)
  {
   string text = "";

   text += "شناسه: " + IntegerToString((int)pattern.pattern_id);
   text += " | توضیح: " + pattern.description;
   text += " | نمونه: " + IntegerToString(pattern.sample_count);
   text += " | برد: " + IntegerToString(pattern.win_count);
   text += " | باخت: " + IntegerToString(pattern.loss_count);
   text += " | Win Rate: " + DoubleToString(pattern.win_rate, 2) + "%";
   text += " | Total: " + DoubleToString(pattern.total_profit, 2);
   text += " | AvgWin: " + DoubleToString(pattern.average_win, 2);
   text += " | AvgLoss: " + DoubleToString(pattern.average_loss, 2);
   text += " | Expectancy: " + DoubleToString(pattern.expectancy, 3);
   text += " | PF: " + DoubleToString(pattern.profit_factor, 2);
   text += " | Quality: " + DoubleToString(pattern.quality_score, 1);
   text += " | آماده: " + (pattern.statistically_ready ? "بله" : "خیر");

   return text;
  }

//------------------------------------------------------------------
// [جدید] آیا الگو قابل معامله است؟
//------------------------------------------------------------------
bool AIAnalyzer_IsPatternTradeable(const AIPattern &pattern,
                                   const double min_quality_score = 60.0)
  {
   if(!pattern.statistically_ready)
      return false;
   
   if(pattern.quality_score < min_quality_score)
      return false;
   
   if(pattern.expectancy <= 0.0)
      return false;
   
   if(pattern.profit_factor < 1.0)
      return false;
   
   return true;
  }

//------------------------------------------------------------------
// [جدید] تشخیص برتری الگو نسبت به رندوم (50%)
//------------------------------------------------------------------
bool AIAnalyzer_HasEdge(const AIPattern &pattern,
                        const double min_win_rate = 52.0,
                        const double min_expectancy = 0.0)
  {
   if(!pattern.statistically_ready)
      return false;
   
   if(pattern.win_rate < min_win_rate)
      return false;
   
   if(pattern.expectancy <= min_expectancy)
      return false;
   
   return true;
  }

//------------------------------------------------------------------
// [جدید] محاسبه Kelly Percentage برای الگو
//------------------------------------------------------------------
double AIAnalyzer_KellyPercent(const AIPattern &pattern)
  {
   if(pattern.win_rate <= 0.0 || pattern.average_loss <= 0.0)
      return 0.0;
   
   double w = pattern.win_rate / 100.0;
   double r = pattern.average_win / pattern.average_loss;
   
   if(r <= 0.0)
      return 0.0;
   
   //--- Kelly = W - [(1 - W) / R]
   double kelly = w - ((1.0 - w) / r);
   
   //--- Half Kelly برای امنیت بیشتر
   return MathMax(0.0, kelly * 0.5) * 100.0;
  }

//+------------------------------------------------------------------+

#endif // __TFLAB_AI_ANALYZER_MQH__