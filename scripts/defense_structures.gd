extends RefCounted
## Structures reset each wave. Only the solo/host simulation advances their state.
const Layout = preload("res://scripts/defense_layout.gd")
const EnemyView = preload("res://scripts/enemy_view.gd")
const TURRET_RANGE = 10.0
const TURRET_DAMAGE_MULTIPLIER = .5
const MINE_DELAY = preload("res://scripts/equipment_core.gd").GRENADE_FUSE
const MINE_TRIGGER_RADIUS = .8
const GATE_HEIGHT = 1.05
const GATE_WIDTH = 10.4
const GATE_DEPTH = .35
var director_ref: WeakRef
var director:
	get: return director_ref.get_ref()
var sim:
	get: return director.sim

static func initial_state() -> Array:
	var result: Array = []
	for index in 2:
		var point = Vector2(-6.3 if index == 0 else 6.3,-6.0)
		result.append({"id":"turret_left" if index == 0 else "turret_right","kind":"turret","pos":point,"height":Layout.height(point),"hp":200,"max_hp":200,"cooldown":0.0,"yaw":0.0,"pitch":0.0,"shots":0,"destroyed_at":-1.0})
	result.append({"id":"bridge_gate","kind":"gate","pos":Vector2(0,Layout.RAMP.end.y),"height":3.0,"hp":1000,"max_hp":1000,"destroyed_at":-1.0})
	result.append({"id":"crystal_mine","kind":"mine","pos":Layout.CRYSTAL+Vector2(0,-8),"height":3.0,"hp":1,"max_hp":1,"triggered":false,"fuse":MINE_DELAY,"spent":false})
	return result

func _init(owner) -> void:
	director_ref = weakref(owner)
	director.state["structures"] = initial_state()

func reset_wave() -> void:
	director.state["structures"] = initial_state()
	# Restored obstacles invalidate routes cached while the gate was destroyed.
	sim.paths.clear()

func find(id: String) -> Dictionary:
	for item in director.state.structures:
		if item.id == id: return item
	return {}

static func bounds(item: Dictionary) -> Rect2:
	var size = Vector2(GATE_WIDTH,GATE_DEPTH) if item.kind == "gate" else Vector2(1.3,1.3)
	return Rect2(item.pos-size*.5,size)

func target(item: Dictionary, from: Vector2) -> Dictionary:
	var point: Vector2 = item.pos
	if item.kind == "gate": point.x = clampf(from.x,-GATE_WIDTH*.5+.25,GATE_WIDTH*.5-.25)
	return {"id":item.id,"pos":point,"height":item.height,"hp":item.hp,"is_structure":true,"structure_kind":item.kind}

func targets(from: Vector2) -> Array:
	var result: Array = []
	for item in director.state.structures:
		if item.kind == "turret" and item.hp > 0: result.append(target(item,from))
	return result

func barrier(from: Vector2, destination: Vector2) -> Dictionary:
	var gate = find("bridge_gate")
	# Navigation still knows the route behind the gate. It must attack this
	# obstruction rather than fail A* or select a target through it.
	if gate.hp > 0 and sim.arena.segment_rect(from,destination,bounds(gate).grow(.95)):
		return target(gate,from)
	return {}

func contact_radius(target_data: Dictionary, enemy_kind: String) -> float:
	return maxf(Data.contact(enemy_kind),1.5 if target_data.structure_kind == "gate" else 1.8)

func visible(z: Dictionary, target_data: Dictionary) -> bool:
	var origin = Vector3(z.pos.x,Layout.height(z.pos)+1.1,z.pos.y)
	var end = Vector3(target_data.pos.x,target_data.height+.65,target_data.pos.y)
	return sim.arena.surface_hit(origin,end,target_data.id).is_empty()

func damage(id: String, amount: int) -> bool:
	var item = find(id)
	if item.is_empty() or item.kind == "mine" or item.hp <= 0: return false
	item.hp = maxi(0,item.hp-amount)
	sim.events.append({"kind":"structure_hit","position":Vector3(item.pos.x,item.height+.7,item.pos.y)})
	if item.hp == 0:
		item.destroyed_at = float(director.state.prop_clock)
		sim.paths.clear()
		sim.events.append({"kind":"structure_destroyed","position":Vector3(item.pos.x,item.height+.7,item.pos.y)})
		# Remove collision immediately on authority; snapshots repeat this on clients.
		director.sync_world()
	return true

