"""Privileged, fixed-purpose reader. Exports counters only; accepts no commands."""
import json
import os
import time
from pathlib import Path

def collect(procroot=Path('/proc')):
    records = []
    for proc in procroot.glob('[0-9]*'):
        try:
            start = int((proc/'stat').read_text().rsplit(')',1)[1].split()[19])
            for fd in (proc/'fd').iterdir():
                try:
                    if not os.readlink(fd).startswith('/dev/dri/'):
                        continue
                    fields = dict(line.split(':',1) for line in
                        (proc/'fdinfo'/fd.name).read_text().splitlines() if ':' in line)
                    bus, client = fields.get('drm-pdev','').strip(), fields.get('drm-client-id','').strip()
                    engines = {k:int(v.split()[0]) for k,v in fields.items()
                        if k.startswith('drm-engine-') and not k.startswith('drm-engine-capacity-')}
                    if bus and client and engines:
                        records.append({'pid':int(proc.name),'start':start,'bus':bus,
                                        'client':client,'engines':engines})
                except (OSError,ValueError,IndexError):
                    continue
        except (OSError,ValueError,IndexError):
            continue
    return {'version':1,'time':time.time(),'clients':records}

def main():
    root=Path('/run/ai-usage-probe')
    os.umask(0o022)
    while True:
        result=collect()
        path=root/'pending.json'
        fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_TRUNC|os.O_NOFOLLOW,0o644)
        with os.fdopen(fd,'w') as stream:
            json.dump(result,stream,separators=(',',':'))
        os.replace(path,root/'current.json')
        time.sleep(5)

if __name__=='__main__':
    main()
