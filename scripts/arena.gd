extends Node3D
## Crystal defense terrain supplies both physical cover and enemy navigation.
const Maps = preload("res://scripts/map_catalog.gd")
var map_id = "graypine_defense"
var definition: Dictionary
var bounds: Rect2
var walk_regions: Array[PackedVector2Array] = []
var obstacles: Array = []
var collision_buckets: Dictionary = {}
var structure_state: Array = []
var grid = AStarGrid2D.new()
var scenery: Node3D
var sun: DirectionalLight3D
var enemy_grids: Dictionary = {}
var navigation_revision = 0
var layout_signature = ""
var shared_routes: Dictionary = {}
var route_cache_hits = 0
var route_cache_misses = 0
const CELL = .65

func _ready() -> void:
	definition = Maps.definition(map_id)
	bounds = definition.bounds
	scenery = load(definition.scene).instantiate()
	add_child(scenery)
	obstacles = scenery.get_meta("navigation_obstacles")
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = definition.sky
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e0ecde")
	environment.environment.ambient_light_energy = .35
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment.fog_enabled = true
	environment.environment.fog_light_color = definition.fog
	environment.environment.fog_density = .018
	environment.environment.ambient_light_color = Color("b9d5c5")
	environment.environment.ambient_light_energy = .58
	environment.environment.fog_density = .0045
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-35,0)
	sun.light_color = definition.sun
	sun.light_energy = .8
	sun.light_energy = 1.15
	sun.rotation_degrees = Vector3(-48,-18,0)
	sun.shadow_enabled = Data.settings.quality > 0
	sun.directional_shadow_max_distance = 65
	add_child(sun)
	build_grid()

func build_grid() -> void:
	collision_buckets.clear()
	# Solid scenery and the chasm define enemy navigation.
	for o in obstacles:
		index_obstacle(Rect2(o.minX-.95,o.minZ-.95,o.maxX-o.minX+1.9,o.maxZ-o.minZ+1.9),false)
	grid.region = Rect2i(Vector2i.ZERO,Vector2i(ceil(bounds.size.x/CELL)+1,ceil(bounds.size.y/CELL)+1))
	grid.cell_size = Vector2(CELL,CELL)
	grid.offset = bounds.position
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var p = bounds.position+Vector2(x,y)*CELL
			grid.set_point_solid(Vector2i(x,y), not clear(p,p))

func segment_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	var near = 0.0
	var far = 1.0
	var delta = b-a
	for axis in range(2):
		if delta[axis] == 0.0:
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
	if not bounds.grow(-.95).has_point(a) or not bounds.grow(-.95).has_point(b): return false
	for item in structure_state:
		if item.hp > 0 and item.kind != "mine" and segment_rect(a,b,preload("res://scripts/defense_structures.gd").bounds(item).grow(.95)): return false
	for y in range(floori(minf(a.y,b.y)/4),floori(maxf(a.y,b.y)/4)+1):
		for x in range(floori(minf(a.x,b.x)/4),floori(maxf(a.x,b.x)/4)+1):
			for obstacle in collision_buckets.get(Vector2i(x,y),[]):
				if allow_water and obstacle.water: continue
				if segment_rect(a,b,obstacle.rect): return false
	return true

func endpoint_link(a: Vector2, b: Vector2) -> bool:
	if clear(a,b): return true
	# Players can stand inside the enemy clearance margin. Project only
	# across free physical space, never through a wall or a closed door.
	if clear(a,a): return false
	if not bounds.has_point(a) or not bounds.has_point(b): return false
	for obstacle in obstacles:
		if segment_rect(a,b,Rect2(obstacle.minX,obstacle.minZ,obstacle.maxX-obstacle.minX,obstacle.maxZ-obstacle.minZ)): return false
	return true

