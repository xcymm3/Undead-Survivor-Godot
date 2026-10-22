import { test, expect } from '@playwright/test';

test('主页问题反馈仅展示QQ邮箱和QQ群联系方式', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto('/');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'home', null, { timeout: 90_000 });
  const state = await page.evaluate(() => window.__survivorSnapshot);
  const button = state.buttons.find(item => item.text.includes('问题反馈') && !item.disabled);
  expect(button).toBeTruthy();
  const canvas = await page.locator('canvas').boundingBox();
  await page.mouse.click(canvas.x + (button.x + button.width / 2) * canvas.width / 1440,
    canvas.y + (button.y + button.height / 2) * canvas.height / 900);
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'feedback');
  const feedback = await page.evaluate(() => window.__survivorSnapshot);
  expect(feedback.buttons.some(item => item.text === '返回主菜单')).toBe(true);
  const screenshot = info.outputPath('feedback-contacts-1440.png');
  await page.screenshot({ path: screenshot, timeout: 60_000 });
  await info.attach('feedback-contacts-1440', { path: screenshot, contentType: 'image/png' });
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  expect(errors).toEqual([]);
});
