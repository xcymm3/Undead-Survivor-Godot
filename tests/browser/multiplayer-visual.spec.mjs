import { test, expect } from '@playwright/test';

test('多人建房界面不同状态的隔离截图', async ({ page }, info) => {
  test.setTimeout(600_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text());
  });
  await page.setViewportSize({ width: 1440, height: 900 });
  const scenarios = ['browser_steam', 'browser_lan', 'host_ready', 'direct_lan', 'direct_steam', 'filtered', 'empty', 'error'];
  for (const scenario of scenarios) {
    await page.goto(`/?campaignReview=multiplayer_${scenario}`);
    await page.waitForFunction(() => Boolean(window.__campaignReviewReady), null, { timeout: 90_000 });
    const state = await page.evaluate(() => window.__campaignReviewReady);
    expect(state.menu).toBe('multiplayer');
    const file = info.outputPath(`${scenario}.png`);
    await page.screenshot({ path: file, timeout: 60_000 });
    await info.attach(scenario, { path: file, contentType: 'image/png' });
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  await page.setViewportSize({ width: 960, height: 600 });
  for (const scenario of ['browser_lan', 'direct_lan']) {
    await page.goto(`/?campaignReview=multiplayer_${scenario}`);
    await page.waitForFunction(() => Boolean(window.__campaignReviewReady), null, { timeout: 90_000 });
    const file = info.outputPath(`${scenario}-960.png`);
    await page.screenshot({ path: file });
  }
  expect(errors).toEqual([]);
});
