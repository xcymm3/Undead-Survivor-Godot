import { test, expect } from '@playwright/test';
import { PNG } from 'pngjs';

test('staged weapon hands and remote crouch visual evidence', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto('/?poses=1');
  await page.waitForFunction(() => window.__poseReady, null, { timeout: 90_000 });
  const poses = [];
  for (let weapon = 0; weapon < 10; weapon++) {
    poses.push([`weapon-${weapon}-hip`, { weapon }], [`weapon-${weapon}-aim`, { weapon, aim: true }]);
  }
  for (const reload of [.2, .5, .85]) poses.push([`ak-reload-${reload}`, { reload }]);
  poses.push(['ak-fire', { fire: .2 }], ['ak-crouch', { crouch: true }]);
  for (const partner_yaw of [Math.PI, Math.PI / 2]) {
    poses.push([`partner-standing-${partner_yaw}`, { partner: true, partner_yaw }]);
    poses.push([`partner-crouched-${partner_yaw}`, { partner: true, partner_yaw, partner_crouch: true }]);
  }
  for (const [name, pose] of poses) {
    await page.evaluate(pose => { window.__poseRequest = pose; }, pose);
    await page.waitForFunction(pose => JSON.stringify(window.__poseRendered) === JSON.stringify(pose), pose, { timeout: 30_000 });
    const file = info.outputPath(`${name}.png`);
    const bytes = await page.screenshot({ path: file });
    if (!(pose.weapon === 5 && pose.aim)) {
      const pixels = PNG.sync.read(bytes).data;
      let skinOrWood = 0;
      for (let i = 0; i < pixels.length; i += 4) {
        if (pixels[i] > pixels[i + 1] * 1.18 && pixels[i + 1] > pixels[i + 2] * 1.15) skinOrWood++;
      }
      expect(skinOrWood, `${name}: hands/weapon must be rendered, not just the empty studio`).toBeGreaterThan(200);
    }
    await info.attach(name, { path: file, contentType: 'image/png' });
  }
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
