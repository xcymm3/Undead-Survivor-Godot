extends SceneTree
## Internal gameplay API QA: inputs go through Simulation.submit and real capsule movement.
## Explicit state fixtures below test edge cases; traversal never teleports or grants invulnerability.
var Layout = preload("res://scripts/night_layout.gd")
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

func start(party := 1, seed_value := -1) -> void:
	game.return_home()
	root.get_node("Data").settings.map_id = Layout.ID
	game.start_solo("campaign",seed_value)
	if party > 1:
		game.sim.campaign = null
		for i in range(1,party): game.sim.add_pawn("qa%d" % i,"队友%d" % i,i)
		if seed_value >= 0: game.sim.random.seed = seed_value
		game.sim.start("campaign")
	await physics_frame
	await process_frame


func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	await start(1,71245)
	validate_lighting()
	validate_population()
	check(game.sim.zombies.filter(func(z): return z.kind in ["normal","crawler"]).size() >= ceili(Layout.ZONES.reduce(func(total,zone): return total+zone.budget,0)/2.0),"At least half the habitat point budget remains ordinary infected")
	check(game.sim.zombies.all(func(z): return not z.guard_awake),"Habitats begin idle")
	check(game.sim.zombies.all(func(z): return game.arena.clear(z.pos,z.pos)),"No infected start inside solid cover")
	check(is_equal_approx(root.get_node("Data").enemy_ground_height(Vector2(0,-17),Layout.ID),-.05),"Night terrain does not inherit the old outpost river depression")
	var hidden = 0
	for infected in game.sim.zombies:
		var road: Vector2 = Layout.closest_route(infected.pos)
		if not game.arena.surface_hit(Vector3(road.x,1.7,road.y),Vector3(infected.pos.x,1.2,infected.pos.y)).is_empty(): hidden += 1
	print("NIGHT HABITATS: total=",game.sim.zombies.size()," solid_occluded_from_nearest_route=",hidden)
	check(hidden >= ceili(game.sim.zombies.size()/3.0),"At least one third of point-budget habitats are behind real cover, independent of darkness")
	var p: Dictionary = game.local_pawn()
	for slot in [4,5]:
		var reload_probe: Dictionary = p.duplicate(true)
		reload_probe.weapon = 3
		reload_probe.slot = slot
		reload_probe.reloading = true
		reload_probe.reload = .8
		reload_probe.ammo[3] = 2
		game.sim.update_arsenal(reload_probe,{"slot":slot},.016)
		check(not reload_probe.reloading and reload_probe.ammo[3] == 2,"Revolver reload cancels without free ammunition when equipping item slot "+str(slot))
	check(game.arena.surface_hit(Vector3(0,1.7,60),Vector3(0,1.7,-49)).size() > 0,"Buildings obstruct long-range shooting lane")
	game.sim.campaign.state.departed = true
	game.sim.campaign.state.exit_control = true
	game.arena.sync_campaign(game.sim.campaign.state)
	for i in range(Layout.ROUTE.size()-1):
		check(not game.arena.path_to(Layout.ROUTE[i],Layout.ROUTE[i+1]).is_empty(),"Route segment connects "+str(i))
	var reachable = 0
	for z in game.sim.zombies:
		if not game.arena.path_to(z.pos,Layout.EXIT).is_empty(): reachable += 1
	check(reachable == game.sim.zombies.size(),"Every habitat connects to the route")
	for item in Layout.ITEMS: check(not game.arena.path_to(Layout.START,item.pos).is_empty(),"Supply reachable: "+item.id)
	var z: Dictionary = game.sim.zombies[0]
	var view = load("res://scripts/enemy_view.gd")
	var first: Array = view.transforms(z,0,false)
	var second: Array = view.transforms(z,1,false)
	check(first[0] != second[0],"Idle pose visibly changes, with shared CPU/GPU root")
	var ordinary: Dictionary = game.sim.zombies.filter(func(enemy): return enemy.kind == "normal")[0]
	game.sim.hit_enemy(ordinary,10,false,p,Vector3(ordinary.pos.x,1,ordinary.pos.y))
	check(ordinary.state == "stunned","A nonlethal bullet visibly staggers an ordinary infected")
	ordinary.state_time = .07
	game.sim.hit_enemy(ordinary,10,false,p,Vector3(ordinary.pos.x,1,ordinary.pos.y))
	check(is_equal_approx(ordinary.state_time,.07),"Rapid follow-up hits do not extend stagger through its cooldown")
	var probe: Dictionary = ordinary.duplicate(true)
	probe.pos = Vector2(.55,17)
	probe.guard_awake = true
	probe.state = "ready"
	probe.attack_time = .3
	var saved_pos: Vector2 = p.pos
	p.pos = Vector2(1.45,17)
	var saved_hp: int = p.hp
	game.sim.update_zombie(probe,p,.1)
	check(p.hp == saved_hp,"An infected cannot melee through the shop side wall")
	p.pos = saved_pos
	check(not game.sim.campaign.safe_point(p.pos+Vector2(0,-2)),"Reinforcement cannot materialize beside player")
	game.sim.campaign.queue_batch("blocked_fixture",5,["normal"])
	game.sim.campaign.credit = 1
	var pending: int = game.sim.campaign.reinforcement_batches[-1].roster.size()
	check(not game.sim.campaign.spawn_one([p.pos],"normal"),"Unsafe batch remains blocked")
	check(game.sim.campaign.reinforcement_batches[-1].roster.size() == pending,"Blocked batch keeps remaining quota")
	await start(1,71245)
	p = game.local_pawn()
	p.pos = Vector2(0,66.5)
	check(game.sim.campaign.target(p).get("id","") == "depart","Closed departure door can be operated from inside")
	await validate_sound_and_holdout()
	# Synthetic traversal observations are saved even on death; no invulnerability or teleport.
	for seed_value in [71245,71246]:
		await start(1,seed_value)
		var driver = load("res://tools/campaign-unrestricted-driver.gd").new(game,false)
		var timings: Array = []
		var last_index = -1
		for i in 7200:
			if game.sim.won or game.sim.failed: break
			if driver.index != last_index:
				last_index = driver.index
				timings.append({"task":last_index,"at":game.sim.elapsed,"hp":game.local_pawn().hp})
			game.sim.submit("solo",driver.command(.05))
			game.sim.step(.05)
			if i%100 == 0: await process_frame
		var result = {"boss_remaining":game.sim.zombies.filter(func(enemy): return enemy.kind == "football").map(func(enemy): return {"hp":enemy.hp,"armor":enemy.armor}),"hp":game.local_pawn().hp,"medkits":game.local_pawn().medkits,"grenades":game.local_pawn().grenades,"shoves":game.local_pawn().get("shoves",0),"shove_hits":game.local_pawn().get("shove_hits",0),"seed":seed_value,"won":game.sim.won,"failed":game.sim.failed,"seconds":game.sim.elapsed,"kills":game.sim.kills,"task":driver.index,"position":game.local_pawn().pos,"remaining":game.sim.zombies.filter(func(enemy): return enemy.hp > 0).size(),"timings":timings,"diagnostics":game.sim.campaign.diagnostics()}
		runs.append(result)
		print("NIGHT RESULT ",JSON.stringify(result))
	check(runs.all(func(result): return result.won),"Both fixed unrestricted-input seeds reach the safe room")
	check(runs.all(func(result): return result.diagnostics.milestones.get("holdout_complete",0)-result.diagnostics.milestones.get("holdout_started",0) >= 29.95),"Every successful route includes the full holdout")
	check(runs.all(func(result): return result.remaining > 0),"Completion leaves living enemies; hearing can now draw formerly hidden population")
	var f = FileAccess.open("res://artifacts/night-acceptance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":count,"failures":failures,"runs":runs,"boundary":"Synthetic unrestricted input policy, normal authority and resources; human fun and native GPU still require acceptance. No duration gate."},"  "))
	f.close()
	game.return_home()
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame
	await create_timer(.15).timeout
	print("NIGHT VALIDATION: %d checks; %d failures" % [count,failures.size()])
	quit(0 if failures.is_empty() else 1)

