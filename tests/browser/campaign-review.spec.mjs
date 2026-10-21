import {mkdir,readFile} from 'node:fs/promises';
import {PNG} from 'pngjs';
import path from 'node:path';
import {test,expect} from '@playwright/test';
test('战斗反馈、主页、设置与失败镜头隔离截图',async({page},info)=>{
 test.setTimeout(900000);
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',message=>{if(/^(SCRIPT ERROR|ERROR):/.test(message.text()))errors.push(message.text());});
 await page.setViewportSize({width:1440,height:900});
 const scenarios=process.env.QA_MELEE_FLOW_REVIEW ? ['axe_comparison','axe_attack','ultimate_attack','ultimate_flow'] : process.env.QA_MELEE_REVIEW ? ['axe_comparison','ultimate_draw','ultimate_attack','ultimate_sheathe'] : process.env.QA_BLADE_ATTACK_ONLY ? ['ultimate_attack'] : process.env.QA_SHIELD_BLADE_ONLY ? ['toy_shield','ultimate_draw','ultimate_attack','ultimate_sheathe'] : process.env.QA_TOYS_ONLY ? ['toy_normal','toy_cone','toy_bucket','toy_imp','toy_shield','toy_berserker','toy_berserker_rage','toy_giant','toy_football','toy_dancer','toy_lineup'] : process.env.QA_FACE_ONLY ? ['normal_studio','normal_lineup','normal_night'] : process.env.QA_NORMAL_ONLY ? ['normal_studio','normal_lineup','normal_night','normal_walk','normal_idle','normal_attack','normal_hit','normal_shove','normal_stunned','normal_death','normal_emerge'] : process.env.QA_SWITCH_ONLY ? ['switch_rifle_raise','switch_rifle_bolt','switch_pistol_spin'] : ['switch_rifle_raise','switch_rifle_bolt','switch_pistol_spin','interaction_station','interaction_gate','crystal_half','crystal_broken','heal','boss','home','home_hover','failure_player','failure_crystal','settings'];
 for(const scenario of scenarios){
  await page.setViewportSize((scenario.startsWith('ultimate_')||scenario==='axe_attack')?{width:960,height:600}:scenario==='toy_lineup'?{width:1920,height:1080}:{width:1440,height:900});
  await page.goto(`/?campaignReview=${scenario}`);
  await page.waitForFunction(()=>window.__campaignReviewReady,null,{timeout:90000});
  const state=await page.evaluate(()=>window.__campaignReviewReady);
  if(scenario.startsWith('normal_')){expect(state.count).toBe(scenario==='normal_lineup'?5:1);expect(state.head_size).toEqual([.49,.49,.45]);expect(state.roughness).toBeCloseTo(.3);}
  if(scenario.startsWith('toy_')){expect(state.count).toBe(scenario==='toy_lineup'?9:1);expect(state.kinds.length).toBe(scenario==='toy_lineup'?9:1);}
  if(scenario==='axe_comparison')expect(state.head_lift).toBeCloseTo(.2046,3);
  if(scenario==='crystal_half')expect(state.cracks).toBe(true);
  if(scenario==='crystal_broken')expect(state.fragments).toBe(true);
  if(scenario==='boss')expect(state.boss).toContain('62450');
  if(scenario.startsWith('failure'))expect(state.menu).not.toBe('result');
  if(scenario.startsWith('home'))expect(state.menu).toBe('home');
  if(scenario==='settings')expect(state.menu).toBe('settings');
  if(scenario.startsWith('interaction_')){expect(state.focus_visible).toBe(true);expect(state.ring).toBe(true);expect(state.payments).toBeGreaterThan(0);}
  if(!scenario.startsWith('normal_') && !scenario.startsWith('toy_') && !['home','home_hover','settings','interaction_station','interaction_gate'].includes(scenario))expect(state.focus_visible).toBe(false);
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
  if(scenario.startsWith('ultimate_')||scenario==='axe_attack'){
   const directory=info.outputPath(`${scenario.replaceAll('_','-')}-frames`);
   await mkdir(directory,{recursive:true});
   const samples=[];
   for(let frame=0;frame<state.frames;frame++){
    await page.evaluate(index=>window.__drawUltimateAction(index),frame);
    await page.waitForFunction(index=>window.__ultimateActionFrame===index,frame,{timeout:15000});
    samples.push(await page.evaluate(()=>window.__ultimateActionState));
    if(!(process.env.QA_MELEE_REVIEW||process.env.QA_MELEE_FLOW_REVIEW) || frame%(state.fps===60?3:state.fps===30?2:1)===0)
    await page.screenshot({path:path.join(directory,`frame-${String(frame).padStart(3,'0')}.png`),timeout:60000});
   }
   if(scenario==='axe_attack'){
    expect(samples.some(s=>s.fire>0)).toBe(true);expect(samples.every(s=>s.axe&&!s.blade&&!s.active)).toBe(true);
   }else{
    expect(samples.some(s=>s.blade)).toBe(true);expect(samples.filter(s=>s.blade).every(s=>s.energy)).toBe(true);expect(samples.filter(s=>s.active).every(s=>!s.axe)).toBe(true);
   }
   if(scenario==='ultimate_flow'){
    expect(samples.every(s=>s.energy&&!s.trail)).toBe(true);
    await page.evaluate(index=>window.__drawUltimateAction(index),state.frames);
    await page.waitForFunction(index=>window.__ultimateActionFrame===index,state.frames);
    const wrap=info.outputPath('flow-wrap.png');await page.screenshot({path:wrap});
    const first=PNG.sync.read(await readFile(path.join(directory,'frame-000.png')));
    const last=PNG.sync.read(await readFile(wrap));let error=0,count=0;
    for(let i=0;i<first.data.length;i+=4){
     if(first.data[i+2]-first.data[i]>40 && first.data[i+2]-first.data[i+1]>10){
      for(let c=0;c<3;c++)error+=Math.abs(first.data[i+c]-last.data[i+c]);count++;
     }
    }
    expect(count).toBeGreaterThan(300);expect(error/(count*3)).toBeLessThan(3);
    await info.attach('蓝芒首尾接缝检查',{body:JSON.stringify({seconds:state.frames/state.fps,bluePixels:count,meanRgbError:error/(count*3)}),contentType:'application/json'});
   }
   if(scenario==='ultimate_draw'){expect(samples[0].active).toBe(false);expect(samples.at(-1).active).toBe(true);expect(samples.some(s=>s.scabbard)).toBe(true);expect(samples.at(-1).scabbard).toBe(false);}
   if(scenario==='ultimate_attack'){expect(samples.some(s=>s.fire>0)).toBe(true);expect(samples.every(s=>!s.scabbard)).toBe(true);expect(samples.every(s=>s.energy)).toBe(true);expect(samples.some(s=>s.trail)).toBe(true);expect(samples.at(-1).trail).toBe(false);expect(samples.every(s=>s.trail_samples<=24)).toBe(true);}
   if(scenario==='ultimate_sheathe'){expect(samples.some(s=>s.sheathe>0)).toBe(true);expect(samples.at(-1).blade).toBe(false);}
   await info.attach(`${scenario}-timing`,{body:JSON.stringify({frames:state.frames,fps:state.fps,samples}),contentType:'application/json'});
  }
  expect(await page.evaluate(()=>window.__qaSafety)).toEqual({pointerLockRequests:0,fullscreenRequests:0});
 }
 expect(errors).toEqual([]);
});
