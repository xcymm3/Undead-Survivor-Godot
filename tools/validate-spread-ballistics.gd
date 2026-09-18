extends SceneTree
var failed: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var data = root.get_node("Data")
	var rows = []
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.start_solo("campaign",71245)
	await physics_frame
	var pawn: Dictionary = game.local_pawn()
	pawn.pos = Vector2(8,60)
	pawn.yaw = 0
	pawn.pitch = 0
	game.sim.zombies.clear()
	for index in [0,1,5,9,3]:
		var w: Dictionary = data.weapons[index]
		pawn.weapon = index
		var straight: Dictionary = w.duplicate(true)
		straight.spread = 0
		game.sim.events.clear()
		game.sim.fire(pawn,straight)
		var baseline: Dictionary = game.sim.events.filter(func(e): return e.kind == "shot")[-1]
		var forward: Vector3 = (baseline.to-baseline.from).normalized()
		for aiming in [false,true]:
			pawn.aim = aiming
			for shot in 8:
				pawn.gun_shots[index] = shot
				game.sim.events.clear()
				game.sim.fire(pawn,w)
				var event: Dictionary = game.sim.events.filter(func(e): return e.kind == "shot")[-1]
				var ray: Vector3 = (event.to-event.from).normalized()
				var actual = forward.cross(ray).length()/forward.dot(ray)
				var expected: float = data.pellet(w,0,shot+1,aiming).length()
				if absf(actual-expected) > .0001: failed.append(w.id+" authority ray does not match ADS/hip cone")
		var hip_max = 0.0
		var ads_max = 0.0
		var hip_energy = 0.0
		var ads_energy = 0.0
		var mean = Vector2.ZERO
		for shot in 2048:
			var hip: Vector2 = data.pellet(w,0,shot,false)
			var ads: Vector2 = data.pellet(w,0,shot,true)
			if hip.length() > w.spread+.000001 or ads.length() > w.adsSpread+.000001: failed.append(w.id+" exceeds cone")
			if not ads.is_equal_approx(hip*(w.adsSpread/w.spread)): failed.append(w.id+" ADS scale mismatch")
			hip_max = maxf(hip_max,hip.length())
			ads_max = maxf(ads_max,ads.length())
			hip_energy += hip.length_squared()
			ads_energy += ads.length_squared()
			mean += hip
		if hip_max < w.spread*.99 or mean.length()/2048 > w.spread*.01: failed.append(w.id+" insufficient or biased sampling")
		rows.append({"weapon":w.id,"samples":2048,"hip_max":hip_max,"ads_max":ads_max,"hip_rms":sqrt(hip_energy/2048),"ads_rms":sqrt(ads_energy/2048),"mean":str(mean/2048)})
	var file = FileAccess.open("res://artifacts/spread-ballistics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows":rows,"failures":failed},"  "))
	print("SPREAD BALLISTICS: ",rows.size()," weapons; ",failed.size()," failures")
	game.return_home()
	game.queue_free()
	await process_frame
	await physics_frame
	quit(0 if failed.is_empty() else 1)
