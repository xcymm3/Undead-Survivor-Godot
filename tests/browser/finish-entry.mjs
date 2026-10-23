// Cloud/headless browser integration follows the same walk-and-select input as a new player.
export async function finishEntry(page) {
  await page.waitForFunction(() => window.__survivorSnapshot?.entry?.phase === 'room' || window.__survivorSnapshot?.mode === 'defense', null, { timeout: 45_000 });
  if (await page.evaluate(() => Boolean(window.__survivorSnapshot?.entry))) {
    await page.keyboard.down('w');
    try {
      await page.waitForFunction(() => window.__survivorSnapshot?.entry?.z < .3, null, { timeout: 15_000 });
    } finally { await page.keyboard.up('w'); }
    await page.waitForFunction(() => window.__survivorSnapshot?.entry?.focus === 'blade');
    await page.keyboard.down('e');
    try {
      await page.waitForFunction(() => !window.__survivorSnapshot?.entry || window.__survivorSnapshot.entry.phase !== 'room');
    } finally { await page.keyboard.up('e'); }
    await page.waitForFunction(() => !window.__survivorSnapshot?.entry && window.__survivorSnapshot?.mode === 'defense', null, { timeout: 20_000 });
  }
}
