import { spawn, execFileSync } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

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
async function network(count) {
  const peers = [];
  const args = [...godotArgs, '--script', 'res://tools/validate-network.gd', '--', '--silent', '--automation', ...(count === 4 ? ['--four'] : [])];
  const host = launch(`network-${count}-host`, engine, [...args, '--host'], 30_000);
  peers.push(host.promise);
  const deadline = Date.now() + 15_000;
  while (!host.output().includes('NETWORK READY')) {
    if (Date.now() > deadline || host.child.exitCode !== null) throw new Error('Network host did not become ready.');
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  for (let i = 1; i < count; i++) peers.push(launch(`network-${count}-client-${i}`, engine, args, 30_000).promise);
  const outputs = await Promise.all(peers);
  if (!outputs.every(output => /result=PASS/.test(output))) throw new Error('Missing network pass marker.');
}
let sourceDigest, failure;
try {
  if (process.platform !== 'win32') throw new Error('This pipeline targets Windows; use the windows-2022 Actions runner.');
  await powershell('setup-runtime', 'tools/setup-runtime.ps1', [], 600_000);
  await powershell('setup-web-templates', 'tools/setup-web-templates.ps1', [], 1200_000);
  await run('import', engine, [...godotArgs, '--editor', '--import', '--quit']);
  sourceDigest = await fingerprint();
  const output = await run('runtime', engine, [...godotArgs, '--script', 'res://tools/validate-runtime.gd', '--', '--silent', '--automation']);
  if (!/RUNTIME VALIDATION: \d+ checks; 0 failures/.test(output)) throw new Error('Missing runtime validation pass marker.');
  await network(2);
  await network(4);
  await mkdir('build/web', { recursive: true });
  await run('export-web', engine, [...godotArgs, '--export-release', 'Web QA']);
  await run('browser-playthrough', process.execPath, ['node_modules/@playwright/test/cli.js', 'test'], 360_000);
  if (release) {
    await powershell('export-windows', 'tools/export-windows.ps1', [], 900_000);
    // Never launch the EXE graphically: the package itself runs its smoke check headless.
    const exe = path.join(root, 'build/Undead-Survivor-Godot.exe');
    const smoke = await run('packaged-exe', exe, ['--headless', '--audio-driver', 'Dummy', '--', '--automation', '--silent', '--qa-native-smoke'], 60_000);
    if (!smoke.includes('PACKAGED EXE SMOKE: PASS')) throw new Error('Missing packaged EXE pass marker.');
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
    boundaries: ['Web gameplay runs with actual browser input and read-only telemetry.', 'Screenshots validate rendered output; they do not establish subjective feel parity.', 'Windows EXE smoke uses the headless driver, not a graphical desktop.', 'Cross-account Steam matchmaking is not verified by ENet or the EXE smoke check.'] };
  await writeFile('artifacts/acceptance.json', JSON.stringify(report, null, 2));
  await writeFile('artifacts/acceptance.md', `# 自动验收：${report.status}\n\n提交：${report.commit}\n\n源码 SHA-256：${sourceDigest ?? '未完成导入'}\n\n| 阶段 | 结果 | 耗时 |\n| --- | --- | --- |\n${stages.map(s => `| ${s.name} | ${s.passed ? '通过' : '失败'} | ${s.seconds.toFixed(1)}s |`).join('\n')}\n\n${report.boundaries.map(b => '- ' + b).join('\n')}\n${failure ? '\n```text\n' + failure + '\n```\n' : ''}`);
  process.exitCode = failure ? 1 : 0;
}
