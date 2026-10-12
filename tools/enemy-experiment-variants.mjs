// Experimental changes are applied ONLY to a frozen temporary project.
import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
export const variants = ['baseline', 'navigation', 'rays', 'animation'];
export async function applyVariant(root, variant) {
  if (!variants.includes(variant)) throw new Error(`Unknown variant: ${variant}`);
  const changed = [];
  async function edit(name, transform) {
    const filename = path.join(root, name);
    const before = (await readFile(filename, 'utf8')).replaceAll('\r\n', '\n');
    const after = transform(before);
    if (after === before) throw new Error(`Patch did not change ${name}`);
    await writeFile(filename, after);
    changed.push(name);
  }
  function replace(source, before, after) {
    if (!source.includes(before)) throw new Error(`Patch anchor missing: ${before.slice(0,100)}`);
    return source.replace(before, after);
  }
  if (variant === 'navigation') {
    await edit('scripts/arena.gd', s => {
      s = replace(s, 'var navigation_structures: Array = []', 'var navigation_structures: Array = []\nvar experiment_routes: Dictionary = {}\nvar experiment_epoch = 0');
      s = replace(s, '\t\tnavigation_structures = active', '\t\tnavigation_structures = active\n\t\texperiment_routes.clear()\n\t\texperiment_epoch += 1');
      return s + `
# Cache the reverse suffix tree of actual A* routes, per exact goal cell.
# This avoids a synchronous whole-map flow-field construction spike.
func experiment_path(a: Vector2, b: Vector2) -> PackedVector2Array:
\tvar start = nearest_cell(a)
\tvar end = nearest_cell(b)
\tif start.x < 0 or end.x < 0: return PackedVector2Array()
\tif not experiment_routes.has(end): experiment_routes[end] = {}
\tvar tree: Dictionary = experiment_routes[end]
\tvar route = PackedVector2Array()
\tif tree.has(start):
\t\tvar cell = start
\t\tvar remaining = grid.region.size.x*grid.region.size.y
\t\twhile remaining > 0:
\t\t\troute.append(grid.get_point_position(cell))
\t\t\tif cell == end: break
\t\t\tif not tree.has(cell): return path_to(a,b)
\t\t\tcell = tree[cell]
\t\t\tremaining -= 1
\telse:
\t\tvar ids = grid.get_id_path(start,end)
\t\tfor i in ids.size():
\t\t\troute.append(grid.get_point_position(ids[i]))
\t\t\tif i+1 < ids.size() and not tree.has(ids[i]): tree[ids[i]] = ids[i+1]
\tif not route.is_empty() and clear(route[-1],b): route.append(b)
\treturn route
`;
    });
    await edit('scripts/simulation.gd', s => {
      s = replace(s, 'var crowd_buckets: Dictionary = {}', 'var crowd_buckets: Dictionary = {}\nvar experiment_targets: Dictionary = {}');
      s = replace(s, 'func choose_zombie_target(z: Dictionary, living: Array) -> Dictionary:', `func choose_zombie_target(z: Dictionary, living: Array) -> Dictionary:
\tvar old: Dictionary = experiment_targets.get(z.id,{})
\tif not old.is_empty() and old.epoch == arena.experiment_epoch and elapsed < old.until:
\t\tvar current: Dictionary = target_by_id(str(old.id))
\t\tif not current.is_empty() and current.hp > 0 and z.pos.distance_squared_to(current.pos) > 144:
\t\t\tif current.get("is_structure",false):
\t\t\t\tcurrent = defense_director.structures.target(defense_director.structures.find(str(old.id)),z.pos)
\t\t\treturn current
\tvar result = experiment_choose_target(z,living)
\texperiment_targets[z.id] = {"id":result.id,"epoch":arena.experiment_epoch,"until":elapsed+.1+fmod(z.id*.013,.1)}
\treturn result

func experiment_choose_target(z: Dictionary, living: Array) -> Dictionary:`);
      s = replace(s, 'cached.path = arena.path_to(z.pos,goal)', 'cached.path = arena.experiment_path(z.pos,goal) if stop_at_waypoint else arena.path_to(z.pos,goal)');
      s = replace(s, '\tfor y in range(-1,2):\n\t\tfor x in range(-1,2):\n\t\t\tfor other in crowd_buckets.get(cell+Vector2i(x,y),[]):', `\tvar examined = 0
\tfor y in range(-1,2):
\t\tfor x in range(-1,2):
\t\t\tvar bucket: Array = crowd_buckets.get(cell+Vector2i(x,y),[])
\t\t\tfor j in mini(4,bucket.size()):
\t\t\t\tif examined >= 32: break
\t\t\t\texamined += 1
\t\t\t\tvar other: Dictionary = bucket[(j+int(z.id))%bucket.size()]`);
      return replace(s, 'separation.limit_length(.75)', 'separation.limit_length(.3 if crowd_buckets.get(cell,[]).size() > 20 else .75)');
    });
  }
  if (variant === 'rays') {
    await writeFile(path.join(root, 'scripts/experiment_reference_enemy_view.gd'), await readFile(path.join(root, 'scripts/enemy_view.gd')));
    changed.push('scripts/experiment_reference_enemy_view.gd');
    await writeFile(path.join(root, 'scripts/experiment_ray_grid.gd'), `extends RefCounted
const CELL = 6.0
var buckets: Dictionary = {}
var zombies: Array
var radius = 0.0
func _init(items: Array) -> void:
\tzombies = items
\tfor i in items.size():
\t\tvar z: Dictionary = items[i]
\t\tif z.hp <= 0: continue
\t\tradius = maxf(radius,1.5*Data.enemy_scale(z.kind))
\t\tvar cell = Vector2i(floori(z.pos.x/CELL),floori(z.pos.y/CELL))
\t\tif not buckets.has(cell): buckets[cell] = []
\t\tbuckets[cell].append(i)
func query(origin: Vector3, direction: Vector3, distance: float) -> Array:
\tvar start = Vector2(origin.x,origin.z)
\tvar delta = Vector2(direction.x,direction.z)*distance
\tvar steps = maxi(1,ceili(delta.length()/(CELL*.5)))
\tvar reach = ceili((radius+CELL*.5)/CELL)
\tvar visited: Dictionary = {}
\tvar selected: Dictionary = {}
\tfor i in steps+1:
\t\tvar p = start+delta*(float(i)/steps)
\t\tvar center = Vector2i(floori(p.x/CELL),floori(p.y/CELL))
\t\tfor y in range(-reach,reach+1):
\t\t\tfor x in range(-reach,reach+1):
\t\t\t\tvar cell = center+Vector2i(x,y)
\t\t\t\tif visited.has(cell): continue
\t\t\t\tvisited[cell] = true
\t\t\t\tfor index in buckets.get(cell,[]): selected[index] = true
\tvar indices = selected.keys()
\tindices.sort()
\tvar result: Array = []
\tfor i in indices: result.append(zombies[i])
\treturn result
`);
    changed.push('scripts/experiment_ray_grid.gd');
    await edit('scripts/enemy_view.gd', s => {
      s = replace(s, 'static func hit(z:', 'static var experiment_pose_time = -INF\nstatic var experiment_poses: Dictionary = {}\n\nstatic func hit(z:');
      return replace(s, '\tvar poses = transforms(z,elapsed,stationary)', `\tif elapsed != experiment_pose_time:
\t\texperiment_pose_time = elapsed
\t\texperiment_poses.clear()
\tvar cached: Dictionary = experiment_poses.get(z.id,{})
\tif cached.get("state",{}) != z or cached.get("stationary",not stationary) != stationary:
\t\tcached = {"state":z.duplicate(),"stationary":stationary,"poses":transforms(z,elapsed,stationary)}
\t\texperiment_poses[z.id] = cached
\tvar poses = cached.poses`);
    });
    await edit('scripts/simulation.gd', s => {
      const start = s.indexOf('func fire(p:');
      const end = s.indexOf('\nfunc shotgun_damage_scale', start);
      let fire = s.slice(start,end);
      fire = replace(fire, '\tvar closest = camera.origin.distance_to(target)', '\tvar ray_grid = load("res://scripts/experiment_ray_grid.gd").new(zombies)\n\tvar closest = camera.origin.distance_to(target)');
      fire = replace(fire, 'for z in zombies:', 'for z in ray_grid.query(camera.origin,forward,closest):');
      fire = replace(fire, 'for z in zombies:', 'for z in ray_grid.query(muzzle,ray,distance):');
      return s.slice(0,start)+fire+s.slice(end);
    });
    await edit('tools/profile-enemy-cpu.gd', s => replace(s, '\t\tfor z in sim.zombies:\n\t\t\tif z.hp <= 0: continue\n\t\t\tvar hit = enemy_view.hit', '\t\tvar ray_grid = load("res://scripts/experiment_ray_grid.gd").new(sim.zombies)\n\t\tfor z in ray_grid.query(camera.origin,direction,distance):\n\t\t\tif z.hp <= 0: continue\n\t\t\tvar hit = enemy_view.hit'));
  }
  if (variant === 'animation') {
    await edit('scripts/enemy_view.gd', s => {
      s = replace(s, 'var actors: Dictionary = {}', 'var actors: Dictionary = {}\nvar experiment_camera = Transform3D.IDENTITY\nvar experiment_camera_enabled = false');
      const before = '\t\tvar state = pose_state(z,elapsed,stationary)\n\t\tactor.body.transform = state.root\n\t\tactor.view.mesh = mesh_for(z.kind,int(z.id)%4,z.rage,z.armor > 0,int(z.get("outfit",-1)))';
      return replace(s, before, `\t\tvar mesh_key = [z.kind,int(z.id)%4,z.rage,z.armor > 0,int(z.get("outfit",-1))]
\t\tif actor.get("experiment_mesh_key",[]) != mesh_key:
\t\t\tactor.view.mesh = mesh_for(z.kind,int(z.id)%4,z.rage,z.armor > 0,int(z.get("outfit",-1)))
\t\t\tactor["experiment_mesh_key"] = mesh_key
\t\tvar point = Vector3(z.pos.x,Data.enemy_ground_height(z.pos,z.get("map_id","graypine_defense"))+1.4,z.pos.y)
\t\tvar local = experiment_camera.affine_inverse()*point
\t\tvar margin = 3.0*Data.enemy_scale(z.kind)
\t\tvar visible = not experiment_camera_enabled or (local.z < margin and absf(local.x) < -local.z*1.048+margin and absf(local.y) < -local.z*.589+margin)
\t\tvar distance = point.distance_to(experiment_camera.origin)
\t\tvar hz = 60 if not experiment_camera_enabled or distance < 15 else 30 if distance < 40 else 15
\t\tvar tick = floori(elapsed*hz)
\t\tif not visible:
\t\t\tactor.body.transform = crawl_pose(z,elapsed,stationary).root if z.kind == "crawler" else root_transform(z,elapsed,stationary,sin(z.get("gait",0.0)))
\t\t\tcontinue
\t\tif actor.get("experiment_tick",-1) == tick and actor.get("experiment_hz",0) == hz:
\t\t\tactor.body.transform = crawl_pose(z,elapsed,stationary).root if z.kind == "crawler" else root_transform(z,elapsed,stationary,sin(z.get("gait",0.0)))
\t\t\tcontinue
\t\tactor["experiment_tick"] = tick
\t\tactor["experiment_hz"] = hz
\t\tvar state = pose_state(z,elapsed,stationary)
\t\tactor.body.transform = state.root`);
    });
    await edit('tools/profile-enemy-cpu.gd', s => replace(s, '\t\tgame.enemies.sync(sim.zombies,sim.elapsed,false)', '\t\tgame.enemies.experiment_camera = camera\n\t\tgame.enemies.experiment_camera_enabled = true\n\t\tgame.enemies.sync(sim.zombies,sim.elapsed,false)'));
  }
  return changed;
}

