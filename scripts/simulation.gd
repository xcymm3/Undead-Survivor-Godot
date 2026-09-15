extends RefCounted
## The sole authority for movement, ammunition, enemies, damage and score, shared by solo/coop.
const EnemyView = preload("res://scripts/enemy_view.gd")
const PlayerBody = preload("res://scripts/player_body.gd")
var player_bodies: Dictionary = {}
var arena
var map_id = "graypine_night"
var map_definition: Dictionary
var pawns: Dictionary = {}
var zombies: Array = []
var events: Array = []
var mode = "survival"
var campaign
var campaign_replica: Dictionary = {}
var won = false
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
const SHOVE_INTERVAL = .65
const SHOVE_COOLDOWN = 3.5
const SHOVE_WINDOW = 3.0
const SHOVE_LIMIT = 3
const MELEE_START = .22
const MELEE_END = .66
const MELEE_HALF_WIDTH = 20.0
const CHARGE_DURATION = 4.0
const CHARGE_DAMAGE = 30
const CHARGE_KNOCKBACK = .65
const CHARGE_WALL_STUN = 2.0

func _init(world = null) -> void:
	arena = world
	if world and world.get("map_id") is String: map_id = world.map_id
	map_definition = Data.Maps.definition(map_id)
	random.randomize()

func dispose() -> void:
	for body in player_bodies.values():
		if is_instance_valid(body): body.free()
	player_bodies.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for body in player_bodies.values():
			if is_instance_valid(body): body.free()

func player_body(p: Dictionary):
	if not player_bodies.has(p.id):
		var body = PlayerBody.new()
		arena.add_child(body)
		player_bodies[p.id] = body
	var body = player_bodies[p.id]
	body.sync_from(p)
	return body

func add_pawn(id: String, player_name: String, index: int) -> void:
	var ammo: Array = []
	for w in Data.weapons: ammo.append(int(w.capacity))
	# The authority draws without replacement; snapshots carry the stable result.
	var available = range(Data.MODELS.size())
	for pawn in pawns.values(): available.erase(int(pawn.appearance[0]))
	if available.is_empty(): available = range(Data.MODELS.size())
	var model: int = available[random.randi_range(0,available.size()-1)]
	pawns[id] = {"id":id,"name":player_name,"pos":map_definition.spawn+Vector2((index%2)*2.8-1.4,floori(index/2.0)*2.6),"yaw":map_definition.yaw,"pitch":0.0,"height":0.0,"velocity":0.0,"crouch":0.0,"crouching":false,"air":Vector2.ZERO,"hp":100,"protection":0.0,"shove_cd":0.0,"shove_gap":0.0,"shove_window":0.0,"shove_count":0,"shoves":0,"shove_hits":0,"shove_anim":0.0,"weapon":0,"requested":0,"switch":0.0,"ammo":ammo,"cooldown":0.0,"fire_anim":0.0,"reload":0.0,"reload_queued":false,"reloading":false,"shots":0,"gun_shots":[0,0,0,0,0,0,0,0,0,0],"hits":0,"kills":0,"aim":false,"trigger":false,"input":{},"input_age":0.0,"appearance":[model,0,0]}

	pawns[id].height = 0.0

