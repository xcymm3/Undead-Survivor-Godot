extends RefCounted
## Authority-only equipment, pickups, healing and ballistic grenades.
var Layout:
	get: return director.Layout
const GUNS = [0,1,2,4,5,7,8,9]
const MAX_GRENADES = 3
const HEAL_SECONDS = 3.0
const GRENADE_FUSE = 1.5
const GRENADE_RADIUS = 11.0
const GRENADE_THROW_INTERVAL = 1.0
var director_ref: WeakRef
var director:
	get: return director_ref.get_ref()
var sim:
	get: return director.sim
var next_grenade = 0
var grenade_history: Array = []

func grab_point(p: Dictionary) -> Vector3:
	var forward = Vector3(-sin(p.yaw)*cos(p.pitch),sin(p.pitch),-cos(p.yaw)*cos(p.pitch))
	var right = Vector3(cos(p.yaw),0,-sin(p.yaw))
	return Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p)-.13,p.pos.y)+forward*.55+right*.19

func pickup_motion(p: Dictionary, point: Vector3, weapon := -1, slot := 0, old := -1) -> void:
	if not director.state.has("pickup_motion"): director.state.pickup_motion = []
	var serial: int = director.state.get("pickup_serial",0)+1
	director.state.pickup_serial = serial
	director.state.pickup_motion.append({"id":serial,"owner":p.id,"at":director.state.get("prop_clock",0.0),"from":point,"to":Vector3(p.pos.x,p.height+1.3,p.pos.y),"yaw":p.yaw,"weapon":weapon,"slot":slot,"old":old})
	director.state.pickup_motion[-1].drop = grab_point(p)
	director.state.pickup_motion[-1].to = grab_point(p)
	director.state.pickup_motion[-1].pitch = p.pitch
	while director.state.pickup_motion.size() > 24: director.state.pickup_motion.pop_front()
	if weapon >= 0:
		p.pickup_until = director.state.get("prop_clock",0.0)+.65
		p.pickup_remaining = .65

func _init(director_node) -> void:
	director_ref = weakref(director_node)

func initialize() -> void:
	for p in sim.pawns.values():
		p.secondary = 3
		p.slot = 1
		p.grenades = 0
		p.grenade_ready_at = 0.0
		p.healing = ""
		p.heal_time = 0.0
		p.being_healed = false
		p.use_latch = false
		p.pickup_latched = false
		p.heal_hurt = -100.0
		p.reserves = []
		p.reserves.resize(10)
		p.reserves.fill(0)
		p.reserves[p.primary] = p.reserve
		p.ammo[p.secondary] = int(Data.weapons[p.secondary].capacity)
		p.reserves[p.secondary] = Data.full_reserve(p.secondary)
	director.state.loot = []
	director.state.grenade_stations = {}
	director.state.medical_stations = {}
	director.state.projectiles = []
	for item in Layout.ITEMS:
		director.state.medical_stations[item.id] = {"remaining":director.state.party}
		if item.kind != "ammo": continue
		var tier: String = item.tier
		var source: Array = GUNS.filter(func(index): return Data.weapons[index].tier == tier)
		var pool: Array = []
		for i in director.state.party*2:
			if pool.is_empty():
				pool = source.duplicate()
				for j in pool.size():
					var k = sim.random.randi_range(j,pool.size()-1)
					var swap = pool[j]
					pool[j] = pool[k]
					pool[k] = swap
			var pos: Vector2 = item.pos+Vector2((i%2)*1.3-.65,-.62)
			director.state.loot.append({"id":item.id+"_gun_"+str(i),"station":item.id,"pos":pos,"mount_height":1.35+floori(i/2.0)*.55,"weapon":pool.pop_front(),"tier":tier,"taken":false})
		director.state.grenade_stations[item.id] = {"remaining":director.state.party,"claimed":[]}

