import { test, expect } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

test.use({ trace: 'off' });
test('新存档序章、三色终极武器展厅与选择后进入商店GIF', async ({ page }) => {
  test.setTimeout(600_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text()); });
  const directory = path.resolve('artifacts/ultimate-entry');
  await mkdir(directory, { recursive: true });
  await page.goto('/?campaignReview=ultimate_entry');
  await page.waitForFunction(() => Boolean(window.__campaignReviewReady), null, { timeout: 90_000 });
  const ready = await page.evaluate(() => window.__campaignReviewReady);
  const states = [];
  for (let frame = 0; frame < ready.frames; frame++) {
    await page.evaluate(index => window.__drawUltimateEntry(index), frame);
    await page.waitForFunction(index => window.__entryFrame === index, frame);
    states.push(await page.evaluate(() => window.__entryState));
    await page.screenshot({ path: path.join(directory, `frame-${String(frame).padStart(3, '0')}.png`) });
  }
  await writeFile(path.join(directory, 'timing.json'), JSON.stringify({ ...ready, commit: process.env.GITHUB_SHA, states }, null, 2));
  expect(states.slice(0, 70).every(state => state.phase === 'intro' && !state.sim_started)).toBe(true);
  expect(states[120].rocket_blocked).toBe(true);
  expect(states[160].scepter_blocked).toBe(true);
  expect(states.some(state => state.phase === 'fade_out' && state.choice === 'blade' && !state.sim_started)).toBe(true);
  expect(states.some(state => state.phase === 'handoff' && state.black === 1 && state.sim_started)).toBe(true);
  expect(states.at(-1)).toMatchObject({ phase: 'shop', choice: 'blade', intro_seen: true, ultimate_unlocked: false, main_visible: true });
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  expect(errors).toEqual([]);
});
