extends RefCounted
## The sole authority for movement, ammunition, enemies, damage and score, shared by solo/coop.
const EnemyView = preload("res://scripts/enemy_view.gd")
var arena
var pawns: Dictionary = {}
var zombies: Array = []
var events: Array = []
var mode = "survival"
var elapsed = 0.0
var wave = 1
var cleared = 0
var spawned = 0
var kills = 0
var rest = 0.0
var credit = 0.0
var roster: Array = []
var next_id = 0
var failed = false
var cause = "zombie"
var culprit = -1
var random = RandomNumberGenerator.new()
var paths: Dictionary = {}
var crowd_buckets: Dictionary = {}
# Authority-only swing history; clients receive the resulting damage and animation.
var melee_swings: Dictionary = {}
const MELEE_START = .22
const MELEE_END = .66
const MELEE_HALF_WIDTH = 20.0
const CHARGE_DURATION = 4.0
const CHARGE_DAMAGE = 30
const CHARGE_KNOCKBACK = .65
const CHARGE_WALL_STUN = 2.0

func _init(world = null) -> void:
	arena = world
	random.randomize()

func add_pawn(id: String, player_name: String, index: int) -> void:
	var ammo: Array = []
	for w in Data.weapons: ammo.append(int(w.capacity))
	# The authority draws without replacement; snapshots carry the stable result.
	var available = range(Data.MODELS.size())
	for pawn in pawns.values(): available.erase(int(pawn.appearance[0]))
	if available.is_empty(): available = range(Data.MODELS.size())
	var model: int = available[random.randi_range(0,available.size()-1)]
	pawns[id] = {"id":id,"name":player_name,"pos":Vector2((index%2)*2.8-1.4,9+floori(index/2.0)*2.6),"yaw":0.0,"pitch":0.0,"height":0.0,"velocity":0.0,"air":Vector2.ZERO,"hp":100,"protection":0.0,"weapon":0,"requested":0,"switch":0.0,"ammo":ammo,"cooldown":0.0,"fire_anim":0.0,"reload":0.0,"reload_queued":false,"reloading":false,"shots":0,"gun_shots":[0,0,0,0,0,0,0,0,0,0],"hits":0,"kills":0,"aim":false,"trigger":false,"input":{},"input_age":0.0,"appearance":[model,0,0]}

func start(game_mode: String) -> void:
	mode = game_mode
	if mode == "practice":
		for pos in Data.PRACTICE: spawn(pos,"normal")
	else: prepare_wave()

func prepare_wave() -> void:
	roster.clear()
	var weights: Array = [1,0,0,0] if wave <= 2 else [.8,.2,0,0] if wave <= 4 else [.64,.26,.1,0] if wave <= 6 else [.5,.28,.17,.05] if wave <= 8 else [.38,.3,.24,.08] if wave <= 10 else [.32,.3,.28,.1]
	var pools = [["normal","cone","bucket"],["imp","shield"],["berserker","giant"],["football"]]
	var odds = [[.6,.27,.13],[.6,.4],[.75,.25],[1.0]]
	for i in Data.wave_settings(wave).count:
		var tier = weighted(weights)
		roster.append(pools[tier][weighted(odds[tier])])
	if wave in [7,8] and not roster.has("football"): roster[-1] = "football"

func weighted(weights: Array) -> int:
	var roll = random.randf()
	for i in weights.size():
		roll -= weights[i]
		if roll < 0: return i
	return weights.size()-1

func spawn(pos: Vector2, kind: String) -> void:
	var def: Dictionary = Data.enemies[kind]
	zombies.append({"id":next_id,"pos":pos,"kind":kind,"original":kind,"hp":float(def.health),"body":float(def.health-def.armor),"armor":float(def.armor),"down":0.0,"born":elapsed,"heading":0.0,"attack_time":0.0,"target":"","rage":false,"rage_pause":0.0,"state":"ready","state_time":0.0,"charge_cooldown":0.0,"charge_direction":Vector2.ZERO,"charge_target":Vector2.ZERO})
	next_id += 1

