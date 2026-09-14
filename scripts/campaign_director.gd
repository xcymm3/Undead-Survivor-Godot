extends RefCounted
const Layout = preload("res://scripts/campaign_layout.gd")
var owner_ref: WeakRef
var sim:
	get: return owner_ref.get_ref()
var state = {"shop_key":false,"shop_open":false,"pump_ready":false,"power_ready":false,"milestones":{},"phase":"PREPARE","departed":false,"gate_open":false,"complete":false,"bridge_time":0.0,"taken":{},"claimed":{},"objective":"在值班室选择主武器，E 开门出发","party":1,"zones":{},"rest_until":0.0,"pressure_until":0.0,"relief_ready":0.0,"elite_cancelled":false}
var credit = 0.0
var bridge_window = -1
var bridge_spawned = 0
var elite_spawned = false
var bridge_imps = 0
var previous_party = 1
var revived_this_step: Dictionary = {}
var cue_at = -1

func _init(world) -> void:
	owner_ref = weakref(world)
	state.party = world.pawns.size()
	previous_party = state.party
	for p in world.pawns.values():
		p.reserve = 5*int(Data.weapons[0].capacity)
		p.primary = 0
		p.medkits = 1
		p.downed = false
		p.dead = false
		p.bleed = 0.0
		p.revives = 0
		p.interaction = ""
		p.interact_time = 0.0
		p.hint = "1—0 选主武器 · E 开门 · H 治疗"
		p.hurt_at = -100.0
		p.action_hurt = -100.0
		p.ammo.fill(0)
		p.ammo[0] = int(Data.weapons[0].capacity)
	world.arena.sync_campaign(state)

func survivors() -> Array:
	return sim.pawns.values().filter(func(p): return not p.get("dead",false))

func standing() -> Array:
	return sim.pawns.values().filter(func(p): return p.hp > 0)

func phase(value: String, objective: String) -> void:
	state.phase = value
	state.objective = objective

func multiply() -> float:
	return [1.0,1.5,1.9,2.3][clampi(state.party-1,0,3)]

func cap() -> int:
	return [18,28,36,44][clampi(state.party-1,0,3)]

func start_room_ready() -> bool:
	return survivors().all(func(p): return Layout.START_ROOM.has_point(p.pos))

func near(p: Dictionary, point: Vector2, distance := 2.0) -> bool:
	if p.pos.distance_to(point) > distance: return false
	return sim.arena.surface_hit(Vector3(p.pos.x,p.height+1.1,p.pos.y),Vector3(point.x,p.height+1.1,point.y)).is_empty()

func target(p: Dictionary) -> Dictionary:
	if state.departed and not state.shop_key and near(p,Layout.SHOP):
		return {"id":"key","label":"取出岗亭检修钥匙","seconds":1.0}
	if state.shop_key and not state.shop_open and near(p,Layout.STREET_PANEL):
		return {"id":"shop","label":"解锁街道检修通道","seconds":2.0}
	if state.gate_open and not state.pump_ready and near(p,Layout.PUMP):
		return {"id":"pump","label":"复位泵房断路器","seconds":3.0}
	if state.pump_ready and not state.power_ready and near(p,Layout.VALVE):
		return {"id":"power","label":"恢复安全屋门供电","seconds":3.0}
	for other in sim.pawns.values():
		if other.id != p.id and other.get("downed",false) and near(p,other.pos):
			return {"id":"revive:"+other.id,"label":"救起 "+other.name,"seconds":4.0}
	if not state.departed and p.pos.distance_to(Vector2(0,110.5)) < 2.4:
		return {"id":"depart","label":"开门出发" if start_room_ready() else "等待全员进入值班室","seconds":1.0}
	if state.phase == "BRIDGE_READY" and p.pos.distance_to(Layout.CONTROL) < 2.2:
		return {"id":"winch","label":"启动卷扬机","seconds":2.0}
	if state.gate_open and Layout.EXIT_ROOM.has_point(p.pos):
		return {"id":"finish","label":finish_label(),"seconds":1.0}
	for item in Layout.ITEMS:
		if item.get("party",1) > state.party or not near(p,item.pos): continue
		if item.kind == "med":
			if not state.taken.has(item.id) and p.medkits < 1: return {"id":item.id,"label":"领取医疗包","seconds":.25}
		elif not state.claimed.get(item.id,[]).has(p.id) and p.reserve < 6*int(Data.weapons[p.primary].capacity):
			return {"id":item.id,"label":"领取弹药","seconds":.25}
	return {}

