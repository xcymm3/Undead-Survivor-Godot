import { spawn, execFileSync } from 'node:child_process';
import { readFile, writeFile, mkdir, mkdtemp, cp } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { tmpdir, cpus, totalmem, release, arch } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const outputDir = path.join(root, 'artifacts', process.argv.includes('--pilot') ? 'enemy-cpu-pilot' : process.argv.includes('--control') ? 'enemy-cpu-control' : 'enemy-cpu-profile');
const git = args => execFileSync('git', args, { cwd: root, encoding: 'utf8', windowsHide: true }).trim();
const names = [...new Set(git(['ls-files', '-co', '--exclude-standard', '-z']).split('\0').filter(Boolean))].sort();
const snapshot = await mkdtemp(path.join(tmpdir(), 'undead-enemy-cpu-'));
await mkdir(outputDir, { recursive: true });
const hash = createHash('sha256');
const manifest = [];
for (const name of names) {
  let contents;
  try { contents = await readFile(path.join(root, name)); }
  catch (error) { if (error.code === 'ENOENT') continue; throw error; }
  hash.update(name + '\0'); hash.update(contents);
  manifest.push({ path: name, sha256: createHash('sha256').update(contents).digest('hex') });
  const target = path.join(snapshot, name);
  await mkdir(path.dirname(target), { recursive: true });
  await writeFile(target, contents);
}
const sourceDigest = hash.digest('hex');
// Imported resource cache is validated by Godot; no gameplay source is taken from it.
try { await cp(path.join(root, '.godot', 'imported'), path.join(snapshot, '.godot', 'imported'), { recursive: true }); }
catch (error) { if (error.code !== 'ENOENT') throw error; }
const metadata = { startedAt: new Date().toISOString(), head: git(['rev-parse', 'HEAD']), branch: git(['branch', '--show-current']), workingTree: git(['status', '--short']), sourceDigest, snapshot, manifest, environment:{cpu:cpus()[0]?.model,logicalCpus:cpus().length,memoryBytes:totalmem(),osRelease:release(),arch:arch(),node:process.version} };
await writeFile(path.join(outputDir, 'source-manifest.json'), JSON.stringify(metadata, null, 2));
console.log(`Frozen source ${sourceDigest}; snapshot ${snapshot}`);
const godot = path.join(root, '.runtime', 'Godot_v4.5.2-stable_win64_console.exe');
async function launch(name, args, timeoutMs) {
  const child = spawn(godot, ['--headless', '--audio-driver', 'Dummy', '--path', snapshot, ...args], { cwd: snapshot, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  let output = '';
  const append = data => { output += data; if (name !== 'import') process.stdout.write(data); };
  child.stdout.on('data', append); child.stderr.on('data', append);
  const timer = setTimeout(() => { child.kill(); }, timeoutMs);
  const code = await new Promise((resolve, reject) => { child.on('error', reject); child.on('close', resolve); }).finally(() => clearTimeout(timer));
  await writeFile(path.join(outputDir, `${name}.log`), output);
  if (code !== 0 || /^(SCRIPT ERROR|ERROR):/m.test(output)) throw new Error(`${name} failed (${code}); see ${outputDir}\n${output.slice(-3000)}`);
}
await launch('import', ['--editor', '--import', '--quit'], 180000);
const pilot = process.argv.includes('--pilot');
const profileArgs = pilot ? ['--counts=50', '--warmup=30', '--samples=60', '--rounds=1'] : ['--warmup=120', '--samples=300', '--rounds=2'];
profileArgs.push(...process.argv.slice(2).filter(arg => /^--(counts|scenarios|warmup|samples|rounds)=/.test(arg)));
if (process.argv.includes('--control')) profileArgs.push('--unprofiled');
await launch('profile', ['--script', 'res://tools/profile-enemy-cpu.gd', '--', '--automation', '--silent', ...profileArgs], 1800000);
const result = JSON.parse(await readFile(path.join(snapshot, 'artifacts', 'enemy-cpu-profile.json'), 'utf8'));
result.source = metadata;
result.finishedAt = new Date().toISOString();
await writeFile(path.join(outputDir, 'results.json'), JSON.stringify(result, null, 2));
console.log(`CPU profile saved: ${path.join(outputDir, 'results.json')}`);
// Preserve the frozen project for reproducibility; never delete user directories.
