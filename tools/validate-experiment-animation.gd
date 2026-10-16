extends SceneTree
var failures = 0
var checks = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.start_solo("defense",42029)
	game.sim.defense.erase("intro_elapsed") # Fixture starts after the narrative intro.
	await physics_frame
	game.sim.zombies.clear()
	game.enemies.clear()
	for depth in [35,10,-30]: game.sim.spawn(Vector2(0,depth),"normal")
	game.enemies.experiment_camera_enabled = true
	game.enemies.experiment_camera = Transform3D(Basis.IDENTITY,Vector3(0,4.7,42))
	game.enemies.sync(game.sim.zombies,1.0,false)
	for i in 3:
		var z: Dictionary = game.sim.zombies[i]
		var actor: Dictionary = game.enemies.actors[z.id]
		check(actor.experiment_hz == [60,30,15][i],"distance LOD rate")
		z.move_speed = 4.8
		z.gait = 1.1
	var mid: Dictionary = game.enemies.actors[game.sim.zombies[1].id]
	var previous = mid.skeleton.get_bone_pose(1)
	game.enemies.sync(game.sim.zombies,1.0+1.0/60,false)
	check(mid.skeleton.get_bone_pose(1).is_equal_approx(previous),"30Hz holds pose between samples")
	game.enemies.sync(game.sim.zombies,1.0+1.0/30,false)
	check(not mid.skeleton.get_bone_pose(1).is_equal_approx(previous),"30Hz updates at next sample")
	var exact = load("res://scripts/enemy_view.gd")
	var z: Dictionary = game.sim.zombies[1]
	var poses = exact.transforms(z,1.019,false)
	var origin = Vector3(z.pos.x,4.4,z.pos.y+6)
	var direction = (poses[0].origin-origin).normalized()
	var hit: Dictionary = exact.hit(z,origin,direction,20,1.019,false)
	check(not hit.is_empty(),"authority hit remains precise between animation samples")
	var old_tick: int = mid.experiment_tick
	game.enemies.experiment_camera = Transform3D(Basis(Vector3.UP,PI),Vector3(0,4.7,42))
	game.enemies.sync(game.sim.zombies,2.0,false)
	check(mid.experiment_tick == old_tick,"offscreen bone submission stops")
	game.enemies.experiment_camera = Transform3D(Basis.IDENTITY,Vector3(0,4.7,42))
	game.enemies.sync(game.sim.zombies,2.01,false)
	check(mid.experiment_tick != old_tick,"returning onscreen refreshes pose")
	var mesh = mid.view.mesh
	game.enemies.sync(game.sim.zombies,2.1,false)
	check(mid.view.mesh == mesh,"unchanged mesh selection is cached")
	print("EXPERIMENT ANIMATION: ",checks," checks; ",failures," failures")
	game.return_home()
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
