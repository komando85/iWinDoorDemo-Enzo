#ifndef __TFLAB_RISK_ENGINE_MQH__
#define __TFLAB_RISK_ENGINE_MQH__

//+------------------------------------------------------------------+
//|                         Risk_Engine.mqh                           |
//|                         TFlab New EA V.5                         |
//|                                                                  |
//| مسئولیت: محاسبه و کنترل ریسک                                     |
//| بدون منطق تحلیل بازار، سناریو، Entry، SL، TP یا Execution        |
//|                                                                  |
//| v2.2 - Fixed Lot + Financial Risk + Open Risk Calculation       |
//|                                                                  |
//| نکته مهم:                                                        |
//| در حالت Fixed Lot، حجم مستقیماً از fixed_lot_size گرفته می‌شود؛  |
//| سپس ریسک واقعی همان حجم محاسبه و تمام کنترل‌های ریسک اعمال می‌شود.|
//+------------------------------------------------------------------+
#property strict

//====================================================================
// نتیجه کنترل ریسک
//====================================================================
enum ENUM_RISK_STATUS
  {
   RISK_STATUS_UNKNOWN = 0,
   RISK_STATUS_APPROVED,
   RISK_STATUS_BLOCKED
  };

//====================================================================
// محدودیت‌های ریسک
//====================================================================
struct RiskLimits
  {
   double risk_percent_per_trade;
   double max_risk_percent_per_trade;
   double max_total_open_risk_percent;
   double max_directional_risk_percent;
   double min_rr;
   double max_sl_distance_points;
   double min_sl_distance_points;
   double daily_loss_limit_percent;
   double max_drawdown_percent;
   int    max_consecutive_losses;
   bool   block_after_daily_loss;   // [جدید] قبلاً Inp_Block_After_Daily_Loss هیچ‌جا چک نمی‌شد
   bool   block_after_drawdown;     // [جدید] قبلاً Inp_Block_After_Drawdown هیچ‌جا چک نمی‌شد
   bool   ignore_capital_size_for_min_volume; // [جدید] دکمه نادیده گرفتن اندازه سرمایه برای حداقل حجم
   bool   enable_adaptive_risk;              // [جدید] فعال بودن سایزینگ تطبیقی
   double adaptive_reduction_per_loss_percent;
   double adaptive_increase_per_win_percent;
   double adaptive_min_multiplier;
   double adaptive_max_multiplier;
   
   //--- Financial Risk
   double min_financial_risk_percent;
   double max_financial_risk_percent;
   double min_trade_probability_percent;
   double probability_at_min_financial_risk;
   double probability_at_max_financial_risk;
   double max_total_financial_risk_percent;
   double max_directional_financial_risk_percent;

   //--- Fixed Lot
   bool   use_fixed_lot;
   double fixed_lot_size;
  };

//====================================================================
// وضعیت حساب
//====================================================================
struct RiskAccountState
  {
   double balance;
   double equity;
   double peak_equity;
   double open_risk_money;
   double open_risk_percent;
   double buy_risk_money;
   double sell_risk_money;
   double daily_loss_money;
   double daily_loss_percent;
   int    consecutive_losses;
   int    consecutive_wins;
  };

//====================================================================
// ورودی معامله برای ارزیابی ریسک
//====================================================================
struct RiskTradeInput
  {
   bool   is_buy;
   double entry_price;
   double sl_price;
   double target_price;
   double risk_percent_requested;
   double estimated_cost_money;
  };

//====================================================================
// نتیجه ارزیابی ریسک
//====================================================================
struct RiskResult
  {
   ENUM_RISK_STATUS status;
   bool             approved;
   double           risk_money;
   double           risk_percent;
   double           reward_money;
   double           rr;
   double           stop_distance_price;
   double           stop_distance_points;
   double           position_volume;
   string           reason;
  };

//----------------------------------------------------------------------
// متن فارسی وضعیت ریسک
//----------------------------------------------------------------------
string RiskStatusToPersian(const ENUM_RISK_STATUS status)
  {
   switch(status)
     {
      case RISK_STATUS_APPROVED: return "ریسک تأیید شد";
      case RISK_STATUS_BLOCKED:  return "ریسک مسدود شد";
      default:                   return "نامشخص";
     }
  }

