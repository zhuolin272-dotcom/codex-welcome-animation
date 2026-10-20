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
  console.log('First-frame startup: held at zero until presentation, then correct start and completion PASS');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
