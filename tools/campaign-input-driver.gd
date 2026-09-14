extends RefCounted
## QA input policy only. Does not mutate pawns, enemies, inventory or director state.
const Layout = preload("res://scripts/campaign_layout.gd")
var game
var tasks: Array = []
var index = 0
var path = PackedVector2Array()
var angle = 0.0
var fire_clock = 0.0
var grenade_cooldown = 0.0
var grenade_pending = 0.0
var grenade_count = 0
var grenade_aim = Vector2.ZERO

func _init(current_game, yard: bool) -> void:
	game = current_game
	tasks = [[Vector2(0,111),"depart"],[Vector2(0,103),""],[Vector2(18,96),""],[Vector2(18,78),""],[Vector2(-15,70),""]]
	for point in Layout.SHOP_ROUTE: tasks.append([point,"key" if point == Layout.SHOP else ""])
	tasks.append([Vector2(-58,73),"shop_ammo"])
	append_objective_route(Layout.LOADING_ROUTE)
	for point in Layout.STREET_PANEL_ROUTE: tasks.append([point,"shop" if point == Layout.STREET_PANEL else ""])
	for point in Layout.SHOP_RETURN: tasks.append([point,""])
	if yard: tasks.append_array([[Vector2(-33,52),""],[Vector2(-44,52),""],[Vector2(-44,41),"yard_ammo"],[Vector2(-44,32),""],[Vector2(-29,32),""],[Vector2(-15,40),""]])
	tasks.append_array([[Vector2(8,30),""],[Vector2(8,6),""],[Vector2(0,-8),""],[Vector2(11,-11),"bridge_ammo"],[Vector2(8,-14.4),"winch"],[Vector2(0,-18),"defend"],[Vector2(0,-29),""],[Vector2(0,-50),""],[Vector2(0,-62),""],[Vector2(20,-77),"shed_ammo"],[Vector2(23,-77),"shed_med"]])
	for point in Layout.PUMP_ROUTE: tasks.append([point,"leak" if point == Layout.LEAK else ""])
	append_objective_route(Layout.REPAIR_ROUTE)
	for point in Layout.PUMP_INTERIOR: tasks.append([point,"pump" if point == Layout.PUMP else ""])
	tasks.append([Vector2(-55,-112),"pump_ammo"])
	tasks.append([Vector2(-55,-114),"pump_med"])
	for point in Layout.VALVE_ROUTE: tasks.append([point,"power" if point == Layout.VALVE else ""])
	tasks.append([Vector2(69,-124),"valve_ammo"])
	append_objective_route(Layout.SERVICE_ROUTE)
	for point in Layout.FINISH_ROUTE: tasks.append([point,"finish" if point == Layout.FINISH_ROUTE[-1] else ""])
	var expanded: Array = []
	for task in tasks:
		expanded.append(task)
		for item in Layout.ITEMS:
			if task[1] == item.id and item.kind == "ammo": expanded.append([item.pos+Vector2(-1,1.3),"grenade:"+item.id])
	tasks = expanded

func append_objective_route(route: Array) -> void:
	var objectives = load("res://scripts/campaign_objectives.gd")
	for point in route:
		var action: String = objectives.at(point)
		tasks.append([point,action])
		var supplies = {"loading_power":[Vector2(-28,145),"loading_ammo"],"pump_fault_b":[Vector2(-18,-180),"repair_ammo"],"exit_relay":[Vector2(62,-220),"service_ammo"]}
		if supplies.has(action): tasks.append(supplies[action])

