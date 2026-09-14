extends RefCounted
const Layout = preload("res://scripts/campaign_layout.gd")
const Objectives = preload("res://scripts/campaign_objectives.gd")
var owner_ref: WeakRef
var sim:
	get: return owner_ref.get_ref()
var state = {"shop_key":false,"shop_open":false,"leak_closed":false,"pump_ready":false,"power_ready":false,"milestones":{},"late_stage":false,"phase":"PREPARE","departed":false,"gate_open":false,"complete":false,"bridge_time":0.0,"taken":{},"claimed":{},"objective":"检查装备，E 开门出发","party":1,"zones":{},"rest_until":0.0,"pressure_until":0.0,"relief_ready":0.0,"elite_cancelled":false}
var equipment
var initial_seed = 0
var reinforcement_batches: Array = []
var credit = 0.0
var revived_this_step: Dictionary = {}
var damage_log: Array = []
var casualties: Array = []
var damage_totals: Dictionary = {}
var guard_counts: Dictionary = {}
var guidance_until = 0.0
var report_path = "user://campaign-diagnostics-%d-%d.json" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec()]

func _init(world) -> void:
	owner_ref = weakref(world)
	state.party = world.pawns.size()
	for objective in Objectives.NODES: state[objective.id] = false
	initial_seed = world.random.seed
	for p in world.pawns.values():
		p.primary = 1
		p.weapon = p.primary
		p.requested = p.primary
		p.reserve = 5*int(Data.weapons[p.primary].capacity)
		p.medkits = 1
		p.downed = false
		p.dead = false
		p.bleed = 0.0
		p.revives = 0
		p.interaction = ""
		p.interact_time = 0.0
		p.hint = "1 主武器 · 2 副武器 · 3 斧 · 4 手雷 · 5 医疗包"
		p.hurt_at = -100.0
		p.action_hurt = -100.0
		p.ammo.fill(0)
		p.ammo[p.primary] = int(Data.weapons[p.primary].capacity)
	equipment = preload("res://scripts/campaign_equipment.gd").new(self)
	equipment.initialize()
	world.arena.sync_campaign(state)
	for guard in Layout.GUARDS:
		world.spawn(guard.pos,guard.kind)
		world.zombies[-1]["guard_awake"] = false
		guard_counts[guard.zone] = guard_counts.get(guard.zone,0)+1
	populate_route()

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
	return ([18,28,36,44] if state.late_stage else [10,16,22,28])[clampi(state.party-1,0,3)]

func start_room_ready() -> bool:
	return survivors().all(func(p): return Layout.START_ROOM.has_point(p.pos))

func near(p: Dictionary, point: Vector2, distance := 2.0) -> bool:
	if p.pos.distance_to(point) > distance: return false
	return sim.arena.surface_hit(Vector3(p.pos.x,p.height+1.1,p.pos.y),Vector3(point.x,p.height+1.1,point.y)).is_empty()

func target(p: Dictionary) -> Dictionary:
	for objective in Objectives.NODES:
		if Objectives.available(objective,state) and near(p,objective.pos): return {"id":objective.id,"label":objective.label,"seconds":objective.seconds}
	if state.departed and not state.shop_key and near(p,Layout.SHOP):
		return {"id":"key","label":"取出岗亭检修钥匙","seconds":1.0}
	if state.loading_power and not state.shop_open and near(p,Layout.STREET_PANEL):
		return {"id":"shop","label":"解锁街道检修通道","seconds":2.0}
	if state.gate_open and not state.leak_closed and near(p,Layout.LEAK):
		return {"id":"leak","label":"关闭泄漏隔离阀","seconds":2.0}
	if state.gate_open and state.pump_fault_b and not state.pump_ready and near(p,Layout.PUMP):
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
	return equipment.pickup_target(p)

func finish_label() -> String:
	if not state.power_ready: return "先检修泵房与东侧阀站，恢复门供电"
	if not state.exit_control: return "穿过维修通道，恢复继电器并操作门控台"
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
		if not input.get("interact",false): p.pickup_latched = false
		var choice = target(p)
		p.hint = "E "+choice.label if not choice.is_empty() else p.get("route_hint",state.objective)
		if p.slot == 5: p.hint = "左键治疗自己 · 右键治疗瞄准的近处队友"
		if not p.healing.is_empty(): p.hint = "治疗中 · 无法行动 %.1f / 3 秒" % p.heal_time
		if not input.get("interact",false) or not p.healing.is_empty() or p.being_healed or p.pickup_latched: choice = {}
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
				record_casualty(p,"bleed_out")

