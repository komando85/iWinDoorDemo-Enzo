#ifndef __TFLAB_TEST_REPORT_LOGGER_MQH__
#define __TFLAB_TEST_REPORT_LOGGER_MQH__

//+------------------------------------------------------------------+
//|                   Test_Report_Logger.mqh                         |
//|                   TFlab New EA V.5                                   |
//|                                                                  |
//| مسئولیت: ثبت Snapshot مستقل از هر چرخه تحلیل برای تست و ارزیابی |
//| بدون منطق تحلیل، تصمیم‌گیری، ریسک، SL/TP یا اجرای سفارش          |
//+------------------------------------------------------------------+
#property strict

#define TEST_REPORT_DEFAULT_FILE "TFlab_Analysis_Snapshot.csv"
#define TEST_REPORT_FALLBACK_FILE "TFlab_Analysis_Snapshot_Fallback.csv"

struct TestReportLoggerState
  {
   bool initialized;
   ulong snapshot_count;
   datetime last_snapshot_time;
   string file_name;
   string fallback_file_name;
   string symbol;
   bool use_fallback;
  };

void TestReportLogger_InitState(TestReportLoggerState &state)
  {
   ZeroMemory(state);
   state.initialized=false;
   state.snapshot_count=0;
   state.last_snapshot_time=0;
   state.file_name=(MQLInfoInteger(MQL_TESTER) ? "TFlab_BACKTEST_Analysis_Snapshot.csv" : TEST_REPORT_DEFAULT_FILE);
   state.fallback_file_name=(MQLInfoInteger(MQL_TESTER) ? "TFlab_BACKTEST_Analysis_Snapshot_Fallback.csv" : TEST_REPORT_FALLBACK_FILE);
   state.symbol="";
   state.use_fallback=false;
  }

string TestReportLogger_CsvEscape(const string value)
  {
   string result=value;
   StringReplace(result,"\"","\"\"");
   return "\""+result+"\"";
  }

string TestReportLogger_Header()
  {
   return "شماره;زمان;نماد;تایم‌فریم;کندل_تحلیل;قیمت_Bid;قیمت_Ask;اسپرد_Point;H4;H1;زمینه_کلی;M30_وضعیت;M30_Context;M30_Context_قدرت;M30_Context_موقعیت_روز;M15_ساختار;M5_حرکت_اصلاح;M5_جهت;M5_ImpulseValid;M5_اندازه_Point;M5_تعداد_کندل;M5_ATR_Point;M5_ATRx;M5_DirectionRatio;M5_Continuity;M5_Efficiency;M5_Momentum;M5_Correction;M5_CorrectionRatio;BUY_Zone_Distance_Point;SELL_Zone_Distance_Point;BUY_Zone_Strength;SELL_Zone_Strength;Zone_Position;Scenario_State;Scenario_Direction;Scenario_Quality;Scenario_Alignment;Scenario_Reason;Setup_State;Setup_Direction;Setup_Reason;نتیجه_چرخه";
  }

bool TestReportLogger_EnsureFile(TestReportLoggerState &state, const string target_file)
  {
   if(target_file=="") return false;
   ResetLastError();
   // استفاده از FILE_SHARE_READ و FILE_SHARE_WRITE برای جلوگیری از خطای 5004 هنگام باز بودن فایل در اکسل
   int handle=FileOpen(target_file, FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE, ';');
   if(handle==INVALID_HANDLE)
     {
      Print("[Test Report] خطا | FileOpen ناموفق | فایل=",target_file," | Error=",GetLastError());
      return false;
     }
   if(FileSize(handle)==0) FileWriteString(handle,TestReportLogger_Header()+"\r\n");
   FileClose(handle);
   return true;
  }

bool TestReportLogger_Init(TestReportLoggerState &state,const string symbol,const string file_name="")
  {
   TestReportLogger_InitState(state);
   state.symbol=symbol;
   if(file_name!="") state.file_name=file_name;
   
   if(!TestReportLogger_EnsureFile(state, state.file_name)) 
     {
      Print("[Test Report] فایل اصلی قفل است یا در دسترس نیست. استفاده از فایل جایگزین (Fallback).");
      if(!TestReportLogger_EnsureFile(state, state.fallback_file_name))
         return false;
      state.use_fallback = true;
     }
     
   state.initialized=true;
   Print("[Test Report] فعال شد | فایل=", (state.use_fallback ? state.fallback_file_name : state.file_name), " | MQL5\\Files");
   return true;
  }

