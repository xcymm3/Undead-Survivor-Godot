import {spawn,execFileSync} from 'node:child_process';
import {mkdir,readFile,writeFile,appendFile,copyFile} from 'node:fs/promises';
import path from 'node:path';
const pilot=process.argv.includes('--pilot');
const folder=pilot?'cpu-improvements-pilot':'cpu-improvements-night';
const dir=`artifacts/${folder}`;await mkdir(dir,{recursive:true});
const git=args=>execFileSync('git',args,{encoding:'utf8',windowsHide:true}).trim();
const head=git(['rev-parse','HEAD']),branch=git(['branch','--show-current']);
const variants=['prechange','cpu_target','cpu_ray','cpu_crowd','cpu_paths','cpu_all'];
let step=0,source=null;const runs=[];
function gitStep(args){log({operation:'git-start',command:['git',...args]});try{const output=git(args);log({operation:'git-finish',command:['git',...args],exitCode:0,output});return output;}catch(error){log({operation:'git-failed',command:['git',...args],error:String(error)});throw error;}}
await writeFile(`${dir}/cli.json`,JSON.stringify({pid:process.pid,startedAt:new Date().toISOString(),head,branch,pilot},null,2));
let writes=Promise.resolve();
function log(event){const entry={at:new Date().toISOString(),...event};writes=writes.then(()=>appendFile(`${dir}/audit.jsonl`,JSON.stringify(entry)+'\n'));const line=`[${entry.at}] ${event.message??event.operation??JSON.stringify(event)}\n`;process.stdout.write(line);writes=writes.then(()=>appendFile(`${dir}/cli.log`,line));}
async function command(name,args,options={}){
 const id=++step;log({operation:'start',step:id,message:`STEP ${id} START ${name}`,command:[process.execPath,...args]});
 await writeFile(`${dir}/progress.json`,JSON.stringify({state:'running',pid:process.pid,head,step:id,label:name,completedRuns:runs.length,updatedAt:new Date().toISOString()},null,2));
 const child=spawn(process.execPath,args,{windowsHide:true,stdio:['ignore','pipe','pipe'],...options});
 let output='';
 const emit=data=>{output+=data;process.stdout.write(data);writes=writes.then(()=>appendFile(`${dir}/cli.log`,data));};child.stdout.on('data',emit);child.stderr.on('data',emit);
 const code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',resolve);});
 await writeFile(`${dir}/step-${id}.log`,output);log({operation:'finish',step:id,message:`STEP ${id} ${code===0?'PASS':'FAIL'} ${name}`,exitCode:code});
 if(code!==0)throw Error(`${name} failed; see step-${id}.log`);
 return output;
}
async function profile(variant,label,args,regressions=false){
 const options=['tools/run-enemy-cpu-profile.mjs',`--variant=${variant}`,`--output=${folder}/${label}`,'--control','--rounds=1',...args];
 if(regressions)options.push('--regressions');
 if(regressions&&variant==='cpu_all')options.push('--cpu-checks');
 await command(label,options);
 const d=JSON.parse(await readFile(`${dir}/${label}/results.json`,'utf8'));
 if(!source)source=d.source.sourceDigest;
 if(d.source.sourceDigest!==source||d.failed||d.cases.some(c=>!c.valid))throw Error(`Uncontrolled sample ${label}`);
 if(['cpu_paths','cpu_all'].includes(variant)&&d.cases.some(c=>c.samples.some(s=>(s.cpu_work?.astar_used??0)>12)))throw Error('Path budget exceeded');
 runs.push({variant,label});await writeFile(`${dir}/index.json`,JSON.stringify(runs,null,2));
 log({operation:'result',label,variant,sourceDigest:source,cases:d.cases.map(c=>({count:c.count,scenario:c.scenario,samples:c.samples.length,mean:c.mean_cpu_ms,moving:c.moving_fraction,hits:c.hits,valid:c.valid}))});
}
const stats=a=>{const s=a.toSorted((x,y)=>x-y),q=p=>s[Math.ceil(s.length*p)-1];return {mean:s.reduce((t,x)=>t+x,0)/s.length,p50:q(.5),p95:q(.95),p99:q(.99),max:s.at(-1),over16_67:s.filter(x=>x>1000/60).length/s.length};};
async function summarize(){
 const cases=[];let environment;
 for(const r of runs){const d=JSON.parse(await readFile(`${dir}/${r.label}/results.json`,'utf8'));environment??=d.source.environment;for(const c of d.cases)cases.push({...r,count:c.count,scenario:c.scenario,wall_seconds:c.wall_seconds,simulation_seconds:c.simulation_seconds,moving_fraction:c.moving_fraction,peak_live:c.peak_live,metrics:Object.fromEntries(['cpu_sections_ms','simulation_ms','animation_submit_ms','crosshair_ms','presentation_ms'].map(k=>[k,stats(c.samples.map(s=>s[k]))])),nodes:stats(c.samples.map(s=>s.nodes)),work:{astar_peak:Math.max(...c.samples.map(s=>s.cpu_work?.astar_used??0)),pending_peak:Math.max(...c.samples.map(s=>s.cpu_work?.astar_pending??0)),neighbors_mean:c.samples.reduce((t,s)=>t+(s.cpu_work?.neighbors??0),0)/c.samples.length}});}
 const pairs=[];
 if(!pilot)for(const variant of variants.filter(v=>v!=='prechange'))for(const scenario of ['movement','bridge','rifle','auto-shotgun']){const gains=[];for(let round=1;round<=5;round++){const b=cases.find(c=>c.label===`formal-${round}-prechange`&&c.scenario===scenario),v=cases.find(c=>c.label===`formal-${round}-${variant}`&&c.scenario===scenario);if(!b||!v)throw Error('Incomplete five-round comparison');gains.push(1-v.metrics.cpu_sections_ms.p95/b.metrics.cpu_sections_ms.p95);}pairs.push({variant,scenario,median_gain:stats(gains).p50,positive_rounds:gains.filter(g=>g>0).length,gains});}
 const summary={head,sourceDigest:source,environment,pilot,cases,pairs,completedAt:new Date().toISOString(),gpu:false};
 await writeFile(`${dir}/summary.json`,JSON.stringify(summary,null,2));
 const f=x=>x.toFixed(2);let report=`# 四项CPU优化对照结果\n\n提交：${head}；冻结源码SHA-256：${source}。硬件：${environment.cpu}。无窗口CPU测试，没有GPU数据。\n\nprechange为1940134提交的原始simulation/main/arena；其余独立方案只启用目标缓存、射线索引、避让限额或路径限额；cpu_all在本报告表示四项全部启用。每个副本及补丁哈希见source-manifest.json。\n\n| 方案 | 场景 | 五轮配对P95减少中位数 | 改善轮数 |\n|---|---|---:|---:|\n`;
 for(const p of pairs)report+=`| ${p.variant} | ${p.scenario} | ${f(p.median_gain*100)}% | ${p.positive_rounds}/5 |\n`;
 report+='\n## 正式300只长采样\n\n| 方案 | 场景 | 平均/P95/P99（轮中位数）ms | 最坏尖峰ms |\n|---|---|---:|---:|\n';
 if(!pilot)for(const v of variants)for(const scene of ['movement','bridge','rifle','auto-shotgun']){const cs=cases.filter(c=>c.label.startsWith('formal-')&&c.variant===v&&c.scenario===scene);report+=`| ${v} | ${scene} | ${['mean','p95','p99'].map(k=>f(stats(cs.map(c=>c.metrics.cpu_sections_ms[k])).p50)).join('/')} | ${f(Math.max(...cs.map(c=>c.metrics.cpu_sections_ms.max)))} |\n`;}
 report+='\n## 短采样、动态与十分钟资源周转\n\n| 案例 | 人数 | 场景 | 平均/P95/P99 ms | 模拟秒 | 节点峰值 | 路径单步最大/排队峰值 |\n|---|---:|---|---:|---:|---:|---:|\n';
 for(const c of cases.filter(c=>!c.label.startsWith('formal-')))report+=`| ${c.label} | ${c.count} | ${c.scenario} | ${['mean','p95','p99'].map(k=>f(c.metrics.cpu_sections_ms[k])).join('/')} | ${f(c.simulation_seconds)} | ${c.nodes.max} | ${c.work.astar_peak}/${c.work.pending_peak} |\n`;
 report+='\n计时是CPU分段合计，不是渲染FPS。每场预热后采样，核心长采样每场墙钟60秒、5轮，轮次反转方案和场景顺序。固定人口场景每600步恢复起点；较快版本推进更多模拟时间，移动/拥堵状态分布仍可能不同。原版无预算统计，不表示原版没有A*调用。远处索敌最多延后约0.1–0.2秒；路径排队可能短暂延迟，保留实际通行检查并优先处理近处/被堵敌人，年龄防饥饿。避让允许更紧密重叠，可能影响防线难度。动态BOSS样本需结合模拟时间和人口，不能直接排名。十分钟测试仅为资源周转，不是完整自然对局。对象池及骨骼简化未改。原始数据、每步命令、退出码和输出见audit.jsonl、step-*.log、cli.log。\n';
 await writeFile(`${dir}/report.md`,report);return summary;
}
try{
 log({operation:'implementation',message:`Four CPU optimizations; source commit ${head}; exact pre-change reference 1940134`});
 await writeFile(`${dir}/implementation.patch`,git(['diff','1940134',head,'--','scripts/','tools/profile-enemy-cpu.gd']));
 await command('basic-verification',['tools/automation.mjs']);
 for(const v of variants)await profile(v,`short-${v}`,[`--counts=${pilot?'50':'50,100,200'}`,'--scenarios=movement,bridge,rifle',`--warmup=${pilot?10:120}`,`--samples=${pilot?20:300}`],!pilot);
 if(!pilot){
  for(let round=1;round<=5;round++)for(const v of round%2?variants:variants.toReversed())await profile(v,`formal-${round}-${v}`,['--counts=300','--scenarios=movement,bridge,rifle,auto-shotgun','--warmup-seconds=10','--samples=300','--wall-seconds=60',...(round%2?[]:['--reverse-order'])]);
  for(const v of variants)await profile(v,`dynamic-${v}`,['--counts=300','--scenarios=mixed,boss,lifecycle','--warmup=120','--samples=300','--wall-seconds=60','--epoch-frames=0']);
  for(const v of ['prechange','cpu_all'])await profile(v,`endurance-${v}`,['--counts=300','--scenarios=lifecycle','--warmup=120','--samples=300','--wall-seconds=600','--epoch-frames=0']);
 }
 await summarize();
 if(!pilot){
  await copyFile(`${dir}/report.md`,'docs/performance/cpu-improvements-report.md');await copyFile(`${dir}/summary.json`,'docs/performance/cpu-improvements-summary.json');
  await command('final-basic-verification',['tools/automation.mjs']);
  await command('exact-source-report-gate',['tools/automation.mjs','--check-report']);
  if(git(['rev-parse','HEAD'])!==head||git(['branch','--show-current'])!==branch)throw Error('Branch changed; results saved, automatic commit skipped');
  gitStep(['diff','--cached','--quiet']);
  const files=['docs/performance/cpu-improvements-report.md','docs/performance/cpu-improvements-summary.json'];
  log({operation:'publish-start',message:'Commit and push only the completed performance report',files});
  gitStep(['add','--',...files]);gitStep(['diff','--cached','--check']);
  gitStep(['commit','-m','docs: 记录四项CPU优化的对照测试结果']);gitStep(['push','origin','HEAD']);
  log({operation:'publish-finish',message:`Report pushed: ${git(['rev-parse','HEAD'])}`});
 }
 await writeFile(`${dir}/progress.json`,JSON.stringify({state:'completed',pid:process.pid,head,sourceDigest:source,runs:runs.length,pilot,finishedAt:new Date().toISOString()},null,2));log({operation:'completed',message:'CPU comparison complete; report.md and summary.json saved'});
}catch(error){log({operation:'failed',message:String(error.stack??error)});await writeFile(`${dir}/progress.json`,JSON.stringify({state:'failed',pid:process.pid,head,completedRuns:runs.length,error:String(error),at:new Date().toISOString()},null,2));process.exitCode=1;}
await writes;
