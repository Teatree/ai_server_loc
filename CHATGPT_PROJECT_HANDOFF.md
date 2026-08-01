# LAST SHIFT — ChatGPT / OpenCode Project Handoff

_Last updated from the conversation and the latest supplied overnight report on 2026-08-01._

This file is the durable context package for a fresh ChatGPT conversation or another coding agent.  
It records the project setup, automation design, completed work, current blocker, known failure modes, and the exact procedure for resuming safely.

---

## 1. Project identity

- **Project name:** LAST SHIFT
- **Engine:** Godot 4.x
- **Observed Godot version:** 4.7.1 stable
- **Language:** typed GDScript
- **Local project path:** `D:\_projects\local_llm_evo_x2_test`
- **Godot executable observed by validation:** `D:\_projects\local_llm_evo_x2_test\godot.exe`
- **Original project-local executable name mentioned earlier:** `Godot_v4.7.1-stable_win64.exe`
- **Git branch observed:** `master`
- **Development workflow:** one fresh OpenCode session per story, controlled by an external PowerShell loop

The project is intended to become a runnable vertical slice with:

- title flow
- player movement
- health, damage, death, and checkpoint respawn
- weapons
- zombie enemies
- combat arena
- encounter director
- upgrades
- saving/loading
- HUD, feedback, audio architecture, and debug tools
- final integration and release baseline

---

## 2. Hardware and model environment

### EVO-X2 inference machine

- **Hardware:** Ryzen AI Max+ 395
- **Memory:** 128 GB
- **Backend:** llama.cpp Vulkan
- **Model family:** Step-3.7 Flash GGUF
- **Server host:** `10.10.10.2`
- **Server port:** `8080`
- **API base:** `http://10.10.10.2:8080/v1`
- **Alias:** `step-3.7-flash`
- **Main PC connection:** direct Ethernet to EVO-X2

### Known llama-server launch pattern

```powershell
.\llama-server.exe `
  -m $stepModel.FullName `
  -c 34000 `
  -ngl 99 `
  -fa on `
  -ctk q8_0 `
  -ctv q8_0 `
  -np 1 `
  --jinja `
  --temp 1.0 `
  --top-p 0.95 `
  --reasoning-budget 4096 `
  --reasoning-budget-message "I have reasoned sufficiently. I will now provide the direct answer or perform the required tool action." `
  --host 10.10.10.2 `
  --port 8080 `
  --alias step-3.7-flash `
  --api-key $env:STEP37_API_KEY
```

### Current user-selected context target

The user intends to run both llama-server and OpenCode with:

```json
"limit": {
  "context": 282768
}
```

and llama-server:

```powershell
-c 282768
```

### Important context warning

A large configured context limit is only a ceiling. It does not guarantee that:

- llama.cpp can allocate the KV cache
- OpenCode will actually use the full amount
- tool-call JSON will remain valid
- the model will reason better over very long histories
- latency will remain acceptable

With Q8 KV cache, a context of `282768` may consume substantial memory. Watch the llama-server console for:

- allocation failures
- out-of-memory errors
- Vulkan device-memory errors
- extreme prompt ingestion time
- server disconnects or timeouts

The project previously ran successfully at much smaller contexts. The recurring S05 blocker was a deterministic test failure, not a detected context overflow.

---

## 3. OpenCode setup

- **Observed OpenCode version:** 1.18.3
- **Provider/model identifier:** `evox2/step-3.7-flash`
- **OpenCode executable observed in the report:**

```text
C:\nvm4w\nodejs\node_modules\opencode-ai\bin\opencode.exe
```

### Model configuration requirement

The provider model context limit should match the llama-server context:

```json
"limit": {
  "context": 282768
}
```

After changing the configuration:

1. restart llama-server
2. restart OpenCode
3. confirm the resolved OpenCode config
4. run a small test before an overnight session

---

## 4. Git history and completed stories

### Initial repository setup

Known initial setup commit:

```text
38b337b chore(setup): initialize git repository and add .gitignore
```

### S00

S00 stabilized the repository and created a working title/main-scene baseline.

Known S00-related commits:

```text
0b5d0bf
801447d
```

### S01

S01 created the launchable shell and title flow.

Known commit:

