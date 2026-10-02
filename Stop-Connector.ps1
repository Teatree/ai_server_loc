$ErrorActionPreference = 'Stop'
$configPath = Join-Path $PSScriptRoot 'private\connector.json'
$pythonPath = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
$connectorMatches = @(Get-CimInstance Win32_Process -Filter "name = 'python.exe'" | Where-Object {
    $_.ExecutablePath -eq $pythonPath -and
    (($_.CommandLine -match 'gateway\.connector' -and
    $_.CommandLine -match [regex]::Escape($configPath)) -or
    $_.CommandLine -match '-m\s+gateway\.(?:usage_bridge|models_bridge)(?:\s|$)')
})
if (-not $connectorMatches) { Write-Host 'This remote connector is not running.'; exit 0 }
foreach ($connectorProcess in $connectorMatches) {
    Stop-Process -Id $connectorProcess.ProcessId -ErrorAction SilentlyContinue
}
Write-Host 'Remote access, Usage Metrics, and model controls disconnected. AI apps, Ubuntu recording, and the main local dashboard were left running.'
