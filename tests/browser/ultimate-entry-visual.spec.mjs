import { test, expect } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

test.use({ trace: 'off' });
test('新存档序章、三色终极武器展厅与选择后进入商店GIF', async ({ page }) => {
  test.setTimeout(600_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text()); });
  const directory = path.resolve('artifacts/ultimate-entry');
  await mkdir(directory, { recursive: true });
  await page.goto('/?campaignReview=ultimate_entry');
  await page.waitForFunction(() => Boolean(window.__campaignReviewReady), null, { timeout: 90_000 });
  const ready = await page.evaluate(() => window.__campaignReviewReady);
  const states = [];
  // Actual browser input, never teleporting the player or setting the camera.
  const held = new Set();
  let mouseX = 480;
  await page.mouse.move(mouseX, 300);
  const inputs = [];

  for (let frame = 0; frame < ready.frames; frame++) {
    const key = frame >= 80 && frame < 98 ? 'a'
      : frame >= 98 && frame < 110 ? 'w'
      : frame >= 126 && frame < 138 ? 's'
      : frame >= 138 && frame < 174 ? 'd'
      : frame >= 174 && frame < 186 ? 'w'
      : frame >= 202 && frame < 214 ? 's'
      : frame >= 214 && frame < 232 ? 'a'
      : frame >= 232 && frame < 244 ? 'w'
      : ([122, 198].includes(frame) || (frame >= 252 && frame <= 260)) ? 'e' : '';
    for (const old of held) if (old !== key) { await page.keyboard.up(old); held.delete(old); }
    if (key && !held.has(key)) { await page.keyboard.down(key); held.add(key); }
    const turn = [112, 188, 246].some(start => frame >= start && frame < start + 4) ? 6
      : [116, 192, 250].some(start => frame >= start && frame < start + 4) ? -6 : 0;
    if (turn) { mouseX += turn; await page.mouse.move(mouseX, 300); }
    // Let the Web input loop receive DOM events before advancing physics.
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
    inputs.push({ frame, key, mouseDeltaX: turn });
    await page.evaluate(index => window.__drawUltimateEntry(index), frame);
    await page.waitForFunction(index => window.__entryFrame === index, frame);
    states.push(await page.evaluate(() => window.__entryState));
    await page.screenshot({ path: path.join(directory, `frame-${String(frame).padStart(3, '0')}.png`) });
  }
  await writeFile(path.join(directory, 'timing.json'), JSON.stringify({ ...ready, commit: process.env.GITHUB_SHA, inputs, states }, null, 2));
  expect(states.slice(0, 70).every(state => state.phase === 'intro' && !state.sim_started)).toBe(true);
  expect(states[124].rocket_blocked).toBe(true);
  expect(states[200].scepter_blocked).toBe(true);
  expect(states[110].focus).toBe('rocket_launcher');
  expect(states[186].focus).toBe('crimson_scepter');
  expect(states[244].focus).toBe('blade');
  expect(states[255].hold_progress).toBeGreaterThan(.4);
  expect(states[255].phase).toBe('room');
  expect(states[260].choice).toBe('blade');
  expect(states[244].detail.rows[0]).toEqual(['伤害', '200']);
  expect(Math.abs(states[115].yaw - states[111].yaw)).toBeGreaterThan(.02);
  for (let index = 81; index < 260; index++) {
    expect(Math.hypot(states[index].x - states[index - 1].x, states[index].z - states[index - 1].z)).toBeLessThanOrEqual(.451);
  }
  expect(states.some(state => state.phase === 'fade_out'  && state.choice === 'blade' && !state.sim_started)).toBe(true);
  expect(states.some(state => state.phase === 'handoff' && state.black === 1 && state.sim_started)).toBe(true);
  expect(states.at(-1)).toMatchObject({ phase: 'shop', choice: 'blade', intro_seen: true, ultimate_unlocked: false, main_visible: true });
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  expect(errors).toEqual([]);
});
