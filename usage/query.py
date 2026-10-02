"""Bounded, read-only query protocol over SSH stdin. Never accepts SQL or paths."""
import json
import math
import sqlite3
import sys
import time
from pathlib import Path
from .store import unpack

STEPS = (60,300,900,3600,14400,86400,604800,2592000,31536000)

def options(params):
    if set(params)-{'start','end','step'}:
        raise ValueError('Unknown query parameter')
    end = float(params.get('end',time.time()))
    start = float(params.get('start',end-28800))
    if not all(math.isfinite(x) for x in (start,end)) or start<0 or end<=start or end>time.time()+86400:
        raise ValueError('Invalid date range')
    if end-start>100*366*86400:
        raise ValueError('Date range exceeds 100 years')
    start, end = math.floor(start/60)*60, math.ceil(end/60)*60
    desired = params.get('step','auto')
    desired = 60 if desired=='auto' else int(desired)
    if desired not in STEPS:
        raise ValueError('Unsupported interval')
    step = next((x for x in STEPS if x>=desired and (end-start)/x<=1200),STEPS[-1])
    return start,end,step

def rows(db, start, end, size):
    for timestamp, blob in db.execute('SELECT time,data FROM buckets WHERE resolution=? AND time>=? AND time<? ORDER BY time',
                                      (size,int(start//size)*size,end)):
        if size>60 and (timestamp<start or timestamp+size>end):
            yield from rows(db,max(start,timestamp),min(end,timestamp+size),3600 if size==86400 else 60)
        else:
            yield timestamp,unpack(blob)

def combine(target, source):
    for key,value in source.items():
        item = target.setdefault(key,{'sum':0,'seconds':0,'peak':0,'apps':{}})
        item['sum'] += value['sum']
        item['seconds'] += value['seconds']
        item['peak'] = max(item['peak'],value['peak'])
        for app,amount in value['apps'].items():
            item['apps'][app] = item['apps'].get(app,0)+amount

def query(path, params):
    start,end,step = options(params)
    if not Path(path).exists():
        return {'ok':True,'start':start,'end':end,'step':step,'catalog':[],
                'points':[],'metadata':{},'message':'History collection has not produced its first sample yet.'}
    db = sqlite3.connect(Path(path).resolve().as_uri()+'?mode=ro',uri=True,timeout=5)
    try:
        db.execute('PRAGMA query_only=ON')
        db.execute('BEGIN')
        version = db.execute('PRAGMA user_version').fetchone()[0]
        if version!=1:
            raise ValueError('Unsupported history schema; existing data has not been modified')
        catalog = [json.loads(row[0]) for row in db.execute('SELECT data FROM catalog')]
        metadata = {key:json.loads(value) for key,value in db.execute('SELECT id,value FROM metadata')}
        size = 86400 if step>=86400 else 3600 if step>=3600 else 60
        buckets = {}
        for timestamp, data in rows(db,start,end,size):
            combine(buckets.setdefault(timestamp//step*step,{}),data)
        points = []
        for timestamp,data in sorted(buckets.items()):
            metrics = {}
            for key,value in data.items():
                seconds = value['seconds']
                metrics[key] = {'value':value['sum']/seconds if seconds else None,
                    'seconds':seconds,'peak':value['peak'],
                    'apps':{app:amount/seconds for app,amount in value['apps'].items()} if seconds else {}}
            # Repair presentation for every client, including older Render pages.
            # Original stored estimates remain untouched for audit/recovery.
            for key, value in metrics.items():
                if key.startswith('gpu:') and 'measured:'+key in metrics:
                    value['apps'] = dict(metrics['measured:'+key]['apps'])
            points.append({'time':timestamp,'metrics':metrics})
        return {'ok':True,'schema':version,'start':start,'end':end,'step':step,
                'catalog':catalog,'metadata':metadata,'points':points}
    finally:
        db.close()

def main():
    try:
        params = json.loads(sys.stdin.read(8193))
        result = query(Path.home()/'.local/share/ai-usage-history/history.sqlite3',params)
        print(json.dumps(result,separators=(',',':'),allow_nan=False))
    except Exception as error:
        print(json.dumps({'ok':False,'error':str(error)[:180]}))
        sys.exit(1)

if __name__=='__main__':
    main()
