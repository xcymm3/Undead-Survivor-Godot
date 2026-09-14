extends RefCounted
## QA input policy only. Does not mutate pawns, enemies, inventory or director state.
var game
var tasks: Array = []
var index = 0
var path = PackedVector2Array()
var angle = 0.0

func _init(current_game, yard: bool) -> void:
	game = current_game
	tasks = [[Vector2(0,111),"depart"],[Vector2(0,103),""],[Vector2(18,96),""],[Vector2(18,78),""],[Vector2(-15,70),""],[Vector2(-15,53),""]]
	if yard: tasks.append_array([[Vector2(-33,52),""],[Vector2(-44,52),""],[Vector2(-44,41),"yard_ammo"],[Vector2(-44,32),""],[Vector2(-29,32),""],[Vector2(-15,40),""]])
	tasks.append_array([[Vector2(8,30),""],[Vector2(8,6),""],[Vector2(0,-8),""],[Vector2(11,-11),"bridge_ammo"],[Vector2(8,-14.4),"winch"],[Vector2(0,-18),"defend"],[Vector2(0,-29),""],[Vector2(0,-50),""],[Vector2(0,-62),""],[Vector2(20,-77),"shed_ammo"],[Vector2(36,-92),""],[Vector2(8,-103),""],[Vector2(25,-115),""],[Vector2(25,-123),"finish"]])

func command(dt: float) -> Dictionary:
	var p: Dictionary = game.local_pawn()
	if p.is_empty() or not p.has("primary") or p.hp <= 0: return {}
	var state: Dictionary = game.sim.campaign_state()
	if state.is_empty() or index >= tasks.size(): return {}
	var goal: Vector2 = tasks[index][0]
	var action: String = tasks[index][1]
	var arrived = p.pos.distance_to(goal) < .55
	var interact = false
	var advance = false
	if action == "defend":
		advance = state.gate_open
		angle += dt*.7
		goal = Vector2(cos(angle)*5,-18+sin(angle)*5)
	elif arrived:
		interact = action != ""
		if action == "": advance = true
		elif action == "depart": advance = state.departed
		elif action == "winch": advance = state.phase == "BRIDGE_ACTIVE" or state.gate_open
		elif action == "finish": advance = state.complete
		else: advance = state.claimed.get(action,[]).has(p.id) or p.reserve >= int(Data.weapons[p.primary].capacity)*6
	if advance:
		index += 1
		path.clear()
		return {}
	if action != "defend":
		if path.is_empty():
			path = game.arena.path_to(p.pos,goal)
			path.append(goal)
		while path.size() > 1 and p.pos.distance_to(path[0]) < .85: path.remove_at(0)
		goal = path[0]
	var delta: Vector2 = goal-p.pos
	var yaw: float = p.yaw
	var pitch = 0.0
	var fire = false
	var distance = 32.0
	for z in game.sim.zombies:
		if z.hp <= 0 or z.pos.distance_to(p.pos) >= distance: continue
		var poses: Array = load("res://scripts/enemy_view.gd").transforms(z,game.sim.elapsed,false)
		var point: Vector3 = poses[0].origin
		for part in Data.parts.size():
			if Data.parts[part].get("head",false):
				point = poses[part].origin
				break
		var origin = Vector3(p.pos.x,p.height+1.7,p.pos.y)
		if not game.arena.surface_hit(origin,point).is_empty(): continue
		distance = z.pos.distance_to(p.pos)
		var aim = point-origin
		yaw = atan2(-aim.x,-aim.z)
		pitch = atan2(aim.y,Vector2(aim.x,aim.z).length())
		fire = true
	var heal: bool = p.hp < 55 and p.medkits > 0
	var direction = delta.normalized() if delta.length() > .25 else Vector2.ZERO
	return {"x":direction.x*cos(yaw)-direction.y*sin(yaw),"y":direction.x*sin(yaw)+direction.y*cos(yaw),"yaw":yaw,"pitch":pitch,"weapon":6 if p.reserve == 0 and p.ammo[p.primary] == 0 else p.primary,"fire":fire and not interact and not heal,"reload":p.ammo[p.primary] < 5,"interact":interact,"heal":heal,"jump":game.sim.zombies.any(func(z): return z.hp > 0 and z.kind == "football" and z.state == "charging" and z.pos.distance_to(p.pos) < 8)}
