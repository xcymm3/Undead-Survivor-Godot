import { execFileSync, spawn } from 'node:child_process';
import { mkdir, readFile, writeFile, cp } from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import os from 'node:os';
import { chromium } from '@playwright/test';

const root = process.cwd();
const output = path.resolve('artifacts/render-performance');
await mkdir(output, { recursive: true });
const base = process.env.PERF_BASE_REF ?? '9ea4837fa5a0c5ebe24fb85e89bf3a2749879d8b';
const git = args => execFileSync('git', args, { encoding: 'utf8', windowsHide: true }).trim();
const engine = path.resolve('.runtime/Godot_v4.5.2-stable_win64_console.exe');
const helper = await readFile('scripts/qa_render_performance.gd', 'utf8');
const versions = { baseline: git(['rev-parse', base]), optimized: git(['rev-parse', 'HEAD']) };
const manifest = { versions, fixtureSha256: createHash('sha256').update(helper).digest('hex'), renderer: 'headless Chromium / SwiftShader', samples: [] };
manifest.machine = { platform: os.platform(), release: os.release(), cpu: os.cpus()[0]?.model, logicalCpus: os.cpus().length, memoryBytes: os.totalmem() };
const run = (exe, args, cwd = root) => new Promise((resolve, reject) => {
  const child = spawn(exe, args, { cwd, windowsHide: true, shell: false });
  let log = '';
  child.stdout.on('data', chunk => log += chunk);
  child.stderr.on('data', chunk => log += chunk);
  child.once('error', reject);
  child.once('close', code => code === 0 && !/^(SCRIPT ERROR|ERROR):/m.test(log) ? resolve(log) : reject(new Error(log.slice(-6000))));
});
for (const [name, sha] of Object.entries(versions)) {
  const folder = path.join(output, 'sources', name);
  await mkdir(folder, { recursive: true });
  const archive = path.join(output, `${name}.zip`);
  execFileSync('git', ['archive', '--format=zip', '-o', archive, sha], { windowsHide: true });
  manifest[`${name}ArchiveSha256`] = createHash('sha256').update(await readFile(archive)).digest('hex');
  await run('python', ['-c', 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])', archive, folder]);
  await cp('.runtime/templates', path.join(folder, '.runtime/templates'), { recursive: true });
  await writeFile(path.join(folder, 'scripts/qa_render_performance.gd'), helper);
  const observerPath = path.join(folder, 'scripts/automation_observer.gd');
  let observer = await readFile(observerPath, 'utf8');
  observer = observer.replace('func _ready() -> void:\n', 'func _ready() -> void:\n\tif "--qa-render-performance" in OS.get_cmdline_user_args():\n\t\tvar fixture = load("res://scripts/qa_render_performance.gd").new()\n\t\tfixture.game = game\n\t\tadd_child(fixture)\n');
  await writeFile(observerPath, observer);
  const shellPath = path.join(folder, 'tools/web-shell.html');
  const shell = (await readFile(shellPath, 'utf8')).replace("const qaArgs = ['--', '--automation', '--silent'];", "const qaArgs = ['--', '--automation', '--silent', '--qa-render-performance'];");
  await writeFile(shellPath, shell);
  await run(engine, ['--headless', '--audio-driver', 'Dummy', '--path', folder, '--editor', '--import', '--quit']);
  const destination = path.resolve('build/web', name, 'index.html');
  await mkdir(path.dirname(destination), { recursive: true });
  await writeFile(path.join(output, `${name}-export.log`), await run(engine, ['--headless', '--audio-driver', 'Dummy', '--path', folder, '--export-release', 'Web QA', destination]));
}
await writeFile(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2));
const server = spawn(process.execPath, ['tools/serve-web.mjs'], { windowsHide: true, stdio: 'ignore', env: { ...process.env, QA_WEB_PORT: '4187' } });
let browser;
try {
  for (let i = 0; i < 60; i++) {
    try { if ((await fetch('http://127.0.0.1:4187/baseline/index.html')).ok) break; } catch { }
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  browser = await chromium.launch({ headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--mute-audio'] });
  manifest.browser = browser.version();
  let token = 0;
  const errors = [];
  for (let round = 0; round < 3; round++) {
    for (const name of (round % 2 ? ['optimized', 'baseline'] : ['baseline', 'optimized'])) {
      const context = await browser.newContext({ viewport: { width: 960, height: 600 } });
      const page = await context.newPage();
      page.on('pageerror', error => errors.push(String(error)));
      page.on('console', message => { if (/^(SCRIPT ERROR|ERROR):/.test(message.text())) errors.push(message.text()); });
      await page.goto(`http://127.0.0.1:4187/${name}/index.html`);
      await page.waitForFunction(() => window.__renderPerfReady, null, { timeout: 180000 });
      manifest.webglRenderer = await page.evaluate(() => {
        const gl = document.getElementById('canvas').getContext('webgl2');
        const info = gl.getExtension('WEBGL_debug_renderer_info');
        return gl.getParameter(info ? info.UNMASKED_RENDERER_WEBGL : gl.RENDERER);
      });
      for (const scenario of ['bedroom', 'shop', 'outside', 'battle100']) {
        for (let frame = -3; frame < 8; frame++) {
          const current = ++token;
          await page.evaluate(([scenario, token]) => window.__renderPerfRun(scenario, token), [scenario, current]);
          await page.waitForFunction(token => window.__renderPerfResult?.token === token, current, { timeout: 90000 });
          if (frame >= 0) manifest.samples.push({ variant: name, round, ...await page.evaluate(() => window.__renderPerfResult) });
        }
        await writeFile(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2));
        console.log(`${name} round ${round + 1}: ${scenario}`);
      }
      const safety = await page.evaluate(() => window.__qaSafety);
      if (safety.pointerLockRequests || safety.fullscreenRequests) throw new Error('Unexpected pointer/fullscreen request');
      await context.close();
    }
  }
  if (errors.length) throw new Error(errors.join('\n'));
  const percentile = (values, q) => [...values].sort((a, b) => a - b)[Math.ceil(values.length * q) - 1];
  manifest.summary = {};
  for (const scenario of ['bedroom', 'shop', 'outside', 'battle100']) {
    manifest.summary[scenario] = {};
    for (const variant of Object.keys(versions)) {
      const samples = manifest.samples.filter(row => row.scenario === scenario && row.variant === variant);
      manifest.summary[scenario][variant] = { samples: samples.length, p50_ms: percentile(samples.map(row => row.total_ms), .5), p95_ms: percentile(samples.map(row => row.total_ms), .95), draw_calls: percentile(samples.map(row => row.draw_calls), .5), cpu_p50_ms: percentile(samples.map(row => row.cpu_ms), .5), draw_finish_p50_ms: percentile(samples.map(row => row.draw_finish_ms), .5), shadow_lights: samples[0].shadow_lights, batches: samples[0].batches };
    }
  }
  manifest.status = 'passed';
  console.log(JSON.stringify(manifest.summary));
} finally {
  await writeFile(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2));
  if (browser) await browser.close();
  server.kill();
}