func submit(id: String, input: Dictionary) -> void:
	if not pawns.has(id): return
	# No client position, HP, ammo, damage or kill fields are accepted.
	var clean = {}
	for key in ["x","y","yaw","pitch","weapon"]:
		var value = input.get(key,0)
		if not (value is int or value is float) or not is_finite(float(value)): return
		clean[key] = float(value)
	clean.x = clampf(clean.x,-1,1)
	clean.y = clampf(clean.y,-1,1)
	clean.yaw = wrapf(clean.yaw,-PI,PI)
	clean.pitch = clampf(clean.pitch,-deg_to_rad(85),deg_to_rad(85))
	clean.weapon = clampi(int(clean.weapon),0,9)
	for key in ["jump","fire","reload","aim"]: clean[key] = input.get(key,false) == true
	pawns[id].input = clean
	pawns[id].input_age = 0.0

func step(dt: float) -> void:
	events.clear()
	if failed: return
	for id in melee_swings.keys():
		if not pawns.has(id) or pawns[id].hp <= 0: melee_swings.erase(id)
	elapsed += dt
	for p in pawns.values(): update_pawn(p,dt)
	crowd_buckets.clear()
	for z in zombies:
		if z.hp <= 0: continue
		var key = Vector2i(floori(z.pos.x/3),floori(z.pos.y/3))
		if not crowd_buckets.has(key): crowd_buckets[key] = []
		crowd_buckets[key].append(z)
	var living: Array = pawns.values().filter(func(p): return p.hp > 0)
	if living.is_empty():
		failed = true
		return
	for z in zombies:
		if z.hp <= 0:
			z.down -= dt
			if mode == "practice" and z.down <= 0:
				z.hp = Data.enemies[z.original].health
				z.body = z.hp
				z.kind = z.original
			continue
		if mode == "practice": continue
		var target: Dictionary = living[0]
		for p in living:
			if z.pos.distance_squared_to(p.pos) < z.pos.distance_squared_to(target.pos): target = p
		update_zombie(z,target,dt)
	if mode == "practice": return
	zombies = zombies.filter(func(z): return z.hp > 0 or z.down > 0)
	if pawns.values().all(func(p): return p.hp <= 0):
		failed = true
		return
	if rest > 0:
		rest = maxf(0,rest-dt)
		if rest <= 0:
			wave += 1
			spawned = 0
			credit = 0
			prepare_wave()
		return
	if roster.is_empty() and alive_count() == 0:
		cleared = wave
		rest = 3
		for p in pawns.values():
			if p.hp <= 0:
				p.pos = safe_spawn()
				p.height = 0.0
				p.velocity = 0.0
			p.hp = 100
			p.protection = 0.0
		return
	if roster.is_empty(): return
	credit = minf(1,credit+dt*Data.wave_settings(wave).rate)
	if credit < 1: return
	var entries: Array = Array(Data.SPAWNS).duplicate()
	entries.shuffle()
	for point in entries:
		var safe = true
		for p in living:
			var delta: Vector2 = point-p.pos
			if delta.length() < 8: safe = false
		if not safe or not arena.clear(point,point): continue
		if zombies.any(func(z): return z.hp > 0 and point.distance_to(z.pos) < 2.0): continue
		spawn(point,roster[0])
		roster.remove_at(0)
		spawned += 1
		credit = 0
		break

func safe_spawn() -> Vector2:
	for p in [Vector2(0,9),Vector2(-3,9),Vector2(3,9),Vector2(0,5)]:
		if arena.clear(p,p,true) and not Data.water(p) and zombies.all(func(z): return z.hp <= 0 or p.distance_to(z.pos) > 2): return p
	return Vector2(0,9)

func alive_count() -> int:
	return zombies.filter(func(z): return z.hp > 0).size()

func can_move(p: Dictionary, point: Vector2) -> bool:
	if not arena.clear(p.pos,point,true): return false
	if p.height >= 1.1: return true
	for z in zombies:
		if z.hp <= 0: continue
		if point.distance_to(z.pos) < Data.contact(z.kind) and point.distance_to(z.pos) < p.pos.distance_to(z.pos)-.00001: return false
	return true

