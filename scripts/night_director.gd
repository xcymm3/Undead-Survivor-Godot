extends "res://scripts/campaign_director.gd"
const Population = preload("res://scripts/night_population.gd")
var sense_at = 0.0
var cue_at = 0.0
var sound_events: Array = []
var sound_serial = 0
var burst_at = 0.0
var burst_left = 0
var burst_next = 0.0
var batch_cursor = 0
var ordinary_slots = 0
var next_timer_index = 1

func population_kind(kind: String) -> String:
	# Count successful ordinary spawns across habitats and delayed batches.
	if kind != "normal": return kind
	ordinary_slots += 1
	return Population.population_kind(kind,ordinary_slots)

func emit_noise(point: Vector3, kind: String, shot_origin := Vector2.INF) -> void:
	if not state.departed or state.complete: return
	sound_serial += 1
	sound_events.append({"id":sound_serial,"pos":Vector2(point.x,point.z),"kind":kind,"shot_origin":shot_origin,"expires":sim.elapsed+1.0})

func investigate_sounds() -> void:
	for z in sim.zombies:
		if z.hp <= 0 or z.get("guard_awake",true): continue
		for noise in sound_events:
			if noise.id <= z.get("heard_id",0): continue
			z.heard_id = noise.id
			var radius = 18.0 if noise.kind == "gunshot" else 8.0
			var delta: Vector2 = noise.pos-z.pos
			if delta.length() > radius: continue
			var blocked = not sim.arena.surface_hit(Vector3(z.pos.x,1.2,z.pos.y),Vector3(noise.pos.x,1.2,noise.pos.y)).is_empty()
			if blocked and delta.length() > radius*.45: continue
			# Impacts can lie inside walls; investigate a reachable point on this side.
			var goal: Vector2 = noise.get("shot_origin",Vector2.INF)
			if not goal.is_finite(): goal = noise.pos
			elif noise.kind == "gunshot":
				z["heard_muzzle_until"] = sim.elapsed+1.2
				z["heard_muzzle_pos"] = goal
			elif z.get("heard_muzzle_until",0.0) <= sim.elapsed or z.get("heard_muzzle_pos",Vector2.INF).distance_to(goal) > 3:
				# An impact gives incoming-fire bearing, not the shooter's exact
				# position through unseen rooms. Move out to investigate that bearing.
				goal = noise.pos+(goal-noise.pos).limit_length(8.0)
			var duration = 12.0 # Fresh audible shots renew this; stale evidence must expire.
			if z.get("investigate_until",0.0) > sim.elapsed and z.get("investigate_pos",Vector2.INF).distance_to(goal) < 3:
				z.investigate_until = sim.elapsed+duration
				continue
			var found = false
			for offset in [Vector2.ZERO,(z.pos-goal).normalized()*1.5,(z.pos-goal).normalized()*3.0]:
				var candidate: Vector2 = goal+offset
				if sim.arena.clear(candidate,candidate) and not sim.arena.path_to(z.pos,candidate).is_empty():
					z.investigate_pos = candidate
					found = true
					break
			if found:
				z.investigate_until = sim.elapsed+duration
				z.search_until = 0.0
				sim.paths.erase(z.id)
	sound_events.clear()

func finish_label() -> String:
	if not state.exit_control: return "先启动门锁并坚守 30 秒"
	if survivors().any(func(p): return Rect2(10.1,-57.5,3.8,4).has_point(p.pos)): return "请退离门扇转动区域"
	return super()

