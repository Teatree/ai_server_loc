"use strict";
window.UsageCharts = (() => {
  const palette=['#64edab','#54d8e7','#f4b85d','#aa8cff','#ff8d79','#6fa8ff','#e58dcf','#b8d475','#dda778','#65c7b0'];
  const stableColor=id=>{let n=0;for(const c of id)n=(n*31+c.charCodeAt(0))>>>0;return id==='unattributed'?'#7a8784':id==='other'?'#445b65':palette[n%palette.length];};
  function chart(container, config) {
    const panel=document.createElement('article');panel.className='chart-panel';
    const heading=document.createElement('h3');heading.textContent=config.title;
    const plot=document.createElement('div');plot.className='plot';
    const canvas=document.createElement('canvas');canvas.tabIndex=0;canvas.setAttribute('role','img');canvas.setAttribute('aria-label',config.title+'. Use arrow keys to inspect time values.');
    const inspect=document.createElement('div');inspect.className='inspect';inspect.textContent='Tap the chart to inspect a time and its application breakdown.';
    plot.append(canvas);panel.append(heading,plot,inspect);container.append(panel);
    const ctx=canvas.getContext('2d'), pad={left:40,right:12,top:14,bottom:38};
    let width=0,height=0,cursor=null,drag=null,disposed=false;
    const points=new Map(config.points.map(p=>[p.time,p]));
    const label=t=>new Date(t*1000).toLocaleString(undefined,{timeZone:config.utc?'UTC':undefined,month:'short',day:'numeric',hour:'2-digit',minute:'2-digit',year:'numeric'});
    const x=t=>pad.left+(t-config.start)/(config.end-config.start)*(width-pad.left-pad.right);
    const y=v=>height-pad.bottom-v/config.max*(height-pad.top-pad.bottom);
    const at=px=>Math.floor((config.start+(px-pad.left)/(width-pad.left-pad.right)*(config.end-config.start))/config.step)*config.step;
    function draw() {
      if(disposed||!width)return;
      ctx.clearRect(0,0,width,height);ctx.font='10px Consolas, monospace';ctx.lineWidth=1;
      for(let i=0;i<=4;i++){
        const v=config.max*i/4;ctx.strokeStyle='#26302f';ctx.beginPath();ctx.moveTo(pad.left,y(v));ctx.lineTo(width-pad.right,y(v));ctx.stroke();
        ctx.fillStyle='#8d9997';ctx.textAlign='right';ctx.fillText(v.toFixed(config.max<1?3:0),pad.left-6,y(v)+4);
      }
      ctx.textAlign='center';
      for(let i=0;i<=2;i++){
        const t=config.start+(config.end-config.start)*i/2;
        const px=Math.max(70,Math.min(width-65,x(t)));const d=new Date(t*1000);
        ctx.fillText(d.toLocaleDateString(undefined,{timeZone:config.utc?'UTC':undefined,month:'short',day:'numeric'}),px,height-20);
        ctx.fillText(config.end-config.start>30*86400?String(config.utc?d.getUTCFullYear():d.getFullYear()):d.toLocaleTimeString(undefined,{timeZone:config.utc?'UTC':undefined,hour:'2-digit',minute:'2-digit'}),px,height-6);
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
      if(!config.points.length){ctx.fillStyle='#8d9997';ctx.textAlign='center';ctx.fillText('No recorded measurements in this range',width/2,height/2);}
    }
    function show(time){
      cursor=time;const p=points.get(time);
      inspect.textContent=label(time)+(p?' · '+config.series.map(s=>`${s.label}: ${(p.values[s.id]||0).toFixed(config.unit==='%'?1:4)}${config.unit}`).join(' · ')+(p.note?' · '+p.note:''):' · No measurement recorded.');draw();
    }
    const observer=new ResizeObserver(()=>{const r=plot.getBoundingClientRect();width=r.width;height=r.height;const scale=Math.min(devicePixelRatio||1,2);canvas.width=width*scale;canvas.height=height*scale;ctx.setTransform(scale,0,0,scale,0,0);draw();});observer.observe(plot);
    const localX=e=>e.clientX-canvas.getBoundingClientRect().left;
    canvas.addEventListener('pointerdown',e=>{drag={x:localX(e)};canvas.setPointerCapture(e.pointerId);show(at(localX(e)));});
    canvas.addEventListener('pointermove',e=>{if(!drag)show(at(localX(e)));});
    canvas.addEventListener('pointerup',e=>{if(drag){const delta=localX(e)-drag.x;if(Math.abs(delta)>14)config.pan(-delta/(width-pad.left-pad.right));else show(at(localX(e)));}drag=null;});
    canvas.addEventListener('pointercancel',()=>{drag=null;});
    canvas.addEventListener('wheel',e=>{e.preventDefault();config.zoom(e.deltaY>0?2:.5);},{passive:false});
    canvas.addEventListener('keydown',e=>{
      if(!['ArrowLeft','ArrowRight','Home','End'].includes(e.key))return;e.preventDefault();
      const initial=cursor===null?Math.floor(config.start/config.step)*config.step:cursor;
      const time=e.key==='Home'?config.start:e.key==='End'?config.end-config.step:initial+(e.key==='ArrowLeft'?-config.step:config.step);
      show(Math.floor(Math.max(config.start,Math.min(config.end-config.step,time))/config.step)*config.step);
    });
    return ()=>{disposed=true;observer.disconnect();};
  }
  return {chart,color:stableColor};
})();
