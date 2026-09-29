extends "res://scripts/equipment_core.gd"
## Crystal defense armory, two unrestricted weapon slots and per-wave grenades.
const DefenseLayout = preload("res://scripts/defense_layout.gd")

func _init(defense_director) -> void:
	super(defense_director)

func initialize() -> void:
	for p in sim.pawns.values():
		# Two independent weapon inventories; grenades refill only when a wave starts.
		p.weapon1 = 0
		p.weapon2 = 8
		p.slot = 1
		p.weapon_slot = 1
		p.slot_ammo = [int(Data.weapons[0].capacity),int(Data.weapons[8].capacity)]
		p.slot_reserves = [Data.defense_full_reserve(0),Data.defense_full_reserve(8)]
		p.grenades = 0
		p.grenade_ready_at = 0.0
		p.use_latch = false
		p.pickup_latched = false
		p.hurt_at = -100.0
		p.action_hurt = -100.0
		p.interaction = ""
		p.interact_time = 0.0
		p.reserves = []
		p.reserves.resize(10)
		p.reserves.fill(0)
		p.weapon = p.weapon1
		p.requested = p.weapon1
		p.ammo.fill(0)
		p.ammo[p.weapon1] = int(Data.weapons[p.weapon1].capacity)
		p.reserves[p.weapon1] = Data.defense_full_reserve(p.weapon1)
		p.ammo[p.weapon2] = int(Data.weapons[p.weapon2].capacity)
		p.reserves[p.weapon2] = Data.defense_full_reserve(p.weapon2)
		p.reserve = p.reserves[p.weapon1]
	director.state.projectiles = []
	director.state.pickup_motion = []
	director.state.pickup_serial = 0

func aimed_score(p: Dictionary, point: Vector3) -> float:
	var forward = Vector3(-sin(p.yaw)*cos(p.pitch),sin(p.pitch),-cos(p.yaw)*cos(p.pitch))
	var eye = Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p),p.pos.y)
	var delta = point-eye
	if delta.length() > 3.6 or not director.near(p,Vector2(point.x,point.z),3.6): return -10.0
	return forward.dot(delta.normalized())-delta.length()*.035

func pickup_target(p: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var score = .3
	for display_index in DefenseLayout.ARMORY_WEAPONS.size():
		var weapon: int = DefenseLayout.ARMORY_WEAPONS[display_index]
		var value = aimed_score(p,DefenseLayout.weapon_mount(display_index))
		if value > score:
			score = value
			best = {"id":"weapon:"+str(weapon),"label":"换取 "+Data.weapons[weapon].label+"（替换武器%d）" % (2 if p.slot == 2 else 1),"seconds":.3}
	return best

func pickup(p: Dictionary, id: String) -> bool:
	if not id.begins_with("weapon:"): return false
	var suffix = id.trim_prefix("weapon:")
	if not suffix.is_valid_int(): return false
	var weapon := int(suffix)
	if weapon not in DefenseLayout.ARMORY_WEAPONS: return false
	var display_index: int = DefenseLayout.ARMORY_WEAPONS.find(weapon)
	if aimed_score(p,DefenseLayout.weapon_mount(display_index)) <= .3: return false
	save_weapon_slot(p)
	var slot: int = 2 if p.slot == 2 else 1
	var old: int = p.weapon1 if slot == 1 else p.weapon2
	pickup_motion(p,DefenseLayout.weapon_mount(display_index),weapon,0,old)
	p["weapon1" if slot == 1 else "weapon2"] = weapon
	p.slot_ammo[slot-1] = int(Data.weapons[weapon].capacity)
	p.slot_reserves[slot-1] = Data.defense_full_reserve(weapon)
	var other: int = p.weapon2 if slot == 1 else p.weapon1
	if old != other and old != weapon:
		p.ammo[old] = 0
		p.reserves[old] = 0
	p.slot = slot
	select_weapon_slot(p,slot,false)
	p.switch = .65
	p.fire_anim = 0.0
	sim.melee_swings.erase(p.id)
	p.pickup_latched = true
	return true
