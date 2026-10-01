"""Public AMD KFD accounting covers compute clients owned by other Unix users."""
from pathlib import Path
from .processes import read

def augment(rows, clients, sysroot=Path('/sys')):
    devices = {}
    for node in (sysroot/'class/kfd/kfd/topology/nodes').glob('*'):
        try:
            gpu = read(node/'gpu_id')
            props = dict(line.split(None,1) for line in read(node/'properties').splitlines())
            minor = int(props['drm_render_minor'])
            device = sysroot/f'class/drm/renderD{minor}/device'
            if gpu!='0' and device.exists():
                devices[gpu] = device.resolve().name
        except (ValueError,KeyError,OSError):
            continue
    for process in (sysroot/'class/kfd/kfd/proc').glob('[0-9]*'):
        pid = int(process.name)
        for allocation in process.glob('vram_*'):
            bus = devices.get(allocation.name.removeprefix('vram_'))
            if not bus:
                continue
            try:
                used = int(read(allocation))
            except ValueError:
                continue
            matching = [key for key,c in clients.items() if key[0]==bus and c.get('pid')==pid]
            if any(clients[key]['engines'] for key in matching):
                continue
            # KFD reports a process/device total: replace DRM aliases, don't add both.
            for key in matching:
                del clients[key]
            clients[(bus,'kfd:'+str(pid))] = {
                'owner':rows.get(pid,{}).get('owner','unattributed'), 'pid':pid,
                'engines':{}, 'vram':max(0,used), 'compute':True, 'source':'kfd'}
