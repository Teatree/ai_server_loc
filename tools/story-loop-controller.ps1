param(
    [string]$ProjectRoot = (Get-Location).Path,
    [ValidateRange(0, 1000)][int]$MaxStories = 0,
    [ValidateRange(1, 50)][int]$HardPassLimit = 20,
    [ValidateRange(1, 10)][int]$MaxNoProgress = 3,
    [ValidateRange(1, 20)][int]$MaxTransientFailures = 5,
    [ValidateRange(1000, 1000000)][int]$MinimumContext = 250000,
    [string]$Model = "evox2/step-3.7-flash",
    [string]$Agent = "build",
    [switch]$PreflightOnly
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
Set-Location $ProjectRoot

$TasksPath = Join-Path $ProjectRoot "TASKS.json"
$ValidatePath = Join-Path $ProjectRoot "tools\validate.ps1"
$LogDirectory = Join-Path $ProjectRoot ".agent-logs"
$StateDirectory = Join-Path $ProjectRoot ".loop-state"
$StatePath = Join-Path $StateDirectory "active.json"
$StatusPath = Join-Path $LogDirectory "overnight-status.md"
$RunId = Get-Date -Format "yyyyMMdd-HHmmss"
$ReportPath = Join-Path $LogDirectory "overnight-report-$RunId.md"
$RunStarted = Get-Date

New-Item -ItemType Directory -Force $LogDirectory | Out-Null
New-Item -ItemType Directory -Force $StateDirectory | Out-Null

function Get-Timestamp {
    return (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

function Add-Report {
    param([string[]]$Lines)
    Add-Content -LiteralPath $ReportPath -Value $Lines -Encoding UTF8
}

function Read-Tasks {
    return (Get-Content -LiteralPath $TasksPath -Raw | ConvertFrom-Json)
}

function Get-StoryById {
    param($Tasks, [string]$StoryId)
    return $Tasks.stories | Where-Object id -eq $StoryId | Select-Object -First 1
}

function Get-ChangedFiles {
    return @(git status --porcelain=v1 | ForEach-Object { $_.Substring(3) })
}

function Get-TextHash {
    param([string]$Text)
    $Sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $Bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        return ([BitConverter]::ToString($Sha.ComputeHash($Bytes))).Replace("-", "")
    }
    finally {
        $Sha.Dispose()
    }
}

function Get-TreeFingerprint {
    $Status = (git status --porcelain=v1) -join "`n"
    $Diff = (git diff HEAD --stat) -join "`n"
    return Get-TextHash "$Status`n$Diff"
}

function Get-FailureState {
    $TestLog = Join-Path $LogDirectory "godot-tests.log"
    if (-not (Test-Path $TestLog)) {
        return [pscustomobject]@{ Count = -1; Lines = @(); Fingerprint = "none" }
    }
    $Lines = @(
        Get-Content $TestLog |
            Where-Object { $_ -match '^FAIL:|failed with exit code|Parse Error' } |
            Select-Object -Unique
    )
    return [pscustomobject]@{
        Count = $Lines.Count
        Lines = $Lines
        Fingerprint = Get-TextHash ($Lines -join "`n")
    }
}

function Write-ActiveState {
    param($State)
    $State.updated_at = Get-Timestamp
    $State | ConvertTo-Json -Depth 8 |
        Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Read-ActiveState {
    if (-not (Test-Path $StatePath)) { return $null }
    return Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
}

function Assert-TaskState {
    param($Tasks)
    $Active = @($Tasks.stories | Where-Object {
        $_.status -in @("in_progress", "ready_for_validation")
    })
    if ($Active.Count -gt 1) {
        throw "More than one active story: $($Active.id -join ', ')"
    }
    if ($Active.Count -eq 0 -and $Tasks.active_story_id) {
        throw "active_story_id is set but no story is active."
    }
    if ($Active.Count -eq 1 -and $Tasks.active_story_id -ne $Active[0].id) {
        throw "active_story_id does not match the active story."
    }
    $Ids = @($Tasks.stories.id)
    if (($Ids | Select-Object -Unique).Count -ne $Ids.Count) {
        throw "TASKS.json contains duplicate story IDs."
    }
    foreach ($Story in $Tasks.stories) {
        foreach ($Dependency in @($Story.dependencies)) {
            if ($Dependency -notin $Ids) {
                throw "$($Story.id) has missing dependency $Dependency."
            }
        }
    }
}

function Get-NextStory {
    param($Tasks)
    $Active = $Tasks.stories | Where-Object {
        $_.status -in @("in_progress", "ready_for_validation")
    } | Select-Object -First 1
    if ($Active) { return $Active }
    $Done = @{}
    $Tasks.stories | Where-Object status -eq "done" |
        ForEach-Object { $Done[[string]$_.id] = $true }
    return $Tasks.stories | Where-Object {
        if ($_.status -ne "open") { return $false }
        foreach ($Dependency in @($_.dependencies)) {
            if (-not $Done.ContainsKey([string]$Dependency)) { return $false }
        }
        return $true
    } | Sort-Object priority, id | Select-Object -First 1
}

function Assert-AllowedChanges {
    param($Story, [string[]]$ChangedFiles)
    if (-not $Story.allowed_paths -or $ChangedFiles.Count -eq 0) { return }
    foreach ($File in $ChangedFiles) {
        $Allowed = @($Story.allowed_paths | Where-Object { $File -like $_ })
        if ($Allowed.Count -eq 0) { throw "Changed file outside story scope: $File" }
    }
}

function Resolve-OpenCodeExe {
    $Command = Get-Command opencode.exe -ErrorAction SilentlyContinue
    if ($Command) { return $Command.Source }
    $Wrapper = Get-Command opencode.ps1 -ErrorAction SilentlyContinue
    if ($Wrapper) {
        $Candidate = Join-Path (Split-Path $Wrapper.Source) `
            "node_modules\opencode-ai\bin\opencode.exe"
        if (Test-Path $Candidate) { return (Resolve-Path $Candidate).Path }
    }
    throw "Could not locate opencode.exe."
}

function Assert-ModelContext {
    $ConfigPath = Join-Path $env:USERPROFILE ".config\opencode\opencode.json"
    if (-not (Test-Path $ConfigPath)) {
        Write-Warning "OpenCode config not found; model context could not be verified."
        return -1
    }
    $Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    $Parts = $Model.Split('/', 2)
    if ($Parts.Count -ne 2) { throw "Model must be provider/model." }
    $Provider = $Config.provider.($Parts[0])
    $ModelConfig = if ($Provider) { $Provider.models.($Parts[1]) } else { $null }
    if (-not $ModelConfig -or -not $ModelConfig.limit.context) {
        throw "No context limit found for $Model in OpenCode config."
    }
    $Context = [int]$ModelConfig.limit.context
    if ($Context -lt $MinimumContext) {
        throw "$Model context is $Context; at least $MinimumContext is required."
    }
    Write-Host "Verified model context: $Context"
    return $Context
}

function Get-Diagnostics {
    param([string]$LogPath)
    $Patterns = [ordered]@{
        ContextIssue = "context window|context length|prompt is too long|request too large"
        ToolIssue = "JSON Parse error|Unterminated string|invalid json|Invalid Tool"
        ApiIssue = "socket closed|connection refused|timed out|HTTP 401|HTTP 403"
        MemoryIssue = "out of memory|allocation failed|VK_ERROR_OUT_OF_DEVICE_MEMORY|\bOOM\b"
    }
    $Result = [ordered]@{ ContextIssue=$false; ToolIssue=$false; ApiIssue=$false; MemoryIssue=$false }
    foreach ($Name in $Patterns.Keys) {
        if (Select-String -Path $LogPath -Pattern $Patterns[$Name] -Quiet) {
            $Result[$Name] = $true
        }
    }
    $Result.Transient = $Result.ContextIssue -or $Result.ToolIssue -or `
        $Result.ApiIssue -or $Result.MemoryIssue
    return [pscustomobject]$Result
}

function Write-LoopStatus {
    param([string]$Phase, [string]$StoryId, [int]$Pass, [string]$Detail)
    $Elapsed = New-TimeSpan -Start $RunStarted -End (Get-Date)
    @(
        "# Overnight Loop Status", "",
        "- Updated: $(Get-Timestamp)", "- Phase: $Phase",
        "- Story: $StoryId", "- Pass: $Pass",
        "- Elapsed: $([math]::Floor($Elapsed.TotalHours))h $($Elapsed.Minutes)m",
        "- Detail: $Detail", "", "- Full report: $ReportPath",
        "- Active continuation: $StatePath"
    ) | Set-Content -LiteralPath $StatusPath -Encoding UTF8
}

function Invoke-OpenCodePass {
    param(
        [string]$OpenCodeExe,
        [string]$CommandName,
        [string]$StoryId,
        [int]$Pass
    )
    $Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $LogPath = Join-Path $LogDirectory "$Stamp-$StoryId-pass$Pass-opencode.log"
    $Arguments = @(
        "run", "--command", $CommandName,
        "--model", $Model, "--agent", $Agent,
        "--dir", $ProjectRoot, "--auto", $StoryId
    )
    $PreviousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $OpenCodeExe @Arguments 2>&1 | ForEach-Object {
            $Line = [string]$_
            Write-Host $Line
            Add-Content -LiteralPath $LogPath -Value $Line -Encoding UTF8
        }
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }
    $Diagnostics = Get-Diagnostics $LogPath
    $Tail = @(Get-Content $LogPath -Tail 30 -ErrorAction SilentlyContinue)
    Add-Report @(
        "", "## $(Get-Timestamp) - $StoryId pass $Pass",
        "", "- Command: $CommandName", "- Exit code: $ExitCode",
        "- Transient issue: $($Diagnostics.Transient)",
        "- Log: $LogPath", "", "~~~text"
    )
    Add-Report $Tail
    Add-Report @("~~~", "")
    return [pscustomobject]@{
        ExitCode = $ExitCode
        LogPath = $LogPath
        Diagnostics = $Diagnostics
    }
}

function Invoke-GlobalValidation {
    param([string]$StoryId)
    $Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $LogPath = Join-Path $LogDirectory "$Stamp-$StoryId-validation.log"
    & powershell -NoProfile -File $ValidatePath 2>&1 | ForEach-Object {
        $Line = [string]$_
        Write-Host $Line
        Add-Content -LiteralPath $LogPath -Value $Line -Encoding UTF8
    }
    return [pscustomobject]@{ ExitCode=$LASTEXITCODE; LogPath=$LogPath }
}

function Set-StoryStatus {
    param([string]$StoryId, [string]$Status)
    $Tasks = Read-Tasks
    $Story = Get-StoryById $Tasks $StoryId
    if (-not $Story) { throw "Unknown story $StoryId" }
    $Story.status = $Status
    if ($Status -in @("done", "blocked")) {
        $Tasks.active_story_id = $null
    }
    else {
        $Tasks.active_story_id = $StoryId
    }
    $Tasks | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath $TasksPath -Encoding UTF8
}

function Invoke-Finalizer {
    param([string]$OpenCodeExe, [string]$StoryId, [string]$StartCommit)
    $Result = Invoke-OpenCodePass $OpenCodeExe "finalize-story" $StoryId 0
    if ($Result.ExitCode -ne 0) { return $false }
    $Tasks = Read-Tasks
    $Story = Get-StoryById $Tasks $StoryId
    $Head = (git rev-parse HEAD).Trim()
    if ($Story.status -ne "done") { return $false }
    if ($Head -eq $StartCommit) { return $false }
    if (@(git status --porcelain).Count -gt 0) { return $false }
    return $true
}

function Initialize-ActiveState {
    param($Story)
    $Existing = Read-ActiveState
    if ($Existing -and $Existing.story_id -eq $Story.id) { return $Existing }
    $State = [pscustomobject]@{
        schema_version = 1
        story_id = [string]$Story.id
        pass = 0
        status = [string]$Story.status
        verified_criteria = @()
        failing_check = ""
        last_command = ""
        last_error = ""
        next_action = "Inspect the story and run its focused validation."
        changed_files = @()
        transient_issue = $false
        consecutive_no_progress = 0
        updated_at = Get-Timestamp
    }
    Write-ActiveState $State
    return $State
}

if (-not (Test-Path $TasksPath)) { throw "TASKS.json is missing." }
if (-not (Test-Path $ValidatePath)) { throw "tools\validate.ps1 is missing." }
if (-not (Test-Path ".\run-full-story-loop.cmd")) { throw "Loop launcher is missing." }
$VerifiedContext = Assert-ModelContext

$Tasks = Read-Tasks
Assert-TaskState $Tasks
$InitialStory = Get-NextStory $Tasks
$InitialChanges = @(Get-ChangedFiles)
if ($InitialChanges.Count -gt 0) {
    if (-not $InitialStory -or $InitialStory.status -eq "open") {
        throw "Refusing to start a new story from a dirty working tree."
    }
    Assert-AllowedChanges $InitialStory $InitialChanges
}

if ($PreflightOnly) {
    Write-Host "Loop preflight passed."
    if ($InitialStory) {
        Write-Host "Next story: $($InitialStory.id) - $($InitialStory.title)"
    }
    else {
        Write-Host "No eligible stories remain."
    }
    exit 0
}

$OpenCodeExe = Resolve-OpenCodeExe
$CompletedCount = 0
Add-Report @(
    "# Automatic OpenCode Loop Report", "",
    "- Run ID: $RunId", "- Started: $(Get-Timestamp)",
    "- Model: $Model", "- Hard pass limit: $HardPassLimit",
    "- Verified model context: $VerifiedContext",
    "- Consecutive no-progress limit: $MaxNoProgress",
    "- Transient failure limit: $MaxTransientFailures", ""
)

while ($MaxStories -eq 0 -or $CompletedCount -lt $MaxStories) {
    $Tasks = Read-Tasks
    Assert-TaskState $Tasks
    $Story = Get-NextStory $Tasks
    if (-not $Story) { break }

    $StoryId = [string]$Story.id
    $StartCommit = (git rev-parse HEAD).Trim()
    $State = Initialize-ActiveState $Story
    $NoProgress = [int]$State.consecutive_no_progress
    $TransientFailures = 0
    $PreviousTree = Get-TreeFingerprint
    $PreviousFailure = Get-FailureState
    $PreviousVerified = @($State.verified_criteria).Count
    $StoryDone = $false
    Add-Report @("", "# Story $StoryId - $($Story.title)", "")

    for ($Pass = 1; $Pass -le $HardPassLimit; $Pass++) {
        $State.pass = $Pass
        Write-ActiveState $State
        Write-LoopStatus "Running" $StoryId $Pass "Implementation pass running."
        $CommandName = if ($Pass -eq 1 -and $Story.status -eq "open") {
            "next-story"
        } else {
            "continue-story"
        }
        $Result = Invoke-OpenCodePass $OpenCodeExe $CommandName $StoryId $Pass
        $State = Read-ActiveState
        if (-not $State -or $State.story_id -ne $StoryId) {
            throw "Active loop state was removed or replaced during $StoryId."
        }

        if ($Result.Diagnostics.Transient) {
            $TransientFailures++
            $State.transient_issue = $true
            $State.last_error = "Transient tool, API, context, or memory failure."
            $State.next_action = "Retry the same focused action with smaller tool payloads."
            Write-ActiveState $State
            if ($TransientFailures -gt $MaxTransientFailures) {
                throw "Too many consecutive transient failures for $StoryId."
            }
            Write-LoopStatus "Retrying" $StoryId $Pass "Transient failure; pass not charged."
            continue
        }
        if ($Result.ExitCode -ne 0) {
            throw "OpenCode exited with code $($Result.ExitCode) for $StoryId."
        }
        $TransientFailures = 0
        $State.transient_issue = $false

        $UpdatedTasks = Read-Tasks
        Assert-TaskState $UpdatedTasks
        $UpdatedStory = Get-StoryById $UpdatedTasks $StoryId
        if (-not $UpdatedStory) { throw "Story $StoryId disappeared." }
        $Status = [string]$UpdatedStory.status

        if ($Status -eq "blocked") {
            Write-LoopStatus "Blocked" $StoryId $Pass "External blocker requires user action."
            Add-Report @("", "## Story blocked", "", "- Story: $StoryId")
            exit 21
        }
        if ($Status -eq "done") {
            throw "$StoryId was marked done before independent validation."
        }

        if ($Status -eq "ready_for_validation") {
            Write-LoopStatus "Validating" $StoryId $Pass "Independent global validation running."
            $Validation = Invoke-GlobalValidation $StoryId
            if ($Validation.ExitCode -ne 0) {
                Set-StoryStatus $StoryId "in_progress"
                $Failure = Get-FailureState
                $State.status = "in_progress"
                $State.failing_check = ($Failure.Lines -join " | ")
                $State.last_command = "tools\validate.ps1"
                $State.last_error = "Independent validation failed."
                $State.next_action = "Fix only the reported validation failure."
                $State.consecutive_no_progress = 0
                Write-ActiveState $State
                $PreviousFailure = $Failure
                $NoProgress = 0
                continue
            }

            $State.status = "ready_for_validation"
            $State.last_command = $Validation.LogPath
            $State.last_error = ""
            $State.next_action = "Finalize the independently validated story."
            Write-ActiveState $State
            Write-LoopStatus "Finalizing" $StoryId $Pass "Validation passed; final commit requested."
            if (-not (Invoke-Finalizer $OpenCodeExe $StoryId $StartCommit)) {
                throw "Finalization failed for validated story $StoryId."
            }
            Remove-Item -LiteralPath $StatePath -ErrorAction SilentlyContinue
            $CompletedCount++
            $StoryDone = $true
            Add-Report @(
                "", "## Story completed", "", "- Story: $StoryId",
                "- Commit: $((git rev-parse HEAD).Trim())",
                "- Independent validation: PASS"
            )
            break
        }

        if ($Status -ne "in_progress") {
            throw "Unexpected status '$Status' for $StoryId."
        }
        $ChangedFiles = @(Get-ChangedFiles)
        Assert-AllowedChanges $UpdatedStory $ChangedFiles
        $CurrentTree = Get-TreeFingerprint
        $CurrentFailure = Get-FailureState
        $CurrentVerified = @($State.verified_criteria).Count
        $MadeProgress = ($CurrentTree -ne $PreviousTree) -or `
            ($CurrentVerified -gt $PreviousVerified) -or `
            ($PreviousFailure.Count -ge 0 -and $CurrentFailure.Count -ge 0 -and `
                $CurrentFailure.Count -lt $PreviousFailure.Count)

        if ($MadeProgress) {
            $NoProgress = 0
        }
        else {
            $NoProgress++
        }
        $State.status = $Status
        $State.changed_files = $ChangedFiles
        $State.consecutive_no_progress = $NoProgress
        Write-ActiveState $State
        $PreviousTree = $CurrentTree
        $PreviousFailure = $CurrentFailure
        $PreviousVerified = $CurrentVerified

        if ($NoProgress -ge $MaxNoProgress) {
            Write-LoopStatus "Stopped" $StoryId $Pass `
                "$NoProgress consecutive passes made no measurable progress."
            Add-Report @(
                "", "## Loop stopped for stagnation", "",
                "- Story: $StoryId", "- Consecutive no-progress passes: $NoProgress",
                "- Next action: $($State.next_action)"
            )
            exit 22
        }
    }

    if (-not $StoryDone) {
        Write-LoopStatus "Stopped" $StoryId $HardPassLimit "Hard safety ceiling reached."
        exit 23
    }
}

Write-LoopStatus "Finished" "none" 0 "No eligible work remains or story limit reached."
Add-Report @("", "## Run finished", "", "- Completed stories: $CompletedCount")
