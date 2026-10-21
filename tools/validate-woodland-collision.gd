extends RefCounted
const Body = preload("res://scripts/player_body.gd")

static func validate(game, check: Callable) -> void:
	game.start_solo("defense",817)
	await game.get_tree().physics_frame
	var arena = game.arena
	var world = arena.scenery
	var checked = 0
	for item in world.get_children():
		if not item.has_meta("forest_obstacle"): continue
		var rect: Dictionary = item.get_meta("forest_obstacle")
		check.call(arena.obstacles.has(rect),"Forest collision has an authoritative navigation footprint: "+str(item.name))
		var shape = item.get_child(0).shape
		var local_center = Vector3.ZERO
		if shape is ConvexPolygonShape3D:
			for point in shape.points: local_center += point
			local_center /= shape.points.size()
		if item.has_meta("forest_render_vertices"):
			var vertices: PackedVector3Array = item.get_meta("forest_render_vertices")
			var pose: Transform3D = item.get_meta("forest_render_pose")
			var same = vertices.size() == shape.points.size()
			for index in vertices.size():
				same = same and (pose*vertices[index]).is_equal_approx(item.global_transform*shape.points[index])
			check.call(same,"Rotated leaf render and collision vertices agree exactly: "+str(item.name))
		var center: Vector3 = item.global_transform*local_center
		check.call(not arena.clear(Vector2(center.x,center.z),Vector2(center.x,center.z)),"Visible forest volume is not a walkable enemy cell: "+str(item.name))
		var hit: Dictionary = arena.surface_hit(center+Vector3(-8,0,0),center)
		check.call(not hit.is_empty(),"Forest shape also blocks physical rays through its interior: "+str(item.name))
		checked += 1
	check.call(checked >= 600,"Every tree, branch, crown and shrub receives shared cover")
	check.call(world.get_node("FarForestLeaves").multimesh.mesh is ArrayMesh and world.get_node("FarForestUndergrowth").multimesh.mesh is ArrayMesh,"Leaf crowns and shrubs use irregular polygon meshes instead of spheres")
	var room = world.shop.get_node("Bedroom")
	for title in ["WritingDeskCore","StoolCore","HangingWorkCoat","WallShelf","Mattress","BedsideLampCore"]:
		var item = room.get_node(title)
		check.call(item is StaticBody3D and item.get_child(1) is CollisionShape3D,"Large bedroom prop has a simplified collider: "+title)
	for title in ["Notebook","PaperSheet","BedsideBook","DeskMug"]:
		check.call(not room.get_node(title) is StaticBody3D,"Small bedroom decoration remains non-solid: "+title)
	var body = Body.new()
	arena.add_child(body)
	await game.get_tree().physics_frame
	var desk = room.get_node("WritingDeskCore")
	body.position = desk.global_position+Vector3(0,-.49,-2.0)
	body.velocity = Vector3.ZERO
	for tick in 90: body.advance(Vector2(0,4.2),1.0/60)
	check.call(body.position.z < desk.global_position.z-.8,"Actual player capsule cannot walk through the space below the desk")
	body.free()
