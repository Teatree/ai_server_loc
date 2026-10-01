const test=require('node:test'),assert=require('node:assert/strict');
const vm=require('node:vm'),fs=require('node:fs');
function page(){
  const values={rate:'4',currency:'c','cpu-idle':'10','cpu-max':'90',overhead:'10',efficiency:'100',zone:'utc',resources:'all',app:'all',interval:'auto'};
  const els={};const element=id=>els[id]||=( {value:values[id]||'',checked:true,textContent:'',style:{},setAttribute(){},replaceChildren(){},append(){}} );
  const context=vm.createContext({document:{getElementById:element,querySelectorAll:()=>[],addEventListener(){}},location:{hostname:'test'},localStorage:{getItem:()=>null},setInterval(){},setTimeout(){},Intl,Date,AbortController,URLSearchParams,UsageCharts:{chart:()=>()=>{}},fetch:async()=>{throw Error('not available')}});
  let source=fs.readFileSync('web/usage.js','utf8');
  source=source.replace(/document.addEventListener\('visibilitychange',tick\);setInterval\(tick,15000\);syncRange\(\);load\(\);/,'');
  vm.runInContext(source,context);
  vm.runInContext(`U.start=3600;U.end=7200;U.data={start:3600,end:7200,step:3600,catalog:[{id:'gpu:test',type:'gpu'},{id:'cpu',type:'cpu'},{id:'ram',type:'ram'}],points:[{time:3600,metrics:{cpu:{value:100,seconds:3600,peak:100,apps:{test:100}},'gpu:test':{value:50,seconds:3600,peak:80,apps:{test:50}},'power:gpu:test':{value:100,seconds:3600}}}]};`,context);
  return {context,els,element};
}
test('200 watts for one hour costs 0.8 cents at 4 cents/kWh',()=>{
  const {context,els}=page();vm.runInContext('electricity();summaries()',context);
  assert.equal(els['cost-total'].textContent,'0.8000 c');
  assert.match(els['energy-note'].textContent,/0.2000 kWh/);
  assert.equal(els['compute-hours'].textContent,'0.500 h');
  assert.equal(els['peak-load'].textContent,'80.0%');
  assert.equal(els.coverage.textContent,'100.0%');
});
test('unrecorded time is excluded from cost and flagged in coverage',()=>{
  const {context,els}=page();vm.runInContext('U.data.end=10800;electricity();summaries()',context);
  assert.equal(els['cost-total'].textContent,'0.8000 c');
  assert.equal(els.coverage.textContent,'50.0%');
});
test('missing GPU power is flagged and invalid assumptions rejected',()=>{
  const {context,els,element}=page();vm.runInContext("delete U.data.points[0].metrics['power:gpu:test'];electricity()",context);
  assert.match(els['energy-note'].textContent,/Partial estimate/);
  assert.equal(els['cost-total'].textContent,'0.4000 c');
  element('efficiency').value='0';assert.throws(()=>vm.runInContext('powerSettings()',context),/valid power/);
});
test('legacy and mixed buckets never attribute unknown service load to another app',()=>{
  const {context}=page();
  vm.runInContext("U.data.points[0].metrics['measured:gpu:test']={value:50,seconds:3600,apps:{unattributed:50}}",context);
  assert.equal(vm.runInContext("metric(U.data.points[0],'gpu:test').apps.unattributed",context),50);
  vm.runInContext("U.data.points[0].metrics['quality:gpu-attribution']={value:2,seconds:30}",context);
  assert.equal(vm.runInContext("metric(U.data.points[0],'gpu:test').apps.unattributed",context),50);
  vm.runInContext("U.data.points[0].metrics['quality:gpu-attribution'].seconds=3600",context);
  assert.equal(vm.runInContext("metric(U.data.points[0],'gpu:test').apps.test",context),50);
});
test('System / Unattributed remains visible with one app selected and hidden flag set',()=>{
  const {context,element}=page();element('app').value='test';
  const ids=vm.runInContext("seriesFor([{id:'cpu'}]).map(s=>s.id).join(',')",context);
  assert.equal(ids,'test,unattributed');
  assert.equal(vm.runInContext("U.hidden.add('unattributed');groupedValues({apps:{unattributed:30}},[{id:'unattributed'}]).unattributed",context),30);
});
