import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const inputArg = process.argv.find(arg => arg.startsWith('--input='));
const input = path.resolve(root, inputArg?.slice(8) ?? 'artifacts/enemy-cpu-profile/results.json');
const raw = JSON.parse(await readFile(input, 'utf8'));
const overlapMovement = raw.movement_model === '2d-overlap';
if (raw.failed || raw.display_driver !== 'headless') throw new Error('Profile did not complete successfully in headless mode');
const labels = { movement: '移动', bridge: '桥口拥堵', rifle: '持续射击·步枪', 'auto-shotgun': '持续射击·自动霰弹枪', flamethrower: '持续射击·喷火器' };
const stages = {
  simulation: '其余模拟', target_selection: '目标选择', enemy_logic: '敌人状态与攻击',
  navigation_steering: '寻路与邻居避让', enemy_movement: '物理移动及写回', enemy_sync: '敌人物理同步',
  attack_occlusion: '近战遮挡射线', shooting: '射击结算',
};
function stats(values) {
  if (!values.length || values.some(value => !Number.isFinite(value) || value < 0)) throw new Error('Invalid samples');
  const sorted = [...values].sort((a, b) => a - b);
  const quantile = q => sorted[Math.max(0, Math.ceil(q * sorted.length) - 1)];
  return { n: values.length, mean: values.reduce((a,b) => a+b,0)/values.length, p50: quantile(.5), p95: quantile(.95), p99: quantile(.99), max: sorted.at(-1), overBudgetPct: values.filter(value => value > 1000/60).length/values.length*100 };
}
const grouped = new Map();
for (const entry of raw.cases) {
  if (!entry.valid || entry.live !== entry.count || entry.samples.length !== raw.sample_frames) throw new Error('Invalid population/sample count');
  for (const sample of entry.samples) {
    const total = Object.values(sample.exclusive_ms).reduce((a,b) => a+b,0);
    if (Math.abs(total - sample.inclusive_ms.simulation) > .00001) throw new Error('Nested timing reconciliation failed');
    if (Math.abs(sample.cpu_sections_ms - sample.simulation_ms - sample.animation_submit_ms - sample.crosshair_ms) > .00001) throw new Error('CPU timing reconciliation failed');
  }
  if (entry.scenario === 'movement' && entry.moving_fraction < .5) throw new Error('Movement scenario did not sustain movement');
  if (entry.scenario === 'bridge' && entry.blocked_fraction < .05) throw new Error('Bridge scenario did not produce congestion');
  if (!['movement','bridge'].includes(entry.scenario) && (entry.shots < 1 || entry.hits < 1)) throw new Error('Shooting scenario did not hit enemies');
  const key = `${entry.scenario}:${entry.count}`;
  if (!grouped.has(key)) grouped.set(key, []);
  grouped.get(key).push(entry);
}
const groups = [];
for (const scenario of Object.keys(labels)) for (const count of [50,100,200,300]) {
  const entries = grouped.get(`${scenario}:${count}`);
  if (!entries) continue;
  if (entries.length !== raw.rounds || new Set(entries.map(entry => entry.round)).size !== raw.rounds) throw new Error('Incomplete repeats');
  const samples = entries.flatMap(entry => entry.samples.map(sample => ({...sample,round:entry.round})));
  const metrics = {};
  for (const key of ['cpu_sections_ms','simulation_ms','enemy_capsule_ms','animation_submit_ms','crosshair_ms','engine_physics_monitor_ms']) metrics[key] = stats(samples.map(sample => sample[key]));
  metrics.shooting_all_frames_ms = stats(samples.map(sample => sample.inclusive_ms.shooting ?? 0));
  const shotSamples = samples.filter(sample => sample.shot_calls > 0);
  if (shotSamples.length) {
    metrics.shooting_active_frames_ms = stats(shotSamples.map(sample => sample.inclusive_ms.shooting));
    metrics.cpu_shot_frames_ms = stats(shotSamples.map(sample => sample.cpu_sections_ms));
    metrics.cpu_nonshot_frames_ms = stats(samples.filter(sample => !sample.shot_calls).map(sample => sample.cpu_sections_ms));
  }
  const exclusive = {};
  for (const stage of Object.keys(stages)) exclusive[stage] = stats(samples.map(sample => sample.exclusive_ms[stage] ?? 0));
  const rank = [
    ...Object.entries(exclusive).map(([key,value]) => ({stage:stages[key],mean:value.mean,pct:value.mean/metrics.cpu_sections_ms.mean*100})),
    {stage:'动画姿态计算与提交',mean:metrics.animation_submit_ms.mean,pct:metrics.animation_submit_ms.mean/metrics.cpu_sections_ms.mean*100},
    {stage:'准星扫描',mean:metrics.crosshair_ms.mean,pct:metrics.crosshair_ms.mean/metrics.cpu_sections_ms.mean*100},
  ].sort((a,b) => b.mean-a.mean);
  groups.push({scenario,count,metrics,exclusive,rank,rounds:entries.map(entry => ({round:entry.round,mean:entry.mean_cpu_ms,spawn_ms:entry.spawn_ms,moving_fraction:entry.moving_fraction,blocked_fraction:entry.blocked_fraction,shots:entry.shots,hits:entry.hits})),slowest_samples:[...samples].sort((a,b) => b.cpu_sections_ms-a.cpu_sections_ms).slice(0,10)});
}
const controlArg = process.argv.find(arg => arg.startsWith('--control='));
let control;
const controls = [];
if (controlArg) {
  control = JSON.parse(await readFile(path.resolve(root,controlArg.slice(10)),'utf8'));
  if (control.failed || control.instrumented !== false || control.display_driver !== 'headless') throw new Error('Invalid uninstrumented control');
  const gameplayFiles = manifest => manifest.filter(item => /^(scripts\/|scenes\/|assets\/|project\.godot$)/.test(item.path));
  if (JSON.stringify(gameplayFiles(raw.source.manifest)) !== JSON.stringify(gameplayFiles(control.source.manifest))) throw new Error('Gameplay source differs between profile and control');
  for (const group of groups) {
    const entries = control.cases.filter(entry => entry.count === group.count && entry.scenario === group.scenario);
    if (!entries.length) continue;
    if (entries.length !== control.rounds || entries.some(entry => !entry.valid || entry.live !== entry.count || entry.samples.length !== control.sample_frames)) throw new Error('Incomplete control');
    const samples = entries.flatMap(entry => entry.samples);
    const metrics = {};
    for (const key of ['cpu_sections_ms','simulation_ms','enemy_capsule_ms','animation_submit_ms','crosshair_ms']) metrics[key] = stats(samples.map(sample => sample[key]));
    const shotSamples = samples.filter(sample => sample.shot_calls > 0);
    if (shotSamples.length) {
      metrics.cpu_shot_frames_ms = stats(shotSamples.map(sample => sample.cpu_sections_ms));
      metrics.cpu_nonshot_frames_ms = stats(samples.filter(sample => !sample.shot_calls).map(sample => sample.cpu_sections_ms));
    }
    controls.push({scenario:group.scenario,count:group.count,metrics,rounds:entries.map(entry=>({round:entry.round,mean:entry.mean_cpu_ms,shots:entry.shots,hits:entry.hits}))});
  }
}
const f = value => value.toFixed(2);
const lines = [
  '# 敌人 CPU 性能测量', '',
  `完成时间：${new Date(raw.finishedAt).toLocaleString('zh-CN',{timeZone:'Asia/Shanghai',hour12:false})}（北京时间）。Godot ${raw.engine}；显示驱动 ${raw.display_driver}；物理频率 ${raw.physics_hz}Hz。`, '',
  `硬件：${raw.source.environment?.cpu ?? '未记录'}；逻辑处理器 ${raw.source.environment?.logicalCpus ?? '未记录'}；系统 ${raw.source.environment?.osRelease ?? '未记录'}。`, '',
  `源码提交：\`${raw.source.head}\`。测量使用未提交文件在内的冻结源码副本，完整树 SHA-256：\`${raw.source.sourceDigest}\`。该摘要对应测量时版本，后续添加的报告不在该摘要中。`, '',
  '## 测量口径', '',
  `- 50 / 100 / 200 / 300 只敌人，每组 ${raw.rounds} 轮，第二轮反转数量和场景顺序。每轮预热 ${raw.warmup_frames} 帧，然后采样 ${raw.sample_frames} 帧；固定 dt=1/60。计时单位为毫秒，P95/P99 使用 nearest-rank。`,
  overlapMovement
    ? '- 敌人构成为 90% 普通、10% 爬行。使用真实 simulation、二维位置移动、障碍矩形导航、软分离、武器命中和骨骼姿态提交；允许僵尸重叠，不包含精英与橄榄球混合压力。'
    : '- 敌人构成为 90% 普通、10% 爬行。使用真实 simulation、CharacterBody3D、碰撞代理、导航、武器命中和骨骼姿态提交，不包含精英与橄榄球混合压力。',
  '- 移动：本岸宽区域朝目标前进；桥口：完整栅栏门前五列排队，超出桥容量的敌人从实际远岸接近；射击：本岸敌人接近无敌玩家，持续追瞄最近敌人，分别使用步枪、自动霰弹枪和喷火器。',
  '- 炮塔关闭、地雷停用；敌人和水晶高生命，玩家无敌，弹药在测量区间外补充。这用于保持固定数量，包含真实伤害与硬直，不代表正常击杀后的实战总体开销。',
  '- CPU 段合计 = simulation.step 墙钟耗时 + 准星扫描 + 动画姿态计算与提交。模拟内部已包含物理和射击，不能再次相加。它不是完整引擎帧时间，也不是实测 FPS。',
  overlapMovement
    ? '- 二维移动版本没有敌人胶囊，兼容字段 enemy_capsule_ms 固定为 0，不能解读为整个引擎物理耗时为零。移动计入寻路与邻居避让、敌人状态与攻击；blocked_fraction 记录静止敌人比例，包含障碍停留和攻击停留。射击结算仍为完整 fire() 耗时。'
    : '- 胶囊移动为生产代码 enemy_physics_usec：扫掠、地面、重叠与代理更新。射击结算为 fire()：摄像机/枪口射线、逐弹丸候选遍历、身体命中、排序、伤害和事件；不是只计单个碰撞算法。',
  '- 模拟分段使用嵌套计时扣除子调用，exclusive 分段可相加；胶囊移动计时嵌套在物理移动分段内，不能再加一次。脚本计时和探针本身存在开销，结果为带探针诊断值。',
  '- 动画只测 CPU 计算和 API 提交，headless 不测真实 GPU 蒙皮/上传/绘制。引擎上一物理帧 Performance.TIME_PHYSICS_PROCESS 单独保留在原始数据中，仅作上下文，不作为可加分段。',
  '- 不含网络快照、声音、特效、HUD、第一人称武器同步、独立引擎物理步与 GPU；没有运行视觉验收、全量测试或发布门禁。运行中其他桌面任务可能影响尖峰，两轮差异单独保留。', '',
  '## CPU 段合计', '',
  '| 场景 | 数量 | 样本 | 平均 | P50 | P95 | P99 | 最大 | 超过16.67ms |',
  '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |',
];
const movement300 = groups.find(group=>group.scenario==='movement' && group.count===300);
const bridge300 = groups.find(group=>group.scenario==='bridge' && group.count===300);
const shotgun300 = groups.find(group=>group.scenario==='auto-shotgun' && group.count===300);
const flame300 = groups.find(group=>group.scenario==='flamethrower' && group.count===300);
if (movement300 && bridge300 && shotgun300 && flame300) {
  const plainMovement = controls.find(entry=>entry.scenario==='movement' && entry.count===300);
  const plainBridge = controls.find(entry=>entry.scenario==='bridge' && entry.count===300);
  const movementCpu = (plainMovement ?? movement300).metrics.cpu_sections_ms;
  const bridgeCpu = (plainBridge ?? bridge300).metrics.cpu_sections_ms;
  const findings = [
    '## 结论', '',
    `1. CPU侧已经存在超过60FPS预算的开销。${plainMovement && plainBridge ? '不带分段探针对照中，' : '带分段探针测量中，'}300只移动场景的测量段合计均值 ${f(movementCpu.mean)}ms、P95 ${f(movementCpu.p95)}ms；桥口拥堵均值 ${f(bridgeCpu.mean)}ms、P95 ${f(bridgeCpu.p95)}ms。它们尚未包含GPU和完整帧的其他系统。`,
    `2. 多弹丸射击是明显的尖峰来源。带分段探针的300只场景中，自动霰弹枪单次结算平均 ${f(shotgun300.metrics.shooting_active_frames_ms.mean)}ms、最大 ${f(shotgun300.metrics.shooting_active_frames_ms.max)}ms；喷火器平均 ${f(flame300.metrics.shooting_active_frames_ms.mean)}ms、最大 ${f(flame300.metrics.shooting_active_frames_ms.max)}ms。生产代码每条射线遍历所有活敌人，粗筛命中后再次计算姿态与部件变换，应优先测试空间筛选和同帧姿态复用。`,
    `3. 物理开销明显，但不能据此把所有卡顿归因于CharacterBody3D。300只移动时胶囊移动平均 ${f(movement300.metrics.enemy_capsule_ms.mean)}ms，独立的敌人物理同步分段 ${f(movement300.exclusive.enemy_sync.mean)}ms，目标选择 ${f(movement300.exclusive.target_selection.mean)}ms，动画计算与提交 ${f(movement300.metrics.animation_submit_ms.mean)}ms。桥口胶囊移动平均 ${f(bridge300.metrics.enemy_capsule_ms.mean)}ms。回退移动方案可能降低相关成本，但射击和动画仍需处理；本次未做回退A/B，不能承诺回退收益比例。`,
    '4. 优先顺序：射击候选筛选与姿态复用 → 去除重复物理同步并降低目标/导航更新频率 → 动画更新分级 → 再评估碰撞架构。以上是分段证据支持的优化方向，本次没有修改玩法或实现这些优化。', '',
  ];
  lines.splice(lines.indexOf('## 测量口径'),0,...findings);
}
for (const group of groups) {
  const metric = group.metrics.cpu_sections_ms;
  lines.push(`| ${labels[group.scenario]} | ${group.count} | ${metric.n} | ${f(metric.mean)} | ${f(metric.p50)} | ${f(metric.p95)} | ${f(metric.p99)} | ${f(metric.max)} | ${f(metric.overBudgetPct)}% |`);
}
if (control) {
  lines.push('', '## 不带分段探针的生产模拟对照', '',
    `对 ${[...new Set(controls.map(entry=>entry.count))].sort((a,b)=>a-b).join(' / ')} 只敌人的全部场景再次运行 ${control.rounds} 轮，直接实例化生产 simulation.gd，仅在外部记录模拟/准星/动画墙钟时间。所有 scripts、scenes、assets 和 project.godot 的逐文件 SHA-256 与分段测量一致。对照完成于 ${new Date(control.finishedAt).toLocaleString('zh-CN',{timeZone:'Asia/Shanghai',hour12:false})}（北京时间）。对照树摘要：\`${control.source.sourceDigest}\`。`, '',
    '以下值更适合判断实际 CPU 预算。分段测量用于定位热点；两者在不同时间串行运行，差值包含环境波动，不能全部解释为探针开销。', '',
    '| 场景 | 数量 | 平均 | P95 | P99 | 最大 | 超过16.67ms | 带探针均值 |', '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |');
  for (const entry of controls) {
    const m = entry.metrics.cpu_sections_ms;
    const instrumented = groups.find(group=>group.count===entry.count && group.scenario===entry.scenario);
    lines.push(`| ${labels[entry.scenario]} | ${entry.count} | ${f(m.mean)} | ${f(m.p95)} | ${f(m.p99)} | ${f(m.max)} | ${f(m.overBudgetPct)}% | ${f(instrumented.metrics.cpu_sections_ms.mean)} |`);
  }
}
lines.push('', '## 分段均值与瓶颈', '', '| 场景 | 数量 | 模拟 | 胶囊移动（模拟内） | 动画提交 | 准星扫描 | 开火帧射击结算（模拟内） | 最大均值分段 |', '| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |');
for (const group of groups) {
  const m = group.metrics;
  lines.push(`| ${labels[group.scenario]} | ${group.count} | ${f(m.simulation_ms.mean)} | ${f(m.enemy_capsule_ms.mean)} | ${f(m.animation_submit_ms.mean)} | ${f(m.crosshair_ms.mean)} | ${m.shooting_active_frames_ms ? f(m.shooting_active_frames_ms.mean) : '—'} | ${group.rank[0].stage} ${f(group.rank[0].pct)}% |`);
}
lines.push('', '## 每组详细分布', '');
for (const group of groups) {
  lines.push(`### ${labels[group.scenario]} · ${group.count} 只`, '', '| 测量项 | 平均 | P95 | P99 | 最大 |', '| --- | ---: | ---: | ---: | ---: |');
  for (const [key,label] of Object.entries({simulation_ms:'完整模拟',enemy_capsule_ms:'胶囊移动（模拟内）',animation_submit_ms:'动画提交',crosshair_ms:'准星扫描',shooting_active_frames_ms:'射击结算·仅开火帧',cpu_shot_frames_ms:'CPU合计·仅开火帧',cpu_nonshot_frames_ms:'CPU合计·未开火帧'})) {
    const m = group.metrics[key]; if (m) lines.push(`| ${label} | ${f(m.mean)} | ${f(m.p95)} | ${f(m.p99)} | ${f(m.max)} |`);
  }
  const peak = group.slowest_samples[0];
  lines.push('', `最慢样本（第${peak.round}轮、采样帧${peak.frame}，帧号从0开始）同帧分解：CPU段合计 ${f(peak.cpu_sections_ms)}ms = 模拟 ${f(peak.simulation_ms)}ms + 动画 ${f(peak.animation_submit_ms)}ms + 准星 ${f(peak.crosshair_ms)}ms。该帧模拟内的胶囊移动 ${f(peak.enemy_capsule_ms)}ms，射击结算 ${f(peak.inclusive_ms.shooting ?? 0)}ms。`);
  lines.push('', `均值占比前三：${group.rank.slice(0,3).map(stage => `${stage.stage} ${f(stage.mean)}ms（${f(stage.pct)}%）`).join('；')}。`, '', '| 轮次 | CPU合计均值 | 移动占比 | 被堵占比 | 实际开火/命中次数 | 一次性测试布置生成耗时（不等同正式分批刷新） |', '| ---: | ---: | ---: | ---: | ---: | ---: |');
  for (const round of group.rounds) lines.push(`| ${round.round} | ${f(round.mean)} | ${f(round.moving_fraction*100)}% | ${f(round.blocked_fraction*100)}% | ${round.shots} / ${round.hits} | ${f(round.spawn_ms)} |`);
  lines.push('');
}
lines.push('## 复现与证据', '', '```powershell', 'node tools/run-enemy-cpu-profile.mjs', 'node tools/run-enemy-cpu-profile.mjs --control --counts=50,300 --rounds=1', 'node tools/summarize-enemy-cpu-profile.mjs --control=artifacts/enemy-cpu-control/results.json', '```', '', '- 原始逐帧数据：`artifacts/enemy-cpu-profile/results.json`；源码逐文件摘要：`source-manifest.json`；无窗口日志：`profile.log`。', '- 无分段探针对照：`artifacts/enemy-cpu-control/results.json`。', '- 汇总与每组最慢十帧的分段：`artifacts/enemy-cpu-profile/summary.json`。', '- 启动器保留临时冻结工程路径，写在源码清单中。全程 headless + Dummy 音频 + 无控制台窗口。', '- 数据验证包含：数量始终固定、模拟未失败、真实移动/堵塞/射击命中、嵌套计时相加一致、CPU段合计一致、重复轮次完整。');
const outputDir = path.dirname(input);
await mkdir(outputDir,{recursive:true});
await writeFile(path.join(outputDir,'summary.json'),JSON.stringify({sourceDigest:raw.source.sourceDigest,groups,controlSourceDigest:control?.source.sourceDigest,controls},null,2));
await writeFile(path.join(outputDir,'report.md'),lines.join('\n')+'\n');
const reportArg = process.argv.find(arg => arg.startsWith('--report='));
if (reportArg) await writeFile(path.resolve(root,reportArg.slice(9)),lines.join('\n')+'\n');
if (process.argv.includes('--quiet')) console.log(`Validated ${groups.length} profile groups and ${controls.length} control groups; report saved to ${path.join(outputDir,'report.md')}`);
else console.log(JSON.stringify(groups.map(group => ({scenario:group.scenario,count:group.count,mean:group.metrics.cpu_sections_ms.mean,p95:group.metrics.cpu_sections_ms.p95,p99:group.metrics.cpu_sections_ms.p99,max:group.metrics.cpu_sections_ms.max,top:group.rank.slice(0,3)})),null,2));