// Diagnostic probes are separate from the uninstrumented A/B experiment.
export async function applyDiagnosticDetails(root) {
  const simulation = path.join(root,'scripts/simulation.gd');
  let s = (await readFile(simulation,'utf8')).replaceAll('\r\n','\n');
  s = s.replace('var crowd_buckets: Dictionary = {}','var crowd_buckets: Dictionary = {}\nvar experiment_detail: Dictionary = {}');
  s = s.replace('func step(dt: float) -> void:\n\tevents.clear()', 'func step(dt: float) -> void:\n\texperiment_detail.clear()\n\tevents.clear()');
  s = s.replace(/^(\t\t\t)cached.path = (.+)$/m, '$1var experiment_path_before = Time.get_ticks_usec()\n$1cached.path = $2\n$1experiment_record_detail("astar_or_shared_route",experiment_path_before)');
  s = s.replace('\tvar separation = Vector2.ZERO','\tvar experiment_avoid_before = Time.get_ticks_usec()\n\tvar separation = Vector2.ZERO');
  s = s.replace('\tvar route_direction = direction','\texperiment_record_detail("neighbor_avoidance",experiment_avoid_before)\n\tvar route_direction = direction');
  s += '\nfunc experiment_record_detail(label: String, started: int) -> void:\n\texperiment_detail[label] = experiment_detail.get(label,0)+Time.get_ticks_usec()-started\n';
  await writeFile(simulation,s);
  const view = path.join(root,'scripts/enemy_view.gd');
  s = (await readFile(view,'utf8')).replaceAll('\r\n','\n');
  s = s.replace('var actors: Dictionary = {}','var actors: Dictionary = {}\nvar experiment_animation_detail: Dictionary = {}');
  s = s.replace('func sync(zombies: Array, elapsed: float, stationary: bool) -> void:', 'func sync(zombies: Array, elapsed: float, stationary: bool) -> void:\n\texperiment_animation_detail = {"pose_mesh":0,"bone_submit":0}');
  s = s.replace('\t\tvar state = pose_state(z,elapsed,stationary)','\t\tvar experiment_pose_before = Time.get_ticks_usec()\n\t\tvar state = pose_state(z,elapsed,stationary)');
  s = s.replace('\t\tfor j in 7: actor.skeleton.set_bone_pose(j,state.bones[j])','\t\texperiment_animation_detail.pose_mesh += Time.get_ticks_usec()-experiment_pose_before\n\t\tvar experiment_submit_before = Time.get_ticks_usec()\n\t\tfor j in 7: actor.skeleton.set_bone_pose(j,state.bones[j])');
  s = s.replace('\t\tactor.skeleton.force_update_all_bone_transforms()','\t\tactor.skeleton.force_update_all_bone_transforms()\n\t\texperiment_animation_detail.bone_submit += Time.get_ticks_usec()-experiment_submit_before');
  await writeFile(view,s);
  return ['scripts/simulation.gd','scripts/enemy_view.gd'];
}
