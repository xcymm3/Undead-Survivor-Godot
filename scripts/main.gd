extends Node3D
const Simulation = preload("res://scripts/simulation.gd")
const Arena = preload("res://scripts/arena.gd")
const EnemyView = preload("res://scripts/enemy_view.gd")
var arena
var enemies
var sim
var camera: Camera3D
var flashlight: SpotLight3D
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
var requested_slot = 1
var medical_camera_active = false
var medical_yaw = 0.0
var medical_pitch = -.15
var equipment_prop: Node3D
var equipment_prop_slot = -1
var requested_weapon = 0
var jump_pending = false
var reload_pending = false
var aim_pending = false
var shove_pending = false
var fire_pending = false
var fire_held = false
var aim_held = false
var spectating = ""
var snapshot_timer = 0.0
var queued_effects: Array = []
var death_timer = 0.0
var draw_timer = 0.0
var display_buffer = preload("res://scripts/snapshot_buffer.gd").new()
var pixelation: ColorRect

func _ready() -> void:
	RenderingServer.render_loop_enabled = focused and not software_qa()
	arena = Arena.new()
	arena.map_id = Data.settings.map_id
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
	flashlight = SpotLight3D.new()
	# The beam shares the viewpoint, including when standing against a wall.
	flashlight.position = Vector3.ZERO
	flashlight.spot_range = 23
	flashlight.spot_angle = 38
	flashlight.spot_angle_attenuation = 1.2
	flashlight.light_color = Color("e4e8cd")
	flashlight.light_energy = 3.2
	# A camera-coincident beam lights camera-visible surfaces directly. Its shadow
	# depth map self-shadows distant flat faces into moving bands in Compatibility.
	# Keep occluder shadows on the world lights, not this camera-mounted fill light.
	flashlight.shadow_enabled = false
	camera.add_child(flashlight)
	weapon = preload("res://scripts/weapon_view.gd").new()
	camera.add_child(weapon)
	weapon.visible = false
	sound = preload("res://scripts/sound.gd").new()
	add_child(sound)
	effects = preload("res://scripts/effects.gd").new()
	add_child(effects)
	effects.collision_query = arena.surface_hit
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
	Session.map_preparing.connect(prepare_coop)
	Session.input_received.connect(func(id,command):
		if running and sim and Session.is_host(): sim.submit(id,command))
	Session.world_received.connect(func(state):
		if running and sim:
			sim.apply_snapshot(state)
			display_buffer.push(state))
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
	if "--survival" in args: start_solo("survival")
	if "--defense" in args:
		Data.settings.map_id = "graypine_defense"
		start_solo("defense")
	if "--campaign" in args:
		Data.settings.map_id = "graypine_night"
		start_solo("campaign")
	if "--lan-host" in args: Session.host_lan("房主")
	for arg in args:
		if arg.begins_with("--lan-join="): Session.join_lan(arg.trim_prefix("--lan-join="),"队友")
	if Data.automation:
		var observer = preload("res://scripts/automation_observer.gd").new()
		observer.game = self
		add_child(observer)

func start_solo(mode: String, campaign_seed := -1) -> void:
	Session.leave()
	reset_game()
	load_map(Data.settings.map_id)
	sim = Simulation.new(arena)
	sim.add_pawn("solo","幸存者",0)
	sim.pawns.solo.pos = arena.definition.spawn
	yaw = arena.definition.yaw
	sim.pawns.solo.yaw = yaw
	if campaign_seed >= 0: sim.random.seed = campaign_seed
	sim.start(mode)
	resume_game()

func start_coop() -> void:
	reset_game()
	load_map(Session.map_id)
	yaw = arena.definition.yaw
	sim = Simulation.new(arena)
	var i = 0
	for id in Session.members:
		sim.add_pawn(id,Session.members[id],i)
		i += 1
	if Session.is_host(): sim.start(str(arena.definition.get("mode","survival")))
	resume_game()

func prepare_coop() -> void:
	load_map(Session.map_id)
	# Wait for physics to register the loaded terrain before acknowledging readiness.
	await get_tree().physics_frame
	await get_tree().process_frame
	if Session.active and Session.loading: Session.confirm_map_ready()

