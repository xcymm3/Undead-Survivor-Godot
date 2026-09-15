extends RefCounted
## Authority-only equipment, pickups, healing and ballistic grenades.
var Layout:
	get: return director.Layout
const GUNS = [0,1,2,3,4,5,7,8,9]
const HEAL_SECONDS = 3.0
const GRENADE_FUSE = 3.0
const GRENADE_RADIUS = 8.0
var director_ref: WeakRef
var director:
	get: return director_ref.get_ref()
var sim:
	get: return director.sim
var next_grenade = 0
var grenade_history: Array = []

func _init(director_node) -> void:
	director_ref = weakref(director_node)

func initialize() -> void:
	for p in sim.pawns.values():
		p.secondary = 3
		p.slot = 1
		p.grenades = 0
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
		p.reserves[p.secondary] = 5*int(Data.weapons[p.secondary].capacity)
	director.state.loot = []
	director.state.grenade_stations = {}
	director.state.projectiles = []
	for item in Layout.ITEMS:
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
			var pos: Vector2 = item.pos+Vector2((i%2)*.8-.4,(i/2)*.45-.65)
			director.state.loot.append({"id":item.id+"_gun_"+str(i),"station":item.id,"pos":pos,"weapon":pool.pop_front(),"tier":tier,"taken":false})
		director.state.grenade_stations[item.id] = {"remaining":director.state.party,"claimed":[]}

func pickup_target(p: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var score = -10.0
	var forward = Vector2(-sin(p.yaw),-cos(p.yaw))
	for loot in director.state.loot:
		if (loot.tier == "A" and not director.state.gate_open) or loot.taken or not director.near(p,loot.pos,2.5): continue
		var delta: Vector2 = loot.pos-p.pos
		var aim = forward.dot(delta.normalized())
		if delta.length() > .6 and aim < .35: continue
		var value = aim-delta.length()*.05
		if value > score:
			score = value
			best = {"id":loot.id,"label":"换取 "+loot.tier+" 级 "+Data.weapons[loot.weapon].label+"（替换"+("副武器" if loot.weapon in [2,3] else "主武器")+"）","seconds":.3}
	for item in Layout.ITEMS:
		if item.kind != "ammo" or not director.near(p,item.pos+Vector2(-1,0),2.0): continue
		var station: Dictionary = director.state.grenade_stations[item.id]
		if station.remaining > 0 and p.grenades < 1:
			var delta: Vector2 = item.pos+Vector2(-1,0)-p.pos
			var value: float = forward.dot(delta.normalized())-delta.length()*.05
			if value > score and (delta.length() <= .6 or forward.dot(delta.normalized()) > .35):
				score = value
				best = {"id":"grenade:"+item.id,"label":"领取手雷","seconds":.25}
	return best

func pickup(p: Dictionary, id: String) -> bool:
	# Recheck on completion: two clients cannot consume the same world item.
	if id.begins_with("grenade:"):
		var station_id = id.trim_prefix("grenade:")
		for item in Layout.ITEMS:
			if item.id != station_id or item.kind != "ammo" or not director.near(p,item.pos+Vector2(-1,0),2.0): continue
			var station: Dictionary = director.state.grenade_stations[item.id]
			if station.remaining <= 0 or p.grenades >= 1: return false
			station.remaining -= 1
			if not station.claimed.has(p.id): station.claimed.append(p.id)
			p.grenades += 1
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
		p.ammo[old] = 0
		p.reserves[old] = 0
		p[key] = loot.weapon
		p.ammo[loot.weapon] = int(Data.weapons[loot.weapon].capacity)
		p.reserves[loot.weapon] = 5*int(Data.weapons[loot.weapon].capacity)
		p.reserve = p.reserves[p.primary]
		p.slot = 2 if key == "secondary" else 1
		p.weapon = loot.weapon
		p.requested = loot.weapon
		p.switch = .4
		p.reloading = false
		p.reload_queued = false
		p.reload = 0.0
		p.fire_anim = 0.0
		sim.melee_swings.erase(p.id)
		return true
	return false

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
		var use: bool = input.get("fire",false) or input.get("aim",false)
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
					q.hp = mini(100,q.hp+50)
					p.healing = ""
					p.heal_time = 0.0
		elif (click or use and not p.use_latch) and p.interaction == "":
			if p.slot == 5 and p.medkits > 0:
				p.healing = heal_target(p,input.get("use_other",false) or input.get("aim",false))
				p.heal_hurt = p.hurt_at
				p.heal_time = 0.0
				if not p.healing.is_empty(): sim.pawns[p.healing].being_healed = true
			elif p.slot == 4 and (input.get("use_self",false) or input.get("fire",false)) and director.state.departed and p.grenades > 0:
				throw_grenade(p)
		p.use_latch = use
		p.input["use_self"] = false
		p.input["use_other"] = false

func throw_grenade(p: Dictionary) -> void:
	p.grenades -= 1
	var direction = Vector3(-sin(p.yaw)*cos(p.pitch),sin(p.pitch),-cos(p.yaw)*cos(p.pitch))
	var origin = Vector3(p.pos.x,p.height+1.4,p.pos.y)
	director.state.projectiles.append({"id":next_grenade,"owner":p.id,"pos":origin,"velocity":direction*12+Vector3.UP*3,"fuse":GRENADE_FUSE})
	grenade_history.append({"id":next_grenade,"owner":p.id,"thrown_at":sim.elapsed,"origin":origin,"hits":[],"kills":0,"damage":0.0})
	next_grenade += 1

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
		sim.hit_enemy(z,lerpf(700,150,distance/GRENADE_RADIUS),true,owner,target)
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
