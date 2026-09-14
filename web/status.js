"use strict";
(() => {
  const panel = document.querySelector("#connection-status");
  const title = document.querySelector("#connection-title");
  const detail = document.querySelector("#connection-detail");
  let generation = 0;
  function display(state, heading, message) {
    panel.dataset.state = state;
    title.textContent = heading;
    detail.textContent = message;
  }
  window.dashboardStatus = async (data, error) => {
    const current = ++generation;
    if (data) {
      if (!data.ssh?.ok) {
        display("offline", "CONNECTED TO WINDOWS · AI SERVER UNREACHABLE",
          "The connector is online, but server load could not be verified. Check the AI server's power and private network connection.");
        return;
      }
      const running = Object.entries(data.services || {}).filter(([, app]) => app.running);
      const names = running.map(([id, app]) => `${id.toUpperCase()} (${app.activity?.label || app.label || "running"})`);
      const checked = new Date(data.checkedAt).toLocaleTimeString();
      display("live", "LIVE AI SERVER DATA",
        `${names.length ? "Running: " + names.join(" · ") : "No managed apps are running."} · Last verified ${checked}. Load readings below refresh automatically.`);
      return;
    }
    display("offline", "LIVE SERVER DATA UNAVAILABLE",
      "Readings and app states are unknown until the connection returns. Checking the Windows connector…");
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    try {
      const response = await fetch("/_gateway/info", {cache:"no-store", signal:controller.signal});
      if (current !== generation) return;
      if (response.status === 401) {
        display("offline", "SIGN IN AGAIN", "Your session expired. Reload this page to sign in and restore live status.");
        return;
      }
      if (!response.ok) throw Error("Gateway unavailable");
      const info = await response.json();
      if (current !== generation) return;
      display("offline", info.connected ? "CONNECTOR ONLINE · STATUS UNAVAILABLE" : "WINDOWS CONNECTOR OFFLINE",
        info.connected ? "The remote connection is open, but the local dashboard is not returning status. Keep AI Server Control Center open on Windows. " + (error?.message || "")
          : "The website is online, but it cannot reach your AI server. On Windows, run C:\\AI\\AI-Server-Remote-Gateway\\Start-Connector.ps1 and keep it running. Your AI workloads may still be running normally.");
    } catch {
      if (current === generation) display("offline", "REMOTE CONNECTION UNAVAILABLE",
        "Render or your network is not responding. Live load and app status are unknown; this does not mean your AI workloads stopped.");
    } finally { clearTimeout(timer); }
  };
})();
