extends SceneTree
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.start_solo("defense",42)
	var sim = game.sim
	var p: Dictionary = sim.pawns.solo
	p.hp = 45
	p.combat_remaining = 3.2
	p.grenades = 0
	p.grenade_capacity = 3
	p.grenade_replenish = 15.0
	sim.defense_director.begin_wave()
	sim.roster.clear()
	check(p.hp == 45 and p.combat_remaining == 3.2 and p.grenades == 0,"Wave start preserves health, healing delay and grenades")
	sim.update_pawn(p,14.99)
	check(p.grenades == 0,"Grenades do not replenish before fifteen seconds")
	sim.update_pawn(p,.01)
	check(p.grenades == 1,"Fifteen seconds replenish exactly one grenade")
	sim.update_pawn(p,30.01)
	check(p.grenades == 3,"Long updates replenish to capacity without exceeding it")
	p.grenades = 1
	p.grenade_replenish = 6
	sim.defense_director.begin_wave()
	check(p.grenade_replenish == 6 and p.grenades == 1,"Wave transitions preserve grenade replenishment timer")
	check(load("res://scripts/preparation_catalog.gd").focus(sim,p).is_empty(),"Battle disables all world information prompts")
	sim.progression.data.talents.strong = 1
	p.hp = 50
	p.max_hp = 110
	p.combat_remaining = 0
	sim.update_defense_regen(p,1)
	check(p.hp == 51 and p.healing_flash > 0 and sim.events.any(func(e): return e.kind == "heal"),"Actual healing emits its bounded audiovisual feedback")
	var sound_hashes = {}
	for index in root.get_node("Data").weapons.size():
		var stream = game.sound.streams["reload-"+str(root.get_node("Data").weapons[index].id)]
		check(stream.data.size() > 0,"Weapon reload cue exists: %d" % index)
		sound_hashes[hash(stream.data)] = true
	check(sound_hashes.size() == 10,"All weapons have distinct reload resources")
	var state = sim.defense
	state.crystal_hp = 750
	game.arena.scenery.sync(state)
	check(game.arena.scenery.crystal_damage.cracks.visible,"Crystal half health exposes cracks")
	state.crystal_hp = 751
	game.arena.scenery.sync(state)
	check(not game.arena.scenery.crystal_damage.cracks.visible,"Crystal above half health has no cracks")
	sim.damage_crystal({},1500)
	state.prop_clock += .5
	game.arena.scenery.sync(state)
	var damage = game.arena.scenery.crystal_damage
	check(damage.debris.visible and not game.arena.scenery.crystal_core.visible and game.arena.scenery.get_node("CrystalBody").collision_layer == 0,"Broken crystal replaces core with nonblocking fragments")
	var point: Vector3 = damage.fragments[0].node.position
	state.prop_clock += .3
	game.arena.scenery.sync(state)
	check(damage.fragments[0].node.position != point,"Crystal fragments actually move over time")
	game.start_solo("defense",42)
	sim = game.sim
	p = sim.pawns.solo
	sim.wave = 10
	sim.defense_director.begin_wave()
	sim.roster.clear()
	sim.spawn(Vector2(0,3),"dancer")
	var boss: Dictionary = sim.zombies[-1]
	check(boss.chase_speed >= 4.6 and boss.chase_speed <= 5.2,"Boss speed is the ordinary sampled speed")
	sim.spawn(Vector2(2,3),"bucket")
	game.ui.native_hud.sync()
	check(game.ui.native_hud.boss_title.text.contains("90000") and game.ui.native_hud.boss_title.get_parent().visible,"Boss health HUD shows exact health on arrival")
	sim.hit_enemy(boss,1000000,true,p,Vector3(0,4,3))
	check(sim.won and sim.alive_count() == 0 and sim.earned_coins > 0 and sim.earned_diamonds == 1,"Boss defeat clears and rewards the army and wins immediately")
	game.finish_run()
	game.update_finish_camera(1)
	check(not sim.coin_drops.is_empty() and sim.coin_drops[0].age >= 1,"Victory coin pickup animations continue during the cinematic")
	check(game.ui.current != "result","Battle aftermath delays the result panel")
	game.update_finish_camera(3)
	check(game.ui.current == "result" and game.ui.menu.find_children("*","Label",true,false).any(func(n): return n.text.contains("本局获得")),"Result shows session coin and diamond earnings after camera sequence")
	game.return_home()
	await process_frame
	await process_frame
	var actions = game.ui.menu.get_node("HomeStage/HomeActions")
	var setup_row = game.ui.menu.get_node("HomeStage/DifficultySelection")
	check(absf(actions.get_global_rect().get_center().x-game.ui.root.size.x*.5) < 1 and actions.get_children().size() == 5,"All five home buttons including saves form one centered row")
	check(absf(setup_row.get_global_rect().get_center().x-game.ui.root.size.x*.5) < 1,"Difficulty and test-money controls are centered as a group")
	check(game.ui.menu.has_node("HomeStage/GameTitle"),"Home uses the central game title and bottom action layout")
	check(game.ui.menu.get_node("HomeStage/CrystalSigil").size == Vector2(80,80),"Home crystal emblem stays inside its title-free reserved space")
	check(game.ui.menu.get_child(0) is TextureRect and game.ui.menu.get_child(0).texture is GradientTexture2D,"Home restores the original translucent battlefield backdrop")
	check(game.sound.streams.has("menu-hover") and game.sound.streams["menu-hover"].get_length() < .1,"Home hover cue is a short bounded audio tick")
	var home_buttons = game.ui.menu.find_children("*","Button",true,false)
	var start_button = home_buttons.filter(func(n): return n.text == "开始防守")[0]
	var voices = game.sound.index
	start_button.mouse_entered.emit()
	await create_timer(.18).timeout
	check(start_button.scale.x > 1.05 and game.sound.index == voices+1,"Home hover enlarges the button and emits one cue")
	start_button.mouse_exited.emit()
	await create_timer(.18).timeout
	check(start_button.scale.is_equal_approx(Vector2.ONE),"Home hover exit restores its size")
	game.ui.show_settings()
	await process_frame
	await process_frame
	var returns = game.ui.menu.find_children("*","Button",true,false).filter(func(n): return n.text == "返回")
	check(not returns.is_empty() and returns[0].get_global_rect().end.y <= returns[0].get_parent().get_parent().get_global_rect().end.y+1,"Settings return button fits the visible panel without outer scrolling")
	game.start_solo("defense",42)
	sim = game.sim
	p = sim.pawns.solo
	p.hp = 0
	sim.failed = true
	sim.cause = "enemy"
	game.finish_run()
	check(game.partners.has("fallen_guard") and not game.ui.native_hud.visible,"Player defeat creates a corpse and hides combat HUD")
	game.update_finish_camera(2.4)
	game.ui.tick(0)
	check(not game.ui.native_hud.visible,"HUD stays hidden throughout failure camera updates")
	check(game.ui.current != "result" and game.camera.position.distance_to(Vector3(p.pos.x,p.height,p.pos.y)) < 10,"Player defeat focuses the fallen guard before any result dialog")
	game.update_finish_camera(1.5)
	check(game.ui.current == "result","Player defeat opens results after the cinematic delay")
	game.free()
	print("CAMPAIGN FEEDBACK: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
