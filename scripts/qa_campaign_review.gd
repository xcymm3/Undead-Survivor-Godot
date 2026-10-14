extends Node
var game
func _ready() -> void:
	if not Data.automation or not OS.has_feature("web"): queue_free(); return
	call_deferred("stage")

func stage() -> void:
	var scenario = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('campaignReview')",true))
	game.set_process(false)
	game.set_physics_process(false)
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
