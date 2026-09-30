#ifndef __TFLAB_AI_LEARNING_MQH__
#define __TFLAB_AI_LEARNING_MQH__

//+------------------------------------------------------------------+
//|                         AI_Learning.mqh                          |
//|                         TFlab New EA V.5                             |
//|                                                                  |
//| مسئولیت: یادگیری آماری از داده‌های ثبت‌شده                       |
//|                                                                  |
//| این فایل فقط مسئول نگهداری و استخراج دانش آماری است.            |
//| اجرای معامله واقعی و تغییر منطق هسته ربات در این فایل انجام     |
//| نمی‌شود.                                                        |
//|                                                                  |
//| v2.1 - Fixed result logic + Average R calc + لاگ تشخیصی       |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// نتیجه یک نمونه آموزشی
//====================================================================
enum ENUM_AI_LEARNING_RESULT
  {
   AI_LEARNING_RESULT_UNKNOWN = 0,
   AI_LEARNING_RESULT_WIN,
   AI_LEARNING_RESULT_LOSS,
   AI_LEARNING_RESULT_BREAKEVEN,
   AI_LEARNING_RESULT_NEUTRAL
  };

//====================================================================
// نوع نمونه
//====================================================================
enum ENUM_AI_SAMPLE_TYPE
  {
   AI_SAMPLE_REAL = 0,
   AI_SAMPLE_VIRTUAL,
   AI_SAMPLE_REJECTED_OPPORTUNITY
  };

//====================================================================
// نمونه یادگیری
//====================================================================
struct AILearningSample
  {
   ulong                    sample_id;
   datetime                 decision_time;
   datetime                 close_time;

   ENUM_AI_SAMPLE_TYPE      sample_type;
   ENUM_AI_LEARNING_RESULT  result;

   string                   pattern_key;
   string                   direction;
   string                   market_regime;
   string                   scenario;
   string                   entry_model;

   double                   score;
   double                   confidence;

   double                   entry_price;
   double                   sl_price;
   double                   target_price;

   double                   profit;
   double                   r_multiple;
   double                   max_favorable_excursion;
   double                   max_adverse_excursion;

   int                      duration_minutes;
  };

//====================================================================
// دانش یک الگو
//====================================================================
struct AIPatternKnowledge
  {
   string   pattern_key;

   int      total_samples;
   int      real_samples;
   int      virtual_samples;
   int      rejected_samples;

   int      wins;
   int      losses;
   int      breakevens;
   int      neutrals;

   double   total_profit;
   double   average_profit;
   double   win_rate;
   double   average_r;

   double   best_profit;
   double   worst_profit;

   double   average_mfe;
   double   average_mae;

   int      minimum_samples_required;
   bool     statistically_reliable;

   datetime first_sample_time;
   datetime last_sample_time;
  };

//====================================================================
// خلاصه کل یادگیری
//====================================================================
struct AILearningSummary
  {
   int      total_samples;
   int      valid_samples;
   int      ignored_samples;

   int      wins;
   int      losses;
   int      breakevens;
   int      neutrals;

   int      real_samples;
   int      virtual_samples;
   int      rejected_samples;

   double   total_profit;
   double   average_profit;
   double   win_rate;
   double   average_r;

   int      reliable_patterns;
   int      weak_patterns;

   string   summary_text;
  };

//------------------------------------------------------------------
// تبدیل نتیجه یادگیری به متن فارسی
//------------------------------------------------------------------
string AI_LearningResultToPersian(const ENUM_AI_LEARNING_RESULT result)
  {
   switch(result)
     {
      case AI_LEARNING_RESULT_WIN:        return "موفق";
      case AI_LEARNING_RESULT_LOSS:       return "ناموفق";
      case AI_LEARNING_RESULT_BREAKEVEN:  return "سر‌به‌سر";
      case AI_LEARNING_RESULT_NEUTRAL:    return "خنثی";
      default:                            return "نامشخص";
     }
  }

//------------------------------------------------------------------
// تبدیل نوع نمونه به متن فارسی
//------------------------------------------------------------------
string AI_SampleTypeToPersian(const ENUM_AI_SAMPLE_TYPE type)
  {
   switch(type)
     {
      case AI_SAMPLE_REAL:                  return "معامله واقعی";
      case AI_SAMPLE_VIRTUAL:               return "معامله مجازی";
      case AI_SAMPLE_REJECTED_OPPORTUNITY:  return "فرصت ردشده";
      default:                              return "نامشخص";
     }
  }

