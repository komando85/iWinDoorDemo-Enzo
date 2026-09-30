#ifndef __TFLAB_M5_MOVEMENT_METRICS_MQH__
#define __TFLAB_M5_MOVEMENT_METRICS_MQH__

//+------------------------------------------------------------------+
//|                   M5_Movement_Metrics.mqh                        |
//|                   TFlab New EA V.5                                   |
//|                                                                  |
//| مسئولیت: تحلیل معیارهای حرکتی در تایم‌فریم M5                   |
//|                                                                  |
//| v2.1 - Fixed ZeroMemory + Volume-based directional + ATR       |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// ساختار معیارهای حرکتی M5
//====================================================================
struct M5MovementMetrics
  {
   bool     valid;
   
   //--- نسبت‌های پایه
   double   continuity_ratio;
   double   directional_ratio;
   double   efficiency_ratio;
   double   momentum_score;
   
   //--- [جدید] معیارهای کمکی
   double   net_move_points;
   double   gross_move_points;
   double   avg_range_points;
   double   atr_points;
   double   net_move_atr_multiple;
   double   bullish_volume;
   double   bearish_volume;
   int      total_bars;
   int      bullish_bars;
   int      bearish_bars;
   
   string   reason;
  };

//====================================================================
// مقداردهی اولیه
// [اصلاح] مقداردهی دستی فیلدها به جای ZeroMemory
//====================================================================
void M5MovementMetrics_Reset(M5MovementMetrics &m)
  {
   m.valid                   = false;
   m.continuity_ratio        = 0.0;
   m.directional_ratio       = 0.0;
   m.efficiency_ratio        = 0.0;
   m.momentum_score          = 0.0;
   
   m.net_move_points         = 0.0;
   m.gross_move_points       = 0.0;
   m.avg_range_points        = 0.0;
   m.atr_points              = 0.0;
   m.net_move_atr_multiple   = 0.0;
   m.bullish_volume          = 0.0;
   m.bearish_volume          = 0.0;
   m.total_bars              = 0;
   m.bullish_bars            = 0;
   m.bearish_bars            = 0;
   
   m.reason                  = "";
  }

