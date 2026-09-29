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

func _init(owner) -> void:
	owner_ref = weakref(owner)
	spawn_region = sim.map_definition.spawn_region

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
	# Check connectivity on the existing shared navigation, without building
	# extra grids. The approach point is on the far bank before the bridge.
	return not sim.arena.path_to(point,Vector2(0,Layout.BRIDGE.position.y-2)).is_empty()

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
		sim.spawn(point,sim.defense_population_kind(sim.roster[0]))
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
