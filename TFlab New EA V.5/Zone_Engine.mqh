//+------------------------------------------------------------------+
//|                         Zone_Engine.mqh                           |
//|                         TFlab New EA V.5                              |
//|                                                                  |
//| کشف، ارزیابی و مدیریت نواحی قیمتی                                |
//| بدون Entry / Risk / SL / TP / Execution                           |
//|                                                                  |
//| ZONE ENGINE v2.30 - Fixed bugs + Better diagnostics              |
//+------------------------------------------------------------------+
#ifndef __ZONE_ENGINE_MQH__
#define __ZONE_ENGINE_MQH__

#property strict
#include "EA_Inputs.mqh"

//====================================================================
// نوع Zone
//====================================================================
enum ENUM_ZONE_TYPE
  {
   ZONE_TYPE_NONE = 0,
   ZONE_TYPE_ORIGIN,
   ZONE_TYPE_STRUCTURE,
   ZONE_TYPE_IMBALANCE,
   ZONE_TYPE_PULLBACK
  };

//====================================================================
// وضعیت Zone
//====================================================================
enum ENUM_ZONE_STATUS
  {
   ZONE_STATUS_UNKNOWN = 0,
   ZONE_STATUS_CANDIDATE,
   ZONE_STATUS_ACTIVE,
   ZONE_STATUS_TESTED,
   ZONE_STATUS_USED,
   ZONE_STATUS_INVALID,
   ZONE_STATUS_EXPIRED
  };

//====================================================================
// جهت Zone
//====================================================================
enum ENUM_ZONE_DIRECTION
  {
   ZONE_DIRECTION_NONE = 0,
   ZONE_DIRECTION_BUY,
   ZONE_DIRECTION_SELL
  };

//====================================================================
// وضعیت فاصله قیمت از Zone
//====================================================================
enum ENUM_ZONE_DISTANCE_STATE
  {
   ZONE_DISTANCE_UNKNOWN = 0,
   ZONE_DISTANCE_INSIDE,
   ZONE_DISTANCE_NEAR,
   ZONE_DISTANCE_FAR
  };

//====================================================================
// اطلاعات یک Zone
//====================================================================
struct ZoneInfo
  {
   ulong id;
   ENUM_ZONE_TYPE type;
   ENUM_ZONE_DIRECTION direction;
   ENUM_ZONE_STATUS status;
   double upper_price;
   double lower_price;
   double invalidation_price;
   datetime created_time;
   datetime updated_time;
   datetime expiration_time;
   ENUM_TIMEFRAMES timeframe;
   int source_shift;
   int source_bars;
   double strength;
   double freshness;
   double width_points;
   double distance_points;
   string source;
   string reason;
  };

//====================================================================
// Snapshot موتور Zone
//====================================================================
struct ZoneEngineSnapshot
  {
   bool valid;
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   datetime analysis_time;
   double current_price;
   double atr_points;
   int total_zones;
   int active_zones;
   int buy_zones;
   int sell_zones;
   int nearest_buy_index;
   int nearest_sell_index;
   double nearest_buy_distance_points;
   double nearest_sell_distance_points;
   ENUM_ZONE_DISTANCE_STATE price_zone_state;
   string status_text;
   string reason;
  };

//====================================================================
// کتاب Zone ها
//====================================================================
struct ZoneBook
  {
   ZoneInfo zones[];
   int count;
   ulong next_id;
   datetime last_refresh;
  };

ZoneBook g_zone_book;
ZoneEngineSnapshot g_zone_snapshot;

//====================================================================
// توابع تبدیل
//====================================================================
string ZoneTypeToPersian(const ENUM_ZONE_TYPE type)
  {
   switch(type)
     {
      case ZONE_TYPE_ORIGIN:    return "مبدأ حرکت";
      case ZONE_TYPE_STRUCTURE: return "ساختاری";
      case ZONE_TYPE_IMBALANCE: return "عدم تعادل";
      case ZONE_TYPE_PULLBACK:  return "اصلاحی";
      default:                  return "نامشخص";
     }
  }

string ZoneStatusToPersian(const ENUM_ZONE_STATUS status)
  {
   switch(status)
     {
      case ZONE_STATUS_CANDIDATE: return "کاندیدا";
      case ZONE_STATUS_ACTIVE:    return "فعال";
      case ZONE_STATUS_TESTED:    return "تست شده";
      case ZONE_STATUS_USED:      return "استفاده شده";
      case ZONE_STATUS_INVALID:   return "باطل";
      case ZONE_STATUS_EXPIRED:   return "منقضی";
      default:                    return "نامشخص";
     }
  }