func start(_game_mode: String) -> void:
	mode = "campaign"
	if mode == "campaign":
		zombies.clear()
		paths.clear()
		campaign = preload("res://scripts/night_director.gd").new(self)
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
	var locomotion = RandomNumberGenerator.new()
	locomotion.seed = int(random.seed) ^ (next_id*7919+104729)
	zombies.append({"id":next_id,"map_id":map_id,"pos":pos,"kind":kind,"original":kind,"hp":float(def.health),"body":float(def.health-def.armor),"armor":float(def.armor),"down":0.0,"born":elapsed,"chase_speed":locomotion.randf_range(4.6,5.2),"move_speed":0.0,"gait":locomotion.randf_range(0,TAU),"shove_velocity":Vector2.ZERO,"shove_time":0.0,"heading":0.0,"attack_time":0.0,"target":"","rage":false,"rage_pause":0.0,"state":"ready","state_time":0.0,"charge_cooldown":0.0,"charge_direction":Vector2.ZERO,"charge_target":Vector2.ZERO})
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
	for key in ["jump","fire","reload","aim","crouch","interact","heal","use_self","use_other","shove"]: clean[key] = input.get(key,false) == true
	if campaign:
		var slot = input.get("slot",pawns[id].slot)
		if not slot is int or slot < 1 or slot > 5: return
		clean.slot = slot
	# Network polling can deliver several commands before the next physics tick.
	# Keep a jump edge until update_pawn consumes it, even if a newer packet releases it.
	clean.jump = clean.jump or pawns[id].input.get("jump",false)
	for action in ["use_self","use_other","shove"]: clean[action] = clean[action] or pawns[id].input.get(action,false)
	pawns[id].input = clean
	pawns[id].input_age = 0.0

func step(dt: float) -> void:
	events.clear()
	if failed or won: return
	for id in player_bodies.keys():
		if not pawns.has(id):
			player_bodies[id].free()
			player_bodies.erase(id)
	for id in melee_swings.keys():
		if not pawns.has(id) or pawns[id].hp <= 0: melee_swings.erase(id)
	if not campaign or campaign.state.departed: elapsed += dt
	if campaign: campaign.equipment.before_movement(dt)
	for p in pawns.values(): update_pawn(p,dt)
	if campaign: campaign.equipment.step_projectiles(dt)
	crowd_buckets.clear()
	for z in zombies:
		if z.hp <= 0: continue
		var key = Vector2i(floori(z.pos.x/3),floori(z.pos.y/3))
		if not crowd_buckets.has(key): crowd_buckets[key] = []
		crowd_buckets[key].append(z)
	var living: Array = pawns.values().filter(func(p): return p.hp > 0)
	if living.is_empty():
		failed = true
		if campaign:
			campaign.phase("FAILED","全队失去行动能力")
			for fallen in pawns.values(): campaign.record_casualty(fallen,"team_wipe")
		return
	for z in zombies:
		if z.hp <= 0:
			z.down -= dt
			continue
		var target: Dictionary = living[0]
		for p in living:
			if z.pos.distance_squared_to(p.pos) < z.pos.distance_squared_to(target.pos): target = p
		update_zombie(z,target,dt)
	zombies = zombies.filter(func(z): return z.hp > 0 or z.down > 0)
	if pawns.values().all(func(p): return p.hp <= 0):
		failed = true
		if campaign:
			campaign.phase("FAILED","全队失去行动能力")
			for fallen in pawns.values(): campaign.record_casualty(fallen,"team_wipe")
		return
	if campaign:
		campaign.step(dt)
		won = campaign.state.complete
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
	var entries: Array = map_definition.spawns.duplicate()
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
	for p in map_definition.safe:
		if arena.clear(p,p,true) and not is_water(p) and zombies.all(func(z): return z.hp <= 0 or p.distance_to(z.pos) > 2): return p
	return map_definition.spawn

func alive_count() -> int:
	return zombies.filter(func(z): return z.hp > 0).size()

func can_move(p: Dictionary, point: Vector2) -> bool:
	if not map_definition.bounds.grow(-.95).has_point(point): return false
	for z in zombies:
		if z.hp <= 0: continue
		if p.height-Data.enemy_ground_height(z.pos,map_id) >= 1.1: continue
		if point.distance_to(z.pos) < Data.contact(z.kind) and point.distance_to(z.pos) < p.pos.distance_to(z.pos)-.00001: return false
	return true

