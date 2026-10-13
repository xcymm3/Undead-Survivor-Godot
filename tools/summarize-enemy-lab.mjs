import {readFile,writeFile,mkdir} from 'node:fs/promises';
const safeLabel=s=>s.replace(/[^a-zA-Z0-9_.+-]/g,'-');
const dir=process.argv.find(a=>a.startsWith('--output-dir='))?.slice(13)??'artifacts/enemy-lab';
const index=JSON.parse(await readFile(`${dir}/index.json`,'utf8'));
const complete=JSON.parse(await readFile(`${dir}/complete.json`,'utf8'));
const selection=JSON.parse(await readFile(`${dir}/selection.json`,'utf8'));
const runs=[];
for(const entry of index){
 const data=JSON.parse(await readFile(`${dir}/${entry.label}/results.json`,'utf8'));
 if(data.source.sourceDigest!==complete.sourceDigest||data.instrumented||data.failed||data.display_driver!=='headless'||data.cases.some(c=>!c.valid))throw Error(`Uncontrolled run ${entry.label}`);
 runs.push({...entry,data});
}
function stats(values){
 const s=values.toSorted((a,b)=>a-b);if(!s.length)throw Error('No samples');
 const q=p=>s[Math.min(s.length-1,Math.ceil(s.length*p)-1)];
 return {n:s.length,mean:s.reduce((a,b)=>a+b,0)/s.length,p50:q(.5),p95:q(.95),p99:q(.99),max:s.at(-1),over16_67:s.filter(x=>x>1000/60).length/s.length,over33_33:s.filter(x=>x>1000/30).length/s.length};
}
const metrics=['cpu_sections_ms','simulation_ms','animation_submit_ms','crosshair_ms','presentation_ms'];
const summary={sourceDigest:complete.sourceDigest,formalCounts:complete.formalCounts,head:runs[0].data.source.head,environment:runs[0].data.source.environment,gpu:false,selection,formal:[],screen:[],dynamic:[],scaling:[],endurance:[]};
for(const run of runs){
 for(const c of run.data.cases){
  const entry={variant:run.variant,label:run.label,count:c.count,scenario:c.scenario,moving_fraction:c.moving_fraction,blocked_fraction:c.blocked_fraction,hits:c.hits,shots:c.shots,live:c.live,peak_live:c.peak_live,wall_seconds:c.wall_seconds,simulation_seconds:c.simulation_seconds,metrics:Object.fromEntries(metrics.map(m=>[m,stats(c.samples.map(s=>s[m]??0))])),activation_ms:c.actor_activation_ms,spawn_ms:c.spawn_ms,nodes:stats(c.samples.map(s=>s.nodes??0))};
  const phase=run.label.split('-')[0];if(summary[phase])summary[phase].push(entry);
 }
}
const formalVariants=[...new Set(summary.formal.map(c=>c.variant))];
summary.confirmation=[];
for(const variant of formalVariants.filter(v=>v!=='baseline'))for(const count of complete.formalCounts)for(const scenario of ['movement','bridge','rifle']){
 const pairs=[];
 for(let round=1;round<=5;round++){
  const b=summary.formal.find(c=>c.label===`formal-${round}-baseline`&&c.count===count&&c.scenario===scenario);
  const c=summary.formal.find(c=>c.label===safeLabel(`formal-${round}-${variant}`)&&c.count===count&&c.scenario===scenario);
  if(!b||!c||b.wall_seconds<60||c.wall_seconds<60)throw Error('Missing five-round long confirmation');
  pairs.push({round,baseline_p95:b.metrics.cpu_sections_ms.p95,candidate_p95:c.metrics.cpu_sections_ms.p95,gain:1-c.metrics.cpu_sections_ms.p95/b.metrics.cpu_sections_ms.p95,p99_gain:1-c.metrics.cpu_sections_ms.p99/b.metrics.cpu_sections_ms.p99});
 }
 summary.confirmation.push({variant,count,scenario,pairs,median_gain:stats(pairs.map(p=>p.gain)).p50,positive_rounds:pairs.filter(p=>p.gain>0).length});
}
const diagnostic=JSON.parse(await readFile(`${dir}/diagnostic-baseline/results.json`,'utf8'));
if(diagnostic.source.sourceDigest!==complete.sourceDigest||!diagnostic.instrumented||diagnostic.failed)throw Error('Invalid diagnostic');
summary.diagnostic=diagnostic.cases.map(c=>({scenario:c.scenario,inclusive:Object.fromEntries(['simulation','target_selection','player_reachability','enemy_logic','navigation_steering','shooting'].map(m=>[m,stats(c.samples.map(s=>s.inclusive_ms[m]??0))])),counts:Object.fromEntries(["astar","neighbors"].map(m=>[m,stats(c.samples.map(s=>s.detail_counts?.[m]??0))])),calls:Object.fromEntries(["target_selection","player_reachability","navigation_steering","shooting"].map(m=>[m,stats(c.samples.map(s=>s.call_counts?.[m]??0))])),detail:Object.fromEntries(['astar_or_shared_route','neighbor_avoidance'].map(m=>[m,stats(c.samples.map(s=>s.detail_ms?.[m]??0))])),animation:Object.fromEntries(['pose_mesh','bone_submit'].map(m=>[m,stats(c.samples.map(s=>(s.animation_detail_us?.[m]??0)/1000))]))}));
const f=x=>x.toFixed(2);
let md=`# 尸潮独立 CPU 实验\n\n冻结提交：${summary.head}\n\n源码 SHA-256：${summary.sourceDigest}\n\nCPU：${summary.environment.cpu}；${summary.environment.logicalCpus}逻辑核。Godot真正headless、Dummy音频，串行测量，无GPU数据。\n\n计时合计为模拟、动画计算/提交、准星、第一人称/界面/音效路由及特效CPU更新，不能当成完整渲染帧或FPS。详细探针不参与收益排名。普通人口测试每600个模拟步恢复起点，保持持续移动和拥堵；动态、耐久测试不恢复位置。墙钟采样60秒/轮、5轮，实际模拟进度分别记录。\n\n`;
md+='| 方案 | 人数 | 场景 | 5轮配对P95改善中位数 | 改善轮数 |\n|---|---:|---|---:|---:|\n';
for(const c of summary.confirmation)md+=`| ${c.variant} | ${c.count} | ${c.scenario} | ${f(c.median_gain*100)}% | ${c.positive_rounds}/5 |\n`;
md+='\n## 正式长采样\n\n| 方案 | 人数 | 场景 | 均值/P95/P99（各轮中位数）ms | 最坏单帧ms | 超16.67ms比例（轮中位数） |\n|---|---:|---|---:|---:|---:|\n';
for(const variant of formalVariants)for(const count of complete.formalCounts)for(const scenario of ['movement','bridge','rifle']){
 const rows=summary.formal.filter(c=>c.variant===variant&&c.count===count&&c.scenario===scenario).map(c=>c.metrics.cpu_sections_ms);
 md+=`| ${variant} | ${count} | ${scenario} | ${['mean','p95','p99'].map(k=>f(stats(rows.map(r=>r[k])).p50)).join('/')} | ${f(Math.max(...rows.map(r=>r.max)))} | ${f(stats(rows.map(r=>r.over16_67)).p50*100)}% |\n`;
}
md+='\n## 独立筛选（短采样，仅用于选候选）\n\n| 方案 | 场景 | CPU均值/P95 ms | 模拟/动画/准星/表现均值 ms |\n|---|---|---:|---:|\n';
for(const c of summary.screen)md+=`| ${c.variant} | ${c.scenario} | ${f(c.metrics.cpu_sections_ms.mean)}/${f(c.metrics.cpu_sections_ms.p95)} | ${['simulation_ms','animation_submit_ms','crosshair_ms','presentation_ms'].map(k=>f(c.metrics[k].mean)).join('/')} |\n`;
md+='\n## 动态与耐久\n\n| 方案 | 场景 | 墙钟/模拟秒 | 敌人峰值 | CPU均值/P95 ms |\n|---|---|---|---:|---:|\n';
for(const c of [...summary.dynamic,...summary.endurance])md+=`| ${c.variant} | ${c.scenario} | ${f(c.wall_seconds)}/${f(c.simulation_seconds??0)} | ${c.peak_live} | ${f(c.metrics.cpu_sections_ms.mean)}/${f(c.metrics.cpu_sections_ms.p95)} |\n`;
md+='\n## 分段归因（独立探针，有额外开销）\n\n| 场景 | 寻路/避让均值 ms | 姿态及模型/骨骼提交均值 ms | A*次数/邻居候选均值 |\n|---|---:|---:|---:|\n';
for(const c of summary.diagnostic)md+=`| ${c.scenario} | ${f(c.detail.astar_or_shared_route.mean)}/${f(c.detail.neighbor_avoidance.mean)} | ${f(c.animation.pose_mesh.mean)}/${f(c.animation.bone_submit.mean)} | ${f(c.counts.astar.mean)}/${f(c.counts.neighbors.mean)} |\n`;
md+='\n## 人数短采样\n\n| 方案 | 人数 | 场景 | CPU均值/P95/P99 ms |\n|---|---:|---|---:|\n';
for(const c of summary.scaling)md+=`| ${c.variant} | ${c.count} | ${c.scenario} | ${['mean','p95','p99'].map(k=>f(c.metrics.cpu_sections_ms[k])).join('/')} |\n`;
md+='\n## 十分钟资源周转\n\n| 方案 | 节点数中位数/最大 | CPU均值/P95/P99 ms |\n|---|---:|---:|\n';
for(const c of summary.endurance)md+=`| ${c.variant} | ${c.nodes.max===0?'无':`${f(c.nodes.p50)}/${f(c.nodes.max)}`} | ${['mean','p95','p99'].map(k=>f(c.metrics.cpu_sections_ms[k])).join('/')} |\n`;
md+='\n耐久场景固定存活人数，周期性击杀并生成敌人，测资源周转；不代表自然推进整局十分钟的体验验证。\n';
md+='\n动态BOSS场景因为更快方案推进更多模拟时间而可能召唤更多敌人，必须结合人口和模拟进度解读，不能直接按平均ms排名。no_submit、no_pose、no_avoid、bones1为诊断简化，不代表可上线。动画低频原型没有新增GPU插值；原生GPU、画面与真人手感尚未验收。减面数和阴影/灯光方向等待隔离GPU机器。\n';
await writeFile(`${dir}/summary.json`,JSON.stringify(summary,null,2));await writeFile(`${dir}/report.md`,md);
await mkdir('docs/performance',{recursive:true});await writeFile('docs/performance/enemy-lab-report.md',md);
console.log(md.slice(0,6000));