func pickup_target(p: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var score = -10.0
	var forward = Vector2(-sin(p.yaw),-cos(p.yaw))
	var sight = Vector3(forward.x*cos(p.pitch),sin(p.pitch),forward.y*cos(p.pitch))
	var eye = Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p),p.pos.y)
	for loot in director.state.loot:
		if (loot.tier == "A" and not director.state.gate_open) or loot.taken or not director.near(p,loot.pos,2.5): continue
		var delta: Vector2 = loot.pos-p.pos
		var point = Vector3(loot.pos.x,loot.mount_height,loot.pos.y)
		var aim = sight.dot((point-eye).normalized())
		if delta.length() > .6 and aim < .35: continue
		var value = aim-delta.length()*.05
		if value > score:
			score = value
			best = {"id":loot.id,"label":"换取 "+loot.tier+" 级 "+Data.weapons[loot.weapon].label+"（替换"+("副武器" if loot.weapon in [2,3] else "主武器")+"）","seconds":.3}
	for item in Layout.ITEMS:
		var medical_pos: Vector2 = item.pos+Vector2(1,0) if item.kind == "ammo" else item.pos
		if p.medkits < 1 and director.state.medical_stations[item.id].remaining > 0 and director.near(p,medical_pos,2.0):
			var medical_delta: Vector2 = medical_pos-p.pos
			var medical_aim = sight.dot((Vector3(medical_pos.x,.8,medical_pos.y)-eye).normalized())
			var medical_score = medical_aim-medical_delta.length()*.05
			if medical_score > score and (medical_delta.length() <= .6 or medical_aim > .35):
				score = medical_score
				best = {"id":"medical:"+item.id,"label":"领取医疗包（恢复至100）","seconds":.25}
		if item.kind != "ammo" or not director.near(p,item.pos+Vector2(-1,0),2.0): continue
		var station: Dictionary = director.state.grenade_stations[item.id]
		if station.remaining > 0 and p.grenades < MAX_GRENADES:
			var delta: Vector2 = item.pos+Vector2(-1,0)-p.pos
			var point = Vector3(item.pos.x-1,.65,item.pos.y)
			var aim = sight.dot((point-eye).normalized())
			var value: float = aim-delta.length()*.05
			if value > score and (delta.length() <= .6 or aim > .35):
				score = value
				best = {"id":"grenade:"+item.id,"label":"领取手雷","seconds":.25}
	return best

func pickup(p: Dictionary, id: String) -> bool:
	# Recheck on completion: two clients cannot consume the same world item.
	if id.begins_with("medical:"):
		for item in Layout.ITEMS:
			if item.id != id.trim_prefix("medical:"): continue
			var point: Vector2 = item.pos+Vector2(1,0) if item.kind == "ammo" else item.pos
			var station: Dictionary = director.state.medical_stations[item.id]
			if p.medkits >= 1 or station.remaining <= 0 or not director.near(p,point,2.0): return false
			station.remaining -= 1
			p.medkits += 1
			pickup_motion(p,Vector3(point.x,.83,point.y),-1,5)
			if item.kind == "med" and station.remaining == 0: director.state.taken[item.id] = true
			p.pickup_latched = true
			return true
	if id.begins_with("grenade:"):
		var station_id = id.trim_prefix("grenade:")
		for item in Layout.ITEMS:
			if item.id != station_id or item.kind != "ammo" or not director.near(p,item.pos+Vector2(-1,0),2.0): continue
			var station: Dictionary = director.state.grenade_stations[item.id]
			if station.remaining <= 0 or p.grenades >= MAX_GRENADES: return false
			station.remaining -= 1
			if not station.claimed.has(p.id): station.claimed.append(p.id)
			p.grenades += 1
			pickup_motion(p,Vector3(item.pos.x-1,.85,item.pos.y),-1,4)
			p.pickup_latched = true
			return true
	for loot in director.state.loot:
		if loot.id != id or (loot.tier == "A" and not director.state.gate_open) or loot.taken or not director.near(p,loot.pos,2.5): continue
		loot.taken = true
		p.pickup_latched = true
		if not director.state.claimed.has(loot.station): director.state.claimed[loot.station] = []
		if not director.state.claimed[loot.station].has(p.id): director.state.claimed[loot.station].append(p.id)
		var key = "secondary" if loot.weapon in [2,3] else "primary"
		var old: int = p[key]
		pickup_motion(p,Vector3(loot.pos.x,loot.mount_height,loot.pos.y),loot.weapon,0,old)
		p.ammo[old] = 0
		p.reserves[old] = 0
		p[key] = loot.weapon
		p.ammo[loot.weapon] = int(Data.weapons[loot.weapon].capacity)
		p.reserves[loot.weapon] = Data.full_reserve(loot.weapon)
		p.reserve = p.reserves[p.primary]
		p.slot = 2 if key == "secondary" else 1
		p.weapon = loot.weapon
		p.requested = loot.weapon
		p.switch = .65
		p.reloading = false
		p.reload_queued = false
		p.reload = 0.0
		p.fire_anim = 0.0
		sim.melee_swings.erase(p.id)
		return true
	return false

