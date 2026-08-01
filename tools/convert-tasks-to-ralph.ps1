param(
    [string]$InputPath = ".\TASKS.json",
    [string]$OutputPath = ".\.agents\tasks\prd-last-shift.json",
    [string]$MigrationBackupRef = "refs/backups/pre-ralph-s05b-20260801"
)

$ErrorActionPreference = "Stop"
$Tasks = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json
$BackupExists = git rev-parse --verify --quiet $MigrationBackupRef
$DirtyFiles = if ($BackupExists) {
    @(git diff --name-only "$MigrationBackupRef^1" $MigrationBackupRef)
}
else {
    @(git status --porcelain=v1 | ForEach-Object { $_.Substring(3) })
}
$Stories = foreach ($Story in $Tasks.stories) {
    $Allowed = @($Story.allowed_paths | Where-Object {
        $_ -notin @("TASKS.json", "PROGRESS.md")
    })
    if ($Story.status -in @("in_progress", "ready_for_validation")) {
        $Allowed += $DirtyFiles | Where-Object {
            $_ -notin @("TASKS.json", "PROGRESS.md")
        }
    }
    $Criteria = @($Story.acceptance_criteria | ForEach-Object {
        "$($_.id): $($_.text)"
    })
    [ordered]@{
        id = [string]$Story.id
        title = [string]$Story.title
        status = if ($Story.status -eq "done") { "done" } else { "open" }
        dependsOn = @($Story.dependencies)
        description = [string]$Story.objective
        acceptanceCriteria = $Criteria
        validationCommands = @($Story.validation)
        allowedPaths = @($Allowed | Select-Object -Unique)
    }
}
$Prd = [ordered]@{
    version = 1
    project = "LAST SHIFT"
    overview = "Complete the existing Godot action-platformer through bounded stories."
    goals = @("Finish every story", "Keep validation and Git history trustworthy")
    nonGoals = @("External assets or dependencies", "Work outside the selected story")
    successMetrics = @("Every story is done", "Global validation passes")
    openQuestions = @()
    stack = [ordered]@{ framework = "Godot 4.x"; language = "typed GDScript" }
    rules = @("One story per iteration", "Ralph owns PRD status", "Never edit TASKS.json")
    qualityGates = @("powershell -NoProfile -File .\tools\validate.ps1")
    stories = @($Stories)
}
$Directory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $Directory | Out-Null
$Json = $Prd | ConvertTo-Json -Depth 12
$AbsoluteOutput = [IO.Path]::GetFullPath($OutputPath)
[IO.File]::WriteAllText($AbsoluteOutput, $Json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
Write-Output "Wrote $($Stories.Count) stories to $OutputPath"
