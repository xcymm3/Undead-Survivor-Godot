import { test, expect } from '@playwright/test';
import { PNG } from 'pngjs';

const snapshot = page => page.evaluate(() => window.__survivorSnapshot);
async function until(page, predicate, timeout = 15_000) {
  await page.waitForFunction(predicate, undefined, { timeout });
}
async function clickButton(page, text) {
  await expect.poll(async () => (await snapshot(page))?.buttons.some(b => b.text === text && !b.disabled)).toBe(true);
  const button = (await snapshot(page)).buttons.find(b => b.text === text && !b.disabled);
  const canvas = await page.locator('canvas').boundingBox();
  const point = { x: canvas.x + (button.x + button.width / 2) * canvas.width / 1440,
    y: canvas.y + (button.y + button.height / 2) * canvas.height / 900 };
  await page.mouse.click(point.x, point.y);
  return point;
}
// Move within the canvas, recentering only while paused. Each event is small enough
// to follow the game's normal mouse-jump filter without pointer lock or state writes.
async function turnTo(page, yaw, pitch = 0) {
  for (let attempt = 0; attempt < 8; attempt++) {
    let state = await snapshot(page);
    let dx = Math.atan2(Math.sin(state.yaw-yaw), Math.cos(state.yaw-yaw));
    let dy = state.pitch-pitch;
    if (Math.abs(dx) < .015 && Math.abs(dy) < .015) return;
    await page.keyboard.press('Escape');
    await until(page, () => window.__survivorSnapshot?.paused);
    await page.mouse.move(480, 300);
    await page.keyboard.press('Escape');
    await until(page, () => !window.__survivorSnapshot?.paused);
    const sensitivity = .0022 * Math.tan(state.fov*Math.PI/360) / Math.tan(61*Math.PI/360);
    const mx = Math.max(-360, Math.min(360, dx/sensitivity));
    const my = Math.max(-210, Math.min(210, dy/sensitivity));
    const steps = Math.ceil(Math.max(Math.abs(mx), Math.abs(my))/60);
    for (let i = 1; i <= steps; i++) {
      await page.mouse.move(480+mx*i/steps, 300+my*i/steps);
      await page.waitForTimeout(100);
    }
  }
  throw new Error('Normal mouse input did not reach requested view direction');
}
async function imageEvidence(page, info, name) {
	await page.waitForTimeout(650); // Allow the throttled QA renderer to present the latest state.
  const buffer = await page.screenshot({ path: info.outputPath(name + '.png') });
  const png = PNG.sync.read(buffer);
  const colors = new Set();
  let luminous = 0;
  for (let i = 0; i < png.data.length; i += 64) {
    const [r, g, b] = png.data.subarray(i, i + 3);
    colors.add(`${r >> 4},${g >> 4},${b >> 4}`);
    if (r + g + b > 60) luminous++;
  }
  expect(colors.size, 'The rendered scene must contain more than a blank canvas').toBeGreaterThan(30);
  expect(luminous).toBeGreaterThan(500);
  await info.attach(name, { body: buffer, contentType: 'image/png' });
}