func validate_population() -> void:
	var population = preload("res://scripts/night_population.gd")
	var director = game.sim.campaign
	for zone in director.state.zones.values():
		check(zone.spent == zone.budget and zone.preplaced == zone.requested,"Habitat spends complete point budget")
	for kind in population.SPECIALS:
		check(game.sim.zombies.any(func(z): return z.kind == kind),"Route includes special type "+kind)
	check(game.sim.zombies.all(func(z): return z.kind not in ["giant","football"]),"Neither giant nor boss in ordinary habitats")
	var random = RandomNumberGenerator.new()
	random.seed = 82
	for budget in [0,1,5,18,22,68]:
		var roster = population.roster(budget,population.SPECIALS+["giant","football"],random)
		check(population.points(roster) == budget,"Exact point accounting budget "+str(budget))
		check(roster.all(func(kind): return kind not in ["giant","football"]),"Unsupported boss/giant excluded from budget pool")
	# All entries occupied: boss debt survives and bypasses ordinary population cap.
	var saved = game.sim.zombies.duplicate(true)
	game.sim.zombies.clear()
	director.state.boss_queued = true
	for point in Layout.FINAL_ENTRIES: game.sim.spawn(point,"normal")
	director.spawn_boss()
	check(not director.state.boss_spawned,"Unsafe boss remains pending instead of disappearing")
	game.sim.zombies.clear()
	game.local_pawn().pos = Layout.HOLDOUT
	for i in director.cap(): game.sim.spawn(Vector2(0,50),"normal")
	director.spawn_boss()
	check(director.state.boss_spawned,"Boss has independent slot even at normal cap")
	director.spawn_boss()
	check(game.sim.zombies.filter(func(z): return z.kind == "football").size() == 1,"Retry never duplicates boss")
	game.sim.zombies = saved
	game.local_pawn().pos = Layout.START
	director.state.boss_queued = false
	director.state.boss_spawned = false
	for key in ["boss_queued","boss_spawned","boss_holdout_time"]: director.state.milestones.erase(key)


