import { test, expect } from '@playwright/test';

test('整备展台、关闭防护罩、金币与钱包图标截图', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  await page.setViewportSize({ width: 1440, height: 900 });
  for (const scenario of ['open', 'closed', 'rifle', 'coins']) {
    await page.goto(`/?preparationReview=${scenario}`);
    await page.waitForFunction(() => window.__preparationReviewReady, null, { timeout: 90_000 });
    const state = await page.evaluate(() => window.__preparationReviewReady);
    expect(state.stations).toBe(9);
    expect(state.closed).toBe(scenario === 'closed');
    await page.waitForTimeout(700);
    const file = info.outputPath(`${scenario}.png`);
    await page.screenshot({ path: file, timeout: 60_000 });
    await info.attach(scenario, { path: file, contentType: 'image/png' });
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  expect(errors).toEqual([]);
});
