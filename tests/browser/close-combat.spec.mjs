import { test, expect } from '@playwright/test';
import { finishEntry } from './finish-entry.mjs';

test('right shove cooldown ring and middle toggle use real input', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text()); });
  await page.goto('/');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'home', null, { timeout: 90_000 });
  const button = await page.evaluate(() => window.__survivorSnapshot.buttons.find(item => item.text === '开始游戏' && !item.disabled));
  expect(button).toBeTruthy();
  const canvas = await page.locator('canvas').boundingBox();
  await page.mouse.click(canvas.x + (button.x + button.width / 2) * canvas.width / 1440,
    canvas.y + (button.y + button.height / 2) * canvas.height / 900);
  await finishEntry(page);
  await page.mouse.down({ button: 'middle' });
  await page.mouse.up({ button: 'middle' });
  await page.waitForFunction(() => window.__survivorSnapshot.player.aim);
  await page.mouse.down({ button: 'middle' });
  await page.mouse.up({ button: 'middle' });
  await page.waitForFunction(() => !window.__survivorSnapshot.player.aim);
  for (let count = 1; count <= 3; count++) {
    await page.waitForFunction(() => window.__survivorSnapshot.player.shove_gap === 0);
    await page.mouse.down({ button: 'right' });
    await page.mouse.up({ button: 'right' });
    await page.waitForFunction(value => window.__survivorSnapshot.shove_events?.some(event => event.count === value), count);
    const event = await page.evaluate(value => window.__survivorSnapshot.shove_events.find(event => event.count === value), count);
    expect(event.combo).toBe(count === 3 ? 0 : count);
    if (count === 3) expect(event.cooldown).toBeGreaterThan(0);
  }
  const before = await page.evaluate(() => window.__survivorSnapshot.player.shove_cd);
  await page.mouse.down({ button: 'right' });
  await page.mouse.up({ button: 'right' });
  expect(await page.evaluate(() => window.__survivorSnapshot.player.shove_cd)).toBeLessThanOrEqual(before);
  await page.screenshot({ path: info.outputPath('shove-cooldown-ring.png'), timeout: 60_000 });
  await page.waitForFunction(() => window.__survivorSnapshot.player.shove_cd === 0);
  const completedShoves = await page.evaluate(() => window.__survivorSnapshot.shoves);
  await page.mouse.down({ button: 'right' });
  await page.mouse.up({ button: 'right' });
  // The short combo window may expire during a slow software-rendered frame.
  await page.waitForFunction(before => window.__survivorSnapshot.shoves === before + 1, completedShoves);
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
