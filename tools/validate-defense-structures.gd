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
		check(turret.shots-before_shots == 10 and is_equal_approx(before-z.hp,float(data.weapons[0].damage)*10),"%s fires rifle damage every rifle interval without headshot bonus" % id)
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
		sim.spawn(Vector2(0,-36),kind)
		var z: Dictionary = sim.zombies[-1]
		var blocked = true
		for i in 160:
			sim.elapsed += .05
			var target: Dictionary = sim.choose_zombie_target(z,sim.pawns.values())
			sim.update_zombie(z,target,.05)
			blocked = blocked and z.pos.y < -30.0
		check(gate.hp < 1000 and blocked,"%s attacks the gate and cannot cross it" % kind)
		manager.damage(gate.id,1000)
		await physics_frame
		for i in 70:
			sim.elapsed += .05
			sim.update_zombie(z,sim.choose_zombie_target(z,sim.pawns.values()),.05)
		check(z.pos.y > -29 and game.arena.clear(Vector2(0,-32),Vector2(0,-28)),"%s passes through after the gate is destroyed" % kind)
	# Native capsule checks: walk is blocked, jump clears the low full-width gate.
	sim = fresh()
	await physics_frame
	var p: Dictionary = sim.pawns.solo
	p.pos = Vector2(0,-32)
	p.height = .12
	p.velocity = 0.0
	for i in 50:
		sim.submit("solo",{"y":1,"yaw":0.0,"slot":1})
		sim.update_pawn(p,.02)
	check(p.pos.y < -30.3,"Walking player cannot pass through intact gate")
	p.pos = Vector2(0,-32.2)
	p.height = .14
	p.velocity = 0.0
	for i in 10:
		sim.submit("solo",{"slot":1})
		sim.update_pawn(p,.02)
	for i in 85:
		sim.submit("solo",{"y":1,"yaw":0.0,"slot":1,"jump":i == 0})
		sim.update_pawn(p,.02)
	check(p.pos.y > -29,"Player jumps over the gate using normal jump input (pos=%s height=%.2f)" % [p.pos,p.height])
	check(game.arena.surface_hit(Vector3(0,1.7,-32),Vector3(0,1.7,-28)).is_empty(),"Standing gunfire passes above the gate")
	check(not game.arena.surface_hit(Vector3(0,.55,-32),Vector3(0,.55,-28)).is_empty(),"Low bullets collide with the gate rather than passing through gaps")
	# Mine explosion and grenade explosion are numerically identical.
	sim = fresh()
	await physics_frame
	manager = sim.defense_director.structures
	var mine: Dictionary = manager.find("crystal_mine")
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
	# Fresh readiness and joining supply initialization cannot repair structures.
	manager.damage("turret_left",200)
	manager.damage("bridge_gate",1000)
	var persistent = sim.defense.structures.duplicate(true)
	sim.defense_director.finish_wave()
	sim.defense_director.begin_wave()
	sim.add_pawn("two","二号",1)
	sim.defense_director.equipment.initialize()
	check(sim.defense.structures == persistent,"Wave transitions and multiplayer supplies do not repair or replace structures")
	var snapshot = sim.snapshot()
	root.get_node("Session").members = {"solo":{"name":"一号"},"two":{"name":"二号"}}
	check(root.get_node("Session").valid_world(snapshot),"Coop world packet accepts authoritative structure state")
	var replica = load("res://scripts/simulation.gd").new(game.arena)
	replica.apply_snapshot(snapshot)
	check(replica.defense_state().structures == persistent,"Client snapshot retains destroyed turrets, broken gate and spent mine")
	check(game.arena.scenery.structure_view.actors.bridge_gate.body.collision_layer == 0,"Client snapshot removes destroyed gate collision")
	snapshot.defense.structures[0].hp = 201
	check(not root.get_node("Session").valid_world(snapshot),"Malformed structure health is rejected by network validation")
	game.start_solo("defense",42)
	check(game.sim.defense.structures == Structures.initial_state(),"Only starting a new match restores the four structures")
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
