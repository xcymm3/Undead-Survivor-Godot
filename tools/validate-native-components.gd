extends SceneTree
var failures: Array[String] = []
var checks = 0
var game

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var maps = load("res://scripts/map_catalog.gd")
	check(maps.IDS == ["graypine_night"] and game.arena.map_id == "graypine_night","Night is the only registered and default map")
	for retired in ["outpost","dust","graypine_ferry"]: check(not maps.valid(retired),"Retired map rejected: "+retired)
	check(not game.arena.obstacles.is_empty(),"Native scene retains navigation footprints")
	var ray = game.arena.surface_hit(Vector3(0,5,9),Vector3(0,-2,9))
	check(not ray.is_empty(),"Baked ground participates in native physics rays")
	check(RenderingServer.render_loop_enabled,"Normal rendering uses the engine loop")
	game.start_solo("campaign")
	game.ui.tick(.016)
	check(game.ui.native_hud.visible,"Native HUD appears on game start")
	check(game.ui.native_hud.cards.has("solo"),"Player card is a retained control")
	var card: Dictionary = game.ui.native_hud.cards.solo
	check(card.bar is ProgressBar and card.name is Label,"Health and name use native widgets")
	var pawn: Dictionary = game.local_pawn()
	pawn.hp = 42
	game.ui.tick(.016)
	check(card.bar.value == 42 and card.hp.text == "+42","Native health widget updates from authority")
	check(card.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE,"HUD does not capture combat input")
	await process_frame
	await process_frame
	var single_width: float = card.panel.size.x
	check(single_width >= 210 and single_width <= 260,"Single health card stays compact")
	for i in 1:
		var peer: Dictionary = pawn.duplicate(true)
		peer.id = "hud_fixture_"+str(i)
		peer.name = "队友长名字布局验证"
		game.sim.pawns[peer.id] = peer
	game.ui.tick(.016)
	await process_frame
	await process_frame
	check(game.ui.native_hud.cards.size() == 2 and is_equal_approx(card.panel.size.x,single_width),"Each teammate gets a separate card without stretching the local card")
	for id in game.sim.pawns.keys():
		if str(id).begins_with("hud_fixture_"): game.sim.pawns.erase(id)
	game.ui.tick(.016)

	game.ui.native_hud.size = Vector2(960,540)
	game.ui.native_hud.layout()
	check(game.ui.native_hud.content.size.x >= 1440,"HUD maintains readable layout at smaller viewport sizes")
	var original = InputMap.action_get_events("jump")
	InputMap.action_erase_events("jump")
	var rebound = InputEventKey.new()
	rebound.physical_keycode = KEY_J
	InputMap.action_add_event("jump",rebound)
	rebound.pressed = true
	game._unhandled_input(rebound)
	check(game.input_state().jump,"Jump obeys an InputMap rebind")
	var space = InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	game._unhandled_input(space)
	check(not game.input_state().jump,"Old jump key is no longer hard-coded")
	InputMap.action_erase_events("jump")
	for event in original: InputMap.action_add_event("jump",event)
	var fire = InputEventAction.new()
	fire.action = "fire"
	fire.pressed = true
	game._input(fire)
	check(game.input_state().fire,"Attack accepts an action independent of device")
	game.pause_game()
	check(not game.input_state().fire,"Pause clears held attack")
	game.resume_game()
	var fullscreen = InputEventKey.new()
	fullscreen.physical_keycode = KEY_F11
	fullscreen.pressed = true
	check(fullscreen.is_action_pressed("fullscreen"),"Fullscreen default maps to F11")
	game.sound.play_at("gun",Vector3(7,2,-8))
	check(game.sound.spatial_players[0].global_position == Vector3(7,2,-8),"World audio retains the event position")
	check(game.sound.spatial_players[0].max_distance > 0,"World audio has distance attenuation")
	game.sound.clear_effects()
	check(game.sound.spatial_players.all(func(p): return p.stream == null),"World voice resources clear on scene reset")
	await validate_equipment()
	validate_close_combat()
	validate_revolver()
	validate_buffer()
	var session = root.get_node("Session")
	var packet = {"type":"probe","state":{"test":123}}
	var encoded = session.encode_packet(packet)
	var decoded = bytes_to_var(encoded.decompress_dynamic(2000000,FileAccess.COMPRESSION_DEFLATE))
	check(decoded.state.test == 123 and decoded.has("protocol"),"Shared packet encoding preserves wire payload")
	check(not packet.has("protocol"),"Encoding does not mutate caller state")
	# Exercise the actual receiver/render integration without opening a network port.
	game.sim.spawn(Vector2(0,3),"normal")
	session.playing = true
	var world: Dictionary = game.sim.snapshot()
	world.elapsed = 2.0
	session.world_received.emit(world)
	world = world.duplicate(true)
	world.elapsed = 2.1
	world.zombies[0].pos.x += 1
	session.world_received.emit(world)
	game.display_buffer.clock = 2.05
	game._process(0)
	check(game.display_buffer.history.size() == 2,"World receiver feeds the display buffer")
	check(game.sim.zombies[0].pos == world.zombies[0].pos,"Rendering retains the latest authoritative enemy position")
	session.playing = false
	game.return_home()
	check(not game.ui.native_hud.visible,"HUD hides on return to menu")
	check(game.display_buffer.history.is_empty(),"Leaving clears interpolation history")
	game.free()
	# Allow the audio thread to release stopped voices before the test exits.
	await create_timer(.15).timeout
	print("NATIVE COMPONENTS: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func validate_revolver() -> void:
	var p: Dictionary = game.local_pawn().duplicate(true)
	p.weapon = 3
	p.requested = 3
	p.switch = 0.0
	p.hp = 100
	p.aim = false
	p.reloading = false
	p.fire_anim = 0.0
	var rig = game.weapon.models[3]
	var before = p.duplicate(true)
	game.weapon.sync(p,.016,0)
	check(p == before,"Revolver presentation never mutates authoritative ammo or input")
	check(rig.find_children("RightHand","",true,false).is_empty() and rig.find_children("LeftHand","",true,false).is_empty() and rig.find_children("*Forearm*","",true,false).is_empty(),"Revolver first-person model contains no hands or forearms")
	var states = []
	for phase in [.1,.3,.5,.65,.85]:
		p.reloading = true
		p.reload = 1.6*(1-phase)
		game.weapon.sync(p,.016,phase)
		states.append(rig.loader_anchor.position)
	check(states[0].distance_to(states[2]) > .2,"Reload reaches from cylinder latch to fresh-round retrieval")
	check(states[2].distance_to(states[3]) > .15,"Speedloader returns to the open cylinder")
	p.reloading = false
	p.switch = .4
	game.weapon.sync(p,.016,1)
	check(rig.state_name == "cancel","Interrupted reload begins a finite visual recovery")
	for i in 20: game.weapon.sync(p,.016,1+i*.016)
	check(rig.cylinder_open == 0 and not rig.loader.visible and not rig.shells.visible,"Cancellation removes loose props and closes the cylinder")
	p.weapon = 0
	game.weapon.sync(p,.016,2)
	check(not rig.visible,"Switching to other weapons hides the revolver model")
	p.weapon = 3
	p.hp = 0
	game.weapon.sync(p,.016,2)
	check(not rig.visible,"Death cannot leave a live revolver model on screen")
	# Exercise real authority interruption separately from the presentation sampler.
	for phase in [.2,.5,.85]:
		var state: Dictionary = game.local_pawn().duplicate(true)
		state.weapon = 3
		state.requested = 3
		state.ammo[3] = 1
		state.reloading = true
		state.reload = 1.6*(1-phase)
		state.fire_anim = 0.0
		state.switch = 0.0
		state.slot = 1
		game.sim.update_arsenal(state,{"slot":1},.016)
		check(not state.reloading and state.ammo[3] == 1,"Switching cancels revolver reload without granting rounds at phase "+str(phase))
	game.weapon.sync(game.local_pawn(),.016,0)

func validate_buffer() -> void:
	var buffer = load("res://scripts/snapshot_buffer.gd").new()
	var a = {"elapsed":1.0,"pawns":{},"zombies":[{"id":1,"pos":Vector2.ZERO,"hp":10,"heading":deg_to_rad(179),"gait":1.0,"state":"ready","attack_time":0.0}]}
	var b: Dictionary = a.duplicate(true)
	b.elapsed = 1.1
	b.zombies[0].pos = Vector2(1,0)
	b.zombies[0].heading = deg_to_rad(-179)
	b.zombies[0].gait = 2.0
	buffer.push(a)
	buffer.push(b)
	buffer.clock = 1.05
	var sample: Dictionary = buffer.sample(0)
	check(absf(sample.zombies[0].pos.x-.5) < .001,"Enemy positions interpolate between timestamped snapshots")
	check(is_equal_approx(sample.zombies[0].gait,1.5),"Running gait interpolates across cooperative snapshots without changing authority")
	check(absf(absf(sample.zombies[0].heading)-PI) < .01,"Heading interpolation takes the short arc")
	check(a.zombies[0].pos == Vector2.ZERO and b.zombies[0].pos == Vector2(1,0),"Display interpolation leaves authority snapshots untouched")
	buffer.push(a)
	check(buffer.history.size() == 2,"Out-of-order snapshots are rejected")
	var teleported: Dictionary = b.duplicate(true)
	teleported.zombies[0].pos = Vector2(20,0)
	var frozen: Dictionary = buffer.blend(a.zombies[0],teleported.zombies[0],.5,false)
	check(frozen.pos == Vector2.ZERO,"Teleports never interpolate through obstacles")
	var dead: Dictionary = b.zombies[0].duplicate()
	dead.hp = 0
	check(buffer.blend(a.zombies[0],dead,.5,false).hp == 10,"Death transitions wait for their snapshot boundary")
	var last: Dictionary = buffer.sample(1)
	check(last.zombies[0].pos == Vector2(1,0),"Missing packets freeze at the newest state without extrapolating")
	buffer.clear()
	check(buffer.sample(.016).is_empty(),"Reset removes stale display entities")

func validate_close_combat() -> void:
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	var saved = p.duplicate(true)
	var original_zombies: Array = sim.zombies.duplicate(true)
	sim.zombies.clear()
	sim.campaign.state.departed = true
	game.arena.sync_campaign(sim.campaign.state)
	p.slot = 1
	p.healing = ""
	p.interaction = ""
	p.pos = Vector2(0,70)
	p.height = 0.0
	p.hp = 100
	p.yaw = 0.0
	p.switch = 0.0
	p.weapon = p.primary
	p.requested = p.primary
	p.shove_gap = 0.0
	p.shove_cd = 0.0
	p.shove_count = 0
	sim.spawn(Vector2(0,68.65),"normal")
	sim.spawn(Vector2(0,71.35),"normal")
	var front: Dictionary = sim.zombies[0]
	var rear: Dictionary = sim.zombies[1]
	front.attack_time = .2
	check(sim.try_shove(p),"First shove is accepted")
	check(front.state == "stunned" and front.attack_time == 0 and rear.state == "ready","Frontal shove interrupts windup without hitting enemies behind")
	var old = front.pos
	sim.update_zombie(front,p,.18)
	check(front.pos.distance_to(old) > 1 and game.arena.clear(old,front.pos),"Shove displacement is clipped through real terrain")
	check(not sim.try_shove(p),"Shove rejects immediate repeated input")
	for i in 2:
		p.shove_gap = 0.0
		check(sim.try_shove(p),"Accepted spaced shove "+str(i))
	check(p.shove_cd == sim.SHOVE_COOLDOWN and not sim.try_shove(p),"Three rapid shoves trigger cooldown")
	p.input = {}
	sim.update_pawn(p,sim.SHOVE_COOLDOWN+.01)
	check(p.shove_cd == 0 and p.shove_count == 0 and sim.try_shove(p),"Cooldown expires and restores shove")
	p.shove_gap = 0.0
	p.shove_cd = 0.0
	sim.zombies.clear()
	sim.spawn(Vector2(0,68.65),"football")
	var football: Dictionary = sim.zombies[0]
	football.state = "charging"
	sim.try_shove(p)
	check(football.state == "charging" and football.shove_time == 0,"Shove cannot cancel football charge")
	# Use an existing native collider: the pushed body must stop at its clearance.
	var wall_checked = false
	for obstacle in game.arena.obstacles:
		var edge = Vector2(obstacle.minX,(obstacle.minZ+obstacle.maxZ)*.5)
		var start = edge-Vector2(1.15,0)
		var player_start = edge-Vector2(2.5,0)
		if not game.arena.clear(player_start,start): continue
		if game.arena.surface_hit(Vector3(edge.x-.3,1.1,edge.y),Vector3(edge.x+.3,1.1,edge.y)).is_empty(): continue
		sim.zombies.clear()
		sim.spawn(start,"normal")
		var blocked: Dictionary = sim.zombies[0]
		p.pos = player_start
		p.yaw = -PI/2
		p.shove_cd = 0.0
		p.shove_gap = 0.0
		sim.try_shove(p)
		sim.update_zombie(blocked,p,.18)
		check(blocked.pos.x <= edge.x-.95 and blocked.pos.distance_to(start) < .3,"A shove against a real wall stops before its clearance margin")
		p.pos = edge-Vector2(.3,0)
		blocked.pos = edge+Vector2(.3,0)
		blocked.state = "ready"
		blocked.shove_time = 0.0
		p.shove_cd = 0.0
		p.shove_gap = 0.0
		sim.try_shove(p)
		check(blocked.state == "ready" and blocked.shove_time == 0,"A wall blocks the shove hit itself")
		wall_checked = true
		break
	check(wall_checked,"Close-combat obstruction fixture found a native wall")
	p.pos = Vector2(0,70)
	p.yaw = 0.0
	sim.zombies.clear()
	for i in 24: sim.spawn(Vector2(i*.02,66),"normal")
	var speeds = sim.zombies.map(func(z): return z.chase_speed)
	check(speeds.min() >= 4.6 and speeds.max() <= 5.2 and speeds.max()-speeds.min() > .3,"Spawned normal speeds vary within the faster-than-player range")
	var goals = sim.zombies.map(func(z): return sim.approach_goal(z,p))
	check(goals[0].distance_to(goals[1]) > 1 and goals[1].distance_to(goals[2]) > 1,"Nearby enemies choose distributed approach slots")
	sim.zombies.clear()
	sim.spawn(Vector2(0,68.8),"normal")
	var attacker: Dictionary = sim.zombies[0]
	p.pos = Vector2(0,70)
	p.protection = 0.0
	sim.events.clear()
	sim.update_zombie(attacker,p,.1)
	check(p.hp == 100 and attacker.attack_time > 0 and sim.events.any(func(e): return e.kind == "enemy_windup"),"Attack announces a windup before dealing damage")
	p.pos = Vector2(0,72)
	sim.update_zombie(attacker,p,.45)
	check(p.hp == 100 and sim.events.any(func(e): return e.kind == "enemy_miss"),"Leaving attack range produces a miss instead of guaranteed contact damage")
	attacker.attack_time = 0.0
	p.pos = Vector2(0,70)
	sim.update_zombie(attacker,p,.51)
	check(p.hp == 90 and sim.events.any(func(e): return e.kind == "enemy_impact"),"In-range strike deals damage with an impact cue")
	for cue in ["enemy-windup","enemy-impact","enemy-miss","shove","shove-hit"]:
		check(game.sound.streams.has(cue) and game.sound.streams[cue].get_length() > .15,"Close-combat sound resource exists: "+cue)
	var middle = InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	game.reset_mouse_buttons()
	game._input(middle)
	check(game.input_state().aim,"Middle click toggles aim on")
	middle.pressed = false
	game._input(middle)
	check(game.input_state().aim,"Aim remains enabled after middle release")
	middle.pressed = true
	game._input(middle)
	check(not game.input_state().aim,"Second middle click toggles aim off")
	var right = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	game._input(right)
	check(game.input_state().shove and not game.input_state().shove,"Right click produces one consumed shove edge")
	var session = root.get_node("Session")
	var recovered = session.recover_input_edges("shove_fixture",{"shove":false,"shove_seq":1})
	check(recovered.shove and not session.recover_input_edges("shove_fixture",{"shove_seq":1}).shove,"Network retains a lost shove edge and does not replay duplicate counters")
	session.received_edges.erase("shove_fixture")
	game.reset_mouse_buttons()
	for key in saved: p[key] = saved[key]
	sim.zombies = original_zombies

func validate_equipment() -> void:
	var layout = load("res://scripts/night_layout.gd")
	for party in [1,2]:
		game.return_home()
		game.start_solo("campaign",71245)
		if party == 2:
			game.sim.campaign = null
			game.sim.add_pawn("equipment_peer","队友",1)
			game.sim.start("campaign")
		await physics_frame
		await process_frame
		var sim = game.sim
		var director = sim.campaign
		var equipment = director.equipment
		var p: Dictionary = game.local_pawn()
		for item in layout.ITEMS:
			if item.kind != "ammo": continue
			var guns: Array = director.state.loot.filter(func(g): return g.station == item.id)
			check(guns.size() == party*2,"Night supply gun count is players x2: "+str(party)+" "+item.id)
			check(guns.all(func(g): return root.get_node("Data").weapons[g.weapon].tier == item.tier),"Night supply respects weapon tier: "+item.id)
			check(director.state.grenade_stations[item.id].remaining == party,"Night supply grenade count equals players")
		p.pos = layout.ITEMS[0].pos+Vector2(-1,0)
		p.grenades = 0
		check(equipment.pickup(p,"grenade:night_start") and p.grenades == 1,"Night grenade pickup fills one slot")
		var remaining: int = director.state.grenade_stations.night_start.remaining
		check(not equipment.pickup(p,"grenade:night_start") and director.state.grenade_stations.night_start.remaining == remaining,"Full grenade slot cannot consume a second item")
		var gun: Dictionary = director.state.loot[0]
		p.pos = gun.pos
		check(equipment.pickup(p,gun.id) and gun.taken,"Night gun can be replaced through the authority pickup")
		check(not equipment.pickup(p,gun.id),"Consumed gun cannot be picked up again")
		var med: Dictionary = layout.ITEMS[-1]
		p.pos = med.pos
		p.medkits = 1
		director.perform(p,med.id)
		check(p.medkits == 1 and not director.state.taken.has(med.id),"Full medical slot preserves the world medical pack")
		p.medkits = 0
		director.perform(p,med.id)
		check(p.medkits == 1 and director.state.taken.has(med.id),"Empty medical slot can collect one medical pack")
		p.pos = Vector2(0,70)
		p.hp = 40
		p.slot = 5
		p.interaction = ""
		p.input_age = 0.0
		p.input = {"slot":5,"use_self":true,"y":-1}
		equipment.before_movement(.016)
		check(p.healing == p.id,"Left medical input starts self healing")
		var before: Vector2 = p.pos
		sim.update_pawn(p,.1)
		check(p.pos.distance_to(before) < .01,"Healing blocks movement")
		equipment.before_movement(3.0)
		check(p.hp == 90 and p.medkits == 0 and p.healing == "","Completed healing consumes one kit")
		if party == 2:
			var q: Dictionary = sim.pawns.equipment_peer
			q.pos = Vector2(0,68.5)
			q.hp = 40
			p.yaw = 0.0
			p.medkits = 1
			p.input = {"slot":5,"use_other":true}
			equipment.before_movement(.016)
			check(p.healing == q.id and q.being_healed,"Right medical input selects the nearby teammate")
			equipment.before_movement(3.0)
			check(q.hp == 90 and p.medkits == 0,"Teammate healing consumes the healer's single kit")
		p.slot = 1
		p.grenades = 1
		var old_hp: int = p.hp
		sim.zombies.clear()
		sim.spawn(Vector2(0,68.7),"normal")
		equipment.throw_grenade(p)
		check(p.grenades == 0 and director.state.projectiles[0].fuse == 3.0,"Thrown grenade empties slot and has a three-second fuse")
		equipment.explode({"owner":p.id,"pos":Vector3(0,1,69)})
		check(sim.zombies[0].hp <= 0 and p.hp == old_hp,"Close grenade kills ordinary infected without self damage")
		if party == 2: check(sim.pawns.equipment_peer.hp == 90,"Grenade does not damage teammate")
	game.return_home()
	game.start_solo("campaign",71245)
	await physics_frame
	await process_frame