static func slot_available(p: Dictionary, slot: int) -> bool:
	return slot >= 1 and slot <= 5 and (slot != 4 or p.get("grenades",0) > 0) and (slot != 5 or p.get("medkits",0) > 0)

func heal_target(p: Dictionary, other: bool) -> String:
	if not other: return p.id if p.hp > 0 and p.hp < 100 else ""
	var result = ""
	var best = .75
	var forward = Vector2(-sin(p.yaw),-cos(p.yaw))
	for q in sim.pawns.values():
		if q.id == p.id or q.hp <= 0 or q.hp >= 100 or not director.near(p,q.pos,2.5): continue
		var dot: float = forward.dot((q.pos-p.pos).normalized())
		if dot > best:
			best = dot
			result = q.id
	return result

func before_movement(dt: float) -> void:
	for p in sim.pawns.values(): p.being_healed = false
	for p in sim.pawns.values():
		var input: Dictionary = p.input if p.input_age < .5 else {}
		var requested: int = int(input.get("slot",p.slot))
		if not slot_available(p,requested): requested = p.slot if slot_available(p,p.slot) else 1
		if requested != p.slot:
			p.slot = requested
			p.use_latch = false
			p.healing = ""
			p.heal_time = 0.0
			p.reloading = false
			p.reload_queued = false
			p.reload = 0.0
			p.fire_anim = 0.0
			sim.melee_swings.erase(p.id)
		var click: bool = input.get("use_self",false) or input.get("use_other",false)
		var use: bool = input.get("fire",false)
		if p.hp <= 0:
			p.healing = ""
			p.heal_time = 0.0
		elif not p.healing.is_empty():
			var q: Dictionary = sim.pawns.get(p.healing,{})
			if p.slot != 5 or p.medkits <= 0 or input.is_empty() or q.is_empty() or q.hp <= 0 or q.hp >= 100 or p.hurt_at > p.heal_hurt or (q.id != p.id and not director.near(p,q.pos,2.5)):
				p.healing = ""
				p.heal_time = 0.0
			else:
				q.being_healed = true
				p.heal_time += dt
				if p.heal_time >= HEAL_SECONDS:
					p.medkits -= 1
					q.hp = 100
					p.healing = ""
					p.heal_time = 0.0
		elif (click or use and not p.use_latch) and p.interaction == "":
			if p.slot == 5 and p.medkits > 0:
				p.healing = heal_target(p,input.get("use_other",false))
				p.heal_hurt = p.hurt_at
				p.heal_time = 0.0
				if not p.healing.is_empty(): sim.pawns[p.healing].being_healed = true
			elif p.slot == 4 and (input.get("use_self",false) or input.get("fire",false)) and director.state.departed and p.grenades > 0:
				throw_grenade(p)
		if not slot_available(p,p.slot): p.slot = 1
		p.use_latch = use
		p.input["use_self"] = false
		p.input["use_other"] = false

