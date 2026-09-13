# Ubuntu AI Server Setup Handoff

## Instruction to the assisting agent

Execute this setup on the Ubuntu computer; do not merely explain how to do it.
The Windows main PC is the control machine. The Ubuntu computer performs AI work.
Continue until the acceptance checks pass or a decision genuinely requires the user.

Do not modify the Godot game project. Do not erase existing user files. Do not
download any LLM/GGUF model. In particular, do not download Step 3.7 Flash or
Qwen3.5-122B. Installing and building `llama.cpp` itself is required.

## Desired result

Build a replacement for the former EVO-X2 arrangement containing:

1. `llama.cpp` and `llama-server`, ready for a model to be added later.
2. ComfyUI with ComfyUI-Manager and working model/workflow directories.
3. InvokeAI, using its supported model manager rather than manual model placement.
4. Persistent services with Start, Stop, Restart, logs, and honest health status.
5. A mobile-friendly dashboard on the Windows main PC.
6. Passwordless SSH from the Windows main PC to Ubuntu.
7. Internet access on Ubuntu through Windows Internet Connection Sharing.

The dashboard must never claim READY merely because a start command succeeded.
READY requires both runtime evidence and a successful application health request.
If the state cannot be proven, show UNKNOWN.

## Phase 1: inventory before installation

Record, without changing anything:

- Ubuntu release, kernel, hostname, username, and available disk space.
- CPU model, total RAM, swap, GPU(s), and PCI IDs.
- `lspci -k`, `vulkaninfo --summary`, and any NVIDIA/ROCm status available.
- Wired interface name, current IPv4 address, gateway, and DNS.
- Whether Secure Boot is enabled.
- Existing Docker, Python, Git, ComfyUI, InvokeAI, or llama.cpp installations.
- Existing changes under the intended installation directory.

Present a compact inventory and choose the supported compute backend from evidence:

- NVIDIA: current supported NVIDIA driver plus CUDA-enabled PyTorch/backend.
- Supported AMD: official ROCm/PyTorch path for that exact GPU and Ubuntu release.
- Unsupported/older AMD or Intel: Vulkan for llama.cpp and the safest supported
  ComfyUI/InvokeAI fallback; explicitly report limitations.
- CPU-only: install successfully but warn about practical generation speed.

Use current official documentation at execution time. Do not guess a GPU override.

## Phase 2: network and remote control

The Windows main PC shares its working Wi-Fi connection over physical Ethernet.
Keep Ubuntu's wired IPv4 method on Automatic (DHCP). Do not reuse `10.10.10.1`
or `10.10.10.2`, and do not replace Windows ICS addressing with an arbitrary static IP.

1. Verify Ubuntu receives an ICS address, normally `192.168.137.x/24`, with
   gateway and DNS normally at `192.168.137.1`.
2. Verify IP connectivity, DNS resolution, HTTPS downloads, and apt access.
3. Give Ubuntu a sensible hostname such as `ai-server` and enable mDNS/Avahi so
   the main PC can try `ai-server.local`.
4. Also record the assigned numeric address. If DHCP stability is required, prefer
   a Windows-side reservation or a carefully tested NetworkManager profile later.
5. Install and enable OpenSSH Server.
6. Create a dedicated ED25519 key on Windows for this server if one does not exist.
7. Add only its public key to Ubuntu and verify passwordless login before proceeding.
8. Configure Ubuntu's firewall to permit SSH and app ports only from the private
   Ethernet/ICS subnet. Do not expose the services to the public internet.

The user may need to type the Ubuntu password for sudo, approve a Windows elevation
prompt, configure Windows ICS, and accept the first SSH host fingerprint. Point out
each such moment clearly and wait only when interaction is actually required.

## Phase 3: directories and base packages

Use a clean structure under the Ubuntu user's home directory:

```text
~/ai/
  llama.cpp/
  models/llm/
  ComfyUI/
  invokeai/
  logs/
  backups/
```

Install supported versions of Git, build tools, CMake, Ninja, Python tooling,
FFmpeg, curl/wget, jq, Vulkan utilities, archive tools, and required media libraries.
Use separate Python virtual environments for ComfyUI and any non-container InvokeAI
installation. Do not modify Ubuntu's system Python packages with unrestricted pip.

