import { test, expect } from '@playwright/test';

// Requested visual review only; every image uses the actual frozen production scene.
test('商店柜台、贴墙现状及四人底部技能布局', async ({ page }, info) => {
  test.setTimeout(600_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text());
  });
  for (const [scenario, width, height] of (process.env.QA_SHOP_FIX_ONLY ? [['entry',1440,900],['dialogue_near',1440,900],['dialogue_normal',1440,900],['dialogue_near',960,600]] : process.env.QA_HEALTH_ROW_ONLY ? [['four',1440,900],['four',960,540]] : [
    ['front', 1440, 900], ['side', 1440, 900], ['wall', 1440, 900],
    ['four', 1440, 900], ['four', 960, 540],
    ['locked', 1440, 900], ['ready', 1440, 900], ['flow', 1440, 900],
  ])) {
    await page.setViewportSize({ width, height });
    await page.goto(`/?preparationReview=shop_review_${scenario}`);
    await page.waitForFunction(() => Boolean(window.__shopHudReviewReady), null, { timeout: 90_000 });
    const state = await page.evaluate(() => window.__shopHudReviewReady);
    expect(state.owner_yaw).toBeCloseTo(0, 4);
    expect(state.stations).toBe(9);
    if (process.env.QA_SHOP_FIX_ONLY) {
      const fix = await page.evaluate(() => window.__shopFixReview);
      expect(fix.doorway_posts).toBe(0);
      if (scenario.startsWith('dialogue_')) {
        expect(fix.dialogue_visible).toBe(true);
        expect(fix.dialogue).toBe('要对付僵尸，光靠勇气可不够，你还得有好的武器');
        expect(fix.center.y).toBeGreaterThan(height * .1);
        expect(fix.center.y).toBeLessThan(height * .8);
        if (scenario === 'dialogue_near') expect(fix.distance).toBeCloseTo(1.5, 2);
      }
      await info.attach(`${scenario}-${width}-fix`, { body: JSON.stringify(fix, null, 2), contentType: 'application/json' });
    }
    if (scenario === 'front') expect(state.focus).toBe('shopkeeper');
    if (scenario === 'side') expect(state.focus).not.toBe('shopkeeper');
    if (scenario === 'four') {
      expect(state.health_rects).toHaveLength(1);
      expect(state.left_count).toBe(1);
      expect(state.right_count).toBe(0);
      expect(state.health_rects.every(rect => Math.abs(rect.y-state.health_rects[0].y)<.5)).toBe(true);
      expect(state.no_portraits).toBe(true);
      expect(state.overlaps).toBe(false);
      expect(state.ultimate_rect.x + state.ultimate_rect.width / 2).toBeCloseTo(state.width / 2, 0);
    }
    expect(state.ultimate_visible).toBe(true);
    if (scenario === 'ready') {
      expect(state.ready_flash).toBeGreaterThan(0);
      expect(state.ready_flash_count).toBeGreaterThan(0);
    }
    expect(state.grenade_rect.x).toBeGreaterThan(state.width * .75);
    expect(state.first_person).toBe(true);
    expect(state.grenade_caption).toBe('');
    expect(state.grenade_progress).toBeCloseTo(.65, 3);
    const file = info.outputPath(`${scenario}-${width}.png`);
    await page.screenshot({ path: file, timeout: 60_000 });
    await info.attach(`${scenario}-${width}`, { path: file, contentType: 'image/png' });
    await info.attach(`${scenario}-${width}-state`, { body: JSON.stringify(state, null, 2), contentType: 'application/json' });
    if (scenario === 'flow') {
      const rect = state.ultimate_rect;
      for (let frame = 0; frame < 20; frame++) {
        const time = frame / 10;
        await page.evaluate(t => window.__skillVisualSeek(t), time);
        await page.waitForFunction(t => Math.abs(window.__skillVisualTime - t) < .001, time);
        await page.screenshot({ path: info.outputPath(`flow-frame-${String(frame).padStart(2, '0')}.png`),
          clip: { x: rect.x - 30, y: rect.y - 16, width: rect.width + 60, height: rect.height + 32 } });
      }
    }
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  expect(errors).toEqual([]);
});
