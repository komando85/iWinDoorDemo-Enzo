#ifndef __TFLAB_EA_INPUTS_MQH__
#define __TFLAB_EA_INPUTS_MQH__

//+------------------------------------------------------------------+
//|                         EA_Inputs.mqh                             |
//|                    New EA - Central Inputs                       |
//|                                                                  |
//| تمام تنظیمات قابل تغییر کاربر فقط در این فایل قرار می‌گیرد.       |
//| هیچ موتور معاملاتی نباید Input مستقل خارج از این فایل داشته باشد.  |
//+------------------------------------------------------------------+

//====================================================================
// ENUMS
//====================================================================

enum ENUM_AI_MODE
  {
   AI_MODE_OBSERVER = 0,      // فقط تحلیل و پیشنهاد
   AI_MODE_LEARNING = 1,      // تحلیل + یادگیری + معامله مجازی
   AI_MODE_FULL = 2           // فعلاً رزرو؛ اجرای واقعی توسط AI مجاز نیست
  };

enum ENUM_LOG_DETAIL_LEVEL
  {
   LOG_DETAIL_MINIMAL = 0,    // حداقل اطلاعات
   LOG_DETAIL_NORMAL  = 1,    // اطلاعات عادی
   LOG_DETAIL_FULL    = 2     // ریزترین جزئیات
  };

enum ENUM_PARTIAL_CLOSE_MODE
  {
   PARTIAL_CLOSE_DISABLED = 0,// بدون خروج بخشی
   PARTIAL_CLOSE_PERCENT  = 1 // خروج بر اساس درصد حجم
  };

enum ENUM_ENTRY_PREFERENCE
  {
   ENTRY_AUTO   = 0,          // انتخاب خودکار بر اساس سناریو
   ENTRY_MARKET = 1,          // فقط ورود بازار
   ENTRY_LIMIT  = 2,          // فقط سفارش Limit
   ENTRY_STOP   = 3           // فقط سفارش Stop
  };

//====================================================================
// 1) تنظیمات عمومی ربات
//====================================================================
input group "========== تنظیمات عمومی ==========";
input ulong  Inp_MagicNumber              = 14050612;      // شماره اختصاصی ربات
input bool   Inp_EnableTrading             = true;          // اجازه معاملات واقعی
input bool   Inp_AllowMultipleTrades       = true;          // اجازه چند معامله همزمان
input int    Inp_MaxOpenTrades             = 4;             // حداکثر معاملات باز
input int    Inp_Simultaneous_Trades       = 1;             // تعداد معاملات همزمان برای هر سیگنال
input bool   Inp_AllowPendingOrders        = true;          // اجازه سفارش‌های Pending
input bool   Inp_AllowBuy                  = true;          // اجازه BUY
input bool   Inp_AllowSell                 = true;          // اجازه SELL
input int    Inp_MaxSlippagePoints         = 50;            // حداکثر لغزش مجاز (Point)
input bool   Inp_Show_All_Trades_In_Panel  = true;          // نمایش سود همه معاملات نماد (شامل دستی)

//====================================================================
// 2) تایم‌فریم‌های تحلیل
//====================================================================
input group "========== تایم‌فریم‌های تحلیل ==========";
input ENUM_TIMEFRAMES Inp_TF_Background_H4 = PERIOD_H4;     // پس‌زمینه بلندمدت
input ENUM_TIMEFRAMES Inp_TF_Background_H1 = PERIOD_H1;     // وضعیت روز جاری
input ENUM_TIMEFRAMES Inp_TF_Context_M30   = PERIOD_M30;    // شناخت محیط بازار
input ENUM_TIMEFRAMES Inp_TF_Structure_M15 = PERIOD_M15;    // ساختار اصلی
input ENUM_TIMEFRAMES Inp_TF_Setup_M5      = PERIOD_M5;     // سناریو و Setup
input ENUM_TIMEFRAMES Inp_TF_Monitor_M1    = PERIOD_M1;     // رصد زنده
input int    Inp_Monitor_Update_Seconds    = 60;            // فاصله رصد زنده (ثانیه)
input int    Inp_Monitor_Confirm_Minutes   = 3;             // تعداد دقیقه برای تأیید استمرار وضعیت