func finish_label() -> String:
	if not state.power_ready: return "先检修泵房与东侧阀站，恢复门供电"
	var alive = survivors()
	var inside = alive.filter(func(p): return Layout.EXIT_ROOM.grow(-.5).has_point(p.pos) and not p.downed)
	if inside.size() != alive.size(): return "等待队友 %d/%d" % [inside.size(),alive.size()]
	if sim.zombies.any(func(z): return z.hp > 0 and Layout.EXIT_ROOM.has_point(z.pos)): return "清除安全屋内敌人"
	if sim.pawns.values().any(func(p): return not p.dead and Layout.EXIT_DOOR.grow(.4).has_point(p.pos)) or sim.zombies.any(func(z): return z.hp > 0 and Layout.EXIT_DOOR.grow(.4).has_point(z.pos)): return "门口被占用"
	return "关闭安全屋门，完成本关"

func interactions(dt: float) -> void:
	revived_this_step.clear()
	for p in sim.pawns.values():
		if p.hp <= 0:
			p.interaction = ""
			p.interact_time = 0.0
			continue
		var input: Dictionary = p.input if p.input_age < .5 else {}
		var choice = target(p)
		p.hint = "E "+choice.label if not choice.is_empty() else "H 治疗" if p.medkits > 0 and p.hp < 100 else "前往泵站避难点"
		if input.get("heal",false) and p.medkits > 0 and p.hp < 100: choice = {"id":"heal","label":"包扎伤口","seconds":3.0}
		elif not input.get("interact",false): choice = {}
		if choice.is_empty() or p.hurt_at > p.action_hurt and p.interaction != "":
			p.interaction = ""
			p.interact_time = 0.0
			p.action_hurt = p.hurt_at
			continue
		if p.interaction != choice.id:
			p.interaction = choice.id
			p.interact_time = 0.0
			p.action_hurt = p.hurt_at
		p.interact_time += dt
		p.hint = "%s %.1f/%.1f 秒" % [choice.label,p.interact_time,choice.seconds]
		if choice.id.begins_with("revive:"): revived_this_step[choice.id.trim_prefix("revive:")] = true
		if p.interact_time >= choice.seconds:
			perform(p,choice.id)
			p.interaction = ""
			p.interact_time = 0.0
	for p in sim.pawns.values():
		if p.downed and not revived_this_step.has(p.id):
			p.bleed = maxf(0,p.bleed-dt)
			if p.bleed <= 0:
				p.downed = false
				p.dead = true

