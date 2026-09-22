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
  await clickButton(page, '简单 · 70%');
  await page.screenshot({ path: info.outputPath('defense-home.png') });
  await clickButton(page, '单人防守');
  await page.waitForFunction(() => window.__survivorSnapshot?.mode === 'defense' && window.__survivorSnapshot?.running);
  let state = await snapshot(page);
  expect(state.defense.difficulty).toBe('easy');
  expect(state.defense.difficulty_multiplier).toBe(.7);
  expect(state.defense.started).toBe(false);
  expect(state.elapsed).toBe(0);
  expect(state.player.primary).toBe(0);
  expect(state.player.secondary).toBe(3);
  expect(state.player.medkits).toBe(1);
  expect(state.player.grenades).toBe(0);
  await page.keyboard.press('2');
  await page.waitForFunction(() => window.__survivorSnapshot?.player?.slot === 2 && window.__survivorSnapshot?.player?.weapon === 3);
  await page.keyboard.down('d');
  await page.waitForFunction(() => window.__survivorSnapshot?.player?.x > 5.7);
  await page.keyboard.up('d');
  await page.keyboard.down('w');
  await page.waitForFunction(() => window.__survivorSnapshot?.player?.z < 50.5);
  await page.keyboard.up('w');
  await page.keyboard.press('3');
  await page.waitForFunction(() => window.__survivorSnapshot?.player?.slot === 3 && window.__survivorSnapshot?.player?.weapon === 6);
  await page.keyboard.press('1');
  await page.waitForFunction(() => window.__survivorSnapshot?.player?.slot === 1 && window.__survivorSnapshot?.player?.weapon === 0);
  await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot?.defense?.started, null, { timeout: 10_000 });
  await page.keyboard.up('e');
  state = await snapshot(page);
  expect(state.defense.countdown).toBeGreaterThan(0);
  expect(state.enemies).toHaveLength(0);
  await page.waitForFunction(() => window.__survivorSnapshot?.enemies?.length > 0, null, { timeout: 10_000 });
  state = await snapshot(page);
  expect(state.wave).toBe(1);
  expect(state.player.ammo[state.player.primary]).toBe(30);
  expect(state.player.reserves[state.player.primary]).toBe(510);
  expect(state.defense.crystal_hp).toBe(state.defense.crystal_max_hp);
  await page.screenshot({ path: info.outputPath('defense-wave-started.png') });
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
