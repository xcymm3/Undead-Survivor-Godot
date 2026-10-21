import { test, expect } from '@playwright/test';

const snapshot = page => page.evaluate(() => window.__survivorSnapshot);
async function clickButton(page, text) {
  await expect.poll(async () => (await snapshot(page))?.buttons.some(button => button.text.includes(text) && !button.disabled)).toBe(true);
  const button = (await snapshot(page)).buttons.find(item => item.text.includes(text) && !item.disabled);
  const canvas = await page.locator('canvas').boundingBox();
  await page.mouse.click(canvas.x + (button.x + button.width / 2) * canvas.width / 1440,
    canvas.y + (button.y + button.height / 2) * canvas.height / 900);
}

test('店内出生后使用真实输入穿过武器前厅并出门修复水晶开始进攻', async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  await page.goto('/');
  await page.waitForFunction(() => window.__survivorSnapshot?.menu === 'home', null, { timeout: 90_000 });
  await page.waitForFunction(() => window.__survivorSnapshot?.map_id === 'graypine_defense');
  await page.screenshot({ path: info.outputPath('defense-home.png') });
  await clickButton(page, '单人游戏');
  await page.waitForFunction(() => window.__survivorSnapshot?.mode === 'defense' && window.__survivorSnapshot?.running);
  let state = await snapshot(page);
  expect(state.defense.difficulty).toBe('normal');
  expect(state.defense.difficulty_multiplier).toBe(1);
  expect(state.defense.started).toBe(false);
  expect(state.elapsed).toBe(0);
  expect(state.player.weapon1).toBe(0);
  expect(state.player.weapon2).toBe(2);
  expect(state.player.medkits).toBeUndefined();
  expect(state.player.grenades).toBe(0);
  expect(state.menu).toBe('');
  expect(state.paused).toBe(false);
  // The opening black-screen story deliberately blocks all gameplay input.
  await page.waitForFunction(() => window.__survivorSnapshot.defense.intro_elapsed >= 15, null, { timeout: 45_000 });
  await page.keyboard.press('2');
  await page.waitForFunction(() => window.__survivorSnapshot?.player?.slot === 2 && window.__survivorSnapshot?.player?.weapon === 2);
  expect(state.defense.crystal_hp).toBe(0);
  expect(state.player.x).toBeCloseTo(-6.5, 1);
  expect(state.player.z).toBeGreaterThan(45);
  // Follow the actual backroom passage, showroom aisle and side-facing door.
  // Software rendering and trace capture can delay CDP key-up delivery.
  // Real crouch input keeps stopping distance inside the showroom aisle.
  await page.keyboard.down('Control');
  await page.waitForFunction(() => window.__survivorSnapshot.player.crouch >= .99);
  for (const [key, axis, threshold, increasing] of [
    ['w', 'z', 40.0, false],
    ['d', 'x', 15.0, true],
    // Clear the front wall (z=30.67) before turning; match the native route's 3 m margin.
    ['w', 'z', 27.5, false],
    ['a', 'x', 2.5, false],
    ['w', 'z', 21.3, false],
  ]) {
    await page.keyboard.down(key);
    try {
      await page.waitForFunction(({ axis, threshold, increasing }) => {
        const value = window.__survivorSnapshot?.player?.[axis];
        return Number.isFinite(value) && (increasing ? value >= threshold : value <= threshold);
      }, { axis, threshold, increasing }, { timeout: 60_000 });
    } finally {
      await page.keyboard.up(key);
    }
    const stopped = await snapshot(page);
    await page.waitForFunction(frame => window.__survivorSnapshot.frames > frame + 1, stopped.frames);
    await info.attach(`route-${key}-${axis}-${threshold}`, {
      body: JSON.stringify(await snapshot(page), null, 2), contentType: 'application/json',
    });
  }
  await page.keyboard.up('Control');
  await page.waitForFunction(() => window.__survivorSnapshot.player.crouch <= .01);
  await page.keyboard.press('3');
  await page.waitForFunction(() => window.__survivorSnapshot?.player?.slot === 3 && window.__survivorSnapshot?.player?.weapon === 6);
  await page.keyboard.press('1');
  await page.waitForFunction(() => window.__survivorSnapshot?.player?.slot === 1 && window.__survivorSnapshot?.player?.weapon === 0);
  // Aim using observed position/angles; all changes still use actual mouse input.
  await page.mouse.move(480, 300);
  const beforeAim = await snapshot(page);
  await page.waitForFunction(frame => window.__survivorSnapshot.frames > frame, beforeAim.frames);
  const aimed = await snapshot(page);
  const crystal = { x: 0, y: 4.0, z: 17.3333333333 };
  const dx = crystal.x - aimed.player.x;
  const dz = crystal.z - aimed.player.z;
  const targetYaw = Math.atan2(-dx, -dz);
  const targetPitch = Math.atan2(crystal.y - aimed.player.height - aimed.player.eye_height, Math.hypot(dx, dz));
  const deltaX = Math.atan2(Math.sin(aimed.yaw - targetYaw), Math.cos(aimed.yaw - targetYaw)) / .0022;
  const deltaY = (aimed.pitch - targetPitch) / .0022;
  await page.mouse.move(480 + deltaX, 300 + deltaY, { steps: Math.max(1, Math.ceil(Math.max(Math.abs(deltaX), Math.abs(deltaY)) / 100)) });
  await page.waitForFunction(() => window.__survivorSnapshot.player.focus?.id === 'crystal');
  await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot?.defense?.started, null, { timeout: 10_000 });
  await page.keyboard.up('e');
  await page.waitForFunction(() => window.__survivorSnapshot.announcement.visible && window.__survivorSnapshot.announcement.text === '第1波');
  await page.waitForFunction(() => window.__survivorSnapshot.elapsed > 3.1 && !window.__survivorSnapshot.announcement.visible);
  state = await snapshot(page);
  expect(state.defense.waiting).toBe(false);
  expect(state.player.grenades).toBe(0);
  expect(state.defense.ready_players).toEqual([]);
  await page.waitForFunction(() => window.__survivorSnapshot?.enemies?.length > 0, null, { timeout: 10_000 });
  state = await snapshot(page);
  expect(state.wave).toBe(1);
  expect(state.player.ammo[state.player.weapon1]).toBe(30);
  expect(state.player.reserves[state.player.weapon1]).toBe(180);
  expect(state.defense.crystal_hp).toBe(state.defense.crystal_max_hp);
  const beforeEmptySlot = await snapshot(page);
  await page.keyboard.press('4');
  await page.waitForFunction(frame => window.__survivorSnapshot.frames > frame + 1, beforeEmptySlot.frames);
  expect((await snapshot(page)).player.slot).toBe(1);
  expect((await snapshot(page)).player.grenade_capacity).toBe(0);
  await page.keyboard.press('1');
  await page.waitForFunction(() => window.__survivorSnapshot.player.slot === 1 && window.__survivorSnapshot.player.weapon === 0);
  await page.screenshot({ path: info.outputPath('defense-wave-started.png') });
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
