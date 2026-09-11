import {chromium} from '@playwright/test';
import {spawn} from 'node:child_process';
import {mkdir} from 'node:fs/promises';
import path from 'node:path';
const out=process.argv[2]||'artifacts/visual-reviewed'; await mkdir(out,{recursive:true});
const server=spawn(process.execPath,[path.resolve('tools/serve-web.mjs')],{cwd:path.resolve('artifacts/visual-project'),windowsHide:true,stdio:['ignore','pipe','pipe']});let browser;
try {await new Promise((r,j)=>{server.stdout.once('data',r);server.once('error',j);server.once('exit',code=>j(new Error('Visual server exited '+code)))});
 browser=await chromium.launch({headless:true,args:['--use-angle=swiftshader','--enable-unsafe-swiftshader','--mute-audio']});const page=await browser.newPage({viewport:{width:960,height:600}}); const errors=[];page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 await page.goto('http://127.0.0.1:4178');await page.waitForFunction(()=>window.__visualReady,{},{timeout:90000});
 const full=true;
 const extraOnly=process.argv.includes("--extra");
 for(const weapon of extraOnly?[]:process.argv.includes('--axe')?[6]:[0,1,2,3,4,5,6,7,8,9]) for(const view of ['side','front','first']) for(const [action,phase] of full?[['idle',0],['aim',0],['fire',.025],['reload',.5]]:[['idle',0],['fire',.025]]) {
 const spec={weapon,view,action,phase,model:0}; await page.evaluate(s=>window.__visualPose=s,spec);await page.waitForFunction(s=>window.__visualReady===JSON.stringify(s),spec);await page.waitForTimeout(150);await page.screenshot({path:`${out}/${weapon}-${view}-${action}.png`}); }
 for(const model of [0,1,2,3]) for(const weapon of [0,2]) {
 const spec={weapon,view:'front',action:'aim',phase:0,model};await page.evaluate(s=>window.__visualPose=s,spec);await page.waitForFunction(s=>window.__visualReady===JSON.stringify(s),spec);await page.screenshot({path:`${out}/model-${model}-weapon-${weapon}.png`});}
 for(const phase of [.22,.52,.66]) for(const view of ['first','side']) {
 const spec={weapon:6,view,action:'fire',phase,model:0};await page.evaluate(s=>window.__visualPose=s,spec);await page.waitForFunction(s=>window.__visualReady===JSON.stringify(s),spec);await page.screenshot({path:`${out}/axe-${view}-${phase}.png`});}
 const spec={view:'lineup',weapon:0,model:0,action:'idle',phase:0};
 await page.evaluate(s=>window.__visualPose=s,spec);await page.waitForFunction(s=>window.__visualReady===JSON.stringify(s),spec);await page.waitForTimeout(200);await page.screenshot({path:`${out}/survivor-lineup.png`});
 const safety=await page.evaluate(()=>({requests:window.__qaSafety,locked:!!document.pointerLockElement}));if(safety.locked||safety.requests.pointerLockRequests||safety.requests.fullscreenRequests)throw new Error('Desktop safety violation');if(errors.length)throw new Error(errors.join('\n'));
 console.log('CAPTURE COMPLETE '+out);
} finally {await browser?.close();server.kill()}
