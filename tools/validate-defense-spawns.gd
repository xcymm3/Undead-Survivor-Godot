extends SceneTree
## Headless checks for the five independent cave spawns and bridge approach.
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
	check(arena.scenery.find_children("SpawnCave*Roof","Node3D",true,false).size() == entries.size(),"Each spawn has its own roof")
	check(arena.scenery.find_children("SpawnCave*DarkMouth","MeshInstance3D",true,false).size() == entries.size(),"Each cave has an unlit entrance")
	check(arena.scenery.get_node_or_null("FarBridgePlayerBarrier") == null,"Bridge mouth has no player-only barrier")
	check(arena.surface_hit(Vector3(6,10,-73),Vector3(6,5,-73)).is_empty(),"Space between caves remains open above")
	var goal = Vector2(0,-59.5)
	game.start_solo("defense")
	await physics_frame
	var sim = game.sim
	for index in entries.size():
		var point: Vector2 = entries[index]
		check(arena.clear(point,point),"Spawn %d has free enemy clearance" % index)
		var mouth = arena.scenery.get_node("SpawnCave%02dDarkMouth" % index) as MeshInstance3D
		check(mouth.position.z > point.y and mouth.material_override is StandardMaterial3D and mouth.material_override.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and mouth.material_override.albedo_color == Color.BLACK,"Spawn %d starts behind a black cave mouth" % index)
		check(mouth.mesh.surface_get_array_len(0) == 27,"Spawn %d cave mouth is closed down to the ground" % index)
		check(mouth.mesh.get_aabb().size.y > 6.0,"Spawn %d has clearance for giant zombies" % index)
		sim.zombies.clear()
		sim.paths.clear()
		sim.crowd_buckets.clear()
		sim.spawn(point,"normal")
		var zombie: Dictionary = sim.zombies[0]
		var stayed_on_route := true
		var crossed_mouth := false
		var exited_opening := false
		for tick in 180:
			sim.elapsed += .1
			sim.move_zombie(zombie,goal,4.9,.1,zombie.pos.distance_to(goal),data.contact(zombie.kind))
			stayed_on_route = stayed_on_route and arena.clear(zombie.pos,zombie.pos)
			if not crossed_mouth and zombie.pos.y > point.y+2.35:
				crossed_mouth = true
				exited_opening = absf(zombie.pos.x-point.x) < 2.75
			if zombie.pos.y > -63: break
		check(crossed_mouth and exited_opening,"Spawn %d exits through its cave mouth" % index)
		check(stayed_on_route and zombie.pos.y > -63,"Spawn %d reaches the bridge without leaving walkable terrain" % index)
	print("DEFENSE SPAWN VALIDATION: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