```text
544adb8 story(S01): create launchable project shell and title flow
```

The first automated controller test correctly stopped afterward because `PROGRESS.md` and `run-story-loop.ps1` remained modified.

### Overnight run that began at 2026-08-01 02:57:36

The supplied report recorded these successfully completed stories:

| Story | Result | Commit |
|---|---|---|
| S02 | Basic player locomotion | `f725b3e` |
| S02B | Advanced jumping mechanics | `d174417` |
| S02C | Dodge, drop-through, and movement reset | `ebee661` |
| S03 | Health, damage, death, checkpoint respawn | `9ce4bdd` |
| S04 | Weapon framework and pistol | implementation `8ff0577`, metadata follow-up `7a310c9` |

Each of these stories reached `done`, left a clean tree, and passed the controller's independent validation.

---

## 5. Story plan

The current plan contains these stories:

- **S00** — Audit and stabilize the current repository
- **S01** — Create the launchable project shell and title flow
- **S02** — Implement basic player locomotion
- **S02B** — Add advanced jumping mechanics
- **S02C** — Add dodge, drop-through, and movement reset
- **S03** — Implement health, damage, death, and checkpoint respawn
- **S04** — Implement the weapon framework and pistol
- **S05** — Implement Shambler enemy, perception, and basic combat
- **S06** — Build the first complete combat arena
- **S07** — Add shotgun, rifle, melee, reload, and weapon switching
- **S08** — Add Runner, Spitter, Brute, and platform navigation
- **S09** — Implement encounter director and final holdout
- **S10** — Implement upgrades and deterministic choices
- **S11** — Implement versioned save and load
- **S12** — Complete HUD, feedback, audio architecture, and debug tools
- **S13** — Integration audit, tests, documentation, and release baseline

Dependency chain around movement and health:

```text
S02 -> S02B -> S02C -> S03 -> S04 -> S05 -> S06 ...
```

---

## 6. Automation architecture

The automation uses:

- `AGENTS.md`
- `TASKS.json`
- `PROGRESS.md`
- `ARCHITECTURE.md`
- `.opencode/commands/next-story.md`
- `.opencode/commands/review-story.md`
- `.opencode/commands/validate-story.md`
- `.opencode/commands/loop-status.md`
- `tools/validate.ps1`
- `run-story-loop.ps1`
- `.agent-logs/`

### Intended behavior

The PowerShell controller:

1. reads `TASKS.json`
2. resumes the single `in_progress` story, or selects the next eligible `open` story
3. starts a fresh noninteractive OpenCode session
4. gives the story multiple passes
5. rereads story state after each pass
6. stops on:
   - blocked story
   - unexpected status
   - OpenCode nonzero exit
   - story marked done without a commit
   - dirty working tree after done
   - missing validation script
   - validation failure
   - maximum passes reached
7. independently runs `tools\validate.ps1`
8. proceeds to the next story only after a clean validated completion

### Logs

The controller writes:

```text
.agent-logs\overnight-status.md
.agent-logs\overnight-report-YYYYMMDD-HHMMSS.md
.agent-logs\*-opencode.log
.agent-logs\*-validation.log
```

The short status file is the first place to inspect after any stop.

---

## 7. Current state at the end of the supplied report

### Controller result

The run stopped at:

```text
Story: S05 - Implement Shambler enemy, perception, and basic combat
Pass: 6
Stories completed this run: 5 / 20
Reason: Story S05 did not finish after 6 fresh passes.
```

### Current likely Git state

At the final recorded pass:

```text
 M TASKS.json
 M tests/run_tests.gd
?? scenes/enemies/
?? scripts/enemies/
```

This state may have changed after the report. Always verify with:

```powershell
git status --short
```

### S05 files observed

The agent created or modified:

```text
scenes/enemies/shambler.tscn
scripts/enemies/shambler.gd
scripts/enemies/...
tests/run_tests.gd
TASKS.json
```

The exact second file under `scripts/enemies/` should be confirmed from the filesystem.

---

## 8. Exact S05 blocker

The Godot project imported and started successfully.

The automated tests reached:

```text
Tests: 31 passed, 1 failed, 32 total
```

The persistent failure was:

```text
FAIL: death should emit exactly once
```

Other Shambler checks passed, including:

