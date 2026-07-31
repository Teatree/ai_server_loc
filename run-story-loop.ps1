param(
    [string]$ProjectRoot = (Get-Location).Path,

    [ValidateRange(1, 100)]
    [int]$MaxStories = 20,

    [ValidateRange(1, 10)]
    [int]$MaxPassesPerStory = 4,

    [string]$Model = "evox2/step-3.7-flash",

    [string]$Agent = "build"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path $ProjectRoot).Path
Set-Location $ProjectRoot

$tasksPath = Join-Path $ProjectRoot "TASKS.json"
$validatePath = Join-Path $ProjectRoot "tools\validate.ps1"
$logDirectory = Join-Path $ProjectRoot ".agent-logs"
$reportPath = Join-Path $logDirectory "overnight-loop-report.md"
$statusPath = Join-Path $logDirectory "overnight-loop-status.md"
$eventsPath = Join-Path $logDirectory "overnight-loop-events.jsonl"

if (-not (Test-Path $tasksPath)) {
    throw "TASKS.json was not found in: $ProjectRoot"
}

New-Item -ItemType Directory -Force $logDirectory | Out-Null

$runId = Get-Date -Format "yyyyMMdd-HHmmss"
$runStart = Get-Date
$script:CurrentStoryId = "none"
$script:CurrentStoryTitle = "none"
$script:CurrentPass = 0
$script:CompletedThisRun = 0
$script:StopReason = "Run is active."
$script:OpenCodeExe = $null

function Get-IsoTimestamp {
    (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
}

function Add-ReportText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    Add-Content -Path $reportPath -Value $Text -Encoding UTF8
}

function Add-Event {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Type,

        [hashtable]$Data = @{}
    )

    $event = [ordered]@{
        timestamp = Get-IsoTimestamp
        run_id = $runId
        type = $Type
        story_id = $script:CurrentStoryId
        story_title = $script:CurrentStoryTitle
        pass = $script:CurrentPass
        data = $Data
    }

    $event |
        ConvertTo-Json -Depth 10 -Compress |
        Add-Content -Path $eventsPath -Encoding UTF8
}

function Write-CurrentStatus {
    param(
        [string]$Phase,
        [string]$Detail = ""
    )

    $elapsed = New-TimeSpan -Start $runStart -End (Get-Date)

    $content = @"
# Overnight Loop Status

- **Updated:** $(Get-IsoTimestamp)
- **Run ID:** $runId
- **Phase:** $Phase
- **Current story:** $($script:CurrentStoryId) — $($script:CurrentStoryTitle)
- **Current pass:** $($script:CurrentPass)
- **Stories completed this run:** $($script:CompletedThisRun) / $MaxStories
- **Elapsed:** $([math]::Floor($elapsed.TotalHours))h $($elapsed.Minutes)m $($elapsed.Seconds)s
- **Model:** $Model
- **Stop reason / current detail:** $Detail

## Files to inspect

- Full human-readable report: `.agent-logs/overnight-loop-report.md`
- Machine-readable events: `.agent-logs/overnight-loop-events.jsonl`
- Per-pass OpenCode logs: `.agent-logs/*-opencode.log`
- Per-story validation logs: `.agent-logs/*-validation.log`
"@

    Set-Content -Path $statusPath -Value $content -Encoding UTF8
}

