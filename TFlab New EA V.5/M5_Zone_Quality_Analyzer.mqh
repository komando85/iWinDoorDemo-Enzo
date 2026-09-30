#ifndef __TFLAB_M5_ZONE_QUALITY_ANALYZER_MQH__
#define __TFLAB_M5_ZONE_QUALITY_ANALYZER_MQH__

//+------------------------------------------------------------------+
//|                 M5_Zone_Quality_Analyzer.mqh                     |
//|                 TFlab New EA V.5                                     |
//|                                                                  |
//| مسئولیت: تحلیل کیفیت Zone و Movement در تایم‌فریم M5            |
//|                                                                  |
//| v2.1 - Fixed ZeroMemory + ATR-based proximity + لاگ تشخیصی    |
//+------------------------------------------------------------------+
#property strict

#include "EA_Inputs.mqh"
#include "M5_Movement_Metrics.mqh"
#include "Zone_Engine.mqh"

//====================================================================
// موقعیت قیمت نسبت به Zone
//====================================================================
enum ENUM_M5_ZONE_POSITION
  {
   M5_ZONE_POSITION_OUTSIDE = 0,
   M5_ZONE_POSITION_BUY,
   M5_ZONE_POSITION_SELL,
   M5_ZONE_POSITION_BOTH,
   M5_ZONE_POSITION_NEAR_BUY,
   M5_ZONE_POSITION_NEAR_SELL
  };

//====================================================================
// Snapshot کیفیت Zone
//====================================================================
struct M5ZoneQualitySnapshot
  {
   bool                    valid;
   
   double                  movement_quality_score;
   double                  zone_quality_score;
   double                  proximity_score;
   double                  movement_alignment_score;
   double                  combined_quality_score;
   
   //--- [جدید] معیارهای کمکی
   double                  nearest_zone_distance_points;
   double                  nearest_zone_strength;
   double                  atr_points;
   double                  near_threshold_points;
   
   ENUM_M5_ZONE_POSITION   zone_position;
   string                  reason;
  };

//====================================================================
// مقداردهی اولیه
// [اصلاح] مقداردهی دستی به جای ZeroMemory
//====================================================================
void M5ZoneQuality_Reset(M5ZoneQualitySnapshot &s)
  {
   s.valid                       = false;
   s.movement_quality_score      = 0.0;
   s.zone_quality_score          = 0.0;
   s.proximity_score             = 0.0;
   s.movement_alignment_score    = 0.0;
   s.combined_quality_score      = 0.0;
   
   s.nearest_zone_distance_points = DBL_MAX;
   s.nearest_zone_strength       = 0.0;
   s.atr_points                  = 0.0;
   s.near_threshold_points       = 0.0;
   
   s.zone_position               = M5_ZONE_POSITION_OUTSIDE;
   s.reason                      = "";
  }

//====================================================================
// تبدیل موقعیت به فارسی
//====================================================================
string M5ZoneQuality_PositionToPersian(const ENUM_M5_ZONE_POSITION p)
  {
   switch(p)
     {
      case M5_ZONE_POSITION_BUY:       return "داخل BUY Zone";
      case M5_ZONE_POSITION_SELL:      return "داخل SELL Zone";
      case M5_ZONE_POSITION_BOTH:      return "داخل BUY و SELL Zone";
      case M5_ZONE_POSITION_NEAR_BUY:  return "نزدیک BUY Zone";
      case M5_ZONE_POSITION_NEAR_SELL: return "نزدیک SELL Zone";
      default:                         return "خارج از Zone";
     }
  }

