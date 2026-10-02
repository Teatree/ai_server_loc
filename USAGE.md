# Usage Metrics

Installed October 1, 2026. No AI application was stopped or restarted.

## Open it now

Refresh the local dashboard at http://127.0.0.1:32146/ and click **Usage Metrics**
below the hardware readings. Direct address: http://127.0.0.1:32149/usage.html.
The existing dashboard launcher now also starts this independent companion.
If necessary, run `C:\AI\AI-Server-Remote-Gateway\Start-Usage-Metrics.ps1`.
It is safe to run twice; it leaves an existing companion running.

## Update your existing Render dashboard

1. Sign into Render and open **garry-ai-remote-0913-dashboard**.
2. Under Settings, confirm its deployment branch is **codex/render-gateway**
   in **Teatree/ai_server_loc**. Keep your existing environment variables.
3. Open **Manual Deploy → Deploy latest commit**. The commit title for this
   current update is **Replace VRAM attribution with protected GPU counter monitoring**.
4. Wait for the deployment to become Live. Sign into the dashboard again if asked.
5. Refresh and click **Usage Metrics**, or visit
   https://garry-ai-remote-0913-dashboard.onrender.com/usage.html.
6. The status should show **Recording · updates every 15s**. If history is offline,
   run `Start-Usage-Metrics.ps1` on Windows and check SSH access to Ubuntu.

Only the dashboard Render service needs this update. No new service, database,
connector token, OAuth callback or paid plan is needed. Do not re-create the Blueprint.
Manual deployment controls: https://render.com/docs/deploys#manual-deploys.
Render deployment may end your dashboard login; Ubuntu jobs and recording continue.

## Controls and interpretation

Choose 8h, 24h, 7d, 30d, 1y, 10y or any custom range, in local time or UTC.
Resource selections show separate synchronized GPU, CPU and RAM plots; percentages
are never added across unlike devices. Stacked bars are default; switch to lines.
Scrolling and swiping always move the page. Each chart has instant Earlier/Later,
Zoom and Reset chart buttons; they stay inside the page's selected time range and
do not request data from the server. Live refresh preserves individual zoom positions.
Reset all restores the latest eight hours and clears filters. Page navigation clamps
to recorded history; the date picker still permits explicit empty date ranges.
Inspect with touch/mouse/arrow keys, select an app, toggle legend series,
export to CSV, or return to Live. Live reads every 15 seconds.
System / Unattributed is always shown, even when filtering to one application.
The top nine apps have individual colors; remaining apps are grouped as Other.
Select any app from the Application list for its individual chart, even if grouped.
Application totals always cover all apps and all resources in the selected range.

Minute averages and sampled peaks remain available indefinitely. Large ranges
automatically coarsen to at most about 1,200 bars; zoom in for minute detail.
Recording began at installation: blank earlier years and downtime are not zero usage.
Three extra indicators show load-weighted GPU hours, peak GPU load and coverage.
CPU hours mean whole-machine capacity-hours, not summed individual core-hours.

## Measurement accuracy and electricity

CPU uses process CPU-time counters; RAM uses proportional set size (PSS).
Protected processes, kernel/cache usage and missed short-lived jobs remain unattributed.
Recognized app children inherit their parent's name. Other apps appear automatically
by process name; Python/Node projects use distinct working-directory identities
on Linux under home/opt/srv. Optional literal matching rules go in Ubuntu's
`~/.local/share/ai-usage-history/apps.json`, e.g.
`[{"id":"my_app","name":"My App","patterns":["/opt/my-app"]}]`.
Rules affect new measurements; they do not silently rewrite old history.

