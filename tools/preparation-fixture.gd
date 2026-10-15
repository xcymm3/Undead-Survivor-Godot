extends RefCounted
const Catalog = preload("res://scripts/preparation_catalog.gd")

static func face(sim, p: Dictionary, id: String) -> void:
	var anchor = id
	if id in sim.progression.WEAPONS or id in sim.progression.MAGAZINES:
		var weapon = id.trim_suffix("_magazine")
		p.weapon = {"rifle":0,"pistol":2,"axe":6}[weapon]
		p.requested = p.weapon
		p.slot = {"rifle":1,"pistol":2,"axe":3}[weapon]
		anchor = "rifle_magazine" if id in sim.progression.MAGAZINES else "rifle"
	for entry in Catalog.targets(sim):
		if entry.id != anchor: continue
		var point: Vector3 = entry.position
		var station: bool = id in sim.progression.WEAPONS or id in sim.progression.MAGAZINES or id in sim.progression.TALENTS or id in ["grenade","alarm","ultimate"]
		p.pos = Vector2(point.x,point.z)+Vector2(0,-2 if station else 2)
		if id in sim.progression.MAGAZINES: p.pos = Vector2(point.x-2,point.z)
		p.height = preload("res://scripts/defense_layout.gd").height(p.pos)
		var eye = Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p),p.pos.y)
		var direction = (point-eye).normalized()
		p.yaw = atan2(-direction.x,-direction.z)
		p.pitch = asin(direction.y)
		p.input_age = 0
		return

static func buy(sim, p: Dictionary, id: String) -> bool:
	face(sim,p,id)
	return sim.purchase_upgrade(id,p)

static func hold(sim, p: Dictionary, seconds: float) -> void:
	p.input = {"interact":true}
	p.input_age = 0
	sim.defense_director.interactions(seconds)
