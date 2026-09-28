extends RefCounted
## Dense authority physics storage; dictionaries remain the snapshot boundary.
const Body = preload("res://scripts/enemy_body.gd")
var arena
var by_id: Dictionary = {}
var slots: Dictionary = {}
var bodies: Array = []
var ids = PackedInt64Array()
var positions = PackedVector2Array()
var heights = PackedFloat32Array()
var alive = PackedByteArray()
var cells: Dictionary = {}
var epoch = 0
var early_wakes = 0

func _init(world) -> void:
	arena = world

func body_for(z: Dictionary):
	if not by_id.has(z.id):
		var body = Body.new(z.kind)
		body.name = "ZombieBody_"+str(z.id)
		body.enemy_id = z.id
		arena.add_child(body)
		by_id[z.id] = body
		slots[z.id] = bodies.size()
		bodies.append(body)
		ids.append(z.id)
		positions.append(z.pos)
		heights.append(z.get("height",0.0))
		alive.append(1)
	var result = by_id[z.id]
	result.sync_from(z)
	record(z)
	return result

func record(z: Dictionary) -> void:
	if not slots.has(z.id): return
	var slot: int = slots[z.id]
	positions[slot] = z.pos
	heights[slot] = z.get("height",0.0)
	alive[slot] = int(z.hp > 0)
	var body = bodies[slot]
	var pose = Vector3(z.pos.x,heights[slot],z.pos.y)
	if body.wake_anchor.distance_squared_to(pose) > .0064 or absf(angle_difference(body.wake_heading,body.rotation.y)) > .15:
		body.pose_revision += 1
		body.wake_anchor = pose
		body.wake_heading = body.rotation.y

func reconcile(zombies: Array, build_cells := false) -> void:
	epoch += 1
	for z in zombies:
		if z.hp <= 0: continue
		var body = body_for(z)
		body.seen_epoch = epoch
	for i in range(bodies.size()-1,-1,-1):
		if bodies[i].seen_epoch == epoch: continue
		var id: int = ids[i]
		# Compacting slots invalidates last tick's spatial indices. They are
		# rebuilt before the next authority movement batch.
		cells.clear()
		bodies[i].retire()
		bodies[i].free()
		by_id.erase(id)
		slots.erase(id)
		var last = bodies.size()-1
		if i != last:
			bodies[i] = bodies[last]
			ids[i] = ids[last]
			positions[i] = positions[last]
			heights[i] = heights[last]
			alive[i] = alive[last]
			slots[ids[i]] = i
		bodies.resize(last)
		ids.resize(last)
		positions.resize(last)
		heights.resize(last)
		alive.resize(last)
	if build_cells:
		index_cells()

func index_cells() -> void:
	cells.clear()
	for i in bodies.size():
		if alive[i] == 0: continue
		var cell = Vector2i(floori(positions[i].x/3),floori(positions[i].y/3))
		var bucket: PackedInt32Array = cells.get(cell,PackedInt32Array())
		bucket.append(i)
		cells[cell] = bucket

func separation(id: int, point: Vector2, radius: float) -> Vector2:
	var result = Vector2.ZERO
	var cell = Vector2i(floori(point.x/3),floori(point.y/3))
	for y in range(-1,2):
		for x in range(-1,2):
			for slot in cells.get(cell+Vector2i(x,y),PackedInt32Array()):
				if ids[slot] == id or alive[slot] == 0: continue
				var offset = point-positions[slot]
				var d = offset.length_squared()
				if d > .001 and d < radius*radius: result += offset.normalized()*(radius-sqrt(d))
	return result

func needs_wake(body, goal: Vector2) -> bool:
	if body.wait_revision != arena.navigation_revision or body.wait_goal.distance_squared_to(goal) > .4225: return true
	if body.blocker_a >= 0 and (not by_id.has(body.blocker_a) or by_id[body.blocker_a].pose_revision != body.blocker_revision_a):
		early_wakes += 1
		return true
	if body.blocker_b >= 0 and (not by_id.has(body.blocker_b) or by_id[body.blocker_b].pose_revision != body.blocker_revision_b):
		early_wakes += 1
		return true
	return false

func clear() -> void:
	for body in bodies:
		if is_instance_valid(body): body.free()
	by_id.clear()
	slots.clear()
	bodies.clear()
	ids.clear()
	positions.clear()
	heights.clear()
	alive.clear()
	cells.clear()