//====================================================================
// تحلیل کیفیت Zone/Movement
// [اصلاح] بهبود proximity + ATR-based threshold + وزن‌دهی
//====================================================================
bool M5ZoneQuality_Analyze(
   const M5MovementMetrics &m,
   const ZoneInfo &buy,
   const ZoneInfo &sell,
   const double price,
   M5ZoneQualitySnapshot &s)
  {
   M5ZoneQuality_Reset(s);

   if(!m.valid)
     {
      s.reason = "Movement معتبر نیست";
      return false;
     }

   if(price <= 0.0)
     {
      s.reason = "قیمت نامعتبر است";
      return false;
     }

   //=================================================================
   // محاسبه ATR برای threshold پویا
   //=================================================================
   double atr_price = 0.0;
   if(Inp_ATR_Period > 0)
     {
      int atr_handle = iATR(_Symbol, Inp_TF_Setup_M5, Inp_ATR_Period);
      if(atr_handle != INVALID_HANDLE)
        {
         double atr_buf[];
         ArraySetAsSeries(atr_buf, true);
         if(CopyBuffer(atr_handle, 0, 1, 1, atr_buf) == 1)
            atr_price = atr_buf[0];
         IndicatorRelease(atr_handle);
        }
     }
   
   s.atr_points = (atr_price > 0.0 ? atr_price / _Point : 0.0);

   //=================================================================
   // بررسی قرارگیری قیمت در Zone
   //=================================================================
   bool in_buy  = Zone_IsValid(buy) && Zone_ContainsPrice(buy, price);
   bool in_sell = Zone_IsValid(sell) && Zone_ContainsPrice(sell, price);

   //=================================================================
   // محاسبه فاصله از midpoint هر Zone
   //=================================================================
   double dist_buy  = DBL_MAX;
   double dist_sell = DBL_MAX;

   if(Zone_IsValid(buy))
     {
      double mid_buy = (buy.lower_price + buy.upper_price) * 0.5;
      dist_buy = MathAbs(price - mid_buy) / _Point;
     }

   if(Zone_IsValid(sell))
     {
      double mid_sell = (sell.lower_price + sell.upper_price) * 0.5;
      dist_sell = MathAbs(price - mid_sell) / _Point;
     }

   //=================================================================
   // Movement Quality Score
   //=================================================================
   s.movement_quality_score = MathMin(100.0, m.momentum_score);

   //=================================================================
   // Zone Quality Score
   // [اصلاح] میانگین وزنی strength Zoneهای معتبر
   //=================================================================
   double zone_strength_sum = 0.0;
   int zone_count = 0;

   if(Zone_IsValid(buy))
     {
      zone_strength_sum += buy.strength;
      zone_count++;
     }
   if(Zone_IsValid(sell))
     {
      zone_strength_sum += sell.strength;
      zone_count++;
     }

   if(zone_count > 0)
      s.zone_quality_score = zone_strength_sum / zone_count;
   else
      s.zone_quality_score = 0.0;

   //=================================================================
   // Nearest Zone
   //=================================================================
   s.nearest_zone_distance_points = MathMin(dist_buy, dist_sell);
   
   if(dist_buy < dist_sell && Zone_IsValid(buy))
      s.nearest_zone_strength = buy.strength;
   else if(Zone_IsValid(sell))
      s.nearest_zone_strength = sell.strength;
   else
      s.nearest_zone_strength = 0.0;

   //=================================================================
   // Proximity Score
   // [اصلاح] تابع نزولی ملایم + threshold پویا بر اساس ATR
   //=================================================================
   //--- [اصلاح] threshold پویا: 2 برابر ATR یا حداقل 100 point
   double near_threshold = 0.0;
   if(atr_price > 0.0)
      near_threshold = MathMax(atr_price * 2.0, _Point * 100.0) / _Point;
   else
      near_threshold = 300.0; // fallback
   
   s.near_threshold_points = near_threshold;

   if(s.nearest_zone_distance_points < DBL_MAX)
     {
      //--- [اصلاح] تابع نزولی: 100 در distance=0، 50 در distance=threshold، 0 در distance=2*threshold
      if(s.nearest_zone_distance_points <= near_threshold)
        {
         //--- بین 0 و threshold: score بین 50 و 100
         double ratio = s.nearest_zone_distance_points / near_threshold;
         s.proximity_score = 100.0 - (ratio * 50.0);
        }
      else if(s.nearest_zone_distance_points <= near_threshold * 2.0)
        {
         //--- بین threshold و 2*threshold: score بین 0 و 50
         double ratio = (s.nearest_zone_distance_points - near_threshold) / near_threshold;
         s.proximity_score = 50.0 - (ratio * 50.0);
        }
      else
         s.proximity_score = 0.0;
     }
   else
      s.proximity_score = 0.0;

   //=================================================================
   // Movement Alignment Score
   //=================================================================
   s.movement_alignment_score = m.directional_ratio * 100.0;

   //=================================================================
   // Combined Quality Score
   // [اصلاح] وزن‌دهی: zone_strength و proximity مهم‌تر هستند
   //=================================================================
   //--- وزن‌ها: Movement=20%, Zone=30%, Proximity=30%, Alignment=20%
   s.combined_quality_score =
      (s.movement_quality_score * 0.20) +
      (s.zone_quality_score * 0.30) +
      (s.proximity_score * 0.30) +
      (s.movement_alignment_score * 0.20);

   //=================================================================
   // Zone Position
   // [اصلاح] استفاده از near_threshold پویا
   //=================================================================
   if(in_buy && in_sell)
      s.zone_position = M5_ZONE_POSITION_BOTH;
   else if(in_buy)
      s.zone_position = M5_ZONE_POSITION_BUY;
   else if(in_sell)
      s.zone_position = M5_ZONE_POSITION_SELL;
   else if(dist_buy < dist_sell && dist_buy < near_threshold && Zone_IsValid(buy))
      s.zone_position = M5_ZONE_POSITION_NEAR_BUY;
   else if(dist_sell < near_threshold && Zone_IsValid(sell))
      s.zone_position = M5_ZONE_POSITION_NEAR_SELL;
   else
      s.zone_position = M5_ZONE_POSITION_OUTSIDE;

   s.valid = true;
   s.reason = "کیفیت Zone/M5 محاسبه شد | " +
              "Movement=" + DoubleToString(s.movement_quality_score, 1) + " | " +
              "Zone=" + DoubleToString(s.zone_quality_score, 1) + " | " +
              "Proximity=" + DoubleToString(s.proximity_score, 1) + " | " +
              "Alignment=" + DoubleToString(s.movement_alignment_score, 1) + " | " +
              "Combined=" + DoubleToString(s.combined_quality_score, 1) + " | " +
              "Position=" + M5ZoneQuality_PositionToPersian(s.zone_position);

   //=================================================================
   // [جدید] لاگ تشخیصی
   //=================================================================
   Print(
      "[M5 ZONE QUALITY] ANALYZED",
      " | MovementScore=", DoubleToString(s.movement_quality_score, 1),
      " | ZoneScore=", DoubleToString(s.zone_quality_score, 1),
      " | Proximity=", DoubleToString(s.proximity_score, 1),
      " | Alignment=", DoubleToString(s.movement_alignment_score, 1),
      " | Combined=", DoubleToString(s.combined_quality_score, 1),
      " | NearestDist=", DoubleToString(s.nearest_zone_distance_points, 1), " pts",
      " | NearestStr=", DoubleToString(s.nearest_zone_strength, 1),
      " | ATR=", DoubleToString(s.atr_points, 1), " pts",
      " | NearThreshold=", DoubleToString(s.near_threshold_points, 1), " pts",
      " | Position=", M5ZoneQuality_PositionToPersian(s.zone_position)
   );

   return true;
  }