func reset_game() -> void:
	display_buffer.clear()
	if sound: sound.clear_effects()
	if sim: sim.dispose()
	reset_mouse_buttons()
	running = true
	paused = false
	finished = false
	death_timer = 0.0
	yaw = 0
	pitch = 0
	requested_weapon = 0
	requested_slot = 1
	jump_pending = false
	reload_pending = false
	fire_pending = false
	spectating = ""
	queued_effects.clear()
	for partner in partners.values(): partner.queue_free()
	partners.clear()
	effects.clear()
	enemies.clear()
	weapon.visible = true
	snapshot_timer = 0
	sound.set_playing(true)

func local_pawn() -> Dictionary:
	return sim.pawns.get(Session.local_id,{}) if sim else {}

func view_pawn() -> Dictionary:
	var local = local_pawn()
	if local.is_empty() or local.hp > 0 or local.get("downed",false) or not Session.playing: return local
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
	var command = {"x":Input.get_axis("left","right") if enabled else 0.0,"y":Input.get_axis("forward","back") if enabled else 0.0,"yaw":yaw,"pitch":pitch,"weapon":requested_weapon,"interact":enabled and Input.is_action_pressed("interact"),"heal":enabled and Input.is_action_pressed("heal"),"crouch":enabled and Input.is_action_pressed("crouch"),"jump":jump_pending and enabled,"reload":reload_pending and enabled,"fire":enabled and (fire_pending or fire_held),"aim":enabled and aim_held,"shove":enabled and shove_pending}
	if sim and sim.mode == "campaign":
		if not preload("res://scripts/campaign_equipment.gd").slot_available(local_pawn(),requested_slot): requested_slot = int(local_pawn().get("slot",1))
		command.slot = requested_slot
		command.use_self = enabled and fire_pending
		command.use_other = enabled and shove_pending and requested_slot == 5
	shove_pending = false
	aim_pending = false
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
			if snapshot_timer >= .05 or sim.failed or sim.won:
				snapshot_timer = 0
				Session.send_world(sim.snapshot(),queued_effects)
				queued_effects.clear()
		else: queued_effects.clear()
	if sim.failed or sim.won: finish_run()

