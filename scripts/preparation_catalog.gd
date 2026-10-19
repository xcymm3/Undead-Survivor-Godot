extends RefCounted
## Shared world positions, gaze selection and compact descriptions.
const Layout = preload("res://scripts/defense_layout.gd")
const HOLD_SECONDS = 1.0
const NAMES = {"rifle":"步枪","rifle_magazine":"步枪弹匣","pistol_magazine":"手枪弹匣","pistol":"手枪","axe":"消防斧","grenade":"手雷","ultimate":"终极技能","strong":"强壮","precise":"本能","swift":"极速","supply":"补给","greed":"贪婪","turret_left":"炮塔","turret_right":"炮塔","bridge_gate":"栅栏门","bridge_entry_gate":"栅栏门","crystal_mine":"地雷","ramp_mine":"地雷","gate_mine":"地雷","crystal":"水晶"}

static func stations() -> Array:
	var result: Array = []
	var ids = ["rifle","rifle_magazine","ultimate","grenade","strong","precise","swift","supply","greed"]
	for i in ids.size():
		var x: float = [-9.0,-3.0,3.0,9.0][i] if i < 4 else [-10.0,-5.0,0.0,5.0,10.0][i-4]
		result.append({"id":ids[i],"position":Vector3(x,4.15,Layout.SHOP_WALL_Z-2.3 if i < 4 else Layout.SHOP_WALL_Z-7.5),"radius":.85,"range":3.2})

	return result

static func targets(sim) -> Array:
	var result: Array = stations()
	for item in sim.defense.get("structures",[]):
		if not item.get("owned",false) and sim.defense.started: continue
		if item.kind == "mine" and item.get("spent",false): continue
		var point: Vector3 = Vector3(item.pos.x,item.height+.7,item.pos.y)
		if item.kind == "turret" and item.get("owned",false): point.y = item.height+1.25
		# Gate labels use the centre as an anchor; gaze selection uses the entire
		# face volume, including the unbuilt preview, rather than this point.
		result.append({"id":item.id,"position":point,"radius":.8,"range":3.2,"gate_body":item.kind == "gate"})
	result.append({"id":"crystal","position":Vector3(Layout.CRYSTAL.x,4.0 if sim.defense.get("crystal_repair_required",false) else 5.0,Layout.CRYSTAL.y),"radius":1.1,"range":5.0})
	return result

static func focus(sim, p: Dictionary) -> Dictionary:
	if preload("res://scripts/first_attempt_intro.gd").active(sim.defense): return {}
	if sim.defense.get("started",false): return {}
	if p.get("hp",0) <= 0: return {}
	var eye = Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p),p.pos.y)
	var direction = Basis.from_euler(Vector3(p.pitch,p.yaw,0))*Vector3.FORWARD
	var selected: Dictionary = {}
	var nearest = INF
	for entry in targets(sim):
		if entry.get("gate_body",false):
			var gate = sim.defense_director.structures.find(entry.id)
			var structures = sim.defense_director.structures
			var box = AABB(Vector3(gate.pos.x-structures.GATE_WIDTH/2,gate.height,gate.pos.y-structures.GATE_DEPTH/2),Vector3(structures.GATE_WIDTH,structures.GATE_HEIGHT,structures.GATE_DEPTH))
			var distance = gate_distance(box,eye,direction,entry.range)
			if distance < 0 or distance >= nearest: continue
			var point = eye+direction*distance
			if not sim.arena.surface_hit(eye,point-direction*.02,entry.id).is_empty(): continue
			nearest = distance
			selected = entry.duplicate()
			selected.position = point
			continue
		var delta: Vector3 = entry.position-eye
		var along: float = delta.dot(direction)
		if delta.length() > entry.range or along <= 0 or (delta-direction*along).length() > entry.radius: continue
		if along >= nearest: continue
		# Existing structure collision is excluded; unrelated scenery still occludes.
		var endpoint: Vector3 = entry.position-direction*(1.25 if entry.id == "crystal" else .55)
		if not sim.arena.surface_hit(eye,endpoint,entry.id).is_empty(): continue
		nearest = along
		selected = entry
	if selected.get("id","") in ["rifle","rifle_magazine"]:
		var base: Dictionary = sim.arena.get_node("/root/Data").weapons[int(p.weapon)]
		var capacity: bool = selected.id == "rifle_magazine"
		selected = selected.duplicate()
		selected.id = base.id+("_magazine" if capacity else "") if base.id in (["rifle","pistol"] if capacity else ["rifle","pistol","axe"]) and p.get("slot",1) != 4 else "unsupported_weapon"
	return selected

