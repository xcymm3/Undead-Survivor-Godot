extends SceneTree
## Headless acceptance for the defense map, ready gate, weapon zone and crystal target.
var checks = 0
var failures = 0
var game

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)

func valid_roster_budget(value: Array, budget: int) -> bool:
	return preload("res://scripts/enemy_population.gd").points(value) == budget

func command(weapon := 0, interact := false, slot := 1, yaw := 0.0, pitch := 0.0, fire := false) -> Dictionary:
	return {"x":0.0,"y":0.0,"yaw":yaw,"pitch":pitch,"weapon":weapon,"slot":slot,"interact":interact,"crouch":false,"jump":false,"reload":false,"fire":fire,"use_self":fire,"aim":false,"shove":false}

func interact_with(sim, pawn: Dictionary, point: Vector3, id := "solo") -> void:
	pawn.pos = Vector2(point.x-1.65,point.z)
	pawn.height = root.get_node("Data").Maps.Defense.height(pawn.pos)
	var eye_y: float = pawn.height+preload("res://scripts/player_body.gd").eye_height(pawn)
	var pitch := atan2(point.y-eye_y,1.65)
	for i in 5:
		sim.submit(id,command(int(pawn.weapon),true,int(pawn.slot),-PI/2,pitch))
		sim.step(.1)
	sim.submit(id,command(int(pawn.weapon),false,int(pawn.slot),-PI/2,pitch))
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
	var layout = data.Maps.Defense
	check(is_equal_approx(layout.PLATEAU.size.y,82.0*2.0/3.0) and is_equal_approx(layout.BOUNDS.end.y,layout.PLATEAU.end.y),"Plateau and world boundary shorten to two thirds of the original length")
	check(layout.CRYSTAL == layout.PLATEAU.get_center(),"Crystal occupies the exact centre of the flat plateau")
	check(layout.SHOP_AREA.get_center().x == layout.CRYSTAL.x and layout.SPAWN.y < layout.BRIDGE.position.y and layout.CRYSTAL.y < layout.SHOP_AREA.position.y,"Spawn, bridge, crystal and shop follow the approach order")
	check(game.arena.obstacles.size() >= 5,"Chasm, ramp shelves and solid shop furniture participate in navigation")
	check(not game.arena.clear(Vector2(12,-70),Vector2(12,0)),"Chasm prevents routes that bypass the bridge")
	check(not game.arena.clear(Vector2(12,-20),Vector2(12,0)),"Ramp-side shelves cannot bypass the central climb")
	check(game.arena.clear(Vector2(0,layout.SHOP_AREA.position.y-2),layout.SHOP_AREA.get_center()),"Zombies can enter the shop through its central aisle")
	check(game.arena.clear(Vector2(0,-70),Vector2(0,data.Maps.Defense.CRYSTAL.y-3.299999999999997)),"Bridge and ramp form one open approach lane")
	check(not game.arena.clear(Vector2(0,data.Maps.Defense.CRYSTAL.y-3.299999999999997),data.Maps.Defense.CRYSTAL),"Crystal body blocks enemy navigation")
	check(game.arena.scenery.find_children("CrystalPedestal","*",true,false).is_empty(),"Crystal pedestal has been removed")
	check(game.arena.scenery.find_children("WaveLever","*",true,false).is_empty(),"Defense wave lever has been removed")
	var crystal_bodies = game.arena.scenery.find_children("CrystalBody","StaticBody3D",true,false)
	check(crystal_bodies.size() == 1 and crystal_bodies[0].find_children("*","CollisionShape3D",true,false).size() == 1,"Crystal has a native solid body")
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
	check(not plateau_hit.is_empty() and absf(plateau_hit.position.y-3) < .1,"Crystal stands at the centre of the shortened raised flat ground")
	var environment_features = game.arena.scenery.find_children("*","Node3D",true,false)
	var boulder_count = environment_features.filter(func(node): return node.get_meta("environment_feature","") == "boulder").size()
	var vegetation_count = environment_features.filter(func(node): return node.get_meta("environment_feature","") == "vegetation").size()
	var perimeter_count = environment_features.filter(func(node): return node.get_meta("environment_feature","") == "perimeter_wall").size()
	check(boulder_count >= 10,"Defense field has authored natural rock cover")
	check(vegetation_count >= 20,"Defense terrain has distributed vegetation detail")
	check(perimeter_count == 8,"Outer walls and both ramp-shelf cliff ends are physically enclosed")
	check(game.arena.clear(Vector2(0,-70),Vector2(0,data.Maps.Defense.CRYSTAL.y-3.299999999999997)),"Environmental cover preserves the central bridge, ramp and field lane")
	check(game.arena.scenery.find_children("WeaponDisplay*","Node3D",true,false).is_empty(),"Shop removes all free weapon racks")
	check(game.arena.scenery.has_node("PreparationWorld/Station_rifle") and game.arena.scenery.find_children("Label3D","Label3D",true,false).is_empty(),"Rear shop has physical display stations without persistent signs")
	var shop_walls = game.arena.scenery.find_children("WeaponShopWall","StaticBody3D",true,false)
	check(shop_walls.size() == 1 and shop_walls[0].position.x == 0 and is_equal_approx(shop_walls[0].position.z+.325,layout.PLATEAU.end.y),"Shop is centered and flush with the rear perimeter")

	game.start_solo("defense")
	game.sim.defense.erase("intro_elapsed") # Fixture starts after the narrative intro.
	await physics_frame
	var sim = game.sim
	var pawn: Dictionary = sim.pawns.solo
	check(sim.mode == "defense" and not sim.defense.started,"Entering the map does not start waves")
	check(sim.defense.difficulty == "normal" and is_equal_approx(sim.defense.difficulty_multiplier,1.0),"Defense always uses Normal difficulty despite a legacy Easy setting")
	check(pawn.weapon1 == 0 and pawn.weapon2 == 2 and pawn.slot == 1,"Defense starts with fixed rifle, pistol and axe slots")
	check(not pawn.has("medkits") and pawn.grenades == 1,"Medical inventory is absent and new players carry one grenade")
	check(pawn.reserves[pawn.weapon1] == data.defense_full_reserve(pawn.weapon1) and pawn.reserves[pawn.weapon2] == data.defense_full_reserve(pawn.weapon2),"Defense firearms start with seventeen reserve magazines")
	var prestart_shoves: int = pawn.shoves
	var shove_command: Dictionary = command()
	shove_command.shove = true
	sim.submit("solo",shove_command)
	sim.step(.05)
	check(pawn.shoves == prestart_shoves+1 and not sim.defense.started,"Shove works before starting defense")
	sim.submit("solo",command())
	sim.step(.35)
	var prestart_shots: int = pawn.shots
	var prestart_ammo: int = pawn.ammo[pawn.weapon1]
	sim.submit("solo",command(0,false,1,pawn.yaw,pawn.pitch,true))
	sim.step(.05)
	check(pawn.shots == prestart_shots+1 and pawn.ammo[pawn.weapon1] == prestart_ammo-1 and not sim.defense.started,"Rifle fires and consumes ammunition before starting defense")
	sim.submit("solo",command())
	sim.step(.15)
	var reserve_before_auto_reload: int = pawn.reserves[pawn.weapon1]
	pawn.ammo[pawn.weapon1] = 0
	sim.update_arsenal(pawn,command(pawn.weapon1),.01)
	check(pawn.reloading,"An empty firearm automatically starts reloading without an R input")
	sim.update_arsenal(pawn,command(pawn.weapon1),float(data.weapons[pawn.weapon1].reloadDuration)+.01)
	check(pawn.ammo[pawn.weapon1] == data.weapons[pawn.weapon1].capacity and pawn.reserves[pawn.weapon1] == reserve_before_auto_reload-data.weapons[pawn.weapon1].capacity,"Automatic reload transfers one full magazine from the finite reserve")
	check(not sim.defense.has("grenade_slots") and not sim.defense.has("medkit_slots"),"Armory contains no grenade or medical supplies")
	for i in 10:
		sim.submit("solo",command(0,false,2))
		sim.step(.05)
	check(sim.elapsed == 0 and sim.spawned == 0 and sim.zombies.is_empty(),"Preparation keeps timer and spawns stopped")
	check(pawn.weapon == pawn.weapon2 and pawn.slot == 2,"Defense uses weapon-slot-2 switching")
	check(not sim.shop_available(pawn),"Spawn at the bridge entrance is outside the shop")
	check(not sim.equipment.pickup(pawn,"weapon:5") and not sim.equipment.pickup(pawn,"weapon:7"),"Removed weapon racks cannot exchange the fixed loadout")
	check(pawn.weapon1 == 0 and pawn.weapon2 == 2,"Invalid pickups preserve fixed weapons")
	var fixture = preload("res://tools/preparation-fixture.gd")
	fixture.face(sim,pawn,"crystal")
	fixture.hold(sim,pawn,3.1)
	pawn.pos = Vector2(0,10)
	pawn.height = 3
	check(sim.defense.started and not sim.defense.waiting and sim.rest == 0 and not sim.roster.is_empty(),"Repairing the crystal starts wave one immediately without a countdown")
	check(sim.wave == 1 and sim.events.filter(func(event): return event.kind == "wave_start").size() == 1,"Crystal defense sounds one low horn when wave one begins")
	var grenades_before: int = pawn.grenades
	sim.submit("solo",command(int(pawn.weapon),false,4,pawn.yaw,pawn.pitch,true))
	sim.step(.05)
	check(pawn.grenades == grenades_before-1 and sim.defense.projectiles.size() == 1,"Defense uses shared grenade slot and authoritative projectile logic")
	var thrown: Dictionary = sim.defense.projectiles[0]
	var grenade_view: Node3D = game.arena.scenery.projectile_views.get(thrown.id)
	check(is_instance_valid(grenade_view) and grenade_view.position.distance_to(thrown.pos) < .001,"Thrown defense grenade has a world model at its projectile position")
	for i in 40:
		sim.submit("solo",command(int(pawn.weapon),false,1,pawn.yaw,pawn.pitch,false))
		sim.step(.05)
	check(sim.defense.projectiles.is_empty() and game.arena.scenery.projectile_views.is_empty(),"Exploded defense grenade removes its world model")
	sim.roster.clear()
	sim.zombies.clear()
	sim.step(.02)
	sim.step(10)
	check(sim.cleared == 1 and sim.rest == 0 and sim.wave == 2 and not sim.defense.waiting and sim.defense.ready_players.is_empty(),"Completed deployment automatically starts wave two")
	for i in 60: sim.step(.1)
	check(sim.wave == 2 and not sim.defense.waiting and sim.spawned > 0,"Wave two deploys automatically without further ready input")
	sim.submit("solo",{"wave_ready":true})
	sim.step(.02)
	sim.step(10)
	check(sim.wave == 2 and not sim.defense.waiting and not sim.events.any(func(event): return event.kind == "wave_start"),"Legacy ready input cannot restart an active wave")

	# Isolate target choice from the wave spawner: the closest valid unit must take the hit.
	sim.roster.clear()
	sim.zombies.clear()
	pawn.pos = data.Maps.Defense.SHOP_AREA.get_center()
	pawn.hp = 100
	var crystal_before: int = sim.defense.crystal_hp
	sim.spawn(Vector2(0,data.Maps.Defense.CRYSTAL.y-3.299999999999997),"normal")
	for i in 4: sim.step(.4)
	check(sim.defense.crystal_hp < crystal_before and pawn.hp == 100,"A zombie beside the crystal attacks the crystal instead of a distant player")
	check(sim.zombies[0].pos.y <= data.Maps.Defense.CRYSTAL.y-1.9500000000000028 and game.arena.clear(sim.zombies[0].pos,sim.zombies[0].pos),"Crystal attacker stays outside the solid crystal")
	sim.zombies.clear()
	crystal_before = sim.defense.crystal_hp
	sim.spawn(Vector2(0,data.Maps.Defense.CRYSTAL.y-6.0),"crawler")
	for i in 35: sim.step(.1)
	var crawler: Dictionary = sim.zombies[0]
	check(crawler.pos.y <= data.Maps.Defense.CRYSTAL.y-1.9500000000000028 and game.arena.clear(crawler.pos,crawler.pos),"Crawler remains outside the solid crystal")
	check(sim.defense.crystal_hp < crystal_before,"Crawler can strike the crystal without entering it")
	var shot_origin := Vector3(0,4.6,data.Maps.Defense.CRYSTAL.y-7.0)
	var crawler_hittable := false
	for aim_step in 8:
		var aim := Vector3(crawler.pos.x,3.2+aim_step*.1,crawler.pos.y)
		var ray := (aim-shot_origin).normalized()
		var hit: Dictionary = load("res://scripts/enemy_view.gd").hit(crawler,shot_origin,ray,8,sim.elapsed,false)
		if not hit.is_empty() and game.arena.surface_hit(shot_origin,shot_origin+ray*hit.distance).is_empty(): crawler_hittable = true
	check(crawler_hittable,"Approach-lane shots can hit a crawler beside the crystal")
	sim.zombies.clear()
	crystal_before = sim.defense.crystal_hp
	sim.spawn(Vector2(4,data.Maps.Defense.CRYSTAL.y-4.0),"normal")
	for i in 45: sim.step(.1)
	check(sim.defense.crystal_hp < crystal_before and game.arena.clear(sim.zombies[0].pos,sim.zombies[0].pos),"Diagonal attackers surround and damage the crystal")
	# Every enemy archetype must reach and damage the crystal from each open face.
	for kind in ["normal","crawler","cone","bucket","imp","shield","berserker","giant","football"]:
		for entry in [data.Maps.Defense.CRYSTAL+Vector2(0,-6),data.Maps.Defense.CRYSTAL+Vector2(-5,0),data.Maps.Defense.CRYSTAL+Vector2(5,0),data.Maps.Defense.CRYSTAL+Vector2(0,4),data.Maps.Defense.CRYSTAL+Vector2(-4,-4),data.Maps.Defense.CRYSTAL+Vector2(4,-4),data.Maps.Defense.CRYSTAL+Vector2(-4,4),data.Maps.Defense.CRYSTAL+Vector2(4,4)]:
			sim.zombies.clear()
			sim.paths.clear()
			sim.crowd_buckets.clear()
			sim.defense.crystal_hp = data.Maps.Defense.CRYSTAL_MAX_HP
			sim.spawn(entry,kind)
			for tick in 50:
				sim.elapsed += .1
				sim.update_zombie(sim.zombies[0],sim.crystal_target(),.1)
			var attacker: Dictionary = sim.zombies[0]
			var sight: Dictionary = game.arena.surface_hit(Vector3(attacker.pos.x,4.1,attacker.pos.y),Vector3(0,4.1,data.Maps.Defense.CRYSTAL.y+0.0))
			check(sim.defense.crystal_hp < data.Maps.Defense.CRYSTAL_MAX_HP and game.arena.clear(attacker.pos,attacker.pos),"Crystal attack reaches from %s with %s: pos=%s distance=%.2f attack=%.2f sight=%s" % [str(entry),kind,str(attacker.pos),attacker.pos.distance_to(data.Maps.Defense.CRYSTAL),attacker.attack_time,str(not sight.is_empty())])
	sim.zombies.clear()
	pawn.pos = Vector2(0,data.Maps.Defense.CRYSTAL.y+4.0)
	pawn.hp = 100
	crystal_before = sim.defense.crystal_hp
	sim.spawn(Vector2(0,data.Maps.Defense.CRYSTAL.y+2.8999999999999986),"normal")
	for i in 4: sim.step(.4)
	check(pawn.hp < 100 and sim.defense.crystal_hp == crystal_before,"A zombie beside the player attacks the player instead of the farther crystal")

	# Imps ignore even a point-blank player and continue toward the crystal.
	sim.zombies.clear()
	pawn.pos = Vector2(0,data.Maps.Defense.CRYSTAL.y-3.5)
	pawn.hp = 100
	pawn.protection = 0.0
	sim.spawn(Vector2(0,data.Maps.Defense.CRYSTAL.y-3.299999999999997),"imp")
	var imp: Dictionary = sim.zombies[-1]
	var chosen: Dictionary = sim.choose_zombie_target(imp,[pawn])
	check(chosen.get("is_crystal",false),"Imp target selection is locked to the crystal")
	for i in 5: sim.step(.2)
	check(pawn.hp == 100 and imp.pos.y <= data.Maps.Defense.CRYSTAL.y-1.9500000000000028,"An imp beside the player attacks from outside the crystal")

	# Giants share the crystal-only target policy and their defense slam cannot
	# damage a player standing inside its otherwise shared area of effect.
	sim.zombies.clear()
	pawn.pos = Vector2(0,data.Maps.Defense.CRYSTAL.y-3.299999999999997)
	pawn.height = data.enemy_ground_height(pawn.pos,sim.map_id)
	pawn.hp = 100
	pawn.protection = 0.0
	crystal_before = sim.defense.crystal_hp
	sim.spawn(Vector2(0,data.Maps.Defense.CRYSTAL.y-3.299999999999997),"giant")
	var giant: Dictionary = sim.zombies[-1]
	chosen = sim.choose_zombie_target(giant,[pawn])
	check(chosen.get("is_crystal",false),"Giant target selection is locked to the crystal")
	for i in 15: sim.step(.2)
	check(pawn.hp == 100 and sim.defense.crystal_hp < crystal_before,"Defense giant attacks only the crystal even when its slam overlaps a player")

	# Move the native player capsule into the crystal from both sides.
	sim.zombies.clear()
	pawn.pos = Vector2(0,data.Maps.Defense.CRYSTAL.y-4.0)
	pawn.height = 3.0
	var into_crystal = command(int(pawn.weapon))
	into_crystal.y = 1.0
	for i in 80:
		sim.submit("solo",into_crystal)
		sim.step(.05)
	check(pawn.pos.y > data.Maps.Defense.CRYSTAL.y-3.5 and pawn.pos.y < data.Maps.Defense.CRYSTAL.y-1.2000000000000028,"Player capsule stops at the crystal's near side")
	check(not game.arena.surface_hit(Vector3(0,4.1,data.Maps.Defense.CRYSTAL.y-4.0),Vector3(0,4.1,data.Maps.Defense.CRYSTAL.y+0.0)).is_empty(),"Native physics ray hits the crystal body")
	pawn.pos = Vector2(0,data.Maps.Defense.CRYSTAL.y+4.0)
	into_crystal.y = -1.0
	for i in 80:
		sim.submit("solo",into_crystal)
		sim.step(.05)
	check(pawn.pos.y < data.Maps.Defense.CRYSTAL.y+3.5 and pawn.pos.y > data.Maps.Defense.CRYSTAL.y+1.2000000000000028,"Player capsule stops at the crystal's far side")

	# The crystal occludes a player on its far side; enemies must keep the crystal target.
	sim.zombies.clear()
	pawn.pos = Vector2(0,data.Maps.Defense.CRYSTAL.y+1.3999999999999986)
	pawn.height = 3.0
	pawn.hp = 100
	pawn.protection = 0.0
	crystal_before = sim.defense.crystal_hp
	sim.spawn(Vector2(0,data.Maps.Defense.CRYSTAL.y-4.0),"normal")
	check(sim.choose_zombie_target(sim.zombies[0],[pawn]).get("is_crystal",false),"Crystal-side player does not steal an occluded zombie target")
	for i in 50: sim.step(.1)
	check(sim.defense.crystal_hp < crystal_before and pawn.hp == 100 and game.arena.clear(sim.zombies[0].pos,sim.zombies[0].pos),"Zombie continues attacking crystal while player stands behind it")

	# No baseline regeneration; the Strong talent enables delayed healing.
	sim.zombies.clear()
	pawn.pos = Vector2(14,-45)
	pawn.height = -6.0
	pawn.hp = 100
	pawn.protection = 0.0
	sim.step(.02)
	check(pawn.pos.distance_to(data.Maps.Defense.FALL_RETURN) < .01 and pawn.hp == 90 and absf(pawn.height-3.0) < .01,"Falling returns the player and removes ten health")
	for i in 20: sim.update_pawn(pawn,.05)
	check(pawn.hp == 90,"Players without Strong cannot regenerate after falling")
	sim.progression.data.talents.strong = 1
	pawn.max_hp = 110
	pawn.hp = 80
	sim.enter_combat(pawn)
	sim.update_defense_regen(pawn,5.0)
	check(pawn.hp == 80,"Strong waits five full seconds before healing")
	sim.update_defense_regen(pawn,1.0)
	check(pawn.hp == 81,"Rank-one Strong heals one health per second out of combat")
	var shots_before: int = pawn.shots
	for i in 80:
		sim.submit(pawn.id,command(int(pawn.weapon),false,int(pawn.slot),0.0,0.0,true))
		sim.update_pawn(pawn,.05)
	check(pawn.shots > shots_before and pawn.hp == 85,"Continuous live firing permits Strong healing without incoming damage")
	pawn.regen_credit = .75
	pawn.protection = 0.0
	var hurt_hp: int = pawn.hp
	check(sim.damage_pawn(pawn,{"pos":pawn.pos+Vector2(0,1),"id":99},10),"Regeneration regression applies real enemy damage")
	sim.update_defense_regen(pawn,.25)
	check(pawn.hp == hurt_hp-10 and pawn.regen_credit == 0,"Damage clears partial healing and restarts the delay")
	pawn.hp = 109
	pawn.combat_remaining = 0
	sim.update_defense_regen(pawn,2.0)
	check(pawn.hp == 110 and pawn.regen_credit == 0,"Strong healing caps at the upgraded maximum")
	pawn.hp = 0
	sim.update_defense_regen(pawn,10.0)
	check(pawn.hp == 0,"Strong does not revive a dead player")
	sim.progression.data.talents.strong = 0
	pawn.max_hp = 100
	pawn.hp = 100

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

	# Shared wave generation spends the full budget within the authored list.
	var population = preload("res://scripts/defense_population.gd")
	var shared_population = preload("res://scripts/enemy_population.gd")
	var generation_valid = true
	for party_size in range(1,5):
		for difficulty in population.DIFFICULTIES:
			for current_wave in [1,2,3,4,5,6,7,8,9,10,23,100]:
				var seed_value = 1000+current_wave
				var random = RandomNumberGenerator.new()
				var reference_random = RandomNumberGenerator.new()
				random.seed = seed_value
				reference_random.seed = seed_value
				var budget: int = population.budget(current_wave,party_size,difficulty)
				var value: Array = population.roster(current_wave,party_size,random,difficulty)
				var regular: Array = value.filter(func(kind): return kind != "dancer")
				generation_valid = generation_valid and valid_roster_budget(value,budget) and regular == shared_population.roster(budget,population.kinds(current_wave),reference_random)
				generation_valid = generation_valid and regular.all(func(kind): return kind in population.kinds(current_wave)) and value.count("dancer") == (1 if current_wave == 10 else 0)
	check(generation_valid,"All difficulties and party sizes spend the full shared budget inside the authored list; only wave ten adds a boss")
	check(shared_population.COST.imp == 3 and shared_population.COST.shield == 4 and shared_population.COST.berserker == 8 and shared_population.COST.giant == 8 and shared_population.COST.football == 12,"Unified costs include budget-generated football zombies")
	var actual_budgets: Array = []
	for current_wave in range(1,9): actual_budgets.append(population.budget(current_wave,1,"normal"))
	check(actual_budgets == [69,79,89,97,104,110,115,119],"Solo wave budgets are halved with fractional points rounded down")
	check(population.budget(8,2,"normal") == floori(roundi(population.base_budget(8)*1.2*population.budget_multiplier(8))*.5) and population.budget(8,4,"normal") == floori(roundi(population.base_budget(8)*1.6*population.budget_multiplier(8))*.5),"Party coefficients remain unchanged before the final budget halving")
	check(population.base_budget(20)-population.base_budget(19) == 5 and population.base_budget(1000000) == population.base_budget(20)+(1000000-20)*5,"Large-wave arithmetic preserves the five-point tail")

	var reduced_budgets_valid = true
	var decreasing_growth = true
	var previous_growth = 31
	for current_wave in range(1,101):
		reduced_budgets_valid = reduced_budgets_valid and is_equal_approx(population.budget_multiplier(current_wave),1.0-minf(9,current_wave-1)*(.15/9))
		if current_wave < 2: continue
		var growth: int = population.base_budget(current_wave)-population.base_budget(current_wave-1)
		decreasing_growth = decreasing_growth and growth >= 5 and growth <= previous_growth
		previous_growth = growth
	check(reduced_budgets_valid,"Existing budget reduction reaches 85 percent at wave ten and remains capped")
	check(decreasing_growth,"Budget increments decrease monotonically and never fall below five")
	var difficulty_budgets_valid = true
	for party_size in range(1,5):
		for current_wave in [1,3,6,9,10,100]:
			var normal_budget: int = population.normal_budget(current_wave,party_size)
			difficulty_budgets_valid = difficulty_budgets_valid and population.budget(current_wave,party_size,"normal") == floori(normal_budget*.5) and population.budget(current_wave,party_size,"easy") == floori(roundi(normal_budget*.7)*.5) and population.budget(current_wave,party_size,"hard") == floori(roundi(normal_budget*1.3)*.5)
	check(difficulty_budgets_valid,"All difficulty and party budgets are halved after existing rounding")

	var fixed_health = true
	for kind in data.enemies:
		sim.zombies.clear()
		sim.wave = 1
		sim.spawn(Vector2(0,-70),kind)
		var wave_one_hp: float = sim.zombies[-1].hp
		sim.zombies.clear()
		sim.wave = 100
		sim.spawn(Vector2(0,-70),kind)
		fixed_health = fixed_health and is_equal_approx(wave_one_hp,float(data.enemies[kind].health)) and is_equal_approx(sim.zombies[-1].hp,wave_one_hp)
	check(fixed_health,"Every enemy keeps its resource health in high endless waves")
	check(shared_population.COST.shield == 4,"Shield zombies consume four threat points")
	pawn.hp = 100
	pawn.protection = 0.0
	var damage_zombie: Dictionary = sim.zombies[-1]
	pawn.pos = damage_zombie.pos
	pawn.height = data.enemy_ground_height(pawn.pos,sim.map_id)
	sim.damage_target(pawn,damage_zombie,10)
	var before_shared_damage: int = sim.defense.crystal_hp
	sim.damage_target(sim.crystal_target(),damage_zombie,10)
	check(pawn.hp == 90 and sim.defense.crystal_hp == before_shared_damage-10,"Defense uses shared unscaled ten-point melee damage for players and crystal")
	before_shared_damage = sim.defense.crystal_hp
	sim.damage_target(sim.crystal_target(),damage_zombie,sim.CHARGE_DAMAGE)
	check(sim.defense.crystal_hp == before_shared_damage-30,"Football charge deals the same unscaled thirty damage as ordinary melee")
	sim.zombies.clear()
	sim.roster.clear()
	sim.wave = 8
	sim.defense.waiting = false
	sim.step(.02)
	sim.step(10)
	check(not sim.won and sim.wave == 9 and not sim.defense.waiting and sim.roster.count("football") > 0,"Wave eight deployment automatically starts wave nine")
	sim.zombies.clear()
	sim.roster.clear()
	sim.step(.02)
	sim.step(10)
	check(not sim.won and sim.wave == 10 and sim.roster.count("dancer") == 0 and sim.zombies.any(func(z): return z.kind == "dancer" and z.hp > 0),"Wave nine automatically enters the final wave with its dancing boss")
	sim.roster.clear()
	sim.spawn(Vector2(8,24),"normal")
	sim.step(.02)
	check(not sim.won and sim.wave == 10,"Final deployment waits for every remaining living enemy")
	sim.zombies.clear()
	sim.step(.02)
	check(sim.won and sim.wave == 10,"Final-wave clear ends the campaign without wave eleven")
	# The dormant shared host simulation also advances without repeated input.
	game.start_solo("defense")
	game.sim.defense.erase("intro_elapsed") # Fixture starts after the narrative intro.
	await physics_frame
	sim = game.sim
	sim.add_pawn("two","二号",1)
	sim.add_pawn("three","三号",2)
	sim.defense_director.equipment.initialize()
	sim.defense_director.begin_wave()
	sim.roster.clear()
	sim.step(.02)
	sim.step(10)
	check(sim.wave == 2 and not sim.defense.waiting and sim.defense.ready_players.is_empty(),"Shared authority starts the next deployment without multiplayer ready presses")

	# Failure is driven by non-recoverable crystal health, independent of player health.
	game.start_solo("defense")
	game.sim.defense.erase("intro_elapsed") # Fixture starts after the narrative intro.
	await physics_frame
	sim = game.sim
	pawn = sim.pawns.solo
	pawn.pos = Vector2(6,data.Maps.Defense.CRYSTAL.y+3.0)
	var failure_ready := command()
	failure_ready.wave_ready = true
	sim.defense_director.begin_wave()
	sim.step(.02)
	sim.damage_crystal({"id":77},Data.Maps.Defense.CRYSTAL_MAX_HP)
	sim.step(.02)
	check(sim.failed and sim.cause == "crystal" and sim.defense.crystal_hp == 0,"Destroying the fixed-health crystal ends the game in failure")
	sim.add_pawn("two","二号",1)
	sim.defense.party = sim.pawns.size()
	sim.defense_director.equipment.initialize()
	sim.defense_director.begin_wave()
	check(sim.pawns.solo.grenades == 1 and sim.pawns.two.grenades == 1,"Wave start refills grenades for every coop player")

	print("DEFENSE VALIDATION: %d checks; %d failures" % [checks,failures])
	game.queue_free()
	quit(1 if failures else 0)