func perform(p: Dictionary, id: String) -> void:
	if id == "key" and state.departed and not state.shop_key and near(p,Layout.SHOP):
		state.shop_key = true
		state.milestones.key = sim.elapsed
		phase("STREET","钥匙已取得，前往东侧岗亭解锁检修通道")
	elif id == "shop" and state.shop_key and not state.shop_open and near(p,Layout.STREET_PANEL):
		state.shop_open = true
		state.milestones.shop = sim.elapsed
		phase("STREET","检修通道已开，穿过街道前往河桥")
		sim.arena.sync_campaign(state)
	elif id == "pump" and state.gate_open and not state.pump_ready and near(p,Layout.PUMP):
		state.pump_ready = true
		state.milestones.pump = sim.elapsed
		phase("FINAL_APPROACH","前往东侧阀站恢复安全屋门供电")
	elif id == "power" and state.pump_ready and not state.power_ready and near(p,Layout.VALVE):
		state.power_ready = true
		state.milestones.power = sim.elapsed
		phase("FINAL_APPROACH","供电恢复，撤入泵站安全屋并关门")
		sim.arena.sync_campaign(state)
	elif id == "depart" and not state.departed and start_room_ready():
		state.departed = true
		sim.elapsed = 0.0
		phase("STREET","沿街道进入西侧商铺，解锁检修通道")
		sim.arena.sync_campaign(state)
	elif id == "winch" and state.phase == "BRIDGE_READY":
		state.milestones.bridge_start = sim.elapsed
		phase("BRIDGE_ACTIVE","守住桥头，等待检修闸门打开")
		sim.events.append({"kind":"campaign_cue","cue":"winch","position":Vector3(8,1,-16)})
	elif id == "finish" and state.gate_open and finish_label() == "关闭安全屋门，完成本关":
		state.complete = true
		phase("COMPLETE","灰松渡口完成 · 全队抵达泵站")
		sim.arena.sync_campaign(state)
	elif id == "heal" and p.medkits > 0:
		p.medkits -= 1
		p.hp = mini(100,p.hp+50)
	elif id.begins_with("revive:"):
		var other: Dictionary = sim.pawns.get(id.trim_prefix("revive:"),{})
		if not other.is_empty() and other.downed and near(p,other.pos):
			other.downed = false
			other.hp = 30
			other.revives += 1
			other.protection = 1.0
	else:
		for item in Layout.ITEMS:
			if item.id != id or not near(p,item.pos): continue
			if item.kind == "med" and not state.taken.has(id) and p.medkits < 1:
				state.taken[id] = true
				p.medkits += 1
			elif item.kind == "ammo" and not state.claimed.get(id,[]).has(p.id):
				if not state.claimed.has(id): state.claimed[id] = []
				state.claimed[id].append(p.id)
				p.reserve = mini(6*int(Data.weapons[p.primary].capacity),p.reserve+2*int(Data.weapons[p.primary].capacity))

func damage(p: Dictionary) -> void:
	p.hurt_at = sim.elapsed
	if p.hp > 0: return
	p.downed = state.party > 1 and p.revives < 2
	p.dead = not p.downed
	p.bleed = 30.0 if p.downed else 0.0

func choose_weapon(p: Dictionary, requested: int) -> int:
	if not state.departed and requested != 6 and requested != p.primary:
		p.primary = requested
		p.ammo.fill(0)
		p.ammo[requested] = int(Data.weapons[requested].capacity)
		p.reserve = 5*int(Data.weapons[requested].capacity)
	return requested if requested in [p.primary,6] else p.primary

func safe_point(point: Vector2) -> bool:
	if not sim.arena.clear(point,point) or Layout.water(point) or Layout.START_ROOM.has_point(point) or Layout.EXIT_ROOM.has_point(point): return false
	for p in survivors():
		var delta: Vector2 = point-p.pos
		if delta.length() < 12: return false
		var forward = Vector2(-sin(p.yaw),-cos(p.yaw))
		if forward.dot(delta.normalized()) > .35:
			if sim.arena.surface_hit(Vector3(p.pos.x,p.height+1.7,p.pos.y),Vector3(point.x,1.2,point.y)).is_empty(): return false
	if sim.zombies.any(func(z): return z.hp > 0 and z.pos.distance_to(point) < 1.5): return false
	return standing().any(func(p): return not sim.arena.path_to(point,p.pos).is_empty())

func spawn_one(points: Array, kind: String) -> bool:
	if sim.alive_count() >= cap() or credit < 1: return false
	var candidates = points.duplicate()
	# Authority RNG is also used for candidate order; QA can reproduce the seed.
	for i in candidates.size():
		var other = sim.random.randi_range(i,candidates.size()-1)
		var swap = candidates[i]
		candidates[i] = candidates[other]
		candidates[other] = swap
	for point in candidates:
		if safe_point(point):
			sim.spawn(point,kind)
			credit = 0.0
			return true
	return false

