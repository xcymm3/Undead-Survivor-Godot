extends Node
## Explicit visual QA fixture, rendered only by isolated headless Chromium.
const Intro = preload("res://scripts/first_attempt_intro.gd")
const Tutorial = preload("res://scripts/onboarding.gd")
const Layout = preload("res://scripts/defense_layout.gd")
var game
var scenario = ""
var callback: JavaScriptObject
var sample_time = 0.0

func stage(value: String) -> void:
	scenario = value
	var progress = game.get_node("/root/Progress")
	progress.store = preload("res://scripts/progression_store.gd").new()
	progress.store.data.coins = 150.0
	progress.store.data.intro_seen = scenario != "tutorial_intro"
	progress.store.data.tutorial_stage = Tutorial.SHOP_PENDING if scenario in ["tutorial_dialogue","tutorial_owner_idle","tutorial_owner_motion"] else Tutorial.DEFENSE_PENDING if scenario == "tutorial_payment" else Tutorial.FIRST_RUN
	game.start_solo("defense",491)
	game.set_process(false)
	game.set_physics_process(false)
	await get_tree().physics_frame
	game.ui.clear_menu()
	game.weapon.visible = false
	game.get_viewport().scaling_3d_scale = 1.0
	var pawn = game.local_pawn()
	if scenario in ["tutorial_dialogue","tutorial_payment","tutorial_owner_idle","tutorial_owner_motion"]:
		pawn.pos = Layout.SHOP_OWNER+Vector2(1.5,-3.6)
		game.camera.position = Vector3(pawn.pos.x,4.65,pawn.pos.y)
		game.camera.look_at(Vector3(Layout.SHOP_OWNER.x,4.85,Layout.SHOP_OWNER.y))
		pawn.yaw = game.camera.rotation.y
		pawn.pitch = game.camera.rotation.x
		if scenario not in ["tutorial_owner_idle","tutorial_owner_motion"]: Tutorial.begin_dialogue(game.sim,pawn)
		game.camera.rotation = Vector3(pawn.pitch,pawn.yaw,0)
	elif scenario in ["tutorial_bedroom","tutorial_bedroom_door"]:
		pawn.pos = Layout.SPAWN+Vector2(-1.4,0)
		game.camera.position = Vector3(pawn.pos.x,4.7,pawn.pos.y)
		game.camera.look_at(Vector3(-10.0,4.0,Layout.SHOP_AREA.end.y-2.1))
		if scenario == "tutorial_bedroom_door":
			game.camera.position = Vector3(-9.6,4.7,Layout.SHOP_PARTITION_Z+1.0)
			game.camera.look_at(Vector3(-4.3,4.2,Layout.SHOP_AREA.end.y-1.3))
	elif scenario == "tutorial_combat":
		pawn.pos = Layout.CRYSTAL+Vector2(3.5,5)
		game.sim.defense_director.begin_wave()
		game.camera.position = Vector3(pawn.pos.x,4.65,pawn.pos.y)
		game.camera.look_at(Vector3(0,4.3,-8))
	else:
		pawn.pos = Vector2(-2,Layout.SHOP_FRONT_Z+1.9)
		game.camera.position = Vector3(pawn.pos.x,4.9,pawn.pos.y)
		game.camera.look_at(Vector3(-3,4.0,Layout.SHOP_WALL_Z-2.3))
		if scenario == "tutorial_broken":
			game.camera.position = Vector3(-3,4.8,Layout.SHOP_WALL_Z-5.5)
			game.camera.look_at(Vector3(-3,3.85,Layout.SHOP_WALL_Z-2.3))
	if scenario == "tutorial_owner_motion":
		pawn.pos = Layout.SHOP_OWNER+Vector2(-1.6,-2.8)
		game.camera.position = Vector3(pawn.pos.x,4.7,pawn.pos.y)
		game.camera.look_at(Vector3(Layout.SHOP_OWNER.x,4.7,Layout.SHOP_OWNER.y))
		pawn.yaw = game.camera.rotation.y
		pawn.pitch = game.camera.rotation.x
	game.camera.fov = 48 if scenario == "tutorial_owner_motion" else 61
	pawn.height = 3.0
	callback = JavaScriptBridge.create_callback(requested)
	JavaScriptBridge.get_interface("window").__tutorialSeekCallback = callback
	JavaScriptBridge.eval("window.__tutorialSeek = t => { window.__tutorialReviewReady = null; window.__tutorialSeekCallback(t); }",true)
	await seek(0)

func requested(arguments: Array) -> void:
	if not arguments.is_empty(): call_deferred("seek",float(arguments[0]))

func seek(time: float) -> void:
	if scenario == "tutorial_intro": game.sim.defense.intro_elapsed = time
	elif scenario == "tutorial_owner_motion":
		# One uninterrupted production animation: breathe, greet, finish, return.
		var start_at = 4.8
		if sample_time < start_at and time >= start_at: Tutorial.begin_dialogue(game.sim,game.local_pawn())
		if time >= start_at: game.sim.defense_director.interactions(maxf(0,time-maxf(start_at,sample_time)))
	elif scenario in ["tutorial_dialogue","tutorial_payment"]:
		game.sim.defense_director.interactions(maxf(0,time-sample_time))
	sample_time = time
	game.sim.defense.prop_clock = time
	game.arena.scenery.sync(game.sim.defense)
	game.arena.scenery.sync_focus(game.sim,game.local_pawn())
	if scenario == "tutorial_owner_motion":
		var preparation = game.arena.scenery.preparation
		for overlay in [preparation.focus_label,preparation.interaction_ring,preparation.price_icon]: overlay.hide()
	game.running = true
	game.ui.native_hud.sync()
	game.running = false
	game.ui.native_hud.visible = scenario != "tutorial_owner_motion"
	game.ui.native_hud.upgrade_details.hide()
	RenderingServer.render_loop_enabled = false
	for index in 3: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	RenderingServer.force_draw(true)
	var frame = Tutorial.dialogue_frame(game.sim.defense)
	var payment_at: float = Tutorial.DEFENSE_LINES[0].length()/Tutorial.CHARACTERS_PER_SECOND+Tutorial.LINE_PAUSE
	JavaScriptBridge.eval("window.__tutorialReviewReady="+JSON.stringify({"head_yaw":game.arena.scenery.shop.owner_head_yaw,"breath_y":game.arena.scenery.shop.owner_chest.position.y,"scenario":scenario,"time":time,"coins":game.sim.progression.data.coins,"dialogue":frame.text,"line":frame.line,"payment_at":payment_at,"flying_coins":game.arena.scenery.preparation.money_flights.multimesh.visible_instance_count,"caption":Intro.caption(game.sim.defense),"hint":Tutorial.hint_mode(game.sim.defense),"black":game.ui.native_hud.tutorial_overlay.black.visible}),true)
