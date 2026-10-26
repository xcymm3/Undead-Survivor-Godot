extends RefCounted
## Shared, authored woodland lanes. Only displaced enemies need a rejoin query.
const DATA_PATH = "res://assets/data/forest_routes.json"
const EXITS = [Vector2(-23,-80),Vector2(0,-80),Vector2(23,-80)]
const HANDOFF_Z = -56.0
var entries: Array[Dictionary] = []

func _init(arena) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	for item in data.routes:
		var points = PackedVector2Array()
		for point in item.points: points.append(Vector2(point[0],point[1]))
		var group = int(item.get("exit",-1))
		var valid = points.size() >= 5 and group >= 0 and group < EXITS.size()
		valid = valid and is_equal_approx(points[-1].y,HANDOFF_Z) and absf(points[-1].x) <= 2.5
		if valid:
			valid = false
			for point in points:
				if point.distance_to(EXITS[group]) <= .5: valid = true
		for index in points.size()-1:
			valid = valid and arena.clear(points[index],points[index+1])
		if not valid:
			push_error("Invalid fixed forest route: "+str(item.id))
			continue
		entries.append({"id":str(item.id),"exit":group,"points":points})
	if entries.size() != 20: push_error("Expected twenty fixed forest routes")

func attach(z: Dictionary, position: Vector2) -> void:
	for index in entries.size():
		if position.distance_squared_to(entries[index].points[0]) > .000001: continue
		z["forest_route"] = index
		z["forest_waypoint"] = 1
		return

func active(z: Dictionary) -> bool:
	var index = int(z.get("forest_route",-1))
	return index >= 0 and index < entries.size()

func finish(sim, z: Dictionary) -> void:
	z["forest_route"] = -1
	z["forest_waypoint"] = -1
	sim.paths.erase(z.id)

func follow(sim, z: Dictionary, speed: float, dt: float) -> bool:
	if not active(z): return false
	var index = int(z.forest_route)
	var points: PackedVector2Array = entries[index].points
	var cursor = int(z.forest_waypoint)
	while cursor < points.size() and z.pos.distance_squared_to(points[cursor]) <= .0004:
		cursor += 1
	z.forest_waypoint = cursor
	if cursor >= points.size():
		finish(sim,z)
		return false
	var waypoint: Vector2 = points[cursor]
	var projection = Geometry2D.get_closest_point_to_segment(z.pos,points[cursor-1],waypoint)
	# Shoves, knockback and charges may leave the lane. Rejoin safely using the
	# existing bounded planner; never teleport through scenery or abandon the lane.
	if z.pos.distance_squared_to(projection) > .0004:
		preload("res://scripts/stutter_log.gd").path_event("forest_rejoin",{"enemy_id":z.id,"route":index,"position":[z.pos.x,z.pos.y],"projection":[projection.x,projection.y]})
		sim.move_zombie(z,projection,speed,dt,z.pos.distance_to(projection),0.0,true,"forest_rejoin")
		return true
	var direction: Vector2 = (waypoint-z.pos).normalized()
	var travel = minf(speed*dt,z.pos.distance_to(waypoint))
	# Stay on the same polyline instead of applying lateral crowd steering into
	# trees. A bounded local headway check prevents same-lane overtaking/stacking.
	var cell = Vector2i(floori(z.pos.x/3),floori(z.pos.y/3))
	var examined = 0
	for y in range(-1,2):
		for x in range(-1,2):
			for other in sim.crowd_buckets.get(cell+Vector2i(x,y),[]):
				if examined >= 32: break
				examined += 1
				if other.id == z.id or other.hp <= 0 or int(other.get("forest_route",-1)) != index: continue
				var offset: Vector2 = other.pos-z.pos
				var ahead = offset.dot(direction)
				var lateral = absf(offset.cross(direction))
				var gap = 1.5 if z.kind == "giant" or other.kind == "giant" else .9
				if ahead > .0001 and lateral < .5: travel = minf(travel,maxf(0,ahead-gap))
	var old_position: Vector2 = z.pos
	# All segments are validated once against the same conservative collision
	# footprint as normal movement. Exactly following them needs no per-step ray,
	# A* request, long goal visibility test or repeated obstacle scan.
	z.pos = z.pos.move_toward(waypoint,travel)
	z.gait = z.get("gait",0.0)+old_position.distance_to(z.pos)*2.3
	z.move_speed = old_position.distance_to(z.pos)/maxf(dt,.001)
	if direction.length_squared() > .01: z.heading = atan2(direction.x,direction.y)
	return true
