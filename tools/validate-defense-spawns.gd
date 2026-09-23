extends SceneTree
## Headless checks for the covered five-point defense spawn and player-only gate.
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
	var gate = arena.scenery.get_node("FarBridgePlayerBarrier") as StaticBody3D
	check(gate.collision_layer == 2 and gate.find_children("*","CollisionShape3D",true,false).size() == 1,"Bridge gate collides only on the player barrier layer")
	var gate_ray = PhysicsRayQueryParameters3D.create(Vector3(0,1.2,-60),Vector3(0,1.2,-65),2)
	check(not arena.get_world_3d().direct_space_state.intersect_ray(gate_ray).is_empty(),"Player-only barrier closes the bridge mouth")
	check(arena.surface_hit(Vector3(0,1.2,-61),Vector3(0,1.2,-64)).is_empty(),"Bridge gate does not block bullets or zombie sight")
	check(not arena.surface_hit(Vector3(0,10,-72),Vector3(0,5,-72)).is_empty(),"Roof covers the spawn platform")
	var goal = Vector2(0,-59.5)
	game.start_solo("defense")
	await physics_frame
	var sim = game.sim
	for index in entries.size():
		var point: Vector2 = entries[index]
		check(arena.clear(point,point),"Spawn %d has free enemy clearance" % index)
		check(not arena.surface_hit(Vector3(0,1.7,-59),Vector3(point.x,1.2,point.y)).is_empty(),"Spawn %d is hidden from the bridge" % index)
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
	var pawn: Dictionary = game.local_pawn()
	pawn.pos = Vector2(0,-59)
	pawn.height = 0.0
	var body = sim.player_body(pawn)
	body.advance(Vector2(0,-4.2),1.0)
	body.sync_to(pawn)
	check(pawn.pos.y > -62.2,"Player capsule cannot enter the covered spawn platform")
	print("DEFENSE SPAWN VALIDATION: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