string ZoneDirectionToPersian(const ENUM_ZONE_DIRECTION direction)
  {
   switch(direction)
     {
      case ZONE_DIRECTION_BUY:  return "خرید";
      case ZONE_DIRECTION_SELL: return "فروش";
      default:                  return "بدون جهت";
     }
  }

string ZoneDistanceToPersian(const ENUM_ZONE_DISTANCE_STATE state)
  {
   switch(state)
     {
      case ZONE_DISTANCE_INSIDE: return "داخل Zone";
      case ZONE_DISTANCE_NEAR:   return "نزدیک Zone";
      case ZONE_DISTANCE_FAR:    return "دور از Zone";
      default:                   return "نامشخص";
     }
  }

//====================================================================
// مقداردهی اولیه
//====================================================================
void Zone_Init(ZoneInfo &zone)
  {
   ZeroMemory(zone);
   zone.id = 0;
   zone.type = ZONE_TYPE_NONE;
   zone.direction = ZONE_DIRECTION_NONE;
   zone.status = ZONE_STATUS_UNKNOWN;
   zone.timeframe = PERIOD_CURRENT;
   zone.source_shift = -1;
   zone.source_bars = 0;
  }

void ZoneBook_Init()
  {
   ArrayResize(g_zone_book.zones, 0);
   g_zone_book.count = 0;
   g_zone_book.next_id = 1;
   g_zone_book.last_refresh = 0;
   ZeroMemory(g_zone_snapshot);
   g_zone_snapshot.nearest_buy_index = -1;
   g_zone_snapshot.nearest_sell_index = -1;
  }

//====================================================================
// اعتبارسنجی
//====================================================================
bool Zone_IsValid(const ZoneInfo &zone)
  {
   if(zone.id == 0 || zone.type == ZONE_TYPE_NONE || zone.direction == ZONE_DIRECTION_NONE)
      return false;
   if(zone.lower_price <= 0.0 || zone.upper_price <= zone.lower_price)
      return false;
   if(zone.invalidation_price <= 0.0 || zone.timeframe == PERIOD_CURRENT)
      return false;
   return true;
  }

bool Zone_IsActive(const ZoneInfo &zone)
  {
   if(!Zone_IsValid(zone)) return false;
   return (zone.status == ZONE_STATUS_CANDIDATE ||
           zone.status == ZONE_STATUS_ACTIVE ||
           zone.status == ZONE_STATUS_TESTED);
  }

bool Zone_ContainsPrice(const ZoneInfo &zone, const double price)
  {
   return Zone_IsValid(zone) && price >= zone.lower_price && price <= zone.upper_price;
  }

double Zone_Range(const ZoneInfo &zone)
  {
   return (zone.upper_price > zone.lower_price ? zone.upper_price - zone.lower_price : 0.0);
  }

double Zone_Midpoint(const ZoneInfo &zone)
  {
   if(!Zone_IsValid(zone)) return 0.0;
   return (zone.upper_price + zone.lower_price) / 2.0;
  }

//====================================================================
// ساخت Zone
//====================================================================
bool Zone_Create(const ulong id, const ENUM_ZONE_TYPE type, const ENUM_ZONE_DIRECTION direction,
                 const double lower_price, const double upper_price, const double invalidation_price,
                 const datetime created_time, const datetime expiration_time,
                 const ENUM_TIMEFRAMES timeframe, const double strength,
                 const string source, const string reason, ZoneInfo &zone)
  {
   Zone_Init(zone);
   if(id == 0 || type == ZONE_TYPE_NONE || direction == ZONE_DIRECTION_NONE) return false;
   if(lower_price <= 0.0 || upper_price <= lower_price || invalidation_price <= 0.0) return false;
   
   zone.id = id;
   zone.type = type;
   zone.direction = direction;
   zone.status = ZONE_STATUS_CANDIDATE;
   zone.lower_price = lower_price;
   zone.upper_price = upper_price;
   zone.invalidation_price = invalidation_price;
   zone.created_time = created_time;
   zone.updated_time = created_time;
   zone.expiration_time = expiration_time;
   zone.timeframe = timeframe;
   zone.strength = MathMax(0.0, MathMin(100.0, strength));
   zone.freshness = 100.0;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   zone.width_points = (point > 0.0 ? (upper_price - lower_price) / point : 0.0);
   zone.source = source;
   zone.reason = reason;
   
   return Zone_IsValid(zone);
  }

