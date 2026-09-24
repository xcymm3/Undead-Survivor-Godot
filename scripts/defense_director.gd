extends RefCounted
## Authority-only defense interactions, armory inventory and preparation state.
const Layout = preload("res://scripts/defense_layout.gd")
var owner_ref: WeakRef
var sim:
	get: return owner_ref.get_ref()
var state: Dictionary
var equipment

func _init(world) -> void:
	owner_ref = weakref(world)
	state = {
		"started":false,"departed":false,"waiting":true,"ready_players":[],"crystal_hp":Layout.CRYSTAL_MAX_HP,
		"crystal_max_hp":Layout.CRYSTAL_MAX_HP,"wave":1,
		"objective":"第 1 波待开始 · 按 T 准备 (0/%d)" % world.pawns.size(),"party":world.pawns.size(),"prop_clock":0.0,
		"difficulty":world.defense_difficulty,"difficulty_multiplier":preload("res://scripts/defense_population.gd").difficulty_multiplier(world.defense_difficulty)
	}
	equipment = preload("res://scripts/defense_equipment.gd").new(self)
	equipment.initialize()
	sync_world()

func near(p: Dictionary, point: Vector2, distance := 2.0) -> bool:
	if p.pos.distance_to(point) > distance: return false
	return sim.arena.surface_hit(Vector3(p.pos.x,p.height+1.1,p.pos.y),Vector3(point.x,p.height+1.1,point.y)).is_empty()

func begin_wave() -> void:
	sim.wave = int(state.wave)
	sim.spawned = 0
	sim.credit = 0.0
	sim.rest = 0.0
	sim.prepare_wave()
	state.started = true
	state.departed = true
	state.waiting = false
	state.ready_players.clear()
	state.objective = "第 %d 波正在逼近" % sim.wave
	sim.events.append({"kind":"campaign_cue","cue":"horde","position":Vector3(Layout.CRYSTAL.x,5.0,Layout.CRYSTAL.y)})
	sync_world()

func finish_wave() -> void:
	state.waiting = true
	state.wave = sim.wave+1
	state.ready_players.clear()
	state.objective = "第 %d 波已清除 · 按 T 准备第 %d 波 (0/%d)" % [sim.wave,state.wave,sim.pawns.size()]
	sync_world()

func choose_weapon(p: Dictionary, _requested: int) -> int:
	return p.primary if p.slot == 1 else p.secondary if p.slot == 2 else 6

func target(p: Dictionary) -> Dictionary:
	var supply: Dictionary = equipment.pickup_target(p)
	if not supply.is_empty(): return supply
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
		p.hint = "E "+choice.label if not choice.is_empty() else "按 T 准备下一波；可在后方军械库整备" if state.waiting else "保护水晶；在后方军械库补给"
		if p.pickup_latched or not input.get("interact",false) or not p.get("healing","").is_empty() or p.get("being_healed",false): choice = {}
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
		equipment.pickup(p,choice.id)
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
	sim.arena.sync_campaign(state)
