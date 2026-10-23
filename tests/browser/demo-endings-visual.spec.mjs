import { test, expect } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

test.use({ trace: 'off' });
test('倒下、水晶摧毁、舞王胜利自动重生和联机须知与老板提示GIF', async ({ page }) => {
  test.setTimeout(1_500_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text()); });
  await page.setViewportSize({ width: 960, height: 600 });
  for (const kind of ['failure', 'crystal', 'victory', 'notice']) {
    const directory = path.resolve('artifacts/demo-endings', kind);
    await mkdir(directory, { recursive: true });
    await page.goto(`/?campaignReview=${kind === 'notice' ? 'notice_merchant' : `demo_${kind}`}`);
    await page.waitForFunction(() => Boolean(window.__campaignReviewReady), null, { timeout: 90_000 });
    const ready = await page.evaluate(() => window.__campaignReviewReady);
    const states = [];
    const canvas = await page.locator('canvas').boundingBox();
    const xy = pair => [canvas.x + pair[0] * canvas.width / 1440, canvas.y + pair[1] * canvas.height / 900];
    for (let frame = 0; frame < ready.frames; frame++) {
      if (kind === 'notice') {
        if (frame === 12) { await page.mouse.move(...xy(ready.drag_from)); await page.mouse.down(); }
        if (frame > 12 && frame < 24) {
          const t = (frame - 12) / 11;
          await page.mouse.move(...xy(ready.drag_from.map((value, index) => value + (ready.drag_to[index] - value) * t)));
        }
        if (frame === 24) await page.mouse.up();
        if (frame === 36) await page.mouse.click(...xy(ready.confirm));
        if (frame === 44) await page.mouse.click(...xy(ready.reopen));
        if (frame === 52) await page.mouse.click(...xy(ready.cancel));
        await page.evaluate(() => new Promise(resolve => requestAnimationFrame(resolve)));
      }
      await page.evaluate(({ frame, notice }) => notice ? window.__drawNoticeMerchant(frame) : window.__drawDemoEnding(frame), { frame, notice: kind === 'notice' });
      await page.waitForFunction(({ frame, notice }) => (notice ? window.__noticeFrame : window.__demoEndingFrame) === frame, { frame, notice: kind === 'notice' });
      states.push(await page.evaluate(notice => notice ? window.__noticeState : window.__demoEndingState, kind === 'notice'));
      await page.screenshot({ path: path.join(directory, `frame-${String(frame).padStart(3, '0')}.png`) });
    }
    await writeFile(path.join(directory, 'timing.json'), JSON.stringify({ ...ready, commit: process.env.GITHUB_SHA, states }, null, 2));
    if (kind === 'notice') {
      expect(states[0]).toMatchObject({ dialog: true, confirm_disabled: true, seen: false });
      expect(states[35]).toMatchObject({ dialog: true, read: true, confirm_disabled: false });
      expect(states[40]).toMatchObject({ dialog: false, menu: 'multiplayer', seen: true });
      expect(states[48]).toMatchObject({ dialog: true, confirm_disabled: true });
      expect(states[56].menu).toBe('home');
      expect(states.at(-1).merchant).toBe(true);
      expect(states.at(-1).alert_size).toBeGreaterThan(1);
    } else {
      expect(states.every(state => !state.result)).toBe(true);
      expect(states.some(state => state.phase === 'fade_out' && state.black > 0 && state.black < 1)).toBe(true);
      expect(states.some(state => state.caption && state.caption_alpha > .9 && state.black === 1 && state.text === (kind === 'victory' ? '太阳升起，你活下来了...' : '今晚，无人生还...'))).toBe(true);
      expect(states.some(state => state.phase === 'fade_in' && state.restarted && state.black > 0 && state.black < 1)).toBe(true);
      expect(states.at(-1)).toMatchObject({ restarted: true, phase: 'playing', black: 0, failed: false, won: false });
      if (kind === 'failure') expect(states.some(state => Math.abs(state.camera_roll) > 1)).toBe(true);
      if (kind === 'crystal') expect(states.some(state => state.crystal_hp === 0)).toBe(true);
    }
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  expect(errors).toEqual([]);
});