//====================================================================
// افزودن Zone به کتاب
//====================================================================
bool ZoneBook_Add(const ZoneInfo &zone)
  {
   if(!Zone_IsValid(zone)) return false;
   if(g_zone_book.count >= MathMax(1, Inp_Max_Active_Zones)) return false;
   
   int n = g_zone_book.count + 1;
   if(ArrayResize(g_zone_book.zones, n) != n) return false;
   
   ZoneInfo copy = zone;
   g_zone_book.zones[g_zone_book.count] = copy;
   g_zone_book.count = n;
   
   //--- لاگ تشخیصی
   Print(
      "[ZONE ENGINE] CREATED",
      " | ID=", zone.id,
      " | Type=", ZoneTypeToPersian(zone.type),
      " | Dir=", ZoneDirectionToPersian(zone.direction),
      " | Lower=", DoubleToString(zone.lower_price, _Digits),
      " | Upper=", DoubleToString(zone.upper_price, _Digits),
      " | Invalid=", DoubleToString(zone.invalidation_price, _Digits),
      " | Strength=", DoubleToString(zone.strength, 1),
      " | ", zone.reason
   );
   
   return true;
  }

void ZoneBook_Clear()
  {
   ArrayResize(g_zone_book.zones, 0);
   g_zone_book.count = 0;
  }

//====================================================================
// بررسی ابطال Zone با Buffer
// [اصلاح] افزودن buffer برای جلوگیری از fakeout
//====================================================================
bool Zone_CheckInvalidation(const ZoneInfo &zone, const double price)
  {
   if(!Zone_IsValid(zone)) return true;
   
   //--- محاسبه buffer: حداقل 3 point یا 2% عرض Zone
   double buffer_points = 3.0;
   if(zone.width_points > 0.0)
     {
      double width_buffer = zone.width_points * 0.02;
      buffer_points = MathMax(buffer_points, width_buffer);
     }
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double buffer_price = buffer_points * point;
   
   if(zone.direction == ZONE_DIRECTION_BUY && price < zone.invalidation_price - buffer_price)
      return true;
   if(zone.direction == ZONE_DIRECTION_SELL && price > zone.invalidation_price + buffer_price)
      return true;
   
   return false;
  }

//====================================================================
// به‌روزرسانی وضعیت همه Zone ها
//====================================================================
void Zone_UpdateAllStatuses(const double current_price, const datetime now)
  {
   int invalidated = 0;
   int expired = 0;
   int activated = 0;
   int tested = 0;
   
   for(int i = 0; i < g_zone_book.count; i++)
     {
      ZoneInfo zone = g_zone_book.zones[i];
      if(zone.status == ZONE_STATUS_INVALID || zone.status == ZONE_STATUS_USED) continue;
      
      if(zone.expiration_time > 0 && now >= zone.expiration_time)
        {
         zone.status = ZONE_STATUS_EXPIRED;
         expired++;
        }
      else if(Zone_CheckInvalidation(zone, current_price))
        {
         zone.status = ZONE_STATUS_INVALID;
         invalidated++;
        }
      else if(Zone_ContainsPrice(zone, current_price))
        {
         if(zone.status == ZONE_STATUS_CANDIDATE)
           {
            zone.status = ZONE_STATUS_ACTIVE;
            activated++;
           }
         else if(zone.status == ZONE_STATUS_ACTIVE)
           {
            zone.status = ZONE_STATUS_TESTED;
            tested++;
           }
        }
      
      zone.updated_time = now;
      g_zone_book.zones[i] = zone;
     }
   
   //--- لاگ تشخیصی
   if(invalidated > 0 || expired > 0 || activated > 0 || tested > 0)
     {
      Print(
         "[ZONE ENGINE] STATUS UPDATE",
         " | Invalidated=", invalidated,
         " | Expired=", expired,
         " | Activated=", activated,
         " | Tested=", tested
      );
     }
  }

//====================================================================
// حذف Zone های نامعتبر
// [اصلاح] حذف Zone های USED هم
//====================================================================
void ZoneBook_RemoveInvalid()
  {
   int removed = 0;
   int w = 0;
   for(int i = 0; i < g_zone_book.count; i++)
     {
      ZoneInfo zone = g_zone_book.zones[i];
      if(zone.status == ZONE_STATUS_INVALID ||
         zone.status == ZONE_STATUS_EXPIRED ||
         zone.status == ZONE_STATUS_USED)
        {
         removed++;
         continue;
        }
      g_zone_book.zones[w] = zone;
      w++;
     }
   
   if(w < g_zone_book.count)
     {
      ArrayResize(g_zone_book.zones, w);
      Print("[ZONE ENGINE] REMOVED | Count=", removed, " | Remaining=", w);
     }
   
   g_zone_book.count = w;
  }

