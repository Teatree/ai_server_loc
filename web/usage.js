"use strict";
const $=id=>document.getElementById(id);
const U={start:Date.now()/1000-28800,end:Date.now()/1000,live:true,mode:'bars',data:null,
  hidden:new Set(),charts:[],loading:false,request:0};
const costFields=['rate','currency','cpu-idle','cpu-max','overhead','efficiency'];
try{const saved=JSON.parse(localStorage.getItem('ai-usage-cost')||'{}');for(const key of costFields)if(saved[key]!==undefined)$(key).value=saved[key];}catch{}
if(location.hostname==='127.0.0.1'||location.hostname==='localhost')$('back').href='http://127.0.0.1:32146/';
function fieldDate(seconds){const d=new Date(seconds*1000);if($('zone').value==='local')d.setMinutes(d.getMinutes()-d.getTimezoneOffset());return d.toISOString().slice(0,16);}
function syncRange(){ $('from').value=fieldDate(U.start);$('to').value=fieldDate(U.end);$('live').setAttribute('aria-pressed',String(U.live));}
function intervalLabel(step){return step<3600?`${step/60} min`:step<86400?`${step/3600} h`:`${(step/86400).toFixed(1)} days`;}
function error(message){$('error').hidden=!message;$('error').textContent=message;}
function selectedResources(){return (U.data?.catalog||[]).filter(r=>['gpu','cpu','ram'].includes(r.type)).filter(r=>{
  const choice=$('resources').value;return choice==='all'||choice==='gpus_cpu'&&r.type!=='ram'||choice==='gpus'&&r.type==='gpu'||choice===r.type||choice===r.id;
}).sort((a,b)=>['gpu','cpu','ram'].indexOf(a.type)-['gpu','cpu','ram'].indexOf(b.type));}
function metric(point,id){const key=id.startsWith('gpu:')&&!$('estimate').checked?'measured:'+id:id;return point.metrics[key];}
function appNames(){return Object.fromEntries((U.data?.catalog||[]).filter(r=>r.type==='app').map(r=>[r.id.slice(4),r.label]));}
function navigate(start,end){const span=Math.max(600,Math.min(100*366*86400,end-start));U.end=Math.min(Date.now()/1000,Math.max(span,end));U.start=Math.max(0,U.end-span);U.live=false;syncRange();load();}
function pan(amount){const span=U.end-U.start;navigate(U.start+span*amount,U.end+span*amount);}
function zoom(factor){const mid=(U.start+U.end)/2,half=(U.end-U.start)*factor/2;navigate(mid-half,mid+half);}
function disposeCharts(){for(const stop of U.charts)stop();U.charts=[];}
async function load(){
  const request=++U.request;U.controller?.abort();U.controller=new AbortController();U.loading=true;
  const controller=U.controller,timer=setTimeout(()=>controller.abort(),30000);
  $('connection').textContent='Reading history…';error('');
  try{
    const query=new URLSearchParams({start:Math.floor(U.start),end:Math.floor(U.end),step:$('interval').value});
    const response=await fetch('/api/usage?'+query,{cache:'no-store',signal:U.controller.signal});
    if(response.status===401)throw Error('Your session expired. Return to the dashboard and sign in again.');
    if(response.status===503)throw Error('The history connection is offline. Keep the Usage Metrics companion running on Windows; recording on Ubuntu is independent.');
    if(!response.ok)throw Error(`History request failed (${response.status}).`);
    const data=await response.json();if(!data.ok)throw Error(data.error||'History unavailable');
    if(request!==U.request)return;
    U.data=data;
    const saved=$('resources').value;for(const item of [...$('resources').options])if(item.dataset.device)item.remove();
    for(const resource of data.catalog.filter(r=>r.type==='gpu')){const o=new Option(resource.label,resource.id);o.dataset.device='1';$('resources').add(o);}
    $('resources').value=[...$('resources').options].some(o=>o.value===saved)?saved:'gpus';
    const app=$('app').value;$('app').replaceChildren(new Option('All applications','all'));
    for(const [id,label] of Object.entries(appNames()).sort((a,b)=>a[1].localeCompare(b[1])))$('app').add(new Option(label,id));
    $('app').value=[...$('app').options].some(o=>o.value===app)?app:'all';
    const latest=data.metadata.last_sample,lag=latest?Date.now()/1000-latest:Infinity;
    $('connection').textContent=lag<60?'● Recording · updates every 15s':latest?'Recording delayed · last sample '+new Date(latest*1000).toLocaleString():'Waiting for first sample';
    $('history-start').textContent=data.metadata.first_sample?'History begins '+new Date(data.metadata.first_sample*1000).toLocaleString()+'. Earlier periods contain no recorded data.':'The first measurement appears after the collector’s second sample.';
    const health=data.metadata.health||{};$('collector-health').textContent=`Read-only history · Collector: ${health.collection_ms??'—'} ms/sample · ${health.processes??'—'} inspected processes · No automatic history deletion. ${health.last_backup?'Daily backup: '+new Date(health.last_backup*1000).toLocaleString()+'. ':''}${health.backup_warning||''}${health.disk_free_bytes!==undefined?' Free disk: '+(health.disk_free_bytes/1024**3).toFixed(1)+' GiB.':''}`;
    render();
  }catch(e){if(request===U.request){U.data=null;disposeCharts();$('charts').replaceChildren();$('cost-chart').replaceChildren();$('app-totals').replaceChildren();for(const id of ['compute-hours','peak-load','coverage','cost-total'])$(id).textContent='—';$('connection').textContent='History unavailable';error(e.name==='AbortError'?'History request timed out. Try a shorter range or check the AI server connection.':e.message);}}
  finally{clearTimeout(timer);if(request===U.request)U.loading=false;}
}
function seriesFor(resources){
  const names=appNames(),scores={};
  for(const point of U.data.points)for(const r of resources){const m=metric(point,r.id);if(m)for(const [id,value] of Object.entries(m.apps))scores[id]=(scores[id]||0)+value*m.seconds;}
  const focused=$('app').value;
  const ids=focused!=='all'?[focused]:Object.keys(scores).filter(id=>id!=='unattributed').sort((a,b)=>scores[b]-scores[a]).slice(0,9);
  if(focused==='all')ids.push('unattributed','other');
  return ids.map(id=>({id,label:id==='other'?'Other applications':names[id]||id}));
}
function groupedValues(m,series){
  const values={};for(const s of series)values[s.id]=0;
  for(const [id,value] of Object.entries(m.apps||{})){
    const target=Object.hasOwn(values,id)?id:'other';if(Object.hasOwn(values,target)&&!U.hidden.has(target))values[target]+=value;
  }return values;
}
function render(){
  if(!U.data)return;disposeCharts();$('charts').replaceChildren();$('cost-chart').replaceChildren();$('legend').replaceChildren();
  const resources=selectedResources(),series=seriesFor(resources);
  for(const s of series){const button=document.createElement('button');button.textContent=s.label;button.style.borderColor=UsageCharts.color(s.id);button.setAttribute('aria-pressed',String(!U.hidden.has(s.id)));button.onclick=()=>{U.hidden.has(s.id)?U.hidden.delete(s.id):U.hidden.add(s.id);render();};$('legend').append(button);}
  const visible=series.filter(s=>!U.hidden.has(s.id));
  $('resolution').textContent=`${intervalLabel(U.data.step)} bars · ${$('zone').value==='utc'?'UTC':Intl.DateTimeFormat().resolvedOptions().timeZone} · Each device has its own 0–100% scale`;
  for(const r of resources){
    const points=U.data.points.flatMap(p=>{const m=metric(p,r.id);return m?[{time:p.time,values:groupedValues(m,series),note:`Device total ${m.value.toFixed(1)}%; ${Math.round(m.seconds)}s observed`}]:[];});
    U.charts.push(UsageCharts.chart($('charts'),{title:r.label+' · %',points,start:U.start,end:U.end,step:U.data.step,max:100,mode:U.mode,series:visible,unit:'%',utc:$('zone').value==='utc',pan,zoom}));
  }
  if(!resources.length)$('charts').textContent='No matching devices recorded yet.';
  summaries();electricity();applicationTotals();
}
function summaries(){
  let hours=0,peak=0,seconds=0,observedGPU=false;
  for(const p of U.data.points){seconds+=p.metrics.cpu?.seconds||0;for(const [id,m] of Object.entries(p.metrics))if(id.startsWith('gpu:')){observedGPU=true;hours+=m.value*m.seconds/360000;peak=Math.max(peak,m.peak);}}
  $('compute-hours').textContent=observedGPU?hours.toFixed(3)+' h':'—';$('peak-load').textContent=observedGPU?peak.toFixed(1)+'%':'—';
  $('coverage').textContent=(Math.min(1,seconds/(U.data.end-U.data.start))*100).toFixed(1)+'%';
}
function powerSettings(){
  const rate=+$('rate').value,idle=+$('cpu-idle').value,max=+$('cpu-max').value,overhead=+$('overhead').value,eff=+$('efficiency').value/100;
  if(![rate,idle,max,overhead,eff].every(Number.isFinite)||rate<0||idle<0||max<idle||overhead<0||eff<.1||eff>1)throw Error('Enter valid power assumptions; CPU full-load watts must be at least idle watts.');
  return {rate,idle,max,overhead,eff,unit:$('currency').value.trim()||'c'};
}
function electricity(){
  let s;try{s=powerSettings();}catch(e){$('energy-note').textContent=e.message;return;}
  let energy=0,cost=0,missing=false;const gpus=U.data.catalog.filter(r=>r.type==='gpu');
  const points=U.data.points.flatMap(p=>{
    const cpu=p.metrics.cpu;if(!cpu)return [];
    const values={gpu:0,cpu:(s.idle+(s.max-s.idle)*cpu.value/100)*cpu.seconds/3600000/s.eff,system:s.overhead*cpu.seconds/3600000/s.eff};
    for(const gpu of gpus){const m=p.metrics['power:'+gpu.id];if(m){values.gpu+=m.value*m.seconds/3600000/s.eff;if(m.seconds+1<cpu.seconds)missing=true;}else missing=true;}
    const kwh=Object.values(values).reduce((a,b)=>a+b,0);energy+=kwh;cost+=kwh*s.rate;
    for(const key of Object.keys(values))values[key]*=s.rate;
    return [{time:p.time,values,note:`${kwh.toFixed(5)} kWh; ${Math.round(cpu.seconds)}s recorded`}];
  });
  $('cost-total').textContent=points.length?cost.toFixed(4)+' '+s.unit:'—';
  $('energy-note').textContent=`${energy.toFixed(4)} kWh estimated during recorded periods only · Rate ${s.rate} ${s.unit}/kWh. ${missing?'Partial estimate: one or more GPUs have missing power readings.':''}`;
  U.charts.push(UsageCharts.chart($('cost-chart'),{title:`Estimated cost per ${intervalLabel(U.data.step)} · ${s.unit}`,points,start:U.start,end:U.end,step:U.data.step,max:Math.max(.001,...points.map(p=>Object.values(p.values).reduce((a,b)=>a+b,0)))*1.1,mode:U.mode,series:[{id:'gpu',label:'GPU'},{id:'cpu',label:'CPU model'},{id:'system',label:'System overhead'}],unit:' '+s.unit,utc:$('zone').value==='utc',pan,zoom}));
}
function applicationTotals(){
  const totals={},names=appNames();let ramSeconds=0;
  for(const p of U.data.points){ramSeconds+=p.metrics.ram?.seconds||0;for(const r of U.data.catalog.filter(r=>['gpu','cpu','ram'].includes(r.type))){const m=metric(p,r.id);if(!m)continue;for(const [id,v] of Object.entries(m.apps)){const a=totals[id]||=( {gpu:0,cpu:0,ram:0});a[r.type]+=v*m.seconds/(r.type==='ram'?1:360000);}}}
  $('app-totals').replaceChildren();
  for(const [id,a] of Object.entries(totals).sort((a,b)=>(b[1].gpu+b[1].cpu)-(a[1].gpu+a[1].cpu))){
    const tr=document.createElement('tr');for(const value of [names[id]||id,a.gpu.toFixed(3),a.cpu.toFixed(3),(ramSeconds?a.ram/ramSeconds:0).toFixed(2)+'%']){const td=document.createElement('td');td.textContent=value;tr.append(td);}$('app-totals').append(tr);
  }
}
function exportCSV(){
  if(!U.data)return;const lines=[['UTC bucket start','Resource','Application','Average percent','Observed seconds','Peak device percent']],names=appNames();
  for(const p of U.data.points)for(const r of selectedResources()){const m=metric(p,r.id);if(m)for(const [app,value] of Object.entries(m.apps))lines.push([new Date(p.time*1000).toISOString(),r.label,names[app]||app,value,m.seconds,m.peak]);}
  const quote=value=>'"'+String(value).replace(/^[=+@-]/,"'$&").replaceAll('"','""')+'"';
  const url=URL.createObjectURL(new Blob([lines.map(row=>row.map(quote).join(',')).join('\r\n')],{type:'text/csv;charset=utf-8'}));
  const a=document.createElement('a');a.href=url;a.download='ai-server-usage.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
for(const button of document.querySelectorAll('[data-hours]'))button.onclick=()=>{U.end=Date.now()/1000;U.start=U.end-Number(button.dataset.hours)*3600;U.live=true;syncRange();load();};
$('range-form').onsubmit=e=>{e.preventDefault();const suffix=$('zone').value==='utc'?'Z':'';const start=Date.parse($('from').value+suffix)/1000,end=Date.parse($('to').value+suffix)/1000;if(!Number.isFinite(start+end)||end<=start){error('Choose an end date after the start date.');return;}navigate(start,end);};
$('earlier').onclick=()=>pan(-.5);$('later').onclick=()=>pan(.5);
$('zoom-in').onclick=()=>zoom(.5);$('zoom-out').onclick=()=>zoom(2);
$('interval').onchange=load;for(const id of ['resources','app','estimate'])$(id).onchange=render;
$('zone').onchange=()=>{syncRange();render();};
$('live').onclick=()=>{U.live=!U.live;if(U.live){const span=U.end-U.start;U.end=Date.now()/1000;U.start=U.end-span;load();}syncRange();};
$('mode').onclick=()=>{U.mode=U.mode==='bars'?'lines':'bars';$('mode').textContent=U.mode==='bars'?'Line chart':'Stacked bars';$('mode').setAttribute('aria-pressed',String(U.mode==='lines'));render();};
$('reset').onclick=()=>{U.end=Date.now()/1000;U.start=U.end-28800;U.live=true;U.mode='bars';U.hidden.clear();$('resources').value='gpus';$('app').value='all';$('interval').value='auto';$('mode').textContent='Line chart';$('mode').setAttribute('aria-pressed','false');syncRange();load();};
$('fullscreen').onclick=async()=>{try{if(document.fullscreenElement)await document.exitFullscreen();else if($('workspace').requestFullscreen)await $('workspace').requestFullscreen();else error('Full screen is unavailable in this browser.');}catch{error('This browser could not open full screen.');}};
$('export').onclick=exportCSV;
$('cost-form').onsubmit=e=>{e.preventDefault();try{powerSettings();const values=Object.fromEntries(costFields.map(id=>[id,$(id).value]));localStorage.setItem('ai-usage-cost',JSON.stringify(values));error('');render();}catch(e){error(e.message);}};
function tick(){if(U.live&&!U.loading&&!document.hidden){const span=U.end-U.start;U.end=Date.now()/1000;U.start=U.end-span;syncRange();load();}}
document.addEventListener('visibilitychange',tick);setInterval(tick,15000);syncRange();load();
