extends Node
## Cloud-only deterministic recording of the production ending camera and effects.
var game
var callback: JavaScriptObject
var last_frame = -1
var victory = false
var crystal = false
const FPS = 8.0

func stage(scenario: String) -> void:
	if not Data.automation or not OS.has_feature("web"): return
	victory = scenario == "demo_victory"
	crystal = scenario == "demo_crystal"
	Data.settings.resolution = 1.0
	Data.settings.aa = 0
	game.apply_graphics()
	Progress.store = preload("res://scripts/progression_store.gd").new()
	Progress.store.data.merge({"intro_seen":true,"tutorial_stage":5,"ultimate_unlocked":true},true)
	game.start_solo("defense",491)
	game.set_process(false)
	game.set_physics_process(false)
	await get_tree().physics_frame
	var sim = game.sim
	var p = game.local_pawn()
	sim.roster.clear()
	# Reproduce an already repaired, live defense rather than the pre-wave wreckage.
	sim.defense.crystal_hp = sim.defense.crystal_max_hp
	sim.defense.started = true
	sim.wave = 10 if victory else 3
	sim.defense.wave = sim.wave
	p.pos = Data.Maps.Defense.CRYSTAL+Vector2(0,9)
	p.height = 3.0
	p.yaw = 0.0
	p.pitch = -.04
	game.yaw = p.yaw
	game.pitch = p.pitch
	game.focused = true
	sim.spawn(Data.Maps.Defense.CRYSTAL+Vector2(2,-4),"dancer" if victory else "normal")
	var enemy: Dictionary = sim.zombies[-1]
	enemy.emerge = 0.0
	game._process(0)
	game.first_person_layer.sync_view()
	game.arena.scenery.sync(sim.defense)
	for index in 4: await get_tree().process_frame
	RenderingServer.render_loop_enabled = false
	RenderingServer.force_draw(true)
	callback = JavaScriptBridge.create_callback(draw_frame)
	JavaScriptBridge.get_interface("window").__drawDemoEnding = callback
	JavaScriptBridge.eval("window.__demoEndingFrame=-1",true)
	JavaScriptBridge.eval("window.__campaignReviewReady="+JSON.stringify({"scenario":scenario,"frames":64 if victory else 80,"fps":FPS,"crystal_hp":sim.defense.crystal_hp,"health_cards":game.ui.native_hud.cards.size(),"no_portraits":game.ui.native_hud.cards.values().all(func(card): return not card.has("portrait")),"partners":game.partners.size()}),true)

func draw_frame(args: Array) -> void:
	var frame = int(args[0])
	if frame != last_frame+1: return
	last_frame = frame
	var sim = game.sim
	var p = game.local_pawn()
	if frame == 0:
		if victory:
			var boss: Dictionary = sim.zombies[0]
			sim.hit_enemy(boss,boss.hp+1,false,p,Vector3(boss.pos.x,4.2,boss.pos.y))
		elif crystal:
			sim.damage_crystal(sim.zombies[0],3000)
			sim.failed = true
			sim.cause = "crystal"
		else:
			p.protection = 0.0
			sim.damage_pawn(p,sim.zombies[0],1000)
			sim.fail_from_player_death()
		game.handle_effects(sim.events)
		game.finish_run()
	game._process(0.0 if frame == 0 else 1.0/FPS)
	game.first_person_layer.sync_view()
	for index in 2: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var ending = game.ending_sequence
	JavaScriptBridge.eval("window.__demoEndingState="+JSON.stringify({"frame":frame,"age":game.death_timer,"camera_y":game.camera.position.y,"camera_roll":game.camera.rotation.z,"phase":ending.phase if ending else "playing","black":ending.black.color.a if ending else 0.0,"text":ending.caption.text if ending else "","caption":ending.caption.visible if ending else false,"caption_alpha":ending.caption.modulate.a if ending else 0.0,"result":game.ui.current == "result","restarted":not game.finished,"crystal_hp":game.sim.defense.crystal_hp,"failed":game.sim.failed,"won":game.sim.won}),true)
	JavaScriptBridge.eval("window.__demoEndingFrame="+str(frame),true)
