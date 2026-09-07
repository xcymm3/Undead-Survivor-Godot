extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await physics_frame
	var sim = load("res://scripts/simulation.gd").new(game.arena)
	sim.add_pawn("solo","Profiler",0)
	sim.start("survival")
	sim.wave = 12
	sim.roster.clear()
	for y in range(-44,4,2):
		for x in range(-19,20,2):
			var pos = Vector2(x,y)
			if sim.zombies.size() < 256 and game.arena.clear(pos,pos): sim.spawn(pos,"normal")
	var timings: Array = []
	for i in 90:
		var before = Time.get_ticks_usec()
		sim.step(1.0/60)
		if i >= 10: timings.append((Time.get_ticks_usec()-before)/1000.0)
	timings.sort()
	print("SIMULATION PROFILE enemies=%d median_ms=%.2f p95_ms=%.2f" % [sim.zombies.size(),timings[timings.size()/2],timings[int(timings.size()*.95)]])
	var draw_timings: Array = []
	for i in 20:
		var before = Time.get_ticks_usec()
		game.enemies.sync(sim.zombies,sim.elapsed+i*.016,false)
		draw_timings.append((Time.get_ticks_usec()-before)/1000.0)
	draw_timings.sort()
	print("INSTANCE UPDATE enemies=%d median_ms=%.2f" % [sim.zombies.size(),draw_timings[10]])
	game.queue_free()
	await process_frame
	quit()