func _process(dt: float) -> void:
	if not focused: return
	if not running or (paused and not Session.playing) or (finished and death_timer > 1.2 and ui.current == "result"):
		# Normal menus use the engine render loop, including animations and async UI.
		Engine.max_fps = 20 if Data.automation and OS.has_feature("web") else 60
		qa_draw(dt)
		return
	Engine.max_fps = int(Data.settings.frame_limit)
	if not sim: return
	var displayed: Dictionary = display_buffer.sample(dt) if Session.playing and not Session.is_host() else {}
	var visible_zombies: Array = displayed.get("zombies",sim.zombies)
	sound.sync_enemy_steps(visible_zombies,camera.position,dt)
	var visible_pawns: Dictionary = displayed.get("pawns",sim.pawns)
	var visual_time: float = displayed.get("elapsed",sim.elapsed)
	var p = view_pawn()
	if p.is_empty(): return
	if p.id != Session.local_id: p = visible_pawns.get(p.id,p)
	var desired = Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p),p.pos.y)
	if Session.playing and not Session.is_host(): camera.position = camera.position.lerp(desired,1-exp(-dt*22))
	else: camera.position = desired
	var spectate: bool = p.id != Session.local_id
	camera.rotation = Vector3(p.pitch,p.yaw,0) if spectate else Vector3(pitch,yaw,0)
	var medical_view: bool = not p.get("healing","").is_empty() or p.get("being_healed",false)
	if medical_view and not medical_camera_active:
		medical_yaw = p.yaw
		medical_pitch = -.15
	if not medical_view and medical_camera_active:
		yaw = p.yaw
		pitch = p.pitch
	medical_camera_active = medical_view
	if medical_view and not finished:
		var focus = Vector3(p.pos.x,p.height+.95-.25*p.get("crouch",0.0),p.pos.y)
		var back = Vector3(sin(medical_yaw)*cos(medical_pitch),-sin(medical_pitch),cos(medical_yaw)*cos(medical_pitch))
		var camera_target: Vector3 = focus+back*2.6
		desired = focus
		var obstruction = arena.surface_hit(desired,camera_target)
		camera.position = obstruction.position+(desired-obstruction.position).normalized()*.2 if not obstruction.is_empty() else camera_target
		camera.look_at(desired)
	var w: Dictionary = Data.weapons[int(p.weapon)]
	var magnification: float = 6.0 if w.id == "sniper" else 1.0 if w.get("kind", "gun") in ["melee","flame"] else 1.25
	var aim_fov = rad_to_deg(2*atan(tan(deg_to_rad(61)/2)/magnification))
	camera.fov = lerpf(61,aim_fov,weapon.ads)
	var aim_target = camera.position-camera.global_basis.z*180
	var aim_surface: Dictionary = arena.surface_hit(camera.position,aim_target)
	if flashlight.visible:
		var wall_distance = camera.position.distance_to(aim_surface.position) if not aim_surface.is_empty() else 180.0
		# Near walls must not saturate after moving the beam back onto the sight line.
		flashlight.light_energy = 3.2*clampf(pow(wall_distance/1.8,2),.025,1.0)
	if not aim_surface.is_empty(): aim_target = aim_surface.position
	var aim_distance = camera.position.distance_to(aim_target)
	for zombie in visible_zombies:
		if zombie.hp <= 0: continue
		var impact = EnemyView.hit(zombie,camera.position,-camera.global_basis.z,aim_distance,visual_time,false)
		if not impact.is_empty():
			aim_distance = impact.distance
			aim_target = camera.position-camera.global_basis.z*aim_distance
	weapon.sync(p,dt,visual_time,camera.to_local(aim_target))
	var equipment_slot: int = p.get("slot",1)
	weapon.visible = not medical_view and equipment_slot < 4 and not finished
	if equipment_prop_slot != equipment_slot:
		if equipment_prop: equipment_prop.queue_free()
		equipment_prop = null
		equipment_prop_slot = equipment_slot
		if equipment_slot >= 4:
			equipment_prop = preload("res://scripts/campaign_props.gd").model(equipment_slot)
			camera.add_child(equipment_prop)
			equipment_prop.position = Vector3(.24,-.20,-.55)
	if equipment_prop: equipment_prop.visible = not medical_view and not finished
	if medical_view: camera.fov = 61
	enemies.sync(visible_zombies,visual_time,false)
	effects.step(dt)
	for id in sim.pawns:
		if id == Session.local_id and not medical_view:
			if partners.has(id): partners[id].visible = false
			continue
		if not partners.has(id):
			var partner = preload("res://scripts/partner_view.gd").new()
			add_child(partner)
			partner.setup(sim.pawns[id])
			partners[id] = partner
		partners[id].sync(visible_pawns.get(id,sim.pawns[id]),dt,not displayed.is_empty())
		partners[id].label.visible = id != Session.local_id
		if spectate and id == p.id: partners[id].visible = false
	for id in partners.keys():
		if not sim.pawns.has(id):
			partners[id].queue_free()
			partners.erase(id)
	if finished:
		death_timer += dt
		weapon.visible = false
		for z in sim.zombies:
			if not sim.won and z.id == sim.culprit:
				var head = Vector3(z.pos.x,1.8*Data.enemy_scale(z.kind),z.pos.y)
				camera.position = desired.lerp(head+(desired-head).normalized()*.85,clampf(death_timer*.8,0,1))
				if camera.position.distance_to(head) > .05: camera.look_at(head)
		if death_timer > 1.2 and ui.current != "result": ui.show_result()
	ui.tick(dt)
	qa_draw(dt)

