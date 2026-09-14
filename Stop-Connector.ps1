$ErrorActionPreference = 'Stop'
$configPath = Join-Path $PSScriptRoot 'private\connector.json'
$pythonPath = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
$connectorMatches = @(Get-CimInstance Win32_Process -Filter "name = 'python.exe'" | Where-Object {
    $_.ExecutablePath -eq $pythonPath -and
    $_.CommandLine -match 'gateway\.connector' -and
    $_.CommandLine -match [regex]::Escape($configPath)
})
if (-not $connectorMatches) { Write-Host 'This remote connector is not running.'; exit 0 }
foreach ($connectorProcess in $connectorMatches) {
    Stop-Process -Id $connectorProcess.ProcessId -ErrorAction SilentlyContinue
}
Write-Host 'Remote access disconnected. AI apps and the local dashboard were left running.'
