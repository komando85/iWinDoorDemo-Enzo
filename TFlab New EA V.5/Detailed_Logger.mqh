#ifndef __TFLAB_DETAILED_LOGGER_MQH__
#define __TFLAB_DETAILED_LOGGER_MQH__

//+------------------------------------------------------------------+
//|                    Detailed_Logger.mqh                          |
//|                    TFlab New EA V.5                                 |
//|                                                                  |
//| مسئولیت: ثبت گزارش جزئیات کامل اجرای ربات                       |
//|                                                                  |
//| این فایل فقط برای ثبت و ذخیره رویدادهاست.                       |
//| هیچ تصمیم معاملاتی، محاسبه ریسک یا اجرای سفارش انجام نمی‌دهد.   |
//|                                                                  |
//| v2.1 - Fixed FILE_CSV bug + FILE_COMMON + لاگ تشخیصی           |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// سطح اهمیت رویداد
//====================================================================
enum ENUM_DETAILED_LOG_LEVEL
  {
   DLOG_LEVEL_DEBUG = 0,
   DLOG_LEVEL_INFO,
   DLOG_LEVEL_WARNING,
   DLOG_LEVEL_ERROR,
   DLOG_LEVEL_CRITICAL
  };

//====================================================================
// گروه رویداد
//====================================================================
enum ENUM_DETAILED_LOG_CATEGORY
  {
   DLOG_CATEGORY_SYSTEM = 0,
   DLOG_CATEGORY_MARKET,
   DLOG_CATEGORY_STRUCTURE,
   DLOG_CATEGORY_SCENARIO,
   DLOG_CATEGORY_ENTRY,
   DLOG_CATEGORY_ORDER,
   DLOG_CATEGORY_RISK,
   DLOG_CATEGORY_TRADE,
   DLOG_CATEGORY_AI,
   DLOG_CATEGORY_REPORT,
   DLOG_CATEGORY_ERROR
  };

//====================================================================
// ساختار یک رکورد گزارش
//====================================================================
struct DetailedLogRecord
  {
   long                       sequence;
   datetime                   time;
   ENUM_DETAILED_LOG_LEVEL    level;
   ENUM_DETAILED_LOG_CATEGORY category;

   string symbol;
   ENUM_TIMEFRAMES timeframe;

   string event_name;
   string stage;
   string direction;
   string status;
   string message;

   double value1;
   double value2;
   double value3;
   double value4;

   double price;
   double volume;
   double sl;
   double tp;

   ulong scenario_id;
   ulong order_ticket;
   ulong position_ticket;
  };

//====================================================================
// تنظیمات runtime گزارشگر
//====================================================================
struct DetailedLoggerConfig
  {
   bool enabled;
   bool write_to_file;
   bool write_to_terminal;
   bool include_debug;
   bool include_m1_monitoring;
   bool include_non_trade_events;

   ENUM_DETAILED_LOG_LEVEL minimum_level;

   string file_prefix;
   string file_name;
  };

//====================================================================
// وضعیت گزارشگر
//====================================================================
struct DetailedLoggerState
  {
   bool initialized;
   long sequence;
   datetime last_event_time;
   long event_count;
   long error_count;
   long warning_count;
   long file_write_failures;

   string active_symbol;
   string last_stage;
   string last_event;
  };

//====================================================================
// تبدیل سطح به فارسی
//====================================================================
string DetailedLogger_LevelToPersian(const ENUM_DETAILED_LOG_LEVEL level)
  {
   switch(level)
     {
      case DLOG_LEVEL_DEBUG:    return "جزئیات";
      case DLOG_LEVEL_INFO:     return "اطلاعات";
      case DLOG_LEVEL_WARNING:  return "هشدار";
      case DLOG_LEVEL_ERROR:    return "خطا";
      case DLOG_LEVEL_CRITICAL: return "بحرانی";
      default:                  return "نامشخص";
     }
  }

//====================================================================
// تبدیل گروه به فارسی
//====================================================================
string DetailedLogger_CategoryToPersian(const ENUM_DETAILED_LOG_CATEGORY category)
  {
   switch(category)
     {
      case DLOG_CATEGORY_SYSTEM:     return "سیستم";
      case DLOG_CATEGORY_MARKET:     return "بازار";
      case DLOG_CATEGORY_STRUCTURE:  return "ساختار";
      case DLOG_CATEGORY_SCENARIO:   return "سناریو";
      case DLOG_CATEGORY_ENTRY:      return "ورود";
      case DLOG_CATEGORY_ORDER:      return "سفارش";
      case DLOG_CATEGORY_RISK:       return "ریسک";
      case DLOG_CATEGORY_TRADE:      return "معامله";
      case DLOG_CATEGORY_AI:         return "هوش مصنوعی";
      case DLOG_CATEGORY_REPORT:     return "گزارش";
      case DLOG_CATEGORY_ERROR:      return "خطا";
      default:                       return "نامشخص";
     }
  }

