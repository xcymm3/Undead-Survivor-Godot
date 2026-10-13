extends RefCounted
## Broad-phase only: exact poses, armor and penetration still use EnemyView.hit.
const CELL = 6.0
var buckets: Dictionary = {}
var items: Array = []
var builds = 0
var queries = 0

func rebuild(zombies: Array) -> void:
	items = zombies
	buckets.clear()
	builds += 1
	for i in items.size():
		var z: Dictionary = items[i]
		if z.hp <= 0: continue
		# Match the XZ extent of hit()'s existing conservative broad box.
		var radius = 1.5*Data.enemy_scale(z.kind)+.0001
		var first = Vector2i(((z.pos-Vector2.ONE*radius)/CELL).floor())
		var last = Vector2i(((z.pos+Vector2.ONE*radius)/CELL).floor())
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				var key = Vector2i(x,y)
				if not buckets.has(key): buckets[key] = []
				buckets[key].append(i)

func query(origin: Vector3, direction: Vector3, distance: float) -> Array:
	queries += 1
	var point = Vector2(origin.x,origin.z)/CELL
	var delta = Vector2(direction.x,direction.z)*distance/CELL
	var cell = Vector2i(point.floor())
	var destination = Vector2i((point+delta).floor())
	var stride = Vector2i(sign(delta.x),sign(delta.y))
	var increment = Vector2(INF if absf(delta.x)<.0000001 else absf(1/delta.x),INF if absf(delta.y)<.0000001 else absf(1/delta.y))
	var next = Vector2(INF,INF)
	if stride.x != 0: next.x = (cell.x+(1 if stride.x>0 else 0)-point.x)/delta.x
	if stride.y != 0: next.y = (cell.y+(1 if stride.y>0 else 0)-point.y)/delta.y
	var selected: Dictionary = {}
	var remaining = absi(destination.x-cell.x)+absi(destination.y-cell.y)+3
	while remaining > 0:
		for i in buckets.get(cell,[]): selected[i] = true
		if cell == destination: break
		if next.x <= next.y:
			cell.x += stride.x
			next.x += increment.x
		else:
			cell.y += stride.y
			next.y += increment.y
		remaining -= 1
	# Original roster order preserves equal-distance tie behavior.
	var indices = selected.keys()
	indices.sort()
	var result: Array = []
	for i in indices:
		if items[i].hp > 0: result.append(items[i])
	return result
