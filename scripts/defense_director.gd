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
var launched_waves: Dictionary = {}

func _init(world) -> void:
	owner_ref = weakref(world)
	state = {
		"started":false,"waiting":true,"ready_players":[],"crystal_hp":Layout.CRYSTAL_MAX_HP,
		"crystal_max_hp":Layout.CRYSTAL_MAX_HP,"wave":1,
		"objective":"战前准备 · 点击开始进攻 · 共十波","party":world.pawns.size(),"prop_clock":0.0,
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
	state.wave = clampi(int(state.wave),1,10)
	sim.wave = int(state.wave)
	sim.spawned = 0
	sim.rest = 0.0
	sim.prepare_wave()
	structures.reset_mines()
	launched_waves[sim.wave] = true
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
	reward_finished_waves()
	sync_world()

func reward_finished_waves() -> void:
	if sim.failed or not state.started or state.crystal_hp <= 0: return
	for generation in launched_waves:
		if rewarded_waves.has(generation) or (generation == sim.wave and not sim.roster.is_empty()): continue
		if sim.zombies.any(func(z): return z.hp > 0 and int(z.get("spawn_wave",sim.wave)) == generation): continue
		rewarded_waves[generation] = true
		sim.progression.award_wave(generation)
		for p in sim.pawns.values(): equipment.award_wave_ammo(p)
		sim.cleared = rewarded_waves.size()

func choose_weapon(p: Dictionary, _requested: int) -> int:
	return p.weapon1 if p.slot == 1 else 6 if p.slot == 3 else p.weapon2 if p.slot == 2 else p.weapon

func target(p: Dictionary) -> Dictionary:
	return preload("res://scripts/preparation_catalog.gd").focus(sim,p)

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
		p.input["wave_ready"] = false
		if not input.get("interact",false): p.pickup_latched = false
		var choice := target(p)
		p["focus"] = choice
		p.hint = ""
		if not choice.is_empty() and not preload("res://scripts/preparation_catalog.gd").available(sim,choice.id): choice = {}
		if p.pickup_latched or not input.get("interact",false): choice = {}
		if choice.is_empty():
			p.interaction = ""
			p.interact_time = 0.0
			continue
		if p.interaction != choice.id:
			p.interaction = choice.id
			p.interact_time = 0.0
		p.interact_time += dt
		if p.interact_time < preload("res://scripts/preparation_catalog.gd").HOLD_SECONDS: continue
		p.pickup_latched = true
		if choice.id == "alarm":
			begin_wave()
		else:
			var purchased: bool = sim.purchase_upgrade(choice.id,p)
			p["work_feedback"] = "完成" if purchased else sim.progression.notice if not sim.progression.notice.is_empty() else "钻石不足" if choice.id in sim.progression.TALENTS else "金币不足"
			p["work_feedback_id"] = choice.id
			p["work_feedback_until"] = state.prop_clock+1.5
			if purchased: sim.events.append({"kind":"world_upgrade","id":choice.id,"position":choice.position,"player":p.id})
		p.interaction = ""
		p.interact_time = 0.0
	for p in sim.pawns.values(): p.input.interact = false
	if state.waiting: state.objective = "战前准备"
	sync_world()

func sync_world() -> void:
	sim.arena.sync_defense(state)
