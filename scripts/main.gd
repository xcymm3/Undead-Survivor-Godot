extends Node3D
const Simulation = preload("res://scripts/simulation.gd")
const Arena = preload("res://scripts/arena.gd")
const EnemyView = preload("res://scripts/enemy_view.gd")
var arena
var enemies
var sim
var camera: Camera3D
var weapon
var sound
var effects
var ui
var partners: Dictionary = {}
var running = false
var paused = false
var focused = true
var finished = false
var yaw = 0.0
var pitch = 0.0
var requested_weapon = 0
var jump_pending = false
var reload_pending = false
var fire_pending = false
var fire_held = false
var aim_held = false
var spectating = ""
var snapshot_timer = 0.0
var queued_effects: Array = []
var death_timer = 0.0
var draw_timer = 0.0
var redraw_frames = 4
var pixelation: ColorRect

func _ready() -> void:
	RenderingServer.render_loop_enabled = "--capture" in OS.get_cmdline_user_args()
	arena = Arena.new()
	add_child(arena)
	enemies = EnemyView.new()
	add_child(enemies)
	camera = Camera3D.new()
	camera.near = .04
	camera.far = 250
	camera.fov = 61
	camera.cull_mask = 3
	add_child(camera)
	camera.current = true
	weapon = preload("res://scripts/weapon_view.gd").new()
	camera.add_child(weapon)
	weapon.visible = false
	sound = preload("res://scripts/sound.gd").new()
	add_child(sound)
	effects = preload("res://scripts/effects.gd").new()
	add_child(effects)
	var post = CanvasLayer.new()
	post.layer = 0
	add_child(post)
	pixelation = ColorRect.new()
	pixelation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pixelation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pixel_material = ShaderMaterial.new()
	pixel_material.shader = load("res://scripts/pixelation.gdshader")
	pixelation.material = pixel_material
	post.add_child(pixelation)
	Data.settings_changed.connect(apply_graphics)
	apply_graphics()
	ui = preload("res://scripts/interface.gd").new()
	ui.game = self
	add_child(ui)
	Session.match_started.connect(start_coop)
	Session.input_received.connect(func(id,command):
		if running and sim and Session.is_host(): sim.submit(id,command))
	Session.world_received.connect(func(state):
		if running and sim: sim.apply_snapshot(state))
	Session.effects_received.connect(handle_effects)
	Session.member_left.connect(func(id):
		if running and sim and Session.is_host(): sim.pawns.erase(id))
	Session.disconnected.connect(func(message):
		return_home()
		ui.message = message
		ui.show_home())
	get_window().focus_exited.connect(_focus_lost)
	get_window().focus_entered.connect(_focus_gained)
	get_window().close_requested.connect(quit_game)
	return_home()
	# Explicit command-line launch modes also support silent local integration validation.
	var args = OS.get_cmdline_user_args()
	if "--practice" in args: start_solo("practice")
	if "--survival" in args: start_solo("survival")
	if "--lan-host" in args: Session.host_lan("房主")
	for arg in args:
		if arg.begins_with("--lan-join="): Session.join_lan(arg.trim_prefix("--lan-join="),"队友")
	if Data.automation:
		var observer = preload("res://scripts/automation_observer.gd").new()
		observer.game = self
		add_child(observer)

func start_solo(mode: String) -> void:
	Session.leave()
	reset_game()
	sim = Simulation.new(arena)
	sim.add_pawn("solo","幸存者",0)
	sim.pawns.solo.pos = Vector2(0,9)
	sim.start(mode)
	resume_game()

func start_coop() -> void:
	reset_game()
	sim = Simulation.new(arena)
	var i = 0
	for id in Session.members:
		sim.add_pawn(id,Session.members[id],i)
		i += 1
	if Session.is_host(): sim.start("survival")
	resume_game()

func reset_game() -> void:
	if sim: sim.dispose()
	reset_mouse_buttons()
	running = true
	paused = false
	finished = false
	death_timer = 0.0
	yaw = 0
	pitch = 0
	requested_weapon = 0
	jump_pending = false
	reload_pending = false
	fire_pending = false
	spectating = ""
	queued_effects.clear()
	for partner in partners.values(): partner.queue_free()
	partners.clear()
	effects.particles.clear()
	enemies.clear()
	weapon.visible = true
	snapshot_timer = 0
	sound.set_playing(true)

