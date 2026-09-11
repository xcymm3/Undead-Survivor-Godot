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
	check(game.arena.has_node("World/Scenery_000/Collision/Shape"),"Baked world exposes an explicit native collider")
	check(not game.arena.obstacles.is_empty(),"Native scene retains navigation footprints")
	var ray = game.arena.surface_hit(Vector3(0,5,9),Vector3(0,-2,9))
	check(not ray.is_empty(),"Baked ground participates in native physics rays")
	check(RenderingServer.render_loop_enabled,"Normal rendering uses the engine loop")
	game.start_solo("survival")
	game.ui.tick(.016)
	check(game.ui.native_hud.visible,"Native HUD appears on game start")
	check(game.ui.native_hud.cards.has("solo"),"Player card is a retained control")
	var card: Dictionary = game.ui.native_hud.cards.solo
	check(card.bar is ProgressBar and card.name is Label,"Health and name use native widgets")
	var pawn: Dictionary = game.local_pawn()
	pawn.hp = 42
	game.ui.tick(.016)
	check(card.bar.value == 42 and card.hp.text.begins_with("42"),"Native health widget updates from authority")
	check(card.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE,"HUD does not capture combat input")
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

func validate_buffer() -> void:
	var buffer = load("res://scripts/snapshot_buffer.gd").new()
	var a = {"elapsed":1.0,"pawns":{},"zombies":[{"id":1,"pos":Vector2.ZERO,"hp":10,"heading":deg_to_rad(179),"state":"ready","attack_time":0.0}]}
	var b: Dictionary = a.duplicate(true)
	b.elapsed = 1.1
	b.zombies[0].pos = Vector2(1,0)
	b.zombies[0].heading = deg_to_rad(-179)
	buffer.push(a)
	buffer.push(b)
	buffer.clock = 1.05
	var sample: Dictionary = buffer.sample(0)
	check(absf(sample.zombies[0].pos.x-.5) < .001,"Enemy positions interpolate between timestamped snapshots")
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