```text
PASS: shambler should start idle
PASS: noise should set investigate state
PASS: last known position should be noise origin
PASS: noise timer should be active
PASS: last known position should expire
PASS: dead shambler should stay dead
PASS: state should be dead
PASS: reset should clear death
PASS: reset should restore idle state
```

This means the implementation was close to completion. The unresolved defect is likely localized to one of:

- duplicate signal connections
- both `HealthComponent` and `Shambler` emitting equivalent death notifications
- a death callback running more than once
- test signal-count bookkeeping
- scene-instantiation cleanup or stale connections
- `reset()` reconnecting without disconnecting
- a signal connected both in script and in the scene file

Do not weaken the test merely to mark S05 done.

---

## 9. Tool-call failures observed

### Large write failure

An earlier S02 attempt tried to write a very large `player_controller.gd` payload and failed with:

```text
JSON Parse error: Unterminated string
```

A hard write-size rule was introduced:

- maximum about 60 lines per write/edit
- maximum about 6,000 characters per write/edit
- build large files incrementally
- after a truncation, retry at one quarter of the previous size

### S02C

One S02C pass recorded:

```text
JSON Parse error: Unterminated string
```

Despite that, a later pass completed and committed S02C successfully.

### S05

S05 pass 1 recorded:

```text
JSON Parse error: Unterminated string
```

S05 pass 6 recorded:

```text
JSON Parse error: Expected '}'
```

The pass-6 error came from an invalid `read` tool payload, not from Godot.

### Interpretation

These errors are model/tool serialization failures. A larger context may reduce some truncation pressure, but it does not guarantee valid JSON. The durable mitigation is:

- smaller tool calls
- narrower file scope
- focused retry instructions
- fresh sessions
- explicit continuation notes
- deterministic validation

---

## 10. Validation behavior

Validation script:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate.ps1
```

Observed validation stages:

```text
godot-import
godot-startup
godot-tests
```

### Nonfatal console noise

These lines appeared frequently:

```text
System.Management.Automation.RemoteException
```

In the supplied runs, these were usually PowerShell/native-stderr formatting noise rather than the real failure.

There were also leak warnings:

```text
WARNING: CanvasItem RIDs were leaked
WARNING: ObjectDB instances were leaked at exit
ERROR: resources still in use at exit
```

The validation script still considered earlier test runs successful when all assertions passed. These leaks should eventually be fixed, but the immediate S05 blocker is the failed assertion.

### Real failure signal

The meaningful failure is:

```text
godot-tests failed with exit code 1
```

combined with the named failed assertion.

---

## 11. Encoding artifacts

Console output contained mojibake such as:

```text
ΓåÉ
ΓÇö
Γ£ô
```

These are encoding/rendering artifacts for arrows, em dashes, and symbols. They are not themselves Godot or Git failures.

Using UTF-8 output may improve readability, but do not mistake mojibake for source corruption without inspecting the actual file.

---

## 12. Batch/CMD launcher and Bitdefender

A downloaded `.bat` launcher was quarantined by Bitdefender, likely because it:

- was downloaded from the Internet
- launched PowerShell
- used `-ExecutionPolicy Bypass`

The safer approach is to create the launcher locally and omit `Bypass`.

Create this file locally as:

```text
run-full-story-loop.cmd
```

with:

```bat
@echo off
setlocal
cd /d "%~dp0"

echo Starting OpenCode story loop...
echo.

powershell.exe -NoLogo -NoProfile ^
  -File ".\run-story-loop.ps1" ^
  -ProjectRoot "%CD%" ^
  -MaxStories 20 ^
  -MaxPassesPerStory 6

set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo Loop exited with code %EXIT_CODE%.
echo Status: .agent-logs\overnight-status.md
pause

