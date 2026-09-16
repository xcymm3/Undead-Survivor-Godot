extends RefCounted
var Layout = preload("res://scripts/night_layout.gd")
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

func target(_p: Dictionary) -> Dictionary:
	return {}
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
	if id.begins_with("revive:"):
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

func guidance(_p: Dictionary) -> String:
	return state.objective
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
	pass
func queue_batch(id: String, count: int, kinds: Array) -> void:
	if reinforcement_batches.any(func(batch): return batch.id == id): return
	var roster: Array = []
	for i in roundi(count*multiply()): roster.append(kinds[i%kinds.size()])
	reinforcement_batches.append({"id":id,"queued_at":sim.elapsed,"roster":roster,"spawned":0})
	var source: Vector2 = Layout.HOLDOUT if id.begins_with("night_holdout_") else standing()[0].pos if not standing().is_empty() else Layout.START
	sim.events.append({"kind":"campaign_cue","cue":"horde","position":Vector3(source.x,1,source.y)})


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
	if sim.zombies.filter(func(z): return z.hp > 0 and z.get("guard_awake",true) and not z.get("boss",false)).size() >= cap() or credit < 1: return false
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

func step(_dt: float) -> void:
	pass
func snapshot() -> Dictionary:
	return state.duplicate(true)
