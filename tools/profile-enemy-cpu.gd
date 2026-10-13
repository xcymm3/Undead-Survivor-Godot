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
var wall_seconds = 0.0
var warmup_seconds = 0.0
var epoch_frames = 600
var order_offset = 0
var counts: Array = [50,100,200,300,500]
var scenarios: Array = ["movement","bridge","rifle","auto-shotgun","flamethrower","axe","visible","offscreen","lifecycle","boss","mixed"]

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
		if arg == "--reverse-order": order_offset = 1
		if arg.begins_with("--warmup-seconds="): warmup_seconds = float(arg.get_slice("=",1))
		if arg.begins_with("--wall-seconds="): wall_seconds = float(arg.get_slice("=",1))
		if arg.begins_with("--epoch-frames="): epoch_frames = int(arg.get_slice("=",1))
		if arg.begins_with("--samples="): sample_count = int(arg.get_slice("=",1))
		if arg.begins_with("--warmup="): warmup = int(arg.get_slice("=",1))
		if arg.begins_with("--rounds="): rounds = int(arg.get_slice("=",1))
		if arg.begins_with("--counts="):
			counts.clear()
			for item in arg.get_slice("=",1).split(","): counts.append(int(item))
		if arg.begins_with("--scenarios="): scenarios = Array(arg.get_slice("=",1).split(","))
	if warmup_seconds < 0 or warmup_seconds > 30 or wall_seconds < 0 or wall_seconds > 600 or sample_count < 1 or warmup < 0 or rounds < 1 or rounds > 5 or counts.any(func(n): return n not in [50,100,200,300,500]) or scenarios.any(func(s): return s not in ["movement","bridge","rifle","auto-shotgun","flamethrower","axe","visible","offscreen","lifecycle","boss","mixed"]):
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
		if (round_index+order_offset)%2 == 1:
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
	if game.arena.has_method("experiment_path"): game.arena.experiment_routes.clear()
	if game.sim: game.sim.dispose()
	var sim = (measured_simulation if instrumented else plain_simulation).new(game.arena)
	game.sim = sim
	game.running = true
	game.ui.clear_menu()
	game.effects.clear()
	sim.random.seed = 42029
	sim.add_pawn("solo","CPU profiler",0)
	sim.start("defense")
	sim.roster.clear()
	sim.wave = 10
	sim.defense.wave = 10
	sim.defense.started = true
	sim.defense.waiting = false
	sim.defense.crystal_hp = 1000000000
	var p: Dictionary = sim.pawns.solo
	p.pos = Vector2(0,data.Maps.Defense.BOUNDS.end.y-6) if scenario in ["movement","bridge","visible","offscreen","lifecycle","boss","mixed"] else Vector2(0,38)
	p.height = 3.0
	p.yaw = 0.0
	p.protection = 10000.0
	for item in sim.defense.structures:
		if item.kind == "turret": item.hp = 0
		if item.kind == "mine": item.spent = true
		if item.kind == "gate":
			item.owned = scenario == "bridge"
			item.hp = 1000000000 if scenario == "bridge" else 0
	game.arena.sync_defense(sim.defense)
	var weapon_index = 0
	if scenario not in ["movement","bridge","visible","offscreen","lifecycle","boss","mixed"]:
		for index in data.weapons.size():
			if data.weapons[index].id == scenario: weapon_index = index
	p.weapon1 = weapon_index
	p.weapon = weapon_index
	p.requested = weapon_index
	var positions: Array = []
	if scenario == "bridge":
		# Five lanes start at the intact gate and queue down the ramp/bridge.
		for row in 29:
			for column in 5:
				var point = Vector2((column-2)*1.45,-13-row*1.65)
				if sim.defense_spawner.ground_clear(point): positions.append(point)
		# 300 actors cannot fit in a single bridge queue without leaving the map.
		# Additional ranks approach from the actual far bank, inside map bounds.
		for row in 32:
			for column in 45:
				var point = Vector2(-35.2+column*1.6,-64-row*1.65)
				if sim.defense_spawner.ground_clear(point): positions.append(point)
	else:
		for row in range(32):
			for column in range(16 if scenario in ["visible","offscreen"] else 33):
				var point = Vector2(-25.6+column*1.6,row*1.65) if scenario == "movement" else Vector2(-25.6+column*1.6,34-row*1.65)
				if scenario in ["visible","offscreen"]: point = Vector2(-5.6+column*.7,row*1.05)
				if point.y < 0 or point.y > 35: continue
				if sim.arena.clear(point,point):
					positions.append(point)
				if positions.size() >= count: break
			if positions.size() >= count: break
	var begin = Time.get_ticks_usec()
	for i in mini(count,positions.size()):
		# Controlled ordinary population: crawlers are no longer generated in play.
		sim.spawn(positions[i],(["normal","normal","cone","bucket","imp","shield","berserker","giant","football"][i%9] if scenario == "mixed" else "dancer" if scenario == "boss" and i == 0 else "normal"))
		var z: Dictionary = sim.zombies[-1]
		# Preserve population while retaining real hit, damage and flinch work.
		z.body = 1000000000.0
		z.hp = z.body+z.armor
		if scenario == "mixed" and z.kind == "berserker": z.rage = i%2 == 0
	var spawn_ms = (Time.get_ticks_usec()-begin)/1000.0
	var activation_before = Time.get_ticks_usec()
	game.enemies.sync(sim.zombies,sim.elapsed,false)
	var actor_activation_ms = (Time.get_ticks_usec()-activation_before)/1000.0
	disable_callbacks(root)
	return {"sim":sim,"pawn":p,"weapon":weapon_index,"spawn_ms":spawn_ms,"actor_activation_ms":actor_activation_ms,"initial_positions":positions,"scenario":scenario}