func nearest_cell(p: Vector2) -> Vector2i:
	var base = Vector2i(((p-bounds.position)/CELL).round())
	if grid.is_in_boundsv(base) and not grid.is_point_solid(base) and endpoint_link(p,grid.get_point_position(base)): return base
	var best = Vector2i(-1,-1)
	var distance = INF
	for y in range(-5,6):
		for x in range(-5,6):
			var candidate = base+Vector2i(x,y)
			if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate): continue
			var point = grid.get_point_position(candidate)
			var d = p.distance_squared_to(point)
			if d < distance and endpoint_link(p,point):
				distance = d
				best = candidate
	return best

func path_to(a: Vector2, b: Vector2) -> PackedVector2Array:
	if clear(a,b): return PackedVector2Array([b])
	var start = nearest_cell(a)
	var end = nearest_cell(b)
	if start.x < 0 or end.x < 0: return PackedVector2Array()
	return grid.get_point_path(start,end)

func surface_hit(origin: Vector3, end: Vector3, ignore_structure := "") -> Dictionary:
	var query = PhysicsRayQueryParameters3D.create(origin,end,1)
	if not ignore_structure.is_empty() and scenery.structure_view:
		query.exclude = scenery.structure_view.collision_rids(ignore_structure)
	return get_world_3d().direct_space_state.intersect_ray(query)


func sync_defense(state: Dictionary) -> void:
	structure_state = state.get("structures",[])
	refresh_navigation_revision()
	scenery.sync(state)

func refresh_navigation_revision() -> void:
	var signature = ""
	for item in structure_state:
		if item.hp > 0 and item.kind != "mine": signature += item.id+";"
	if signature != layout_signature:
		layout_signature = signature
		navigation_revision += 1
		shared_routes.clear()

func enemy_grid(kind: String) -> AStarGrid2D:
	var profile = preload("res://scripts/enemy_body.gd").profile(kind)
	var key: String = profile.key
	# Also supports deliberate authority fixtures that directly alter HP.
	refresh_navigation_revision()
	var signature = layout_signature
	if not enemy_grids.has(key):
		var navigation = AStarGrid2D.new()
		navigation.region = grid.region
		navigation.cell_size = grid.cell_size
		navigation.offset = grid.offset
		navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		navigation.update()
		var shape = CylinderShape3D.new()
		shape.radius = profile.clearance
		shape.height = (.72 if kind == "crawler" else profile.height)-.24
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.collision_mask = 1
		var excluded: Array[RID] = []
		for item in structure_state:
			excluded.append_array(scenery.structure_view.collision_rids(item.id))
		query.exclude = excluded
		var static_solid = PackedByteArray()
		static_solid.resize(navigation.region.size.x*navigation.region.size.y)
		for y in navigation.region.size.y:
			for x in navigation.region.size.x:
				var p = navigation.get_point_position(Vector2i(x,y))
				var solid = not bounds.grow(-profile.clearance).has_point(p)
				# Authored void boundaries and actual physical scenery share the
				# same per-body clearance. Rails, cliff faces and posts are queried
				# even when their old art metadata omitted navigation obstacles.
				for obstacle in obstacles:
					var rect = Rect2(obstacle.minX,obstacle.minZ,obstacle.maxX-obstacle.minX,obstacle.maxZ-obstacle.minZ).grow(profile.clearance)
					if rect.has_point(p):
						solid = true
						break
				if not solid:
					query.transform = Transform3D(Basis.IDENTITY,Vector3(p.x,Data.enemy_ground_height(p,map_id)+.24+shape.height/2,p.y))
					solid = not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
				static_solid[y*navigation.region.size.x+x] = int(solid)
		enemy_grids[key] = {"grid":navigation,"solid":static_solid,"signature":"!"}
	var cached: Dictionary = enemy_grids[key]
	var result: AStarGrid2D = cached.grid
	if cached.signature != signature:
		for y in result.region.size.y:
			for x in result.region.size.x:
				var cell = Vector2i(x,y)
				var solid = cached.solid[y*result.region.size.x+x] != 0
				if not solid:
					for item in structure_state:
						if item.hp > 0 and item.kind != "mine" and preload("res://scripts/defense_structures.gd").bounds(item).grow(profile.clearance).has_point(result.get_point_position(cell)):
							solid = true
							break
				result.set_point_solid(cell,solid)
		cached.signature = signature
	return result