//====================================================================
// 3) کنترل‌های تحلیل بازار
//====================================================================
input group "========== تحلیل بازار ==========";
input bool   Inp_Use_H4_Background        = true;           // استفاده از H4 برای شناخت زمینه
input bool   Inp_Use_H1_Background        = true;           // استفاده از H1 برای شناخت زمینه
input bool   Inp_Use_M30_Context          = true;           // استفاده از M30
input bool   Inp_Use_M15_Structure        = true;           // استفاده از M15
input bool   Inp_Use_M5_Setup             = true;           // استفاده از M5
input bool   Inp_Use_M1_Monitor           = true;           // استفاده از M1 برای رصد
input bool   Inp_Require_Closed_Bars      = true;           // استفاده از کندل بسته برای تحلیل اصلی

//====================================================================
// 4) Impulse / Correction
//====================================================================
input group "========== حرکت اصلی و اصلاح ==========";
input bool   Inp_Use_Impulse_Correction   = true;           // فعال بودن تشخیص حرکت و اصلاح
input int    Inp_Min_Swing_Count          = 2;              // حداقل تعداد Swing برای ساختار حرکت
input double Inp_Min_Impulse_ATR_Multiple = 1.20;           // حداقل قدرت حرکت نسبت به ATR
input double Inp_Max_Correction_Ratio     = 0.70;           // حداکثر نسبت اصلاح به Impulse
input int    Inp_Min_Impulse_Bars         = 2;              // حداقل تعداد کندل حرکت
input int    Inp_Max_Impulse_Bars         = 20;             // حداکثر تعداد کندل مورد بررسی برای حرکت

//====================================================================
// 5) حقیقت بازار / PriceFirst Engine
//====================================================================
input group "========== حقیقت بازار ==========";
input bool   Inp_Use_Market_Truth                 = true;   // تشخیص مستقل روند و حرکت واقعی قیمت
input int    Inp_Market_Truth_Lookback            = 48;     // تعداد کندل بسته برای تحلیل PriceFirst
input double Inp_Market_Truth_Min_Move_ATR        = 1.50;   // حداقل حرکت معنی‌دار نسبت به ATR
input bool   Inp_Market_Truth_Override_Confluence = true;   // عدم حذف Opportunity به‌دلیل Confluence ضعیف

//====================================================================
// 6) Zone Engine
//====================================================================
input group "========== نواحی قیمتی ==========";
input bool   Inp_Use_Origin_Zone       = true;              // استفاده از Origin Zone
input bool   Inp_Use_Structure_Zone    = true;              // استفاده از Structure Zone
input bool   Inp_Use_Displacement_Zone = true;              // استفاده از ناحیه Displacement
input bool   Inp_Use_Pullback_Zone     = true;              // استفاده از Pullback Zone
input int    Inp_Zone_Max_Width_Points = 500;               // حداکثر عرض Zone (Point)
input int    Inp_Zone_Max_Age_Bars     = 100;               // حداکثر عمر Zone بر حسب کندل
input int    Inp_Max_Active_Zones      = 10;                // حداکثر نواحی فعال

//====================================================================
// 7) Scenario Engine
//====================================================================
input group "========== سناریوی معاملاتی ==========";
input bool   Inp_Enable_Scenarios         = true;           // فعال بودن Scenario Engine
input int    Inp_Max_Active_Scenarios     = 5;              // حداکثر سناریوهای همزمان
input int    Inp_Scenario_Max_Age_Minutes = 360;            // حداکثر عمر سناریو (دقیقه)
input bool   Inp_Allow_Contrary_Background= true;           // اجازه سناریوی خلاف زمینه H4/H1
input bool   Inp_Require_Complete_Scenario= true;           // فقط برای اجرای واقعی؛ فرصت اولیه نیاز به تکمیل ندارد
input bool   Inp_Enable_Regime_Filter     = true;           // جلوگیری از معامله در جهت مخالف رژیم بازار
input double Inp_Min_Regime_Confidence    = 60.0;           // حداقل اطمینان رژیم برای اعمال فیلتر
input bool   Inp_Allow_Transition_Strategy= true;           // اجازه استراتژی در ساختار در حال تغییر
input bool   Inp_Buy_Continuation_Require_Pullback = true;     // نیاز BUY Continuation به Pullback معتبر
input double Inp_AI_Boost_Quality         = 15.0;           // افزایش کیفیت سناریو در صورت هم‌جهتی با AI مستقل
input double Inp_AI_Boost_Min_Confidence  = 75.0;           // حداقل اطمینان AI برای اعمال boost

