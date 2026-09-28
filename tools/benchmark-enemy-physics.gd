extends SceneTree
## Native headless counterpart of the Web congestion benchmark. No rendering.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var cases: Array = []
	var failures = 0
	for count in [50,100,200]:
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
		for frame in 1200:
			sim.step(1.0/60)
			if frame >= 120:
				var value = float(sim.enemy_physics_usec)/1000
				samples.append(value)
				total += value
			if frame%60 == 0:
				observer.clock = frame/60.0
				observer.check_geometry()
			await physics_frame
		samples.sort()
		var result = {"count":count,"mean_ms":total/samples.size(),"p95_ms":samples[floori((samples.size()-1)*.95)],"max_ms":samples[-1],"samples":samples.size(),"issues":observer.issues,"live":sim.alive_count(),"failed":sim.failed}
		cases.append(result)
		if not observer.issues.is_empty() or sim.failed or sim.alive_count() != count: failures += 1
		print("NATIVE ENEMY PHYSICS: "+JSON.stringify(result))
		observer.free()
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var output = FileAccess.open("res://artifacts/enemy-physics-native.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"renderer":"headless","engine":Engine.get_version_info().string,"duration_seconds":20,"warmup_seconds":2,"cases":cases,"failures":failures},"\t"))
	output.close()
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
