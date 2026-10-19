import { test, expect } from '@playwright/test';
import { mkdir } from 'node:fs/promises';
import path from 'node:path';

test('舞王黑金配色正面、侧面与舞蹈姿态截图', async ({ page }, info) => {
  test.setTimeout(300_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text());
  });
  await page.setViewportSize({ width: 1440, height: 900 });
  await mkdir('artifacts/dancer-black-gold', { recursive: true });
  for (const scenario of ['toy_dancer_front', 'toy_dancer', 'toy_dancer_dance']) {
    await page.goto(`/?campaignReview=${scenario}`);
    await page.waitForFunction(() => Boolean(window.__campaignReviewReady), null, { timeout: 90_000 });
    const state = await page.evaluate(() => window.__campaignReviewReady);
    expect(state.kinds).toEqual(['dancer']);
    expect(state.count).toBe(1);
    const file = path.resolve(`artifacts/dancer-black-gold/${scenario}.png`);
    await page.screenshot({ path: file, timeout: 60_000 });
    await info.attach(scenario, { path: file, contentType: 'image/png' });
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  expect(errors).toEqual([]);
});
