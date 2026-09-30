extends RefCounted
## Authority wave bursts. All batches are scheduled across thirty game seconds.
const DURATION = 30.0
const MIN_BATCH_SIZE = 5
const MAX_BATCHES = 30
const Layout = preload("res://scripts/defense_layout.gd")
const MAX_SPAWN_ATTEMPTS = 4096
var owner_ref: WeakRef
var sim:
	get: return owner_ref.get_ref()
var clock = 0.0
var total = 0
var batches = 0
var interval = 0.0
var batch_size = 0
var retries_at = 0.0
var spawn_region: Rect2
var spawn_random = RandomNumberGenerator.new()
var reachable = PackedByteArray()
var grid_width = 0
var sight_profiles: Dictionary = {}
const SIGHT_MASK = 1 | preload("res://scripts/defense_spawn_forest.gd").SIGHT_LAYER

func _init(owner) -> void:
	owner_ref = weakref(owner)
	spawn_region = sim.map_definition.spawn_region
	build_reachability()

func build_reachability() -> void:
	var grid = sim.arena.grid
	grid_width = grid.region.size.x
	reachable.resize(grid_width*grid.region.size.y)
	reachable.fill(0)
	var start: Vector2i = sim.arena.nearest_cell(Layout.ENEMY_BRIDGE_START+Vector2(0,-2))
	if start.x < 0: return
	var queue: Array[Vector2i] = [start]
	reachable[start.y*grid_width+start.x] = 1
	var head = 0
	while head < queue.size():
		var cell = queue[head]
		head += 1
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+offset
			if not grid.is_in_boundsv(next) or grid.is_point_solid(next): continue
			if grid.get_point_position(next).y >= Layout.BRIDGE.position.y: continue
			var index: int = next.y*grid_width+next.x
			if reachable[index] == 1: continue
			reachable[index] = 1
			queue.append(next)

func reset(count: int) -> void:
	clock = 0.0
	retries_at = 0.0
	# Placement randomness never changes wave composition or combat randomness.
	spawn_random.seed = int(sim.random.seed) ^ (sim.wave*7919+67867967)
	total = count
	batch_size = maxi(MIN_BATCH_SIZE,ceili(float(count)/MAX_BATCHES))
	batches = ceili(float(count)/batch_size) if count > 0 else 0
	interval = DURATION/batches if batches > 0 else DURATION

func scheduled_count(at: float) -> int:
	if batches == 0: return 0
	var due = mini(batches,floori((at+.000001)/interval))
	return roundi(float(total)*due/batches)

func describe() -> Dictionary:
	return {"duration":DURATION,"total":total,"batches":batches,"interval":interval,"max_batch":batch_size}

func random_point() -> Vector2:
	return Vector2(spawn_random.randf_range(spawn_region.position.x,spawn_region.end.x),spawn_random.randf_range(spawn_region.position.y,spawn_region.end.y))

func ground_clear(point: Vector2) -> bool:
	if not Layout.enemy_spawn_allowed(point) or not sim.arena.clear(point,point): return false
	# A one-time flood fill replaces per-candidate A* on the larger woodland bank.
	var grid = sim.arena.grid
	var cell = Vector2i(((point-grid.offset)/grid.cell_size).round())
	return grid.is_in_boundsv(cell) and reachable[cell.y*grid_width+cell.x] == 1 and sim.arena.clear(point,grid.get_point_position(cell))

func sight_profile(kind: String) -> PackedVector2Array:
	if sight_profiles.has(kind): return sight_profiles[kind]
	# Build once per kind. Radial widths cover any initial facing, including
	# outstretched hands, shields and hats; small margins allow idle sway.
	var feet = Vector2(.3,.25)
	var shoulders = Vector2(.35,1.1)
	var head = Vector2(.25,1.8)
	var top = 0.0
	for part in Data.parts:
		if part.has("kind") and part.kind != kind: continue
		var center: Vector3 = Data.v3(part.position)
		var edge: Vector3 = center.abs()+Data.v3(part.size)*.5
		var width = Vector2(edge.x,edge.z).length()
		top = maxf(top,edge.y)
		if part.get("head",false):
			if width > head.x: head = Vector2(width,center.y)
		elif absf(float(part.get("limb",0.0))) >= 1:
			if width > feet.x: feet = Vector2(width,center.y)
		elif width > shoulders.x: shoulders = Vector2(width,center.y)
	var profile = PackedVector2Array([Vector2(0,.25),Vector2(0,1.1),Vector2(0,top+.08)])
	for edge in [shoulders,head,feet]:
		profile.append(Vector2(-edge.x-.12,edge.y))
		profile.append(Vector2(edge.x+.12,edge.y))
	var scale: float = Data.enemy_scale(kind)
	for index in profile.size(): profile[index] *= scale
	sight_profiles[kind] = profile
	return profile

func hidden_from_players(point: Vector2, kind: String, living: Array) -> bool:
	var ground = Layout.height(point)
	var profile = sight_profile(kind)
	var space = sim.arena.get_world_3d().direct_space_state
	for p in living:
		var eye = Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p),p.pos.y)
		var toward: Vector2 = (point-p.pos).normalized()
		var side = Vector3(-toward.y,0,toward.x)
		# A hidden centre is insufficient: a tall hat or either shoulder can
		# protrude. Nine bounded rays test the silhouette and fail early.
		for sample in profile:
			var target = Vector3(point.x,ground+sample.y,point.y)+side*sample.x
			var query = PhysicsRayQueryParameters3D.create(eye,target,SIGHT_MASK)
			if space.intersect_ray(query).is_empty(): return false
	return true

func step(dt: float, living: Array) -> void:
	clock += dt
	var due = scheduled_count(clock)-sim.spawned
	if due <= 0 or sim.roster.is_empty() or clock < retries_at: return
	# Blocked points keep their quota. Retry safely rather than discarding
	# enemies or dumping the entire wave. Spawn spacing is only placement policy.
	retries_at = clock+.1
	var occupied = {}
	for z in sim.zombies:
		if z.hp > 0: add_occupied(occupied,z.pos)
	var released = 0
	var attempts = mini(MAX_SPAWN_ATTEMPTS,maxi(128,batch_size*64))
	for attempt in attempts:
		if released >= mini(due,batch_size) or sim.roster.is_empty(): break
		var point = random_point()
		if not Layout.enemy_spawn_allowed(point) or near_occupied(occupied,point): continue
		if living.any(func(p): return p.pos.distance_squared_to(point) < 64): continue
		if not ground_clear(point): continue
		var kind: String = sim.defense_population_kind(sim.roster[0])
		if not hidden_from_players(point,kind,living): continue
		sim.spawn(point,kind)
		sim.roster.remove_at(0)
		sim.spawned += 1
		released += 1
		add_occupied(occupied,point)

func add_occupied(cells: Dictionary, point: Vector2) -> void:
	var key = Vector2i(floori(point.x/3),floori(point.y/3))
	if not cells.has(key): cells[key] = []
	cells[key].append(point)

func near_occupied(cells: Dictionary, point: Vector2) -> bool:
	var key = Vector2i(floori(point.x/3),floori(point.y/3))
	for y in range(-1,2):
		for x in range(-1,2):
			for other in cells.get(key+Vector2i(x,y),[]):
				if point.distance_squared_to(other) < 4.0: return true
	return false