//====================================================================
// محاسبه ATR
//====================================================================
double Zone_ATRPoints(const string symbol, const ENUM_TIMEFRAMES timeframe, const int period)
  {
   if(symbol == "" || timeframe == PERIOD_CURRENT || period < 1) return 0.0;
   int handle = iATR(symbol, timeframe, period);
   if(handle == INVALID_HANDLE) return 0.0;
   
   double data[];
   ArraySetAsSeries(data, true);
   double val = 0.0;
   if(CopyBuffer(handle, 0, 1, 1, data) == 1)
      val = data[0];
   
   IndicatorRelease(handle);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   return (point > 0.0 ? val / point : 0.0);
  }

//====================================================================
// بارگذاری Rate ها
//====================================================================
bool Zone_LoadRates(const string symbol, const ENUM_TIMEFRAMES timeframe, const int bars, MqlRates &rates[])
  {
   ArrayResize(rates, 0);
   ArraySetAsSeries(rates, true);
   if(symbol == "" || timeframe == PERIOD_CURRENT || bars < 20) return false;
   return CopyRates(symbol, timeframe, 0, bars, rates) >= 20;
  }

//====================================================================
// بررسی همپوشانی با Zone های موجود
// [اصلاح] افزایش tolerance از 5 به 10 point
//====================================================================
bool Zone_OverlapsExisting(const double lower, const double upper,
                           const ENUM_ZONE_DIRECTION direction, const ENUM_ZONE_TYPE type)
  {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return false;
   
   //--- [اصلاح] tolerance بیشتر برای بازارهای پرنوسان
   double tolerance = 10.0 * point;
   
   for(int i = 0; i < g_zone_book.count; i++)
     {
      ZoneInfo zone = g_zone_book.zones[i];
      if(!Zone_IsActive(zone) || zone.direction != direction || zone.type != type) continue;
      
      double low = MathMax(lower, zone.lower_price);
      double high = MathMin(upper, zone.upper_price);
      
      if(high + tolerance >= low) return true;
     }
   
   return false;
  }

//====================================================================
// افزودن Origin Zone
//====================================================================
bool Zone_AddOrigin(const MqlRates &rates[], const int i, const int total,
                    const double point, const double atr, const ENUM_TIMEFRAMES tf)
  {
   if(i < 1 || i + 1 >= total || point <= 0.0) return false;
   
   int next = i - 1;
   double range = (rates[i].high - rates[i].low) / point;
   double next_body = MathAbs(rates[next].close - rates[next].open) / point;
   
   if(range <= 0.0) return false;
   if(atr > 0.0 && next_body < atr * 1.05) return false;
   
   ENUM_ZONE_DIRECTION dir = ZONE_DIRECTION_NONE;
   if(rates[i].close < rates[i].open && rates[next].close > rates[next].open) dir = ZONE_DIRECTION_BUY;
   if(rates[i].close > rates[i].open && rates[next].close < rates[next].open) dir = ZONE_DIRECTION_SELL;
   
   if(dir == ZONE_DIRECTION_NONE) return false;
   
   double lower = rates[i].low, upper = rates[i].high;
   if(range > Inp_Zone_Max_Width_Points) return false;
   if(Zone_OverlapsExisting(lower, upper, dir, ZONE_TYPE_ORIGIN)) return false;
   
   ulong id = g_zone_book.next_id++;
   double score = 50.0;
   if(atr > 0.0) score += MathMin(50.0, (next_body / atr) * 30.0);
   
   ZoneInfo zone;
   double invalid = (dir == ZONE_DIRECTION_BUY ? lower - point * 2.0 : upper + point * 2.0);
   
   if(!Zone_Create(id, ZONE_TYPE_ORIGIN, dir, lower, upper, invalid, rates[i].time,
                   rates[i].time + (long)PeriodSeconds(tf) * Inp_Zone_Max_Age_Bars, tf, score,
                   "Origin", (dir == ZONE_DIRECTION_BUY ? "مبدأ قبل از گسترش صعودی" : "مبدأ قبل از گسترش نزولی"), zone))
      return false;
   
   zone.source_shift = i;
   zone.source_bars = 1;
   
   return ZoneBook_Add(zone);
  }