func update_pawn(p: Dictionary, dt: float) -> void:
	p.protection = maxf(0,p.protection-dt)
	p.cooldown = maxf(0,p.cooldown-dt)
	p.fire_anim = maxf(0,p.fire_anim-dt)
	p.input_age += dt
	var input: Dictionary = p.input if p.input_age < .5 else {}
	if p.hp <= 0: return
	p.yaw = input.get("yaw",p.yaw)
	p.pitch = input.get("pitch",p.pitch)
	var movement = Vector2(input.get("x",0),input.get("y",0)).limit_length()
	if input.get("jump",false) and p.height <= 0 and p.velocity == 0:
		p.velocity = 8.4
		p.air = movement
	if p.height > 0 or p.velocity > 0: movement = p.air
	var dir = Vector2(movement.x*cos(p.yaw)+movement.y*sin(p.yaw), -movement.x*sin(p.yaw)+movement.y*cos(p.yaw))
	var remaining = dt
	while remaining > .00001:
		var step_time = minf(.01,remaining)
		remaining -= step_time
		var next: Vector2 = p.pos+dir*4.2*step_time
		next = next.clamp(Vector2(-21.05,-47.05),Vector2(21.05,13.05))
		if can_move(p,next): p.pos = next
		else:
			var horizontal = Vector2(next.x,p.pos.y)
			if can_move(p,horizontal): p.pos = horizontal
			var vertical = Vector2(p.pos.x,next.y)
			if can_move(p,vertical): p.pos = vertical
		if p.height > 0 or p.velocity > 0:
			p.height += p.velocity*step_time-9*step_time*step_time
			p.velocity -= 18*step_time
			if p.height <= 0 and p.velocity < 0:
				p.height = 0.0
				p.velocity = 0.0
		if p.height <= 0 and Data.water(p.pos,.22):
			p.hp = maxi(0,p.hp-10)
			p.pos = safe_spawn()
			p.height = 0.0
			p.velocity = 0.0
			p.protection = .3
			events.append({"kind":"hurt","player":p.id})
			if p.hp == 0: cause = "water"
			break
	p.input.jump = false
	update_arsenal(p,input,dt)

func update_arsenal(p: Dictionary, input: Dictionary, dt: float) -> void:
	var w: Dictionary = Data.weapons[p.weapon]
	update_melee_swing(p,w)
	var requested: int = input.get("weapon",p.weapon)
	if requested != p.requested:
		p.requested = requested
		p.reload_queued = false
	if p.reloading and p.requested != p.weapon:
		# Keep already loaded shells; an unfinished magazine grants no ammunition.
		p.reloading = false
		p.reload = 0.0
		p.reload_queued = false
		p.input.reload = false
	p.aim = input.get("aim",false) and not p.reloading and p.switch <= 0 and p.requested == p.weapon
	if p.switch > 0:
		var before: float = p.switch
		p.switch = maxf(0,p.switch-dt)
		if before > .2 and p.switch <= .2: p.weapon = p.requested
		return
	if p.reloading:
		p.reload -= dt
		if p.reload <= 0:
			if w.get("shellReload",false):
				p.ammo[p.weapon] = mini(int(w.capacity),p.ammo[p.weapon]+1)
				p.reload = w.reloadDuration
				events.append({"kind":"reload","player":p.id})
				if p.ammo[p.weapon] >= w.capacity: p.reloading = false
			else:
				p.ammo[p.weapon] = int(w.capacity)
				p.reloading = false
		return
	if p.requested != p.weapon and p.fire_anim <= 0:
		p.switch = .4
		p.aim = false
		return
	if input.get("reload",false) and not w.get("infiniteAmmo",false) and p.ammo[p.weapon] < w.capacity: p.reload_queued = true
	p.input.reload = false
	if p.reload_queued and p.fire_anim <= 0:
		p.reload = w.reloadDuration
		p.reloading = true
		p.reload_queued = false
		p.aim = false
		events.append({"kind":"reload","player":p.id})
		return
	var trigger: bool = input.get("fire",false)
	if trigger and (w.automatic or not p.trigger) and p.cooldown <= 0 and p.fire_anim <= .00001:
		if p.ammo[p.weapon] > 0 or w.get("infiniteAmmo",false):
			if not w.get("infiniteAmmo",false): p.ammo[p.weapon] -= 1
			p.cooldown = w.interval
			p.fire_anim = w.fireDuration
			p.shots += 1
			fire(p,w)
			p.gun_shots[p.weapon] += 1
	p.trigger = trigger

