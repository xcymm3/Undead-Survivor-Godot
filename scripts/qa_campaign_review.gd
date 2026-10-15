extends Node
var game
var action_callback
var action_name = ""
var action_frames = 48
var action_fps = 20.0
func _ready() -> void:
	if not Data.automation or not OS.has_feature("web"): queue_free(); return
	call_deferred("stage")

func stage() -> void:
	var scenario = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('campaignReview')",true))
	game.set_process(false)
	game.set_physics_process(false)
	if scenario.begins_with("normal_") or scenario.begins_with("toy_"):
		await stage_normal_zombie(scenario)
		return
	if scenario in ["home","home_hover","settings"]:
		game.ui.show_home()
		if scenario == "home_hover":
			var buttons = game.ui.menu.find_children("*","Button",true,false)
			for item in buttons:
				if item.text == "开始防守":
					item.mouse_entered.emit()
					await get_tree().create_timer(.16).timeout
		if scenario == "settings": game.ui.show_settings()
	else:
		game.start_solo("defense",42)
		await get_tree().physics_frame
		game.ui.clear_menu()
		game.sim.roster.clear()
		game.sim.defense.started = true
		var p = game.local_pawn()
		var sim = game.sim
		var center = Vector3(Data.Maps.Defense.CRYSTAL.x,4.6,Data.Maps.Defense.CRYSTAL.y)
		p.pos = Data.Maps.Defense.CRYSTAL+Vector2(0,6)
		p.height = 3
		game.camera.position = center+Vector3(3.8,1.7,-5.4)
		game.camera.look_at(center)
		game.camera.fov = 61
		game.weapon.hide()
		if scenario.begins_with("interaction_"):
			sim.defense.started = false
			sim.progression.data.coins = 10000
			var id = "pistol" if scenario == "interaction_station" else "bridge_gate"
			if id == "bridge_gate":
				face(sim,p,id)
				sim.purchase_upgrade(id,p)
			face(sim,p,id)
			p.input = {"interact":true}
			p.input_age = 0
			sim.defense_director.interactions(.55)
			game.camera.position = Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p),p.pos.y)
			game.camera.rotation = Vector3(p.pitch,p.yaw,0)
			game.camera.fov = 74
			game.weapon.show()
			game.weapon.sync(p,0,sim.elapsed,Vector3(0,0,-50))
		if scenario.begins_with("switch_"):
			p.weapon = 0 if scenario.begins_with("switch_rifle") else 2
			p.requested = p.weapon
			p.switch_duration = .9
			var phase = .53 if scenario == "switch_rifle_bolt" else .32 if scenario == "switch_pistol_spin" else .28
			p.switch = .9*(1.0-(.25+.75*phase))
			p.pos = Vector2(0,8)
			p.height = 3
			p.yaw = 0
			p.pitch = 0
			game.camera.position = Vector3(0,4.65,8)
			game.camera.rotation = Vector3.ZERO
			game.weapon.show()
			game.weapon.sync(p,0,sim.elapsed,Vector3(0,0,-50))
		if scenario == "crystal_half": sim.defense.crystal_hp = 1500
		if scenario == "crystal_broken":
			sim.damage_crystal({},3000)
			sim.defense.prop_clock += .6
		if scenario == "heal":
			sim.progression.data.talents.strong = 1
			p.max_hp = 110
			p.hp = 72
			p.combat_remaining = 0
			sim.update_defense_regen(p,1.1)
			game.camera.position = Vector3(p.pos.x,4.7,p.pos.y)
			game.camera.look_at(center)
			game.weapon.show()
			game.weapon.sync(p,.1,sim.elapsed,Vector3(0,0,-50))
		if scenario == "boss":
			sim.wave = 10
			sim.defense.wave = 10
			sim.spawn(Vector2(0,2),"dancer")
			sim.zombies[-1].hp = 62450
			for point in [Vector2(-3,3),Vector2(3,4)]: sim.spawn(point,"normal")
			game.enemies.sync(sim.zombies,sim.elapsed,false)
			game.camera.position = Vector3(0,4.8,12)
			game.camera.look_at(Vector3(0,4.5,2))
		if scenario.begins_with("failure"):
			game.camera.position = Vector3(p.pos.x,4.7,p.pos.y)
			game.camera.look_at(center)
			sim.failed = true
			if scenario == "failure_crystal":
				sim.cause = "crystal"
				sim.damage_crystal({},3000)
			else: p.hp = 0; sim.cause = "enemy"
			game.finish_run()
			game.update_finish_camera(2.4)
		game.arena.scenery.sync(sim.defense)
		game.arena.scenery.sync_focus(sim,p)
		game.running = true
		game.ui.native_hud.visible = not scenario.begins_with("failure")
		game.ui.tick(0)
	game.get_viewport().scaling_3d_scale = 1.0
	RenderingServer.render_loop_enabled = false
	for i in 5: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	RenderingServer.force_draw(true)
	JavaScriptBridge.eval("window.__campaignReviewReady="+JSON.stringify({"ring":game.arena.scenery.preparation.interaction_ring.visible,"payments":game.arena.scenery.preparation.money_flights.multimesh.visible_instance_count,"scenario":scenario,"menu":game.ui.current,"boss":game.ui.native_hud.boss_title.text,"focus_visible":game.arena.scenery.preparation.focus_label.visible,"cracks":game.arena.scenery.crystal_damage.cracks.visible,"fragments":game.arena.scenery.crystal_damage.debris.visible}),true)

