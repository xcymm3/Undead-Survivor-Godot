extends "res://tools/campaign-input-driver.gd"
## Perfect input timing/aim, normal authority, collision, ammunition and cooldowns.
var kite_index = 0
var shotgun_only = false
func _init(current_game, yard: bool) -> void:
	super(current_game,yard)
	unrestricted = true
	prefer_shotgun = true
	tasks.insert(0,[Vector2(-3,71),"night_start"])
	for i in range(tasks.size()-1,-1,-1):
		if tasks[i][1] in ["night_shop","night_van"]:
			var station = tasks[i][1]
			tasks.insert(i+1,[tasks[i][0]+Vector2(1,0),"medical:"+station])

func command(dt: float) -> Dictionary:
	var result = super.command(dt)
	if result.is_empty(): return result
	var p: Dictionary = game.local_pawn()
	var state: Dictionary = game.sim.campaign_state()
	# Enforce comparison equipment before rescue/finish branches can return.
	if shotgun_only and result.get("slot",1) == 2:
		result.slot = 3
		result.weapon = 6
	if test_weapon >= 0 and result.get("slot",1) < 4:
		result.slot = 3 if test_weapon == 6 else 2 if test_weapon in [2,3] else 1
		result.weapon = test_weapon
		if test_weapon == 6: result.fire = not p.trigger
		result.reload = p.ammo[test_weapon] == 0 and not Data.weapons[test_weapon].get("infiniteAmmo",false)
	# Rescue through the same held interaction as a human, only after making space.
	for other in game.sim.pawns.values():
		if not other.get("downed",false) or p.pos.distance_to(other.pos) > 12 or result.get("slot",1) == 5: continue
		if game.sim.zombies.any(func(z): return z.hp > 0 and z.get("guard_awake",true) and z.pos.distance_to(other.pos) < 7): continue
		if p.pos.distance_to(other.pos) < 2:
			result.interact = true
			result.fire = false
			result.x = 0
			result.y = 0
			return result
		var rescue_route: PackedVector2Array = game.arena.path_to(p.pos,other.pos)
		while rescue_route.size() > 1 and p.pos.distance_to(rescue_route[0]) < .5: rescue_route.remove_at(0)
		if not rescue_route.is_empty():
			var move: Vector2 = (rescue_route[0]-p.pos).normalized()
			result.x = move.x*cos(result.yaw)-move.y*sin(result.yaw)
			result.y = move.x*sin(result.yaw)+move.y*cos(result.yaw)
			return result
	if index < tasks.size() and tasks[index][1] == "finish" and state.exit_control and game.sim.pawns.values().all(func(q): return q.get("dead",false) or (not q.get("downed",false) and Layout.EXIT_ROOM.grow(-.5).has_point(q.pos))) and not game.sim.pawns.values().any(func(q): return not q.get("dead",false) and (Layout.EXIT_DOOR.grow(.4).has_point(q.pos) or Rect2(10.1,-57.5,3.8,4).has_point(q.pos))) and not game.sim.zombies.any(func(z): return z.hp > 0 and (Layout.EXIT_ROOM.has_point(z.pos) or Layout.EXIT_DOOR.grow(.4).has_point(z.pos))):
		result.interact = true
		result.fire = false
		result.x = 0
		result.y = 0
		result.jump = false
		return result
	if test_weapon < 0 and result.get("slot",1) < 4:
		result.reload = p.ammo[p.weapon] == 0 or (not result.get("fire",false) and p.ammo[p.weapon] < Data.weapons[p.weapon].capacity)
	# Circle physical cover rather than trying to outrun a faster boss in open space.
	if index < tasks.size() and tasks[index][1] == "defend" and result.get("slot",1) != 5:
		var circuit = [Vector2(8,-52),Vector2(1,-52),Vector2(1,-42),Vector2(8,-42)]
		var goal: Vector2 = Vector2(12,-52) if state.holdout_time >= 26 else circuit[kite_index%circuit.size()]
		if p.pos.distance_to(goal) < .7 and state.holdout_time < 26:
			kite_index += 1
			goal = circuit[kite_index%circuit.size()]
		var route: PackedVector2Array = game.arena.path_to(p.pos,goal)
		while route.size() > 1 and p.pos.distance_to(route[0]) < .5: route.remove_at(0)
		if not route.is_empty():
			var move: Vector2 = (route[0]-p.pos).normalized() if p.pos.distance_to(goal) > .3 else Vector2.ZERO
			result.x = move.x*cos(result.yaw)-move.y*sin(result.yaw)
			result.y = move.x*sin(result.yaw)+move.y*cos(result.yaw)
	# Dodge across a committed charge rather than retreating along its path.
	for z in game.sim.zombies:
		if z.hp <= 0 or z.kind != "football" or z.state != "charging" or z.pos.distance_to(p.pos) > 12: continue
		var end: Vector2 = z.pos+z.charge_direction*12*maxf(z.state_time,0)
		if p.pos.distance_to(Geometry2D.get_closest_point_to_segment(p.pos,z.pos,end)) > 2.5: continue
		var side: Vector2 = z.charge_direction.orthogonal()
		var best = -INF
		var dodge = Vector2.ZERO
		for dir in [side,-side]:
			var candidate: Vector2 = p.pos+dir*2.5
			if not game.arena.endpoint_link(p.pos,candidate): continue
			var score = candidate.distance_to(Geometry2D.get_closest_point_to_segment(candidate,z.pos,end))
			if state.exit_control: score -= candidate.distance_to(Layout.EXIT)*.1
			if score > best:
				best = score
				dodge = dir
		if best > -INF and result.get("slot",1) != 5:
			result.x = dodge.x*cos(result.yaw)-dodge.y*sin(result.yaw)
			result.y = dodge.x*sin(result.yaw)+dodge.y*cos(result.yaw)
	if index < tasks.size() and str(tasks[index][1]).begins_with("medical:"):
		var point: Vector2 = tasks[index][0]
		if p.pos.distance_to(point) < .55:
			result.interact = p.medkits == 0
			result.fire = false
	return result