//====================================================================
// نام فارسی تایم‌فریم برای گزارش
//====================================================================
string DetailedLogger_TimeframeToPersian(const ENUM_TIMEFRAMES timeframe)
  {
   switch(timeframe)
     {
      case PERIOD_M1:  return "یک دقیقه";
      case PERIOD_M2:  return "دو دقیقه";
      case PERIOD_M3:  return "سه دقیقه";
      case PERIOD_M4:  return "چهار دقیقه";
      case PERIOD_M5:  return "پنج دقیقه";
      case PERIOD_M6:  return "شش دقیقه";
      case PERIOD_M10: return "ده دقیقه";
      case PERIOD_M12: return "دوازده دقیقه";
      case PERIOD_M15: return "پانزده دقیقه";
      case PERIOD_M20: return "بیست دقیقه";
      case PERIOD_M30: return "سی دقیقه";
      case PERIOD_H1:  return "یک ساعت";
      case PERIOD_H2:  return "دو ساعت";
      case PERIOD_H3:  return "سه ساعت";
      case PERIOD_H4:  return "چهار ساعت";
      case PERIOD_H6:  return "شش ساعت";
      case PERIOD_H8:  return "هشت ساعت";
      case PERIOD_H12: return "دوازده ساعت";
      case PERIOD_D1:  return "روزانه";
      case PERIOD_W1:  return "هفتگی";
      case PERIOD_MN1: return "ماهانه";
      default:         return "فعلی";
     }
  }

//====================================================================
// مقداردهی تنظیمات پیش‌فرض
//====================================================================
void DetailedLogger_ConfigInit(DetailedLoggerConfig &config)
  {
   config.enabled               = true;
   config.write_to_file         = true;
   config.write_to_terminal     = true;
   config.include_debug         = true;
   config.include_m1_monitoring = true;
   config.include_non_trade_events = true;
   config.minimum_level         = DLOG_LEVEL_DEBUG;
   config.file_prefix           = "TFlab_NewEA";
   config.file_name             = "Detailed_Report.csv";
  }

//====================================================================
// مقداردهی وضعیت
//====================================================================
void DetailedLogger_StateInit(DetailedLoggerState &state)
  {
   state.initialized      = false;
   state.sequence         = 0;
   state.last_event_time  = 0;
   state.event_count      = 0;
   state.error_count      = 0;
   state.warning_count    = 0;
   state.file_write_failures = 0;
   state.active_symbol    = "";
   state.last_stage       = "";
   state.last_event       = "";
  }

//====================================================================
// تبدیل ساختار لاگ به متن خوانا
//====================================================================
string DetailedLogger_BuildText(const DetailedLogRecord &record)
  {
   string text = "";

   text += "[" + TimeToString(record.time, TIME_DATE|TIME_SECONDS) + "]";
   text += " [" + DetailedLogger_LevelToPersian(record.level) + "]";
   text += " [" + DetailedLogger_CategoryToPersian(record.category) + "]";

   if(record.symbol != "")
      text += " [" + record.symbol + "]";

   if(record.timeframe != PERIOD_CURRENT)
      text += " [" + DetailedLogger_TimeframeToPersian(record.timeframe) + "]";

   if(record.stage != "")
      text += " | مرحله: " + record.stage;

   if(record.event_name != "")
      text += " | رویداد: " + record.event_name;

   if(record.direction != "")
      text += " | جهت: " + record.direction;

   if(record.status != "")
      text += " | وضعیت: " + record.status;

   if(record.message != "")
      text += " | " + record.message;

   return text;
  }

//====================================================================
// Escape برای CSV
//====================================================================
string DetailedLogger_CsvEscape(const string value)
  {
   string result = value;
   StringReplace(result, "\"", "\"\"");
   return "\"" + result + "\"";
  }

