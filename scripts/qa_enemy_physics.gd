extends Node
## Browser-only staging. The normal authority loop performs movement and combat.
const Body = preload("res://scripts/enemy_body.gd")
var game
var scenario = ""
var active = false
var clock = 0.0
var sample_clock = 0.0
var samples: Array = []
var simulation_samples: Array = []
var issues: Array = []
var queue: Array = []
var combat: Array = []
var fixture: Dictionary = {}
var initial: Dictionary = {}
var rear_attempts = 0
var rear_attacks = 0
var attacks = 0
var movement = 0.0
var death_report: Dictionary = {}
var dead: Dictionary = {}
var neighbour: Dictionary = {}
var neighbour_start = Vector2.ZERO
var free_stall: Dictionary = {}

func _ready() -> void:
	if not Data.automation or not OS.has_feature("web") or "--qa-enemy-physics" not in OS.get_cmdline_user_args():
		queue_free()
		return
	scenario = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('crowdCase')",true))
	if scenario not in ["50","100","200","combat","death","entries"]:
		queue_free()
		return
	call_deferred("stage")

func stage() -> void:
	game.start_solo("defense",42)
	await get_tree().physics_frame
	var sim = game.sim
	sim.roster.clear()
	sim.defense.started = true
	sim.defense.waiting = false
	sim.pawns.solo.pos = Vector2(0,48)
	sim.pawns.solo.height = 3
	sim.pawns.solo.protection = 1000
	for item in sim.defense.structures:
		if item.kind == "turret": item.cooldown = 1000
		if item.kind == "mine": item.spent = true
	if scenario == "combat":
		for kind in ["normal","giant","imp","crawler"]:
			for target in ["bridge_gate","turret_left","crystal","solo"]:
				if target == "solo" and kind in ["giant","imp"]: continue
				queue.append({"kind":kind,"target":target})
		next_combat()
	elif scenario == "death":
		sim.spawn(Vector2(0,20),"normal")
		dead = sim.zombies[-1]
		sim.spawn(Vector2(.84,20),"normal")
		neighbour = sim.zombies[-1]
		neighbour.state = "stunned"
		neighbour.state_time = 100
		dead.state = "stunned"
		dead.state_time = 100
	elif scenario == "entries":
		# All five real spawn positions exercise the cliff entrance and bridge.
		# Keep the destination intact for the entire path observation window.
		sim.defense_director.structures.find("bridge_gate").hp = 1000000
		for kind in ["normal","giant","imp","crawler"]:
			for point in sim.map_definition.spawns:
				var index = ["normal","giant","imp","crawler"].find(kind)
				var p: Vector2 = point+Vector2(-.9 if index%2 == 0 else .9,0 if index < 2 else 2)
				var navigation = game.arena.enemy_grid(kind)
				var cell = game.arena.enemy_cell(navigation,p)
				if cell.x >= 0: p = navigation.get_point_position(cell)
				sim.spawn(p,kind)
				initial[sim.zombies[-1].id] = p
	else:
		# Increased durability isolates sustained congestion; normal 1000-HP
		# gate destruction is covered by the separate structure browser test.
		sim.defense_director.structures.find("bridge_gate").hp = 1000000
		var kinds: Array = Data.enemies.keys()
		for i in int(scenario):
			var p = Vector2((i%5-2)*1.45,-13-floori(i/5)*1.6)
			sim.spawn(p,kinds[i%kinds.size()])
			initial[sim.zombies[-1].id] = p
	game.arena.sync_defense(sim.defense)
	game.ui.root.visible = false
	game.weapon.visible = false
	active = true

func next_combat() -> void:
	var sim = game.sim
	sim.zombies.clear()
	sim.sync_enemy_bodies()
	fixture = queue.pop_front().duplicate()
	fixture.time = 0.0
	sim.pawns.solo.protection = 0.0
	sim.pawns.solo.hp = 100
	sim.pawns.solo.pos = Vector2(0,48)
	sim.pawns.solo.height = 3
	sim.defense.crystal_hp = 1500
	var manager = sim.defense_director.structures
	manager.find("bridge_gate").hp = 1000
	manager.find("turret_left").hp = 200
	var p = Vector2.ZERO
	if fixture.target == "bridge_gate": p = Vector2(0,-14)
	elif fixture.target == "turret_left": p = manager.find("turret_left").pos+Vector2(0,4)
	elif fixture.target == "crystal": p = Vector2(0,42)
	else:
		sim.pawns.solo.pos = Vector2(0,25)
		p = Vector2(0,21)
	game.arena.sync_defense(sim.defense)
	sim.spawn(p,fixture.kind)
	fixture.id = sim.zombies[-1].id
	fixture.initial_hp = target_hp()

func target_hp() -> float:
	if fixture.target == "solo": return game.sim.pawns.solo.hp
	if fixture.target == "crystal": return game.sim.defense.crystal_hp
	return game.sim.defense_director.structures.find(fixture.target).hp