func update_pawn(p: Dictionary, dt: float) -> void:
	p.shove_cd = maxf(0,p.get("shove_cd",0.0)-dt)
	p.shove_gap = maxf(0,p.get("shove_gap",0.0)-dt)
	p.shove_anim = maxf(0,p.get("shove_anim",0.0)-dt)
	p.shove_window = maxf(0,p.get("shove_window",0.0)-dt)
	if p.shove_window <= 0: p.shove_count = 0
	p.protection = maxf(0,p.protection-dt)
	p.cooldown = maxf(0,p.cooldown-dt)
	p.fire_anim = maxf(0,p.fire_anim-dt)
	p.input_age += dt
	var input: Dictionary = p.input if p.input_age < .5 else {}
	if p.hp <= 0: return
	p.yaw = input.get("yaw",p.yaw)
	p.pitch = input.get("pitch",p.pitch)
	var locked: bool = campaign != null and (not p.healing.is_empty() or p.being_healed)
	if locked:
		input = input.duplicate()
		for action in ["x","y","jump","fire","aim","reload","shove"]: input[action] = 0
		p.air = Vector2.ZERO
	var body = player_body(p)
	body.update_stance(p,input.get("crouch",false),dt)
	var movement = Vector2(input.get("x",0),input.get("y",0)).limit_length()
	if body.grounded: p.air = movement
	if input.get("jump",false) and body.grounded and p.crouch < .1:
		body.velocity.y = PlayerBody.JUMP_SPEED
		body.grounded = false
		p.air = movement
	if not body.grounded: movement = p.air
	var dir = Vector2(movement.x*cos(p.yaw)+movement.y*sin(p.yaw), -movement.x*sin(p.yaw)+movement.y*cos(p.yaw))
	var remaining = dt
	while remaining > .00001:
		var step_time = minf(.01,remaining)
		remaining -= step_time
		var wading: bool = body.grounded and is_wading(p.pos,p.height)
		var next: Vector2 = p.pos+dir*4.2*lerpf(1.0,.55,p.crouch)*(Data.WADE_SPEED if wading else 1.0)*step_time
		next = next.clamp(map_definition.bounds.position+Vector2.ONE*.95,map_definition.bounds.end-Vector2.ONE*.95)
		if not can_move(p,next):
			var horizontal = Vector2(next.x,p.pos.y)
			var vertical = Vector2(p.pos.x,next.y)
			next = horizontal if can_move(p,horizontal) else vertical if can_move(p,vertical) else p.pos
		body.advance((next-p.pos)/step_time,step_time)
		body.sync_to(p)
	p.wading = body.grounded and is_wading(p.pos,p.height)
	p.input.jump = false
	if input.get("shove",false): try_shove(p)
	p.input.shove = false
	update_arsenal(p,input,dt)
	if campaign: p.reserve = p.reserves[p.primary]

