import { test, expect } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

test.use({ viewport: { width: 1440, height: 900 }, trace: 'off' });
test('按需截取新手故事、操作提示、展台与老板付款', async ({ page }) => {
  test.setTimeout(600_000);
  const directory = path.resolve('artifacts/tutorial-review');
  await mkdir(path.join(directory, 'payment-frames'), { recursive: true });
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text()); });
  const states = [];
  async function open(scenario) {
    await page.goto(`/?preparationReview=tutorial_${scenario}`);
    await page.waitForFunction(() => window.__tutorialReviewReady, null, { timeout: 90_000 });
  }
  async function seek(time) {
    await page.evaluate(time => window.__tutorialSeek(time), time);
    await page.waitForFunction(time => window.__tutorialReviewReady && Math.abs(window.__tutorialReviewReady.time-time) < .001, time, { timeout: 30_000 });
    return page.evaluate(() => window.__tutorialReviewReady);
  }
  for (const [scenario, time, filename] of [
    ['intro', 7.2, '01-opening.png'],
    ['movement', 0, '02-movement-hint.png'],
    ['combat', 0, '03-combat-hint.png'],
    ['broken', 0, '04-broken-stations.png'],
    ['dialogue', 3.2, '05-shopkeeper-dialogue.png'],
  ]) {
    await open(scenario);
    const state = await seek(time);
    states.push(state);
    if (scenario === 'intro') expect(state.caption.split('\n')).toHaveLength(3);
    if (scenario === 'movement') expect(state.hint).toBe('movement');
    if (scenario === 'combat') expect(state.hint).toBe('combat');
    await page.screenshot({ path: path.join(directory, filename), timeout: 60_000 });
  }
  await open('payment');
  const initial = await page.evaluate(() => window.__tutorialReviewReady);
  const start = initial.payment_at - .4;
  for (let index = 0; index < 26; index++) {
    const state = await seek(start + index * .1);
    states.push(state);
    await page.screenshot({ path: path.join(directory, 'payment-frames', `${String(index).padStart(3,'0')}.png`), timeout: 60_000 });
    if (index === 20) await page.screenshot({ path: path.join(directory, '06-blueprint-payment.png'), timeout: 60_000 });
  }
  expect(states.some(state => state.scenario === 'tutorial_payment' && state.coins === 150)).toBe(true);
  expect(states.some(state => state.scenario === 'tutorial_payment' && state.coins === 100 && state.flying_coins > 0)).toBe(true);
  await page.screenshot({ path: path.join(directory, '06-blueprint-dialogue.png'), timeout: 60_000 });
  await writeFile(path.join(directory, 'states.json'), JSON.stringify(states, null, 2));
  expect(errors).toEqual([]);
  expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
});