func face(sim, p: Dictionary, id: String) -> void:
	for entry in preload("res://scripts/preparation_catalog.gd").targets(sim):
		if entry.id != id: continue
		var point: Vector3 = entry.position
		p.pos = Vector2(point.x,point.z)+Vector2(0,-2 if id == "pistol" else 2)
		p.height = preload("res://scripts/defense_layout.gd").height(p.pos)
		var eye = Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p),p.pos.y)
		var direction = (point-eye).normalized()
		p.yaw = atan2(-direction.x,-direction.z)
		p.pitch = asin(direction.y)
		p.input_age = 0
		return

func stage_normal_zombie(scenario: String) -> void:
	# Only reachable behind --automation + Web + explicit review URL.
	game.start_solo("defense",42)
	await get_tree().physics_frame
	game.running = false
	game.ui.root.hide()
	game.weapon.hide()
	game.sim.roster.clear()
	game.sim.zombies.clear()
	var studio: bool = scenario != "normal_night"
	var all_toys: bool = scenario == "toy_lineup"
	var toy_review: bool = scenario.begins_with("toy_")
	var lineup: bool = scenario == "normal_lineup" or all_toys
	var selected_kind: String = scenario.trim_prefix("toy_").trim_suffix("_rage") if toy_review and not all_toys else "normal"
	var display_kinds: Array = preload("res://scripts/zombie_toy_styles.gd").KINDS if all_toys else [selected_kind]
	var walking: bool = scenario == "normal_walk"
	action_name = scenario.trim_prefix("normal_")
	var animated: bool = action_name in ["walk","idle","attack","hit","shove","stunned","death","emerge"]
	action_frames = 48 if action_name in ["walk","idle"] else 52 if action_name == "attack" else 76 if action_name == "shove" else 40
	action_fps = 12.0*4.9*2.3/TAU if walking else 20.0
	var center = Vector3(0,4.05,10)
	if studio:
		game.arena.scenery.hide()
		game.arena.sun.hide()
		var environment: Environment = game.arena.find_children("*","WorldEnvironment",true,false)[0].environment
		environment.background_color = Color("344552")
		environment.fog_enabled = false
		environment.ambient_light_color = Color("d1e0e5")
		environment.ambient_light_energy = .25
		var ground = MeshInstance3D.new()
		ground.mesh = PlaneMesh.new()
		ground.mesh.size = Vector2(80,80)
		ground.position = Vector3(0,3,10)
		var material = StandardMaterial3D.new()
		material.albedo_color = Color("53616a")
		material.roughness = .85
		ground.material_override = material
		game.add_child(ground)
		for entry in [[Vector3(-3,8,15),Color("ffe5bc"),.75],[Vector3(4,6,8),Color("abcff0"),.25]]:
			var light = DirectionalLight3D.new()
			game.add_child(light)
			light.position = entry[0]
			light.look_at(center)
			light.light_color = entry[1]
			light.light_energy = entry[2]
			light.shadow_enabled = true
		var highlight = OmniLight3D.new()
		game.add_child(highlight)
		highlight.position = Vector3(1.6,5.3,13.5)
		highlight.light_color = Color("fff0cf")
		highlight.light_energy = .65
		highlight.omni_range = 8.0
	var count: int = display_kinds.size() if all_toys else 5 if lineup else 1
	for index in count:
		var kind: String = display_kinds[index] if all_toys else selected_kind
		var x: float = (index-(count-1)*.5)*(2.6 if all_toys else 1.5) if lineup else 0.0
		game.sim.spawn(Vector2(x,10),kind)
		var z: Dictionary = game.sim.zombies[-1]
		if kind in ["normal","cone","bucket"]: z.outfit = index if lineup and not all_toys else 1
		z.heading = -.12 if lineup else -.18
		z.rage = scenario == "toy_berserker_rage"
		z.move_speed = 4.9 if walking else 0.0
		z.gait = .6
	game.enemies.sync(game.sim.zombies,.3,not walking)
	game.camera.fov = 38 if lineup else 32
	game.camera.position = Vector3(2.6,5.2,21) if lineup else Vector3(2.1,4.65,14.5)
	if toy_review:
		if all_toys:
			center = Vector3(0,4.9,10)
			game.camera.fov = 30
			game.camera.position = Vector3(1.5,6,36)
		else:
			var height: float = Data.enemy_scale(selected_kind)*{"cone":2.82,"bucket":2.56,"dancer":2.36}.get(selected_kind,2.12)
			center = Vector3(0,3+height*.52,10)
			game.camera.position = center+Vector3(height*.65,height*.16,height*1.95)
	game.camera.look_at(center)
	game.get_viewport().scaling_3d_scale = 1.0
	RenderingServer.render_loop_enabled = false
	for i in 6: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	RenderingServer.force_draw(true)
	if animated:
		action_callback = JavaScriptBridge.create_callback(draw_action_frame)
		JavaScriptBridge.get_interface("window").__drawNormalAction = action_callback
		JavaScriptBridge.eval("window.__normalActionFrame=-1",true)
	JavaScriptBridge.eval("window.__campaignReviewReady="+JSON.stringify({"scenario":scenario,"count":game.sim.zombies.size(),"head_size":[.49,.49,.45],"roughness":game.enemies.toy_material.roughness,"studio":studio,"kinds":display_kinds,"frames":action_frames if animated else 0,"fps":action_fps}),true)