//----------------------------------------------------------------------
// مقداردهی محدودیت‌ها
//----------------------------------------------------------------------
void Risk_InitLimits(RiskLimits &limits)
  {
   limits.risk_percent_per_trade     = 1.00;
   limits.max_risk_percent_per_trade = 1.00;
   limits.max_total_open_risk_percent= 2.00;
   limits.max_directional_risk_percent = 1.50;
   limits.min_rr                     = 1.00;
   limits.max_sl_distance_points     = 0.0;
   limits.min_sl_distance_points     = 0.0;
   limits.daily_loss_limit_percent   = 3.00;
   limits.max_drawdown_percent       = 10.00;
   limits.block_after_daily_loss     = false;
   limits.block_after_drawdown       = false;
   limits.ignore_capital_size_for_min_volume = false;
   limits.enable_adaptive_risk = false;
   limits.adaptive_reduction_per_loss_percent = 25.0;
   limits.adaptive_increase_per_win_percent = 10.0;
   limits.adaptive_min_multiplier = 0.3;
   limits.adaptive_max_multiplier = 1.3;
   limits.max_consecutive_losses     = 0;
   limits.min_financial_risk_percent = 0.0;
   limits.max_financial_risk_percent = 0.0;
   limits.min_trade_probability_percent = 0.0;
   limits.probability_at_min_financial_risk = 0.0;
   limits.probability_at_max_financial_risk = 0.0;
   limits.max_total_financial_risk_percent = 0.0;
   limits.max_directional_financial_risk_percent = 0.0;

   //--- در نسخه فعلی: معامله با حجم ثابت 0.01 لات
   //--- فایل Inputs بعداً می‌تواند این دو مقدار را کنترل کند.
   limits.use_fixed_lot = true;
   limits.fixed_lot_size = 0.01;
  }

//----------------------------------------------------------------------
// مقداردهی وضعیت حساب
//----------------------------------------------------------------------
void Risk_InitAccountState(RiskAccountState &state)
  {
   state.balance              = 0.0;
   state.equity               = 0.0;
   state.peak_equity          = 0.0;
   state.open_risk_money      = 0.0;
   state.open_risk_percent    = 0.0;
   state.buy_risk_money       = 0.0;
   state.sell_risk_money      = 0.0;
   state.daily_loss_money     = 0.0;
   state.daily_loss_percent   = 0.0;
   state.consecutive_losses   = 0;
   state.consecutive_wins     = 0;
  }

//----------------------------------------------------------------------
// مقداردهی نتیجه
//----------------------------------------------------------------------
void Risk_InitResult(RiskResult &result)
  {
   result.status              = RISK_STATUS_UNKNOWN;
   result.approved            = false;
   result.risk_money          = 0.0;
   result.risk_percent        = 0.0;
   result.reward_money        = 0.0;
   result.rr                  = 0.0;
   result.stop_distance_price = 0.0;
   result.stop_distance_points= 0.0;
   result.position_volume     = 0.0;
   result.reason              = "";
  }

//----------------------------------------------------------------------
// فاصله استاپ از ورود
//----------------------------------------------------------------------
double Risk_StopDistancePrice(const bool is_buy,
                              const double entry_price,
                              const double sl_price)
  {
   if(entry_price <= 0.0 || sl_price <= 0.0)
      return 0.0;

   if(is_buy)
      return entry_price - sl_price;

   return sl_price - entry_price;
  }

//----------------------------------------------------------------------
// فاصله هدف از ورود
//----------------------------------------------------------------------
double Risk_RewardDistancePrice(const bool is_buy,
                                const double entry_price,
                                const double target_price)
  {
   if(entry_price <= 0.0 || target_price <= 0.0)
      return 0.0;

   if(is_buy)
      return target_price - entry_price;

   return entry_price - target_price;
  }

//----------------------------------------------------------------------
// بررسی جهت صحیح SL و Target
//----------------------------------------------------------------------
bool Risk_ValidatePriceGeometry(const bool is_buy,
                                const double entry_price,
                                const double sl_price,
                                const double target_price,
                                string &reason)
  {
   const double stop_distance   = Risk_StopDistancePrice(is_buy,entry_price,sl_price);
   const double reward_distance = Risk_RewardDistancePrice(is_buy,entry_price,target_price);

   if(stop_distance <= 0.0)
     {
      reason = "حد ضرر در سمت صحیح ورود قرار ندارد";
      return false;
     }

   if(reward_distance <= 0.0)
     {
      reason = "هدف در سمت صحیح ورود قرار ندارد";
      return false;
     }

   reason = "هندسه قیمت معتبر است";
   return true;
  }

