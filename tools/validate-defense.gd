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

func command(weapon := 0, interact := false, slot := 1, yaw := 0.0, pitch := 0.0, fire := false) -> Dictionary:
	return {"x":0.0,"y":0.0,"yaw":yaw,"pitch":pitch,"weapon":weapon,"slot":slot,"interact":interact,"heal":false,"crouch":false,"jump":false,"reload":false,"fire":fire,"use_self":fire,"use_other":false,"aim":false,"shove":false}

func interact_with(sim, pawn: Dictionary, point: Vector3, id := "solo") -> void:
	pawn.pos = Vector2(point.x,point.z-1.65)
	pawn.height = root.get_node("Data").Maps.Defense.height(pawn.pos)
	var eye_y: float = pawn.height+preload("res://scripts/player_body.gd").eye_height(pawn)
	var pitch := atan2(point.y-eye_y,1.65)
	for i in 5:
		sim.submit(id,command(int(pawn.weapon),true,int(pawn.slot),PI,pitch))
		sim.step(.1)
	sim.submit(id,command(int(pawn.weapon),false,int(pawn.slot),PI,pitch))
	sim.step(.02)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var data = root.get_node("Data")
	data.settings.map_id = "graypine_defense"
	data.settings.defense_difficulty = "easy"
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
	check(game.arena.clear(Vector2(0,-70),Vector2(0,42.7)),"Bridge and ramp form one open approach lane")
	check(not game.arena.clear(Vector2(0,42.7),data.Maps.Defense.CRYSTAL),"Crystal pedestal blocks enemy navigation")
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
	check(game.arena.clear(Vector2(0,-70),Vector2(0,42.7)),"Environmental cover preserves the central bridge, ramp and field lane")
	var weapon_displays = game.arena.scenery.find_children("WeaponDisplay*","Node3D",true,false)
	var primary_weapon_indices := [0,1,4,5,7,8,9]
	check(weapon_displays.size() == primary_weapon_indices.size(),"Safe zone displays exactly the seven primary weapons")
	var displayed_weapon_indices: Array = weapon_displays.map(func(node): return int(node.get_meta("weapon_display_index")))
	displayed_weapon_indices.sort()
	check(displayed_weapon_indices == primary_weapon_indices,"Armory wall excludes always-carried sidearms and melee weapon")
	var shop_walls = game.arena.scenery.find_children("WeaponShopWall","StaticBody3D",true,false)
	check(shop_walls.size() == 1,"Safe zone uses one continuous physical shop wall")
	var shop_shape = shop_walls[0].find_children("*","CollisionShape3D",true,false)[0] as CollisionShape3D
	check(shop_shape and shop_shape.shape is BoxShape3D and shop_shape.shape.size.y >= 8.8,"Weapon shop wall is at least twice its previous height")
	var weapon_mounts: Array = weapon_displays.map(func(node): return Vector2(float(node.get_meta("mount_x")),float(node.get_meta("mount_height"))))
	var columns: Array = []
	for point in weapon_mounts:
		if not columns.has(point.x): columns.append(point.x)
	columns.sort()
	var separated = true
	for index in range(1,columns.size()): separated = separated and columns[index]-columns[index-1] >= 4.79
	check(columns.size() == 4 and separated,"Weapon displays use four generously spaced columns")
	check(columns.all(func(x): return weapon_mounts.filter(func(point): return point.x == x).size() in [1,2]) and weapon_mounts.map(func(point): return point.y).min() < weapon_mounts.map(func(point): return point.y).max(),"Primary weapons use two rows per column")
	var standing_eye = data.Maps.Defense.height(Vector2(0,60))+preload("res://scripts/player_body.gd").eye_height({"crouch":0.0})
	check(weapon_mounts.all(func(point): return point.y <= standing_eye+1.0),"Every weapon is reachable while standing without jumping")
	check(game.arena.scenery.find_children("WeaponRack*","StaticBody3D",true,false).is_empty(),"Safe zone no longer uses five separate rack walls")

	game.start_solo("defense")
	await physics_frame
	var sim = game.sim
	var pawn: Dictionary = sim.pawns.solo
	check(sim.mode == "defense" and not sim.defense.started,"Entering the map does not start waves")
	check(sim.defense.difficulty == "easy" and is_equal_approx(sim.defense.difficulty_multiplier,.7),"Defense validation runs the Easy difficulty selected before the match")
	check(pawn.primary == 0 and pawn.secondary == 3 and pawn.slot == 1,"Defense starts with primary, sidearm and melee equipment slots")
	check(pawn.medkits == 1 and pawn.grenades == 0,"Defense initializes Night's medical and grenade inventory")
	check(pawn.reserves[pawn.primary] == data.defense_full_reserve(pawn.primary) and pawn.reserves[pawn.secondary] == data.defense_full_reserve(pawn.secondary),"Defense firearms start with seventeen reserve magazines")
	var prestart_shoves: int = pawn.shoves
	var shove_command: Dictionary = command()
	shove_command.shove = true
	sim.submit("solo",shove_command)
	sim.step(.05)
	check(pawn.shoves == prestart_shoves+1 and not sim.defense.started,"Shove works before pulling the defense lever")
	sim.submit("solo",command())
	sim.step(.35)
	var prestart_shots: int = pawn.shots
	var prestart_ammo: int = pawn.ammo[pawn.primary]
	sim.submit("solo",command(0,false,1,pawn.yaw,pawn.pitch,true))
	sim.step(.05)
	check(pawn.shots == prestart_shots+1 and pawn.ammo[pawn.primary] == prestart_ammo-1 and not sim.defense.started,"Rifle fires and consumes ammunition before pulling the defense lever")
	sim.submit("solo",command())
	sim.step(.15)
	var reserve_before_auto_reload: int = pawn.reserves[pawn.primary]
	pawn.ammo[pawn.primary] = 0
	sim.update_arsenal(pawn,command(pawn.primary),.01)
	check(pawn.reloading,"An empty firearm automatically starts reloading without an R input")
	sim.update_arsenal(pawn,command(pawn.primary),float(data.weapons[pawn.primary].reloadDuration)+.01)
	check(pawn.ammo[pawn.primary] == data.weapons[pawn.primary].capacity and pawn.reserves[pawn.primary] == reserve_before_auto_reload-data.weapons[pawn.primary].capacity,"Automatic reload transfers one full magazine from the finite reserve")
	check(sim.defense.grenade_slots.size() == 1 and sim.defense.medkit_slots.size() == 1,"Solo armory creates one independent grenade and medical slot")
	for i in 10:
		sim.submit("solo",command(0,false,2))
		sim.step(.05)
	check(sim.elapsed == 0 and sim.spawned == 0 and sim.zombies.is_empty(),"Waiting before the lever keeps timer and spawns stopped")
	check(pawn.weapon == pawn.secondary and pawn.slot == 2,"Defense uses Night's secondary-weapon slot switching")
	interact_with(sim,pawn,data.Maps.Defense.weapon_mount(0))
	check(pawn.primary == 0 and pawn.weapon == 0 and pawn.ammo[0] == data.weapons[0].capacity and pawn.reserves[0] == data.defense_full_reserve(0),"Interacting with a wall weapon replaces and fully restocks the primary weapon")
	check(game.arena.scenery.find_children("WeaponDisplay*","Node3D",true,false).size() == primary_weapon_indices.size(),"A replacement copy appears immediately after a wall weapon pickup")
	var grenade_clock: float = sim.defense.prop_clock
	interact_with(sim,pawn,data.Maps.Defense.GRENADE_MOUNTS[0])
	check(pawn.grenades == 1 and sim.defense.grenade_slots[0].ready_at >= grenade_clock+30.0,"Grenade pickup starts its own thirty-second refill cooldown")
	pawn.medkits = 0
	var medkit_clock: float = sim.defense.prop_clock
	interact_with(sim,pawn,data.Maps.Defense.MEDKIT_MOUNTS[0])
	check(pawn.medkits == 1 and sim.defense.medkit_slots[0].ready_at >= medkit_clock+30.0,"Medical pickup starts its own thirty-second refill cooldown")
	pawn.pos = Vector2(6,49)
	pawn.height = data.Maps.Defense.height(pawn.pos)
	interact_with(sim,pawn,Vector3(data.Maps.Defense.LEVER.x,pawn.height+1.1,data.Maps.Defense.LEVER.y))
	check(sim.defense.started and sim.rest > 4.0 and sim.roster.is_empty(),"Pulling the lever starts a five-second preparation countdown before wave one")
	for i in 52:
		sim.submit("solo",command(int(pawn.weapon),false,int(pawn.slot)))
		sim.step(.1)
	check(sim.wave == 1 and sim.rest == 0 and not sim.roster.is_empty(),"Wave one starts after the countdown without being skipped")
	var grenades_before: int = pawn.grenades
	sim.submit("solo",command(int(pawn.weapon),false,4,pawn.yaw,pawn.pitch,true))
	sim.step(.05)
	check(pawn.grenades == grenades_before-1 and sim.defense.projectiles.size() == 1,"Defense uses Night's grenade slot and authoritative projectile logic")
	pawn.hp = 50
	pawn.combat_timer = 100.0
	sim.submit("solo",command(int(pawn.weapon),false,5,pawn.yaw,pawn.pitch,true))
	sim.step(.05)
	for i in 62:
		sim.submit("solo",command(int(pawn.weapon),false,5,pawn.yaw,pawn.pitch,false))
		sim.step(.05)
	check(pawn.hp == 100 and pawn.medkits == 0,"Defense uses Night's three-second medical treatment logic")
	sim.roster.clear()
	sim.zombies.clear()
	sim.step(.02)
	check(sim.cleared == 1 and sim.rest > 4.9 and sim.defense.wave == 2 and sim.defense.countdown > 4.9,"Every later wave also receives a five-second preparation countdown")

	# Isolate target choice from the wave spawner: the closest valid unit must take the hit.
	sim.roster.clear()
	sim.zombies.clear()
	pawn.pos = Vector2(0,60)
	pawn.hp = 100
	var crystal_before: int = sim.defense.crystal_hp
	sim.spawn(Vector2(0,42.7),"normal")
	for i in 4: sim.step(.4)
	check(sim.defense.crystal_hp < crystal_before and pawn.hp == 100,"A zombie beside the crystal attacks the crystal instead of a distant player")
	check(sim.zombies[0].pos.y <= 42.95,"Crystal attacker stays outside the pedestal")
	sim.zombies.clear()
	crystal_before = sim.defense.crystal_hp
	sim.spawn(Vector2(0,40),"crawler")
	for i in 35: sim.step(.1)
	var crawler: Dictionary = sim.zombies[0]
	check(crawler.pos.y <= 42.95 and game.arena.clear(crawler.pos,crawler.pos),"Crawler remains outside the crystal pedestal")
	check(sim.defense.crystal_hp < crystal_before,"Crawler can strike the crystal from outside its pedestal")
	var shot_origin := Vector3(0,4.6,39)
	var crawler_hittable := false
	for aim_step in 8:
		var aim := Vector3(crawler.pos.x,3.2+aim_step*.1,crawler.pos.y)
		var ray := (aim-shot_origin).normalized()
		var hit: Dictionary = load("res://scripts/enemy_view.gd").hit(crawler,shot_origin,ray,8,sim.elapsed,false)
		if not hit.is_empty() and game.arena.surface_hit(shot_origin,shot_origin+ray*hit.distance).is_empty(): crawler_hittable = true
	check(crawler_hittable,"Approach-lane shots can hit a crawler beside the crystal")
	sim.zombies.clear()
	crystal_before = sim.defense.crystal_hp
	sim.spawn(Vector2(4,42),"normal")
	for i in 45: sim.step(.1)
	check(sim.defense.crystal_hp < crystal_before and game.arena.clear(sim.zombies[0].pos,sim.zombies[0].pos),"Diagonal attackers reach a pedestal face and damage the crystal")
	sim.zombies.clear()
	pawn.pos = Vector2(0,50)
	pawn.hp = 100
	crystal_before = sim.defense.crystal_hp
	sim.spawn(Vector2(0,48.9),"normal")
	for i in 4: sim.step(.4)
	check(pawn.hp < 100 and sim.defense.crystal_hp == crystal_before,"A zombie beside the player attacks the player instead of the farther crystal")

	# Imps ignore even a point-blank player and continue toward the crystal.
	sim.zombies.clear()
	pawn.pos = Vector2(0,42.5)
	pawn.hp = 100
	pawn.protection = 0.0
	sim.spawn(Vector2(0,42.7),"imp")
	var imp: Dictionary = sim.zombies[-1]
	var chosen: Dictionary = sim.choose_zombie_target(imp,[pawn])
	check(chosen.get("is_crystal",false),"Imp target selection is locked to the crystal")
	for i in 5: sim.step(.2)
	check(pawn.hp == 100 and imp.pos.y <= 42.95,"An imp beside the player attacks the crystal from outside its pedestal")

	# Giants share the crystal-only target policy and their defense slam cannot
	# damage a player standing inside its otherwise shared area of effect.
	sim.zombies.clear()
	pawn.pos = Vector2(0,42.7)
	pawn.height = data.enemy_ground_height(pawn.pos,sim.map_id)
	pawn.hp = 100
	pawn.protection = 0.0
	crystal_before = sim.defense.crystal_hp
	sim.spawn(Vector2(0,42.7),"giant")
	var giant: Dictionary = sim.zombies[-1]
	chosen = sim.choose_zombie_target(giant,[pawn])
	check(chosen.get("is_crystal",false),"Giant target selection is locked to the crystal")
	for i in 5: sim.step(.2)
	check(pawn.hp == 100 and sim.defense.crystal_hp < crystal_before,"Defense giant attacks only the crystal even when its slam overlaps a player")

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
		exact_sample_budgets = exact_sample_budgets and shared_population.points(sim.roster) == population.budget(1,1,"easy")
	check(exact_sample_budgets,"Easy defense rosters preserve the exact reduced point budget")
	sim.defense_ordinary_slots = 0
	var variants: Array = []
	for slot in 20: variants.append(sim.defense_population_kind("normal"))
	check(variants.count("crawler") == 2 and variants[9] == "crawler" and variants[19] == "crawler","Defense uses the Night rule of every tenth ordinary zombie becoming a crawler")
	var exact_wave_budgets = true
	var exact_football_counts = true
	var shared_rosters = true
	for current_wave in range(1,data.Maps.Defense.MAX_WAVES+1):
		var defense_random = RandomNumberGenerator.new()
		var night_random = RandomNumberGenerator.new()
		defense_random.seed = 1000+current_wave
		night_random.seed = defense_random.seed
		var defense_roster: Array = population.roster(current_wave,1,defense_random,"easy")
		var ordinary_roster: Array = defense_roster.filter(func(kind): return kind != "football")
		var night_roster: Array = shared_population.roster(population.budget(current_wave,1,"easy"),population.kinds(current_wave),night_random)
		exact_wave_budgets = exact_wave_budgets and shared_population.points(defense_roster) == population.budget(current_wave,1,"easy")
		exact_football_counts = exact_football_counts and defense_roster.count("football") == population.footballs(current_wave,1)
		shared_rosters = shared_rosters and ordinary_roster == night_roster
	check(exact_wave_budgets,"All eight Easy waves spend their exact reduced point budgets")
	check(exact_football_counts,"Solo waves six and seven have one football; wave eight has two")
	check(shared_rosters,"Defense ordinary rosters are generated by the Night point algorithm")
	check(not shared_population.COST.has("football"),"Authored football zombies have no point cost")
	var expected_normal_budgets := [52,83,111,138,162,184,205,223]
	var actual_normal_budgets: Array = []
	var normal_rosters_spend_exactly := true
	for current_wave in range(1,data.Maps.Defense.MAX_WAVES+1):
		var wave_budget: int = population.budget(current_wave,1,"normal")
		actual_normal_budgets.append(wave_budget)
		var wave_roster: Array = population.roster(current_wave,1,RandomNumberGenerator.new(),"normal")
		normal_rosters_spend_exactly = normal_rosters_spend_exactly and shared_population.points(wave_roster) == wave_budget
	check(data.Maps.Defense.MAX_WAVES == 8 and actual_normal_budgets == expected_normal_budgets and actual_normal_budgets.reduce(func(total, value): return total+value,0) == 1158 and normal_rosters_spend_exactly,"Normal defense uses the eight-wave 1158-point curve exactly")
	check(population.budget(8,2,"normal") == roundi(population.BASE_BUDGET[7]*1.2) and population.budget(8,4,"normal") == roundi(population.BASE_BUDGET[7]*1.6),"Normal difficulty preserves the existing multiplayer budget rules")
	var difficulty_budgets_are_scaled = true
	var multiplayer_footballs_are_scaled = true
	for party_size in range(1,5):
		for current_wave in range(1,data.Maps.Defense.MAX_WAVES+1):
			var normal_budget: int = population.normal_budget(current_wave,party_size)
			difficulty_budgets_are_scaled = difficulty_budgets_are_scaled and population.budget(current_wave,party_size,"normal") == normal_budget
			difficulty_budgets_are_scaled = difficulty_budgets_are_scaled and population.budget(current_wave,party_size,"easy") == roundi(normal_budget*.7)
			difficulty_budgets_are_scaled = difficulty_budgets_are_scaled and population.budget(current_wave,party_size,"hard") == roundi(normal_budget*1.3)
			var expected_footballs: int = party_size if current_wave in [6,7] else party_size*2 if current_wave == 8 else 0
			var coop_roster: Array = population.roster(current_wave,party_size,RandomNumberGenerator.new(),"normal")
			multiplayer_footballs_are_scaled = multiplayer_footballs_are_scaled and population.footballs(current_wave,party_size) == expected_footballs and coop_roster.count("football") == expected_footballs and shared_population.points(coop_roster) == normal_budget
	check(difficulty_budgets_are_scaled,"Difficulty changes only the final point budget by 70, 100 or 130 percent")
	check(multiplayer_footballs_are_scaled,"Waves six through eight scale football bosses with player count without spending points")

	var fixed_health = true
	for kind in data.enemies:
		sim.zombies.clear()
		sim.wave = 1
		sim.spawn(Vector2(0,-70),kind)
		var wave_one_hp: float = sim.zombies[-1].hp
		sim.zombies.clear()
		sim.wave = data.Maps.Defense.MAX_WAVES
		sim.spawn(Vector2(0,-70),kind)
		fixed_health = fixed_health and is_equal_approx(wave_one_hp,float(data.enemies[kind].health)) and is_equal_approx(sim.zombies[-1].hp,wave_one_hp)
	check(fixed_health,"Every enemy keeps its resource health through the final wave")
	check(shared_population.COST.shield == 6,"Shield zombies consume six threat points")
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
	sim.wave = data.Maps.Defense.MAX_WAVES
	sim.cleared = data.Maps.Defense.MAX_WAVES-1
	sim.rest = 0
	sim.step(.02)
	check(sim.won and sim.cleared == data.Maps.Defense.MAX_WAVES,"Clearing wave eight completes the defense")

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
	sim.add_pawn("two","二号",1)
	sim.defense.party = sim.pawns.size()
	sim.defense_director.equipment.initialize()
	check(sim.defense.grenade_slots.size() == 2 and sim.defense.medkit_slots.size() == 2,"Coop armory creates one grenade and medical slot per player")
	var coop_pawn: Dictionary = sim.pawns.solo
	var coop_mount: Vector3 = data.Maps.Defense.GRENADE_MOUNTS[0]
	coop_pawn.pos = Vector2(coop_mount.x,coop_mount.z-1.65)
	coop_pawn.height = data.Maps.Defense.height(coop_pawn.pos)
	coop_pawn.yaw = PI
	coop_pawn.pitch = atan2(coop_mount.y-(coop_pawn.height+preload("res://scripts/player_body.gd").eye_height(coop_pawn)),1.65)
	check(sim.defense_director.equipment.pickup(coop_pawn,"grenade:0"),"A coop player can pick one authoritative grenade slot")
	check(sim.defense.grenade_slots[0].ready_at >= sim.defense.prop_clock+30 and sim.defense.grenade_slots[1].ready_at == 0,"Coop supply slots keep independent thirty-second cooldowns")

	print("DEFENSE VALIDATION: %d checks; %d failures" % [checks,failures])
	game.queue_free()
	quit(1 if failures else 0)
