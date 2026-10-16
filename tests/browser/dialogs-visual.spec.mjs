import { test, expect } from '@playwright/test';

test('隔离审查结束、设置与存档弹窗', async ({ page }, info) => {
  test.setTimeout(600_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text());
  });
  for (const width of [1440, 960]) {
    await page.setViewportSize({ width, height: width === 1440 ? 900 : 600 });
    for (const scenario of ['result_player', 'result_crystal', 'settings', 'saves']) {
      await page.goto(`/?campaignReview=${scenario}`);
      await page.waitForFunction(() => Boolean(window.__campaignReviewReady), null, { timeout: 90_000 });
      const state = await page.evaluate(() => window.__campaignReviewReady);
      expect(state.menu).toBe(scenario.startsWith('result_') ? 'result' : scenario);
      if (scenario === 'result_player') expect(state.fragments).toBe(false);
      if (scenario === 'result_crystal') expect(state.fragments).toBe(true);
      const file = info.outputPath(`${scenario}-${width}.png`);
      await page.screenshot({ path: file, timeout: 60_000 });
      await info.attach(`${scenario}-${width}`, { path: file, contentType: 'image/png' });
      expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
    }
  }
  expect(errors).toEqual([]);
});
