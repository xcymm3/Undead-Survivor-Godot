import { test, expect } from '@playwright/test';

test('隔离审查地雷待机闪灯、触发灯及游戏菜单', async ({ page }, info) => {
  test.setTimeout(600_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text());
  });
  for (const scenario of ['bridge_guard', 'mine_blink_on', 'mine_blink_off', 'mine_triggered_on', 'settings', 'settings_graphics', 'saves']) {
    await page.setViewportSize({ width: 1440, height: 900 });
    const mine = scenario.startsWith('mine_') || scenario === 'bridge_guard';
    await page.goto(`/?${mine ? 'preparationReview' : 'campaignReview'}=${scenario}`);
    await page.waitForFunction(mine => Boolean(mine ? window.__preparationReviewReady : window.__campaignReviewReady), mine, { timeout: 90_000 });
    if (!mine) {
      const state = await page.evaluate(() => window.__campaignReviewReady);
      expect(state.menu).toBe(scenario === 'saves' ? 'saves' : 'settings');
    }
    const file = info.outputPath(`${scenario}.png`);
    await page.screenshot({ path: file, timeout: 60_000 });
    await info.attach(scenario, { path: file, contentType: 'image/png' });
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  for (const scenario of ['settings', 'settings_graphics', 'saves']) {
    await page.setViewportSize({ width: 960, height: 600 });
    await page.goto(`/?campaignReview=${scenario}`);
    await page.waitForFunction(() => window.__campaignReviewReady, null, { timeout: 90_000 });
    const file = info.outputPath(`${scenario}-960.png`);
    await page.screenshot({ path: file, timeout: 60_000 });
    await info.attach(`${scenario}-960`, { path: file, contentType: 'image/png' });
  }
  expect(errors).toEqual([]);
});
