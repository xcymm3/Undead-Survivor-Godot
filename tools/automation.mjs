import { spawn, execFileSync } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer } from 'node:net';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
process.chdir(root);
const release = process.argv.includes('--release');
// Packaging an EXE always requires the full suite. Otherwise full testing is opt-in.
const full = release || process.argv.includes('--full');
const profile = full ? 'full' : 'basic';
const excluded = full
  ? [
      'night-scripted-playthrough', 'night-full-enet-2',
      'browser-night-playthrough', 'browser-defense-playthrough',
      ...(release ? [] : ['windows-export-and-package']),
    ]
  : [
      'crystal-defense', 'spread-ballistics', 'export-web', 'browser-technical',
      'night-scripted-playthrough', 'night-full-enet-2',
      'browser-night-playthrough', 'browser-defense-playthrough',
      'windows-export-and-package',
    ];
const children = new Set();
const stages = [];
const startedAt = new Date().toISOString();
const git = args => execFileSync('git', args, { encoding: 'utf8', windowsHide: true }).trim();

function stop(child) {
  if (!child.pid || child.exitCode !== null) return;
  if (process.platform === 'win32') {
    try { execFileSync('taskkill.exe', ['/PID', String(child.pid), '/T', '/F'], { windowsHide: true, stdio: 'ignore' }); } catch { }
  } else child.kill();
}

async function fingerprint() {
  const names = [...new Set(git(['ls-files', '-co', '--exclude-standard', '-z']).split('\0').filter(Boolean))].sort();
  const hash = createHash('sha256');
  for (const name of names) {
    try {
      const contents = await readFile(name);
      hash.update(name + '\0');
      hash.update(contents);
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
  return hash.digest('hex');
}

if (process.argv.includes('--check-report')) {
  const report = JSON.parse(await readFile('artifacts/acceptance.json', 'utf8'));
  if (report.status !== 'passed' || report.sourceDigest !== await fingerprint()) {
    throw new Error('Verification report failed or is stale. Run npm run verify again before submitting.');
  }
  console.log(`Verification gate: PASS (${report.profile ?? 'legacy'}), exact current source tree verified.`);
  process.exit(0);
}

await import('./postinstall.mjs');

function launch(name, command, args, timeout = 180_000) {
  console.log(`START ${name}`);
  const start = Date.now();
  const child = spawn(command, args, {
    cwd: root,
    windowsHide: true,
    shell: false,
    env: { ...process.env, PWDEBUG: '0', PLAYWRIGHT_HTML_OPEN: 'never' },
  });
  children.add(child);
  let output = '';
  let timedOut = false;
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
  promise.catch(() => {});
  return promise;
}

const run = (name, command, args, timeout) => launch(name, command, args, timeout);
const powershell = (name, script, args = [], timeout = 180_000) =>
  run(name, 'pwsh.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, ...args], timeout);
const engine = path.join(root, '.runtime/Godot_v4.5.2-stable_win64_console.exe');
const godotArgs = ['--headless', '--audio-driver', 'Dummy', '--path', root];
let sourceDigest;
let failure;

try {
  if (process.platform !== 'win32') throw new Error('This pipeline targets Windows; use the windows-2022 Actions runner.');
  await run('version', process.execPath, ['tools/version.mjs', '--check']);
  await powershell('setup-runtime', 'tools/setup-runtime.ps1', [], 600_000);
  if (full) await powershell('setup-web-templates', 'tools/setup-web-templates.ps1', [], 1200_000);
  await run('import', engine, [...godotArgs, '--editor', '--import', '--quit']);
  sourceDigest = await fingerprint();
  const native = await run('native-components', engine, [...godotArgs, '--script', 'res://tools/validate-native-components.gd', '--', '--silent', '--automation']);
  if (!/NATIVE COMPONENTS: \d+ checks; 0 failures/.test(native)) throw new Error('Missing native component check marker.');

  if (full) {
    const defense = await run('crystal-defense', engine, [...godotArgs, '--script', 'res://tools/validate-defense.gd', '--', '--silent', '--automation'], 300_000);
    if (!/DEFENSE VALIDATION: \d+ checks; 0 failures/.test(defense)) throw new Error('Missing crystal defense check marker.');
    await run('spread-ballistics', engine, [...godotArgs, '--script', 'res://tools/validate-spread-ballistics.gd', '--', '--silent', '--automation'], 300_000);
    await mkdir('build/web', { recursive: true });
    await run('export-web', engine, [...godotArgs, '--export-release', 'Web QA']);
    process.env.QA_WEB_PORT = await new Promise((resolve, reject) => {
      const server = createServer();
      server.once('error', reject);
      server.listen(0, '127.0.0.1', () => {
        const port = String(server.address().port);
        server.close(error => error ? reject(error) : resolve(port));
      });
    });
    const browserGateSpecs = [
      'tests/browser/campaign.spec.mjs',
      'tests/browser/close-combat.spec.mjs',
      'tests/browser/defense-overview.spec.mjs',
      'tests/browser/defense.spec.mjs',
      'tests/browser/revolver-input.spec.mjs',
    ];
    await run('browser-technical', process.execPath, ['node_modules/@playwright/test/cli.js', 'test', ...browserGateSpecs], 900_000);
    const browser = JSON.parse(await readFile('artifacts/browser-results.json', 'utf8'));
    if (browser.stats.unexpected || browser.stats.flaky || browser.stats.skipped || browser.errors?.length || browser.stats.expected !== browserGateSpecs.length) {
      throw new Error('Browser gate must complete all five technical tests without failures, skips, or retries.');
    }
  }

  if (release) {
    await powershell('export-windows', 'tools/export-windows.ps1', [], 900_000);
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
  const boundaries = full
    ? ['本次为发布技术门禁：包含水晶防守规则、弹道、Web 导出和五项浏览器技术检查。', '所有脚本试玩及所有联机测试均为独立观察项，不参与发布通过判定；原生 GPU、真人体验和 Steam 双账号联网也不在自动门禁范围内。']
    : ['本次为基础测试：仅检查版本、资源导入和原生组件。整关、联网、Web、浏览器、视觉与发布项目未执行，也不计为通过。'];
  if (release) boundaries.push('本次包含 Windows 导出、无窗口 EXE 冒烟和 ZIP 打包。');
  const report = {
    status: failure ? 'failed' : 'passed', startedAt, finishedAt: new Date().toISOString(),
    commit: git(['rev-parse', 'HEAD']), sourceDigest, release, profile, excluded, stages, failure, boundaries,
  };
  report.seconds = (Date.parse(report.finishedAt) - Date.parse(startedAt)) / 1000;
  await writeFile('artifacts/acceptance.json', JSON.stringify(report, null, 2));
  await writeFile('artifacts/acceptance.md', `# 自动检查：${report.status}\n\n配置：${profile}；总耗时：${report.seconds.toFixed(1)}s\n\n提交：${report.commit}\n\n源码 SHA-256：${sourceDigest ?? '未完成导入'}\n\n| 阶段 | 结果 | 耗时 |\n| --- | --- | --- |\n${stages.map(s => `| ${s.name} | ${s.passed ? '通过' : '失败'} | ${s.seconds.toFixed(1)}s |`).join('\n')}\n\n${boundaries.map(item => '- ' + item).join('\n')}\n\n本配置未运行：${excluded.join(', ') || '无'}\n${failure ? '\n```text\n' + failure + '\n```\n' : ''}`);
  process.exitCode = failure ? 1 : 0;
}
