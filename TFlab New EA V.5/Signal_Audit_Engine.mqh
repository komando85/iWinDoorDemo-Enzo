#ifndef __TFLAB_SIGNAL_AUDIT_ENGINE_MQH__
#define __TFLAB_SIGNAL_AUDIT_ENGINE_MQH__

//+------------------------------------------------------------------+
//|                  Signal_Audit_Engine.mqh                         |
//| ممیزی سیگنال بدون دخالت در ورود/خروج                             |
//| V5.12: ثبت ادعای سیگنال و سنجش نتیجه واقعی در 15/30/60 دقیقه      |
//+------------------------------------------------------------------+
#property strict

#include "EA_Inputs.mqh"
#include "Scenario_Engine.mqh"
#include "Strategy_Engine.mqh"
#include "Market_Regime.mqh"
#include "Market_Structure.mqh"
#include "Impulse_Correction.mqh"
#include "Market_Truth_Engine.mqh"
#include "Market_HigherTimeframe.mqh"

struct SignalAuditHorizon
  {
   bool      finalized;
   double    mfe_atr;
   double    mae_atr;
   datetime  first_favorable_time;
   datetime  first_adverse_time;
   string    result;
  };

struct SignalAuditRecord
  {
   bool                    active;
   ulong                   signal_id;
   string                  symbol;
   string                  strategy;
   string                  direction;
   datetime                signal_time;
   double                  entry_price;
   double                  stop_loss;
   double                  target_1;
   double                  target_2;
   double                  atr_price;
   double                  scenario_quality;
   double                  strategy_confidence;
   string                  regime;
   double                  regime_confidence;
   string                  htf_direction;
   double                  htf_strength;
   string                  structure;
   bool                    structure_valid;
   bool                    impulse_valid;
   string                  truth_direction;
   double                  truth_move_atr;
   bool                    zone_valid;
   double                  max_favorable_price;
   double                  max_adverse_price;
   datetime                last_update_time;
   SignalAuditHorizon      h15;
   SignalAuditHorizon      h30;
   SignalAuditHorizon      h60;
  };

struct SignalAuditState
  {
   bool                  enabled;
   bool                  initialized;
   string                file_name;
   datetime              last_update_time;
   SignalAuditRecord     records[];
  };

string SignalAudit_Escape(const string value)
  {
   string s=value;
   StringReplace(s,"\"","\"\"");
   return "\""+s+"\"";
  }

