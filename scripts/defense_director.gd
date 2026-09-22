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
		"started":false,"departed":false,"crystal_hp":Layout.CRYSTAL_MAX_HP,
		"crystal_max_hp":Layout.CRYSTAL_MAX_HP,"wave":1,"countdown":0.0,
		"objective":"前往水晶旁拉下拉杆，准备第一波进攻","party":world.pawns.size(),"prop_clock":0.0
	}
	equipment = preload("res://scripts/defense_equipment.gd").new(self)
	equipment.initialize()
	sync_world()

func near(p: Dictionary, point: Vector2, distance := 2.0) -> bool:
	if p.pos.distance_to(point) > distance: return false
	return sim.arena.surface_hit(Vector3(p.pos.x,p.height+1.1,p.pos.y),Vector3(point.x,p.height+1.1,point.y)).is_empty()

func start_wave_countdown() -> void:
	sim.rest = 5.0
	state.countdown = 5.0
	state.wave = sim.wave
	state.objective = "第 %d 波将在 5 秒后开始 · 请整备" % sim.wave
	sync_world()

func choose_weapon(p: Dictionary, _requested: int) -> int:
	return p.primary if p.slot == 1 else p.secondary if p.slot == 2 else 6

func sync_countdown(seconds: float) -> void:
	state.countdown = maxf(0,seconds)
	var pending_wave: int = sim.wave+1 if sim.cleared >= sim.wave else sim.wave
	state.wave = pending_wave
	state.objective = "第 %d 波将在 %d 秒后开始 · 请整备" % [pending_wave,maxi(1,ceili(seconds))] if seconds > 0 else "第 %d 波正在逼近" % pending_wave
	sync_world()

func target(p: Dictionary) -> Dictionary:
	var supply: Dictionary = equipment.pickup_target(p)
	if not supply.is_empty(): return supply
	if not state.started and p.pos.distance_to(Layout.LEVER) <= 2.7:
		return {"id":"lever","label":"拉下拉杆并开始防守","seconds":.0}
	return {}

func interactions(dt: float) -> void:
	state.prop_clock += dt
	for p in sim.pawns.values(): p.pickup_remaining = maxf(0,p.get("pickup_until",0.0)-state.prop_clock)
	for motion in state.get("pickup_motion",[]):
		var owner: Dictionary = sim.pawns.get(motion.owner,{})
		if not owner.is_empty() and state.prop_clock-motion.at < .65:
			motion.to = equipment.grab_point(owner)
			motion.pitch = owner.pitch
	for p in sim.pawns.values():
		var input: Dictionary = p.input if p.input_age < .5 else {}
		if not input.get("interact",false): p.pickup_latched = false
		var choice := target(p)
		p.hint = "E "+choice.label if not choice.is_empty() else "保护水晶；在后方军械库补给" if state.started else "前往水晶旁拉杆；可先在后方军械库整备"
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
		if choice.id == "lever":
			state.started = true
			state.departed = true
			start_wave_countdown()
			sim.events.append({"kind":"campaign_cue","cue":"horde","position":Vector3(p.pos.x,p.height+1,p.pos.y)})
			p.pickup_latched = true
		else:
			equipment.pickup(p,choice.id)
		p.interaction = ""
		p.interact_time = 0.0
	for p in sim.pawns.values(): p.input.interact = false
	sync_world()

func sync_world() -> void:
	sim.arena.sync_campaign(state)
