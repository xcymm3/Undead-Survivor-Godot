import { test, expect } from '@playwright/test';

test.use({ video: { mode: 'on', size: { width: 1280, height: 800 } } });

test('revolver without arms and complete action sequence', async ({ page }, info) => {
  test.setTimeout(300_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('/?poses=1');
  await page.waitForFunction(() => window.__poseReady, null, { timeout: 90_000 });
  const poses = [
    ['hold', {}], ['walk-left', { speed: 4.2, stride: 1.5 }], ['walk-right', { speed: 4.2, stride: 4.5 }],
    ['aim', { aim: true }], ['fire', { fire: .12, shots: 1 }], ['recover', { fire: .75, shots: 1 }],
    ...[.12, .25, .35, .50, .62, .69, .84, .97].map(reload => [`reload-${reload}`, { reload }]),
    ['holster', { switch: .3 }], ['draw', { switch: .1 }], ['dead', { dead: true }], ['other-weapon', { weapon: 0 }],
  ];
  for (const [name, sample] of poses) {
    const pose = { weapon: 3, ...sample };
    await page.evaluate(pose => { window.__poseRequest = pose; }, pose);
    await page.waitForFunction(pose => JSON.stringify(window.__poseRendered) === JSON.stringify(pose), pose, { timeout: 30_000 });
    await page.screenshot({ path: info.outputPath(`revolver-${name}.png`), timeout: 60_000 });
    if (name === 'other-weapon' || name === 'dead') expect(await page.evaluate(() => window.__revolverPose.visible)).toBe(false);
    if (name === 'reload-0.62') {
      const state = await page.evaluate(() => window.__revolverPose);
      expect(state.open).toBeGreaterThan(.99);
      expect(state.loader).toBe(true);
    }
  }
  await page.evaluate(() => { window.__poseRequest = { weapon: 3, playback: true }; });
  // Preserve a continuous playback video, including reload cancellation and switching back.
  await page.waitForTimeout(17_000);
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