func local_pawn() -> Dictionary:
	return sim.pawns.get(Session.local_id,{}) if sim else {}

func view_pawn() -> Dictionary:
	var local = local_pawn()
	if local.is_empty() or local.hp > 0 or not Session.playing: return local
	if sim.pawns.has(spectating) and sim.pawns[spectating].hp > 0: return sim.pawns[spectating]
	for p in sim.pawns.values():
		if p.hp > 0:
			spectating = p.id
			return p
	return local

func cycle_spectator() -> void:
	var living: Array = sim.pawns.values().filter(func(p): return p.hp > 0)
	if living.is_empty(): return
	var index = 0
	for i in living.size():
		if living[i].id == spectating: index = (i+1)%living.size()
	spectating = living[index].id

func input_state() -> Dictionary:
	var enabled = running and not paused and focused and not finished
	var command = {"x":Input.get_axis("left","right") if enabled else 0.0,"y":Input.get_axis("forward","back") if enabled else 0.0,"yaw":yaw,"pitch":pitch,"weapon":requested_weapon,"jump":jump_pending and enabled,"reload":reload_pending and enabled,"fire":enabled and (fire_pending or fire_held),"aim":enabled and aim_held}
	jump_pending = false
	reload_pending = false
	fire_pending = false
	return command

func _physics_process(dt: float) -> void:
	if "--auto-start" in OS.get_cmdline_user_args() and Session.is_host() and not Session.playing and Session.members.size() >= 2: Session.begin_match()
	if not running or not sim or finished: return
	if paused and not Session.playing: return
	var command = input_state()
	if Session.playing and not Session.is_host():
		Session.send_input(command)
	else:
		sim.submit(Session.local_id,command)
		sim.step(dt)
		handle_effects(sim.events)
		queued_effects.append_array(sim.events)
		if Session.is_host():
			snapshot_timer += dt
			if snapshot_timer >= .05 or sim.failed:
				snapshot_timer = 0
				Session.send_world(sim.snapshot(),queued_effects)
				queued_effects.clear()
		else: queued_effects.clear()
	if sim.failed: finish_run()

