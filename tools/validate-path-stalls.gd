extends SceneTree
## Targeted real-map navigation regressions. No desktop, GPU or input automation.
const Recorder = preload("res://scripts/stutter_log.gd")
var game
var checks = 0
var failures = 0
var cases: Array = []
var reference_checks = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func fresh(owned := false):
	var progress = root.get_node("Progress").store
	for id in progress.BUILDINGS: progress.data.buildings[id].owned = owned
	game.start_solo("defense",19457)
	preload("res://tools/preparation-fixture.gd").skip_tutorial(game.sim)
	game.sim.defense_director.begin_wave()
	game.sim.roster.clear()
	game.running = false
	return game.sim

func timing(values: Array) -> Dictionary:
	var sorted = values.duplicate()
	sorted.sort()
	return {"p50_us":sorted[sorted.size()/2],"p95_us":sorted[mini(sorted.size()-1,ceili(sorted.size()*.95)-1)],"max_us":sorted[-1],"total_us":values.reduce(func(a,b): return a+b,0)}

func targets(label: String, position: Vector2, count: int, moving := false) -> void:
	var sim = fresh()
	var p: Dictionary = game.local_pawn()
	p.pos = position
	p.height = 0
	for i in count: sim.spawn(Vector2((i%3)*.2,-40-(i/3)*.2),"normal")
	var costs: Array = []
	var selections: Array = []
	for tick in 30:
		sim.elapsed += .05
		if moving: p.pos = position+Vector2(0,.08 if tick%2 else -.08)
		var start = Time.get_ticks_usec()
		for enemy in sim.zombies:
			var target: Dictionary = sim.choose_zombie_target(enemy,[p])
			selections.append(target.id == p.id)
		costs.append(Time.get_ticks_usec()-start)
	check(selections.all(func(value): return value),label+": nearby bridge player remains targetable")
	cases.append({"case":label,"enemies":count,"tick_us":costs,"timing":timing(costs)})

# Preserve the old linear algorithm as an independent semantic reference for
# the spatial index. Timings are observations, never flaky pass/fail limits.
func reference_link(world, a: Vector2, b: Vector2) -> bool:
	if world.clear(a,b): return true
	if world.clear(a,a): return false
	if not world.bounds.has_point(a) or not world.bounds.has_point(b): return false
	for item in world.structure_state:
		if item.hp > 0 and item.kind != "mine" and world.segment_rect(a,b,load("res://scripts/defense_structures.gd").bounds(item)): return false
	for obstacle in world.obstacles:
		reference_checks += 1
		if world.segment_rect(a,b,Rect2(obstacle.minX,obstacle.minZ,obstacle.maxX-obstacle.minX,obstacle.maxZ-obstacle.minZ)): return false
	return true

func reference_cell(world, position: Vector2) -> Vector2i:
	var base = Vector2i(((position-world.bounds.position)/world.CELL).round())
	if world.grid.is_in_boundsv(base) and not world.grid.is_point_solid(base) and reference_link(world,position,world.grid.get_point_position(base)): return base
	var best = Vector2i(-1,-1)
	var distance = INF
	for y in range(-5,6):
		for x in range(-5,6):
			var cell = base+Vector2i(x,y)
			if not world.grid.is_in_boundsv(cell) or world.grid.is_point_solid(cell): continue
			var point = world.grid.get_point_position(cell)
			var d = position.distance_squared_to(point)
			if d < distance and reference_link(world,position,point): best = cell; distance = d
	return best

func grid_matches_full_rebuild(world) -> bool:
	var reference: PackedByteArray = world.static_solid.duplicate()
	for item in world.structure_state:
		if item.hp <= 0 or item.kind == "mine": continue
		var rect = load("res://scripts/defense_structures.gd").bounds(item).grow(.95+world.CELL*.5+.001)
		var first = Vector2i(((rect.position-world.bounds.position)/world.CELL).floor())
		var last = Vector2i(((rect.end-world.bounds.position)/world.CELL).ceil())
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var cell = Vector2i(x,y)
				if world.grid.is_in_boundsv(cell) and rect.has_point(world.grid.get_point_position(cell)): reference[y*world.grid.region.size.x+x] = 1
	for y in world.grid.region.size.y:
		for x in world.grid.region.size.x:
			if world.grid.is_point_solid(Vector2i(x,y)) != bool(reference[y*world.grid.region.size.x+x]): return false
	return true