//====================================================================
// 8) Entry Planner
//====================================================================
input group "========== ورود به معامله ==========";
input ENUM_ENTRY_PREFERENCE Inp_Entry_Preference = ENTRY_AUTO; // روش ترجیحی ورود
input bool   Inp_Allow_Market_Entry         = true;           // اجازه Market Entry
input bool   Inp_Allow_Limit_Entry          = true;           // اجازه Limit Entry
input bool   Inp_Allow_Stop_Entry           = true;           // اجازه Stop Entry
input int    Inp_Pending_Expiration_Minutes = 120;            // عمر سفارش Pending
input bool   Inp_Cancel_Pending_On_Invalid  = true;
input bool   Inp_Enable_Early_Market_Entry         = true;
input double Inp_Early_Entry_Min_Progress_Percent = 50.0;
input double Inp_Early_Entry_SL_ATR_Multiple       = 1.00;
input bool   Inp_Enable_Entry_Decision_Gate        = true;
input double Inp_Direct_Continuation_Max_ATR       = 3.50;
input bool   Inp_Enable_Entry_Revalidation          = true;

//====================================================================
// 9) ریسک
//====================================================================
input group "========== مدیریت ریسک ==========";
input bool   Inp_Use_Fixed_Lot             = false;           // تایید حجم ثابت معامله
input double Inp_Fixed_Lot_Size            = 0.01;            // مقدار حجم ثابت معامله
input double Inp_Risk_Per_Trade_Percent    = 2.00;            // ریسک پایه هر معامله (%)
input double Inp_Max_Risk_Per_Trade_Percent= 30.00;           // حداکثر ریسک مجاز هر معامله (%)
input double Inp_Max_Portfolio_Risk_Percent= 35.00;           // حداکثر ریسک همزمان (%)
input double Inp_Max_Directional_Risk_Percent = 30.00;        // حداکثر ریسک هم‌جهت (%)
input double Inp_Min_RR                    = 1.00;            // حداقل نسبت سود به ریسک
input double Inp_Max_RR                    = 10.00;           // حداکثر RR برای کنترل داده‌های غیرعادی
input double Inp_Max_SL_Distance_Points    = 5000;            // حداکثر فاصله SL (پوینت)
input double Inp_Min_SL_Distance_Points    = 30;              // حداقل فاصله SL (پوینت)
input double Inp_Daily_Loss_Limit_Percent  = 50.00;           // سقف ضرر روزانه (%)
input double Inp_Max_Drawdown_Percent      = 50.00;           // سقف افت سرمایه (%)
input int    Inp_Max_Consecutive_Losses    = 100;               // حداکثر ضرر متوالی
input bool   Inp_Enable_Adaptive_Risk      = true;            // سایزینگ تطبیقی نرم
input double Inp_Adaptive_Reduction_Per_Loss_Percent = 25.0;  // درصد کاهش ریسک به‌ازای هر باخت متوالی
input double Inp_Adaptive_Increase_Per_Win_Percent   = 10.0;  // درصد افزایش ریسک به‌ازای هر برد متوالی
input double Inp_Adaptive_Risk_Min_Multiplier = 0.30;         // کف ضریب تطبیقی
input double Inp_Adaptive_Risk_Max_Multiplier = 1.30;         // سقف ضریب تطبیقی
input bool   Inp_Block_After_Daily_Loss    = false;           // مدار محافظ ضرر روزانه
input bool   Inp_Block_After_Drawdown      = false;           // مدار محافظ دراودان
input bool   Inp_Count_Pending_As_Risk     = true;            // لحاظ ریسک Pending در Exposure
input bool   Inp_Ignore_Capital_Size_For_Min_Volume = true;   // استفاده از حداقل حجم بروکر در صورت کمبود سرمایه

