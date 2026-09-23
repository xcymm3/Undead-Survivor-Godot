import { test, expect } from '@playwright/test';

test('保卫水晶桥口遮挡画面', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto('/?defenseBridgeMouth=1');
  await page.waitForFunction(() => window.__defenseBridgeMouthReady, null, { timeout: 90_000 });
  await page.waitForTimeout(700);
  const file = info.outputPath('保卫水晶-对岸桥口.png');
  await page.screenshot({ path: file });
  await info.attach('保卫水晶-对岸桥口', { path: file, contentType: 'image/png' });
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
