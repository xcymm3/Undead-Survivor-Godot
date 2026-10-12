extends SceneTree
const Store = preload("res://scripts/progression_store.gd")
const Boss = preload("res://scripts/dancer_boss.gd")
var checks = 0
var failures = 0

func check(value: bool, caption: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(caption)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var data = root.get_node("Data")
	var progress = root.get_node("Progress")
	var directory = "res://artifacts/slot-qa-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var manager = load("res://scripts/progression.gd").new()
	manager.configure(directory)
	check(manager.slots.size() == 3 and manager.slots.all(func(slot): return slot.data == Store.defaults()),"Three slots start from independent zero progress")
	manager.store.data.coins = 100
	manager.store.dirty = true
	check(manager.store.purchase("rifle") and manager.select_slot(1),"Switching saves the current slot before selecting another")
	check(manager.store.data.coins == 0 and manager.store.level("rifle") == 0,"Second slot does not inherit money or upgrades")
	manager.store.data.coins = 45
	manager.store.dirty = true
	check(manager.select_slot(2) and manager.store.data.coins == 0,"Third slot also starts at zero")
	var reopened = load("res://scripts/progression.gd").new()
	reopened.configure(directory)
	check(reopened.active_slot == 2 and reopened.slots[0].data.coins == 80 and reopened.slots[0].level("rifle") == 1 and reopened.slots[1].data.coins == 45,"Restart restores the selected slot and separate progress files")
	check(not reopened.select_slot(-1) and not reopened.select_slot(3) and reopened.active_slot == 2,"Invalid slots cannot change active progress")
	reopened.selection_path = directory.path_join("absent/selection.json")
	check(not reopened.select_slot(0) and reopened.active_slot == 2,"Failed slot selection write leaves the active slot intact")
	manager.free()
	reopened.free()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	check(game.ui.menu.has_node("InfiniteCoins") or game.ui.menu.find_child("InfiniteCoins",true,false) != null,"Homepage exposes the test-money checkbox")
	check(game.ui.menu.find_children("*","Button",true,false).any(func(button): return button.text.contains("切换存档")),"Homepage exposes save-slot selection")
	data.test_money = true
	game.start_solo("defense",20261012)
	await physics_frame
	check(game.sim.progression.data.coins == 1000000000,"Test-money checkbox configures one billion coins on entry")
	game.return_home()
	data.test_money = false
	game.select_save_slot(1)
	await physics_frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	check(progress.active_slot == 1 and sim.progression == progress.store and sim.wave == 1 and not sim.defense.started and sim.progression.data.coins == 0,"Selecting a new save creates a fresh preparation match")
	var environment = game.arena.find_children("*","WorldEnvironment",true,false)[0].environment
	check(environment.background_color.v < .2 and environment.ambient_light_energy <= .25 and game.arena.sun.light_energy < .4,"Native terrain uses night sky and moonlit exposure")
	check(game.sound.streams.disco.get_length() >= 2.99 and game.sound.streams.disco.get_length() <= 3.01,"Boss has an independent three-second disco resource")
	game.ui.show_preparation()
	check(game.ui.menu.find_children("*","Button",true,false).any(func(button): return button.text == "开始进攻"),"Preparation offers a visible first-wave start button")
	sim.progression.data.coins = 1000
	check(sim.purchase_upgrade("turret_left",p),"Shop manufactures a turret before combat")
	check(not sim.purchase_upgrade("turret_left",p),"Built turret cannot upgrade remotely from the shop")
	var turret: Dictionary = sim.defense_director.structures.find("turret_left")
	p.pos = turret.pos+Vector2(0,2)
	p.height = 3
	sim.events.clear()
	sim.submit(p.id,{"interact":true})
	sim.defense_director.interactions(.016)
	check(sim.events.any(func(event): return event.kind == "structure_open" and event.id == "turret_left"),"Authority E interaction beside a built turret requests its upgrade panel")
	game.handle_effects(sim.events)
	check(game.ui.current == "building", "Near a built turret the native upgrade panel opens")
	check(sim.progression.cost("turret_left") == 20 and sim.purchase_upgrade("turret_left",p) and sim.progression.cost("turret_left") == 40 and is_equal_approx(turret.damage_multiplier,1.1),"Onsite turret upgrades use gun prices and ten percent damage growth")
	p.pos = data.Maps.Defense.SPAWN
	check(sim.purchase_upgrade("bridge_gate",p),"Shop can manufacture a gate")
	var gate: Dictionary = sim.defense_director.structures.find("bridge_gate")
	p.pos = gate.pos+Vector2(0,2)
	check(sim.purchase_upgrade("bridge_gate",p) and gate.max_hp == 1100 and sim.progression.cost("bridge_gate") == 40,"Gate onsite upgrades increase durability and double the gun-equivalent price")
	check(not sim.building_available("turret_right",p),"Unbuilt structures cannot expose upgrades")
	p.pos = data.Maps.Defense.SPAWN
	p.height = 3
	sim.spawn(Vector2(8,25),"normal")
	var coin_enemy: Dictionary = sim.zombies[-1]
	var balance: int = sim.progression.data.coins
	sim.hit_enemy(coin_enemy,1000,false,p,Vector3(8,4,25))
	sim.hit_enemy(coin_enemy,1000,false,p,Vector3(8,4,25))
	check(sim.coin_drops.size() == 1 and sim.progression.data.coins == balance+1,"A death creates one coin animation and credits its reward once")
	var origin: Vector3 = sim.coin_drops[0].pos
	sim.step_coins(.2)
	check(sim.coin_drops[0].pos.y > origin.y+.7,"Coin drop first pops upward from the corpse")
	game.coins.sync(sim.coin_drops)
	check(game.coins.multimesh.visible_instance_count == 1,"Coin animation uses the native batch renderer")
	sim.step_coins(.8)
	var halfway: Vector3 = sim.coin_drops[0].pos
	check(halfway.distance_to(Vector3(p.pos.x,4.05,p.pos.y)) < origin.distance_to(Vector3(p.pos.x,4.05,p.pos.y)),"Coin follows an automatic curved attraction path")
	sim.step_coins(.7)
	check(sim.coin_drops.is_empty() and sim.progression.data.coins == balance+1,"Arrival removes the coin without a second payment")
	sim.zombies.clear()
	game.start_attack()
	check(sim.defense.started and not sim.defense.waiting and not game.paused,"First-wave button starts the authority and resumes gameplay")
	turret.hp = 50
	gate.hp = 0
	var expected: int = sim.wave_total
	for tick in 90:
		if sim.roster.is_empty(): break
		sim.defense_spawner.step(1,[p])
	check(sim.spawned == expected and sim.alive_count() == expected,"The real spawner completes wave one while its enemies remain alive")
	sim.step(.02)
	check(sim.wave == 2 and sim.alive_count() == expected and not sim.roster.is_empty(),"The next wave starts immediately after deployment without clearing living zombies")
	check(turret.hp == 50 and gate.hp == 0 and not sim.building_available("turret_left",p),"New waves preserve turret damage and destroyed gates and close onsite upgrades")
	var diamonds: int = sim.progression.data.diamonds
	var reserve: int = p.reserves[0]
	for enemy in sim.zombies: enemy.hp = 0
	sim.defense_director.reward_finished_waves()
	sim.defense_director.reward_finished_waves()
	check(sim.progression.data.diamonds == diamonds+1 and p.reserves[0] == reserve+60,"Overlapping waves reward their cleared generation exactly once")
	for generation in range(2,10):
		sim.roster.clear()
		sim.step(.02)
	check(sim.wave == 10 and sim.roster.count("dancer") == 1,"The tenth and final wave contains exactly one dancing boss")
	check(data.enemies.dancer.health == data.enemies.football.health*10,"Boss health is exactly ten football zombies")
	sim.roster.clear()
	sim.zombies.clear()
	sim.spawn(Vector2(8,23),"dancer")
	var boss: Dictionary = sim.zombies[-1]
	check(is_equal_approx(boss.chase_speed,2.1),"Dancing boss moves slowly")
	Boss.step(sim,9.9)
	check(boss.dance_remaining == 0 and boss.summon_roster.is_empty(),"Boss cannot summon before ten seconds")
	Boss.step(sim,.11)
	check(boss.dance_remaining == 3 and sim.events.any(func(event): return event.kind == "disco"),"Ten-second summon starts a stopped disco dance and audio cue")
	var ordinary: Array = boss.summon_roster.filter(func(kind): return kind in Store.COIN_REWARDS and kind in preload("res://scripts/enemy_population.gd").ORDINARY)
	var specials: Array = boss.summon_roster.filter(func(kind): return kind in preload("res://scripts/enemy_population.gd").ELITES)
	var population = preload("res://scripts/enemy_population.gd")
	check(population.points(ordinary) <= 25 and 25-population.points(ordinary) < .75 and population.points(specials) <= 25 and 25-population.points(specials) < 4,"Summons respect separate ordinary and special twenty-five-point pools")
	var boss_point: Vector2 = boss.pos
	sim.update_zombie(boss,sim.crystal_target(),.5)
	check(boss.pos == boss_point and boss.move_speed == 0,"Boss neither walks nor attacks during the summoning dance")
	sim.hit_enemy(boss,1,false,p,Vector3(8,5,23))
	check(boss.pos == boss_point and boss.hp == data.enemies.dancer.health-1,"Dance remains stationary under gunfire while still taking damage")
	var view = load("res://scripts/enemy_view.gd")
	check(view.transforms(boss,.1,false) != view.transforms(boss,.2,false),"Disco dance animates the shared rendering and CPU-hit pose")
	var planned: int = boss.summon_roster.size()
	Boss.step(sim,3)
	for tick in 20: Boss.step(sim,.016)
	var summoned: Array = sim.zombies.filter(func(enemy): return enemy.get("summoned",false))
	check(summoned.size() == planned and boss.summon_roster.is_empty(),"The full bounded summon quota appears beside the boss")
	check(summoned.all(func(enemy): return enemy.spawn_wave == 10 and enemy.pos.distance_to(boss.pos) <= 7.01 and sim.arena.clear(enemy.pos,enemy.pos)),"Summoned zombies stay on connected terrain near their owner and belong to wave ten")
	var rising: Dictionary = summoned[0]
	var below: float = view.pose_state(rising,0,false).root.origin.y
	sim.update_zombie(rising,sim.crystal_target(),1.4)
	check(view.pose_state(rising,0,false).root.origin.y > below+1 and rising.emerge_remaining == 0,"Summoned zombie rises out of the ground using the shared hit pose")
	sim.hit_enemy(boss,1000000,false,p,Vector3(8,5,23))
	var count: int = sim.zombies.size()
	Boss.step(sim,20)
	check(sim.zombies.size() == count,"Dead boss cannot summon more zombies")
	sim.step(.02)
	check(not sim.won and sim.wave == 10,"Killing the boss alone does not ignore remaining summoned enemies")
	for enemy in sim.zombies: enemy.hp = 0
	sim.step(.02)
	check(sim.won and sim.wave == 10 and sim.cleared == 10,"Clearing the final wave wins and never creates wave eleven")
	game.ui.show_result()
	check(game.ui.menu.find_children("*","Label",true,false).any(func(label): return label.text == "游戏通关"),"Native result screen explicitly displays campaign victory")
	game.return_home()
	game.queue_free()
	await process_frame
	print("CAMPAIGN VALIDATION: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