//----------------------------------------------------------------------
// محاسبه R/R
//----------------------------------------------------------------------
double Risk_CalculateRR(const bool is_buy,
                        const double entry_price,
                        const double sl_price,
                        const double target_price)
  {
   const double risk_distance   = Risk_StopDistancePrice(is_buy,entry_price,sl_price);
   const double reward_distance = Risk_RewardDistancePrice(is_buy,entry_price,target_price);

   if(risk_distance <= 0.0 || reward_distance <= 0.0)
      return 0.0;

   return reward_distance / risk_distance;
  }

//----------------------------------------------------------------------
// محاسبه ارزش ریسک برای یک حجم
//----------------------------------------------------------------------
double Risk_CalculateMoney(const string symbol,
                           const double volume,
                           const double entry_price,
                           const double sl_price)
  {
   if(symbol == "" || volume <= 0.0 || entry_price <= 0.0 || sl_price <= 0.0)
      return 0.0;

   double tick_size  = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);

   if(tick_value <= 0.0)
     {
      tick_value = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
      //--- لاگ هشدار فقط یک بار
      static bool warned = false;
      if(!warned)
        {
         Print("[RISK ENGINE] WARNING | SYMBOL_TRADE_TICK_VALUE_LOSS not available, using SYMBOL_TRADE_TICK_VALUE");
         warned = true;
        }
     }

   if(tick_size <= 0.0 || tick_value <= 0.0)
      return 0.0;

   const double distance = MathAbs(entry_price-sl_price);
   const double ticks    = distance/tick_size;

   return ticks*tick_value*volume;
  }

//----------------------------------------------------------------------
// محاسبه حجم بر اساس ریسک پولی
//----------------------------------------------------------------------
double Risk_CalculateVolume(const string symbol,
                            const double entry_price,
                            const double sl_price,
                            const double allowed_risk_money,
                            const bool ignore_capital_size_for_min_volume = false)
  {
   if(symbol == "" || entry_price <= 0.0 || sl_price <= 0.0 || allowed_risk_money <= 0.0)
      return 0.0;

   const double tick_size = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double tick_value     = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);

   if(tick_value <= 0.0)
      tick_value = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);

   const double volume_min  = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   const double volume_max  = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);

   if(tick_size <= 0.0 || tick_value <= 0.0 || volume_min <= 0.0 || volume_step <= 0.0)
     {
      Print("[RISK ENGINE] FAIL | Invalid symbol info | TickSize=", tick_size,
            " | TickValue=", tick_value, " | VolMin=", volume_min, " | VolStep=", volume_step);
      return 0.0;
     }

   const double distance = MathAbs(entry_price-sl_price);
   if(distance <= 0.0)
      return 0.0;

   const double loss_per_lot = (distance/tick_size)*tick_value;
   if(loss_per_lot <= 0.0)
      return 0.0;

   double raw_volume = allowed_risk_money/loss_per_lot;

   //--- همیشه به سمت ریسک کمتر گرد می‌کنیم
   double volume = MathFloor(raw_volume/volume_step)*volume_step;

   if(volume > volume_max)
      volume = volume_max;

   if(volume < volume_min)
     {
      //--------------------------------------------------------------
      // [جدید] دکمه «به سرمایه اولیه کاری نداشته باش»
      // اگر فعال باشد: به‌جای رد کردن کامل معامله (چون سرمایه کوچک
      // اجازه محاسبه دقیق ریسک‌محور را نمی‌دهد)، از حداقل حجم مجاز
      // بروکر استفاده می‌شود. توجه: این یعنی ریسک واقعی این معامله
      // ممکن است از درصد تنظیم‌شده در Inp_Risk_Per_Trade_Percent
      // بیشتر شود - این دقیقاً همان چیزی است که این دکمه با روشن
      // کردنش می‌پذیرد. سایر فیلترهای ریسک (RR، سقف SL، ریسک هم‌جهت،
      // زیان روزانه و ...) کاملاً دست‌نخورده باقی می‌مانند.
      //--------------------------------------------------------------
      if(ignore_capital_size_for_min_volume)
        {
         double actual_risk_money = volume_min * loss_per_lot;

         Print("[RISK ENGINE] MIN_VOLUME_OVERRIDE | سرمایه برای حجم محاسبه‌شده کافی نبود اما طبق "
               "تنظیم شما (نادیده گرفتن اندازه سرمایه) از حداقل حجم استفاده شد | "
               "MinVolume=", DoubleToString(volume_min, 2),
               " | RiskMoneyMatched=$", DoubleToString(actual_risk_money, 2),
               " (به‌جای $", DoubleToString(allowed_risk_money, 2), " برنامه‌ریزی‌شده)");

         return volume_min;
        }

      return 0.0;
     }

   int volume_digits = 0;
   double step_test = volume_step;
   while(volume_digits < 8 && MathAbs(step_test-MathRound(step_test)) > 0.00000001)
     {
      step_test *= 10.0;
      volume_digits++;
     }

   return NormalizeDouble(volume,volume_digits);
  }

