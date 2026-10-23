extends Node
## Isolated first-person recording: browser keyboard/mouse -> production input and collision.
const FPS = 8.0
const FRAMES = 288
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
	JavaScriptBridge.eval("window.__campaignReviewReady="+JSON.stringify({"scenario":"ultimate_entry","fps":FPS,"frames":FRAMES,"renderer":"Godot Web / Chromium SwiftShader, full internal resolution","camera":"first-person browser keyboard/mouse; production input, walking collisions and selection"}),true)

func draw_frame(args: Array) -> void:
	var frame = int(args[0])
	if frame != last_frame+1: return
	last_frame = frame
	# Eight fixed physics ticks per capture frame. No position, gaze or command overrides.
	for tick in 8: game._physics_process(1.0/FPS/8.0)
	if frame == 124: attempted_rocket = Progress.store.needs_ultimate_choice() and game.entry_sequence.phase == "room" and game.entry_sequence.focus == "rocket_launcher" and game.entry_sequence.notice == "Demo版不可用"
	if frame == 200: attempted_scepter = Progress.store.needs_ultimate_choice() and game.entry_sequence.phase == "room" and game.entry_sequence.focus == "crimson_scepter" and game.entry_sequence.notice == "Demo版不可用"
	game._process(1.0/FPS)
	game.first_person_layer.sync_view()
	for i in 2: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	# Label3D can grow the shared font atlas after the custom dossier drew.
	# Rebuild its cached canvas commands against the settled atlas before capture.
	for settle in 2:
		if game.entry_sequence: game.entry_sequence.detail.queue_redraw()
		await get_tree().process_frame
		RenderingServer.force_draw(true)
		await get_tree().process_frame
	var sequence = game.entry_sequence
	var state = {"frame":frame,"phase":sequence.phase if sequence else "shop","focus":sequence.focus if sequence else "","hold_progress":sequence.hold_time/sequence.HOLD_SECONDS if sequence else 0.0,"black":sequence.black.color.a if sequence else 0.0,"choice":Progress.store.data.ultimate_choice,"rocket_blocked":attempted_rocket,"scepter_blocked":attempted_scepter,"sim_started":game.sim != null,"intro_seen":Progress.store.data.intro_seen,"ultimate_unlocked":Progress.store.data.ultimate_unlocked,"main_visible":game.arena.visible,"x":sequence.room.player.position.x if sequence else 0.0,"z":sequence.room.player.position.z if sequence else 0.0,"yaw":sequence.yaw if sequence else 0.0,"detail":sequence.detail.details if sequence else {}}
	JavaScriptBridge.eval("window.__entryState="+JSON.stringify(state),true)
	JavaScriptBridge.eval("window.__entryFrame="+str(frame),true)
