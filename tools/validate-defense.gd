extends SceneTree
## Headless acceptance for the defense map, lever gate, weapon zone and crystal target.
var checks = 0
var failures = 0
var game

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)

func command(weapon := 0, interact := false) -> Dictionary:
	return {"x":0.0,"y":0.0,"yaw":0.0,"pitch":0.0,"weapon":weapon,"interact":interact,"heal":false,"crouch":false,"jump":false,"reload":false,"fire":false,"aim":false,"shove":false}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var data = root.get_node("Data")
	data.settings.map_id = "graypine_defense"
	var scene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	check(game.arena.map_id == "graypine_defense","Defense map loads as an authored scene")
	check(game.arena.obstacles.size() >= 5,"Chasm, ramp shelves and rear safe zone participate in navigation")
	check(not game.arena.clear(Vector2(12,-70),Vector2(12,0)),"Chasm prevents routes that bypass the bridge")
	check(not game.arena.clear(Vector2(12,-20),Vector2(12,0)),"Ramp-side shelves cannot bypass the central climb")
	check(not game.arena.clear(Vector2(0,50),Vector2(0,60)),"Zombies cannot enter the rear loadout safe zone")
	check(game.arena.clear(Vector2(0,-70),Vector2(0,44)),"Bridge and ramp form one open approach lane")
	var bridge_hit: Dictionary = game.arena.surface_hit(Vector3(0,5,-45),Vector3(0,-10,-45))
	var bridge_rail_hit: Dictionary = game.arena.surface_hit(Vector3(0,.72,-45),Vector3(5,.72,-45))
	var ramp_hit: Dictionary = game.arena.surface_hit(Vector3(0,8,-19),Vector3(0,-5,-19))
	var shelf_hit: Dictionary = game.arena.surface_hit(Vector3(12,5,-19),Vector3(12,-5,-19))
	var ramp_fill_hit: Dictionary = game.arena.surface_hit(Vector3(7,.55,-18),Vector3(0,.55,-18))
	var ramp_seam_hit: Dictionary = game.arena.surface_hit(Vector3(5.48,2,-27.5),Vector3(5.48,-2,-27.5))
	var plateau_hit: Dictionary = game.arena.surface_hit(Vector3(0,8,20),Vector3(0,-5,20))
	check(not bridge_hit.is_empty() and absf(bridge_hit.position.y) < .1,"Suspension bridge has a native walkable deck")
	check(not bridge_rail_hit.is_empty() and absf(bridge_rail_hit.position.x) > 3.6,"Bridge has continuous physical guard rails")
	check(not ramp_hit.is_empty() and ramp_hit.position.y > 1 and ramp_hit.position.y < 2,"Approach includes a physical rising ramp")
	check(not shelf_hit.is_empty() and absf(shelf_hit.position.y) < .1,"Ramp sides provide low physical fall-catching shelves")
	check(not ramp_fill_hit.is_empty() and ramp_fill_hit.position.x > 5.3,"Ramp underside is a solid physical wedge")
	check(not ramp_seam_hit.is_empty() and ramp_seam_hit.position.y > -.1,"Ramp fill closes the seam beside the lower rail")
	check(not plateau_hit.is_empty() and absf(plateau_hit.position.y-3) < .1,"Crystal stands at the end of the raised flat ground")
	var environment_features = game.arena.scenery.find_children("*","Node3D",true,false)
	var boulder_count = environment_features.filter(func(node): return node.get_meta("environment_feature","") == "boulder").size()
	var vegetation_count = environment_features.filter(func(node): return node.get_meta("environment_feature","") == "vegetation").size()
	var perimeter_count = environment_features.filter(func(node): return node.get_meta("environment_feature","") == "perimeter_wall").size()
	check(boulder_count >= 10,"Defense field has authored natural rock cover")
	check(vegetation_count >= 20,"Defense terrain has distributed vegetation detail")
	check(perimeter_count == 6,"All outer edges except the two chasm-side runs have physical perimeter walls")
	check(game.arena.clear(Vector2(0,-70),Vector2(0,44)),"Environmental cover preserves the central bridge, ramp and field lane")
	var weapon_displays = game.arena.scenery.find_children("WeaponDisplay*","Node3D",true,false)
	check(weapon_displays.size() == data.weapons.size(),"Safe zone displays every selectable weapon on the physical wall")
	var shop_walls = game.arena.scenery.find_children("WeaponShopWall","StaticBody3D",true,false)
	check(shop_walls.size() == 1,"Safe zone uses one continuous physical shop wall")
	var shop_shape = shop_walls[0].find_children("*","CollisionShape3D",true,false)[0] as CollisionShape3D
	check(shop_shape and shop_shape.shape is BoxShape3D and shop_shape.shape.size.y >= 8.8,"Weapon shop wall is at least twice its previous height")
	var weapon_mounts: Array = weapon_displays.map(func(node): return Vector2(float(node.get_meta("mount_x")),float(node.get_meta("mount_height"))))
	weapon_mounts.sort_custom(func(a,b): return a.x < b.x)
	var separated = true
	for index in range(1,weapon_mounts.size()): separated = separated and weapon_mounts[index].x-weapon_mounts[index-1].x >= 2.39
	check(separated,"Weapon displays leave a generous horizontal gap between adjacent guns")
	var standing_eye = data.Maps.Defense.height(Vector2(0,60))+preload("res://scripts/player_body.gd").eye_height({"crouch":0.0})
	check(weapon_mounts.all(func(point): return point.y <= standing_eye),"Every weapon is reachable at standing eye height without jumping")
	check(game.arena.scenery.find_children("WeaponRack*","StaticBody3D",true,false).is_empty(),"Safe zone no longer uses five separate rack walls")

	game.start_solo("defense")
	await physics_frame
	var sim = game.sim
	var pawn: Dictionary = sim.pawns.solo
	check(sim.mode == "defense" and not sim.defense.started,"Entering the map does not start waves")
	for i in 10:
		sim.submit("solo",command(1))
		sim.step(.05)
	check(sim.elapsed == 0 and sim.spawned == 0 and sim.zombies.is_empty(),"Waiting before the lever keeps timer and spawns stopped")
	check(pawn.weapon == 1,"Any primary weapon can be selected inside the rear safe zone")
	pawn.pos = Vector2(6,49)
	for i in 10:
		sim.submit("solo",command(2))
		sim.step(.05)
	check(pawn.weapon == 1,"Weapon switching is locked outside the safe zone")
	sim.submit("solo",command(1,true))
	sim.step(.02)
	check(sim.defense.started and not sim.roster.is_empty(),"Pulling the crystal-side lever prepares wave one")

	# Isolate target choice from the wave spawner: the closest valid unit must take the hit.
	sim.roster.clear()
	sim.zombies.clear()
	pawn.pos = Vector2(0,60)
	pawn.hp = 100
	var crystal_before: int = sim.defense.crystal_hp
	sim.spawn(Vector2(0,44.9),"normal")
	for i in 4: sim.step(.4)
	check(sim.defense.crystal_hp < crystal_before and pawn.hp == 100,"A zombie beside the crystal attacks the crystal instead of a distant player")
	sim.zombies.clear()
	pawn.pos = Vector2(0,50)
	pawn.hp = 100
	crystal_before = sim.defense.crystal_hp
	sim.spawn(Vector2(0,48.9),"normal")
	for i in 4: sim.step(.4)
	check(pawn.hp < 100 and sim.defense.crystal_hp == crystal_before,"A zombie beside the player attacks the player instead of the farther crystal")

	# Imps ignore even a point-blank player and continue toward the crystal.
	sim.zombies.clear()
	pawn.pos = Vector2(0,50)
	pawn.hp = 100
	pawn.protection = 0.0
	sim.spawn(Vector2(0,49.5),"imp")
	var imp: Dictionary = sim.zombies[-1]
	var chosen: Dictionary = sim.choose_zombie_target(imp,[pawn])
	check(chosen.get("is_crystal",false),"Imp target selection is locked to the crystal")
	for i in 5: sim.step(.2)
	check(pawn.hp == 100 and imp.pos.y < 49.0,"An imp beside the player does not attack or chase the player")

	# Falling is recoverable but costs health; regeneration starts only after the
	# full five-second combat delay and advances in one-point-per-second ticks.
	sim.zombies.clear()
	pawn.pos = Vector2(14,-45)
	pawn.height = -6.0
	pawn.hp = 100
	pawn.protection = 0.0
	sim.step(.02)
	check(pawn.pos.distance_to(Data.Maps.Defense.FALL_RETURN) < .01 and pawn.hp == 90 and absf(pawn.height-3.0) < .01,"Falling returns the player beside the crystal and removes ten health")
	for i in 99: sim.update_pawn(pawn,.05)
	check(pawn.hp == 90,"Defense regeneration waits five seconds after combat")
	for i in 21: sim.update_pawn(pawn,.05)
	check(pawn.hp == 91,"Defense regeneration restores one health per second")

	# Stress crowd separation on both narrow sections without attack handling.
	# Every displacement still has to pass arena.clear, so overlap pressure cannot
	# push a zombie onto the chasm or the non-route side shelves.
	sim.zombies.clear()
	sim.paths.clear()
	for i in 12:
		sim.spawn(Vector2(-2.4+(i%4)*1.6,-60+(i/4)*.75),"normal")
	for i in 12:
		sim.spawn(Vector2(-3.6+(i%4)*2.4,-26+(i/4)*.75),"normal")
	var crowd_safe = true
	for tick in 500:
		sim.elapsed += .05
		sim.crowd_buckets.clear()
		for z in sim.zombies:
			var key = Vector2i(floori(z.pos.x/3),floori(z.pos.y/3))
			if not sim.crowd_buckets.has(key): sim.crowd_buckets[key] = []
			sim.crowd_buckets[key].append(z)
		for z in sim.zombies:
			var distance: float = z.pos.distance_to(Data.Maps.Defense.CRYSTAL)
			sim.move_zombie(z,Data.Maps.Defense.CRYSTAL,4.9,.05,distance,data.contact(z.kind))
			if not game.arena.clear(z.pos,z.pos): crowd_safe = false
	check(crowd_safe,"Crowd separation cannot push zombies off the bridge or around the ramp")

	# Exact point budgets replace fixed body counts. A crawler remains a
	# one-point normal-body variant, so its conversion never changes spending.
	var population = preload("res://scripts/defense_population.gd")
	var shared_population = preload("res://scripts/night_population.gd")
	sim.wave = 1
	sim.random.seed = 481516
	var exact_sample_budgets = true
	for sample in 200:
		sim.prepare_wave()
		exact_sample_budgets = exact_sample_budgets and shared_population.points(sim.roster) == population.budget(1,1)
	check(exact_sample_budgets,"Shared population rules preserve the exact point budget")
	sim.defense_ordinary_slots = 0
	var variants: Array = []
	for slot in 20: variants.append(sim.defense_population_kind("normal"))
	check(variants.count("crawler") == 2 and variants[9] == "crawler" and variants[19] == "crawler","Defense uses the Night rule of every tenth ordinary zombie becoming a crawler")
	var exact_wave_budgets = true
	var exact_football_counts = true
	var shared_rosters = true
	for current_wave in range(1,11):
		var defense_random = RandomNumberGenerator.new()
		var night_random = RandomNumberGenerator.new()
		defense_random.seed = 1000+current_wave
		night_random.seed = defense_random.seed
		var defense_roster: Array = population.roster(current_wave,1,defense_random)
		var ordinary_roster: Array = defense_roster.filter(func(kind): return kind != "football")
		var night_roster: Array = shared_population.roster(population.budget(current_wave,1),population.kinds(current_wave),night_random)
		exact_wave_budgets = exact_wave_budgets and shared_population.points(defense_roster) == population.budget(current_wave,1)
		exact_football_counts = exact_football_counts and defense_roster.count("football") == population.footballs(current_wave)
		shared_rosters = shared_rosters and ordinary_roster == night_roster
	check(exact_wave_budgets,"All ten waves spend their exact point budgets")
	check(exact_football_counts,"Waves seven and eight have one football; waves nine and ten have two")
	check(shared_rosters,"Defense ordinary rosters are generated by the Night point algorithm")
	check(not shared_population.COST.has("football"),"Authored football zombies have no point cost")
	check(population.budget(10,2) == roundi(population.budget(10,1)*1.2) and population.budget(10,4) == roundi(population.budget(10,1)*1.6),"Defense uses the Night multiplayer budget multipliers")

	var fixed_health = true
	for kind in data.enemies:
		sim.zombies.clear()
		sim.wave = 1
		sim.spawn(Vector2(0,-70),kind)
		var wave_one_hp: float = sim.zombies[-1].hp
		sim.zombies.clear()
		sim.wave = 10
		sim.spawn(Vector2(0,-70),kind)
		fixed_health = fixed_health and is_equal_approx(wave_one_hp,float(data.enemies[kind].health)) and is_equal_approx(sim.zombies[-1].hp,wave_one_hp)
	check(fixed_health,"Every enemy keeps its resource health through wave ten")
	pawn.hp = 100
	pawn.protection = 0.0
	var damage_zombie: Dictionary = sim.zombies[-1]
	pawn.pos = damage_zombie.pos
	pawn.height = data.enemy_ground_height(pawn.pos,sim.map_id)
	sim.damage_target(pawn,damage_zombie,10)
	var before_shared_damage: int = sim.defense.crystal_hp
	sim.damage_target(sim.crystal_target(),damage_zombie,10)
	check(pawn.hp == 90 and sim.defense.crystal_hp == before_shared_damage-10,"Defense uses Night's unscaled ten-point melee damage for players and crystal")
	before_shared_damage = sim.defense.crystal_hp
	sim.damage_target(sim.crystal_target(),damage_zombie,sim.CHARGE_DAMAGE)
	check(sim.defense.crystal_hp == before_shared_damage-30,"Football charge deals the same unscaled thirty damage as Night")
	sim.zombies.clear()
	sim.roster.clear()
	sim.cleared = 9
	sim.rest = 0
	sim.step(.02)
	check(sim.won and sim.cleared == 10,"Clearing wave ten completes the defense")

	# Failure is driven by non-recoverable crystal health, independent of player health.
	game.start_solo("defense")
	await physics_frame
	sim = game.sim
	pawn = sim.pawns.solo
	pawn.pos = Vector2(6,49)
	sim.submit("solo",command(0,true))
	sim.step(.02)
	sim.damage_crystal({"id":77},Data.Maps.Defense.CRYSTAL_MAX_HP)
	sim.step(.02)
	check(sim.failed and sim.cause == "crystal" and sim.defense.crystal_hp == 0,"Destroying the fixed-health crystal ends the game in failure")

	print("DEFENSE VALIDATION: %d checks; %d failures" % [checks,failures])
	game.queue_free()
	quit(1 if failures else 0)
