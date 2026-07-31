param(
    [int]$StartupFrames = 120
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$logDir = Join-Path $root ".agent-logs"
New-Item -ItemType Directory -Force $logDir | Out-Null

function Find-GodotExecutable {
    $candidates = @(
        (Join-Path $root "godot.exe"),
        (Join-Path $root "Godot_v4.7.1-stable_win64.exe")
    )

    $versioned = Get-ChildItem $root -File -Filter "Godot_v*-stable_win64.exe" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -ExpandProperty FullName

    $candidates += $versioned

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }

    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw "Godot executable not found. Put godot.exe or Godot_v*-stable_win64.exe in the project root, or add godot to PATH."
}

function Invoke-GodotCheck {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    $logPath = Join-Path $logDir "$Name.log"
    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    Write-Host "$godot $($Arguments -join ' ')"

    $output = & $godot @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output | Tee-Object -FilePath $logPath | ForEach-Object { Write-Host $_ }

    $fatalPattern = "SCRIPT ERROR|Parse Error|Failed loading resource|Cannot open file|Invalid call|Invalid get index"
    $fatalLines = $output | Select-String -Pattern $fatalPattern

    if ($exitCode -ne 0) {
        throw "$Name failed with exit code $exitCode. See $logPath"
    }

    if ($fatalLines) {
        throw "$Name reported a likely script/resource error. See $logPath"
    }

    Write-Host "$Name passed." -ForegroundColor Green
}

Set-Location $root

if (-not (Test-Path (Join-Path $root "project.godot"))) {
    throw "project.godot is missing from $root"
}

$godot = Find-GodotExecutable
Write-Host "Project root: $root"
Write-Host "Godot: $godot"

Invoke-GodotCheck -Name "godot-import" -Arguments @(
    "--headless",
    "--path", $root,
    "--import"
)

Invoke-GodotCheck -Name "godot-startup" -Arguments @(
    "--headless",
    "--path", $root,
    "--quit-after", "$StartupFrames"
)

$testRunner = Join-Path $root "tests\run_tests.gd"
if (Test-Path $testRunner) {
    Invoke-GodotCheck -Name "godot-tests" -Arguments @(
        "--headless",
        "--path", $root,
        "--script", "res://tests/run_tests.gd"
    )
} else {
    Write-Host "`nNo tests\run_tests.gd found; automated logic tests skipped." -ForegroundColor Yellow
}

Write-Host "`nAll configured validation checks passed." -ForegroundColor Green
