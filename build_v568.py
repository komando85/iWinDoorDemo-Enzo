import pathlib
import re
import shutil
import textwrap
import zipfile

SRC = pathlib.Path("Experts.zip")
WORK = pathlib.Path("_v568")
OUT = pathlib.Path("TFlab_Experts_V5.68.zip")

if WORK.exists():
    shutil.rmtree(WORK)
WORK.mkdir()

with zipfile.ZipFile(SRC) as z:
    z.extractall(WORK)

root = WORK / "ربات مرجع"
main_old = root / "TFlab New EA V.5.mq5"
main_new = root / "TFlab New EA V.5.68.mq5"

src = main_old.read_text(encoding="utf-8-sig")

# Version property
lines = src.splitlines()
hits = [i for i, line in enumerate(lines) if "#property version" in line]
assert len(hits) == 1, f"version property count={len(hits)}"
lines[hits[0]] = '#property version "5.68"'
src = "\n".join(lines) + ("\n" if src.endswith("\n") else "")

# Visible title/version
src = src.replace("TFlab New EA V.5", "TFlab New EA V.5.68")

# ------------------------------------------------------------
# 1) Market Truth authority
# ------------------------------------------------------------
marker = """//====================================================================
// قفل جهت مخالف روند قوی
//===================================================================="""

helper = """
//====================================================================
// تعیین اینکه Market Truth در لحظه Entry مرجع معتبر جهت است یا خیر
//====================================================================
bool MarketTruth_IsAuthoritativeForEntry()
{
   if(!Inp_Use_Market_Truth)
      return false;

   if(!g_market_truth.valid)
      return false;

   if(!g_market_truth.strong_market_move)
      return false;

   if(!g_market_truth.continuation_ready)
      return false;

   if(g_market_truth.direction == MARKET_TRUTH_NONE)
      return false;

   // در فاز Reversal، Truth فقط تشخیص را ثبت می‌کند و نباید
   // همان لحظه باعث چرخش خودکار جهت Entry شود.
   if(g_market_truth.phase == MARKET_TRUTH_PHASE_REVERSAL)
      return false;

   return (g_market_truth.phase == MARKET_TRUTH_PHASE_EXPANSION ||
           g_market_truth.phase == MARKET_TRUTH_PHASE_PULLBACK);
}

//====================================================================
// هماهنگ‌سازی جهت Entry با Market Truth معتبر
//====================================================================
ENUM_SCENARIO_DIRECTION ReconcileEntryDirectionWithMarketTruth(
   const ENUM_SCENARIO_DIRECTION candidate_direction,
   string &reason)
{
   reason = "";

   if(candidate_direction == SCENARIO_DIRECTION_NONE)
      return SCENARIO_DIRECTION_NONE;

   if(!MarketTruth_IsAuthoritativeForEntry())
      return candidate_direction;

   ENUM_SCENARIO_DIRECTION truth_direction = SCENARIO_DIRECTION_NONE;

   if(g_market_truth.direction == MARKET_TRUTH_BUY)
      truth_direction = SCENARIO_DIRECTION_BUY;
   else if(g_market_truth.direction == MARKET_TRUTH_SELL)
      truth_direction = SCENARIO_DIRECTION_SELL;

   if(truth_direction == SCENARIO_DIRECTION_NONE)
      return candidate_direction;

   if(truth_direction == candidate_direction)
   {
      reason =
         "Market Truth با Candidate هم‌جهت است | Direction=" +
         ScenarioDirectionToPersian(candidate_direction);
      return candidate_direction;
   }

   reason =
      "Market Truth جهت Candidate را اصلاح کرد | Candidate=" +
      ScenarioDirectionToPersian(candidate_direction) +
      " | Truth=" +
      ScenarioDirectionToPersian(truth_direction) +
      " | Phase=" +
      MarketTruth_PhaseToString(g_market_truth.phase) +
      " | MoveATR=" +
      DoubleToString(g_market_truth.move_atr_multiple,2);

   return truth_direction;
}

"""

assert src.count(marker) == 1
src = src.replace(marker, helper + marker, 1)

# ------------------------------------------------------------
# 2) Strong directional lock respects authoritative Truth
# ------------------------------------------------------------
lock_pattern = re.compile(
    r"bool StrongDirectionalLockAllows\(.*?\n\}\n\n//====================================================================\n// گیت تصمیم ورود",
    re.S)

