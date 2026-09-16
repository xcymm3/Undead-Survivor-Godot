extends RefCounted
## QA input policy only. Does not mutate pawns, enemies, inventory or director state.
var Layout = preload("res://scripts/night_layout.gd")
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
var prefer_shotgun = false

func _init(current_game, _yard: bool) -> void:
	game = current_game
	Layout = preload("res://scripts/night_layout.gd")
	tasks = [[Vector2(-3.7,72.3),"grenade:night_start"],[Vector2(0,66.5),"depart"]]
	for point in Layout.ROUTE.slice(1):
		if point == Layout.EXIT: tasks.append_array([[Layout.HOLDOUT,"holdout"],[Layout.HOLDOUT,"defend"]])
		tasks.append([point,"finish" if point == Layout.EXIT else ""])
		if point == Vector2(-9,21): tasks.append_array([[Vector2(-14,25),"night_shop"],[Vector2(-15,26.3),"grenade:night_shop"]])
		if point == Vector2(-6,-34): tasks.append_array([[Vector2(-12,-32),"night_van"],[Vector2(-13,-30.7),"grenade:night_van"]])


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
	# Supplies are optional on the escape route. A wounded, armed test pawn must
	# not repeatedly walk back into a surrounded pickup instead of seeking safety.
	if game.sim.map_id == "graypine_night" and state.departed and action not in ["","depart","finish","holdout","defend"] and p.hp < 75 and p.ammo[p.primary]+p.reserve > int(Data.weapons[p.primary].capacity):
		if game.sim.zombies.any(func(z): return z.hp > 0 and z.get("guard_awake",true) and z.pos.distance_to(p.pos) < 7):
			index += 1
			path.clear()
			return {}
	var arrived = p.pos.distance_to(goal) < .55
	var interact = false
	var advance = false
	if action == "defend":
		advance = state.exit_control
		# Separate teammates and use a wider loop so the horde cannot cut across
		# the entire defensive route. These remain ordinary movement inputs.
		angle += dt*.45
		var offset = float(str(p.id).hash() % 628)/100.0
		goal = Layout.HOLDOUT+Vector2(cos(angle+offset)*3.0,3.5+sin(angle+offset)*2.0)
	elif arrived:
		interact = action != ""
		if action == "": advance = true
		elif action == "depart": advance = state.departed
		elif action == "holdout": advance = state.holdout_started
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
	var distance = 14.0 if game.sim.map_id == "graypine_night" else 32.0
	var enemy_point = Vector2.INF
	var close_threat = game.sim.zombies.any(func(z): return z.hp > 0 and z.get("guard_awake",true) and z.state != "stunned" and z.pos.distance_to(p.pos) < 4)
	for z in game.sim.zombies:
		if z.hp <= 0 or z.pos.distance_to(p.pos) >= distance: continue
		if close_threat and z.state == "stunned": continue
		if game.sim.map_id == "graypine_night" and not z.get("guard_awake",true) and z.pos.distance_to(p.pos) > 7: continue
		var poses: Array = load("res://scripts/enemy_view.gd").transforms(z,game.sim.elapsed,false)
		var point: Vector3 = poses[0].origin
		for part in (0 if prefer_shotgun and Data.weapons[p.primary].id in ["shotgun","auto-shotgun"] else Data.parts.size()):
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
	if arrived and state.get("loot",[]).any(func(loot): return loot.station == action and not loot.taken) and distance >= 6:
		for loot in state.get("loot",[]):
			if loot.station == action and not loot.taken:
				var aim: Vector2 = loot.pos-p.pos
				yaw = atan2(-aim.x,-aim.y)
				pitch = atan2(loot.mount_height-p.height-preload("res://scripts/player_body.gd").eye_height(p),aim.length())
				break
	# A threatened bot must keep fighting instead of repeatedly interrupting
	# its own three-second heal until the whole party goes down.
	var nearest = 1000.0
	var active_nearest = 1000.0
	for z in game.sim.zombies:
		if z.hp > 0 and z.get("guard_awake",true):
			nearest = minf(nearest,z.pos.distance_to(p.pos))
			if z.state != "stunned": active_nearest = minf(active_nearest,z.pos.distance_to(p.pos))
	var heal: bool = p.hp < 70 and p.medkits > 0 and nearest > 8.0
	if arrived and action.begins_with("grenade:") and distance >= 6:
		for item in Layout.ITEMS:
			if item.id == action.trim_prefix("grenade:"):
				var aim: Vector2 = item.pos+Vector2(-1,0)-p.pos
				yaw = atan2(-aim.x,-aim.y)
				pitch = atan2(.65-p.height-preload("res://scripts/player_body.gd").eye_height(p),aim.length())
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
	# Once unlocked, enter and close the shelter instead of clearing the outdoor horde.
	if action == "finish" and game.sim.zombies.any(func(z): return z.hp > 0 and (Layout.EXIT_ROOM.has_point(z.pos) or Layout.EXIT_DOOR.grow(.4).has_point(z.pos))): interact = false
	if distance < 6 and action != "finish": interact = false
	if active_nearest < 3.5 and enemy_point.is_finite() and not (action == "finish" and state.exit_control):
		var away = (p.pos-enemy_point).normalized()
		for candidate in [away,away.rotated(PI/2),away.rotated(-PI/2)]:
			if game.arena.endpoint_link(p.pos,p.pos+candidate*2) and game.sim.can_move(p,p.pos+candidate*.3):
				direction = candidate
				interact = false
				break
	var crowd = game.sim.zombies.filter(func(z): return z.hp > 0 and z.state != "stunned" and z.pos.distance_to(p.pos) < 3.0).size()
	var shove: bool = not heal and p.get("shove_cd",0.0) <= 0 and p.get("shove_gap",0.0) <= 0 and game.sim.zombies.any(func(z): return z.hp > 0 and z.state != "stunned" and z.pos.distance_to(p.pos) < 3.0 and (z.attack_time > 0 or p.reloading or (crowd >= 3 and nearest < 2.8)) and Vector2(-sin(yaw),-cos(yaw)).dot((z.pos-p.pos).normalized()) > .6)
	# Finish the active axe strike instead of repeatedly cancelling its damage
	# window with a shove. This policy reads the same weapon animation as a player.
	if p.slot == 3 and p.fire_anim > float(Data.weapons[p.weapon].fireDuration)*.34: shove = false
	if game.sim.map_id == "graypine_night" and distance < (3.8 if p.slot == 3 else 2.2) and not heal:
		return {"x":direction.x*cos(yaw)-direction.y*sin(yaw),"y":direction.x*sin(yaw)+direction.y*cos(yaw),"yaw":yaw,"pitch":0.0,"slot":3,"shove":shove,"fire":fmod(fire_clock,.3) < .15,"interact":false}
	return {"x":direction.x*cos(yaw)-direction.y*sin(yaw),"y":direction.x*sin(yaw)+direction.y*cos(yaw),"yaw":yaw,"pitch":pitch,"shove":shove,"weapon":6 if p.reserve == 0 and p.ammo[p.primary] == 0 else p.primary,"fire":heal or (fire and not interact),"reload":(p.ammo[p.weapon] == 0 or (nearest > 8 and p.ammo[p.weapon] < Data.weapons[p.weapon].capacity)) if prefer_shotgun else p.ammo[p.weapon] < 5,"interact":interact,"slot":5 if heal or not p.get("healing","").is_empty() else 1 if p.reserve > 0 or p.ammo[p.primary] > 0 else 2 if p.reserves[p.secondary] > 0 or p.ammo[p.secondary] > 0 else 3,"jump":game.sim.zombies.any(func(z): return z.hp > 0 and z.kind == "football" and z.state == "charging" and z.pos.distance_to(p.pos) < 8)}
