const SERVICES = {
  openclaw: {
    name: "OpenClaw", description: "Local agent, tools, and web research",
    url: "/go/openclaw", logo: "assets/openclaw.svg",
    openLabel: "OPEN CONTROL UI ↗", hideCommands: true
  },
  comfy: {
    name: "ComfyUI", description: "Node-based generative workflows",
    url: "/go/comfy", logo: "assets/comfy.svg"
  },
  unsloth: {
    name: "Unsloth", description: "Efficient local model training and inference",
    url: "/go/unsloth", logo: "assets/unsloth.png"
  },
  llm: {
    name: "llama.cpp", description: "Local language model server",
    url: "/go/llm", logo: "assets/llama.svg"
  },
  ollama: {
    name: "Ollama", description: "Local model and embedding runtime",
    url: "/go/ollama", logo: "assets/ollama.png", openLabel: "OPEN API ↗",
    chatUrl: "/go/openwebui", modelManagerUrl: "/go/openwebui-models"
  },
  invoke: {
    name: "InvokeAI", description: "Creative AI workspace",
    url: "/go/invoke", logo: "assets/invoke.svg"
  }
};

const grid = document.querySelector("#service-grid");
const events = document.querySelector("#events");
const pending = new Set();
const downloadStates = {llm: null, comfy: null, unsloth: null};
const lastDownloadPhase = {llm: null, comfy: null, unsloth: null};
const shutdownButton = document.querySelector("#shutdown-button");
let refreshing = false;
let downloadRefreshing = false;
let downloadTarget = "comfy";

function bytes(value) {
  if (value == null) return "—";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let size = Number(value), index = 0;
  while (size >= 1024 && index < units.length - 1) { size /= 1024; index++; }
  return `${size.toFixed(index > 2 ? 1 : 0)} ${units[index]}`;
}

function addEvent(message, tone = "") {
  const stamp = new Date().toLocaleTimeString([], {hour: "2-digit", minute: "2-digit", second: "2-digit"});
  const row = document.createElement("p");
  row.className = tone;
  const time = document.createElement("time");
  time.textContent = stamp;
  row.append(time, document.createTextNode(String(message)));
  events.prepend(row);
  while (events.children.length > 30) events.lastElementChild.remove();
}

function cardMarkup(id, service) {
  const profileControl = "";
  const addModel = ["llm", "comfy", "unsloth"].includes(id)
    ? `<button data-model-download="${id}">ADD MODEL</button>` : "";
  const manageModels = service.modelManagerUrl
    ? `<a href="${service.modelManagerUrl}" target="_blank">ADD MODEL ↗</a>` : "";
  const manager = service.managerUrl
    ? `<a href="${service.managerUrl}" target="_blank">MANAGER ↗</a>` : "";
  const chat = service.chatUrl
    ? `<a href="${service.chatUrl}" target="_blank">CHAT ↗</a>` : "";
  const commands = service.hideCommands ? "" :
    `<a href="commands.html?service=${id}" target="_blank">COMMANDS</a>`;
  return `<article class="service-card ${id}" id="card-${id}">
    <div class="card-top">
      <div class="app-identity"><span class="logo-shell"><img src="${service.logo}" alt=""></span>
        <div><p>APP CONTROL</p><h2>${service.name}</h2><small>${service.description}</small></div></div>
      <div class="badge unknown" data-status>UNKNOWN</div>
    </div>
    <div class="activity-row unknown" data-activity>
      <i></i><div><strong>ACTIVITY UNKNOWN</strong><small>Awaiting app telemetry.</small></div>
    </div>
    <p class="evidence" data-evidence>Awaiting verified process and HTTP evidence…</p>
    <div class="meter"><i data-meter></i></div>
    ${profileControl}
    <div class="primary-actions">
      <button class="power" data-action="start" data-service="${id}">START</button>
      <button data-action="stop" data-service="${id}">STOP</button>
      <button data-action="restart" data-service="${id}">RESTART</button>
    </div>
    <div class="secondary-actions">
      <a href="${service.url}" target="_blank">${service.openLabel || "OPEN APP ↗"}</a>
      ${chat}${addModel}${manageModels}${manager}
      ${commands}
      <button data-logs="${id}">LOGS</button>
    </div>
  </article>`;
}

grid.innerHTML = Object.entries(SERVICES).map(([id, service]) => cardMarkup(id, service)).join("");