func holdout_step(dt: float) -> void:
	if state.holdout_started and not state.exit_control:
		# At least one standing survivor must remain near the entrance.
		if standing().any(func(p): return p.pos.distance_to(Layout.HOLDOUT) < 14):
			state.holdout_time = minf(30,state.holdout_time+dt)
		state.objective = "守住门前 · 解锁剩余 %d 秒" % ceili(30-state.holdout_time)
		for i in 3:
			if state.holdout_time >= i*10:
				queue_batch("night_holdout_"+str(i),Layout.HOLDOUT_BUDGET,[["imp","cone","bucket"],["shield","cone","imp"],["berserker","bucket","cone"]][i])
		if state.holdout_time >= 10 and not state.boss_queued:
			state.boss_queued = true
			state.milestones.boss_queued = sim.elapsed
		if state.holdout_time >= 30:
			state.boss2_queued = true
			state.milestones.boss2_queued = sim.elapsed
			state.exit_control = true
			state.exit_passable = false
			state.exit_motion = 0.0
			state.milestones.holdout_complete = sim.elapsed
			phase("ESCAPE","门已解锁！进入安全屋并按 E 关门")
			sim.arena.sync_campaign(state)

func spawn_boss() -> void:
	var second: bool = state.boss_spawned
	if (not state.boss2_queued or state.boss2_spawned) if second else not state.boss_queued: return
	# Separate slot: no threat points, burst quota or credit used.
	for point in Layout.FINAL_ENTRIES:
		if not safe_point(point): continue
		sim.spawn(point,"football")
		sim.zombies[-1]["boss"] = true
		if second:
			state.boss2_spawned = true
			state.milestones.boss2_spawned = sim.elapsed
			state.milestones.boss2_holdout_time = state.holdout_time
		else:
			state.boss_spawned = true
			state.milestones.boss_spawned = sim.elapsed
			state.milestones.boss_holdout_time = state.holdout_time
		sim.events.append({"kind":"campaign_cue","cue":"horde","position":Vector3(point.x,1,point.y)})
		return

func queue_batch(id: String, budget: int, kinds: Array) -> void:
	if reinforcement_batches.any(func(batch): return batch.id == id): return
	var requested = roundi(budget*reinforcement_scale())
	# Keep finale quotas independent from the increased roaming reinforcements.
	if state.party == 2 and id.begins_with("night_holdout_"): requested = Layout.HOLDOUT_DUO_BUDGET
	var roster = Population.roster(requested,kinds,sim.random,2.0/3.0 if id.begins_with("night_holdout_") else .4)
	reinforcement_batches.append({"id":id,"queued_at":sim.elapsed,"roster":roster,"spawned":0,"budget":requested,"spent":0,"planned":roster.size()})
	var source: Vector2 = Layout.HOLDOUT if id.begins_with("night_holdout_") else standing()[0].pos if not standing().is_empty() else Layout.START
	sim.events.append({"kind":"campaign_cue","cue":"horde","position":Vector3(source.x,1,source.y)})

func spawn_groups() -> void:
	spawn_boss()
	if sim.elapsed >= burst_at and burst_left <= 0:
		burst_left = 6 if state.party == 1 else Layout.DUO_BURST_SIZE
		burst_at = sim.elapsed+2.0
	if burst_left <= 0 or sim.elapsed < burst_next: return
	# Round-robin batches prevent a blocked earlier wave starving the finale.
	for offset in reinforcement_batches.size():
		var index = (batch_cursor+offset)%reinforcement_batches.size()
		var batch: Dictionary = reinforcement_batches[index]
		if batch.roster.is_empty(): continue
		credit = 1
		var entries: Array = Layout.FINAL_ENTRIES if batch.id.begins_with("night_holdout_") else Layout.ENTRIES
		if spawn_one(entries,batch.roster[0]):
			batch.spent += Population.COST[batch.roster.pop_front()]
			batch.spawned += 1
			if not batch.has("spawn_times"): batch.spawn_times = []
			batch.spawn_times.append(sim.elapsed)
			if not batch.has("spawn_points"): batch.spawn_points = []
			batch.spawn_points.append(sim.zombies[-1].pos)
			burst_left -= 1
			burst_next = sim.elapsed+.1
			batch_cursor = (index+1)%reinforcement_batches.size()
			return