func damage_pawn(p: Dictionary, z: Dictionary, amount := 10) -> bool:
	if p.protection > 0 or p.hp <= 0 or p.height >= 1.1: return false
	p.hp = maxi(0,p.hp-amount)
	p.protection = .3
	events.append({"kind":"hurt","player":p.id})
	if p.hp == 0:
		cause = "zombie"
		culprit = int(z.id)
	return true

func charge_knockback(p: Dictionary, direction: Vector2) -> void:
	# Short authority-side displacement, clipped against terrain and other enemies.
	for i in 13:
		var next: Vector2 = p.pos+direction*(CHARGE_KNOCKBACK/13.0)
		if not arena.clear(p.pos,next) or not can_move(p,next): break
		p.pos = next

func update_zombie(z: Dictionary, target: Dictionary, dt: float) -> void:
	var delta: Vector2 = target.pos-z.pos
	var distance = delta.length()
	var contact = Data.contact(z.kind)
	var base_speed: float = Data.wave_settings(wave).speed
	var speed: float = base_speed
	z.rage_pause = maxf(0,z.rage_pause-dt)
	z.charge_cooldown = maxf(0,z.charge_cooldown-dt)
	if z.kind == "imp": speed = minf(4,base_speed*1.75)
	if z.kind == "shield": speed = minf(3.6,base_speed*1.1)
	if z.kind == "giant": speed *= .75
	if z.kind == "berserker": speed = minf(5.8,base_speed*(2.6 if z.rage else 1.35))
	if z.kind == "football": speed = minf(3.3,base_speed*(1.25 if z.armor > 0 else 1.05))
	if z.rage_pause > 0: return
	if z.state == "windup":
		z.charge_target = target.pos
		z.heading = atan2(delta.x,delta.y)
		if not arena.clear(z.pos,z.charge_target):
			cancel_charge(z)
			return
	if z.state in ["windup","stunned","charging"]:
		z.state_time -= dt
		if z.state_time <= 0:
			if z.state == "windup":
				z.state = "charging"
				z.state_time = CHARGE_DURATION
				z.charge_direction = delta.normalized()
			elif z.state == "charging": stun(z,.45)
			else: z.state = "ready"
		if z.state == "windup" and not arena.clear(z.pos,z.charge_target): cancel_charge(z)
		if z.state in ["windup","stunned"]: return
	if z.kind == "football" and z.state == "ready" and z.armor > 0 and z.charge_cooldown <= 0 and distance >= 5 and distance <= minf(16,minf(10,base_speed*4.2)*CHARGE_DURATION+contact) and arena.clear(z.pos,target.pos):
		z.state = "windup"
		z.state_time = .35
		z.charge_direction = Vector2.ZERO
		z.charge_target = target.pos
		z.heading = atan2(delta.x,delta.y)
		z.attack_time = 0.0
		return
	if z.state == "charging":
		var next: Vector2 = z.pos+z.charge_direction*minf(10,base_speed*4.2)*dt
		if not arena.clear(z.pos,next):
			if arena.clear(z.pos,next,true): cancel_charge(z)
			else: stun(z,CHARGE_WALL_STUN)
			return
		z.pos = next
		for p in pawns.values():
			if p.hp > 0 and z.pos.distance_to(p.pos) <= contact and p.height < 1.1:
				if damage_pawn(p,z,CHARGE_DAMAGE): charge_knockback(p,z.charge_direction)
				z.state = "ready"
				z.charge_cooldown = 3.2
				break
		return
	if distance <= contact and target.height < 1.1:
		if z.target != target.id: z.attack_time = 0.0
		z.target = target.id
		z.heading = atan2(delta.x,delta.y)
		var profile = Data.attack(z.kind,z.rage)
		var before: float = z.attack_time
		z.attack_time += dt
		if before < profile.x and z.attack_time >= profile.x:
			if z.kind == "giant":
				for p in pawns.values():
					if z.pos.distance_to(p.pos) <= 2.4: damage_pawn(p,z)
			else: damage_pawn(target,z)
		if z.attack_time >= profile.y: z.attack_time = 0.0
		return
	z.attack_time = 0.0
	var direction = delta.normalized()
	var cached: Dictionary = paths.get(z.id,{"until":0.0,"path":PackedVector2Array(),"goal":Vector2.INF,"direct_until":0.0,"direct":false})
	if elapsed >= cached.get("direct_until",0.0) or cached.goal.distance_to(target.pos) > .65:
		cached.direct = arena.clear(z.pos,target.pos)
		cached.direct_until = elapsed+.15+fmod(z.id*.027,.12)
		cached.goal = target.pos
		paths[z.id] = cached
	if not cached.get("direct",false):
		if elapsed >= cached.until or cached.goal.distance_to(target.pos) > 1.3:
			cached.until = elapsed+.65+fmod(z.id*.037,.25)
			cached.path = arena.path_to(z.pos,target.pos)
			cached.goal = target.pos
			paths[z.id] = cached
		var route: PackedVector2Array = cached.path
		while route.size() > 1 and z.pos.distance_to(route[0]) < .4: route.remove_at(0)
		cached.path = route
		if route.is_empty(): return
		direction = (route[0]-z.pos).normalized()
	var separation = Vector2.ZERO
	var cell = Vector2i(floori(z.pos.x/3),floori(z.pos.y/3))
	var radius = 2.1 if z.kind == "giant" else .85 if z.kind == "imp" else 1.35
	for y in range(-1,2):
		for x in range(-1,2):
			for other in crowd_buckets.get(cell+Vector2i(x,y),[]):
				if other.id == z.id or other.hp <= 0: continue
				var offset: Vector2 = z.pos-other.pos
				var d = offset.length_squared()
				if d > .001 and d < radius*radius: separation += offset.normalized()*(radius-sqrt(d))
	direction = (direction+separation.limit_length(.25)).normalized()
	var next: Vector2 = z.pos+direction*minf(speed*dt,maxf(0,distance-contact*.96))
	if arena.clear(z.pos,next): z.pos = next
	else:
		var x = Vector2(next.x,z.pos.y)
		if arena.clear(z.pos,x): z.pos = x
		var y = Vector2(z.pos.x,next.y)
		if arena.clear(z.pos,y): z.pos = y
	if direction.length_squared() > .01: z.heading = atan2(direction.x,direction.y)

