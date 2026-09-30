extends "res://scripts/equipment_core.gd"
## Fixed rifle, revolver, axe and grenade loadout.
const DefenseLayout = preload("res://scripts/defense_layout.gd")

func _init(defense_director) -> void:
	super(defense_director)

func initialize() -> void:
	for p in sim.pawns.values():
		# Two independent weapon inventories; grenades refill only when a wave starts.
		p.weapon1 = 0
		p.weapon2 = 3
		p.slot = 1
		p.weapon_slot = 1
		p.slot_ammo = [int(Data.weapons[0].capacity),int(Data.weapons[3].capacity)]
		p.slot_reserves = [roundi(Data.defense_full_reserve(0)*sim.progression.reserve_multiplier()),roundi(Data.defense_full_reserve(3)*sim.progression.reserve_multiplier())]
		p.grenade_capacity = sim.progression.grenade_capacity()
		p.grenades = p.grenade_capacity
		p.max_hp = sim.progression.max_health()
		p.hp = p.max_hp
		p.combat_remaining = 0.0
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
		p.reserves[p.weapon1] = p.slot_reserves[0]
		p.ammo[p.weapon2] = int(Data.weapons[p.weapon2].capacity)
		p.reserves[p.weapon2] = p.slot_reserves[1]
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
	return director.target(p)

func pickup(p: Dictionary, id: String) -> bool:
	# Legacy weapon pickup identifiers cannot alter the fixed inventory.
	return false
