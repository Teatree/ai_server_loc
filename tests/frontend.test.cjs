const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

test('remote local-only clicks stop before old Windows handlers and show the popup', () => {
  const listeners = {}, alerts = [];
  const button = {disabled: true};
  const window = {alert: text => alerts.push(text), confirm: () => false,
    fetch: () => { throw Error('Local-only button must not send a request'); }};
  const context = {window, MutationObserver: class {observe() {}},
    document: {addEventListener: (type, fn, capture) => {
      assert.equal(capture, true); listeners[type] = fn;
    }, querySelectorAll: () => [button],
    createElement: () => ({append() {}}), querySelector: () => ({after() {}})}};
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../web/remote.js'), 'utf8'), context);
  let prevented = false, stopped = false;
  listeners.click({target: {closest: () => button},
    preventDefault() {prevented = true;}, stopImmediatePropagation() {stopped = true;}});
  assert.equal(button.disabled, false);
  assert.equal(prevented, true);
  assert.equal(stopped, true);
  assert.match(alerts[0], /accessed locally/);
  prevented = stopped = false;
  listeners.click({target: {closest: selector => selector === '[data-action]'
      ? {dataset: {action: 'stop', service: 'invoke'}} : null},
    preventDefault() {prevented = true;}, stopImmediatePropagation() {stopped = true;}});
  assert.equal(prevented, true);
  assert.equal(stopped, true);
});

test('GPU telemetry cannot insert executable markup into the remote dashboard', () => {
  const source = fs.readFileSync(path.join(__dirname, '../web/app.js'), 'utf8');
  const escape = source.match(/function escapeHtml\(value\) \{[\s\S]*?\n\}/)[0];
  const fn = vm.runInNewContext('(' + escape + ')');
  assert.equal(fn('<img src=x onerror="steal()">'), '&lt;img src=x onerror=&quot;steal()&quot;&gt;');
});
