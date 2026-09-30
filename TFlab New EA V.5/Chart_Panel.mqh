#ifndef __TFLAB_CHART_PANEL_MQH__
#define __TFLAB_CHART_PANEL_MQH__

//+------------------------------------------------------------------+
//|                         Chart_Panel.mqh                          |
//|                         TFlab New EA V.5                         |
//|                                                                  |
//| v2.3 - Added Overall P&L and Balance rows                        |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// وضعیت پنل
//====================================================================
struct ChartPanelState
  {
   string  market_status;
   string  direction;
   string  structure;
   string  scenario;
   string  entry_status;
   string  bot_status;
   double  current_risk_percent;
   int     open_trades;
   int     pending_orders;
   double  open_profit;
   double  today_profit;
   double  overall_profit;      // [جدید] سود/ضرر کل از تاریخچه
   double  account_balance;     // [جدید] سرمایه حساب
   datetime updated_time;
  };

//====================================================================
// نام آبجکت‌های پنل
//====================================================================
#define CP_PREFIX             "TFLAB_CP_"
#define CP_BG                 CP_PREFIX "BG"
#define CP_TITLE              CP_PREFIX "TITLE"
#define CP_LINE1              CP_PREFIX "L1"
#define CP_LINE2              CP_PREFIX "L2"
#define CP_LINE3              CP_PREFIX "L3"
#define CP_LINE4              CP_PREFIX "L4"
#define CP_LINE5              CP_PREFIX "L5"
#define CP_LINE6              CP_PREFIX "L6"
#define CP_LINE7              CP_PREFIX "L7"
#define CP_LINE8              CP_PREFIX "L8"
#define CP_LINE9              CP_PREFIX "L9"
#define CP_LINE10             CP_PREFIX "L10"
#define CP_LINE11             CP_PREFIX "L11"
#define CP_LINE12             CP_PREFIX "L12"
#define CP_LINE13             CP_PREFIX "L13"
#define CP_LINE14             CP_PREFIX "L14"
#define CP_VAL1               CP_PREFIX "V1"
#define CP_VAL2               CP_PREFIX "V2"
#define CP_VAL3               CP_PREFIX "V3"
#define CP_VAL4               CP_PREFIX "V4"
#define CP_VAL5               CP_PREFIX "V5"
#define CP_VAL6               CP_PREFIX "V6"
#define CP_VAL7               CP_PREFIX "V7"
#define CP_VAL8               CP_PREFIX "V8"
#define CP_VAL9               CP_PREFIX "V9"
#define CP_VAL10              CP_PREFIX "V10"
#define CP_VAL11              CP_PREFIX "V11"
#define CP_VAL12              CP_PREFIX "V12"
#define CP_VAL13              CP_PREFIX "V13"
#define CP_VAL14              CP_PREFIX "V14"

//====================================================================
// موقعیت‌ها و رنگ‌ها
//====================================================================
#define CP_X                    15
#define CP_Y                    40
#define CP_WIDTH                460
#define CP_HEIGHT               960       // [اصلاح] افزایش ارتفاع برای 14 ردیف
#define CP_TITLE_SIZE           12
#define CP_TEXT_SIZE            10
#define CP_LABEL_X_OFFSET       15
#define CP_VALUE_X_OFFSET       245
#define CP_TITLE_Y_OFFSET       10
#define CP_ROW_HEIGHT           58
#define CP_FIRST_ROW_Y          50

#define CP_BG_COLOR             clrBlack
#define CP_BORDER_COLOR         clrDimGray
#define CP_TITLE_COLOR          clrAqua
#define CP_LABEL_COLOR          clrWhite
#define CP_NEUTRAL_COLOR        clrYellow
#define CP_BUY_COLOR            clrLime
#define CP_SELL_COLOR           clrRed
#define CP_WARN_COLOR           clrOrange
#define CP_PENDING_COLOR        clrDodgerBlue
#define CP_BALANCE_COLOR        clrAqua   // [جدید] رنگ مخصوص سرمایه

//====================================================================
// محاسبه y برای یک ردیف خاص
//====================================================================
int ChartPanel_GetRowY(const int row)
  {
   return CP_Y + CP_FIRST_ROW_Y + (row * CP_ROW_HEIGHT);
  }

