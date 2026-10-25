extends Node
## Explicit, frozen production scene captures for the requested shop/HUD review.
const Layout = preload("res://scripts/defense_layout.gd")
const Catalog = preload("res://scripts/preparation_catalog.gd")
const Tutorial = preload("res://scripts/onboarding.gd")
var game
var visual_callback: JavaScriptObject
var visual_time = 0.0

func rectangle(rect: Rect2) -> Dictionary:
	return {"x":rect.position.x,"y":rect.position.y,"width":rect.size.x,"height":rect.size.y}

func stage(scenario: String) -> void:
	var progress = game.get_node("/root/Progress")
	progress.store = preload("res://scripts/progression_store.gd").new()
	progress.store.data.merge({"intro_seen":true,"tutorial_stage":Tutorial.SHOP_PENDING if scenario in ["shop_review_front","shop_review_side","shop_review_dialogue_near","shop_review_dialogue_normal"] else Tutorial.COMPLETE,"ultimate_unlocked":true,"coins":350.0},true)
	progress.store.data.grenade_level = 3
	game.start_solo("defense",491)
	game.set_process(false)
	game.set_physics_process(false)
	await get_tree().physics_frame
	game.ui.clear_menu()
	var sim = game.sim
	var p = game.local_pawn()
	p.height = 3.0
	p.grenade_capacity = 3
	p.grenades = 1
	p.grenade_replenish = 5.25
	p.ultimate_cd = 35.0
	game.weapon.hide()
	var point = Vector3(Layout.SHOP_OWNER.x,4.7,Layout.SHOP_OWNER.y)
	match scenario:
		"shop_review_entry":
			p.pos = Vector2(20,Layout.SHOP_DOOR_Z)
			game.camera.position = Vector3(p.pos.x,4.7,p.pos.y)
			game.camera.look_at(Vector3(12.8,4.7,Layout.SHOP_DOOR_Z))
		"shop_review_dialogue_near", "shop_review_dialogue_normal":
			p.pos = Vector2(Layout.SHOP_OWNER.x,Layout.SHOP_COUNTER_FRONT_Z-.65) if scenario.ends_with("near") else Layout.SHOP_OWNER+Vector2(.7,-2.7)
			game.camera.position = Vector3(p.pos.x,4.7,p.pos.y)
			Tutorial.begin_dialogue(sim,p)
			sim.defense.tutorial_dialogue_elapsed = Tutorial.SHOP_LINES[0].length()/Tutorial.CHARACTERS_PER_SECOND+.1
			game.camera.rotation = Vector3(p.pitch,p.yaw,0)
		"shop_review_front":
			p.pos = Layout.SHOP_OWNER+Vector2(0,-2.7)
			game.camera.position = Vector3(p.pos.x,4.7,p.pos.y)
			game.camera.look_at(point)
		"shop_review_side":
			p.pos = Vector2(Layout.SHOP_COUNTER_X-2.2,Layout.SHOP_OWNER.y)
			game.camera.position = Vector3(p.pos.x,4.7,p.pos.y)
			game.camera.look_at(point)
		"shop_review_wall":
			p.pos = Vector2(-2.7,Layout.SHOP_AREA.end.y-2.0)
			game.camera.position = Vector3(p.pos.x,4.7,p.pos.y)
			game.camera.look_at(Vector3(-2.7,4.7,Layout.SHOP_AREA.end.y-.7))
			game.weapon.show()
		"shop_review_four", "shop_review_grenade", "shop_review_locked", "shop_review_ready", "shop_review_flow":
			p.pos = Layout.CRYSTAL+Vector2(0,6)
			game.camera.position = Vector3(p.pos.x,4.7,p.pos.y)
			game.camera.look_at(Vector3(0,4.4,Layout.CRYSTAL.y-15))
			if scenario == "shop_review_four":
				for index in 3:
					var guest = p.duplicate(true)
					guest.id = "review_guest_"+str(index)
					guest.name = ["队友·先锋","队友·守卫","队友·斥候"][index]
					guest.hp = [74.5,42.0,100.0][index]
					guest.appearance = p.appearance.duplicate()
					guest.appearance[0] = (int(p.appearance[0])+index+1)%4
					guest.pos = Layout.CRYSTAL+Vector2(-3+index*3,-3)
					sim.pawns[guest.id] = guest
			game.weapon.show()
		_:
			p.pos = Vector2(9,Layout.SHOP_FRONT_Z+1.5)
			game.camera.position = Vector3(p.pos.x,6.2,p.pos.y)
			game.camera.look_at(Vector3(-2,4.2,Layout.SHOP_FRONT_Z+10.5))
	game.camera.fov = 72 if scenario == "shop_review_overview" else 65
	if scenario in ["shop_review_entry","shop_review_dialogue_near","shop_review_dialogue_normal"]: game.camera.fov = 61
	p.yaw = game.camera.rotation.y
	p.pitch = game.camera.rotation.x
	game.weapon.sync(p,0,sim.elapsed,Vector3(0,0,-20))
	game.arena.scenery.sync(sim.defense)
	game.arena.scenery.sync_focus(sim,p)
	if scenario == "shop_review_locked":
		p.ultimate_unlocked = false
		sim.progression.data.ultimate_unlocked = false
	game.running = true
	game.ui.native_hud.sync()
	game.running = false
	game.ui.native_hud.upgrade_details.hide()
	game.get_viewport().scaling_3d_scale = 1.0
	var ring = game.ui.native_hud.ultimate_ring
	ring.set_process(false)
	game.ui.native_hud.grenade_ring.set_process(false)
	ring.animation_clock = 0.0
	if scenario == "shop_review_ready":
		p.ultimate_cd = 0.0
		ring.sync(.99,"99%","终极技能 · Q")
		ring.sync(1.0,"100%","终极技能 · Q")
		ring.advance_visual(.24)
	visual_callback = JavaScriptBridge.create_callback(request_visual)
	JavaScriptBridge.get_interface("window").__skillVisualCallback = visual_callback
	JavaScriptBridge.eval("window.__skillVisualSeek = t => { window.__skillVisualTime = -1; window.__skillVisualCallback(t); }",true)
	RenderingServer.render_loop_enabled = false
	for index in 6: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	RenderingServer.force_draw(true)
	var hud = game.ui.native_hud
	var ultimate_rect: Rect2 = hud.ultimate_ring.get_global_rect()
	var grenade_rect: Rect2 = hud.grenade_ring.get_global_rect()
	var health_rects: Array = []
	var overlaps = false
	var shop = game.arena.scenery.shop
	var doorway_posts = shop.get_node("Storefront").get_children().filter(func(node): return str(node.name).begins_with("SideTimberPost") and node.position.x > 0 and absf(node.position.z-Layout.SHOP_DOOR_Z) < Layout.SHOP_DOOR_WIDTH*.5).size()
	var dialogue_center: Vector2 = game.camera.unproject_position(shop.owner_dialogue.global_position)
	var text_rect = Rect2(dialogue_center,Vector2.ZERO)
	# Billboard AABBs include rotation padding; project the actual text vertices.
	var text_mesh = shop.owner_dialogue.generate_triangle_mesh()
	if text_mesh:
		for vertex in text_mesh.get_faces():
			var corner = shop.owner_dialogue.global_position+game.camera.global_basis.x*vertex.x+game.camera.global_basis.y*vertex.y
			text_rect = text_rect.expand(game.camera.unproject_position(corner))
	JavaScriptBridge.eval("window.__shopFixReview="+JSON.stringify({"doorway_posts":doorway_posts,"dialogue":shop.owner_dialogue.text,"dialogue_visible":shop.owner_dialogue.visible,"dialogue_height":shop.owner_dialogue.position.y,"dialogue_width":shop.owner_dialogue.width,"text_rect":rectangle(text_rect),"center":rectangle(Rect2(dialogue_center,Vector2.ZERO)),"distance":p.pos.distance_to(Layout.SHOP_OWNER)}),true)
	for card in hud.cards.values():
		var rect: Rect2 = card.panel.get_global_rect()
		health_rects.append(rectangle(rect))
		overlaps = overlaps or rect.intersects(ultimate_rect) or rect.intersects(grenade_rect)
	JavaScriptBridge.eval("window.__shopHudReviewReady="+JSON.stringify({"scenario":scenario,"focus":Catalog.focus(sim,p).get("id",""),"owner_yaw":game.arena.scenery.shop.owner_model.rotation.y,"ultimate_rect":rectangle(ultimate_rect),"grenade_rect":rectangle(grenade_rect),"health_rects":health_rects,"overlaps":overlaps,"ultimate_visible":hud.ultimate_ring.visible,"ready_flash":hud.ultimate_ring.ready_flash,"ready_flash_count":hud.ultimate_ring.ready_flash_count,"grenade_caption":hud.grenade_ring.caption,"grenade_progress":hud.grenade_ring.progress,"width":game.get_viewport().get_visible_rect().size.x,"height":game.get_viewport().get_visible_rect().size.y,"no_portraits":hud.cards.values().all(func(card): return not card.has("portrait")),"left_count":hud.health_row.get_child_count(),"right_count":hud.health_right.get_child_count(),"first_person":game.first_person_layer.camera.cull_mask == 2 and game.camera.cull_mask & 2 == 0,"stations":Catalog.stations().size()}),true)

func request_visual(args: Array) -> void:
	if not args.is_empty(): call_deferred("seek_visual",float(args[0]))

func seek_visual(time: float) -> void:
	game.ui.native_hud.ultimate_ring.advance_visual(maxf(0,time-visual_time))
	visual_time = time
	for index in 2: await get_tree().process_frame
	RenderingServer.force_draw(true)
	JavaScriptBridge.eval("window.__skillVisualTime="+str(time),true)
