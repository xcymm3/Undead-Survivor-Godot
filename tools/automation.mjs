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
  ? (release ? [] : ['windows-export-and-package'])
  : [
      'night-campaign', 'crystal-defense', 'spread-ballistics', 'night-full-enet-2',
      'export-web', 'browser-playthrough', 'windows-export-and-package',
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

function browserSpecs(suites) {
  return suites.flatMap(suite => [...(suite.specs ?? []), ...browserSpecs(suite.suites ?? [])]);
}

function gameplayObservation(browser) {
  const spec = browserSpecs(browser.suites ?? []).find(item => item.title.includes('精确自动瞄准'));
  const attachment = spec?.tests?.[0]?.results?.[0]?.attachments?.find(item => item.name === 'defense-playthrough.json');
  if (!attachment?.body) return { name: '水晶防线单人自动试玩', result: '未取得结果' };
  try {
    const { result } = JSON.parse(Buffer.from(attachment.body, 'base64').toString('utf8'));
    const player = result.player ?? {};
    const defense = result.defense ?? {};
    const accuracy = player.shots > 0 ? `${(player.hits * 100 / player.shots).toFixed(1)}%` : '0.0%';
    return {
      name: '水晶防线单人自动试玩',
      result: result.won ? '胜利' : result.failed ? `失败（${result.cause}）` : '未完成',
      wave: result.wave,
      cleared: result.cleared,
      elapsed: result.elapsed,
      kills: result.kills,
      playerHp: player.hp,
      crystalHp: defense.crystal_hp,
      crystalMaxHp: defense.crystal_max_hp,
      shots: player.shots,
      hits: player.hits,
      accuracy,
    };
  } catch {
    return { name: '水晶防线单人自动试玩', result: '结果解析失败' };
  }
}

function gameplayMarkdown(observation) {
  if (!observation) return '';
  if (observation.wave === undefined) return `## 玩法观察\n\n- ${observation.name}：${observation.result}`;
  return `## 玩法观察\n\n- ${observation.name}：${observation.result}；第 ${observation.wave} 波，完成 ${observation.cleared} 波；用时 ${Number(observation.elapsed).toFixed(1)} 秒；击杀 ${observation.kills}；玩家 ${observation.playerHp} HP；水晶 ${observation.crystalHp}/${observation.crystalMaxHp} HP；命中 ${observation.hits}/${observation.shots}（${observation.accuracy}）`;
}

const run = (name, command, args, timeout) => launch(name, command, args, timeout);
const powershell = (name, script, args = [], timeout = 180_000) =>
  run(name, 'pwsh.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script, ...args], timeout);
const engine = path.join(root, '.runtime/Godot_v4.5.2-stable_win64_console.exe');
const godotArgs = ['--headless', '--audio-driver', 'Dummy', '--path', root];
let sourceDigest;
let failure;
let observation;

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
    const night = await run('night-campaign', engine, [...godotArgs, '--script', 'res://tools/validate-night.gd', '--', '--silent', '--automation'], 900_000);
    if (!/NIGHT VALIDATION: \d+ checks; 0 failures/.test(night)) throw new Error('Missing night campaign check marker.');
    const defense = await run('crystal-defense', engine, [...godotArgs, '--script', 'res://tools/validate-defense.gd', '--', '--silent', '--automation'], 300_000);
    if (!/DEFENSE VALIDATION: \d+ checks; 0 failures/.test(defense)) throw new Error('Missing crystal defense check marker.');
    await run('spread-ballistics', engine, [...godotArgs, '--script', 'res://tools/validate-spread-ballistics.gd', '--', '--silent', '--automation'], 300_000);
    await run('night-full-enet-2', process.execPath, ['tools/validate-campaign-network.mjs', '2'], 960_000);
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
    await run('browser-playthrough', process.execPath, ['node_modules/@playwright/test/cli.js', 'test'], 900_000);
    const browser = JSON.parse(await readFile('artifacts/browser-results.json', 'utf8'));
    if (browser.stats.unexpected || browser.stats.flaky || browser.stats.skipped || browser.errors?.length || browser.stats.expected !== 7) {
      throw new Error('Browser suite must complete all seven retained tests without failures, skips, or retries.');
    }
    observation = gameplayObservation(browser);
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
    ? ['本次为全量测试：包含夜路与水晶防守、弹道、ENet 双人、Web 导出和六项浏览器检查。', '原生 GPU、真人体验和 Steam 双账号联网仍不在自动测试范围内。']
    : ['本次为基础测试：仅检查版本、资源导入和原生组件。整关、联网、Web、浏览器、视觉与发布项目未执行，也不计为通过。'];
  if (release) boundaries.push('本次包含 Windows 导出、无窗口 EXE 冒烟和 ZIP 打包。');
  const report = {
    status: failure ? 'failed' : 'passed', startedAt, finishedAt: new Date().toISOString(),
    commit: git(['rev-parse', 'HEAD']), sourceDigest, release, profile, excluded, stages, failure, boundaries,
  };
  if (observation) report.gameplayObservation = observation;
  report.seconds = (Date.parse(report.finishedAt) - Date.parse(startedAt)) / 1000;
  await writeFile('artifacts/acceptance.json', JSON.stringify(report, null, 2));
  await writeFile('artifacts/acceptance.md', `# 自动检查：${report.status}\n\n配置：${profile}；总耗时：${report.seconds.toFixed(1)}s\n\n提交：${report.commit}\n\n源码 SHA-256：${sourceDigest ?? '未完成导入'}\n\n| 阶段 | 结果 | 耗时 |\n| --- | --- | --- |\n${stages.map(s => `| ${s.name} | ${s.passed ? '通过' : '失败'} | ${s.seconds.toFixed(1)}s |`).join('\n')}\n\n${gameplayMarkdown(observation)}\n\n${boundaries.map(item => '- ' + item).join('\n')}\n\n本配置未运行：${excluded.join(', ') || '无'}\n${failure ? '\n```text\n' + failure + '\n```\n' : ''}`);
  process.exitCode = failure ? 1 : 0;
}
