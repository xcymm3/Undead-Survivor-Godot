import { cp, mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawn, execFileSync } from 'node:child_process';
import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from '@playwright/test';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const stage = path.join(root, 'build/trailer-source');
const output = path.join(root, 'artifacts/trailer');
const source = path.join(root, 'tools/trailer');
const width = 1600, height = 670, fps = 24;
const shots = { horde: 5, rifle: 9, axe: 7, boss: 8, armory: 3, finale: 8 };
await mkdir(output, { recursive: true });

async function run(args, label) {
  const child = spawn(path.join(root, '.runtime/Godot_v4.5.2-stable_win64_console.exe'),
    ['--headless', '--audio-driver', 'Dummy', '--path', stage, ...args],
    { cwd: stage, windowsHide: true, shell: false, stdio: ['ignore', 'pipe', 'pipe'] });
  let log = '';
  child.stdout.on('data', value => log += value);
  child.stderr.on('data', value => log += value);
  const code = await new Promise((resolve, reject) => { child.on('error', reject); child.on('close', resolve); });
  await writeFile(path.join(output, label + '.log'), log);
  if (code || /^(?:SCRIPT ERROR|ERROR):/m.test(log)) throw new Error(log.slice(-5000));
  console.log(label + ': PASS');
}

if (process.argv.includes('--prepare')) {
  await mkdir(stage, { recursive: true });
  for (const name of ['assets', 'scripts', 'scenes', 'project.godot', 'export_presets.cfg', 'icon.svg'])
    await cp(path.join(root, name), path.join(stage, name), { recursive: true });
  await mkdir(path.join(stage, 'tools'), { recursive: true });
  await cp(path.join(root, 'tools/web-shell.html'), path.join(stage, 'tools/web-shell.html'));
  await cp(path.join(root, '.godot/imported'), path.join(stage, '.godot/imported'), { recursive: true });
  let project = await readFile(path.join(stage, 'project.godot'), 'utf8');
  project = project.replace('viewport_width=1440', 'viewport_width=' + width).replace('viewport_height=900', 'viewport_height=' + height);
  await writeFile(path.join(stage, 'project.godot'), project);
  let presets = await readFile(path.join(stage, 'export_presets.cfg'), 'utf8');
  presets = presets.replaceAll('res://.runtime/templates/', root.replaceAll('\\', '/') + '/.runtime/templates/');
  // Keep production-only promotional scripts out of all exported game builds.
  presets = presets.replaceAll('docs/*,tools/*,', 'docs/*,tools/*,marketing/*,');
  await writeFile(path.join(stage, 'export_presets.cfg'), presets);
  await cp(path.join(source, 'capture_scene.gd'), path.join(stage, 'scripts/trailer_scene.gd'));
  let observer = await readFile(path.join(stage, 'scripts/automation_observer.gd'), 'utf8');
  observer = observer.replace('func _ready() -> void:', 'func _ready() -> void:\n\tvar trailer = preload("res://scripts/trailer_scene.gd").new()\n\ttrailer.game = game\n\tadd_child(trailer)\n\tset_process(false)\n\treturn');
  await writeFile(path.join(stage, 'scripts/automation_observer.gd'), observer);
  await mkdir(path.join(stage, 'build/web'), { recursive: true });
  await run(['--editor', '--import', '--quit'], 'import');
  await run(['--export-release', 'Web QA'], 'export');
  await writeFile(path.join(output, 'source.json'), JSON.stringify({
    commit: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, windowsHide: true, encoding: 'utf8' }).trim(),
    environment: 'isolated source copy / Godot Web Compatibility / headless Chromium / SwiftShader',
    nativeResolution: [width, height], fps, shots,
    staging: 'Scripted cameras, enemy placement, slow approach speeds, protected player and temporary rifle magazine level 5. Native simulation damage, axe sweep, enemy poses and 26-unit boss summoning.',
  }, null, 2));
}

if (process.argv.includes('--preview') || process.argv.includes('--capture')) {
  const webroot = path.join(stage, 'build/web');
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
  const server = createServer((request, response) => {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    const file = path.resolve(webroot, '.' + (pathname === '/' ? '/index.html' : pathname));
    if (!file.startsWith(webroot + path.sep)) { response.writeHead(403).end(); return; }
    const stream = createReadStream(file);
    stream.on('error', () => { response.writeHead(404).end(); });
    response.setHeader('Content-Type', types[path.extname(file)] ?? 'application/octet-stream');
    stream.pipe(response);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const browser = await chromium.launch({ headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--mute-audio', '--disable-background-timer-throttling'] });
  try {
    const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: 1 });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
    await page.goto('http://127.0.0.1:' + server.address().port);
    await page.waitForFunction(() => window.__trailerReady, null, { timeout: 120_000 });
    const records = [];
    const preview = process.argv.includes('--preview');
    const requested = process.argv.find(arg => arg.startsWith('--shot='))?.slice(7);
    for (const [shot, seconds] of Object.entries(shots)) {
      if (requested && shot !== requested) continue;
      const dir = path.join(output, 'frames', shot);
      await mkdir(dir, { recursive: true });
      const frames = preview ? [0, Math.round(seconds * fps * .5)] : Array.from({ length: Math.round(seconds * fps) }, (_, i) => i);
      const start = Date.now();
      for (const frame of frames) {
        await page.evaluate(command => { window.__trailerCommand = command; }, { shot, frame });
        await page.waitForFunction(({ shot, frame }) => window.__trailerFrame?.shot === shot && window.__trailerFrame?.frame === frame, { shot, frame }, { timeout: 90_000, polling: 50 });
        const report = await page.evaluate(() => window.__trailerFrame);
        records.push(report);
        await page.screenshot({ path: preview ? path.join(output, shot + '-' + frame + '.png') : path.join(dir, String(frame).padStart(5, '0') + '.jpg'), type: preview ? 'png' : 'jpeg', quality: preview ? undefined : 96 });
        if (frame % fps === 0) console.log(`${shot}: ${frame}/${Math.round(seconds * fps)} frames, ${(Date.now() - start) / 1000}s`);
      }
      console.log(`${shot}: captured in ${((Date.now() - start) / 1000).toFixed(1)}s`);
    }
    const safety = await page.evaluate(() => window.__qaSafety);
    if (safety.pointerLockRequests || safety.fullscreenRequests || errors.length) throw new Error(JSON.stringify({ safety, errors }));
    const report = { safety, errors, records };
    await writeFile(path.join(output, requested ? 'capture-' + requested + '.json' : preview ? 'preview.json' : 'capture.json'), JSON.stringify(report, null, 2));
    if (requested && !preview) {
      try {
        const previous = JSON.parse(await readFile(path.join(output, 'capture.json'), 'utf8'));
        previous.records = previous.records.filter(record => record.shot !== requested).concat(records);
        previous.safety = safety;
        previous.errors = errors;
        await writeFile(path.join(output, 'capture.json'), JSON.stringify(previous, null, 2));
      } catch (error) { if (error.code !== 'ENOENT') throw error; }
    }
  } finally {
    await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
}
