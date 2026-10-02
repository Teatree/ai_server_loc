# Manual model controls

Each dashboard app card has a **Loaded models** section. Refresh the dashboard
after installation. Status refreshes every 20 seconds while the page is visible.
Loaded models are separate from the downloaded-model catalog. Unload releases
memory; it never deletes model files or stops the app service.

| App | Visibility and release |
| --- | --- |
| Ollama | `/api/ps` resident names, memory and VRAM. Unload one or all listed models using the native expiry request. Activity is unknown; active requests finish before expiry. A later client request can reload a model. |
| ComfyUI | Idle/busy queue status; release all model and execution caches. This version has no resident-name API, so names and model memory are explicitly unavailable. No installed filenames are presented as loaded models. |
| InvokeAI | Queue status; empty the model RAM/VRAM cache. Locked models remain in use. Resident names are unavailable. Existing app authentication still applies. |
| Unsloth | Resident text, image/video, speech and embedding backends, plus active text/diffusion training. Text and speech support scoped unload. Training/loading blocks controls. Image/video and embedding rows direct you to Unsloth because their APIs do not provide a verified idle-only release. |
| llama.cpp | Reports the running server's model. This single-model configuration requires stopping the app to release its model; it has no separate unload control. |
| OpenClaw / Open WebUI | Use models hosted by their configured providers. Local Ollama models are managed on the Ollama card. Releasing a shared model affects every client using it. |

Some per-model memory measurements are unavailable; the UI says so. “Unknown”
activity does not mean idle. Unload-all operates on the displayed selection,
rechecking state before every release. It is not an atomic transaction: if a
later model becomes busy, earlier releases can have succeeded. Failed requests
are never retried automatically. Refresh status before retrying.

Apps now remain running when another app is started. Loaded models can still
compete for RAM/VRAM even while idle. Native app cache policies, automatic model
expiry, and model loading behavior remain under each application's control.

## Install or reproduce locally

Run `Install-Model-Controls.ps1` from the gateway directory. It copies the new
SSH module, backs up and removes exclusive-start rules from `ai-workload` and
the four managed Ubuntu unit files, then runs `systemctl --user daemon-reload`.
That reload changes service definitions without restarting services. It also
installs static dashboard assets and a companion startup hook. Backups live in
`~/.local/share/ai-model-control/backups` and the gateway's ignored `private` directory.

The companion binds only to Windows loopback port 32150. Local browser access is
restricted to the dashboard on port 32146. SSH can invoke only the fixed model
module; request data cannot choose a URL or shell command. Remote requests use
the existing GitHub owner login, session and origin checks, and a separate
authenticated `models-` channel. Existing app and metrics channels keep running.

## Update Render

1. Open the existing **garry-ai-remote-0913-dashboard** service.
2. Confirm its branch is **codex/render-gateway**.
3. Choose **Manual Deploy → Deploy latest commit**.
4. When the deployment is live, refresh the dashboard and sign in again if asked.

No new Render service, token or environment variable is required. The model
companion reconnects automatically. Other app services do not need redeploying.
Render deployment briefly reconnects dashboard access; AI jobs continue locally.

API references: [Ollama expiry scheduling](https://github.com/ollama/ollama/blob/main/server/sched.go).
ComfyUI, InvokeAI and Unsloth capabilities were checked against their installed source.

Validation: `Validate.ps1` covers mocked release requests, concurrency policy,
stale/busy rejection, authentication, origin checks and bridge isolation. The
Playwright function in `tests/models.browser.js` tests 320/390/1280px widths,
escaped model names, cancellation, and single/all unloads using intercepted
responses; it never sends a real unload request.
