extends RefCounted
## Authority wave bursts. All batches are scheduled across thirty game seconds.
const DURATION = 30.0
const MIN_BATCH_SIZE = 5
const MAX_BATCHES = 30
const SPACING = 2.4
var owner_ref: WeakRef
var sim:
	get: return owner_ref.get_ref()
var clock = 0.0
var total = 0
var batches = 0
var interval = 0.0
var batch_size = 0
var retries_at = 0.0
var candidates: Array[Vector2] = []

func _init(owner) -> void:
	owner_ref = weakref(owner)
	# Five authored spawn centres retain their near/far identities. Small
	# nearby offsets provide empty ground when a batch exceeds five bodies.
	for ring in range(3):
		for centre in sim.map_definition.spawns:
			for y in range(-ring,ring+1):
				for x in range(-ring,ring+1):
					if maxi(absi(x),absi(y)) == ring:
						candidates.append(centre+Vector2(x,y)*SPACING)

func reset(count: int) -> void:
	clock = 0.0
	retries_at = 0.0
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
	var centres: Array = sim.map_definition.spawns.duplicate()
	centres.shuffle()
	var ordered: Array = centres.duplicate()
	var offsets: Array = []
	for point in candidates:
		if point not in centres: offsets.append(point)
	offsets.shuffle()
	ordered.append_array(offsets)
	var released = 0
	for point in ordered:
		if released >= mini(due,batch_size) or sim.roster.is_empty(): break
		if not sim.arena.clear(point,point) or near_occupied(occupied,point): continue
		if living.any(func(p): return p.pos.distance_squared_to(point) < 64): continue
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