func cancel_charge(z: Dictionary) -> void:
	z.state = "ready"
	z.state_time = 0.0
	z.charge_cooldown = .6

func stun(z: Dictionary, duration: float) -> void:
	z.state = "stunned"
	z.state_time = duration
	z.charge_cooldown = 3.2
	z.attack_time = 0.0

func hit_enemy(z: Dictionary, amount: float, armor_contact: bool, p: Dictionary, position: Vector3) -> void:
	if z.hp <= 0: return
	var armor_kind: String = z.kind if z.armor > 0 and armor_contact else ""
	if not armor_kind.is_empty():
		var absorbed = minf(z.armor,amount)
		z.armor -= absorbed
		amount -= absorbed
	z.body = maxf(0,z.body-amount)
	z.hp = z.body+z.armor
	if not armor_kind.is_empty():
		events.append({"kind":"armor","player":p.id,"armor":armor_kind,"broken":z.armor <= 0,"position":position})
		if z.armor <= 0 and z.kind in ["cone","bucket"]: z.kind = "normal"
		if z.armor <= 0 and z.kind == "football":
			cancel_charge(z)
			z.charge_cooldown = 3.2
	if z.kind == "berserker" and not z.rage and z.hp > 0 and z.hp <= 600:
		z.rage = true
		z.rage_pause = .3
		z.attack_time = 0.0
	if z.body <= 0:
		z.hp = 0.0
		z.armor = 0.0
		z.down = 3.0 if mode == "practice" else .85
		z.attack_time = 0.0
		kills += 1
		p.kills += 1
		paths.erase(z.id)
		events.append({"kind":"death","player":p.id,"position":position})
	else: events.append({"kind":"blood","player":p.id,"position":position})

