extends Node
## In-memory sample progress, production save UI; isolated cloud screenshot fixture only.
var game
var callback: JavaScriptObject

func stage() -> void:
	if not Data.automation or not OS.has_feature("web"): return
	Progress.slots.clear()
	for index in 3:
		var profile = preload("res://scripts/progression_store.gd").new()
		profile.award_coins([1285.5,275.0,0.0][index])
		for wave in [12,4,0][index]: profile.award_wave(wave%10+1)
		if index == 0: profile.award_victory()
		if index < 2:
			profile.purchase("rifle")
			profile.purchase("strong")
		Progress.slots.append(profile)
	Progress.active_slot = 0
	Progress.store = Progress.slots[0]
	game.ui.show_save_slots()
	callback = JavaScriptBridge.create_callback(request_action)
	JavaScriptBridge.get_interface("window").__saveSlotAction = callback
	await publish("initial")

func request_action(args: Array) -> void:
	var action = str(args[0])
	var index = int(args[1])
	if action == "delete": game.ui.menu.find_child("DeleteSlot%d" % (index+1),true,false).pressed.emit()
	elif action == "cancel": game.ui.show_save_slots()
	elif action == "select": game.ui.menu.find_child("SelectSlot%d" % (index+1),true,false).pressed.emit()
	await publish(action)

func publish(action: String) -> void:
	RenderingServer.render_loop_enabled = false
	game.get_viewport().scaling_3d_scale = 1.0
	for index in 5: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var fields = []
	for index in 3:
		var slot = game.ui.menu.find_child("SaveSlot%d" % (index+1),true,false)
		if slot:
			var remove = slot.find_child("DeleteSlot%d" % (index+1),true,false)
			fields.append({"coins":slot.find_child("LifetimeCoins",true,false).text,"diamonds":slot.find_child("LifetimeDiamonds",true,false).text,"victories":slot.find_child("Victories",true,false).text,"delete_text":remove.text,"delete_name":remove.accessibility_name})
	var frame = game.ui.menu.find_child("FieldConsole",true,false)
	JavaScriptBridge.eval("window.__saveSlotsReady="+JSON.stringify({"action":action,"menu":game.ui.current,"active":Progress.active_slot,"running":game.running,"has_sim":game.sim != null,"fields":fields,"frame_size":[frame.size.x,frame.size.y] if frame else [],"wallet":Progress.store.data.coins,"total_coins":Progress.store.data.total_coins_earned}),true)