//====================================================================
// تبدیل رکورد به خط CSV
// [اصلاح] استفاده از 2 رقم اعشار برای خوانایی بهتر
//====================================================================
string DetailedLogger_BuildCsvRow(const DetailedLogRecord &record)
  {
   string row = "";

   row += (string)record.sequence + ";";
   row += TimeToString(record.time, TIME_DATE|TIME_SECONDS) + ";";
   row += DetailedLogger_CsvEscape(DetailedLogger_LevelToPersian(record.level)) + ";";
   row += DetailedLogger_CsvEscape(DetailedLogger_CategoryToPersian(record.category)) + ";";
   row += DetailedLogger_CsvEscape(record.symbol) + ";";
   row += DetailedLogger_CsvEscape(DetailedLogger_TimeframeToPersian(record.timeframe)) + ";";
   row += DetailedLogger_CsvEscape(record.event_name) + ";";
   row += DetailedLogger_CsvEscape(record.stage) + ";";
   row += DetailedLogger_CsvEscape(record.direction) + ";";
   row += DetailedLogger_CsvEscape(record.status) + ";";
   row += DetailedLogger_CsvEscape(record.message) + ";";

   row += DoubleToString(record.value1, 4) + ";";
   row += DoubleToString(record.value2, 4) + ";";
   row += DoubleToString(record.value3, 4) + ";";
   row += DoubleToString(record.value4, 4) + ";";

   row += DoubleToString(record.price, _Digits) + ";";
   row += DoubleToString(record.volume, 4) + ";";
   row += DoubleToString(record.sl, _Digits) + ";";
   row += DoubleToString(record.tp, _Digits) + ";";

   row += (string)record.scenario_id + ";";
   row += (string)record.order_ticket + ";";
   row += (string)record.position_ticket;

   return row;
  }

//====================================================================
// ساخت هدر CSV
//====================================================================
string DetailedLogger_CsvHeader()
  {
   return "شماره;زمان;سطح;گروه;نماد;تایم‌فریم;رویداد;مرحله;جهت;وضعیت;پیام;مقدار1;مقدار2;مقدار3;مقدار4;قیمت;حجم;حدضرر;حدسود;شناسه سناریو;تیکت سفارش;تیکت معامله";
  }

//====================================================================
// آماده‌سازی ساختار رکورد
//====================================================================
void DetailedLogger_RecordInit(DetailedLogRecord &record)
  {
   record.sequence        = 0;
   record.time            = 0;
   record.level           = DLOG_LEVEL_INFO;
   record.category        = DLOG_CATEGORY_SYSTEM;
   record.symbol          = "";
   record.timeframe       = PERIOD_CURRENT;
   record.event_name      = "";
   record.stage           = "";
   record.direction       = "";
   record.status          = "";
   record.message         = "";
   record.value1          = 0.0;
   record.value2          = 0.0;
   record.value3          = 0.0;
   record.value4          = 0.0;
   record.price           = 0.0;
   record.volume          = 0.0;
   record.sl              = 0.0;
   record.tp              = 0.0;
   record.scenario_id     = 0;
   record.order_ticket    = 0;
   record.position_ticket = 0;
  }

//====================================================================
// بررسی قابل ثبت بودن سطح
//====================================================================
bool DetailedLogger_ShouldWrite(const DetailedLoggerConfig &config,
                                const ENUM_DETAILED_LOG_LEVEL level)
  {
   if(!config.enabled)
      return false;

   if(level < config.minimum_level)
      return false;

   if(level == DLOG_LEVEL_DEBUG && !config.include_debug)
      return false;

   return true;
  }

//====================================================================
// ایجاد پوشه/فایل گزارش
// [اصلاح حیاتی] استفاده از FILE_TXT به جای FILE_CSV + FILE_COMMON
//====================================================================
bool DetailedLogger_EnsureFile(const DetailedLoggerConfig &config)
  {
   if(!config.write_to_file)
      return true;

   //--- [اصلاح] استفاده از FILE_COMMON برای ذخیره دائمی + FILE_TXT برای نوشتن صحیح
   bool file_exists = FileIsExist(config.file_name, FILE_COMMON);
   
   ResetLastError();
   int handle = FileOpen(config.file_name,
                         FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_UNICODE,
                         ';');

   if(handle == INVALID_HANDLE)
     {
      int err = GetLastError();
      Print(
         "[DETAILED LOGGER] FILE ERROR | Cannot open file: ",
         config.file_name,
         " | Error=", err
      );
      return false;
     }

   //--- فقط اگر فایل جدید است، header را بنویس
   if(!file_exists || FileSize(handle) == 0)
     {
      FileWriteString(handle, DetailedLogger_CsvHeader() + "\r\n");
      Print(
         "[DETAILED LOGGER] FILE CREATED | ",
         config.file_name,
         " | Location=Common\\Files"
      );
     }

   FileClose(handle);
   return true;
  }