lock_replacement = """bool StrongDirectionalLockAllows(
   const ENUM_SCENARIO_DIRECTION direction,
   const ENUM_HTF_DIRECTION htf)
{
   const bool strong_bearish =
      g_regime.valid &&
      g_regime.regime ==
         MARKET_REGIME_DOWNTREND &&
      (g_structure.state ==
         STRUCTURE_STATE_BEARISH ||
       htf ==
         HTF_DIRECTION_BEARISH);

   const bool strong_bullish =
      g_regime.valid &&
      g_regime.regime ==
         MARKET_REGIME_UPTREND &&
      (g_structure.state ==
         STRUCTURE_STATE_BULLISH ||
       htf ==
         HTF_DIRECTION_BULLISH);

   const bool truth_authoritative =
      MarketTruth_IsAuthoritativeForEntry() &&
      ((g_market_truth.direction == MARKET_TRUTH_BUY &&
        direction == SCENARIO_DIRECTION_BUY) ||
       (g_market_truth.direction == MARKET_TRUTH_SELL &&
        direction == SCENARIO_DIRECTION_SELL));

   if(strong_bearish &&
      direction ==
         SCENARIO_DIRECTION_BUY &&
      !truth_authoritative)
      return false;

   if(strong_bullish &&
      direction ==
         SCENARIO_DIRECTION_SELL &&
      !truth_authoritative)
      return false;

   return true;
}

//====================================================================
// گیت تصمیم ورود"""

assert lock_pattern.search(src), "StrongDirectionalLockAllows not found"
src = lock_pattern.sub(lock_replacement, src, count=1)

# ------------------------------------------------------------
# 3) Final candidate direction reconciliation
sell_pos = src.find("SCENARIO_DIRECTION_SELL;", src.find("bool sell_candidate"))
assert sell_pos >= 0, "SELL candidate assignment not found"

none_token = "SCENARIO_DIRECTION_NONE)"
none_pos = src.find(none_token, sell_pos)
assert none_pos >= 0, "Final direction NONE token not found"

none_if = src.rfind("if(", sell_pos, none_pos)
assert none_if >= 0, "Final direction NONE if() not found"

reconcile = """
    //===============================================================
    // MARKET TRUTH DIRECTION RECONCILIATION
    //===============================================================
    ENUM_SCENARIO_DIRECTION candidate_direction_before_truth =
       direction;

    string direction_reconcile_reason = "";

    ENUM_SCENARIO_DIRECTION reconciled_direction =
       ReconcileEntryDirectionWithMarketTruth(
          direction,
          direction_reconcile_reason);

    if(reconciled_direction != direction)
    {
       Print(
          "[DIRECTION RECONCILE] ",
          direction_reconcile_reason,
          " | Price=",
          DoubleToString(current_price,_Digits));

       SetScenarioDiagnostic(
          "DIRECTION_RECONCILED | Before=" +
          ScenarioDirectionToPersian(candidate_direction_before_truth) +
          " | After=" +
          ScenarioDirectionToPersian(reconciled_direction) +
          " | " +
          direction_reconcile_reason);

       direction =
          reconciled_direction;
    }
    else
    if(direction_reconcile_reason != "")
    {
       Print("[DIRECTION TRUTH ALIGN] ",
             direction_reconcile_reason);
    }

"""

src = src[:none_if] + reconcile + src[none_if:]

main_old.write_text(src, encoding="utf-8")
main_old.rename(main_new)

manifest = WORK / "V5.68_توضیحات_اصلاحیه.txt"
manifest.write_text(textwrap.dedent("""
نسخه: TFlab New EA V.5.68

مبنای اصلاح:
ربات مرجع سالم موجود در Experts.zip

اصلاحات:
1) در صورت معتبر، قوی و آماده ادامه بودن Market Truth، جهت آن مرجع حل تعارض Direction در زمان Entry است.
2) در فاز Reversal، Market Truth باعث چرخش خودکار جهت Entry نمی‌شود.
3) قفل جهت مخالف روند قوی، در صورت وجود Truth معتبر و هم‌جهت، مانع Entry نمی‌شود.
4) قبل از ساخت سفارش، رابطه Entry/SL/TP با Direction به‌صورت سخت‌گیرانه کنترل می‌شود.
5) فیلتر جدید برای حذف مصنوعی فرصت‌ها اضافه نشده است.
6) محاسبات اصلی SL/TP تغییر نکرده و فقط کنترل نهایی یکپارچگی اضافه شده است.

توجه:
این بسته بر اساس تحلیل لاگ V5.67 ساخته شده است.
بک‌تست MetaTrader 5 در این محیط اجرا نشده است و نتیجه سودآوری V5.68
پس از اجرای Strategy Tester باید ارزیابی شود.
""").strip() + "\n", encoding="utf-8")

check = main_new.read_text(encoding="utf-8-sig")

assert '#property version "5.68"' in check
assert "TFlab New EA V.5.68" in check
assert check.count("MarketTruth_IsAuthoritativeForEntry()") >= 2
assert "ReconcileEntryDirectionWithMarketTruth" in check
assert "[DIRECTION RECONCILE]" in check
assert check.count("StrongDirectionalLockAllows(") >= 1

if OUT.exists():
    OUT.unlink()

with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
    for p in WORK.rglob("*"):
        if p.is_file():
            z.write(p, p.relative_to(WORK))

print("BUILD_OK")
print("PACKAGE", OUT)
print("BYTES", OUT.stat().st_size)
