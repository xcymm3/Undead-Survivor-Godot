import { spawn, execFileSync } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer } from 'node:net';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
process.chdir(root);
const release = process.argv.includes('--release');
const full = process.argv.includes('--full');
const profile = full ? 'full' : 'core';
const excluded = full ? [] : ['balance-solo-duo', 'shotgun-unrestricted', 'all-weapons', 'weapon-comparison', 'target-weapons', 'spread-weapons', 'browser-visual-matrix'];
const children = new Set();
function stop(child) {
  if (!child.pid || child.exitCode !== null) return;
  if (process.platform === 'win32') {
    try { execFileSync('taskkill.exe', ['/PID', String(child.pid), '/T', '/F'], { windowsHide: true, stdio: 'ignore' }); } catch { }
  } else child.kill();
}
const stages = [];
const startedAt = new Date().toISOString();
const git = args => execFileSync('git', args, { encoding: 'utf8', windowsHide: true }).trim();
async function fingerprint() {
  const names = [...new Set(git(['ls-files', '-co', '--exclude-standard', '-z']).split('\0').filter(Boolean))].sort();
  const hash = createHash('sha256');
  for (const name of names) { hash.update(name + '\0'); hash.update(await readFile(name)); }
  return hash.digest('hex');
}
if (process.argv.includes('--check-report')) {
  const report = JSON.parse(await readFile('artifacts/acceptance.json', 'utf8'));
  if (report.status !== 'passed' || report.sourceDigest !== await fingerprint()) {
    throw new Error('Acceptance report failed or is stale. Run npm run verify again before submitting.');
  }
  console.log(`Acceptance gate: PASS (${report.profile ?? 'legacy-full'}), exact current source tree verified.`);
  process.exit(0);
}
await import('./postinstall.mjs');

