import { test, expect } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

test.use({ trace: 'off' });
test('新存档播放序章后直接进入出生点', async ({ page }) => {
  test.setTimeout(600_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text()); });
  const directory = path.resolve('artifacts/ultimate-entry');
  await mkdir(directory, { recursive: true });
  await page.goto('/?campaignReview=ultimate_entry');
  await page.waitForFunction(() => Boolean(window.__campaignReviewReady), null, { timeout: 90_000 });
  const ready = await page.evaluate(() => window.__campaignReviewReady);
  const stills = process.env.QA_ENTRY_STILLS === '1';
  const states = [];
  const captures = new Map([[8,'intro-first'],[32,'intro-second'],[56,'intro-third'],[76,'spawn-fade'],[87,'spawn']]);
  for (let frame = 0; frame < ready.frames; frame++) {
    await page.evaluate(([i,paint]) => window.__drawUltimateEntry(i,paint),[frame,!stills || captures.has(frame)]);
    await page.waitForFunction(index => window.__entryFrame === index,frame);
    states.push(await page.evaluate(() => window.__entryState));
    if (!stills) await page.screenshot({path:path.join(directory,`frame-${String(frame).padStart(3,'0')}.png`)});
    if (captures.has(frame)) await page.screenshot({path:path.join(directory,captures.get(frame)+'.png')});
  }
  await writeFile(path.join(directory,'timing.json'),JSON.stringify({...ready,states},null,2));
  expect(states.slice(0,71).every(s=>s.phase==='intro' && !s.sim_started && s.black===1)).toBe(true);
  expect(states.some(s=>s.phase==='handoff' && s.at_spawn && s.black===1)).toBe(true);
  expect(states.at(-1)).toMatchObject({phase:'spawn',choice:'blade',at_spawn:true,intro_seen:true,ultimate_unlocked:false});
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  expect(errors).toEqual([]);
});
