extends RefCounted
const Layout = preload("res://scripts/defense_layout.gd")

static func validate(game, check: Callable) -> void:
	var batch = game.arena.static_scenery
	check.call(batch.stats.original_meshes > 200 and batch.stats.batch_draws < batch.stats.original_meshes*.6,"Static shop meshes collapse into fewer spatial/material batches")
	check.call(batch.stats.multimeshes > 0 and batch.stats.merged_surfaces > 0,"Repeated boxes use MultiMesh and other static decorations use merged surfaces")
	for preset in range(5):
		game.get_node("/root/Data").set_preset(preset)
		check.call(game.arena.find_children("*","Light3D",true,false).all(func(light): return not light.shadow_enabled),"All quality presets keep every light shadow disabled: "+str(preset))
	var transform: Transform3D = game.camera.transform
	for sample in [
		[Vector3(20,4.7,Layout.SHOP_DOOR_Z),Vector3(13,4.7,Layout.SHOP_DOOR_Z),"shop",true],
		[Vector3(20,4.7,Layout.SHOP_DOOR_Z),Vector3(30,4.7,Layout.SHOP_DOOR_Z),"shop",false],
		[Vector3(-20,4.7,Layout.SHOP_DOOR_Z),Vector3(0,4.7,Layout.SHOP_DOOR_Z),"shop",false],
		[Vector3(-6.5,4.7,Layout.SHOP_AREA.end.y-3),Vector3(-6.5,4.7,Layout.SHOP_AREA.end.y),"shop",false],
		[Vector3(-6.5,4.7,Layout.SHOP_AREA.end.y-3),Vector3(-6.5,4.7,Layout.SHOP_PARTITION_Z),"shop",true],
		[Vector3(0,4.7,Layout.SHOP_FRONT_Z+5),Vector3(0,4.7,Layout.SHOP_FRONT_Z),"bedroom",false]]:
		game.camera.position = sample[0]
		game.camera.look_at(sample[1])
		game.camera.force_update_transform()
		batch.update_visibility()
		check.call(batch.visibility_state[sample[2]] == sample[3],"Regional portal visibility: "+str(sample))
	check.call(game.arena.scenery.shop.get_node("ShopRoof") is StaticBody3D and game.arena.scenery.shop.get_node("Bedroom/Mattress").get_child(1) is CollisionShape3D,"Batching retains named roof and bedroom physics shapes")
	check.call(batch.exterior_visuals.size() > 100,"Static outdoor geometry participates in regional visibility without taking ownership of moving props")
	game.camera.position = Vector3(-6.5,4.7,Layout.SHOP_AREA.end.y-3)
	game.camera.look_at(Vector3(-6.5,4.7,Layout.SHOP_AREA.end.y))
	batch.update_visibility()
	check.call(batch.exterior_visuals.all(func(view): return not view.visible),"Bedroom views behind solid walls hide outdoor render geometry")
	game.camera.transform = transform
	batch.update_visibility()
	var layer = game.first_person_layer
	layer.sync_view()
	var updates: int = layer.configuration_updates
	for index in 20: layer.sync_view()
	check.call(layer.configuration_updates == updates and not layer.is_processing(),"Stable first-person frames reuse the target configuration and have no duplicate process callback")
	var viewport = game.get_viewport()
	var original = viewport.msaa_3d
	viewport.msaa_3d = Viewport.MSAA_DISABLED if original != Viewport.MSAA_DISABLED else Viewport.MSAA_2X
	layer.sync_view()
	check.call(layer.configuration_updates == updates+1 and layer.viewport.msaa_3d == viewport.msaa_3d,"A real graphics change refreshes first-person configuration once")
	viewport.msaa_3d = original
	layer.sync_view()
