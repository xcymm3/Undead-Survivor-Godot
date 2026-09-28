extends SceneTree
var checks = 0
var failures = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if value: print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.start_solo("defense",42)
	game.running = false
	await physics_frame
	var sim = game.sim
	sim.spawn(Vector2(0,-45),"normal")
	var z: Dictionary = sim.zombies[-1]
	var body = sim.enemy_bodies[z.id]
	sim.physical_move(z,Vector2.ZERO,.016,true)
	var writes: int = body.sync_writes
	for i in 20: sim.enemy_body(z)
	check(body.sync_writes == writes,"Unchanged state does not publish duplicate native transforms")
	check(body.flat_region.has_point(z.pos),"Flat support cache comes from the real bridge collision box")
	var queries: int = body.query_count
	sim.physical_move(z,Vector2(0,2),.016)
	check(body.query_count-queries <= 3,"Validated flat motion avoids repeated support casts and rays")
	check(PhysicsServer3D.body_get_state(body.peer_rid,PhysicsServer3D.BODY_STATE_TRANSFORM) == body.global_transform,"Dirty pose is published to the native peer in the same tick")
	var route = game.arena.enemy_path(Vector2(0,-55),Vector2(0,-13),"normal")
	var hits: int = game.arena.route_cache_hits
	var shared = game.arena.enemy_path(Vector2(0,-55),Vector2(0,-13),"normal")
	check(not route.is_empty() and game.arena.route_cache_hits > hits,"Same body profile and corridor reuse an existing native-grid route")
	shared.remove_at(0)
	check(game.arena.enemy_path(Vector2(0,-55),Vector2(0,-13),"normal") == route,"An actor cannot mutate the shared route owned by other actors")
	sim.zombies.clear()
	sim.sync_enemy_bodies()
	sim.spawn(Vector2(0,20),"normal")
	var front: Dictionary = sim.zombies[-1]
	sim.spawn(Vector2(0,19.05),"normal")
	var rear: Dictionary = sim.zombies[-1]
	body = sim.enemy_bodies[rear.id]
	sim.physical_move(front,Vector2.ZERO,.016,true)
	sim.physical_move(rear,Vector2.ZERO,.016,true)
	sim.physical_move(rear,Vector2(0,4),.1)
	check((body.blocker_a == front.id or body.blocker_b == front.id) and rear.crowd_blocked,"Native peer collision records the actual queue blocker")
	var goal = Vector2(0,30)
	body.wait_goal = goal
	body.wait_revision = game.arena.navigation_revision
	body.next_crowd_probe = 10
	rear.blocked_time = 1.0
	var attempts: int = body.move_attempts
	sim.move_zombie(rear,goal,4,.016,11,1.25)
	check(body.move_attempts == attempts,"An unchanged blocker sleeps without repeating physics or navigation")
	sim.physical_move(front,Vector2(2,0),.15)
	check(sim.enemy_crowd.needs_wake(body,goal),"A blocking neighbour moving eight centimetres wakes the queue")
	sim.move_zombie(rear,goal,4,.016,11,1.25)
	check(body.move_attempts > attempts,"Neighbour movement bypasses the pending retry deadline")
	front.pos = Vector2(0,20)
	rear.pos = Vector2(0,19.05)
	sim.physical_move(front,Vector2.ZERO,.016,true)
	sim.physical_move(rear,Vector2(0,4),.1)
	body.wait_goal = goal
	body.wait_revision = game.arena.navigation_revision
	sim.enemy_crowd.index_cells()
	sim.hit_enemy(front,10000,false,sim.pawns.solo,sim.enemy_bodies[front.id].position)
	check(sim.enemy_crowd.needs_wake(body,goal),"Death removes collision and wakes dependent queues immediately")
	sim.sync_enemy_bodies()
	check(sim.enemy_crowd.cells.is_empty(),"Slot compaction invalidates old spatial indices before the next batch")
	check(sim.enemy_crowd.ids.size() == 1 and sim.enemy_crowd.ids[0] == rear.id and sim.enemy_crowd.slots[rear.id] == 0,"Removing a dead slot compacts all physics arrays without stale indices")
	check(sim.enemy_crowd.positions[0] == rear.pos,"Packed physics position stays consistent with the authoritative snapshot")
	body.wait_revision = game.arena.navigation_revision
	var revision: int = game.arena.navigation_revision
	sim.defense_director.structures.damage("bridge_gate",1000)
	check(game.arena.navigation_revision > revision and game.arena.shared_routes.is_empty(),"Gate destruction invalidates shared routes")
	check(sim.enemy_crowd.needs_wake(body,goal),"Gate destruction wakes queued actors before their retry timer")
	print("ENEMY OPTIMIZATION: %d checks; %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
