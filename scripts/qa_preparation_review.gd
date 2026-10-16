extends Node
## Isolated software Web stills; uses the production scenery and wallet widgets.
var game

func _ready() -> void:
	if not Data.automation or not OS.has_feature("web"):
		queue_free()
		return
	call_deferred("stage")

func stage() -> void:
	var scenario = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('preparationReview')",true))
	Progress.store.data.coins = 12450
	Progress.store.data.diamonds = 37
	var parts = scenario.split("_")
	var building_id = {"turret":"turret_left","gate":"bridge_gate","mine":"crystal_mine"}.get(parts[0],"")
	if not building_id.is_empty() and parts[1] != "unbuilt":
		if building_id in Progress.store.MINES: Progress.store.data.mines[building_id] = true
		else: Progress.store.data.buildings[building_id].owned = true
	game.start_solo("defense",42)
	await get_tree().physics_frame
	game.running = false
	game.set_process(false)
	game.set_physics_process(false)
	game.ui.clear_menu()
	game.ui.root.visible = true
	game.ui.native_hud.visible = true
	game.weapon.visible = false
	game.get_viewport().scaling_3d_scale = 1.0
	var wall: float = Data.Maps.Defense.SHOP_WALL_Z
	game.camera.position = Vector3(0,7.3,wall-18)
	game.camera.look_at(Vector3(0,4.1,wall-5))
	game.camera.fov = 76
	var p = game.local_pawn()
	if scenario == "closed": game.start_attack(); game.running = false
	if scenario == "rifle":
		var point: Vector3 = preload("res://scripts/preparation_catalog.gd").stations()[0].position
		p.pos = Vector2(point.x,point.z-2.4)
		p.height = 3
		p.yaw = PI
		p.pitch = -.25
		game.camera.position = Vector3(p.pos.x,4.55,p.pos.y)
		game.camera.look_at(point+Vector3(0,.3,0))
		game.camera.fov = 65
		game.arena.scenery.sync_focus(game.sim,p)
	if scenario == "bridge_guard":
		game.camera.position = Vector3(0,1.7,-48)
		game.camera.look_at(Vector3(0,1.7,-26))
		game.camera.fov = 76
	if scenario == "coins":
		var z: float = Data.Maps.Defense.CRYSTAL.y+6
		game.camera.position = Vector3(4,4.1,z+1.2)
		game.camera.look_at(Vector3(4,3.7,z-1))
		game.camera.fov = 61
		var drops: Array = []
		for i in 5: drops.append({"age":.05*i,"value":1,"arrival":0.0,"pos":Vector3(3.55+i*.23,3.8+sin(i)*.16,z-.1-i*.18)})
		game.coins.sync(drops)
	if scenario in ["wave","wave10"]:
		game.sim.defense.wave = 10 if scenario == "wave10" else 2
		game.sim.defense_director.begin_wave()
		game.sim.elapsed += 1.2
		p.pos = Data.Maps.Defense.CRYSTAL+Vector2(0,-5)
		p.height = 3
		game.camera.position = Vector3(p.pos.x,4.55,p.pos.y)
		game.camera.look_at(Vector3(0,3,-18))
		game.camera.fov = 61
		p.yaw = game.camera.rotation.y
		p.pitch = game.camera.rotation.x
		game.weapon.sync(p,.1,game.sim.elapsed,Vector3(0,0,-50))
		game.weapon.visible = true
		for point in [Vector2(-3,3),Vector2(2,1),Vector2(0,-4)]: game.sim.spawn(point,"normal")
		game.enemies.sync(game.sim.zombies,game.sim.elapsed,false)
	if scenario.begins_with("crystal"):
		game.sim.defense.prop_clock = 9.0 if scenario.ends_with("9") else 0.0
		game.arena.scenery.sync(game.sim.defense)
		var center = Vector3(Data.Maps.Defense.CRYSTAL.x,4.75,Data.Maps.Defense.CRYSTAL.y)
		game.camera.position = center+Vector3(4.5,1.4,6)
		game.camera.look_at(center)
		game.camera.fov = 52
	if scenario.begins_with("display"):
		game.sim.defense.prop_clock = 9.0 if scenario.ends_with("9") else 0.0
		game.arena.scenery.sync(game.sim.defense)
		game.camera.position = Vector3(0,6.2,wall-8.6)
		game.camera.look_at(Vector3(0,4.35,wall-2.3))
		game.camera.fov = 90
	if not building_id.is_empty():
		var item = game.sim.defense_director.structures.find(building_id)
		var center = Vector3(item.pos.x,item.height+.7,item.pos.y)
		if parts[0] == "gate" and parts[1] == "built":
			game.camera.position = center+Vector3(2,4.5,11)
		elif parts[0] == "gate":
			center.x = -4.65
			game.camera.position = center+Vector3(2,2,4)
		elif parts[0] == "mine":
			center.y = item.height+.25
			game.sim.defense.prop_clock = .8 if scenario == "mine_blink_off" else 0.0
			item.triggered = scenario.begins_with("mine_triggered")
			item.fuse = 1.45
			game.arena.scenery.sync(game.sim.defense)
			game.camera.position = center+Vector3(1.5,1.6,2.0)
		else:
			game.camera.position = center+Vector3(2.8,2,-4)
		game.camera.look_at(center)
		game.camera.fov = 60
		if parts[1] in ["prompt","unbuilt"]:
			for entry in preload("res://scripts/preparation_catalog.gd").targets(game.sim):
				if entry.id != building_id: continue
				p.pos = Vector2(entry.position.x,entry.position.z+(-2.4 if parts[0] == "turret" else 2.4))
				p.height = Data.Maps.Defense.height(p.pos)
				game.camera.position = Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p),p.pos.y)
				game.camera.look_at(entry.position+Vector3(0,.25,0))
				p.yaw = game.camera.rotation.y
				p.pitch = game.camera.rotation.x
			game.arena.scenery.sync_focus(game.sim,p)
	game.running = true
	game.ui.native_hud.sync()
	game.running = false
	game.ui.native_hud.visible = true
	if scenario in ["open","closed"] or not building_id.is_empty() or scenario.begins_with("display") or scenario.begins_with("crystal"): game.ui.native_hud.weapon_label.get_parent().get_parent().visible = false
	game.arena.scenery.preparation.sync(game.sim.defense)
	RenderingServer.render_loop_enabled = false
	for i in 5: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	RenderingServer.force_draw(true)
	JavaScriptBridge.eval("window.__preparationReviewReady="+JSON.stringify({"scenario":scenario,"stations":game.arena.scenery.preparation.stations.size(),"closed":game.sim.defense.started,"coins":12450,"diamonds":37,"announcement":game.ui.native_hud.wave_announcement.text,"alpha":game.ui.native_hud.wave_announcement.modulate.a,"focus_text":game.arena.scenery.preparation.focus_label.text,"focus_visible":game.arena.scenery.preparation.focus_label.visible}),true)
