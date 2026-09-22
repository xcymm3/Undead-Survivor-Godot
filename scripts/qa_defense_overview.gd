extends Node
## Opt-in software-Web overview used for repeatable whole-map visual review.
var game

func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if not Data.automation or not OS.has_feature("web") or ("--qa-defense-overview" not in args and "--qa-defense-safe-zone" not in args):
		queue_free()
		return
	call_deferred("stage")

func stage() -> void:
	Data.settings.map_id = "graypine_defense"
	game.start_solo("defense")
	await get_tree().process_frame
	game.running = false
	game.ui.root.visible = false
	game.weapon.visible = false
	var safe_zone = "--qa-defense-safe-zone" in OS.get_cmdline_user_args()
	game.camera.projection = Camera3D.PROJECTION_PERSPECTIVE if safe_zone else Camera3D.PROJECTION_ORTHOGONAL
	game.camera.fov = 60 if safe_zone else 56
	game.camera.size = 100
	game.camera.near = .1
	game.camera.far = 260
	if safe_zone:
		# Front oblique framing includes the safe-zone floor and both weapon rows.
		game.camera.position = Vector3(0,5.0,53.2)
		game.camera.look_at(Vector3(0,5.35,67.2),Vector3.UP)
	else:
		# Side-rear elevation keeps the whole route readable while exposing the
		# three-metre rise from bridge deck through the ramp onto the plateau.
		game.camera.position = Vector3(86,68,92)
		game.camera.look_at(Vector3(0,1,-5),Vector3.UP)
	RenderingServer.render_loop_enabled = true
	for i in 5: await get_tree().process_frame
	JavaScriptBridge.eval("window.__defenseSafeZoneReady=true" if safe_zone else "window.__defenseOverviewReady=true",true)
