const {chromium}=require('playwright');
const {pathToFileURL}=require('node:url');const path=require('node:path');const fs=require('node:fs');
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 try{
  const page=await browser.newPage();await page.goto(pathToFileURL(path.resolve(__dirname,'../docs/animation.html')).href);
  await page.waitForFunction(()=>window.__voiceDiagnostics);
  const frame=await page.evaluate(()=>{window.__timelines['jimmsun-intro'].pause(0);if(!shaderReady)throw Error('Shader unavailable');gl.finish();return document.getElementById('clouds').toDataURL('image/png')});
  const data=Buffer.from(frame.split(',')[1],'base64');fs.writeFileSync(path.resolve(__dirname,'../assets/startup-cloud.png'),data);fs.writeFileSync(path.resolve(__dirname,'../docs/orb-cloud.png'),data);console.log('Startup cloud generated from t=0 shader: '+data.length+' bytes');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