exit /b %EXIT_CODE%
```

Do not disable Bitdefender globally.

---

## 13. Known process defects

### Post-commit metadata edit

S01 originally created a story commit and then edited `PROGRESS.md` to insert the commit hash. That left the working tree dirty and caused the controller to stop.

The corrected policy is:

1. update `TASKS.json`
2. update `PROGRESS.md`
3. validate
4. stage all story files
5. create the final story commit
6. do not edit tracked files after the final commit
7. leave the tree clean

In `PROGRESS.md`, use wording such as:

```text
Commit: included in final story commit; see Git history
```

instead of editing the hash afterward.

### Repeated broad re-planning

Fresh passes sometimes repeatedly reread the same broad set of files instead of focusing on the remaining failed criterion.

For an `in_progress` story, the preferred behavior is:

1. read the latest failure
2. inspect only directly relevant files
3. make the smallest root-cause fix
4. run the narrow test
5. run global validation
6. finish and commit

---

## 14. Immediate diagnostic commands

Run these from:

```text
D:\_projects\local_llm_evo_x2_test
```

### Repository state

```powershell
git status --short
git log --oneline -10
```

### Active story

```powershell
$tasks = Get-Content .\TASKS.json -Raw | ConvertFrom-Json
$tasks.active_story_id
$tasks.stories |
    Where-Object status -eq "in_progress" |
    Format-List id, title, status, dependencies
```

### Validate current files

```powershell
powershell `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File .\tools\validate.ps1
```

### Read current loop status

```powershell
Get-Content .\.agent-logs\overnight-status.md
```

### Find newest report

```powershell
$latestReport = Get-ChildItem `
    .\.agent-logs\overnight-report-*.md |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

$latestReport.FullName
```

### Find newest S05 pass log

```powershell
$latestS05Log = Get-ChildItem `
    .\.agent-logs\*-S05-pass*-opencode.log |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

$latestS05Log.FullName
```

---

## 15. How to put ChatGPT into the project context

ChatGPT cannot live inside the local repository as a continuously running process merely by adding a Markdown file. The reliable approach is to place a durable context package in the repository, then provide the project files to a fresh ChatGPT conversation.

Use the following procedure.

### Step 1 — Put this handoff file in the project root

Save this file as:

```text
D:\_projects\local_llm_evo_x2_test\CHATGPT_PROJECT_HANDOFF.md
```

### Step 2 — Add a pointer in AGENTS.md

Add near the top of `AGENTS.md`:

```markdown
## Durable project context

Before changing this repository, read:

- CHATGPT_PROJECT_HANDOFF.md
- TASKS.json
- PROGRESS.md
- ARCHITECTURE.md
- the newest .agent-logs/overnight-status.md
- the newest .agent-logs/overnight-report-*.md

For an in-progress story, inspect the latest failing validation and work only on
the smallest unresolved acceptance criterion.
```

### Step 3 — Commit the handoff file

Only do this while no autonomous loop is currently running.

```powershell
git add `
    .\CHATGPT_PROJECT_HANDOFF.md `
    .\AGENTS.md

git commit -m "docs: add durable ChatGPT project handoff"
```

If S05 currently has uncommitted implementation work, stage only the two documentation files as shown. Do not accidentally include unfinished S05 files in this documentation commit.

### Step 4 — Create a project snapshot for a fresh ChatGPT conversation

The best input is a ZIP of the project excluding large and generated files.

From the project root:

```powershell
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$stage = Join-Path $env:TEMP "last-shift-chatgpt-handoff-$stamp"
$zip = Join-Path $env:USERPROFILE "Desktop\last-shift-chatgpt-handoff-$stamp.zip"

New-Item -ItemType Directory -Force $stage | Out-Null

$include = @(
    "AGENTS.md",
    "CHATGPT_PROJECT_HANDOFF.md",
    "TASKS.json",
    "PROGRESS.md",
    "ARCHITECTURE.md",
    "project.godot",
    "tools",
    "scripts",
    "scenes",
    "resources",
    "tests",
    ".opencode"
)

foreach ($item in $include) {
    $source = Join-Path (Get-Location) $item

    if (Test-Path $source) {
        Copy-Item `
            -Path $source `
            -Destination $stage `
            -Recurse `
            -Force
    }
}

$latestStatus = ".\.agent-logs\overnight-status.md"

if (Test-Path $latestStatus) {
    New-Item `
        -ItemType Directory `
        -Force `
        (Join-Path $stage ".agent-logs") |
        Out-Null

    Copy-Item `
        $latestStatus `
        (Join-Path $stage ".agent-logs") `
        -Force
}

$latestReport = Get-ChildItem `
    .\.agent-logs\overnight-report-*.md `
    -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if ($latestReport) {
    Copy-Item `
        $latestReport.FullName `
        (Join-Path $stage ".agent-logs") `
        -Force
}