bool TestReportLogger_WriteSnapshot(
   TestReportLoggerState &state,
   const datetime snapshot_time,
   const string symbol,
   const ENUM_TIMEFRAMES analysis_timeframe,
   const datetime analysis_bar_time,
   const double bid,
   const double ask,
   const double spread_points,
   const string h4_direction,
   const string h1_direction,
   const string higher_context,
   const string m30_regime,
   const string m30_context,
   const double m30_context_strength,
   const double m30_day_position,
   const string m15_structure,
   const string m5_state,
   const string m5_direction,
   const bool m5_impulse_valid,
   const double m5_impulse_size_points,
   const int m5_impulse_bars,
   const double m5_atr_points,
   const double m5_atr_multiple,
   const double m5_directional_ratio,
   const double m5_continuity_ratio,
   const double m5_efficiency_ratio,
   const double m5_momentum_score,
   const string m5_correction_state,
   const double m5_correction_ratio,
   const double buy_zone_distance_points,
   const double sell_zone_distance_points,
   const double buy_zone_strength,
   const double sell_zone_strength,
   const string zone_position,
   const string scenario_state,
   const string scenario_direction,
   const double scenario_quality,
   const double scenario_alignment,
   const string scenario_reason,
   const string setup_state,
   const string setup_direction,
   const string setup_reason,
   const string cycle_result)
  {
   if(!state.initialized) return false;
   
   string active_file = state.use_fallback ? state.fallback_file_name : state.file_name;
   
   ResetLastError();
   int handle=FileOpen(active_file, FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE, ';');
   
   // اگر فایل اصلی قفل بود و هنوز به Fallback سوییچ نکرده‌ایم، تلاش برای فایل جایگزین
   if(handle==INVALID_HANDLE && !state.use_fallback)
     {
      Print("[Test Report] خطا | باز کردن فایل اصلی ناموفق | Error=",GetLastError(), " | تلاش برای فایل جایگزین");
      active_file = state.fallback_file_name;
      state.use_fallback = true;
      ResetLastError();
      handle = FileOpen(active_file, FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE, ';');
     }
     
   if(handle==INVALID_HANDLE)
     {
      Print("[Test Report] خطا | باز کردن فایل جایگزین هم ناموفق بود | Error=",GetLastError());
      return false;
     }
     
   FileSeek(handle,0,SEEK_END);
   state.snapshot_count++;
   state.last_snapshot_time=snapshot_time;
   
   string row="";
   row+=(string)state.snapshot_count+";";
   row+=TimeToString(snapshot_time,TIME_DATE|TIME_SECONDS)+";";
   row+=TestReportLogger_CsvEscape(symbol)+";";
   row+=TestReportLogger_CsvEscape(EnumToString(analysis_timeframe))+";";
   row+=TimeToString(analysis_bar_time,TIME_DATE|TIME_MINUTES)+";";
   row+=DoubleToString(bid,_Digits)+";";
   row+=DoubleToString(ask,_Digits)+";";
   row+=DoubleToString(spread_points,1)+";";
   row+=TestReportLogger_CsvEscape(h4_direction)+";";
   row+=TestReportLogger_CsvEscape(h1_direction)+";";
   row+=TestReportLogger_CsvEscape(higher_context)+";";
   row+=TestReportLogger_CsvEscape(m30_regime)+";";
   row+=TestReportLogger_CsvEscape(m30_context)+";";
   row+=DoubleToString(m30_context_strength,2)+";";
   row+=DoubleToString(m30_day_position,2)+";";
   row+=TestReportLogger_CsvEscape(m15_structure)+";";
   row+=TestReportLogger_CsvEscape(m5_state)+";";
   row+=TestReportLogger_CsvEscape(m5_direction)+";";
   row+=(m5_impulse_valid?"بله":"خیر")+";";
   row+=DoubleToString(m5_impulse_size_points,1)+";";
   row+=IntegerToString(m5_impulse_bars)+";";
   row+=DoubleToString(m5_atr_points,1)+";";
   row+=DoubleToString(m5_atr_multiple,2)+";";
   row+=DoubleToString(m5_directional_ratio*100.0,2)+";";
   row+=DoubleToString(m5_continuity_ratio*100.0,2)+";";
   row+=DoubleToString(m5_efficiency_ratio*100.0,2)+";";
   row+=DoubleToString(m5_momentum_score,2)+";";
   row+=TestReportLogger_CsvEscape(m5_correction_state)+";";
   row+=DoubleToString(m5_correction_ratio*100.0,2)+";";
   row+=DoubleToString(buy_zone_distance_points,1)+";";
   row+=DoubleToString(sell_zone_distance_points,1)+";";
   row+=DoubleToString(buy_zone_strength,2)+";";
   row+=DoubleToString(sell_zone_strength,2)+";";
   row+=TestReportLogger_CsvEscape(zone_position)+";";
   row+=TestReportLogger_CsvEscape(scenario_state)+";";
   row+=TestReportLogger_CsvEscape(scenario_direction)+";";
   row+=DoubleToString(scenario_quality,2)+";";
   row+=DoubleToString(scenario_alignment,2)+";";
   row+=TestReportLogger_CsvEscape(scenario_reason)+";";
   row+=TestReportLogger_CsvEscape(setup_state)+";";
   row+=TestReportLogger_CsvEscape(setup_direction)+";";
   row+=TestReportLogger_CsvEscape(setup_reason)+";";
   row+=TestReportLogger_CsvEscape(cycle_result);
   
   bool write_ok = (FileWriteString(handle,row+"\r\n") > 0);

   FileFlush(handle);
   ulong file_size = FileSize(handle);
   FileClose(handle);

   if(!write_ok)
     {
      Print(
         "[Test Report] ERROR | Snapshot write failed",
         " | File=",active_file,
         " | Error=",GetLastError()
      );
      return false;
     }

   Print(
      "[Test Report] SNAPSHOT OK",
      " | #",(string)state.snapshot_count,
      " | Candle=",
      TimeToString(analysis_bar_time,TIME_DATE|TIME_MINUTES),
      " | Size=",(string)file_size,
      (state.use_fallback ? " | Fallback=YES" : "")
   );

   return true;
  }

void TestReportLogger_Shutdown(TestReportLoggerState &state){ state.initialized=false; }

string TestReportLogger_StatusText(const TestReportLoggerState &state)
  {
   string text="Test Report: ";
   text+=(state.initialized?"فعال":"غیرفعال");
   text+=" | Snapshots="+(string)state.snapshot_count;
   if(state.file_name!="") text+=" | File="+(state.use_fallback ? state.fallback_file_name : state.file_name);
   return text;
  }

#endif // __TFLAB_TEST_REPORT_LOGGER_MQH__