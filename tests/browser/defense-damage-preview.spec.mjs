import { test, expect } from '@playwright/test';

test('防御建筑完整与半血外观对比', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  await page.setViewportSize({ width: 1440, height: 900 });
  for (const [state, title] of [['intact', '防御建筑-完整'], ['damaged', '防御建筑-半血破损与冒烟']]) {
    await page.goto('/?defenseStructures=' + state);
    await page.waitForFunction(() => window.__defenseStructuresReady, null, { timeout: 90_000 });
    await page.waitForTimeout(900);
    const file = info.outputPath(title + '.png');
    await page.screenshot({ path: file });
    await info.attach(title, { path: file, contentType: 'image/png' });
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  expect(errors).toEqual([]);
});
