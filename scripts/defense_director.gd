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
const WAVE_GAP = 10.0

func _init(world) -> void:
	owner_ref = weakref(world)
	state = {
		"started":false,"waiting":true,"ready_players":[],"crystal_hp":0,
		"crystal_repair_required":true,"crystal_broken_at":-3.0,
		"crystal_max_hp":Layout.CRYSTAL_MAX_HP,"wave":1,
		"objective":"过桥整备 · 修复水晶后立即开始","party":world.pawns.size(),"prop_clock":0.0,
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
	if sim.failed or sim.won: return
	# The first launch completes the repair. Later waves preserve battle damage.
	if not state.started:
		for pawn in sim.pawns.values():
			var offset: Vector2 = pawn.pos-Layout.CRYSTAL
			if offset.length() >= Layout.CRYSTAL_RADIUS+.65: continue
			pawn.pos = Layout.CRYSTAL+(offset.normalized() if offset.length() > .01 else Vector2(0,-1))*(Layout.CRYSTAL_RADIUS+.75)
			pawn.height = Layout.height(pawn.pos)
		state.crystal_hp = state.crystal_max_hp
		state.crystal_repair_required = false
		state.erase("crystal_broken_at")
	state.wave = clampi(int(state.wave),1,10)
	sim.wave = int(state.wave)
	sim.spawned = 0
	sim.rest = 0.0
	sim.prepare_wave()
	if sim.wave == 10 and "dancer" in sim.roster:
		var point = sim.defense_spawner.random_point()
		for attempt in 4096:
			if sim.defense_spawner.ground_clear(point): break
			point = sim.defense_spawner.random_point()
		sim.spawn(point,"dancer")
		sim.roster.erase("dancer")
		sim.spawned = 1
	launched_waves[sim.wave] = true
	state.started = true
	state["wave_started_at"] = sim.elapsed
	state["next_wave_at"] = -1.0
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
		sim.earned_diamonds += 1
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
		if not choice.is_empty() and choice.id != "crystal":
			if sim.progression.data[sim.progression.currency(choice.id)] < sim.progression.cost(choice.id): choice = {}
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
		if choice.id == "crystal":
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
	if state.waiting: state.objective = "过桥整备 · 修复水晶后立即开始"
	sync_world()

func sync_world() -> void:
	sim.arena.sync_defense(state)
