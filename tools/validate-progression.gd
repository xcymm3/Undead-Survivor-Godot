extends SceneTree
const Fixture = preload("res://tools/preparation-fixture.gd")
const Store = preload("res://scripts/progression_store.gd")
class SlowRegen extends "res://scripts/progression_store.gd":
	func regen_rate() -> float: return .2

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
	validate_talent_economy()
	var data = root.get_node("Data")
	var profile = Store.new()
	check(Store.valid(profile.data) and profile.data.coins == 0 and profile.data.diamonds == 0,"Fresh progress starts without currencies")
	check(not profile.purchase("rifle") and profile.level("rifle") == 0,"Insufficient coins cannot purchase an upgrade")
	check(not profile.data.ultimate_unlocked and profile.grenade_capacity() == 0,"Fresh progress has neither the ultimate unlock nor grenade capacity")
	for kind in Store.COIN_REWARDS:
		check(profile.award_kill(kind) == Store.COIN_REWARDS[kind],"Reward tier: "+kind)
	var expected_rewards = {"normal":1,"cone":2,"bucket":5,"imp":10,"shield":25,"berserker":100,"giant":150,"football":250,"dancer":2000}
	for kind in expected_rewards: check(Store.COIN_REWARDS[kind] == expected_rewards[kind],"Authored staircase reward: "+kind)
	var defense_population = preload("res://scripts/defense_population.gd")
	var expected_wave_rewards = [20,45,160,258,452,535,889,765,1140,3480]
	var wave_income_total = 0
	for wave in range(1,11):
		var income = 0
		for kind in defense_population.roster(wave,1,RandomNumberGenerator.new()): income += Store.COIN_REWARDS[kind]
		wave_income_total += income
		check(income == expected_wave_rewards[wave-1],"Staircase reward total for wave "+str(wave))
	check(wave_income_total == 7744 and Store.UPGRADE_PRICES.reduce(func(total,value): return total+value,0) == 6375,"One complete campaign funds all ten rifle upgrades with 1369 coins to spare")
	profile.data.coins = 100000
	for id in Store.WEAPONS:
		check(profile.cost(id) == 25 and profile.purchase(id) and profile.cost(id) == 100,"First weapon upgrade uses the next fixed price: "+id)
		check(profile.purchase(id) and is_equal_approx(profile.weapon_multiplier(id),1.44 if id == "axe" else 1.5625),"Gun damage compounds by twenty-five percent; axe keeps twenty percent: "+id)
	for count in range(1,5):
		check(profile.cost("grenade") == [300,450,650,1000][count-1] and profile.purchase("grenade") and profile.grenade_capacity() == count,"Grenade capacity increases to "+str(count))
	check(not profile.purchase("grenade") and profile.cost("grenade") == -1,"Grenade capacity cannot exceed four")
	for id in Store.BUILDINGS:
		check(profile.cost(id) == 25,"Each building uses its confirmed manufacturing price: "+id)
		check(not profile.owned(id) and profile.purchase(id) and profile.owned(id),"Manufacturing grants persistent ownership: "+id)
		check(profile.purchase(id) and profile.cost(id) == 100 and is_equal_approx(profile.building_multiplier(id),1.25),"Building upgrade compounds and uses fixed prices: "+id)
	for id in Store.MINES:
		var coins: int = profile.data.coins
		check(not profile.owned(id) and profile.cost(id) == Store.MINE_PRICES[id] and profile.purchase(id) and profile.data.coins == coins-Store.MINE_PRICES[id],"Mine uses its distance-tier purchase price: "+id)
		check(profile.owned(id) and profile.level(id) == 0 and profile.cost(id) == -1 and not profile.purchase(id),"Owned mines cannot be bought again or upgraded: "+id)
	for id in Store.TALENTS:
		profile.data.diamonds = 15
		for rank in range(1,6):
			check(profile.cost(id) == [1,2,3,4,5][rank-1] and profile.purchase(id),"Talent rank costs its rank: "+id+str(rank))
		check(profile.data.diamonds == 0 and profile.level(id) == 5 and not profile.purchase(id),"Five ranks consume exactly fifteen diamonds: "+id)
	check(profile.max_health() == 150 and profile.regen_rate() == 2.5 and is_equal_approx(profile.damage_multiplier(),1.5) and is_equal_approx(profile.ultimate_cooldown_multiplier(),.5) and profile.reserve_magazines() == 16 and is_equal_approx(profile.coin_multiplier(),2.0),"Max talents apply the confirmed values")
	for rank in range(11):
		check(profile.magazine_capacity("rifle",30,rank) == 30+5*rank and profile.magazine_capacity("pistol",15,rank) == 15+3*rank,"Fixed magazine capacities at rank "+str(rank))
	var capped = Store.new()
	capped.data.coins = Store.MAX_CURRENCY
	for id in Store.WEAPONS+Store.MAGAZINES+Store.BUILDINGS:
		if id in Store.BUILDINGS: check(capped.purchase(id),"Cap fixture manufactures "+id)
		for rank in range(1,11): check(capped.cost(id) == [25,100,150,200,300,450,650,1000,1500,2000][rank-1] and capped.purchase(id) and capped.level(id) == rank,"Upgrade purchases through rank ten: "+id+str(rank))
		var wallet: int = capped.data.coins
		check(capped.cost(id) == -1 and not capped.purchase(id) and capped.data.coins == wallet,"Rank eleven is blocked without payment: "+id)
	check(capped.magazine_capacity("rifle",30) == 80 and capped.magazine_capacity("pistol",15) == 45,"Magazine capacity adds fixed rounds independently to rank ten")
	# Unique temporary files exercise actual JSON writes without touching player saves.
	var path = OS.get_cache_dir().path_join("undead-progress-qa-"+str(Time.get_ticks_usec())+".json")
	var saved = Store.new(path)
	saved.data.coins = 200
	saved.dirty = true
	check(saved.save() and saved.purchase("rifle"),"Permanent transaction writes its upgraded state")
	var reloaded = Store.new(path)
	check(reloaded.data.coins == 175 and reloaded.level("rifle") == 1 and reloaded.cost("rifle") == 100,"Reload restores coins, levels and subsequent prices")
	check(reloaded.purchase("rifle"),"Reloaded progress remains purchasable")
	var bad = FileAccess.open(path,FileAccess.WRITE)
	bad.store_string("{broken")
	bad.close()
	var recovered = Store.new(path)
	check(recovered.data.coins == 175 and recovered.level("rifle") == 1 and not recovered.notice.is_empty(),"Corrupt primary save recovers the last complete backup")
	check(recovered.save() and Store.new(path).data.coins == 175,"Recovered state repairs the primary save")
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
	check(migrated.data.version == Store.SAVE_VERSION and Store.valid(migrated.data) and migrated.data.coins == 321 and migrated.data.diamonds == 7 and migrated.level("rifle") == 3 and migrated.level("pistol") == 4 and migrated.level("strong") == 2 and migrated.level("bridge_gate") == 2,"Migration preserves old currencies, talents and building upgrades")
	check(migrated.owned("crystal_mine") and not migrated.owned("ramp_mine") and not migrated.owned("gate_mine") and not migrated.owned("bridge_entry_gate"),"Old free mine is retained while new defenses require purchase")
	check(migrated.dirty and migrated.save() and Store.new(path).data == migrated.data,"Migrated progress persists and reloads without repeating migration")
	var corrupt_primary = FileAccess.open(path,FileAccess.WRITE)
	corrupt_primary.store_string("{broken")
	corrupt_primary.close()
	var legacy_backup = Store.new(path)
	check(legacy_backup.owned("crystal_mine") and legacy_backup.data.version == Store.SAVE_VERSION and legacy_backup.level("bridge_gate") == 2,"Recovery also migrates a valid old-format backup")
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
	check(upgraded_v2.data.version == Store.SAVE_VERSION and upgraded_v2.level("pistol") == 7 and upgraded_v2.data.coins == 1234 and upgraded_v2.data.diamonds == 9 and not upgraded_v2.data.weapons.has("revolver"),"Version-two saves migrate revolver upgrades without losing currencies")
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
	check(migrated_v3.data.version == Store.SAVE_VERSION and migrated_v3.data.coins == 555 and migrated_v3.level("rifle") == 10 and migrated_v3.level("bridge_gate") == 10 and migrated_v3.data.magazines == {"rifle_magazine":0,"pistol_magazine":0},"Old saves gain zero magazine levels and clamp previous upgrades to the new ten-level limit")
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
	preload("res://tools/preparation-fixture.gd").skip_tutorial(game.sim) # Fixture starts after the narrative intro.
	await physics_frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	check(sim.defense.structures.all(func(item): return item.hp == 0 and not item.owned),"Fresh player owns no turrets, gates or mines")
	var view = game.arena.scenery.structure_view
	check(view.actors.turret_left.root.visible and view.actors.turret_left.body.collision_layer == 0 and view.actors.bridge_gate.root.visible,"Unowned buildings show nonblocking construction ghosts")
	check(view.actors.bridge_entry_gate.root.visible and view.actors.bridge_entry_gate.body.collision_layer == 0 and Store.MINES.all(func(id): return view.actors[id].root.visible and view.actors[id].ghost),"Unlocked unbuilt gates and mines show construction ghosts")
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
	check(game.arena.scenery.preparation.stations.has("strong"),"Strong has a physical station")
	check(Fixture.buy(sim,p,"strong") and sim.progression.level("strong") == 1 and p.max_hp == 110 and p.hp == 60,"Medical station raises maximum and current health")
	check(Fixture.buy(sim,p,"precise") and Fixture.buy(sim,p,"swift") and Fixture.buy(sim,p,"supply"),"Each talent upgrades at its own station")
	check(p.reserves[0] == 240 and p.reserves[2] == 120,"Supply increases both finite reserves")
	for rank in range(2,6): check(Fixture.buy(sim,p,"supply"),"Additional Supply purchase "+str(rank))
	check(p.reserves[0] == 480 and p.reserves[2] == 240,"Repeated Supply purchases retain exact reserve rounding")
	check(is_equal_approx(sim.weapon_damage(data.weapons[0],false),165.0) and is_equal_approx(sim.weapon_damage(data.weapons[0],true),330.0),"Instinct increases both body and head damage without changing base headshot ratio")
	check(Fixture.buy(sim,p,"grenade") and p.grenades == 1 and p.grenade_capacity == 1,"Capacity purchase immediately grants its extra grenade")
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
	check(manager.find("bridge_gate").max_hp == 625 and is_equal_approx(manager.find("turret_left").damage_multiplier,1.25) and manager.find("turret_right").hp == 0,"Purchased building upgrades affect only their owned targets")
	check(manager.find("bridge_entry_gate").max_hp == 625 and sim.progression.cost("bridge_entry_gate") == 100,"Bridge-end gate uses the weapon upgrade price and uses the next fixed price")
	check(view.actors.turret_left.root.visible and view.actors.turret_left.body.collision_layer == 1 and view.actors.bridge_gate.root.visible,"Manufacturing creates visible native building collision")
	var turret: Dictionary = manager.find("turret_left")
	sim.spawn(turret.pos+Vector2(0,4),"normal")
	var target: Dictionary = sim.zombies[-1]
	target.body = 10000.0
	target.hp = 10000.0
	manager.step_turret(turret,.01)
	check(is_equal_approx(target.hp,9925),"Upgraded turret actually deals seventy-five damage independently of player weapon and headshot upgrades")
	sim.zombies.clear()
	sim.enter_combat(p)
	sim.update_defense_regen(p,5)
	check(p.hp == 60,"Strong waits all five combat seconds")
	sim.update_defense_regen(p,.4)
	sim.update_defense_regen(p,.6)
	check(is_equal_approx(p.hp,60.5) and is_zero_approx(p.regen_credit),"Strong accumulates half a health per second at rank one")
	p.protection = 0
	sim.damage_pawn(p,{"pos":p.pos+Vector2(0,1),"id":99},10)
	sim.update_defense_regen(p,4.9)
	check(is_equal_approx(p.hp,50.5),"Taking damage restarts the five-second delay")
	sim.fire(p,data.weapons[0])
	sim.update_defense_regen(p,4.9)
	check(is_equal_approx(p.hp,52.9),"Attacking permits healing after five seconds without incoming damage")
	sim.update_defense_regen(p,2)
	check(is_equal_approx(p.hp,53.9),"Healing continues while attacking")
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
	var original_profile = sim.progression
	sim.progression = SlowRegen.new()
	p.hp = 60.0
	p.combat_remaining = 0
	for tick in 10: sim.update_defense_regen(p,.1)
	check(is_equal_approx(p.hp,60.2) and "%d" % p.hp == "60","A 0.2/s rate heals exactly 0.2 per second while displayed health remains an integer")
	p.protection = 0
	sim.damage_pawn(p,{"pos":p.pos+Vector2(0,1),"id":99},10)
	check(is_equal_approx(p.hp,50.2),"Incoming damage preserves fractional health")
	sim.update_defense_regen(p,5)
	check(is_equal_approx(p.hp,50.2),"Combat delay does not erase already healed fractional health")
	sim.progression = original_profile

	p.hp = 100
	game.resume_game()
	sim.spawn(Vector2(12,25),"bucket")
	var z: Dictionary = sim.zombies[-1]
	var greedy_coins: float = sim.progression.data.coins
	check(Fixture.buy(sim,p,"greed") and sim.progression.level("greed") == 1,"Greed can be purchased at its new station")
	check(game.arena.scenery.preparation.stations.has("greed"),"Greed has its own physical station")
	sim.spawn(Vector2(12,25),"normal")
	var greedy_enemy: Dictionary = sim.zombies[-1]
	sim.hit_enemy(greedy_enemy,10000,false,p,Vector3(12,4,25))
	check(is_equal_approx(sim.progression.data.coins,greedy_coins+1.2) and is_equal_approx(sim.earned_coins,1.2),"Authority retains fractional Greed wallet and session rewards")
	game.ui.native_hud.sync()
	check(game.ui.native_hud.currency_label.text == str(floori(greedy_coins+1.2)),"Top-right coin HUD displays only the integer part")
	sim.progression.data.talents.greed = 0
	sim.progression.data.coins = greedy_coins
	sim.earned_coins = 0.0
	sim.coin_drops.clear()
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
	p.slot_reserves = [23,510]
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
	check(p.ammo[0] == 7 and p.reserves[0] == 23 and p.reserves[2] == 510 and p.slot_reserves == [23,510] and p.reserve == 23,"Clearing a wave awards no ammunition and preserves loaded rounds")
	sim.equipment.select_weapon_slot(p,2)
	check(p.reserves[2] == 510 and p.reserve == 510,"Switching guns preserves above-capacity wave ammunition")
	check(not sim.purchase_upgrade("rifle",p),"Shop stays closed after clearing a wave")
	sim.defense.wave = 2
	sim.defense_director.begin_wave()
	check(manager.find("bridge_gate").hp == 0 and p.grenades == 0 and p.reserves[0] == 83 and p.reserves[2] == 540,"Second wave start adds two magazines while preserving destroyed buildings and spent grenades")
	sim.defense_director.begin_wave()
	check(p.reserves[0] == 83 and p.reserves[2] == 540,"Repeated launch of the same wave cannot grant ammunition twice")
	var permanent = sim.progression.data.duplicate(true)
	game.start_solo("defense",42)
	preload("res://tools/preparation-fixture.gd").skip_tutorial(game.sim) # Fixture starts after the narrative intro.
	await physics_frame
	sim = game.sim
	p = game.local_pawn()
	check(sim.wave == 1 and sim.progression.data == permanent and not sim.defense.started and sim.defense.crystal_repair_required,"Restart resets combat and reopens shop while preserving permanent progress")
	check(p.hp == 110 and p.ammo[0] == 30 and p.reserves[0] == 480 and p.reserves[2] == 240,"Restart restores ammunition using upgraded Supply")
	sim.defense_director.begin_wave()
	sim.roster.clear()
	sim.step(.02)
	check(sim.progression.data.diamonds == diamonds+2,"Replaying wave one earns another diamond")
	check(p.reserves[0] == 480 and p.reserves[2] == 240,"Replayed first wave grants no extra ammunition")
	sim.defense.wave = 2
	sim.defense_director.begin_wave()
	sim.roster.clear()
	sim.defense.crystal_hp = 0
	sim.step(.02)
	check(sim.failed and sim.progression.data.diamonds == diamonds+2,"A failed wave awards no diamond")
	check(p.reserves[0] == 540 and p.reserves[2] == 270,"Failure grants no additional ammunition after the second-wave start grant")
	game.ui.native_hud.sync()
	check(game.ui.native_hud.currency_label.text == str(floori(sim.progression.data.coins)),"Top-right HUD shows permanent currency")
	root.get_node("Progress").store = Store.new()
	game.start_solo("defense",913)
	preload("res://tools/preparation-fixture.gd").skip_tutorial(game.sim) # Fixture starts after the narrative intro.
	await physics_frame
	sim = game.sim
	p = game.local_pawn()
	sim.progression.data.coins = 100000
	check(game.arena.scenery.preparation.stations.has("rifle_magazine") and not game.arena.scenery.preparation.stations.has("pistol_magazine"),"Both magazine upgrades share one physical preparation station")
	Fixture.face(sim,p,"rifle_magazine")
	Fixture.hold(sim,p,.99)
	check(sim.progression.level("rifle_magazine") == 0,"A hold shorter than one second cannot buy")
	Fixture.hold(sim,p,.011)
	check(sim.progression.level("rifle_magazine") == 1 and sim.weapon_capacity(0) == 35 and p.ammo[0] == 30 and p.reserves[0] == 210,"One-second hold buys rifle capacity without manufacturing extra loaded ammunition")
	Fixture.hold(sim,p,1.1)
	check(sim.progression.level("rifle_magazine") == 1,"Continued hold cannot repeatedly purchase")
	p.input = {}
	sim.defense_director.interactions(.01)
	check(Fixture.buy(sim,p,"pistol_magazine") and sim.weapon_capacity(2) == 18 and p.ammo[2] == 15 and p.reserves[2] == 108,"Pistol magazine has an independent eighteen-round first upgrade")
	sim.progression.data.diamonds = 100
	check(Fixture.buy(sim,p,"supply") and p.reserves[0] == 280 and p.reserves[2] == 144,"Supply after capacity uses eight upgraded magazines")
	check(Fixture.buy(sim,p,"rifle_magazine") and p.reserves[0] == 320 and p.ammo[0] == 30,"Capacity after Supply adds eight times the five-round increment without filling loaded ammo")
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
	check(p.reserves[0] == 140 and p.reserves[2] == 118,"Wave-start grant uses two upgraded reserve magazines per gun")
	var capacity_state = sim.progression.data.duplicate(true)
	game.start_solo("defense",913)
	preload("res://tools/preparation-fixture.gd").skip_tutorial(game.sim) # Fixture starts after the narrative intro.
	await physics_frame
	sim = game.sim
	p = game.local_pawn()
	check(sim.progression.data == capacity_state and p.ammo[0] == 40 and p.ammo[2] == 18 and p.slot_ammo == [40,18] and p.reserves[0] == 320 and p.reserves[2] == 144,"Restart restores upgraded capacities for both equipped guns")
	sim.progression.data.magazines.rifle_magazine = 10
	check(preload("res://scripts/preparation_catalog.gd").description(sim,"rifle_magazine").begins_with("LV MAX") and not preload("res://scripts/preparation_catalog.gd").available(sim,"rifle_magazine"),"Maximum magazine level displays LV MAX and disables the interaction")
	validate_instinct(sim,p)
	game.return_home()
	check(not game.ui.menu.find_children("*","Button",true,false).any(func(button): return button.text == "多人游戏"),"Demo homepage exposes single player only")
	game.queue_free()
	print("INCREMENTAL PROGRESSION: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)

func validate_talent_economy() -> void:
	var profile = Store.new()
	var path = OS.get_cache_dir().path_join("undead-talents-qa-"+str(Time.get_ticks_usec())+".json")
	var legacy = Store.defaults()
	legacy.version = 6
	legacy.coins = 123
	legacy.talents.erase("greed")
	legacy.talents.precise = 3
	legacy.talents.swift = 4
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated = Store.new(path)
	check(migrated.data.version == Store.SAVE_VERSION and migrated.level("precise") == 3 and migrated.level("swift") == 4 and migrated.level("greed") == 0 and migrated.data.coins == 123,"Version six retains old talent levels and adds zero Greed")
	var v7 = Store.defaults()
	v7.version = 7
	v7.erase("ultimate_unlocked")
	file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(v7))
	file.close()
	check(not Store.new(path).data.ultimate_unlocked,"An untouched version-seven save still receives the new skill tutorial")
	v7.tutorial_stage = 5
	file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(v7))
	file.close()
	check(Store.new(path).data.ultimate_unlocked,"A veteran version-seven save keeps access to the formerly available skill")
	check(is_equal_approx(migrated.damage_multiplier(),1.3) and is_equal_approx(preload("res://scripts/ultimate.gd").cooldown(migrated),60),"Inherited levels use Instinct and ultimate cooldown effects")
	for rank in range(6):
		for id in Store.TALENTS: profile.data.talents[id] = rank
		check(is_equal_approx(profile.regen_rate(),.5*rank) and is_equal_approx(profile.damage_multiplier(),1+.1*rank) and profile.reserve_magazines() == 6+2*rank and is_equal_approx(preload("res://scripts/ultimate.gd").cooldown(profile),100-10*rank) and is_equal_approx(profile.coin_multiplier(),1+.2*rank),"All talent curves at rank "+str(rank))
	profile.data.talents.greed = 1
	profile.data.coins = 0
	for i in 10: profile.award_kill("normal")
	check(is_equal_approx(profile.data.coins,12),"Ten 1.2 rewards accumulate to exactly twelve displayable coins")
	profile.path = path
	profile.data.coins = 50.5
	check(profile.save() and Store.new(path).data.coins == 50.5,"Fractional coins survive JSON save and reload")
	check(profile.purchase("rifle") and is_equal_approx(profile.data.coins,25.5) and is_equal_approx(Store.new(path).data.coins,25.5),"Coin purchases preserve fractional change through reload")
	profile.data.coins = 24.9
	check(not profile.purchase("pistol") and is_equal_approx(profile.data.coins,24.9),"Fractional wallet cannot buy an unaffordable upgrade")
	for invalid in [-.1,INF,NAN,"1.5"]:
		var bad = Store.defaults()
		bad.coins = invalid
		check(not Store.valid(bad),"Invalid fractional currency is rejected")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)