//====================================================================
// افزودن Imbalance Zone
//====================================================================
bool Zone_AddImbalance(const MqlRates &rates[], const int i, const int total,
                       const double point, const double atr, const ENUM_TIMEFRAMES tf)
  {
   if(i < 1 || i + 2 >= total || point <= 0.0) return false;
   
   int old = i + 2;
   ENUM_ZONE_DIRECTION dir = ZONE_DIRECTION_NONE;
   double lower = 0.0, upper = 0.0;
   
   if(rates[i].low > rates[old].high)
     { dir = ZONE_DIRECTION_BUY; lower = rates[old].high; upper = rates[i].low; }
   else if(rates[i].high < rates[old].low)
     { dir = ZONE_DIRECTION_SELL; lower = rates[i].high; upper = rates[old].low; }
   else return false;
   
   double gap = (upper - lower) / point;
   double middle_body = MathAbs(rates[i + 1].close - rates[i + 1].open) / point;
   
   if(gap <= 0.0 || gap > Inp_Zone_Max_Width_Points) return false;
   if(atr > 0.0 && middle_body < atr * 0.45) return false;
   if(Zone_OverlapsExisting(lower, upper, dir, ZONE_TYPE_IMBALANCE)) return false;
   
   ulong id = g_zone_book.next_id++;
   double score = 55.0 + (atr > 0.0 ? MathMin(45.0, (middle_body / atr) * 30.0) : 0.0);
   
   ZoneInfo zone;
   double invalid = (dir == ZONE_DIRECTION_BUY ? lower - point * 2.0 : upper + point * 2.0);
   
   if(!Zone_Create(id, ZONE_TYPE_IMBALANCE, dir, lower, upper, invalid, rates[i].time,
                   rates[i].time + (long)PeriodSeconds(tf) * Inp_Zone_Max_Age_Bars, tf, MathMin(100.0, score),
                   "Imbalance", (dir == ZONE_DIRECTION_BUY ? "عدم تعادل صعودی" : "عدم تعادل نزولی"), zone))
      return false;
   
   zone.source_shift = i + 1;
   zone.source_bars = 3;
   
   return ZoneBook_Add(zone);
  }

//====================================================================
// افزودن Structure Pivot Zone
//====================================================================
bool Zone_AddStructurePivot(const MqlRates &rates[], const int i, const int total,
                            const double point, const double atr, const ENUM_TIMEFRAMES tf)
  {
   if(i < 2 || i + 2 >= total || point <= 0.0) return false;
   
   bool sh = rates[i].high > rates[i - 1].high && rates[i].high >= rates[i + 1].high &&
             rates[i].high > rates[i - 2].high && rates[i].high >= rates[i + 2].high;
   bool sl = rates[i].low < rates[i - 1].low && rates[i].low <= rates[i + 1].low &&
             rates[i].low < rates[i - 2].low && rates[i].low <= rates[i + 2].low;
   
   if(!sh && !sl) return false;
   
   ENUM_ZONE_DIRECTION dir = sh ? ZONE_DIRECTION_SELL : ZONE_DIRECTION_BUY;
   double width_points = (atr > 0.0 ? MathMin((double)Inp_Zone_Max_Width_Points, atr * 0.30) : 80.0);
   if(width_points < 5.0) width_points = 5.0;
   
   double lower = 0.0, upper = 0.0, invalid = 0.0;
   if(sh) { upper = rates[i].high; lower = upper - width_points * point; invalid = upper + point * 2.0; }
   else  { lower = rates[i].low; upper = lower + width_points * point; invalid = lower - point * 2.0; }
   
   if(Zone_OverlapsExisting(lower, upper, dir, ZONE_TYPE_STRUCTURE)) return false;
   
   ulong id = g_zone_book.next_id++;
   double score = 50.0;
   double range = (rates[i].high - rates[i].low) / point;
   if(atr > 0.0) score += MathMin(35.0, (range / atr) * 20.0);
   if((sh && rates[i].close < rates[i].open) || (sl && rates[i].close > rates[i].open)) score += 15.0;
   
   ZoneInfo zone;
   if(!Zone_Create(id, ZONE_TYPE_STRUCTURE, dir, lower, upper, invalid, rates[i].time,
                   rates[i].time + (long)PeriodSeconds(tf) * Inp_Zone_Max_Age_Bars, tf, MathMin(100.0, score),
                   "Structure", (sh ? "سقف محلی ساختاری" : "کف محلی ساختاری"), zone))
      return false;
   
   zone.source_shift = i;
   zone.source_bars = 5;
   
   return ZoneBook_Add(zone);
  }