Before installing GPU software, verify that the selected driver/runtime supports the
detected GPU. Do not install both conflicting stacks experimentally.

## Phase 4: llama.cpp without LLM models

Clone the official `ggml-org/llama.cpp` repository and build a release server:

- Use CUDA for a supported NVIDIA GPU.
- Use Vulkan for AMD/Intel when that is the reliable supported path.
- Use the appropriate supported backend discovered during inventory.
- Include HTTPS support for future Hugging Face downloads.
- Confirm `llama-server --help` works.

Create `~/ai/models/llm/`, but leave it empty. Do not start llama-server without a
model and do not download a placeholder model merely to satisfy a health check.

Create a user service template for llama-server with:

- Port `8080`.
- A configurable model path and context size in a separate environment file.
- Binding limited to the private interface where practical.
- Restart-on-failure with a sensible delay, not an infinite rapid crash loop.
- Logs available through `journalctl --user`.
- A clear dashboard state of `NO MODEL CONFIGURED` until the user selects a GGUF.

Retain an Add LLM Model feature that can download a user-supplied Hugging Face GGUF
link later, with progress, cancellation, checksum/size verification, and atomic rename.
Do not prepopulate it with the EVO-X2 models or their API keys.

## Phase 5: ComfyUI

Install the current official ComfyUI into `~/ai/ComfyUI` using the supported PyTorch
build chosen from the hardware inventory. Install ComfyUI-Manager using its current
official instructions and use its supported security configuration for a private,
single-user LAN deployment.

Requirements:

- Port `8188` and a working `/system_stats` health endpoint.
- Inputs, outputs, models, custom nodes, workflows, and manager data persist.
- FFmpeg video input/output works.
- A user service starts and stops cleanly and exposes logs.
- ComfyUI opens from the Windows browser.
- The Manager UI is actually visible; a dashboard link must not pretend it is a
  separate page if the Manager is an in-app menu.
- Hugging Face model download accepts a file URL, infers/asks for the correct ComfyUI
  model folder, displays live progress, verifies completion, and clears stale notices.

Do not automatically download LLM GGUFs. Do not blindly download the former EVO-X2's
MiniMax H3, Flux, SeedVR2, or other multi-gigabyte image/video models. After hardware
validation, present optional compatible model packs and ask the user which to install.
Small application-required assets are allowed.

If these Windows-side workflow backups still exist, copy them into ComfyUI's saved
workflow folder but label missing model/node dependencies honestly:

```text
C:\AI\EVO-X2-Control-Center\1 - SeedVR2 Conservative Restoration.json
C:\AI\EVO-X2-Control-Center\2 - MiniMax H3 Reference Refinement.json
C:\AI\EVO-X2-Control-Center\3 - Targeted Illustrated Face Repair.json
C:\AI\EVO-X2-Control-Center\Video Upscale - Preserve Original x2.json
```

Do not install their large dependencies automatically unless the user approves them
after seeing disk, RAM, VRAM, and estimated runtime requirements.

## Phase 6: InvokeAI

Install InvokeAI using its current official Ubuntu method. Prefer the officially
supported container only if it supports the detected GPU correctly; otherwise use its
supported installer in an isolated environment. Do not reuse an obsolete ROCm tag.

Requirements:

- Persistent data under `~/ai/invokeai` or a clearly documented equivalent.
- Port `9090` and a working application version/health endpoint.
- GPU access verified from inside the runtime/container.
- Models are managed through InvokeAI's own model manager.
- No image-generation model needs to be preinstalled unless InvokeAI requires one;
  present optional starter models after checking hardware compatibility and licensing.
- Start, stop, restart, and log retrieval work without leaving orphaned containers.

## Phase 7: workload controller

Create user-level services and a small controller command such as `ai-workload`.
Enable lingering once with `sudo loginctl enable-linger <user>` so services survive SSH.

The controller must support:

```text
ai-workload status
ai-workload start llm|comfy|invoke
ai-workload stop llm|comfy|invoke|all
ai-workload restart llm|comfy|invoke
ai-workload logs llm|comfy|invoke
```

