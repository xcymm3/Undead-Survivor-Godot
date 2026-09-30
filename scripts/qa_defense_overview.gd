extends Node
## Opt-in software-Web overview used for repeatable whole-map visual review.
var game
var damage_preview := false

func _ready() -> void:
	var args = Array(OS.get_cmdline_user_args())
	if not Data.automation or not OS.has_feature("web") or not args.any(func(arg): return arg in ["--qa-defense-overview","--qa-defense-safe-zone","--qa-defense-structures-intact","--qa-defense-structures-damaged"]):
		queue_free()
		return
	call_deferred("stage")

func stage() -> void:
	Data.settings.map_id = "graypine_defense"
	if "--qa-defense-structures-intact" in OS.get_cmdline_user_args() or "--qa-defense-structures-damaged" in OS.get_cmdline_user_args():
		for id in ["turret_left","turret_right","bridge_gate"]: Progress.store.data.buildings[id].owned = true
	game.start_solo("defense")
	await get_tree().process_frame
	game.running = false
	game.ui.root.visible = false
	game.weapon.visible = false
	# Static review uses full internal resolution so wall labels stay readable.
	Data.settings.resolution = 1.0
	game.get_viewport().scaling_3d_scale = 1.0
	var safe_zone = "--qa-defense-safe-zone" in OS.get_cmdline_user_args()
	var structure_preview = "--qa-defense-structures-intact" in OS.get_cmdline_user_args() or "--qa-defense-structures-damaged" in OS.get_cmdline_user_args()
	game.camera.projection = Camera3D.PROJECTION_PERSPECTIVE if safe_zone else Camera3D.PROJECTION_ORTHOGONAL
	game.camera.fov = 60 if safe_zone else 56
	game.camera.size = 98
	game.camera.near = .1
	game.camera.far = 260
	if structure_preview:
		game.camera.size = 19
		game.camera.position = Vector3(12,10,-23)
		game.camera.look_at(Vector3(0,4.4,-7.5),Vector3.UP)
		if "--qa-turret-close" in OS.get_cmdline_user_args():
			game.camera.size = 5.4
			game.camera.position = Vector3(9.3,7.2,-10)
			game.camera.look_at(Vector3(6.3,4.45,-6),Vector3.UP)
		damage_preview = "--qa-defense-structures-damaged" in OS.get_cmdline_user_args()
		if damage_preview:
			game.sim.defense_director.structures.damage("bridge_gate",500)
			game.sim.defense_director.structures.damage("turret_left",100)
			game.sim.defense_director.structures.damage("turret_right",100)
		game.sim.defense_director.sync_world()
	elif safe_zone:
		# Front oblique framing includes the safe-zone floor and both weapon rows.
		var placement = Data.Maps.Defense.armory_transform()
		game.camera.position = placement*Vector3(0,5.0,53.2)
		game.camera.look_at(placement*Vector3(0,5.35,67.2),Vector3.UP)
	else:
		# Side-rear elevation keeps the whole route readable while exposing the
		# three-metre rise from bridge deck through the ramp onto the plateau.
		game.camera.position = Vector3(-60,80,58)
		game.camera.look_at(Vector3(0,1,-16),Vector3.UP)
	RenderingServer.render_loop_enabled = true
	for i in 5: await get_tree().process_frame
	JavaScriptBridge.eval("window.__defenseStructuresReady=true" if structure_preview else "window.__defenseSafeZoneReady=true" if safe_zone else "window.__defenseOverviewReady=true",true)

func _process(dt: float) -> void:
	if not damage_preview or not is_instance_valid(game): return
	game.sim.defense.prop_clock += dt
	game.sim.defense_director.sync_world()