//====================================================================
// تحلیل حرکت M5
// [اصلاح] بهبود directional_ratio + استفاده از ATR
//====================================================================
bool M5MovementMetrics_Analyze(
   const string symbol,
   const ENUM_TIMEFRAMES timeframe,
   const int lookback,
   const double unused,
   const int atr_period,
   M5MovementMetrics &m)
  {
   M5MovementMetrics_Reset(m);

   MqlRates r[];
   ArraySetAsSeries(r, true);
   
   int n = CopyRates(symbol, timeframe, 1, MathMax(10, lookback), r);
   if(n < 5)
     {
      m.reason = "داده حرکت کافی نیست | Copied=" + IntegerToString(n);
      return false;
     }

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
     {
      m.reason = "Point نماد معتبر نیست";
      return false;
     }

   //=================================================================
   // محاسبه gross و net move
   //=================================================================
   double gross = 0.0;
   double net_move = r[0].close - r[n - 1].close;
   double net_abs = MathAbs(net_move);
   
   int bullish_bars = 0;
   int bearish_bars = 0;
   double bullish_volume = 0.0;
   double bearish_volume = 0.0;
   double total_range = 0.0;

   for(int i = 0; i < n; i++)
     {
      double range = r[i].high - r[i].low;
      gross += range;
      total_range += range;
      
      double body = r[i].close - r[i].open;
      if(body > 0.0)
        {
         bullish_bars++;
         bullish_volume += body;
        }
      else if(body < 0.0)
        {
         bearish_bars++;
         bearish_volume += MathAbs(body);
        }
     }

   //=================================================================
   // محاسبه ATR
   //=================================================================
   double atr_value = 0.0;
   if(atr_period > 0)
     {
      int atr_handle = iATR(symbol, timeframe, atr_period);
      if(atr_handle != INVALID_HANDLE)
        {
         double atr_buf[];
         ArraySetAsSeries(atr_buf, true);
         if(CopyBuffer(atr_handle, 0, 1, 1, atr_buf) == 1)
            atr_value = atr_buf[0];
         IndicatorRelease(atr_handle);
        }
     }

   //=================================================================
   // [اصلاح] Directional Ratio بر اساس حجم حرکت (نه فقط تعداد)
   //=================================================================
   double total_volume = bullish_volume + bearish_volume;
   double dominant_volume = MathMax(bullish_volume, bearish_volume);
   
   if(total_volume > 0.0)
      m.directional_ratio = dominant_volume / total_volume;
   else
      m.directional_ratio = 0.5; // خنثی

   //=================================================================
   // Efficiency Ratio (Kauffman)
   //=================================================================
   m.efficiency_ratio = (gross > 0.0 ? net_abs / gross : 0.0);

   //=================================================================
   // Continuity Ratio
   //=================================================================
   m.continuity_ratio = m.directional_ratio * m.efficiency_ratio * 100.0;

   //=================================================================
   // [جدید] معیارهای کمکی بر حسب point
   //=================================================================
   m.net_move_points = net_abs / point;
   m.gross_move_points = gross / point;
   m.avg_range_points = (n > 0 ? (total_range / n) / point : 0.0);
   m.atr_points = (atr_value > 0.0 ? atr_value / point : 0.0);
   m.net_move_atr_multiple = (atr_value > 0.0 ? net_abs / atr_value : 0.0);
   m.bullish_volume = bullish_volume / point;
   m.bearish_volume = bearish_volume / point;
   m.total_bars = n;
   m.bullish_bars = bullish_bars;
   m.bearish_bars = bearish_bars;

   //=================================================================
   // [اصلاح] Momentum Score ترکیبی
   //=================================================================
   double momentum = 0.0;
   
   //--- Continuity (حداکثر 40 امتیاز)
   momentum += MathMin(40.0, m.continuity_ratio * 0.40);
   
   //--- Net Move ATR Multiple (حداکثر 30 امتیاز)
   momentum += MathMin(30.0, m.net_move_atr_multiple * 15.0);
   
   //--- Efficiency (حداکثر 30 امتیاز)
   momentum += MathMin(30.0, m.efficiency_ratio * 30.0);
   
   m.momentum_score = MathMin(100.0, momentum);

   m.valid = true;
   m.reason = "حرکت M5 تحلیل شد | " +
              "NetMove=" + DoubleToString(m.net_move_atr_multiple, 2) + " ATR | " +
              "Efficiency=" + DoubleToString(m.efficiency_ratio * 100.0, 1) + "% | " +
              "Directional=" + DoubleToString(m.directional_ratio * 100.0, 1) + "% | " +
              "Momentum=" + DoubleToString(m.momentum_score, 1);

   //=================================================================
   // [جدید] لاگ تشخیصی
   //=================================================================
   Print(
      "[M5 MOVEMENT] ANALYZED",
      " | Bars=", n,
      " | NetMove=", DoubleToString(m.net_move_points, 1), " pts",
      " | GrossMove=", DoubleToString(m.gross_move_points, 1), " pts",
      " | Efficiency=", DoubleToString(m.efficiency_ratio * 100.0, 1), "%",
      " | Directional=", DoubleToString(m.directional_ratio * 100.0, 1), "%",
      " | Continuity=", DoubleToString(m.continuity_ratio, 1),
      " | Momentum=", DoubleToString(m.momentum_score, 1),
      " | ATR_Mult=", DoubleToString(m.net_move_atr_multiple, 2)
   );

   return true;
  }

//====================================================================
// اعتبارسنجی
//====================================================================
bool M5MovementMetrics_IsValid(const M5MovementMetrics &m)
  {
   return m.valid;
  }

//====================================================================
// تشخیص جهت غالب
//====================================================================
string M5MovementMetrics_DominantDirection(const M5MovementMetrics &m)
  {
   if(!m.valid)
      return "NONE";
   
   if(m.bullish_volume > m.bearish_volume * 1.20)
      return "BULLISH";
   if(m.bearish_volume > m.bullish_volume * 1.20)
      return "BEARISH";
   
   return "NEUTRAL";
  }

//====================================================================
// آیا حرکت قوی است؟
//====================================================================
bool M5MovementMetrics_IsStrongMovement(const M5MovementMetrics &m, const double min_score = 60.0)
  {
   if(!m.valid)
      return false;
   return (m.momentum_score >= min_score);
  }

//====================================================================
// آیا حرکت کارآمد است؟ (Efficiency بالا)
//====================================================================
bool M5MovementMetrics_IsEfficientMovement(const M5MovementMetrics &m, const double min_efficiency = 0.40)
  {
   if(!m.valid)
      return false;
   return (m.efficiency_ratio >= min_efficiency);
  }

#endif // __TFLAB_M5_MOVEMENT_METRICS_MQH__