//----------------------------------------------------------------------
// [جدید] محاسبه حجم ثابت با رعایت Min/Max/Step نماد
//----------------------------------------------------------------------
double Risk_CalculateFixedVolume(const string symbol,
                                 const double requested_volume)
  {
   if(symbol == "" || requested_volume <= 0.0)
      return 0.0;

   const double volume_min  = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   const double volume_max  = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);

   if(volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0)
     {
      Print("[RISK ENGINE] FIXED LOT FAIL | Invalid symbol volume info",
            " | Min=",volume_min,
            " | Max=",volume_max,
            " | Step=",volume_step);
      return 0.0;
     }

   if(requested_volume < volume_min)
     {
      Print("[RISK ENGINE] FIXED LOT BLOCKED | Requested=",
            DoubleToString(requested_volume,8),
            " < SymbolMin=",
            DoubleToString(volume_min,8));
      return 0.0;
     }

   if(requested_volume > volume_max)
     {
      Print("[RISK ENGINE] FIXED LOT BLOCKED | Requested=",
            DoubleToString(requested_volume,8),
            " > SymbolMax=",
            DoubleToString(volume_max,8));
      return 0.0;
     }

   //--- حجم را روی مضرب معتبر Step قرار می‌دهیم؛ هرگز به سمت افزایش ریسک گرد نمی‌کنیم.
   double volume = MathFloor((requested_volume + 0.0000000001)/volume_step)*volume_step;

   if(volume < volume_min)
      return 0.0;

   if(volume > volume_max)
      volume = volume_max;

   int volume_digits = 0;
   double step_test = volume_step;
   while(volume_digits < 8 && MathAbs(step_test-MathRound(step_test)) > 0.00000001)
     {
      step_test *= 10.0;
      volume_digits++;
     }

   return NormalizeDouble(volume,volume_digits);
  }

//----------------------------------------------------------------------
// محاسبه درصد ریسک نسبت به Equity
//----------------------------------------------------------------------
double Risk_MoneyToPercent(const double risk_money,
                           const double equity)
  {
   if(risk_money < 0.0 || equity <= 0.0)
      return 0.0;

   return (risk_money/equity)*100.0;
  }

//----------------------------------------------------------------------
// [جدید] محاسبه ریسک باز از معاملات واقعی
//----------------------------------------------------------------------
void Risk_CalculateOpenRiskFromPositions(
   const string symbol,
   const ulong magic_number,
   RiskAccountState &state)
  {
   double total_risk = 0.0;
   double buy_risk = 0.0;
   double sell_risk = 0.0;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      
      if((ulong)PositionGetInteger(POSITION_MAGIC) != magic_number)
         continue;

      bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double volume = PositionGetDouble(POSITION_VOLUME);

      if(sl <= 0.0 || open_price <= 0.0 || volume <= 0.0)
         continue;

      double risk_money = Risk_CalculateMoney(symbol, volume, open_price, sl);
      total_risk += risk_money;

      if(is_buy)
         buy_risk += risk_money;
      else
         sell_risk += risk_money;
     }

   state.open_risk_money = total_risk;
   state.buy_risk_money = buy_risk;
   state.sell_risk_money = sell_risk;
   state.open_risk_percent = Risk_MoneyToPercent(total_risk, state.equity);
  }

