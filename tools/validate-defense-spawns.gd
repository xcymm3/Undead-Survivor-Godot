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
	check(layout.ENEMY_SPAWN_REGION.size == Vector2(96,96),"Far bank is a ninety-six-metre square")
	check(not layout.enemy_spawn_allowed(Vector2(0,-62)) and not layout.enemy_spawn_allowed(Vector2(0,-93.9)) and not layout.enemy_spawn_allowed(Vector2(31,-63)),"Circular thirty-two-metre bridge-start exclusion rejects front and side births")
	check(layout.enemy_spawn_allowed(Vector2(0,-94)) and layout.enemy_spawn_allowed(Vector2(33,-64)),"Ground on and outside the circular exclusion remains eligible")
	check(not layout.enemy_spawn_allowed(Vector2(0,-60)) and not layout.enemy_spawn_allowed(Vector2(0,20)),"Bridge deck and crystal bank cannot be spawn ground")
	check(arena.scenery.find_children("FarForestTrunk*","StaticBody3D",true,false).size() >= 70 and arena.scenery.find_children("FarForestBoulder*","StaticBody3D",true,false).size() >= 20,"Spawn bank contains distributed woodland and boulders")
	check(arena.scenery.get_node("FarForestLeaves").multimesh.instance_count >= 200 and arena.scenery.get_node("FarForestUndergrowth").multimesh.instance_count >= 70,"Foliage and undergrowth are batched rather than individually drawn")
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
	check(entries.any(func(p): return p.x < -35) and entries.any(func(p): return p.x > 35) and entries.any(func(p): return p.y > -100) and entries.any(func(p): return p.y < -140),"Sampling covers the enlarged bank's side and rear regions")
	var saved_seed: int = planner.spawn_random.seed
	planner.spawn_random.seed = 19457
	var first: Vector2 = planner.random_point()
	planner.spawn_random.seed = 19457
	check(first == planner.random_point(),"Placement uses reproducible seeded randomness")
	planner.spawn_random.seed = saved_seed
	var hidden: Array[Vector2] = []
	for point in entries:
		if planner.hidden_from_players(point,"normal",sim.pawns.values()): hidden.append(point)
	check(hidden.size() >= 20,"Woodland supplies many reachable births hidden from the starting player")
	var p: Dictionary = sim.pawns.solo
	var original_pos: Vector2 = p.pos
	var original_height: float = p.height
	p.pos = Vector2(0,-66)
	p.height = 0
	var bridge_hidden = entries.filter(func(point): return planner.hidden_from_players(point,"giant",[p]))
	check(bridge_hidden.size() >= 10,"Even a bridge-side observer has hidden positions for tall zombies")
	p.pos = original_pos
	p.height = original_height
	# Completely exposed candidates keep their quota until cover is available.
	var saved_check = planner.spawn_region
	var exposed = Vector2(44,-66)
	planner.spawn_region = Rect2(exposed-Vector2.ONE*.01,Vector2.ONE*.02)
	p.pos = Vector2(43,-70)
	p.height = 0
	check(not planner.hidden_from_players(exposed,"normal",[p]),"Direct sight rejects an exposed birth")
	planner.reset(1)
	sim.roster = ["normal"]
	planner.step(30,[p])
	check(sim.spawned == 0 and sim.roster.size() == 1,"An exposed field retains its pending birth quota")
	planner.spawn_region = saved_check
	p.pos = original_pos
	p.height = original_height
	# Independent geometry fixtures: all three old centre rays are blocked,
	# but the actual hat tip or shoulder remains visible around the cover.
	var silhouette_point = Vector2(44,-74)
	p.pos = Vector2(44,-64)
	p.height = 0
	var cover = StaticBody3D.new()
	cover.collision_layer = planner.SIGHT_MASK
	cover.collision_mask = 0
	cover.position = Vector3(44,1.1,-72)
	var cover_shape = CollisionShape3D.new()
	var cover_box = BoxShape3D.new()
	cover_box.size = Vector3(6,2.2,.25)
	cover_shape.shape = cover_box
	cover.add_child(cover_shape)
	arena.add_child(cover)
	await physics_frame
	var eye = Vector3(44,1.7,-64)
	var space = arena.get_world_3d().direct_space_state
	var centre_blocked = true
	for height in [.25,1.1,2.1]:
		centre_blocked = centre_blocked and not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,Vector3(44,height,-74),planner.SIGHT_MASK)).is_empty()
	check(centre_blocked and planner.hidden_from_players(silhouette_point,"normal",[p]),"Low cover hides the normal body and all three former centre rays")
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,Vector3(44,2.81,-74),planner.SIGHT_MASK)).is_empty(),"Cone tip is physically visible above the low cover")
	check(not planner.hidden_from_players(silhouette_point,"cone",[p]) and not planner.hidden_from_players(silhouette_point,"bucket",[p]),"Exposed cone and bucket tops reject births despite hidden body centres")
	cover_box.size = Vector3(.35,4,.25)
	cover.position.y = 2
	await physics_frame
	centre_blocked = true
	for height in [.25,1.1,2.1]:
		centre_blocked = centre_blocked and not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,Vector3(44,height,-74),planner.SIGHT_MASK)).is_empty()
	check(centre_blocked and space.intersect_ray(PhysicsRayQueryParameters3D.create(eye,Vector3(44.54,1.3,-74),planner.SIGHT_MASK)).is_empty(),"Narrow cover hides centre rays while leaving the actual shoulder exposed")
	check(not planner.hidden_from_players(silhouette_point,"normal",[p]),"Exposed shoulder rejects a birth behind narrow cover")
	cover.free()
	await physics_frame
	p.pos = original_pos
	p.height = original_height
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
		for tick in 600:
			sim.elapsed += .1
			sim.move_zombie(zombie,goal,4.9,.1,zombie.pos.distance_to(goal),data.contact(zombie.kind))
			stayed_on_route = stayed_on_route and arena.clear(zombie.pos,zombie.pos)
			if zombie.pos.y > -63: break
		check(stayed_on_route and zombie.pos.y > -63,"Random spawn %d reaches the bridge without leaving walkable terrain" % index)
	print("DEFENSE SPAWN VALIDATION: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