//------------------------------------------------------------------
// مقداردهی اولیه وضعیت پنل
//------------------------------------------------------------------
void ChartPanel_InitState(ChartPanelState &state)
  {
   state.market_status        = "در حال بررسی";
   state.direction            = "نامشخص";
   state.structure            = "نامشخص";
   state.scenario             = "بدون سناریو";
   state.entry_status         = "در انتظار";
   state.bot_status           = "فعال";
   state.current_risk_percent = 0.0;
   state.open_trades          = 0;
   state.pending_orders       = 0;
   state.open_profit          = 0.0;
   state.today_profit         = 0.0;
   state.overall_profit       = 0.0;      // [جدید]
   state.account_balance      = 0.0;      // [جدید]
   state.updated_time         = 0;
  }

//------------------------------------------------------------------
// [اصلاح v2] محاسبه سود/ضرر کل از تاریخچه - شامل همه معاملات نماد
// (ربات + دستی)
//------------------------------------------------------------------
double ChartPanel_CalculateOverallProfit(const string symbol = "")
  {
   double total_profit = 0.0;
   
   //--- انتخاب تمام تاریخچه
   if(!HistorySelect(0, TimeCurrent()))
      return 0.0;
   
   int total_deals = HistoryDealsTotal();
   string target_symbol = (symbol == "" ? _Symbol : symbol);
   
   for(int i = 0; i < total_deals; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      
      //--- فقط این نماد
      string deal_symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      if(deal_symbol != target_symbol)
         continue;
      
      //--- فقط معامله‌های خروج (بسته شده)
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
         continue;
      
      //--- جمع سود، کمیسیون، سواپ و فی
      total_profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      total_profit += HistoryDealGetDouble(ticket, DEAL_SWAP);
      total_profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      total_profit += HistoryDealGetDouble(ticket, DEAL_FEE);
     }
   
   return total_profit;
  }

//------------------------------------------------------------------
// [جدید] دریافت سرمایه حساب
//------------------------------------------------------------------
double ChartPanel_GetAccountBalance()
  {
   return AccountInfoDouble(ACCOUNT_BALANCE);
  }

