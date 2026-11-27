extends Node
## Isolated first-person recording: browser keyboard/mouse -> production input and collision.
const FPS = 8.0
const FRAMES = 88
var game
var callback: JavaScriptObject
var last_frame = -1

func stage() -> void:
	Progress.store = preload("res://scripts/progression_store.gd").new()
	game.begin_game()
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
	JavaScriptBridge.eval("window.__campaignReviewReady="+JSON.stringify({"scenario":"ultimate_entry","fps":FPS,"frames":FRAMES,"renderer":"Godot Web / Chromium SwiftShader"}),true)

func draw_frame(args: Array) -> void:
	var frame = int(args[0])
	if frame != last_frame+1: return
	last_frame = frame
	# Eight fixed physics ticks per capture frame. No position, gaze or command overrides.
	for tick in 8: game._physics_process(1.0/FPS/8.0)
	game._process(1.0/FPS)
	game.first_person_layer.sync_view()
	for i in 2: await get_tree().process_frame
	# Stills advance the exact same input/physics timeline but render only target views.
	var paint: bool = args.size() < 2 or bool(args[1])
	if paint:
		for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
		for settle in 2:
			await get_tree().process_frame
			RenderingServer.force_draw(true)
			await get_tree().process_frame
	var sequence = game.entry_sequence
	var state = {"frame":frame,"phase":sequence.phase if sequence else "spawn","black":sequence.black.color.a if sequence else 0.0,"choice":Progress.store.data.ultimate_choice,"sim_started":game.sim != null,"intro_seen":Progress.store.data.intro_seen,"ultimate_unlocked":Progress.store.data.ultimate_unlocked,"at_spawn":game.sim != null and game.local_pawn().pos.distance_to(game.arena.definition.spawn)<.1}
	JavaScriptBridge.eval("window.__entryState="+JSON.stringify(state),true)
	JavaScriptBridge.eval("window.__entryFrame="+str(frame),true)