//------------------------------------------------------------------
// مقداردهی نمونه
//------------------------------------------------------------------
void AI_LearningSampleInit(AILearningSample &sample)
  {
   sample.sample_id                = 0;
   sample.decision_time            = 0;
   sample.close_time               = 0;

   sample.sample_type              = AI_SAMPLE_REAL;
   sample.result                   = AI_LEARNING_RESULT_UNKNOWN;

   sample.pattern_key              = "";
   sample.direction                = "";
   sample.market_regime            = "";
   sample.scenario                 = "";
   sample.entry_model              = "";

   sample.score                    = 0.0;
   sample.confidence               = 0.0;

   sample.entry_price              = 0.0;
   sample.sl_price                 = 0.0;
   sample.target_price             = 0.0;

   sample.profit                   = 0.0;
   sample.r_multiple               = 0.0;
   sample.max_favorable_excursion  = 0.0;
   sample.max_adverse_excursion    = 0.0;

   sample.duration_minutes         = 0;
  }

//------------------------------------------------------------------
// مقداردهی دانش الگو
//------------------------------------------------------------------
void AI_PatternKnowledgeInit(AIPatternKnowledge &knowledge)
  {
   knowledge.pattern_key             = "";

   knowledge.total_samples           = 0;
   knowledge.real_samples            = 0;
   knowledge.virtual_samples         = 0;
   knowledge.rejected_samples        = 0;

   knowledge.wins                    = 0;
   knowledge.losses                  = 0;
   knowledge.breakevens              = 0;
   knowledge.neutrals                = 0;

   knowledge.total_profit            = 0.0;
   knowledge.average_profit          = 0.0;
   knowledge.win_rate                = 0.0;
   knowledge.average_r               = 0.0;

   knowledge.best_profit             = 0.0;
   knowledge.worst_profit            = 0.0;

   knowledge.average_mfe             = 0.0;
   knowledge.average_mae             = 0.0;

   knowledge.minimum_samples_required = 20;
   knowledge.statistically_reliable  = false;

   knowledge.first_sample_time       = 0;
   knowledge.last_sample_time        = 0;
  }

//------------------------------------------------------------------
// مقداردهی خلاصه یادگیری
//------------------------------------------------------------------
void AI_LearningSummaryInit(AILearningSummary &summary)
  {
   summary.total_samples       = 0;
   summary.valid_samples       = 0;
   summary.ignored_samples     = 0;

   summary.wins                = 0;
   summary.losses              = 0;
   summary.breakevens          = 0;
   summary.neutrals            = 0;

   summary.real_samples        = 0;
   summary.virtual_samples     = 0;
   summary.rejected_samples    = 0;

   summary.total_profit        = 0.0;
   summary.average_profit      = 0.0;
   summary.win_rate            = 0.0;
   summary.average_r           = 0.0;

   summary.reliable_patterns   = 0;
   summary.weak_patterns       = 0;

   summary.summary_text        = "";
  }

//------------------------------------------------------------------
// تعیین نتیجه بر اساس سود
// [اصلاح] منطق صحیح: ابتدا breakeven را چک می‌کنیم
//------------------------------------------------------------------
ENUM_AI_LEARNING_RESULT AI_LearningResultFromProfit(const double profit,
                                                    const double tolerance)
  {
   //--- [اصلاح] ابتدا breakeven را بررسی می‌کنیم (مقدار نزدیک به صفر)
   if(MathAbs(profit) <= tolerance)
      return AI_LEARNING_RESULT_BREAKEVEN;

   //--- سپس سود یا زیان
   if(profit > tolerance)
      return AI_LEARNING_RESULT_WIN;

   if(profit < -tolerance)
      return AI_LEARNING_RESULT_LOSS;

   return AI_LEARNING_RESULT_UNKNOWN;
  }

//------------------------------------------------------------------
// اعتبارسنجی نمونه
//------------------------------------------------------------------
bool AI_LearningSampleIsValid(const AILearningSample &sample)
  {
   if(sample.sample_id == 0)
      return false;

   if(sample.decision_time <= 0)
      return false;

   if(sample.pattern_key == "")
      return false;

   if(sample.result == AI_LEARNING_RESULT_UNKNOWN)
      return false;

   if(!MathIsValidNumber(sample.profit))
      return false;

   if(!MathIsValidNumber(sample.r_multiple))
      return false;

   return true;
  }