//====================================================================
// 10) حد ضرر / حد سود
//====================================================================
input group "========== حد ضرر و حد سود ==========";
input bool   Inp_Enable_Smart_SL           = true;            // استفاده از SL ساختاری
input bool   Inp_Enable_ATR_SL_Fallback    = true;            // استفاده از ATR در صورت نبود ساختار مناسب
input int    Inp_ATR_Period                = 14;              // دوره ATR
input double Inp_ATR_SL_Multiplier         = 2.0;             // ضریب ATR برای SL پشتیبان
input bool   Inp_Enable_Structural_Target  = true;            // Target ساختاری
input bool   Inp_Enable_Liquidity_Target   = true;            // Target نقدینگی
input bool   Inp_Enable_Zone_Target        = true;            // Target ناحیه‌ای
input bool   Inp_Enable_Expansion_Target   = true;            // Target توسعه‌ای
input bool   Inp_Use_Manual_TP               = false;           // استفاده از حد سود دستی بر اساس مبلغ
input double Inp_Manual_TP_Profit_Money      = 10.0;             // مبلغ سود هدف دستی (واحد حساب)

//====================================================================
// 11) تنظیمات بافر ابطال هوشمند (منطق جدید و یکپارچه)
//====================================================================
input group "========== بافر ابطال هوشمند ==========";
input double Inp_Invalidation_Buffer_ATR_Multiplier = 0.15;   // ضریب بافر بر اساس ATR
input double Inp_Invalidation_Min_Buffer_Points     = 30.0;   // حداقل بافر (پوینت)
input double Inp_Invalidation_Max_Buffer_Points     = 200.0;  // حداکثر بافر (پوینت)
input int    Inp_Invalidation_ATR_Period            = 14;     // دوره ATR برای محاسبه بافر

//====================================================================
// 12) مدیریت معامله
//====================================================================
input group "========== مدیریت معامله ==========";
input bool   Inp_Enable_Trade_Management   = true;            // فعال بودن مدیریت معامله
input bool   Inp_Close_Opposite_On_Reverse = true;            // بستن معامله مخالف هنگام ورود معکوس
input bool   Inp_Cancel_Pending_On_SL_Breach = true;    // [جدید] کنسل پندینگ در عبور قیمت از حد ضرر
input ENUM_PARTIAL_CLOSE_MODE Inp_Partial_Close_Mode = PARTIAL_CLOSE_PERCENT; // نوع Partial Close
input double Inp_Partial_Close_Percent     = 50.0;            // درصد حجم خروج اول
input bool   Inp_Move_SL_To_Breakeven      = false;           // انتقال SL به نقطه ورود بعد از خروج اول
input double Inp_Breakeven_Offset_Points   = 10;              // فاصله محافظ روی نقطه ورود
input bool   Inp_Allow_Profit_Lock         = false;           // اجازه انتقال SL به ناحیه سود
input double Inp_Profit_Lock_Trigger_R     = 1.50;            // شروع Profit Lock بر اساس R
input double Inp_Profit_Lock_R             = 0.25;            // مقدار سود قفل‌شده بر اساس R
input bool   Inp_Use_Structural_Trailing   = false;           // حد ضرر جا به جا شونده
input bool   Inp_Allow_Time_Exit           = true;            // خروج زمانی در صورت نیاز
input int    Inp_Max_Trade_Duration_Minutes= 1440;            // حداکثر مدت معامله

