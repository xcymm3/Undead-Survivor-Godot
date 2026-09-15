extends Node
## Explicit Web-only staged visual evidence, not a gameplay or network test.
var game
var last_request = ""
var pending_frames = 0
var ready_for_capture = false
var playback = false
var animation_clock = 0.0

func _ready() -> void:
	if not OS.has_feature("web") or not Data.automation or "--qa-poses" not in OS.get_cmdline_user_args():
		queue_free()
		return
	game.start_solo("campaign")
	game.sim.zombies.clear()
	game.local_pawn().pos = Vector2(0,9)
	game.local_pawn().height = 0.0
	Data.settings.resolution = 1.0
	Data.settings.frame_limit = 20
	Data.settings.pixelated = false
	game.apply_graphics()
	# A lightweight studio retains the actual meshes/lights, without rasterizing the map.
	# This keeps the normal render loop responsive on headless software WebGL.
	for node in game.arena.get_children():
		if node is Node3D and not node is Light3D: node.visible = false
	game.ui.visible = false
	var floor_mesh = MeshInstance3D.new()
	var floor_shape = BoxMesh.new()
	floor_shape.size = Vector3(100,.05,100)
	floor_mesh.mesh = floor_shape
	floor_mesh.position.y = -.04
	var floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color("717c77")
	floor_mesh.material_override = floor_material
	game.add_child(floor_mesh)
	game.set_physics_process(false)
	game.set_process(false)
	game.sim.roster.clear()
	game.sim.rest = 0
	game.sim.add_pawn("pose-partner","蹲姿观察",1)
	game.sim.pawns["pose-partner"].pos = Vector2(-1.2,6)
	game.sim.pawns["pose-partner"].yaw = PI
	game.sim.pawns["pose-partner"].appearance = [2,0,0]
	RenderingServer.render_loop_enabled = false
	RenderingServer.frame_post_draw.connect(presented)

func presented() -> void:
	if pending_frames <= 0: return
	pending_frames -= 1
	if pending_frames == 0:
		RenderingServer.render_loop_enabled = playback
		JavaScriptBridge.eval("window.__poseRendered="+last_request,true)
		if not ready_for_capture:
			ready_for_capture = true
			JavaScriptBridge.eval("window.__poseReady=true",true)

func _process(_dt: float) -> void:
	var request = str(JavaScriptBridge.eval("JSON.stringify(window.__poseRequest || {})",true))
	if request != last_request or playback:
		if request != last_request: animation_clock = 0.0
		last_request = request
		var pose = JSON.parse_string(request)
		if not pose is Dictionary: return
		playback = pose.get("playback",false)
		if playback:
			animation_clock += _dt
			var t = fmod(animation_clock,8.0)
			pose.weapon = 3
			pose.speed = 4.2 if t < 2.0 else 0.0
			pose.aim = t >= 2 and t < 3.8
			pose.time = animation_clock
			pose.stride = animation_clock*12.0
			if t >= 3 and t < 3.8: pose.fire = fmod(t-3,.45)/.36
			if t >= 4 and t < 5.6: pose.reload = (t-4)/1.6
			if t >= 6 and t < 6.55: pose.reload = (t-6)/1.6
			if t >= 6.55 and t < 6.95: pose.switch = .4-(t-6.55)
			if t >= 6.75 and t < 7.4: pose.weapon = 0
			if t >= 7.4 and t < 7.6: pose.switch = .2-(t-7.4)
		if pose.has("enemy"):
			var kind: String = pose.get("enemy_kind","normal")
			if not Data.enemies.has(kind): kind = "normal"
			if game.sim.zombies.is_empty() or game.sim.zombies[0].kind != kind:
				game.sim.zombies.clear()
				game.sim.spawn(Vector2(-1.0,.5 if kind == "giant" else 5.6),kind)
			var z: Dictionary = game.sim.zombies[0]
			z.id = 1
			z.born = 0.0
			z.gait = float(pose.get("time",0.0))*11.5
			z.heading = 0.0
			z.move_speed = 5.0 if pose.enemy == "run" else 0.0
			z.attack_time = float(pose.get("attack",0.0))
		else: game.sim.zombies.clear()
		var p = game.local_pawn()
		p.weapon = clampi(int(pose.get("weapon",0)),0,9)
		p.requested = p.weapon
		p.crouch = 1.0 if pose.get("crouch",false) else 0.0
		p.aim = pose.get("aim",false)
		p.hp = 0 if pose.get("dead",false) else 100
		p.switch = float(pose.get("switch",0.0))
		p.shots = int(pose.get("shots",0))
		p.reloading = pose.has("reload")
		p.reload = Data.weapons[p.weapon].reloadDuration*(1-float(pose.get("reload",0.0)))
		p.fire_anim = Data.weapons[p.weapon].fireDuration*(1-float(pose.get("fire",1.0)))
		if not playback: game.weapon.ads = 1.0 if p.aim else 0.0
		game.sim.elapsed = float(pose.get("time",0.0))
		var revolver = game.weapon.models[3]
		if not playback: revolver.reset_motion()
		revolver.preview_speed = float(pose.get("speed",0.0))
		revolver.motion = revolver.preview_speed
		revolver.preview_stride = float(pose.get("stride",0.0))
		game.yaw = float(pose.get("yaw",0.0))
		game.pitch = float(pose.get("pitch",0.0))
		var partner = game.sim.pawns["pose-partner"]
		partner.crouch = 1.0 if pose.get("partner_crouch",false) else 0.0
		partner.weapon = p.weapon
		partner.yaw = float(pose.get("partner_yaw",PI))
		partner.pos = Vector2(-1.2,5.3) if pose.get("partner",false) else Vector2(-150,-30)
		JavaScriptBridge.eval("window.__poseApplied="+request,true)
		pending_frames = 8
		RenderingServer.render_loop_enabled = true
	game._process(1.0/60)
	var rig = game.weapon.models[3]
	JavaScriptBridge.eval("window.__revolverPose="+JSON.stringify({"state":rig.state_name,"open":rig.cylinder_open,"visible":rig.is_visible_in_tree(),"loader":rig.loader.is_visible_in_tree()}),true)

	JavaScriptBridge.eval("window.__enemyPose="+JSON.stringify({"count":game.sim.zombies.size(),"visible":game.enemies.visible_count(game.sim.zombies[0].kind) if not game.sim.zombies.is_empty() else 0,"focused":game.focused,"gait":game.sim.zombies[0].gait if not game.sim.zombies.is_empty() else 0,"attack":game.sim.zombies[0].attack_time if not game.sim.zombies.is_empty() else 0}),true)