const downloadDialog = document.querySelector("#download-dialog");
const downloadForm = document.querySelector("#download-form");
const downloadUrl = document.querySelector("#download-url");
const downloadStart = document.querySelector("#download-start");
const downloadCancel = document.querySelector("#download-cancel");

function completionIsFresh(state) {
  if (!state?.finishedAt) return false;
  const age = Date.now() - new Date(state.finishedAt).getTime();
  return Number.isFinite(age) && age >= 0 && age < 8000;
}

function updateDownloadButton(target, state) {
  const button = document.querySelector(`[data-model-download="${target}"]`);
  if (!button) return;
  if (state?.active) {
    button.classList.add("transferring");
    button.textContent = state.percent == null ? "DOWNLOADING…" : `MODEL ${Number(state.percent).toFixed(0)}%`;
  } else if (state?.phase === "done" && completionIsFresh(state)) {
    button.classList.remove("transferring");
    button.textContent = "INSTALLED ✓";
  } else {
    button.classList.remove("transferring");
    button.textContent = "ADD MODEL";
  }
}

function renderDownloadModal() {
  const state = downloadStates[downloadTarget] || {phase: "idle"};
  const app = SERVICES[downloadTarget].name;
  const active = Boolean(state.active);
  const staleDone = state.phase === "done" && !completionIsFresh(state);
  const phase = staleDone ? "idle" : (state.phase || "idle");
  const labels = {idle: "READY FOR A LINK", starting: "PREPARING DOWNLOAD",
    downloading: "DOWNLOADING TO SERVER", verifying: "VERIFYING INTEGRITY",
    done: "INSTALLED AND VERIFIED", failed: "DOWNLOAD FAILED",
    cancelled: "DOWNLOAD PAUSED", unknown: "STATUS UNVERIFIED"};
  document.querySelector("#download-app").textContent = app;
  document.querySelector("#download-title").textContent = `Add a model to ${app}`;
  const downloadHelp = {
    comfy: "Paste a Hugging Face model file link. Its ComfyUI folder is inferred and the file is verified.",
    llm: "Paste a Hugging Face .gguf file link. It is verified and stored in the llama.cpp model library.",
    unsloth: "Paste a Hugging Face .gguf file link. It is verified and stored in Unsloth's local model library."
  };
  document.querySelector("#download-help").textContent = downloadHelp[downloadTarget];
  const readout = document.querySelector("#download-readout");
  readout.dataset.phase = phase;
  document.querySelector("#download-label").textContent = labels[phase] || labels.unknown;
  document.querySelector("#download-percent").textContent = state.percent == null || staleDone
    ? "—" : `${Number(state.percent).toFixed(1)}%`;
  document.querySelector("#download-progress").value = state.percent == null || staleDone ? 0 : state.percent;
  const size = state.expectedBytes
    ? `${bytes(state.downloadedBytes)} / ${bytes(state.expectedBytes)}` : "No active transfer";
  document.querySelector("#download-detail").textContent = staleDone
    ? "Ready for another Hugging Face link."
    : state.error ? `${state.message || "Download failed."} ${state.error}`
      : `${state.message || "Ready for another Hugging Face link."} ${size}`.trim();
  document.querySelector("#download-file").textContent = staleDone ? "" : (state.fileName || "");
  downloadStart.disabled = active;
  downloadUrl.disabled = active;
  downloadCancel.hidden = !active;
}

function openDownload(target) {
  downloadTarget = target;
  downloadUrl.value = "";
  renderDownloadModal();
  downloadDialog.showModal();
}

async function fetchDownloadState(target) {
  const response = await fetch(`/api/model-download?target=${target}`, {cache: "no-store"});
  const result = await response.json();
  if (!response.ok || !result.ok) throw new Error(result.error || "Download status unavailable");
  return result;
}

async function refreshDownloads() {
  if (downloadRefreshing) return;
  downloadRefreshing = true;
  await Promise.all(["llm", "comfy", "unsloth"].map(async target => {
    try {
      const state = await fetchDownloadState(target);
      const previous = lastDownloadPhase[target];
      downloadStates[target] = state;
      updateDownloadButton(target, state);
      if (previous && previous !== state.phase) {
        if (state.phase === "done") addEvent(`${state.fileName} installed and verified on the AI server.`, "good");
        if (state.phase === "failed") addEvent(`${SERVICES[target].name} model download failed: ${state.error || state.message}`, "bad");
      }
      lastDownloadPhase[target] = state.phase;
    } catch (error) {
      downloadStates[target] = {phase: "unknown", error: error.message};
      updateDownloadButton(target, downloadStates[target]);
    }
  }));
  if (downloadDialog.open) renderDownloadModal();
  downloadRefreshing = false;
}

