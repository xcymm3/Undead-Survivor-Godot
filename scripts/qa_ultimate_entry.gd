extends Node
## Isolated recording: scripted camera tour, production selection and scene transitions.
const FPS = 8.0
const FRAMES = 224
var game
var callback: JavaScriptObject
var last_frame = -1
var entry
var attempted_rocket = false
var attempted_scepter = false

func stage() -> void:
	Progress.store = preload("res://scripts/progression_store.gd").new()
	game.begin_game()
	entry = game.entry_sequence
	game.set_process(false)
	game.set_physics_process(false)
	Data.settings.resolution = 1.0
	Data.settings.aa = 0
	game.apply_graphics()
	game.focused = true
	await get_tree().physics_frame
	game._process(0)
	for i in 3: await get_tree().process_frame
	RenderingServer.render_loop_enabled = false
	RenderingServer.force_draw(true)
	callback = JavaScriptBridge.create_callback(draw_frame)
	JavaScriptBridge.get_interface("window").__drawUltimateEntry = callback
	JavaScriptBridge.eval("window.__entryFrame=-1",true)
	JavaScriptBridge.eval("window.__campaignReviewReady="+JSON.stringify({"scenario":"ultimate_entry","fps":FPS,"frames":FRAMES,"renderer":"Godot Web / Chromium SwiftShader, full internal resolution","camera":"scripted exhibit tour; production selection and transition"}),true)

func draw_frame(args: Array) -> void:
	var frame = int(args[0])
	if frame != last_frame+1: return
	last_frame = frame
	if is_instance_valid(entry) and entry.phase == "room":
		var at = Vector3(0,.10,5.8)
		if frame >= 96 and frame < 112:
			at = Vector3(0,.10,5.8).lerp(Vector3(-8,.10,.6),smoothstep(0,1,float(frame-96)/15))
		elif frame >= 112 and frame < 128: at = Vector3(-8,.10,.6)
		elif frame >= 128 and frame < 152:
			at = Vector3(-8,.10,.6).lerp(Vector3(8,.10,.6),smoothstep(0,1,float(frame-128)/23))
		elif frame >= 152 and frame < 168: at = Vector3(8,.10,.6)
		elif frame >= 168 and frame < 184:
			at = Vector3(8,.10,.6).lerp(Vector3(0,.10,.6),smoothstep(0,1,float(frame-168)/15))
		elif frame >= 184: at = Vector3(0,.10,.6)
		entry.room.player.position = at
		entry.room.player.velocity = Vector3.ZERO
		entry.yaw = 0.0
		entry.pitch = .10 if frame >= 96 else .02
	if game.entry_sequence:
		game.entry_sequence.step(1.0/FPS,{"movement":Vector2.ZERO,"interact":frame in [120,160,190]})
		if frame == 120: attempted_rocket = Progress.store.needs_ultimate_choice() and game.entry_sequence.phase == "room"
		if frame == 160: attempted_scepter = Progress.store.needs_ultimate_choice() and game.entry_sequence.phase == "room"
	else:
		game.sim.submit("solo",{"yaw":game.yaw,"pitch":game.pitch})
		game.sim.step(1.0/FPS)
	game._process(1.0/FPS)
	game.first_person_layer.sync_view()
	for i in 2: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var sequence = game.entry_sequence
	var state = {"frame":frame,"phase":sequence.phase if sequence else "shop","focus":sequence.focus if sequence else "","black":sequence.black.color.a if sequence else 0.0,"choice":Progress.store.data.ultimate_choice,"rocket_blocked":attempted_rocket,"scepter_blocked":attempted_scepter,"sim_started":game.sim != null,"intro_seen":Progress.store.data.intro_seen,"ultimate_unlocked":Progress.store.data.ultimate_unlocked,"main_visible":game.arena.visible}
	JavaScriptBridge.eval("window.__entryState="+JSON.stringify(state),true)
	JavaScriptBridge.eval("window.__entryFrame="+str(frame),true)