func _init(world) -> void:
	Layout = preload("res://scripts/night_layout.gd")
	super(world)
	state.gate_open = true
	state.exit_control = false
	state.holdout_started = false
	state.holdout_time = 0.0
	state.boss_queued = false
	state.boss_spawned = false
	state.boss2_queued = false
	state.boss2_spawned = false
	state.power_ready = true
	state.objective = "沿绿灯穿过街口与店铺，抵达林边安全屋"
	sim.arena.sync_campaign(state)

func reinforcement_scale() -> float: return Layout.DUO_REINFORCEMENT_SCALE if state.party == 2 else 1.0
func multiply() -> float: return Population.party_multiplier(state.party)

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
		var budget = roundi(zone.budget*multiply())
		var roster = Population.roster(budget,zone.kinds,sim.random)
		var wanted = roster.size()
		var spent = 0
		while (not candidates.is_empty() or not concealed.is_empty()) and count < wanted:
			var pool: Array = concealed if not concealed.is_empty() and (count%5 != 0 or candidates.is_empty()) else candidates
			var index = sim.random.randi_range(0,pool.size()-1)
			var point: Vector2 = pool[index]
			pool.remove_at(index)
			if sim.zombies.any(func(z): return z.pos.distance_to(point) < 1.6): continue
			sim.spawn(point,population_kind(roster[count]))
			spent += Population.COST[roster[count]]
			var z: Dictionary = sim.zombies[-1]
			z.guard_awake = false
			z["home"] = point
			z["idle_heading"] = sim.random.randf_range(-PI,PI)
			z.heading = z.idle_heading
			count += 1
		state.zones[zone.id] = {"preplaced":count,"requested":wanted,"budget":budget,"spent":spent}
		if count < wanted: push_warning("Night habitat population shortfall: "+zone.id+" "+str(count)+"/"+str(wanted))

func target(p: Dictionary) -> Dictionary:
	for other in sim.pawns.values():
		if other.id != p.id and other.get("downed",false) and near(p,other.pos): return {"id":"revive:"+other.id,"label":"救起 "+other.name,"seconds":4.0}
	if not state.departed and p.pos.distance_to(Layout.START_DOOR.get_center()) < 2.6:
		return {} if state.get("start_opening",false) else {"id":"depart","label":"推开安全屋门" if state.get("bar_removed",false) else "拆除横向门闩","seconds":0.0}
	if state.departed and not state.holdout_started and near(p,Layout.HOLDOUT,2.6): return {"id":"holdout","label":"拉下开关 · 坚守 30 秒","seconds":0.0}
	if state.departed and Layout.EXIT_ROOM.has_point(p.pos): return {} if state.get("exit_closing",false) else {"id":"finish","label":finish_label(),"seconds":0.0}
	return equipment.pickup_target(p)

func perform(p: Dictionary, id: String) -> void:
	if id == "depart":
		if state.departed or not start_room_ready() or p.pos.distance_to(Layout.START_DOOR.get_center()) >= 2.6: return
		if state.get("start_opening",false): return
		p.pickup_latched = true
		if not state.get("bar_removed",false):
			state.bar_removed = true
			state.bar_time = 0.0
			state.objective = "门闩已拆除 · 再按 E 推开门"
		else: state.start_opening = true
		sim.events.append({"kind":"campaign_cue","cue":"gate","position":Vector3(0,1.9,65)})
	elif id == "holdout":
		if not state.departed or state.holdout_started or not near(p,Layout.HOLDOUT,2.6): return
		state.holdout_started = true
		p.pickup_latched = true
		sim.events.append({"kind":"campaign_cue","cue":"winch","position":Vector3(14.4,1.5,-50)})
		state.milestones.holdout_started = sim.elapsed
		phase("HOLDOUT","守住门前 30 秒，等待安全屋解锁")
		burst_at = sim.elapsed
		burst_left = 0
	elif id == "finish":
		if not state.get("exit_passable",false) or state.get("exit_closing",false): return
		if finish_label() != "关闭安全屋门，完成本关": return
		state.exit_closing = true
		p.pickup_latched = true
		sim.events.append({"kind":"campaign_cue","cue":"gate","position":Vector3(12,2,-54)})
	else:
		for item in Layout.ITEMS:
			if item.kind == "med" and item.id == id:
				equipment.pickup(p,"medical:"+id)
				return
		super(p,id)

