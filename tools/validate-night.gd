extends "res://tools/validate-campaign.gd"

func _init() -> void:
	Layout = preload("res://scripts/night_layout.gd")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	await start(1,71245)
	check(game.sim.zombies.size() >= 180,"Dense baseline population exists before departure")
	check(game.sim.zombies.all(func(z): return not z.guard_awake),"Habitats begin idle")
	check(game.sim.zombies.all(func(z): return game.arena.clear(z.pos,z.pos)),"No infected start inside solid cover")
	check(is_equal_approx(root.get_node("Data").enemy_ground_height(Vector2(0,-17),Layout.ID),-.05),"Night terrain does not inherit the old outpost river depression")
	var hidden = 0
	for infected in game.sim.zombies:
		var road: Vector2 = Layout.closest_route(infected.pos)
		if not game.arena.surface_hit(Vector3(road.x,1.7,road.y),Vector3(infected.pos.x,1.2,infected.pos.y)).is_empty(): hidden += 1
	print("NIGHT HABITATS: total=",game.sim.zombies.size()," solid_occluded_from_nearest_route=",hidden)
	check(hidden >= 60,"Many habitats are behind real cover, independent of darkness")
	var p: Dictionary = game.local_pawn()
	check(game.arena.surface_hit(Vector3(0,1.7,60),Vector3(0,1.7,-49)).size() > 0,"Buildings obstruct long-range shooting lane")
	game.sim.campaign.state.departed = true
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
	# Synthetic traversal observations are saved even on death; no invulnerability or teleport.
	for seed_value in [71245,71246]:
		await start(1,seed_value)
		var driver = load("res://tools/campaign-limited-driver.gd").new(game,false)
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
		var result = {"seed":seed_value,"won":game.sim.won,"failed":game.sim.failed,"seconds":game.sim.elapsed,"kills":game.sim.kills,"task":driver.index,"position":game.local_pawn().pos,"remaining":game.sim.zombies.filter(func(enemy): return enemy.hp > 0).size(),"timings":timings,"diagnostics":game.sim.campaign.diagnostics()}
		runs.append(result)
		print("NIGHT RESULT ",JSON.stringify(result))
	check(runs.all(func(result): return result.won),"Both fixed limited-input seeds reach the safe room")
	check(runs.all(func(result): return result.seconds >= 120 and result.seconds <= 240),"Synthetic route stays within the documented 2-4 minute calibration band")
	check(runs.all(func(result): return result.remaining >= 60),"Completion does not require clearing hidden population")
	var f = FileAccess.open("res://artifacts/night-acceptance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":count,"failures":failures,"runs":runs,"boundary":"Synthetic limited inputs; three-minute fun and native GPU still require human acceptance."},"  "))
	f.close()
	game.return_home()
	game.queue_free()
	await process_frame
	await physics_frame
	await process_frame
	await create_timer(.15).timeout
	print("NIGHT VALIDATION: %d checks; %d failures" % [count,failures.size()])
	quit(0 if failures.is_empty() else 1)
