import { test, expect } from '@playwright/test';

test('仅审查大招蓝色渐变充能环', async ({ page }, info) => {
  test.setTimeout(300_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text());
  });
  await page.setViewportSize({ width: 1440, height: 900 });
  for (const charge of [0, 65, 100]) {
    await page.goto(`/?preparationReview=ultimate_${charge}`);
    await page.waitForFunction(() => Boolean(window.__preparationReviewReady), null, { timeout: 90_000 });
    const state = await page.evaluate(() => window.__preparationReviewReady);
    expect(state.ring_count).toBe(1);
    expect(state.charge).toBeCloseTo(charge / 100, 3);
    expect(state.objective_text).toBe('修复水晶');
    const { x, y, width, height } = state.ring_rect;
    const file = info.outputPath(`ultimate-${charge}.png`);
    await page.screenshot({ path: file, clip: {
      x: Math.floor(x) - 24, y: Math.floor(y) - 8,
      width: Math.ceil(width) + 48, height: Math.ceil(height) + 16,
    } });
    await info.attach(`大招充能${charge}%`, { path: file, contentType: 'image/png' });
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  expect(errors).toEqual([]);
});
