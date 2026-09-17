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
var grenade_pitch = 0.0
var grenade_scan = 0.0
var prefer_shotgun = false
var unrestricted = false
var allow_grenades = true
var test_weapon = -1

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
	grenade_scan = maxf(0,grenade_scan-dt)
	var p: Dictionary = game.local_pawn()
	if p.is_empty() or not p.has("primary") or p.hp <= 0: return {}
	var equipped: int = test_weapon if test_weapon >= 0 else p.primary
	if test_weapon < 0 and p.ammo[p.primary]+p.reserves[p.primary] == 0: equipped = p.secondary
	# Release E after any pickup, including a grenade that was selected while
	# turning toward a gun. Holding E cannot consume a second item.
	if p.get("pickup_latched",false): return {}
	if grenade_pending > 0 and p.grenades == grenade_count:
		grenade_pending -= dt
		var aim: Vector2 = grenade_aim-p.pos
		return {"x":0.0,"y":0.0,"yaw":atan2(-aim.x,-aim.y),"pitch":grenade_pitch,"slot":4,"fire":true,"use_self":true}
	grenade_pending = 0.0
	var state: Dictionary = game.sim.campaign_state()
	if state.is_empty() or index >= tasks.size(): return {}
	var goal: Vector2 = tasks[index][0]
	var action: String = tasks[index][1]
	if action.begins_with("medical:") and (p.medkits >= 1 or state.medical_stations[action.trim_prefix("medical:")].remaining <= 0):
		index += 1
		path.clear()
		return {}
	if not allow_grenades and action.begins_with("grenade:"):
		index += 1
		path.clear()
		return {}
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
			var teammates_needing = game.sim.pawns.values().filter(func(other): return other.id != p.id and other.hp > 0 and other.grenades == 0).size()
			advance = station.remaining <= 0 or p.grenades >= 3 or (p.grenades >= 1 and station.remaining <= teammates_needing)
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
	if unrestricted: distance = minf(60,float(Data.weapons[test_weapon if test_weapon >= 0 else p.primary].get("range",30)))
	var enemy_point = Vector2.INF
	var melee_target = true
	var scan_limit = distance
	var best_target_score = INF
	var party_index: int = game.sim.pawns.keys().find(p.id)
	var close_threat = game.sim.zombies.any(func(z): return z.hp > 0 and z.get("guard_awake",true) and z.state != "stunned" and z.pos.distance_to(p.pos) < 4)
	for z in game.sim.zombies:
		var candidate_distance: float = z.pos.distance_to(p.pos)
		if z.hp <= 0 or candidate_distance >= scan_limit: continue
		var candidate_score = candidate_distance
		# Split low-health targets to avoid spending both players' shots on one kill.
		if unrestricted and game.sim.pawns.size() == 2 and candidate_distance > 3 and z.hp <= 300 and z.id%2 != party_index: candidate_score += 4
		if candidate_score >= best_target_score: continue
		if close_threat and z.state == "stunned": continue
		if not unrestricted and game.sim.map_id == "graypine_night" and not z.get("guard_awake",true) and z.pos.distance_to(p.pos) > 7: continue
		var poses: Array = load("res://scripts/enemy_view.gd").transforms(z,game.sim.elapsed,false)
		var point: Vector3 = poses[0].origin
		for part in (0 if prefer_shotgun and Data.weapons[equipped].id in ["shotgun","auto-shotgun"] else Data.parts.size()):
			if Data.parts[part].get("head",false):
				point = poses[part].origin
				break
		var origin = Vector3(p.pos.x,p.height+1.7,p.pos.y)
		if not game.arena.surface_hit(origin,point).is_empty(): continue
		distance = z.pos.distance_to(p.pos)
		best_target_score = candidate_score
		enemy_point = z.pos
		melee_target = z.kind not in ["football","berserker","shield"]
		var aim = point-origin
		yaw = atan2(-aim.x,-aim.z)
		pitch = atan2(aim.y,Vector2(aim.x,aim.z).length())
		fire = true
	if not enemy_point.is_finite(): distance = 1000.0
	if arrived and state.get("loot",[]).any(func(loot): return loot.station == action and not loot.taken) and distance >= 6:
		var choices: Array = state.get("loot",[]).duplicate()
		if unrestricted:
			var ranks = {9:10,8:9,0:8,7:7,4:6,1:5,5:4,3:3,2:2,6:1}
			choices.sort_custom(func(a,b): return ranks.get(a.weapon,0) > ranks.get(b.weapon,0))
		for loot in choices:
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
	var heal: bool = p.hp < (100 if unrestricted and action == "holdout" else 70) and p.medkits > 0 and nearest > (16.0 if unrestricted else 8.0) and action != "finish"
	if arrived and action.begins_with("grenade:") and distance >= 6:
		for item in Layout.ITEMS:
			if item.id == action.trim_prefix("grenade:"):
				var aim: Vector2 = item.pos+Vector2(-1,0)-p.pos
				yaw = atan2(-aim.x,-aim.y)
				pitch = atan2(.65-p.height-preload("res://scripts/player_body.gd").eye_height(p),aim.length())
	if allow_grenades and p.grenades > 0 and grenade_cooldown <= 0 and grenade_scan <= 0 and not heal and p.get("healing","").is_empty():
		grenade_scan = .3
		var choice = choose_grenade(p,state)
		if not choice.is_empty():
			grenade_cooldown = 2.0
			grenade_pending = .8
			grenade_count = p.grenades
			grenade_aim = choice.point
			var aim: Vector2 = grenade_aim-p.pos
			var landing_distance: float = choice.distance
			grenade_pitch = -1.0 if landing_distance < 5 else -.65 if landing_distance < 8 else -.25 if landing_distance < 12 else .05
			if unrestricted and choice.get("close_boss",false): grenade_pitch = -deg_to_rad(85)
			return {"x":0.0,"y":0.0,"yaw":atan2(-aim.x,-aim.y),"pitch":grenade_pitch,"slot":4,"fire":true,"use_self":true}

	if not Data.weapons[equipped].automatic: fire = fire and (not p.trigger if unrestricted else fmod(fire_clock,.2) < .1)
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
	if unrestricted and not heal and p.get("shove_cd",0.0) <= 0 and p.get("shove_gap",0.0) <= 0 and active_nearest < 2.4: shove = true
	# Finish the active axe strike instead of repeatedly cancelling its damage
	# window with a shove. This policy reads the same weapon animation as a player.
	if p.slot == 3 and p.fire_anim > float(Data.weapons[p.weapon].fireDuration)*.34: shove = false
	# With a teammate, retain an automatic primary with ammunition for sustained cover.
	# Repeated axe/gun switches otherwise consume the entire close-range window.
	var keep_primary: bool = unrestricted and game.sim.pawns.size() == 2 and p.primary in [0,8,9] and p.ammo[p.primary]+p.reserves[p.primary] > 0
	if not keep_primary and (not unrestricted or melee_target) and game.sim.map_id == "graypine_night" and distance < (float(Data.weapons[6].range)+.3 if p.slot == 3 else minf(2.2,float(Data.weapons[6].range)-.3)) and not heal:
		return {"x":direction.x*cos(yaw)-direction.y*sin(yaw),"y":direction.x*sin(yaw)+direction.y*cos(yaw),"yaw":yaw,"pitch":0.0,"slot":3,"shove":shove,"fire":not p.trigger if unrestricted else fmod(fire_clock,.3) < .15,"interact":false}
	return {"x":direction.x*cos(yaw)-direction.y*sin(yaw),"y":direction.x*sin(yaw)+direction.y*cos(yaw),"yaw":yaw,"pitch":pitch,"shove":shove,"weapon":equipped,"fire":heal or (fire and not interact),"reload":(p.ammo[p.weapon] == 0 or (nearest > 8 and p.ammo[p.weapon] < Data.weapons[p.weapon].capacity)) if prefer_shotgun else p.ammo[p.weapon] < 5,"interact":interact,"slot":5 if heal or not p.get("healing","").is_empty() else 1 if p.reserve > 0 or p.ammo[p.primary] > 0 else 2 if Data.weapons[p.secondary].get("infiniteReserve",false) or p.reserves[p.secondary] > 0 or p.ammo[p.secondary] > 0 else 3,"jump":game.sim.zombies.any(func(z): return z.hp > 0 and z.kind == "football" and z.state == "charging" and z.pos.distance_to(p.pos) < 8)}


