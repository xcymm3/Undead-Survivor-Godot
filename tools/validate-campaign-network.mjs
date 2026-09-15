import { spawn, execFileSync } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

const count = Number(process.argv[2] ?? 2);
if (![2, 4].includes(count)) throw new Error('Expected two or four players');
const night = process.argv.includes('--night');
const prefix = night ? 'night-enet' : 'campaign-enet';
const root = process.cwd();
const engine = path.join(root, '.runtime/Godot_v4.5.2-stable_win64_console.exe');
const args = ['--headless', '--audio-driver', 'Dummy', '--path', root, '--script', 'res://tools/validate-campaign-network.gd', '--', '--automation', '--silent', ...(night ? ['--night', '--map=graypine_night'] : ['--map=graypine_ferry']), ...(count === 4 ? ['--four'] : [])];
const children = new Set();
await mkdir('artifacts', { recursive: true });
function stop(child) {
  if (child.exitCode !== null || !child.pid) return;
  try { execFileSync('taskkill.exe', ['/PID', String(child.pid), '/T', '/F'], { windowsHide: true, stdio: 'ignore' }); } catch {}
}
function launch(role) {
  let output = '';
  const child = spawn(engine, ['--log-file', path.join(root, `artifacts/${prefix}-${count}-${role}-live.log`), ...args, ...(role === 'host' ? ['--host'] : [])], { windowsHide: true, cwd: root });
  children.add(child);
  const timer = setTimeout(() => stop(child), 930_000);
  child.stdout.on('data', data => { output += data; });
  child.stderr.on('data', data => { output += data; });
  const promise = new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('close', async code => {
      clearTimeout(timer);
      children.delete(child);
      await writeFile(`artifacts/${prefix}-${count}-${role}.log`, output);
      if (code !== 0 || !output.includes('CAMPAIGN NETWORK FULL: PASS') || /^(?:SCRIPT ERROR|ERROR):/m.test(output)) reject(new Error(`${role} failed (${code}):\n${output.slice(-4500)}`));
      else { console.log(output.trim()); resolve(); }
    });
  });
  promise.catch(() => {});
  return { child, promise, output: () => output };
}
try {
  const host = launch('host');
  const deadline = Date.now() + 25_000;
  while (!host.output().includes('CAMPAIGN NETWORK READY')) {
    if (Date.now() > deadline || host.child.exitCode !== null) throw new Error('Campaign host did not become ready: ' + host.output());
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  const peers = [host.promise];
  for (let i = 1; i < count; i++) peers.push(launch(`client-${i}`).promise);
  await Promise.all(peers);
  console.log(`FULL CAMPAIGN ENET ${count}: PASS`);
} finally {
  for (const child of children) stop(child);
}