static func available(sim, id: String) -> bool:
	if preload("res://scripts/first_attempt_intro.gd").active(sim.defense): return false
	if sim.defense.started or sim.failed or sim.won: return false
	if id == "crystal": return sim.defense.get("crystal_repair_required",false)
	if id in sim.progression.BUILDINGS:
		var item = sim.defense_director.structures.find(id)
		if item.get("owned",false) and item.hp <= 0: return false
	return sim.progression.cost(id) >= 0

static func description(sim, id: String) -> String:
	var profile = sim.progression
	if id == "unsupported_weapon": return "此装备无需升级"
	if id == "crystal":
		if sim.defense.get("crystal_repair_required",false): return "水晶已破损\n长按 E 修复\n修复完成立即开始进攻"
		return "水晶\n%d / %d" % [sim.defense.crystal_hp,sim.defense.crystal_max_hp]
	var price: int = profile.cost(id)
	var cost_text = "%d%s" % [price," 钻石" if id in profile.TALENTS else " 金币"] if price >= 0 else ""
	var level_text = "LV%d" % (profile.level(id)+1) if id not in profile.TALENTS else "LV%d / 5" % profile.level(id)
	if price < 0: level_text = "LV MAX"
	var detail = ""
	if id in profile.WEAPONS:
		var index: int = {"rifle":0,"pistol":2,"axe":6}[id]
		detail = NAMES[id]+"伤害 %s" % number(sim.arena.get_node("/root/Data").weapons[index].damage*profile.weapon_multiplier(id)*profile.damage_multiplier())
	elif id in profile.MAGAZINES:
		detail = "%s容量 %d" % [NAMES[id],sim.weapon_capacity(0 if id == "rifle_magazine" else 2)]
	elif id == "ultimate":
		level_text = "LV%d / 4" % profile.level(id) if price >= 0 else "LV MAX"
		detail = "伤害 %s · 持续10秒" % number(300*pow(1.2,maxi(0,profile.level(id)-1))*profile.damage_multiplier())
		var title = "解锁终极技能" if profile.level(id) == 0 else "终极技能  "+level_text.replace("LV MAX","已满级").replace("LV","等级 ")
		return (title+"\n"+detail+"\n"+cost_text).strip_edges()
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
			"strong": detail = "强壮 · 生命 %d · 回复 %s/s" % [profile.max_health(),number(profile.regen_rate())]
			"precise": detail = "本能 · 伤害 +%d%%" % (profile.level(id)*5)
			"swift": detail = "极速 · 终极技能冷却 -%d%%" % (profile.level(id)*10)
			"supply": detail = "补给 · 备弹 +%d%%" % (profile.level(id)*10)
			"greed": detail = "贪婪 · 金币 +%d%%" % (profile.level(id)*10)
	return (level_text+"\n"+detail+"\n"+("整备已结束" if sim.defense.started else cost_text)).strip_edges()

static func prompt_description(sim, id: String) -> String:
	if id in ["crystal","unsupported_weapon"]: return description(sim,id)
	var profile = sim.progression
	var title: String = NAMES.get(id,id)
	if id == "ultimate" and profile.level(id) == 0: title = "解锁终极技能"
	var price: int = profile.cost(id)
	var payment = str(price) if price >= 0 else "已满级"
	return title+"\n"+payment

