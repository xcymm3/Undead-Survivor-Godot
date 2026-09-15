import { test, expect } from '@playwright/test';

test('weapon poses with revolver hands and remote crouch visual evidence', async ({ page }, info) => {
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
    await page.screenshot({ path: file });
    // Only the revolver has first-person hands; other weapons retain weapon-only presentation.
    // Screenshots remain visual-review evidence; console and safety checks follow below.
    await info.attach(name, { path: file, contentType: 'image/png' });
  }
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