//====================================================================
// افزودن Pullback Zone (نسخه اصلاح‌شده)
//====================================================================
bool Zone_AddPullbackFixed(const MqlRates &rates[], const int total, const double point, const double atr, const ENUM_TIMEFRAMES tf)
  {
   if(total < 10 || point <= 0.0) return false;
   
   double hi = rates[2].high, lo = rates[2].low;
   for(int i = 2; i <= 8 && i < total; i++)
     { hi = MathMax(hi, rates[i].high); lo = MathMin(lo, rates[i].low); }
   
   double range = hi - lo;
   if(range <= 0.0) return false;
   
   double close = rates[1].close;
   ENUM_ZONE_DIRECTION dir = (close > lo + range * 0.50 ? ZONE_DIRECTION_BUY : ZONE_DIRECTION_SELL);
   
   double lower, upper;
   if(dir == ZONE_DIRECTION_BUY)
     { lower = hi - range * 0.62; upper = hi - range * 0.38; }
   else
     { lower = lo + range * 0.38; upper = lo + range * 0.62; }
   
   if(atr > 0.0)
     {
      double max_width = atr * 0.40 * point;
      double center = (lower + upper) * 0.50;
      if(upper - lower > max_width)
        { lower = center - max_width * 0.5; upper = center + max_width * 0.5; }
     }
   
   if(Zone_OverlapsExisting(lower, upper, dir, ZONE_TYPE_PULLBACK)) return false;
   
   ulong id = g_zone_book.next_id++;
   double invalid = (dir == ZONE_DIRECTION_BUY ? lower - point * 2.0 : upper + point * 2.0);
   
   ZoneInfo zone;
   if(!Zone_Create(id, ZONE_TYPE_PULLBACK, dir, lower, upper, invalid, rates[2].time,
                   rates[2].time + (long)PeriodSeconds(tf) * Inp_Zone_Max_Age_Bars, tf, 70.0,
                   "Pullback", "اصلاح 38 تا 62 درصد موج اخیر", zone))
      return false;
   
   zone.source_shift = 2;
   zone.source_bars = 7;
   
   return ZoneBook_Add(zone);
  }

//====================================================================
// به‌روزرسانی متریک‌ها
//====================================================================
void Zone_UpdateMetrics(const double current_price, const double point, const datetime now, const ENUM_TIMEFRAMES tf)
  {
   if(point <= 0.0) return;
   
   long max_seconds = (long)PeriodSeconds(tf) * Inp_Zone_Max_Age_Bars;
   if(max_seconds <= 0) max_seconds = 1;
   
   for(int i = 0; i < g_zone_book.count; i++)
     {
      ZoneInfo zone = g_zone_book.zones[i];
      
      if(current_price < zone.lower_price)
         zone.distance_points = (zone.lower_price - current_price) / point;
      else if(current_price > zone.upper_price)
         zone.distance_points = (current_price - zone.upper_price) / point;
      else
         zone.distance_points = 0.0;
      
      long age = (long)(now - zone.created_time);
      zone.freshness = MathMax(0.0, MathMin(100.0, 100.0 - ((double)MathMax(0, age) / (double)max_seconds) * 100.0));
      
      g_zone_book.zones[i] = zone;
     }
  }

//====================================================================
// تشخیص وضعیت فاصله
// [اصلاح] near_limit بیشتر برای Zone های بزرگ
//====================================================================
ENUM_ZONE_DISTANCE_STATE Zone_GetDistanceState(const ZoneInfo &zone, const double price, const double point)
  {
   if(point <= 0.0 || !Zone_IsValid(zone)) return ZONE_DISTANCE_UNKNOWN;
   if(Zone_ContainsPrice(zone, price)) return ZONE_DISTANCE_INSIDE;
   
   double distance = (price < zone.lower_price ? (zone.lower_price - price) / point : (price - zone.upper_price) / point);
   
   //--- [اصلاح] near_limit: حداقل 20 point یا 2 برابر عرض Zone
   double near_limit = MathMax(20.0, zone.width_points * 2.0);
   near_limit = MathMin(near_limit, 200.0); // حداکثر 200 point
   
   return (distance <= near_limit ? ZONE_DISTANCE_NEAR : ZONE_DISTANCE_FAR);
  }

