const assert=require('node:assert/strict');
const path=require('node:path');const {pathToFileURL}=require('node:url');
const {chromium}=require('playwright');
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.platform==='win32'?{channel:'msedge'}:{})});
 try {
  const page=await browser.newPage({viewport:{width:1280,height:832}});
  const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.addInitScript(()=>{window.bootMessages=[];window.webkit={messageHandlers:{codexWelcome:{postMessage:message=>window.bootMessages.push(message)}}}});
  const url=pathToFileURL(path.resolve(__dirname,'../docs/animation.html'));
  url.search=new URLSearchParams({play:'1',launch:'1','defer-start':'1','motion-test':'1',name:'Alex+Sun'});
  await page.goto(url.href);await page.waitForFunction(()=>window.bootMessages.some(m=>m.kind==='prepared'));
  for(const [width,height] of [[1920,1080],[1536,864],[1280,1024],[2560,1440],[3440,1440],[900,1200]]){
   await page.setViewportSize({width,height});
   const frame=await page.evaluate(()=>{
    fitStage();const r=document.getElementById('orb').getBoundingClientRect();
    return {x:r.x+r.width/2,y:r.y+r.height/2,w:r.width,h:r.height,width:innerWidth,height:innerHeight,canvas:[canvas.width,canvas.height]};
   });
   assert.ok(Math.abs(frame.x-width/2)<.2 && Math.abs(frame.y-height/2)<.2,'Opening orb is not centered');
   assert.ok(frame.w<width*.3 && frame.h<height*.3,'Full-screen blue first frame regressed');
   assert.deepEqual(frame.canvas,[512,512]);
  }
  await page.setViewportSize({width:1280,height:832});
  await page.waitForTimeout(200);
  assert.equal(await page.evaluate(()=>window.__voiceDiagnostics.state.time),0,'Timeline ran before its first frame was presented');
  assert.equal(await page.evaluate(()=>window.__startWelcome()),false,'Timeline accepted an early start');
  assert.equal(await page.evaluate(()=>window.__prepareWelcomeDisplay()),true);
  await page.waitForFunction(()=>window.bootMessages.some(m=>m.kind==='presented'));
  assert.equal(await page.evaluate(()=>window.__voiceDiagnostics.state.time),0);
  assert.equal(await page.evaluate(()=>window.__startWelcome()),true);
  await page.waitForTimeout(150);
  const time=await page.evaluate(()=>window.__voiceDiagnostics.state.time);
  assert.ok(time>0 && time<1,'Timeline did not start from zero');
  await page.evaluate(()=>window.__timelines['jimmsun-intro'].progress(1));
  const messages=await page.evaluate(()=>window.bootMessages);
  assert.deepEqual(messages.filter(m=>['prepared','presented','ready','complete'].includes(m.kind)).map(m=>m.kind),['prepared','presented','ready','complete']);
  assert.ok(messages.filter(m=>['prepared','presented','ready'].includes(m.kind)).every(m=>m.time===0 && m.name==='Alex+Sun'));
  assert.deepEqual(errors,[]);
  console.log('Browser preview: centered orb and deferred first presentation PASS');
  url.searchParams.set('native-orb','1');
  await page.goto(url.href);await page.waitForFunction(()=>window.bootMessages.some(m=>m.kind==='prepared'));
  await page.waitForTimeout(150);
  const handoff=await page.evaluate(()=>({time:frameTime,orb:getComputedStyle(orb).opacity,logo:getComputedStyle(logo).opacity,atmosphere:document.querySelector('.atmosphere')}));
  assert.equal(handoff.time,1.72);assert.equal(handoff.orb,'0');assert.equal(handoff.logo,'0');assert.equal(handoff.atmosphere,null);
  assert.equal(await page.evaluate(()=>window.__startWelcome()),false);
  await page.evaluate(()=>window.__prepareWelcomeDisplay());
  await page.waitForFunction(()=>window.bootMessages.some(m=>m.kind==='presented'));
  await page.evaluate(()=>window.__startWelcome());await page.waitForTimeout(150);
  const continuation=await page.evaluate(()=>({time:frameTime,orb:getComputedStyle(orb).opacity,logo:getComputedStyle(logo).opacity}));
  assert.ok(continuation.time>1.72 && continuation.time<2.5,'Native opening restarted in the browser');
  assert.equal(continuation.orb,'0');assert.ok(+continuation.logo>0,'Logo did not continue after native collapse');
  await page.evaluate(()=>window.__timelines['jimmsun-intro'].progress(1));
  assert.ok((await page.evaluate(()=>window.bootMessages)).filter(m=>['prepared','presented','ready'].includes(m.kind)).every(m=>m.time===1.72));
  assert.deepEqual(errors,[]);
  console.log('Native opening: invisible logo entry, no second orb or timeline restart PASS');
  for(const system of ['light','dark'])for(const choice of ['system','dark','light']){
   await page.emulateMedia({colorScheme:system});url.searchParams.set('theme',choice);await page.goto(url.href);
   const expected=choice==='system'?system:choice;
   const appearance=await page.evaluate(()=>({dark:document.documentElement.classList.contains('dark'),background:getComputedStyle(document.body).backgroundColor,logo:getComputedStyle(document.getElementById('logo')).color}));
   assert.equal(appearance.dark,expected==='dark');assert.equal(appearance.background,expected==='dark'?'rgb(5, 6, 9)':'rgb(247, 246, 242)');
   assert.equal(appearance.logo,expected==='dark'?'rgb(240, 242, 247)':'rgb(36, 37, 39)');
  }
  console.log('Web appearance: system dark/light and both explicit overrides PASS');

 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