func step(dt: float) -> void:
	if not director.state.started: return
	for item in director.state.structures:
		if item.kind == "mine":
			step_mine(item,dt)
		elif item.kind == "turret" and item.hp > 0 and not director.state.waiting:
			step_turret(item,dt)

func step_mine(item: Dictionary, dt: float) -> void:
	if item.spent: return
	if not item.triggered:
		for z in sim.zombies:
			if z.hp > 0 and z.pos.distance_to(item.pos) <= MINE_TRIGGER_RADIUS:
				item.triggered = true
				sim.events.append({"kind":"grenade_fuse","position":Vector3(item.pos.x,item.height+.16,item.pos.y)})
				return # Fuse starts at this contact, not at the beginning of the tick.
		return
	item.fuse = maxf(0,item.fuse-dt)
	if item.fuse <= 0:
		item.spent = true
		item.hp = 0
		# Reuse the exact grenade damage, radius, cover, armor and stun rules.
		sim.equipment.explode({"id":-1,"owner":item.id,"pos":Vector3(item.pos.x,item.height+.16,item.pos.y)})

func step_turret(item: Dictionary, dt: float) -> void:
	var rifle: Dictionary = Data.weapons[0]
	item.cooldown -= dt
	var origin = Vector3(item.pos.x,item.height+1.55,item.pos.y)
	var selected: Dictionary = {}
	var torso = Vector3.ZERO
	var nearest = TURRET_RANGE*TURRET_RANGE
	for z in sim.zombies:
		if z.hp <= 0 or z.pos.distance_squared_to(item.pos) > TURRET_RANGE*TURRET_RANGE: continue
		var point: Vector3 = EnemyView.transforms(z,sim.elapsed,false)[0].origin
		var distance = origin.distance_squared_to(point)
		if distance > nearest or not sim.arena.surface_hit(origin,point,item.id).is_empty(): continue
		nearest = distance
		selected = z
		torso = point
	if selected.is_empty():
		item.cooldown = maxf(0,item.cooldown)
		return
	var direction = (torso-origin).normalized()
	item.yaw = atan2(-direction.x,-direction.z)
	item.pitch = asin(direction.y)
	if item.cooldown > .00001: return
	item.cooldown = maxf(0,item.cooldown+float(rifle.interval))
	origin += direction*.85
	# The torso aim follows the same pose used by rendering and player ray hits.
	# A nearer zombie can intercept the shot; armor still absorbs it normally.
	var shot: Dictionary = {}
	var shot_distance = TURRET_RANGE
	for z in sim.zombies:
		if z.hp <= 0: continue
		var hit = EnemyView.hit(z,origin,direction,shot_distance,sim.elapsed,false)
		if not hit.is_empty():
			shot = hit
			shot_distance = hit.distance
	var end = origin+direction*shot_distance
	if not shot.is_empty():
		sim.hit_enemy(shot.z,float(rifle.damage)*TURRET_DAMAGE_MULTIPLIER,shot.armor,{"id":item.id,"kills":0},end)
	item.shots += 1
	item["fired_at"] = float(director.state.prop_clock)
	sim.events.append({"kind":"turret_shot","from":origin,"to":end})

static func valid_state(value) -> bool:
	if not value is Array or value.size() != 4: return false
	var expected = initial_state()
	for index in expected.size():
		var item = value[index]
		var base: Dictionary = expected[index]
		if not item is Dictionary or not item.has_all(base.keys()): return false
		if item.id != base.id or item.kind != base.kind or item.pos != base.pos or item.height != base.height or item.max_hp != base.max_hp: return false
		if not item.hp is int or item.hp < 0 or item.hp > base.max_hp: return false
		for key in ["cooldown","yaw","pitch","destroyed_at","fuse"]:
			if item.has(key) and (not (item[key] is int or item[key] is float) or not is_finite(float(item[key]))): return false
		if item.kind == "mine" and (not item.triggered is bool or not item.spent is bool or item.fuse < 0 or item.fuse > MINE_DELAY): return false
		if item.kind == "turret" and (not item.shots is int or item.shots < 0): return false
	return true
