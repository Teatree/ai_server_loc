# Minimal OpenCode Story Loop — Setup

This kit replaces a framework-driven Ralph loop with a transparent project-local workflow.

## 1. Remove the globally installed Ralph CLI

Run in PowerShell:

```powershell
npm uninstall -g @iannuttall/ralph
```

Verify:

```powershell
npm list -g --depth=0 | Select-String -Pattern "ralph"
Get-Command ralph -ErrorAction SilentlyContinue
```

No output from `Get-Command` means the CLI is no longer on `PATH`.

### Optional project cleanup

If you also ran `ralph install`, inspect its project files first:

```powershell
Get-ChildItem -Force .agents\ralph,.ralph -ErrorAction SilentlyContinue
```

Ralph normally creates customizable templates under `.agents/ralph/` and runtime state under `.ralph/`. Remove those directories only when they were created for Ralph and contain nothing you want to keep:

```powershell
Remove-Item -Recurse -Force .agents\ralph -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force .ralph -ErrorAction SilentlyContinue
```

If you installed Ralph skills, inspect `.opencode\skills` before deleting anything. Do not delete shared skills blindly.

## 2. Put this kit in the project root

The final structure should include:

```text
AGENTS.md
TASKS.json
PROGRESS.md
ARCHITECTURE.md
.opencode/
  commands/
    next-story.md
    review-story.md
    validate-story.md
    loop-status.md
tools/
  validate.ps1
```

Back up existing files with the same names before replacing them.

## 3. Merge the Git ignore additions

Open `gitignore.additions.txt` and append the entries to your existing `.gitignore`.

Confirm the Godot executable is ignored:

```powershell
git check-ignore -v .\Godot_v4.7.1-stable_win64.exe
```

Use the actual executable filename when different.

## 4. Initialize Git when necessary

```powershell
git rev-parse --is-inside-work-tree
```

If that fails:

```powershell
git init
git branch -M main
```

Create a baseline commit after inspecting the current files:

```powershell
git status --short
git add AGENTS.md TASKS.json PROGRESS.md ARCHITECTURE.md .opencode tools gitignore.additions.txt
git commit -m "chore: add minimal OpenCode story loop"
```

Do not blindly stage partial game files until you have reviewed them.

## 5. Configure OpenCode

OpenCode automatically reads project-root `AGENTS.md` and project commands from `.opencode/commands/`.

Keep your existing provider configuration. Recommended compaction setting for the local Step-3.7 workflow:

```json
"compaction": {
  "auto": false,
  "prune": true,
  "reserved": 2048
}
```

The resolved `evox2/step-3.7-flash` model must expose at least:

```json
"limit": {
  "context": 250000
}
```

Keep llama-server at the same ceiling. The loop preflight rejects a lower OpenCode
limit, but it cannot inspect the remote server allocation.

A minimal project-level example is included as `opencode.project.example.json`. Merge it manually; do not overwrite your working provider configuration.

Restart OpenCode after adding command files.

## 6. Establish the validation baseline

From the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate.ps1
```

The first run may fail because the partial project is broken. That is expected; story `S00` exists specifically to establish the baseline.

## 7. Run the loop

First run the non-mutating preflight:

```powershell
powershell -NoProfile -File .\tools\story-loop-controller.ps1 -PreflightOnly
```

It verifies task-state consistency, dependency IDs, allowed dirty paths, required
files, and an OpenCode context of at least 250,000 tokens.

For an unattended run, use the locally created launcher:

```text
run-full-story-loop.cmd
```

The controller starts with `/next-story`, resumes with `/continue-story`, retries
transient tool failures without charging the story, and stops only after three
consecutive no-progress passes, an external blocker, or the per-story hard safety
ceiling. `MaxStories=0` keeps selecting eligible stories until none remain.

Implementation moves to `ready_for_validation`. The controller then runs global
validation and invokes `/finalize-story` for the single final commit.

Start a fresh OpenCode session from the project root:

```powershell
opencode
```

Check status:

```text
/loop-status
```

Run exactly one story:

```text
/next-story
```

Or choose a story explicitly:

```text
/next-story S00
```

After the story stops, close the session. Start a new session for the next story.

## 8. Review before continuing

In a fresh session:

```text
/review-story S00
```

Run validation independently:

```text
/validate-story
```

When review identifies a bounded defect, start another fresh session and run `/next-story S00` to repair it. Do not mix the next feature into the repair session.

## 9. Daily operating pattern

```text
new session
→ /loop-status
→ /next-story SXX
→ agent runs focused checks and writes .loop-state/active.json
→ /continue-story SXX until ready_for_validation
→ controller runs global validation
→ /finalize-story SXX commits the validated story
→ close session
→ new session
→ /review-story SXX
→ repair if required
→ proceed to next story
```

The design goal is unattended completion through small, independently bounded stories.
