import { test, expect } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

test.use({ trace: 'off' });
const allScenarios = ['fire', 'axe', 'reload', 'switch', 'ultimate', 'guest_death', 'retry_failure', 'retry_victory', 'host_death', 'spectate'];
const requested = process.env.QA_COOP_SCENARIOS ?? 'all';
const selection = requested.split(',');
if (requested !== 'all' && selection.some(name => !allScenarios.includes(name))) throw new Error(`Unknown coop scenario: ${requested}`);
const scenarios = requested === 'all' ? allScenarios : allScenarios.filter(name => selection.includes(name));
for (const scenario of scenarios) {
  test(`合作动作与流程 GIF：${scenario}`, async ({ page }) => {
    test.setTimeout(300_000);
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => { if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text()); });
    const directory = path.resolve('artifacts/coop-review', scenario);
    await mkdir(directory, { recursive: true });
    await page.goto(`/?campaignReview=coop_${scenario}`);
    await page.waitForFunction(() => Boolean(window.__campaignReviewReady), null, { timeout: 90_000 });
    const ready = await page.evaluate(() => window.__campaignReviewReady);
    await page.screenshot({ path: path.join(directory, 'before.png') });
    const states = [];
    for (let frame = 0; frame < ready.frames; frame++) {
      await page.evaluate(index => window.__drawCoopReview(index), frame);
      await page.waitForFunction(index => window.__coopFrame === index, frame);
      states.push(await page.evaluate(() => window.__coopState));
      await page.screenshot({ path: path.join(directory, `frame-${String(frame).padStart(3, '0')}.png`) });
    }
    await writeFile(path.join(directory, 'timing.json'), JSON.stringify({ ...ready, commit: process.env.GITHUB_SHA, states }, null, 2));
    if (scenario === 'fire') expect(states.at(-1).shots).toBeGreaterThan(5);
    if (scenario === 'axe') expect(states.filter(state => state.fire_anim > 0 && state.held).length).toBeGreaterThan(5);
    if (scenario === 'reload') {
      expect(states.some(state => state.reload)).toBe(true);
      expect(states.at(-1).reload).toBe(false);
      expect(states.at(-1).ammo).toBe(30);
    }
    if (scenario === 'switch') expect(new Set(states.map(state => state.weapon))).toEqual(new Set([0, 2, 6]));
    if (scenario === 'ultimate') expect(states.filter(state => state.ultimate && state.held && state.fire_anim > 0).length).toBeGreaterThan(10);
    if (scenario === 'guest_death') {
      expect(states.at(-1).hp).toBe(0);
      expect(states.at(-1).failed).toBe(false);
      expect(states.at(-1).living).toBe(2);
    }
    if (scenario.startsWith('retry_')) {
      expect(states.some(state => state.result && state[scenario === 'retry_failure' ? 'failed' : 'won'])).toBe(true);
      expect(states.at(-1).restarted).toBe(true);
      expect(states.at(-1).living).toBe(3);
      expect(states.at(-1).members).toBe(3);
      expect(states.at(-1).failed || states.at(-1).won).toBe(false);
    }
    if (scenario === 'host_death') {
      expect(states.at(-1).hp).toBe(0);
      expect(states.at(-1).failed).toBe(true);
      expect(states.at(-1).result).toBe(true);
    }
    if (scenario === 'spectate') expect(new Set(states.filter(state => state.frame >= 12).map(state => state.view))).toEqual(new Set(['1', '3']));
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
    expect(errors).toEqual([]);
  });
}

test('主菜单四个按钮截图', async ({ page }) => {
  await page.goto('/?campaignReview=home');
  await page.waitForFunction(() => Boolean(window.__campaignReviewReady), null, { timeout: 90_000 });
  await page.waitForFunction(() => Boolean(window.__survivorSnapshot?.buttons?.length));
  const buttons = await page.evaluate(() => window.__survivorSnapshot.buttons.map(button => button.text));
  expect(buttons).toContain('多人合作');
  expect(buttons).not.toContain('问题反馈');
  await page.screenshot({ path: 'artifacts/coop-review/home-four-actions.png' });
});
