"""Explicit native refit of one packaged job; no runtime install or auto compile."""
from __future__ import annotations
import argparse,concurrent.futures,hashlib,json,os,subprocess
from pathlib import Path
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser();p.add_argument('--job',type=Path,required=True);p.add_argument('--model-source',type=Path,required=True)
    p.add_argument('--executable',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--runtime-path',type=Path)
    a=p.parse_args();j=json.loads(a.job.read_text());data=a.job.parent/'data.json'
    if sha(data)!=j['data_file_sha256'] or sha(a.model_source)!=j['model_source_sha256']:raise ValueError('PACKAGED_INPUT_SOURCE_DIFFERS')
    a.output.mkdir(parents=True,exist_ok=False);env=os.environ.copy();env.update(OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1')
    if a.runtime_path:env['PATH']=str(a.runtime_path)+os.pathsep+env.get('PATH','')
    def chain(i):
        command=[str(a.executable.resolve()),'sample','num_warmup=1000','num_samples=2000','save_warmup=1','adapt','delta=0.99',
            'algorithm=hmc','engine=nuts','max_depth=12','id='+str(i),'random','seed='+str(j['seed']),
            'data','file='+str(data.resolve()),'output','file='+str((a.output/f'chain-{i}.csv').resolve()),'sig_figs=18','refresh=200']
        with (a.output/f'chain-{i}.log').open('w') as f:return subprocess.run(command,env=env,stdout=f,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0)).returncode
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:codes=list(pool.map(chain,range(1,5)))
    record=dict(status='SAMPLED_NOT_YET_DIAGNOSED' if not any(codes) else 'EXECUTION_FAILED',returncodes=codes,
        job=j['name'],seed=j['seed'],user_supplied_executable_sha256=sha(a.executable),model_source_sha256=sha(a.model_source),
        executable_compilation_provenance_not_independently_certified=True,chains=4,warmup=1000,retained=2000)
    (a.output/'portable-refit.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'])
    return 0 if not any(codes) else 1
if __name__=='__main__':raise SystemExit(main())
