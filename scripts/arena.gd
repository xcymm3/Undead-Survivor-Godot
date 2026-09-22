extends Node3D
## Load the night route; physical cover and navigation share the authored scenery.
const Maps = preload("res://scripts/map_catalog.gd")
var map_id = "graypine_night"
var definition: Dictionary
var bounds: Rect2
var walk_regions: Array[PackedVector2Array] = []
var obstacles: Array = []
var collision_buckets: Dictionary = {}
var grid = AStarGrid2D.new()
var campaign_state: Dictionary = {}
var scenery: Node3D
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
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e0ecde")
	environment.environment.ambient_light_energy = .35
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment.fog_enabled = true
	environment.environment.fog_light_color = definition.fog
	environment.environment.fog_density = .018
	if map_id == "graypine_night":
		environment.environment.ambient_light_color = Color("839caf")
		environment.environment.ambient_light_energy = .24
		environment.environment.fog_density = .018
	elif map_id == "graypine_defense":
		environment.environment.ambient_light_color = Color("b9d5c5")
		environment.environment.ambient_light_energy = .58
		environment.environment.fog_density = .0045
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-35,0)
	sun.light_color = definition.sun
	sun.light_energy = .8
	if map_id == "graypine_night":
		sun.light_energy = .24
		sun.shadow_bias = .12
		sun.shadow_normal_bias = 2.0
	elif map_id == "graypine_defense":
		sun.light_energy = 1.15
		sun.rotation_degrees = Vector3(-48,-18,0)
	sun.shadow_enabled = Data.settings.quality > 0
	sun.directional_shadow_max_distance = 65
	add_child(sun)
	build_grid()

func build_grid() -> void:
	collision_buckets.clear()
	# Shallow water is walkable; only solid scenery blocks enemy navigation.
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
	if map_id == "graypine_night":
		if not campaign_state.get("departed",false) and segment_rect(a,b,Maps.Night.START_DOOR.grow(.95)): return false
		if (not campaign_state.get("exit_passable",campaign_state.get("exit_control",false)) or campaign_state.get("complete",false)) and segment_rect(a,b,Maps.Night.EXIT_DOOR.grow(.95)): return false
	if not bounds.grow(-.95).has_point(a) or not bounds.grow(-.95).has_point(b): return false
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
	if map_id == "graypine_night":
		if (not campaign_state.get("exit_control",false) or campaign_state.get("complete",false)) and segment_rect(a,b,Maps.Night.EXIT_DOOR): return false
		if not campaign_state.get("departed",false) and segment_rect(a,b,Maps.Night.START_DOOR): return false
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

func surface_hit(origin: Vector3, end: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,1))


func sync_campaign(state: Dictionary) -> void:
	var changed: bool = campaign_state.get("exit_control",false) != state.get("exit_control",false) or campaign_state.get("departed",false) != state.get("departed",false) or campaign_state.get("complete",false) != state.get("complete",false)
	changed = changed or campaign_state.get("exit_passable",false) != state.get("exit_passable",false)
	campaign_state = state.duplicate(true)
	scenery.sync(state)
	if changed: build_grid()
