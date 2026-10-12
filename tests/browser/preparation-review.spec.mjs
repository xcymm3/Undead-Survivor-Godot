import { test, expect } from '@playwright/test';
import { readFile } from 'node:fs/promises';

test('水晶与展台动画、防御设施三种状态截图', async ({ page }, info) => {
  test.setTimeout(900_000);
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  await page.setViewportSize({ width: 1440, height: 900 });
  const cases = ['crystal_0', 'crystal_9', 'display_0', 'display_9',
    ...['turret', 'mine', 'gate'].flatMap(type => ['unbuilt', 'built', 'prompt'].map(state => `${type}_${state}`))];
  const pictures = new Map();
  for (const scenario of cases) {
    await page.goto(`/?preparationReview=${scenario}`);
    await page.waitForFunction(() => window.__preparationReviewReady, null, { timeout: 90_000 });
    const state = await page.evaluate(() => window.__preparationReviewReady);
    expect(state.closed).toBe(false);
    if (scenario.endsWith('_unbuilt')) {
      expect(state.focus_visible).toBe(true);
      expect(state.focus_text).toContain(scenario.startsWith('gate') ? '80$' : '100$');
    }
    if (scenario.endsWith('_prompt')) {
      expect(state.focus_visible).toBe(true);
      expect(state.focus_text).toContain(scenario.startsWith('mine') ? '已布置' : '20$');
      if (!scenario.startsWith('mine')) expect(state.focus_text).toContain('长按 E');
    }
    const file = info.outputPath(`${scenario}.png`);
    await page.screenshot({ path: file, timeout: 60_000 });
    pictures.set(scenario, `data:image/png;base64,${(await readFile(file)).toString('base64')}`);
    await info.attach(scenario, { path: file, contentType: 'image/png' });
    expect(await page.evaluate(() => window.__qaSafety)).toEqual({ pointerLockRequests: 0, fullscreenRequests: 0 });
  }
  expect(errors).toEqual([]);
  const groups = [
    ['crystal', '水晶循环旋转', ['crystal_0', 'crystal_9'], ['0 秒', '9 秒']],
    ['display', '展台武器循环旋转', ['display_0', 'display_9'], ['0 秒', '9 秒']],
    ...[['turret', '炮塔'], ['mine', '地雷'], ['gate', '栅栏门']].map(([id, title]) =>
      [id, title, [`${id}_unbuilt`, `${id}_built`, `${id}_prompt`], ['未建造', '建造后', id === 'mine' ? '靠近后的状态提示（无升级项）' : '靠近后的升级提示']]),
  ];
  for (const [id, title, names, captions] of groups) {
    await page.goto('about:blank');
    await page.setViewportSize({ width: names.length === 2 ? 1440 : 1920, height: 540 });
    await page.setContent(`<html><head><style>*{box-sizing:border-box}body{margin:0;background:#0c1520;color:#ece5d3;font-family:"Segoe UI",sans-serif}h1{font-size:25px;margin:18px 22px 10px}.grid{display:grid;grid-template-columns:repeat(${names.length},1fr);gap:12px;padding:0 16px}figure{margin:0}figcaption{font-size:19px;margin:4px 0 10px}img{width:100%;display:block}</style></head><body><h1>${title} · 云端隔离实景截图</h1><div class="grid">${names.map((name, i) => `<figure><figcaption>${captions[i]}</figcaption><img src="${pictures.get(name)}"></figure>`).join('')}</div></body></html>`);
    await page.waitForFunction(() => [...document.images].every(image => image.complete));
    const file = info.outputPath(`${id}-board.png`);
    await page.screenshot({ path: file, timeout: 60_000, fullPage: true });
    await info.attach(`${id}-board`, { path: file, contentType: 'image/png' });
  }
});
