extends SceneTree
## Headless checks for the five-point defense spawn on the original open terrain.
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
	var entries: Array = data.Maps.Defense.ENTRIES
	check(entries.size() == 5 and entries.map(func(p): return p.y).min() < entries.map(func(p): return p.y).max(),"Five spawn points have near and far positions")
	check(arena.scenery.find_children("FarSpawn*","Node3D",true,false).is_empty(),"Spawn platform has no added roof, walls or mist")
	check(arena.scenery.get_node_or_null("FarBridgePlayerBarrier") == null,"Bridge mouth has no player-only barrier")
	check(arena.surface_hit(Vector3(0,10,-72),Vector3(0,5,-72)).is_empty(),"Spawn platform remains open above")
	var goal = Vector2(0,-59.5)
	game.start_solo("defense")
	await physics_frame
	var sim = game.sim
	for index in entries.size():
		var point: Vector2 = entries[index]
		check(arena.clear(point,point),"Spawn %d has free enemy clearance" % index)
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
		check(stayed_on_route and zombie.pos.y > -63,"Spawn %d reaches the bridge without leaving walkable terrain" % index)
	print("DEFENSE SPAWN VALIDATION: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