//------------------------------------------------------------------
// اضافه کردن نمونه به دانش الگو
//------------------------------------------------------------------
bool AI_LearningAddSample(AIPatternKnowledge &knowledge,
                          const AILearningSample &sample)
  {
   if(!AI_LearningSampleIsValid(sample))
      return false;

   if(knowledge.pattern_key == "")
      knowledge.pattern_key = sample.pattern_key;

   if(knowledge.pattern_key != sample.pattern_key)
      return false;

   if(knowledge.total_samples == 0)
     {
      knowledge.best_profit       = sample.profit;
      knowledge.worst_profit      = sample.profit;
      knowledge.first_sample_time = sample.decision_time;
     }

   //--- میانگین‌های تجمعی
   const int previous_count = knowledge.total_samples;
   const int new_count      = previous_count + 1;

   knowledge.total_samples = new_count;

   if(sample.sample_type == AI_SAMPLE_REAL)
      knowledge.real_samples++;
   else if(sample.sample_type == AI_SAMPLE_VIRTUAL)
      knowledge.virtual_samples++;
   else if(sample.sample_type == AI_SAMPLE_REJECTED_OPPORTUNITY)
      knowledge.rejected_samples++;

   switch(sample.result)
     {
      case AI_LEARNING_RESULT_WIN:        knowledge.wins++;       break;
      case AI_LEARNING_RESULT_LOSS:       knowledge.losses++;     break;
      case AI_LEARNING_RESULT_BREAKEVEN:  knowledge.breakevens++; break;
      case AI_LEARNING_RESULT_NEUTRAL:    knowledge.neutrals++;   break;
      default: break;
     }

   knowledge.total_profit += sample.profit;

   if(sample.profit > knowledge.best_profit)
      knowledge.best_profit = sample.profit;

   if(sample.profit < knowledge.worst_profit)
      knowledge.worst_profit = sample.profit;

   knowledge.average_profit = knowledge.total_profit / knowledge.total_samples;

   knowledge.win_rate = ((double)knowledge.wins / (double)knowledge.total_samples) * 100.0;

   knowledge.average_r =
      ((knowledge.average_r * previous_count) + sample.r_multiple) / new_count;

   knowledge.average_mfe =
      ((knowledge.average_mfe * previous_count) + sample.max_favorable_excursion) / new_count;

   knowledge.average_mae =
      ((knowledge.average_mae * previous_count) + sample.max_adverse_excursion) / new_count;

   knowledge.last_sample_time = sample.decision_time;

   return true;
  }

//------------------------------------------------------------------
// ارزیابی اعتبار آماری
//------------------------------------------------------------------
bool AI_LearningEvaluateReliability(AIPatternKnowledge &knowledge,
                                    const int minimum_samples,
                                    const double minimum_win_rate)
  {
   if(minimum_samples < 1)
     {
      knowledge.statistically_reliable = false;
      return false;
     }

   knowledge.minimum_samples_required = minimum_samples;

   if(knowledge.total_samples < minimum_samples)
     {
      knowledge.statistically_reliable = false;
      return false;
     }

   if(knowledge.win_rate < minimum_win_rate)
     {
      knowledge.statistically_reliable = false;
      return false;
     }

   knowledge.statistically_reliable = true;
   return true;
  }

//------------------------------------------------------------------
// ساخت خلاصه از یک الگو
//------------------------------------------------------------------
void AI_LearningBuildSummary(const AIPatternKnowledge &knowledge,
                             AILearningSummary &summary)
  {
   summary.total_samples     += knowledge.total_samples;
   summary.valid_samples     += knowledge.total_samples;

   summary.real_samples      += knowledge.real_samples;
   summary.virtual_samples   += knowledge.virtual_samples;
   summary.rejected_samples  += knowledge.rejected_samples;

   summary.wins              += knowledge.wins;
   summary.losses            += knowledge.losses;
   summary.breakevens        += knowledge.breakevens;
   summary.neutrals          += knowledge.neutrals;

   summary.total_profit      += knowledge.total_profit;

   //--- [اصلاح] محاسبه weighted average_r
   if(knowledge.total_samples > 0)
      summary.average_r += knowledge.average_r * knowledge.total_samples;

   if(knowledge.statistically_reliable)
      summary.reliable_patterns++;
   else
      summary.weak_patterns++;
  }

