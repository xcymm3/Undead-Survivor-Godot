import { test, expect } from '@playwright/test';

test('隔离审查新出生动线、修复开波与玩具防线', async ({ page }, info) => {
  test.setTimeout(600_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text());
  });
  await page.setViewportSize({ width: 1440, height: 900 });
  for (const scenario of ['map_overview', 'map_spawn', 'crystal_broken', 'crystal_repaired', 'toy_turret', 'toy_mine', 'toy_stands']) {
    await page.goto(`/?preparationReview=${scenario}`);
    await page.waitForFunction(() => Boolean(window.__preparationReviewReady), null, { timeout: 90_000 });
    const state = await page.evaluate(() => window.__preparationReviewReady);
    expect(state.stations).toBe(8);
    if (scenario === 'crystal_broken') {
      expect(state.closed).toBe(false);
      expect(state.focus_visible).toBe(true);
      expect(state.focus_text).toContain('修复完成立即开始');
    }
    if (scenario === 'crystal_repaired') expect(state.closed).toBe(true);
    const file = info.outputPath(`${scenario}.png`);
    await page.screenshot({ path: file, timeout: 60_000 });
    await info.attach(scenario, { path: file, contentType: 'image/png' });
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  expect(errors).toEqual([]);
});
