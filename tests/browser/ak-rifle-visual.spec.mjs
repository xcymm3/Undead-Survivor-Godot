import { test, expect } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

test.use({ trace: 'off', viewport: { width: 960, height: 600 } });
for (const action of ['fire', 'reload', 'shove']) {
  test(`Blender AK ${action} production animation capture`, async ({ page }) => {
    test.setTimeout(480_000);
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => {
      if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text());
    });
    const directory = path.resolve('artifacts/ak47-review', action);
    await mkdir(directory, { recursive: true });
    await page.goto(`/?campaignReview=ak_${action}`);
    await page.waitForFunction(() => window.__campaignReviewReady?.scenario, null, { timeout: 90_000 });
    const ready = await page.evaluate(() => window.__campaignReviewReady);
    expect(ready.scenario).toBe(action);
    expect(ready.asset).toContain('ak47.glb');
    const states = [];
    for (let frame = 0; frame < ready.frames; frame++) {
      await page.evaluate(index => window.__drawAKReview(index), frame);
      await page.waitForFunction(index => window.__akFrame === index, frame, { timeout: 60_000 });
      states.push(await page.evaluate(() => window.__akState));
      await page.screenshot({ path: path.join(directory, `frame-${String(frame).padStart(3, '0')}.png`) });
    }
    await writeFile(path.join(directory, 'timing.json'), JSON.stringify({ ...ready, commit: process.env.GITHUB_SHA, states }, null, 2));
    expect(states.every(state => state.hp === states[0].hp)).toBe(true);
    if (action === 'fire') {
      expect(states.at(-1).shots).toBeGreaterThan(5);
      expect(states.at(-1).ammo).toBeLessThan(states[0].ammo);
      expect(states.some(state => state.flash)).toBe(true);
      expect(Math.max(...states.map(state => state.bolt_z)) - Math.min(...states.map(state => state.bolt_z))).toBeGreaterThan(.01);
    } else if (action === 'reload') {
      expect(states.some(state => state.reload)).toBe(true);
      expect(Math.min(...states.map(state => state.mag_y))).toBeLessThan(ready.mag_y - .25);
      expect(states.at(-1).ammo).toBe(ready.capacity);
      expect(states.at(-1).reserve).toBe(states[0].reserve - (ready.capacity - states[0].ammo));
      expect(states.at(-1).reload).toBe(false);
      expect(states.at(-1).mag_y).toBeCloseTo(ready.mag_y, 4);
    } else {
      expect(states.at(-1).shoves).toBe(3);
      expect(Math.max(...states.map(state => Math.abs(state.weapon_yaw)))).toBeGreaterThan(1.8);
      expect(states.at(-1).shove).toBe(0);
    }
    expect(errors).toEqual([]);
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  });
}
