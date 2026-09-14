const catalog = {
  llm: {
    title: "LLAMA.CPP",
    subtitle: "llama.cpp service on port 8080",
    groups: [
      ["Control", `~/.local/bin/ai-workload start llm
~/.local/bin/ai-workload stop llm
~/.local/bin/ai-workload restart llm`],
      ["Verified health", `curl -sS http://127.0.0.1:8080/health
~/.local/bin/ai-workload status`],
      ["Live logs", `~/.local/bin/ai-workload logs llm`],
      ["Dashboard model library", `~/.local/bin/ai-hf-download status llm
Use ADD MODEL in the llama.cpp card for a Hugging Face .gguf file.
The verified GGUF is stored under ~/ai/models/huggingface.`],
      ["OpenAI-compatible endpoint", `Local base URL: http://127.0.0.1:8080/v1
Model list: GET /v1/models
The LAN address is read from the dashboard configuration.`]
    ]
  },
  comfy: {
    title: "COMFYUI",
    subtitle: "Workflow service on port 8188",
    groups: [
      ["Control", `~/.local/bin/ai-workload start comfy
~/.local/bin/ai-workload stop comfy
~/.local/bin/ai-workload restart comfy`],
      ["Verified health", `curl -sS http://127.0.0.1:8188/system_stats
~/.local/bin/ai-workload status`],
      ["Live logs", `~/.local/bin/ai-workload logs comfy`],
      ["Manager UI", `Open ComfyUI from the dashboard.
Inside ComfyUI: Extensions → Model Manager
Downloads started there are saved on the AI server.`],
      ["Dashboard downloads", `~/.local/bin/ai-hf-download status comfy
Use ADD MODEL in the ComfyUI card and paste a Hugging Face file link.
Paused or interrupted downloads retain their partial data for resume.`],
      ["Model folders", `cd ~/ai/ComfyUI
ls -lh models/diffusion_models
ls -lh models/text_encoders
ls -lh models/vae`]
    ]
  },
  unsloth: {
    title: "UNSLOTH",
    subtitle: "Unsloth Studio on port 8888",
    groups: [
      ["Control", `~/.local/bin/ai-workload start unsloth
~/.local/bin/ai-workload stop unsloth
~/.local/bin/ai-workload restart unsloth`],
      ["Verified health", `curl -sS http://127.0.0.1:8888/api/health
~/.local/bin/ai-workload status`],
      ["Installation verification", `unsloth --version
unsloth studio verify-install`],
      ["Live logs", `~/.local/bin/ai-workload logs unsloth`],
      ["Dashboard model library", `~/.local/bin/ai-hf-download status unsloth
Use ADD MODEL in the Unsloth card for a Hugging Face .gguf file.
Verified files are stored under ~/.unsloth/models.`],
      ["Studio address", `Local: http://127.0.0.1:8888
LAN: http://AI_SERVER_LAN_IP:8888
The service does not create a public tunnel.`]
    ]
  },
  invoke: {
    title: "INVOKEAI",
    subtitle: "InvokeAI service on port 9090",
    groups: [
      ["Control", `~/.local/bin/ai-workload start invoke
~/.local/bin/ai-workload stop invoke
~/.local/bin/ai-workload restart invoke`],
      ["Verified health", `curl -sS http://127.0.0.1:9090/api/v1/app/version
~/.local/bin/ai-workload status`],
      ["Live logs", `~/.local/bin/ai-workload logs invoke`],
      ["Container and storage", `docker ps -a --filter name=invokeai
du -sh ~/invokeai
df -h /home`]
    ]
  },
  ollama: {
    title: "OLLAMA",
    subtitle: "Ollama API service on port 11434",
    groups: [
      ["One-time authorization", `sudo bash ~/ai/services/dashboard-install/install-ollama-dashboard-control.sh
This grants the dashboard control of ollama.service only.`],
      ["Control", `~/.local/bin/ai-workload start ollama
~/.local/bin/ai-workload stop ollama
~/.local/bin/ai-workload restart ollama`],
      ["Verified health", `curl -sS http://127.0.0.1:11434/api/tags
~/.local/bin/ai-workload status`],
      ["Installed models", `ollama list
ollama show huihui_ai/qwen3-abliterated:14b
ollama show bge-m3`],
      ["Live logs", `~/.local/bin/ai-workload logs ollama`],
      ["Project settings", `OLLAMA_HOST=http://127.0.0.1:11434
LLM_MODEL=huihui_ai/qwen3-abliterated:14b
EMBED_MODEL=bge-m3`],
      ["LAN endpoint", `Base URL: http://AI_SERVER_LAN_IP:11434
Tags: GET /api/tags
Loaded models: GET /api/ps`]
    ]
  }
};

const params = new URLSearchParams(location.search);
const service = catalog[params.get("service")] || catalog.llm;
document.querySelector("#title").textContent = service.title;
document.querySelector("#subtitle").textContent = service.subtitle;
document.querySelector("#commands").innerHTML = service.groups.map(([name, command], index) =>
  `<article class="command-group"><header><h2>${String(index + 1).padStart(2, "0")} / ${name.toUpperCase()}</h2><button data-copy="${index}">COPY</button></header><pre>${command}</pre></article>`
).join("");

document.querySelector("#commands").addEventListener("click", async event => {
  const button = event.target.closest("[data-copy]");
  if (!button) return;
  const command = service.groups[Number(button.dataset.copy)][1];
  await navigator.clipboard.writeText(command);
  button.textContent = "COPIED";
  setTimeout(() => button.textContent = "COPY", 1300);
});