func draw_action_frame(args: Array) -> void:
	# Deterministic pose previews of actual shared engine animations, not timed video.
	var frame = clampi(int(args[0]),0,action_frames-1)
	var time: float = frame/action_fps
	var z: Dictionary = game.sim.zombies[0]
	z.hp = 200.0
	z.down = .85
	z.move_speed = 0.0
	z.attack_time = 0.0
	z.state = "ready"
	z.state_time = 0.0
	z.emerge_remaining = 0.0
	z.toy_hit_at = -100.0
	z.toy_shove_at = -100.0
	z.toy_shove_until = -1.0
	match action_name:
		"walk":
			z.gait = float(frame)*TAU/12.0
			z.move_speed = 4.9
		"attack": z.attack_time = fposmod(time,Data.attack("normal").y)
		"hit":
			if time >= .4:
				z.toy_hit_at = .4
				z.toy_hit_side = .8
				if time < .58: z.state = "stunned"; z.state_time = .58-time
		"shove":
			if time >= .25 and time < 3.37:
				z.state = "stunned"
				z.state_time = 3.37-time
				z.toy_shove_at = .25
				z.toy_shove_until = 3.37
		"stunned":
			if time >= .25 and time < 1.5: z.state = "stunned"; z.state_time = 1.5-time
		"death":
			if time >= .25: z.hp = 0.0; z.down = maxf(0.0,.85-(time-.25))
		"emerge": z.emerge_remaining = maxf(0.0,1.4-time)
	game.enemies.sync(game.sim.zombies,time,false)
	for i in 2: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	JavaScriptBridge.eval("window.__normalActionFrame="+str(frame),true)
