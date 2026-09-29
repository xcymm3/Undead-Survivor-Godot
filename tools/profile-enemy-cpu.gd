extends SceneTree
## CPU-only diagnostics. The production simulation is inherited, never copied.
var enemy_view
var measured_simulation
var plain_simulation
var instrumented = true


var game
var data
var all_results: Array = []
var warmup = 120
var sample_count = 300
var rounds = 2
var counts: Array = [50,100,200,300]
var scenarios: Array = ["movement","bridge","rifle","auto-shotgun","flamethrower"]

func _initialize() -> void:
	call_deferred("run")

func disable_callbacks(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	for child in node.get_children(): disable_callbacks(child)

func run() -> void:
	if DisplayServer.get_name() != "headless":
		push_error("CPU profiling requires a real headless display driver")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "--unprofiled": instrumented = false
		if arg.begins_with("--samples="): sample_count = int(arg.get_slice("=",1))
		if arg.begins_with("--warmup="): warmup = int(arg.get_slice("=",1))
		if arg.begins_with("--rounds="): rounds = int(arg.get_slice("=",1))
		if arg.begins_with("--counts="):
			counts.clear()
			for item in arg.get_slice("=",1).split(","): counts.append(int(item))
		if arg.begins_with("--scenarios="): scenarios = Array(arg.get_slice("=",1).split(","))
	if sample_count < 1 or warmup < 0 or rounds < 1 or rounds > 4 or counts.any(func(n): return n not in [50,100,200,300]) or scenarios.any(func(s): return s not in ["movement","bridge","rifle","auto-shotgun","flamethrower"]):
		push_error("Invalid profile parameters")
		quit(1)
		return
	game = load("res://scenes/main.tscn").instantiate()
	data = root.get_node("Data")
	enemy_view = load("res://scripts/enemy_view.gd")
	measured_simulation = load("res://tools/profile-enemy-simulation.gd")
	plain_simulation = load("res://scripts/simulation.gd")
	root.add_child(game)
	disable_callbacks(root)
	Engine.max_fps = 0
	RenderingServer.render_loop_enabled = false
	await physics_frame
	var failed = false
	for round_index in rounds:
		# Reverse the second round to reduce systematic order/thermal bias.
		var ordered_counts = counts.duplicate()
		var ordered_scenarios = scenarios.duplicate()
		if round_index%2 == 1:
			ordered_counts.reverse()
			ordered_scenarios.reverse()
		for count in ordered_counts:
			for scenario in ordered_scenarios:
				var result = await run_case(count,scenario,round_index+1)
				all_results.append(result)
				failed = failed or not result.valid
				save_results(failed)
				print("CPU PROFILE CASE "+JSON.stringify({"count":count,"scenario":scenario,"round":round_index+1,"valid":result.valid,"samples":result.samples.size(),"shots":result.shots,"hits":result.hits,"moving_fraction":result.moving_fraction,"blocked_fraction":result.blocked_fraction,"mean_cpu_ms":result.mean_cpu_ms}))
	game.sim = null
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)

func stage_case(count: int, scenario: String) -> Dictionary:
	game.enemies.clear()
	if game.sim: game.sim.dispose()
	var sim = (measured_simulation if instrumented else plain_simulation).new(game.arena)
	game.sim = sim
	sim.random.seed = 42029
	sim.add_pawn("solo","CPU profiler",0)
	sim.start("defense")
	sim.roster.clear()
	sim.defense.started = true
	sim.defense.waiting = false
	sim.defense.crystal_hp = 1000000000
	var p: Dictionary = sim.pawns.solo
	p.pos = Vector2(0,48) if scenario in ["movement","bridge"] else Vector2(0,40)
	p.height = 3.0
	p.yaw = 0.0
	p.protection = 10000.0
	for item in sim.defense.structures:
		if item.kind == "turret": item.hp = 0
		if item.kind == "mine": item.spent = true
		if item.kind == "gate": item.hp = 1000000000 if scenario == "bridge" else 0
	game.arena.sync_defense(sim.defense)
	var weapon_index = 0
	if scenario not in ["movement","bridge"]:
		for index in data.weapons.size():
			if data.weapons[index].id == scenario: weapon_index = index
	p.weapon1 = weapon_index
	p.weapon = weapon_index
	p.requested = weapon_index
	var positions: Array = []
	if scenario == "bridge":
		# Five lanes start at the intact gate and queue down the ramp/bridge.
		for row in 29:
			for column in 5: positions.append(Vector2((column-2)*1.45,-13-row*1.65))
		# 300 actors cannot fit in a single bridge queue without leaving the map.
		# Additional ranks approach from the actual far bank, inside map bounds.
		for row in 8:
			for column in 33:
				var point = Vector2(-25.6+column*1.6,-64-row*1.65)
				if sim.arena.clear(point,point) and sim.defense_spawner.capsule_clear(point,"crawler"): positions.append(point)
	else:
		for row in range(32):
			for column in range(33):
				var point = Vector2(-25.6+column*1.6,row*1.65) if scenario == "movement" else Vector2(-25.6+column*1.6,34-row*1.65)
				if point.y < 0 or point.y > 35: continue
				if sim.arena.clear(point,point) and sim.defense_spawner.capsule_clear(point,"crawler"):
					positions.append(point)
				if positions.size() >= count: break
			if positions.size() >= count: break
	var begin = Time.get_ticks_usec()
	for i in mini(count,positions.size()):
		sim.spawn(positions[i],"crawler" if i%10 == 9 else "normal")
		var z: Dictionary = sim.zombies[-1]
		# Preserve population while retaining real hit, damage and flinch work.
		z.hp = 1000000000.0
		z.body = 1000000000.0
	var spawn_ms = (Time.get_ticks_usec()-begin)/1000.0
	game.enemies.sync(sim.zombies,sim.elapsed,false)
	disable_callbacks(root)
	return {"sim":sim,"pawn":p,"weapon":weapon_index,"spawn_ms":spawn_ms,"initial_positions":positions}