//====================================================================
// اعتبارسنجی
//====================================================================
bool M5ZoneQuality_IsValid(const M5ZoneQualitySnapshot &s)
  {
   return s.valid;
  }

//====================================================================
// آیا کیفیت بالا است؟
//====================================================================
bool M5ZoneQuality_IsHighQuality(const M5ZoneQualitySnapshot &s, const double min_score = 65.0)
  {
   if(!s.valid)
      return false;
   return (s.combined_quality_score >= min_score);
  }

//====================================================================
// آیا قیمت در Zone است؟
//====================================================================
bool M5ZoneQuality_IsInZone(const M5ZoneQualitySnapshot &s)
  {
   if(!s.valid)
      return false;
   return (s.zone_position == M5_ZONE_POSITION_BUY ||
           s.zone_position == M5_ZONE_POSITION_SELL ||
           s.zone_position == M5_ZONE_POSITION_BOTH);
  }

//====================================================================
// آیا قیمت نزدیک Zone است؟
//====================================================================
bool M5ZoneQuality_IsNearZone(const M5ZoneQualitySnapshot &s)
  {
   if(!s.valid)
      return false;
   return (s.zone_position == M5_ZONE_POSITION_NEAR_BUY ||
           s.zone_position == M5_ZONE_POSITION_NEAR_SELL);
  }

#endif // __TFLAB_M5_ZONE_QUALITY_ANALYZER_MQH__