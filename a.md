# AI Server Access Handoff for Claude

Verified from the Windows control PC on 2026-08-24. This is the current Ubuntu AI server, not the retired EVO-X2 endpoint.

## Current server

- Host/IP: `teatree-MS-7998` / `192.168.137.54`
- Ubuntu user: `teatree`
- Network: private Windows ICS Ethernet subnet `192.168.137.0/24`; Windows gateway `192.168.137.1`
- SSH key: `C:\Users\Garry\.ssh\id_ed25519_ai_server`
- SSH command: `ssh -i "$env:USERPROFILE\.ssh\id_ed25519_ai_server" teatree@192.168.137.54`
- Hardware: i7-6700K, about 48 GiB RAM, AMD Radeon AI PRO R9700 with about 32 GiB VRAM
- Server files: `/home/teatree/ai/`

Passwordless SSH was verified. These are private-LAN services without TLS; do not expose their ports to the public Internet.

## Direct Claude Code access

Ollama 0.30.10 provides an Anthropic-compatible `/v1/messages` API, so Claude Code needs no proxy. In PowerShell:

```powershell
$env:ANTHROPIC_BASE_URL = "http://192.168.137.54:11434"
$env:ANTHROPIC_AUTH_TOKEN = "ollama-local"
Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
claude --model "gemma4:e4b"
```

`ollama-local` is a non-secret placeholder required by Claude; this private Ollama endpoint does not validate it. Verified test:

```powershell
claude -p --model "gemma4:e4b" "Reply with exactly: CLAUDE_SERVER_OK"
```

This exact test passed from Claude Code 2.1.220 on 2026-08-24.

## APIs and models

- Anthropic: `http://192.168.137.54:11434/v1/messages`
- OpenAI: `http://192.168.137.54:11434/v1/chat/completions`
- Ollama: `http://192.168.137.54:11434/api/chat`
- Inventory: `http://192.168.137.54:11434/api/tags`
- Open WebUI: `http://192.168.137.54:3000`

Installed Ollama models:

- `gemma4:e4b` — 8B, tools/thinking; verified with Claude Code
- `gemma4-openclaw:latest` — 8B, tools/thinking
- `huihui_ai/qwen3-abliterated:14b` — 14.8B, tools/thinking, 40,960 context
- `hf.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF:Q4_K_M` — 27.3B, completion, 262,144 context
- `bge-m3:latest` — embedding model, 8,192 context

## Administration and other services

After SSH login, use the full controller path:

```bash
~/.local/bin/ai-workload status
~/.local/bin/ai-workload start llm|comfy|invoke
~/.local/bin/ai-workload stop llm|comfy|invoke|all
~/.local/bin/ai-workload restart llm|comfy|invoke
~/.local/bin/ai-workload logs llm|comfy|invoke
```

Current verified state: Ollama and Open WebUI are running; llama.cpp, ComfyUI, and InvokeAI are stopped. Starting a GPU-heavy managed workload may stop a conflicting one.

- llama.cpp: port `8080`, OpenAI base `/v1`; configured alias `qwen3.6-35b-a3b-heretic-apex`, context 16,384, currently stopped
- ComfyUI: `http://192.168.137.54:8188`, health `/system_stats`, currently stopped
- InvokeAI: `http://192.168.137.54:9090`, health `/api/v1/app/version`, currently stopped
- Remote Desktop: `192.168.137.54:3389`, username `teatree`; use the Ubuntu account password
- Windows dashboard: launch `C:\AI\AI-Server-Control-Center\Launch-AI-Server-Control-Center.ps1`, then open `http://127.0.0.1:32146/`

llama.cpp uses `/home/teatree/ai/models/llm/active.gguf`, currently linked to `Qwen3.6-35B-A3B-uncensored-heretic-Native-MTP-Preserved-APEX-I-Quality.gguf`. Its runtime settings are in `/home/teatree/ai/services/llama-server.env`; its user service is `ai-llama.service`.

## Security and changing addresses

SSH is authenticated by the dedicated private key. Ollama and llama.cpp currently rely on LAN isolation rather than API authentication. Open WebUI has its own login. Do not copy passwords or private-key contents into prompts. If DHCP changes the address, read `C:\AI\AI-Server-Control-Center\config.json` and replace `192.168.137.54` in the commands above.

## Legacy EVO-X2 server

The former server was `http://10.10.10.2:8080/v1`, using the OpenCode model ID `evox2/step-3.7-flash` and an API key stored as the user environment variable `STEP37_API_KEY`. Its provider definition is in `C:\Users\Garry\.config\opencode\opencode.json`. Never paste the key into this document; Claude can read the environment variable when needed. The old host was unreachable during this verification and its direct `10.10.10.x` network is no longer configured, so prefer the current Ubuntu/Ollama endpoint.

## Work completed with the AI setup

The old EVO-X2 Step 3.7/OpenCode workflow ran the Ralph story loop for the Godot project `D:\_projects\local_llm_evo_x2_test`. It completed every PRD story from S00 through S13B. The work included repository stabilization; title flow; advanced movement; health/death/respawn; pistol, shotgun, rifle, melee, inventory and reload systems; four zombie archetypes; navigation, arena hazards and pickups; encounter director and final holdout; upgrades; versioned saves; HUD, camera, combat feedback, audio, debug/performance tools; integration testing; and release documentation. The final story commit is `edeb7bd` (`story(S13B): finalize documentation and release baseline`).

The replacement Ubuntu server work installed and configured llama.cpp, Ollama, Open WebUI, ComfyUI, InvokeAI, SSH, RDP, workload services, health checks, hardware telemetry, model storage, and the Windows control dashboard. At verification time, SSH, RDP, Ollama, Open WebUI, Ollama native chat, OpenAI chat completions, Anthropic messages, and an end-to-end Claude Code request all worked.
