extends SceneTree
## Renders the real native scene into an offscreen viewport hosted by an invisible parent window.
var viewport: SubViewport
var game
func _initialize() -> void:
	root.hide()
	root.unfocusable = true
	call_deferred("capture")

func frame() -> void:
	await process_frame
	RenderingServer.force_draw(false)

func shot(name: String) -> void:
	for i in 4: await frame()
	var image = viewport.get_texture().get_image()
	image.save_png("res://docs/screenshots/"+name+".png")
	print("Captured "+name+" "+str(image.get_size()))

func capture() -> void:
	AudioServer.set_bus_mute(0,true)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1440,900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	game.focused = true
	game.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute("res://docs/screenshots")
	await shot("home")
	game.ui.show_settings()
	await shot("settings")
	game.start_solo("practice")
	game.focused = true
	game.set_physics_process(false)
	game.sim.pawns.solo.pos = Vector2(0,0)
	game.camera.position = Vector3(0,1.7,0)
	game.yaw = 0
	game.pitch = 0
	await shot("practice")
	for i in range(10):
		game.sim.pawns.solo.weapon = i
		game.sim.pawns.solo.requested = i
		game.sim.pawns.solo.aim = false
		game.weapon.ads = 0
		await shot("weapon-%02d" % (i+1))
	game.sim.pawns.solo.weapon = 5
	game.sim.pawns.solo.aim = true
	game.weapon.ads = 1
	await shot("scope")
	game.sim.zombies.clear()
	var i = 0
	for kind in root.get_node("Data").enemies:
		game.sim.spawn(Vector2(-8+i*2.2,-8),kind)
		i += 1
	game.sim.pawns.solo.weapon = 0
	game.sim.pawns.solo.aim = false
	game.weapon.ads = 0
	await shot("enemies")
	game.sim.zombies.clear()
	for partner_index in 3:
		var id = "preview-"+str(partner_index)
		game.sim.add_pawn(id,["士兵","幸存者","工人"][partner_index],partner_index)
		game.sim.pawns[id].pos = Vector2(-3+partner_index*3,-6)
		game.sim.pawns[id].yaw = PI
		game.sim.pawns[id].appearance = [partner_index*2,partner_index,partner_index+3]
		game.sim.pawns[id].weapon = [0,6,9][partner_index]
	await shot("partners")
	game.ui.show_guide()
	await shot("guide")
	game.return_home()
	game.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	quit()