func step(dt: float) -> void:
	if state.complete or sim.failed: return
	state.party = mini(state.party,sim.pawns.size())
	interactions(dt)
	if state.complete: return
	if not state.departed: return
	var living = standing()
	if living.is_empty(): return
	var average = 0.0
	for p in living: average += p.hp/float(living.size())
	if sim.elapsed >= state.relief_ready and (average < 35 or survivors().any(func(p): return p.downed)):
		state.pressure_until = sim.elapsed+8
		state.relief_ready = sim.elapsed+25
		state.elite_cancelled = true
	credit = minf(1,credit+dt*[1.0,1.5,1.9,2.3][clampi(state.party-1,0,3)])
	if state.phase == "STREET" and living.any(func(p): return p.pos.y < 5): phase("BRIDGE_READY","到桥头按住 E 启动卷扬机")
	if state.phase == "BRIDGE_ACTIVE":
		state.bridge_time = minf(90,state.bridge_time+dt)
		var t: float = state.bridge_time
		var window = 0 if t >= 5 and t < 30 else 1 if t >= 40 and t < 65 else 2 if t >= 75 and t < 90 else -1
		if window != bridge_window:
			bridge_window = window
			bridge_spawned = 0
			state.elite_cancelled = sim.elapsed < state.pressure_until
		if window >= 0 and cue_at != window:
			cue_at = window
			sim.events.append({"kind":"campaign_cue","cue":"horde","position":Vector3(8,1,-16)})
		if window >= 0 and sim.elapsed >= state.pressure_until:
			var budget = roundi([16,20,12][window]*multiply())
			if bridge_spawned < budget:
				var kind = "normal"
				if window == 1 and bridge_spawned % 6 == 4 and bridge_imps < 4: kind = "imp"
				if window == 1 and t >= 47 and not elite_spawned and not state.elite_cancelled: kind = "football"
				if spawn_one(Layout.BRIDGE_POINTS,kind):
					bridge_spawned += 1
					if kind == "football": elite_spawned = true
					if kind == "imp": bridge_imps += 1
		if t >= 90:
			state.milestones.bridge_end = sim.elapsed
			state.gate_open = true
			phase("GATE_OPEN","穿过北岸闸门，前往工具棚休整")
			sim.paths.clear()
			sim.events.append({"kind":"campaign_cue","cue":"gate","position":Vector3(0,2,-57)})
			sim.arena.sync_campaign(state)
	if state.phase == "GATE_OPEN" and survivors().all(func(p): return p.pos.y < -60):
		state.rest_until = sim.elapsed+25
		phase("FINAL_APPROACH","补充物资，沿服务路进入西侧泵房检修")
	# Rest belongs to the shed approach, not the whole remaining route.
	# The leading player commits the party to the final encounter; returning
	# to the shed must not restart the timer or replenish encounter budgets.
	if state.gate_open and (state.zones.has("final") or living.any(func(p): return p.pos.y < -82)):
		state.rest_until = 0.0
	if state.phase != "BRIDGE_ACTIVE" and sim.elapsed >= state.pressure_until and sim.elapsed >= state.rest_until:
		for zone in Layout.ZONES:
			if zone.id == "final" and not state.gate_open: continue
			if not state.zones.has(zone.id):
				if not living.any(func(p): return zone.rect.has_point(p.pos)): continue
				state.zones[zone.id] = {"spawned":0,"until":sim.elapsed+40,"kinds":{}}
			var progress: Dictionary = state.zones[zone.id]
			if sim.elapsed > progress.until or progress.spawned >= roundi(zone.budget*multiply()): continue
			# Fixed rare-kind limits do not multiply with player count.
			var kind: String = zone.kinds[progress.spawned%zone.kinds.size()]
			var limit: int = {"shield":1,"bucket":1 if zone.id == "drain" else 2,"imp":2,"cone":2 if zone.id == "yard" else 999}.get(kind,999)
			if progress.kinds.get(kind,0) >= limit: kind = "normal"
			if spawn_one(zone.points,kind):
				progress.spawned += 1
				progress.kinds[kind] = progress.kinds.get(kind,0)+1
	sim.arena.scenery.sync(state)

func snapshot() -> Dictionary:
	return state.duplicate(true)
