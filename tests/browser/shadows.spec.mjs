import { test, expect } from '@playwright/test';

test.use({ video: { mode: 'on', size: { width: 960, height: 600 } } });

test('night close-wall lighting and shadow controls while turning', async ({ page }, info) => {
  test.setTimeout(300_000);
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  await page.setViewportSize({ width: 960, height: 600 });
  await page.goto('/?nightGallery=1');
  await page.waitForFunction(() => window.__campaignGalleryReady, null, { timeout: 90_000 });
  for (const [name, position, yaw, pitch] of [
    ['wall-close', [4.43,70], -Math.PI/2, -.12],
    ['shop-close', [-18.38,17], Math.PI/2, -.12],
  ]) {
    for (const offset of [-.15,.15]) {
      for (const mode of ['normal','no-flash','no-shadows']) {
        const view = { name: 'night_street', position, yaw: yaw+offset, pitch, time: 2.5,
          shadows: mode === 'no-shadows' ? 0 : 3,
          ...(mode === 'no-flash' ? { flash_shadow: false } : {}) };
        await page.evaluate(view => { window.__campaignView = view; }, view);
        await page.waitForFunction(view => JSON.stringify(window.__campaignRendered) === JSON.stringify(view), view);
        const lighting = await page.evaluate(() => window.__lightingState);
        expect(lighting.energy).toBeLessThan(.2);
        expect(lighting.flash_shadow).toBe(mode === 'normal');
        expect(lighting.world_shadows.every(enabled => enabled === (mode !== 'no-shadows'))).toBe(true);
        await page.screenshot({ path: info.outputPath(`${name}-${offset}-${mode}.png`), timeout: 60_000 });
      }
    }
    // Retain adjacent angles in the video; static endpoints alone miss moving bands.
    for (let step = 0; step <= 12; step++) {
      const view = { name: 'night_street', position, yaw: yaw-.36+step*.06, pitch, shadows: 3, time: 2.5 };
      await page.evaluate(view => { window.__campaignView = view; }, view);
      await page.waitForFunction(view => JSON.stringify(window.__campaignRendered) === JSON.stringify(view), view);
      if (step % 6 === 0) await page.screenshot({ path: info.outputPath(`${name}-turn-${step}.png`), timeout: 60_000 });
    }
  }
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
