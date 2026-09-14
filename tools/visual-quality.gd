extends SceneTree
## Deliberately staged GPU evidence, complementary to real-input browser playthrough.
var viewport: SubViewport
var game
var shots: Array = []
const OUT = "res://artifacts/visual/"

func _initialize() -> void:
	root.hide()
	root.unfocusable = true
	call_deferred("capture")

func shot(id: String) -> void:
	for i in 12:
		game._process(1.0/60)
		game.ui.tick(1.0/60)
		await process_frame
		RenderingServer.force_draw(false)
	var picture = viewport.get_texture().get_image()
	picture.save_png(OUT+id+".png")
	shots.append({"id":id,"size":str(viewport.size),"map":game.arena.map_id})
	print("VISUAL "+id)

func start_map(id: String) -> void:
	game.return_home()
	game.select_map(id)
	game.start_solo("survival")
	game.set_process(false)
	game.set_physics_process(false)
	game.focused = true
	await physics_frame

func view_at(point: Vector2, yaw: float, pitch := 0.0) -> void:
	var pawn: Dictionary = game.local_pawn()
	pawn.pos = point
	pawn.height = root.get_node("Data").enemy_ground_height(point,game.arena.map_id)
	pawn.yaw = yaw
	pawn.pitch = pitch
	game.yaw = yaw
	game.pitch = pitch

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1440,900)
	# Match the project's canvas_items logical canvas, rather than shrinking controls.
	viewport.size_2d_override = Vector2i(1440,900)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	root.add_child(viewport)
	game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.focused = true
	for id in ["outpost","dust"]:
		game.select_map(id)
		for size in [Vector2i(1440,900),Vector2i(960,540),Vector2i(1920,1080)]:
			viewport.size = size
			await shot(id+"-home-"+str(size.x))
	viewport.size = Vector2i(1440,900)
	game.ui.show_settings()
	await shot("settings")
	for scroll in game.ui.menu.find_children("*","ScrollContainer",true,false): scroll.scroll_vertical = 10000
	await shot("settings-bottom")
	game.ui.show_guide()
	await shot("guide")
	game.ui.show_multiplayer()
	await shot("multiplayer")
	game.ui.show_scores()
	await shot("scores")
	await start_map("outpost")
	for sample in [["spawn",Vector2(0,9),0.0],["river",Vector2(0,-17),PI/2],["bridge",Vector2(-10,-13),0.0],["north",Vector2(1,-36),PI]]:
		view_at(sample[1],sample[2])
		await shot("outpost-"+sample[0])
	view_at(Vector2(0,3),0)
	for i in 10:
		var pawn: Dictionary = game.local_pawn()
		pawn.weapon = i
		pawn.requested = i
		pawn.aim = false
		game.weapon.ads = 0
		await shot("weapon-%02d-hip" % i)
		pawn.aim = true
		game.weapon.ads = 1
		await shot("weapon-%02d-aim" % i)
	game.local_pawn().weapon = 0
	game.local_pawn().aim = false
	game.weapon.ads = 0
	game.local_pawn().reloading = true
	game.local_pawn().reload = root.get_node("Data").weapons[0].reloadDuration*.5
	await shot("rifle-reload")
	game.local_pawn().reloading = false
	game.local_pawn().fire_anim = root.get_node("Data").weapons[0].fireDuration*.85
	await shot("rifle-fire")
	game.local_pawn().weapon = 6
	for phase in [.22,.52,.82]:
		game.local_pawn().fire_anim = root.get_node("Data").weapons[6].fireDuration*(1-phase)
		await shot("axe-swing-"+str(int(phase*100)))
	game.local_pawn().weapon = 0
	game.local_pawn().fire_anim = 0
	var n = 0
	for kind in root.get_node("Data").enemies:
		game.sim.spawn(Vector2(-7+n*2,-7),kind)
		n += 1
	await shot("enemy-roster")
	for i in 3:
		game.sim.add_pawn("visual-"+str(i),"队友昵称较长的幸存者"+str(i),i+1)
		game.sim.pawns["visual-"+str(i)].pos = Vector2(-3+i*3,-2)
	await shot("party-hud")
	viewport.size = Vector2i(960,540)
	await shot("party-hud-960")
	viewport.size = Vector2i(1440,900)
	game.pause_game()
	await shot("pause")
	game.resume_game()
	game.sim.failed = true
	game.local_pawn().hp = 0
	game.finish_run()
	game.ui.show_result()
	await shot("result")
	await start_map("dust")
	var layout = load("res://scripts/dust_layout.gd")
	for sample in [["ct",704,301,PI/2],["b",568,280,-PI/2],["a",442,70,PI],["t",126,198,0.0],["platform",170,141,PI],["tunnel",350,350,0.0],["tunnel-north",380,209,PI],["west",269,330,-PI/2]]:
		view_at(layout.point(sample[1],sample[2]),sample[3])
		await shot("dust-"+sample[0])
	var file = FileAccess.open(OUT+"manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"shots":shots},"\t"))
	game.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	quit()
