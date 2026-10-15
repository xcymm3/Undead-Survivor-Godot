extends SceneTree
const Fixture = preload("res://tools/preparation-fixture.gd")
const Store = preload("res://scripts/progression_store.gd")
var checks = 0
var failures = 0
var game

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var data = root.get_node("Data")
	var profile = Store.new()
	check(Store.valid(profile.data) and profile.data.coins == 0 and profile.data.diamonds == 0,"Fresh progress starts without currencies")
	check(not profile.purchase("rifle") and profile.level("rifle") == 0,"Insufficient coins cannot purchase an upgrade")
	for kind in Store.COIN_REWARDS:
		check(profile.award_kill(kind) == Store.COIN_REWARDS[kind],"Reward tier: "+kind)
	var expected_rewards = {"normal":1,"cone":2,"bucket":5,"imp":10,"shield":25,"berserker":100,"giant":150,"football":250,"dancer":2000}
	for kind in expected_rewards: check(Store.COIN_REWARDS[kind] == expected_rewards[kind],"Authored staircase reward: "+kind)
	var defense_population = preload("res://scripts/defense_population.gd")
	var expected_wave_rewards = [69,118,235,209,452,535,889,765,1140,3480]
	var wave_income_total = 0
	for wave in range(1,11):
		var income = 0
		for kind in defense_population.roster(wave,1,RandomNumberGenerator.new()): income += Store.COIN_REWARDS[kind]
		wave_income_total += income
		check(income == expected_wave_rewards[wave-1],"Staircase reward total for wave "+str(wave))
	check(wave_income_total == 7892 and Store.UPGRADE_PRICES.reduce(func(total,value): return total+value,0) == 6400,"One complete campaign funds all ten rifle upgrades with 1492 coins to spare")
	profile.data.coins = 100000
	for id in Store.WEAPONS:
		check(profile.cost(id) == 50 and profile.purchase(id) and profile.cost(id) == 100,"First weapon upgrade uses the next fixed price: "+id)
		check(profile.purchase(id) and is_equal_approx(profile.weapon_multiplier(id),1.44),"Weapon damage compounds by twenty percent: "+id)
	for count in range(2,6):
		check(profile.cost("grenade") == [300,450,650,1000][count-2] and profile.purchase("grenade") and profile.grenade_capacity() == count,"Grenade capacity increases to "+str(count))
	check(not profile.purchase("grenade") and profile.cost("grenade") == -1,"Grenade capacity cannot exceed five")
	for id in Store.BUILDINGS:
		check(profile.cost(id) == 100,"Each building uses its confirmed manufacturing price: "+id)
		check(not profile.owned(id) and profile.purchase(id) and profile.owned(id),"Manufacturing grants persistent ownership: "+id)
		var first: int = profile.cost(id)
		check(profile.purchase(id) and profile.cost(id) == first*2 and is_equal_approx(profile.building_multiplier(id),1.2),"Building upgrade compounds and uses fixed prices: "+id)
	for id in Store.MINES:
		var coins: int = profile.data.coins
		check(not profile.owned(id) and profile.cost(id) == Store.MINE_PRICES[id] and profile.purchase(id) and profile.data.coins == coins-Store.MINE_PRICES[id],"Mine uses its distance-tier purchase price: "+id)
		check(profile.owned(id) and profile.level(id) == 0 and profile.cost(id) == -1 and not profile.purchase(id),"Owned mines cannot be bought again or upgraded: "+id)
	for id in Store.TALENTS:
		profile.data.diamonds = 9
		for rank in range(1,6):
			check(profile.cost(id) == [1,1,2,2,3][rank-1] and profile.purchase(id),"Talent rank costs its rank: "+id+str(rank))
		check(profile.data.diamonds == 0 and profile.level(id) == 5 and not profile.purchase(id),"Five ranks consume exactly nine diamonds: "+id)
	check(profile.max_health() == 150 and profile.regen_rate() == 5 and is_equal_approx(profile.head_multiplier(),2) and is_equal_approx(profile.move_multiplier(),1.25) and is_equal_approx(profile.reserve_multiplier(),2),"Max talents apply the confirmed values")
	var capped = Store.new()
	capped.data.coins = Store.MAX_CURRENCY
	for id in Store.WEAPONS+Store.MAGAZINES+Store.BUILDINGS:
		if id in Store.BUILDINGS: check(capped.purchase(id),"Cap fixture manufactures "+id)
		for rank in range(1,11): check(capped.cost(id) == [50,100,150,200,300,450,650,1000,1500,2000][rank-1] and capped.purchase(id) and capped.level(id) == rank,"Upgrade purchases through rank ten: "+id+str(rank))
		var wallet: int = capped.data.coins
		check(capped.cost(id) == -1 and not capped.purchase(id) and capped.data.coins == wallet,"Rank eleven is blocked without payment: "+id)
	check(is_equal_approx(capped.magazine_multiplier("rifle"),pow(1.2,10)) and is_equal_approx(capped.magazine_multiplier("pistol"),pow(1.2,10)),"Magazine capacity compounds independently to rank ten")
	# Unique temporary files exercise actual JSON writes without touching player saves.
	var path = OS.get_cache_dir().path_join("undead-progress-qa-"+str(Time.get_ticks_usec())+".json")
	var saved = Store.new(path)
	saved.data.coins = 200
	saved.dirty = true
	check(saved.save() and saved.purchase("rifle"),"Permanent transaction writes its upgraded state")
	var reloaded = Store.new(path)
	check(reloaded.data.coins == 150 and reloaded.level("rifle") == 1 and reloaded.cost("rifle") == 100,"Reload restores coins, levels and subsequent prices")
	check(reloaded.purchase("rifle"),"Reloaded progress remains purchasable")
	var bad = FileAccess.open(path,FileAccess.WRITE)
	bad.store_string("{broken")
	bad.close()
	var recovered = Store.new(path)
	check(recovered.data.coins == 150 and recovered.level("rifle") == 1 and not recovered.notice.is_empty(),"Corrupt primary save recovers the last complete backup")
	check(recovered.save() and Store.new(path).data.coins == 150,"Recovered state repairs the primary save")
	var legacy: Dictionary = Store.defaults()
	legacy.version = 1
	legacy.weapons.revolver = 4
	legacy.weapons.erase("pistol")
	legacy.erase("mines")
	legacy.buildings.erase("bridge_entry_gate")
	legacy.coins = 321
	legacy.diamonds = 7
	legacy.weapons.rifle = 3
	legacy.talents.strong = 2
	legacy.buildings.bridge_gate = {"owned":true,"level":2}
	check(Store.valid(legacy),"Version-one progress is still recognized before migration")
	var legacy_file = FileAccess.open(path,FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	var migrated = Store.new(path)
	check(migrated.data.version == 6 and Store.valid(migrated.data) and migrated.data.coins == 321 and migrated.data.diamonds == 7 and migrated.level("rifle") == 3 and migrated.level("pistol") == 4 and migrated.level("strong") == 2 and migrated.level("bridge_gate") == 2,"Migration preserves old currencies, talents and building upgrades")
	check(migrated.owned("crystal_mine") and not migrated.owned("ramp_mine") and not migrated.owned("gate_mine") and not migrated.owned("bridge_entry_gate"),"Old free mine is retained while new defenses require purchase")
	check(migrated.dirty and migrated.save() and Store.new(path).data == migrated.data,"Migrated progress persists and reloads without repeating migration")
	var corrupt_primary = FileAccess.open(path,FileAccess.WRITE)
	corrupt_primary.store_string("{broken")
	corrupt_primary.close()
	var legacy_backup = Store.new(path)
	check(legacy_backup.owned("crystal_mine") and legacy_backup.data.version == 6 and legacy_backup.level("bridge_gate") == 2,"Recovery also migrates a valid old-format backup")
	var version_two = Store.defaults()
	version_two.version = 2
	version_two.coins = 1234
	version_two.diamonds = 9
	version_two.weapons.erase("pistol")
	version_two.weapons.revolver = 7
	var v2_file = FileAccess.open(path,FileAccess.WRITE)
	v2_file.store_string(JSON.stringify(version_two))
	v2_file.close()
	var upgraded_v2 = Store.new(path)
	check(upgraded_v2.data.version == 6 and upgraded_v2.level("pistol") == 7 and upgraded_v2.data.coins == 1234 and upgraded_v2.data.diamonds == 9 and not upgraded_v2.data.weapons.has("revolver"),"Version-two saves migrate revolver upgrades without losing currencies")
	check(upgraded_v2.save() and Store.new(path).data == upgraded_v2.data,"Migrated pistol state survives a second disk reload")
	var old_v3 = Store.defaults()
	old_v3.version = 3
	old_v3.erase("magazines")
	old_v3.coins = 555
	old_v3.weapons.rifle = 20
	old_v3.buildings.bridge_gate = {"owned":true,"level":48}
	var old_file = FileAccess.open(path,FileAccess.WRITE)
	old_file.store_string(JSON.stringify(old_v3))
	old_file.close()
	var migrated_v3 = Store.new(path)
	check(migrated_v3.data.version == 6 and migrated_v3.data.coins == 555 and migrated_v3.level("rifle") == 10 and migrated_v3.level("bridge_gate") == 10 and migrated_v3.data.magazines == {"rifle_magazine":0,"pistol_magazine":0},"Old saves gain zero magazine levels and clamp previous upgrades to the new ten-level limit")
	migrated_v3.data.coins = 1000
	check(migrated_v3.purchase("pistol_magazine") and Store.new(path).level("pistol_magazine") == 1,"Magazine purchases persist across disk reloads")
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	var malformed = Store.defaults()
	malformed.coins = -1
	check(not Store.valid(malformed),"Negative currency is rejected")
	malformed = Store.defaults()
	malformed.talents.strong = 11
	check(not Store.valid(malformed),"Out of range talent saves are rejected")
	malformed = Store.defaults()
	malformed.weapons.rifle = "10"
	check(not Store.valid(malformed),"Invalid save field types are rejected")
	malformed = Store.defaults()
	malformed.mines.ramp_mine = 1
	check(not Store.valid(malformed),"Mine ownership must be boolean in version-two progress")
	var unwritable = Store.new()
	unwritable.path = OS.get_cache_dir().path_join("missing-"+str(Time.get_ticks_usec())+"/progress.json")
	unwritable.data.coins = 100
	check(not unwritable.purchase("rifle") and unwritable.data.coins == 100 and unwritable.level("rifle") == 0,"Failed save rolls back the purchase without spending currency")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	root.get_node("Progress").store = Store.new()
	game.start_solo("defense",42)
	await physics_frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	check(sim.defense.structures.all(func(item): return item.hp == 0 and not item.owned),"Fresh player owns no turrets, gates or mines")
	var view = game.arena.scenery.structure_view
	check(view.actors.turret_left.root.visible and view.actors.turret_left.body.collision_layer == 0 and view.actors.bridge_gate.root.visible,"Unowned buildings show nonblocking construction ghosts")
	check(view.actors.bridge_entry_gate.root.visible and view.actors.bridge_entry_gate.body.collision_layer == 0 and Store.MINES.all(func(id): return not view.actors[id].root.visible),"Unbuilt bridge-end gate is a ghost while unbought mines stay absent")
	sim.spawn(sim.defense_director.structures.find("ramp_mine").pos,"normal")
	sim.defense_director.structures.step_mine(sim.defense_director.structures.find("ramp_mine"),10)
	check(not sim.defense_director.structures.find("ramp_mine").triggered and sim.zombies[-1].hp > 0,"An unowned mine cannot trigger or damage enemies")
	sim.zombies.clear()
	check(game.arena.scenery.find_children("WeaponDisplay*","Node3D",true,false).is_empty() and game.arena.scenery.has_node("PreparationWorld/Station_rifle"),"Armory gun racks are replaced by the shop counter")
	p.hp = 50
	sim.update_defense_regen(p,100)
	check(p.hp == 50,"No Strong talent means no automatic healing")
	sim.progression.data.coins = 10000
	sim.progression.data.diamonds = 100
	check(not game.paused and game.ui.current.is_empty(),"Preparation remains in the world")
	check(Fixture.buy(sim,p,"rifle") and sim.progression.cost("rifle") == 100,"Rifle station updates permanent level and next price")
	check(game.arena.scenery.preparation.stations.has("strong"),"Four talents have physical stations")
	check(Fixture.buy(sim,p,"strong") and sim.progression.level("strong") == 1 and p.max_hp == 110 and p.hp == 60,"Medical station raises maximum and current health")
	check(Fixture.buy(sim,p,"precise") and Fixture.buy(sim,p,"swift") and Fixture.buy(sim,p,"supply"),"Each talent upgrades at its own station")
	check(p.reserves[0] == 306 and p.reserves[2] == 154,"Supply increases both finite reserves")
	for rank in range(2,6): check(Fixture.buy(sim,p,"supply"),"Additional Supply purchase "+str(rank))
	check(p.reserves[0] == 510 and p.reserves[2] == 256,"Repeated Supply purchases retain exact reserve rounding")
	check(is_equal_approx(sim.weapon_damage(data.weapons[0],false),144) and is_equal_approx(sim.weapon_damage(data.weapons[0],true),345.6),"Player damage combines weapon and headshot talent upgrades")
	check(Fixture.buy(sim,p,"grenade") and p.grenades == 2 and p.grenade_capacity == 2,"Capacity purchase immediately grants its extra grenade")
	check(Fixture.buy(sim,p,"bridge_entry_gate"),"New bridge-end gate can be bought")
	var shop_position: Vector2 = p.pos
	var shop_height: float = p.height
	p.pos = Vector2(0,-26)
	p.height = data.Maps.Defense.height(p.pos)
	check(Fixture.buy(sim,p,"bridge_entry_gate"),"Bridge-end gate upgrades beside its built position")
	p.pos = shop_position
	p.height = shop_height
	for id in Store.MINES:
		check(Fixture.buy(sim,p,id) and view.actors[id].root.visible and not Fixture.buy(sim,p,id),"Shop buys and reveals each mine once without an upgrade: "+id)
	for id in ["turret_left","bridge_gate"]:
		check(Fixture.buy(sim,p,id),"Buildings can be manufactured: "+id)
		var item: Dictionary = sim.defense_director.structures.find(id)
		p.pos = item.pos+Vector2(0,2)
		p.height = data.Maps.Defense.height(p.pos)
		check(Fixture.buy(sim,p,id),"Buildings upgrade only beside their built position: "+id)
		p.pos = shop_position
		p.height = shop_height
	var manager = sim.defense_director.structures
	check(manager.find("bridge_gate").max_hp == 1200 and is_equal_approx(manager.find("turret_left").damage_multiplier,1.2) and manager.find("turret_right").hp == 0,"Purchased building upgrades affect only their owned targets")
	check(manager.find("bridge_entry_gate").max_hp == 1200 and sim.progression.cost("bridge_entry_gate") == 100,"Bridge-end gate uses the weapon upgrade price and uses the next fixed price")
	check(view.actors.turret_left.root.visible and view.actors.turret_left.body.collision_layer == 1 and view.actors.bridge_gate.root.visible,"Manufacturing creates visible native building collision")
	var turret: Dictionary = manager.find("turret_left")
	sim.spawn(turret.pos+Vector2(0,4),"normal")
	var target: Dictionary = sim.zombies[-1]
	target.body = 10000.0
	target.hp = 10000.0
	manager.step_turret(turret,.01)
	check(is_equal_approx(target.hp,9928),"Upgraded turret actually deals seventy-two damage independently of player weapon and headshot upgrades")
	sim.zombies.clear()
	sim.enter_combat(p)
	sim.update_defense_regen(p,5)
	check(p.hp == 60,"Strong waits all five combat seconds")
	sim.update_defense_regen(p,.4)
	sim.update_defense_regen(p,.6)
	check(p.hp == 61,"Strong heals one health per second at rank one")
	p.protection = 0
	sim.damage_pawn(p,{"pos":p.pos+Vector2(0,1),"id":99},10)
	sim.update_defense_regen(p,4.9)
	check(p.hp == 51,"Taking damage restarts the five-second delay")
	sim.fire(p,data.weapons[0])
	sim.update_defense_regen(p,4.9)
	check(p.hp == 55,"Attacking permits healing after five seconds without incoming damage")
	sim.update_defense_regen(p,2)
	check(p.hp == 57,"Healing continues while attacking")
	p.combat_remaining = 2.0
	p.switch = 0.0
	p.shove_cd = 0.0
	p.shove_gap = 0.0
	p.slot = 1
	sim.fire(p,data.weapons[6])
	check(sim.try_shove(p) and p.combat_remaining == 2.0,"Axe swings and successful shoves do not reset the damage-only healing delay")
	p.grenades = 1
	p.grenade_ready_at = 0
	check(sim.equipment.throw_grenade(p) and p.combat_remaining == 2.0,"Successful grenade throws do not reset the damage-only healing delay")
	p.hp = 109
	p.combat_remaining = 0
	sim.update_defense_regen(p,10)
	check(p.hp == 110 and p.regen_credit == 0,"Strong healing respects the upgraded health maximum")
	p.hp = 0
	sim.update_defense_regen(p,100)
	check(p.hp == 0,"Strong cannot revive a dead player")
	p.hp = 100
	game.resume_game()
	sim.spawn(Vector2(12,25),"bucket")
	var z: Dictionary = sim.zombies[-1]
	var coins_before: int = sim.progression.data.coins
	sim.hit_enemy(z,float(z.armor),true,p,Vector3(12,4,25))
	check(z.kind == "normal" and z.original == "bucket","Broken armor retains the original reward tier")
	sim.hit_enemy(z,10000,false,p,Vector3(12,4,25))
	sim.hit_enemy(z,10000,false,p,Vector3(12,4,25))
	check(sim.progression.data.coins == coins_before+5 and sim.coin_drops.size() == 1,"A kill pays its original tier exactly once")
	var initial_coin: Vector3 = sim.coin_drops[0].pos
	sim.step_coins(.9)
	check(sim.coin_drops[0].pos.distance_to(Vector3(p.pos.x,p.height+1.05,p.pos.y)) < initial_coin.distance_to(Vector3(p.pos.x,p.height+1.05,p.pos.y)),"Coin magnet moves the drop toward the player")
	sim.step_coins(5)
	check(sim.coin_drops.is_empty() and sim.progression.data.coins == coins_before+5,"Cosmetic pickup removal cannot pay coins again")
	for kind in ["bucket","shield","berserker","imp"]:
		sim.spawn(Vector2(12,25),kind)
		var summoned_enemy: Dictionary = sim.zombies[-1]
		summoned_enemy.summoned = true
		var before_coins: int = sim.progression.data.coins
		var before_drops: int = sim.coin_drops.size()
		var before_kills: int = sim.kills
		sim.hit_enemy(summoned_enemy,summoned_enemy.hp+1,false,p,Vector3(12,4,25))
		check(sim.progression.data.coins == before_coins and sim.coin_drops.size() == before_drops and sim.kills == before_kills+1,"Summoned enemy grants a kill but no money or coin animation: "+kind)
	p.ammo[0] = 7
	p.reserves[0] = 23
	p.reserves[2] = 510
	sim.equipment.save_weapon_slot(p)
	p.hp = 63
	p.grenades = 0
	sim.defense_director.begin_wave()
	check(p.hp == 63 and p.grenades == 0 and p.ammo[0] == 7 and p.reserves[0] == 23,"New wave preserves health and spent equipment")
	var money: int = sim.progression.data.coins
	check(not sim.purchase_upgrade("rifle",p) and sim.progression.data.coins == money,"Active-wave shop transactions are rejected")
	manager.damage("bridge_gate",1200)
	sim.roster.clear()
	sim.zombies.clear()
	var diamonds: int = sim.progression.data.diamonds
	sim.step(.02)
	sim.defense_director.finish_wave()
	check(sim.progression.data.diamonds == diamonds+1 and sim.cleared == 1,"Successful wave rewards exactly one diamond, even if completion is repeated")
	check(p.ammo[0] == 7 and p.reserves[0] == 83 and p.reserves[2] == 540 and p.slot_reserves == [83,540] and p.reserve == 83,"Clear rewards two reserve magazines once for both guns, above capacity without filling the magazine")
	sim.equipment.select_weapon_slot(p,2)
	check(p.reserves[2] == 540 and p.reserve == 540,"Switching guns preserves above-capacity wave ammunition")
	check(not sim.purchase_upgrade("rifle",p),"Shop stays closed after clearing a wave")
	sim.defense_director.begin_wave()
	check(manager.find("bridge_gate").hp == 0 and p.grenades == 0 and p.reserves[0] == 83 and p.reserves[2] == 540,"Next wave preserves destroyed buildings and spent grenades without extra ammunition")
	var permanent = sim.progression.data.duplicate(true)
	game.start_solo("defense",42)
	await physics_frame
	sim = game.sim
	p = game.local_pawn()
	check(sim.wave == 1 and sim.progression.data == permanent and sim.shop_available(p),"Restart resets combat and reopens shop while preserving permanent progress")
	check(p.hp == 110 and p.ammo[0] == 30 and p.reserves[0] == 510 and p.reserves[2] == 256,"Restart restores ammunition using upgraded Supply")
	sim.defense_director.begin_wave()
	sim.roster.clear()
	sim.step(.02)
	check(sim.progression.data.diamonds == diamonds+2,"Replaying wave one earns another diamond")
	check(p.reserves[0] == 570 and p.reserves[2] == 286,"A new match can earn the same first-wave ammo reward again")
	sim.defense_director.begin_wave()
	sim.roster.clear()
	sim.defense.crystal_hp = 0
	sim.step(.02)
	check(sim.failed and sim.progression.data.diamonds == diamonds+2,"A failed wave awards no diamond")
	check(p.reserves[0] == 570 and p.reserves[2] == 286,"A failed wave awards no ammunition")
	game.ui.native_hud.sync()
	check(game.ui.native_hud.currency_label.text.contains(str(sim.progression.data.coins)),"Top-right HUD shows permanent currency")
	root.get_node("Progress").store = Store.new()
	game.start_solo("defense",913)
	await physics_frame
	sim = game.sim
	p = game.local_pawn()
	sim.progression.data.coins = 100000
	check(game.arena.scenery.preparation.stations.has("rifle_magazine") and not game.arena.scenery.preparation.stations.has("pistol_magazine"),"Both magazine upgrades share one physical preparation station")
	Fixture.face(sim,p,"rifle_magazine")
	Fixture.hold(sim,p,.99)
	check(sim.progression.level("rifle_magazine") == 0,"A hold shorter than one second cannot buy")
	Fixture.hold(sim,p,.011)
	check(sim.progression.level("rifle_magazine") == 1 and sim.weapon_capacity(0) == 36 and p.ammo[0] == 30,"One-second hold buys rifle capacity without manufacturing extra loaded ammunition")
	Fixture.hold(sim,p,1.1)
	check(sim.progression.level("rifle_magazine") == 1,"Continued hold cannot repeatedly purchase")
	p.input = {}
	sim.defense_director.interactions(.01)
	check(Fixture.buy(sim,p,"pistol_magazine") and sim.weapon_capacity(2) == 18 and p.ammo[2] == 15,"Pistol magazine has an independent eighteen-round first upgrade")
	for index in [0,2]:
		p.weapon = index
		p.slot = 1 if index == 0 else 2
		p.requested = index
		p.switch = 0.0
		p.ammo[index] = 0
		p.reserves[index] = 100
		p.reloading = true
		p.reload = .01
		sim.advance_arsenal(p,{},.02)
		check(p.ammo[index] == sim.weapon_capacity(index) and p.reserves[index] == 100-sim.weapon_capacity(index),"Reload consumes finite reserve up to the upgraded capacity: "+str(index))
	sim.defense_director.equipment.award_wave_ammo(p)
	check(p.reserves[0] == 136 and p.reserves[2] == 118,"Clear rewards use two upgraded reserve magazines per gun")
	var capacity_state = sim.progression.data.duplicate(true)
	game.start_solo("defense",913)
	await physics_frame
	sim = game.sim
	p = game.local_pawn()
	check(sim.progression.data == capacity_state and p.ammo[0] == 36 and p.ammo[2] == 18 and p.slot_ammo == [36,18],"Restart restores upgraded capacities for both equipped guns")
	sim.progression.data.magazines.rifle_magazine = 10
	check(preload("res://scripts/preparation_catalog.gd").description(sim,"rifle_magazine").begins_with("LV MAX") and not preload("res://scripts/preparation_catalog.gd").available(sim,"rifle_magazine"),"Maximum magazine level displays LV MAX and disables the interaction")
	game.return_home()
	check(game.ui.menu.find_children("*","Button",true,false).all(func(button): return not button.text.contains("多人")),"Homepage has no multiplayer entry")
	game.queue_free()
	print("INCREMENTAL PROGRESSION: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
