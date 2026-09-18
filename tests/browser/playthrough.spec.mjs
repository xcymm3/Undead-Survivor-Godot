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

test('夜路真实输入完成菜单、移动、暂停与重开', { tag: '@core' }, async ({ page }, info) => {
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));
  await page.goto('/');
  await until(page, () => window.__survivorSnapshot?.menu === 'home', 90000);
  expect((await snapshot(page)).map_id).toBe('graypine_night');
  for (const removed of ['沙漠之城','灰松哨站','灰松渡口','波次排行榜'])
    expect((await snapshot(page)).buttons.map(b => b.text)).not.toContain(removed);
  await imageEvidence(page, info, '01-night-only-home');
  for (const [label,menu] of [['设置','settings'],['武器与操作','guide'],['多人模式','multiplayer']]) {
    await clickButton(page,label); await until(page, () => window.__survivorSnapshot?.menu !== 'home');
    expect((await snapshot(page)).menu).toBe(menu);
    await page.keyboard.press('Escape');
  }
  await clickButton(page,'单人模式');
  await until(page, () => window.__survivorSnapshot?.mode === 'campaign' && window.__survivorSnapshot?.running);
  await page.keyboard.down('Control');
  await until(page, () => window.__survivorSnapshot.player.crouch > .95);
  expect((await snapshot(page)).player.eye_height).toBeCloseTo(1.1,1);
  await page.keyboard.up('Control');
  await until(page, () => window.__survivorSnapshot.player.crouch < .05);
  await page.keyboard.press('Space');
  await until(page, () => !window.__survivorSnapshot.player.grounded);
  await until(page, () => window.__survivorSnapshot.player.grounded);
  await page.keyboard.down('w'); await page.keyboard.down('e');
  await page.waitForFunction(() => window.__survivorSnapshot.campaign.bar_removed);
  await page.keyboard.up('e');
  await page.waitForTimeout(100);
  await page.keyboard.down('e');
  await until(page, () => window.__survivorSnapshot.campaign.departed);
  await page.keyboard.up('w'); await page.keyboard.up('e');
  await imageEvidence(page,info,'02-night-departed');
  await page.keyboard.press('Escape');
  await until(page, () => window.__survivorSnapshot.paused);
  const t=(await snapshot(page)).elapsed;
  await page.waitForTimeout(500);
  expect((await snapshot(page)).elapsed).toBe(t);
  await clickButton(page,'继续游戏');
  await until(page, () => !window.__survivorSnapshot.paused);
  await page.keyboard.press('Escape'); await clickButton(page,'返回主菜单');
  await clickButton(page,'单人模式');
  await until(page, () => window.__survivorSnapshot.running && !window.__survivorSnapshot.finished);
  expect((await snapshot(page)).player.hp).toBe(100);
  expect((await snapshot(page)).campaign.departed).toBe(false);
  expect((await snapshot(page)).map_id).toBe('graypine_night');
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({pointerLockRequests:0,fullscreenRequests:0});
});