GPU totals use driver counters. DRM engine-time counters estimate per-app shares.
Allocated VRAM is no longer used to assign GPU load. The running Ollama workers did
not appear in the ROCm/KFD allocation interface, while an idle ComfyUI client did;
the previous fallback therefore gave activity to the wrong application.
Only engine-time counters now contribute app shares. Counter shares are normalized
to measured device load and are not exact per-kernel occupancy measurements.
Missing counters stay System / Unattributed. Some ROCm clients expose no engine
counters even with sufficient permissions; those remain unattributed.
The original recorder could not inspect protected Ollama GPU clients and could
incorrectly credit other visible apps. Old and mixed-version time buckets now display
the stored counter-supported shares instead, with unknown load unattributed. Their
missing per-app history cannot be reconstructed; measured device totals are unchanged.
The API also sanitizes old estimated app shares for older online clients without
altering the original stored samples. New samples use attribution version 3.
Multiple DRM GPUs are discovered automatically; unsupported utilization/power sensors
remain missing. This collector currently reads Linux DRM/sysfs, not NVIDIA NVML.

## One-time installation for protected GPU process counters

Files have been prepared on Ubuntu. In the AI Server Terminal, run:

```bash
sudo bash ~/.local/share/ai-usage-collector/usage/install-gpu-probe.sh
```

This requires the Ubuntu administrator password in that terminal. It installs and
starts only `ai-usage-gpu-probe.service`; it never restarts Ollama, ComfyUI or other
AI apps. The existing collector discovers the helper automatically. Check it with
`systemctl status ai-usage-gpu-probe.service` and inspect the Usage Metrics status.

The root-owned helper runs isolated Python from `/usr/local/lib/ai-usage-gpu-probe`.
It has only the capabilities needed for cross-account process reads, no network,
read-only system/home isolation, and blocked debugging/mount/reboot system calls.
It exports only PID/start identity and DRM engine counters to an atomic snapshot
in `/run/ai-usage-probe`. No prompts, command lines or process memory are exported.
The unprivileged collector rejects stale snapshots, unsafe ownership, PID reuse
and duplicate descriptors. Its permissions and the dashboard SSH account stay unchanged.
Installation alone is not proof of attribution: verify changing Ollama engine
counters during a real job. If the backend exposes none, its usage stays unattributed.

## Electricity estimates

The default electricity rate is **4 c/kWh**. The currency label is deliberately `c`:
no national currency was specified. Change the rate/unit and power assumptions in
Electricity settings. These browser-local preferences recalculate all selected history.
GPU board power is measured; CPU uses 10W idle to 91W full load, plus 35W system
overhead, divided by 90% PSU efficiency. These are editable estimates, not wall-meter
measurements. Missing GPU power is flagged; costs exclude unrecorded periods.

## Storage, security and recovery

Ubuntu service: `systemctl --user status ai-usage-collector`.
Code: `~/.local/share/ai-usage-collector/usage/`.
Database: `~/.local/share/ai-usage-history/history.sqlite3`.
The unprivileged recorder uses a 15-second interval, low priority, 10% CPU quota,
192 MB memory ceiling, private file permissions and an exclusive writer lock.
SQLite uses WAL and full synchronous commits. Versioned compressed metric maps allow
new apps/devices/metrics without changing table layouts. Unknown schema versions fail
closed; upgrades must migrate explicitly. History is never automatically deleted.

Daily online SQLite backups keep `backups/history-latest.sqlite3` and
`backups/history-previous.sqlite3`. Rotation replaces backups, never retained history.
The footer reports backup status and free disk. Copy completed backups to another disk
for protection against drive failure; same-disk copies cannot provide that protection.
For recovery, stop only `ai-usage-collector`, preserve the original database and its WAL
files, restore a verified snapshot into a fresh history directory, then start the collector.
Do not overwrite a live database. Recording gaps during recovery remain visible.

The dashboard has only a fixed, read-only history query endpoint. Queries use SQLite
read-only mode and bounded date/interval parameters. No SQL or filesystem paths are
accepted from the browser. No public Ubuntu port is opened. Windows reads over SSH
and serves loopback port 32149; Render uses a separate outbound authenticated channel.
Your existing owner login protects both the page and API. No database or raw process
commands/prompts are uploaded to Git or stored on Render.

`Stop-Connector.ps1` stops both Windows remote connections, including the Usage Metrics
companion, but leaves AI apps and Ubuntu recording running. Reopening the local dashboard
starts the companion again and reconnects its metrics channel. The original app bridge
is independent. Closing only its terminal leaves metrics access running.
