extends SceneTree
var game
var failures: Array[String] = []
var count = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	count += 1
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	var data = root.get_node("Data")
	var session = root.get_node("Session")
	check(game.ui.root.find_child("Map_dust",true,false) != null,"Homepage offers Desert City")
	check(game.ui.root.find_child("Map_outpost",true,false) != null,"Homepage retains Pine Outpost")
	game.ui.root.find_child("Map_dust",true,false).pressed.emit()
	await process_frame
	await physics_frame
	await process_frame
	check(game.arena.map_id == "dust" and data.settings.map_id == "dust","Selection loads and remembers the desert map")
	check(game.arena.find_child("River",true,false) == null,"Desert has no river node")
	check(game.arena.has_node("DesertCity/CourtyardsAndSlopes"),"Desert uses the saved native scene")
	game.start_solo("survival")
	check(game.sim.map_id == "dust" and game.sim.roster.size() > 0,"Single player starts waves on the selected map")
	check(game.local_pawn().pos == game.arena.definition.spawn,"Player uses map-specific spawn")
	check(not game.sim.is_water(Vector2(0,-17)),"Old river coordinates do not cause desert wading")
	for point in game.arena.definition.spawns:
		check(game.arena.clear(point,point),"Spawn is navigable: "+str(point))
		var route: PackedVector2Array = game.arena.path_to(point,game.arena.definition.spawn)
		check(not route.is_empty(),"Spawn connects to the player courtyard: "+str(point))
	for point in game.arena.definition.safe:
		check(game.arena.clear(point,point),"Respawn is navigable: "+str(point))
	var layout = load("res://scripts/dust_layout.gd")
	for point in [layout.point(350,350),layout.point(380,209),layout.point(170,141),layout.point(269,330)]:
		check(not game.arena.path_to(point,game.arena.definition.spawn).is_empty(),"Key Dust route reaches courtyard: "+str(point))
	check(not game.arena.clear(layout.point(146,140),layout.point(156,140)),"Enemies cannot step sideways through a platform cliff")
	for point in [game.arena.definition.spawn,layout.point(351,365),layout.point(170,180),layout.point(312,311)]:
		var height: float = layout.height(point)
		var ray = game.arena.surface_hit(Vector3(point.x,height+1,point.y),Vector3(point.x,-3,point.y))
		check(not ray.is_empty() and absf(ray.position.y-height) < .15,"Floor collision follows map height: "+str(point))
		var pawn: Dictionary = game.local_pawn()
		pawn.pos = point
		pawn.height = height+.1
		pawn.velocity = 0
		for i in 25: game.sim.update_pawn(pawn,1.0/60)
		check(pawn.grounded and absf(pawn.height-height) < .15,"Player lands on map terrain: "+str(point))
		check(not pawn.wading,"Desert terrain never applies wading")
	# Native character movement is blocked by a real exterior wall.
	var p: Dictionary = game.local_pawn()
	p.pos = layout.point(70,240)
	p.height = 0
	p.yaw = 0
	p.velocity = 0
	game.sim.submit(p.id,{"x":-1.0})
	for i in 20: game.sim.update_pawn(p,1.0/60)
	check(p.pos.x > layout.point(59,240).x,"Exterior wall stops the player capsule")
	game.return_home()
	game.start_solo("survival")
	for i in 90: game.sim.step(1.0/60)
	check(not game.sim.zombies.is_empty(),"Survival waves spawn on the new map")
	check(game.sim.zombies.all(func(z): return z.map_id == "dust"),"Enemy snapshots identify their terrain")
	game.return_home()
	game.ui.root.find_child("Map_outpost",true,false).pressed.emit()
	await process_frame
	check(game.arena.map_id == "outpost" and game.arena.has_node("River"),"Switching back restores the original river")
	# Feed a real encoded start packet: only the host controls the loaded map.
	session.active = true
	session.host_id = "host"
	session.local_id = "client"
	session.members = {"host":"房主","client":"队友"}
	session.playing = false
	var packet = {"type":"start","members":session.members,"nonce":"map-test","map_id":"dust"}
	session.receive("stranger",session.encode_packet(packet))
	check(not session.playing,"Non-host cannot choose a multiplayer map")
	var preparation: Dictionary = packet.duplicate()
	preparation.type = "prepare"
	session.receive("host",session.encode_packet(preparation))
	await physics_frame
	await process_frame
	check(session.loading and not session.playing,"Loading the map does not start combat early")
	session.receive("host",session.encode_packet(packet))
	check(session.playing and game.arena.map_id == "dust" and game.sim.map_id == "dust","Host start packet loads the same map on client")
	check(game.sim.player_bodies.is_empty(),"Client does not create authoritative physics bodies")
	var state: Dictionary = game.sim.snapshot()
	check(session.valid_world(state),"Matching map snapshot is accepted")
	state.map_id = "outpost"
	check(not session.valid_world(state),"Mismatched map snapshot is rejected")
	var recovered: Dictionary = session.recover_input_edges("test",{"jump":false,"jump_seq":1,"reload_seq":1})
	check(recovered.jump and recovered.reload,"Later packets recover coalesced jump and reload edges")
	recovered = session.recover_input_edges("test",{"jump":false,"jump_seq":1,"reload_seq":1})
	check(not recovered.jump and not recovered.reload,"Recovered action edges are consumed once")
	game.return_home()
	game.queue_free()
	await process_frame
	print("MAP VALIDATION: %d checks; %d failures" % [count,failures.size()])
	quit(0 if failures.is_empty() else 1)
