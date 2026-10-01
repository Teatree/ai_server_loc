$ErrorActionPreference = 'Stop'
$pythonPath = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
$configPath = Join-Path $PSScriptRoot 'private\connector.json'
try {
    $health = Invoke-RestMethod 'http://127.0.0.1:32149/api/health' -TimeoutSec 2
    if ($health.service -eq 'usage-metrics') { Write-Host 'Usage Metrics is already running.'; return }
    throw 'Port 32149 belongs to another service.'
} catch {
    if (Get-NetTCPConnection -LocalPort 32149 -State Listen -ErrorAction SilentlyContinue) {
        throw 'Port 32149 is occupied. Existing processes were left untouched.'
    }
}
if (!(Test-Path -LiteralPath $pythonPath) -or !(Test-Path -LiteralPath $configPath)) {
    throw 'Configure the gateway and its Python environment first.'
}
$outPath = Join-Path $PSScriptRoot 'private\usage-metrics.out.log'
$errPath = Join-Path $PSScriptRoot 'private\usage-metrics.err.log'
Start-Process -FilePath $pythonPath -ArgumentList '-m','gateway.usage_bridge' -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -RedirectStandardOutput $outPath -RedirectStandardError $errPath | Out-Null
Write-Host 'Usage Metrics companion started. Existing AI apps and connector are unchanged.'
