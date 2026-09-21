import { test, expect } from '@playwright/test';

test('right shove cooldown ring and middle toggle use real input', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text()); });
  await page.goto('/');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'home', null, { timeout: 90_000 });
  const button = await page.evaluate(() => window.__survivorSnapshot.buttons.find(item => item.text === '单人模式'));
  const canvas = await page.locator('canvas').boundingBox();
  await page.mouse.click(canvas.x + (button.x + button.width / 2) * canvas.width / 1440,
    canvas.y + (button.y + button.height / 2) * canvas.height / 900);
  await page.waitForFunction(() => window.__survivorSnapshot?.player?.hp > 0);
  await page.mouse.down({ button: 'middle' });
  await page.mouse.up({ button: 'middle' });
  await page.waitForFunction(() => window.__survivorSnapshot.player.aim);
  await page.mouse.down({ button: 'middle' });
  await page.mouse.up({ button: 'middle' });
  await page.waitForFunction(() => !window.__survivorSnapshot.player.aim);
  await page.keyboard.down('w');
  await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot.campaign.bar_removed);
  await page.keyboard.up('e');
  await page.waitForTimeout(100);
  await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot.campaign.departed, null, { timeout: 15_000 });
  await page.keyboard.up('w');
  await page.keyboard.up('e');
  for (let count = 1; count <= 3; count++) {
    await page.waitForFunction(() => window.__survivorSnapshot.player.shove_gap === 0);
    await page.mouse.down({ button: 'right' });
    await page.mouse.up({ button: 'right' });
    await page.waitForFunction(value => value === 3 ? window.__survivorSnapshot.player.shove_cd > 0 : window.__survivorSnapshot.player.shove_count === value, count);
  }
  const before = await page.evaluate(() => window.__survivorSnapshot.player.shove_cd);
  await page.mouse.down({ button: 'right' });
  await page.mouse.up({ button: 'right' });
  expect(await page.evaluate(() => window.__survivorSnapshot.player.shove_cd)).toBeLessThanOrEqual(before);
  await page.screenshot({ path: info.outputPath('shove-cooldown-ring.png') });
  await page.waitForFunction(() => window.__survivorSnapshot.player.shove_cd === 0);
  await page.mouse.down({ button: 'right' });
  await page.mouse.up({ button: 'right' });
  await page.waitForFunction(() => window.__survivorSnapshot.player.shove_count === 1);
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
