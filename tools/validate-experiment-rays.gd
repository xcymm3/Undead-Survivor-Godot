extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.start_solo("defense",42029)
	await physics_frame
	var sim = game.sim
	sim.zombies.clear()
	var rng = RandomNumberGenerator.new()
	rng.seed = 712934
	var data = root.get_node("Data")
	var kinds = ["normal","crawler","cone","bucket","imp","shield","berserker","giant","football","dancer"]
	for i in 300:
		sim.spawn(Vector2(rng.randf_range(-25,25),rng.randf_range(-90,35)),kinds[i%kinds.size()])
	var reference = load("res://scripts/experiment_reference_enemy_view.gd")
	var view = load("res://scripts/enemy_view.gd")
	var checks = 0
	var failures = 0
	for i in 600:
		var z: Dictionary = sim.zombies[i%300]
		z.heading = rng.randf_range(-PI,PI)
		z.attack_time = .2 if i%3 == 0 else 0.0
		z.armor = 0 if i%4 == 0 else data.enemies[z.kind].armor
		z["emerge_remaining"] = .7 if i%7 == 0 else 0.0
		z.gait = rng.randf_range(0,TAU)
		var origin = Vector3(rng.randf_range(-45,45),rng.randf_range(.2,9),rng.randf_range(-105,50))
		var target = Vector3(z.pos.x,data.enemy_ground_height(z.pos,z.map_id)+rng.randf_range(.1,3),z.pos.y)
		var direction = (target-origin).normalized()
		var distance = 180.0
		var time = floorf(i/30.0)/60.0
		var grid = load("res://scripts/experiment_ray_grid.gd").new(sim.zombies)
		var candidates: Array = grid.query(origin,direction,distance)
		for item in sim.zombies:
			var a: Dictionary = reference.hit(item,origin,direction,distance,time,false)
			if not a.is_empty() and not candidates.has(item): failures += 1
			if a.is_empty(): continue
			var b: Dictionary = view.hit(item,origin,direction,distance,time,false)
			checks += 1
			if b.is_empty() or absf(a.distance-b.distance) > .000001 or a.head != b.head or a.armor != b.armor: failures += 1
	print("EXPERIMENT RAYS: 600 randomized mixed-kind rays; ",checks," precise hits; ",failures," failures")
	game.return_home()
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 and checks > 100 else 1)