func validate_lighting() -> void:
	var data = root.get_node("Data")
	var saved_shadows = data.settings.shadows
	for level in [0,1,2,3,4]:
		data.settings.shadows = level
		game.apply_graphics()
		var lights = game.arena.find_children("*","Light3D",true,false)
		check(lights.size() > 2,"Night shadow setting includes local lamps and sun")
		check(lights.all(func(light): return light.shadow_enabled == (level > 0)),"Shadow setting reaches every night world light at level "+str(level))
		check(not game.flashlight.shadow_enabled,"Camera beam avoids self-shadow banding at level "+str(level))
	check(game.flashlight.position == Vector3.ZERO,"Flashlight shadow camera stays at the viewpoint, inside wall clearance")
	check(game.arena.scenery.find_children("*","OmniLight3D",true,false).all(func(light): return light.shadow_reverse_cull_face),"Night lamps use closed-mesh back faces to avoid floor shadow acne")
	var p: Dictionary = game.local_pawn()
	var saved = p.duplicate(true)
	var old_yaw = game.yaw
	var old_pitch = game.pitch
	p.pos = Vector2(4.43,70)
	game.yaw = -PI/2
	game.pitch = 0.0
	game._process(.016)
	check(game.flashlight.light_energy < .2,"Close wall beam intensity stays bounded")
	p.pos = Vector2(0,70)
	game.yaw = 0.0
	game._process(.016)
	check(is_equal_approx(game.flashlight.light_energy,3.2),"Flashlight retains full energy beyond the near-wall range")
	for key in saved: p[key] = saved[key]
	game.yaw = old_yaw
	game.pitch = old_pitch
	data.settings.shadows = saved_shadows
	game.apply_graphics()

