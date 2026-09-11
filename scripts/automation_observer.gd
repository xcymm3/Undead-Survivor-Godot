extends Node
## Read-only QA telemetry. Gameplay is driven through actual input, never this observer.
var game
var interval = 0.0
var frames = 0
var aim_assist

func _ready() -> void:
	if not Data.automation:
		queue_free()
		return
	if "--qa-native-smoke" in OS.get_cmdline_user_args(): call_deferred("native_smoke")
	if "--qa-autoaim" in OS.get_cmdline_user_args():
		aim_assist = preload("res://scripts/qa_aim_assist.gd").new()
		aim_assist.game = game
		add_child(aim_assist)

func _process(dt: float) -> void:
	frames += 1
	interval += dt
	if not OS.has_feature("web") or interval < .1: return
	interval = 0
	JavaScriptBridge.eval("window.__survivorSnapshot = " + JSON.stringify(snapshot()) + ";", true)

func snapshot() -> Dictionary:
	var result = {"menu": game.ui.current, "running": game.running, "paused": game.paused,
		"finished": game.finished, "frames": frames, "mouse_mode": Input.mouse_mode,
		"yaw": game.yaw, "pitch": game.pitch, "fov": game.camera.fov, "buttons": []}
	for node in game.ui.root.find_children("*", "Button", true, false):
		if node.is_visible_in_tree():
			var rect: Rect2 = node.get_global_rect()
			result.buttons.append({"text": node.text, "x": rect.position.x, "y": rect.position.y,
				"width": rect.size.x, "height": rect.size.y, "disabled": node.disabled})
	if game.sim:
		result.mode = game.sim.mode
		result.elapsed = game.sim.elapsed
		result.wave = game.sim.wave
		result.cleared = game.sim.cleared
		result.rest = game.sim.rest
		result.aim_target = aim_assist.target_id if aim_assist else -1
		result.kills = game.sim.kills
		result.enemies = []
		for z in game.sim.zombies:
			result.enemies.append({"x": z.pos.x, "z": z.pos.y, "hp": z.hp, "kind": z.kind})
		var p: Dictionary = game.local_pawn()
		if not p.is_empty():
			result.player = {"x": p.pos.x, "z": p.pos.y, "height": p.height, "grounded":p.get("grounded",false), "wading":p.get("wading",false), "hp": p.hp,
				"weapon": p.weapon, "ammo": p.ammo, "shots": p.shots, "hits": p.hits,
				"reloading": p.reloading, "aim": p.aim, "fire_anim":p.fire_anim, "switch":p.switch}
	return result

func native_smoke() -> void:
	# Packaged-EXE validation: same scene, real input path, no renderer or Steam login.
	game.start_solo("practice")
	await get_tree().create_timer(.25).timeout
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().create_timer(.15).timeout
	event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)
	var p: Dictionary = game.local_pawn()
	var passed = p.shots > 0 and p.ammo[0] < Data.weapons[0].capacity and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	var tree = get_tree()
	reparent(tree.root)
	game.return_home()
	game.queue_free()
	game = null
	await tree.process_frame
	await tree.process_frame
	await tree.create_timer(.15).timeout
	print("PACKAGED EXE SMOKE: " + ("PASS" if passed else "FAIL"))
	tree.quit(0 if passed else 1)
