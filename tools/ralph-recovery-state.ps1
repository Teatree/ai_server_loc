param(
    [Parameter(Mandatory)]
    [ValidateSet("Prepare", "Record", "Complete", "Interrupt")]
    [string]$Action,
    [Parameter(Mandatory)][string]$PrdPath,
    [Parameter(Mandatory)][string]$StoryId,
    [Parameter(Mandatory)][string]$RecoveryDir,
    [string]$RepoRoot = ".",
    [string]$LogPath = "",
    [string]$RunId = "",
    [int]$Iteration = 0,
    [int]$MinimumStreak = 0
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PrdPath = (Resolve-Path -LiteralPath $PrdPath).Path
New-Item -ItemType Directory -Force -Path $RecoveryDir | Out-Null
$RecoveryDir = (Resolve-Path -LiteralPath $RecoveryDir).Path
$SafeStoryId = $StoryId -replace '[^A-Za-z0-9_.-]', '_'
$StatePath = Join-Path $RecoveryDir "$SafeStoryId.json"
$PacketPath = Join-Path $RecoveryDir "$SafeStoryId.md"

function Read-State {
    if (-not (Test-Path -LiteralPath $StatePath)) { return $null }
    try { return Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json }
    catch { return $null }
}

function Write-State([hashtable]$State) {
    $Json = $State | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($StatePath, $Json + "`n", [Text.UTF8Encoding]::new($false))
}

function Get-Story {
    $Prd = Get-Content -LiteralPath $PrdPath -Raw | ConvertFrom-Json
    $Story = $Prd.stories | Where-Object id -eq $StoryId | Select-Object -First 1
    if (-not $Story) { throw "Story $StoryId is missing from $PrdPath." }
    return $Story
}

function Get-DirtyFiles {
    return @(git -C $RepoRoot status --porcelain=v1 | ForEach-Object {
        if ($_.Length -ge 4) { $_.Substring(3).Trim('"') }
    } | Where-Object { $_ })
}

function Get-CarryoverFiles($Story) {
    $AllowedPaths = @($Story.allowedPaths)
    return @(Get-DirtyFiles | Where-Object {
        $File = $_
        @($AllowedPaths | Where-Object { $File -like $_ }).Count -gt 0
    } | Sort-Object -Unique)
}

function Get-FailureData {
    $Failures = @()
    $Summary = "No test summary captured."
    if ($LogPath -and (Test-Path -LiteralPath $LogPath)) {
        $Lines = Get-Content -LiteralPath $LogPath
        $Failures = @($Lines | Where-Object { $_ -match '^FAIL:\s*' } |
            ForEach-Object { ($_ -replace '^FAIL:\s*', '').Trim() } |
            Sort-Object -Unique)
        $SummaryLine = $Lines | Where-Object { $_ -match '^Tests:\s*' } |
            Select-Object -Last 1
        if ($SummaryLine) { $Summary = $SummaryLine.Trim() }
    }
    $ToolFailures = @()
    if ($LogPath -and (Test-Path -LiteralPath $LogPath)) {
        $ToolFailures = @(Get-Content -LiteralPath $LogPath |
            Where-Object { $_ -match '^TOOL_ERROR:\s*' } |
            ForEach-Object { ($_ -replace '^TOOL_ERROR:\s*', '').Trim() } |
            Sort-Object -Unique)
    }
    return @{ failures = $Failures; summary = $Summary; toolFailures = $ToolFailures }
}

function Get-OutcomeFingerprint($FailureData) {
    $Material = @(
        $StoryId
        $FailureData.summary
        ($FailureData.failures -join "`n")
    ) -join "`n---`n"
    $Bytes = [Text.Encoding]::UTF8.GetBytes($Material)
    $Sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($Sha.ComputeHash($Bytes))).Replace('-', '').ToLower() }
    finally { $Sha.Dispose() }
}

function Get-WorkspaceFingerprint {
    $Head = (git -C $RepoRoot rev-parse HEAD 2>$null)
    $Status = (git -C $RepoRoot status --porcelain=v1) -join "`n"
    $Diff = (git -C $RepoRoot diff --binary HEAD --) -join "`n"
    $Material = @(
        $StoryId
        $Head
        $Status
        $Diff
    ) -join "`n---`n"
    $Bytes = [Text.Encoding]::UTF8.GetBytes($Material)
    $Sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($Sha.ComputeHash($Bytes))).Replace('-', '').ToLower() }
    finally { $Sha.Dispose() }
}

function Get-RecoveryLevel([int]$Streak) {
    if ($Streak -ge 3) { return 2 }
    if ($Streak -ge 1) { return 1 }
    return 0
}