//====================================================================
// مدیریت دقیقه‌ای TP و برگشت قطعی روند
//====================================================================
input group "========== مدیریت پویا و برگشت روند ==========";
input bool   Inp_Enable_Dynamic_TP         = true;            // بازبینی حد سود در هر چرخه رصد
input double Inp_Dynamic_TP_Min_Confidence  = 60.0;           // حداقل اطمینان برای عقب‌آوردن حد سود
input double Inp_Dynamic_TP_Close_Confidence= 45.0;           // اطمینان پایین برای بستن با حد سود پویا
input double Inp_Dynamic_TP_Min_Move_Points = 30.0;           // حداقل فاصله تغییر حد سود (پوینت)
input double Inp_Dynamic_TP_Min_Remaining_Ratio = 0.20;       // حداقل سهم فاصله باقیمانده تا Entry
input double Inp_Signal_Audit_Threshold_ATR = 0.50;       // آستانه سنجش درست/غلط بودن جهت بر حسب ATR
input bool   Inp_Enable_Confirmed_Reversal_Close = true;      // بستن معاملات قبلی فقط هنگام تأیید برگشت و قصد ورود معکوس
input bool   Inp_Enable_Adaptive_Loss_Protection = true;      // محافظت پویا در برابر زیان بزرگ
input double Inp_Adverse_Move_ATR_Trigger = 1.00;              // آستانه حرکت خلاف جهت بر حسب ATR برای محافظت اولیه
input double Inp_Adverse_Move_Risk_Fraction = 0.50;            // سهم ریسک اولیه برای فعال شدن محافظت اولیه
input double Inp_Adverse_Move_Hard_ATR_Trigger = 1.75;         // آستانه اضطراری حرکت خلاف جهت بر حسب ATR
input double Inp_Adverse_Move_Hard_Risk_Fraction = 0.90;       // سهم ریسک اولیه برای فعال شدن محافظت اضطراری
input double Inp_Adverse_Move_Min_Reversal_Confidence = 65.0;  // حداقل اطمینان برگشت برای محافظت اولیه
input double Inp_Adverse_Move_Max_Continuation = 60.0;         // حداکثر قدرت ادامه روند برای محافظت اولیه
input bool   Inp_Enable_Profit_Protection = true;              // محافظت از سود شناور
input double Inp_Profit_Protection_ATR_Trigger = 0.75;         // آستانه سود شناور بر حسب ATR
input double Inp_Profit_Protection_Risk_Fraction = 0.35;       // سهم ریسک اولیه برای فعال شدن محافظت سود
input double Inp_Profit_Protection_Lock_ATR = 0.15;            // مقدار سود قفل‌شده بر حسب ATR
input double Inp_Profit_Protection_Lock_Risk_Fraction = 0.10;  // سهم ریسک اولیه برای مقدار سود قفل‌شده

//====================================================================
// 13) Execution
//====================================================================
input group "========== اجرای سفارش ==========";
input bool   Inp_Check_Trading_Session     = true;            // بررسی مجاز بودن ساعت معامله
input string Inp_Trading_Session_Start     = "00:00";         // شروع بازه معامله
input string Inp_Trading_Session_End       = "23:59";         // پایان بازه معامله
input bool   Inp_Reject_If_Spread_High     = true;            // رد معامله در Spread بالا
input double Inp_Max_Spread_Points         = 300;             // حداکثر Spread مجاز
input bool   Inp_Reject_If_Market_Closed   = true;            // جلوگیری از معامله خارج از شرایط بازار

//====================================================================
// 14) گزارش جزئیات کامل
//====================================================================
input group "========== گزارش جزئیات کامل ==========";
input bool   Inp_Enable_Detailed_Log       = true;            // فعال بودن گزارش جزئیات کامل
input ENUM_LOG_DETAIL_LEVEL Inp_Detail_Log_Level = LOG_DETAIL_FULL; // سطح جزئیات
input bool   Inp_Log_No_Trade_Decisions    = true;            // ثبت زمان‌هایی که معامله نشد
input bool   Inp_Log_All_Filter_Results    = true;            // ثبت نتیجه تمام فیلترها
input bool   Inp_Log_M1_Monitoring         = true;            // ثبت رصد M1
input bool   Inp_Log_Scenario_Lifecycle    = true;            // ثبت چرخه عمر سناریو
input bool   Inp_Log_Pending_Lifecycle     = true;            // ثبت چرخه عمر Pending
input bool   Inp_Log_Order_Requests        = true;            // ثبت درخواست‌های سفارش
input bool   Inp_Log_Execution_Result      = true;            // ثبت نتیجه اجرای سفارش
input bool   Inp_Log_File_Timestamp        = true;            // ثبت زمان دقیق در فایل گزارش

