import { test, expect } from '@playwright/test';

test('night route software visual matrix', async ({ page }, info) => {
  // Dense shadowed scenes use software rendering in CI; image capture is not an input-latency check.
  test.setTimeout(360_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.goto('/?nightGallery=1');
  await page.waitForFunction(() => window.__campaignGalleryReady, null, { timeout: 90_000 });
  for (const [width, height] of [[960, 540], [1440, 900], [1920, 1080]]) {
    await page.setViewportSize({ width, height });
    for (const name of ['night_street', 'night_shop', 'night_woods', 'night_exit']) {
      const view = { name, width, height, time: 2.5, party: width === 1920 ? 2 : 1 };
      await page.evaluate(view => { window.__campaignView = view; }, view);
      await page.waitForFunction(view => JSON.stringify(window.__campaignRendered) === JSON.stringify(view), view);
      await page.screenshot({ path: info.outputPath(`${name}-${width}.png`), timeout: 60_000 });
    }
  }
  await page.setViewportSize({ width: 1440, height: 900 });
  const idle = { name: 'night_woods', width: 1440, height: 900, time: 7.3, party: 1 };
  await page.evaluate(view => { window.__campaignView = view; }, idle);
  await page.waitForFunction(view => JSON.stringify(window.__campaignRendered) === JSON.stringify(view), idle);
  await page.screenshot({ path: info.outputPath('night_woods-idle-later-1440.png'), timeout: 60_000 });
  for (const state of [{holdout:false, holdout_time:0, unlocked:false}, {holdout:true, holdout_time:15, unlocked:false}, {holdout:true, holdout_time:30, unlocked:true}]) {
    const view = {name:'night_exit',width:1440,height:900,time:3,party:2,...state};
    await page.evaluate(view => { window.__campaignView = view; }, view);
    await page.waitForFunction(view => JSON.stringify(window.__campaignRendered) === JSON.stringify(view), view);
    await page.screenshot({path:info.outputPath(`holdout-${state.holdout_time}.png`),timeout:60_000});
  }
  for (const [name,position] of [['start',[-3,74]],['shop',[-14,28]],['van',[-12,-29]]]) {
    const view = {name:'loot',position,yaw:0,pitch:0,width:1440,height:900,time:3,party:2,rear_hit:name==='start'};
    await page.evaluate(view => { window.__campaignView = view; }, view);
    await page.waitForFunction(view => JSON.stringify(window.__campaignRendered) === JSON.stringify(view), view);
    await page.screenshot({path:info.outputPath(`wall-rack-${name}.png`),timeout:60_000});
  }
  for (const shotgun of [4, 8]) {
    for (const fired of [false, true]) {
      const view = {name:'night_street',position:[0,60],yaw:0,pitch:-0.1,width:1440,height:900,time:3,party:1,shotgun,fired};
      await page.evaluate(view => { window.__campaignView = view; }, view);
      await page.waitForFunction(view => JSON.stringify(window.__campaignRendered) === JSON.stringify(view), view);
      await page.screenshot({path:info.outputPath(`shotgun-${shotgun}-${fired ? 'impact' : 'ready'}.png`),timeout:60_000});
    }
  }
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