//----------------------------------------------------------------------
// کنترل محدودیت‌های عمومی حساب
//----------------------------------------------------------------------
bool Risk_CheckAccountLimits(const RiskLimits &limits,
                             const RiskAccountState &account,
                             const double new_risk_percent,
                             const bool is_buy,
                             string &reason)
  {
   if(account.equity <= 0.0)
     {
      reason = "Equity معتبر نیست";
      return false;
     }

   if(new_risk_percent <= 0.0)
     {
      reason = "ریسک معامله صفر یا نامعتبر است";
      return false;
     }

   if(new_risk_percent > limits.max_risk_percent_per_trade)
     {
      reason = "ریسک این معامله از سقف مجاز بیشتر است | " +
               DoubleToString(new_risk_percent, 2) + "% > " +
               DoubleToString(limits.max_risk_percent_per_trade, 2) + "%";
      return false;
     }

   if(account.open_risk_percent + new_risk_percent > limits.max_total_open_risk_percent + 0.0000001)
     {
      reason = "مجموع ریسک معاملات باز از سقف مجاز عبور می‌کند | " +
               "Current=" + DoubleToString(account.open_risk_percent, 2) + "% + " +
               "New=" + DoubleToString(new_risk_percent, 2) + "% > " +
               "Max=" + DoubleToString(limits.max_total_open_risk_percent, 2) + "%";
      return false;
     }

   const double directional_money = is_buy ? account.buy_risk_money : account.sell_risk_money;
   const double directional_percent = Risk_MoneyToPercent(directional_money, account.equity);

   if(directional_percent + new_risk_percent > limits.max_directional_risk_percent + 0.0000001)
     {
      reason = "ریسک هم‌جهت از سقف مجاز بیشتر می‌شود | " +
               "Current=" + DoubleToString(directional_percent, 2) + "% + " +
               "New=" + DoubleToString(new_risk_percent, 2) + "% > " +
               "Max=" + DoubleToString(limits.max_directional_risk_percent, 2) + "%";
      return false;
     }

   if(limits.block_after_daily_loss &&
      limits.daily_loss_limit_percent > 0.0 &&
      account.daily_loss_percent >= limits.daily_loss_limit_percent)
     {
      reason = "سقف زیان روزانه فعال شده است | " +
               "Loss=" + DoubleToString(account.daily_loss_percent, 2) + "% >= " +
               "Limit=" + DoubleToString(limits.daily_loss_limit_percent, 2) + "%";
      return false;
     }

   if(limits.block_after_drawdown &&
      limits.max_drawdown_percent > 0.0 && account.peak_equity > 0.0)
     {
      const double drawdown = ((account.peak_equity-account.equity)/account.peak_equity)*100.0;
      if(drawdown >= limits.max_drawdown_percent)
        {
         reason = "سقف افت سرمایه فعال شده است | " +
                  "Drawdown=" + DoubleToString(drawdown, 2) + "% >= " +
                  "Max=" + DoubleToString(limits.max_drawdown_percent, 2) + "%";
         return false;
        }
     }

   if(limits.max_consecutive_losses > 0 &&
      account.consecutive_losses >= limits.max_consecutive_losses)
     {
      reason = "حداکثر زیان‌های متوالی فعال شده است | " +
               "Losses=" + IntegerToString(account.consecutive_losses) + " >= " +
               "Max=" + IntegerToString(limits.max_consecutive_losses);
      return false;
     }

   reason = "محدودیت‌های حساب تأیید شد";
   return true;
  }

//----------------------------------------------------------------------
// کنترل فاصله SL
//----------------------------------------------------------------------
bool Risk_CheckStopDistance(const RiskLimits &limits,
                            const double stop_distance_points,
                            string &reason)
  {
   if(stop_distance_points <= 0.0)
     {
      reason = "فاصله حد ضرر نامعتبر است";
      return false;
     }

   if(limits.min_sl_distance_points > 0.0 &&
      stop_distance_points < limits.min_sl_distance_points)
     {
      reason = "فاصله حد ضرر کمتر از حداقل مجاز است | " +
               DoubleToString(stop_distance_points, 1) + " < " +
               DoubleToString(limits.min_sl_distance_points, 1);
      return false;
     }

   if(limits.max_sl_distance_points > 0.0 &&
      stop_distance_points > limits.max_sl_distance_points)
     {
      reason = "فاصله حد ضرر بیشتر از حداکثر مجاز است | " +
               DoubleToString(stop_distance_points, 1) + " > " +
               DoubleToString(limits.max_sl_distance_points, 1);
      return false;
     }

   reason = "فاصله حد ضرر مجاز است";
   return true;
  }

//----------------------------------------------------------------------
// کنترل R/R
//----------------------------------------------------------------------
bool Risk_CheckRR(const RiskLimits &limits,
                  const double rr,
                  string &reason)
  {
   if(rr <= 0.0)
     {
      reason = "نسبت سود به ریسک نامعتبر است";
      return false;
     }

   if(limits.min_rr > 0.0 && rr < limits.min_rr)
     {
      reason = "نسبت سود به ریسک کمتر از حداقل مجاز است | " +
               DoubleToString(rr, 2) + " < " +
               DoubleToString(limits.min_rr, 2);
      return false;
     }

   reason = "نسبت سود به ریسک تأیید شد";
   return true;
  }