static func upgrade_details(sim, id: String) -> Dictionary:
	if id in ["crystal","unsupported_weapon"] or not NAMES.has(id): return {}
	var profile = sim.progression
	var rank: int = profile.level(id)
	var maximum = 5 if id in profile.TALENTS else 4 if id in ["ultimate","grenade"] else 10
	var next_rank: int = mini(rank+1,maximum) if profile.cost(id) >= 0 else rank
	var rows: Array = []
	var note = ""
	if id in profile.WEAPONS:
		var base: float = sim.arena.get_node("/root/Data").weapons[{"rifle":0,"pistol":2,"axe":6}[id]].damage*profile.damage_multiplier()
		rows.append(["伤害",number(base*pow(1.2,rank)),number(base*pow(1.2,next_rank))])
	elif id in profile.MAGAZINES:
		var base: float = sim.arena.get_node("/root/Data").weapons[0 if id == "rifle_magazine" else 2].capacity
		rows.append(["弹匣容量",str(roundi(base*pow(1.2,rank))),str(roundi(base*pow(1.2,next_rank)))])
	elif id == "ultimate":
		rows.append(["伤害",number(300*pow(1.2,maxi(rank-1,0))*profile.damage_multiplier()) if rank > 0 else "未解锁",number(300*pow(1.2,maxi(next_rank-1,0))*profile.damage_multiplier())])
		rows.append(["持续时间","10秒","10秒"])
		var cooldown = number(preload("res://scripts/ultimate.gd").cooldown(profile))+"秒"
		rows.append(["冷却时间",cooldown,cooldown])
	elif id == "grenade": rows.append(["持有上限",str(1+rank),str(1+next_rank)])
	elif id == "strong":
		rows.append(["最大生命",str(100+10*rank),str(100+10*next_rank)])
		rows.append(["每秒回复",number(.5*rank),number(.5*next_rank)])
		note = "连续5秒未受伤后回复"
	elif id == "swift": rows.append(["技能冷却",str(100-10*rank)+"秒",str(100-10*next_rank)+"秒"])
	elif id in ["precise","supply","greed"]:
		var rate = 5 if id == "precise" else 10
		rows.append([{"precise":"伤害加成","supply":"备弹加成","greed":"金币加成"}[id],"+%d%%" % (rank*rate),"+%d%%" % (next_rank*rate)])
	elif id in profile.BUILDINGS:
		var owned: bool = profile.owned(id)
		var base = 1000.0 if id in profile.GATES else 60.0
		rows.append(["耐久" if id in profile.GATES else "伤害",number(base*pow(1.2,rank)) if owned else "未建造",number(base*pow(1.2,next_rank if owned else rank))])
	elif id in profile.MINES:
		rows.append(["最大伤害","1400","1400"])
		note = "距离衰减 · 本局引爆一次"
	if profile.cost(id) < 0: note = "已满级 · 无需继续升级"
	elif profile.data[profile.currency(id)] < profile.cost(id): note = "钻石不足" if id in profile.TALENTS else "金币不足"
	return {"title":NAMES[id],"level":"等级 %d / %d" % [rank,maximum],"rows":rows,"note":note}

static func number(value: float) -> String:
	return ("%.1f" % value).trim_suffix(".0")

static func gate_distance(box: AABB, origin: Vector3, direction: Vector3, reach: float) -> float:
	var near = 0.0
	var far = reach
	for axis in 3:
		if absf(direction[axis]) < .000001:
			if origin[axis] < box.position[axis] or origin[axis] > box.end[axis]: return -1.0
			continue
		var a = (box.position[axis]-origin[axis])/direction[axis]
		var b = (box.end[axis]-origin[axis])/direction[axis]
		near = maxf(near,minf(a,b))
		far = minf(far,maxf(a,b))
		if near > far: return -1.0
	return near

static func payment_interval(amount: int) -> float:
	return .18 if amount <= 100 else .09 if amount <= 1000 else .045
