"""NumPy-only replay of exported v5 draws; no model refit or calibration claim."""
from __future__ import annotations
import argparse,csv,json,math
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
S=ROOT/'studies/01-wma-long-term-factors';O=S/'analysis/outputs/substantive-revision-v5'
def rows(p):
    with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def crps(x,y,w=None):
    if w is None:w=np.ones(len(x))/len(x)
    w=w/w.sum();ix=np.argsort(x);a=x[ix];b=w[ix]
    return float(np.sum(b*np.abs(a-y))-np.sum(b*a*(2*np.cumsum(b)-b-1)))
def lse(x):
    m=np.max(x);return float(m+np.log(np.exp(x-m).sum()))

def run(output):
    errors=[];checks=0;maxerr=0.
    def check(value,expected,label,tolerance=1e-10):
        nonlocal checks,maxerr
        checks+=1;error=abs(float(value)-float(expected));maxerr=max(maxerr,error)
        if not np.isfinite(error) or error>tolerance:errors.append(label+': '+str(error))
    draws=np.load(O/'sps10-target-draws.npz')
    for r in rows(O/'sps10-targets.csv'):
        key=r['model']+'__lambda'+r['lambda_value']+'__'+r['target'];k=0 if r['contrast']=='F-H' else 1;a=draws[key][:,k]
        for name,val in zip(['lower','median','upper'],np.quantile(a,[.025,.5,.975])):check(val,r[name],key+'/'+name)
        check(np.mean(a>0),r['Pr_positive'],key+'/sign')
    for r in rows(O/'sps10-bridges.csv'):
        prefix=r['model']+'__lambda'+r['lambda_value']+'__';k=0 if r['contrast']=='F-H' else 1
        c={name:draws[prefix+name][:,k] for name in ['new6','new4','existing4','expected_bracket_operator']}
        value={'project_support':c['new6']-c['new4'],'new_section_transport':c['new4']-c['existing4'],
            'curve':c['expected_bracket_operator']-c['existing4']}[r['component']]
        for name,val in zip(['lower','median','upper'],np.quantile(value,[.025,.5,.975])):check(val,r[name],prefix+r['component']+'/'+name)
    for model in ['rho-beta22','section-half','section-double','technology-double']:
        for target in ['existing4','expected_bracket_operator']:
            for lam in ['0.5','1']:check(np.max(abs(draws[model+'__lambda0__'+target]-draws[model+'__lambda'+lam+'__'+target])),0,model+'/unchanged/'+target)
        check(np.max(abs(draws[model+'__lambda1__new4']-draws[model+'__lambda1__existing4'])),0,model+'/lambda1')
    hold=np.load(O/'sps10-validation-draws.npz')
    for r in rows(O/'sps10-validation.csv'):
        key='__'.join(r[k] for k in ['model','role','project','date','contrast']);a=hold[key];y=float(r['observed_mm'])
        check(crps(a[:,0],y),r['crps_mm'],key+'/crps');check(lse(a[:,1])-math.log(len(a)),r['log_ratio_predictive_density'],key+'/logscore')
    d=np.load(O/'manitoba-target-draws.npz')
    for r in rows(O/'manitoba-targets.csv'):
        k=['preparation','material','thickness'].index(r['contrast']);a=d[r['model']+'__delta'][:,k]
        for name,val in zip(['lower','median','upper'],np.quantile(a,[.025,.5,.975])):check(val,r[name],r['model']+'/'+name)
        check(np.mean(a>0),r['Pr_positive'],r['model']+'/sign')
    d=np.load(O/'manitoba-validation-draws.npz')
    for r in rows(O/'manitoba-validation.csv'):
        key='__'.join(r[k] for k in ['model','pair','campaign']);a=d[key];w=a[:,4];y=float(r['observed_mm'])
        check(w.sum(),1,key+'/weights');check(crps(a[:,0],y,w),r['crps_mm'],key+'/crps')
        check(crps(a[:,1],y,w),r['rounded_crps_mm'],key+'/rounded')
        check(lse(a[:,2]+np.log(w)),r['log_ratio_predictive_density'],key+'/logratio')
        check(lse(a[:,3]+np.log(w)),r['joint_bin_log_score'],key+'/bin')
    quantized=np.load(O/'manitoba-rounded-target-draws.npz')
    for r in rows(O/'manitoba-rounded-targets.csv'):
        k=['preparation','material','thickness'].index(r['contrast']);a=quantized[r['target']][:,k]
        for name,val in zip(['lower','median','upper'],np.quantile(a,[.025,.5,.975])):check(val,r[name],'integer-mean/'+name)
    check(np.max(abs(quantized['integer']-quantized['unrounded']-quantized['integer_minus_unrounded'])),0,'integer-mean/paired-identity')
    baseline=rows(O/'manitoba-recording-baseline.csv');d=np.load(O/'manitoba-recording-baseline-draws.npz')
    old=rows(S/'analysis/outputs/substantive-revision-v4/manitoba-held-pair-validation.csv')
    for r in baseline:
        key='__'.join(r[k] for k in ['model','pair','campaign']);a=d[key]
        ref=next(t for t in old if all(t[k]==r[k] for k in ['model','pair','campaign']));y=float(ref['observed_mm'])
        check(crps(a[:,0],y,a[:,2]),r['rounded_crps_mm'],key+'/baseline-rounded')
        check(lse(a[:,1]+np.log(a[:,2])),r['joint_bin_log_score'],key+'/baseline-bin')
        check(ref['crps_mm'],r['crps_mm'],key+'/original-crps')
    for r in rows(O/'manitoba-time-contribution.csv'):
        campaign=r['campaign'];a=[t for t in old if t['campaign']==campaign and t['model']=='linear-stationary']
        b=[t for t in old if t['campaign']==campaign and t['model']=='linear-event']
        gain=np.mean([float(t['crps_mm']) for t in a])-np.mean([float(t['crps_mm']) for t in b])
        check(gain,r['mean_gain_mm'],campaign+'/gain');check(len(a),4,campaign+'/pairs')
    result=dict(status='PASS' if not errors else 'FAIL',checks=checks,max_absolute_error=maxerr,errors=errors,
        numpy_version=np.__version__,native_refits_executed=0,
        scope='Targets and scores from exported derived draws; no direct latent-mean or causal calibration',g='UNDEFINED')
    output.parent.mkdir(parents=True,exist_ok=True);output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result));return not errors

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    raise SystemExit(0 if run(args.output) else 1)
