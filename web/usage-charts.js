"use strict";
window.UsageCharts = (() => {
  const palette=['#64edab','#54d8e7','#f4b85d','#aa8cff','#ff8d79','#6fa8ff','#e58dcf','#b8d475','#dda778','#65c7b0'];
  const stableColor=id=>{let n=0;for(const c of id)n=(n*31+c.charCodeAt(0))>>>0;return id==='unattributed'?'#b7c3be':id==='other'?'#445b65':palette[n%palette.length];};
  function clampView(start,end,lower,upper,minimum){
    const span=Math.min(upper-lower,Math.max(minimum,end-start));
    const left=Math.max(lower,Math.min(upper-span,start));return {start:left,end:left+span};
  }
  function chart(container, config) {
    const panel=document.createElement('article');panel.className='chart-panel';
    const heading=document.createElement('h3');heading.textContent=config.title;
    const toolbar=document.createElement('div');toolbar.className='chart-toolbar';
    const rangeLabel=document.createElement('span');rangeLabel.className='chart-range';
    const systemSummary=document.createElement('span');systemSummary.className='system-summary';
    const buttons={};
    const state=config.view||{};let view;
    function bounds(){view=state.range?clampView(state.range.start,state.range.end,config.start,config.end,config.step*2):{start:config.start,end:config.end};}
    function change(factor,shift=0){const span=view.end-view.start,next=span*factor,mid=(view.start+view.end)/2+span*shift;state.range=clampView(mid-next/2,mid+next/2,config.start,config.end,config.step*2);state.cursor=null;cursor=null;bounds();inspect.textContent='View updated. Tap or hover to inspect values.';draw();}
    for(const [key,title,action] of [['earlier','← Earlier',()=>change(1,-.5)],['in','＋ Zoom',()=>change(.5)],['out','− Zoom',()=>change(2)],['later','Later →',()=>change(1,.5)],['reset','Reset chart',()=>{state.range=null;state.cursor=null;cursor=null;bounds();inspect.textContent='Showing the full selected time range.';draw();}]]){
      const b=document.createElement('button');b.type='button';b.textContent=title;b.dataset.chartAction=key;b.setAttribute('aria-label',title+' — '+config.title);b.onclick=action;toolbar.append(b);buttons[key]=b;
    }
    const hint=document.createElement('p');hint.className='hint';hint.textContent='Scroll moves the page. These buttons adjust only this chart.';
    const plot=document.createElement('div');plot.className='plot';
    const canvas=document.createElement('canvas');canvas.tabIndex=0;canvas.setAttribute('role','img');canvas.setAttribute('aria-label',config.title+'. Use arrow keys to inspect time values.');
    const inspect=document.createElement('div');inspect.className='inspect';inspect.textContent='Tap the chart to inspect a time and its application breakdown.';
    plot.append(canvas);panel.append(heading,toolbar,rangeLabel,plot,inspect,hint,systemSummary);container.append(panel);
    const ctx=canvas.getContext('2d'), pad={left:40,right:12,top:14,bottom:38};
    let width=0,height=0,cursor=state.cursor??null,drag=null,disposed=false;
    let points=new Map(config.points.map(p=>[p.time,p]));bounds();
    const label=t=>new Date(t*1000).toLocaleString(undefined,{timeZone:config.utc?'UTC':undefined,month:'short',day:'numeric',hour:'2-digit',minute:'2-digit',year:'numeric'});
    const x=t=>pad.left+(t-view.start)/(view.end-view.start)*(width-pad.left-pad.right);
    const y=v=>height-pad.bottom-v/config.max*(height-pad.top-pad.bottom);
    const at=px=>Math.floor(Math.max(view.start,Math.min(view.end-.001,view.start+(px-pad.left)/(width-pad.left-pad.right)*(view.end-view.start)))/config.step)*config.step;
    function draw() {
      if(disposed||!width)return;
      rangeLabel.textContent=label(view.start)+' — '+label(view.end);
      systemSummary.hidden=!config.series.some(s=>s.id==='unattributed');
      const latest=config.points.filter(p=>p.time<view.end&&p.time+config.step>view.start).at(-1);
      systemSummary.textContent='System / Unattributed: '+(latest?(latest.values.unattributed||0).toFixed(1)+'% in the last recorded bar shown':'no measurement in this view');
      buttons.earlier.disabled=view.start<=config.start;buttons.later.disabled=view.end>=config.end;
      buttons.in.disabled=view.end-view.start<=config.step*2;buttons.out.disabled=view.end-view.start>=config.end-config.start;
      ctx.clearRect(0,0,width,height);ctx.font='10px Consolas, monospace';ctx.lineWidth=1;
      for(let i=0;i<=4;i++){
        const v=config.max*i/4;ctx.strokeStyle='#26302f';ctx.beginPath();ctx.moveTo(pad.left,y(v));ctx.lineTo(width-pad.right,y(v));ctx.stroke();
        ctx.fillStyle='#8d9997';ctx.textAlign='right';ctx.fillText(v.toFixed(config.max<1?3:0),pad.left-6,y(v)+4);
      }
      ctx.textAlign='center';
      for(let i=0;i<=2;i++){
        const t=view.start+(view.end-view.start)*i/2;
        const px=Math.max(70,Math.min(width-65,x(t)));const d=new Date(t*1000);
        ctx.fillText(d.toLocaleDateString(undefined,{timeZone:config.utc?'UTC':undefined,month:'short',day:'numeric'}),px,height-20);
        ctx.fillText(view.end-view.start>30*86400?String(config.utc?d.getUTCFullYear():d.getFullYear()):d.toLocaleTimeString(undefined,{timeZone:config.utc?'UTC':undefined,hour:'2-digit',minute:'2-digit'}),px,height-6);
      }
      ctx.save();ctx.beginPath();ctx.rect(pad.left,pad.top,width-pad.left-pad.right,height-pad.top-pad.bottom);ctx.clip();
      if(config.mode==='bars'){
        for(const p of config.points){
          let base=0;const w=Math.max(.5,x(p.time+config.step)-x(p.time)-.8);
          for(const series of config.series){const v=p.values[series.id]||0;ctx.fillStyle=stableColor(series.id);ctx.fillRect(x(p.time),y(base+v),w,Math.max(0,y(base)-y(base+v)));base+=v;}
        }
      }else{
        for(const series of config.series){
          ctx.strokeStyle=stableColor(series.id);ctx.lineWidth=1.7;ctx.beginPath();let last=null;
          for(const p of config.points){const px=x(Math.min(config.end,p.time+config.step/2)),py=y(p.values[series.id]||0);if(last===null||p.time-last>config.step*1.1)ctx.moveTo(px,py);else ctx.lineTo(px,py);last=p.time;}ctx.stroke();
          if(config.points.length<40)for(const p of config.points){ctx.fillStyle=stableColor(series.id);ctx.beginPath();ctx.arc(x(Math.min(config.end,p.time+config.step/2)),y(p.values[series.id]||0),2.3,0,Math.PI*2);ctx.fill();}
        }
      }
      if(cursor!==null){ctx.strokeStyle='#e3eeea';ctx.lineWidth=1;ctx.setLineDash([3,3]);ctx.beginPath();ctx.moveTo(x(cursor+config.step/2),pad.top);ctx.lineTo(x(cursor+config.step/2),height-pad.bottom);ctx.stroke();ctx.setLineDash([]);}
      ctx.restore();
      if(!config.points.some(p=>p.time<view.end&&p.time+config.step>view.start)){ctx.fillStyle='#8d9997';ctx.textAlign='center';ctx.fillText('No samples here — use Reset chart',width/2,height/2);}
    }
    function show(time){
      cursor=time;state.cursor=time;const p=points.get(time);
      inspect.textContent=label(time)+(p?' · '+config.series.map(s=>`${s.label}: ${(p.values[s.id]||0).toFixed(config.unit==='%'?1:4)}${config.unit}`).join(' · ')+(p.note?' · '+p.note:''):' · No measurement recorded.');draw();
    }
    const observer=new ResizeObserver(()=>{const r=plot.getBoundingClientRect();width=r.width;height=r.height;const scale=Math.min(devicePixelRatio||1,2);canvas.width=width*scale;canvas.height=height*scale;ctx.setTransform(scale,0,0,scale,0,0);draw();});observer.observe(plot);
    const localX=e=>e.clientX-canvas.getBoundingClientRect().left;
    canvas.addEventListener('pointerdown',e=>{drag={x:localX(e),y:e.clientY};});
    canvas.addEventListener('pointermove',e=>{const time=at(localX(e));if(!drag&&e.pointerType!=='touch'&&cursor!==time)show(time);});
    canvas.addEventListener('pointerup',e=>{if(drag&&Math.abs(localX(e)-drag.x)<10&&Math.abs(e.clientY-drag.y)<10)show(at(localX(e)));drag=null;});
    canvas.addEventListener('pointercancel',()=>{drag=null;});
    canvas.addEventListener('keydown',e=>{
      if(!['ArrowLeft','ArrowRight','Home','End'].includes(e.key))return;e.preventDefault();
      const initial=cursor===null?Math.floor(view.start/config.step)*config.step:cursor;
      const time=e.key==='Home'?view.start:e.key==='End'?view.end-config.step:initial+(e.key==='ArrowLeft'?-config.step:config.step);
      show(Math.floor(Math.max(view.start,Math.min(view.end-config.step,time))/config.step)*config.step);
    });
    const dispose=()=>{disposed=true;observer.disconnect();panel.remove();};
    dispose.update=next=>{config=next;heading.textContent=config.title;points=new Map(config.points.map(p=>[p.time,p]));bounds();if(state.cursor!==undefined&&state.cursor!==null)show(state.cursor);else {cursor=null;draw();}};
    dispose.panel=panel;return dispose;
  }
  return {chart,color:stableColor,clampView};
})();