func enemy_cell(navigation: AStarGrid2D, p: Vector2) -> Vector2i:
	var base = Vector2i(((p-bounds.position)/CELL).round())
	var best = Vector2i(-1,-1)
	var distance = INF
	for y in range(-5,6):
		for x in range(-5,6):
			var cell = base+Vector2i(x,y)
			if not navigation.is_in_boundsv(cell) or navigation.is_point_solid(cell): continue
			var point = navigation.get_point_position(cell)
			var d = p.distance_squared_to(point)
			if d >= distance: continue
			# Endpoint projection may recover a clearance boundary but must not
			# link to the other side of a wall, gate or cliff.
			var hit = surface_hit(Vector3(p.x,Data.enemy_ground_height(p,map_id)+.3,p.y),Vector3(point.x,Data.enemy_ground_height(point,map_id)+.3,point.y))
			if not hit.is_empty(): continue
			best = cell
			distance = d
	return best

func enemy_clear(a: Vector2, b: Vector2, kind: String) -> bool:
	var navigation = enemy_grid(kind)
	var steps = maxi(1,ceili(a.distance_to(b)/(CELL*.4)))
	for i in steps+1:
		var p = a.lerp(b,float(i)/steps)
		var cell = Vector2i(((p-bounds.position)/CELL).round())
		if not navigation.is_in_boundsv(cell): return false
		if navigation.is_point_solid(cell) and not enemy_point_clear(p,kind): return false
	return true

func enemy_point_clear(p: Vector2, kind: String) -> bool:
	var profile = preload("res://scripts/enemy_body.gd").profile(kind)
	if not bounds.grow(-profile.clearance).has_point(p): return false
	for obstacle in obstacles:
		if Rect2(obstacle.minX,obstacle.minZ,obstacle.maxX-obstacle.minX,obstacle.maxZ-obstacle.minZ).grow(profile.clearance).has_point(p): return false
	var shape = CylinderShape3D.new()
	shape.radius = profile.clearance
	shape.height = (.72 if kind == "crawler" else profile.height)-.24
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.transform = Transform3D(Basis.IDENTITY,Vector3(p.x,Data.enemy_ground_height(p,map_id)+.24+shape.height/2,p.y))
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func enemy_path(a: Vector2, b: Vector2, kind: String) -> PackedVector2Array:
	var navigation = enemy_grid(kind)
	var first = enemy_cell(navigation,a)
	var last = enemy_cell(navigation,b)
	if first.x < 0 or last.x < 0: return PackedVector2Array()
	var tile = Vector2i(floori(first.x/8.0),floori(first.y/8.0))
	var goal_tile = Vector2i(floori(last.x/8.0),floori(last.y/8.0))
	var key = [preload("res://scripts/enemy_body.gd").profile(kind).key,goal_tile,tile]
	var route = PackedVector2Array()
	if shared_routes.has(key):
		var corridor: PackedVector2Array = shared_routes[key]
		var end_point = navigation.get_point_position(last)
		var tail_clear = not corridor.is_empty() and (corridor[-1] == end_point or enemy_clear(corridor[-1],end_point,kind))
		var nearest = -1
		var nearest_distance = INF
		for i in (mini(12,corridor.size()) if tail_clear else 0):
			var d = a.distance_squared_to(corridor[i])
			if d < nearest_distance and enemy_clear(a,corridor[i],kind):
				nearest = i
				nearest_distance = d
		if nearest >= 0:
			route = corridor.slice(nearest)
			if route[-1] != end_point: route.append(end_point)
			route_cache_hits += 1
	if route.is_empty():
		route = navigation.get_point_path(first,last)
		route_cache_misses += 1
		if shared_routes.size() >= 512: shared_routes.clear()
		shared_routes[key] = route.duplicate()
	if not route.is_empty() and enemy_clear(route[-1],b,kind): route.append(b)
	return route
