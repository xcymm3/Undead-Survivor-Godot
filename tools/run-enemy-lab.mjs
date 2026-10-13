import {spawn} from 'node:child_process';
import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {variants,candidates} from './enemy-lab-variants.mjs';
const dir=process.argv.find(a=>a.startsWith('--output-dir='))?.slice(13)??'artifacts/enemy-lab';await mkdir(dir,{recursive:true});
const pilot=process.argv.includes('--pilot');
let screen=variants.filter(v=>!['navigation','rays'].includes(v));
const from=process.argv.find(a=>a.startsWith('--from='))?.slice(7);if(from)screen=screen.slice(screen.indexOf(from));
const formalCounts=process.argv.find(a=>a.startsWith('--formal-counts='))?.slice(16)??'50,100,200,300';
if(!['300','50,100,200,300'].includes(formalCounts))throw Error('Unsupported formal matrix');
const resume=process.argv.includes('--resume');
const screenOnly=process.argv.includes('--screen-only');
const runs=resume?JSON.parse(await readFile(`${dir}/index.json`,'utf8')):[];
const cliStartedAt=new Date().toISOString();
let statusWrites=Promise.resolve();
function status(state,label,variant,progress=''){
 const value={state,pid:process.pid,startedAt:cliStartedAt,updatedAt:new Date().toISOString(),completedRuns:runs.length,label,variant,progress,formalCounts};
 statusWrites=statusWrites.then(()=>writeFile(`${dir}/progress.json`,JSON.stringify(value,null,2)));return statusWrites;
}
async function run(variant,label,options,regressions=false){
 const args=['tools/run-enemy-cpu-profile.mjs',`--variant=${variant}`,`--output=${dir.replace(/^artifacts\//,'')}/${label}`,'--control','--rounds=1',...options];
 if(regressions)args.push('--regressions');
 await status("running",label,variant);
 console.log(`LAB START ${label}: ${variant}; completed=${runs.length}`);
 const child=spawn(process.execPath,args,{windowsHide:true,stdio:['ignore','pipe','pipe']});
 let log='',partial='';
 function append(data){log+=data;partial+=data;const lines=partial.split('\n');partial=lines.pop();for(const line of lines)if(/CPU PROFILE START|CPU PROFILE PROGRESS|CPU PROFILE CASE|checks;|Error:|Frozen source/.test(line)) {console.log(line.trim());status("running",label,variant,line.trim());}}
 child.stdout.on('data',append);child.stderr.on('data',append);
 const code=await new Promise((resolve,reject)=>{child.on('close',resolve);child.on('error',reject);});
 await writeFile(`${dir}/${label}.log`,log);
 if(code!==0){await status("failed",label,variant,log.slice(-3000));throw Error(`Lab ${label} failed`);}
 const result=JSON.parse(await readFile(`${dir}/${label}/results.json`,'utf8'));
 if(result.failed||result.cases.some(c=>!c.valid)){await status("failed",label,variant,"Invalid cases");throw Error(`Invalid cases ${label}`);}
 runs.push({variant,label,source:result.source.sourceDigest});await writeFile(`${dir}/index.json`,JSON.stringify(runs,null,2));
 return result;
}
const scenarios=pilot?'movement,bridge,rifle':'movement,bridge,rifle,auto-shotgun,axe,visible,offscreen';
const screenOptions=[`--counts=${pilot?50:300}`,`--scenarios=${scenarios}`,`--warmup=${pilot?20:120}`,`--samples=${pilot?40:300}`];
if(!resume)for(let i=0;i<screen.length;i++){
 if(i>0&&i%4===0)await run('baseline',`screen-control-${i}`,screenOptions);
 await run(screen[i],`screen-${screen[i]}`,screenOptions,!pilot&&candidates.includes(screen[i]));
}
if(pilot){console.log('Pilot complete; no final performance claims.');process.exit(0);}
function quantile(values,p){const s=values.toSorted((a,b)=>a-b);return s[Math.min(s.length-1,Math.ceil(s.length*p)-1)];}
const baseline=JSON.parse(await readFile(`${dir}/screen-baseline/results.json`,'utf8'));
const ranking=[];
for(const variant of candidates){
 const data=JSON.parse(await readFile(`${dir}/screen-${variant}/results.json`,'utf8'));
 const ratios=data.cases.filter(c=>['movement','bridge','rifle'].includes(c.scenario)).map(c=>{
  const b=baseline.cases.find(b=>b.scenario===c.scenario);
  return quantile(c.samples.map(s=>s.cpu_sections_ms),.95)/quantile(b.samples.map(s=>s.cpu_sections_ms),.95);
 });
 ranking.push({variant,score:Math.exp(ratios.reduce((s,r)=>s+Math.log(r),0)/ratios.length)});
}
ranking.sort((a,b)=>a.score-b.score);
const finalists=[];for(const r of ranking){if(r.variant.startsWith('avoid')&&finalists.some(v=>v.startsWith('avoid')))continue;finalists.push(r.variant);if(finalists.length===2)break;}
const combo='combo:'+finalists.join('+');
if(!resume)await run(combo,'screen-combo',screenOptions,true);
await writeFile(`${dir}/selection.json`,JSON.stringify({ranking,finalists,criterion:'screen geometric mean P95 ratio; confirmation remains mandatory'},null,2));
console.log(`FINALISTS ${finalists.join(', ')}`);
if(screenOnly){console.log('SCREEN COMPLETE; long confirmation pending.');process.exit(0);}
// Scaling controls, then five paired long runs. No detailed probes in comparisons.
for(const variant of ['baseline',...finalists,combo])await run(variant,`scaling-${variant}`,[`--counts=${formalCounts==='300'?'50,100,200,500':'500'}`,'--scenarios=movement,bridge,rifle','--warmup=120','--samples=300']);
for(let round=1;round<=5;round++){
 const order=round%2?['baseline',...finalists,combo]:[combo,...finalists.toReversed(),'baseline'];
 for(const variant of order)await run(variant,`formal-${round}-${variant}`,[`--counts=${formalCounts}`,'--scenarios=movement,bridge,rifle','--warmup-seconds=10','--samples=300','--wall-seconds=60',...(round%2?[]:['--reverse-order'])]);
}
// Real mixed/summoning/churn paths, without forced position resets.
for(const variant of ['baseline',...finalists,combo])await run(variant,`dynamic-${variant}`,['--counts=300','--scenarios=mixed,boss,lifecycle','--warmup=120','--samples=300','--wall-seconds=60','--epoch-frames=0']);
for(const variant of ['baseline',combo])await run(variant,`endurance-${variant}`,['--counts=300','--scenarios=lifecycle','--warmup=120','--samples=300','--wall-seconds=600','--epoch-frames=0']);
// Attribution has its own instrumented run and never feeds the ranking.
await status('running','diagnostic-baseline','baseline');
console.log('LAB diagnostic baseline');
const child=spawn(process.execPath,['tools/run-enemy-cpu-profile.mjs','--variant=baseline',`--output=${dir.replace(/^artifacts\//,'')}/diagnostic-baseline`,'--details','--counts=300','--scenarios=movement,bridge,rifle','--warmup=120','--samples=300','--rounds=1'],{windowsHide:true,stdio:['ignore','pipe','pipe']});
let log='';child.stdout.on('data',d=>{log+=d;process.stdout.write(d);});child.stderr.on('data',d=>{log+=d;process.stderr.write(d);});
if(await new Promise((resolve,reject)=>{child.on('close',resolve);child.on('error',reject);})!==0)throw Error('Diagnostic failed');
await writeFile(`${dir}/diagnostic.log`,log);
await writeFile(`${dir}/complete.json`,JSON.stringify({completedAt:new Date().toISOString(),finalists,runs:runs.length,sourceDigest:runs[0].source,formalCounts:formalCounts.split(',').map(Number),gpu:false},null,2));
await status('completed','complete','',`CPU lab complete; ${runs.length} comparison runs plus diagnostic`);
console.log('LAB COMPLETE: CPU only; isolated GPU unavailable.');
