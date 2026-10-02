"""One-time removal of exclusive-start rules, without starting/stopping apps."""
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

UNITS = ('ai-comfyui.service','ai-unsloth.service','ai-llama.service','ai-invokeai.service')
LOOP = '''    for other in llm comfy unsloth invoke ollama; do
      if [[ $other != "$name" ]]; then
        if [[ $other != ollama || $(active_state ollama) == active ]]; then
          stop_one "$other"
        fi
      fi
    done
'''

def launcher_policy(text):
    if LOOP not in text and 'for other in llm comfy' in text:
        raise ValueError('Unrecognized launcher. No changes applied.')
    return text.replace(LOOP,'').replace('Only one GPU workload is allowed to run at a time.',
        'Apps may run concurrently. Release models manually when memory is needed.')

def unit_policy(text):
    lines = []
    for line in text.splitlines(keepends=True):
        if line.startswith('Conflicts='):
            remaining = [unit for unit in line.split('=',1)[1].split() if unit not in UNITS]
            if remaining:
                lines.append('Conflicts='+' '.join(remaining)+'\n')
        else:
            lines.append(line)
    return ''.join(lines)

def main():
    home = Path.home()
    paths = [home/'.local/bin/ai-workload'] + [home/'.config/systemd/user'/u for u in UNITS]
    changes = [(p,(launcher_policy if p.name=='ai-workload' else unit_policy)(p.read_text())) for p in paths]
    backup = home/'.local/share/ai-model-control/backups'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup.mkdir(parents=True,exist_ok=False)
    for path, content in changes:
        if content==path.read_text():
            continue
        shutil.copy2(path,backup/path.name)
        temp = path.with_name(path.name+'.model-control.tmp')
        temp.write_text(content)
        temp.chmod(path.stat().st_mode)
        temp.replace(path)
        print('Updated',path.name)
    subprocess.run(['bash','-n',str(paths[0])],check=True)
    subprocess.run(['systemctl','--user','daemon-reload'],check=True)
    print('Service definitions reloaded. No start, stop, restart, or unload was issued.')

if __name__=='__main__':
    main()
