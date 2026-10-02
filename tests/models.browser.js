async (page) => {
  const assert = {
    ok(value,message) { if (!value) throw Error(message || 'Assertion failed'); },
    equal(a,b,message) { this.ok(a===b,message || `${a} !== ${b}`); },
    deepEqual(a,b) { this.equal(JSON.stringify(a),JSON.stringify(b)); }
  };
  const calls = [], errors = [];
  const hostile = '<img src=x onerror=alert(1)>very-long-resident-model-name:latest';
  let models = [{id:'test-a',name:hostile,can_unload:true,bytes:2*1024**3,vram_bytes:1024**3},
                {id:'test-b',name:'Second test model',can_unload:true}];
  let busy = true;
  const handler = async route => {
    const req = route.request();
    if (req.method()==='OPTIONS') return route.fulfill({status:204,headers:{
      'Access-Control-Allow-Origin':'http://127.0.0.1:32146',
      'Access-Control-Allow-Methods':'GET, POST, OPTIONS','Access-Control-Allow-Headers':'Content-Type'}});
    let data;
    if (req.method()==='POST') {
      const body = req.postDataJSON(); calls.push(body);
      models = models.filter(m => !body.models.includes(m.id));
      data = {ok:true,message:'Simulated unload completed'};
    } else data = {ok:true,apps:{
      ollama:{online:true,models,note:'Mock resident models',activity:'unknown',unload_all:!!models.length},
      comfy:{online:true,models:[],note:'Mock cache',activity:busy?'busy':'idle',inventory_known:false,unload_all:!busy}
    }};
    return route.fulfill({json:data,headers:{'Access-Control-Allow-Origin':'http://127.0.0.1:32146'}});
  };
  page.on('pageerror',error => errors.push(error.message));
  await page.route('http://127.0.0.1:32150/api/models**',handler);
  try {
    await page.goto('http://127.0.0.1:32146/');
    const panel = page.locator('#card-ollama .loaded-models');
    await panel.getByText(hostile,{exact:true}).waitFor();
    assert.equal(await panel.locator('img').count(),0);
    assert.equal(await page.locator('#card-comfy').getByRole('button',{name:'Release all cached models'}).count(),0);
    for (const width of [320,390,1280]) {
      await page.setViewportSize({width,height:844});
      const fits = await page.evaluate(() => document.documentElement.scrollWidth<=innerWidth);
      assert.ok(fits,`No horizontal overflow at ${width}px`);
    }
    await page.evaluate(() => { window.confirm = () => false; });
    await panel.getByRole('button',{name:'Unload',exact:true}).first().click();
    assert.equal(calls.length,0);
    await page.evaluate(() => { window.confirm = () => true; });
    await panel.getByRole('button',{name:'Unload',exact:true}).first().click();
    await panel.getByText(hostile,{exact:true}).waitFor({state:'detached'});
    assert.deepEqual(calls[0],{action:'unload',app:'ollama',models:['test-a']});
    await panel.getByRole('button',{name:'Unload all listed models'}).click();
    await panel.getByText('No loaded models reported.',{exact:true}).waitFor();
    assert.deepEqual(calls[1].models,['test-b']);
    assert.equal(errors.length,0,errors.join('\n'));
    return {passed:true,widths:[320,390,1280],simulatedUnloads:calls.length,realUnloads:0};
  } finally {
    await page.unroute('http://127.0.0.1:32150/api/models**',handler);
    await page.goto('http://127.0.0.1:32146/');
  }
}
