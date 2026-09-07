// Rebuild native Godot assets from the sibling Three.js project's exact geometry and poses.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const source = path.resolve(process.argv[2] ?? path.join(root, '../Undead-Survivor'));
const req = createRequire(path.join(source, 'package.json'));
const ts = req('typescript');
const resolve = id => id === 'three' ? path.join(path.dirname(req.resolve('three')), 'three.module.js') : req.resolve(id);
const THREE = await import(pathToFileURL(resolve('three')));
const { FBXLoader } = await import(pathToFileURL(req.resolve('three/addons/loaders/FBXLoader.js')));
const { GLTFExporter } = await import(pathToFileURL(req.resolve('three/addons/exporters/GLTFExporter.js')));
const cache = path.join(root, 'tools/.cache'); fs.mkdirSync(cache, { recursive: true });
for (const name of ['geometry', 'terrain', 'terrainView', 'world', 'config', 'weapons', 'weapon', 'spawn', 'soundSynthesis']) {
  let code = fs.readFileSync(path.join(source, `src/game/${name}.ts`), 'utf8').replace(/\r\n/g, '\n');
  if (name === 'world') {
    const start = code.indexOf('  const canvas = document.createElement');
    const end = code.indexOf('\n}\n', start);
    code = code.slice(0, start) + `  const marker = new THREE.Object3D(); marker.position.set(x,y,z); marker.userData.sign = { text, subtitle, width }; parent.add(marker); return marker;` + code.slice(end);
  }
  code = ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText;
  code = code.replace(/from ['"](three[^'"]*)['"]/g, (_, id) => `from '${pathToFileURL(resolve(id)).href}'`)
    .replace(/from ['"]\.\/([^'"]+)['"]/g, (_, id) => `from './${id}.mjs'`);
  fs.writeFileSync(path.join(cache, name + '.mjs'), code);
}
const { createWorld } = await import(pathToFileURL(path.join(cache, 'world.mjs')));
const { WEAPONS } = await import(pathToFileURL(path.join(cache, 'weapons.mjs')));
// Godot gameplay adjustments must survive rebuilding assets from the original project.
for (const weapon of WEAPONS) {
  if (weapon.id === 'axe') weapon.range = 3.5;
  if (weapon.id === 'shotgun') Object.assign(weapon, { spread: .045, spreadVertical: .045 });
  if (weapon.id === 'auto-shotgun') Object.assign(weapon, { spread: .055, spreadVertical: .055 });
}
const config = await import(pathToFileURL(path.join(cache, 'config.mjs')));
const { prepareWeapon, prepareProceduralWeapon } = await import(pathToFileURL(path.join(cache, 'weapon.mjs')));
const audio = await import(pathToFileURL(path.join(cache, 'soundSynthesis.mjs')));
const scene = new THREE.Scene(); const world = createWorld(scene); scene.updateMatrixWorld(true);
const meshes = [], signs = [], geometries = {}, materials = {};
scene.traverse(node => {
  if (node.userData.sign) signs.push({ ...node.userData.sign, matrix: node.matrixWorld.toArray() });
  if (!(node instanceof THREE.Mesh)) return;
  const geo = node.geometry;
  if (!geometries[geo.uuid]) geometries[geo.uuid] = {
    position: Array.from(geo.attributes.position.array), normal: Array.from(geo.attributes.normal.array),
    index: geo.index ? Array.from(geo.index.array) : [],
  };
  const mat = node.material;
  materials[mat.uuid] = { color: mat.color.toArray(), roughness: mat.roughness ?? 1, unshaded: mat.isMeshBasicMaterial === true, double: mat.side === THREE.DoubleSide };
  const transforms = [], colors = [];
  if (node.isInstancedMesh) {
    for (let i = 0; i < node.count; i++) {
      const m = new THREE.Matrix4(); node.getMatrixAt(i, m); transforms.push(node.matrixWorld.clone().multiply(m).toArray());
      if (node.instanceColor) { const c = new THREE.Color(); node.getColorAt(i, c); colors.push(c.toArray()); }
    }
  } else transforms.push(node.matrixWorld.toArray());
  meshes.push({ geometry: geo.uuid, material: mat.uuid, transforms, colors, shadow: node.castShadow, name: node.name });
});
fs.writeFileSync(path.join(root, 'assets/data/world.json'), JSON.stringify({ geometries, materials, meshes, signs, obstacles: world.obstacles }));
const zombies = fs.readFileSync(path.join(source, 'src/game/zombies.ts'), 'utf8');
const partCode = zombies.slice(zombies.indexOf('const PARTS: Part[] = ') + 'const PARTS: Part[] = '.length, zombies.indexOf('\nconst SHIRTS')).replace(/;\s*$/, '');
const parts = Function('return ' + partCode)();
fs.writeFileSync(path.join(root, 'assets/data/rules.json'), JSON.stringify({ weapons: WEAPONS, enemies: config.ZOMBIE_TYPES, enemy_rules: config.ENEMY_RULES, parts }, null, 2));
globalThis.FileReader = class {
  readAsArrayBuffer(blob) { blob.arrayBuffer().then(result => { this.result = result; this.onloadend?.(); }); }
  readAsDataURL(blob) { blob.arrayBuffer().then(result => { this.result = 'data:application/octet-stream;base64,' + Buffer.from(result).toString('base64'); this.onloadend?.(); }); }
};
for (const weapon of WEAPONS) {
  const raw = weapon.procedural ? null : fs.readFileSync(path.join(source, `public/models/weapons/${weapon.model}.fbx`));
  const prepared = weapon.procedural ? prepareProceduralWeapon(weapon) : prepareWeapon(new FBXLoader().parse(raw.buffer.slice(raw.byteOffset, raw.byteOffset + raw.byteLength), ''), weapon);
  // Capture every animated local transform, including procedural parts and normalized FBX bones.
  const nodes = []; prepared.holder.traverse(n => nodes.push(n));
  const animations = [];
  for (const kind of ['fire', 'reload']) {
    const duration = kind === 'fire' ? weapon.fireDuration : Math.max(.1, weapon.reloadDuration);
    const frames = Math.ceil(duration * 30), samples = nodes.map(() => ({ position: [], quaternion: [], scale: [] })), times = [];
    for (let f = 0; f <= frames; f++) {
      times.push(f / frames * duration); prepared.sample(kind, f / frames);
      nodes.forEach((n, i) => { samples[i].position.push(...n.position.toArray()); samples[i].quaternion.push(...n.quaternion.toArray()); samples[i].scale.push(...n.scale.toArray()); });
    }
    const tracks = [];
    nodes.forEach((n, i) => { for (const prop of ['position', 'quaternion', 'scale']) {
      const T = prop === 'quaternion' ? THREE.QuaternionKeyframeTrack : THREE.VectorKeyframeTrack;
      tracks.push(new T(`${n.uuid}.${prop}`, times, samples[i][prop]));
    }});
    animations.push(new THREE.AnimationClip(kind, duration, tracks));
  }
  prepared.sample('idle');
  const wrapper = new THREE.Group(); wrapper.add(prepared.holder);
  const glb = await new GLTFExporter().parseAsync(wrapper, { binary: true, animations, onlyVisible: false });
  fs.writeFileSync(path.join(root, `assets/models/${weapon.id}.glb`), Buffer.from(glb));
  console.log('Converted', weapon.id);
}
fs.cpSync(path.join(source, 'public/models/characters'), path.join(root, 'assets/models/characters'), { recursive: true });
fs.cpSync(path.join(source, 'public/THIRD-PARTY-NOTICES.txt'), path.join(root, 'assets/THIRD-PARTY-NOTICES.txt'));
fs.cpSync(path.join(source, 'public/models/weapons/README.md'), path.join(root, 'assets/models/WEAPON-SOURCES.md'));
const sourceFiles = fs.readdirSync(path.join(source, 'src/game')).filter(name => name.endsWith('.ts'));
const hashes = Object.fromEntries(sourceFiles.map(name => [name, createHash('sha256').update(fs.readFileSync(path.join(source, 'src/game', name))).digest('hex')]));
fs.writeFileSync(path.join(root, 'assets/data/provenance.json'), JSON.stringify({
  source: 'Undead-Survivor', version: req('./package.json').version,
  revision: execFileSync('git', ['-C', source, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(),
  source_game_sha256: hashes, weapons: WEAPONS.length, enemy_parts: parts.length,
  world_geometries: Object.keys(geometries).length, world_batches: meshes.length,
}, null, 2));
function wav(name, samples, rate = 22050) {
  const b = Buffer.alloc(44 + samples.length * 2); b.write('RIFF'); b.writeUInt32LE(b.length - 8, 4); b.write('WAVEfmt ', 8);
  b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22); b.writeUInt32LE(rate, 24); b.writeUInt32LE(rate * 2, 28);
  b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(samples.length * 2, 40);
  samples.forEach((s, i) => b.writeInt16LE(Math.round(Math.max(-1, Math.min(1, s)) * 32767), 44 + i * 2));
  fs.writeFileSync(path.join(root, `assets/audio/${name}.wav`), b);
}
wav('music', audio.synthesizeMusic(22050));
for (let i = 0; i < 3; i++) wav(`death-${i}`, audio.synthesizeDeath(22050, i));
for (const kind of ['cone', 'bucket', 'shield', 'football']) for (const broken of [false, true]) wav(`${kind}-${broken}`, audio.synthesizeArmor(22050, kind, broken));
for (const kind of ['gun', 'flame', 'axe', 'reload', 'hurt', 'failure']) {
  const duration = kind === 'failure' ? 1.8 : kind === 'axe' ? .32 : .26;
  let low = 0, phase = 0;
  const samples = Float32Array.from({ length: Math.ceil(duration * 22050) }, (_, i) => {
    const t = i / 22050, p = t / duration, noise = Math.random() * 2 - 1;
    low += (noise - low) * (kind === 'flame' ? .35 : .65) * (1 - p);
    phase += (kind === 'failure' ? 140 * Math.pow(.25, p) : 140 * Math.pow(.32, p)) / 22050;
    return (low * (kind === 'reload' ? .3 : .7) + Math.sin(phase * Math.PI * 2) * .25) * Math.exp(-p * 6) * Math.min(1, t / .001);
  }); wav(kind, samples);
}
console.log('Native assets and source rules converted.');
