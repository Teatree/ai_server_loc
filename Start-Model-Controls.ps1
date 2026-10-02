$ErrorActionPreference = 'Stop'
$pythonPath = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
$configPath = Join-Path $PSScriptRoot 'private\connector.json'
try {
    $health = Invoke-RestMethod 'http://127.0.0.1:32150/api/health' -TimeoutSec 2
    if ($health.service -eq 'model-control') { Write-Host 'Model controls are already running.'; return }
} catch { }
if (Get-NetTCPConnection -LocalPort 32150 -State Listen -ErrorAction SilentlyContinue) {
    throw 'Port 32150 is occupied. Existing processes were left untouched.'
}
if (!(Test-Path -LiteralPath $pythonPath) -or !(Test-Path -LiteralPath $configPath)) {
    throw 'Configure the gateway and its Python environment first.'
}
$outPath = Join-Path $PSScriptRoot 'private\models.out.log'
$errPath = Join-Path $PSScriptRoot 'private\models.err.log'
Start-Process -FilePath $pythonPath -ArgumentList '-m','gateway.models_bridge' -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput $outPath -RedirectStandardError $errPath | Out-Null
Write-Host 'Model controls started. No AI workloads were changed.'
