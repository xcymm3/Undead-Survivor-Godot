import { test, expect } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

test('Demo第一人称倒下与击败舞王后的连续画面', async ({ page }) => {
  test.setTimeout(900_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text());
  });
  await page.setViewportSize({ width: 960, height: 600 });
  for (const kind of ['failure', 'victory']) {
    const directory = path.resolve('artifacts/demo-endings', kind);
    await mkdir(directory, { recursive: true });
    await page.goto(`/?campaignReview=demo_${kind}`);
    await page.waitForFunction(() => Boolean(window.__campaignReviewReady), null, { timeout: 90_000 });
    const ready = await page.evaluate(() => window.__campaignReviewReady);
    expect(ready.crystal_hp).toBe(3000);
    expect(ready.health_cards).toBe(1);
    expect(ready.no_portraits).toBe(true);
    expect(ready.partners).toBe(0);
    await page.screenshot({ path: path.join(directory, 'before.png') });
    const states = [];
    for (let frame = 0; frame < ready.frames; frame++) {
      await page.evaluate(index => window.__drawDemoEnding(index), frame);
      await page.waitForFunction(index => window.__demoEndingFrame === index, frame);
      const state = await page.evaluate(() => window.__demoEndingState);
      expect(state.result).toBe(false);
      expect(state.partners).toBe(0);
      expect(state[kind === 'victory' ? 'won' : 'failed']).toBe(true);
      states.push(state);
      await page.screenshot({ path: path.join(directory, `frame-${String(frame).padStart(3, '0')}.png`) });
    }
    if (kind === 'failure') {
      expect(states.at(-1).camera_y).toBeCloseTo(3.28, 2);
      expect(Math.abs(states.at(-1).camera_roll)).toBeGreaterThan(1);
      expect(states[0].camera_y - states.at(-1).camera_y).toBeGreaterThan(1);
    } else {
      expect(states.some(state => state.caption && state.caption_alpha > .99)).toBe(true);
      expect(states.every(state => Math.abs(state.camera_y - states[0].camera_y) < .001)).toBe(true);
    }
    await writeFile(path.join(directory, 'timing.json'), JSON.stringify({ ...ready, states }, null, 2));
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  expect(errors).toEqual([]);
});