func run_case(count: int, scenario: String, round_index: int) -> Dictionary:
	print("CPU PROFILE START count=%d scenario=%s round=%d" % [count,scenario,round_index])
	var staged = stage_case(count,scenario)
	var sim = staged.sim
	var p: Dictionary = staged.pawn
	await physics_frame
	var samples: Array = []
	var cold_samples: Array = []
	var population_samples = 0
	var moving_total = 0
	var blocked_total = 0
	var shots = 0
	var cpu_total = 0.0
	var initial_hits: int = p.hits
	var valid = sim.zombies.size() == count
	var frame = 0
	var warmup_started = Time.get_ticks_usec()
	var progress_at = warmup_started
	var case_warmup = 2147483647 if warmup_seconds > 0 else warmup
	var measured_started = 0
	var presentation_ms = 0.0
	var peak_live = count
	var measured_elapsed = 0.0
	while frame < case_warmup+sample_count or (wall_seconds > 0 and (measured_started == 0 or Time.get_ticks_usec()-measured_started < wall_seconds*1000000)):
		if measured_started == 0 and warmup_seconds > 0 and Time.get_ticks_usec()-warmup_started >= warmup_seconds*1000000: case_warmup = frame
		if frame == case_warmup:
			measured_started = Time.get_ticks_usec()
			measured_elapsed = sim.elapsed
		if frame >= case_warmup and epoch_frames > 0 and (frame-case_warmup)%epoch_frames == 0:
			reset_epoch(staged)
		var firing = scenario not in ["movement","bridge","visible","offscreen","lifecycle","boss","mixed"]
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
				p.pitch = atan2(data.enemy_ground_height(target.pos,sim.map_id)+1.2-(p.height+1.7),maxf(delta.length(),.001))
		sim.submit("solo",{"x":0,"y":0,"yaw":p.yaw,"pitch":p.pitch,"weapon":staged.weapon,"slot":1,"fire":firing})
		var before = Time.get_ticks_usec()
		var shots_before: int = p.shots
		sim.step(1.0/60)
		if scenario == "lifecycle" and frame%60 == 0:
			for i in 25:
				var victim = sim.zombies.filter(func(z): return z.hp > 0)[0]
				sim.hit_enemy(victim,2000000000,false,p,Vector3(victim.pos.x,4,victim.pos.y))
				sim.spawn(staged.initial_positions[(frame+i)%count],"normal")
		var simulation_ms = (Time.get_ticks_usec()-before)/1000.0
		# Exact per-frame crosshair scan from main.gd, kept separate from fire().
		before = Time.get_ticks_usec()
		var camera = Transform3D(Basis.from_euler(Vector3(p.pitch,p.yaw,0)),Vector3(p.pos.x,p.height+1.7,p.pos.y))
		if scenario == "offscreen": camera.basis = Basis(Vector3.UP,PI)
		var direction = -camera.basis.z
		var endpoint = camera.origin+direction*180
		var surface: Dictionary = sim.arena.surface_hit(camera.origin,endpoint)
		var distance = camera.origin.distance_to(surface.position) if not surface.is_empty() else 180.0
		var aim_candidates: Array = sim.enemy_ray_candidates(camera.origin,direction,distance) if sim.has_method("enemy_ray_candidates") else sim.zombies
		for z in aim_candidates:
			if z.hp <= 0: continue
			var hit = enemy_view.hit(z,camera.origin,direction,distance,sim.elapsed,false)
			if not hit.is_empty(): distance = hit.distance
		var aim_ms = (Time.get_ticks_usec()-before)/1000.0
		before = Time.get_ticks_usec()
		game.enemies.sync(sim.zombies,sim.elapsed,false)
		var animation_ms = (Time.get_ticks_usec()-before)/1000.0
		before = Time.get_ticks_usec()
		game.camera.transform = camera
		game.weapon.sync(p,1.0/60,sim.elapsed,endpoint)
		game.ui.native_hud.sync()
		game.sound.sync_enemy_steps(sim.zombies,camera.origin,1.0/60)
		game.handle_effects(sim.events)
		game.effects.step(1.0/60)
		game.coins.sync(sim.coin_drops)
		presentation_ms = (Time.get_ticks_usec()-before)/1000.0
		peak_live = maxi(peak_live,sim.alive_count())
		if frame >= case_warmup:
			var sample = {"frame":frame-case_warmup,"simulation_ms":simulation_ms,"enemy_capsule_ms":0.0,"animation_submit_ms":animation_ms,"crosshair_ms":aim_ms,"presentation_ms":presentation_ms,"cpu_sections_ms":simulation_ms+animation_ms+aim_ms+presentation_ms,"live_count":sim.alive_count(),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"shot_calls":p.shots-shots_before,"inclusive_ms":{},"exclusive_ms":{}}
			if instrumented:
				sample["call_counts"] = sim.call_counts.duplicate()
				for label in sim.inclusive: sample.inclusive_ms[label] = float(sim.inclusive[label])/1000.0
				for label in sim.exclusive: sample.exclusive_ms[label] = float(sim.exclusive[label])/1000.0
				if sim.has_method("experiment_record_detail"):
					sample["detail_counts"] = sim.experiment_count.duplicate()
					sample["detail_ms"] = {}
					for label in sim.experiment_detail: sample.detail_ms[label] = float(sim.experiment_detail[label])/1000.0
					sample["animation_detail_us"] = game.enemies.experiment_animation_detail.duplicate()
			if sim.has_method("enemy_ray_candidates"):
				sample["cpu_work"] = {"neighbors":sim.cpu_neighbor_visits,"target_refreshes":sim.cpu_target_refreshes,"astar_used":sim.path_scheduler.used,"astar_pending":sim.path_scheduler.pending.size(),"ray_builds":sim.enemy_ray_index.builds,"ray_queries":sim.enemy_ray_index.queries}
			samples.append(sample)
			shots += sample.shot_calls
			cpu_total += sample.cpu_sections_ms
			for z in sim.zombies:
				if z.hp <= 0: continue
				population_samples += 1
				moving_total += int(z.move_speed > .05)
				blocked_total += int(z.move_speed <= .05)
		else:
			cold_samples.append({"simulation_ms":simulation_ms,"animation_submit_ms":animation_ms,"crosshair_ms":aim_ms,"cpu_sections_ms":simulation_ms+animation_ms+aim_ms})
			initial_hits = p.hits
		valid = valid and not sim.failed and (sim.alive_count() >= count if scenario == "boss" else sim.alive_count() == count)
		if Time.get_ticks_usec()-progress_at >= 5000000:
			progress_at = Time.get_ticks_usec()
			print("CPU PROFILE PROGRESS ",JSON.stringify({"count":count,"scenario":scenario,"round":round_index,"phase":"sample" if measured_started > 0 else "warmup","frames":frame,"samples":samples.size(),"sample_seconds":float(progress_at-measured_started)/1000000 if measured_started > 0 else 0.0,"mean_cpu_ms":cpu_total/maxi(1,samples.size())}))
		await physics_frame
		frame += 1
		# Godot's previous engine physics monitor is contextual, not an additive stage.
		if not samples.is_empty(): samples[-1].engine_physics_monitor_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
	var denominator = float(maxi(1,population_samples))
	if scenario not in ["movement","bridge","visible","offscreen","lifecycle","boss","mixed"]: valid = valid and shots > 0 and p.hits > initial_hits
	return {"count":count,"scenario":scenario,"round":round_index,"valid":valid,"live":sim.alive_count(),"shots":shots,"hits":p.hits-initial_hits,"spawn_ms":staged.spawn_ms,"actor_activation_ms":staged.actor_activation_ms,"moving_fraction":moving_total/denominator,"blocked_fraction":blocked_total/denominator,"warmup_frames":case_warmup,"peak_live":peak_live,"simulation_seconds":sim.elapsed-measured_elapsed,"wall_seconds":float(Time.get_ticks_usec()-measured_started)/1000000,"mean_cpu_ms":cpu_total/maxi(1,samples.size()),"cold_samples":cold_samples,"samples":samples}