func update_arsenal(p: Dictionary, input: Dictionary, dt: float) -> void:
	if campaign and (p.slot >= 4 or not p.healing.is_empty() or p.being_healed):
		if p.weapon == 3 and p.reloading:
			p.reloading = false
			p.reload = 0.0
			p.reload_queued = false
			p.input.reload = false
		p.aim = false
		p.trigger = false
		return
	if p.get("shove_anim",0.0) > 0:
		p.aim = false
		return
	var w: Dictionary = Data.weapons[p.weapon]
	update_melee_swing(p,w)
	var requested: int = input.get("weapon",p.weapon)
	if campaign: requested = campaign.choose_weapon(p,requested)
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
				var loaded = mini(1,p.reserves[p.weapon]) if campaign else 1
				p.ammo[p.weapon] = mini(int(w.capacity),p.ammo[p.weapon]+loaded)
				if campaign: p.reserves[p.weapon] -= loaded
				p.reload = w.reloadDuration
				events.append({"kind":"reload","player":p.id})
				if p.ammo[p.weapon] >= w.capacity or (campaign and p.reserves[p.weapon] <= 0): p.reloading = false
			else:
				var loaded = mini(int(w.capacity)-p.ammo[p.weapon],p.reserves[p.weapon]) if campaign else int(w.capacity)-p.ammo[p.weapon]
				p.ammo[p.weapon] += loaded
				if campaign: p.reserves[p.weapon] -= loaded
				p.reloading = false
		return
	if p.requested != p.weapon and p.fire_anim <= 0:
		p.switch = .4
		p.aim = false
		return
	if input.get("reload",false) and not w.get("infiniteAmmo",false) and p.ammo[p.weapon] < w.capacity and (not campaign or p.reserves[p.weapon] > 0): p.reload_queued = true
	p.input.reload = false
	if p.reload_queued and p.fire_anim <= 0:
		p.reload = w.reloadDuration
		p.reloading = true
		p.reload_queued = false
		p.aim = false
		events.append({"kind":"reload","player":p.id})
		return
	var trigger: bool = input.get("fire",false) and (not campaign or (campaign.state.departed and p.interaction == ""))
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
	if won or (campaign and not campaign.state.departed) or p.protection > 0 or p.hp <= 0 or p.height-Data.enemy_ground_height(z.pos,map_id) >= 1.1: return false
	var applied = mini(p.hp,amount)
	p.hp = maxi(0,p.hp-amount)
	p.protection = .3
	if campaign: campaign.damage(p,z,applied)
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
		var body = player_body(p)
		body.move_and_collide(Vector3(direction.x,0,direction.y)*(CHARGE_KNOCKBACK/13.0))
		body.sync_to(p)

func try_shove(p: Dictionary) -> bool:
	if p.hp <= 0 or p.shove_cd > 0 or p.shove_gap > 0 or p.switch > 0: return false
	if campaign and (not campaign.state.departed or p.slot >= 4 or p.interaction != "" or not p.healing.is_empty() or p.being_healed): return false
	p.shoves = p.get("shoves",0)+1
	p.shove_gap = SHOVE_INTERVAL
	p.shove_anim = .32
	p.fire_anim = 0.0
	p.shove_count += 1
	p.shove_window = SHOVE_WINDOW
	if p.shove_count >= SHOVE_LIMIT:
		p.shove_cd = SHOVE_COOLDOWN
		p.shove_count = 0
	p.aim = false
	p.reloading = false
	p.reload = 0.0
	p.reload_queued = false
	p.input.reload = false
	melee_swings.erase(p.id)
	var forward = Vector2(-sin(p.yaw),-cos(p.yaw))
	var hits = 0
	for z in zombies:
		if z.hp <= 0: continue
		var delta: Vector2 = z.pos-p.pos
		if delta.length() > 2.0 or absf(Data.enemy_ground_height(z.pos,map_id)-p.height) > 1.1: continue
		if delta.length() > .05 and forward.dot(delta.normalized()) < cos(deg_to_rad(70)): continue
		if not arena.surface_hit(Vector3(p.pos.x,p.height+1.1,p.pos.y),Vector3(z.pos.x,Data.enemy_ground_height(z.pos,map_id)+1.1,z.pos.y)).is_empty(): continue
		if z.kind == "football" and z.state in ["charging","windup"]: continue
		var heavy: bool = z.kind in ["giant","shield","football"]
		z.guard_awake = true
		z.attack_time = 0.0
		z.state = "stunned"
		z.state_time = .35 if heavy else 1.0
		z.shove_time = .18
		z.shove_velocity = (delta.normalized() if delta.length() > .05 else forward)*(2.0 if heavy else 7.2)
		paths.erase(z.id)
		hits += 1
	p.shove_hits = p.get("shove_hits",0)+hits
	events.append({"kind":"shove","player":p.id,"position":Vector3(p.pos.x,p.height+1.2,p.pos.y),"hits":hits})
	return true

