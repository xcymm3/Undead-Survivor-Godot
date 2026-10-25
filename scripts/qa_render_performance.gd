extends Node
## Injected identically into frozen before/after sources by the cloud benchmark.
const Layout = preload("res://scripts/defense_layout.gd")
var game
var callback: JavaScriptObject
var scenario = ""

func _ready() -> void:
	call_deferred("prepare")

func prepare() -> void:
	Progress.store = preload("res://scripts/progression_store.gd").new()
	Progress.store.data.merge({"intro_seen":true,"tutorial_stage":5,"ultimate_choice":"blade","ultimate_unlocked":true},true)
	game.start_solo("defense",20261025)
	game.set_process(false)
	game.set_physics_process(false)
	game.draw_timer = -100000.0
	Data.settings.merge({"quality":3,"resolution":.75,"aa":0,"shadows":2,"effects":1,"distance":1,"frame_limit":0},true)
	Data.apply_settings()
	game.sim.defense.crystal_hp = Layout.CRYSTAL_MAX_HP
	game.sim.defense.crystal_repair_required = false
	game.sim.defense.prop_clock = 12.5
	game.sim.defense_director.sync_world()
	RenderingServer.render_loop_enabled = false
	callback = JavaScriptBridge.create_callback(request)
	JavaScriptBridge.get_interface("window").__renderPerfCallback = callback
	JavaScriptBridge.eval("window.__renderPerfRun = (scene,token) => window.__renderPerfCallback(scene,token); window.__renderPerfReady = true;",true)

func request(args: Array) -> void:
	call_deferred("sample",str(args[0]),int(args[1]))

func configure(value: String) -> void:
	scenario = value
	game.sim.zombies.clear()
	game.enemies.clear()
	var p: Dictionary = game.local_pawn()
	var target: Vector3
	match scenario:
		"bedroom":
			p.pos = Vector2(-6.5,Layout.SHOP_AREA.end.y-3)
			target = Vector3(-10.6,4.0,Layout.SHOP_AREA.end.y-3)
		"shop":
			p.pos = Vector2(0,Layout.SHOP_FRONT_Z+4)
			target = Vector3(8,4.5,Layout.SHOP_OWNER.y)
		_:
			p.pos = Layout.CRYSTAL+Vector2(0,7)
			target = Vector3(0,4.7,-25)
			if scenario == "battle100":
				for index in 100: game.sim.spawn(Vector2((index%10-5)*1.2,-5.0-floori(index/10.0)*1.1),["normal","cone","bucket"][index%3])
	p.height = 3.0
	game.camera.position = Vector3(p.pos.x,4.7,p.pos.y)
	game.camera.look_at(target)
	p.yaw = game.camera.rotation.y
	p.pitch = game.camera.rotation.x
	game.yaw = p.yaw
	game.pitch = p.pitch
	game.sim.elapsed = 12.5
	game.running = true
	game.ui.clear_menu()
	game.weapon.show()

func sample(value: String, token: int) -> void:
	if value != scenario:
		configure(value)
		for index in 3: await get_tree().process_frame
	var started = Time.get_ticks_usec()
	game._process(1.0/60.0)
	# Reproduce the legacy process callback as well as frame_pre_draw. The
	# optimized layer has no process callback; both versions use the same fixture.
	if game.first_person_layer.has_method("_process"): game.first_person_layer.call("_process",1.0/60.0)
	game.camera.force_update_transform()
	var batch = game.arena.get("static_scenery")
	if batch: batch.update_visibility()
	var cpu_us = Time.get_ticks_usec()-started
	var draw_start = Time.get_ticks_usec()
	RenderingServer.force_draw(true)
	# Wait for submitted software WebGL work, rather than timing submission alone.
	JavaScriptBridge.eval("document.getElementById('canvas').getContext('webgl2').finish()",true)
	var draw_us = Time.get_ticks_usec()-draw_start
	var result = {"token":token,"scenario":scenario,"cpu_ms":cpu_us/1000.0,"draw_finish_ms":draw_us/1000.0,"total_ms":(Time.get_ticks_usec()-started)/1000.0,
		"draw_calls":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"objects":int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"primitives":int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"shadow_lights":game.arena.find_children("*","Light3D",true,false).filter(func(light): return light.shadow_enabled).size(),
		"batches":batch.stats if batch else {},"regions":batch.visibility_state if batch else {},
		"resolution":Data.settings.resolution,"viewport":str(game.get_viewport().get_visible_rect().size),
		"fp_config_updates":game.first_person_layer.get("configuration_updates")}
	JavaScriptBridge.eval("window.__renderPerfResult="+JSON.stringify(result),true)