func validate_sound_and_holdout() -> void:
	await start(1,71245)
	var sim = game.sim
	var director = sim.campaign
	var p: Dictionary = game.local_pawn()
	director.state.departed = true
	game.arena.sync_campaign(director.state)
	sim.zombies.clear()
	p.pos = Vector2(12,-50)
	sim.spawn(Vector2(0,60),"normal")
	var z: Dictionary = sim.zombies[-1]
	z.guard_awake = false
	z.home = z.pos
	z.idle_heading = 0.0
	director.emit_noise(Vector3(0,1.2,57),"impact")
	director.investigate_sounds()
	check(not z.guard_awake and z.get("investigate_until",0.0) > sim.elapsed,"Distant bullet impact starts investigation without omniscient chase")
	var before: Vector2 = z.pos
	sim.update_zombie(z,p,.1)
	check(z.pos.distance_to(Vector2(0,57)) < before.distance_to(Vector2(0,57)),"Investigation moves toward sound, not distant player")
	# A remote bullet impact carries the firing position, not a live player tracker.
	z.pos = Vector2(0,60)
	director.emit_noise(Vector3(0,1.2,57),"impact",Vector2(0,70))
	director.investigate_sounds()
	check(not z.guard_awake and z.investigate_pos.distance_to(Vector2(0,65)) < .1,"Remote impact redirects guards along incoming-fire bearing without revealing exact shooter location")
	var shot_goal: Vector2 = z.investigate_pos
	before = z.pos
	sim.update_zombie(z,p,.1)
	check(z.pos.y > before.y and z.investigate_pos == shot_goal,"Investigator follows incoming fire without tracking a hidden moving player")
	director.emit_noise(Vector3(0,1.2,63),"gunshot",Vector2(0,70))
	director.emit_noise(Vector3(0,1.2,57),"impact",Vector2(0,70))
	director.investigate_sounds()
	check(z.investigate_pos.distance_to(Vector2(0,70)) < .1,"Heard muzzle identifies last firing position and later impact does not pull guards back")
	p.pos = Vector2(0,58)
	director.step(.05)
	check(z.guard_awake,"Investigator switches to chase after seeing a nearby player")
	z.guard_awake = false
	z.investigate_until = 0.0
	p.pos = Vector2(12,-50)
	director.emit_noise(Vector3(0,1.2,63),"gunshot")
	p.fire_anim = 0.0
	director.investigate_sounds()
	check(z.get("investigate_until",0.0) > sim.elapsed,"Independent gunshot is heard after shooting animation has ended")
	z.investigate_until = 0.0
	director.emit_noise(Vector3(12,1.2,-50),"gunshot")
	director.investigate_sounds()
	check(z.investigate_until == 0.0,"Distant gunshot outside hearing range does not wake entire map")
	p.pos = Vector2(0,70)
	p.yaw = -PI/2
	p.pitch = 0.0
	director.sound_events.clear()
	sim.fire(p,root.get_node("Data").weapons[p.primary])
	check(director.sound_events.any(func(event): return event.kind == "gunshot") and director.sound_events.any(func(event): return event.kind == "impact"),"Real gun firing emits both muzzle sound and wall impact events")
	sim.zombies.clear()
	sim.spawn(Vector2(0,67),"normal")
	p.yaw = 0.0
	p.pitch = atan2(-.45,3.0)
	p.aim = true
	var weapon: Dictionary = root.get_node("Data").weapons.filter(func(w): return w.get("piercing",false))[0]
	director.sound_events.clear()
	sim.fire(p,weapon)
	check(director.sound_events.any(func(event): return event.kind == "impact" and event.pos.distance_to(Vector2(0,67)) < 1.2),"Piercing bullet emits sound at hit enemy, not only the distant final wall")
	check(director.sound_events.all(func(event): return event.shot_origin == p.pos),"Gunshot and all actual impact events retain the firing position")
	for party in [1,2]:
		await start(party,71245)
		sim = game.sim
		director = sim.campaign
		p = game.local_pawn()
		director.state.departed = true
		game.arena.sync_campaign(director.state)
		sim.zombies.clear()
		for pawn in sim.pawns.values(): pawn.pos = Layout.HOLDOUT
		check(Layout.FINAL_ENTRIES.size() == 10,"Finale has ten authored entries")
		for entry in Layout.FINAL_ENTRIES.slice(6):
			check(sim.arena.clear(entry,entry) and not sim.arena.path_to(entry,Layout.HOLDOUT).is_empty(),"Added finale entry has clear reachable terrain: "+str(entry))
		check(Layout.FINAL_ENTRIES.any(func(entry): return entry.x < 0 and entry.y < -55 and director.safe_point(entry)),"Concealed left rear entry can actually spawn while players defend")
		check(not game.arena.clear(Vector2(12,-52),Vector2(12,-57)),"Closed exit blocks physical route before event party "+str(party))
		check(director.target(p).get("id","") == "holdout","Door control offers holdout interaction party "+str(party))
		director.perform(p,"finish")
		check(not director.state.complete,"Cannot bypass holdout by sending finish interaction")
		director.perform(p,"holdout")
		director.holdout_step(1.0)
		check(not director.state.boss_queued,"Boss is not queued before ten seconds")
		for pawn in sim.pawns.values(): pawn.pos = Vector2(0,60)
		director.holdout_step(5.0)
		check(is_equal_approx(director.state.holdout_time,1.0),"Leaving entrance pauses holdout countdown")
		for pawn in sim.pawns.values(): pawn.pos = Layout.HOLDOUT
		for i in 580:
			sim.elapsed += .05
			director.holdout_step(.05)
			director.spawn_groups()
			if i == 0: check(is_equal_approx(director.burst_at-sim.elapsed,2.0),"Ordinary reinforcement groups use a two-second schedule")
			for enemy in sim.zombies:
				sim.move_zombie(enemy,Layout.HOLDOUT,float(enemy.chase_speed),.05,enemy.pos.distance_to(Layout.HOLDOUT),1.5)
		var waves: Array = director.reinforcement_batches.filter(func(batch): return batch.id.begins_with("night_holdout_"))
		print("HOLDOUT FIXTURE party=",party," waves=",JSON.stringify(waves)," entries=",Layout.FINAL_ENTRIES.map(func(point): return [point,director.safe_point(point)]))
		check(waves[0].spawn_times.size() >= 3 and waves[0].spawn_times[2]-waves[0].spawn_times[0] < 1.5,"First group enters together instead of slow trickle")
		check(waves.size() == 3,"Exactly three finite holdout batches queued")
		check(waves.all(func(batch): return batch.budget == (Layout.HOLDOUT_DUO_BUDGET if party == 2 else Layout.HOLDOUT_BUDGET) and batch.spent+preload("res://scripts/night_population.gd").points(batch.roster) == batch.budget),"Holdout spends exact point budgets without losing deferred quota")
		check(waves.reduce(func(total,batch): return total+batch.spawned,0) >= ceili(waves.reduce(func(total,batch): return total+batch.planned,0)*.5),"At least half the planned holdout population actually enters")
		check(sim.zombies.filter(func(enemy): return enemy.kind == "football").size() == 2,"Exactly two independent football bosses in solo and duo")
		check(director.state.milestones.get("boss2_holdout_time",0) >= 29.99,"Second boss arrives at end of holdout")
		check(director.state.milestones.get("boss_holdout_time",0) >= 10 and director.state.milestones.get("boss_holdout_time",99) <= 10.1,"Boss appears at ten defended seconds with a safe entry")
		check(sim.zombies.all(func(enemy): return enemy.kind != "giant"),"No giant in holdout population")
		check(director.state.exit_control,"Door unlocks after thirty defended seconds")
		check(not game.arena.clear(Vector2(12,-52),Vector2(12,-57)),"Unlocked door retains navigation blocking while it starts opening")
		director.step_props(1.2)
		check(game.arena.clear(Vector2(12,-52),Vector2(12,-57)),"Fully opened door releases navigation after its animation")
		var spawned: int = sim.zombies.size()
		director.perform(p,"holdout")
		check(director.state.holdout_time >= 30 and sim.zombies.size() == spawned,"Holdout cannot be restarted or duplicated")
