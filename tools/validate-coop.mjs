import { spawn } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

await mkdir('artifacts', { recursive: true });
const engine = path.resolve('.runtime/Godot_v4.5.2-stable_win64_console.exe');
const address = `127.0.0.1:${40000 + Math.floor(Math.random() * 20000)}`;
const children = [];
function launch(role) {
  const child = spawn(engine, ['--headless', '--audio-driver', 'Dummy', '--path', process.cwd(), '--script', 'res://tools/validate-coop.gd', '--', '--automation', '--silent', `--coop-role=${role}`, `--coop-address=${address}`], { windowsHide: true });
  children.push(child);
  let output = '';
  let announce;
  const ready = new Promise(resolve => { announce = resolve; });
  child.stdout.on('data', data => { output += data; if (output.includes('COOP HOST READY')) announce(); });
  child.stderr.on('data', data => { output += data; });
  const done = new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('exit', async code => {
      await writeFile(`artifacts/coop-${role}.log`, output);
      if (code === 0 && !/^(SCRIPT ERROR|ERROR):/m.test(output) && /COOP (HOST|CLIENT): \d+ checks; 0 failures/.test(output)) resolve(output.trim().split('\n').at(-1));
      else reject(new Error(`${role} failed (${code}):\n${output}`));
    });
  });
  done.catch(() => {});
  return { ready, done };
}
const timer = setTimeout(() => { for (const child of children) child.kill(); }, 90_000);
try {
  const host = launch('host');
  await Promise.race([host.ready, host.done.then(() => { throw new Error('Host exited before opening its server'); })]);
  const client = launch('client');
  const results = await Promise.allSettled([host.done, client.done]);
  for (const result of results) {
    if (result.status === 'fulfilled') console.log(result.value);
    else console.error(String(result.reason));
  }
  if (results.some(result => result.status === 'rejected')) process.exitCode = 1;
} finally {
  clearTimeout(timer);
  for (const child of children) if (child.exitCode === null) child.kill();
}
