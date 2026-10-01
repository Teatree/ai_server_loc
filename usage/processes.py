"""Local process inspection. Raw command lines never leave this module."""
import os
import re
import hashlib
from pathlib import Path, PurePosixPath

KNOWN = {'comfy': ('ComfyUI', ['comfyui']), 'unsloth': ('Unsloth', ['unsloth']),
         'ollama': ('Ollama', ['ollama']), 'openclaw': ('OpenClaw', ['openclaw']),
         'invoke': ('InvokeAI', ['invokeai']), 'llm': ('llama.cpp', ['llama-server','llama.cpp']),
         'openwebui': ('Open WebUI', ['open-webui','open_webui'])}

def read(path):
    try:
        return Path(path).read_text(errors='replace').strip()
    except OSError:
        return ''

def number(path, scale=1):
    try:
        return float(read(path)) / scale
    except ValueError:
        return None

def discovered_app(comm, directory):
    # Separate new Python/Node projects without retaining their absolute paths.
    project = PurePosixPath(directory)
    if (comm.startswith(('python','node','uvicorn','gunicorn','bun')) and
            project.is_absolute() and len(project.parts)>3 and
            project.parts[1] in ('home','opt','srv')):
        key = hashlib.sha256(directory.encode()).hexdigest()[:16]
        return 'project:'+key, project.name[:64]+' (discovered)'
    return 'process:'+re.sub(r'[^a-zA-Z0-9_.-]','_',comm), comm

def scan(registry=None):
    rules = dict(KNOWN)
    for item in registry or []:
        if re.fullmatch(r'[a-z0-9_-]{1,50}', item.get('id', '')):
            rules[item['id']] = (str(item['name'])[:80], item['patterns'][:12])
    rows, clients, names = {}, {}, {}
    for proc in Path('/proc').glob('[0-9]*'):
        try:
            fields = read(proc/'stat').rsplit(')', 1)[1].split()
            pid, parent = int(proc.name), int(fields[1])
            ticks, start = int(fields[11]) + int(fields[12]), int(fields[19])
            command = read(proc/'cmdline').split('\0')[:3]
            try:
                cwd = os.readlink(proc/'cwd')
            except OSError:
                cwd = ''
            signature = (' '.join(command) + ' ' + cwd + ' ' + read(proc/'cgroup')).lower()
            app = next((key for key, (_, patterns) in rules.items()
                        if any(str(p).lower() in signature for p in patterns if p)), None)
            comm = read(proc/'comm')[:64] or 'System'
            pss = next((int(line.split()[1])*1024 for line in read(proc/'smaps_rollup').splitlines()
                        if line.startswith('Pss:')), 0)
            rows[pid] = {'parent':parent, 'key':(pid,start), 'ticks':ticks,
                         'pss':pss, 'app':app, 'comm':comm, 'directory':cwd}
        except (OSError, IndexError, ValueError):
            continue
    def owner(pid, visited=None):
        visited = set() if visited is None else visited
        if pid not in rows or pid in visited or len(visited)>32:
            return None
        visited.add(pid)
        row = rows[pid]
        parent = owner(row['parent'], visited)
        return parent if parent and row['app'] in (None,'llm') else row['app'] or parent
    for pid, row in rows.items():
        app = owner(pid)
        if app:
            label = rules[app][0]
        else:
            app, label = discovered_app(row['comm'],row['directory'])
        row['owner'] = app
        names[app] = label
        inspect_clients(pid, app, clients)
    from .kfd import augment
    augment(rows,clients)
    return rows, clients, names

def inspect_clients(pid, app, clients):
    try:
        for fd in Path(f'/proc/{pid}/fd').iterdir():
            try:
                if not os.readlink(fd).startswith('/dev/dri/'):
                    continue
                fields = dict(line.split(':',1) for line in read(f'/proc/{pid}/fdinfo/{fd.name}').splitlines() if ':' in line)
                device = fields.get('drm-pdev','').strip()
                client = fields.get('drm-client-id','').strip()
                if not device or not client:
                    continue
                key = (device, client)
                engines = {k: int(v.strip().split()[0]) for k,v in fields.items()
                           if k.startswith('drm-engine-') and not k.startswith('drm-engine-capacity-')}
                memory = fields.get('drm-resident-vram','0').strip().split()
                units = {'KiB':1024,'MiB':1024**2,'GiB':1024**3}
                vram = int(memory[0])*units.get(memory[1] if len(memory)>1 else '',1)
                candidate = {'owner':app, 'pid':pid, 'engines':engines, 'vram':vram,
                    'compute':Path(f'/sys/class/kfd/kfd/proc/{pid}').exists()}
                # Shared FDs count once. Prefer identified applications to generic parents.
                if key not in clients or clients[key]['owner'].startswith(('process:','project:')):
                    clients[key] = candidate
            except (OSError, ValueError):
                continue
    except OSError:
        pass

def partition(total, contributions):
    if total is None:
        return {}
    contributions = {key:max(0,value) for key,value in contributions.items() if value>0}
    amount = sum(contributions.values())
    scale = min(1,total/amount) if amount else 1
    result = {key:value*scale for key,value in contributions.items()}
    result['unattributed'] = max(0,total-sum(result.values()))
    return result