func _process(dt: float) -> void:
	if not focused: return
	if not running or (paused and not Session.playing) or (finished and death_timer > 1.2 and ui.current == "result"):
		# Menu and pause screens render only after input or UI changes.
		Engine.max_fps = 20 if Data.automation and OS.has_feature("web") else 60
		if redraw_frames > 0:
			redraw_frames -= 1
			RenderingServer.force_draw(true)
		return
	Engine.max_fps = int(Data.settings.frame_limit)
	if not sim: return
	var p = view_pawn()
	if p.is_empty(): return
	var desired = Vector3(p.pos.x,p.height+1.7,p.pos.y)
	if Session.playing and not Session.is_host(): camera.position = camera.position.lerp(desired,1-exp(-dt*22))
	else: camera.position = desired
	var spectate: bool = p.id != Session.local_id
	camera.rotation = Vector3(p.pitch,p.yaw,0) if spectate else Vector3(pitch,yaw,0)
	var w: Dictionary = Data.weapons[int(p.weapon)]
	var magnification: float = 6.0 if w.id == "sniper" else 1.0 if w.get("kind", "gun") in ["melee","flame"] else 1.25
	var aim_fov = rad_to_deg(2*atan(tan(deg_to_rad(61)/2)/magnification))
	camera.fov = lerpf(61,aim_fov,weapon.ads)
	var aim_target = camera.position-camera.global_basis.z*180
	var aim_surface: Dictionary = arena.surface_hit(camera.position,aim_target)
	if not aim_surface.is_empty(): aim_target = aim_surface.position
	var aim_distance = camera.position.distance_to(aim_target)
	for zombie in sim.zombies:
		if zombie.hp <= 0: continue
		var impact = EnemyView.hit(zombie,camera.position,-camera.global_basis.z,aim_distance,sim.elapsed,sim.mode == "practice")
		if not impact.is_empty():
			aim_distance = impact.distance
			aim_target = camera.position-camera.global_basis.z*aim_distance
	weapon.sync(p,dt,sim.elapsed,camera.to_local(aim_target))
	enemies.sync(sim.zombies,sim.elapsed,sim.mode == "practice")
	effects.step(dt)
	for id in sim.pawns:
		if id == Session.local_id: continue
		if not partners.has(id):
			var partner = preload("res://scripts/partner_view.gd").new()
			add_child(partner)
			partner.setup(sim.pawns[id])
			partners[id] = partner
		partners[id].sync(sim.pawns[id],dt)
		if spectate and id == p.id: partners[id].visible = false
	for id in partners.keys():
		if not sim.pawns.has(id):
			partners[id].queue_free()
			partners.erase(id)
	if finished:
		death_timer += dt
		weapon.visible = false
		for z in sim.zombies:
			if z.id == sim.culprit:
				var head = Vector3(z.pos.x,1.8*Data.enemy_scale(z.kind),z.pos.y)
				camera.position = desired.lerp(head+(desired-head).normalized()*.85,clampf(death_timer*.8,0,1))
				if camera.position.distance_to(head) > .05: camera.look_at(head)
		if death_timer > 1.2 and ui.current != "result": ui.show_result()
	ui.tick(dt)
	draw_timer += dt
	if "--capture" not in OS.get_cmdline_user_args():
		# CI keeps physics/input active while limiting expensive software-rasterized frames.
		if not (Data.automation and OS.has_feature("web")) or draw_timer >= .5:
			RenderingServer.force_draw(true)
			draw_timer = 0

func handle_effects(events: Array) -> void:
	for event in events:
		if not event is Dictionary or not event.has("kind"): continue
		match event.kind:
			"shot":
				var index = clampi(int(event.get("weapon",0)),0,9)
				var w: Dictionary = Data.weapons[index]
				var kind: String = w.get("kind","gun")
				sound.play("axe" if kind == "melee" else "flame" if kind == "flame" else "gun",-10 if event.player == Session.local_id else -19)
				var visual_origin: Vector3 = event.from
				var viewed: Dictionary = view_pawn()
				if not viewed.is_empty() and event.player == viewed.id:
					visual_origin = weapon.muzzle_position()
				elif partners.has(event.player):
					visual_origin = partners[event.player].muzzle_position()
				if kind == "flame": effects.flame(visual_origin,event.to)
				elif kind == "gun":
					if event.has("pellet_ends"): effects.shotgun(visual_origin,event.pellet_ends)
					else: effects.tracer(visual_origin,event.to,w.id != "revolver")
			"blood", "death":
				effects.burst(event.position)
				if event.get("player") == Session.local_id: ui.hit_flash = .12
				if event.kind == "death": sound.play("death-%d" % (randi()%3),-16)
			"armor":
				effects.burst(event.position,true,event.broken)
				if event.get("player") == Session.local_id: ui.hit_flash = .12
				sound.play("%s-%s" % [event.armor,"true" if event.broken else "false"],-13)
			"hurt":
				if event.player == Session.local_id:
					ui.hurt_flash = .45
					sound.play("hurt")
			"reload":
				if event.player == Session.local_id: sound.play("reload",-15)

func finish_run() -> void:
	if finished: return
	reset_mouse_buttons()
	finished = true
	death_timer = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sound.set_playing(false)
	sound.play("failure",-9)
	if not Session.playing and sim.mode == "survival":
		var p = local_pawn()
		Data.record(sim.cleared,sim.kills,sim.elapsed,p.shots,p.hits)

func pause_game() -> void:
	if not running or finished: return
	reset_mouse_buttons()
	paused = true
	jump_pending = false
	reload_pending = false
	fire_pending = false
	if sim:
		for p in sim.pawns.values():
			if p.id == Session.local_id: p.aim = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not Session.playing: sound.set_playing(false)
	ui.show_pause()