//----------------------------------------------------------------------
// ارزیابی کامل یک معامله
// [اصلاح] Fixed Lot + محاسبه ریسک واقعی حجم + Financial Risk
//----------------------------------------------------------------------
bool Risk_EvaluateTrade(const string symbol,
                        const RiskLimits &limits,
                        const RiskAccountState &account,
                        const RiskTradeInput &trade_input,
                        const double point,
                        RiskResult &result)
  {
   Risk_InitResult(result);

   if(symbol == "")
     {
      result.status = RISK_STATUS_BLOCKED;
      result.reason = "نماد مشخص نشده است";
      Print("[RISK ENGINE] BLOCKED | ", result.reason);
      return false;
     }

   if(point <= 0.0)
     {
      result.status = RISK_STATUS_BLOCKED;
      result.reason = "Point معتبر نیست";
      Print("[RISK ENGINE] BLOCKED | ", result.reason);
      return false;
     }

   string reason = "";

   if(!Risk_ValidatePriceGeometry(trade_input.is_buy,
                                  trade_input.entry_price,
                                  trade_input.sl_price,
                                  trade_input.target_price,
                                  reason))
     {
      result.status = RISK_STATUS_BLOCKED;
      result.reason = reason;
      Print("[RISK ENGINE] BLOCKED | ", reason);
      return false;
     }

   result.stop_distance_price = Risk_StopDistancePrice(trade_input.is_buy,
                                                        trade_input.entry_price,
                                                        trade_input.sl_price);
   result.stop_distance_points = result.stop_distance_price/point;

   if(!Risk_CheckStopDistance(limits,result.stop_distance_points,reason))
     {
      result.status = RISK_STATUS_BLOCKED;
      result.reason = reason;
      Print("[RISK ENGINE] BLOCKED | ", reason);
      return false;
     }

   result.rr = Risk_CalculateRR(trade_input.is_buy,
                                trade_input.entry_price,
                                trade_input.sl_price,
                                trade_input.target_price);

   if(!Risk_CheckRR(limits,result.rr,reason))
     {
      result.status = RISK_STATUS_BLOCKED;
      result.reason = reason;
      Print("[RISK ENGINE] BLOCKED | ", reason);
      return false;
     }

   //=================================================================
   // تعیین حجم معامله
   //=================================================================
   double requested_percent = trade_input.risk_percent_requested;

   if(!limits.use_fixed_lot)
     {
      //--- حالت قبلی: حجم براساس ریسک پولی محاسبه می‌شود
      if(requested_percent <= 0.0)
         requested_percent = limits.risk_percent_per_trade;

      //--- [جدید] سایزینگ تطبیقی نرم بر اساس روند اخیر برد/باخت
      double adaptive_multiplier = Risk_GetAdaptiveRiskMultiplier(account,
         limits.enable_adaptive_risk, limits.adaptive_reduction_per_loss_percent,
         limits.adaptive_increase_per_win_percent, limits.adaptive_min_multiplier,
         limits.adaptive_max_multiplier);

      if(limits.enable_adaptive_risk && MathAbs(adaptive_multiplier-1.0) > 0.001)
        {
         double before = requested_percent;
         requested_percent *= adaptive_multiplier;
         Print("[RISK ENGINE] ADAPTIVE_SIZING | ریسک از ",
               DoubleToString(before,2), "% به ", DoubleToString(requested_percent,2),
               "% تنظیم شد | ConsecLosses=", account.consecutive_losses,
               " | ConsecWins=", account.consecutive_wins,
               " | Multiplier=", DoubleToString(adaptive_multiplier,2));
        }

      if(requested_percent > limits.max_risk_percent_per_trade)
        {
         result.status = RISK_STATUS_BLOCKED;
         result.reason = "ریسک درخواستی از سقف مجاز بیشتر است | " +
                         DoubleToString(requested_percent, 2) + "% > " +
                         DoubleToString(limits.max_risk_percent_per_trade, 2) + "%";
         Print("[RISK ENGINE] BLOCKED | ", result.reason);
         return false;
        }

      result.risk_percent = requested_percent;
      result.risk_money   = account.equity*(requested_percent/100.0);

      result.position_volume = Risk_CalculateVolume(symbol,
                                                     trade_input.entry_price,
                                                     trade_input.sl_price,
                                                     result.risk_money,
                                                     limits.ignore_capital_size_for_min_volume);
     }
   else
     {
      //--- حالت جدید: حجم ثابت
      result.position_volume = Risk_CalculateFixedVolume(symbol,limits.fixed_lot_size);

      if(result.position_volume <= 0.0)
        {
         result.status = RISK_STATUS_BLOCKED;
         result.reason = "حجم ثابت قابل اجرا نیست | FixedLot=" +
                         DoubleToString(limits.fixed_lot_size,2);
         Print("[RISK ENGINE] BLOCKED | ", result.reason);
         return false;
        }

      //--- بسیار مهم: ریسک واقعی حجم ثابت محاسبه می‌شود
      result.risk_money = Risk_CalculateMoney(symbol,
                                              result.position_volume,
                                              trade_input.entry_price,
                                              trade_input.sl_price);
      result.risk_percent = Risk_MoneyToPercent(result.risk_money,account.equity);

      if(result.risk_money <= 0.0 || result.risk_percent <= 0.0)
        {
         result.status = RISK_STATUS_BLOCKED;
         result.reason = "ریسک واقعی حجم ثابت قابل محاسبه نیست | Volume=" +
                         DoubleToString(result.position_volume,2);
         Print("[RISK ENGINE] BLOCKED | ", result.reason);
         return false;
        }
     }

   //=================================================================
   // کنترل نهایی محدودیت‌های حساب بر اساس ریسک واقعی
   //=================================================================
   if(!Risk_CheckAccountLimits(limits,
                               account,
                               result.risk_percent,
                               trade_input.is_buy,
                               reason))
     {
      result.status = RISK_STATUS_BLOCKED;
      result.reason = reason;
      Print("[RISK ENGINE] BLOCKED | ", reason,
            " | Volume=",DoubleToString(result.position_volume,2));
      return false;
     }

   //--- اگر حالت Dynamic است و حجم محاسبه نشده باشد
   if(result.position_volume <= 0.0)
     {
      result.status = RISK_STATUS_BLOCKED;
      result.reason = "حجم قابل اجرا با ریسک مجاز محاسبه نشد | " +
                      "RiskMoney=" + DoubleToString(result.risk_money, 2) +
                      " | Entry=" + DoubleToString(trade_input.entry_price, _Digits) +
                      " | SL=" + DoubleToString(trade_input.sl_price, _Digits);
      Print("[RISK ENGINE] BLOCKED | ", result.reason);
      return false;
     }

   //--- برای حالت Dynamic، ریسک واقعی حجم نهایی را دوباره اندازه‌گیری می‌کنیم.
   //--- برای Fixed Lot نیز قبلاً محاسبه شده است.
   if(!limits.use_fixed_lot)
     {
      result.risk_money = Risk_CalculateMoney(symbol,
                                              result.position_volume,
                                              trade_input.entry_price,
                                              trade_input.sl_price);
      result.risk_percent = Risk_MoneyToPercent(result.risk_money,account.equity);

      //--- بعد از گرد شدن حجم، یک کنترل نهایی انجام می‌دهیم.
      if(!Risk_CheckAccountLimits(limits,
                                  account,
                                  result.risk_percent,
                                  trade_input.is_buy,
                                  reason))
        {
         result.status = RISK_STATUS_BLOCKED;
         result.reason = reason;
         Print("[RISK ENGINE] BLOCKED | ", reason,
               " | FinalVolume=",DoubleToString(result.position_volume,2));
         return false;
        }
     }

   //=================================================================
   // محاسبه پاداش واقعی بر اساس حجم نهایی
   //=================================================================
   const double reward_risk_ratio = result.rr;
   const double reward_distance   = Risk_RewardDistancePrice(trade_input.is_buy,
                                                              trade_input.entry_price,
                                                              trade_input.target_price);

   double tick_size  = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT);
   if(tick_value <= 0.0)
      tick_value = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);

   if(tick_size > 0.0 && tick_value > 0.0)
      result.reward_money = (reward_distance/tick_size)*tick_value*result.position_volume;
   else
      result.reward_money = result.risk_money*reward_risk_ratio;

   if(trade_input.estimated_cost_money > 0.0)
      result.reward_money = MathMax(0.0,result.reward_money-trade_input.estimated_cost_money);

   result.status   = RISK_STATUS_APPROVED;
   result.approved = true;

   if(limits.use_fixed_lot)
      result.reason = "ریسک معامله تأیید شد | حجم ثابت";
   else
      result.reason = "ریسک معامله تأیید شد";

   //=================================================================
   // لاگ موفقیت
   //=================================================================
   Print(
      "[RISK ENGINE] APPROVED",
      " | Direction=", (trade_input.is_buy ? "BUY" : "SELL"),
      " | Volume=", DoubleToString(result.position_volume, 2),
      " | RiskMoney=", DoubleToString(result.risk_money, 2),
      " | RiskPercent=", DoubleToString(result.risk_percent, 2), "%",
      " | RR=", DoubleToString(result.rr, 2),
      " | SL_Distance=", DoubleToString(result.stop_distance_points, 1), " pts",
      " | Reward=", DoubleToString(result.reward_money, 2),
      " | Mode=", (limits.use_fixed_lot ? "FIXED_LOT" : "RISK_BASED")
   );

   return true;
  }

