extends SceneTree
## Internal gameplay API QA: inputs go through Simulation.submit and real capsule movement.
## Explicit state fixtures below test edge cases; traversal never teleports or grants invulnerability.
const Layout = preload("res://scripts/campaign_layout.gd")
var game
var count = 0
var failures: Array[String] = []
var runs: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	count += 1
	if not ok:
		failures.append(message)
		print("CAMPAIGN FAIL: "+message)

func start(party := 1) -> void:
	game.return_home()
	root.get_node("Data").settings.map_id = Layout.ID
	game.start_solo("campaign")
	if party > 1:
		game.sim.campaign = null
		for i in range(1,party): game.sim.add_pawn("qa%d" % i,"队友%d" % i,i)
		game.sim.start("campaign")
	await physics_frame
	await process_frame

func command(p: Dictionary, destination: Vector2, interact := false, heal := false) -> Dictionary:
	var delta = destination-p.pos
	var yaw: float = p.yaw
	var pitch = 0.0
	var fire = false
	var closest = 32.0
	for z in game.sim.zombies:
		if z.hp <= 0: continue
		var d: float = z.pos.distance_to(p.pos)
		if d >= closest: continue
		var origin = Vector3(p.pos.x,p.height+1.7,p.pos.y)
		var poses: Array = load("res://scripts/enemy_view.gd").transforms(z,game.sim.elapsed,false)
		var target: Vector3 = poses[0].origin
		for part in root.get_node("Data").parts.size():
			if root.get_node("Data").parts[part].get("head",false):
				target = poses[part].origin
				break
		if not game.arena.surface_hit(origin,target).is_empty(): continue
		closest = d
		var aim = target-origin
		yaw = atan2(-aim.x,-aim.z)
		pitch = atan2(aim.y,Vector2(aim.x,aim.z).length())
		fire = true
	var direction = delta.normalized() if delta.length() > .25 else Vector2.ZERO
	var x = direction.x*cos(yaw)-direction.y*sin(yaw)
	var y = direction.x*sin(yaw)+direction.y*cos(yaw)
	var selected = 6 if p.reserve == 0 and p.ammo[p.primary] == 0 else p.primary
	return {"x":x,"y":y,"yaw":yaw,"pitch":pitch,"weapon":selected,"fire":fire and not interact and not heal,"reload":p.ammo[p.primary] < 5,"interact":interact,"heal":heal,"jump":game.sim.zombies.any(func(z): return z.hp > 0 and z.kind == "football" and z.state == "charging" and z.pos.distance_to(p.pos) < 8)}

func tick(destinations: Dictionary, action := "", dt := .05) -> void:
	for p in game.sim.pawns.values():
		var dest: Vector2 = destinations.get(p.id,p.pos)
		game.sim.submit(p.id,command(p,dest,action == "interact",action == "heal"))
	game.sim.step(dt)

func move_party(goal: Vector2, timeout := 80.0) -> bool:
	var paths: Dictionary = {}
	var stalled = 0.0
	for p in game.sim.pawns.values():
		paths[p.id] = game.arena.path_to(p.pos,goal)
		if not paths[p.id].is_empty(): paths[p.id].append(goal)
	for step in ceili(timeout/.05):
		if game.sim.failed: return false
		var destinations = {}
		var arrived = true
		for p in game.sim.pawns.values():
			if p.hp <= 0: continue
			if p.pos.distance_to(goal) > .55: arrived = false
			var path: PackedVector2Array = paths[p.id]
			while path.size() > 1 and p.pos.distance_to(path[0]) < .85: path.remove_at(0)
			paths[p.id] = path
			destinations[p.id] = path[0] if not path.is_empty() else goal
		if arrived: return true
		var heal = game.sim.pawns.values().any(func(p): return p.hp > 0 and p.hp < 55 and p.medkits > 0)
		tick(destinations,"heal" if heal else "")
		stalled += .05
		if step % 100 == 0: await process_frame
	print("Traversal stopped at ",game.local_pawn().pos," goal ",goal," hp ",game.local_pawn().hp)
	return false

func hold(seconds: float, action := "interact") -> void:
	for i in ceili(seconds/.05):
		tick({},action)
		if i % 100 == 0: await process_frame

