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
	if scenario == "coins":
		var z: float = Data.Maps.Defense.CRYSTAL.y+6
		game.camera.position = Vector3(4,4.1,z+1.2)
		game.camera.look_at(Vector3(4,3.7,z-1))
		game.camera.fov = 61
		var drops: Array = []
		for i in 5: drops.append({"age":.05*i,"value":1,"arrival":0.0,"pos":Vector3(3.55+i*.23,3.8+sin(i)*.16,z-.1-i*.18)})
		game.coins.sync(drops)
	game.running = true
	game.ui.native_hud.sync()
	game.running = false
	game.ui.native_hud.visible = true
	if scenario in ["open","closed"]: game.ui.native_hud.weapon_label.get_parent().get_parent().visible = false
	game.arena.scenery.preparation.sync(game.sim.defense)
	RenderingServer.render_loop_enabled = false
	for i in 5: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	RenderingServer.force_draw(true)
	JavaScriptBridge.eval("window.__preparationReviewReady="+JSON.stringify({"scenario":scenario,"stations":game.arena.scenery.preparation.stations.size(),"closed":game.sim.defense.started,"coins":12450,"diamonds":37}),true)