func validate_geometry() -> void:
	var sim = fresh()
	var world = game.arena
	var layout = root.get_node("Data").Maps.Defense
	for center in [Vector2(3.3,-40),Vector2(-3.3,-40),Vector2(12,-20),Vector2(7,-15),Vector2(0,-26),Vector2(5,layout.SHOP_DOOR_Z),layout.CRYSTAL+Vector2(1.4,0)]:
		for offset in [Vector2.ZERO,Vector2(.2,0),Vector2(-.2,0),Vector2(0,.2),Vector2(0,-.2)]:
			var p: Vector2 = center+offset
			check(world.nearest_cell(p) == reference_cell(world,p),"Indexed endpoint preserves exact old navigation projection at "+str(p))
	var random = RandomNumberGenerator.new()
	random.seed = 822714
	for i in 48:
		var position = Vector2(random.randf_range(-45,45),random.randf_range(-154,52))
		check(world.nearest_cell(position) == reference_cell(world,position),"Seeded forest, bank and shop projection retains reference result "+str(i))
	reference_checks = 0
	var expected = reference_cell(world,Vector2(3.3,-40))
	var start = world.endpoint_obstacle_checks
	check(world.nearest_cell(Vector2(3.3,-40)) == expected,"Bridge-edge projection is unchanged")
	var indexed = world.endpoint_obstacle_checks-start
	check(reference_checks > 0 and indexed*10 < reference_checks,"Bridge-edge endpoint scans at least ten times fewer obstacle rectangles")
	cases.append({"case":"endpoint_work","linear_obstacle_checks":reference_checks,"indexed_obstacle_checks":indexed})
	var pawn: Dictionary = game.local_pawn()
	pawn.pos = Vector2(3.3,-40)
	pawn.height = 0
	var body = sim.player_body(pawn)
	body.sync_from(pawn)
	body.advance(Vector2.ZERO,.016)
	check(absf(body.position.x-3.3) < .01,"Reproduction point is a physically valid player position beside bridge rail")

func validate_buildings() -> void:
	var sim = fresh(true)
	for hp in [0,500,0,500]:
		var gate: Dictionary = sim.defense_director.structures.find("bridge_entry_gate")
		gate.hp = hp
		var start = Time.get_ticks_usec()
		sim.defense_director.sync_world()
		cases.append({"case":"gate_change","hp":hp,"update_us":Time.get_ticks_usec()-start,"revision":game.arena.navigation_revision})
		check(grid_matches_full_rebuild(game.arena),"Partial grid update exactly matches a full rebuild after gate change to "+str(hp))
		check(game.arena.path_to(Vector2(0,-40),Vector2(0,-26)).is_empty() == (hp>0),"Destroyed gate opens the route; restored gate blocks it")
	# Overlapping footprints must remain blocked when only one building is removed.
	var upper: Dictionary = sim.defense_director.structures.find("bridge_gate")
	var lower: Dictionary = sim.defense_director.structures.find("bridge_entry_gate")
	lower.hp = 0
	sim.defense_director.sync_world()
	lower.pos = upper.pos
	lower.hp = 500
	sim.defense_director.sync_world()
	check(grid_matches_full_rebuild(game.arena),"Overlapping building footprints match full navigation rebuild")
	upper.hp = 0
	sim.defense_director.sync_world()
	check(grid_matches_full_rebuild(game.arena),"Removing one overlapping building preserves the other footprint")
	lower.hp = 0
	sim.defense_director.sync_world()
	check(grid_matches_full_rebuild(game.arena),"Removing the last overlapping building restores static terrain")

