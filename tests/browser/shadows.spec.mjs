import { test, expect } from '@playwright/test';
import { PNG } from 'pngjs';

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
        expect(lighting.flash_shadow).toBe(false);
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

test('night surfaces do not acquire flashlight or lamp shadow stripes', async ({ page }, info) => {
  test.setTimeout(240_000);
  await page.setViewportSize({ width: 960, height: 600 });
  await page.goto('/?nightGallery=1');
  await page.waitForFunction(() => window.__campaignGalleryReady, null, { timeout: 90_000 });
  const render = async (view, filename) => {
    await page.evaluate(view => { window.__campaignView = view; }, view);
    await page.waitForFunction(view => JSON.stringify(window.__campaignRendered) === JSON.stringify(view), view);
    return page.screenshot({ path: info.outputPath(filename), timeout: 60_000 });
  };
  // This blank van panel reproduces the same moving self-shadow bands as walls.
  // Sum column-to-column luminance changes; a smooth beam has low variation,
  // whereas the old projection repeatedly jumps between lit and shadowed pixels.
  const panelVariation = buffer => {
    const png = PNG.sync.read(buffer);
    const columns = [];
    for (let x = 467; x < 542; x++) {
      let sum = 0;
      for (let y = 319; y < 336; y++) {
        const i = (y * png.width + x) * 4;
        sum += (png.data[i] + png.data[i + 1] + png.data[i + 2]) / 3;
      }
      columns.push(sum / 17);
    }
    return columns.slice(1).reduce((sum, value, i) => sum + Math.abs(value - columns[i]), 0);
  };
  const street = { name: 'night_street', position: [8,60], yaw: -.3, pitch: 0, time: 2.5, shadows: 3 };
  const legacy = await render({ ...street, flash_shadow: true }, 'far-street-legacy.png');
  const fixed = await render(street, 'far-street-fixed.png');
  const variation = { legacy: panelVariation(legacy), fixed: panelVariation(fixed) };
  await info.attach('flat-panel-variation', { body: JSON.stringify(variation), contentType: 'application/json' });
  expect(variation.legacy).toBeGreaterThan(100);
  expect(variation.fixed).toBeLessThan(35);
  const lighting = await page.evaluate(() => window.__lightingState);
  expect(lighting.flash_shadow).toBe(false);
  expect(lighting.energy).toBeCloseTo(3.2, 5);
  expect(lighting.world_shadows.every(Boolean)).toBe(true);
  const floorVariation = buffer => {
    const png = PNG.sync.read(buffer);
    const rows = [];
    for (let y = 400; y < 529; y++) {
      let sum = 0;
      for (let x = 520; x < 546; x++) {
        const i = (y * png.width + x) * 4;
        sum += (png.data[i] + png.data[i + 1] + png.data[i + 2]) / 3;
      }
      rows.push(sum / 26);
    }
    return rows.slice(1).reduce((sum, value, i) => sum + Math.abs(value - rows[i]), 0);
  };
  const shop = { ...street, position: [-9,24], yaw: Math.PI/2 };
  const oldFloor = await render({ ...shop, lamp_reverse_cull: false }, 'shop-floor-legacy.png');
  const newFloor = await render(shop, 'shop-floor-fixed.png');
  const floor = { legacy: floorVariation(oldFloor), fixed: floorVariation(newFloor) };
  await info.attach('floor-variation', { body: JSON.stringify(floor), contentType: 'application/json' });
  expect(floor.legacy).toBeGreaterThan(55);
  expect(floor.fixed).toBeLessThan(35);
  for (const [name, position, yaw] of [
    ['far-street', [8,60], 0],
    ['far-wall', [-10,64], 0],
    ['shop-wall', [-9,24], Math.PI/2],
  ]) {
    for (const step of [-2,-1,0,1,2]) {
      await render({ ...street, position, yaw: yaw + step * .15 }, `${name}-turn-${step}.png`);
    }
  }
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
