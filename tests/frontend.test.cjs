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

function statusPage(fetch) {
  const nodes = Object.fromEntries(['connection-status','connection-title','connection-detail']
    .map(id => ['#'+id, {dataset:{},textContent:''}]));
  const window = {};
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../web/status.js'), 'utf8'),
    {window,document:{querySelector:id=>nodes[id]},fetch,AbortController,setTimeout,clearTimeout});
  return {nodes,update:window.dashboardStatus};
}

test('remote status distinguishes a disconnected bridge, local failure, and expired login', async () => {
  let connected = false, status = 200;
  const page = statusPage(async () => ({ok:status===200,status,json:async()=>({connected})}));
  await page.update(null, Error('Unavailable'));
  assert.match(page.nodes['#connection-title'].textContent,/WINDOWS CONNECTOR OFFLINE/);
  assert.match(page.nodes['#connection-detail'].textContent,/Start-Connector.ps1/);
  connected = true;
  await page.update(null, Error('502'));
  assert.match(page.nodes['#connection-title'].textContent,/CONNECTOR ONLINE/);
  status = 401;
  await page.update(null);
  assert.match(page.nodes['#connection-title'].textContent,/SIGN IN AGAIN/);
});

test('fresh running app status wins over an older delayed connection failure', async () => {
  let resolve;
  const page = statusPage(() => new Promise(done => {resolve=done;}));
  const failure = page.update(null);
  await page.update({ssh:{ok:true},checkedAt:new Date().toISOString(),
    services:{unsloth:{running:true,activity:{label:'MODEL READY'}},comfy:{running:false}}});
  resolve({ok:true,status:200,json:async()=>({connected:false})});
  await failure;
  assert.equal(page.nodes['#connection-status'].dataset.state,'live');
  assert.match(page.nodes['#connection-detail'].textContent,/UNSLOTH \(MODEL READY\)/);
  assert.doesNotMatch(page.nodes['#connection-detail'].textContent,/COMFY/);
  await page.update({ssh:{ok:false},services:{}});
  assert.match(page.nodes['#connection-title'].textContent,/AI SERVER UNREACHABLE/);
  assert.doesNotMatch(page.nodes['#connection-detail'].textContent,/No managed apps/);
});

test('failed status clears old load readings and prevents controls on unknown state', async () => {
  const source = fs.readFileSync(path.join(__dirname, '../web/app.js'), 'utf8');
  const refresh = source.match(/async function refreshStatus\(manual = false\) \{[\s\S]*?\n\}/)[0];
  const nodes = new Map(), buttons = [{disabled:false}];
  const element = id => {
    if (!nodes.has(id)) nodes.set(id, {textContent:'OLD READING',classList:{add(){},remove(){}},
      querySelector:child=>element(id+' '+child)});
    return nodes.get(id);
  };
  const context = {refreshing:false,document:{querySelector:element,querySelectorAll:()=>buttons},
    AbortController,setTimeout,clearTimeout,fetch:async()=>({ok:false,status:503}),
    window:{dashboardStatus(){}},shutdownButton:{disabled:false},SERVICES:{},renderGpus(){}};
  await vm.runInNewContext(refresh+'\nrefreshStatus()',context);
  for (const id of ['cpu-load','memory','gtt','disk','load']) {
    assert.equal(element('#'+id).textContent,'UNVERIFIED');
  }
  assert.equal(buttons[0].disabled,true);
  assert.equal(context.refreshing,false);
});
