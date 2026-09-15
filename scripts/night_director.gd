extends "res://scripts/campaign_director.gd"
var sense_at = 0.0
var cue_at = 0.0

func _init(world) -> void:
	Layout = preload("res://scripts/night_layout.gd")
	super(world)
	state.gate_open = true
	state.exit_control = true
	state.power_ready = true
	state.objective = "沿绿灯穿过街口与店铺，抵达林边安全屋"
	sim.arena.sync_campaign(state)

func multiply() -> float: return [1.0,1.2,1.4,1.6][clampi(state.party-1,0,3)]
func cap() -> int: return [24,36,46,56][clampi(state.party-1,0,3)]

func populate_route() -> void:
	for zone in Layout.ZONES:
		var candidates: Array[Vector2] = []
		var concealed: Array[Vector2] = []
		for x in range(int(zone.rect.position.x)+2,int(zone.rect.end.x)-1,2):
			for y in range(int(zone.rect.position.y)+2,int(zone.rect.end.y)-1,2):
				var p = Vector2(x,y)+Vector2(sim.random.randf_range(-.45,.45),sim.random.randf_range(-.45,.45))
				if sim.arena.clear(p,p) and Layout.route_distance(p) > 2.3 and p.distance_to(Layout.START) > 17:
					if not sim.arena.clear(Layout.closest_route(p),p): concealed.append(p)
					else: candidates.append(p)
		var count = 0
		var wanted = roundi(zone.budget*multiply())
		while (not candidates.is_empty() or not concealed.is_empty()) and count < wanted:
			var pool: Array = concealed if not concealed.is_empty() and (count%5 != 0 or candidates.is_empty()) else candidates
			var index = sim.random.randi_range(0,pool.size()-1)
			var point: Vector2 = pool[index]
			pool.remove_at(index)
			if sim.zombies.any(func(z): return z.pos.distance_to(point) < 1.6): continue
			sim.spawn(point,zone.kinds[count%zone.kinds.size()])
			var z: Dictionary = sim.zombies[-1]
			z.guard_awake = false
			z["home"] = point
			z["idle_heading"] = sim.random.randf_range(-PI,PI)
			z.heading = z.idle_heading
			count += 1
		state.zones[zone.id] = {"preplaced":count,"requested":wanted}
		if count < wanted: push_warning("Night habitat population shortfall: "+zone.id+" "+str(count)+"/"+str(wanted))

func target(p: Dictionary) -> Dictionary:
	for other in sim.pawns.values():
		if other.id != p.id and other.get("downed",false) and near(p,other.pos): return {"id":"revive:"+other.id,"label":"救起 "+other.name,"seconds":4.0}
	if not state.departed and p.pos.distance_to(Layout.START_DOOR.get_center()) < 2.6: return {"id":"depart","label":"开门出发","seconds":.6}
	if state.departed and Layout.EXIT_ROOM.has_point(p.pos): return {"id":"finish","label":finish_label(),"seconds":.8}
	for item in Layout.ITEMS:
		if item.kind == "med" and not state.taken.has(item.id) and p.medkits < 1 and near(p,item.pos): return {"id":item.id,"label":"领取医疗包","seconds":.25}
	return equipment.pickup_target(p)

func perform(p: Dictionary, id: String) -> void:
	if id == "depart":
		if state.departed or not start_room_ready() or p.pos.distance_to(Layout.START_DOOR.get_center()) >= 2.6: return
		state.departed = true
		sim.elapsed = 0.0
		phase("STREET","穿过堵车街口，沿绿灯进入店铺")
		sim.arena.sync_campaign(state)
	elif id == "finish":
		if finish_label() != "关闭安全屋门，完成本关": return
		state.complete = true
		phase("COMPLETE","灰松夜路完成 · 安全屋门已关闭")
		save_diagnostics()
		sim.arena.sync_campaign(state)
	else: super(p,id)

func guidance(p: Dictionary) -> String:
	return "沿绿灯推进 · 无需清光尸群 · 到达安全屋后按住 E 关门"

func safe_point(point: Vector2) -> bool:
	if not super(point): return false
	# Dark does not authorize visible pop-in, including beside a player's peripheral view.
	return survivors().all(func(p): return not sim.arena.surface_hit(Vector3(p.pos.x,p.height+1.5,p.pos.y),Vector3(point.x,1.2,point.y)).is_empty())

func step(dt: float) -> void:
	if state.complete or sim.failed: return
	interactions(dt)
	if not state.departed or state.complete: return
	for p in standing(): p.route_hint = guidance(p)
	if standing().any(func(p): return p.pos.y < 5) and not state.milestones.has("woods"):
		state.milestones.woods = sim.elapsed
		phase("FINAL_APPROACH","穿过林缘，寻找安全屋暖灯")
		queue_batch("night_woods",12,["normal","normal","cone"])
	for i in 2:
		if sim.elapsed >= [65,125][i]: queue_batch("night_timer_"+str(i),10,["normal","normal","cone"])
	credit = minf(1,credit+dt*.8*multiply())
	for batch in reinforcement_batches:
		if batch.roster.is_empty(): continue
		if spawn_one(Layout.ENTRIES,batch.roster[0]):
			batch.roster.pop_front()
			batch.spawned += 1
		break
	# Nearby sight and local gunfire wake habitats, never the entire map through walls.
	if sim.elapsed >= sense_at:
		sense_at = sim.elapsed+.3
		for z in sim.zombies:
			if z.hp <= 0 or z.get("guard_awake",true): continue
			for p in standing():
				var distance: float = p.pos.distance_to(z.pos)
				if distance > 18: continue
				var los = sim.arena.surface_hit(Vector3(z.pos.x,1.2,z.pos.y),Vector3(p.pos.x,p.height+1.3,p.pos.y)).is_empty()
				if (los and distance < 7) or (p.fire_anim > 0 and distance < (12 if los else 4)):
					z.guard_awake = true
					break
		# A positional growl announces living nearby infected, with a bounded rate.
		if sim.elapsed >= cue_at:
			for z in sim.zombies:
				if z.hp > 0 and standing().any(func(p): return p.pos.distance_to(z.pos) < 12):
					sim.events.append({"kind":"campaign_cue","cue":"horde","position":Vector3(z.pos.x,1,z.pos.y)})
					cue_at = sim.elapsed+12
					break
	sim.arena.scenery.sync(state)