async function startDownload(event) {
  event.preventDefault();
  const url = downloadUrl.value.trim();
  downloadStart.disabled = true;
  addEvent(`${SERVICES[downloadTarget].name} model download requested. No completion assumed.`);
  try {
    const response = await fetch("/api/model-download", {method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({target: downloadTarget, url})});
    const result = await response.json();
    if (!response.ok || !result.ok) throw new Error(result.error || "Download could not start");
    downloadStates[downloadTarget] = result;
    renderDownloadModal();
    updateDownloadButton(downloadTarget, result);
    addEvent(`${result.fileName} transfer started on the AI server.`, "good");
  } catch (error) {
    addEvent(`Download rejected: ${error.message}`, "bad");
    await refreshDownloads();
  }
}

async function cancelDownload() {
  downloadCancel.disabled = true;
  try {
    const response = await fetch("/api/model-download/cancel", {method: "POST",
      headers: {"Content-Type": "application/json"}, body: JSON.stringify({target: downloadTarget})});
    const result = await response.json();
    if (!response.ok || !result.ok) throw new Error(result.error || "Download could not be paused");
    downloadStates[downloadTarget] = result;
    renderDownloadModal();
    addEvent("Model download paused. Its partial file is retained for resume.");
  } catch (error) { addEvent(error.message, "bad"); }
  finally { downloadCancel.disabled = false; }
}

function renderActivity(card, activity) {
  const row = card.querySelector("[data-activity]");
  const state = activity?.state || "unknown";
  row.className = `activity-row ${state}`;
  row.querySelector("strong").textContent = activity?.label || "ACTIVITY UNKNOWN";
  row.querySelector("small").textContent = activity?.evidence || "No live activity evidence.";
}

function metric(value, suffix = "") {
  return value == null ? "UNAVAILABLE" : `${Number(value).toFixed(0)}${suffix}`;
}

function temperatureTone(value, kind) {
  if (value == null) return "unknown";
  const warning = kind === "cpu" ? 80 : 75;
  const critical = kind === "cpu" ? 90 : 85;
  return value >= critical ? "critical" : value >= warning ? "warning" : "normal";
}

function renderTemperature(element, value, kind) {
  element.textContent = metric(value, "°C");
  element.title = kind === "cpu" ? "Orange at 80°C; red at 90°C."
    : "Orange at 75°C; red at 85°C.";
  element.classList.remove("temperature-normal", "temperature-warning",
    "temperature-critical", "temperature-unknown");
  element.classList.add(`temperature-${temperatureTone(value, kind)}`);
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, char => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"
  })[char]);
}

function gpuMarkup(gpu) {
  const usage = gpu.utilization == null ? 0 : Math.max(0, Math.min(100, gpu.utilization));
  const memory = gpu.memoryPercent == null ? 0 : Math.max(0, Math.min(100, gpu.memoryPercent));
  const identity = [gpu.vendor, gpu.driver, gpu.busId].filter(Boolean).join(" · ");
  const fan = gpu.fanRpm === 0 && gpu.fanPercent === 0 ? "STOPPED (0 RPM / 0%)"
    : gpu.fanRpm != null && gpu.fanPercent != null
      ? `${metric(gpu.fanRpm, " RPM")} (${metric(gpu.fanPercent, "%")})`
      : gpu.fanRpm != null ? metric(gpu.fanRpm, " RPM")
        : gpu.fanPercent === 0 ? "STOPPED (0%)"
          : gpu.fanPercent != null ? metric(gpu.fanPercent, "%") : "UNAVAILABLE";
  const temperature = metric(gpu.temperatureC, "°C");
  const temperatureClass = `temperature-${temperatureTone(gpu.temperatureC, "gpu")}`;
  const memoryText = gpu.memoryTotal
    ? `${bytes(gpu.memoryUsed || 0)} / ${bytes(gpu.memoryTotal)}` : "Dedicated VRAM unreported";
  return `<article class="gpu-row ${escapeHtml(gpu.state || "unknown")}">
    <div class="gpu-index"><span>GPU</span><strong>${escapeHtml(String(gpu.index).padStart(2, "0"))}</strong></div>
    <div class="gpu-identity"><small>${escapeHtml(identity || "IDENTITY UNAVAILABLE")}</small>
      <h3>${escapeHtml(gpu.name || "Unknown graphics device")}</h3><p>${escapeHtml(gpu.backend || "Telemetry source unavailable")}</p></div>
    <div class="gpu-gauge"><div><span>CORE LOAD</span><strong>${metric(gpu.utilization, "%")}</strong></div>
      <progress max="100" value="${usage}"></progress></div>
    <div class="gpu-gauge"><div><span>VRAM</span><strong>${memoryText}</strong></div>
      <progress max="100" value="${memory}"></progress></div>
    <div class="gpu-vitals"><span>THERMAL / POWER / FAN</span><strong><b class="${temperatureClass}" title="Orange at 75°C; red at 85°C.">${temperature}</b> / ${metric(gpu.powerWatts, " W")} / ${fan}</strong>
      <small>${gpu.state === "busy" ? "ACTIVE" : gpu.state === "idle" ? "IDLE" : "UNVERIFIED"}</small></div>
  </article>`;
}

