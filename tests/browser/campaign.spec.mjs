import { test, expect } from '@playwright/test';

test('campaign can be selected and departed using real keyboard input', async ({ page }, info) => {
  await page.goto('/');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'home', null, { timeout: 90_000 });
  const button = await page.evaluate(() => window.__survivorSnapshot.buttons.find(item => item.text === '单人模式' && !item.disabled));
  expect(button).toBeTruthy();
  const canvas = await page.locator('canvas').boundingBox();
  await page.mouse.click(canvas.x + (button.x + button.width / 2) * canvas.width / 1440,
    canvas.y + (button.y + button.height / 2) * canvas.height / 900);
  await page.waitForFunction(() => window.__survivorSnapshot?.map_id === 'graypine_night');
  await page.waitForFunction(() => window.__survivorSnapshot?.mode === 'campaign');
  await page.keyboard.press('4');
  expect(await page.evaluate(() => window.__survivorSnapshot.player.grenades)).toBe(0);
  await page.waitForFunction(() => window.__survivorSnapshot.player.slot === 1);
  for (const slot of [2, 3, 5, 1]) {
    await page.keyboard.press(String(slot));
    await page.waitForFunction(value => window.__survivorSnapshot?.player?.slot === value, slot);
  }
  await page.keyboard.down('w');
  await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot.campaign.bar_removed);
  await page.keyboard.up('e');
  await page.waitForTimeout(100);
  await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot?.campaign?.departed, null, { timeout: 15_000 });
  await page.waitForFunction(() => window.__survivorSnapshot.player.z < 64, null, { timeout: 10_000 });
  await page.keyboard.up('w');
  await page.keyboard.up('e');
  expect(await page.evaluate(() => window.__survivorSnapshot.campaign.gate_open)).toBe(true);
  await page.screenshot({ path: info.outputPath('campaign-real-input-departure.png') });
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