func perform(p: Dictionary, id: String) -> void:
	for objective in Objectives.NODES:
		if objective.id == id:
			if not Objectives.available(objective,state) or not near(p,objective.pos): return
			state[id] = true
			state.milestones[id] = sim.elapsed
			state.objective = objective.label+" · 完成，沿路线前往下一目标"
			sim.arena.sync_campaign(state)
			return
	if id == "key" and state.departed and not state.shop_key and near(p,Layout.SHOP):
		state.shop_key = true
		state.milestones.key = sim.elapsed
		phase("STREET","前往商铺后方卸货区，恢复出口供电")
	elif id == "shop" and state.loading_power and not state.shop_open and near(p,Layout.STREET_PANEL):
		state.shop_open = true
		state.milestones.shop = sim.elapsed
		phase("STREET","检修通道已开，穿过街道前往河桥")
		sim.arena.sync_campaign(state)
	elif id == "leak" and state.gate_open and not state.leak_closed and near(p,Layout.LEAK):
		state.leak_closed = true
		state.milestones.leak = sim.elapsed
		phase("FINAL_APPROACH","隔离阀已关闭，前往西侧维修工位处理两处故障")
	elif id == "pump" and state.gate_open and state.pump_fault_b and not state.pump_ready and near(p,Layout.PUMP):
		state.pump_ready = true
		state.milestones.pump = sim.elapsed
		phase("FINAL_APPROACH","前往东侧阀站恢复安全屋门供电")
	elif id == "power" and state.pump_ready and not state.power_ready and near(p,Layout.VALVE):
		state.power_ready = true
		state.milestones.power = sim.elapsed
		phase("FINAL_APPROACH","供电恢复，穿过维修通道操作继电器与门控台")
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
		save_diagnostics()
		sim.arena.sync_campaign(state)
	elif id.begins_with("revive:"):
		var other: Dictionary = sim.pawns.get(id.trim_prefix("revive:"),{})
		if not other.is_empty() and other.downed and near(p,other.pos):
			other.downed = false
			other.hp = 30
			other.revives += 1
			other.protection = 1.0
	else:
		if equipment.pickup(p,id): return
		for item in Layout.ITEMS:
			if item.id != id or not near(p,item.pos): continue
			if item.kind == "med" and not state.taken.has(id) and p.medkits < 1:
				state.taken[id] = true
				p.medkits += 1
			p.pickup_latched = true

func diagnostics() -> Dictionary:
	return {"seed":initial_seed,"seconds":sim.elapsed,"phase":state.phase,"milestones":state.milestones.duplicate(true),"damage_totals":damage_totals.duplicate(true),"grenades":equipment.grenade_history.duplicate(true),"recent_damage":damage_log.duplicate(true),"casualties":casualties.duplicate(true),"reinforcements":reinforcement_batches.duplicate(true),"population":state.zones.duplicate(true),"failed":sim.failed,"won":state.complete}

func save_diagnostics() -> void:
	var file = FileAccess.open(report_path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(diagnostics(),"  "))
	else: push_error("Cannot write campaign diagnostics: "+report_path)

func record_casualty(p: Dictionary, outcome: String) -> void:
	casualties.append({"player":p.id,"outcome":outcome,"seconds":sim.elapsed,"phase":state.phase,"zones":Layout.ZONES.filter(func(zone): return zone.rect.has_point(p.pos)).map(func(zone): return zone.id),"position":[p.pos.x,p.pos.y],"hp":p.hp,"ammo":p.ammo[p.primary],"reserve":p.reserve,"secondary":p.secondary,"secondary_reserve":p.reserves[p.secondary],"grenades":p.grenades,"healing":p.healing,"medkits":p.medkits,"nearby_enemies":sim.zombies.filter(func(z): return z.hp > 0 and z.pos.distance_to(p.pos) < 10).size(),"last_hit":p.get("last_damage",{}).duplicate(true)})
	save_diagnostics()

