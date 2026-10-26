extends Node3D
## Crystal defense terrain supplies both physical cover and enemy navigation.
const Maps = preload("res://scripts/map_catalog.gd")
const Recorder = preload("res://scripts/stutter_log.gd")
var map_id = "graypine_defense"
var definition: Dictionary
var bounds: Rect2
var walk_regions: Array[PackedVector2Array] = []
var obstacles: Array = []
var collision_buckets: Dictionary = {}
var endpoint_buckets: Dictionary = {}
var endpoint_obstacle_checks = 0
var structure_state: Array = []
var grid = AStarGrid2D.new()
var static_solid = PackedByteArray()
var navigation_structures: Array = []
var navigation_revision = 0
var navigation_bounds: Dictionary = {}
var scenery: Node3D
var static_scenery
var sun: DirectionalLight3D
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
	environment.environment.background_color = Color("080d1c")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e0ecde")
	environment.environment.ambient_light_energy = .35
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment.fog_enabled = true
	environment.environment.fog_light_color = definition.fog
	environment.environment.fog_density = .018
	environment.environment.ambient_light_color = Color("7796c7")
	environment.environment.ambient_light_energy = .22
	environment.environment.fog_light_color = Color("101a2b")
	environment.environment.fog_density = .006
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-35,0)
	sun.light_color = Color("a8c5ef")
	sun.light_energy = .8
	sun.light_energy = .27
	sun.rotation_degrees = Vector3(-48,-18,0)
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 65
	add_child(sun)
	build_grid()
	static_scenery = preload("res://scripts/static_scenery.gd").new()
	add_child(static_scenery)
	static_scenery.setup(scenery)

func build_grid() -> void:
	collision_buckets.clear()
	endpoint_buckets.clear()
	# Solid scenery and the chasm define enemy navigation.
	for o in obstacles:
		index_obstacle(Rect2(o.minX-.95,o.minZ-.95,o.maxX-o.minX+1.9,o.maxZ-o.minZ+1.9),false)
		var physical = Rect2(o.minX,o.minZ,o.maxX-o.minX,o.maxZ-o.minZ)
		for y in range(floori(physical.position.y/4),floori(physical.end.y/4)+1):
			for x in range(floori(physical.position.x/4),floori(physical.end.x/4)+1):
				var key = Vector2i(x,y)
				if not endpoint_buckets.has(key): endpoint_buckets[key] = []
				endpoint_buckets[key].append(physical)
	grid.region = Rect2i(Vector2i.ZERO,Vector2i(ceil(bounds.size.x/CELL)+1,ceil(bounds.size.y/CELL)+1))
	grid.cell_size = Vector2(CELL,CELL)
	grid.offset = bounds.position
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	static_solid.resize(grid.region.size.x*grid.region.size.y)
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var p = bounds.position+Vector2(x,y)*CELL
			# Whole grid cells must clear geometry, including diagonal edges.
			var margin = Vector2.ONE*(CELL*.5+.001)
			var solid = not clear(p-margin,p+margin) or not clear(p+Vector2(-margin.x,margin.y),p+Vector2(margin.x,-margin.y))
			static_solid[y*grid.region.size.x+x] = int(solid)
			grid.set_point_solid(Vector2i(x,y),solid)

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
	for item in structure_state:
		if item.hp > 0 and item.kind != "mine" and segment_rect(a,b,preload("res://scripts/defense_structures.gd").bounds(item)): return false
	# Same physical-space test as before, restricted to nearby obstacles.
	# A player standing in the enemy clearance margin visits many candidate
	# cells; scanning the entire woodland for each candidate caused hitches.
	for y in range(floori(minf(a.y,b.y)/4),floori(maxf(a.y,b.y)/4)+1):
		for x in range(floori(minf(a.x,b.x)/4),floori(maxf(a.x,b.x)/4)+1):
			for rect in endpoint_buckets.get(Vector2i(x,y),[]):
				endpoint_obstacle_checks += 1
				if segment_rect(a,b,rect): return false
	return true

func nearest_cell(p: Vector2) -> Vector2i:
	var stamp = Recorder.begin()
	var checked = endpoint_obstacle_checks
	var result = _nearest_cell(p)
	Recorder.end("endpoint_lookup",stamp)
	if stamp > 0 and (result.x < 0 or Time.get_ticks_usec()-stamp >= 2000):
		Recorder.path_event("endpoint_lookup",{"position":[p.x,p.y],"cell":[result.x,result.y],"duration_us":Time.get_ticks_usec()-stamp,"obstacle_checks":endpoint_obstacle_checks-checked,"revision":navigation_revision})
	return result