func validate_instinct(sim, p: Dictionary) -> void:
	var original_rank: int = sim.progression.level("precise")
	var data = root.get_node("Data")
	sim.progression.data.talents.precise = 5
	for index in [0,2,6]:
		var w: Dictionary = data.weapons[index]
		var base: float = float(w.damage)*sim.progression.weapon_multiplier(w.id)
		check(is_equal_approx(sim.weapon_damage(w,false),base*1.5),"Maximum Instinct increases weapon body damage: "+w.id)
	var blade: Dictionary = data.weapons[6].duplicate(true)
	blade.id = "ultimate"
	blade.damage = 300
	check(is_equal_approx(sim.weapon_damage(blade,false),450),"Instinct increases long blade damage")
	sim.zombies.clear()
	sim.spawn(Vector2(24,0),"giant")
	var z: Dictionary = sim.zombies[-1]
	var hp: float = z.hp
	sim.equipment.explode({"owner":p.id,"pos":Vector3(24,4,0)})
	check(is_equal_approx(hp-z.hp,2100),"Instinct increases player grenade damage by fifty percent")
	hp = z.hp
	sim.equipment.explode({"owner":"crystal_mine","pos":Vector3(24,4,0)})
	check(is_equal_approx(hp-z.hp,1400),"Mine damage remains independent of Instinct")
	sim.progression.data.talents.precise = original_rank
