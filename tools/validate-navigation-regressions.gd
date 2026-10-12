extends SceneTree
## Real terrain and authority movement regressions; no renderer or desktop input.
var game
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func fresh(owned := false):
	var progress = root.get_node("Progress").store
	for id in progress.BUILDINGS: progress.data.buildings[id].owned = owned
	game.start_solo("defense",19457)
	game.running = false
	return game.sim

func crowd(sim) -> void:
	sim.crowd_buckets.clear()
	for z in sim.zombies:
		var key = Vector2i(floori(z.pos.x/3),floori(z.pos.y/3))
		if not sim.crowd_buckets.has(key): sim.crowd_buckets[key] = []
		sim.crowd_buckets[key].append(z)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	var sim = fresh()
	await physics_frame
	# The shop is ordinary walkable terrain, including pursuit of its occupant.
	var layout = root.get_node("Data").Maps.Defense
	sim.spawn(Vector2(0,layout.SHOP_AREA.position.y-.5),"normal")
	var z: Dictionary = sim.zombies[-1]
	for tick in 100:
		sim.elapsed += .05
		sim.update_zombie(z,sim.choose_zombie_target(z,sim.pawns.values()),.05)
	check(layout.SHOP_AREA.has_point(z.pos) and sim.pawns.solo.hp < 100,"Enemy enters shop and damages its starting player (pos=%s)" % z.pos)
	# Sample actual seeded spawn candidates and execute their paths, not just A* queries.
	sim = fresh()
	await physics_frame
	for attempt in 4096:
		var point: Vector2 = sim.defense_spawner.random_point()
		if sim.defense_spawner.ground_clear(point): sim.spawn(point,"normal")
		if sim.zombies.size() == 50: break
	for tick in 1000:
		sim.elapsed += .05
		for enemy in sim.zombies:
			sim.move_zombie(enemy,Vector2(0,-30),4.8,.05,enemy.pos.distance_to(Vector2(0,-30)),1.25,true)
	var arrived = sim.zombies.filter(func(enemy): return enemy.pos.y > -35).size()
	check(arrived == 50,"All 50 far-bank births actually traverse woodland and bridge (%d/50)" % arrived)
	sim = fresh()
	await physics_frame
	for i in 100: sim.spawn(Vector2(-2.8+(i%8)*.8,-60-(i/8)*.45),"normal")
	for tick in 600:
		sim.elapsed += .05
		crowd(sim)
		for enemy in sim.zombies:
			sim.move_zombie(enemy,Vector2(0,-8),4.8,.05,enemy.pos.distance_to(Vector2(0,-8)),1.25,true)
	arrived = sim.zombies.filter(func(enemy): return enemy.pos.y > -12).size()
	check(arrived == 100,"100 crowded enemies leave bridge and climb ramp (%d/100)" % arrived)
	for kind in ["normal","imp","giant"]:
		for side in [-2.8,0.0,2.8]:
			sim = fresh(true)
			await physics_frame
			var gate: Dictionary = sim.defense_director.structures.find("bridge_entry_gate")
			sim.spawn(Vector2(side*12,-110),kind)
			z = sim.zombies[-1]
			for tick in 900:
				sim.elapsed += .05
				sim.update_zombie(z,sim.choose_zombie_target(z,sim.pawns.values()),.05)
			check(gate.hp < gate.max_hp,"%s approaches and attacks intact lower gate from x=%.1f (pos=%s)" % [kind,side,z.pos])
	for kind in ["normal","imp","giant"]:
		for index in 8:
			sim = fresh(true)
			await physics_frame
			var turret: Dictionary = sim.defense_director.structures.find("turret_left")
			turret.hp = 100000
			var direction = Vector2(cos(index*TAU/8),sin(index*TAU/8))
			var birth: Vector2 = turret.pos+direction*4
			if not game.arena.clear(birth,birth): birth.y = -8.6
			sim.spawn(birth,kind)
			z = sim.zombies[-1]
			var first_attack = Vector2.INF
			var excursion := 0.0
			for tick in 240:
				sim.elapsed += .05
				sim.update_zombie(z,sim.defense_director.structures.target(turret,z.pos),.05)
				if z.attack_time > 0 and first_attack == Vector2.INF: first_attack = z.pos
				if first_attack != Vector2.INF: excursion = maxf(excursion,z.pos.distance_to(first_attack))
			check(turret.hp < 100000 and excursion < .15,"%s turret attack direction %d stays planted (travel=%.3f pos=%s)" % [kind,index,excursion,z.pos])
			var view = load("res://scripts/enemy_view.gd")
			z.attack_time = root.get_node("Data").attack(kind).y-.001
			var recovery: Transform3D = view.root_transform(z,sim.elapsed,true,0)
			z.attack_time = 0
			var idle: Transform3D = view.root_transform(z,sim.elapsed,true,0)
			check(recovery.basis.orthonormalized().get_rotation_quaternion().angle_to(idle.basis.orthonormalized().get_rotation_quaternion()) < .01,"%s direction %d attack pose returns smoothly to idle" % [kind,index])
	# The crystal is stationary too: verify every approach and whole attack cycles.
	for kind in ["normal","imp","giant"]:
		for index in 8:
			sim = fresh()
			await physics_frame
			sim.defense.crystal_hp = 100000
			var direction = Vector2(cos(index*TAU/8),sin(index*TAU/8))
			sim.spawn(layout.CRYSTAL+direction*5,kind)
			z = sim.zombies[-1]
			var first_attack = Vector2.INF
			var excursion := 0.0
			for tick in 240:
				sim.elapsed += .05
				sim.update_zombie(z,sim.crystal_target(),.05)
				if z.attack_time > 0 and first_attack == Vector2.INF: first_attack = z.pos
				if first_attack != Vector2.INF: excursion = maxf(excursion,z.pos.distance_to(first_attack))
			check(sim.defense.crystal_hp < 100000 and excursion < .03,"%s crystal direction %d attacks without retreat/advance oscillation (travel=%.3f)" % [kind,index,excursion])
	sim = fresh()
	await physics_frame
	var pawn: Dictionary = sim.pawns.solo
	var body = sim.player_body(pawn)
	for side in [-1.0,1.0]:
		for z_start in [-26.0,-19.0,-11.0]:
			pawn.pos = Vector2(side*29,z_start)
			pawn.height = 0
			pawn.velocity = 0
			body.sync_from(pawn)
			body.velocity.y = body.JUMP_SPEED
			for tick in 180: body.advance(Vector2(side*12,0),.01)
			check(absf(body.position.x) < 31,"Shelf outer wall stops a sprint-jump on side %.0f at z=%.0f" % [side,z_start])
		pawn.pos = Vector2(side*12,-25)
		pawn.height = 0
		pawn.velocity = 0
		body.sync_from(pawn)
		body.velocity.y = body.JUMP_SPEED
		for tick in 180: body.advance(Vector2(0,-12),.01)
		check(body.position.z > -27.5,"Shelf cliff wall stops a sprint-jump on side %.0f" % side)
		# Simulate a real fall over the low ramp rail, then walk back to its foot.
		pawn.pos = Vector2(side*7,-15)
		pawn.height = 4
		pawn.velocity = 0
		body.sync_from(pawn)
		for tick in 120: body.advance(Vector2.ZERO,.01)
		check(body.grounded and absf(body.position.y) < .1,"Side %.0f fall lands safely on its shelf" % side)
		for tick in 240: body.advance(Vector2(0,-5),.01)
		body.velocity.y = body.JUMP_SPEED
		for tick in 90: body.advance(Vector2(-side*5,0),.01)
		for tick in 380: body.advance(Vector2(0,5),.01)
		check(body.position.z > -10 and body.position.y > 2.9,"Side %.0f shelf returns via ramp foot to plateau (pos=%s)" % [side,body.position])
	print("NAVIGATION REGRESSIONS: %d checks; %d failures" % [checks,failures])
	game.free()
	quit(1 if failures else 0)