//====================================================================
// 15) گزارش معاملات
//====================================================================
input group "========== گزارش معاملات ==========";
input bool   Inp_Enable_Trade_Log          = true;            // فعال بودن گزارش معاملات
input bool   Inp_Log_Virtual_Trades        = true;            // ثبت معاملات مجازی AI
input bool   Inp_Log_Real_Trades           = true;            // ثبت معاملات واقعی
input bool   Inp_Log_Partial_Close         = true;            // ثبت Partial Close
input bool   Inp_Log_SL_Changes            = true;            // ثبت تغییرات SL
input bool   Inp_Log_TP_Changes            = true;            // ثبت تغییرات TP

//====================================================================
// 16) گزارش کلی و جامع
//====================================================================
input group "========== گزارش کلی و جامع ==========";
input bool   Inp_Enable_Performance_Report = true;            // فعال بودن گزارش کلی
input int    Inp_Performance_Update_Minutes= 60;              // به‌روزرسانی گزارش کلی هر چند دقیقه
input bool   Inp_Preserve_Report_History   = true;            // حفظ سابقه گزارش
input bool   Inp_Update_Report_On_Startup  = true;            // به‌روزرسانی هنگام شروع
input bool   Inp_Report_Compare_AI         = true;            // مقایسه عملکرد AI با ربات

//====================================================================
// 17) هوش مصنوعی و یادگیری
//====================================================================
input group "========== تحلیلگر هوشمند ==========";
input bool   Inp_Enable_AI                 = true;            // فعال بودن سیستم هوش مصنوعی
input ENUM_AI_MODE Inp_AI_Mode             = AI_MODE_LEARNING;// حالت AI
input bool   Inp_AI_Use_Detailed_Data      = true;            // استفاده از داده‌های گزارش جزئیات
input bool   Inp_AI_Use_Real_Trades        = true;            // یادگیری از معاملات واقعی
input bool   Inp_AI_Use_No_Trade_Opportunities = true;        // بررسی فرصت‌های بدون معامله
input bool   Inp_AI_Use_Virtual_Trading    = true;            // اجازه معاملات مجازی
input bool   Inp_AI_Use_Fair_Comparison    = true;            // مقایسه عادلانه با شرایط یکسان
input int    Inp_AI_Minimum_Samples        = 30;              // حداقل نمونه برای نتیجه‌گیری
input int    Inp_AI_Analysis_Lookback_Days = 30;              // بازه اولیه یادگیری (روز)
input double Inp_AI_Min_Confidence_Percent = 70.0;            // حداقل اطمینان برای پیشنهاد
input bool   Inp_AI_Prevent_Future_Data    = true;            // جلوگیری از استفاده از داده آینده
input bool   Inp_AI_Can_Trade_Real         = false;           // اجازه اجرای خودکار معامله واقعی توسط AI پس از پیشنهاد
input bool   Inp_AI_Can_Change_Core_Logic  = false;           // AI اجازه تغییر منطق هسته ندارد

