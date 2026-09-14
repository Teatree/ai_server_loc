param([string]$Apps = '')
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$pythonPath = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
$configPath = Join-Path $PSScriptRoot 'private\connector.json'
if (-not (Test-Path -LiteralPath $pythonPath)) {
    throw 'Run python -m venv .venv, then .\.venv\Scripts\python.exe -m pip install -r requirements.txt'
}
if (-not (Test-Path -LiteralPath $configPath)) {
    throw 'Run setup.py --prefix YOUR-UNIQUE-PREFIX first, then configure Render.'
}
Write-Host 'Connecting only. No AI apps will be started, stopped, or restarted.'
Write-Host 'Close this window or press Ctrl+C to cut remote access and leave AI jobs running.'
$connectorArgs = @('-m', 'gateway.connector', '--config', $configPath)
if ($Apps) { $connectorArgs += @('--apps', $Apps) }
& $pythonPath @connectorArgs
