param(
    [string]$ProjectRoot = (Get-Location).Path,
    [ValidateRange(1, 100)][int]$MaxStories = 20,
    [ValidateRange(1, 10)][int]$MaxPassesPerStory = 6,
    [string]$Model = "evox2/step-3.7-flash",
    [string]$Agent = "build"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path $ProjectRoot).Path
Set-Location $ProjectRoot

$TasksPath = Join-Path $ProjectRoot "TASKS.json"
$ValidatePath = Join-Path $ProjectRoot "tools\validate.ps1"
$LogDirectory = Join-Path $ProjectRoot ".agent-logs"

if (-not (Test-Path $TasksPath)) {
    throw ("TASKS.json not found in {0}" -f $ProjectRoot)
}

New-Item -ItemType Directory -Force $LogDirectory | Out-Null

$RunId = Get-Date -Format "yyyyMMdd-HHmmss"
$RunStarted = Get-Date
$ReportPath = Join-Path $LogDirectory ("overnight-report-{0}.md" -f $RunId)
$StatusPath = Join-Path $LogDirectory "overnight-status.md"

function Get-Timestamp {
    return (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

function Add-Report {
    param([string[]]$Lines)

    foreach ($Line in $Lines) {
        Add-Content -Path $ReportPath -Value $Line -Encoding UTF8
    }
}

function Write-LoopStatus {
    param(
        [string]$Phase,
        [string]$StoryId,
        [string]$StoryTitle,
        [int]$PassNumber,
        [int]$CompletedCount,
        [string]$Detail
    )

    $Elapsed = New-TimeSpan -Start $RunStarted -End (Get-Date)

    $Lines = @(
        "# Overnight Loop Status",
        "",
        ("- Updated: {0}" -f (Get-Timestamp)),
        ("- Phase: {0}" -f $Phase),
        ("- Story: {0} - {1}" -f $StoryId, $StoryTitle),
        ("- Pass: {0}" -f $PassNumber),
        ("- Stories completed this run: {0} / {1}" -f $CompletedCount, $MaxStories),
        ("- Elapsed: {0}h {1}m {2}s" -f [math]::Floor($Elapsed.TotalHours), $Elapsed.Minutes, $Elapsed.Seconds),
        ("- Detail: {0}" -f $Detail),
        "",
        ("- Full report: {0}" -f $ReportPath),
        "- Per-pass logs: .agent-logs/*-opencode.log",
        "- Validation logs: .agent-logs/*-validation.log"
    )

    Set-Content -Path $StatusPath -Value $Lines -Encoding UTF8
}

function Resolve-OpenCodeExe {
    $Command = Get-Command "opencode.exe" -ErrorAction SilentlyContinue

    if ($Command) {
        return $Command.Source
    }

    $Wrapper = Get-Command "opencode.ps1" -ErrorAction SilentlyContinue

    if ($Wrapper) {
        $Candidate = Join-Path `
            (Split-Path $Wrapper.Source) `
            "node_modules\opencode-ai\bin\opencode.exe"

        if (Test-Path $Candidate) {
            return (Resolve-Path $Candidate).Path
        }
    }

    throw "Could not locate opencode.exe."
}

function Read-Tasks {
    return (Get-Content $TasksPath -Raw | ConvertFrom-Json)
}

function Get-StoryById {
    param(
        $Tasks,
        [string]$StoryId
    )

    return (
        $Tasks.stories |
            Where-Object { $_.id -eq $StoryId } |
            Select-Object -First 1
    )
}

function Get-NextStory {
    param($Tasks)

    $InProgress = @(
        $Tasks.stories |
            Where-Object { $_.status -eq "in_progress" }
    )

    if ($InProgress.Count -gt 1) {
        throw ("More than one story is in_progress: {0}" -f ($InProgress.id -join ", "))
    }

    if ($InProgress.Count -eq 1) {
        return $InProgress[0]
    }

    $DoneIds = @{}

    foreach ($Story in $Tasks.stories) {
        if ($Story.status -eq "done") {
            $DoneIds[[string]$Story.id] = $true
        }
    }

    $Eligible = @()

    foreach ($Story in $Tasks.stories) {
        if ($Story.status -ne "open") {
            continue
        }

        $DependenciesDone = $true

        foreach ($Dependency in @($Story.dependencies)) {
            if (-not $DoneIds.ContainsKey([string]$Dependency)) {
                $DependenciesDone = $false
                break
            }
        }

        if ($DependenciesDone) {
            $Eligible += $Story
        }
    }

    return (
        $Eligible |
            Sort-Object `
                @{ Expression = { [int]$_.priority }; Ascending = $true },
                @{ Expression = { [string]$_.id }; Ascending = $true } |
            Select-Object -First 1
    )
}

function Get-Diagnostics {
    param([string]$LogPath)

    $Result = [ordered]@{
        ContextIssue = $false
        JsonOrToolIssue = $false
        ApiIssue = $false
        MemoryIssue = $false
        Lines = @()
    }

    if (-not (Test-Path $LogPath)) {
        return [pscustomobject]$Result
    }

    $Patterns = [ordered]@{
        ContextIssue = "context window|context length|context limit|too many tokens|prompt is too long|request too large|exceeds.*context"
        JsonOrToolIssue = "JSON Parse error|Unterminated string|invalid json|malformed tool|tool call.*parse"
        ApiIssue = "socket closed|cannot connect|connection refused|timed out|timeout|Invalid API Key|unauthorized|HTTP 401|HTTP 403"
        MemoryIssue = "out of memory|allocation failed|VK_ERROR_OUT_OF_DEVICE_MEMORY|HIP.*memory|\bOOM\b"
    }

    $FoundLines = @()

    foreach ($Name in $Patterns.Keys) {
        $Matches = @(
            Select-String `
                -Path $LogPath `
                -Pattern $Patterns[$Name] `
                -CaseSensitive:$false `
                -ErrorAction SilentlyContinue
        )

        if ($Matches.Count -gt 0) {
            $Result[$Name] = $true

            foreach ($Match in $Matches) {
                $FoundLines += ("{0}: {1}" -f $Match.LineNumber, $Match.Line.Trim())
            }
        }
    }

    $Result.Lines = @(
        $FoundLines |
            Select-Object -Unique |
            Select-Object -First 20
    )

    return [pscustomobject]$Result
}

function Invoke-OpenCodePass {
    param(
        [string]$OpenCodeExe,
        [string]$StoryId,
        [int]$PassNumber
    )

    $Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $LogPath = Join-Path `
        $LogDirectory `
        ("{0}-{1}-pass{2}-opencode.log" -f $Stamp, $StoryId, $PassNumber)

    $Arguments = @(
        "run",
        "--command", "next-story",
        "--model", $Model,
        "--agent", $Agent,
        "--dir", $ProjectRoot,
        "--auto",
        $StoryId
    )

    $Started = Get-Date

    $PreviousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        & $OpenCodeExe @Arguments 2>&1 |
            ForEach-Object {
                $Line = [string]$_
                Write-Host $Line
                Add-Content -Path $LogPath -Value $Line -Encoding UTF8
            }

        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    $Duration = New-TimeSpan -Start $Started -End (Get-Date)
    $Diagnostics = Get-Diagnostics -LogPath $LogPath
    $Tail = @(
        Get-Content $LogPath -Tail 20 -ErrorAction SilentlyContinue
    )

    Add-Report -Lines @(
        "",
        ("## {0} - {1} pass {2}" -f (Get-Timestamp), $StoryId, $PassNumber),
        "",
        ("- Exit code: {0}" -f $ExitCode),
        ("- Duration: {0}m {1}s" -f [math]::Floor($Duration.TotalMinutes), $Duration.Seconds),
        ("- Context/token issue detected: {0}" -f $Diagnostics.ContextIssue),
        ("- JSON/tool issue detected: {0}" -f $Diagnostics.JsonOrToolIssue),
        ("- API/network issue detected: {0}" -f $Diagnostics.ApiIssue),
        ("- Memory issue detected: {0}" -f $Diagnostics.MemoryIssue),
        ("- Full pass log: {0}" -f $LogPath),
        "",
        "### Diagnostic matches"
    )

    if ($Diagnostics.Lines.Count -eq 0) {
        Add-Report -Lines @("- None")
    }
    else {
        foreach ($DiagnosticLine in $Diagnostics.Lines) {
            Add-Report -Lines @("- " + $DiagnosticLine)
        }
    }

    Add-Report -Lines @(
        "",
        "### Last 20 output lines",
        "",
        "~~~text"
    )

    if ($Tail.Count -eq 0) {
        Add-Report -Lines @("(no output)")
    }
    else {
        Add-Report -Lines $Tail
    }

    Add-Report -Lines @(
        "~~~",
        ""
    )

    return [pscustomobject]@{
        ExitCode = $ExitCode
        LogPath = $LogPath
        Diagnostics = $Diagnostics
    }
}

$OpenCodeExe = Resolve-OpenCodeExe
$CompletedCount = 0
$FinalReason = "Run active."

Add-Report -Lines @(
    "# Automatic OpenCode Overnight Report",
    "",
    ("- Run ID: {0}" -f $RunId),
    ("- Started: {0}" -f (Get-Timestamp)),
    ("- Project: {0}" -f $ProjectRoot),
    ("- Model: {0}" -f $Model),
    ("- Maximum stories: {0}" -f $MaxStories),
    ("- Maximum passes per story: {0}" -f $MaxPassesPerStory),
    ("- OpenCode executable: {0}" -f $OpenCodeExe),
    ""
)

Write-LoopStatus `
    -Phase "Starting" `
    -StoryId "none" `
    -StoryTitle "none" `
    -PassNumber 0 `
    -CompletedCount 0 `
    -Detail "Loop initialization completed."

try {
    while ($CompletedCount -lt $MaxStories) {
        $Tasks = Read-Tasks
        $Story = Get-NextStory -Tasks $Tasks

        if (-not $Story) {
            $FinalReason = "No eligible stories remain."
            Add-Report -Lines @(
                "",
                "## Loop completed",
                "",
                ("- Time: {0}" -f (Get-Timestamp)),
                ("- Reason: {0}" -f $FinalReason)
            )
            break
        }

        $StoryId = [string]$Story.id
        $StoryTitle = [string]$Story.title
        $StartCommit = (git rev-parse HEAD).Trim()
        $StoryDone = $false

        Add-Report -Lines @(
            "",
            ("# Story {0} - {1}" -f $StoryId, $StoryTitle),
            "",
            ("- Started: {0}" -f (Get-Timestamp)),
            ("- Starting status: {0}" -f [string]$Story.status),
            ("- Starting commit: {0}" -f $StartCommit)
        )

        for ($Pass = 1; $Pass -le $MaxPassesPerStory; $Pass++) {
            Write-LoopStatus `
                -Phase "OpenCode pass running" `
                -StoryId $StoryId `
                -StoryTitle $StoryTitle `
                -PassNumber $Pass `
                -CompletedCount $CompletedCount `
                -Detail ("Running fresh pass {0} of {1}." -f $Pass, $MaxPassesPerStory)

            $PassResult = Invoke-OpenCodePass `
                -OpenCodeExe $OpenCodeExe `
                -StoryId $StoryId `
                -PassNumber $Pass

            if ($PassResult.ExitCode -ne 0) {
                $FinalReason = (
                    "OpenCode exited with code {0} during {1} pass {2}." -f
                    $PassResult.ExitCode,
                    $StoryId,
                    $Pass
                )

                Add-Report -Lines @(
                    "",
                    "## LOOP STOPPED",
                    "",
                    ("- Time: {0}" -f (Get-Timestamp)),
                    ("- Reason: {0}" -f $FinalReason),
                    ("- Log: {0}" -f $PassResult.LogPath)
                )

                Write-LoopStatus `
                    -Phase "Stopped" `
                    -StoryId $StoryId `
                    -StoryTitle $StoryTitle `
                    -PassNumber $Pass `
                    -CompletedCount $CompletedCount `
                    -Detail $FinalReason

                exit $PassResult.ExitCode
            }

            $UpdatedTasks = Read-Tasks
            $UpdatedStory = Get-StoryById `
                -Tasks $UpdatedTasks `
                -StoryId $StoryId

            if (-not $UpdatedStory) {
                throw ("Story {0} disappeared from TASKS.json." -f $StoryId)
            }

            $Status = [string]$UpdatedStory.status
            $Head = (git rev-parse HEAD).Trim()
            $WorkingTree = @(git status --short)

            Add-Report -Lines @(
                "",
                ("### State after pass {0}" -f $Pass),
                "",
                ("- Story status: {0}" -f $Status),
                ("- Git HEAD: {0}" -f $Head),
                "- Working tree:",
                "",
                "~~~text"
            )

            if ($WorkingTree.Count -eq 0) {
                Add-Report -Lines @("(clean)")
            }
            else {
                Add-Report -Lines $WorkingTree
            }

            Add-Report -Lines @(
                "~~~",
                ""
            )

            if ($Status -eq "done") {
                $StoryDone = $true
                break
            }

            if ($Status -eq "blocked") {
                $FinalReason = (
                    "Story {0} became blocked after pass {1}." -f
                    $StoryId,
                    $Pass
                )

                Add-Report -Lines @(
                    "",
                    "## LOOP STOPPED",
                    "",
                    ("- Time: {0}" -f (Get-Timestamp)),
                    ("- Reason: {0}" -f $FinalReason)
                )

                Write-LoopStatus `
                    -Phase "Stopped" `
                    -StoryId $StoryId `
                    -StoryTitle $StoryTitle `
                    -PassNumber $Pass `
                    -CompletedCount $CompletedCount `
                    -Detail $FinalReason

                exit 21
            }

            if ($Status -notin @("open", "in_progress")) {
                throw ("Unexpected status '{0}' for story {1}." -f $Status, $StoryId)
            }
        }

        if (-not $StoryDone) {
            $FinalReason = (
                "Story {0} did not finish after {1} fresh passes." -f
                $StoryId,
                $MaxPassesPerStory
            )

            Add-Report -Lines @(
                "",
                "## LOOP STOPPED",
                "",
                ("- Time: {0}" -f (Get-Timestamp)),
                ("- Reason: {0}" -f $FinalReason),
                "- Possible causes: story too large, context too small, repeated tool failure, or weak continuation notes."
            )

            Write-LoopStatus `
                -Phase "Stopped" `
                -StoryId $StoryId `
                -StoryTitle $StoryTitle `
                -PassNumber $MaxPassesPerStory `
                -CompletedCount $CompletedCount `
                -Detail $FinalReason

            exit 22
        }

        $EndCommit = (git rev-parse HEAD).Trim()

        if ($EndCommit -eq $StartCommit) {
            $FinalReason = (
                "Story {0} was marked done but no commit was created." -f
                $StoryId
            )

            Add-Report -Lines @(
                "",
                "## LOOP STOPPED",
                "",
                ("- Time: {0}" -f (Get-Timestamp)),
                ("- Reason: {0}" -f $FinalReason)
            )

            Write-LoopStatus `
                -Phase "Stopped" `
                -StoryId $StoryId `
                -StoryTitle $StoryTitle `
                -PassNumber 0 `
                -CompletedCount $CompletedCount `
                -Detail $FinalReason

            exit 23
        }

        $RemainingChanges = @(git status --porcelain)

        if ($RemainingChanges.Count -gt 0) {
            $FinalReason = (
                "Story {0} was marked done but uncommitted changes remain." -f
                $StoryId
            )

            Add-Report -Lines @(
                "",
                "## LOOP STOPPED",
                "",
                ("- Time: {0}" -f (Get-Timestamp)),
                ("- Reason: {0}" -f $FinalReason),
                "- Remaining changes:",
                "",
                "~~~text"
            )

            Add-Report -Lines $RemainingChanges

            Add-Report -Lines @(
                "~~~",
                ""
            )

            Write-LoopStatus `
                -Phase "Stopped" `
                -StoryId $StoryId `
                -StoryTitle $StoryTitle `
                -PassNumber 0 `
                -CompletedCount $CompletedCount `
                -Detail $FinalReason

            exit 24
        }

        if (-not (Test-Path $ValidatePath)) {
            throw ("Validation script not found: {0}" -f $ValidatePath)
        }

        $ValidationStamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $ValidationLog = Join-Path `
            $LogDirectory `
            ("{0}-{1}-validation.log" -f $ValidationStamp, $StoryId)

        Write-LoopStatus `
            -Phase "Independent validation running" `
            -StoryId $StoryId `
            -StoryTitle $StoryTitle `
            -PassNumber 0 `
            -CompletedCount $CompletedCount `
            -Detail ("Validation log: {0}" -f $ValidationLog)

        $PreviousPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        try {
            & powershell `
                -NoProfile `
                -ExecutionPolicy Bypass `
                -File $ValidatePath 2>&1 |
                ForEach-Object {
                    $Line = [string]$_
                    Write-Host $Line
                    Add-Content -Path $ValidationLog -Value $Line -Encoding UTF8
                }

            $ValidationExitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $PreviousPreference
        }

        $ValidationTail = @(
            Get-Content $ValidationLog -Tail 30 -ErrorAction SilentlyContinue
        )

        Add-Report -Lines @(
            "",
            "## Independent validation",
            "",
            ("- Exit code: {0}" -f $ValidationExitCode),
            ("- Log: {0}" -f $ValidationLog),
            "",
            "~~~text"
        )

        if ($ValidationTail.Count -eq 0) {
            Add-Report -Lines @("(no output)")
        }
        else {
            Add-Report -Lines $ValidationTail
        }

        Add-Report -Lines @(
            "~~~",
            ""
        )

        if ($ValidationExitCode -ne 0) {
            $FinalReason = (
                "Independent validation failed for {0} with exit code {1}." -f
                $StoryId,
                $ValidationExitCode
            )

            Add-Report -Lines @(
                "",
                "## LOOP STOPPED",
                "",
                ("- Time: {0}" -f (Get-Timestamp)),
                ("- Reason: {0}" -f $FinalReason)
            )

            Write-LoopStatus `
                -Phase "Stopped" `
                -StoryId $StoryId `
                -StoryTitle $StoryTitle `
                -PassNumber 0 `
                -CompletedCount $CompletedCount `
                -Detail $FinalReason

            exit $ValidationExitCode
        }

        $CompletedCount++

        Add-Report -Lines @(
            "",
            "## Story completed",
            "",
            ("- Story: {0} - {1}" -f $StoryId, $StoryTitle),
            ("- Time: {0}" -f (Get-Timestamp)),
            ("- Ending commit: {0}" -f $EndCommit),
            "- Independent validation: PASS",
            ("- Stories completed this run: {0} / {1}" -f $CompletedCount, $MaxStories)
        )
    }

    if ($CompletedCount -ge $MaxStories) {
        $FinalReason = ("Reached MaxStories={0}." -f $MaxStories)
    }

    Write-LoopStatus `
        -Phase "Finished" `
        -StoryId "none" `
        -StoryTitle "none" `
        -PassNumber 0 `
        -CompletedCount $CompletedCount `
        -Detail $FinalReason

    Add-Report -Lines @(
        "",
        "## Run finished",
        "",
        ("- Time: {0}" -f (Get-Timestamp)),
        ("- Reason: {0}" -f $FinalReason),
        ("- Stories completed: {0}" -f $CompletedCount)
    )
}
catch {
    $FinalReason = ("PowerShell error: {0}" -f $_.Exception.Message)

    Add-Report -Lines @(
        "",
        "## LOOP CRASHED",
        "",
        ("- Time: {0}" -f (Get-Timestamp)),
        ("- Reason: {0}" -f $FinalReason),
        ("- Position: {0}" -f $_.InvocationInfo.PositionMessage),
        ("- Stack: {0}" -f $_.ScriptStackTrace)
    )

    Write-LoopStatus `
        -Phase "Crashed" `
        -StoryId "unknown" `
        -StoryTitle "unknown" `
        -PassNumber 0 `
        -CompletedCount $CompletedCount `
        -Detail $FinalReason

    throw
}