func guidance(p: Dictionary) -> String:
	if state.holdout_started and not state.exit_control: return "留在门前 14 米内坚守 · 离开则解锁暂停"
	return "沿绿灯推进 · 门前按 E 启动解锁，坚守 30 秒后进屋关门"

func step_props(dt: float) -> void:
	state.prop_clock = state.get("prop_clock",0.0)+dt
	for p in sim.pawns.values(): p.pickup_remaining = maxf(0,p.get("pickup_until",0.0)-state.prop_clock)
	for motion in state.get("pickup_motion",[]):
		var owner: Dictionary = sim.pawns.get(motion.owner,{})
		if not owner.is_empty() and state.prop_clock-motion.at < .65:
			motion.to = equipment.grab_point(owner)
			motion.pitch = owner.pitch
	if state.get("bar_removed",false): state.bar_time = minf(2,state.get("bar_time",0.0)+dt)
	if state.get("start_opening",false) and not state.departed:
		state.start_motion = minf(1,state.get("start_motion",0.0)+dt/1.1)
		if state.start_motion >= 1:
			state.departed = true
			sim.elapsed = 0.0
			phase("STREET","穿过堵车街口，沿绿灯进入店铺")
			sim.arena.sync_campaign(state)
	if state.exit_control:
		var previous: bool = state.get("exit_passable",false)
		if state.get("exit_closing",false) and finish_label() != "关闭安全屋门，完成本关":
			state.exit_closing = false # Reopen rather than crush a player or lock enemies inside.
		state.exit_motion = move_toward(state.get("exit_motion",0.0),0.0 if state.get("exit_closing",false) else 1.0,dt/1.1)
		state.exit_passable = state.exit_motion >= .999
		if state.get("exit_closing",false) and state.exit_motion <= 0:
			state.complete = true
			phase("COMPLETE","灰松夜路完成 · 安全屋门已关闭")
			save_diagnostics()
		if previous != state.exit_passable or state.complete: sim.arena.sync_campaign(state)

func safe_point(point: Vector2) -> bool:
	if not super(point): return false
	# Dark does not authorize visible pop-in, including beside a player's peripheral view.
	return survivors().all(func(p): return not sim.arena.surface_hit(Vector3(p.pos.x,p.height+1.5,p.pos.y),Vector3(point.x,1.2,point.y)).is_empty())

func step(dt: float) -> void:
	if state.complete or sim.failed: return
	step_props(dt)
	interactions(dt)
	sim.arena.scenery.sync(state)
	if not state.departed or state.complete: return
	for p in standing(): p.route_hint = guidance(p)
	if standing().any(func(p): return p.pos.y < 5) and not state.milestones.has("woods"):
		state.milestones.woods = sim.elapsed
		phase("FINAL_APPROACH","穿过林缘，寻找安全屋暖灯")
		queue_batch("night_woods",Layout.WOODS_BUDGET,["imp","cone","bucket","shield","berserker"])
	while sim.elapsed >= next_timer_index*Layout.TIMER_INTERVAL:
		queue_batch("night_timer_"+str(next_timer_index),Layout.TIMER_SOLO_BUDGET if state.party == 1 else Layout.TIMER_BUDGET,["cone","imp","bucket","shield","berserker"])
		next_timer_index += 1
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
					sim.events.append({"kind":"campaign_cue","cue":"growl","position":Vector3(z.pos.x,1,z.pos.y)})
					cue_at = sim.elapsed+12
					break
	sim.arena.scenery.sync(state)
