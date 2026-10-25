import { test, expect } from '@playwright/test';
import { mkdir } from 'node:fs/promises';

test('步枪与手枪递减升级和切换提示截图', async ({ page }) => {
  test.setTimeout(360_000);
  await page.setViewportSize({ width: 1440, height: 900 });
  await mkdir('artifacts/weapon-upgrades', { recursive: true });
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text()); });
  for (const [weapon, before, after] of [['rifle', '162', '215.5'], ['pistol', '135', '179.6']]) {
    await page.goto(`/?preparationReview=upgrade_weapon_${weapon}`);
    await page.waitForFunction(() => Boolean(window.__preparationReviewReady), null, { timeout: 120_000 });
    const state = await page.evaluate(() => window.__preparationReviewReady);
    expect(state.focus_visible).toBe(true);
    expect(state.focus_text).toContain('切换不同武器可以改变此升级项');
    expect(state.upgrade_details.rows[0]).toEqual(['伤害', before, after]);
    expect(state.currency_icon_visible).toBe(true);
    expect(state.focus_text.split('\n').at(-1)).toBe('100');
    await page.screenshot({ path: `artifacts/weapon-upgrades/${weapon}.png` });
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  expect(errors).toEqual([]);
});
