import { spawn } from 'node:child_process';
import { copyFile, mkdir, mkdtemp, readdir, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';

// Test the actual download alone, with spaces/Unicode in paths and concurrent launches.
const root = await mkdtemp(path.join(os.tmpdir(), 'Undead-single-exe-'));
const download = path.join(root, '仅下载 EXE');
const temporary = path.join(root, '运行 临时目录');
const args = ['--headless', '--audio-driver', 'Dummy', '--', '--automation', '--silent', '--qa-native-smoke'];
try {
  await mkdir(download);
  await mkdir(temporary);
  const exe = path.join(download, 'Undead-Survivor-Godot.exe');
  await copyFile('build/Undead-Survivor-Godot.exe', exe);
  const check = () => new Promise((resolve, reject) => {
    const child = spawn(exe, args, { cwd: download, windowsHide: true, env: { ...process.env, TEMP: temporary, TMP: temporary } });
    let output = '', timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      // Only this test's process tree.
      spawn('taskkill.exe', ['/PID', String(child.pid), '/T', '/F'], { windowsHide: true, stdio: 'ignore' });
    }, 60_000);
    child.stdout.on('data', data => { output += data; });
    child.stderr.on('data', data => { output += data; });
    child.once('error', error => { clearTimeout(timer); reject(error); });
    child.once('close', code => {
      clearTimeout(timer);
      if (code !== 0 || timedOut || !output.includes('PACKAGED EXE SMOKE: PASS') || /^(?:SCRIPT ERROR|ERROR):/m.test(output))
        reject(new Error(`Single EXE failed (${code}):\n${output}`));
      else resolve();
    });
  });
  const results = await Promise.allSettled([check(), check()]);
  for (const result of results) if (result.status === 'rejected') throw result.reason;
  assert.deepEqual(await readdir(download), ['Undead-Survivor-Godot.exe'], 'Download directory must remain a single EXE');
  assert.deepEqual(await readdir(path.join(temporary, 'Undead-Survivor-Godot')), [], 'Extraction directories must be cleaned after exit');
  console.log('SINGLE EXE: PASS (isolated download, Unicode/spaces, two concurrent headless games, output forwarding, cleanup)');
} finally {
  await rm(root, { recursive: true, force: true });
}
