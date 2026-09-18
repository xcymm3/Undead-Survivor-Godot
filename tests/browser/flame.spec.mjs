import { test, expect } from '@playwright/test';
import { PNG } from 'pngjs';

test('flamethrower software visual sequence and release', async ({ page }, info) => {
  test.setTimeout(240_000);
  const errors = [];
  const visibleFire = {};
  page.on('pageerror', e => errors.push(String(e)));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto('/?nightGallery=1');
  await page.waitForFunction(() => window.__campaignGalleryReady, null, { timeout: 90_000 });
  await page.setViewportSize({ width: 1440, height: 900 });
  for (const [name, extra] of [
    ['ignition', { flame_time: .12 }],
    ['stream', { flame_time: .7 }],
    ['side', { flame_time: .7, flame_side: true }],
    ['tail', { flame_time: .95, release_time: .25 }],
    ['released', { flame_time: 1.6, release_time: .9 }],
    ['wall', { flame_time: .7, position: [-9, 28], yaw: Math.PI / 2, pitch: -.03 }],
    ['close-wall', { flame_time: .7, position: [4.68, 70], yaw: -Math.PI / 2, pitch: 0 }],
  ]) {
    const view = { name: 'night_exit', position: [12, -42], yaw: 0, pitch: -.03,
      width: 1440, height: 900, time: 3, party: 1, ...extra };
    await page.evaluate(v => { window.__campaignView = v; }, view);
    await page.waitForFunction(v => JSON.stringify(window.__campaignRendered) === JSON.stringify(v), view);
    const state = await page.evaluate(() => window.__flameState);
    if (name === 'released' || name === 'close-wall') expect(state).toEqual({ particles: 0, light: 0 });
    else expect(state.particles).toBeGreaterThan(0);
    const png = PNG.sync.read(await page.screenshot({ path: info.outputPath(`flame-${name}.png`), timeout: 60_000 }));
    let warmPixels = 0;
    for (let i = 0; i < png.data.length; i += 4) {
      // Side-view plume region excludes the warm console and door behind it.
      const x = (i / 4) % png.width, y = Math.floor(i / 4 / png.width);
      if (name === 'side' && (x < 240 || x >= 510 || y < 395 || y >= 500)) continue;
      const [r, g, b] = png.data.subarray(i, i + 3);
      if (r > 180 && g > 70 && g < 225 && b < g * .8 && r > g * 1.1) warmPixels++;
    }
    visibleFire[name] = warmPixels;
  }
  // Live particle telemetry alone cannot detect missing or corrupt GPU instances.
  expect(visibleFire.stream).toBeGreaterThan(visibleFire.released + 5000);
  expect(visibleFire.side).toBeGreaterThan(200);
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
