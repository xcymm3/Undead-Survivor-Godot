extends SceneTree
## Native headless counterpart of the Web congestion benchmark. No rendering.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var requested_count = 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--enemy-count="): requested_count = int(arg.get_slice("=",1))
	if requested_count != 0 and requested_count not in [50,100,200]:
		push_error("Unsupported enemy benchmark count")
		quit(1)
		return
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var cases: Array = []
	var failures = 0
	for count in ([requested_count] if requested_count > 0 else [50,100,200]):
		game.start_solo("defense",42)
		game.running = false
		await physics_frame
		var sim = game.sim
		sim.roster.clear()
		sim.defense.started = true
		sim.defense.waiting = false
		for item in sim.defense.structures:
			if item.kind == "turret": item.cooldown = 1000
			if item.kind == "mine": item.spent = true
			if item.kind == "gate": item.hp = 1000000
		game.arena.sync_defense(sim.defense)
		var kinds: Array = root.get_node("Data").enemies.keys()
		for i in count:
			sim.spawn(Vector2((i%5-2)*1.45,-13-floori(i/5)*1.6),kinds[i%kinds.size()])
		var observer = load("res://scripts/qa_enemy_physics.gd").new()
		observer.game = game
		observer.scenario = str(count)
		var samples: Array = []
		var total = 0.0
		var tick_samples: Array = []
		for frame in 1200:
			var tick_begin = Time.get_ticks_usec()
			sim.step(1.0/60)
			var tick_ms = (Time.get_ticks_usec()-tick_begin)/1000.0
			if frame >= 120:
				var value = float(sim.enemy_physics_usec)/1000
				samples.append(value)
				tick_samples.append(tick_ms)
				total += value
			if frame%60 == 0:
				observer.clock = frame/60.0
				observer.check_geometry()
			await physics_frame
		samples.sort()
		tick_samples.sort()
		var result = {"count":count,"mean_ms":total/samples.size(),"p95_ms":samples[floori((samples.size()-1)*.95)],"max_ms":samples[-1],"samples":samples.size(),"issues":observer.issues,"live":sim.alive_count(),"failed":sim.failed}
		result.simulation_ms = {"mean":tick_samples.reduce(func(a,b): return a+b,0.0)/tick_samples.size(),"p95":tick_samples[floori((tick_samples.size()-1)*.95)]}
		if "--baseline-physics" not in OS.get_cmdline_user_args():
			result.cache_hits = game.arena.route_cache_hits
			result.cache_misses = game.arena.route_cache_misses
			result.early_wakes = sim.enemy_crowd.early_wakes
			result.queries = 0
			result.sync_writes = 0
			for body in sim.enemy_crowd.bodies:
				result.queries += body.query_count
				result.sync_writes += body.sync_writes
		cases.append(result)
		if not observer.issues.is_empty() or sim.failed or sim.alive_count() != count: failures += 1
		print("NATIVE ENEMY PHYSICS: "+JSON.stringify(result))
		observer.free()
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var filename = "res://artifacts/enemy-physics-native%s.json" % ("-"+str(requested_count) if requested_count > 0 else "")
	var output = FileAccess.open(filename,FileAccess.WRITE)
	output.store_string(JSON.stringify({"renderer":"headless","engine":Engine.get_version_info().string,"duration_seconds":20,"warmup_seconds":2,"cases":cases,"failures":failures},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