func guidance(p: Dictionary) -> String:
	var goal: Vector2 = Layout.SHOP
	var label = "商铺钥匙"
	if not state.departed:
		goal = Vector2(0,111)
		label = "出发门"
	elif state.power_ready:
		goal = Layout.EXIT
		label = "终点安全屋"
	elif state.pump_ready:
		goal = Layout.VALVE
		label = "东侧供电控制台"
	elif state.gate_open:
		goal = Layout.PUMP if state.leak_closed else Layout.LEAK
		label = "泵房断路器" if state.leak_closed else "泵房隔离阀"
	elif state.shop_open:
		goal = Vector2(0,-62) if state.phase == "GATE_OPEN" else Layout.CONTROL
		label = "河桥控制台"
	elif state.shop_key:
		goal = Layout.STREET_PANEL
		label = "东侧检修岗亭"
	if state.phase == "BRIDGE_ACTIVE": return "守住桥头 · 等待闸门开启"
	for objective in Objectives.NODES:
		if Objectives.available(objective,state):
			goal = objective.pos
			label = objective.label
			break
	var route = sim.arena.path_to(p.pos,goal)
	var next_point: Vector2 = goal
	for point in route:
		if p.pos.distance_to(point) > 1.5:
			next_point = point
			break
	var delta: Vector2 = next_point-p.pos
	var angle = wrapf(atan2(-delta.x,-delta.y)-p.yaw,-PI,PI)
	var direction = "前方" if absf(angle) < PI/4 else "后方" if absf(angle) > PI*.75 else "左侧" if angle > 0 else "右侧"
	return "%s · %s · 直线 %.0f 米" % [label,direction,p.pos.distance_to(goal)]

func damage(p: Dictionary, z: Dictionary, amount: int) -> void:
	p.hurt_at = sim.elapsed
	var source = str(z.original)
	damage_totals[source] = damage_totals.get(source,0)+amount
	var hit = {"player":p.id,"seconds":sim.elapsed,"phase":state.phase,"zones":Layout.ZONES.filter(func(zone): return zone.rect.has_point(p.pos)).map(func(zone): return zone.id),"position":[p.pos.x,p.pos.y],"enemy_id":z.id,"enemy_kind":source,"attack":z.state,"damage":amount,"hp_after":p.hp,"role":"guard" if z.has("guard_awake") else "horde"}
	p["last_damage"] = hit
	damage_log.append(hit)
	if damage_log.size() > 256: damage_log.pop_front()
	if p.hp > 0: return
	p.downed = state.party > 1 and p.revives < 2
	p.dead = not p.downed
	p.bleed = 30.0 if p.downed else 0.0
	record_casualty(p,"downed" if p.downed else "dead")

func choose_weapon(p: Dictionary, _requested: int) -> int:
	return p.primary if p.slot == 1 else p.secondary if p.slot == 2 else 6

func populate_route() -> void:
	# Entire baseline population is placed before departure; no zone arrival spawning.
	for zone in Layout.ZONES:
		var wanted = roundi(zone.budget*multiply())
		var count: int = guard_counts.get(zone.id,0)
		var kind_counts: Dictionary = {}
		for guard in Layout.GUARDS:
			if guard.zone == zone.id: kind_counts[guard.kind] = kind_counts.get(guard.kind,0)+1
		var candidates: Array = []
		for x in range(ceili(zone.rect.position.x)+2,floori(zone.rect.end.x)-1,3):
			for y in range(ceili(zone.rect.position.y)+2,floori(zone.rect.end.y)-1,3): candidates.append(Vector2(x,y))
		for i in candidates.size():
			var j = sim.random.randi_range(i,candidates.size()-1)
			var temp = candidates[i]
			candidates[i] = candidates[j]
			candidates[j] = temp
		for point in candidates:
			if count >= wanted: break
			if not sim.arena.clear(point,point) or Layout.water(point) or Layout.START_ROOM.grow(3).has_point(point) or Layout.EXIT_ROOM.grow(1).has_point(point) or Layout.SHED_REST_AREA.has_point(point): continue
			if sim.zombies.any(func(z): return z.pos.distance_to(point) < 1.8): continue
			var kind: String = zone.kinds[count%zone.kinds.size()]
			# Early encounters contain only ordinary and a few cone enemies.
			var limit: int = {"cone":2 if zone.rect.position.y > -60 else 999,"bucket":3,"shield":2}.get(kind,999)
			if kind_counts.get(kind,0) >= limit: kind = "normal"
			kind_counts[kind] = kind_counts.get(kind,0)+1
			sim.spawn(point,kind)
			sim.zombies[-1]["guard_awake"] = false
			count += 1
		state.zones[zone.id] = {"preplaced":count,"requested":wanted}
		if count < wanted: push_warning("Preplaced population shortfall in "+zone.id+": "+str(count)+"/"+str(wanted))