func save_results(failed: bool) -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var output = FileAccess.open("res://artifacts/enemy-cpu-profile.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"movement_model":"2d-overlap", "engine":Engine.get_version_info().string,"display_driver":DisplayServer.get_name(),"instrumented":instrumented,"physics_hz":Engine.physics_ticks_per_second,"warmup_frames":warmup,"warmup_seconds":warmup_seconds,"sample_frames":sample_count,"rounds":rounds,"enemy_mix":"scenario-specific; normal controls and mixed/boss transients", "epoch_frames":epoch_frames,"failed":failed,"cases":all_results},"\t"))
	output.close()

func reset_epoch(staged: Dictionary) -> void:
	var sim = staged.sim
	if staged.scenario in ["boss","lifecycle"]: return
	sim.paths.clear()
	if sim.has_method("enemy_ray_candidates"):
		sim.path_scheduler.clear()
		sim.target_cache.clear()
		sim.ray_index_valid = false
	sim.player_route_cache.clear()
	for i in sim.zombies.size():
		var z: Dictionary = sim.zombies[i]
		z.pos = staged.initial_positions[i]
		z.attack_time = 0.0
		z.state = "ready"
		z.state_time = 0.0
		z.move_speed = 0.0
		z.shove_time = 0.0
		z.shove_velocity = Vector2.ZERO