func play(party: int, yard: bool) -> void:
	await start(party)
	game.sim.random.seed = 104729+party
	var passed = await move_party(Vector2(0,111))
	await hold(1.2)
	check(game.sim.campaign.state.departed,"Internal input opens start door (%d)" % party)
	for goal in [Vector2(0,103),Vector2(18,96),Vector2(18,78),Vector2(-15,70),Vector2(-15,53)]:
		passed = await move_party(goal) and passed
	if yard:
		for goal in [Vector2(-33,52),Vector2(-44,52),Vector2(-44,41)]: passed = await move_party(goal) and passed
		await hold(.4)
		for goal in [Vector2(-44,32),Vector2(-29,32),Vector2(-15,40)]: passed = await move_party(goal) and passed
	for goal in [Vector2(8,30),Vector2(8,6),Vector2(0,-8),Vector2(11,-11)]: passed = await move_party(goal) and passed
	await hold(.4)
	passed = await move_party(Vector2(8,-14.4)) and passed
	await hold(2.3)
	check(game.sim.campaign.state.phase == "BRIDGE_ACTIVE","Internal input starts winch (%d)" % party)
	# Hold the arena, firing through the same gun rules. Heal/reload use input commands.
	for i in 1900:
		if game.sim.failed or game.sim.campaign.state.gate_open: break
		var destinations = {}
		var angle = i*.035
		for p in game.sim.pawns.values(): destinations[p.id] = Vector2(cos(angle)*5,-18+sin(angle)*5)
		var heal = game.sim.pawns.values().any(func(p): return p.hp > 0 and p.hp < 60 and p.medkits > 0)
		tick(destinations,"heal" if heal else "")
		if i % 100 == 0: await process_frame
	check(game.sim.campaign.state.gate_open,"90-second event opens gate (%d)" % party)
	for goal in [Vector2(0,-29),Vector2(0,-50),Vector2(0,-62),Vector2(20,-77)]: passed = await move_party(goal) and passed
	await hold(.5)
	var kills_before_final: int = game.sim.kills
	for goal in [Vector2(36,-92),Vector2(8,-103),Vector2(25,-115),Vector2(25,-123)]: passed = await move_party(goal) and passed
	check(game.sim.kills > kills_before_final,"Final approach produces combat before entering safe room (%d)" % party)
	await hold(2)
	check(passed and game.sim.won,"Entire hostile route completes through internal inputs (%d, yard=%s)" % [party,yard])
	var summary = {"party":party,"yard":yard,"won":game.sim.won,"seconds":game.sim.elapsed,"kills":game.sim.kills,"hp":game.local_pawn().hp,"shots":game.local_pawn().shots}
	runs.append(summary)
	summary["final_kills"] = game.sim.kills-kills_before_final
	print("CAMPAIGN PLAY: ",JSON.stringify(summary))

