import { test, expect } from '@playwright/test';

test('night route software visual matrix', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.goto('/?nightGallery=1');
  await page.waitForFunction(() => window.__campaignGalleryReady, null, { timeout: 90_000 });
  for (const [width, height] of [[960, 540], [1440, 900], [1920, 1080]]) {
    await page.setViewportSize({ width, height });
    for (const name of ['night_street', 'night_shop', 'night_woods', 'night_exit']) {
      const view = { name, width, height, time: 2.5, party: width === 1920 ? 4 : 1 };
      await page.evaluate(view => { window.__campaignView = view; }, view);
      await page.waitForFunction(view => JSON.stringify(window.__campaignRendered) === JSON.stringify(view), view);
      await page.screenshot({ path: info.outputPath(`${name}-${width}.png`) });
    }
  }
  await page.setViewportSize({ width: 1440, height: 900 });
  const idle = { name: 'night_woods', width: 1440, height: 900, time: 7.3, party: 1 };
  await page.evaluate(view => { window.__campaignView = view; }, idle);
  await page.waitForFunction(view => JSON.stringify(window.__campaignRendered) === JSON.stringify(view), idle);
  await page.screenshot({ path: info.outputPath('night_woods-idle-later-1440.png') });
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