func throw_grenade(p: Dictionary) -> bool:
	if p.grenades <= 0 or sim.elapsed < float(p.get("grenade_ready_at",0.0)): return false
	p.grenades -= 1
	p.grenade_ready_at = sim.elapsed+GRENADE_THROW_INTERVAL
	# Equipment is processed before movement commits this input's view direction.
	var yaw: float = p.input.get("yaw",p.yaw)
	var pitch: float = p.input.get("pitch",p.pitch)
	var direction = Vector3(-sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))
	var origin = Vector3(p.pos.x,p.height+1.4,p.pos.y)
	director.state.projectiles.append({"id":next_grenade,"owner":p.id,"pos":origin,"velocity":direction*12+Vector3.UP*3,"fuse":GRENADE_FUSE,"tick_at":1.2})
	sim.events.append({"kind":"grenade_throw","position":origin})
	grenade_history.append({"id":next_grenade,"owner":p.id,"thrown_at":sim.elapsed,"origin":origin,"hits":[],"kills":0,"damage":0.0})
	next_grenade += 1
	return true

func step_projectiles(dt: float) -> void:
	for grenade in director.state.projectiles:
		var remaining = dt
		while remaining > .00001:
			var step_time = minf(remaining,.02)
			remaining -= step_time
			grenade.velocity.y -= 9.8*step_time
			var next: Vector3 = grenade.pos+grenade.velocity*step_time
			var hit = sim.arena.surface_hit(grenade.pos,next)
			if not hit.is_empty():
				grenade.pos = hit.position+hit.normal*.08
				grenade.velocity = grenade.velocity.bounce(hit.normal)*.4
			else: grenade.pos = next
		grenade.fuse -= dt
		if grenade.fuse > 0 and grenade.fuse <= grenade.get("tick_at",1.2):
			sim.events.append({"kind":"grenade_fuse","position":grenade.pos})
			grenade.tick_at = grenade.fuse-(.15 if grenade.fuse < .6 else .3)
		if grenade.fuse <= 0: explode(grenade)
	director.state.projectiles = director.state.projectiles.filter(func(g): return g.fuse > 0)

func explode(grenade: Dictionary) -> void:
	var owner: Dictionary = sim.pawns.get(grenade.owner,{"id":grenade.owner,"kills":0})
	var record: Dictionary = {}
	var pawn_health: Dictionary = {}
	for pawn in sim.pawns.values(): pawn_health[pawn.id] = pawn.hp
	for entry in grenade_history:
		if entry.id == grenade.get("id",-1): record = entry
	if not record.is_empty():
		record["exploded_at"] = sim.elapsed
		record["position"] = grenade.pos
		record["self_damage"] = 0
		record["friendly_damage"] = 0
	for z in sim.zombies:
		if z.hp <= 0: continue
		var target = Vector3(z.pos.x,Data.enemy_ground_height(z.pos,sim.map_id)+1,z.pos.y)
		var distance: float = grenade.pos.distance_to(target)
		if distance > GRENADE_RADIUS or not sim.arena.surface_hit(grenade.pos,target).is_empty(): continue
		var health_before: float = z.hp
		var kind_before: String = z.kind
		sim.hit_enemy(z,lerpf(700,150,distance/GRENADE_RADIUS),true,owner,target,Vector2(grenade.pos.x,grenade.pos.z))
		if not record.is_empty():
			record.hits.append({"id":z.id,"kind":kind_before,"distance":distance,"damage":health_before-z.hp,"killed":z.hp <= 0})
			record.damage += health_before-z.hp
			if z.hp <= 0: record.kills += 1
		sim.stun(z,1.0)
	# Campaign grenades currently damage enemies only, consistently with gunfire.
	if not record.is_empty():
		for pawn in sim.pawns.values():
			var lost: int = maxi(0,int(pawn_health[pawn.id])-int(pawn.hp))
			if pawn.id == grenade.owner: record.self_damage += lost
			else: record.friendly_damage += lost
	sim.events.append({"kind":"explosion","position":grenade.pos})
