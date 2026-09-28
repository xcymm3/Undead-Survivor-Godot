import { test, expect } from '@playwright/test';

test('主页只提供水晶防线和难度选择，可直接开始防守', async ({ page }) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text()); });
  await page.goto('/');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'home', null, { timeout: 90_000 });
  const home = await page.evaluate(() => window.__survivorSnapshot);
  expect(home.map_id).toBe('graypine_defense');
  expect(home.buttons.some(button => /灰松夜路|保卫水晶/.test(button.text))).toBe(false);
  for (const difficulty of ['简单 · 70%', '普通 · 100%', '困难 · 130%']) {
    expect(home.buttons.some(button => button.text.includes(difficulty))).toBe(true);
  }
  const button = home.buttons.find(button => button.text === '单人防守' && !button.disabled);
  expect(button).toBeTruthy();
  const canvas = await page.locator('canvas').boundingBox();
  await page.mouse.click(canvas.x + (button.x + button.width / 2) * canvas.width / 1440,
    canvas.y + (button.y + button.height / 2) * canvas.height / 900);
  await page.waitForFunction(() => window.__survivorSnapshot?.running);
  const game = await page.evaluate(() => window.__survivorSnapshot);
  expect(game.mode).toBe('defense');
  expect(game.defense.waiting).toBe(true);
  expect(game.player.primary).toBe(0);
  expect(game.player.reserves[0]).toBe(510);
  expect(game).not.toHaveProperty('campaign');
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