//------------------------------------------------------------------
// تنظیم ویژگی‌های متن
//------------------------------------------------------------------
void ChartPanel_SetLabel(const long chart_id,
                         const string name,
                         const string text,
                         const int x,
                         const int y,
                         const int font_size = 10,
                         const string font = "Arial Bold",
                         const color text_color = CP_LABEL_COLOR)
  {
   if(ObjectFind(chart_id, name) < 0)
     {
      if(!ObjectCreate(chart_id, name, OBJ_LABEL, 0, 0, 0))
         return;
     }

   ObjectSetInteger(chart_id, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chart_id, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(chart_id, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(chart_id, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(chart_id, name, OBJPROP_COLOR, text_color);
   ObjectSetString(chart_id, name, OBJPROP_FONT, font);
   ObjectSetString(chart_id, name, OBJPROP_TEXT, text);
   ObjectSetInteger(chart_id, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chart_id, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(chart_id, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(chart_id, name, OBJPROP_BACK, false);
   ObjectSetInteger(chart_id, name, OBJPROP_ZORDER, 10);
  }

//------------------------------------------------------------------
// ایجاد پس‌زمینه پنل
//------------------------------------------------------------------
void ChartPanel_CreateBackground(const long chart_id,
                                 const int x,
                                 const int y,
                                 const int width,
                                 const int height)
  {
   if(ObjectFind(chart_id, CP_BG) < 0)
     {
      if(!ObjectCreate(chart_id, CP_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return;
     }

   ObjectSetInteger(chart_id, CP_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(chart_id, CP_BG, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(chart_id, CP_BG, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(chart_id, CP_BG, OBJPROP_XSIZE, width);
   ObjectSetInteger(chart_id, CP_BG, OBJPROP_YSIZE, height);
   ObjectSetInteger(chart_id, CP_BG, OBJPROP_BACK, false);
   ObjectSetInteger(chart_id, CP_BG, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chart_id, CP_BG, OBJPROP_SELECTED, false);
   ObjectSetInteger(chart_id, CP_BG, OBJPROP_HIDDEN, true);
   ObjectSetInteger(chart_id, CP_BG, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(chart_id, CP_BG, OBJPROP_BGCOLOR, CP_BG_COLOR);
   ObjectSetInteger(chart_id, CP_BG, OBJPROP_COLOR, CP_BORDER_COLOR);
   ObjectSetInteger(chart_id, CP_BG, OBJPROP_ZORDER, 0);
  }

//------------------------------------------------------------------
// ایجاد پنل - 14 ردیف
//------------------------------------------------------------------
void ChartPanel_Create(const long chart_id,
                       const int x = CP_X,
                       const int y = CP_Y,
                       const int width = CP_WIDTH,
                       const int height = CP_HEIGHT)
  {
   ChartPanel_CreateBackground(chart_id, x, y, width, height);

   ChartPanel_SetLabel(chart_id, CP_TITLE,
                       "TFlab New EA V.5",
                       x + CP_LABEL_X_OFFSET,
                       y + CP_TITLE_Y_OFFSET,
                       CP_TITLE_SIZE,
                       "Arial Bold",
                       CP_TITLE_COLOR);

   //--- ایجاد لیبل‌ها و مقادیر برای 14 ردیف
   for(int i = 0; i < 14; i++)
     {
      string line_name = CP_PREFIX + "L" + IntegerToString(i + 1);
      string val_name  = CP_PREFIX + "V" + IntegerToString(i + 1);
      int row_y = ChartPanel_GetRowY(i);
      ChartPanel_SetLabel(chart_id, line_name, "", x + CP_LABEL_X_OFFSET, row_y);
      ChartPanel_SetLabel(chart_id, val_name,  "", x + CP_VALUE_X_OFFSET, row_y);
     }

   ChartRedraw(chart_id);
  }

//------------------------------------------------------------------
// حذف پنل و تمام اجزای آن
//------------------------------------------------------------------
void ChartPanel_Destroy(const long chart_id)
  {
   ObjectDelete(chart_id, CP_BG);
   ObjectDelete(chart_id, CP_TITLE);

   //--- حذف همه ردیف‌ها (14 ردیف)
   for(int i = 1; i <= 14; i++)
     {
      ObjectDelete(chart_id, CP_PREFIX + "L" + IntegerToString(i));
      ObjectDelete(chart_id, CP_PREFIX + "V" + IntegerToString(i));
     }

   //--- پاکسازی کامل هر آبجکت با پیشوند CP_PREFIX
   int total = ObjectsTotal(chart_id, 0, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(chart_id, i, 0, -1);
      if(StringFind(name, CP_PREFIX) == 0)
         ObjectDelete(chart_id, name);
     }

   ChartRedraw(chart_id);
  }

//------------------------------------------------------------------
// تشخیص رنگ بر اساس متن
//------------------------------------------------------------------
color ChartPanel_GetValueColor(const string value,
                               const bool allow_profit_color = false,
                               const double numeric_value = 0.0)
  {
   if(StringFind(value, "خرید") >= 0 ||
      StringFind(value, "صعودی") >= 0 ||
      StringFind(value, "صعود") >= 0 ||
      StringFind(value, "BUY") >= 0 ||
      StringFind(value, "BULLISH") >= 0 ||
      StringFind(value, "Bullish") >= 0 ||
      StringFind(value, "فعالی") >= 0 ||
      StringFind(value, "ادامه حرکت") >= 0)
      return CP_BUY_COLOR;

   if(StringFind(value, "فروش") >= 0 ||
      StringFind(value, "نزولی") >= 0 ||
      StringFind(value, "نزول") >= 0 ||
      StringFind(value, "SELL") >= 0 ||
      StringFind(value, "BEARISH") >= 0 ||
      StringFind(value, "Bearish") >= 0 ||
      StringFind(value, "برگشت") >= 0 ||
      StringFind(value, "باطل") >= 0)
      return CP_SELL_COLOR;

   if(StringFind(value, "منقضی") >= 0 ||
      StringFind(value, "خطا") >= 0 ||
      StringFind(value, "نامعتبر") >= 0 ||
      StringFind(value, "رد شد") >= 0)
      return CP_WARN_COLOR;

   if(allow_profit_color)
     {
      if(numeric_value > 0.0) return CP_BUY_COLOR;
      if(numeric_value < 0.0) return CP_SELL_COLOR;
     }

   return CP_NEUTRAL_COLOR;
  }

//------------------------------------------------------------------
// به‌روزرسانی محتوای پنل - 14 ردیف
//------------------------------------------------------------------
void ChartPanel_Update(const long chart_id,
                       const ChartPanelState &state)
  {
   const int x_label = CP_X + CP_LABEL_X_OFFSET;
   const int x_value = CP_X + CP_VALUE_X_OFFSET;

   //--- ردیف‌ها
   const int y1  = ChartPanel_GetRowY(0);
   const int y2  = ChartPanel_GetRowY(1);
   const int y3  = ChartPanel_GetRowY(2);
   const int y4  = ChartPanel_GetRowY(3);
   const int y5  = ChartPanel_GetRowY(4);
   const int y6  = ChartPanel_GetRowY(5);
   const int y7  = ChartPanel_GetRowY(6);
   const int y8  = ChartPanel_GetRowY(7);
   const int y9  = ChartPanel_GetRowY(8);
   const int y10 = ChartPanel_GetRowY(9);
   const int y11 = ChartPanel_GetRowY(10);
   const int y12 = ChartPanel_GetRowY(11);
   const int y13 = ChartPanel_GetRowY(12);  // [جدید]
   const int y14 = ChartPanel_GetRowY(13);  // [جدید]

   string value1  = state.market_status;
   string value2  = state.direction;
   string value3  = state.structure;
   string value4  = state.scenario;
   string value5  = state.entry_status;
   string value6  = state.bot_status;
   string value7  = DoubleToString(state.current_risk_percent, 2) + "%";
   string value8  = IntegerToString(state.open_trades);
   string value9  = IntegerToString(state.pending_orders);
   string value10 = DoubleToString(state.open_profit, 2);
   string value11 = DoubleToString(state.today_profit, 2);
   string value12 = DoubleToString(state.overall_profit, 2);      // [جدید]
   string value13 = DoubleToString(state.account_balance, 2);     // [جدید]
   string value14 = (state.updated_time > 0 ?
                     TimeToString(state.updated_time, TIME_MINUTES) : "-");

   color color2  = ChartPanel_GetValueColor(value2);
   color color3  = ChartPanel_GetValueColor(value3);
   color color4  = ChartPanel_GetValueColor(value4);
   color color5  = ChartPanel_GetValueColor(value5);
   color color6  = ChartPanel_GetValueColor(value6);
   color color9  = (state.pending_orders > 0 ? CP_PENDING_COLOR : CP_NEUTRAL_COLOR);
   color color10 = ChartPanel_GetValueColor(value10, true, state.open_profit);
   color color11 = ChartPanel_GetValueColor(value11, true, state.today_profit);
   color color12 = ChartPanel_GetValueColor(value12, true, state.overall_profit);  // [جدید]
   color color13 = CP_BALANCE_COLOR;  // [جدید] سرمایه همیشه طلایی

   //--- لیبل‌ها
   ChartPanel_SetLabel(chart_id, CP_LINE1,  "حال:",                  x_label, y1,  CP_TEXT_SIZE, "Arial", CP_LABEL_COLOR);
   ChartPanel_SetLabel(chart_id, CP_LINE2,  "جهت فرصت:",             x_label, y2,  CP_TEXT_SIZE, "Arial", CP_LABEL_COLOR);
   ChartPanel_SetLabel(chart_id, CP_LINE3,  "ساختار:",               x_label, y3,  CP_TEXT_SIZE, "Arial", CP_LABEL_COLOR);
   ChartPanel_SetLabel(chart_id, CP_LINE4,  "فرصت/سناریو:",          x_label, y4,  CP_TEXT_SIZE, "Arial", CP_LABEL_COLOR);
   ChartPanel_SetLabel(chart_id, CP_LINE5,  "برآورد آینده:",         x_label, y5,  CP_TEXT_SIZE, "Arial", CP_LABEL_COLOR);
   ChartPanel_SetLabel(chart_id, CP_LINE6,  "وضعیت ربات:",           x_label, y6,  CP_TEXT_SIZE, "Arial", CP_LABEL_COLOR);
   ChartPanel_SetLabel(chart_id, CP_LINE7,  "ریسک جاری:",            x_label, y7,  CP_TEXT_SIZE, "Arial", CP_LABEL_COLOR);
   ChartPanel_SetLabel(chart_id, CP_LINE8,  "معاملات باز:",          x_label, y8,  CP_TEXT_SIZE, "Arial", CP_LABEL_COLOR);
   ChartPanel_SetLabel(chart_id, CP_LINE9,  "معاملات منتظر تایید:",  x_label, y9,  CP_TEXT_SIZE, "Arial", CP_LABEL_COLOR);
   ChartPanel_SetLabel(chart_id, CP_LINE10, "سود/ضرر باز:",          x_label, y10, CP_TEXT_SIZE, "Arial", CP_LABEL_COLOR);
   ChartPanel_SetLabel(chart_id, CP_LINE11, "سود/ضرر امروز:",        x_label, y11, CP_TEXT_SIZE, "Arial", CP_LABEL_COLOR);
   ChartPanel_SetLabel(chart_id, CP_LINE12, "سود/ضرر کل:",           x_label, y12, CP_TEXT_SIZE, "Arial", CP_LABEL_COLOR);  // [جدید]
   ChartPanel_SetLabel(chart_id, CP_LINE13, "سرمایه:",               x_label, y13, CP_TEXT_SIZE, "Arial", CP_LABEL_COLOR);  // [جدید]
   ChartPanel_SetLabel(chart_id, CP_LINE14, "آخرین به‌روزرسانی:",    x_label, y14, CP_TEXT_SIZE, "Arial", CP_LABEL_COLOR);

   //--- مقادیر
   ChartPanel_SetLabel(chart_id, CP_VAL1,  value1,  x_value, y1,  CP_TEXT_SIZE, "Arial", CP_NEUTRAL_COLOR);
   ChartPanel_SetLabel(chart_id, CP_VAL2,  value2,  x_value, y2,  CP_TEXT_SIZE, "Arial", color2);
   ChartPanel_SetLabel(chart_id, CP_VAL3,  value3,  x_value, y3,  CP_TEXT_SIZE, "Arial", color3);
   ChartPanel_SetLabel(chart_id, CP_VAL4,  value4,  x_value, y4,  CP_TEXT_SIZE, "Arial", color4);
   ChartPanel_SetLabel(chart_id, CP_VAL5,  value5,  x_value, y5,  CP_TEXT_SIZE, "Arial", color5);
   ChartPanel_SetLabel(chart_id, CP_VAL6,  value6,  x_value, y6,  CP_TEXT_SIZE, "Arial", color6);
   ChartPanel_SetLabel(chart_id, CP_VAL7,  value7,  x_value, y7,  CP_TEXT_SIZE, "Arial", CP_NEUTRAL_COLOR);
   ChartPanel_SetLabel(chart_id, CP_VAL8,  value8,  x_value, y8,  CP_TEXT_SIZE, "Arial", CP_NEUTRAL_COLOR);
   ChartPanel_SetLabel(chart_id, CP_VAL9,  value9,  x_value, y9,  CP_TEXT_SIZE, "Arial", color9);
   ChartPanel_SetLabel(chart_id, CP_VAL10, value10, x_value, y10, CP_TEXT_SIZE, "Arial", color10);
   ChartPanel_SetLabel(chart_id, CP_VAL11, value11, x_value, y11, CP_TEXT_SIZE, "Arial", color11);
   ChartPanel_SetLabel(chart_id, CP_VAL12, value12, x_value, y12, CP_TEXT_SIZE, "Arial", color12);  // [جدید]
   ChartPanel_SetLabel(chart_id, CP_VAL13, value13, x_value, y13, CP_TEXT_SIZE, "Arial", color13);  // [جدید]
   ChartPanel_SetLabel(chart_id, CP_VAL14, value14, x_value, y14, CP_TEXT_SIZE, "Arial", CP_NEUTRAL_COLOR);

   ChartRedraw(chart_id);
  }

//------------------------------------------------------------------
// به‌روزرسانی زمان آخرین پایش
//------------------------------------------------------------------
void ChartPanel_SetUpdatedTime(ChartPanelState &state,
                               const datetime current_time)
  {
   state.updated_time = current_time;
  }

//------------------------------------------------------------------
// متن وضعیت کامل پنل
//------------------------------------------------------------------
string ChartPanel_StateToText(const ChartPanelState &state)
  {
   string text = "";
   text += "وضعیت بازار=" + state.market_status;
   text += " | جهت=" + state.direction;
   text += " | ساختار=" + state.structure;
   text += " | سناریو=" + state.scenario;
   text += " | ورود=" + state.entry_status;
   text += " | ربات=" + state.bot_status;
   text += " | ریسک=" + DoubleToString(state.current_risk_percent, 2) + "%";
   text += " | معاملات باز=" + IntegerToString(state.open_trades);
   text += " | Pending=" + IntegerToString(state.pending_orders);
   text += " | سود/ضرر باز=" + DoubleToString(state.open_profit, 2);
   text += " | سود/ضرر امروز=" + DoubleToString(state.today_profit, 2);
   text += " | سود/ضرر کل=" + DoubleToString(state.overall_profit, 2);      // [جدید]
   text += " | سرمایه=" + DoubleToString(state.account_balance, 2);        // [جدید]
   if(state.updated_time > 0)
      text += " | Updated=" + TimeToString(state.updated_time, TIME_MINUTES);
   return text;
  }

#endif // __TFLAB_CHART_PANEL_MQH__