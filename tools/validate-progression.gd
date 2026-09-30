extends SceneTree
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
	profile.data.coins = 100000
	for id in Store.WEAPONS:
		check(profile.cost(id) == 20 and profile.purchase(id) and profile.cost(id) == 40,"First weapon upgrade doubles its next cost: "+id)
		check(profile.purchase(id) and is_equal_approx(profile.weapon_multiplier(id),1.21),"Weapon damage compounds by ten percent: "+id)
	for count in range(2,6):
		check(profile.purchase("grenade") and profile.grenade_capacity() == count,"Grenade capacity increases to "+str(count))
	check(not profile.purchase("grenade") and profile.cost("grenade") == -1,"Grenade capacity cannot exceed five")
	for id in Store.BUILDINGS:
		check(not profile.owned(id) and profile.purchase(id) and profile.owned(id),"Manufacturing grants persistent ownership: "+id)
		var first: int = profile.cost(id)
		check(profile.purchase(id) and profile.cost(id) == first*2 and is_equal_approx(profile.building_multiplier(id),1.1),"Building upgrade compounds and doubles cost: "+id)
	for id in Store.TALENTS:
		profile.data.diamonds = 55
		for rank in range(1,11):
			check(profile.cost(id) == rank and profile.purchase(id),"Talent rank costs its rank: "+id+str(rank))
		check(profile.data.diamonds == 0 and profile.level(id) == 10 and not profile.purchase(id),"Ten ranks consume exactly fifty-five diamonds: "+id)
	check(profile.max_health() == 200 and profile.regen_rate() == 10 and is_equal_approx(profile.head_multiplier(),2) and is_equal_approx(profile.move_multiplier(),1.5) and is_equal_approx(profile.reserve_multiplier(),2),"Max talents apply the confirmed values")
	# Unique temporary files exercise actual JSON writes without touching player saves.
	var path = OS.get_cache_dir().path_join("undead-progress-qa-"+str(Time.get_ticks_usec())+".json")
	var saved = Store.new(path)
	saved.data.coins = 100
	saved.dirty = true
	check(saved.save() and saved.purchase("rifle"),"Permanent transaction writes its upgraded state")
	var reloaded = Store.new(path)
	check(reloaded.data.coins == 80 and reloaded.level("rifle") == 1 and reloaded.cost("rifle") == 40,"Reload restores coins, levels and subsequent prices")
	check(reloaded.purchase("rifle"),"Reloaded progress remains purchasable")
	var bad = FileAccess.open(path,FileAccess.WRITE)
	bad.store_string("{broken")
	bad.close()
	var recovered = Store.new(path)
	check(recovered.data.coins == 80 and recovered.level("rifle") == 1 and not recovered.notice.is_empty(),"Corrupt primary save recovers the last complete backup")
	check(recovered.save() and Store.new(path).data.coins == 80,"Recovered state repairs the primary save")
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
	check(sim.defense.structures.filter(func(item): return item.kind != "mine").all(func(item): return item.hp == 0 and not item.owned),"Fresh player owns no turrets or gate")
	var view = game.arena.scenery.structure_view
	check(not view.actors.turret_left.root.visible and view.actors.turret_left.body.collision_layer == 0 and not view.actors.bridge_gate.root.visible,"Unowned buildings are invisible and have no collision")
	check(game.arena.scenery.find_children("WeaponDisplay*","Node3D",true,false).is_empty() and game.arena.scenery.has_node("ShopCounter"),"Armory gun racks are replaced by the shop counter")
	p.hp = 50
	sim.update_defense_regen(p,100)
	check(p.hp == 50,"No Strong talent means no automatic healing")
	sim.progression.data.coins = 10000
	sim.progression.data.diamonds = 100
	check(game.open_shop() and game.paused,"Pre-wave shop is reachable from spawn")
	var rifle_button = game.ui.menu.find_child("Purchase_rifle",true,false)
	rifle_button.pressed.emit()
	check(sim.progression.level("rifle") == 1 and game.ui.menu.find_child("Purchase_rifle",true,false).text.contains("40"),"Native shop purchase updates permanent damage level and next price")
	game.ui.shop_tab = "diamonds"
	game.ui.show_shop()
	check(game.ui.menu.find_children("Purchase_*","Button",true,false).size() == 4,"Diamond tab exposes exactly four talents")
	game.ui.menu.find_child("Purchase_strong",true,false).pressed.emit()
	check(sim.progression.level("strong") == 1 and p.max_hp == 110 and p.hp == 60,"Native Strong purchase raises maximum and current health by ten")
	check(sim.purchase_upgrade("precise",p) and sim.purchase_upgrade("swift",p) and sim.purchase_upgrade("supply",p),"All four talents are available in preparation")
	check(p.reserves[0] == 561 and p.reserves[3] == 112,"Supply increases both finite reserves")
	for rank in range(2,11): check(sim.purchase_upgrade("supply",p),"Additional Supply purchase "+str(rank))
	check(p.reserves[0] == 1020 and p.reserves[3] == 204,"Repeated Supply purchases retain exact reserve rounding")
	check(is_equal_approx(sim.weapon_damage(data.weapons[0],false),132) and is_equal_approx(sim.weapon_damage(data.weapons[0],true),290.4),"Player damage combines weapon and headshot talent upgrades")
	check(sim.purchase_upgrade("grenade",p) and p.grenades == 2 and p.grenade_capacity == 2,"Capacity purchase immediately grants its extra grenade")
	check(sim.purchase_upgrade("turret_left",p) and sim.purchase_upgrade("turret_left",p) and sim.purchase_upgrade("bridge_gate",p) and sim.purchase_upgrade("bridge_gate",p),"Buildings can be manufactured then upgraded")
	var manager = sim.defense_director.structures
	check(manager.find("bridge_gate").max_hp == 1100 and is_equal_approx(manager.find("turret_left").damage_multiplier,1.1) and manager.find("turret_right").hp == 0,"Purchased building upgrades affect only their owned targets")
	check(view.actors.turret_left.root.visible and view.actors.turret_left.body.collision_layer == 1 and view.actors.bridge_gate.root.visible,"Manufacturing creates visible native building collision")
	var turret: Dictionary = manager.find("turret_left")
	sim.spawn(turret.pos+Vector2(0,4),"normal")
	var target: Dictionary = sim.zombies[-1]
	target.body = 10000.0
	target.hp = 10000.0
	manager.step_turret(turret,.01)
	check(is_equal_approx(target.hp,9934),"Upgraded turret actually deals sixty-six damage independently of player weapon and headshot upgrades")
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
	check(p.hp == 51,"Attacking also restarts the combat delay")
	sim.update_defense_regen(p,2)
	check(p.hp == 52,"Healing resumes after the remaining combat delay")
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
	check(sim.progression.data.coins == coins_before+3 and sim.coin_drops.size() == 1,"A kill pays its original tier exactly once")
	var initial_coin: Vector3 = sim.coin_drops[0].pos
	sim.step_coins(.2)
	check(sim.coin_drops[0].pos.distance_to(Vector3(p.pos.x,p.height+1.05,p.pos.y)) < initial_coin.distance_to(Vector3(p.pos.x,p.height+1.05,p.pos.y)),"Coin magnet moves the drop toward the player")
	sim.step_coins(5)
	check(sim.coin_drops.is_empty() and sim.progression.data.coins == coins_before+3,"Cosmetic pickup removal cannot pay coins again")
	p.ammo[0] = 7
	p.reserves[0] = 23
	p.reserves[3] = 204
	sim.equipment.save_weapon_slot(p)
	sim.defense_director.begin_wave()
	check(p.hp == 110 and p.ammo[0] == 7 and p.reserves[0] == 23,"New wave fully heals but preserves spent firearm inventory")
	var money: int = sim.progression.data.coins
	check(not sim.purchase_upgrade("rifle",p) and not game.open_shop() and sim.progression.data.coins == money,"Active-wave shop transactions are rejected")
	manager.damage("bridge_gate",1100)
	sim.roster.clear()
	sim.zombies.clear()
	var diamonds: int = sim.progression.data.diamonds
	sim.step(.02)
	sim.defense_director.finish_wave()
	check(sim.progression.data.diamonds == diamonds+1 and sim.cleared == 1,"Successful wave rewards exactly one diamond, even if completion is repeated")
	check(p.ammo[0] == 7 and p.reserves[0] == 83 and p.reserves[3] == 216 and p.slot_reserves == [83,216] and p.reserve == 83,"Clear rewards two reserve magazines once for both guns, above capacity without filling the magazine")
	sim.equipment.select_weapon_slot(p,2)
	check(p.reserves[3] == 216 and p.reserve == 216,"Switching guns preserves above-capacity wave ammunition")
	check(not sim.purchase_upgrade("rifle",p),"Shop stays closed after clearing a wave")
	sim.defense_director.begin_wave()
	check(manager.find("bridge_gate").hp == 1100 and p.grenades == 2 and p.reserves[0] == 83 and p.reserves[3] == 216,"Next wave restores purchased buildings and grenades without granting ammunition again")
	var permanent = sim.progression.data.duplicate(true)
	game.start_solo("defense",42)
	await physics_frame
	sim = game.sim
	p = game.local_pawn()
	check(sim.wave == 1 and sim.progression.data == permanent and sim.shop_available(p),"Restart resets combat and reopens shop while preserving permanent progress")
	check(p.hp == 110 and p.ammo[0] == 30 and p.reserves[0] == 1020 and p.reserves[3] == 204,"Restart restores ammunition using upgraded Supply")
	sim.defense_director.begin_wave()
	sim.roster.clear()
	sim.step(.02)
	check(sim.progression.data.diamonds == diamonds+2,"Replaying wave one earns another diamond")
	check(p.reserves[0] == 1080 and p.reserves[3] == 216,"A new match can earn the same first-wave ammo reward again")
	sim.defense_director.begin_wave()
	sim.roster.clear()
	sim.defense.crystal_hp = 0
	sim.step(.02)
	check(sim.failed and sim.progression.data.diamonds == diamonds+2,"A failed wave awards no diamond")
	check(p.reserves[0] == 1080 and p.reserves[3] == 216,"A failed wave awards no ammunition")
	game.ui.native_hud.sync()
	check(game.ui.native_hud.currency_label.text.contains(str(sim.progression.data.coins)),"Top-right HUD shows permanent currency")
	game.return_home()
	check(game.ui.menu.find_children("*","Button",true,false).all(func(button): return not button.text.contains("多人")),"Homepage has no multiplayer entry")
	game.queue_free()
	print("INCREMENTAL PROGRESSION: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