function renderGpus(gpus) {
  const list = document.querySelector("#gpu-list");
  const summary = document.querySelector("#gpu-summary");
  if (!Array.isArray(gpus) || !gpus.length) {
    list.innerHTML = '<p class="gpu-empty">No GPU inventory received. The dashboard will not infer a device.</p>';
    summary.textContent = "NO VERIFIED GPU DATA";
    return;
  }
  list.innerHTML = gpus.map(gpuMarkup).join("");
  const busy = gpus.filter(gpu => gpu.state === "busy").length;
  summary.textContent = `${gpus.length} DEVICE${gpus.length === 1 ? "" : "S"} · ${busy} ACTIVE`;
}

function renderStatus(data) {
  const host = document.querySelector("#host-state");
  host.className = `host-state ${data.ssh.ok ? "ready" : "unknown"}`;
  host.querySelector("strong").textContent = data.ssh.ok ? "AI SERVER ONLINE" : "CONTROL UNREACHABLE";
  host.querySelector("small").textContent = data.ssh.ok
    ? `SSH ${data.ssh.latencyMs} ms · verified ${new Date(data.checkedAt).toLocaleTimeString()}`
    : `HTTP may still work · ${data.ssh.error || "SSH failed"}`;
  shutdownButton.disabled = !data.ssh.ok;
  const remoteButton = document.querySelector("#open-remote");
  const remoteReady = Boolean(data.remoteDesktop?.ok);
  remoteButton.disabled = !data.ssh.ok;
  remoteButton.classList.toggle("ready", remoteReady);
  remoteButton.classList.toggle("needs-repair", data.ssh.ok && !remoteReady);
  remoteButton.textContent = remoteReady ? "▣ REMOTE DESKTOP" : "↻ REPAIR / OPEN RDP";
  remoteButton.title = remoteReady
    ? `RDP verified on ${data.controlHost}:${data.remoteDesktop.port}`
    : "Click to repair Remote Desktop, authenticate with Ubuntu sudo, and open RDP.";
  const info = data.host || {};
  const cpu = info.cpu || {};
  const cpuName = String(cpu.model || "").replace(/\s+CPU\s+@.*$/i, "")
    .replace("Intel(R) Core(TM)", "Intel").replace("AMD Ryzen", "Ryzen");
  document.querySelector("#server-address").textContent = `REMOTE AI OPERATIONS / ${data.controlHost || "UNRESOLVED"}`;
  document.querySelector("#cpu-model").textContent = cpuName
    ? `${cpuName} · ${cpu.logicalCores || "?"}T` : "UNVERIFIED";
  document.querySelector("#cpu-load").textContent = metric(cpu.utilization, "%");
  renderTemperature(document.querySelector("#cpu-temp"), cpu.temperatureC, "cpu");
  document.querySelector("#cpu-fan").textContent = metric(cpu.fanRpm, " RPM");
  const memoryUsed = info.memoryTotal && info.memoryAvailable != null
    ? info.memoryTotal - info.memoryAvailable : null;
  document.querySelector("#memory").textContent = memoryUsed != null
    ? `${bytes(memoryUsed)} / ${bytes(info.memoryTotal)}` : "UNVERIFIED";
  const knownGpuMemory = (info.gpus || []).filter(gpu => gpu.memoryTotal);
  const gpuUsed = knownGpuMemory.reduce((total, gpu) => total + (gpu.memoryUsed || 0), 0);
  const gpuTotal = knownGpuMemory.reduce((total, gpu) => total + gpu.memoryTotal, 0);
  document.querySelector("#gtt").textContent = gpuTotal ? `${bytes(gpuUsed)} / ${bytes(gpuTotal)}` : "UNVERIFIED";
  document.querySelector("#disk").textContent = bytes(info.diskFree);
  const activeNames = data.active.map(id => SERVICES[id]?.name || id);
  document.querySelector("#load").textContent = activeNames.length
    ? activeNames.join(" + ").toUpperCase() : "NONE";
  renderGpus(info.gpus);
  const alert = document.querySelector("#alert");
  const warnings = [];
  const conflictNames = (data.conflicting || []).map(id => SERVICES[id]?.name || id);
  if (data.conflict) warnings.push(`<b>GPU MEMORY CONFLICT</b> ${escapeHtml(conflictNames.join(" and "))} are simultaneously active. Starting another GPU workload will stop the others.`);
  alert.classList.toggle("hidden", warnings.length === 0);
  alert.innerHTML = warnings.join("<br>");

  for (const [id, state] of Object.entries(data.services)) {
    const card = document.querySelector(`#card-${id}`);
    if (!card) continue;
    const badge = card.querySelector("[data-status]");
    const displayState = pending.has(id) ? "verifying" : state.state;
    badge.className = `badge ${displayState}`;
    badge.textContent = pending.has(id) ? "VERIFYING COMMAND" : state.label;
    card.dataset.state = displayState;
    renderActivity(card, state.activity);
    card.querySelector("[data-evidence]").textContent = pending.has(id)
      ? "Command sent. Waiting for independent process and HTTP verification…"
      : state.evidence;
    card.querySelector("[data-meter]").style.width = state.state === "ready" ? "100%" : state.running ? "52%" : "0%";
    const controlBlocked = id === "ollama" && state.controlAuthorized === false;
    card.querySelector('[data-action="start"]').disabled = controlBlocked || pending.has(id) || state.state === "ready";
    card.querySelector('[data-action="stop"]').disabled = controlBlocked || pending.has(id) || (!state.running && !state.probe.ok);
    card.querySelector('[data-action="restart"]').disabled = controlBlocked || pending.has(id);
    if (pending.has(id) && ["ready", "stopped", "degraded"].includes(state.state)) pending.delete(id);
  }
}