//====================================================================
// تحلیل موتور Zone
//====================================================================
bool ZoneEngine_Analyze(const string symbol, const ENUM_TIMEFRAMES timeframe, const int bars_to_scan, ZoneEngineSnapshot &snapshot)
  {
   ZeroMemory(snapshot);
   snapshot.symbol = symbol;
   snapshot.timeframe = timeframe;
   snapshot.analysis_time = TimeCurrent();
   snapshot.nearest_buy_index = -1;
   snapshot.nearest_sell_index = -1;
   snapshot.nearest_buy_distance_points = -1.0;
   snapshot.nearest_sell_distance_points = -1.0;
   
   if(symbol == "" || timeframe == PERIOD_CURRENT)
     { snapshot.reason = "نماد یا تایم‌فریم معتبر نیست"; return false; }
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
     { snapshot.reason = "Point نماد معتبر نیست"; return false; }
   
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
     { snapshot.reason = "قیمت جاری دریافت نشد"; return false; }
   
   snapshot.current_price = (tick.bid > 0.0 ? tick.bid : tick.last);
   snapshot.atr_points = Zone_ATRPoints(symbol, timeframe, Inp_ATR_Period);
   
   MqlRates rates[];
   if(!Zone_LoadRates(symbol, timeframe, MathMax(80, bars_to_scan), rates))
     { snapshot.reason = "داده کافی برای Zone وجود ندارد"; return false; }
   
   if(g_zone_book.next_id == 0) ZoneBook_Init();
   
   Zone_UpdateAllStatuses(snapshot.current_price, TimeCurrent());
   ZoneBook_RemoveInvalid();
   
   //--- اسکن کندل‌ها برای Zone های جدید
   int max_scan = MathMin(ArraySize(rates) - 3, 40);
   for(int i = 3; i < max_scan; i++)
     {
      if(g_zone_book.count >= Inp_Max_Active_Zones) break;
      if(Inp_Use_Origin_Zone) Zone_AddOrigin(rates, i, ArraySize(rates), point, snapshot.atr_points, timeframe);
      if(Inp_Use_Displacement_Zone) Zone_AddImbalance(rates, i, ArraySize(rates), point, snapshot.atr_points, timeframe);
      if(Inp_Use_Structure_Zone) Zone_AddStructurePivot(rates, i, ArraySize(rates), point, snapshot.atr_points, timeframe);
     }
   
   if(Inp_Use_Pullback_Zone && g_zone_book.count < Inp_Max_Active_Zones)
      Zone_AddPullbackFixed(rates, ArraySize(rates), point, snapshot.atr_points, timeframe);
   
   Zone_UpdateMetrics(snapshot.current_price, point, TimeCurrent(), timeframe);
   
   int buys = 0, sells = 0;
   double nb = DBL_MAX, ns = DBL_MAX;
   
   for(int i = 0; i < g_zone_book.count; i++)
     {
      ZoneInfo zone = g_zone_book.zones[i];
      if(!Zone_IsActive(zone)) continue;
      
      if(zone.direction == ZONE_DIRECTION_BUY)
        { buys++; if(zone.distance_points < nb) { nb = zone.distance_points; snapshot.nearest_buy_index = i; } }
      if(zone.direction == ZONE_DIRECTION_SELL)
        { sells++; if(zone.distance_points < ns) { ns = zone.distance_points; snapshot.nearest_sell_index = i; } }
     }
   
   snapshot.valid = true;
   snapshot.total_zones = g_zone_book.count;
   snapshot.active_zones = buys + sells;
   snapshot.buy_zones = buys;
   snapshot.sell_zones = sells;
   
   if(nb < DBL_MAX) snapshot.nearest_buy_distance_points = nb;
   if(ns < DBL_MAX) snapshot.nearest_sell_distance_points = ns;
   
   snapshot.price_zone_state = ZONE_DISTANCE_FAR;
   
   if(snapshot.nearest_buy_index >= 0)
     {
      ZoneInfo z = g_zone_book.zones[snapshot.nearest_buy_index];
      ENUM_ZONE_DISTANCE_STATE s = Zone_GetDistanceState(z, snapshot.current_price, point);
      if(s == ZONE_DISTANCE_INSIDE) snapshot.price_zone_state = s;
      else if(s == ZONE_DISTANCE_NEAR && snapshot.price_zone_state == ZONE_DISTANCE_FAR) snapshot.price_zone_state = s;
     }
   
   if(snapshot.nearest_sell_index >= 0)
     {
      ZoneInfo z = g_zone_book.zones[snapshot.nearest_sell_index];
      ENUM_ZONE_DISTANCE_STATE s = Zone_GetDistanceState(z, snapshot.current_price, point);
      if(s == ZONE_DISTANCE_INSIDE) snapshot.price_zone_state = s;
      else if(s == ZONE_DISTANCE_NEAR && snapshot.price_zone_state == ZONE_DISTANCE_FAR) snapshot.price_zone_state = s;
     }
   
   snapshot.status_text = "Zoneها=" + IntegerToString(snapshot.total_zones) +
                          " | فعال=" + IntegerToString(snapshot.active_zones) +
                          " | خرید=" + IntegerToString(snapshot.buy_zones) +
                          " | فروش=" + IntegerToString(snapshot.sell_zones) +
                          " | موقعیت=" + ZoneDistanceToPersian(snapshot.price_zone_state);
   
   snapshot.reason = (snapshot.active_zones > 0 ? "Zoneهای فعال بر اساس قیمت و ساختار اخیر شناسایی شدند" : "Zone فعال معتبر در این چرخه پیدا نشد");
   
   g_zone_snapshot = snapshot;
   g_zone_book.last_refresh = snapshot.analysis_time;
   
   return true;
  }

