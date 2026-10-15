extends RefCounted
## Authority owns duration, cooldown and inventory locking.
const DURATION = 10.0
const COOLDOWN = 60.0
const DRAW_TIME = 1.1
const SHEATHE_TIME = .95

static func active(p: Dictionary) -> bool:
	return p.get("ultimate_remaining",0.0) > 0

static func locked(p: Dictionary) -> bool:
	return active(p) or p.get("ultimate_sheathe",0.0) > 0

static func weapon(p: Dictionary, progression, base: Dictionary) -> Dictionary:
	if not locked(p): return base
	var result = base.duplicate(true)
	result.id = "ultimate"
	result.label = "长刀"
	result.damage = 300.0*pow(1.2,maxi(0,progression.level("ultimate")-1))
	result.interval = base.interval*.5
	result.fireDuration = base.fireDuration*.5
	result.automatic = true
	return result

static func tick(sim, p: Dictionary, input: Dictionary, dt: float) -> bool:
	var was_active = active(p)
	p.ultimate_cd = maxf(0,float(p.get("ultimate_cd",0.0))-dt)
	p.ultimate_sheathe = maxf(0,float(p.get("ultimate_sheathe",0.0))-dt)
	if was_active: p.ultimate_remaining = maxf(0,float(p.ultimate_remaining)-dt)
	if input.get("ultimate",false):
		if was_active: p.ultimate_remaining = 0.0
		elif p.ultimate_sheathe <= 0 and p.hp > 0:
			if sim.progression.level("ultimate") <= 0:
				p.ultimate_notice = "尚未学习大招"
				p.ultimate_notice_until = sim.elapsed+1.5
			elif p.ultimate_cd > 0:
				p.ultimate_notice = "大招冷却中"
				p.ultimate_notice_until = sim.elapsed+1.5
			elif sim.defense.get("started",false):
				sim.equipment.save_weapon_slot(p)
				p.ultimate_saved_slot = p.slot
				p.ultimate_remaining = DURATION
				p.ultimate_age = 0.0
				p.weapon = 6
				p.requested = 6
				p.slot = 3
				p.switch = 0.0
				p.reload = 0.0
				p.reloading = false
				p.reload_queued = false
				p.fire_anim = 0.0
				sim.melee_swings.erase(p.id)
				sim.events.append({"kind":"ultimate_start","player":p.id})
	p.input["ultimate"] = false
	if active(p): p.ultimate_age = float(p.get("ultimate_age",0.0))+dt
	if was_active and (not active(p) or p.hp <= 0):
		p.ultimate_remaining = 0.0
		p.ultimate_cd = COOLDOWN
		p.ultimate_sheathe = SHEATHE_TIME
		p.fire_anim = 0.0
		sim.melee_swings.erase(p.id)
		sim.events.append({"kind":"ultimate_end","player":p.id})
	if locked(p):
		p.slot = 3
		p.weapon = 6
		p.requested = 6
		input["weapon"] = 6
		input["slot"] = 3
		input["reload"] = false
		input["aim"] = false
		input["crouch"] = false
		input["shove"] = false
		if not active(p) or p.get("ultimate_age",0.0) < DRAW_TIME: input["fire"] = false
		return true
	if p.has("ultimate_saved_slot"):
		p.slot = int(p.ultimate_saved_slot)
		if p.slot not in [1,2,3,4]: p.slot = 1
		p.erase("ultimate_saved_slot")
		input["slot"] = p.slot
		input["weapon"] = p.weapon1 if p.slot == 1 else p.weapon2 if p.slot == 2 else 6
	return false
