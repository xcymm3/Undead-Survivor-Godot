import {spawn} from 'node:child_process';
import {mkdir,appendFile,writeFile,readFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const controllerRoot=path.dirname(fileURLToPath(import.meta.url));
const args=process.argv.slice(2);
const dir=args.find(a=>a.startsWith('--output-dir='))?.slice(13)??'artifacts/enemy-lab-cli';
await mkdir(dir,{recursive:true});
await writeFile(path.join(dir,'cli.json'),JSON.stringify({pid:process.pid,startedAt:new Date().toISOString(),args},null,2));
let writes=Promise.resolve();
function emit(data){process.stdout.write(data);writes=writes.then(()=>appendFile(path.join(dir,'cli.log'),data));}
async function run(script,options){
 const child=spawn(process.execPath,[path.join(controllerRoot,path.basename(script)),...options],{windowsHide:true,stdio:['ignore','pipe','pipe']});
 child.stdout.on('data',emit);child.stderr.on('data',emit);
 return await new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',resolve);});
}
let code=await run('tools/run-enemy-lab.mjs',[...args,`--output-dir=${dir}`]);
if(code===0)code=await run('tools/summarize-enemy-lab.mjs',[`--output-dir=${dir}`]);
await writes;
const current=JSON.parse(await readFile(path.join(dir,'progress.json'),'utf8'));
await writeFile(path.join(dir,'progress.json'),JSON.stringify({...current,state:code===0?'completed':'failed',exitCode:code,finishedAt:new Date().toISOString()},null,2));
process.exitCode=code??1;