//----------------------------------------------------------------------
// متن کامل نتیجه ریسک برای گزارش
//----------------------------------------------------------------------
string Risk_ResultToText(const RiskResult &result)
  {
   string text = "";

   text += "وضعیت: " + RiskStatusToPersian(result.status);
   text += " | ریسک پولی: " + DoubleToString(result.risk_money,2);
   text += " | ریسک درصدی: " + DoubleToString(result.risk_percent,2) + "%";
   text += " | R/R: " + DoubleToString(result.rr,2);
   text += " | فاصله SL: " + DoubleToString(result.stop_distance_points,1) + " پوینت";
   text += " | حجم: " + DoubleToString(result.position_volume,2);
   text += " | پاداش برآوردی: " + DoubleToString(result.reward_money,2);

   if(result.reason != "")
      text += " | دلیل: " + result.reason;

   return text;
  }

//----------------------------------------------------------------------
// به‌روزرسانی وضعیت Equity و Peak Equity
//----------------------------------------------------------------------
void Risk_UpdateEquityState(RiskAccountState &state,
                            const double balance,
                            const double equity)
  {
   state.balance = balance;
   state.equity  = equity;

   if(state.peak_equity <= 0.0 || equity > state.peak_equity)
      state.peak_equity = equity;
  }

//----------------------------------------------------------------------
// به‌روزرسانی ریسک باز
// [اصلاح] حالا مقادیر واقعی پذیرفته می‌شوند
//----------------------------------------------------------------------
void Risk_UpdateOpenRisk(RiskAccountState &state,
                         const double total_open_risk_money,
                         const double buy_risk_money,
                         const double sell_risk_money)
  {
   state.open_risk_money   = MathMax(0.0,total_open_risk_money);
   state.buy_risk_money    = MathMax(0.0,buy_risk_money);
   state.sell_risk_money   = MathMax(0.0,sell_risk_money);

   state.open_risk_percent = Risk_MoneyToPercent(state.open_risk_money,state.equity);
  }

