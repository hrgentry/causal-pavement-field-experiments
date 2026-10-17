"""NumPy-only replay of v5 and matched-control derived exports; no native refit."""
from __future__ import annotations
import argparse,json,math
from pathlib import Path
import numpy as np
import v5_replay as base

ROOT=Path(__file__).resolve().parents[1]
S=ROOT/'studies/01-wma-long-term-factors'
C=S/'analysis/outputs/substantive-v5-controls'

def run(output):
    old_result=output.with_name('v5-only-replay.json')
    if not base.run(old_result):return False
    old=json.loads(old_result.read_text(encoding='utf-8'));errors=[];checks=0;maxerr=old['max_absolute_error']
    def check(value,expected,label,tolerance=1e-10):
        nonlocal checks,maxerr
        checks+=1;err=abs(float(value)-float(expected));maxerr=max(maxerr,err)
        if not np.isfinite(err) or err>tolerance:errors.append(label+': '+str(err))
    d=np.load(C/'manitoba-target-draws.npz')
    for r in base.rows(C/'manitoba-targets.csv'):
        a=d[r['model']+'__delta'][:,['preparation','material','thickness'].index(r['contrast'])]
        for key,v in zip(['lower','median','upper'],np.quantile(a,[.025,.5,.975])):check(v,r[key],r['model']+'/'+key)
        check(np.mean(a>0),r['Pr_positive'],r['model']+'/sign')
    d=np.load(C/'manitoba-validation-draws.npz');new=base.rows(C/'manitoba-validation.csv')
    for r in new:
        key='__'.join(r[k] for k in ['model','pair','campaign']);a=d[key];w=a[:,4];y=float(r['observed_mm'])
        check(w.sum(),1,key+'/weights');check(base.crps(a[:,0],y,w),r['crps_mm'],key+'/crps')
        check(base.crps(a[:,1],y,w),r['rounded_crps_mm'],key+'/rounded')
        check(base.lse(a[:,2]+np.log(w)),r['log_ratio_predictive_density'],key+'/logratio')
        check(base.lse(a[:,3]+np.log(w)),r['joint_bin_log_score'],key+'/bin')
    for r in base.rows(C/'manitoba-validation-summary.csv'):
        group=[v for v in new if v['model']==r['model']]
        for key in ['crps_mm','rounded_crps_mm','joint_bin_log_score']:check(np.mean([float(v[key]) for v in group]),r['mean_'+key],r['model']+'/summary/'+key)
        check(len(group),r['units'],r['model']+'/units')
        check(sum(v['method']=='exact' for v in group),r['exact_refits'],r['model']+'/exact')
    data=base.rows(C/'matched-comparison-pairs.csv')
    for r in data:check(float(r['reference_score_mm'])-float(r['alternative_score_mm']),r['gain_mm'],r['comparison']+'/gain')
    for r in base.rows(C/'matched-comparison-summary.csv'):
        group=[v for v in data if v['comparison']==r['comparison']]
        for key,col in [('reference_mean_mm','reference_score_mm'),('alternative_mean_mm','alternative_score_mm'),('mean_gain_mm','gain_mm')]:check(np.mean([float(v[col]) for v in group]),r[key],r['comparison']+'/'+key)
        check(sum(float(v['gain_mm'])>0 for v in group),r['improved'],r['comparison']+'/improved')
    for r in base.rows(C/'date-invariance-counts.csv'):check(r['actual_count'],r['shifted_count'],'counter-invariance')
    result=dict(status='PASS' if not errors else 'FAIL',checks=old['checks']+checks,base_checks=old['checks'],
        matched_control_checks=checks,max_absolute_error=maxerr,errors=errors,numpy_version=np.__version__,native_refits_executed=0,
        scope='Exported target quantiles and conditional scores, matched gains and counter invariance; no physical or causal calibration',g='UNDEFINED')
    output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result));return not errors

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    raise SystemExit(0 if run(args.output) else 1)