//====================================================================
// 18) تحلیل مستقل هوش مصنوعی
//====================================================================
input group "========== تحلیل مستقل هوش مصنوعی ==========";
input bool            Inp_AI_Independent_Enable          = true;        // فعال بودن تحلیل مستقل AI
input ENUM_TIMEFRAMES Inp_AI_Independent_Timeframe       = PERIOD_M5;   // تایم‌فریم تحلیل مستقل
input int             Inp_AI_Independent_ADX_Period      = 14;          // دوره ADX
input int             Inp_AI_Independent_RSI_Period      = 14;          // دوره RSI
input int             Inp_AI_Independent_EMA_Period      = 50;          // دوره EMA
input double          Inp_AI_Independent_ADX_Min_Trend   = 20.0;        // حداقل ADX برای روند
input int             Inp_AI_Independent_Structure_Bars  = 50;          // تعداد کندل تحلیل ساختار
input int             Inp_AI_Independent_Pivot_Left      = 2;           // Pivot سمت چپ
input int             Inp_AI_Independent_Pivot_Right     = 2;           // Pivot سمت راست
input double          Inp_AI_Independent_Min_Confidence_To_Trade = 55.0;// حداقل اطمینان برای باز کردن معامله مجازی مستقل
input double          Inp_AI_Independent_RR_Target       = 2.0;         // نسبت سود به ریسک هدف معامله مجازی مستقل

//====================================================================
// 19) معاملات مجازی AI
//====================================================================
input group "========== معاملات مجازی هوش مصنوعی ==========";
input bool   Inp_AI_Virtual_Enable_SL        = true;          // SL برای معامله مجازی
input bool   Inp_AI_Virtual_Enable_TP        = true;          // TP برای معامله مجازی
input bool   Inp_AI_Virtual_Enable_Partial   = true;          // Partial Close مجازی
input bool   Inp_AI_Virtual_Follow_Every_M1  = true;          // پایش معامله مجازی در M1
input double Inp_AI_Virtual_Initial_Risk_Percent = 0.50;      // ریسک شبیه‌سازی مجازی
input double Inp_AI_Virtual_Initial_Lot      = 0.01;          // حجم پایه مجازی
input bool   Inp_AI_Virtual_Use_Same_Entry   = true;          // استفاده از قیمت قابل مقایسه
input bool   Inp_AI_Virtual_Record_WhatIf    = true;          // ثبت سناریوی What-If

//====================================================================
// 20) پیشنهاد AI و هشدارها
//====================================================================
input group "========== پیشنهاد و هشدار هوشمند ==========";
input bool   Inp_AI_Advisor_Enable           = true;          // فعال بودن پیشنهاد AI
input bool   Inp_AI_Advisor_On_Chart         = true;          // نمایش روی چارت
input bool   Inp_AI_Advisor_Popup            = true;          // نمایش Pop-up
input bool   Inp_AI_Advisor_Sound            = false;         // هشدار صوتی
input bool   Inp_AI_Advisor_Require_Fact     = true;          // پیشنهاد باید بر پایه داده باشد
input bool   Inp_AI_Advisor_Show_Comparison  = true;          // نمایش مقایسه ربات و AI
input double Inp_AI_Realtime_Popup_Min_Confidence = 80.0;     // حداقل اطمینان برای پاپ‌آپ لحظه‌ای AI
input bool   Inp_AI_Realtime_Popup_Alert     = true;          // همراه با Alert صوتی/پاپ‌آپ متاتریدر

//====================================================================
// 21) پنل روی چارت
//====================================================================
input group "========== پنل روی چارت ==========";
input bool   Inp_Enable_Chart_Panel         = true;           // فعال بودن پنل
input bool   Inp_Enable_Location_Fix        = true;     // [جدید] فیلتر هوشمند کف/سقف روز
input bool   Inp_Panel_Show_Market_State    = true;           // وضعیت بازار
input bool   Inp_Panel_Show_Direction       = true;           // جهت
input bool   Inp_Panel_Show_Structure       = true;           // ساختار
input bool   Inp_Panel_Show_Scenario        = true;           // سناریو
input bool   Inp_Panel_Show_Entry_State     = true;           // وضعیت ورود
input bool   Inp_Panel_Show_Risk            = true;           // وضعیت ریسک
input bool   Inp_Panel_Show_Open_Trades     = true;           // تعداد معاملات باز
input bool   Inp_Panel_Show_Total_PnL       = true;           // سود/ضرر کل
input bool   Inp_Panel_Show_Today_PnL       = true;           // سود/ضرر امروز
input bool   Inp_Panel_Show_AI_Status       = true;           // وضعیت AI
input bool   Inp_Panel_Show_AI_Advice       = true;           // آخرین پیشنهاد AI
input int    Inp_Panel_Update_Seconds       = 1;              // نرخ به‌روزرسانی پنل