func handle_effects(events: Array) -> void:
	for event in events:
		if not event is Dictionary or not event.has("kind"): continue
		match event.kind:
			"shove":
				if event.player == Session.local_id:
					sound.play("shove",-3)
					if event.get("hits",0) > 0: sound.play("shove-hit",-3)
				else: sound.play_at("shove-hit" if event.get("hits",0) > 0 else "shove",event.position,-5)
			"shotgun_impact":
				sound.play_at("shove-hit",event.position,-7)
				if event.player == Session.local_id: ui.hit_flash = .2
			"enemy_windup", "enemy_impact", "enemy_miss":
				sound.play_at(event.kind.replace("_","-"),event.position,-12)
			"crystal_hit":
				sound.play_at("enemy-impact",event.position,-7)
			"explosion":
				effects.explosion(event.position)
				sound.play_at("grenade-explosion",event.position,-6)
			"grenade_throw", "grenade_fuse":
				sound.play_at(event.kind.replace("_","-"),event.position,-5)
			"campaign_cue":
				sound.play_at("campaign-"+event.get("cue","horde"),event.position,-8)
			"shot":
				var index = clampi(int(event.get("weapon",0)),0,9)
				var w: Dictionary = Data.weapons[index]
				var kind: String = w.get("kind","gun")
				var cue = "axe" if kind == "melee" else "flame" if kind == "flame" else "gun"
				if event.player == Session.local_id: sound.play(cue,-10)
				else: sound.play_at(cue,event.from,-10)
				var visual_origin: Vector3 = event.from
				var viewed: Dictionary = view_pawn()
				if not viewed.is_empty() and event.player == viewed.id:
					visual_origin = weapon.muzzle_position()
				elif partners.has(event.player):
					visual_origin = partners[event.player].muzzle_position()
				if kind == "flame":
					# The first-person mesh can extend past a nearby wall; never emit
					# from that cosmetic muzzle on the far side of authoritative cover.
					if not arena.surface_hit(event.from,visual_origin).is_empty(): visual_origin = event.from
					effects.flame(visual_origin,event.to)
				elif kind == "gun":
					if event.has("pellet_ends"): effects.shotgun(visual_origin,event.pellet_ends)
					else: effects.tracer(visual_origin,event.to,w.id != "revolver")
			"blood", "death":
				effects.burst(event.position)
				if event.get("player") == Session.local_id: ui.hit_flash = .12
				if event.kind == "death": sound.play_at("death-%d" % (randi()%3),event.position,-16)
			"armor":
				effects.burst(event.position,true,event.broken)
				if event.get("player") == Session.local_id: ui.hit_flash = .12
				sound.play_at("%s-%s" % [event.armor,"true" if event.broken else "false"],event.position,-13)
			"hurt":
				if event.player == Session.local_id:
					ui.hurt_flash = .45
					sound.play("rear-warning" if event.get("rear",false) else "hurt")
			"reload":
				if event.player == Session.local_id: sound.play("reload",-15)

func finish_run() -> void:
	if finished: return
	reset_mouse_buttons()
	finished = true
	death_timer = 1.3 if sim.won else 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sound.set_playing(false)
	sound.play("campaign-gate" if sim.won else "failure",-9)
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
	display_buffer.clear()
	if sound: sound.clear_effects()
	reset_mouse_buttons()
	Session.leave()
	running = false
	paused = false
	finished = false
	if sim: sim.dispose()
	sim = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if weapon: weapon.visible = false
	if equipment_prop: equipment_prop.visible = false
	if enemies: enemies.clear()
	for partner in partners.values(): partner.queue_free()
	partners.clear()
	if sound: sound.set_playing(false)
	load_map(Data.settings.map_id)
	if camera:
		camera.position = arena.definition.camera
		camera.look_at(arena.definition.look_at)
		camera.fov = 61
	if ui: ui.show_home()

func software_qa() -> bool:
	return Data.automation and OS.has_feature("web") and "--capture" not in OS.get_cmdline_user_args()

func qa_draw(dt: float) -> void:
	if not software_qa(): return
	draw_timer += dt
	if draw_timer >= .5:
		# With the render loop disabled, flush deferred scene transforms before drawing.
		# Otherwise UI/camera updates can be captured with the previous weapon/actor pose.
		for node in find_children("*","Node3D",true,false): node.force_update_transform()
		RenderingServer.force_draw(true)
		draw_timer = 0.0

func request_draw() -> void:
	# Retained for UI callers; normal rendering no longer requires invalidation.
	if software_qa(): draw_timer = .5

func apply_graphics() -> void:
	flashlight.visible = arena.map_id == "graypine_night"
	flashlight.shadow_enabled = false
	for light in arena.find_children("*","Light3D",true,false):
		light.shadow_enabled = Data.settings.shadows > 0
	arena.sun.directional_shadow_max_distance = [0,25,45,65,90][int(Data.settings.shadows)]
	RenderingServer.directional_shadow_atlas_set_size([512,512,1024,2048,4096][int(Data.settings.shadows)],true)
	camera.far = [90,150,250][int(Data.settings.distance)]
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X,Viewport.MSAA_8X][int(Data.settings.aa)]
	get_viewport().scaling_3d_scale = Data.settings.resolution
	pixelation.visible = Data.settings.pixelated
	var region = arena.bounds.grow(6)
	var visible_bounds = AABB(Vector3(region.position.x,-6,region.position.y),Vector3(region.size.x,28,region.size.y))
	for group in [enemies,effects]:
		if group:
			for child in group.get_children():
				if child is MultiMeshInstance3D: child.custom_aabb = visible_bounds
	request_draw()

