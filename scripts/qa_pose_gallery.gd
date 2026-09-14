extends Node
## Explicit Web-only staged visual evidence, not a gameplay or network test.
var game
var last_request = ""
var pending_frames = 0
var ready_for_capture = false

func _ready() -> void:
	if not OS.has_feature("web") or not Data.automation or "--qa-poses" not in OS.get_cmdline_user_args():
		queue_free()
		return
	game.start_solo("survival")
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
		RenderingServer.render_loop_enabled = false
		JavaScriptBridge.eval("window.__poseRendered="+last_request,true)
		if not ready_for_capture:
			ready_for_capture = true
			JavaScriptBridge.eval("window.__poseReady=true",true)

func _process(_dt: float) -> void:
	var request = str(JavaScriptBridge.eval("JSON.stringify(window.__poseRequest || {})",true))
	if request != last_request:
		last_request = request
		var pose = JSON.parse_string(request)
		if not pose is Dictionary: return
		var p = game.local_pawn()
		p.weapon = clampi(int(pose.get("weapon",0)),0,9)
		p.requested = p.weapon
		p.crouch = 1.0 if pose.get("crouch",false) else 0.0
		p.aim = pose.get("aim",false)
		p.reloading = pose.has("reload")
		p.reload = Data.weapons[p.weapon].reloadDuration*(1-float(pose.get("reload",0.0)))
		p.fire_anim = Data.weapons[p.weapon].fireDuration*(1-float(pose.get("fire",1.0)))
		game.weapon.ads = 1.0 if p.aim else 0.0
		game.yaw = float(pose.get("yaw",0.0))
		game.pitch = float(pose.get("pitch",0.0))
		var partner = game.sim.pawns["pose-partner"]
		partner.crouch = 1.0 if pose.get("partner_crouch",false) else 0.0
		partner.weapon = p.weapon
		partner.yaw = float(pose.get("partner_yaw",PI))
		partner.pos = Vector2(-1.2,5.3) if pose.get("partner",false) else Vector2(-150,-30)
		JavaScriptBridge.eval("window.__poseApplied="+request,true)
		pending_frames = 2 if ready_for_capture else 6
		RenderingServer.render_loop_enabled = true
	game._process(1.0/60)
