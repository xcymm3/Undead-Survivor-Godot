extends RefCounted
## Shared world positions, gaze selection and compact descriptions.
const Layout = preload("res://scripts/defense_layout.gd")
const HOLD_SECONDS = 1.2
const NAMES = {"rifle":"步枪","revolver":"左轮","axe":"消防斧","grenade":"手雷","strong":"强壮","precise":"精准","swift":"迅捷","supply":"补给","turret_left":"炮塔","turret_right":"炮塔","bridge_gate":"栅栏门","bridge_entry_gate":"栅栏门","crystal_mine":"地雷","ramp_mine":"地雷","gate_mine":"地雷","alarm":"警报器","crystal":"水晶"}

static func stations() -> Array:
	var result: Array = []
	var ids = ["rifle","revolver","axe","grenade","strong","precise","swift","supply"]
	for i in ids.size():
		result.append({"id":ids[i],"position":Vector3([-9.0,-3.0,3.0,9.0][i%4],4.15,Layout.SHOP_WALL_Z-2.3 if i < 4 else Layout.SHOP_WALL_Z-7.5),"radius":.85,"range":3.2})
	result.append({"id":"alarm","position":Vector3(-4,4.15,Layout.SHOP_AREA.position.y-2),"radius":.7,"range":3.2})
	return result

static func targets(sim) -> Array:
	var result: Array = stations()
	for item in sim.defense.get("structures",[]):
		if not item.get("owned",false) and sim.defense.started: continue
		if item.kind == "mine" and item.get("spent",false): continue
		var point: Vector3 = Vector3(item.pos.x,item.height+.7,item.pos.y)
		if item.kind == "turret" and item.get("owned",false): point.y = item.height+1.25
		# The lower gate's end posts border the sealed shelf/cliff. Keep its
		# interaction on the accessible bridge-facing panel inside the rail.
		if item.kind == "gate": point.x = -1.8 if item.id == "bridge_entry_gate" else -4.65
		result.append({"id":item.id,"position":point,"radius":.8,"range":3.2})
	result.append({"id":"crystal","position":Vector3(Layout.CRYSTAL.x,5.0,Layout.CRYSTAL.y),"radius":1.1,"range":5.0})
	return result

static func focus(sim, p: Dictionary) -> Dictionary:
	if p.get("hp",0) <= 0: return {}
	var eye = Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p),p.pos.y)
	var direction = Basis.from_euler(Vector3(p.pitch,p.yaw,0))*Vector3.FORWARD
	var selected: Dictionary = {}
	var nearest = INF
	for entry in targets(sim):
		var delta: Vector3 = entry.position-eye
		var along: float = delta.dot(direction)
		if delta.length() > entry.range or along <= 0 or (delta-direction*along).length() > entry.radius: continue
		if along >= nearest: continue
		# Existing structure collision is excluded; unrelated scenery still occludes.
		var endpoint: Vector3 = entry.position-direction*(1.25 if entry.id == "crystal" else .55)
		if not sim.arena.surface_hit(eye,endpoint,entry.id).is_empty(): continue
		nearest = along
		selected = entry
	return selected

static func available(sim, id: String) -> bool:
	if sim.defense.started or sim.failed or sim.won or id == "crystal": return false
	if id == "alarm": return true
	if id in sim.progression.BUILDINGS:
		var item = sim.defense_director.structures.find(id)
		if item.get("owned",false) and item.hp <= 0: return false
	return sim.progression.cost(id) >= 0

static func description(sim, id: String) -> String:
	var profile = sim.progression
	if id == "crystal": return "水晶\n%d / %d" % [sim.defense.crystal_hp,sim.defense.crystal_max_hp]
	if id == "alarm": return "进攻中" if sim.defense.started else "开始进攻\n长按 E"
	var price: int = profile.cost(id)
	var cost_text = "%d%s" % [price,"◆" if id in profile.TALENTS else "$"] if price >= 0 else "MAX"
	var level_text = "LV%d" % (profile.level(id)+1) if id not in profile.TALENTS else "LV%d / 10" % profile.level(id)
	var detail = ""
	if id in profile.WEAPONS:
		var index: int = {"rifle":0,"revolver":3,"axe":6}[id]
		detail = "伤害 %s" % number(sim.arena.get_node("/root/Data").weapons[index].damage*profile.weapon_multiplier(id))
	elif id == "grenade": detail = "容量 %d / 5" % profile.grenade_capacity()
	elif id in profile.MINES:
		var item = sim.defense_director.structures.find(id)
		return "地雷\n"+("已触发" if item.get("triggered",false) else "已布置") if profile.owned(id) else "地雷\n"+cost_text
	elif id in profile.BUILDINGS:
		if not profile.owned(id): return NAMES[id]+"\n建造\n"+cost_text
		var item = sim.defense_director.structures.find(id)
		detail = "耐久 %d / %d" % [item.hp,item.max_hp] if id in profile.GATES else "伤害 %s" % number(60*profile.building_multiplier(id))
	else:
		match id:
			"strong": detail = "生命 %d · 回复 %d/s" % [profile.max_health(),profile.level(id)]
			"precise": detail = "爆头 +%d%%" % (profile.level(id)*10)
			"swift": detail = "移速 +%d%%" % (profile.level(id)*5)
			"supply": detail = "备弹 +%d%%" % (profile.level(id)*10)
	return level_text+"\n"+detail+"\n"+("整备已结束" if sim.defense.started else cost_text)

static func number(value: float) -> String:
	return ("%.1f" % value).trim_suffix(".0")