func choose_grenade(p: Dictionary, state: Dictionary) -> Dictionary:
	# No inventory/state mutation: ordinary pickup and throw inputs only.
	# Reserve two for the boss; spend them early only to escape a close emergency.
	var best: Dictionary = {}
	var score = 0.0
	var eye = Vector3(p.pos.x,p.height+1.4,p.pos.y)
	var boss_remaining = not state.get("boss_spawned",false) or game.sim.zombies.any(func(z): return z.hp > 0 and z.kind == "football")
	for z in game.sim.zombies:
		if z.hp <= 0 or not z.get("guard_awake",true): continue
		var distance: float = z.pos.distance_to(p.pos)
		if distance < (.3 if unrestricted and z.kind == "football" else 2.0) or distance > 16: continue
		if not game.arena.surface_hit(eye,Vector3(z.pos.x,1.0,z.pos.y)).is_empty(): continue
		var nearby = game.sim.zombies.filter(func(other): return other.hp > 0 and other.pos.distance_to(z.pos) < 5).size()
		var boss: bool = z.kind == "football"
		if unrestricted and boss_remaining:
			if not boss and p.grenades <= 2: continue
			if boss and (distance > 7 or (p.grenades == 1 and state.get("holdout_time",0) < 30 and (state.party == 1 or p.hp > 40))): continue
		var emergency: bool = distance < 5 and ((nearby >= 4 and p.hp < 40) or (nearby >= 6 and distance < 3.5))
		if not boss and not emergency:
			if boss_remaining and p.grenades <= 2: continue
			if nearby < (4 if state.holdout_started else 7): continue
		# Do not double-bomb a teammate's still-flying grenade.
		if state.get("projectiles",[]).any(func(g): return Vector2(g.pos.x,g.pos.z).distance_to(z.pos) < 7): continue
		var value = float(nearby)+(8.0 if boss else 0.0)
		if value > score:
			score = value
			# Approximate one second of visible approach, not a perfect future-state
			# simulation. The ordinary pitch input still receives aim error.
			var toward_player: Vector2 = (p.pos-z.pos).normalized()
			var forward = Vector2(sin(z.heading),cos(z.heading))
			var closing = maxf(0,forward.dot(toward_player))*float(z.get("move_speed",0))
			best = {"point":z.pos,"distance":maxf(2,distance-minf(6,closing)),"close_boss":boss and distance <= 7}
	return best
