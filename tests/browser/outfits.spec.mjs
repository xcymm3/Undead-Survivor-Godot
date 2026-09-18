import { test, expect } from '@playwright/test';
test('five outfits on ordinary crawler cone and bucket software views', async ({page},info)=>{
  test.setTimeout(240000);
  const errors=[];
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  await page.setViewportSize({width:1440,height:900});
  await page.goto('/?nightGallery=1');
  await page.waitForFunction(()=>window.__campaignGalleryReady,null,{timeout:90000});
  for(const [name,kind,extra] of [['normal','normal',{}],['crawler','crawler',{}],['cone','cone',{}],['bucket','bucket',{}],['crawl-left','crawler',{outfit_moving:true,outfit_gait:Math.PI/2}],['crawl-right','crawler',{outfit_moving:true,outfit_gait:Math.PI*1.5}],['crawl-side','crawler',{outfit_heading:Math.PI/2,outfit_moving:true,outfit_gait:Math.PI/2}],['attack','normal',{outfit_attack:.4}]]) {
    const view={name:'night_street',position:[8,50],width:1440,height:900,time:3,party:1,yaw:0,pitch:kind==='crawler'?-.16:-.03,outfits:kind,...extra};
    await page.evaluate(v=>{window.__campaignView=v;},view);
    await page.waitForFunction(v=>JSON.stringify(window.__campaignRendered)===JSON.stringify(v),view);
    await page.screenshot({path:info.outputPath(`${name}.png`)});
  }
  expect(errors).toEqual([]);
  expect(await page.evaluate(()=>window.__qaSafety)).toEqual({pointerLockRequests:0,fullscreenRequests:0});
});

