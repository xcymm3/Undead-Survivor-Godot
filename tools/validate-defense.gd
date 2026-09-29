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
	var population = preload("res://scripts/enemy_population.gd")
	var spent: float = population.points(value)
	var specials: Array = value.filter(func(kind): return kind in population.ELITES)
	return spent <= budget and budget-spent < .75 and population.points(specials) <= budget*.25

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
	check(layout.SAFE_ZONE.position.x > 0 and layout.SAFE_ZONE.get_center().y < layout.CRYSTAL.y and layout.SAFE_ZONE.has_point(layout.SPAWN),"Armory and player spawn occupy the right side toward the bridge")
	check(game.arena.obstacles.size() >= 5,"Chasm, ramp shelves and rear safe zone participate in navigation")
	check(not game.arena.clear(Vector2(12,-70),Vector2(12,0)),"Chasm prevents routes that bypass the bridge")
	check(not game.arena.clear(Vector2(12,-20),Vector2(12,0)),"Ramp-side shelves cannot bypass the central climb")
	check(not game.arena.clear(Vector2(17,6),Vector2(25,6)),"Zombies cannot enter the side armory safe zone")
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
	check(perimeter_count == 6,"All outer edges except the two chasm-side runs have physical perimeter walls")
	check(game.arena.clear(Vector2(0,-70),Vector2(0,data.Maps.Defense.CRYSTAL.y-3.299999999999997)),"Environmental cover preserves the central bridge, ramp and field lane")
	var weapon_displays = game.arena.scenery.find_children("WeaponDisplay*","Node3D",true,false)
	var armory_weapon_indices := [0,8,7,5]
	check(weapon_displays.size() == 4,"Armory displays only rifle, automatic shotgun, flamethrower and sniper")
	var displayed_weapon_indices: Array = weapon_displays.map(func(node): return int(node.get_meta("weapon_display_index")))
	displayed_weapon_indices.sort()
	check(displayed_weapon_indices == [0,5,7,8],"Armory contains exactly the four allowed guns")
	var shop_walls = game.arena.scenery.find_children("WeaponShopWall","StaticBody3D",true,false)
	check(shop_walls.size() == 1,"Safe zone uses one continuous physical shop wall")
	var shop_shape = shop_walls[0].find_children("*","CollisionShape3D",true,false)[0] as CollisionShape3D
	check(is_equal_approx(shop_walls[0].position.x+.325,30.9) and absf(shop_walls[0].basis.z.x) > .99,"Armory wall sits flush against the right perimeter and faces the field")
	check(shop_shape and shop_shape.shape is BoxShape3D and shop_shape.shape.size.y >= 8.8,"Weapon shop wall is at least twice its previous height")
	var weapon_mounts: Array = weapon_displays.map(func(node): return Vector2(float(node.get_meta("mount_x")),float(node.get_meta("mount_height"))))
	var columns: Array = []
	for point in weapon_mounts:
		if not columns.has(point.x): columns.append(point.x)
	columns.sort()
	var separated = true
	for index in range(1,columns.size()): separated = separated and columns[index]-columns[index-1] >= 4.79
	check(columns.size() == 4 and separated,"Weapon displays use four generously spaced columns")
	check(weapon_mounts.all(func(point): return is_equal_approx(point.y,data.Maps.Defense.ARMORY_ROWS[0])),"Four weapon displays share a reachable row")
	var standing_eye = data.Maps.Defense.height(Vector2(0,60))+preload("res://scripts/player_body.gd").eye_height({"crouch":0.0})
	check(weapon_mounts.all(func(point): return point.y <= standing_eye+1.0),"Every armory weapon is reachable while standing without jumping")
	check(game.arena.scenery.find_children("WeaponRack*","StaticBody3D",true,false).is_empty(),"Safe zone no longer uses five separate rack walls")

	game.start_solo("defense")
	await physics_frame
	var sim = game.sim
	var pawn: Dictionary = sim.pawns.solo
	check(sim.mode == "defense" and not sim.defense.started,"Entering the map does not start waves")
	check(sim.defense.difficulty == "easy" and is_equal_approx(sim.defense.difficulty_multiplier,.7),"Defense validation runs the Easy difficulty selected before the match")
	check(pawn.weapon1 == 0 and pawn.weapon2 == 8 and pawn.slot == 1,"Defense starts with two unrestricted guns and the fixed axe slot")
	check(not pawn.has("medkits") and pawn.grenades == 0,"Medical inventory is absent and grenades wait for wave start")
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
	check(sim.elapsed == 0 and sim.spawned == 0 and sim.zombies.is_empty(),"Waiting for T keeps timer and spawns stopped")
	check(pawn.weapon == pawn.weapon2 and pawn.slot == 2,"Defense uses weapon-slot-2 switching")
	interact_with(sim,pawn,data.Maps.Defense.weapon_mount(3))
	check(pawn.weapon1 == 0 and pawn.weapon2 == 5 and pawn.weapon == 5,"Picking up a sniper replaces selected weapon slot 2")
	check(pawn.ammo[5] == data.weapons[5].capacity and pawn.reserves[5] == data.defense_full_reserve(5),"Replacement weapon is fully supplied")
	for i in 10:
		sim.submit("solo",command(0,false,1))
		sim.step(.05)
	interact_with(sim,pawn,data.Maps.Defense.weapon_mount(2))
	check(pawn.weapon1 == 7 and pawn.weapon2 == 5 and pawn.weapon == 7,"Flamethrower replaces slot 1 and keeps the sniper in slot 2")
	check(game.arena.scenery.find_children("WeaponDisplay*","Node3D",true,false).size() == 4,"Wall guns remain available after pickup")
	check(not sim.equipment.pickup(pawn,"grenade:0") and not sim.equipment.pickup(pawn,"medkit:0"),"Removed supplies cannot be picked up")
	var ready_input := command(int(pawn.weapon),false,int(pawn.slot))
	ready_input.wave_ready = true
	sim.submit("solo",ready_input)
	sim.step(.02)
	check(sim.defense.started and not sim.defense.waiting and sim.rest == 0 and not sim.roster.is_empty(),"T starts wave one immediately without a countdown")
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
	check(sim.cleared == 1 and sim.rest == 0 and sim.defense.wave == 2 and sim.defense.waiting and sim.defense.ready_players.is_empty(),"Wave end pauses before wave two and resets readiness")
	for i in 60: sim.step(.1)
	check(sim.wave == 1 and sim.defense.waiting and sim.roster.is_empty(),"Waiting never automatically starts the next wave")
	sim.submit("solo",ready_input)
	sim.step(.02)
	check(sim.wave == 2 and not sim.defense.waiting and sim.events.any(func(event): return event.kind == "wave_start"),"A fresh T starts wave two and sounds its horn")

	# Isolate target choice from the wave spawner: the closest valid unit must take the hit.
	sim.roster.clear()
	sim.zombies.clear()
	pawn.pos = data.Maps.Defense.SPAWN
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
		for entry in [Vector2(0,data.Maps.Defense.CRYSTAL.y-6.0),Vector2(-5,data.Maps.Defense.CRYSTAL.y+0.0),Vector2(5,data.Maps.Defense.CRYSTAL.y+0.0),Vector2(0,data.Maps.Defense.CRYSTAL.y+4.0)]:
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

	# Quarter-point costs spend the budget without exceeding either pool;
	# an unspendable remainder is less than one ordinary body (0.75 points).
	var population = preload("res://scripts/defense_population.gd")
	var shared_population = preload("res://scripts/enemy_population.gd")
	sim.wave = 1
	sim.random.seed = 481516
	var exact_sample_budgets = true
	for sample in 200:
		sim.prepare_wave()
		exact_sample_budgets = exact_sample_budgets and valid_roster_budget(sim.roster,population.budget(1,1,"easy"))
	check(exact_sample_budgets,"Easy rosters respect the quarter-point budget and twenty-five percent special cap")
	sim.defense_ordinary_slots = 0
	var variants: Array = []
	for slot in 20: variants.append(sim.defense_population_kind("normal"))
	check(variants.count("crawler") == 1 and variants[18] == "normal" and variants[19] == "crawler","Defense uses the shared rule of every twentieth ordinary zombie becoming a crawler")
	var exact_wave_budgets = true
	var exact_football_counts = true
	var shared_rosters = true
	for current_wave in [1,2,3,4,5,6,7,8,9,10,23,24,100]:
		var defense_random = RandomNumberGenerator.new()
		var reference_random = RandomNumberGenerator.new()
		defense_random.seed = 1000+current_wave
		reference_random.seed = defense_random.seed
		var defense_roster: Array = population.roster(current_wave,1,defense_random,"easy")
		var ordinary_roster: Array = defense_roster.filter(func(kind): return kind != "football")
		var reference_roster: Array = shared_population.roster(population.budget(current_wave,1,"easy"),population.kinds(current_wave),reference_random)
		exact_wave_budgets = exact_wave_budgets and valid_roster_budget(defense_roster,population.budget(current_wave,1,"easy"))
		exact_football_counts = exact_football_counts and defense_roster.count("football") == population.footballs(current_wave,1)
		shared_rosters = shared_rosters and ordinary_roster == reference_roster
	check(exact_wave_budgets,"Easy early and endless waves respect both point pools and integer-body remainder")
	check(exact_football_counts,"Solo waves six and seven have one football; every wave from eight has two")
	check(shared_rosters,"Defense ordinary rosters are generated by the shared point algorithm")
	check(not shared_population.COST.has("football"),"Authored football zombies have no point cost")
	var expected_normal_budgets := [138,162,184,204,223,240,256,271]
	var actual_normal_budgets: Array = []
	var normal_rosters_spend_exactly := true
	for current_wave in range(1,9):
		var wave_budget: int = population.budget(current_wave,1,"normal")
		actual_normal_budgets.append(wave_budget)
		var wave_roster: Array = population.roster(current_wave,1,RandomNumberGenerator.new(),"normal")
		normal_rosters_spend_exactly = normal_rosters_spend_exactly and valid_roster_budget(wave_roster,wave_budget)
	check(actual_normal_budgets == expected_normal_budgets and normal_rosters_spend_exactly,"Budget curve shifts forward three waves and the first wave starts at 138 points")
	check(population.budget(8,2,"normal") == roundi(population.base_budget(8)*1.2) and population.budget(8,4,"normal") == roundi(population.base_budget(8)*1.6),"Normal difficulty preserves the existing multiplayer budget rules")
	var decreasing_growth = true
	var previous_growth = 31
	for current_wave in range(2,101):
		var growth: int = population.base_budget(current_wave)-population.base_budget(current_wave-1)
		decreasing_growth = decreasing_growth and growth >= 5 and growth <= previous_growth
		previous_growth = growth
	check(decreasing_growth,"Budget increments decrease monotonically and never fall below five")
	check(population.base_budget(20)-population.base_budget(19) == 5 and population.base_budget(1000000) == population.base_budget(20)+(1000000-20)*5,"From wave twenty the shifted unlimited budget tail grows by exactly five")
	var difficulty_budgets_are_scaled = true
	var multiplayer_footballs_are_scaled = true
	for party_size in range(1,5):
		for current_wave in [1,2,3,4,5,6,7,8,9,10,23,24,100]:
			var normal_budget: int = population.normal_budget(current_wave,party_size)
			difficulty_budgets_are_scaled = difficulty_budgets_are_scaled and population.budget(current_wave,party_size,"normal") == normal_budget
			difficulty_budgets_are_scaled = difficulty_budgets_are_scaled and population.budget(current_wave,party_size,"easy") == roundi(normal_budget*.7)
			difficulty_budgets_are_scaled = difficulty_budgets_are_scaled and population.budget(current_wave,party_size,"hard") == roundi(normal_budget*1.3)
			var expected_footballs: int = party_size if current_wave in [6,7] else party_size*2 if current_wave >= 8 else 0
			var coop_roster: Array = population.roster(current_wave,party_size,RandomNumberGenerator.new(),"normal")
			multiplayer_footballs_are_scaled = multiplayer_footballs_are_scaled and population.footballs(current_wave,party_size) == expected_footballs and coop_roster.count("football") == expected_footballs and valid_roster_budget(coop_roster,normal_budget)
	check(difficulty_budgets_are_scaled,"Difficulty changes only the final point budget by 70, 100 or 130 percent")
	check(multiplayer_footballs_are_scaled,"All endless waves scale football bosses with player count without spending points")

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
	check(shared_population.COST.shield == 6,"Shield zombies consume six threat points")
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
	sim.cleared = 7
	sim.rest = 0
	sim.defense.waiting = false
	sim.step(.02)
	check(not sim.won and sim.cleared == 8 and sim.defense.waiting and sim.defense.wave == 9 and sim.defense.ready_players.is_empty(),"Clearing wave eight prepares wave nine without winning or retaining readiness")
	var endless_ready := command()
	endless_ready.wave_ready = true
	sim.submit("solo",endless_ready)
	sim.step(.02)
	check(sim.wave == 9 and not sim.defense.waiting and sim.roster.count("football") == 2,"A fresh T starts wave nine with two football zombies")
	sim.zombies.clear()
	sim.roster.clear()
	sim.wave = 100
	sim.cleared = 99
	sim.step(.02)
	check(not sim.won and sim.cleared == 100 and sim.defense.waiting and sim.defense.wave == 101,"A high wave also prepares the next wave without a victory cap")

	# Three players must each send a fresh T press for every wave.
	game.start_solo("defense")
	await physics_frame
	sim = game.sim
	sim.add_pawn("two","二号",1)
	sim.add_pawn("three","三号",2)
	sim.defense.party = sim.pawns.size()
	sim.defense_director.equipment.initialize()
	var coop_ready := command()
	coop_ready.wave_ready = true
	sim.submit("solo",coop_ready)
	sim.step(.02)
	check(sim.defense.waiting and not sim.defense.started and sim.defense.ready_players.size() == 1 and sim.roster.is_empty(),"One of three players pressing T cannot start wave one")
	sim.submit("two",coop_ready)
	sim.step(.02)
	check(sim.defense.waiting and sim.defense.ready_players.size() == 2 and sim.roster.is_empty(),"Two of three players pressing T cannot start wave one")
	sim.submit("three",coop_ready)
	sim.step(.02)
	check(not sim.defense.waiting and sim.defense.started and sim.wave == 1 and not sim.roster.is_empty() and sim.defense.ready_players.is_empty(),"All three T presses start wave one and clear readiness")
	sim.submit("solo",coop_ready)
	sim.submit("two",coop_ready)
	sim.submit("three",coop_ready)
	sim.step(.02)
	check(sim.defense.ready_players.is_empty(),"T presses during an active wave are not saved")
	sim.roster.clear()
	sim.zombies.clear()
	sim.step(.02)
	check(sim.defense.waiting and sim.defense.wave == 2 and sim.defense.ready_players.is_empty(),"Wave one completion clears all prior T presses")
	for i in 60: sim.step(.1)
	check(sim.defense.waiting and sim.wave == 1 and sim.roster.is_empty(),"Three-player wave two stays paused without new presses")
	sim.submit("solo",coop_ready)
	sim.step(.02)
	sim.submit("two",coop_ready)
	sim.step(.02)
	check(sim.defense.waiting and sim.defense.ready_players.size() == 2 and sim.roster.is_empty(),"Prior-wave readiness cannot satisfy the missing third player")
	sim.submit("three",coop_ready)
	sim.step(.02)
	check(not sim.defense.waiting and sim.wave == 2 and not sim.roster.is_empty() and sim.defense.ready_players.is_empty(),"All players press T again to start wave two")
	sim.zombies.clear()
	sim.roster.clear()
	sim.wave = 8
	sim.cleared = 7
	sim.step(.02)
	check(sim.defense.waiting and sim.defense.wave == 9 and sim.defense.ready_players.is_empty() and not sim.won,"Coop wave eight completion enters fresh wave-nine preparation")
	sim.submit("solo",coop_ready)
	sim.submit("two",coop_ready)
	sim.step(.02)
	check(sim.defense.waiting and sim.wave == 8 and sim.roster.is_empty(),"Two of three new T presses cannot start coop wave nine")
	sim.submit("three",coop_ready)
	sim.step(.02)
	check(sim.wave == 9 and not sim.defense.waiting and sim.roster.count("football") == 6 and sim.defense.ready_players.is_empty(),"All new T presses start coop wave nine with twice the player count of footballs")

	# Failure is driven by non-recoverable crystal health, independent of player health.
	game.start_solo("defense")
	await physics_frame
	sim = game.sim
	pawn = sim.pawns.solo
	pawn.pos = Vector2(6,data.Maps.Defense.CRYSTAL.y+3.0)
	var failure_ready := command()
	failure_ready.wave_ready = true
	sim.submit("solo",failure_ready)
	sim.step(.02)
	sim.damage_crystal({"id":77},Data.Maps.Defense.CRYSTAL_MAX_HP)
	sim.step(.02)
	check(sim.failed and sim.cause == "crystal" and sim.defense.crystal_hp == 0,"Destroying the fixed-health crystal ends the game in failure")
	sim.add_pawn("two","二号",1)
	sim.defense.party = sim.pawns.size()
	sim.defense_director.equipment.initialize()
	sim.defense_director.begin_wave()
	check(sim.pawns.solo.grenades == 3 and sim.pawns.two.grenades == 3,"Wave start refills grenades for every coop player")

	print("DEFENSE VALIDATION: %d checks; %d failures" % [checks,failures])
	game.queue_free()
	quit(1 if failures else 0)
