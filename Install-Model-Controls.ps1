param([string]$DashboardRoot = 'C:\AI\AI-Server-Control-Center')
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$pythonPath = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
$config = Get-Content -Raw (Join-Path $PSScriptRoot 'private\connector.json') | ConvertFrom-Json
$keyPath = [Environment]::ExpandEnvironmentVariables($config.ssh.key)
$target = $config.ssh.target
ssh -i $keyPath -o BatchMode=yes -o StrictHostKeyChecking=yes $target 'mkdir -p ~/.local/share/ai-model-control/model_control'
if ($LASTEXITCODE -ne 0) { throw 'Remote preparation failed' }
$files = @(Get-ChildItem (Join-Path $PSScriptRoot 'model_control') -Filter *.py | Select-Object -ExpandProperty FullName)
scp -i $keyPath -o BatchMode=yes -o StrictHostKeyChecking=yes @files ($target+':.local/share/ai-model-control/model_control/')
if ($LASTEXITCODE -ne 0) { throw 'Model control upload failed' }
ssh -i $keyPath -o BatchMode=yes -o StrictHostKeyChecking=yes $target 'cd ~/.local/share/ai-model-control && python3 -m model_control.install_policy'
if ($LASTEXITCODE -ne 0) { throw 'Concurrency policy update failed' }
& $pythonPath -m model_control.install_windows $DashboardRoot
if ($LASTEXITCODE -ne 0) { throw 'Dashboard UI installation failed' }
& (Join-Path $PSScriptRoot 'Start-Model-Controls.ps1')
Write-Host 'Installed. Refresh the dashboard. No running AI app was started, stopped, or restarted.'
