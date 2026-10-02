"""Install static UI and launcher hooks without restarting the dashboard."""
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from .install_policy import launcher_policy, unit_policy

def install(destination):
    root = Path(__file__).resolve().parent.parent
    web = destination/'web'
    if not (web/'index.html').is_file():
        raise ValueError('Existing dashboard web/index.html is required')
    backup = root/'private'/('models-backup-'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
    def write(path, content):
        if path.exists() and path.read_text(encoding='utf-8-sig')==content:
            return
        if path.exists():
            target = backup/path.relative_to(destination)
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(path,target)
        path.write_text(content,encoding='utf-8')
    for name in ('models.js','models.css'):
        write(web/name,(root/'web'/name).read_text(encoding='utf-8'))
    index = (web/'index.html').read_text(encoding='utf-8-sig')
    if 'src="models.js' not in index:
        index = index.replace('</body>','  <link rel="stylesheet" href="models.css?v=1">\n  <script src="models.js?v=1"></script>\n</body>')
    write(web/'index.html',index)
    app = (web/'app.js').read_text(encoding='utf-8-sig')
    app = ''.join(line for line in app.splitlines(keepends=True)
                  if 'if (data.conflict) warnings.push' not in line and 'const conflictNames =' not in line)
    write(web/'app.js',app)
    commands = web/'commands.html'
    if commands.exists():
        content = commands.read_text(encoding='utf-8-sig').replace(
            'Starting one heavy workload stops the other GPU workloads first.',
            'Apps may run together. Use Loaded models on the dashboard to release memory manually.')
        write(commands,content)
    launcher = destination/'Launch-AI-Server-Control-Center.ps1'
    content = launcher.read_text(encoding='utf-8-sig')
    if 'Start-Model-Controls.ps1' not in content:
        script = str(root/'Start-Model-Controls.ps1').replace("'","''")
        content += f"\ntry {{ & '{script}' }}\ncatch {{ Write-Warning \"Model controls could not start: $_\" }}\n"
    write(launcher,content)
    for path in (destination/'remote').glob('*'):
        if path.name=='ai-workload':
            write(path,launcher_policy(path.read_text(encoding='utf-8-sig')))
        elif path.name in {'ai-comfyui.service','ai-unsloth.service','ai-llama.service','ai-invokeai.service'}:
            write(path,unit_policy(path.read_text(encoding='utf-8-sig')))

if __name__=='__main__':
    install(Path(sys.argv[1]))