func resume_game() -> void:
	reset_mouse_buttons()
	paused = false
	ui.clear_menu()
	if not Data.automation and DisplayServer.get_name() != "headless" and "--silent" not in OS.get_cmdline_user_args(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	sound.set_playing(true)

func return_home() -> void:
	reset_mouse_buttons()
	Session.leave()
	running = false
	paused = false
	finished = false
	if sim: sim.dispose()
	sim = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if weapon: weapon.visible = false
	if enemies: enemies.clear()
	for partner in partners.values(): partner.queue_free()
	partners.clear()
	if sound: sound.set_playing(false)
	if camera:
		camera.position = Vector3(14,10,11)
		camera.look_at(Vector3(-3,1,-21))
		camera.fov = 61
	if ui: ui.show_home()

func request_draw() -> void:
	redraw_frames = 4

func apply_graphics() -> void:
	arena.sun.shadow_enabled = Data.settings.shadows > 0
	arena.sun.directional_shadow_max_distance = [0,25,45,65,90][int(Data.settings.shadows)]
	RenderingServer.directional_shadow_atlas_set_size([512,512,1024,2048,4096][int(Data.settings.shadows)],true)
	camera.far = [90,150,250][int(Data.settings.distance)]
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X,Viewport.MSAA_8X][int(Data.settings.aa)]
	get_viewport().scaling_3d_scale = Data.settings.resolution
	pixelation.visible = Data.settings.pixelated
	request_draw()

func reset_mouse_buttons() -> void:
	fire_pending = false
	fire_held = false
	aim_held = false

func _input(event: InputEvent) -> void:
	request_draw()
	# Read each button before GUI handling; right-button aim never owns left-button fire.
	if not event is InputEventMouseButton: return
	if not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: fire_held = false
		if event.button_index == MOUSE_BUTTON_RIGHT: aim_held = false
	if not running or paused or finished or not focused: return
	if event.button_index == MOUSE_BUTTON_LEFT:
		fire_held = event.pressed
		if event.pressed:
			if not local_pawn().is_empty() and local_pawn().hp <= 0: cycle_spectator()
			else: fire_pending = true
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		aim_held = event.pressed
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if running and not finished:
				if paused: resume_game()
				else: pause_game()
			elif ui.current != "home": ui.back()
		if event.keycode == KEY_M:
			Data.settings.muted = not Data.settings.muted
			Data.apply_settings()
			Data.save()
		if event.keycode == KEY_F11:
			Data.settings.fullscreen = not Data.settings.fullscreen
			Data.apply_settings()
			Data.save()
	if not running or paused or finished: return
	if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Data.automation):
		var sensitivity: float = Data.settings.sensitivity*tan(deg_to_rad(camera.fov)/2)/tan(deg_to_rad(61)/2)
		var delta = event.screen_relative
		var max_delta = minf(180,deg_to_rad(25)/maxf(.000001,sensitivity))
		if absf(delta.x) <= max_delta: yaw = wrapf(yaw-delta.x*sensitivity,-PI,PI)
		if absf(delta.y) <= max_delta: pitch = clampf(pitch-delta.y*sensitivity,-deg_to_rad(85),deg_to_rad(85))
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: requested_weapon = posmod(requested_weapon-1,10)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: requested_weapon = (requested_weapon+1)%10
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE: jump_pending = true
		if event.physical_keycode == KEY_R: reload_pending = true
		if event.keycode >= KEY_1 and event.keycode <= KEY_9: requested_weapon = event.keycode-KEY_1
		if event.keycode == KEY_0: requested_weapon = 9

func _focus_lost() -> void:
	if "--capture" in OS.get_cmdline_user_args(): return
	reset_mouse_buttons()
	focused = false
	jump_pending = false
	reload_pending = false
	fire_pending = false
	if running and not finished: pause_game()
	RenderingServer.render_loop_enabled = false

func _focus_gained() -> void:
	focused = true
	request_draw()
	RenderingServer.render_loop_enabled = "--capture" in OS.get_cmdline_user_args()

func quit_game() -> void:
	Data.save()
	Session.leave()
	get_tree().quit()
