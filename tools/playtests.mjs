import { spawn, execFileSync } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { createServer } from 'node:net';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
process.chdir(root);
await import('./postinstall.mjs');
await mkdir('artifacts', { recursive: true });

const engine = path.join(root, '.runtime/Godot_v4.5.2-stable_win64_console.exe');
const godotArgs = ['--headless', '--audio-driver', 'Dummy', '--path', root];
const stages = [];
const children = new Set();
const startedAt = new Date().toISOString();

function stop(child) {
  if (!child.pid || child.exitCode !== null) return;
  if (process.platform === 'win32') {
    try { execFileSync('taskkill.exe', ['/PID', String(child.pid), '/T', '/F'], { windowsHide: true, stdio: 'ignore' }); } catch { }
  } else child.kill();
}

async function run(name, command, args, timeout = 900_000, extraEnv = {}) {
  console.log(`START ${name}`);
  const start = Date.now();
  const child = spawn(command, args, {
    cwd: root,
    windowsHide: true,
    shell: false,
    env: { ...process.env, ...extraEnv, PWDEBUG: '0', PLAYWRIGHT_HTML_OPEN: 'never' },
  });
  children.add(child);
  let output = '';
  let timedOut = false;
  const timer = setTimeout(() => { timedOut = true; stop(child); }, timeout);
  const collect = chunk => { output += chunk; };
  child.stdout.on('data', collect);
  child.stderr.on('data', collect);
  const result = await new Promise(resolve => {
    child.once('error', error => resolve({ code: -1, error }));
    child.once('close', code => resolve({ code }));
  });
  clearTimeout(timer);
  children.delete(child);
  const passed = result.code === 0 && !timedOut && !/^(?:SCRIPT ERROR|ERROR):/m.test(output);
  const stage = { name, passed, exitCode: result.code, timedOut, seconds: (Date.now() - start) / 1000, log: `playtest-${name}.log` };
  stages.push(stage);
  await writeFile(path.join('artifacts', stage.log), output);
  console.log(`${passed ? 'PASS' : 'FAIL'} ${name} (${stage.seconds.toFixed(1)}s)`);
  return passed;
}

async function freePort() {
  return new Promise((resolve, reject) => {
    const server = createServer();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const port = String(server.address().port);
      server.close(error => error ? reject(error) : resolve(port));
    });
  });
}

try {
  if (process.platform !== 'win32') throw new Error('Playtest observations currently target Windows.');
  const setupRuntime = await run('setup-runtime', 'pwsh.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'tools/setup-runtime.ps1'], 600_000);
  const setupWeb = await run('setup-web-templates', 'pwsh.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'tools/setup-web-templates.ps1'], 1_200_000);
  if (setupRuntime) await run('import', engine, [...godotArgs, '--editor', '--import', '--quit'], 180_000);
  if (setupRuntime) await run('night-scripted-playthrough', engine, [...godotArgs, '--script', 'res://tools/validate-night.gd', '--', '--silent', '--automation']);
  if (setupRuntime) await run('night-full-enet-2', process.execPath, ['tools/validate-campaign-network.mjs', '2'], 960_000);
  if (setupRuntime && setupWeb) {
    await mkdir('build/web', { recursive: true });
    const exported = await run('export-web-for-playtests', engine, [...godotArgs, '--export-release', 'Web QA'], 300_000);
    if (exported) {
      const port = await freePort();
      await run(
        'browser-scripted-playthroughs',
        process.execPath,
        ['node_modules/@playwright/test/cli.js', 'test', 'tests/browser/playthrough.spec.mjs', 'tests/browser/defense-playthrough.spec.mjs'],
        900_000,
        { QA_WEB_PORT: port },
      );
    }
  }
} catch (error) {
  stages.push({ name: 'runner', passed: false, seconds: 0, error: String(error.stack ?? error) });
} finally {
  for (const child of children) stop(child);
  const finishedAt = new Date().toISOString();
  const passed = stages.length > 0 && stages.every(stage => stage.passed);
  const report = {
    status: passed ? 'passed' : 'failed',
    startedAt,
    finishedAt,
    commit: execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8', windowsHide: true }).trim(),
    releaseGate: false,
    note: '脚本试玩与联机测试仅提供观察信息，结果不参与发布门禁。',
    stages,
  };
  await writeFile('artifacts/playtests.json', JSON.stringify(report, null, 2));
  await writeFile('artifacts/playtests.md', `# 独立试玩观察：${report.status}\n\n${report.note}\n\n| 项目 | 结果 | 耗时 |\n| --- | --- | --- |\n${stages.map(stage => `| ${stage.name} | ${stage.passed ? '通过' : '失败'} | ${Number(stage.seconds).toFixed(1)}s |`).join('\n')}\n`);
  process.exitCode = passed ? 0 : 1;
}