//====================================================================
// مقداردهی و آماده‌سازی گزارشگر
//====================================================================
bool DetailedLogger_Init(const string symbol,
                         DetailedLoggerConfig &config,
                         DetailedLoggerState &state)
  {
   DetailedLogger_ConfigInit(config);
   DetailedLogger_StateInit(state);

   state.active_symbol = symbol;

   if(!config.enabled)
     {
      state.initialized = true;
      return true;
     }

   if(!DetailedLogger_EnsureFile(config) && config.write_to_file)
     {
      state.initialized = false;
      return false;
     }

   state.initialized = true;
   return true;
  }

//====================================================================
// بستن گزارشگر
//====================================================================
void DetailedLogger_Shutdown(DetailedLoggerState &state)
  {
   if(state.initialized)
     {
      Print(
         "[DETAILED LOGGER] SHUTDOWN",
         " | TotalEvents=", state.event_count,
         " | Errors=", state.error_count,
         " | Warnings=", state.warning_count,
         " | FileFailures=", state.file_write_failures
      );
     }
   state.initialized = false;
  }

//====================================================================
// ثبت یک رکورد
// [اصلاح] استفاده از FILE_TXT به جای FILE_CSV + لاگ تشخیصی
//====================================================================
bool DetailedLogger_Write(const DetailedLogRecord &log_input,
                         DetailedLoggerConfig &config,
                         DetailedLoggerState &state)
  {
   if(!DetailedLogger_ShouldWrite(config, log_input.level))
      return false;

   if(!state.initialized)
      return false;

   DetailedLogRecord record = log_input;

   state.sequence++;
   state.event_count++;

   record.sequence = state.sequence;

   if(record.time <= 0)
      record.time = TimeCurrent();

   state.last_event_time = record.time;
   state.last_stage      = record.stage;
   state.last_event      = record.event_name;

   if(record.level == DLOG_LEVEL_ERROR ||
      record.level == DLOG_LEVEL_CRITICAL)
      state.error_count++;

   if(record.level == DLOG_LEVEL_WARNING)
      state.warning_count++;

   bool written = false;

   if(config.write_to_terminal)
     {
      Print(DetailedLogger_BuildText(record));
      written = true;
     }

   if(config.write_to_file)
     {
      ResetLastError();
      //--- [اصلاح حیاتی] استفاده از FILE_TXT + FILE_COMMON به جای FILE_CSV
      int handle = FileOpen(config.file_name,
                            FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_UNICODE,
                            ';');

      if(handle != INVALID_HANDLE)
        {
         FileSeek(handle, 0, SEEK_END);
         FileWriteString(handle, DetailedLogger_BuildCsvRow(record) + "\r\n");
         FileClose(handle);
         written = true;
        }
      else
        {
         state.file_write_failures++;
         int err = GetLastError();
         //--- فقط هر 10 بار یک بار لاگ بزن تا لاگ پر نشود
         if(state.file_write_failures % 10 == 1)
           {
            Print(
               "[DETAILED LOGGER] WRITE FAIL",
               " | File=", config.file_name,
               " | Error=", err,
               " | TotalFailures=", state.file_write_failures
            );
           }
        }
     }

   return written;
  }

//====================================================================
// تابع کمکی برای ایجاد رکورد رویداد
//====================================================================
bool DetailedLogger_Log(const ENUM_DETAILED_LOG_LEVEL level,
                        const ENUM_DETAILED_LOG_CATEGORY category,
                        const string event_name,
                        const string stage,
                        const string direction,
                        const string status,
                        const string message,
                        const string symbol,
                        const ENUM_TIMEFRAMES timeframe,
                        const double value1,
                        const double value2,
                        const double value3,
                        const double value4,
                        const double price,
                        const double volume,
                        const double sl,
                        const double tp,
                        const ulong scenario_id,
                        const ulong order_ticket,
                        const ulong position_ticket,
                        DetailedLoggerConfig &config,
                        DetailedLoggerState &state)
  {
   DetailedLogRecord record;
   DetailedLogger_RecordInit(record);

   record.time            = TimeCurrent();
   record.level           = level;
   record.category        = category;
   record.symbol          = symbol;
   record.timeframe       = timeframe;
   record.event_name      = event_name;
   record.stage           = stage;
   record.direction       = direction;
   record.status          = status;
   record.message         = message;
   record.value1          = value1;
   record.value2          = value2;
   record.value3          = value3;
   record.value4          = value4;
   record.price           = price;
   record.volume          = volume;
   record.sl              = sl;
   record.tp              = tp;
   record.scenario_id     = scenario_id;
   record.order_ticket    = order_ticket;
   record.position_ticket = position_ticket;

   return DetailedLogger_Write(record, config, state);
  }

