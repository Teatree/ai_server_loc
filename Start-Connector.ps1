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
$existing = @(Get-CimInstance Win32_Process -Filter "name = 'python.exe'" | Where-Object {
    $_.ExecutablePath -eq $pythonPath -and $_.CommandLine -match 'gateway\.connector' -and
    $_.CommandLine -match [regex]::Escape($configPath)
})
if ($existing.Count) {
    Write-Host 'This connector is already running. Use Stop-Connector.ps1 before changing the app selection.'
    exit 0
}
Write-Host 'Connecting only. No AI apps will be started, stopped, or restarted.'
Write-Host 'Close this window or press Ctrl+C to cut remote access and leave AI jobs running.'
$connectorArgs = @('-m', 'gateway.connector', '--config', $configPath)
if ($Apps) { $connectorArgs += @('--apps', $Apps) }
& $pythonPath @connectorArgs