func fixtures() -> void:
	await start(1)
	game.sim.campaign.state.departed = true
	game.sim.campaign.state.gate_open = true
	game.sim.campaign.phase("FINAL_APPROACH","QA")
	game.sim.campaign.state.rest_until = game.sim.elapsed+25
	game.sim.pawns.solo.pos = Vector2(20,-77)
	game.sim.campaign.step(.05)
	check(game.sim.campaign.state.rest_until > game.sim.elapsed and not game.sim.campaign.state.zones.has("final"),"Shed preserves its rest interval")
	game.sim.pawns.solo.pos = Vector2(36,-84)
	game.sim.campaign.step(.05)
	check(game.sim.campaign.state.rest_until == 0 and game.sim.campaign.state.zones.has("final"),"Leaving shed activates final encounter before rest timer expires")
	var final_until: float = game.sim.campaign.state.zones.final.until
	game.sim.pawns.solo.pos = Vector2(20,-77)
	game.sim.campaign.step(.05)
	check(game.sim.campaign.state.rest_until == 0 and game.sim.campaign.state.zones.final.until == final_until,"Returning to shed cannot reset rest or final encounter")
	await start(2)
	var sim = game.sim
	var p: Dictionary = sim.pawns.solo
	var q: Dictionary = sim.pawns.qa1
	check(not game.arena.clear(Vector2(0,-54),Vector2(0,-61)),"Closed gate blocks navigation")
	check(not game.arena.path_to(Vector2(0,-20),Vector2(0,-80)).size(),"Closed gate prevents river bypass")
	for point in [Vector2(6,-40),Vector2(6,-45),Vector2(0,-40)]:
		var hit = game.arena.surface_hit(Vector3(point.x,2,point.y),Vector3(point.x,-2,point.y))
		check(not hit.is_empty() and absf(hit.position.y-root.get_node("Data").enemy_ground_height(point,Layout.ID)) < .12,"Physical ground matches shared enemy height "+str(point))
	# Edge-case fixtures deliberately position entities, separate from end-to-end traversal above.
	p.pos = Vector2(0,112)
	q.pos = Vector2(1,112)
	await hold(.5)
	check(not sim.campaign.state.departed,"Releasing departure before one second cancels")
	await hold(.1,"")
	await hold(1.2)
	check(sim.campaign.state.departed,"Cooperative departure fixture")
	p.hp = 60
	await hold(3.2,"heal")
	check(p.hp == 100 and p.medkits == 0,"Medical pack consumes once and clamps health")
	p.hp = 40
	p.medkits = 1
	await hold(1,"heal")
	sim.damage_pawn(p,{"pos":p.pos,"id":42},10)
	await hold(.05,"heal")
	check(p.hp == 30 and p.medkits == 1 and p.interact_time == 0,"Damage cancels incomplete treatment without consuming it")
	await hold(.1,"")
	p.pos = Vector2(-44,41)
	q.pos = Vector2(-44,41)
	p.reserve = 0
	q.reserve = 0
	await hold(.4)
	check(p.reserve == 60 and q.reserve == 60,"Ammo point grants each player an independent allocation")
	await hold(.5)
	check(p.reserve == 60 and q.reserve == 60,"Repeated interaction cannot farm the ammo point")
	p.pos = Vector2(-46,41)
	q.pos = Vector2(-46,41)
	p.medkits = 0
	q.medkits = 0
	await hold(.4)
	check(p.medkits+q.medkits == 1,"Concurrent shared medical pickup is awarded once")
	p.pos = Vector2(0,112)
	q.pos = Vector2(1,112)
	p.reserve = 3
	p.ammo[0] = 0
	for i in 45:
		sim.submit(p.id,{"reload":true})
		sim.update_pawn(p,.05)
	check(p.ammo[0] == 3 and p.reserve == 0,"Partial reload conserves reserve")
	sim.submit(p.id,{"weapon":9})
	sim.update_pawn(p,.05)
	check(p.requested == p.primary,"Post-departure weapon switching cannot create ammo")
	q.pos = p.pos+Vector2(1,0)
	q.hp = 0
	sim.campaign.damage(q)
	check(q.downed and not q.dead,"Cooperative lethal damage enters downed state")
	await hold(1.0)
	check(q.bleed == 30.0 and q.hp == 0,"Active rescue pauses the bleed timer without early revival")
	await hold(.5,"")
	check(q.bleed < 30.0 and p.interact_time == 0,"Cancelled rescue resets progress and resumes bleeding")
	await hold(4.3)
	check(q.hp == 30 and not q.downed and q.revives == 1,"Held rescue input revives partner")
	q.hp = 0
	q.revives = 2
	sim.campaign.damage(q)
	check(q.dead and not q.downed,"Third lethal hit cannot be revived")
	sim.campaign.state.gate_open = true
	sim.arena.sync_campaign(sim.campaign.state)
	check(game.arena.clear(Vector2(0,-54),Vector2(0,-61)),"Opened gate updates path blocking")
	check(sim.campaign.safe_point(p.pos) == false,"Spawn safety rejects positions beside a player")
	sim.campaign.credit = 1.0
	var old_count: int = sim.zombies.size()
	check(not sim.campaign.spawn_one([],"normal") and sim.zombies.size() == old_count and sim.campaign.credit <= 1,"Unavailable entrances do not spend budget or build burst credit")
	var session = root.get_node("Session")
	session.members = {"solo":"幸存者","qa1":"队友"}
	session.map_id = Layout.ID
	check(session.valid_world(sim.snapshot()),"Campaign snapshot passes the real transport validator")
	var malformed: Dictionary = sim.snapshot()
	malformed.pawns.solo.reserve = "untrusted"
	check(not session.valid_world(malformed),"Transport rejects invalid campaign inventory types")
	malformed = sim.snapshot()
	malformed.campaign.bridge_time = NAN
	check(not session.valid_world(malformed),"Transport rejects non-finite event timers")
	p.pos = Vector2(25,-124)
	p.hp = 100
	p.height = 0
	q.dead = false
	q.hp = 30
	q.pos = Vector2(25,-115)
	await hold(1.2)
	check(not sim.won,"Living teammate outside the safe room blocks completion")
	q.dead = true
	q.hp = 0
	sim.spawn(Vector2(26,-124),"normal")
	await hold(1.2)
	check(not sim.won,"Enemy inside the safe room blocks closure")
	sim.zombies.clear()
	await hold(1.2)
	check(sim.won,"Dead partner does not block final safe room")
	var before: int = p.hp
	sim.damage_pawn(p,{"pos":p.pos,"id":42},50)
	check(p.hp == before,"Completion freezes damage")
	await start()
	check(not game.sim.won and game.sim.campaign.state.taken.is_empty() and not game.sim.campaign.state.gate_open,"Restart clears progress, pickups and gate")
	game.sim.campaign.state.departed = true
	game.sim.pawns.solo.hp = 0
	game.sim.step(.05)
	check(game.sim.failed and game.sim.campaign.state.phase == "FAILED","Solo lethal state fails without waiting for rescue")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	await fixtures()
	for party in [1,2,4]: await play(party,party != 2)
	var report = {"checks":count,"failures":failures,"runs":runs,"boundary":"Internal input traversal and explicit edge-case fixtures; not human pacing, GPU visuals or Steam cross-account acceptance"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file = FileAccess.open("res://artifacts/campaign-acceptance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("CAMPAIGN VALIDATION: %d checks; %d failures" % [count,failures.size()])
	game.return_home()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