async function refreshStatus(manual = false) {
  if (refreshing) return;
  refreshing = true;
  document.querySelector("#refresh").classList.add("working");
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 20000);
  try {
    const response = await fetch("/api/status", {cache: "no-store", signal: controller.signal});
    if (!response.ok) throw new Error(`Dashboard backend returned ${response.status}`);
    const data = await response.json();
    renderStatus(data);
    window.dashboardStatus?.(data);
    if (manual) addEvent("Live state verified from the AI server.", "good");
  } catch (error) {
    window.dashboardStatus?.(null, error);
    const host = document.querySelector("#host-state");
    host.className = "host-state unknown";
    host.querySelector("strong").textContent = "DASHBOARD DISCONNECTED";
    host.querySelector("small").textContent = error.message;
    document.querySelector("#open-remote").disabled = true;
    shutdownButton.disabled = true;
    for (const id of ["cpu-model", "cpu-load", "cpu-temp", "cpu-fan", "memory", "gtt", "disk", "load"]) {
      document.querySelector(`#${id}`).textContent = "UNVERIFIED";
    }
    document.querySelectorAll("[data-action]").forEach(button => { button.disabled = true; });
    for (const id of Object.keys(SERVICES)) {
      const card = document.querySelector(`#card-${id}`);
      card.dataset.state = "unknown";
      card.querySelector("[data-status]").className = "badge unknown";
      card.querySelector("[data-status]").textContent = "UNKNOWN";
      card.querySelector("[data-evidence]").textContent = "Live verification unavailable; previous state has expired.";
      card.querySelector("[data-meter]").style.width = "0%";
      renderActivity(card, null);
    }
    renderGpus(null);
    if (manual) addEvent(`Verification failed: ${error.message}`, "bad");
  } finally {
    clearTimeout(timeout);
    refreshing = false;
    document.querySelector("#refresh").classList.remove("working");
  }
}