//====================================================================
// توابع کمکی
//====================================================================
bool ZoneEngine_IsValid(const ZoneEngineSnapshot &snapshot)
  {
   return snapshot.valid && snapshot.symbol != "" && snapshot.analysis_time > 0;
  }

int ZoneEngine_CountActive()
  {
   int count = 0;
   for(int i = 0; i < g_zone_book.count; i++)
     { ZoneInfo z = g_zone_book.zones[i]; if(Zone_IsActive(z)) count++; }
   return count;
  }

bool ZoneEngine_GetNearestBuy(ZoneInfo &zone)
  {
   if(g_zone_snapshot.nearest_buy_index < 0 || g_zone_snapshot.nearest_buy_index >= g_zone_book.count) return false;
   ZoneInfo copy = g_zone_book.zones[g_zone_snapshot.nearest_buy_index];
   zone = copy;
   return Zone_IsValid(zone);
  }

bool ZoneEngine_GetNearestSell(ZoneInfo &zone)
  {
   if(g_zone_snapshot.nearest_sell_index < 0 || g_zone_snapshot.nearest_sell_index >= g_zone_book.count) return false;
   ZoneInfo copy = g_zone_book.zones[g_zone_snapshot.nearest_sell_index];
   zone = copy;
   return Zone_IsValid(zone);
  }

string ZoneEngine_BuildSummary(const ZoneEngineSnapshot &snapshot)
  {
   if(!ZoneEngine_IsValid(snapshot)) return "Zone Engine | نتیجه معتبر نیست";
   string text = "Zone Engine v2.30 | " + snapshot.status_text;
   if(snapshot.nearest_buy_distance_points >= 0.0) text += " | نزدیک‌ترین خرید=" + DoubleToString(snapshot.nearest_buy_distance_points, 1) + " Point";
   if(snapshot.nearest_sell_distance_points >= 0.0) text += " | نزدیک‌ترین فروش=" + DoubleToString(snapshot.nearest_sell_distance_points, 1) + " Point";
   return text;
  }

string Zone_ToText(const ZoneInfo &zone)
  {
   if(!Zone_IsValid(zone)) return "Zone نامعتبر";
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   string text = "شناسه: " + (string)zone.id +
               " | نوع: " + ZoneTypeToPersian(zone.type) +
               " | جهت: " + ZoneDirectionToPersian(zone.direction) +
               " | وضعیت: " + ZoneStatusToPersian(zone.status) +
               " | کف: " + DoubleToString(zone.lower_price, digits) +
               " | سقف: " + DoubleToString(zone.upper_price, digits) +
               " | ابطال: " + DoubleToString(zone.invalidation_price, digits) +
               " | قدرت: " + DoubleToString(zone.strength, 1) +
               " | تازگی: " + DoubleToString(zone.freshness, 1);
   if(zone.source != "") text += " | منبع: " + zone.source;
   if(zone.reason != "") text += " | دلیل: " + zone.reason;
   return text;
  }

#endif // __ZONE_ENGINE_MQH__
//+------------------------------------------------------------------+