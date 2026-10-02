/* Model lifecycle controls are independent of app start/stop and metrics. */
(() => {
  'use strict';
  const local = ['127.0.0.1','localhost'].includes(location.hostname);
  const base = local ? 'http://127.0.0.1:32150' : '';
  const panels = new Map();
  let pending = false, reading = false;
  const el = (tag, text, className) => {
    const node = document.createElement(tag);
    if (text !== undefined) node.textContent = text;
    if (className) node.className = className;
    return node;
  };
  function button(label, action) {
    const node = el('button',label); node.type = 'button';
    node.addEventListener('click',action); return node;
  }
  for (const card of document.querySelectorAll('.service-card')) {
    const app = card.id.replace('card-','');
    const section = el('section',undefined,'loaded-models');
    section.setAttribute('aria-label','Loaded models');
    const heading = el('div',undefined,'models-heading');
    heading.append(el('h3','Loaded models'),button('Refresh',() => refresh(true)));
    const content = el('div','Reading model status…','models-content');
    const notice = el('p','','models-notice'); notice.setAttribute('role','status');
    section.append(heading,content,notice); card.append(section);
    panels.set(app,{section,content,notice,last:''});
  }
  async function request(path, payload) {
    const controller = new AbortController(), timer = setTimeout(() => controller.abort(),75000);
    try {
      const response = await fetch(base+path,{signal:controller.signal,cache:'no-store',
        ...(payload ? {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)} : {})});
      if (response.status===401) throw Error('Sign in again, then refresh. No action was retried.');
      const data = await response.json().catch(() => ({}));
      if (!response.ok || !data.ok) throw Error(data.error || 'Model connection unavailable. Refresh before retrying.');
      return data;
    } finally { clearTimeout(timer); }
  }
  function memory(model) {
    const size = n => (n/1024**3).toFixed(1)+' GiB';
    const parts = [];
    if (Number.isFinite(model.bytes)) parts.push(size(model.bytes)+' resident');
    if (Number.isFinite(model.vram_bytes)) parts.push(size(model.vram_bytes)+' VRAM');
    return parts.length ? parts.join(' · ') : 'Memory not reported';
  }
  function action(app, keys, label) {
    return button(label,() => unload(app,keys));
  }
  function render(app, state) {
    const panel = panels.get(app);
    if (!panel || panel.last===JSON.stringify(state)) return;
    panel.last = JSON.stringify(state);
    const body = panel.content; body.replaceChildren();
    if (!state.online) { body.append(el('p',state.note)); return; }
    if (state.provider) {
      body.append(el('p',state.note));
      const link = el('a','View Ollama models'); link.href = '#card-ollama';
      body.append(link); return;
    }
    const label = state.activity==='busy' ? 'Busy / loading' : state.activity==='idle' ? 'Idle' : 'Activity not reported';
    body.append(el('p',label,'model-activity'));
    for (const model of state.models) {
      const item = el('div',undefined,'model-row'), details = el('div');
      details.append(el('strong',model.name),el('small',`${model.kind || 'Model'} · ${memory(model)}`));
      if (!model.can_unload) details.append(el('small',model.activity==='busy' ? 'In use — finish the job first' : 'Unload through the app'));
      item.append(details);
      if (model.can_unload) item.append(action(app,[model.id],'Unload'));
      body.append(item);
    }
    if (!state.models.length) body.append(el('p',state.inventory_known===false ? 'Resident names unavailable' : 'No loaded models reported.'));
    body.append(el('p',state.note,'models-note'));
    if (state.unload_all) body.append(action(app,state.inventory_known===false ? ['cache'] : state.models.map(m => m.id),
      state.inventory_known===false ? 'Release all cached models' : 'Unload all listed models'));
  }
  async function refresh(manual=false) {
    if (reading || pending || (!manual && document.hidden)) return;
    reading = true;
    try {
      const data = await request('/api/models');
      if (pending) return;
      for (const [app,state] of Object.entries(data.apps)) render(app,state);
      for (const panel of panels.values()) {
        if (panel.failed) panel.notice.textContent = '';
        panel.failed = false;
      }
    } catch (error) {
      for (const panel of panels.values()) {
        panel.last = ''; panel.failed = true;
        panel.content.replaceChildren(el('p','Model status unavailable.'));
        panel.notice.textContent = error.name==='AbortError' ? 'Status timed out. Refresh to try again.' : error.message;
      }
    } finally { reading = false; }
  }
  async function unload(app, keys) {
    if (pending) return;
    const names = keys.map(key => key==='cache' ? 'all cached models' : key.replace(/^(text|stt:[^:]+):/,'')).join('\n');
    if (!window.confirm(`Unload from ${app}?\n\n${names}\n\nThe app stays running and files stay on disk. Clients may reload a model when it is used again.`)) return;
    pending = true;
    for (const panel of panels.values()) {
      for (const node of panel.section.querySelectorAll('button')) node.disabled = true;
    }
    const notice = panels.get(app).notice;
    notice.textContent = 'Requesting release…';
    try {
      const result = await request('/api/models/unload',{action:'unload',app,models:keys});
      notice.textContent = result.message;
    } catch (error) {
      notice.textContent = error.name==='AbortError' ? 'Request timed out; outcome unknown. Refresh before retrying.' : error.message;
    } finally {
      pending = false;
      for (const panel of panels.values()) {
        for (const node of panel.section.querySelectorAll('button')) node.disabled = false;
      }
      await refresh(true);
    }
  }
  refresh();
  setInterval(() => refresh(),20000);
  document.addEventListener('visibilitychange',() => refresh());
})();