func run_case(count: int, scenario: String, round_index: int) -> Dictionary:
	print("CPU PROFILE START count=%d scenario=%s round=%d" % [count,scenario,round_index])
	var staged = stage_case(count,scenario)
	var sim = staged.sim
	var p: Dictionary = staged.pawn
	await physics_frame
	var samples: Array = []
	var moving_total = 0
	var blocked_total = 0
	var shots = 0
	var cpu_total = 0.0
	var initial_hits: int = p.hits
	var valid = sim.zombies.size() == count
	for frame in warmup+sample_count:
		var firing = scenario not in ["movement","bridge"]
		# Replenishment is outside measured sections; actual weapon cooldowns remain.
		p.ammo[staged.weapon] = 100000
		p.slot_ammo[0] = 100000
		p.protection = 10000.0
		# Track a living enemy, as a player would, to exercise narrow-phase hits.
		var target: Dictionary = {}
		if firing:
			var nearest = INF
			for z in sim.zombies:
				var distance: float = p.pos.distance_squared_to(z.pos)
				if z.hp > 0 and distance < nearest:
					nearest = distance
					target = z
			if not target.is_empty():
				var delta: Vector2 = target.pos-p.pos
				p.yaw = atan2(-delta.x,-delta.y)
				p.pitch = atan2(target.height+1.2-(p.height+1.7),maxf(delta.length(),.001))
		sim.submit("solo",{"x":0,"y":0,"yaw":p.yaw,"pitch":p.pitch,"weapon":staged.weapon,"slot":1,"fire":firing})
		var before = Time.get_ticks_usec()
		var shots_before: int = p.shots
		sim.step(1.0/60)
		var simulation_ms = (Time.get_ticks_usec()-before)/1000.0
		# Exact per-frame crosshair scan from main.gd, kept separate from fire().
		before = Time.get_ticks_usec()
		var camera = Transform3D(Basis.from_euler(Vector3(p.pitch,p.yaw,0)),Vector3(p.pos.x,p.height+1.7,p.pos.y))
		var direction = -camera.basis.z
		var endpoint = camera.origin+direction*180
		var surface: Dictionary = sim.arena.surface_hit(camera.origin,endpoint)
		var distance = camera.origin.distance_to(surface.position) if not surface.is_empty() else 180.0
		for z in sim.zombies:
			if z.hp <= 0: continue
			var hit = enemy_view.hit(z,camera.origin,direction,distance,sim.elapsed,false)
			if not hit.is_empty(): distance = hit.distance
		var aim_ms = (Time.get_ticks_usec()-before)/1000.0
		before = Time.get_ticks_usec()
		game.enemies.sync(sim.zombies,sim.elapsed,false)
		var animation_ms = (Time.get_ticks_usec()-before)/1000.0
		if frame >= warmup:
			var sample = {"frame":frame-warmup,"simulation_ms":simulation_ms,"enemy_capsule_ms":float(sim.enemy_physics_usec)/1000.0,"animation_submit_ms":animation_ms,"crosshair_ms":aim_ms,"cpu_sections_ms":simulation_ms+animation_ms+aim_ms,"shot_calls":p.shots-shots_before,"inclusive_ms":{},"exclusive_ms":{}}
			if instrumented:
				for label in sim.inclusive: sample.inclusive_ms[label] = float(sim.inclusive[label])/1000.0
				for label in sim.exclusive: sample.exclusive_ms[label] = float(sim.exclusive[label])/1000.0
			samples.append(sample)
			shots += sample.shot_calls
			cpu_total += sample.cpu_sections_ms
			for z in sim.zombies:
				moving_total += int(z.move_speed > .05)
				blocked_total += int(z.get("crowd_blocked",false))
		else:
			initial_hits = p.hits
		valid = valid and not sim.failed and sim.zombies.size() == count
		await physics_frame
		# Godot's previous engine physics monitor is contextual, not an additive stage.
		if frame >= warmup: samples[-1].engine_physics_monitor_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
	var denominator = float(count*sample_count)
	if scenario not in ["movement","bridge"]: valid = valid and shots > 0 and p.hits > initial_hits
	return {"count":count,"scenario":scenario,"round":round_index,"valid":valid,"live":sim.alive_count(),"shots":shots,"hits":p.hits-initial_hits,"spawn_ms":staged.spawn_ms,"moving_fraction":moving_total/denominator,"blocked_fraction":blocked_total/denominator,"mean_cpu_ms":cpu_total/sample_count,"samples":samples}

func save_results(failed: bool) -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var output = FileAccess.open("res://artifacts/enemy-cpu-profile.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"display_driver":DisplayServer.get_name(),"instrumented":instrumented,"physics_hz":Engine.physics_ticks_per_second,"warmup_frames":warmup,"sample_frames":sample_count,"rounds":rounds,"enemy_mix":"90% normal, 10% crawler","failed":failed,"cases":all_results},"\t"))
	output.close()
