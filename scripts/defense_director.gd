extends RefCounted
## Single-player preparation, shop access and wave rewards.
const Layout = preload("res://scripts/defense_layout.gd")
var owner_ref: WeakRef
var sim:
	get: return owner_ref.get_ref()
var state: Dictionary
var equipment
var structures
var rewarded_waves: Dictionary = {}

func _init(world) -> void:
	owner_ref = weakref(world)
	state = {
		"started":false,"waiting":true,"ready_players":[],"crystal_hp":Layout.CRYSTAL_MAX_HP,
		"crystal_max_hp":Layout.CRYSTAL_MAX_HP,"wave":1,
		"objective":"第 1 波待开始 · 按 T 准备 (0/%d)" % world.pawns.size(),"party":world.pawns.size(),"prop_clock":0.0,
		"difficulty":world.defense_difficulty,"difficulty_multiplier":preload("res://scripts/defense_population.gd").difficulty_multiplier(world.defense_difficulty)
	}
	structures = preload("res://scripts/defense_structures.gd").new(self)
	equipment = preload("res://scripts/defense_equipment.gd").new(self)
	equipment.initialize()
	sync_world()

func near(p: Dictionary, point: Vector2, distance := 2.0) -> bool:
	if p.pos.distance_to(point) > distance: return false
	return sim.arena.surface_hit(Vector3(p.pos.x,p.height+1.1,p.pos.y),Vector3(point.x,p.height+1.1,point.y)).is_empty()

func begin_wave() -> void:
	sim.wave = int(state.wave)
	sim.spawned = 0
	sim.rest = 0.0
	sim.prepare_wave()
	structures.reset_wave()
	for p in sim.pawns.values():
		p.hp = p.max_hp
		p.regen_credit = 0.0
		p.combat_remaining = 0.0
		p.damage_hint = 0.0
		p.damage_dir = Vector2.ZERO
		p.damage_rear = false
		p.grenades = sim.progression.grenade_capacity()
		p.grenade_ready_at = 0.0
	state.started = true
	state.waiting = false
	state.ready_players.clear()
	state.objective = "第 %d 波正在逼近" % sim.wave
	sim.events.append({"kind":"wave_start","position":Vector3(Layout.CRYSTAL.x,5.0,Layout.CRYSTAL.y)})
	sync_world()

func finish_wave() -> void:
	if not rewarded_waves.has(sim.wave) and state.started and not state.waiting and not sim.failed and state.crystal_hp > 0 and sim.roster.is_empty() and sim.alive_count() == 0:
		rewarded_waves[sim.wave] = true
		sim.progression.award_wave(sim.wave)
	state.waiting = true
	state.wave = sim.wave+1
	state.ready_players.clear()
	state.objective = "第 %d 波已清除 · 钻石 +1 · 按 T 开始第 %d 波" % [sim.wave,state.wave]
	sync_world()

func choose_weapon(p: Dictionary, _requested: int) -> int:
	return p.weapon1 if p.slot == 1 else 6 if p.slot == 3 else p.weapon2 if p.slot == 2 else p.weapon

func target(p: Dictionary) -> Dictionary:
	if sim.shop_available(p): return {"id":"shop","label":"打开商店（本局开波后关闭）","seconds":0.0}
	return {}

func interactions(dt: float) -> void:
	state.party = sim.pawns.size()
	state.prop_clock += dt
	for p in sim.pawns.values(): p.pickup_remaining = maxf(0,p.get("pickup_until",0.0)-state.prop_clock)
	for motion in state.get("pickup_motion",[]):
		var owner: Dictionary = sim.pawns.get(motion.owner,{})
		if not owner.is_empty() and state.prop_clock-motion.at < .65:
			motion.to = equipment.grab_point(owner)
			motion.pitch = owner.pitch
	for p in sim.pawns.values():
		var input: Dictionary = p.input if p.input_age < .5 else {}
		if state.waiting and input.get("wave_ready",false) and not state.ready_players.has(p.id): state.ready_players.append(p.id)
		p.input["wave_ready"] = false
		if not input.get("interact",false): p.pickup_latched = false
		var choice := target(p)
		p.hint = "E "+choice.label if not choice.is_empty() else "水晶后方商店升级 · 按 T 开始第一波" if not state.started else "商店已关闭 · 按 T 开始下一波" if state.waiting else "保护水晶 · 弹药本局不补充"
		if p.pickup_latched or not input.get("interact",false): choice = {}
		if choice.is_empty():
			p.interaction = ""
			p.interact_time = 0.0
			continue
		if p.interaction != choice.id:
			p.interaction = choice.id
			p.interact_time = 0.0
		p.interact_time += dt
		p.hint = "%s %.1f/%.1f 秒" % [choice.label,p.interact_time,choice.seconds]
		if p.interact_time < float(choice.seconds): continue
		if choice.id == "shop":
			p.pickup_latched = true
			sim.events.append({"kind":"shop_open","player":p.id})
		p.interaction = ""
		p.interact_time = 0.0
	for p in sim.pawns.values(): p.input.interact = false
	if state.waiting:
		state.ready_players = state.ready_players.filter(func(id): return sim.pawns.has(id))
		if not sim.pawns.is_empty() and sim.pawns.keys().all(func(id): return state.ready_players.has(id)):
			begin_wave()
		else:
			state.objective = "第 %d 波待开始 · 按 T 准备 (%d/%d)" % [state.wave,state.ready_players.size(),sim.pawns.size()]
	sync_world()

func sync_world() -> void:
	sim.arena.sync_defense(state)