function Resolve-OpenCodeExecutable {
    $exeCommand = Get-Command "opencode.exe" -ErrorAction SilentlyContinue

    if ($exeCommand) {
        return $exeCommand.Source
    }

    $psWrapper = Get-Command "opencode.ps1" -ErrorAction SilentlyContinue

    if ($psWrapper) {
        $candidate = Join-Path `
            (Split-Path $psWrapper.Source) `
            "node_modules\opencode-ai\bin\opencode.exe"

        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    throw "Could not locate opencode.exe. Confirm that OpenCode is installed and available on PATH."
}

function Read-Tasks {
    Get-Content $tasksPath -Raw | ConvertFrom-Json
}

function Get-StoryById {
    param(
        [Parameter(Mandatory = $true)]
        $Tasks,

        [Parameter(Mandatory = $true)]
        [string]$StoryId
    )

    $Tasks.stories |
        Where-Object { $_.id -eq $StoryId } |
        Select-Object -First 1
}

function Test-DependenciesDone {
    param(
        [Parameter(Mandatory = $true)]
        $Story,

        [Parameter(Mandatory = $true)]
        [hashtable]$DoneIds
    )

    foreach ($dependency in @($Story.dependencies)) {
        if (-not $DoneIds.ContainsKey([string]$dependency)) {
            return $false
        }
    }

    return $true
}

function Get-NextStory {
    param(
        [Parameter(Mandatory = $true)]
        $Tasks
    )

    $inProgress = @(
        $Tasks.stories |
            Where-Object { $_.status -eq "in_progress" }
    )

    if ($inProgress.Count -gt 1) {
        throw "More than one story is in_progress: $($inProgress.id -join ', ')"
    }

    if ($inProgress.Count -eq 1) {
        return $inProgress[0]
    }

    $doneIds = @{}

    foreach ($story in $Tasks.stories) {
        if ($story.status -eq "done") {
            $doneIds[[string]$story.id] = $true
        }
    }

    $eligible = @()

    foreach ($story in $Tasks.stories) {
        if (
            $story.status -eq "open" -and
            (Test-DependenciesDone -Story $story -DoneIds $doneIds)
        ) {
            $eligible += $story
        }
    }

    return $eligible |
        Sort-Object `
            @{ Expression = { [int]$_.priority }; Ascending = $true },
            @{ Expression = { [string]$_.id }; Ascending = $true } |
        Select-Object -First 1
}

function Get-LogDiagnostics {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )

    $result = [ordered]@{
        context_or_token_issue = $false
        tool_or_json_issue = $false
        api_or_network_issue = $false
        memory_issue = $false
        matching_lines = @()
    }

    if (-not (Test-Path $LogPath)) {
        return $result
    }

    $patterns = [ordered]@{
        context_or_token_issue = @(
            "context window",
            "context length",
            "context limit",
            "maximum context",
            "too many tokens",
            "tokens exceeds",
            "exceeds the available context",
            "prompt is too long",
            "request too large"
        )
        tool_or_json_issue = @(
            "JSON Parse error",
            "Unterminated string",
            "invalid json",
            "malformed tool",
            "tool call.*parse"
        )
        api_or_network_issue = @(
            "socket closed",
            "cannot connect",
            "connection refused",
            "timed out",
            "timeout",
            "Invalid API Key",
            "unauthorized",
            "HTTP 401",
            "HTTP 403"
        )
        memory_issue = @(
            "out of memory",
            "allocation failed",
            "VK_ERROR_OUT_OF_DEVICE_MEMORY",
            "HIP.*memory",
            "\bOOM\b"
        )
    }

    $allMatches = @()

    foreach ($category in $patterns.Keys) {
        foreach ($pattern in $patterns[$category]) {
            $matches = @(
                Select-String `
                    -Path $LogPath `
                    -Pattern $pattern `
                    -CaseSensitive:$false `
                    -ErrorAction SilentlyContinue
            )

            if ($matches.Count -gt 0) {
                $result[$category] = $true

                foreach ($match in $matches) {
                    $allMatches += "$($match.LineNumber): $($match.Line.Trim())"
                }
            }
        }
    }

    $result.matching_lines = @(
        $allMatches |
            Select-Object -Unique |
            Select-Object -First 20
    )

    return $result
}

function Get-RecentLogLines {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath,

        [int]$Count = 20
    )

    if (-not (Test-Path $LogPath)) {
        return @("Log file was not created.")
    }

    return @(
        Get-Content $LogPath -Tail $Count -ErrorAction SilentlyContinue
    )
}

function Invoke-OpenCodePass {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StoryId,

        [Parameter(Mandatory = $true)]
        [int]$PassNumber
    )

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logPath = Join-Path `
        $logDirectory `
        "$timestamp-$StoryId-pass$PassNumber-opencode.log"

    $passStart = Get-Date

    Add-ReportText @"

## $(Get-IsoTimestamp) — $StoryId pass $PassNumber started

- Story: **$StoryId — $($script:CurrentStoryTitle)**
- Model: `$Model`
- Agent: `$Agent`
- Log: `$logPath`
"@

    Add-Event -Type "pass_started" -Data @{
        log_path = $logPath
        model = $Model
        agent = $Agent
    }

    Write-CurrentStatus `
        -Phase "OpenCode pass running" `
        -Detail "$StoryId pass $PassNumber is active. See $logPath."

    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Story $StoryId - fresh OpenCode pass $PassNumber" -ForegroundColor Cyan
    Write-Host "Log: $logPath"
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    $arguments = @(
        "run",
        "--command", "next-story",
        "--model", $Model,
        "--agent", $Agent,
        "--dir", $ProjectRoot,
        "--auto",
        $StoryId
    )

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        & $script:OpenCodeExe @arguments 2>&1 |
            ForEach-Object {
                $_ | Tee-Object -FilePath $logPath -Append
            }

        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }

    $passEnd = Get-Date
    $duration = New-TimeSpan -Start $passStart -End $passEnd
    $diagnostics = Get-LogDiagnostics -LogPath $logPath
    $recentLines = Get-RecentLogLines -LogPath $logPath -Count 20

    $diagnosticSummary = @()
    if ($diagnostics.context_or_token_issue) {
        $diagnosticSummary += "Possible context/token-limit issue detected."
    }
    if ($diagnostics.tool_or_json_issue) {
        $diagnosticSummary += "Possible tool-call or JSON truncation issue detected."
    }
    if ($diagnostics.api_or_network_issue) {
        $diagnosticSummary += "Possible API/network issue detected."
    }
    if ($diagnostics.memory_issue) {
        $diagnosticSummary += "Possible memory-allocation issue detected."
    }
    if ($diagnosticSummary.Count -eq 0) {
        $diagnosticSummary += "No known fatal-pattern diagnostic was detected in this pass log."
    }

    Add-ReportText @"

### Pass result

- Exit code: **$exitCode**
- Duration: $([math]::Floor($duration.TotalMinutes))m $($duration.Seconds)s
- Diagnostics:
$(
    ($diagnosticSummary | ForEach-Object { "  - $_" }) -join [Environment]::NewLine
)

### Matching diagnostic lines

$(
    if ($diagnostics.matching_lines.Count -gt 0) {
        ($diagnostics.matching_lines | ForEach-Object { "- `$_`" }) -join [Environment]::NewLine
    }
    else {
        "- None"
    }
)

### Last 20 log lines

```text
$($recentLines -join [Environment]::NewLine)
```
"@

    Add-Event -Type "pass_finished" -Data @{
        exit_code = $exitCode
        duration_seconds = [math]::Round($duration.TotalSeconds, 1)
        log_path = $logPath
        diagnostics = $diagnostics
    }

    return @{
        exit_code = $exitCode
        log_path = $logPath
        diagnostics = $diagnostics
    }
}

$initialReportHeader = @"
# Automatic OpenCode Overnight Loop Report

## Run $runId

- Started: $(Get-IsoTimestamp)
- Project: `$ProjectRoot`
- Model: `$Model`
- Agent: `$Agent`
- Maximum stories: $MaxStories
- Maximum fresh passes per story: $MaxPassesPerStory

This file is append-only for the duration of the run. The most recent state is
also written to `.agent-logs/overnight-loop-status.md`.
"@

Add-Content -Path $reportPath -Value $initialReportHeader -Encoding UTF8
Add-Event -Type "run_started" -Data @{
    project_root = $ProjectRoot
    model = $Model
    agent = $Agent
    max_stories = $MaxStories
    max_passes_per_story = $MaxPassesPerStory
}

try {
    $script:OpenCodeExe = Resolve-OpenCodeExecutable

    Write-CurrentStatus `
        -Phase "Starting" `
        -Detail "OpenCode executable resolved to $($script:OpenCodeExe)."

    Add-ReportText @"

## Environment

- OpenCode executable: `$($script:OpenCodeExe)`
- Starting Git commit: `$(git rev-parse HEAD)`
- Starting working-tree status:

```text
$((git status --short) -join [Environment]::NewLine)
```
"@

    Write-Host ""
    Write-Host "Automatic OpenCode overnight story loop" -ForegroundColor Cyan
    Write-Host "Project:              $ProjectRoot"
    Write-Host "OpenCode executable:  $script:OpenCodeExe"
    Write-Host "Model:                $Model"
    Write-Host "Maximum stories:      $MaxStories"
    Write-Host "Passes per story:     $MaxPassesPerStory"
    Write-Host "Current status:       $statusPath"
    Write-Host "Full report:          $reportPath"
    Write-Host ""

    while ($script:CompletedThisRun -lt $MaxStories) {
        $tasks = Read-Tasks
        $story = Get-NextStory -Tasks $tasks

        if (-not $story) {
            $script:StopReason = "No eligible stories remain."
            Add-ReportText @"

## Loop completed

- Time: $(Get-IsoTimestamp)
- Result: **No eligible stories remain**
"@
            Add-Event -Type "no_eligible_stories"
            Write-Host "No eligible stories remain. The loop is complete." -ForegroundColor Green
            break
        }

        $script:CurrentStoryId = [string]$story.id
        $script:CurrentStoryTitle = [string]$story.title
        $script:CurrentPass = 0

        $storyId = $script:CurrentStoryId
        $storyTitle = $script:CurrentStoryTitle
        $storyStartCommit = (git rev-parse HEAD).Trim()
        $storyFinished = $false

        Add-ReportText @"

# Story $storyId — $storyTitle

- Started: $(Get-IsoTimestamp)
- Starting commit: `$storyStartCommit`
- Starting status: `$([string]$story.status)`
"@

        Add-Event -Type "story_started" -Data @{
            starting_commit = $storyStartCommit
            starting_status = [string]$story.status
        }

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkGray
        Write-Host "Story: $storyId - $storyTitle" -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor DarkGray

        for ($pass = 1; $pass -le $MaxPassesPerStory; $pass++) {
            $script:CurrentPass = $pass

            $passResult = Invoke-OpenCodePass `
                -StoryId $storyId `
                -PassNumber $pass

            $exitCode = [int]$passResult.exit_code

            if ($exitCode -ne 0) {
                $script:StopReason = "OpenCode exited with code $exitCode during $storyId pass $pass."

                Add-ReportText @"

## LOOP STOPPED

- Time: $(Get-IsoTimestamp)
- Reason: **$($script:StopReason)**
- Pass log: `$($passResult.log_path)`
- Review the diagnostic section above and the full pass log.
"@

                Add-Event -Type "loop_stopped" -Data @{
                    reason = $script:StopReason
                    log_path = $passResult.log_path
                }

                Write-CurrentStatus `
                    -Phase "Stopped" `
                    -Detail $script:StopReason

                Write-Host $script:StopReason -ForegroundColor Red
                exit $exitCode
            }

            $updatedTasks = Read-Tasks
            $updatedStory = Get-StoryById `
                -Tasks $updatedTasks `
                -StoryId $storyId

            if (-not $updatedStory) {
                throw "Story $storyId disappeared from TASKS.json."
            }

            $status = [string]$updatedStory.status
            $workingTreeSnapshot = @(
                git status --short |
                    Select-Object -First 80
            )

            Add-ReportText @"

### State after pass $pass

- Story status: **$status**
- Git HEAD: `$(git rev-parse HEAD)`
- Working tree:

```text
$($workingTreeSnapshot -join [Environment]::NewLine)
```
"@

            Add-Event -Type "story_state_after_pass" -Data @{
                status = $status
                git_head = (git rev-parse HEAD).Trim()
                working_tree = $workingTreeSnapshot
            }

            Write-Host ""
            Write-Host "Status after pass $pass: $status"

            if ($status -eq "blocked") {
                $script:StopReason = "$storyId became blocked after pass $pass."

                Add-ReportText @"

## LOOP STOPPED

- Time: $(Get-IsoTimestamp)
- Reason: **$($script:StopReason)**
- Read the latest entry in `PROGRESS.md` and the pass log.
"@

                Add-Event -Type "loop_stopped" -Data @{
                    reason = $script:StopReason
                    log_path = $passResult.log_path
                }

                Write-CurrentStatus `
                    -Phase "Stopped" `
                    -Detail $script:StopReason

                Write-Host $script:StopReason -ForegroundColor Yellow
                exit 21
            }

            if ($status -eq "done") {
                $storyFinished = $true
                break
            }

            if ($status -notin @("open", "in_progress")) {
                $script:StopReason = "Unexpected story status '$status' for $storyId."

                Add-ReportText @"

## LOOP STOPPED

- Time: $(Get-IsoTimestamp)
- Reason: **$($script:StopReason)**
"@

                Add-Event -Type "loop_stopped" -Data @{
                    reason = $script:StopReason
                }

                Write-CurrentStatus `
                    -Phase "Stopped" `
                    -Detail $script:StopReason

                Write-Host $script:StopReason -ForegroundColor Red
                exit 22
            }

            if ($pass -lt $MaxPassesPerStory) {
                Write-Host "Story is not finished. Starting another fresh pass for the same story." -ForegroundColor Yellow

                Add-ReportText @"

The story remains `$status`. A fresh OpenCode pass will resume the same story.
"@
            }
        }

        if (-not $storyFinished) {
            $script:StopReason = "$storyId did not finish after $MaxPassesPerStory fresh passes."

            Add-ReportText @"

## LOOP STOPPED

- Time: $(Get-IsoTimestamp)
- Reason: **$($script:StopReason)**
- This commonly indicates that the story is too large, the context budget is too small,
  or the agent repeatedly failed to persist an actionable continuation.
"@

            Add-Event -Type "loop_stopped" -Data @{
                reason = $script:StopReason
            }

            Write-CurrentStatus `
                -Phase "Stopped" `
                -Detail $script:StopReason

            Write-Host $script:StopReason -ForegroundColor Yellow
            exit 23
        }

        $storyEndCommit = (git rev-parse HEAD).Trim()

        if ($storyEndCommit -eq $storyStartCommit) {
            $script:StopReason = "$storyId was marked done, but no Git commit was created."

            Add-ReportText @"

## LOOP STOPPED

- Time: $(Get-IsoTimestamp)
- Reason: **$($script:StopReason)**
"@

            Add-Event -Type "loop_stopped" -Data @{
                reason = $script:StopReason
            }

            Write-CurrentStatus `
                -Phase "Stopped" `
                -Detail $script:StopReason

            Write-Host $script:StopReason -ForegroundColor Red
            exit 24
        }

        $workingTreeChanges = @(git status --porcelain)

        if ($workingTreeChanges.Count -gt 0) {
            $script:StopReason = "$storyId was marked done, but uncommitted changes remain."

            Add-ReportText @"

## LOOP STOPPED

- Time: $(Get-IsoTimestamp)
- Reason: **$($script:StopReason)**
- Remaining changes:

```text
$($workingTreeChanges -join [Environment]::NewLine)
```
"@

            Add-Event -Type "loop_stopped" -Data @{
                reason = $script:StopReason
                working_tree = $workingTreeChanges
            }

            Write-CurrentStatus `
                -Phase "Stopped" `
                -Detail $script:StopReason

            Write-Host $script:StopReason -ForegroundColor Yellow
            exit 25
        }

        if (-not (Test-Path $validatePath)) {
            $script:StopReason = "Validation script not found: $validatePath"

            Add-ReportText @"

## LOOP STOPPED

- Time: $(Get-IsoTimestamp)
- Reason: **$($script:StopReason)**
"@

            Add-Event -Type "loop_stopped" -Data @{
                reason = $script:StopReason
            }

            Write-CurrentStatus `
                -Phase "Stopped" `
                -Detail $script:StopReason

            Write-Host $script:StopReason -ForegroundColor Red
            exit 26
        }

        $validationTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $validationLog = Join-Path `
            $logDirectory `
            "$validationTimestamp-$storyId-validation.log"

        Write-CurrentStatus `
            -Phase "Independent validation running" `
            -Detail "Validating completed story $storyId. Log: $validationLog"

        Write-Host ""
        Write-Host "Running independent Godot validation..." -ForegroundColor Cyan

        $oldPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        try {
            & powershell `
                -NoProfile `
                -ExecutionPolicy Bypass `
                -File $validatePath 2>&1 |
                ForEach-Object {
                    $_ | Tee-Object -FilePath $validationLog -Append
                }

            $validationExitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $oldPreference
        }

        $validationTail = Get-RecentLogLines `
            -LogPath $validationLog `
            -Count 30

        Add-ReportText @"

## Story completion check

- Ending commit: `$storyEndCommit`
- Commits created during story:

```text
$((git log --oneline "$storyStartCommit..$storyEndCommit") -join [Environment]::NewLine)
```

- Files changed during story:

```text
$((git diff --name-status "$storyStartCommit..$storyEndCommit") -join [Environment]::NewLine)
```

- Independent validation exit code: **$validationExitCode**
- Validation log: `$validationLog`

### Last 30 validation lines

```text
$($validationTail -join [Environment]::NewLine)
```
"@

        Add-Event -Type "validation_finished" -Data @{
            exit_code = $validationExitCode
            validation_log = $validationLog
            ending_commit = $storyEndCommit
        }

        if ($validationExitCode -ne 0) {
            $script:StopReason = "Independent validation failed for $storyId with exit code $validationExitCode."

            Add-ReportText @"

## LOOP STOPPED

- Time: $(Get-IsoTimestamp)
- Reason: **$($script:StopReason)**
- Validation log: `$validationLog`
"@

            Add-Event -Type "loop_stopped" -Data @{
                reason = $script:StopReason
                validation_log = $validationLog
            }

            Write-CurrentStatus `
                -Phase "Stopped" `
                -Detail $script:StopReason

            Write-Host $script:StopReason -ForegroundColor Red
            exit $validationExitCode
        }

        $script:CompletedThisRun++

        Add-ReportText @"

## Story result

- Result: **COMPLETED**
- Story: **$storyId — $storyTitle**
- Finished: $(Get-IsoTimestamp)
- Final commit: `$storyEndCommit`
- Independent validation: **PASS**
- Stories completed this run: $($script:CompletedThisRun) / $MaxStories
"@

        Add-Event -Type "story_completed" -Data @{
            ending_commit = $storyEndCommit
            stories_completed_this_run = $script:CompletedThisRun
        }

        Write-CurrentStatus `
            -Phase "Story completed" `
            -Detail "$storyId completed and independently validated. Selecting the next story."

        Write-Host ""
        Write-Host "Completed $storyId successfully." -ForegroundColor Green
        Write-Host "Stories completed this run: $($script:CompletedThisRun) of $MaxStories"
    }

    if ($script:CompletedThisRun -ge $MaxStories) {
        $script:StopReason = "Reached MaxStories=$MaxStories."

        Add-ReportText @"

## Loop limit reached

- Time: $(Get-IsoTimestamp)
- Result: **$($script:StopReason)**
"@

        Add-Event -Type "max_stories_reached" -Data @{
            max_stories = $MaxStories
        }
    }

    Write-CurrentStatus `
        -Phase "Finished" `
        -Detail $script:StopReason

    Add-Event -Type "run_finished" -Data @{
        reason = $script:StopReason
        stories_completed_this_run = $script:CompletedThisRun
    }

    Write-Host ""
    Write-Host "Automatic overnight story loop finished." -ForegroundColor Cyan
}
catch {
    $script:StopReason = "Unhandled PowerShell error: $($_.Exception.Message)"

    Add-ReportText @"

## LOOP CRASHED

- Time: $(Get-IsoTimestamp)
- Reason: **$($script:StopReason)**
- PowerShell position: `$($_.InvocationInfo.PositionMessage)`
- Script stack:

```text
$($_.ScriptStackTrace)
```
"@

    Add-Event -Type "loop_crashed" -Data @{
        reason = $script:StopReason
        position = $_.InvocationInfo.PositionMessage
        stack = $_.ScriptStackTrace
    }

    Write-CurrentStatus `
        -Phase "Crashed" `
        -Detail $script:StopReason

    throw
}