func approach_goal(z: Dictionary, target: Dictionary) -> Vector2:
	var distance: float = z.pos.distance_to(target.pos)
	if distance > 24: return target.pos
	# Stable per-enemy offsets avoid a shared chase point; navigation validates each slot.
	var sector = fmod(z.id*2.399963,TAU)
	var radius = Data.contact(z.kind)*.88
	if distance > 5: radius += 1.4+fmod(z.id*.37,1.8)
	var candidate: Vector2 = target.pos+Vector2(cos(sector),sin(sector))*radius
	if arena.clear(candidate,candidate) and arena.clear(candidate,target.pos): return candidate
	return target.pos

func update_zombie(z: Dictionary, target: Dictionary, dt: float) -> void:
	z.move_speed = 0.0
	if z.get("shove_time",0.0) > 0:
		var duration = minf(dt,z.shove_time)
		z.shove_time -= duration
		for i in 6:
			var pushed: Vector2 = z.pos+z.shove_velocity*duration/6.0
			if arena.clear(z.pos,pushed): z.pos = pushed
			else: break
	# Authored guards exist from map start; proximity with sight or damage wakes them once.
	if z.has("guard_awake") and not z.guard_awake:
		if map_id == "graypine_night" and z.hp >= float(Data.enemies[z.original].health):
			z.heading = z.get("idle_heading",0.0)+sin(elapsed*.43+z.id)*.3
			if elapsed > 0 and z.id%4 == 0:
				var phase_time = fmod(elapsed+z.id*1.731,16.0)
				if phase_time < 4 or (phase_time > 8 and phase_time < 12):
					var home: Vector2 = z.get("home",z.pos)
					var idle_goal = home+Vector2(sin(z.id),cos(z.id))*1.1 if phase_time < 4 else home
					var idle_delta: Vector2 = idle_goal-z.pos
					var next_idle: Vector2 = z.pos+idle_delta.limit_length(dt*.3)
					if arena.clear(z.pos,next_idle): z.pos = next_idle
					if idle_delta.length() > .1: z.heading = atan2(idle_delta.x,idle_delta.y)
			return
		var sees_player = pawns.values().any(func(p): return p.hp > 0 and p.pos.distance_to(z.pos) < 14 and arena.surface_hit(Vector3(z.pos.x,1.2,z.pos.y),Vector3(p.pos.x,p.height+1.2,p.pos.y)).is_empty())
		if z.hp >= float(Data.enemies[z.original].health) and not sees_player: return
		z.guard_awake = true
	var delta: Vector2 = target.pos-z.pos
	var distance = delta.length()
	var contact = Data.contact(z.kind)
	var base_speed: float = float(z.get("chase_speed",4.8))
	var speed: float = base_speed
	z.rage_pause = maxf(0,z.rage_pause-dt)
	z.charge_cooldown = maxf(0,z.charge_cooldown-dt)
	if z.kind == "imp": speed = base_speed*1.08
	if z.kind == "shield": speed = base_speed*.78
	if z.kind == "giant": speed *= .68
	if z.kind == "berserker": speed = minf(5.8,base_speed*(2.6 if z.rage else 1.35))
	if z.kind == "football": speed = base_speed*(.90 if z.armor > 0 else 1.0)
	var wading: bool = is_water(z.pos)
	if wading:
		speed *= Data.WADE_SPEED
		if z.state in ["charging","windup"]: cancel_charge(z)
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
	if z.kind == "football" and not wading and z.state == "ready" and z.armor > 0 and z.charge_cooldown <= 0 and distance >= 5 and distance <= minf(16,minf(10,base_speed*4.2)*CHARGE_DURATION+contact) and arena.clear(z.pos,target.pos):
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
		z.move_speed = z.pos.distance_to(next)/maxf(dt,.001)
		z.gait = z.get("gait",0.0)+z.pos.distance_to(next)*2.3
		z.pos = next
		if is_water(next):
			cancel_charge(z)
			return
		for p in pawns.values():
			if p.hp > 0 and z.pos.distance_to(p.pos) <= contact and p.height-Data.enemy_ground_height(z.pos,map_id) < 1.1:
				if damage_pawn(p,z,CHARGE_DAMAGE): charge_knockback(p,z.charge_direction)
				z.state = "ready"
				z.charge_cooldown = 3.2
				break
		return
	var contact_visible = arena.surface_hit(Vector3(z.pos.x,1.1+Data.enemy_ground_height(z.pos,map_id),z.pos.y),Vector3(target.pos.x,target.height+1.1,target.pos.y)).is_empty() if distance <= contact else false
	if z.attack_time > 0 or (distance <= contact and contact_visible and absf(target.height-Data.enemy_ground_height(z.pos,map_id)) < 1.1):
		var profile = Data.attack(z.kind,z.rage)
		if z.attack_time <= 0:
			z.target = target.id
			z.heading = atan2(delta.x,delta.y)
			events.append({"kind":"enemy_windup","position":Vector3(z.pos.x,1.2+Data.enemy_ground_height(z.pos,map_id),z.pos.y)})
		var before: float = z.attack_time
		z.attack_time += dt
		if before < profile.x and z.attack_time >= profile.x:
			var hit = false
			for victim in pawns.values():
				if z.kind != "giant" and victim.id != z.target: continue
				var offset: Vector2 = victim.pos-z.pos
				if victim.hp <= 0 or offset.length() > (2.4 if z.kind == "giant" else contact+.15): continue
				if Vector2(sin(z.heading),cos(z.heading)).dot(offset.normalized()) < .4: continue
				if not arena.surface_hit(Vector3(z.pos.x,1.1+Data.enemy_ground_height(z.pos,map_id),z.pos.y),Vector3(victim.pos.x,victim.height+1.1,victim.pos.y)).is_empty(): continue
				hit = damage_pawn(victim,z) or hit
			events.append({"kind":"enemy_impact" if hit else "enemy_miss","position":Vector3(z.pos.x,1.2+Data.enemy_ground_height(z.pos,map_id),z.pos.y)})
		if z.attack_time >= profile.y: z.attack_time = 0.0
		return
	var goal = approach_goal(z,target)
	var direction = (goal-z.pos).normalized()
	var cached: Dictionary = paths.get(z.id,{"until":0.0,"path":PackedVector2Array(),"goal":Vector2.INF,"direct_until":0.0,"direct":false})
	if elapsed >= cached.get("direct_until",0.0) or cached.get("direct_goal",Vector2.INF).distance_to(goal) > .65:
		cached.direct = arena.clear(z.pos,goal)
		cached.direct_goal = goal
		cached.direct_until = elapsed+.15+fmod(z.id*.027,.12)
		paths[z.id] = cached
	if not cached.get("direct",false):
		if elapsed >= cached.until or cached.goal.distance_to(goal) > 1.3:
			cached.until = elapsed+.65+fmod(z.id*.037,.25)
			cached.path = arena.path_to(z.pos,goal)
			cached.goal = goal
			paths[z.id] = cached
		var route: PackedVector2Array = cached.path
		while route.size() > 1 and z.pos.distance_to(route[0]) < .4: route.remove_at(0)
		cached.path = route
		if route.is_empty(): return
		direction = (route[0]-z.pos).normalized()
	var separation = Vector2.ZERO
	var cell = Vector2i(floori(z.pos.x/3),floori(z.pos.y/3))
	var radius = 2.1 if z.kind == "giant" else .85 if z.kind == "imp" else 1.65
	for y in range(-1,2):
		for x in range(-1,2):
			for other in crowd_buckets.get(cell+Vector2i(x,y),[]):
				if other.id == z.id or other.hp <= 0: continue
				var offset: Vector2 = z.pos-other.pos
				var d = offset.length_squared()
				if d > .001 and d < radius*radius: separation += offset.normalized()*(radius-sqrt(d))
	direction = (direction+separation.limit_length(.75)).normalized()
	var old_position: Vector2 = z.pos
	var next: Vector2 = z.pos+direction*minf(speed*dt,maxf(0,distance-contact*.88))
	if arena.clear(z.pos,next): z.pos = next
	else:
		var x = Vector2(next.x,z.pos.y)
		if arena.clear(z.pos,x): z.pos = x
		var y = Vector2(z.pos.x,next.y)
		if arena.clear(z.pos,y): z.pos = y
	z.gait = z.get("gait",0.0)+z.pos.distance_to(old_position)*2.3
	z.move_speed = z.pos.distance_to(old_position)/maxf(dt,.001)
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
		z.down = .85
		z.attack_time = 0.0
		kills += 1
		p.kills += 1
		paths.erase(z.id)
		events.append({"kind":"death","player":p.id,"position":position})
	else:
		if map_id == "graypine_night" and z.kind == "normal" and elapsed >= z.get("stagger_ready",-1.0):
			stun(z,.18)
			z["stagger_ready"] = elapsed+.8
		events.append({"kind":"blood","player":p.id,"position":position})

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
		var origin = Vector3(p.pos.x,p.height+PlayerBody.eye_height(p)-.5,p.pos.y)
		var facing = Basis(Vector3.UP,p.yaw)
		var reach: float = w.range
		# A generous vertical blade volume moves down with the diagonal swing.
		var upper = p.height+PlayerBody.eye_height(p)+lerpf(0,-1,first)+1.1+sin(p.pitch)*1.2
		var lower = p.height+PlayerBody.eye_height(p)+lerpf(0,-1,last)-1.1+sin(p.pitch)*1.2
		for z in zombies:
			if z.hp <= 0 or swing.damaged.has(z.id): continue
			if p.pos.distance_to(z.pos) > reach+Data.enemy_scale(z.kind)*1.5: continue
			var poses: Array = EnemyView.transforms(z,elapsed,false)
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
				var hit = EnemyView.hit(z,origin,direction,distance,elapsed,false)
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
		var origin = Vector3(p.pos.x,p.height+PlayerBody.eye_height(p)-.5,p.pos.y)
		events.append({"kind":"shot","player":p.id,"weapon":p.weapon,"from":origin,"to":origin})
		return
	var camera = Transform3D(Basis.from_euler(Vector3(p.pitch,p.yaw,0)),Vector3(p.pos.x,p.height+PlayerBody.eye_height(p),p.pos.y))
	var forward = -camera.basis.z
	var reach: float = w.get("range",180.0)
	var target = camera.origin+forward*reach
	var surface: Dictionary = arena.surface_hit(camera.origin,target)
	if not surface.is_empty(): target = surface.position
	var closest = camera.origin.distance_to(target)
	for z in zombies:
		if z.hp <= 0: continue
		var impact = EnemyView.hit(z,camera.origin,forward,closest,elapsed,false)
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
			var candidate = EnemyView.hit(z,muzzle,ray,distance,elapsed,false)
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
	return {"campaign":campaign_state(),"won":won,"map_id":map_id,"pawns":players,"zombies":zombies.duplicate(true),"mode":mode,"elapsed":elapsed,"wave":wave,"cleared":cleared,"spawned":spawned,"total":Data.wave_settings(wave).count,"kills":kills,"rest":rest,"failed":failed,"cause":cause,"culprit":culprit}

func apply_snapshot(state: Dictionary) -> void:
	pawns = state.pawns
	won = state.get("won",false)
	campaign_replica = state.get("campaign",{})
	arena.sync_campaign(campaign_replica)
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

func is_water(p: Vector2) -> bool:
	return false

func is_wading(p: Vector2, height: float) -> bool:
	return false

func campaign_state() -> Dictionary:
	return campaign.snapshot() if campaign else campaign_replica
