import { test, expect } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';

test.use({ trace: 'off' });
for (const view of ['overview', 'bridge']) {
  test(`林地三出口与桥面分散行军：${view}`, async ({ page }) => {
    test.setTimeout(360_000);
    await page.setViewportSize({ width: 960, height: 600 });
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => { if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text()); });
    const directory = `artifacts/forest-bridge/${view}`;
    await mkdir(directory, { recursive: true });
    await page.goto(`/?forestReview=${view}`);
    await page.waitForFunction(() => Boolean(window.__forestReady), null, { timeout: 120_000 });
    const ready = await page.evaluate(() => window.__forestReady);
    const states = [];
    for (let frame = 0; frame < ready.frames; frame++) {
      await page.evaluate(index => window.__drawForestReview(index), frame);
      await page.waitForFunction(index => window.__forestFrame === index, frame);
      states.push(await page.evaluate(() => window.__forestState));
      await page.screenshot({ path: `${directory}/frame-${String(frame).padStart(3, '0')}.png` });
    }
    await writeFile(`${directory}/timing.json`, JSON.stringify({ ...ready, commit: process.env.GITHUB_SHA, states }, null, 2));
    const bridge = states.flatMap(state => state.positions.filter(p => p.z > -62 && p.z < -56));
    expect(bridge.some(p => p.x < -1.4)).toBe(true);
    expect(bridge.some(p => Math.abs(p.x) < 0.6)).toBe(true);
    expect(bridge.some(p => p.x > 1.4)).toBe(true);
    expect(states.every(state => !state.failed)).toBe(true);
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
    expect(errors).toEqual([]);
  });
}
