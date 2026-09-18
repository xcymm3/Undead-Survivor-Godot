import { test, expect } from '@playwright/test';
test('crawler stays prone in idle crawl and attack software views', async ({page}, info) => {
  const errors=[];
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  await page.setViewportSize({width:1440,height:900});
  await page.goto('/?nightGallery=1');
  await page.waitForFunction(()=>window.__campaignGalleryReady,null,{timeout:90000});
  for(const [name,extra] of [['idle',{}],['left',{crawler_moving:true,crawler_gait:Math.PI/2}],['right',{crawler_moving:true,crawler_gait:Math.PI*1.5}],['attack',{crawler_attack:.5}],['side',{crawler_moving:true,crawler_gait:Math.PI/2,crawler_heading:Math.PI/2}]]) {
    const view={name:'night_street',position:[8,60],width:1440,height:900,time:3,party:1,yaw:0,pitch:-.18,special:'crawler',...extra};
    await page.evaluate(v=>{window.__campaignView=v;},view);
    await page.waitForFunction(v=>JSON.stringify(window.__campaignRendered)===JSON.stringify(v),view);
    await page.screenshot({path:info.outputPath(`${name}.png`)});
  }
  expect(errors).toEqual([]);
  expect(await page.evaluate(()=>window.__qaSafety)).toEqual({pointerLockRequests:0,fullscreenRequests:0});
});
