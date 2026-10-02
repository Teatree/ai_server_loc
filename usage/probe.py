"""Join trusted counter snapshots to local process identities; no elevation here."""
import json
import re
import time
from pathlib import Path

def merge_snapshot(data, rows, clients, now):
    if data.get('version')!=1 or not -2<=now-data.get('time',0)<=20:
        raise ValueError('Stale GPU probe snapshot')
    joined=0
    for item in data.get('clients',[]):
        pid=item['pid'];row=rows.get(pid)
        if not row or tuple(row['key'])!=(pid,item['start']):
            continue
        if not re.fullmatch(r'[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-7]',item['bus']):
            continue
        engines={k:v for k,v in item['engines'].items() if
            re.fullmatch(r'drm-engine-[a-z0-9_-]+',k) and not k.startswith('drm-engine-capacity-')
            and isinstance(v,int) and v>=0}
        if not engines:
            continue
        key=(item['bus'],str(item['client']))
        # Shared descriptors count once; process start time prevents PID reuse.
        if key in clients and clients[key].get('source')=='probe':
            continue
        clients[key]={'pid':pid,'owner':row['owner'],'engines':engines,
            'compute':False,'vram':0,'source':'probe','sample_time':data['time']}
        joined+=1
    return joined

def augment(rows, clients, path=Path('/run/ai-usage-probe/current.json')):
    try:
        info=path.stat()
        if path.is_symlink() or info.st_uid!=0 or info.st_mode&0o022 or info.st_size>2_000_000:
            return 'GPU probe snapshot rejected: ownership or permissions'
        data=json.loads(path.read_text())
        count=merge_snapshot(data,rows,clients,time.time())
        return f'GPU probe active: {count} counter clients'
    except FileNotFoundError:
        return 'GPU probe not installed; cross-account GPU counters unavailable'
    except (OSError,ValueError,KeyError,TypeError):
        return 'GPU probe unavailable or stale; unknown usage remains unattributed'
