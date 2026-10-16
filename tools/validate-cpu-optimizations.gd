extends SceneTree
var failed = 0
var checks = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.start_solo("defense",42029)
	game.sim.defense.erase("intro_elapsed") # Fixture starts after the narrative intro.
	var data = root.get_node("Data")
	var sim = game.sim
	sim.zombies.clear()
	var rng = RandomNumberGenerator.new()
	rng.seed = 712934
	var kinds = ["normal","crawler","cone","bucket","imp","shield","berserker","giant","football","dancer"]
	for i in 300: sim.spawn(Vector2(rng.randf_range(-25,25),rng.randf_range(-90,35)),kinds[i%kinds.size()])
	var index = load("res://scripts/enemy_ray_index.gd").new()
	index.rebuild(sim.zombies)
	var precise_hits = 0
	for i in 600:
		var z: Dictionary = sim.zombies[i%300]
		z.heading = rng.randf_range(-PI,PI)
		z.attack_time = .2 if i%3==0 else 0.0
		z.armor = 0 if i%4==0 else data.enemies[z.kind].armor
		z["emerge_remaining"] = .7 if i%7==0 else 0.0
		var origin = Vector3(rng.randf_range(-45,45),rng.randf_range(.2,9),rng.randf_range(-105,50))
		var end = Vector3(z.pos.x,data.enemy_ground_height(z.pos,z.map_id)+rng.randf_range(.1,3),z.pos.y)
		var direction = (end-origin).normalized()
		var candidates: Array = index.query(origin,direction,180)
		for enemy in sim.zombies:
			var hit = load("res://scripts/enemy_view.gd").hit(enemy,origin,direction,180,sim.elapsed,false)
			if not hit.is_empty():
				precise_hits += 1
				check(candidates.has(enemy),"Ray index dropped an exact hit")
	check(precise_hits>100,"Randomized rays exercise sufficient real intersections")
	sim.ray_index_valid = false
	var before = sim.enemy_ray_index.builds
	for i in 20: sim.enemy_ray_candidates(Vector3(0,4,38),Vector3.FORWARD,180)
	check(sim.enemy_ray_index.builds==before+1,"Twenty rays share a single index rebuild")
	var victim: Dictionary = sim.zombies[0]
	victim.hp = 0
	check(not sim.enemy_ray_candidates(Vector3(victim.pos.x,8,victim.pos.y),Vector3.DOWN,180).has(victim),"Dead enemies are immediately excluded")
	sim.spawn(Vector2(0,20),"giant")
	check(sim.enemy_ray_candidates(Vector3(0,8,20),Vector3.DOWN,180).has(sim.zombies[-1]),"Spawn invalidates the shared index")
	# Compare cached building enumeration with the original target decision.
	for i in 120:
		sim.elapsed += .05
		var z: Dictionary = sim.zombies[1+i%299]
		sim.target_cache.clear()
		var a: Dictionary = sim.original_choose_zombie_target(z,sim.pawns.values())
		var b: Dictionary = sim.choose_zombie_target(z,sim.pawns.values())
		check(a.id==b.id and a.pos==b.pos,"Cached building target differs from original decision")
	# Real A* calls are capped, both direct requests and queued jobs count.
	sim.path_scheduler.clear()
	for i in 300:
		sim.path_scheduler.request("move:"+str(i),Vector2(0,-45),Vector2(0,-30),0,100,sim.arena)
	check(sim.path_scheduler.used==12 and sim.path_scheduler.pending.size()==288,"300 simultaneous routes execute only 12 A* calls")
	for tick in 25: sim.path_scheduler.begin(100+(tick+1)/60.0,sim.arena)
	check(sim.path_scheduler.pending.is_empty() and sim.path_scheduler.peak<=12,"Pending routes drain without starvation or budget overruns")
	sim.path_scheduler.clear()
	for i in 20: sim.path_scheduler.request("move:"+str(i),Vector2(0,-45),Vector2(0,-30),0,200,sim.arena)
	sim.arena.navigation_revision += 1
	sim.path_scheduler.begin(201,sim.arena)
	check(sim.path_scheduler.pending.is_empty() and sim.path_scheduler.ready.is_empty(),"Building revision invalidates pending and completed routes")
	print("CPU OPTIMIZATIONS: ",checks," checks; ",precise_hits," precise hits; ",failed," failures")
	game.return_home()
	game.queue_free()
	await process_frame
	quit(0 if failed==0 else 1)
