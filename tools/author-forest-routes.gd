extends SceneTree
## Development-only authoring: bake collision-checked routes, never run in gameplay.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena = load("res://scripts/arena.gd").new()
	root.add_child(arena)
	await physics_frame
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/forest_routes.json"))
	var origins: Array[Vector2] = []
	for item in previous.routes: origins.append(Vector2(item.points[0][0],item.points[0][1]))
	origins.sort_custom(func(a,b): return a.x < b.x)
	var authored: Array = []
	for index in origins.size():
		var group = 0 if index < 7 else 1 if index < 13 else 2
		var local_index = index if group == 0 else index-7 if group == 1 else index-13
		var variation = -.45 if local_index % 2 == 0 else .45
		var exit_x = [-23.0,0.0,23.0][group]+variation
		var lane = [-1.95,0.0,1.95][group]+variation
		var origin = origins[index]
		if not arena.clear(origin,origin):
			var cell = arena.nearest_cell(origin)
			if cell.x < 0:
				push_error("Blocked forest origin: "+str(origin)); quit(1); return
			origin = arena.grid.get_point_position(cell)
		var points = PackedVector2Array([origin])
		for destination in [Vector2(exit_x,-92),Vector2(exit_x,-80),Vector2(lane*2,-69),Vector2(lane,-60),Vector2(lane,-56)]:
			var current: Vector2 = points[-1]
			var path = arena.path_to(current,destination)
			if path.is_empty() or not path[-1].is_equal_approx(destination):
				push_error("Unreachable authored waypoint: "+str(destination)); quit(1); return
			while not path.is_empty():
				var last = path.size()-1
				while last >= 0 and not arena.clear(current,path[last]): last -= 1
				if last < 0:
					push_error("Unsafe authored segment"); quit(1); return
				current = path[last]
				points.append(current)
				path = path.slice(last+1)
		var serialized: Array = []
		for point in points: serialized.append([snappedf(point.x,.0001),snappedf(point.y,.0001)])
		authored.append({"id":"forest_%02d" % index,"exit":group,"points":serialized})
	var file = FileAccess.open("res://assets/data/forest_routes.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"exits":[[-23,-80],[0,-80],[23,-80]],"handoff_z":-56,"routes":authored},"  ")+"\n")
	print("AUTHORED: twenty validated routes, three exits, six bridge lanes")
	quit(0)