//====================================================================
// میانبر برای INFO
//====================================================================
bool DetailedLogger_Info(const ENUM_DETAILED_LOG_CATEGORY category,
                         const string event_name,
                         const string stage,
                         const string message,
                         const string symbol,
                         const ENUM_TIMEFRAMES timeframe,
                         DetailedLoggerConfig &config,
                         DetailedLoggerState &state)
  {
   return DetailedLogger_Log(DLOG_LEVEL_INFO,
                             category,
                             event_name,
                             stage,
                             "",
                             "",
                             message,
                             symbol,
                             timeframe,
                             0.0, 0.0, 0.0, 0.0,
                             0.0, 0.0, 0.0, 0.0,
                             0, 0, 0,
                             config,
                             state);
  }

//====================================================================
// میانبر برای هشدار
//====================================================================
bool DetailedLogger_Warning(const ENUM_DETAILED_LOG_CATEGORY category,
                            const string event_name,
                            const string stage,
                            const string message,
                            const string symbol,
                            const ENUM_TIMEFRAMES timeframe,
                            DetailedLoggerConfig &config,
                            DetailedLoggerState &state)
  {
   return DetailedLogger_Log(DLOG_LEVEL_WARNING,
                             category,
                             event_name,
                             stage,
                             "",
                             "هشدار",
                             message,
                             symbol,
                             timeframe,
                             0.0, 0.0, 0.0, 0.0,
                             0.0, 0.0, 0.0, 0.0,
                             0, 0, 0,
                             config,
                             state);
  }

//====================================================================
// میانبر برای خطا
//====================================================================
bool DetailedLogger_Error(const ENUM_DETAILED_LOG_CATEGORY category,
                          const string event_name,
                          const string stage,
                          const string message,
                          const string symbol,
                          const ENUM_TIMEFRAMES timeframe,
                          DetailedLoggerConfig &config,
                          DetailedLoggerState &state)
  {
   return DetailedLogger_Log(DLOG_LEVEL_ERROR,
                             category,
                             event_name,
                             stage,
                             "",
                             "خطا",
                             message,
                             symbol,
                             timeframe,
                             0.0, 0.0, 0.0, 0.0,
                             0.0, 0.0, 0.0, 0.0,
                             0, 0, 0,
                             config,
                             state);
  }

//====================================================================
// میانبر برای رویداد M1
//====================================================================
bool DetailedLogger_M1Monitor(const string event_name,
                              const string status,
                              const string message,
                              const string symbol,
                              const double price,
                              DetailedLoggerConfig &config,
                              DetailedLoggerState &state)
  {
   if(!config.include_m1_monitoring)
      return false;

   return DetailedLogger_Log(DLOG_LEVEL_DEBUG,
                             DLOG_CATEGORY_MARKET,
                             event_name,
                             "پایش یک‌دقیقه‌ای",
                             "",
                             status,
                             message,
                             symbol,
                             PERIOD_M1,
                             0.0, 0.0, 0.0, 0.0,
                             price, 0.0, 0.0, 0.0,
                             0, 0, 0,
                             config,
                             state);
  }

//====================================================================
// تعداد رویدادها
//====================================================================
long DetailedLogger_EventCount(const DetailedLoggerState &state)
  {
   return state.event_count;
  }

//====================================================================
// تعداد خطاها
//====================================================================
long DetailedLogger_ErrorCount(const DetailedLoggerState &state)
  {
   return state.error_count;
  }

//====================================================================
// تعداد هشدارها
//====================================================================
long DetailedLogger_WarningCount(const DetailedLoggerState &state)
  {
   return state.warning_count;
  }

//====================================================================
// تعداد شکست‌های نوشتن فایل
//====================================================================
long DetailedLogger_FileFailureCount(const DetailedLoggerState &state)
  {
   return state.file_write_failures;
  }

//====================================================================
// متن خلاصه وضعیت گزارشگر
//====================================================================
string DetailedLogger_StatusText(const DetailedLoggerState &state)
  {
   string text = "";

   text += "ثبت گزارش: ";
   text += (state.initialized ? "فعال" : "غیرفعال");

   text += " | تعداد رویداد: " + (string)state.event_count;
   text += " | خطا: " + (string)state.error_count;
   text += " | هشدار: " + (string)state.warning_count;
   text += " | شکست فایل: " + (string)state.file_write_failures;

   if(state.last_event != "")
      text += " | آخرین رویداد: " + state.last_event;

   return text;
  }

//+------------------------------------------------------------------+

#endif // __TFLAB_DETAILED_LOGGER_MQH__