func validate_displaced() -> void:
	for count in [1,5,10]:
		var sim = fresh()
		var routes = sim.defense_spawner.forest_routes
		for i in count:
			var route: Dictionary = routes.entries[i]
			var origin: Vector2 = route.points[0]
			var direction: Vector2 = (route.points[1]-origin).normalized()
			var pos = origin+direction*1.5+Vector2(-direction.y,direction.x)*.5
			if not sim.arena.clear(pos,pos): pos = origin+direction*1.5-Vector2(-direction.y,direction.x)*.5
			sim.spawn(origin,"normal")
			sim.zombies[-1].pos = pos
		var costs: Array = []
		var safe = true
		for tick in 100:
			sim.elapsed += .05
			var start = Time.get_ticks_usec()
			for enemy in sim.zombies:
				routes.follow(sim,enemy,4.8,.05)
				safe = safe and sim.arena.clear(enemy.pos,enemy.pos)
			costs.append(Time.get_ticks_usec()-start)
		check(safe,"Displaced forest enemies rejoin without crossing scenery: "+str(count))
		cases.append({"case":"forest_displaced","enemies":count,"timing":timing(costs)})

func validate_traces() -> void:
	var sim = fresh()
	var recorder = root.get_node("StutterLog")
	recorder.enabled = true
	recorder.navigation.clear()
	recorder.metrics.clear()
	var position = Vector2(3.3,-40)
	var query = {"purpose":"reach","reason":"target_cell_changed","enemy_id":1,"target_type":"player","enemy_kind":"normal"}
	game.arena.path_to(Vector2(0,-40),position,query)
	var trace: Dictionary = recorder.navigation.requests[0]
	check(trace.has("start_cell") and trace.has("goal_cell") and trace.has("endpoint_us") and trace.has("astar_us") and trace.has("goal_connected") and trace.outcome == "projected_endpoint","Real edge query records phases, projected endpoint and caller context")
	check(Vector2(trace.from[0],trace.from[1]).is_equal_approx(Vector2(0,-40)) and Vector2(trace.goal[0],trace.goal[1]).is_equal_approx(position) and trace.purpose == "reach" and trace.reason == "target_cell_changed","Query coordinates and cause survive recording")
	# Force a small burst plus a moving goal; production queue logs stale work.
	sim.path_scheduler.clear()
	for i in 16: sim.path_scheduler.request("move:"+str(i),Vector2(0,-45),Vector2(0,-30),0,100,sim.arena)
	sim.path_scheduler.request("move:12",Vector2(0,-45),Vector2(1,-34),0,100.05,sim.arena)
	check(recorder.navigation.counts.get("event:query_deferred",0) >= 4 and recorder.navigation.counts.get("event:queued_goal_discarded",0) >= 1,"Burst and changed queued target are separately diagnosable")
	cases.append({"case":"queue_target_change","counts":recorder.navigation.counts.duplicate(),"requests":recorder.navigation.requests.duplicate(true),"events":recorder.navigation.events.duplicate(true)})
	recorder.enabled = false
	recorder.navigation.clear()
	recorder.metrics.clear()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	for count in [1,5,10]:
		targets("open_bridge",Vector2(2.5,-40),count)
		targets("rail_margin",Vector2(3.3,-40),count)
		targets("moving_rail_target",Vector2(3.3,-40),count,true)
	validate_geometry()
	validate_buildings()
	validate_displaced()
	validate_traces()
	var file = FileAccess.open("res://artifacts/path-stalls-validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"environment":"native headless CPU; no GPU or human playtest","arena_sha256":FileAccess.get_sha256("res://scripts/arena.gd"),"cases":cases},"  "))
	file.close()
	for row in cases:
		if row.has("timing"): print(row.case," n=",row.get("enemies",1)," ",JSON.stringify(row.timing))
	print("PATH STALLS: %d checks; %d failures" % [checks,failures])
	game.free()
	quit(1 if failures else 0)