//====================================================================
// 22) کنترل توسعه و تست
//====================================================================
input group "========== کنترل تست ==========";
input bool   Inp_Debug_Mode                 = true;           // حالت Debug
input bool   Inp_Simulation_Mode            = false;          // حالت شبیه‌سازی بدون سفارش واقعی
input bool   Inp_Allow_Test_Orders          = false;          // اجازه سفارش آزمایشی
input bool   Inp_Strict_Architecture_Check  = true;           // کنترل سخت‌گیرانه معماری

//====================================================================
// 23) سازگاری API قدیمی EA_Main
//====================================================================
input group "========== تنظیمات سازگاری API قدیمی ==========";
input double Inp_PinBar_Min_Wick_Ratio       = 1.50;          // حداقل نسبت شدو به بدنه برای PinBar
input double Inp_Min_Confluence_Score        = 50.0;          // حداقل امتیاز هم‌پوشانی فیلترها
input int    Inp_ADX_Period                  = 14;            // دوره اندیکاتور ADX
input int    Inp_RSI_Period                  = 14;            // دوره اندیکاتور RSI
input int    Inp_EMA_Trend_Period            = 50;            // دوره EMA برای تشخیص روند
input double Inp_ADX_Min_Trend               = 20.0;          // حداقل ADX برای تشخیص روند
input double Inp_ADX_Exhaustion_Level        = 35.0;          // سطح خستگی روند در ADX
input double Inp_RSI_Overbought              = 70.0;          // سطح اشباع خرید RSI
input double Inp_RSI_Oversold                = 30.0;          // سطح اشباع فروش RSI
input double Inp_Max_Price_EMA_ATR_Distance  = 3.0;           // حداکثر فاصله قیمت از EMA بر حسب ATR
input int    Inp_Max_Consecutive_Swings      = 4;             // حداکثر Swing های متوالی برای ساختار
input bool   Inp_Enable_Divergence_Filter    = true;          // فعال بودن فیلتر واگرایی
input bool   Inp_Reject_On_Against_Divergence= true;          // رد معامله در صورت واگرایی مخالف
input bool   Inp_Use_Confluence_Scoring      = true;          // استفاده از امتیازدهی هم‌پوشانی
input bool   Inp_Enable_News_Filter          = false;         // فعال بودن فیلتر اخبار اقتصادی
input int    Inp_News_Minutes_Before         = 30;            // دقیقه قبل از خبر برای بلاک کردن
input int    Inp_News_Minutes_After          = 30;            // دقیقه بعد از خبر برای بلاک کردن
input double Inp_Min_Scenario_Quality        = 80.0;          // حداقل کیفیت سناریو برای ورود
input bool   Inp_Require_Candle_Confirmation = true;          // نیاز به تأییدیه کندلی (PinBar/Engulfing)
input int    Inp_Candle_Confirm_Timeout_Minutes = 10;         // بعد از این مدت بدون تأیید کندلی هم وارد شو
input bool   Inp_Enable_Reversal_Exit        = true;           // فعال بودن خروج به دلیل بازگشت روند
input double Inp_Reversal_Exit_Min_Confidence= 70.0;          // حداقل اطمینان برای خروج بازگشتی
input double Inp_Reversal_Exit_Min_ATR_Multiple = 0.35;       // حداقل حرکت خلاف جهت قبل از خروج بازگشتی
input double Inp_Reversal_Exit_Min_Points    = 50;            // حداقل حرکت خلاف جهت بر حسب پوینت
input double Inp_Reversal_Exit_Min_Score_Lead = 10.0;        // حداقل برتری امتیاز برگشت نسبت به ادامه روند
input bool   Inp_Enable_Reversal_Pending_Cancel = true;       // لغو Pending در صورت تشخیص بازگشت مخالف

//+------------------------------------------------------------------+
//| END OF FILE                                                       |
//+------------------------------------------------------------------+
#endif // __TFLAB_EA_INPUTS_MQH__