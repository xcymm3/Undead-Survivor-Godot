extends RefCounted
## Authority owns duration, cooldown and inventory locking.
const DURATION = 10.0
const COOLDOWN = 100.0
const DAMAGE = [200,400,600,900,1350]
const DRAW_TIME = 1.1
const SHEATHE_TIME = .95

static func damage_for_level(rank: int) -> float:
	return float(DAMAGE[clampi(rank,0,DAMAGE.size()-1)])

static func cooldown(progression) -> float:
	return COOLDOWN*progression.ultimate_cooldown_multiplier()

static func unlocked(p: Dictionary) -> bool:
	return p.get("ultimate_unlocked",false)

static func active(p: Dictionary) -> bool:
	return p.get("ultimate_remaining",0.0) > 0

static func locked(p: Dictionary) -> bool:
	return active(p) or p.get("ultimate_sheathe",0.0) > 0

static func weapon(p: Dictionary, progression, base: Dictionary) -> Dictionary:
	if not locked(p): return base
	var result = base.duplicate(true)
	result.id = "ultimate"
	result.label = "长刀"
	result.damage = damage_for_level(progression.level("ultimate"))
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
			if not unlocked(p):
				p.ultimate_notice = "终极技能未解锁"
				p.ultimate_notice_until = sim.elapsed+1.5
			elif p.ultimate_cd > 0:
				p.ultimate_notice = "终极技能冷却中"
				p.ultimate_notice_until = sim.elapsed+1.5
			elif sim.defense.get("started",false):
				sim.defense.erase("ultimate_tutorial_hint")
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
				p.melee_queued = false
				sim.melee_swings.erase(p.id)
				sim.events.append({"kind":"ultimate_start","player":p.id})
	p.input["ultimate"] = false
	if active(p): p.ultimate_age = float(p.get("ultimate_age",0.0))+dt
	if was_active and (not active(p) or p.hp <= 0):
		p.ultimate_remaining = 0.0
		p.ultimate_cd = cooldown(sim.progression)
		p.ultimate_sheathe = SHEATHE_TIME
		p.fire_anim = 0.0
		p.melee_queued = false
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
		if not active(p) or p.get("ultimate_age",0.0) < DRAW_TIME:
			input["fire"] = false
			input["fire_pressed"] = false
			p.melee_queued = false
		return true
	if p.has("ultimate_saved_slot"):
		p.slot = int(p.ultimate_saved_slot)
		if p.slot not in [1,2,3,4]: p.slot = 1
		p.erase("ultimate_saved_slot")
		input["slot"] = p.slot
		input["weapon"] = p.weapon1 if p.slot == 1 else p.weapon2 if p.slot == 2 else 6
	return false
