extends SceneTree
## Headless checks for random far-bank spawns and the bridge-mouth exclusion.
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var data = root.get_node("Data")
	data.settings.map_id = "graypine_defense"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	var arena = game.arena
	var layout = data.Maps.Defense
	check(not layout.enemy_spawn_allowed(Vector2(0,-62)) and not layout.enemy_spawn_allowed(Vector2(0,-69.9)),"Bridge mouth and its eight-metre approach are excluded")
	check(layout.enemy_spawn_allowed(Vector2(0,-70)) and layout.enemy_spawn_allowed(Vector2(20,-65)),"Distant centre and side-bank ground remain available")
	check(not layout.enemy_spawn_allowed(Vector2(0,-60)) and not layout.enemy_spawn_allowed(Vector2(0,20)),"Bridge deck and crystal bank cannot be spawn ground")
	check(arena.scenery.find_children("FarSpawn*","Node3D",true,false).is_empty(),"Spawn platform has no added roof, walls or mist")
	check(arena.scenery.get_node_or_null("FarBridgePlayerBarrier") == null,"Bridge mouth has no player-only barrier")
	check(arena.surface_hit(Vector3(0,10,-72),Vector3(0,5,-72)).is_empty(),"Spawn platform remains open above")
	var goal = Vector2(0,-59.5)
	game.start_solo("defense",20260929)
	await physics_frame
	var sim = game.sim
	var planner = sim.defense_spawner
	var entries: Array[Vector2] = []
	for attempt in 3000:
		var point: Vector2 = planner.random_point()
		if planner.ground_clear(point): entries.append(point)
		if entries.size() == 128: break
	check(entries.size() == 128,"Random sampling finds 128 reachable far-bank positions")
	check(entries.all(func(p): return layout.enemy_spawn_allowed(p) and arena.clear(p,p)),"Every sampled birth position clears obstacles and the bridge exclusion")
	var distinct = {}
	for point in entries: distinct[point] = true
	check(distinct.size() == entries.size(),"Spawn coordinates vary continuously instead of repeating five points")
	check(entries.any(func(p): return p.x < -20) and entries.any(func(p): return p.x > 20) and entries.any(func(p): return p.y > -68) and entries.any(func(p): return p.y < -74),"Sampling covers both sides and the near and far parts of the far bank")
	var saved_seed: int = planner.spawn_random.seed
	planner.spawn_random.seed = 19457
	var first: Vector2 = planner.random_point()
	planner.spawn_random.seed = 19457
	check(first == planner.random_point(),"Placement uses reproducible seeded randomness")
	planner.spawn_random.seed = saved_seed
	# Check real movement from a distributed subset, in addition to path queries.
	entries = entries.slice(0,12)
	for index in entries.size():
		var point: Vector2 = entries[index]
		check(arena.clear(point,point),"Random spawn %d has free enemy clearance" % index)
		sim.zombies.clear()
		sim.paths.clear()
		sim.crowd_buckets.clear()
		sim.spawn(point,"normal")
		var zombie: Dictionary = sim.zombies[0]
		var stayed_on_route := true
		for tick in 180:
			sim.elapsed += .1
			sim.move_zombie(zombie,goal,4.9,.1,zombie.pos.distance_to(goal),data.contact(zombie.kind))
			stayed_on_route = stayed_on_route and arena.clear(zombie.pos,zombie.pos)
			if zombie.pos.y > -63: break
		check(stayed_on_route and zombie.pos.y > -63,"Random spawn %d reaches the bridge without leaving walkable terrain" % index)
	print("DEFENSE SPAWN VALIDATION: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
