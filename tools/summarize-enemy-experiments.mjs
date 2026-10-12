import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { gzipSync } from 'node:zlib';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dir = path.join(root,'artifacts/enemy-experiments');
const variants = ['baseline','navigation','rays','animation'];
function stats(values) {
  const sorted = [...values].sort((a,b)=>a-b);
  const q = p => sorted[Math.min(sorted.length-1,Math.ceil(sorted.length*p)-1)];
  return { samples:values.length, mean:values.reduce((a,b)=>a+b,0)/values.length,p50:q(.5),p95:q(.95),p99:q(.99),max:sorted.at(-1) };
}
const raw = {};
for (const variant of variants) {
  raw[variant] = [];
  for (const round of [1,2]) raw[variant].push(JSON.parse(await readFile(path.join(dir,`${variant}-${round}/results.json`),'utf8')));
}
const digest = raw.baseline[0].source.sourceDigest;
for (const runs of Object.values(raw)) for (const run of runs) {
  if (run.source.sourceDigest !== digest) throw new Error('Baseline snapshots differ; comparisons rejected');
  if (run.instrumented || run.failed || run.cases.some(c=>!c.valid)) throw new Error('Invalid/uncontrolled run');
}
const summary = { sourceDigest:digest,head:raw.baseline[0].source.head,environment:raw.baseline[0].source.environment,
  method:{counts:[50,100,200,300],scenarios:['movement','bridge','rifle','auto-shotgun'],rounds:2,warmup:60,samplesPerRound:180,order:'baseline navigation rays animation animation rays navigation baseline',headless:true,includesGpu:false,frameBudgetMs:1000/60}, variants:{} };
const metrics = ['cpu_sections_ms','simulation_ms','animation_submit_ms','crosshair_ms','engine_physics_monitor_ms'];
for (const variant of variants) {
  summary.variants[variant] = [];
  for (const count of [50,100,200,300]) for (const scenario of summary.method.scenarios) {
    const cases = raw[variant].flatMap(r=>r.cases).filter(c=>c.count===count&&c.scenario===scenario);
    const frames = cases.flatMap(c=>c.samples);
    const entry = {count,scenario,metrics:Object.fromEntries(metrics.map(k=>[k,stats(frames.map(s=>s[k]))])),
      perRound:cases.map(c=>({cpu:stats(c.samples.map(s=>s.cpu_sections_ms)),shots:c.shots,hits:c.hits,moving_fraction:c.moving_fraction,blocked_fraction:c.blocked_fraction})),
      warmup:stats(cases.flatMap(c=>c.cold_samples).map(s=>s.cpu_sections_ms)),
      over16_7Fraction:frames.filter(s=>s.cpu_sections_ms>1000/60).length/frames.length};
    summary.variants[variant].push(entry);
  }
}
await mkdir(path.join(root,'docs/performance'),{recursive:true});
await writeFile(path.join(root,'docs/performance/enemy-independent-summary.json'),JSON.stringify(summary,null,2));
await writeFile(path.join(root,'docs/performance/enemy-independent-raw.json.gz'),gzipSync(JSON.stringify(raw)));
const f = n=>n.toFixed(2);
let markdown = '| 敌人数 | 场景 | 原版均值/P95/P99/最大 ms | 寻路均值/P95 ms | 射线均值/P95 ms | 动画均值/P95 ms |\n|---:|---|---:|---:|---:|---:|\n';
for (const b of summary.variants.baseline) {
  const row = variant=>summary.variants[variant].find(c=>c.count===b.count&&c.scenario===b.scenario).metrics.cpu_sections_ms;
  const base = row('baseline');
  markdown += `| ${b.count} | ${b.scenario} | ${[base.mean,base.p95,base.p99,base.max].map(f).join('/')} | ${variants.slice(1).map(v=>{const s=row(v);return [s.mean,s.p95].map(f).join('/');}).join(' | ')} |\n`;
}
await writeFile(path.join(dir,'comparison-table.md'),markdown);
console.log(markdown);
console.log('300-enemy stage means:');
for (const variant of variants) for (const c of summary.variants[variant].filter(c=>c.count===300)) console.log(variant,c.scenario,Object.fromEntries(metrics.map(k=>[k,f(c.metrics[k].mean)])),c.perRound.map(r=>f(r.cpu.mean)));