Compress-Archive `
    -Path (Join-Path $stage "*") `
    -DestinationPath $zip `
    -Force

Write-Host "Created: $zip"
```

Do not include:

- Godot executable
- `.godot/`
- imported assets
- model files
- `.git/`
- large binary build outputs
- all historical logs

### Step 5 — Start a fresh ChatGPT conversation

Upload:

```text
last-shift-chatgpt-handoff-YYYYMMDD-HHMMSS.zip
```

A fresh conversation is preferable because the existing conversation is long and contains superseded instructions.

### Step 6 — Use this exact first prompt

```text
Read CHATGPT_PROJECT_HANDOFF.md first.

Then inspect TASKS.json, PROGRESS.md, AGENTS.md, ARCHITECTURE.md, the newest
overnight status/report, and the current S05 implementation.

Do not redesign the project and do not restart completed stories.

First report:
1. the exact current Git/story state represented by the files,
2. the root cause of the failing test "death should emit exactly once",
3. the smallest safe patch,
4. any files that are missing from the snapshot.

Then produce corrected full-file replacements or a precise patch for S05.
Do not weaken the test. Preserve typed GDScript and the existing architecture.
Keep every generated tool/edit payload small.
```

### Step 7 — Provide live command output when requested

A ZIP is a snapshot. ChatGPT cannot see changes made afterward unless updated files or logs are supplied.

After applying a patch, provide:

```powershell
git status --short
git diff --stat
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate.ps1
```

### Step 8 — Apply changes carefully

Before replacing files:

```powershell
git diff
```

After replacing files:

```powershell
git diff --check
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate.ps1
```

Only commit when all tests pass.

### Step 9 — Resume the loop only from a clean validated state

Required preconditions:

```powershell
git status --short
```

must print nothing, and:

```powershell
$tasks = Get-Content .\TASKS.json -Raw | ConvertFrom-Json
($tasks.stories | Where-Object id -eq "S05").status
```

must print:

```text
done
```

Then run:

```powershell
.\run-full-story-loop.cmd
```

---

## 16. Recommended fresh-chat repair scope for S05

The first repair pass should inspect only:

```text
tests/run_tests.gd
scripts/enemies/shambler.gd
scripts/core/health_component.gd
scenes/enemies/shambler.tscn
```

Questions to answer:

1. What signal is the test counting?
2. Is it emitted by `HealthComponent`, `Shambler`, or both?
3. Is the signal connected in both `.gd` and `.tscn`?
4. Is the connection repeated during `_ready()`, reset, or scene reuse?
5. Does the test instantiate more than one Shambler without cleaning up?
6. Does `queue_free()` occur too late for the next test?
7. Does `take_damage()` trigger both direct death handling and a connected callback?
8. Does `reset()` reconnect the same callable?

The patch should be localized and preserve:

- one-shot death
- dead entities ignoring later damage
- reset restoring a valid idle state
- existing health tests
- typed GDScript
- deterministic test behavior

---

## 17. Safety rules for the next agent

- Never discard uncommitted S05 work without showing the diff.
- Never mark a story done while validation fails.
- Never remove the failing assertion solely to obtain a green test run.
- Never edit tracked files after the final story commit.
- Never write a large source file in one tool call.
- Never run multiple autonomous loop instances against the same working tree.
- Never run the loop while the user is manually editing the same files.
- Never commit generated `.agent-logs/` unless intentionally changing policy.
- Never assume the working tree is clean; verify it.
- Never assume the report reflects the latest filesystem state; verify it.
- Keep the Godot executable and imported cache out of Git.

---

## 18. Suggested repository documentation commit

After placing this file in the root and adding the AGENTS.md pointer:

```powershell
git add `
    .\CHATGPT_PROJECT_HANDOFF.md `
    .\AGENTS.md

git commit -m "docs: add durable AI troubleshooting handoff"
```

This handoff should be updated whenever:

- model endpoint or context changes
- the controller changes
- a story is split
- validation behavior changes
- a recurring failure is discovered
- the active blocker changes
- the project reaches a new stable milestone
