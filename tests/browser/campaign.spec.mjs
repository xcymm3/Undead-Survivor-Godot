import { test, expect } from '@playwright/test';

test('campaign can be selected and departed using real keyboard input', async ({ page }, info) => {
  await page.goto('/');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'home', null, { timeout: 90_000 });
  for (const text of ['灰松渡口', '单人模式']) {
    const button = await page.evaluate(text => window.__survivorSnapshot.buttons.find(b => b.text === text && !b.disabled), text);
    expect(button).toBeTruthy();
    const canvas = await page.locator('canvas').boundingBox();
    await page.mouse.click(canvas.x + (button.x + button.width / 2) * canvas.width / 1440,
      canvas.y + (button.y + button.height / 2) * canvas.height / 900);
    await page.waitForFunction(() => window.__survivorSnapshot?.map_id === 'graypine_ferry');
  }
  await page.waitForFunction(() => window.__survivorSnapshot?.mode === 'campaign');
  await page.keyboard.down('w');
  await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot?.campaign?.departed, null, { timeout: 15_000 });
  await page.keyboard.up('w');
  await page.keyboard.up('e');
  expect(await page.evaluate(() => window.__survivorSnapshot.campaign.gate_open)).toBe(false);
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
    [960, 540, ['start', 'street', 'yard', 'control', 'bridge', 'river', 'gate', 'shed', 'exit']],
    [1440, 900, ['control']], [1920, 1080, ['exit']],
  ]) {
    await page.setViewportSize({ width, height });
    for (const name of views) {
      const view = { name, width, height, opened: name === 'exit' };
      await page.evaluate(view => { window.__campaignView = view; }, view);
      await page.waitForFunction(view => JSON.stringify(window.__campaignRendered) === JSON.stringify(view), view);
      const file = info.outputPath(`campaign-${name}-${width}.png`);
      await page.screenshot({ path: file });
      await info.attach(`campaign-${name}-${width}`, { path: file, contentType: 'image/png' });
    }
  }
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
