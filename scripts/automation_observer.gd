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
	if "--qa-defense-structures" in OS.get_cmdline_user_args() and OS.has_feature("web"):
		var fixture = preload("res://scripts/qa_defense_structures.gd").new()
		fixture.game = game
		add_child(fixture)
	if OS.has_feature("web") and Array(OS.get_cmdline_user_args()).any(func(arg): return arg in ["--qa-defense-overview","--qa-defense-safe-zone","--qa-defense-structures-intact","--qa-defense-structures-damaged"]):
		var overview = preload("res://scripts/qa_defense_overview.gd").new()
		overview.game = game
		add_child(overview)
	if "--qa-preparation-review" in OS.get_cmdline_user_args() and OS.has_feature("web"):
		var fixture = preload("res://scripts/qa_preparation_review.gd").new()
		fixture.game = game
		add_child(fixture)
	if "--qa-campaign-review" in OS.get_cmdline_user_args() and OS.has_feature("web"):
		var fixture = preload("res://scripts/qa_campaign_review.gd").new()
		fixture.game = game
		add_child(fixture)
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
	var result = {"menu": game.ui.current, "map_id":game.arena.map_id, "running": game.running, "paused": game.paused,
		"finished": game.finished, "frames": frames, "mouse_mode": Input.mouse_mode,
		"yaw": game.yaw, "pitch": game.pitch, "fov": game.camera.fov, "buttons": []}
	for node in game.ui.root.find_children("*", "Button", true, false):
		if node.is_visible_in_tree():
			var rect: Rect2 = node.get_global_rect()
			result.buttons.append({"text": node.text, "x": rect.position.x, "y": rect.position.y,
				"width": rect.size.x, "height": rect.size.y, "disabled": node.disabled})
	if game.sim:
		result.progress = game.sim.progression.data
		result.announcement = {"visible":game.ui.native_hud.wave_announcement.visible,"text":game.ui.native_hud.wave_announcement.text,"alpha":game.ui.native_hud.wave_announcement.modulate.a}
		result.mode = game.sim.mode
		result.defense = game.sim.defense_state()
		result.won = game.sim.won
		result.failed = game.sim.failed
		result.cause = game.sim.cause
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
				"crouch": p.get("crouch",0.0), "eye_height": preload("res://scripts/player_body.gd").eye_height(p), "slot":p.get("slot",0), "weapon1":p.get("weapon1",0), "weapon2":p.get("weapon2",3), "weapon_slot":p.get("weapon_slot",1), "slot_ammo":p.get("slot_ammo",[]), "slot_reserves":p.get("slot_reserves",[]), "grenades":p.get("grenades",0), "grenade_capacity":p.get("grenade_capacity",1), "max_hp":p.get("max_hp",100), "weapon": p.weapon, "ammo": p.ammo, "reserves":p.get("reserves",[]), "shots": p.shots, "hits": p.hits,
				"focus":p.get("focus",{}),"interaction":p.get("interaction",""),"interact_time":p.get("interact_time",0.0),"regen_credit":p.get("regen_credit",0.0),"shove_cd":p.get("shove_cd",0.0),"shove_gap":p.get("shove_gap",0.0),"shove_count":p.get("shove_count",0),"shove_anim":p.get("shove_anim",0.0),"reloading": p.reloading, "aim": p.aim, "fire_anim":p.fire_anim, "switch":p.switch}
	return result

func native_smoke() -> void:
	# Packaged-EXE validation: same scene, real input path, no renderer or Steam login.
	game.start_solo("defense")
	await get_tree().create_timer(.2).timeout
	var alarm = preload("res://scripts/preparation_catalog.gd").stations()[-1].position
	var local = game.local_pawn()
	local.pos = Vector2(alarm.x,alarm.z-2)
	local.height = 3
	local.yaw = PI
	local.pitch = -.2
	game.yaw = game.local_pawn().yaw
	game.pitch = game.local_pawn().pitch
	Input.action_press("interact")
	await get_tree().create_timer(preload("res://scripts/preparation_catalog.gd").HOLD_SECONDS+.3).timeout
	Input.action_release("interact")
	Input.action_press("forward")
	await get_tree().create_timer(.2).timeout
	Input.action_release("forward")
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
	var passed = game.sim.mode == "defense" and game.sim.defense.started and not game.sim.defense.waiting
	passed = passed and p.weapon1 == 0 and p.shots > 0 and p.ammo[0] < Data.weapons[0].capacity and p.reserve == Data.defense_full_reserve(0) and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	if not passed: print("PACKAGED DEFENSE STATE: "+JSON.stringify({"started":game.sim.defense.started,"waiting":game.sim.defense.waiting,"weapon":p.weapon1,"shots":p.shots,"ammo":p.ammo[0],"reserve":p.reserve,"mouse_mode":Input.mouse_mode}))
	print("PACKAGED DEFENSE SMOKE: "+("PASS" if passed else "FAIL"))
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
