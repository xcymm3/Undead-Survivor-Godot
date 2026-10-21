import {mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {test,expect} from '@playwright/test';

test('按需录制标准档爆炸回摆与距离衰减',async({page},info)=>{
 test.setTimeout(360000);
 const errors=[];
 page.on('pageerror',error=>errors.push(String(error)));
 page.on('console',message=>{if(/^(SCRIPT ERROR|ERROR):/.test(message.text()))errors.push(message.text());});
 await page.setViewportSize({width:960,height:600});
 const peaks=[];
 for(const scenario of ['shake_near','shake_far']){
  await page.goto(`/?campaignReview=${scenario}`);
  await page.waitForFunction(()=>window.__campaignReviewReady,null,{timeout:90000});
  const config=await page.evaluate(()=>window.__campaignReviewReady);
  const directory=info.outputPath(scenario);
  await mkdir(directory,{recursive:true});
  const samples=[];
  for(let frame=0;frame<config.frames;frame++){
   await page.evaluate(index=>window.__drawShakeFrame(index),frame);
   await page.waitForFunction(index=>window.__shakeFrame===index,frame);
   samples.push(await page.evaluate(()=>window.__shakeState));
   await page.screenshot({path:path.join(directory,`frame-${String(frame).padStart(3,'0')}.png`)});
  }
  expect(samples.slice(0,12).every(s=>s.yaw===0&&s.pitch===0)).toBe(true);
  expect(samples.every(s=>s.authority_yaw===0&&s.authority_pitch===0)).toBe(true);
  expect(samples.at(-1).remaining).toBe(0);
  expect(samples.at(-1).yaw).toBe(0);
  let crossings=0,previous=0;
  for(const sample of samples){if(Math.abs(sample.yaw)>1e-6){if(sample.yaw*previous<0)crossings++;previous=sample.yaw;}}
  expect(crossings).toBeGreaterThanOrEqual(5);
  peaks.push(Math.max(...samples.map(s=>Math.abs(s.yaw))));
  await writeFile(info.outputPath(`${scenario}.json`),JSON.stringify({config,samples},null,2));
  expect(await page.evaluate(()=>window.__qaSafety)).toEqual({pointerLockRequests:0,fullscreenRequests:0});
 }
 expect(peaks[0]).toBeGreaterThan(peaks[1]*2.5);
 expect(errors).toEqual([]);
});