bool SignalAudit_OpenAppend(const string file_name,int &handle,const string header)
  {
   handle=FileOpen(file_name,FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(handle==INVALID_HANDLE)
      return false;

   if(FileSize(handle)==0 && header!="")
      FileWriteString(handle,header+"\r\n");

   FileSeek(handle,0,SEEK_END);
   return true;
  }

void SignalAudit_HorizonReset(SignalAuditHorizon &h)
  {
   ZeroMemory(h);
   h.finalized=false;
   h.mfe_atr=0.0;
   h.mae_atr=0.0;
   h.first_favorable_time=0;
   h.first_adverse_time=0;
   h.result="در انتظار";
  }

void SignalAudit_InitState(SignalAuditState &state)
  {
   ZeroMemory(state);
   state.enabled=false;
   state.initialized=false;
   state.file_name="TFlab_BACKTEST_Signal_Audit.csv";
   state.last_update_time=0;
   ArrayResize(state.records,0);
  }

void SignalAudit_Init(SignalAuditState &state)
  {
   state.enabled=(MQLInfoInteger(MQL_TESTER) && Inp_Enable_Performance_Report);
   if(!state.enabled)
      return;

   state.initialized=true;

   int h=INVALID_HANDLE;
   string header=
      "SignalID;Symbol;Strategy;Direction;SignalTime;Entry;SL;TP1;TP2;ATR;ScenarioQuality;StrategyConfidence;Regime;RegimeConfidence;HTF;HTFStrength;Structure;StructureValid;ImpulseValid;TruthDirection;TruthMoveATR;ZoneValid;15m_MFE_ATR;15m_MAE_ATR;15m_FirstFav;15m_FirstAdv;15m_Result;30m_MFE_ATR;30m_MAE_ATR;30m_FirstFav;30m_FirstAdv;30m_Result;60m_MFE_ATR;60m_MAE_ATR;60m_FirstFav;60m_FirstAdv;60m_Result";

   if(SignalAudit_OpenAppend(state.file_name,h,header))
      FileClose(h);

   Print("[SIGNAL AUDIT] فعال شد | هیچ دخالتی در تصمیم ورود ندارد | خروجی=",state.file_name);
  }

int SignalAudit_Find(const SignalAuditState &state,const ulong signal_id)
  {
   if(signal_id==0)
      return -1;

   for(int i=0;i<ArraySize(state.records);i++)
      if(state.records[i].active && state.records[i].signal_id==signal_id)
         return i;

   return -1;
  }

string SignalAudit_HorizonResult(const SignalAuditHorizon &h)
  {
   return h.result;
  }

void SignalAudit_UpdateHorizonResult(
   SignalAuditHorizon &h,
   const datetime start_time,
   const datetime now,
   const double favorable_atr,
   const double adverse_atr,
   const double threshold_favorable,
   const double threshold_adverse)
  {
   if(h.first_favorable_time==0 && favorable_atr>=threshold_favorable)
      h.first_favorable_time=now;

   if(h.first_adverse_time==0 && adverse_atr>=threshold_adverse)
      h.first_adverse_time=now;

   if(h.first_favorable_time>0 &&
      h.first_adverse_time==0)
      h.result="CORRECT";
   else
   if(h.first_adverse_time>0 &&
      h.first_favorable_time==0)
      h.result="WRONG";
   else
   if(h.first_favorable_time>0 &&
      h.first_adverse_time>0)
     {
      if(h.first_favorable_time<h.first_adverse_time)
         h.result="CORRECT";
      else
      if(h.first_adverse_time<h.first_favorable_time)
         h.result="WRONG";
      else
         h.result="MIXED";
     }
   else
      h.result="UNDECIDED";
  }

void SignalAudit_Register(
   SignalAuditState &state,
   const TradingScenario &scenario,
   const ENUM_STRATEGY_TYPE strategy_type,
   const double strategy_confidence,
   const MarketRegimeState &regime,
   const MarketStructureSnapshot &structure,
   const ImpulseCorrectionSnapshot &move,
   const MarketTruthSnapshot &truth,
   const HigherTimeframeContext &htf)
  {
   if(!state.enabled || !state.initialized)
      return;

   if(scenario.id==0 || scenario.entry_price<=0.0)
      return;

   if(SignalAudit_Find(state,scenario.id)>=0)
      return;

   int n=ArraySize(state.records);
   ArrayResize(state.records,n+1);

   SignalAuditRecord r;
   ZeroMemory(r);

   r.active=true;
   r.signal_id=scenario.id;
   r.symbol=_Symbol;
   r.strategy=StrategyTypeToPersian(strategy_type);
   r.direction=ScenarioDirectionToPersian(scenario.direction);
   r.signal_time=(scenario.created_time>0 ? scenario.created_time : TimeCurrent());
   r.entry_price=scenario.entry_price;
   r.stop_loss=scenario.invalidation_price;
   r.target_1=scenario.target_1;
   r.target_2=scenario.target_2;
   r.atr_price=regime.atr_value;
   r.scenario_quality=scenario.quality_value;
   r.strategy_confidence=strategy_confidence;
   r.regime=MarketRegime_ToPersian(regime.regime);
   r.regime_confidence=regime.confidence;
   r.htf_direction=HigherTimeframeDirectionToText(htf.combined_direction);
   r.htf_strength=htf.combined_strength;
   r.structure=MarketStructure_StateToPersian(structure.state);
   r.structure_valid=structure.valid;
   r.impulse_valid=move.impulse_valid;
   r.truth_direction=MarketTruth_DirectionToString(truth.direction);
   r.truth_move_atr=truth.move_atr_multiple;
   r.zone_valid=scenario.zone_valid;
   r.max_favorable_price=r.entry_price;
   r.max_adverse_price=r.entry_price;
   r.last_update_time=r.signal_time;

   SignalAudit_HorizonReset(r.h15);
   SignalAudit_HorizonReset(r.h30);
   SignalAudit_HorizonReset(r.h60);
   state.records[n]=r;

   Print("[SIGNAL AUDIT] ثبت شد | ID=",r.signal_id,
         " | Direction=",r.direction,
         " | Quality=",DoubleToString(r.scenario_quality,1),
         " | StrategyConf=",DoubleToString(r.strategy_confidence,1));
  }

void SignalAudit_UpdateOneHorizon(
   SignalAuditHorizon &h,
   const datetime signal_time,
   const datetime now,
   const double mfe,
   const double mae,
   const int horizon_minutes)
  {
   if(h.finalized)
      return;

   long elapsed=(long)(now-signal_time);
   if(elapsed<0)
      return;

   // تا قبل از پایان افق، زمان اولین برخورد آستانه‌ها ثبت می‌شود.
   if(elapsed <= horizon_minutes*60)
     {
      if(h.first_favorable_time==0 &&
         mfe>=Inp_Signal_Audit_Threshold_ATR)
         h.first_favorable_time=now;

      if(h.first_adverse_time==0 &&
         mae>=Inp_Signal_Audit_Threshold_ATR)
         h.first_adverse_time=now;
     }

   if(elapsed < horizon_minutes*60)
      return;

   h.mfe_atr=mfe;
   h.mae_atr=mae;

   if(h.first_favorable_time>0 &&
      h.first_adverse_time==0)
      h.result="CORRECT";
   else
   if(h.first_adverse_time>0 &&
      h.first_favorable_time==0)
      h.result="WRONG";
   else
   if(h.first_favorable_time>0 &&
      h.first_adverse_time>0)
     {
      if(h.first_favorable_time<h.first_adverse_time)
         h.result="CORRECT";
      else
      if(h.first_adverse_time<h.first_favorable_time)
         h.result="WRONG";
      else
         h.result="MIXED";
     }
   else
      h.result="UNDECIDED";

   h.finalized=true;
  }

void SignalAudit_Update(SignalAuditState &state,const datetime now,const double bid,const double ask)
  {
   if(!state.enabled || !state.initialized || bid<=0.0 || ask<=0.0)
      return;

   for(int i=0;i<ArraySize(state.records);i++)
     {
      SignalAuditRecord r=state.records[i];
      if(!r.active || r.signal_id==0 || r.atr_price<=0.0)
         continue;

      if(now<r.signal_time)
         continue;

      double mfe=0.0;
      double mae=0.0;

      if(r.direction=="خرید")
        {
         if(bid>r.max_favorable_price)
            r.max_favorable_price=bid;
         if(ask<r.max_adverse_price || r.max_adverse_price==r.entry_price)
            r.max_adverse_price=ask;

         mfe=MathMax(0.0,(r.max_favorable_price-r.entry_price)/r.atr_price);
         mae=MathMax(0.0,(r.entry_price-r.max_adverse_price)/r.atr_price);
        }
      else
        {
         if(ask<r.max_favorable_price || r.max_favorable_price==r.entry_price)
            r.max_favorable_price=ask;
         if(bid>r.max_adverse_price || r.max_adverse_price==r.entry_price)
            r.max_adverse_price=bid;

         mfe=MathMax(0.0,(r.entry_price-r.max_favorable_price)/r.atr_price);
         mae=MathMax(0.0,(r.max_adverse_price-r.entry_price)/r.atr_price);
        }

      SignalAudit_UpdateOneHorizon(r.h15,r.signal_time,now,mfe,mae,15);
      SignalAudit_UpdateOneHorizon(r.h30,r.signal_time,now,mfe,mae,30);
      SignalAudit_UpdateOneHorizon(r.h60,r.signal_time,now,mfe,mae,60);

      r.last_update_time=now;
      state.records[i]=r;
     }

   if(now-state.last_update_time>=60)
     {
      state.last_update_time=now;
      SignalAudit_Write(state);
     }
  }

void SignalAudit_Write(SignalAuditState &state)
  {
   if(!state.enabled || !state.initialized)
      return;

   int h=INVALID_HANDLE;
   if(!SignalAudit_OpenAppend(state.file_name,h,""))
      return;

   // بازنویسی رکوردها در همان فایل برای اینکه وضعیت آخرین افق‌ها کامل باشد.
   FileClose(h);
   h=FileOpen(state.file_name,FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(h==INVALID_HANDLE)
      return;

   string header=
      "SignalID;Symbol;Strategy;Direction;SignalTime;Entry;SL;TP1;TP2;ATR;ScenarioQuality;StrategyConfidence;Regime;RegimeConfidence;HTF;HTFStrength;Structure;StructureValid;ImpulseValid;TruthDirection;TruthMoveATR;ZoneValid;15m_MFE_ATR;15m_MAE_ATR;15m_FirstFav;15m_FirstAdv;15m_Result;30m_MFE_ATR;30m_MAE_ATR;30m_FirstFav;30m_FirstAdv;30m_Result;60m_MFE_ATR;60m_MAE_ATR;60m_FirstFav;60m_FirstAdv;60m_Result";
   FileWriteString(h,header+"\r\n");

   for(int i=0;i<ArraySize(state.records);i++)
     {
      SignalAuditRecord r=state.records[i];
      if(!r.active)
         continue;

      FileWrite(h,
         (string)r.signal_id,
         SignalAudit_Escape(r.symbol),
         SignalAudit_Escape(r.strategy),
         SignalAudit_Escape(r.direction),
         TimeToString(r.signal_time,TIME_DATE|TIME_SECONDS),
         DoubleToString(r.entry_price,_Digits),
         DoubleToString(r.stop_loss,_Digits),
         DoubleToString(r.target_1,_Digits),
         DoubleToString(r.target_2,_Digits),
         DoubleToString(r.atr_price,_Digits),
         DoubleToString(r.scenario_quality,1),
         DoubleToString(r.strategy_confidence,1),
         SignalAudit_Escape(r.regime),
         DoubleToString(r.regime_confidence,1),
         SignalAudit_Escape(r.htf_direction),
         DoubleToString(r.htf_strength,1),
         SignalAudit_Escape(r.structure),
         (r.structure_valid?"YES":"NO"),
         (r.impulse_valid?"YES":"NO"),
         SignalAudit_Escape(r.truth_direction),
         DoubleToString(r.truth_move_atr,2),
         (r.zone_valid?"YES":"NO"),
         DoubleToString(r.h15.mfe_atr,2),
         DoubleToString(r.h15.mae_atr,2),
         (r.h15.first_favorable_time>0?TimeToString(r.h15.first_favorable_time,TIME_DATE|TIME_SECONDS):""),
         (r.h15.first_adverse_time>0?TimeToString(r.h15.first_adverse_time,TIME_DATE|TIME_SECONDS):""),
         SignalAudit_Escape(r.h15.result),
         DoubleToString(r.h30.mfe_atr,2),
         DoubleToString(r.h30.mae_atr,2),
         (r.h30.first_favorable_time>0?TimeToString(r.h30.first_favorable_time,TIME_DATE|TIME_SECONDS):""),
         (r.h30.first_adverse_time>0?TimeToString(r.h30.first_adverse_time,TIME_DATE|TIME_SECONDS):""),
         SignalAudit_Escape(r.h30.result),
         DoubleToString(r.h60.mfe_atr,2),
         DoubleToString(r.h60.mae_atr,2),
         (r.h60.first_favorable_time>0?TimeToString(r.h60.first_favorable_time,TIME_DATE|TIME_SECONDS):""),
         (r.h60.first_adverse_time>0?TimeToString(r.h60.first_adverse_time,TIME_DATE|TIME_SECONDS):""),
         SignalAudit_Escape(r.h60.result));
     }

   FileClose(h);
  }

void SignalAudit_WriteSummary(SignalAuditState &state)
  {
   if(!state.enabled || !state.initialized)
      return;

   int h=INVALID_HANDLE;
   string file_name="TFlab_BACKTEST_Signal_Audit_Summary.csv";
   if(!SignalAudit_OpenAppend(file_name,h,"Metric;Value"))
      return;
   FileClose(h);

   h=FileOpen(file_name,FILE_WRITE|FILE_CSV|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(h==INVALID_HANDLE)
      return;
   FileWriteString(h,"Metric;Value\r\n");

   int total=0, buy=0, sell=0;
   int h15c=0,h15w=0,h15u=0,h15m=0;
   int h30c=0,h30w=0,h30u=0,h30m=0;
   int h60c=0,h60w=0,h60u=0,h60m=0;
   int q70=0,q80=0,q90=0,q100=0;

   for(int i=0;i<ArraySize(state.records);i++)
     {
      SignalAuditRecord r=state.records[i];
      if(!r.active) continue;
      total++;
      if(r.direction=="خرید") buy++;
      if(r.direction=="فروش") sell++;

      if(r.scenario_quality<70.0) q70++;
      else if(r.scenario_quality<80.0) q80++;
      else if(r.scenario_quality<90.0) q90++;
      else q100++;

      if(r.h15.result=="CORRECT") h15c++;
      else if(r.h15.result=="WRONG") h15w++;
      else if(r.h15.result=="MIXED") h15m++;
      else if(r.h15.result=="UNDECIDED") h15u++;

      if(r.h30.result=="CORRECT") h30c++;
      else if(r.h30.result=="WRONG") h30w++;
      else if(r.h30.result=="MIXED") h30m++;
      else if(r.h30.result=="UNDECIDED") h30u++;

      if(r.h60.result=="CORRECT") h60c++;
      else if(r.h60.result=="WRONG") h60w++;
      else if(r.h60.result=="MIXED") h60m++;
      else if(r.h60.result=="UNDECIDED") h60u++;
     }

   FileWrite(h,"TotalSignals",total);
   FileWrite(h,"BUYSignals",buy);
   FileWrite(h,"SELLSignals",sell);
   FileWrite(h,"QualityBelow70",q70);
   FileWrite(h,"Quality70to79",q80);
   FileWrite(h,"Quality80to89",q90);
   FileWrite(h,"Quality90to100",q100);
   FileWrite(h,"15m_CORRECT",h15c);
   FileWrite(h,"15m_WRONG",h15w);
   FileWrite(h,"15m_MIXED",h15m);
   FileWrite(h,"15m_UNDECIDED",h15u);
   FileWrite(h,"30m_CORRECT",h30c);
   FileWrite(h,"30m_WRONG",h30w);
   FileWrite(h,"30m_MIXED",h30m);
   FileWrite(h,"30m_UNDECIDED",h30u);
   FileWrite(h,"60m_CORRECT",h60c);
   FileWrite(h,"60m_WRONG",h60w);
   FileWrite(h,"60m_MIXED",h60m);
   FileWrite(h,"60m_UNDECIDED",h60u);
   FileWrite(h,"AuditThresholdATR",DoubleToString(Inp_Signal_Audit_Threshold_ATR,2));
   FileClose(h);
  }

void SignalAudit_Finalize(SignalAuditState &state)
  {
   if(!state.enabled || !state.initialized)
      return;

   SignalAudit_Write(state);
   SignalAudit_WriteSummary(state);
   Print("[SIGNAL AUDIT] نهایی شد | Signals=",ArraySize(state.records)," | File=",state.file_name);
  }

#endif
