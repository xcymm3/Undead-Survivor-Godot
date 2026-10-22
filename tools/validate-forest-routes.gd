extends RefCounted
## All lane segments, authority movement, interruption recovery and handoff.
static func validate(game, check: Callable) -> void:
	var sim = load("res://scripts/simulation.gd").new(game.arena)
	sim.add_pawn("solo","Route fixture",0)
	sim.start("defense")
	preload("res://tools/preparation-fixture.gd").skip_tutorial(sim)
	var routes = sim.defense_spawner.forest_routes
	check.call(routes.entries.size() == 20,"Exactly twenty fixed forest birth lanes are available")
	var origins = {}
	for entry in routes.entries: origins[entry.points[0]] = true
	check.call(origins.size() == 20,"All forest origins are distinct")
	var kinds = ["normal","cone","bucket","shield","imp","berserker","giant","football","dancer"]
	for index in routes.entries.size():
		var points: PackedVector2Array = routes.entries[index].points
		var valid = sim.defense_spawner.ground_clear(points[0]) and points[-1].is_equal_approx(routes.EXIT)
		for j in points.size()-1: valid = valid and sim.arena.clear(points[j],points[j+1])
		check.call(valid,"Fixed forest lane %d clears every obstacle and ends outside the forest" % index)
		for kind in kinds:
			sim.zombies.clear()
			sim.paths.clear()
			sim.crowd_buckets.clear()
			sim.spawn(points[0],kind)
			var z: Dictionary = sim.zombies[-1]
			var safe = routes.active(z) and z.forest_route == index
			for tick in 1200:
				if not routes.follow(sim,z,4.9,.05): break
				safe = safe and sim.arena.clear(z.pos,z.pos)
			check.call(safe and not routes.active(z) and z.pos.distance_to(routes.EXIT) <= .021,"Lane %d carries %s safely to normal-AI handoff" % [index,kind])
	# Different targets cannot pull an undisturbed enemy into an ad-hoc forest path.
	sim.zombies.clear()
	sim.spawn(routes.entries[0].points[0],"normal")
	var z: Dictionary = sim.zombies[-1]
	var origin: Vector2 = z.pos
	var waypoint: Vector2 = routes.entries[0].points[1]
	var direction: Vector2 = (waypoint-origin).normalized()
	sim.update_zombie(z,{"id":"crystal","pos":Vector2(40,17),"height":3.0,"hp":3000,"is_crystal":true},.1)
	check.call(z.pos.distance_to(origin+direction*.1*z.chase_speed) < .001 and sim.paths.is_empty(),"Forest movement follows its assigned lane instead of the selected combat target or A*")
	# A physical shove must rejoin, not teleport or disable collision checks.
	z.pos = origin+direction*1.5+Vector2(-direction.y,direction.x)*.5
	if not sim.arena.clear(z.pos,z.pos): z.pos = origin+direction*1.5-Vector2(-direction.y,direction.x)*.5
	var safe = sim.arena.clear(z.pos,z.pos)
	for tick in 100:
		sim.elapsed += .05
		var before: Vector2 = z.pos
		routes.follow(sim,z,4.9,.05)
		safe = safe and sim.arena.clear(before,z.pos) and before.distance_to(z.pos) <= .246
		if Geometry2D.get_closest_point_to_segment(z.pos,origin,waypoint).distance_to(z.pos) <= .02: break
	check.call(safe and routes.active(z) and Geometry2D.get_closest_point_to_segment(z.pos,origin,waypoint).distance_to(z.pos) <= .02,"Displaced enemy rejoins its original lane without teleporting through scenery")
	# Same-lane spacing is longitudinal; no lateral detour into foliage.
	sim.zombies.clear()
	sim.crowd_buckets.clear()
	sim.spawn(origin,"normal")
	sim.spawn(origin,"giant")
	var rear: Dictionary = sim.zombies[0]
	var front: Dictionary = sim.zombies[1]
	front.pos = origin+direction*2.0
	for enemy in sim.zombies:
		var cell = Vector2i(floori(enemy.pos.x/3),floori(enemy.pos.y/3))
		if not sim.crowd_buckets.has(cell): sim.crowd_buckets[cell] = []
		sim.crowd_buckets[cell].append(enemy)
	routes.follow(sim,rear,50,.1)
	check.call(rear.pos.distance_to(front.pos) >= 1.499 and Geometry2D.get_closest_point_to_segment(rear.pos,origin,waypoint).distance_to(rear.pos) < .001,"Shared lane keeps headway behind a giant without sidestepping")
	var snapshot = sim.snapshot()
	check.call(snapshot.zombies[0].forest_route == rear.forest_route and snapshot.zombies[0].forest_waypoint == rear.forest_waypoint,"Authority snapshot retains lane progress for cooperative rendering")
	sim.zombies.clear()
	sim.crowd_buckets.clear()
	sim.spawn(origin,"normal")
	z = sim.zombies[-1]
	var player: Dictionary = sim.pawns.solo
	player.pos = origin+direction*.7
	player.height = 0.0
	sim.update_zombie(z,player,.1)
	check.call(z.attack_time > 0 and routes.active(z),"Nearby player still triggers melee while woodland lane progress is retained")
	sim.zombies.clear()
	sim.spawn(origin,"dancer")
	var boss: Dictionary = sim.zombies[-1]
	boss.summon_clock = 100.0
	boss.summon_roster = ["bucket"]
	preload("res://scripts/dancer_boss.gd").step(sim,.1)
	check.call(sim.zombies.size() == 2 and sim.zombies[-1].get("forest_route",-1) == boss.forest_route and sim.zombies[-1].get("forest_waypoint",-1) == boss.forest_waypoint,"Boss guards summoned in woodland inherit its lane and safely rejoin after emerging")
	sim.dispose()
