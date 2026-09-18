import { test, expect } from '@playwright/test';

test('real input fires cancels and completes revolver reload', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  await page.goto('/');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'home', null, { timeout: 90_000 });
  expect(await page.evaluate(() => window.__survivorSnapshot.map_id)).toBe('graypine_night');
  for (const text of ['单人模式']) {
    const button = await page.evaluate(text => window.__survivorSnapshot.buttons.find(b => b.text === text && !b.disabled), text);
    expect(button).toBeTruthy();
    const canvas = await page.locator('canvas').boundingBox();
    await page.mouse.click(canvas.x+(button.x+button.width/2)*canvas.width/1440, canvas.y+(button.y+button.height/2)*canvas.height/900);
  }
  await page.waitForFunction(() => window.__survivorSnapshot?.mode === 'campaign');
  await page.keyboard.down('w'); await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot.campaign.bar_removed);
  await page.keyboard.up('e');
  await page.waitForTimeout(100);
  await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot.campaign.departed, null, {timeout:15000});
  await page.keyboard.up('w'); await page.keyboard.up('e');
  await page.keyboard.press('4');
  await page.waitForFunction(() => window.__survivorSnapshot.player.slot === 1);
  await page.keyboard.press('2');
  await page.waitForFunction(() => window.__survivorSnapshot.player.weapon === 3 && window.__survivorSnapshot.player.switch <= 0);
  await page.mouse.click(480, 300);
  await page.waitForFunction(() => window.__survivorSnapshot.player.ammo[3] === 5);
  await page.keyboard.press('r');
  await page.waitForFunction(() => window.__survivorSnapshot.player.reloading);
  await page.keyboard.press('1');
  await page.waitForFunction(() => !window.__survivorSnapshot.player.reloading && window.__survivorSnapshot.player.weapon === window.__survivorSnapshot.player.primary);
  expect(await page.evaluate(() => window.__survivorSnapshot.player.ammo[3])).toBe(5);
  await page.keyboard.press('2');
  await page.waitForFunction(() => window.__survivorSnapshot.player.weapon === 3 && window.__survivorSnapshot.player.switch <= 0);
  await page.keyboard.press('r');
  await page.waitForFunction(() => window.__survivorSnapshot.player.reloading);
  await page.waitForFunction(() => !window.__survivorSnapshot.player.reloading && window.__survivorSnapshot.player.ammo[3] === 6);
  await page.mouse.down({ button: 'middle' }); await page.mouse.up({ button: 'middle' });
  await page.waitForFunction(() => window.__survivorSnapshot.player.aim);
  await page.screenshot({ path: info.outputPath('revolver-real-input-aim-after-reload.png'), timeout: 60_000 });
  await page.mouse.down({ button: 'middle' }); await page.mouse.up({ button: 'middle' });
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