func check_geometry() -> void:
	var sim = game.sim
	for z in sim.zombies:
		if z.hp <= 0: continue
		var body = sim.enemy_bodies[z.id]
		var shape = body.collider.shape.duplicate()
		shape.radius -= .025
		shape.height -= .05
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = body.collider.global_transform
		query.transform.origin.y += .005
		query.exclude = [body.get_rid(),body.peer_rid]
		query.collision_mask = 9
		for hit in game.arena.get_world_3d().direct_space_state.intersect_shape(query,3):
			if issues.size() < 20: issues.append({"time":clock,"id":z.id,"kind":z.kind,"other":str(hit.collider.name),"pos":str(z.pos),"height":z.height})
		if z.height < -.25 or not sim.map_definition.bounds.has_point(z.pos):
			if issues.size() < 20: issues.append({"time":clock,"id":z.id,"void":true,"pos":str(z.pos),"height":z.height})
		if scenario in ["50","100","200"] and z.pos.y > -10.01:
			if issues.size() < 20: issues.append({"time":clock,"id":z.id,"gate_bypass":true})
		var target: Dictionary = sim.choose_zombie_target(z,sim.pawns.values())
		var contact: float = maxf(Data.contact(z.kind),2.3) if target.get("is_crystal",false) else sim.defense_director.structures.contact_radius(target,z.kind) if target.get("is_structure",false) else Data.contact(z.kind)
		var requesting: float = z.get("desired_speed",0.0)
		var missing_route = requesting < .1 and sim.paths.get(z.id,{}).get("path",PackedVector2Array()).is_empty()
		# Being pressed against a wall is legitimate only in a real queue.
		# An isolated actor stuck on scenery must still fail navigation QA.
		var crowded_wall = z.get("world_blocked",false) and body.overlaps(8,-.35)
		var free_motion = requesting >= .1 and not z.get("crowd_blocked",false) and not crowded_wall
		var idle = z.state == "ready" and z.attack_time <= 0 and (missing_route or free_motion) and z.get("move_speed",0.0) < .05 and z.pos.distance_to(target.pos) > contact+.3
		free_stall[z.id] = free_stall.get(z.id,0.0)+.25 if idle else 0.0
		if free_stall[z.id] > 2 and issues.size() < 20:
			issues.append({"time":clock,"id":z.id,"navigation_stall":true,"pos":str(z.pos),"target":target.id,"requested":requesting,"route_size":sim.paths.get(z.id,{}).get("path",PackedVector2Array()).size(),"world_blocked":z.get("world_blocked",false)})

func _physics_process(dt: float) -> void:
	if not active: return
	clock += dt
	var sim = game.sim
	var done = false
	if scenario == "combat":
		fixture.time += dt
		if target_hp() < fixture.initial_hp or fixture.time > 7:
			fixture.damage = fixture.initial_hp-target_hp()
			fixture.targeted = sim.zombies[0].target
			fixture.position = str(sim.zombies[0].pos)
			fixture.height = sim.zombies[0].height
			combat.append(fixture.duplicate())
			if queue.is_empty(): done = true
			else: next_combat()
	elif scenario == "death":
		if clock > .3 and death_report.is_empty():
			neighbour_start = neighbour.pos
			var body = sim.enemy_bodies[dead.id]
			sim.hit_enemy(dead,10000,false,sim.pawns.solo,body.position)
			death_report = {"layer":body.collision_layer,"mask":body.collision_mask,"peer_layer":PhysicsServer3D.body_get_collision_layer(body.peer_rid),"disabled":body.collider.disabled,"down":dead.down}
		if clock > 1.4:
			death_report.neighbour_movement = neighbour.pos.distance_to(neighbour_start)
			death_report.released = not sim.enemy_bodies.has(dead.id)
			# Walk through the corpse's former location using the real capsule.
			sim.physical_move(neighbour,Vector2(-2,0),.5)
			death_report.crossed = neighbour.pos.x < dead.pos.x
			done = true
	else:
		if clock > 2:
			samples.append(float(sim.enemy_physics_usec)/1000)
			simulation_samples.append(float(sim.simulation_usec)/1000)
		for z in sim.zombies:
			if z.id >= int(scenario)/2 and scenario != "entries":
				if z.get("desired_speed",0.0) > .1 and z.get("crowd_blocked",false): rear_attempts += 1
				if z.attack_time > 0 and z.pos.y < -12: rear_attacks += 1
			if z.attack_time > 0: attacks += 1
		sample_clock += dt
		if sample_clock >= .25:
			sample_clock = 0
			check_geometry()
		done = clock >= (55 if scenario == "entries" else 20)
	var profiles = {}
	for kind in ["normal","giant","imp","crawler"]: profiles[kind] = Body.profile(kind)
	var report = {"case":scenario,"time":clock,"done":done,"failed":sim.failed,"issues":issues,"combat":combat,"death":death_report,"profiles":profiles,"rear_attempts":rear_attempts,"rear_attacks":rear_attacks,"attack_frames":attacks,"live":sim.alive_count()}
	if done:
		var total = 0.0
		for value in samples: total += value
		samples.sort()
		report.physics_ms = {"mean":total/maxi(1,samples.size()),"p95":samples[floori((samples.size()-1)*.95)] if not samples.is_empty() else 0,"max":samples[-1] if not samples.is_empty() else 0,"samples":samples.size()}
		var simulation_total = 0.0
		for value in simulation_samples: simulation_total += value
		simulation_samples.sort()
		report.simulation_ms = {"mean":simulation_total/maxi(1,simulation_samples.size()),"p95":simulation_samples[floori((simulation_samples.size()-1)*.95)] if not simulation_samples.is_empty() else 0,"samples":simulation_samples.size()}
		report.optimization = {"route_hits":game.arena.route_cache_hits,"route_misses":game.arena.route_cache_misses,"early_wakes":sim.enemy_crowd.early_wakes,"slots":sim.enemy_crowd.ids.size()}
		report.progress = []
		for z in sim.zombies:
			if initial.has(z.id): report.progress.append({"id":z.id,"kind":z.kind,"moved":z.pos.distance_to(initial[z.id]),"pos":str(z.pos),"blocked":z.get("crowd_blocked",false),"requested":z.get("desired_speed",0.0),"physical_attempts":sim.enemy_bodies[z.id].move_attempts})
	JavaScriptBridge.eval("window.__enemyPhysicsReport="+JSON.stringify(report),true)
	if done or sim.failed:
		game.running = false
		active = false
