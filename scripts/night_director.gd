extends "res://scripts/campaign_director.gd"
var sense_at = 0.0
var cue_at = 0.0
var sound_events: Array = []
var sound_serial = 0
var burst_at = 0.0
var burst_left = 0
var burst_next = 0.0
var batch_cursor = 0

func emit_noise(point: Vector3, kind: String) -> void:
	if not state.departed or state.complete: return
	sound_serial += 1
	sound_events.append({"id":sound_serial,"pos":Vector2(point.x,point.z),"kind":kind,"expires":sim.elapsed+1.0})

func investigate_sounds() -> void:
	for z in sim.zombies:
		if z.hp <= 0 or z.get("guard_awake",true): continue
		for noise in sound_events:
			if noise.id <= z.get("heard_id",0): continue
			z.heard_id = noise.id
			var radius = 24.0 if noise.kind == "gunshot" else 12.0
			var delta: Vector2 = noise.pos-z.pos
			if delta.length() > radius: continue
			var blocked = not sim.arena.surface_hit(Vector3(z.pos.x,1.2,z.pos.y),Vector3(noise.pos.x,1.2,noise.pos.y)).is_empty()
			if blocked and delta.length() > radius*.45: continue
			# Impacts can lie inside walls; investigate a reachable point on this side.
			var goal: Vector2 = noise.pos
			if z.get("investigate_until",0.0) > sim.elapsed and z.get("investigate_pos",Vector2.INF).distance_to(goal) < 3:
				z.investigate_until = sim.elapsed+10.0
				continue
			var found = false
			for offset in [Vector2.ZERO,-delta.normalized()*1.5,-delta.normalized()*3.0]:
				var candidate: Vector2 = goal+offset
				if sim.arena.clear(candidate,candidate) and not sim.arena.path_to(z.pos,candidate).is_empty():
					z.investigate_pos = candidate
					found = true
					break
			if found:
				z.investigate_until = sim.elapsed+10.0
				z.search_until = 0.0
				sim.paths.erase(z.id)
	sound_events.clear()

func finish_label() -> String:
	if not state.exit_control: return "先启动门锁并坚守 30 秒"
	return super()

func holdout_step(dt: float) -> void:
	if state.holdout_started and not state.exit_control:
		# At least one standing survivor must remain near the entrance.
		if standing().any(func(p): return p.pos.distance_to(Layout.HOLDOUT) < 14):
			state.holdout_time = minf(30,state.holdout_time+dt)
		state.objective = "守住门前 · 解锁剩余 %d 秒" % ceili(30-state.holdout_time)
		for i in 3:
			if state.holdout_time >= i*10:
				queue_batch("night_holdout_"+str(i),18,["normal","normal","normal","cone"])
		if state.holdout_time >= 30:
			state.exit_control = true
			state.milestones.holdout_complete = sim.elapsed
			phase("ESCAPE","门已解锁！进入安全屋并按 E 关门")
			sim.arena.sync_campaign(state)

func spawn_groups() -> void:
	if sim.elapsed >= burst_at and burst_left <= 0:
		burst_left = 6 if state.party == 1 else 8
		burst_at = sim.elapsed+5.0
	if burst_left <= 0 or sim.elapsed < burst_next: return
	# Round-robin batches prevent a blocked earlier wave starving the finale.
	for offset in reinforcement_batches.size():
		var index = (batch_cursor+offset)%reinforcement_batches.size()
		var batch: Dictionary = reinforcement_batches[index]
		if batch.roster.is_empty(): continue
		credit = 1
		var entries: Array = Layout.FINAL_ENTRIES if batch.id.begins_with("night_holdout_") else Layout.ENTRIES
		if spawn_one(entries,batch.roster[0]):
			batch.roster.pop_front()
			batch.spawned += 1
			if not batch.has("spawn_times"): batch.spawn_times = []
			batch.spawn_times.append(sim.elapsed)
			burst_left -= 1
			burst_next = sim.elapsed+.18
			batch_cursor = (index+1)%reinforcement_batches.size()
			return

func _init(world) -> void:
	Layout = preload("res://scripts/night_layout.gd")
	super(world)
	state.gate_open = true
	state.exit_control = false
	state.holdout_started = false
	state.holdout_time = 0.0
	state.power_ready = true
	state.objective = "沿绿灯穿过街口与店铺，抵达林边安全屋"
	sim.arena.sync_campaign(state)

func multiply() -> float: return [1.0,1.2,1.4,1.6][clampi(state.party-1,0,3)]
func cap() -> int: return ([48,64,76,88] if state.get("holdout_started",false) and not state.exit_control else [30,42,54,66])[clampi(state.party-1,0,3)]

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
	if state.departed and not state.holdout_started and near(p,Layout.HOLDOUT,2.6): return {"id":"holdout","label":"启动门锁 · 坚守 30 秒","seconds":.8}
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
	elif id == "holdout":
		if not state.departed or state.holdout_started or not near(p,Layout.HOLDOUT,2.6): return
		state.holdout_started = true
		state.milestones.holdout_started = sim.elapsed
		phase("HOLDOUT","守住门前 30 秒，等待安全屋解锁")
		burst_at = sim.elapsed
		burst_left = 0
	elif id == "finish":
		if finish_label() != "关闭安全屋门，完成本关": return
		state.complete = true
		phase("COMPLETE","灰松夜路完成 · 安全屋门已关闭")
		save_diagnostics()
		sim.arena.sync_campaign(state)
	else: super(p,id)

func guidance(p: Dictionary) -> String:
	if state.holdout_started and not state.exit_control: return "留在门前 14 米内坚守 · 离开则解锁暂停"
	return "沿绿灯推进 · 门前按 E 启动解锁，坚守 30 秒后进屋关门"

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
	holdout_step(dt)
	spawn_groups()
	investigate_sounds()
	# Sight confirms a player; sound alone only starts an investigation.
	if sim.elapsed >= sense_at:
		sense_at = sim.elapsed+.3
		for z in sim.zombies:
			if z.hp <= 0 or z.get("guard_awake",true): continue
			for p in standing():
				var distance: float = p.pos.distance_to(z.pos)
				if distance > 18: continue
				var los = sim.arena.surface_hit(Vector3(z.pos.x,1.2,z.pos.y),Vector3(p.pos.x,p.height+1.3,p.pos.y)).is_empty()
				if los and distance < (10 if z.get("investigate_until",0.0) > sim.elapsed else 7):
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
