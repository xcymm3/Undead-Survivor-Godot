extends "res://scripts/campaign_equipment.gd"
## Defense armory equipment reuses the campaign's five slots, healing and grenades.
const DefenseLayout = preload("res://scripts/defense_layout.gd")
const REFILL_SECONDS = 30.0

func _init(defense_director) -> void:
	super(defense_director)

func initialize() -> void:
	for p in sim.pawns.values():
		# Keep the defense rifle start while using Night's shared five-slot loadout.
		p.primary = 0
		p.secondary = 3
		p.slot = 1
		p.grenades = 0
		p.medkits = 1
		p.grenade_ready_at = 0.0
		p.healing = ""
		p.heal_time = 0.0
		p.being_healed = false
		p.use_latch = false
		p.pickup_latched = false
		p.heal_hurt = -100.0
		p.hurt_at = -100.0
		p.action_hurt = -100.0
		p.interaction = ""
		p.interact_time = 0.0
		p.downed = false
		p.dead = false
		p.bleed = 0.0
		p.revives = 0
		p.reserves = []
		p.reserves.resize(10)
		p.reserves.fill(0)
		p.weapon = p.primary
		p.requested = p.primary
		p.ammo.fill(0)
		p.ammo[p.primary] = int(Data.weapons[p.primary].capacity)
		p.reserves[p.primary] = 5*int(Data.weapons[p.primary].capacity)
		p.ammo[p.secondary] = int(Data.weapons[p.secondary].capacity)
		p.reserves[p.secondary] = 5*int(Data.weapons[p.secondary].capacity)
		p.reserve = p.reserves[p.primary]
	director.state.projectiles = []
	director.state.pickup_motion = []
	director.state.pickup_serial = 0
	director.state.grenade_slots = []
	director.state.medkit_slots = []
	for index in director.state.party:
		director.state.grenade_slots.append({"id":index,"ready_at":0.0})
		director.state.medkit_slots.append({"id":index,"ready_at":0.0})

func aimed_score(p: Dictionary, point: Vector3) -> float:
	var forward = Vector3(-sin(p.yaw)*cos(p.pitch),sin(p.pitch),-cos(p.yaw)*cos(p.pitch))
	var eye = Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p),p.pos.y)
	var delta = point-eye
	if delta.length() > 3.6 or not director.near(p,Vector2(point.x,point.z),3.6): return -10.0
	return forward.dot(delta.normalized())-delta.length()*.035

func pickup_target(p: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var score = .3
	for display_index in DefenseLayout.PRIMARY_WEAPONS.size():
		var weapon: int = DefenseLayout.PRIMARY_WEAPONS[display_index]
		var value = aimed_score(p,DefenseLayout.weapon_mount(display_index))
		if value > score:
			score = value
			best = {"id":"weapon:"+str(weapon),"label":"换取 "+Data.weapons[weapon].label+"（替换主武器）","seconds":.3}
	for kind in ["grenade","medkit"]:
		if kind == "grenade" and p.grenades >= MAX_GRENADES: continue
		if kind == "medkit" and p.medkits >= 1: continue
		var slots: Array = director.state[kind+"_slots"]
		var mounts: Array = DefenseLayout.GRENADE_MOUNTS if kind == "grenade" else DefenseLayout.MEDKIT_MOUNTS
		for index in slots.size():
			if float(slots[index].ready_at) > float(director.state.prop_clock): continue
			var value = aimed_score(p,mounts[index])
			if value > score:
				score = value
				best = {"id":"%s:%d" % [kind,index],"label":"领取"+("手雷" if kind == "grenade" else "医疗包"),"seconds":.25}
	return best

func pickup(p: Dictionary, id: String) -> bool:
	if id.begins_with("weapon:"):
		var weapon := int(id.trim_prefix("weapon:"))
		if weapon not in DefenseLayout.PRIMARY_WEAPONS: return false
		var display_index: int = DefenseLayout.PRIMARY_WEAPONS.find(weapon)
		if aimed_score(p,DefenseLayout.weapon_mount(display_index)) <= .3: return false
		var old: int = p.primary
		pickup_motion(p,DefenseLayout.weapon_mount(display_index),weapon,0,old)
		p.ammo[old] = 0
		p.reserves[old] = 0
		p.primary = weapon
		p.weapon = weapon
		p.requested = weapon
		p.slot = 1
		p.ammo[weapon] = int(Data.weapons[weapon].capacity)
		p.reserves[weapon] = 5*int(Data.weapons[weapon].capacity)
		p.reserve = p.reserves[weapon]
		p.switch = .65
		p.reloading = false
		p.reload_queued = false
		p.reload = 0.0
		p.fire_anim = 0.0
		sim.melee_swings.erase(p.id)
		p.pickup_latched = true
		return true
	var parts := id.split(":")
	if parts.size() != 2 or parts[0] not in ["grenade","medkit"]: return false
	var kind: String = parts[0]
	var index := int(parts[1])
	var slots: Array = director.state[kind+"_slots"]
	var mounts: Array = DefenseLayout.GRENADE_MOUNTS if kind == "grenade" else DefenseLayout.MEDKIT_MOUNTS
	if index < 0 or index >= slots.size() or float(slots[index].ready_at) > float(director.state.prop_clock): return false
	if aimed_score(p,mounts[index]) <= .3: return false
	if kind == "grenade":
		if p.grenades >= MAX_GRENADES: return false
		p.grenades += 1
		pickup_motion(p,mounts[index],-1,4)
	else:
		if p.medkits >= 1: return false
		p.medkits += 1
		pickup_motion(p,mounts[index],-1,5)
	slots[index].ready_at = float(director.state.prop_clock)+REFILL_SECONDS
	p.pickup_latched = true
	return true
