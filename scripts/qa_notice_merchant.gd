extends Node
## Isolated UI recording; browser drags the actual scrollbar and clicks native buttons.
var game
var callback: JavaScriptObject
var last_frame = -1
const FPS = 8.0
const FRAMES = 104
func stage() -> void:
	Data.settings.coop_notice_seen = false
	Data.settings.resolution = 1.0
	Data.settings.aa = 0
	game.apply_graphics()
	game.ui.show_multiplayer()
	game.set_process(false)
	game.set_physics_process(false)
	game.focused = true
	for i in 5: await get_tree().process_frame
	var view = game.ui.multiplayer_view
	var bar = view.notice_scroll.get_v_scroll_bar()
	var rect: Rect2 = bar.get_global_rect()
	var thumb = rect.size.y*bar.page/bar.max_value
	var confirm: Rect2 = view.notice_confirm.get_global_rect()
	var cancel: Rect2 = view.dialog.find_child("NoticeCancel",true,false).get_global_rect()
	var reopen: Rect2 = view.stage.get_node("CoopNoticeButton").get_global_rect()
	RenderingServer.render_loop_enabled = false
	RenderingServer.force_draw(true)
	callback = JavaScriptBridge.create_callback(draw_frame)
	JavaScriptBridge.get_interface("window").__drawNoticeMerchant = callback
	JavaScriptBridge.eval("window.__noticeFrame=-1",true)
	JavaScriptBridge.eval("window.__campaignReviewReady="+JSON.stringify({"scenario":"notice_merchant","frames":FRAMES,"fps":FPS,"renderer":"Godot Web / Chromium SwiftShader","drag_from":[rect.get_center().x,rect.position.y+thumb*.5],"drag_to":[rect.get_center().x,rect.end.y-thumb*.5],"confirm":[confirm.get_center().x,confirm.get_center().y],"cancel":[cancel.get_center().x,cancel.get_center().y],"reopen":[reopen.get_center().x,reopen.get_center().y]}),true)
func draw_frame(args: Array) -> void:
	var frame = int(args[0])
	if frame != last_frame+1: return
	last_frame = frame
	if frame == 60:
		Progress.store = preload("res://scripts/progression_store.gd").new()
		Progress.store.data.intro_seen = true
		Progress.store.data.tutorial_stage = 1
		Progress.store.data.ultimate_choice = "blade"
		game.start_solo("defense",722)
		await get_tree().physics_frame
		var p = game.local_pawn()
		p.pos = preload("res://scripts/defense_layout.gd").SHOP_OWNER+Vector2(0,-4.5)
		p.height = 3.0
		p.yaw = PI
		p.pitch = .16
		game.yaw = PI
		game.pitch = .16
	if game.sim: game._physics_process(1.0/FPS)
	game._process(1.0/FPS)
	game.first_person_layer.sync_view()
	for i in 3: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var view = game.ui.multiplayer_view
	var dialog_open: bool = game.ui.current == "multiplayer" and is_instance_valid(view.dialog)
	var alert = game.arena.scenery.shop.owner_alert
	JavaScriptBridge.eval("window.__noticeState="+JSON.stringify({"frame":frame,"menu":game.ui.current,"dialog":dialog_open,"read":view.notice_read if dialog_open else false,"confirm_disabled":view.notice_confirm.disabled if dialog_open else false,"seen":Data.settings.coop_notice_seen,"merchant":alert.visible if game.sim else false,"alert_size":alert.font_size*alert.pixel_size if game.sim else 0.0}),true)
	JavaScriptBridge.eval("window.__noticeFrame="+str(frame),true)