test('真实键鼠完成菜单、战斗、换弹、暂停、死亡和重开，禁止鼠标锁', async ({ page }, info) => {
  const errors = [];
  const consoleLines = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    consoleLines.push(`[${message.type()}] ${message.text()}`);
    if (message.type() === 'error') errors.push(message.text());
  });
  try {
    await page.goto('/');
    await until(page, () => window.__survivorSnapshot?.menu === 'home', 90_000);
    expect((await snapshot(page)).buttons.map(b => b.text)).not.toContain('练习模式');
    await clickButton(page, '沙漠之城');
    await until(page, () => window.__survivorSnapshot?.map_id === 'dust');
    await imageEvidence(page, info, '00-desert-home');
    await clickButton(page, '灰松哨站');
    await until(page, () => window.__survivorSnapshot?.map_id === 'outpost');
    await imageEvidence(page, info, '01-home');
    await clickButton(page, '设置');
    await until(page, () => window.__survivorSnapshot?.menu === 'settings');
    await imageEvidence(page, info, '02-settings');
    await page.keyboard.press('Escape');
    await clickButton(page, '武器与操作');
    await until(page, () => window.__survivorSnapshot?.menu === 'guide');
    await page.keyboard.press('Escape');
    await clickButton(page, '多人模式');
    await until(page, () => window.__survivorSnapshot?.menu === 'multiplayer');
    expect((await snapshot(page)).buttons.map(b => b.text)).not.toContain('创建 Steam 房间');
    await page.keyboard.press('Escape');

    // Set the cursor before gameplay. No pointer lock, CDP cursor takeover, or state mutation.
    await page.mouse.move(480, 300);
    await clickButton(page, '单人模式');
    await until(page, () => window.__survivorSnapshot?.mode === 'survival');
    await page.keyboard.down("Control");
    await until(page, () => window.__survivorSnapshot?.player?.crouch > .95);
    expect((await snapshot(page)).player.eye_height).toBeCloseTo(1.1, 1);
    await page.keyboard.up("Control");
    await until(page, () => window.__survivorSnapshot?.player?.crouch < .05);
    const start = await snapshot(page);
    await page.keyboard.down('w');
    await until(page, () => window.__survivorSnapshot?.player?.z < 7.5);
    await page.keyboard.up('w');
    expect((await snapshot(page)).player.z).toBeLessThan(start.player.z - 1);
    await page.keyboard.press('Space');
    await until(page, () => window.__survivorSnapshot?.player?.height > .1);
    await until(page, () => window.__survivorSnapshot?.player?.grounded === true);

    // Aim at an actual enemy using relative browser mouse motion.
    // Telemetry is read-only; bullets must pass through the normal ballistics path.
    await until(page, () => window.__survivorSnapshot?.enemies?.some(z => z.hp > 0 && Math.hypot(z.x-window.__survivorSnapshot.player.x,z.z-window.__survivorSnapshot.player.z) < 8), 60_000);
    let state = await snapshot(page);
    const target = state.enemies.filter(z => z.hp > 0).sort((a,b) => Math.hypot(a.x-state.player.x,a.z-state.player.z)-Math.hypot(b.x-state.player.x,b.z-state.player.z))[0];
    const dx = target.x - state.player.x, dz = target.z - state.player.z;
    const desiredYaw = Math.atan2(-dx, -dz);
    const desiredPitch = Math.atan2(1.4 - 1.7, Math.hypot(dx, dz));
    await turnTo(page, desiredYaw, desiredPitch);
    await expect.poll(async () => Math.abs((await snapshot(page)).yaw - desiredYaw)).toBeLessThan(.06);
    await page.mouse.down({ button: 'right' });
    await until(page, () => window.__survivorSnapshot?.player?.aim);
    await page.mouse.down();
    await until(page, () => window.__survivorSnapshot?.kills > 0);
    await page.mouse.up();
    await page.mouse.up({ button: 'right' });
    state = await snapshot(page);
    expect(state.player.hits).toBeGreaterThan(0);
    expect(state.player.ammo[0]).toBeLessThan(30);
    await page.keyboard.press('r');
    await until(page, () => window.__survivorSnapshot?.player?.reloading);
    const partialAmmo = (await snapshot(page)).player.ammo[0];
    await page.keyboard.press('2');
    await until(page, () => window.__survivorSnapshot?.player?.weapon === 1);
    expect((await snapshot(page)).player.reloading).toBe(false);
    expect((await snapshot(page)).player.ammo[0]).toBe(partialAmmo);
    await page.keyboard.press('1');
    await until(page, () => window.__survivorSnapshot?.player?.weapon === 0 && window.__survivorSnapshot?.player?.switch <= 0);
    await page.keyboard.press('r');
    await until(page, () => window.__survivorSnapshot?.player?.ammo[0] === 30);
    await imageEvidence(page, info, '03-single-player-hit-reload');

    // Weapon inspection needs a fresh encounter: live waves now attack while
    // the tester inspects equipment, unlike the removed stationary range.
    await page.keyboard.press('Escape');
    await clickButton(page, '返回主菜单');
    await clickButton(page, '单人模式');
    await until(page, () => window.__survivorSnapshot?.running && !window.__survivorSnapshot?.paused);
    for (let weapon = 1; weapon < 10; weapon++) {
      await page.keyboard.press(weapon === 9 ? '0' : String(weapon + 1));
      await expect.poll(async () => (await snapshot(page)).player.weapon).toBe(weapon);
    }
    await page.keyboard.press('6');
    await until(page, () => window.__survivorSnapshot?.player?.weapon === 5);
    await page.mouse.down({ button: 'right' });
    await until(page, () => window.__survivorSnapshot?.fov < 20);
    await imageEvidence(page, info, '04-sniper-scope');
    await page.mouse.up({ button: 'right' });
    // Walk into the actual river, jump there, and leave by the opposite bank.
    await page.keyboard.press('Escape');
    await clickButton(page, '返回主菜单');
    await clickButton(page, '单人模式');
    await until(page, () => window.__survivorSnapshot?.running && !window.__survivorSnapshot?.paused);
    await turnTo(page, 0);
    await expect.poll(async () => Math.abs((await snapshot(page)).yaw)).toBeLessThan(.06);
    await page.keyboard.down('w');
    await until(page, () => window.__survivorSnapshot?.player?.wading === true, 30_000);
    await page.keyboard.up('w');
    const riverState = await snapshot(page);
    expect(riverState.player.hp).toBe(100);
    expect(riverState.player.z).toBeLessThan(-14);
    await page.keyboard.press('Space');
    await until(page, () => window.__survivorSnapshot?.player?.grounded === false && window.__survivorSnapshot?.player?.wading === false);
    await until(page, () => window.__survivorSnapshot?.player?.grounded === true);
    expect((await snapshot(page)).player.hp).toBe(100);
    await page.keyboard.down('w');
    await until(page, () => window.__survivorSnapshot?.player?.z < -20.2, 15_000);
    await page.keyboard.up('w');
    expect((await snapshot(page)).player.wading).toBe(false);
    await page.keyboard.press('Escape');
    await until(page, () => window.__survivorSnapshot?.paused);
    const pausedTime = (await snapshot(page)).elapsed;
    await page.waitForTimeout(500);
    expect((await snapshot(page)).elapsed).toBe(pausedTime);
    await clickButton(page, '继续游戏');
    await until(page, () => !window.__survivorSnapshot?.paused);
    await page.keyboard.press('Escape');
    await clickButton(page, '返回主菜单');
    await clickButton(page, '单人模式');
    await until(page, () => window.__survivorSnapshot?.mode === 'survival');
    await until(page, () => window.__survivorSnapshot?.enemies?.length > 0);
    // Stay in the actual encounter until approaching enemies damage and defeat the player.
    await until(page, () => window.__survivorSnapshot?.player?.hp < 100, 100_000);
    await until(page, () => window.__survivorSnapshot?.menu === 'result', 100_000);
    expect((await snapshot(page)).player.hp).toBeLessThanOrEqual(0);
    await imageEvidence(page, info, '05-survival-result');
    await clickButton(page, '再次坚守');
    await until(page, () => window.__survivorSnapshot?.running && !window.__survivorSnapshot?.finished);
    expect((await snapshot(page)).player.hp).toBe(100);
    await page.keyboard.press('Escape');
    await clickButton(page, '返回主菜单');
    await clickButton(page, '波次排行榜');
    await until(page, () => window.__survivorSnapshot?.menu === 'scores');
    await page.keyboard.press('Escape');
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
    expect(await page.evaluate(() => document.pointerLockElement)).toBeNull();
    expect((await snapshot(page)).mouse_mode).toBe(0);
    expect(errors).toEqual([]);
  } finally {
    await info.attach('browser-console', { body: consoleLines.join('\n'), contentType: 'text/plain' });
    await info.attach('final-state', { body: JSON.stringify(await snapshot(page).catch(() => null), null, 2), contentType: 'application/json' });
    await info.attach('desktop-safety', { body: JSON.stringify(await page.evaluate(() => window.__qaSafety).catch(() => null)), contentType: 'application/json' });
  }
});