function Write-Packet($Story, $State, [string[]]$Carryover) {
    $Streak = [int]$State.streak
    $Level = Get-RecoveryLevel $Streak
    $Mode = @("normal", "recovery", "escalated recovery")[$Level]
    $Lines = @(
        "# Ralph recovery packet: $StoryId",
        "",
        "- Mode: $Mode",
        "- Identical failing-outcome streak: $Streak",
        "- Unchanged-workspace streak: $($State.workspaceStreak)",
        "- Previous result: $($State.summary)",
        "- Previous run: $($State.runId), iteration $($State.iteration)",
        "",
        "## Unresolved failures"
    )
    $Failures = @($State.failures)
    if ($Failures.Count) { $Lines += @($Failures | ForEach-Object { "- $_" }) }
    else { $Lines += "- No assertion names were captured; inspect the prior run log." }
    $Lines += @("", "## Recent tool failures")
    $ToolFailures = @($State.toolFailures)
    if ($ToolFailures.Count) { $Lines += @($ToolFailures | ForEach-Object { "- $_" }) }
    else { $Lines += "- (none captured)" }
    $Lines += @("", "## Same-story carryover candidates")
    if ($Carryover.Count) { $Lines += @($Carryover | ForEach-Object { "- $_" }) }
    else { $Lines += "- (none)" }
    $Lines += @(
        "",
        "These files are dirty and within this story's Allowed Paths. Inspect their diffs.",
        "You may continue, correct, stage, and commit them when they belong to this story.",
        "Never stage an unrelated or user-authored change merely because it is listed here."
    )
    if ($Level -ge 1) {
        $Lines += @(
            "", "## Mandatory recovery procedure",
            "Do not begin by rerunning full validation or rereading files without a hypothesis.",
            "1. Read every failing test body and trace the exercised implementation path.",
            "2. State one concrete shared root-cause hypothesis in your activity log.",
            "3. Make a targeted story-scoped edit before rerunning validation.",
            "4. Run the smallest useful check first, then the required full gates.",
            "5. Recover from tool errors in this session; never repeat an identical failed call.",
            "6. Do not end after inspection or after reproducing an already-known failure."
        )
    }
    if ($Level -ge 2) {
        $Lines += @(
            "", "## Escalation",
            "Three or more identical failing outcomes have occurred. Change strategy, not just wording.",
            "Compare test setup assumptions with runtime preconditions and shared failure causes.",
            "If an edit tool fails, retry with a much smaller targeted edit in the same session."
        )
    }
    [IO.File]::WriteAllLines($PacketPath, $Lines, [Text.UTF8Encoding]::new($false))
}

$Story = Get-Story
$Existing = Read-State

if ($Action -eq "Complete") {
    Remove-Item -LiteralPath $StatePath, $PacketPath -Force -ErrorAction SilentlyContinue
    Write-Output "complete|0|Recovery state cleared."
    exit 0
}

if ($Action -eq "Interrupt") {
    $State = @{
        storyId = $StoryId
        streak = if ($Existing) { [int]$Existing.streak } else { 0 }
        outcomeFingerprint = if ($Existing) { [string]$Existing.outcomeFingerprint } else { "" }
        workspaceFingerprint = if ($Existing) { [string]$Existing.workspaceFingerprint } else { "" }
        workspaceStreak = if ($Existing) { [int]$Existing.workspaceStreak } else { 0 }
        summary = "Interrupted before completion; resume this story."
        failures = if ($Existing) { @($Existing.failures) } else { @() }
        toolFailures = if ($Existing) { @($Existing.toolFailures) } else { @() }
        runId = $RunId
        iteration = $Iteration
        interrupted = $true
        updatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    }
    Write-State $State
    Write-Packet $Story $State (Get-CarryoverFiles $Story)
    Write-Output "interrupted|$($State.streak)|Recovery state preserved."
    exit 0
}

if ($Action -eq "Record") {
    $FailureData = Get-FailureData
    if ($FailureData.summary -eq "No test summary captured." -and $Existing) {
        $FailureData.summary = [string]$Existing.summary
        $FailureData.failures = @($Existing.failures)
    }
    if (@($FailureData.toolFailures).Count -eq 0 -and $Existing) {
        $FailureData.toolFailures = @($Existing.toolFailures)
    }
    $OutcomeFingerprint = Get-OutcomeFingerprint $FailureData
    $WorkspaceFingerprint = Get-WorkspaceFingerprint
    $Streak = 1
    if ($Existing -and $Existing.outcomeFingerprint -eq $OutcomeFingerprint) {
        $Streak = [int]$Existing.streak + 1
    }
    $WorkspaceStreak = 1
    if ($Existing -and $Existing.workspaceFingerprint -eq $WorkspaceFingerprint) {
        $WorkspaceStreak = [int]$Existing.workspaceStreak + 1
    }
    if ($Streak -lt $MinimumStreak) { $Streak = $MinimumStreak }
    $State = @{
        storyId = $StoryId
        streak = $Streak
        outcomeFingerprint = $OutcomeFingerprint
        workspaceFingerprint = $WorkspaceFingerprint
        workspaceStreak = $WorkspaceStreak
        summary = $FailureData.summary
        failures = @($FailureData.failures)
        toolFailures = @($FailureData.toolFailures)
        runId = $RunId
        iteration = $Iteration
        interrupted = $false
        updatedAt = [DateTimeOffset]::UtcNow.ToString("o")
    }
    Write-State $State
    Write-Packet $Story $State (Get-CarryoverFiles $Story)
    Write-Output "recorded|$Streak|$($FailureData.summary)"
    exit 0
}

if (-not $Existing) {
    $Existing = [pscustomobject]@{
        streak = 0; summary = "No previous failure recorded."
        workspaceStreak = 0; failures = @(); toolFailures = @()
        outcomeFingerprint = ""; workspaceFingerprint = ""
        runId = ""; iteration = 0
    }
}
Write-Packet $Story $Existing (Get-CarryoverFiles $Story)
Write-Output $PacketPath
