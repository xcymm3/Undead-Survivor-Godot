extends Node
## Opt-in software-Web overview used for repeatable whole-map visual review.
var game

func _ready() -> void:
	if not Data.automation or not OS.has_feature("web") or "--qa-defense-overview" not in OS.get_cmdline_user_args():
		queue_free()
		return
	call_deferred("stage")

func stage() -> void:
	Data.settings.map_id = "graypine_defense"
	game.load_map("graypine_defense")
	game.running = false
	game.ui.root.visible = false
	game.weapon.visible = false
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size = 110
	game.camera.near = .1
	game.camera.far = 260
	# Side-rear elevation keeps the whole route readable while exposing the
	# three-metre rise from bridge deck through the ramp onto the plateau.
	game.camera.position = Vector3(86,68,92)
	game.camera.look_at(Vector3(0,1,-5),Vector3.UP)
	RenderingServer.render_loop_enabled = true
	for i in 5: await get_tree().process_frame
	JavaScriptBridge.eval("window.__defenseOverviewReady=true",true)