By default, starting one GPU-heavy app should stop the other GPU-heavy apps first to
avoid VRAM contention. If hardware testing proves safe concurrency, expose it as an
explicit opt-in setting rather than silently changing behavior.

Status must distinguish at least:

- STOPPED
- STARTING
- READY
- BUSY
- STOPPING
- FAILED
- UNKNOWN
- NO MODEL CONFIGURED (llama.cpp)

Use both process/container evidence and HTTP/API evidence. For BUSY, use each app's
actual queue or processing endpoint where available. Never infer BUSY from GPU use alone.

## Phase 8: Windows control dashboard

Preserve the old control center as a backup. Create a separate replacement, for example:

```text
C:\AI\AI-Server-Control-Center\
```

The former implementation is available at:

```text
C:\AI\EVO-X2-Control-Center\
```

Reuse sound implementation ideas, but remove all EVO-X2, Step 3.7, Qwen, MiniMax,
and old IP assumptions. Configure the new host, username, SSH key, and service URLs
in one human-readable configuration file.

Dashboard requirements:

- Three app-style cards: llama.cpp, ComfyUI, and InvokeAI.
- Actual application colors/logos where licensing permits; clear accessible text too.
- Start, Stop, Restart, Open UI, Commands, Logs, and Verify Now.
- One shared Terminal button outside the cards.
- Truthful status plus separate activity status.
- Current GPU/RAM/VRAM/disk/network summary based on live measurements.
- Model download progress for llama.cpp and ComfyUI; no redundant InvokeAI downloader.
- Mobile-friendly responsive layout.

- No stale success banners: completed download messages automatically dismiss but
  remain available in a short history/log.
- No admin prompt for normal dashboard use. Elevate only for a genuinely privileged
  Windows operation.
- A desktop shortcut that starts the local dashboard server if needed and opens it.
- Browser links must use the server's current resolvable address, not `10.10.10.2`.

Do not copy any old API keys. Generate new local secrets only if required, store them
outside source files with restrictive permissions, and never print their values.

## Acceptance checks

Complete and record all applicable checks:

1. Ubuntu reaches the internet through Windows ICS after reconnect/reboot.
2. Windows reaches Ubuntu by hostname and recorded IP.
3. Passwordless SSH works using the dedicated key.
4. Ubuntu firewall allows intended LAN access and rejects unintended exposure.
5. `llama-server --help` succeeds; no GGUF/LLM model exists in the model directory.
6. llama.cpp status is `NO MODEL CONFIGURED`, not FAILED or READY.
7. ComfyUI starts, `/system_stats` responds, the browser UI opens, Manager is visible,
   and a tiny dependency-free diagnostic workflow can execute.
8. InvokeAI starts, its version/health endpoint responds, and its browser UI opens.
9. Start/stop/restart/log commands work for all three services.
10. Starting a mutually exclusive workload safely stops the previous one.
11. Dashboard status matches process/container and HTTP evidence during transitions.
12. Dashboard remains usable at a narrow mobile viewport.
13. Reboot Ubuntu and verify persistence, networking, SSH, and service control.
14. No old EVO-X2 hostname, IP, user, API key, or model path remains in active config.

Do not run a large generation merely to test installation. Use health checks and the
smallest safe diagnostic operation.

## Final handoff report

Return a concise report containing:

- Detected hardware and selected acceleration backend, with supporting evidence.
- Ubuntu hostname, wired IP, and SSH command from Windows.
- Dashboard shortcut and local dashboard URL.
- App URLs for llama.cpp, ComfyUI, and InvokeAI.
- Service names and controller commands.
- Installed versions and filesystem locations.
- Which optional model packs were not installed.
- Acceptance-check results.
- Any limitations caused by the old PC's GPU, RAM, or driver support.
- Every remaining action that specifically requires the user.

## Non-negotiable exclusions

- No Step 3.7 Flash model.
- No Qwen3.5-122B model.
- No other GGUF/LLM model unless the user later explicitly chooses one.
- No reuse or display of the former `STEP37_API_KEY`.
- No modification of the game repository.
- No destructive disk, partition, or unrelated-file operations.