function launch(name, command, args, timeout = 180_000) {
  console.log(`START ${name}`);
  const start = Date.now();
  const child = spawn(command, args, { cwd: root, windowsHide: true, shell: false, env: { ...process.env, PWDEBUG: '0', PLAYWRIGHT_HTML_OPEN: 'never' } });
  children.add(child);
  let output = '', timedOut = false;
  const timer = setTimeout(() => { timedOut = true; stop(child); }, timeout);
  child.stdout.on('data', chunk => { output += chunk; });
  child.stderr.on('data', chunk => { output += chunk; });
  const promise = new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('close', async code => {
      clearTimeout(timer);
      children.delete(child);
      await writeFile(`artifacts/${name}.log`, output);
      const passed = code === 0 && !timedOut && !/^(?:SCRIPT ERROR|ERROR):/m.test(output);
      stages.push({ name, passed, exitCode: code, seconds: (Date.now() - start) / 1000, log: `${name}.log` });
      console.log(`${passed ? 'PASS' : 'FAIL'} ${name} (${((Date.now() - start) / 1000).toFixed(1)}s)`);
      if (passed) resolve(output);
      else reject(new Error(`${name} failed${timedOut ? ' (timeout)' : ''}. See artifacts/${name}.log\n${output.slice(-3000)}`));
    });
  });
  // Register a handler immediately when running network peers in parallel.
  promise.catch(() => {});
  return { promise, child, output: () => output };
}
const run = (name, command, args, timeout) => launch(name, command, args, timeout).promise;
const powershell = (name, script, args = [], timeout = 180_000) => run(name, 'pwsh.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, ...args], timeout);
const engine = path.join(root, '.runtime/Godot_v4.5.2-stable_win64_console.exe');
const godotArgs = ['--headless', '--audio-driver', 'Dummy', '--path', root];
let sourceDigest, failure;
try {
  if (process.platform !== 'win32') throw new Error('This pipeline targets Windows; use the windows-2022 Actions runner.');
  await run('version', process.execPath, ['tools/version.mjs', '--check']);
  await powershell('setup-runtime', 'tools/setup-runtime.ps1', [], 600_000);
  await powershell('setup-web-templates', 'tools/setup-web-templates.ps1', [], 1200_000);
  await run('import', engine, [...godotArgs, '--editor', '--import', '--quit']);
  sourceDigest = await fingerprint();
  const native = await run('native-components', engine, [...godotArgs, '--script', 'res://tools/validate-native-components.gd', '--', '--silent', '--automation']);
  if (!/NATIVE COMPONENTS: \d+ checks; 0 failures/.test(native)) throw new Error('Missing native component acceptance marker.');
  const night = await run('night-campaign', engine, [...godotArgs, '--script', 'res://tools/validate-night.gd', '--', '--silent', '--automation'], 900_000);
  if (!/NIGHT VALIDATION: \d+ checks; 0 failures/.test(night)) throw new Error('Missing night campaign acceptance marker.');
  const defense = await run('crystal-defense', engine, [...godotArgs, '--script', 'res://tools/validate-defense.gd', '--', '--silent', '--automation'], 300_000);
  if (!/DEFENSE VALIDATION: \d+ checks; 0 failures/.test(defense)) throw new Error('Missing crystal defense acceptance marker.');
  if (full) {
    const balance = await run('balance-solo-duo', engine, [...godotArgs, '--script', 'res://tools/validate-balance.gd', '--', '--silent', '--automation'], 900_000);
    if (!/BALANCE VALIDATION: 4 checks; 0 failures/.test(balance)) throw new Error('Missing complete unrestricted solo/duo balance acceptance marker.');
    await run('shotgun-unrestricted', engine, [...godotArgs, '--script', 'res://tools/validate-shotgun.gd', '--', '--silent', '--automation'], 900_000);
    const weapons = await run('all-weapons', engine, [...godotArgs, '--script', 'res://tools/validate-all-weapons.gd', '--', '--silent', '--automation'], 1800_000);
    if (!/ALL WEAPONS: 20 samples; 0 failures/.test(weapons)) throw new Error('Missing all-weapon comparison or detected another weapon being used.');
    await run('weapon-comparison', process.execPath, ['tools/summarize-weapons.mjs']);
    await run('target-weapons', engine, [...godotArgs, '--script', 'res://tools/validate-target-weapons.gd', '--', '--silent', '--automation'], 900_000);
    await run('spread-weapons', engine, [...godotArgs, '--script', 'res://tools/validate-spread-weapons.gd', '--', '--silent', '--automation'], 1200_000);
  }
  await run('spread-ballistics', engine, [...godotArgs, '--script', 'res://tools/validate-spread-ballistics.gd', '--', '--silent', '--automation'], 300_000);
  await run('night-full-enet-2', process.execPath, ['tools/validate-campaign-network.mjs', '2'], 960_000);
  await mkdir('build/web', { recursive: true });
  await run('export-web', engine, [...godotArgs, '--export-release', 'Web QA']);
  // Keep the isolated QA browser separate from existing preview servers.
  process.env.QA_WEB_PORT = await new Promise((resolve, reject) => {
    const server = createServer();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const port = String(server.address().port);
      server.close(error => error ? reject(error) : resolve(port));
    });
  });
  // Core keeps real input coverage; the expensive visual matrix remains opt-in.
  await run('browser-playthrough', process.execPath,
    ['node_modules/@playwright/test/cli.js', 'test', ...(full ? [] : ['--grep', '@core'])], full ? 1800_000 : 300_000);
  const browser = JSON.parse(await readFile('artifacts/browser-results.json', 'utf8'));
  if (browser.stats.unexpected || browser.stats.flaky || browser.stats.skipped || browser.errors?.length ||
      (!full && browser.stats.expected !== 5) || !browser.stats.expected)
    throw new Error('Browser suite must complete all selected tests without failures, skips, or retries. Core requires five tests.');
  if (release) {
    await powershell('export-windows', 'tools/export-windows.ps1', [], 900_000);
    // Never launch the EXE graphically: the package itself runs its smoke check headless.
    const exe = path.join(root, 'build/payload/Undead-Survivor-Godot.exe');
    const smoke = await run('packaged-exe', exe, ['--headless', '--audio-driver', 'Dummy', '--', '--automation', '--silent', '--qa-native-smoke'], 60_000);
    if (!smoke.includes('PACKAGED EXE SMOKE: PASS')) throw new Error('Missing packaged EXE pass marker.');
    await run('single-exe', process.execPath, ['tools/validate-single-exe.mjs'], 90_000);
    await powershell('package-windows', 'tools/package-windows.ps1');
  }
  if (sourceDigest !== await fingerprint()) throw new Error('Source files changed during verification. Run again for this exact tree.');
} catch (error) {
  failure = String(error.stack ?? error);
  console.error(failure);
} finally {
  for (const child of children) stop(child);
  const report = { status: failure ? 'failed' : 'passed', startedAt, finishedAt: new Date().toISOString(),
    commit: git(['rev-parse', 'HEAD']), sourceDigest, release, profile, excluded, stages, failure,
    boundaries: [full ? '本次为完整回归，包含武器比较、平衡样本和完整软件截图矩阵。' : '本次为核心回归：原生组件、夜路单人整关、水晶防守专项、弹道、ENet 双人和五项浏览器真实输入。未运行的扩展项不计为通过。', '水晶防守验证覆盖单人地图、拉杆、换装区、目标选择、十波胜负；联机整关仍只覆盖灰松夜路双人。', '本机 ENet 双人验证不代表 Steam 双账号验证。真人节奏、趣味性与原生 GPU 质量待验收。', '网页使用独立无界面 Chromium、实际键鼠输入及只读遥测；截图不能证明主观手感或原版地图视觉一致性。', release ? '本次包含 Windows 导出、无窗口 EXE 冒烟和 ZIP 打包。' : '本次不包含 Windows EXE 导出与打包。'] };
  report.seconds = (Date.parse(report.finishedAt) - Date.parse(startedAt)) / 1000;
  await writeFile('artifacts/acceptance.json', JSON.stringify(report, null, 2));
  await writeFile('artifacts/acceptance.md', `# 自动验收：${report.status}\n\n配置：${profile}；总耗时：${report.seconds.toFixed(1)}s\n\n提交：${report.commit}\n\n源码 SHA-256：${sourceDigest ?? '未完成导入'}\n\n| 阶段 | 结果 | 耗时 |\n| --- | --- | --- |\n${stages.map(s => `| ${s.name} | ${s.passed ? '通过' : '失败'} | ${s.seconds.toFixed(1)}s |`).join('\n')}\n\n${report.boundaries.map(b => '- ' + b).join('\n')}\n\n本配置未运行：${excluded.join(', ') || '无'}\n${failure ? '\n```text\n' + failure + '\n```\n' : ''}`);
  process.exitCode = failure ? 1 : 0;
}
