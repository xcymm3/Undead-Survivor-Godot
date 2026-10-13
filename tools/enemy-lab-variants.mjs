import {readFile,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {applyVariant as legacy,applyDiagnosticDetails as legacyDetails} from './enemy-experiment-variants.mjs';

export const variants=['baseline','navigation','rays','animation','mesh_cache','no_submit','no_pose','bones5','bones1','avoid16','avoid32','no_avoid','shared_path','target_rate','ray_grid','pose_cache','pool'];
export const candidates=['mesh_cache','animation','avoid16','avoid32','shared_path','target_rate','ray_grid','pose_cache','pool'];
export async function applyVariant(root,variant){
 if(variant.startsWith('combo:')){
  let names=variant.slice(6).split('+');
  if(names.includes('ray_grid')&&names.includes('pose_cache'))names=[...names.filter(n=>!['ray_grid','pose_cache'].includes(n)),'rays'];
  names.sort((a,b)=>(a==='animation'?-2:a==='shared_path'?-1:0)-(b==='animation'?-2:b==='shared_path'?-1:0));
  const result=[];for(const name of names)result.push(...await applyVariant(root,name));return [...new Set(result)];
 }
 if(!variants.includes(variant))throw Error(`Unknown variant ${variant}`);
 if(['baseline','navigation','rays'].includes(variant))return legacy(root,variant);
 const files=[];
 const read=async n=>(await readFile(path.join(root,n),'utf8')).replaceAll('\r\n','\n');
 const save=async(n,s)=>{await writeFile(path.join(root,n),s);if(!files.includes(n))files.push(n);};
 const replace=(s,a,b)=>{if(!s.includes(a))throw Error(`Missing patch anchor ${a.slice(0,80)}`);return s.replace(a,b);};
 if(variant==='animation'){
  const result=await legacy(root,'animation');
  let s=await read('scripts/enemy_view.gd');
  const a=s.indexOf('\t\tvar mesh_key ='),b=s.indexOf('\t\tvar point = Vector3',a);
  s=s.slice(0,a)+'\t\tactor.view.mesh = mesh_for(z.kind,int(z.id)%4,z.rage,z.armor > 0,int(z.get("outfit",-1)))\n'+s.slice(b);
  await save('scripts/enemy_view.gd',s);return result;
 }
 if(['ray_grid','pose_cache'].includes(variant)){
  const originalView=await read('scripts/enemy_view.gd'), originalSim=await read('scripts/simulation.gd'),originalProfile=await read('tools/profile-enemy-cpu.gd');
  files.push(...await legacy(root,'rays'));
  if(variant==='ray_grid')await save('scripts/enemy_view.gd',originalView);
  else{await save('scripts/simulation.gd',originalSim);await save('tools/profile-enemy-cpu.gd',originalProfile);}
  return files;
 }
 if(variant==='shared_path'){
  const originalSim=await read('scripts/simulation.gd');
  files.push(...await legacy(root,'navigation'));
  await save('scripts/simulation.gd',replace(originalSim,'cached.path = arena.path_to(z.pos,goal)','cached.path = arena.experiment_path(z.pos,goal) if stop_at_waypoint else arena.path_to(z.pos,goal)'));
  return files;
 }
 if(variant==='target_rate'){
  let s=await read('scripts/simulation.gd');
  s=replace(s,'var crowd_buckets: Dictionary = {}','var crowd_buckets: Dictionary = {}\nvar experiment_targets: Dictionary = {}');
  const wrapper=`func choose_zombie_target(z: Dictionary, living: Array) -> Dictionary:
\tvar old: Dictionary = experiment_targets.get(z.id,{})
\tif not old.is_empty() and old.epoch == arena.experiment_epoch and elapsed < old.until:
\t\tvar current: Dictionary = target_by_id(str(old.id))
\t\tif not current.is_empty() and current.hp > 0 and (current.get("is_structure",false) or current.get("is_crystal",false)) and z.pos.distance_squared_to(current.pos) > 144 and living.all(func(p): return z.pos.distance_squared_to(p.pos) > 225):
\t\t\tif current.get("is_structure",false): current = defense_director.structures.target(defense_director.structures.find(str(old.id)),z.pos)
\t\t\treturn current
\tvar result = experiment_choose_target(z,living)
\texperiment_targets[z.id] = {"id":result.id,"epoch":arena.experiment_epoch,"until":elapsed+.1+fmod(z.id*.013,.1)}
\treturn result

func experiment_choose_target(z: Dictionary, living: Array) -> Dictionary:`;
  await save('scripts/simulation.gd',replace(s,'func choose_zombie_target(z: Dictionary, living: Array) -> Dictionary:',wrapper));
  let arena=await read('scripts/arena.gd');
  if(!arena.includes('var experiment_epoch'))await save('scripts/arena.gd',replace(replace(arena,'var navigation_structures: Array = []','var navigation_structures: Array = []\nvar experiment_epoch = 0'),'\t\tnavigation_structures = active','\t\tnavigation_structures = active\n\t\texperiment_epoch += 1'));
  return files;
 }
 if(variant.startsWith('avoid')||variant==='no_avoid'){
  let s=await read('scripts/simulation.gd');
  const a=s.indexOf('\tfor y in range(-1,2):',s.indexOf('func move_zombie(')),b=s.indexOf('\tvar route_direction = direction',a);
  if(variant==='no_avoid')s=s.slice(0,a)+s.slice(b);
  else{
   const limit=Number(variant.slice(5));
   const old=s.slice(a,b);
   let body=replace(old,'\tfor y in range(-1,2):','\tvar examined = 0\n\tfor y in range(-1,2):');
   body=replace(body,'\t\t\tfor other in crowd_buckets.get(cell+Vector2i(x,y),[]):',`\t\t\tvar bucket: Array = crowd_buckets.get(cell+Vector2i(x,y),[])\n\t\t\tfor j in mini(${limit===16?2:4},bucket.size()):\n\t\t\t\tif examined >= ${limit}: break\n\t\t\t\texamined += 1\n\t\t\t\tvar other: Dictionary = bucket[(j+int(z.id))%bucket.size()]`);
   s=s.slice(0,a)+body+s.slice(b);
  }
  await save('scripts/simulation.gd',s);return files;
 }
 let s=await read('scripts/enemy_view.gd');
 const mesh='\t\tactor.view.mesh = mesh_for(z.kind,int(z.id)%4,z.rage,z.armor > 0,int(z.get("outfit",-1)))';
 const submit='\t\tfor j in 7: actor.skeleton.set_bone_pose(j,state.bones[j])\n\t\tactor.skeleton.force_update_all_bone_transforms()';
 if(variant==='mesh_cache')s=replace(s,mesh,'\t\tvar key = [z.kind,int(z.id)%4,z.rage,z.armor > 0,int(z.get("outfit",-1))]\n\t\tif actor.get("mesh_key",[]) != key:\n\t\t\tactor["mesh_key"] = key\n'+mesh.replace('\t\t','\t\t\t'));
 if(variant==='no_submit')s=replace(s,submit,'\t\t# Diagnostic only: omit bone submission, retain full pose calculation.');
 if(variant==='no_pose')s=replace(s,'\t\tvar state = pose_state(z,elapsed,stationary)','\t\tvar state = {"root":root_transform(z,elapsed,stationary,0.0),"bones":[Transform3D.IDENTITY,Transform3D.IDENTITY,Transform3D.IDENTITY,Transform3D.IDENTITY,Transform3D.IDENTITY,Transform3D.IDENTITY,Transform3D.IDENTITY]}');
 if(variant==='bones5'||variant==='bones1'){
  const count=variant==='bones5'?5:1;
  s=s.replace('for part in 7:','for part in '+count+':').replaceAll('for j in 7:',`for j in ${count}:`).replace('PackedInt32Array([6,0,0,0])','PackedInt32Array([0,0,0,0])');
  if(count===1){const start=s.indexOf('static func pose_state(');s=s.slice(0,start)+replace(s.slice(start),'\tvar attack_advancing: bool =','\tif true: return {"root":root_transform(z,elapsed,stationary,sin(z.get("gait",0.0))),"bones":[Transform3D.IDENTITY]}\n\tvar attack_advancing: bool =');}
  s=replace(s,'static func bone_for(part: Dictionary) -> int:',`static func bone_for(part: Dictionary) -> int:\n\tif ${count} == 1 or part.get("head",false) or part.get("shield",false): return 0`);
 }
 if(variant==='pool'){
  s=replace(s,'var actors: Dictionary = {}','var actors: Dictionary = {}\nvar experiment_pool: Array = []');
  s=replace(s,'func create_actor(z: Dictionary) -> Dictionary:','func create_actor(z: Dictionary) -> Dictionary:\n\tif not experiment_pool.is_empty():\n\t\tvar actor: Dictionary = experiment_pool.pop_back()\n\t\tactor.body.show()\n\t\treturn actor');
  s=replace(s,'\tactor.body.queue_free()','\texperiment_pool.append(actor)');
 }
 await save('scripts/enemy_view.gd',s);return files;
}

export async function applyDiagnosticDetails(root){
 const files=await legacyDetails(root);
 const file=path.join(root,'scripts/simulation.gd');
 let s=(await readFile(file,'utf8')).replaceAll('\r\n','\n');
 s=s.replace('var experiment_detail: Dictionary = {}','var experiment_detail: Dictionary = {}\nvar experiment_count: Dictionary = {}');
 s=s.replace('\texperiment_detail.clear()','\texperiment_detail.clear()\n\texperiment_count = {"astar":0,"neighbors":0}');
 s=s.replace('\t\t\tvar experiment_path_before = Time.get_ticks_usec()','\t\t\texperiment_count.astar += 1\n\t\t\tvar experiment_path_before = Time.get_ticks_usec()');
 s=s.replace('\t\t\tfor other in crowd_buckets.get(cell+Vector2i(x,y),[]):','\t\t\tvar experiment_bucket: Array = crowd_buckets.get(cell+Vector2i(x,y),[])\n\t\t\texperiment_count.neighbors += experiment_bucket.size()\n\t\t\tfor other in experiment_bucket:');
 await writeFile(file,s);return files;
}
