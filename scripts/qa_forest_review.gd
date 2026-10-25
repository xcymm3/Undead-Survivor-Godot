extends Node
## Opt-in isolated recording: production authority movement, manually stepped time.
const FPS = 12
const FRAMES = 144
var game
var callback: JavaScriptObject
var emitted = 0
var tick = 0
var last_frame = -1
var view = "overview"
var order = [0,7,13,1,8,14,2,9,15,3,10,16,4,11,17,5,12,18,6,19]

func _ready() -> void:
	call_deferred("stage")

func advance() -> void:
	var sim = game.sim
	if tick % 18 == 0 and emitted < 100:
		var route: Dictionary = sim.defense_spawner.forest_routes.entries[order[emitted % order.size()]]
		sim.spawn(route.points[0],["normal","cone","normal","bucket"][emitted % 4])
		emitted += 1
	sim.step(1.0/60)
	tick += 1

func stage() -> void:
	print("FOREST REVIEW: staging")
	view = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('forestReview')",true))
	Data.settings.map_id = "graypine_defense"
	Progress.store = preload("res://scripts/progression_store.gd").new()
	game.start_solo("defense",19457)
	preload("res://tools/preparation-fixture.gd").skip_tutorial(game.sim)
	game.set_process(false)
	game.set_physics_process(false)
	game.running = false
	game.ui.root.hide()
	game.weapon.hide()
	game.sim.defense.started = true
	game.sim.defense.waiting = true
	game.sim.defense.crystal_hp = game.sim.defense.crystal_max_hp
	game.sim.defense.crystal_repair_required = false
	game.sim.roster.clear()
	game.local_pawn().pos = Vector2(0,-35)
	game.local_pawn().height = 0
	game.local_pawn().protection = 99999
	await get_tree().physics_frame
	for step in 1080: advance()
	print("FOREST REVIEW: warmup complete")
	game.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov = 61
	game.camera.position = Vector3(34,31,-41) if view == "overview" else Vector3(0,5,-52)
	game.camera.look_at(Vector3(0,0,-85) if view == "overview" else Vector3(0,1,-78),Vector3.UP)
	game.get_viewport().scaling_3d_scale = 1.0
	game.enemies.sync(game.sim.zombies,game.sim.elapsed,false)
	game.arena.scenery.sync(game.sim.defense)
	for index in 4: await get_tree().process_frame
	RenderingServer.render_loop_enabled = false
	callback = JavaScriptBridge.create_callback(draw_frame)
	JavaScriptBridge.get_interface("window").__drawForestReview = callback
	JavaScriptBridge.eval("window.__forestFrame=-1; window.__forestReady="+JSON.stringify({"frames":FRAMES,"fps":FPS,"view":view,"renderer":"Godot Web / Chromium SwiftShader","warmup_seconds":18}),true)

func draw_frame(arguments: Array) -> void:
	var frame = int(arguments[0])
	if frame <= last_frame: return
	last_frame = frame
	for step in 5: advance()
	game.enemies.sync(game.sim.zombies,game.sim.elapsed,false)
	game.arena.scenery.sync(game.sim.defense)
	for index in 2: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var positions: Array = []
	for z in game.sim.zombies: positions.append({"x":z.pos.x,"z":z.pos.y,"route":z.forest_route})
	JavaScriptBridge.eval("window.__forestState="+JSON.stringify({"frame":frame,"elapsed":game.sim.elapsed,"emitted":emitted,"positions":positions,"failed":game.sim.failed}),true)
	JavaScriptBridge.eval("window.__forestFrame="+str(frame),true)
