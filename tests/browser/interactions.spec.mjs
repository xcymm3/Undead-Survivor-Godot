import { test, expect } from '@playwright/test';
test('physical interaction stages software review', async ({page},info)=>{
  test.setTimeout(240000);
  const errors=[];
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  await page.setViewportSize({width:1440,height:900});
  await page.goto('/?nightGallery=1');
  await page.waitForFunction(()=>window.__campaignGalleryReady,null,{timeout:90000});
  const cases=[
    ['door-reference-front',[0,70.5],.06,{start_motion:0,bar_removed:false}],
    ['door-reference-angle',[1.2,70.5],.06,{start_motion:0,bar_removed:false},undefined,.22],
    ['bar-locked',[0,69],-.12,{start_motion:0,bar_removed:false}],
    ['bar-falling',[0,69],-.24,{start_motion:0,bar_removed:true,bar_time:.4}],
    ['door-opening',[0,69],-.12,{start_motion:.5,bar_removed:true,bar_time:1}],
    ['door-open',[0,69],-.12,{start_motion:1,bar_removed:true,bar_time:2}],
    ['control-working',[14.4,-47.5],-.18,{exit_motion:0,holdout_started:true,holdout_time:15}],
    ['exit-opening',[12,-49],-.1,{exit_motion:.5,exit_control:true,holdout_started:true,holdout_time:30}],
    ['exit-closing',[12,-60],-.05,{exit_motion:.5,exit_control:true,holdout_started:true,holdout_time:30},undefined,Math.PI],
    ['pickup-start',[-3,72.3],-.55,{},.05],
    ['pickup-flight',[-3,72.3],-.55,{},.32],
    ['pickup-landed',[-3,72.3],-1.05,{},1.2]
  ];
  for(const [name,position,pitch,pose,pickup_time,yaw=0] of cases){
    const view={name:'night_street',position,pitch,yaw,interaction_pose:pose,pickup_time,inspect_drop:name==='pickup-landed',width:1440,height:900,time:3,party:1};
    await page.evaluate(v=>{window.__campaignView=v;},view);
    await page.waitForFunction(v=>JSON.stringify(window.__campaignRendered)===JSON.stringify(v),view);
    await page.screenshot({path:info.outputPath(name+'.png')});
  }
  expect(errors).toEqual([]);
  expect(await page.evaluate(()=>window.__qaSafety)).toEqual({pointerLockRequests:0,fullscreenRequests:0});
});

