extends Node3D
## Render original meshes with native ArrayMesh/MultiMesh, using the source collision footprints.
var obstacles: Array = []
var water_obstacles: Array[Rect2] = []
var collision_buckets: Dictionary = {}
var grid = AStarGrid2D.new()
var sun: DirectionalLight3D
const CELL = .65

func _ready() -> void:
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/world.json"))
	obstacles = world.obstacles.filter(func(o): return o.minX < 22 and o.maxX > -22 and o.minZ < 14 and o.maxZ > -48)
	var meshes = {}
	var materials = {}
	for id in world.materials:
		var source: Dictionary = world.materials[id]
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(source.color[0],source.color[1],source.color[2]).linear_to_srgb()
		material.roughness = source.roughness
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if source.unshaded: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		materials[id] = material
	for id in world.geometries:
		var source: Dictionary = world.geometries[id]
		var vertices = PackedVector3Array()
		var normals = PackedVector3Array()
		for i in range(0, source.position.size(), 3):
			vertices.append(Vector3(source.position[i],source.position[i+1],source.position[i+2]))
			normals.append(Vector3(source.normal[i],source.normal[i+1],source.normal[i+2]))
		var indices = PackedInt32Array(source.index)
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		# glTF/Three counterclockwise faces become Godot clockwise faces.
		for i in range(0, indices.size(), 3):
			var swap = indices[i+1]
			indices[i+1] = indices[i+2]
			indices[i+2] = swap
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		meshes[id] = mesh
	var faces = PackedVector3Array()
	for source in world.meshes:
		var instance = MultiMeshInstance3D.new()
		var multi = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = meshes[source.geometry]
		multi.instance_count = source.transforms.size()
		for i in source.transforms.size():
			var transform = Data.from_matrix(source.transforms[i])
			multi.set_instance_transform(i, transform)
			if source.colors.size() > i:
				var c: Array = source.colors[i]
				multi.set_instance_color(i, Color(c[0],c[1],c[2]).linear_to_srgb())
			else: multi.set_instance_color(i, Color.WHITE)
			# Do not make sky, grass or distant forest collision geometry.
			if source.transforms.size() < 500 and absf(transform.origin.x) < 24 and transform.origin.z > -60 and transform.origin.y < 12:
				for vertex in multi.mesh.get_faces(): faces.append(transform * vertex)
		instance.multimesh = multi
		instance.material_override = materials[source.material]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if source.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	var body = StaticBody3D.new()
	var collider = CollisionShape3D.new()
	var shape = ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	for sign in world.signs:
		var label = Label3D.new()
		label.text = sign.text + "\n" + sign.subtitle
		label.font_size = 42
		label.pixel_size = sign.width / 640.0
		label.modulate = Color("e4dfbd")
		label.outline_size = 5
		label.outline_modulate = Color("303e38")
		label.transform = Data.from_matrix(sign.matrix)
		add_child(label)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("b1c7bd")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e0ecde")
	environment.environment.ambient_light_energy = .35
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment.fog_enabled = true
	environment.environment.fog_light_color = Color("b1c7bd")
	environment.environment.fog_density = .003
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("ffe0b3")
	sun.light_energy = .8
	sun.shadow_enabled = Data.settings.quality > 0
	sun.directional_shadow_max_distance = 65
	add_child(sun)
	build_grid()

func build_grid() -> void:
	# Same conservative quarter-metre river strips and .95 m navigation radius as the source.
	var xs: Array[float] = []
	for i in range(177): xs.append(-22 + i * .25)
	for x in [-12.6, -7.4, 7.4, 12.6]: xs.append(x)
	xs.sort()
	for i in range(1, xs.size()):
		var a = xs[i-1]
		var b = xs[i]
		if is_equal_approx(a, b): continue
		if (a >= -12.6 and b <= -7.4) or (a >= 7.4 and b <= 12.6): continue
		var low = minf(Data.river_center(a), Data.river_center(b)) - 1.25
		var high = maxf(Data.river_center(a), Data.river_center(b)) + 1.25
		water_obstacles.append(Rect2(a-.95, low-.95, b-a+1.9, high-low+1.9))
	for o in obstacles:
		index_obstacle(Rect2(o.minX-.95,o.minZ-.95,o.maxX-o.minX+1.9,o.maxZ-o.minZ+1.9),false)
	for rect in water_obstacles: index_obstacle(rect,true)
	grid.region = Rect2i(0,0,69,97)
	grid.cell_size = Vector2(CELL,CELL)
	grid.offset = Vector2(-22,-48)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(97):
		for x in range(69):
			var p = Vector2(-22+x*CELL, -48+y*CELL)
			grid.set_point_solid(Vector2i(x,y), not clear(p,p))

func segment_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	var near = 0.0
	var far = 1.0
	var delta = b-a
	for axis in range(2):
		if absf(delta[axis]) < .000001:
			if a[axis] < rect.position[axis] or a[axis] > rect.end[axis]: return false
		else:
			var t1 = (rect.position[axis]-a[axis])/delta[axis]
			var t2 = (rect.end[axis]-a[axis])/delta[axis]
			near = maxf(near,minf(t1,t2))
			far = minf(far,maxf(t1,t2))
			if near > far: return false
	return near <= far

func index_obstacle(rect: Rect2, is_water: bool) -> void:
	var obstacle = {"rect":rect,"water":is_water}
	for y in range(floori(rect.position.y/4),floori(rect.end.y/4)+1):
		for x in range(floori(rect.position.x/4),floori(rect.end.x/4)+1):
			var key = Vector2i(x,y)
			if not collision_buckets.has(key): collision_buckets[key] = []
			collision_buckets[key].append(obstacle)

func clear(a: Vector2, b: Vector2, allow_water := false) -> bool:
	if minf(a.x,b.x) < -21.05 or maxf(a.x,b.x) > 21.05 or minf(a.y,b.y) < -47.05 or maxf(a.y,b.y) > 13.05: return false
	for y in range(floori(minf(a.y,b.y)/4),floori(maxf(a.y,b.y)/4)+1):
		for x in range(floori(minf(a.x,b.x)/4),floori(maxf(a.x,b.x)/4)+1):
			for obstacle in collision_buckets.get(Vector2i(x,y),[]):
				if allow_water and obstacle.water: continue
				if segment_rect(a,b,obstacle.rect): return false
	return true

func nearest_cell(p: Vector2) -> Vector2i:
	var base = Vector2i(roundi((p.x+22)/CELL), roundi((p.y+48)/CELL))
	if grid.is_in_boundsv(base) and not grid.is_point_solid(base) and clear(p,grid.get_point_position(base),Data.water(p)): return base
	var best = Vector2i(-1,-1)
	var distance = INF
	for y in range(-5,6):
		for x in range(-5,6):
			var candidate = base+Vector2i(x,y)
			if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate): continue
			var point = grid.get_point_position(candidate)
			var d = p.distance_squared_to(point)
			if d < distance and clear(p,point,Data.water(p)):
				distance = d
				best = candidate
	return best

func path_to(a: Vector2, b: Vector2) -> PackedVector2Array:
	if clear(a,b): return PackedVector2Array([b])
	var start = nearest_cell(a)
	var end = nearest_cell(b)
	if start.x < 0 or end.x < 0: return PackedVector2Array()
	return grid.get_point_path(start,end)

func surface_hit(origin: Vector3, end: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,1))