func update_melee_swing(p: Dictionary, w: Dictionary) -> void:
	if not melee_swings.has(p.id): return
	var swing: Dictionary = melee_swings[p.id]
	if p.hp <= 0 or p.weapon != swing.weapon or p.reloading:
		melee_swings.erase(p.id)
		return
	var progress = clampf(1.0-p.fire_anim/w.fireDuration,0,1)
	var previous: float = swing.progress
	swing.progress = progress
	# Check the whole interval traversed this tick, including ticks crossing both boundaries.
	if progress >= MELEE_START and previous < MELEE_END:
		var first = clampf((previous-MELEE_START)/(MELEE_END-MELEE_START),0,1)
		var last = clampf((progress-MELEE_START)/(MELEE_END-MELEE_START),0,1)
		var right_edge = deg_to_rad(lerpf(65,-65,first)+MELEE_HALF_WIDTH)
		var left_edge = deg_to_rad(lerpf(65,-65,last)-MELEE_HALF_WIDTH)
		var origin = Vector3(p.pos.x,p.height+1.2,p.pos.y)
		var facing = Basis(Vector3.UP,p.yaw)
		var reach: float = w.range
		# A generous vertical blade volume moves down with the diagonal swing.
		var upper = p.height+lerpf(1.7,.7,first)+1.1+sin(p.pitch)*1.2
		var lower = p.height+lerpf(1.7,.7,last)-1.1+sin(p.pitch)*1.2
		for z in zombies:
			if z.hp <= 0 or swing.damaged.has(z.id): continue
			if p.pos.distance_to(z.pos) > reach+Data.enemy_scale(z.kind)*1.5: continue
			var poses: Array = EnemyView.transforms(z,elapsed,mode == "practice")
			var contacts: Array[Vector3] = []
			for i in Data.parts.size():
				var part: Dictionary = Data.parts[i]
				if (part.has("kind") and part.kind != z.kind) or (part.get("armor",false) and z.armor <= 0): continue
				var pose: Transform3D = poses[i]
				# Closest point on each animated body box keeps nearby and large enemies hittable.
				var local = pose.affine_inverse()*origin
				var point = pose*local.clamp(Vector3.ONE*-.5,Vector3.ONE*.5)
				if point.distance_squared_to(origin) < .000001: point = pose.origin
				var offset = point-origin
				if offset.length() > reach or point.y < lower or point.y > upper: continue
				var relative = facing.inverse()*offset
				var angle = atan2(relative.x,-relative.z)
				if angle < left_edge or angle > right_edge: continue
				contacts.append(point)
			contacts.sort_custom(func(a,b): return origin.distance_squared_to(a) < origin.distance_squared_to(b))
			for point in contacts:
				var offset: Vector3 = point-origin
				if offset.length_squared() < .000001: continue
				var direction = offset.normalized()
				var distance = minf(reach,offset.length()+.02)
				var wall: Dictionary = arena.surface_hit(origin,origin+direction*distance)
				if not wall.is_empty(): distance = origin.distance_to(wall.position)
				var hit = EnemyView.hit(z,origin,direction,distance,elapsed,mode == "practice")
				if hit.is_empty(): continue
				swing.damaged[z.id] = true
				if not swing.landed:
					p.hits += 1
					swing.landed = true
				hit_enemy(z,w.damage*(w.get("headshotMultiplier",1) if hit.head else 1),hit.armor,p,origin+direction*hit.distance)
				break
	if progress >= MELEE_END: melee_swings.erase(p.id)

