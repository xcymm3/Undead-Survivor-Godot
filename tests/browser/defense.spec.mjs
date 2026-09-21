import { test, expect } from '@playwright/test';

const snapshot = page => page.evaluate(() => window.__survivorSnapshot);
async function clickButton(page, text) {
  await expect.poll(async () => (await snapshot(page))?.buttons.some(button => button.text.includes(text) && !button.disabled)).toBe(true);
  const button = (await snapshot(page)).buttons.find(item => item.text.includes(text) && !item.disabled);
  const canvas = await page.locator('canvas').boundingBox();
  await page.mouse.click(canvas.x + (button.x + button.width / 2) * canvas.width / 1440,
    canvas.y + (button.y + button.height / 2) * canvas.height / 900);
}

test('吊桥水晶防守使用真实输入换装并拉杆开战', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  await page.goto('/');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'home', null, { timeout: 90_000 });
  await clickButton(page, '保卫水晶');
  await page.waitForFunction(() => window.__survivorSnapshot?.map_id === 'graypine_defense');
  await page.screenshot({ path: info.outputPath('defense-home.png') });
  await clickButton(page, '单人防守');
  await page.waitForFunction(() => window.__survivorSnapshot?.mode === 'defense' && window.__survivorSnapshot?.running);
  expect((await snapshot(page)).defense.started).toBe(false);
  expect((await snapshot(page)).elapsed).toBe(0);
  await page.keyboard.press('2');
  await page.waitForFunction(() => window.__survivorSnapshot?.player?.weapon === 1);
  await page.keyboard.down('d');
  await page.waitForFunction(() => window.__survivorSnapshot?.player?.x > 5.7);
  await page.keyboard.up('d');
  await page.keyboard.down('w');
  await page.waitForFunction(() => window.__survivorSnapshot?.player?.z < 50.5);
  await page.keyboard.up('w');
  await page.keyboard.press('3');
  await page.waitForTimeout(600);
  expect((await snapshot(page)).player.weapon).toBe(1);
  await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot?.defense?.started, null, { timeout: 10_000 });
  await page.keyboard.up('e');
  await page.waitForFunction(() => window.__survivorSnapshot?.enemies?.length > 0, null, { timeout: 10_000 });
  expect((await snapshot(page)).wave).toBe(1);
  expect((await snapshot(page)).defense.crystal_hp).toBe((await snapshot(page)).defense.crystal_max_hp);
  await page.screenshot({ path: info.outputPath('defense-wave-started.png') });
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
