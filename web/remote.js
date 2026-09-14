"use strict";
// Capture before existing local handlers; the backend independently rejects these routes.
const localButtons = "#open-terminal, #open-remote, #shutdown-button";
document.addEventListener("click", event => {
  if (event.target.closest(localButtons)) {
    event.preventDefault();
    event.stopImmediatePropagation();
    window.alert("This action must be accessed locally on your Windows computer.");
    return;
  }
  const action = event.target.closest("[data-action]");
  if (action && !window.confirm(
    `${action.dataset.action.toUpperCase()} ${action.dataset.service}? ` +
    "Starting an app may stop another GPU workload under your existing controller rules.")) {
    event.preventDefault();
    event.stopImmediatePropagation();
  }
}, true);
for (const button of document.querySelectorAll(localButtons)) {
  button.disabled = false;
  button.title = "Available only on the Windows computer";
  new MutationObserver(() => {
    if (button.disabled) button.disabled = false;
  }).observe(button, {attributes: true, attributeFilter: ["disabled"]});
}
const banner = document.createElement("p");
banner.textContent = "REMOTE ACCESS · App logins remain enabled · ";
const account = document.createElement("a");
account.href = "/_gateway";
account.textContent = "Session / sign out";
banner.append(account);
document.querySelector(".masthead").after(banner);
// Do not silently replay fetches after a logout or Render restart.
const originalFetch = window.fetch.bind(window);
let expired = false;
window.fetch = async (...args) => {
  const response = await originalFetch(...args);
  if (response.status === 401 && !expired) {
    expired = true;
    banner.textContent = "Session expired. Reload this page to sign in again. No action was retried.";
  }
  return response;
};