func reset_mouse_buttons() -> void:
	shove_pending = false
	aim_pending = false
	fire_pending = false
	fire_held = false
	aim_held = false

func _input(event: InputEvent) -> void:
	request_draw()
	if event.is_action_released("fire"): fire_held = false
	if not running or paused or finished or not focused: return
	if event.is_action("fire") and not event.is_echo():
		fire_held = event.is_action_pressed("fire")
		if fire_held:
			if not local_pawn().is_empty() and local_pawn().hp <= 0: cycle_spectator()
			else: fire_pending = true
		get_viewport().set_input_as_handled()
	elif event.is_action("aim") and not event.is_echo():
		if event.is_action_pressed("aim"): aim_held = not aim_held
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("shove") and not event.is_echo():
		shove_pending = true
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if event.is_action_pressed("pause"):
			if running and not finished:
				if paused: resume_game()
				else: pause_game()
			elif ui.current != "home": ui.back()
		if event.is_action_pressed("mute"):
			Data.settings.muted = not Data.settings.muted
			Data.apply_settings()
			Data.save()
		if event.is_action_pressed("fullscreen"):
			Data.settings.fullscreen = not Data.settings.fullscreen
			Data.apply_settings()
			Data.save()
	if not running or paused or finished: return
	if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Data.automation):
		var sensitivity: float = Data.settings.sensitivity*tan(deg_to_rad(camera.fov)/2)/tan(deg_to_rad(61)/2)
		var delta = event.screen_relative
		var max_delta = minf(180,deg_to_rad(25)/maxf(.000001,sensitivity))
		if medical_camera_active:
			if absf(delta.x) <= max_delta: medical_yaw = wrapf(medical_yaw-delta.x*sensitivity,-PI,PI)
			if absf(delta.y) <= max_delta: medical_pitch = clampf(medical_pitch-delta.y*sensitivity,-.65,.25)
		else:
			if absf(delta.x) <= max_delta: yaw = wrapf(yaw-delta.x*sensitivity,-PI,PI)
			if absf(delta.y) <= max_delta: pitch = clampf(pitch-delta.y*sensitivity,-deg_to_rad(85),deg_to_rad(85))
	if sim.mode == "campaign":
		if event.is_action_pressed("weapon_previous"): cycle_equipment(-1)
		if event.is_action_pressed("weapon_next"): cycle_equipment(1)
	else:
		if event.is_action_pressed("weapon_previous"): requested_weapon = posmod(requested_weapon-1,10)
		if event.is_action_pressed("weapon_next"): requested_weapon = (requested_weapon+1)%10
	if event.is_action_pressed("jump"): jump_pending = true
	if event.is_action_pressed("reload"): reload_pending = true
	for i in 10:
		if event.is_action_pressed("weapon_%d" % i):
			if sim.mode == "campaign":
				if i < 5 and preload("res://scripts/campaign_equipment.gd").slot_available(local_pawn(),i+1): requested_slot = i+1
			else: requested_weapon = i

func cycle_equipment(direction: int) -> void:
	for offset in range(1,6):
		var slot = posmod(requested_slot-1+direction*offset,5)+1
		if preload("res://scripts/campaign_equipment.gd").slot_available(local_pawn(),slot):
			requested_slot = slot
			return

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
	RenderingServer.render_loop_enabled = focused and not software_qa()

func quit_game() -> void:
	Data.save()
	Session.leave()
	get_tree().quit()

func load_map(id: String) -> void:
	if arena and arena.map_id == id: return
	if arena: arena.free()
	arena = Arena.new()
	arena.map_id = id
	add_child(arena)
	if camera: apply_graphics()

func select_map(id: String) -> void:
	if running or not Data.Maps.valid(id): return
	Data.settings.map_id = id
	Data.save()
	load_map(id)
	camera.position = arena.definition.camera
	camera.look_at(arena.definition.look_at)
	ui.show_home()
