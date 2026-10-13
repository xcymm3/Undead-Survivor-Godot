import {test,expect} from '@playwright/test';
test('战斗反馈、主页、设置与失败镜头隔离截图',async({page},info)=>{
 test.setTimeout(900000);
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',message=>{if(/^(SCRIPT ERROR|ERROR):/.test(message.text()))errors.push(message.text());});
 await page.setViewportSize({width:1440,height:900});
 for(const scenario of ['interaction_station','interaction_gate','crystal_half','crystal_broken','heal','boss','home','home_hover','failure_player','failure_crystal','settings']){
  await page.goto(`/?campaignReview=${scenario}`);
  await page.waitForFunction(()=>window.__campaignReviewReady,null,{timeout:90000});
  const state=await page.evaluate(()=>window.__campaignReviewReady);
  if(scenario==='crystal_half')expect(state.cracks).toBe(true);
  if(scenario==='crystal_broken')expect(state.fragments).toBe(true);
  if(scenario==='boss')expect(state.boss).toContain('62450');
  if(scenario.startsWith('failure'))expect(state.menu).not.toBe('result');
  if(scenario.startsWith('home'))expect(state.menu).toBe('home');
  if(scenario==='settings')expect(state.menu).toBe('settings');
  if(scenario.startsWith('interaction_')){expect(state.focus_visible).toBe(true);expect(state.ring).toBe(true);expect(state.payments).toBeGreaterThan(0);}
  if(!['home','home_hover','settings','interaction_station','interaction_gate'].includes(scenario))expect(state.focus_visible).toBe(false);
  const file=info.outputPath(`${scenario}.png`);
  await page.screenshot({path:file,timeout:60000});
  await info.attach(scenario,{path:file,contentType:'image/png'});
  expect(await page.evaluate(()=>window.__qaSafety)).toEqual({pointerLockRequests:0,fullscreenRequests:0});
 }
 expect(errors).toEqual([]);
});
