import { test, expect } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

test('紧凑存档弹窗、累计收入与仅切换存档', async ({ page }) => {
  test.setTimeout(360_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => { if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text()); });
  const directory = path.resolve('artifacts/save-slots-review');
  await mkdir(directory, { recursive: true });
  for (const width of [1440, 960]) {
    await page.setViewportSize({ width, height: width === 1440 ? 900 : 600 });
    await page.goto('/?campaignReview=save_slots');
    await page.waitForFunction(() => Boolean(window.__saveSlotsReady), null, { timeout: 90_000 });
    const state = await page.evaluate(() => window.__saveSlotsReady);
    expect(state.menu).toBe('saves');
    expect(state.frame_size).toEqual([820, 660]);
    expect(state.fields).toHaveLength(3);
    expect(state.fields[0].coins).toBe('获得金币：1285.5');
    expect(state.fields[0].diamonds).toBe('获得钻石：12');
    expect(state.fields[0].victories).toBe('通关次数：1');
    expect(state.wallet).toBe(1260.5);
    expect(state.fields.every(field => field.delete_text === '' && field.delete_name.startsWith('删除存档'))).toBe(true);
    await page.screenshot({ path: path.join(directory, `saves-${width}.png`) });
    await writeFile(path.join(directory, `saves-${width}.json`), JSON.stringify(state, null, 2));
    await page.evaluate(() => window.__saveSlotAction('delete', 1));
    await page.waitForFunction(() => window.__saveSlotsReady?.action === 'delete');
    expect(await page.evaluate(() => window.__saveSlotsReady.menu)).toBe('delete_save');
    await page.screenshot({ path: path.join(directory, `delete-confirm-${width}.png`) });
    await page.evaluate(() => window.__saveSlotAction('cancel', 1));
    await page.waitForFunction(() => window.__saveSlotsReady?.action === 'cancel');
    await page.evaluate(() => window.__saveSlotAction('select', 1));
    await page.waitForFunction(() => window.__saveSlotsReady?.action === 'select');
    const selected = await page.evaluate(() => window.__saveSlotsReady);
    expect(selected.menu).toBe('home');
    expect(selected.active).toBe(1);
    expect(selected.running).toBe(false);
    expect(selected.has_sim).toBe(false);
    await page.screenshot({ path: path.join(directory, `selected-home-${width}.png`) });
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  expect(errors).toEqual([]);
});
