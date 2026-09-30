#ifndef __TRADE_SIGNAL_LABEL_MQH__
#define __TRADE_SIGNAL_LABEL_MQH__

//--------------------------------------------------
// تنظیمات نمایش BUY / SELL
//--------------------------------------------------
input bool   ShowTradeSignalLabel = true;
input int    TradeSignalOffsetPoints = 60;
input int    TradeSignalFontSize = 10;

// اگر صفر باشد همه معاملات بررسی می‌شوند.
// اگر Magic مشخص کنی، فقط معاملات همان EA نمایش داده می‌شوند.
input ulong  TradeSignalMagic = 0;
input int    TradeSignalHistoryDays = 0; // 0 = تمام تاریخچه موجود


//--------------------------------------------------
// ایجاد نوشته BUY / SELL روی چارت
//--------------------------------------------------
void DrawTradeSignalLabel(
   const bool     isBuy,
   const datetime dealTime,
   const double   dealPrice,
   const ulong    dealTicket
)
{
   if(!ShowTradeSignalLabel)
      return;

   string text = isBuy ? "BUY" : "SELL";

   string objectName = StringFormat(
      "TFLAB_SIGNAL_%s_%I64u",
      text,
      dealTicket
   );

   // کمی پایین‌تر از نقطه ورود
   double textPrice =
      dealPrice - (TradeSignalOffsetPoints * _Point);

   // اگر قبلاً وجود داشت، دوباره نساز
   if(ObjectFind(0, objectName) >= 0)
      return;

   if(!ObjectCreate(
      0,
      objectName,
      OBJ_TEXT,
      0,
      dealTime,
      textPrice
   ))
   {
      Print(
         "TradeSignalLabel: ObjectCreate failed. Error=",
         GetLastError()
      );
      return;
   }

   //------------------------------------------------
   // متن
   //------------------------------------------------
   ObjectSetString(
      0,
      objectName,
      OBJPROP_TEXT,
      text
   );

   //------------------------------------------------
   // BUY = آبی
   // SELL = قرمز
   //------------------------------------------------
   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_COLOR,
      isBuy ? clrBlue : clrRed
   );

   //------------------------------------------------
   // اندازه فونت
   //------------------------------------------------
   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_FONTSIZE,
      TradeSignalFontSize
   );

   //------------------------------------------------
   // فونت
   //------------------------------------------------
   ObjectSetString(
      0,
      objectName,
      OBJPROP_FONT,
      "Arial Bold"
   );

   //------------------------------------------------
   // متن وسط‌چین
   //------------------------------------------------
   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_ANCHOR,
      ANCHOR_CENTER
   );

   //------------------------------------------------
   // قابل انتخاب نباشد
   //------------------------------------------------
   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_SELECTABLE,
      false
   );

   //------------------------------------------------
   // با چارت نمایش داده شود
   //------------------------------------------------
   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_HIDDEN,
      false
   );

   ObjectSetInteger(
      0,
      objectName,
      OBJPROP_BACK,
      false
   );

   ChartRedraw(0);
}


//--------------------------------------------------
// پردازش معامله جدید
//--------------------------------------------------
void HandleTradeSignalTransaction(
   const MqlTradeTransaction &trans
)
{
   if(!ShowTradeSignalLabel)
      return;

   //------------------------------------------------
   // فقط Dealهای واقعی
   //------------------------------------------------
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   if(trans.deal == 0)
      return;

   //------------------------------------------------
   // اطمینان از وجود Deal در History
   //------------------------------------------------
   if(!HistoryDealSelect(trans.deal))
      return;

   //------------------------------------------------
   // فقط معاملات باز
   //
   // IN      = ورود
   // INOUT   = reversal
   //------------------------------------------------
   long dealEntry =
      HistoryDealGetInteger(
         trans.deal,
         DEAL_ENTRY
      );

   if(
      dealEntry != DEAL_ENTRY_IN &&
      dealEntry != DEAL_ENTRY_INOUT
   )
      return;

   //------------------------------------------------
   // Magic Number
   //------------------------------------------------
   long dealMagic =
      HistoryDealGetInteger(
         trans.deal,
         DEAL_MAGIC
      );

   if(
      TradeSignalMagic != 0 &&
      (ulong)dealMagic != TradeSignalMagic
   )
      return;

   //------------------------------------------------
   // نوع معامله
   //------------------------------------------------
   long dealType =
      HistoryDealGetInteger(
         trans.deal,
         DEAL_TYPE
      );

   bool isBuy;

   if(dealType == DEAL_TYPE_BUY)
      isBuy = true;
   else
   if(dealType == DEAL_TYPE_SELL)
      isBuy = false;
   else
      return;

   //------------------------------------------------
   // زمان ورود
   //------------------------------------------------
   datetime dealTime =
      (datetime)HistoryDealGetInteger(
         trans.deal,
         DEAL_TIME
      );

   //------------------------------------------------
   // قیمت ورود
   //------------------------------------------------
   double dealPrice =
      HistoryDealGetDouble(
         trans.deal,
         DEAL_PRICE
      );

   //------------------------------------------------
   // رسم BUY / SELL
   //------------------------------------------------
   DrawTradeSignalLabel(
      isBuy,
      dealTime,
      dealPrice,
      trans.deal
   );
}


//--------------------------------------------------
// نمایش برچسب معاملات قبلی از History
//--------------------------------------------------
void DrawHistoricalTradeSignalLabels()
{
   if(!ShowTradeSignalLabel)
      return;

   datetime toTime = TimeCurrent();
   datetime fromTime = 0;

   if(TradeSignalHistoryDays > 0)
      fromTime = toTime - (datetime)TradeSignalHistoryDays * 86400;

   if(!HistorySelect(fromTime, toTime))
   {
      Print("TradeSignalLabel: HistorySelect failed. Error=", GetLastError());
      return;
   }

   ulong targetMagic =
      (TradeSignalMagic != 0)
      ? TradeSignalMagic
      : Inp_MagicNumber;

   int total = HistoryDealsTotal();
   int drawn = 0;

   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;

      string symbol =
         HistoryDealGetString(ticket, DEAL_SYMBOL);

      if(symbol != _Symbol)
         continue;

      long magic =
         HistoryDealGetInteger(ticket, DEAL_MAGIC);

      if((ulong)magic != targetMagic)
         continue;

      long entry =
         HistoryDealGetInteger(ticket, DEAL_ENTRY);

      // فقط ورود واقعی به پوزیشن
      if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_INOUT)
         continue;

      long type =
         HistoryDealGetInteger(ticket, DEAL_TYPE);

      bool isBuy;

      if(type == DEAL_TYPE_BUY)
         isBuy = true;
      else if(type == DEAL_TYPE_SELL)
         isBuy = false;
      else
         continue;

      datetime dealTime =
         (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

      double dealPrice =
         HistoryDealGetDouble(ticket, DEAL_PRICE);

      DrawTradeSignalLabel(
         isBuy,
         dealTime,
         dealPrice,
         ticket);

      drawn++;
   }

   Print(
      "TradeSignalLabel: Historical labels processed = ",
      drawn,
      " | HistoryDeals = ",
      total);

   ChartRedraw(0);
}

#endif