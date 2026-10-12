import { spawn } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const output = path.join(root, 'artifacts/enemy-experiments');
await mkdir(output, { recursive: true });
// Serial AB ... BA order: CPU contention between experiments would invalidate A/B.
const order = ['baseline','navigation','rays','animation','animation','rays','navigation','baseline'];
for (let index = 0; index < order.length; index++) {
  const variant = order[index];
  const round = index < 4 ? 1 : 2;
  const args = ['tools/run-enemy-cpu-profile.mjs',`--variant=${variant}`,`--output=enemy-experiments/${variant}-${round}`,'--control','--counts=50,100,200,300','--scenarios=movement,bridge,rifle,auto-shotgun','--warmup=60','--samples=180','--rounds=1'];
  if (round === 1) args.push('--regressions');
  if (round === 2) args.push('--reverse-order');
  console.log(`EXPERIMENT ${index+1}/${order.length}: ${variant} round ${round}`);
  const child = spawn(process.execPath,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
  let log = '';
  let partial = '';
  const append = data => {
    log += data;
    partial += data;
    const lines = partial.split('\n');
    partial = lines.pop();
    for (const line of lines) if (/CPU PROFILE CASE|checks;|Frozen source|saved:|Error:/.test(line)) console.log(line.trim());
  };
  child.stdout.on('data',append); child.stderr.on('data',append);
  const code = await new Promise((resolve,reject) => { child.on('error',reject); child.on('close',resolve); });
  await writeFile(path.join(output,`${variant}-${round}.log`),log);
  if (code !== 0) throw new Error(`${variant} round ${round} failed; see log`);
}
if (process.argv.includes('--diagnostics')) {
  for (const variant of ['baseline','navigation','rays','animation']) {
    console.log(`DIAGNOSTIC: ${variant}`);
    const args = ['tools/run-enemy-cpu-profile.mjs',`--variant=${variant}`,`--output=enemy-experiments/diagnostic-${variant}`,'--details','--counts=300','--scenarios=movement,bridge,rifle,auto-shotgun','--warmup=60','--samples=180','--rounds=1'];
    const child = spawn(process.execPath,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
    let log = '';
    child.stdout.on('data',data=>{log+=data; process.stdout.write(data);});
    child.stderr.on('data',data=>{log+=data; process.stderr.write(data);});
    const code = await new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',resolve);});
    await writeFile(path.join(output,`diagnostic-${variant}.log`),log);
    if (code !== 0) throw new Error(`${variant} diagnostic failed`);
  }
}
console.log('Independent CPU experiments finished. GPU measurement is deferred pending isolated hardware.');
