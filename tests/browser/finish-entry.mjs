export async function finishEntry(page) {
  await page.waitForFunction(() => {
    const state = window.__survivorSnapshot;
    return state?.mode === 'defense' && !state.entry && state.running;
  }, null, { timeout: 60_000 });
}