func command(dt: float) -> Dictionary:
	fire_clock += dt
	grenade_cooldown = maxf(0,grenade_cooldown-dt)
	var p: Dictionary = game.local_pawn()
	if p.is_empty() or not p.has("primary") or p.hp <= 0: return {}
	# Release E after any pickup, including a grenade that was selected while
	# turning toward a gun. Holding E cannot consume a second item.
	if p.get("pickup_latched",false): return {}
	if grenade_pending > 0 and p.grenades == grenade_count:
		grenade_pending -= dt
		var aim: Vector2 = grenade_aim-p.pos
		return {"x":0.0,"y":0.0,"yaw":atan2(-aim.x,-aim.y),"pitch":-1.0 if aim.length() < 6 else -.45,"slot":4,"fire":true,"use_self":true}
	grenade_pending = 0.0
	var state: Dictionary = game.sim.campaign_state()
	if state.is_empty() or index >= tasks.size(): return {}
	var goal: Vector2 = tasks[index][0]
	var action: String = tasks[index][1]
	var arrived = p.pos.distance_to(goal) < .55
	var interact = false
	var advance = false
	if action == "defend":
		advance = state.gate_open
		# Separate teammates and use a wider loop so the horde cannot cut across
		# the entire defensive route. These remain ordinary movement inputs.
		angle += dt*.45
		var offset = float(str(p.id).hash() % 628)/100.0
		goal = Vector2(cos(angle+offset)*7,-18+sin(angle+offset)*7)
	elif arrived:
		interact = action != ""
		if action == "": advance = true
		elif action == "depart": advance = state.departed
		elif action == "winch": advance = state.phase == "BRIDGE_ACTIVE" or state.gate_open
		elif action.ends_with("_med"): advance = state.taken.has(action) or p.medkits > 0
		elif action == "key": advance = state.shop_key
		elif action == "shop": advance = state.shop_open
		elif action == "leak": advance = state.leak_closed
		elif action == "pump": advance = state.pump_ready
		elif action == "power": advance = state.power_ready
		elif action == "finish": advance = state.complete
		elif action.begins_with("grenade:"):
			var station: Dictionary = state.grenade_stations[action.trim_prefix("grenade:")]
			advance = station.claimed.has(p.id) or station.remaining <= 0 or p.grenades >= 1
		elif state.has(action) and state[action] is bool: advance = state[action]
		else: advance = state.claimed.get(action,[]).has(p.id) or p.reserve >= int(Data.weapons[p.primary].capacity)*6
	if advance:
		index += 1
		path.clear()
		return {}
	if action != "defend":
		# Combat retreat can put the pawn on the other side of equipment.
		# Replan before following a cached segment that now crosses solid geometry.
		if not path.is_empty() and not game.arena.endpoint_link(p.pos,path[0]) and not game.arena.endpoint_link(path[0],p.pos): path.clear()
		if path.is_empty():
			path = game.arena.path_to(p.pos,goal)
			path.append(goal)
		while path.size() > 1 and p.pos.distance_to(path[0]) < .35: path.remove_at(0)
		goal = path[0]
	var delta: Vector2 = goal-p.pos
	var yaw: float = p.yaw
	var pitch = 0.0
	var fire = false
	var distance = 32.0
	var enemy_point = Vector2.INF
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
		enemy_point = z.pos
		var aim = point-origin
		yaw = atan2(-aim.x,-aim.z)
		pitch = atan2(aim.y,Vector2(aim.x,aim.z).length())
		fire = true
	if arrived and action.ends_with("_ammo") and distance >= 6:
		for loot in state.get("loot",[]):
			if loot.station == action and not loot.taken:
				var aim: Vector2 = loot.pos-p.pos
				yaw = atan2(-aim.x,-aim.y)
				pitch = -.45
				break
	# A threatened bot must keep fighting instead of repeatedly interrupting
	# its own three-second heal until the whole party goes down.
	var nearest = 1000.0
	for z in game.sim.zombies:
		if z.hp > 0: nearest = minf(nearest,z.pos.distance_to(p.pos))
	var heal: bool = p.hp < 70 and p.medkits > 0 and nearest > 8.0
	if arrived and action.begins_with("grenade:") and distance >= 6:
		for item in Layout.ITEMS:
			if item.id == action.trim_prefix("grenade:"):
				var aim: Vector2 = item.pos+Vector2(-1,0)-p.pos
				yaw = atan2(-aim.x,-aim.y)
				pitch = -.45
	if p.grenades > 0 and grenade_cooldown <= 0 and not heal and distance >= 2 and distance <= 14:
		var clustered = game.sim.zombies.filter(func(z): return z.hp > 0 and z.pos.distance_to(enemy_point) < 4).size()
		var heavy = game.sim.zombies.any(func(z): return z.hp > 0 and z.kind == "football" and z.pos.distance_to(p.pos) < 12)
		if clustered >= 4 or heavy:
			grenade_cooldown = 5.0
			grenade_pending = 2.0
			grenade_count = p.grenades
			grenade_aim = enemy_point
			var aim: Vector2 = enemy_point-p.pos
			return {"x":0.0,"y":0.0,"yaw":atan2(-aim.x,-aim.y),"pitch":-1.0 if distance < 6 else -.45,"slot":4,"fire":true,"use_self":true}
	if not Data.weapons[p.weapon].automatic: fire = fire and fmod(fire_clock,.2) < .1
	var direction = delta.normalized() if delta.length() > .25 else Vector2.ZERO
	if distance < 6: interact = false
	if nearest < 3.5 and enemy_point.is_finite():
		var away = (p.pos-enemy_point).normalized()
		for candidate in [away,away.rotated(PI/2),away.rotated(-PI/2)]:
			if game.arena.endpoint_link(p.pos,p.pos+candidate*2) and game.sim.can_move(p,p.pos+candidate*.3):
				direction = candidate
				interact = false
				break
	return {"x":direction.x*cos(yaw)-direction.y*sin(yaw),"y":direction.x*sin(yaw)+direction.y*cos(yaw),"yaw":yaw,"pitch":pitch,"weapon":6 if p.reserve == 0 and p.ammo[p.primary] == 0 else p.primary,"fire":heal or (fire and not interact),"reload":p.ammo[p.weapon] < 5,"interact":interact,"slot":5 if heal or not p.get("healing","").is_empty() else 1 if p.reserve > 0 or p.ammo[p.primary] > 0 else 2 if p.reserves[p.secondary] > 0 or p.ammo[p.secondary] > 0 else 3,"jump":game.sim.zombies.any(func(z): return z.hp > 0 and z.kind == "football" and z.state == "charging" and z.pos.distance_to(p.pos) < 8)}