//----------------------------------------------------------------------
// به‌روزرسانی زیان روزانه
//----------------------------------------------------------------------
void Risk_UpdateDailyLoss(RiskAccountState &state,
                          const double daily_loss_money)
  {
   state.daily_loss_money = MathMax(0.0,daily_loss_money);
   state.daily_loss_percent = Risk_MoneyToPercent(state.daily_loss_money,state.equity);
  }

//----------------------------------------------------------------------
// به‌روزرسانی زیان‌های متوالی
//----------------------------------------------------------------------
void Risk_SetConsecutiveLosses(RiskAccountState &state,
                               const int consecutive_losses)
  {
   state.consecutive_losses = MathMax(0,consecutive_losses);
  }

void Risk_SetConsecutiveWins(RiskAccountState &state,
                             const int consecutive_wins)
  {
   state.consecutive_wins = MathMax(0,consecutive_wins);
  }

//+------------------------------------------------------------------+
//| [جدید] ضریب تطبیقی ریسک بر اساس روند اخیر برد/باخت                |
//| بعد از باخت‌های متوالی: ریسک به‌صورت نرم کاهش می‌یابد (نه توقف کامل)|
//| بعد از بردهای متوالی: ریسک کمی افزایش می‌یابد (تا سقف مشخص)        |
//| این جایگزین/مکمل مدار محافظ سخت Inp_Max_Consecutive_Losses است.   |
//+------------------------------------------------------------------+
double Risk_GetAdaptiveRiskMultiplier(const RiskAccountState &account,
                                      const bool enable_adaptive,
                                      const double reduction_per_loss_percent,
                                      const double increase_per_win_percent,
                                      const double min_multiplier,
                                      const double max_multiplier)
  {
   if(!enable_adaptive) return 1.0;

   double multiplier = 1.0;

   if(account.consecutive_losses > 0)
      multiplier -= (account.consecutive_losses * reduction_per_loss_percent / 100.0);
   else if(account.consecutive_wins > 0)
      multiplier += (account.consecutive_wins * increase_per_win_percent / 100.0);

   return MathMax(min_multiplier, MathMin(max_multiplier, multiplier));
  }

//+------------------------------------------------------------------+

#endif // __TFLAB_RISK_ENGINE_MQH__
