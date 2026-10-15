import {mkdir} from 'node:fs/promises';
import path from 'node:path';
import {test,expect} from '@playwright/test';
test('战斗反馈、主页、设置与失败镜头隔离截图',async({page},info)=>{
 test.setTimeout(900000);
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',message=>{if(/^(SCRIPT ERROR|ERROR):/.test(message.text()))errors.push(message.text());});
 await page.setViewportSize({width:1440,height:900});
 const scenarios=process.env.QA_NORMAL_ONLY ? ['normal_studio','normal_lineup','normal_night','normal_walk','normal_idle','normal_attack','normal_hit','normal_shove','normal_stunned','normal_death','normal_emerge'] : process.env.QA_SWITCH_ONLY ? ['switch_rifle_raise','switch_rifle_bolt','switch_pistol_spin'] : ['switch_rifle_raise','switch_rifle_bolt','switch_pistol_spin','interaction_station','interaction_gate','crystal_half','crystal_broken','heal','boss','home','home_hover','failure_player','failure_crystal','settings'];
 for(const scenario of scenarios){
  await page.goto(`/?campaignReview=${scenario}`);
  await page.waitForFunction(()=>window.__campaignReviewReady,null,{timeout:90000});
  const state=await page.evaluate(()=>window.__campaignReviewReady);
  if(scenario.startsWith('normal_')){expect(state.count).toBe(scenario==='normal_lineup'?5:1);expect(state.head_size).toEqual([.49,.49,.45]);expect(state.roughness).toBeCloseTo(.3);}
  if(scenario==='crystal_half')expect(state.cracks).toBe(true);
  if(scenario==='crystal_broken')expect(state.fragments).toBe(true);
  if(scenario==='boss')expect(state.boss).toContain('62450');
  if(scenario.startsWith('failure'))expect(state.menu).not.toBe('result');
  if(scenario.startsWith('home'))expect(state.menu).toBe('home');
  if(scenario==='settings')expect(state.menu).toBe('settings');
  if(scenario.startsWith('interaction_')){expect(state.focus_visible).toBe(true);expect(state.ring).toBe(true);expect(state.payments).toBeGreaterThan(0);}
  if(!scenario.startsWith('normal_') && !['home','home_hover','settings','interaction_station','interaction_gate'].includes(scenario))expect(state.focus_visible).toBe(false);
  const file=info.outputPath(`${scenario}.png`);
  await page.screenshot({path:file,timeout:60000});
  await info.attach(scenario,{path:file,contentType:'image/png'});
  if(scenario.startsWith('normal_') && state.frames>0){
   const directory=info.outputPath(`${scenario.replaceAll('_','-')}-frames`);
   await mkdir(directory,{recursive:true});
   await info.attach(`${scenario}-timing`,{body:JSON.stringify({frames:state.frames,fps:state.fps}),contentType:'application/json'});
   for(let frame=0;frame<state.frames;frame++){
    await page.evaluate(index=>window.__drawNormalAction(index),frame);
    await page.waitForFunction(index=>window.__normalActionFrame===index,frame,{timeout:15000});
    await page.screenshot({path:path.join(directory,`frame-${String(frame).padStart(3,'0')}.png`),timeout:60000});
   }
  }
  expect(await page.evaluate(()=>window.__qaSafety)).toEqual({pointerLockRequests:0,fullscreenRequests:0});
 }
 expect(errors).toEqual([]);
});
