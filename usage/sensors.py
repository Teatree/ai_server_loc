"""Read-only Linux counters; does not invoke GPU tools or change driver settings."""
import os
import subprocess
from pathlib import Path
from .processes import read, number, scan, partition

def cpu_counters():
    values = [int(x) for x in read('/proc/stat').splitlines()[0].split()[1:9]]
    return sum(values), values[3]+values[4]

def memory():
    fields = {line.split(':')[0]:int(line.split()[1])*1024 for line in read('/proc/meminfo').splitlines()}
    return fields['MemTotal'], fields['MemTotal']-fields['MemAvailable']

class Sensors:
    def __init__(self):
        self.previous = None
        self.names = {}

    def devices(self):
        result = []
        for card in Path('/sys/class/drm').glob('card[0-9]*'):
            if '-' in card.name:
                continue
            device = card/'device'
            bus = device.resolve().name
            vendor, model = read(device/'vendor'), read(device/'device')
            key = f'gpu:{bus}:{vendor}:{model}'
            if key not in self.names:
                label = read(device/'product_name')
                if not label:
                    try:
                        label = subprocess.check_output(['lspci','-s',bus],text=True,timeout=2).strip().split(': ',1)[-1]
                    except (OSError, subprocess.SubprocessError):
                        label = card.name
                self.names[key] = label
            power = next((number(p,1e6) for p in (device/'hwmon').glob('hwmon*/power1_average')),None)
            result.append({'id':key,'bus':bus,'label':self.names[key],
                           'value':number(device/'gpu_busy_percent'), 'power':power})
        return result

    def sample(self, monotonic, registry=None):
        cpu = cpu_counters()
        total_ram, used_ram = memory()
        rows, clients, apps = scan(registry)
        devices = self.devices()
        current = (monotonic, cpu, rows, clients)
        previous, self.previous = self.previous, current
        if previous is None:
            return None
        elapsed = monotonic-previous[0]
        cpu_delta = cpu[0]-previous[1][0]
        if elapsed<=0 or cpu_delta<=0 or elapsed>45:
            return None
        busy = max(0,min(100,100*(1-(cpu[1]-previous[1][1])/cpu_delta)))
        cpu_apps, ram_apps = {}, {}
        for pid, row in rows.items():
            old = previous[2].get(pid)
            app = row['owner']
            if old and old['key']==row['key']:
                cpu_apps[app] = cpu_apps.get(app,0)+100*max(0,row['ticks']-old['ticks'])/cpu_delta
            ram_apps[app] = ram_apps.get(app,0)+100*row['pss']/total_ram
        metrics = {'cpu':{'value':busy,'apps':partition(busy,cpu_apps)},
                   'ram':{'value':100*used_ram/total_ram,'apps':partition(100*used_ram/total_ram,ram_apps)}}
        catalog = [{'id':'cpu','type':'cpu','label':'CPU','unit':'%','cores':os.cpu_count()},
                   {'id':'ram','type':'ram','label':'RAM','unit':'%','capacity':total_ram}]
        for device in devices:
            shares, fallback = {}, {}
            for key, client in clients.items():
                if key[0]!=device['bus']:
                    continue
                if client['compute'] and not client['engines'] and client['vram']>0:
                    fallback[client['owner']] = fallback.get(client['owner'],0)+client['vram']
                old = previous[3].get(key)
                if not old:
                    continue
                deltas = []
                for engine, count in client['engines'].items():
                    before = old['engines'].get(engine,count)
                    deltas.append(max(0,count-before))
                    # Driver counters may temporarily regress; preserve the high-water mark.
                    client['engines'][engine] = max(count,before)
                amount = max(deltas,default=0)/1e9/elapsed*100
                shares[client['owner']] = shares.get(client['owner'],0)+amount
            strict = partition(device['value'],shares)
            remaining = strict.get('unattributed',0)
            if fallback:
                total_vram = sum(fallback.values())
                for app,used in fallback.items():
                    shares[app] = shares.get(app,0)+remaining*used/total_vram
            metrics['measured:'+device['id']] = {'value':device['value'],'apps':strict}
            metrics[device['id']] = {'value':device['value'],'apps':partition(device['value'],shares)}
            catalog.append({'id':device['id'],'type':'gpu','label':device['label'],'unit':'%',
                            'attribution':'Engine time; ROCm fallback uses resident VRAM weights',
                            'supported':device['value'] is not None})
            power_id = 'power:'+device['id']
            metrics[power_id] = {'value':device['power']}
            catalog.append({'id':power_id,'type':'power','label':device['label']+' board power','unit':'W'})
        apps['unattributed'] = 'System / unattributed'
        catalog += [{'id':'app:'+key,'type':'app','label':label} for key,label in apps.items()]
        return elapsed, metrics, catalog, {'processes':len(rows),'gpu_clients':len(clients),
            'interval_seconds':15,'attribution':'GPU: estimated engine time; CPU: process counters; RAM: readable PSS. Unattributed includes protected processes and kernel/cache usage.'}
