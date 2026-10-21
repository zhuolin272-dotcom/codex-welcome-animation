// Pre-render the real cloud shader: 128 frames, 120 fps, a seamless ping-pong loop.
const {chromium}=require('playwright');
const {pathToFileURL}=require('node:url');const path=require('node:path');const fs=require('node:fs');
(async()=>{const browser=await chromium.launch({headless:true,...(process.platform==='win32'?{channel:'msedge'}:{})});try{
 const page=await browser.newPage();await page.goto(pathToFileURL(path.resolve(__dirname,'../docs/animation.html')).href);
 await page.waitForFunction(()=>window.__voiceDiagnostics);
 const png=await page.evaluate(()=>{
  if(!shaderReady)throw Error('WebGL is required only on the developer machine to generate the motion atlas');
  const atlas=document.createElement('canvas');atlas.width=4096;atlas.height=8192;canvas.width=canvas.height=512;gl.viewport(0,0,512,512);drawClouds(-.1);const context=atlas.getContext('2d');
  for(let frame=0;frame<128;frame++){
   drawClouds(.6*(1-Math.cos(2*Math.PI*frame/128)));gl.finish();
   context.drawImage(canvas,frame%8*512,Math.floor(frame/8)*512,512,512);
  }
  return atlas.toDataURL('image/png');
 });
 const bytes=Buffer.from(png.split(',')[1],'base64');fs.writeFileSync(path.resolve(__dirname,'../assets/orb-motion.png'),bytes);
 console.log('Native cloud motion: 128 shader frames at 120 fps, '+bytes.length+' bytes');
}finally{await browser.close()}})().catch(error=>{console.error(error);process.exitCode=1});