func queue_batch(id: String, count: int, kinds: Array) -> void:
	if reinforcement_batches.any(func(batch): return batch.id == id): return
	var roster: Array = []
	for i in roundi(count*multiply()): roster.append(kinds[i%kinds.size()])
	if id in ["pump_leak","exit_power"]:
		roster[6] = "football"
		roster[2] = "imp"
		roster[10] = "imp"
	reinforcement_batches.append({"id":id,"queued_at":sim.elapsed,"roster":roster,"spawned":0})
	sim.events.append({"kind":"campaign_cue","cue":"horde","position":Vector3(8,1,-16)})

func reinforcements() -> void:
	# One gentle early batch, then finite timers measured from the difficulty transition.
	if not state.late_stage and sim.elapsed >= 150: queue_batch("timer_early",6,["normal"])
	if state.late_stage:
		var age: float = sim.elapsed-state.milestones.late_start
		for i in 2:
			if age >= [45,105][i]: queue_batch("timer_late_"+str(i),[8,10][i],["normal","normal","cone","normal","bucket"])
		if state.pump_fault_b: queue_batch("pump_leak",14,["normal","normal","cone","normal"])
		if state.pump_ready: queue_batch("pump_breaker",10,["normal","normal","cone"])
		if state.power_ready: queue_batch("exit_power",18,["normal","normal","cone","normal","bucket"])
	if sim.elapsed < state.pressure_until or sim.elapsed < state.rest_until: return
	var points: Array = Layout.BRIDGE_POINTS.duplicate()
	for zone in Layout.ZONES: points.append_array(zone.points)
	points = points.filter(func(point): return standing().any(func(p): return p.pos.distance_to(point) < 40))
	for batch in reinforcement_batches:
		if batch.roster.is_empty(): continue
		if spawn_one(points,batch.roster[0]):
			batch.roster.pop_front()
			batch.spawned += 1
		break

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
	if sim.zombies.filter(func(z): return z.hp > 0 and z.get("guard_awake",true)).size() >= cap() or credit < 1: return false
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
	if sim.elapsed >= guidance_until:
		guidance_until = sim.elapsed+.5
		for pawn in standing(): pawn["route_hint"] = guidance(pawn)
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
	credit = minf(1,credit+dt*multiply()*(1.0 if state.late_stage else .55))
	if state.phase == "STREET" and living.any(func(p): return p.pos.y < 5): phase("BRIDGE_READY","到桥头按住 E 启动卷扬机")
	if state.phase == "BRIDGE_ACTIVE":
		state.bridge_time = minf(90,state.bridge_time+dt)
		var t: float = state.bridge_time
		for i in 3:
			if t >= [5,40,75][i]:
				queue_batch("bridge_"+str(i),[8,10,8][i],["normal","normal","normal","cone"])
		if t >= 90:
			state.milestones.bridge_end = sim.elapsed
			state.gate_open = true
			phase("GATE_OPEN","穿过北岸闸门，前往工具棚休整")
			sim.paths.clear()
			sim.events.append({"kind":"campaign_cue","cue":"gate","position":Vector3(0,2,-57)})
			sim.arena.sync_campaign(state)
	if state.phase == "GATE_OPEN" and survivors().all(func(p): return p.pos.y < -60):
		state.rest_until = sim.elapsed+25
		phase("FINAL_APPROACH","工具棚可换取 A 级枪械，准备进入高压路段")
	# Rest belongs to the shed approach, not the whole remaining route.
	# The leading player commits the party to the final encounter; returning
	# to the shed must not restart the timer or replenish encounter budgets.
	if state.gate_open and (living.any(func(p): return p.pos.y < -82)):
		state.rest_until = 0.0
		if not state.late_stage:
			state.late_stage = true
			state.milestones.late_start = sim.elapsed
			phase("FINAL_APPROACH","进入高压路段，前往西侧泵房关闭隔离阀")
	reinforcements()
	sim.arena.scenery.sync(state)

func snapshot() -> Dictionary:
	return state.duplicate(true)
