extends RefCounted
const Store = preload("res://scripts/progression_store.gd")

static func validate(game, check: Callable) -> void:
	var progress = game.get_node("/root/Progress")
	var original = progress.store
	var path = OS.get_cache_dir().path_join("combat-hints-"+str(OS.get_process_id())+".json")
	progress.store = Store.new(path)
	var overlay = game.ui.native_hud.tutorial_overlay
	var state = {"tutorial_stage":0,"started":true}
	overlay.sync(state,true,false,progress.store.combat_controls_learned())
	check.call(overlay.hint_frame.visible,"Unpracticed combat controls show both teaching prompts")
	game.reset_mouse_buttons()
	var pawn: Dictionary = game.local_pawn()
	var weapon: int = pawn.weapon
	pawn.weapon = 0
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = true
	game._input(mouse)
	game.input_state()
	check.call(progress.store.data.get("tutorial_aim_used",false) and not progress.store.combat_controls_learned(),"Middle-button ADS records only the aiming control")
	progress.store.save()
	progress.store = Store.new(path)
	overlay.sync(state,true,false,progress.store.combat_controls_learned())
	check.call(overlay.hint_frame.visible and progress.store.data.get("tutorial_aim_used",false),"Partial practice survives reload and keeps both prompts visible")
	game.paused = true
	mouse.button_index = MOUSE_BUTTON_RIGHT
	game._input(mouse)
	game.input_state()
	check.call(not progress.store.combat_controls_learned(),"Menu mouse input cannot complete gameplay teaching")
	game.paused = false
	game.reset_mouse_buttons()
	game._input(mouse)
	game.input_state()
	check.call(progress.store.combat_controls_learned(),"Right-button shove completes the two independent controls")
	progress.store.save()
	progress.store = Store.new(path)
	overlay.sync(state,true,false,progress.store.combat_controls_learned())
	check.call(not overlay.hint_frame.visible,"Completed combat teaching stays hidden after save reload")
	state.ultimate_tutorial_hint = true
	overlay.sync(state,true,false,progress.store.combat_controls_learned())
	check.call(overlay.hint_frame.visible and overlay.movement.text.contains("终极技能"),"Practiced combat controls do not suppress the separate ultimate tutorial")
	check.call(not Store.new().combat_controls_learned(),"Another save has independent combat practice progress")
	var invalid = Store.defaults()
	invalid.tutorial_aim_used = "true"
	check.call(not Store.valid(invalid),"Tutorial practice flags reject malformed save values")
	progress.store = original
	pawn.weapon = weapon
	game.reset_mouse_buttons()
	game.ui.native_hud.sync()
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
