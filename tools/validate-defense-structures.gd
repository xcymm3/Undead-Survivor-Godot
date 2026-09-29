extends SceneTree
var Structures
var Equipment
var checks = 0
var failures = 0
var game

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func fresh():
	game.start_solo("defense",42)
	game.running = false
	game.sim.defense.started = true
	game.sim.defense.waiting = false
	return game.sim

func run() -> void:
	Structures = load("res://scripts/defense_structures.gd")
	Equipment = load("res://scripts/equipment_core.gd")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var data = root.get_node("Data")
	var sim = fresh()
	await physics_frame
	var manager = sim.defense_director.structures
	check(sim.defense.structures.size() == 4,"Match starts with two turrets, one gate and one mine")
	check(manager.find("turret_left").hp == 200 and manager.find("turret_right").hp == 200,"Both turrets have 200 health")
	check(manager.find("bridge_gate").hp == 1000,"Bridge gate starts with 1000 health")
	check(Structures.MINE_DELAY == Equipment.GRENADE_FUSE,"Mine uses the grenade's exact fuse duration")
	check(Structures.valid_state(sim.defense.structures),"Initial structure snapshot passes validation")
	for item in sim.defense.structures:
		var actor: Dictionary = game.arena.scenery.structure_view.actors[item.id]
		check(actor.root.find_children("*","Label3D",true,false).is_empty(),"Buildings have no overhead names or health labels")
		if item.kind == "turret":
			check(item.pos.y > -10 and absf(item.pos.x) > 5 and item.height == 3,"Turret stands on the flat plateau beside the ramp exit")
	var steel = game.arena.scenery.structure_view.actors.bridge_gate.panel.get_node("SteelBar")
	check(steel.material_override.metallic > .7,"Gate bars use a metallic material")
	for id in ["turret_left","turret_right"]:
		var turret: Dictionary = manager.find(id)
		var mirror_id = "turret_right" if id == "turret_left" else "turret_left"
		manager.find(mirror_id).cooldown = 100.0
		sim.zombies.clear()
		sim.spawn(turret.pos+Vector2(0,4),"normal")
		var z: Dictionary = sim.zombies[-1]
		z.body = 10000.0
		z.hp = 10000.0
		var before: float = z.hp
		var before_shots: int = turret.shots
		turret.cooldown = 0.0
		for i in 10: manager.step(.12)
		check(turret.shots-before_shots == 10 and is_equal_approx(before-z.hp,600.0),"%s fires 60 torso damage every rifle interval without headshot bonus" % id)
		var selected: Dictionary = sim.choose_zombie_target(z,sim.pawns.values())
		check(selected.id == id,"%s enters the same nearest-target selection as player and crystal" % id)
		var outside: int = turret.shots
		z.pos = turret.pos+Vector2(0,11)
		manager.step(.12)
		check(turret.shots == outside,"%s does not fire beyond ten metres" % id)
		sim.zombies.clear()
		sim.spawn(turret.pos+Vector2(0,3),"crawler")
		var crawler: Dictionary = sim.zombies[-1]
		crawler.body = 10000.0
		crawler.hp = 10000.0
		manager.step(.12)
		check(crawler.hp < 10000,"%s tracks the crawler's actual lowered torso pose" % id)
		manager.find(mirror_id).cooldown = 0.0
		turret.cooldown = 0.0
		manager.damage(id,200)
		var stopped: int = turret.shots
		manager.step(1.0)
		check(turret.hp == 0 and turret.shots == stopped,"Destroyed %s stops shooting" % id)
		var actor: Dictionary = game.arena.scenery.structure_view.actors[id]
		sim.defense.prop_clock += 1.0
		sim.defense_director.sync_world()
		check(is_instance_valid(actor.root) and actor.root.visible and actor.yaw.rotation.z > 1.0 and actor.body.collision_layer == 0,"%s collapses into persistent nonblocking wreckage" % id)
	# Terrain rays must block turret bullets, including a target beside cover.
	sim = fresh()
	await physics_frame
	manager = sim.defense_director.structures
	var turret: Dictionary = manager.find("turret_left")
	var wall = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3,4,.4)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(turret.pos.x,3,turret.pos.y+2)
	game.arena.add_child(wall)
	await physics_frame
	sim.spawn(turret.pos+Vector2(0,4),"normal")
	manager.step(.12)
	check(turret.shots == 0,"Turret does not shoot through solid cover")
	wall.free()
	await physics_frame
	for kind in data.enemies.keys():
		sim = fresh()
		await physics_frame
		manager = sim.defense_director.structures
		var attacked: Dictionary = manager.find("turret_left")
		sim.spawn(attacked.pos+Vector2(0,4),kind)
		var z: Dictionary = sim.zombies[-1]
		for i in 160:
			sim.elapsed += .05
			sim.update_zombie(z,sim.choose_zombie_target(z,sim.pawns.values()),.05)
		check(attacked.hp < 200,"%s reaches and damages a turret through normal enemy attacks (pos=%s target=%s attack=%.2f visible=%s)" % [kind,z.pos,sim.choose_zombie_target(z,sim.pawns.values()).id,z.attack_time,manager.visible(z,manager.target(attacked,z.pos))])
		sim.pawns.solo.pos = z.pos+Vector2(0,-.5)
		var chosen: Dictionary = sim.choose_zombie_target(z,sim.pawns.values())
		check(chosen.id == (attacked.id if kind in ["imp","giant"] else "solo"),"%s preserves nearest-target priority and dedicated crystal-attacker rules" % kind)
	# Every type attacks the barrier, including dedicated crystal attackers.
	for kind in data.enemies.keys():
		sim = fresh()
		await physics_frame
		manager = sim.defense_director.structures
		var gate: Dictionary = manager.find("bridge_gate")
		sim.spawn(gate.pos+Vector2(0,-6),kind)
		var z: Dictionary = sim.zombies[-1]
		var blocked = true
		for i in 160:
			sim.elapsed += .05
			var target: Dictionary = sim.choose_zombie_target(z,sim.pawns.values())
			sim.update_zombie(z,target,.05)
			blocked = blocked and z.pos.y < gate.pos.y
		check(gate.hp < 1000 and blocked,"%s attacks the gate and cannot cross it" % kind)
		manager.damage(gate.id,1000)
		await physics_frame
		for i in 70:
			sim.elapsed += .05
			sim.update_zombie(z,sim.choose_zombie_target(z,sim.pawns.values()),.05)
		check(z.pos.y > gate.pos.y+1 and game.arena.clear(gate.pos+Vector2(0,-2),gate.pos+Vector2(0,2)),"%s passes through after the gate is destroyed" % kind)
	# Native capsule checks: walk is blocked, jump clears the low full-width gate.
	sim = fresh()
	await physics_frame
	var p: Dictionary = sim.pawns.solo
	p.pos = Vector2(0,-12)
	p.height = 2.79
	p.velocity = 0.0
	for i in 50:
		sim.submit("solo",{"y":1,"yaw":0.0,"slot":1})
		sim.update_pawn(p,.02)
	check(p.pos.y < -10.3,"Walking player cannot pass through intact gate")
	p.pos = Vector2(0,-12.2)
	p.height = 2.78
	p.velocity = 0.0
	for i in 10:
		sim.submit("solo",{"slot":1})
		sim.update_pawn(p,.02)
	for i in 85:
		sim.submit("solo",{"y":1,"yaw":0.0,"slot":1,"jump":i == 0})
		sim.update_pawn(p,.02)
	check(p.pos.y > -9,"Player jumps over the gate using normal jump input (pos=%s height=%.2f)" % [p.pos,p.height])
	check(game.arena.surface_hit(Vector3(0,4.7,-12),Vector3(0,4.7,-8)).is_empty(),"Standing gunfire passes above the gate")
	check(not game.arena.surface_hit(Vector3(0,3.55,-12),Vector3(0,3.55,-8)).is_empty(),"Low bullets collide with the gate rather than passing through gaps")
	# Mine explosion and grenade explosion are numerically identical.
	sim = fresh()
	await physics_frame
	manager = sim.defense_director.structures
	var mine: Dictionary = manager.find("crystal_mine")
	# The shorter field puts these blast samples inside turret range.
	# Isolate mine damage from supporting fire, which is checked above.
	for item in sim.defense.structures:
		if item.kind == "turret": item.cooldown = 1000.0
	for offset in [Vector2.ZERO,Vector2(0,-5),Vector2(0,-10),Vector2(0,-12)]:
		sim.spawn(mine.pos+offset,"giant")
	var before_health: Array = sim.zombies.map(func(z): return z.hp)
	manager.step(.02)
	check(mine.triggered and mine.fuse == Equipment.GRENADE_FUSE,"First living zombie primes mine with full grenade fuse")
	manager.step(Equipment.GRENADE_FUSE-.01)
	check(not mine.spent and sim.zombies.map(func(z): return z.hp) == before_health,"Mine cannot explode before the grenade fuse expires")
	manager.step(.011)
	var mine_health: Array = sim.zombies.map(func(z): return z.hp)
	check(mine.spent and mine.hp == 0 and mine_health[0] < before_health[0] and mine_health[3] == before_health[3],"Mine explodes once and respects grenade range")
	for i in sim.zombies.size():
		var z: Dictionary = sim.zombies[i]
		z.body = float(data.enemies.giant.health-data.enemies.giant.armor)
		z.armor = float(data.enemies.giant.armor)
		z.hp = z.body+z.armor
		z.pos = mine.pos+Vector2(0,[0,-5,-10,-12][i])
	sim.equipment.explode({"id":-1,"owner":"solo","pos":Vector3(mine.pos.x,mine.height+.16,mine.pos.y)})
	check(sim.zombies.map(func(z): return z.hp) == mine_health,"Mine exactly matches grenade damage falloff and armor at every sampled distance")
	var after: Array = sim.zombies.map(func(z): return z.hp)
	manager.step(5.0)
	check(sim.zombies.map(func(z): return z.hp) == after,"Spent mine cannot detonate a second time")
	sim.defense.waiting = true
	var paused_shots: int = manager.find("turret_left").shots
	manager.step(.12)
	check(manager.find("turret_left").shots == paused_shots,"Turrets do not fire during wave preparation")
	# Preparation and joining do not reset structures; only actual wave start does.
	manager.damage("turret_left",200)
	manager.damage("bridge_gate",1000)
	var persistent = sim.defense.structures.duplicate(true)
	sim.defense_director.finish_wave()
	sim.add_pawn("two","二号",1)
	sim.defense_director.equipment.initialize()
	check(sim.defense.structures == persistent,"Preparation and multiplayer supplies preserve damaged structures")
	var snapshot = sim.snapshot()
	root.get_node("Session").members = {"solo":{"name":"一号"},"two":{"name":"二号"}}
	check(root.get_node("Session").valid_world(snapshot),"Coop world packet accepts authoritative structure state")
	var replica = load("res://scripts/simulation.gd").new(game.arena)
	replica.apply_snapshot(snapshot)
	check(replica.defense_state().structures == persistent,"Client snapshot retains destroyed turrets, broken gate and spent mine")
	check(game.arena.scenery.structure_view.actors.bridge_gate.body.collision_layer == 0,"Client snapshot removes destroyed gate collision")
	sim.paths["stale_route"] = [Vector2.ZERO]
	var crystal_hp: int = sim.defense.crystal_hp
	sim.defense_director.begin_wave()
	check(sim.defense.structures == Structures.initial_state() and sim.paths.is_empty(),"Wave start restores every structure's complete initial state and clears cached routes")
	check(sim.defense.crystal_hp == crystal_hp,"Wave start preserves crystal durability")
	var view = game.arena.scenery.structure_view
	check(view.actors.bridge_gate.body.collision_layer == 1 and view.actors.bridge_gate.panel.rotation.x == 0,"Authority restores gate collision and upright appearance")
	check(view.actors.turret_left.body.collision_layer == 1 and view.actors.turret_left.yaw.rotation == Vector3.ZERO,"Authority restores destroyed turret collision and orientation")
	check(view.actors.crystal_mine.root.visible and not view.actors.crystal_mine.led.visible,"Wave start restores a visible unprimed mine")
	snapshot = sim.snapshot()
	check(root.get_node("Session").valid_world(snapshot),"Coop world packet accepts restored structure state")
	replica.apply_snapshot(snapshot)
	check(replica.defense_state().structures == Structures.initial_state() and view.actors.bridge_gate.body.collision_layer == 1,"Client snapshot restores buildings and gate collision for the new wave")
	sim.zombies.clear()
	mine = manager.find("crystal_mine")
	sim.spawn(mine.pos,"normal")
	manager.step_mine(mine,.02)
	check(mine.triggered and not mine.spent,"Restored mine can be triggered in the next wave")
	manager.step_mine(mine,Equipment.GRENADE_FUSE)
	check(mine.spent and sim.zombies[0].hp <= 0,"Restored mine detonates with real grenade damage in the next wave")
	snapshot.defense.structures[0].hp = 201
	check(not root.get_node("Session").valid_world(snapshot),"Malformed structure health is rejected by network validation")
	game.start_solo("defense",42)
	check(game.sim.defense.structures == Structures.initial_state(),"Starting a new match also restores the four structures")
	sim = fresh()
	await physics_frame
	manager = sim.defense_director.structures
	sim.spawn(manager.find("turret_left").pos+Vector2(0,4),"giant")
	var integrated: Dictionary = sim.zombies[-1]
	var original_hp: float = integrated.hp
	for i in 10: sim.step(.05)
	check(integrated.hp < original_hp and manager.find("turret_left").shots > 0,"Normal authority simulation tick runs turret targeting and damage")
	sim = fresh()
	await physics_frame
	manager = sim.defense_director.structures
	mine = manager.find("crystal_mine")
	sim.spawn(mine.pos,"normal")
	sim.step(.02)
	check(mine.triggered,"Normal authority simulation tick detects mine contact")
	sim.defense.waiting = true
	sim.zombies.clear()
	manager.step(Equipment.GRENADE_FUSE)
	check(mine.spent,"A primed mine finishes its fuse even if the wave enters preparation")
	print("DEFENSE STRUCTURES: %d checks; %d failures" % [checks,failures])
	game.queue_free()
	quit(1 if failures else 0)
