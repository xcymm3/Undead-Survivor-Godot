import { test, expect } from '@playwright/test';

// Requested visual review only; every image uses the actual frozen production scene.
test('商店柜台、贴墙现状及四人底部技能布局', async ({ page }, info) => {
  test.setTimeout(600_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text());
  });
  for (const [scenario, width, height] of [
    ['overview', 1440, 900], ['front', 1440, 900], ['side', 1440, 900],
    ['wall', 1440, 900], ['four', 1440, 900], ['four', 960, 540],
    ['grenade', 1440, 900],
  ]) {
    await page.setViewportSize({ width, height });
    await page.goto(`/?preparationReview=shop_review_${scenario}`);
    await page.waitForFunction(() => Boolean(window.__shopHudReviewReady), null, { timeout: 90_000 });
    const state = await page.evaluate(() => window.__shopHudReviewReady);
    expect(state.owner_yaw).toBeCloseTo(Math.PI / 2, 4);
    expect(state.stations).toBe(9);
    if (scenario === 'front') expect(state.focus).toBe('shopkeeper');
    if (scenario === 'side') expect(state.focus).not.toBe('shopkeeper');
    if (scenario === 'four') {
      expect(state.health_rects).toHaveLength(4);
      expect(state.overlaps).toBe(false);
      expect(state.ultimate_rect.x + state.ultimate_rect.width / 2).toBeCloseTo(state.width / 2, 0);
    }
    expect(state.grenade_caption).toBe('');
    expect(state.grenade_progress).toBeCloseTo(.65, 3);
    const file = info.outputPath(`${scenario}-${width}.png`);
    await page.screenshot({ path: file });
    await info.attach(`${scenario}-${width}`, { path: file, contentType: 'image/png' });
    await info.attach(`${scenario}-${width}-state`, { body: JSON.stringify(state, null, 2), contentType: 'application/json' });
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  expect(errors).toEqual([]);
});
