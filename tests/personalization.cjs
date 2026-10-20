const assert = require('node:assert/strict');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
const {chromium} = require('playwright');
(async () => {
  const browser = await chromium.launch({headless:true, ...(process.platform === 'win32' ? {channel:'msedge'} : {})});
  try {
    const page = await browser.newPage({viewport:{width:1440,height:900}});
    const errors = []; page.on('pageerror', error => errors.push(String(error)));
    const base = pathToFileURL(path.resolve(__dirname, '../docs/animation.html'));
    for (const [name, mode] of [['JimmSun','handwriting'], ['Alex Sun','handwriting'], ['Élodie 2026','handwriting'], ['WWWWWWWWWWWWWWWWWWWW','handwriting'], ['小明','smooth-reveal'], ['<img src=x>','handwriting']]) {
      base.search = new URLSearchParams({name});
      await page.goto(base.href);
      await page.waitForFunction(() => window.__voiceDiagnostics);
      const result = await page.evaluate(() => {
        const d = window.__voiceDiagnostics;
        const timeline = window.__timelines['jimmsun-intro'];
        timeline.pause(3.62);
        const initiallyHidden = d.letters.every(s => Number(s.el.style.strokeDashoffset) >= s.length);
        timeline.pause(7.3);
        const fullyWritten = d.letters.every(s => Math.abs(Number(s.el.style.strokeDashoffset)) < .01);
        const group = document.getElementById('personal-name');
        const bounds = group?.getBoundingClientRect();
        return {name:d.personalization.name,mode:d.personalization.mode,initiallyHidden,fullyWritten,
          inFrame:!bounds || bounds.left >= 0 && bounds.right <= innerWidth,
          centered:!bounds || Math.abs(bounds.x+bounds.width/2-innerWidth/2)<1,
          injected:!!document.querySelector('#personal-name img, #personal-name script')};
      });
      assert.equal(result.name,name); assert.equal(result.mode,mode);
      assert.ok(result.initiallyHidden && result.fullyWritten && result.inFrame && result.centered && !result.injected, JSON.stringify(result));
    }
    await page.goto(pathToFileURL(path.resolve(__dirname, '../docs/index.html')).href);
    await page.getByRole('button',{name:'名字',exact:false}).click();
    await page.getByLabel('动画中的名字').fill('  Alex Sun  ');
    await page.getByRole('button',{name:'保存并预览'}).click();
    await page.frameLocator('#film').locator('#writing').waitFor();
    await page.waitForFunction(() => document.getElementById('display-name').textContent === 'Alex Sun');
    await page.reload();
    assert.equal(await page.locator('#display-name').textContent(),'Alex Sun');
    const validation = await page.evaluate(() => ({
      normalized:CWPersonalization.validate(' e\u0301 '),
      rejected:['',' '.repeat(2),'x'.repeat(21),'A\nB','A\u202eB'].every(value => {try{CWPersonalization.validate(value);return false}catch(_){return true}})
    }));
    assert.equal(validation.normalized,'é'); assert.ok(validation.rejected);
    assert.deepEqual(errors,[]);
    console.log('Personalization: English ink / Chinese reveal / long-name fit / safe text / saved preview / validation PASS');
  } finally { await browser.close(); }
})().catch(error => {console.error(error);process.exitCode=1});