func fire(p: Dictionary, w: Dictionary) -> void:
	if w.get("kind","gun") == "melee":
		melee_swings[p.id] = {"weapon":p.weapon,"progress":0.0,"damaged":{},"landed":false}
		var origin = Vector3(p.pos.x,p.height+1.2,p.pos.y)
		events.append({"kind":"shot","player":p.id,"weapon":p.weapon,"from":origin,"to":origin})
		return
	var camera = Transform3D(Basis.from_euler(Vector3(p.pitch,p.yaw,0)),Vector3(p.pos.x,p.height+1.7,p.pos.y))
	var forward = -camera.basis.z
	var reach: float = w.get("range",180.0)
	var target = camera.origin+forward*reach
	var surface: Dictionary = arena.surface_hit(camera.origin,target)
	if not surface.is_empty(): target = surface.position
	var closest = camera.origin.distance_to(target)
	for z in zombies:
		if z.hp <= 0: continue
		var impact = EnemyView.hit(z,camera.origin,forward,closest,elapsed,mode == "practice")
		if not impact.is_empty():
			closest = impact.distance
			target = camera.origin+forward*closest
	var muzzle = camera*Vector3(.24,-.18,-.5)
	# A camera-to-muzzle trace also prevents firing through an obstacle enclosing the barrel.
	var obstruction: Dictionary = arena.surface_hit(camera.origin,muzzle)
	if not obstruction.is_empty():
		var blocked_shot = {"kind":"shot","player":p.id,"weapon":p.weapon,"from":camera.origin,"to":obstruction.position}
		if w.id in ["shotgun", "auto-shotgun"]: blocked_shot.pellet_ends = [obstruction.position]
		events.append(blocked_shot)
		return
	var direction = (target-muzzle).normalized()
	var weapon_kind: String = w.get("kind","gun")
	var damaged: Dictionary = {}
	var landed = false
	var right = direction.cross(Vector3.UP).normalized()
	var up = right.cross(direction).normalized()
	var pellet_ends: Array[Vector3] = []
	for pellet in int(w.pellets):
		var offset = Data.pellet(w,pellet,p.gun_shots[p.weapon]+1)
		var ray = (direction+right*offset.x+up*offset.y).normalized()
		var end = muzzle+ray*reach
		var wall: Dictionary = arena.surface_hit(muzzle,end)
		var distance = muzzle.distance_to(wall.position) if not wall.is_empty() else reach
		var candidates: Array = []
		for z in zombies:
			if z.hp <= 0: continue
			var candidate = EnemyView.hit(z,muzzle,ray,distance,elapsed,mode == "practice")
			if not candidate.is_empty(): candidates.append(candidate)
		candidates.sort_custom(func(a,b): return a.distance < b.distance)
		if not w.get("piercing",false) and candidates.size() > 1: candidates.resize(1)
		for hit in candidates:
			if (w.get("piercing",false) or weapon_kind == "melee") and damaged.has(hit.z.id): continue
			damaged[hit.z.id] = true
			landed = true
			hit_enemy(hit.z,w.damage*(w.get("headshotMultiplier",2) if hit.head else 1),hit.armor,p,muzzle+ray*hit.distance)
		if not candidates.is_empty() and not w.get("piercing",false): distance = candidates[0].distance
		if pellet == 0: target = muzzle+ray*distance
		if w.id in ["shotgun", "auto-shotgun"]: pellet_ends.append(muzzle+ray*distance)
	if landed: p.hits += 1
	var shot_event = {"kind":"shot","player":p.id,"weapon":p.weapon,"from":muzzle,"to":target}
	if not pellet_ends.is_empty(): shot_event.pellet_ends = pellet_ends
	events.append(shot_event)

func snapshot() -> Dictionary:
	var players = {}
	for id in pawns:
		players[id] = pawns[id].duplicate(true)
		players[id].erase("input")
	return {"pawns":players,"zombies":zombies.duplicate(true),"mode":mode,"elapsed":elapsed,"wave":wave,"cleared":cleared,"spawned":spawned,"total":Data.wave_settings(wave).count,"kills":kills,"rest":rest,"failed":failed,"cause":cause,"culprit":culprit}

func apply_snapshot(state: Dictionary) -> void:
	pawns = state.pawns
	zombies = state.zombies
	mode = state.mode
	elapsed = state.elapsed
	wave = state.wave
	cleared = state.cleared
	spawned = state.spawned
	kills = state.kills
	rest = state.rest
	failed = state.failed
	cause = state.cause
	culprit = state.culprit
