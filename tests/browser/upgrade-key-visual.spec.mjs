import { test, expect } from '@playwright/test';
import { mkdir } from 'node:fs/promises';
import path from 'node:path';

test('终极技能展台与方形 E 键填充截图', async ({ page }, info) => {
  test.setTimeout(600_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text());
  });
  await page.setViewportSize({ width: 1440, height: 900 });
  await mkdir('artifacts/upgrade-ui', { recursive: true });
  for (const scenario of ['upgrade_ready', 'upgrade_quarter', 'upgrade_hold', 'upgrade_complete', 'upgrade_learned', 'upgrade_unavailable', 'upgrade_max', 'upgrade_weapon', 'upgrade_talent']) {
    await page.goto(`/?preparationReview=${scenario}`);
    await page.waitForFunction(() => Boolean(window.__preparationReviewReady), null, { timeout: 90_000 });
    const state = await page.evaluate(() => window.__preparationReviewReady);
    expect(state.focus_visible).toBe(true);
    expect(state.details_visible).toBe(true);
    expect(state.upgrade_details.rows.length).toBeGreaterThan(0);
    expect(state.focus_text).not.toMatch(/伤害|持续|冷却|金币|钻石/);
    expect(state.currency_icon_visible).toBe(scenario !== 'upgrade_max');
    if (scenario === 'upgrade_talent') expect(state.currency_is_diamond).toBe(true);
    expect(state.upgrade_details.note).not.toMatch(/永久强化|按.*确认/);
    if (!['upgrade_weapon', 'upgrade_talent'].includes(scenario)) expect(state.focus_text).toContain('终极技能');
    expect(state.focus_text).not.toContain('长刀');
    if (scenario === 'upgrade_ready') expect(state.focus_text).toContain('终极技能');
    if (scenario === 'upgrade_quarter') expect(state.key_progress).toBeCloseTo(.25);
    if (scenario === 'upgrade_hold') expect(state.key_progress).toBeCloseTo(.65);
    if (scenario === 'upgrade_complete') expect(state.key_progress).toBe(1);
    if (scenario === 'upgrade_unavailable') expect(state.key_state).toBe('error');
    if (scenario === 'upgrade_max') expect(state.key_state).toBe('maxed');
    const file = path.resolve(`artifacts/upgrade-ui/${scenario}.png`);
    await page.screenshot({ path: file, timeout: 60_000 });
    await info.attach(scenario, { path: file, contentType: 'image/png' });
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  expect(errors).toEqual([]);
});
