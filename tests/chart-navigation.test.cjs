const test=require('node:test'),assert=require('node:assert/strict');
const vm=require('node:vm'),fs=require('node:fs');
function harness(){
  function el(tag){return {tag,children:[],dataset:{},style:{},listeners:{},textContent:'',setAttribute(){},append(...items){this.children.push(...items)},remove(){},addEventListener(name,fn){this.listeners[name]=fn},getBoundingClientRect(){return {width:400,height:240,left:0}},getContext(){return new Proxy({},{get:()=>()=>{}})}};}
  const context=vm.createContext({window:{},document:{createElement:el},devicePixelRatio:1,ResizeObserver:class{constructor(fn){this.fn=fn}observe(){this.fn()}disconnect(){}}});
  vm.runInContext(fs.readFileSync('web/usage-charts.js','utf8'),context);
  const container=el('container'),view={};
  const config={title:'GPU',start:1000,end:4600,step:60,max:100,mode:'bars',series:[{id:'unattributed',label:'System'}],points:[],view};
  const stop=context.window.UsageCharts.chart(container,config);
  const panel=container.children[0],buttons=panel.children[1].children,canvas=panel.children[3].children[0];
  return {config,view,stop,buttons,canvas,panel};
}
test('wheel and touch scrolling cannot zoom or move a chart',()=>{
  const {canvas,view}=harness();assert.equal(canvas.listeners.wheel,undefined);
  canvas.listeners.pointerdown({clientX:100,clientY:100});
  canvas.listeners.pointerup({clientX:180,clientY:200});
  assert.equal(view.range,undefined);
});
test('local zoom clamps at boundaries, survives refresh, and resets without a request',()=>{
  const {buttons,view,config,stop,panel}=harness();
  buttons.find(b=>b.dataset.chartAction==='in').onclick();
  assert.equal(view.range.end-view.range.start,1800);
  for(let i=0;i<50;i++)buttons.find(b=>b.dataset.chartAction==='earlier').onclick();
  assert.equal(view.range.start,1000);
  for(let i=0;i<50;i++)buttons.find(b=>b.dataset.chartAction==='in').onclick();
  assert.equal(view.range.end-view.range.start,120);
  const before=JSON.stringify(view.range);stop.update({...config,points:[]});
  assert.equal(JSON.stringify(view.range),before);assert.equal(stop.panel,panel);
  buttons.find(b=>b.dataset.chartAction==='reset').onclick();assert.equal(view.range,null);
  assert.equal(buttons.find(b=>b.dataset.chartAction==='out').disabled,true);
});
test('one chart reset leaves another chart unchanged',()=>{
  const a=harness(),b=harness();
  a.buttons[1].onclick();b.buttons[1].onclick();const before=JSON.stringify(b.view);
  a.buttons[4].onclick();assert.equal(a.view.range,null);assert.equal(JSON.stringify(b.view),before);
});
