import { spawn, execFileSync } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer } from 'node:net';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
process.chdir(root);
const release = process.argv.includes('--release');
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
  console.log('Acceptance gate: PASS, exact current source tree verified.');
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
async function network(count, map = 'outpost') {
  const peers = [];
  const args = [...godotArgs, '--script', 'res://tools/validate-network.gd', '--', '--silent', '--automation', ...(count === 4 ? ['--four'] : [])];
  const host = launch(`network-${map}-${count}-host`, engine, [...args, '--host', `--map=${map}`, `--expect-map=${map}`], 200_000);
  peers.push(host.promise);
  const deadline = Date.now() + 90_000;
  while (!host.output().includes('NETWORK READY')) {
    if (Date.now() > deadline || host.child.exitCode !== null) throw new Error('Network host did not become ready.');
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  for (let i = 1; i < count; i++) peers.push(launch(`network-${map}-${count}-client-${i}`, engine, [...args, '--map=outpost', `--expect-map=${map}`], 200_000).promise);
  const outputs = await Promise.all(peers);
  if (!outputs.every(output => /result=PASS/.test(output))) throw new Error('Missing network pass marker.');
}
let sourceDigest, failure;
try {
  if (process.platform !== 'win32') throw new Error('This pipeline targets Windows; use the windows-2022 Actions runner.');
  await run('version', process.execPath, ['tools/version.mjs', '--check']);
  await powershell('setup-runtime', 'tools/setup-runtime.ps1', [], 600_000);
  await powershell('setup-web-templates', 'tools/setup-web-templates.ps1', [], 1200_000);
  await run('import', engine, [...godotArgs, '--editor', '--import', '--quit']);
  sourceDigest = await fingerprint();
  const output = await run('runtime', engine, [...godotArgs, '--script', 'res://tools/validate-runtime.gd', '--', '--silent', '--automation']);
  if (!/RUNTIME VALIDATION: \d+ checks; 0 failures/.test(output)) throw new Error('Missing runtime validation pass marker.');
  for (const [name, marker] of [['native-components', 'NATIVE COMPONENTS'], ['maps', 'MAP VALIDATION']]) {
    const result = await run(name, engine, [...godotArgs, '--script', `res://tools/validate-${name}.gd`, '--', '--silent', '--automation']);
    if (!new RegExp(`${marker}: \\d+ checks; 0 failures`).test(result)) throw new Error(`Missing ${name} pass marker.`);
  }
  const campaign = await run('legacy-campaign-fixtures', engine, [...godotArgs, '--script', 'res://tools/validate-campaign.gd', '--', '--silent', '--automation', '--fixtures-only'], 900_000);
  if (!/CAMPAIGN VALIDATION: \d+ checks; 0 failures/.test(campaign)) throw new Error('Missing campaign acceptance marker.');
  const night = await run('night-campaign', engine, [...godotArgs, '--script', 'res://tools/validate-night.gd', '--', '--silent', '--automation'], 900_000);
  if (!/NIGHT VALIDATION: \d+ checks; 0 failures/.test(night)) throw new Error('Missing night campaign acceptance marker.');
  await network(2);
  await network(4);
  await network(2, 'dust');
  await network(4, 'dust');
  await network(2, 'graypine_ferry');
  await network(4, 'graypine_ferry');
  for (const count of [2, 4]) await run(`night-full-enet-${count}`, process.execPath, ['tools/validate-campaign-network.mjs', String(count), '--night'], 960_000);
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
  // Full-quality shadow matrices and adjacent-angle video add software rasterization work.
  await run('browser-playthrough', process.execPath, ['node_modules/@playwright/test/cli.js', 'test'], 900_000);
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
    commit: git(['rev-parse', 'HEAD']), sourceDigest, release, stages, failure,
    boundaries: ['覆盖生存双地图、旧战役规则回归，以及灰松夜路内部输入试玩与真实 ENet 双人/四人整关合作。旧十五分钟路线不再作为现行关卡执行整关校准。', '三张地图分别运行本机 ENet 双人和四人检查；不代表 Steam 双账号验证。灰松夜路真人约三分钟节奏、趣味性与原生 GPU 质量待验收。', '网页使用独立无界面 Chromium、实际键鼠输入及只读遥测；截图不能证明主观手感或原版地图视觉一致性。', release ? '本次包含 Windows 导出、无窗口 EXE 冒烟和 ZIP 打包。' : '本次为 npm run verify 全量验收，不包含 verify:release 的 Windows EXE 导出与打包。'] };
  await writeFile('artifacts/acceptance.json', JSON.stringify(report, null, 2));
  await writeFile('artifacts/acceptance.md', `# 自动验收：${report.status}\n\n提交：${report.commit}\n\n源码 SHA-256：${sourceDigest ?? '未完成导入'}\n\n| 阶段 | 结果 | 耗时 |\n| --- | --- | --- |\n${stages.map(s => `| ${s.name} | ${s.passed ? '通过' : '失败'} | ${s.seconds.toFixed(1)}s |`).join('\n')}\n\n${report.boundaries.map(b => '- ' + b).join('\n')}\n${failure ? '\n```text\n' + failure + '\n```\n' : ''}`);
  process.exitCode = failure ? 1 : 0;
}
