extends SceneTree
## Headless acceptance for the defense map, lever gate, weapon zone and crystal target.
var checks = 0
var failures = 0
var game

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)

func command(weapon := 0, interact := false) -> Dictionary:
	return {"x":0.0,"y":0.0,"yaw":0.0,"pitch":0.0,"weapon":weapon,"interact":interact,"heal":false,"crouch":false,"jump":false,"reload":false,"fire":false,"aim":false,"shove":false}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var data = root.get_node("Data")
	data.settings.map_id = "graypine_defense"
	var scene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	check(game.arena.map_id == "graypine_defense","Defense map loads as an authored scene")
	check(game.arena.obstacles.size() >= 2,"Chasm sides participate in navigation")
	check(not game.arena.clear(Vector2(12,-70),Vector2(12,0)),"Chasm prevents routes that bypass the bridge")
	check(game.arena.clear(Vector2(0,-70),Vector2(0,44)),"Bridge and ramp form one open approach lane")
	var bridge_hit: Dictionary = game.arena.surface_hit(Vector3(0,5,-45),Vector3(0,-10,-45))
	var ramp_hit: Dictionary = game.arena.surface_hit(Vector3(0,8,-19),Vector3(0,-5,-19))
	var plateau_hit: Dictionary = game.arena.surface_hit(Vector3(0,8,20),Vector3(0,-5,20))
	check(not bridge_hit.is_empty() and absf(bridge_hit.position.y) < .1,"Suspension bridge has a native walkable deck")
	check(not ramp_hit.is_empty() and ramp_hit.position.y > 1 and ramp_hit.position.y < 2,"Approach includes a physical rising ramp")
	check(not plateau_hit.is_empty() and absf(plateau_hit.position.y-3) < .1,"Crystal stands at the end of the raised flat ground")

	game.start_solo("defense")
	await physics_frame
	var sim = game.sim
	var pawn: Dictionary = sim.pawns.solo
	check(sim.mode == "defense" and not sim.defense.started,"Entering the map does not start waves")
	for i in 10:
		sim.submit("solo",command(1))
		sim.step(.05)
	check(sim.elapsed == 0 and sim.spawned == 0 and sim.zombies.is_empty(),"Waiting before the lever keeps timer and spawns stopped")
	check(pawn.weapon == 1,"Any primary weapon can be selected inside the rear safe zone")
	pawn.pos = Vector2(6,49)
	for i in 10:
		sim.submit("solo",command(2))
		sim.step(.05)
	check(pawn.weapon == 1,"Weapon switching is locked outside the safe zone")
	sim.submit("solo",command(1,true))
	sim.step(.02)
	check(sim.defense.started and not sim.roster.is_empty(),"Pulling the crystal-side lever prepares wave one")

	# Isolate target choice from the wave spawner: the closest valid unit must take the hit.
	sim.roster.clear()
	sim.zombies.clear()
	pawn.pos = Vector2(0,60)
	pawn.hp = 100
	var crystal_before: int = sim.defense.crystal_hp
	sim.spawn(Vector2(0,44.9),"normal")
	for i in 4: sim.step(.4)
	check(sim.defense.crystal_hp < crystal_before and pawn.hp == 100,"A zombie beside the crystal attacks the crystal instead of a distant player")
	sim.zombies.clear()
	pawn.pos = Vector2(0,55)
	pawn.hp = 100
	crystal_before = sim.defense.crystal_hp
	sim.spawn(Vector2(0,53.9),"normal")
	for i in 4: sim.step(.4)
	check(pawn.hp < 100 and sim.defense.crystal_hp == crystal_before,"A zombie beside the player attacks the player instead of the farther crystal")

	sim.zombies.clear()
	sim.wave = 1
	sim.spawn(Vector2(0,-70),"normal")
	var wave_one_hp: float = sim.zombies[-1].hp
	sim.zombies.clear()
	sim.wave = 10
	sim.spawn(Vector2(0,-70),"normal")
	check(sim.zombies[-1].hp > wave_one_hp*2,"Wave ten zombies receive the configured health growth")
	sim.zombies.clear()
	sim.roster.clear()
	sim.cleared = 9
	sim.rest = 0
	sim.step(.02)
	check(sim.won and sim.cleared == 10,"Clearing wave ten completes the defense")

	# Failure is driven by non-recoverable crystal health, independent of player health.
	game.start_solo("defense")
	await physics_frame
	sim = game.sim
	pawn = sim.pawns.solo
	pawn.pos = Vector2(6,49)
	sim.submit("solo",command(0,true))
	sim.step(.02)
	sim.damage_crystal({"id":77},Data.Maps.Defense.CRYSTAL_MAX_HP)
	sim.step(.02)
	check(sim.failed and sim.cause == "crystal" and sim.defense.crystal_hp == 0,"Destroying the fixed-health crystal ends the game in failure")

	print("DEFENSE VALIDATION: %d checks; %d failures" % [checks,failures])
	game.queue_free()
	quit(1 if failures else 0)
