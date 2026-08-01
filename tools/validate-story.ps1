param(
    [Parameter(Mandatory = $true)]
    [string]$StoryId
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$TasksPath = Join-Path $Root "TASKS.json"
$Tasks = Get-Content -LiteralPath $TasksPath -Raw | ConvertFrom-Json
$Story = $Tasks.stories | Where-Object id -eq $StoryId | Select-Object -First 1

if (-not $Story) {
    throw "Unknown story ID: $StoryId"
}

Write-Host "Focused validation for $StoryId - $($Story.title)"
Write-Host "Acceptance criteria: $(@($Story.acceptance_criteria).Count)"

& powershell -NoProfile -File (Join-Path $PSScriptRoot "validate.ps1") -TestsOnly
$ExitCode = $LASTEXITCODE

if ($ExitCode -ne 0) {
    throw "Focused validation failed for $StoryId with exit code $ExitCode."
}

Write-Host "Focused validation passed for $StoryId."
