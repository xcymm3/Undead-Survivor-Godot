import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

process.chdir(path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..'));
const argument = process.argv[2] ?? '--check';
const current = (await readFile('VERSION', 'utf8')).trim();
const version = argument === '--check' ? current : argument;
if (!/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(version) || version.split('.').some(n => Number(n) > 65535)) {
  throw new Error('Version must be MAJOR.MINOR.PATCH, without leading zeros; each component must fit Windows version metadata.');
}
const changes = [
  ['project.godot', /^config\/version="[^"]*"$/m, `config/version="${version}"`],
  ['export_presets.cfg', /^application\/file_version="[^"]*"$/m, `application/file_version="${version}.0"`],
  ['export_presets.cfg', /^application\/product_version="[^"]*"$/m, `application/product_version="${version}.0"`],
];
const contents = new Map();
for (const [file, pattern, replacement] of changes) {
  const original = contents.get(file) ?? await readFile(file, 'utf8');
  if (!pattern.test(original)) throw new Error(`Missing version field in ${file}`);
  const updated = original.replace(pattern, replacement);
  if (argument === '--check' && original !== updated) throw new Error(`Version mismatch in ${file}; run node tools/version.mjs ${version}`);
  contents.set(file, updated);
}
if (argument !== '--check') {
  for (const [file, contentsToWrite] of contents) await writeFile(file, contentsToWrite);
  await writeFile('VERSION', version + '\n');
}
console.log(`Version ${version}: project and Windows metadata match.`);