async function action(service, verb) {
  pending.add(service);
  addEvent(`${verb.toUpperCase()} requested for ${SERVICES[service].name}. No success assumed yet.`);
  const card = document.querySelector(`#card-${service}`);
  card.querySelector("[data-status]").className = "badge verifying";
  card.querySelector("[data-status]").textContent = "VERIFYING COMMAND";
  card.querySelector("[data-evidence]").textContent = "Command in progress. No readiness has been assumed.";
  try {
    const response = await fetch("/api/action", {method: "POST", headers: {"Content-Type": "application/json"},
      body: JSON.stringify({service, action: verb})});
    const result = await response.json();
    if (!response.ok || !result.ok) throw new Error(result.error || result.message || "Remote command failed");
    addEvent(`${result.message} Independent verification is running.`, "good");
  } catch (error) {
    pending.delete(service);
    addEvent(`${SERVICES[service].name}: ${error.message}`, "bad");
  }
  await refreshStatus();
  setTimeout(refreshStatus, 1200);
}

async function openTerminal() {
  try {
    const response = await fetch("/api/terminal", {method: "POST", headers: {"Content-Type": "application/json"},
      body: JSON.stringify({service: "system"})});
    const result = await response.json();
    if (!response.ok || !result.ok) throw new Error(result.error || "Could not open terminal");
    addEvent("AI server SSH terminal requested.");
  } catch (error) { addEvent(error.message, "bad"); }
}

async function openRemoteDesktop() {
  try {
    const response = await fetch("/api/remote-desktop", {method: "POST",
      headers: {"Content-Type": "application/json"}, body: "{}"});
    const result = await response.json();
    if (!response.ok || !result.ok) throw new Error(result.error || "Remote Desktop could not open");
    addEvent(result.message, "good");
  } catch (error) { addEvent(error.message, "bad"); }
}

async function requestShutdown() {
  shutdownButton.disabled = true;
  shutdownButton.classList.add("working");
  addEvent("Opening an administrator PowerShell for authenticated shutdown.");
  try {
    const response = await fetch("/api/host/shutdown", {method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({confirmation: "SHUTDOWN AI SERVER"})});
    const result = await response.json();
    if (!response.ok || !result.ok) throw new Error(result.error || "PowerShell could not open.");
    addEvent(result.message, "good");
  } catch (error) { addEvent(error.message, "bad"); }
  finally {
    shutdownButton.classList.remove("working");
    setTimeout(refreshStatus, 1200);
  }
}

async function showLogs(service) {
  const dialog = document.querySelector("#logs-dialog");
  document.querySelector("#logs-title").textContent = `${SERVICES[service].name} logs`;
  document.querySelector("#logs-output").textContent = "Loading verified remote output…";
  dialog.showModal();
  try {
    const response = await fetch(`/api/logs/${service}`, {cache: "no-store"});
    const result = await response.json();
    document.querySelector("#logs-output").textContent = result.output || result.error || "No output.";
  } catch (error) { document.querySelector("#logs-output").textContent = error.message; }
}

grid.addEventListener("click", event => {
  const actionButton = event.target.closest("[data-action]");
  if (actionButton) action(actionButton.dataset.service, actionButton.dataset.action);
  const downloadButton = event.target.closest("[data-model-download]");
  if (downloadButton) openDownload(downloadButton.dataset.modelDownload);
  const logButton = event.target.closest("[data-logs]");
  if (logButton) showLogs(logButton.dataset.logs);
});

document.querySelector("#refresh").addEventListener("click", () => refreshStatus(true));
document.querySelector("#open-terminal").addEventListener("click", openTerminal);
document.querySelector("#open-remote").addEventListener("click", openRemoteDesktop);
shutdownButton.addEventListener("click", requestShutdown);
document.querySelector("#clear-events").addEventListener("click", () => events.innerHTML = "<p>Activity display cleared.</p>");
document.querySelector("#close-logs").addEventListener("click", () => document.querySelector("#logs-dialog").close());
document.querySelector("#close-download").addEventListener("click", () => downloadDialog.close());
downloadForm.addEventListener("submit", startDownload);
downloadCancel.addEventListener("click", cancelDownload);

refreshStatus();
refreshDownloads();
setInterval(refreshStatus, 4000);
setInterval(refreshDownloads, 3000);
