import { test, expect } from '@playwright/test';

test('campaign can be selected and departed using real keyboard input', async ({ page }, info) => {
  await page.goto('/');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'home', null, { timeout: 90_000 });
  for (const text of ['单人模式']) {
    const button = await page.evaluate(text => window.__survivorSnapshot.buttons.find(b => b.text === text && !b.disabled), text);
    expect(button).toBeTruthy();
    const canvas = await page.locator('canvas').boundingBox();
    await page.mouse.click(canvas.x + (button.x + button.width / 2) * canvas.width / 1440,
      canvas.y + (button.y + button.height / 2) * canvas.height / 900);
    await page.waitForFunction(() => window.__survivorSnapshot?.map_id === 'graypine_night');
  }
  await page.waitForFunction(() => window.__survivorSnapshot?.mode === 'campaign');
  await page.keyboard.press('4');
  expect(await page.evaluate(() => window.__survivorSnapshot.player.grenades)).toBe(0);
  await page.waitForFunction(() => window.__survivorSnapshot.player.slot === 1);
  for (const slot of [2, 3, 5, 1]) {
    await page.keyboard.press(String(slot));
    await page.waitForFunction(slot => window.__survivorSnapshot?.player?.slot === slot, slot);
  }
  await page.keyboard.down('w');
  await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot?.campaign?.departed, null, { timeout: 15_000 });
  await page.keyboard.up('w');
  await page.keyboard.up('e');
  expect(await page.evaluate(() => window.__survivorSnapshot.campaign.gate_open)).toBe(true);
  await page.screenshot({ path: info.outputPath('campaign-real-input-departure.png') });
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});

test('campaign authored scene and HUD software visual evidence', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.goto('/?campaignGallery=1');
  await page.waitForFunction(() => window.__campaignGalleryReady, null, { timeout: 90_000 });
  for (const [width, height, views] of [
    [960, 540, ['hud_duo_empty', 'start', 'loot', 'grenade', 'medkit', 'heal_self', 'heal_other', 'axe']],
    [1440, 900, ['hud_duo', 'heal_self', 'heal_other']], [1920, 1080, ['hud_duo', 'loot', 'medkit']],
  ]) {
    await page.setViewportSize({ width, height });
    for (const name of views) {
      const view = { name: name.startsWith('hud_') ? 'start' : name, party: name.startsWith('hud_duo') || name === 'heal_other' ? 2 : 1, empty: name === 'hud_duo_empty', width, height, opened: name === 'exit' };
      await page.evaluate(view => { window.__campaignView = view; }, view);
      await page.waitForFunction(view => JSON.stringify(window.__campaignRendered) === JSON.stringify(view), view);
      const file = info.outputPath(`campaign-${name}-${width}.png`);
      await page.screenshot({ path: file });
      await info.attach(`campaign-${name}-${width}`, { path: file, contentType: 'image/png' });
    }
  }
  await page.setViewportSize({ width: 1440, height: 900 });
  for (const [phase,time] of [['lower',0.15],['retrieve',0.5],['wrap',1.4],['finish',2.5],['rise',2.9]]) {
    const view = {name:'heal_self',width:1440,height:900,party:1,heal_time:time,orbit:Math.PI};
    await page.evaluate(view => { window.__campaignView = view; }, view);
    await page.waitForFunction(view => JSON.stringify(window.__campaignRendered) === JSON.stringify(view), view);
    await page.screenshot({path:info.outputPath(`medical-front-${phase}.png`),timeout:60000});
  }
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});


test('night special infected software visual evidence', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.setViewportSize({width:1440,height:900});
  await page.goto('/?campaignGallery=1');
  await page.waitForFunction(() => window.__campaignGalleryReady, null, {timeout:90000});
  for (const kind of ['cone','bucket','imp','shield','berserker','football']) {
    const view = {name:'night_street',width:1440,height:900,party:1,special:kind};
    await page.evaluate(view => { window.__campaignView = view; }, view);
    await page.waitForFunction(view => JSON.stringify(window.__campaignRendered) === JSON.stringify(view), view);
    await page.screenshot({path:info.outputPath(`night-special-${kind}.png`),timeout:60000});
  }
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({pointerLockRequests:0,fullscreenRequests:0});
});
