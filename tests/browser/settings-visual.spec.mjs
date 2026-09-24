import { test, expect } from '@playwright/test';

const snapshot = page => page.evaluate(() => window.__survivorSnapshot);

async function clickButton(page, text) {
  await expect.poll(async () => (await snapshot(page))?.buttons.some(button => button.text.includes(text) && !button.disabled)).toBe(true);
  const button = (await snapshot(page)).buttons.find(item => item.text.includes(text) && !item.disabled);
  const canvas = await page.locator('canvas').boundingBox();
  await page.mouse.click(canvas.x + (button.x + button.width / 2) * canvas.width / 1440,
    canvas.y + (button.y + button.height / 2) * canvas.height / 900);
}

test('游戏内设置菜单使用半透明淡棕色面板', async ({ page }, info) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.goto('/');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'home', null, { timeout: 90_000 });
  await clickButton(page, '保卫水晶');
  await clickButton(page, '单人防守');
  await page.waitForFunction(() => window.__survivorSnapshot?.running);
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'pause');
  await clickButton(page, '设置');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'settings');
  await page.waitForTimeout(500);
  const screenshot = info.outputPath('游戏内设置菜单.png');
  await page.screenshot({ path: screenshot });
  await info.attach('游戏内设置菜单', { path: screenshot, contentType: 'image/png' });
  expect((await snapshot(page)).menu).toBe('settings');
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