//------------------------------------------------------------------
// نهایی‌سازی خلاصه
// [اصلاح] محاسبه صحیح average_r
//------------------------------------------------------------------
void AI_LearningFinalizeSummary(AILearningSummary &summary)
  {
   if(summary.total_samples > 0)
     {
      summary.average_profit = summary.total_profit / summary.total_samples;
      summary.win_rate = ((double)summary.wins / (double)summary.total_samples) * 100.0;
      
      //--- [اصلاح] محاسبه صحیح average_r به صورت weighted
      summary.average_r = summary.average_r / summary.total_samples;
     }
   else
     {
      summary.average_profit = 0.0;
      summary.win_rate       = 0.0;
      summary.average_r      = 0.0;
     }

   summary.summary_text = "";

   summary.summary_text += "نمونه‌ها: " + IntegerToString(summary.total_samples);
   summary.summary_text += " | واقعی: " + IntegerToString(summary.real_samples);
   summary.summary_text += " | مجازی: " + IntegerToString(summary.virtual_samples);
   summary.summary_text += " | فرصت ردشده: " + IntegerToString(summary.rejected_samples);
   summary.summary_text += " | موفق: " + IntegerToString(summary.wins);
   summary.summary_text += " | ناموفق: " + IntegerToString(summary.losses);
   summary.summary_text += " | سر‌به‌سر: " + IntegerToString(summary.breakevens);
   summary.summary_text += " | نرخ موفقیت: " + DoubleToString(summary.win_rate, 2) + "%";
   summary.summary_text += " | سود خالص: " + DoubleToString(summary.total_profit, 2);
   summary.summary_text += " | میانگین R: " + DoubleToString(summary.average_r, 2);
   summary.summary_text += " | الگوهای قابل اتکا: " + IntegerToString(summary.reliable_patterns);
   summary.summary_text += " | الگوهای ضعیف: " + IntegerToString(summary.weak_patterns);
  }

//------------------------------------------------------------------
// ساخت کلید الگو
//------------------------------------------------------------------
string AI_LearningBuildPatternKey(const string direction,
                                   const string market_regime,
                                   const string scenario,
                                   const string entry_model)
  {
   string key = direction;
   key += "|";
   key += market_regime;
   key += "|";
   key += scenario;
   key += "|";
   key += entry_model;

   return key;
  }

//------------------------------------------------------------------
// مقایسه دو نمونه از نظر الگوی معاملاتی
//------------------------------------------------------------------
bool AI_LearningSamePattern(const AILearningSample &a,
                            const AILearningSample &b)
  {
   if(a.pattern_key == "" || b.pattern_key == "")
      return false;

   return (a.pattern_key == b.pattern_key);
  }

//------------------------------------------------------------------
// تعیین بهتر بودن یک الگو نسبت به الگوی دیگر
// [اصلاح] رفتار صحیح وقتی هر دو غیرقابل اتکا هستند
//------------------------------------------------------------------
bool AI_LearningIsBetter(const AIPatternKnowledge &a,
                         const AIPatternKnowledge &b)
  {
   //--- [اصلاح] اگر هر دو غیرقابل اتکا هستند، الگوی با نمونه بیشتر بهتر است
   if(!a.statistically_reliable && !b.statistically_reliable)
      return (a.total_samples > b.total_samples);

   if(!a.statistically_reliable)
      return false;

   if(!b.statistically_reliable)
      return true;

   //--- هر دو قابل اتکا هستند، مقایسه بر اساس R
   if(a.average_r > b.average_r)
      return true;

   if(a.average_r < b.average_r)
      return false;

   //--- R برابر، مقایسه win rate
   if(a.win_rate > b.win_rate)
      return true;

   if(a.win_rate < b.win_rate)
      return false;

   //--- Win rate برابر، مقایسه average profit
   return (a.average_profit > b.average_profit);
  }

//------------------------------------------------------------------
// تولید یافته آماری
//------------------------------------------------------------------
string AI_LearningGenerateFinding(const AIPatternKnowledge &knowledge)
  {
   if(knowledge.pattern_key == "")
      return "الگوی مشخصی برای تحلیل وجود ندارد";

   if(knowledge.total_samples <= 0)
      return "نمونه کافی برای تحلیل وجود ندارد";

   string text = "";

   text += "الگو: " + knowledge.pattern_key;
   text += " | نمونه: " + IntegerToString(knowledge.total_samples);
   text += " | موفقیت: " + DoubleToString(knowledge.win_rate, 2) + "%";
   text += " | میانگین سود: " + DoubleToString(knowledge.average_profit, 2);
   text += " | میانگین R: " + DoubleToString(knowledge.average_r, 2);

   if(knowledge.statistically_reliable)
      text += " | وضعیت: قابل اتکاتر";
   else
      text += " | وضعیت: هنوز نمونه کافی نیست";

   return text;
  }

