#ifndef __TFLAB_CONFLUENCE_ENGINE_MQH__
#define __TFLAB_CONFLUENCE_ENGINE_MQH__
#property strict

struct ConfluenceResult
  { bool valid; double score; string reason; };
void Confluence_Init(ConfluenceResult &r){ZeroMemory(r);r.valid=false;r.score=0.0;r.reason="";}
void Confluence_Calculate(const bool htf_allowed,const bool regime_allowed,const double regime_confidence,const bool streak_allowed,const bool divergence_against,const bool divergence_supports,ConfluenceResult &r)
  {
   Confluence_Init(r); double s=0;
   if(htf_allowed) s+=25; if(regime_allowed) s+=25; s+=MathMin(20.0,MathMax(0.0,regime_confidence*0.20));
   if(streak_allowed) s+=15; if(divergence_supports) s+=10; if(divergence_against) s-=30;
   r.score=MathMax(0.0,MathMin(100.0,s)); r.valid=true; r.reason="Confluence محاسبه شد";
  }
void Confluence_CalculateContinuation(const bool htf_allowed,const bool regime_allowed,const double regime_confidence,const bool streak_allowed,const bool correction_valid,const double correction_ratio,const double max_ratio,const bool divergence_against,const bool divergence_supports,ConfluenceResult &r)
  {
   Confluence_Calculate(htf_allowed,regime_allowed,regime_confidence,streak_allowed,divergence_against,divergence_supports,r);
   if(correction_valid) r.score+=10.0;
   if(max_ratio>0.0 && correction_ratio>max_ratio) r.score-=20.0;
   r.score=MathMax(0.0,MathMin(100.0,r.score));
  }
#endif
