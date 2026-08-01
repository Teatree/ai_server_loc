param(
    [Parameter(Mandatory)][string]$PrdPath,
    [Parameter(Mandatory)][string]$StoryId,
    [string]$StartCommit = ""
)

$ErrorActionPreference = "Stop"
$Prd = Get-Content -LiteralPath $PrdPath -Raw | ConvertFrom-Json
$Story = $Prd.stories | Where-Object id -eq $StoryId | Select-Object -First 1
if (-not $Story) { throw "Story $StoryId is missing from $PrdPath." }

$Changed = @(git status --porcelain=v1 | ForEach-Object { $_.Substring(3) })
if ($StartCommit) {
    $Changed += @(git diff --name-only $StartCommit HEAD)
}
$Changed = @($Changed | Select-Object -Unique)
foreach ($File in $Changed) {
    $Allowed = @($Story.allowedPaths | Where-Object { $File -like $_ })
    if ($Allowed.Count -eq 0) {
        throw "Changed file outside ${StoryId} scope: $File"
    }
}

$Commands = @($Story.validationCommands) + @($Prd.qualityGates)
foreach ($Command in $Commands | Select-Object -Unique) {
    if (-not $Command) { continue }
    Write-Host "Ralph gate: $Command"
    Invoke-Expression $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Ralph gate failed with exit code ${LASTEXITCODE}: $Command"
    }
}

git diff --check
if ($LASTEXITCODE -ne 0) { throw "git diff --check failed." }
Write-Host "Ralph completion gate passed for $StoryId."