//------------------------------------------------------------------
// آیا دانش برای پیشنهاد قابل استفاده است؟
//------------------------------------------------------------------
bool AI_LearningCanBeUsedForAdvice(const AIPatternKnowledge &knowledge)
  {
   return knowledge.statistically_reliable;
  }

//------------------------------------------------------------------
// مقایسه الگوی واقعی با الگوی مجازی
//------------------------------------------------------------------
void AI_LearningCompareKnowledge(const AIPatternKnowledge &real_knowledge,
                                 const AIPatternKnowledge &virtual_knowledge,
                                 double &profit_difference,
                                 double &winrate_difference,
                                 double &r_difference)
  {
   profit_difference = virtual_knowledge.average_profit - real_knowledge.average_profit;
   winrate_difference = virtual_knowledge.win_rate - real_knowledge.win_rate;
   r_difference = virtual_knowledge.average_r - real_knowledge.average_r;
  }

//------------------------------------------------------------------
// بازنشانی دانش
//------------------------------------------------------------------
void AI_LearningReset(AIPatternKnowledge &knowledge)
  {
   AI_PatternKnowledgeInit(knowledge);
  }

//------------------------------------------------------------------
// بازنشانی خلاصه
//------------------------------------------------------------------
void AI_LearningResetSummary(AILearningSummary &summary)
  {
   AI_LearningSummaryInit(summary);
  }

//------------------------------------------------------------------
// [جدید] تبدیل دانش الگو به متن برای گزارش
//------------------------------------------------------------------
string AI_LearningKnowledgeToText(const AIPatternKnowledge &knowledge)
  {
   string text = "";
   
   text += "الگو: " + knowledge.pattern_key;
   text += " | کل نمونه: " + IntegerToString(knowledge.total_samples);
   text += " | واقعی: " + IntegerToString(knowledge.real_samples);
   text += " | مجازی: " + IntegerToString(knowledge.virtual_samples);
   text += " | برد: " + IntegerToString(knowledge.wins);
   text += " | باخت: " + IntegerToString(knowledge.losses);
   text += " | سر‌به‌سر: " + IntegerToString(knowledge.breakevens);
   text += " | نرخ برد: " + DoubleToString(knowledge.win_rate, 2) + "%";
   text += " | سود کل: " + DoubleToString(knowledge.total_profit, 2);
   text += " | میانگین سود: " + DoubleToString(knowledge.average_profit, 2);
   text += " | میانگین R: " + DoubleToString(knowledge.average_r, 2);
   text += " | بهترین سود: " + DoubleToString(knowledge.best_profit, 2);
   text += " | بدترین ضرر: " + DoubleToString(knowledge.worst_profit, 2);
   text += " | MFE: " + DoubleToString(knowledge.average_mfe, 2);
   text += " | MAE: " + DoubleToString(knowledge.average_mae, 2);
   text += " | قابل اتکا: " + (knowledge.statistically_reliable ? "بله" : "خیر");
   
   return text;
  }

//------------------------------------------------------------------
// [جدید] تبدیل نمونه به متن برای گزارش
//------------------------------------------------------------------
string AI_LearningSampleToText(const AILearningSample &sample)
  {
   string text = "";
   
   text += "ID: " + (string)sample.sample_id;
   text += " | نوع: " + AI_SampleTypeToPersian(sample.sample_type);
   text += " | نتیجه: " + AI_LearningResultToPersian(sample.result);
   text += " | الگو: " + sample.pattern_key;
   text += " | زمان: " + TimeToString(sample.decision_time, TIME_DATE|TIME_SECONDS);
   text += " | سود: " + DoubleToString(sample.profit, 2);
   text += " | R: " + DoubleToString(sample.r_multiple, 2);
   text += " | MFE: " + DoubleToString(sample.max_favorable_excursion, 2);
   text += " | MAE: " + DoubleToString(sample.max_adverse_excursion, 2);
   text += " | مدت: " + IntegerToString(sample.duration_minutes) + " دقیقه";
   
   return text;
  }

//+------------------------------------------------------------------+

#endif // __TFLAB_AI_LEARNING_MQH__