func _nearest_cell(p: Vector2) -> Vector2i:
	var base = Vector2i(((p-bounds.position)/CELL).round())
	if grid.is_in_boundsv(base) and not grid.is_point_solid(base) and endpoint_link(p,grid.get_point_position(base)): return base
	var candidates: Array[Vector3] = []
	for y in range(-5,6):
		for x in range(-5,6):
			var candidate = base+Vector2i(x,y)
			if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate): continue
			var point = grid.get_point_position(candidate)
			candidates.append(Vector3(candidate.x,candidate.y,p.distance_squared_to(point)))
	# Test the nearest candidate first instead of repeatedly validating progressively
	# closer candidates. Equal-distance ties retain the old row/column order.
	candidates.sort_custom(func(a,b): return a.z < b.z if a.z != b.z else a.y < b.y if a.y != b.y else a.x < b.x)
	for candidate in candidates:
		var cell = Vector2i(int(candidate.x),int(candidate.y))
		if endpoint_link(p,grid.get_point_position(cell)): return cell
	return Vector2i(-1,-1)

func path_to(a: Vector2, b: Vector2, request: Dictionary = {}) -> PackedVector2Array:
	var stamp = Recorder.begin()
	var details = request.duplicate() if stamp > 0 else {}
	if stamp > 0:
		details.merge({"from":[a.x,a.y],"goal":[b.x,b.y],"revision":navigation_revision,
			"direct_us":0,"endpoint_us":0,"astar_us":0,"outcome":"unknown"},true)
	var result = _path_to_measured(a,b,details)
	Recorder.end("pathfinding",stamp)
	if stamp > 0:
		details["total_us"] = Time.get_ticks_usec()-stamp
		details["points"] = result.size()
		Recorder.path_request(details)
	return result

func _path_to_measured(a: Vector2, b: Vector2, details: Dictionary = {}) -> PackedVector2Array:
	var traced = not details.is_empty()
	var stamp = Time.get_ticks_usec() if traced else 0
	var direct = clear(a,b)
	if traced: details.direct_us = Time.get_ticks_usec()-stamp
	if direct:
		if traced: details.outcome = "direct"
		return PackedVector2Array([b])
	stamp = Time.get_ticks_usec() if traced else 0
	var checks_before = endpoint_obstacle_checks
	var start = nearest_cell(a)
	var end = nearest_cell(b)
	if traced:
		details.endpoint_us = Time.get_ticks_usec()-stamp
		details["endpoint_obstacle_checks"] = endpoint_obstacle_checks-checks_before
		details["start_cell"] = [start.x,start.y]
		details["goal_cell"] = [end.x,end.y]
		details["start_projection_m"] = a.distance_to(grid.get_point_position(start)) if start.x >= 0 else -1.0
		details["goal_projection_m"] = b.distance_to(grid.get_point_position(end)) if end.x >= 0 else -1.0
	if start.x < 0 or end.x < 0:
		if traced: details.outcome = "invalid_endpoint"
		return PackedVector2Array()
	stamp = Recorder.begin()
	var route = grid.get_point_path(start,end)
	if traced: details.astar_us = Time.get_ticks_usec()-stamp
	Recorder.end("path_astar",stamp)
	# Grid centers are intermediate points, never the final melee position.
	var connected = not route.is_empty() and clear(route[-1],b)
	if connected: route.append(b)
	if traced:
		details["goal_connected"] = connected
		details.outcome = "unreachable" if route.is_empty() else "path" if connected else "projected_endpoint"
	return route

func surface_hit(origin: Vector3, end: Vector3, ignore_structure := "") -> Dictionary:
	var query = PhysicsRayQueryParameters3D.create(origin,end,1)
	if not ignore_structure.is_empty() and scenery.structure_view:
		query.exclude = scenery.structure_view.collision_rids(ignore_structure)
	return get_world_3d().direct_space_state.intersect_ray(query)


func sync_defense(state: Dictionary) -> void:
	structure_state = state.get("structures",[])
	var active: Array = []
	for item in structure_state:
		if item.hp > 0 and item.kind != "mine": active.append(item.id)
	if active != navigation_structures:
		var stamp = Recorder.begin()
		var previous = navigation_structures
		navigation_structures = active
		navigation_revision += 1
		# Update only old/new building footprints. Resetting the entire forest
		# grid on every destroyed/repaired gate created a separate one-frame spike.
		var next_bounds: Dictionary = {}
		for item in structure_state:
			if not item.id in active: continue
			var rect: Rect2 = preload("res://scripts/defense_structures.gd").bounds(item).grow(.95+CELL*.5+.001)
			next_bounds[item.id] = rect
		var current_bounds: Array = next_bounds.values()
		var affected: Array = navigation_bounds.values()+current_bounds
		for rect in affected:
			var first = Vector2i(((rect.position-bounds.position)/CELL).floor())
			var last = Vector2i(((rect.end-bounds.position)/CELL).ceil())
			for y in range(first.y,last.y+1):
				for x in range(first.x,last.x+1):
					var cell = Vector2i(x,y)
					if not grid.is_in_boundsv(cell): continue
					var solid: bool = static_solid[y*grid.region.size.x+x] != 0
					for current in current_bounds:
						if current.has_point(grid.get_point_position(cell)): solid = true; break
					grid.set_point_solid(cell,solid)
		navigation_bounds = next_bounds
		Recorder.end("navigation_grid_update",stamp)
		Recorder.path_event("navigation_changed",{"revision":navigation_revision,"previous_buildings":previous,"active_buildings":active})
	scenery.sync(state)
