extends SceneTree
const Store = preload("res://scripts/progression_store.gd")
const Fixture = preload("res://tools/preparation-fixture.gd")
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
	check(game.ui.menu.find_children("*","Button",true,false).any(func(button): return button.text.begins_with("存档 ")),"Homepage exposes save-slot selection")
	data.test_money = true
	game.start_solo("defense",20261012)
	await physics_frame
	check(game.sim.progression.data.coins == 1000000000 and game.sim.progression.data.diamonds == 10000,"Test-money checkbox configures one billion coins and ten thousand diamonds on entry")
	game.return_home()
	data.test_money = false
	game.select_save_slot(1)
	await physics_frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	check(p.weapon2 == 2 and p.ammo[2] == 15 and data.weapons[2].damage == 100,"Secondary pistol has a fifteen-round magazine and doubled base damage")
	p.slot = 3
	p.weapon = 6
	p.switch = 0
	sim.melee_swings[p.id] = {"elapsed":0.1}
	check(sim.try_shove(p) and p.shove_anim == .32 and not sim.melee_swings.has(p.id),"Axe shove starts the animation and cancels an unfinished melee swing")
	p.slot = 1
	p.weapon = 0
	check(progress.active_slot == 1 and sim.progression == progress.store and sim.wave == 1 and not sim.defense.started and sim.progression.data.coins == 0,"Selecting a new save creates a fresh preparation match")
	var environment = game.arena.find_children("*","WorldEnvironment",true,false)[0].environment
	check(environment.background_color.v < .2 and environment.ambient_light_energy <= .25 and game.arena.sun.light_energy < .4,"Native terrain uses night sky and moonlit exposure")
	check(game.sound.streams.disco.get_length() >= 2.99 and game.sound.streams.disco.get_length() <= 3.01,"Boss has an independent three-second disco resource")
	check(not game.paused and game.ui.current.is_empty(),"Preparation is directly controllable without a start popup")
	sim.progression.data.coins = 1000
	check(Fixture.buy(sim,p,"turret_left"),"Turret can be built at its construction point")
	p.pos = data.Maps.Defense.SPAWN
	check(not sim.purchase_upgrade("turret_left",p),"Built turret cannot upgrade remotely")
	var turret: Dictionary = sim.defense_director.structures.find("turret_left")
	Fixture.face(sim,p,"turret_left")
	sim.events.clear()
	Fixture.hold(sim,p,3.1)
	check(sim.events.any(func(event): return event.kind == "world_upgrade" and event.id == "turret_left"),"Onsite E hold generates workshop feedback")
	game.handle_effects(sim.events)
	check(game.ui.current.is_empty() and not game.paused,"Onsite upgrade keeps the player in the world")
	check(sim.progression.cost("turret_left") == 40 and is_equal_approx(turret.damage_multiplier,1.1),"Onsite upgrade adds ten percent and doubles price")
	p.pos = data.Maps.Defense.SPAWN
	check(Fixture.buy(sim,p,"bridge_gate"),"Shop can manufacture a gate")
	var gate: Dictionary = sim.defense_director.structures.find("bridge_gate")
	p.pos = gate.pos+Vector2(0,2)
	check(Fixture.buy(sim,p,"bridge_gate") and gate.max_hp == 1100 and sim.progression.cost("bridge_gate") == 40,"Gate onsite upgrades increase durability and double the gun-equivalent price")
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
	check(sim.wave == 1 and sim.alive_count() == expected and sim.roster.is_empty(),"Deployment completion begins the gap while remaining enemies stay alive")
	var deadline: float = sim.defense.next_wave_at
	check(is_equal_approx(deadline,sim.elapsed+10),"Inter-wave gap is ten simulation seconds")
	var remaining_enemy_position: Vector2 = sim.zombies[0].pos
	sim.step(9.9)
	check(sim.wave == 1 and sim.roster.is_empty(),"Next wave cannot begin before ten seconds")
	check(sim.zombies[0].pos.distance_to(remaining_enemy_position) > .1,"Remaining enemies keep moving during the inter-wave gap")
	sim.step(.1)
	check(sim.wave == 1 and sim.alive_count() == expected and sim.roster.is_empty(),"Expired gap cannot advance while ten or more enemies remain")
	for index in range(10,sim.zombies.size()): sim.zombies[index].hp = 0
	sim.step(.001)
	check(sim.wave == 1 and sim.alive_count() == 10,"Exactly ten living enemies still block the next wave")
	game.ui.native_hud.sync()
	check(game.ui.native_hud.time_label.text.contains("清理至剩余9只"),"HUD explains the population gate instead of displaying a zero-second countdown")
	sim.zombies[9].hp = 0
	sim.step(.001)
	check(sim.wave == 2 and sim.alive_count() == 9 and not sim.roster.is_empty(),"Nine remaining enemies permit the next wave after the existing gap")
	check(sim.events.count({"kind":"wave_start","position":Vector3(data.Maps.Defense.CRYSTAL.x,5.0,data.Maps.Defense.CRYSTAL.y)}) == 1,"The transition emits one wave announcement event")
	var hud = game.ui.native_hud
	check(hud.announcement_alpha(0) == 0 and is_equal_approx(hud.announcement_alpha(.225),.5) and hud.announcement_alpha(1.2) == 1 and is_equal_approx(hud.announcement_alpha(2.675),.5) and hud.announcement_alpha(3) == 0,"Announcement fades in, holds and fades out over three seconds")
	sim.elapsed += 1.2
	hud.sync()
	check(hud.wave_announcement.visible and hud.wave_announcement.text == "第2波" and hud.wave_announcement.modulate.a == 1,"Native HUD presents the new wave without pausing")
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
		sim.step(10)
	check(sim.wave == 10 and sim.roster.count("dancer") == 0 and sim.zombies.filter(func(z): return z.kind == "dancer" and z.hp > 0).size() == 1,"The tenth and final wave contains exactly one dancing boss")
	sim.elapsed += 1.2
	hud.sync()
	check(hud.wave_announcement.text == "第10波-最后一波！" and hud.wave_announcement.visible,"Final-wave announcement identifies the last wave")
	check(data.enemies.dancer.health == data.enemies.football.health*10,"Boss health is exactly ten football zombies")
	sim.roster.clear()
	sim.zombies.clear()
	validate_summon_cap(sim)
	sim.spawn(Vector2(8,23),"dancer")
	var boss: Dictionary = sim.zombies[-1]
	check(boss.chase_speed >= 4.6 and boss.chase_speed <= 5.2,"Dancing boss uses the ordinary movement speed")
	Boss.step(sim,9.9)
	check(boss.dance_remaining == 0 and boss.summon_roster.is_empty(),"Boss cannot summon before ten seconds")
	Boss.step(sim,.11)
	check(boss.dance_remaining == 3 and sim.events.any(func(event): return event.kind == "disco"),"Ten-second summon starts a stopped disco dance and audio cue")
	var population = preload("res://scripts/enemy_population.gd")
	var expected_summons = {"bucket":18,"shield":3,"berserker":1,"imp":4}
	var exact_summons = boss.summon_roster.size() == 26 and population.points(boss.summon_roster) == 50
	for kind in expected_summons: exact_summons = exact_summons and boss.summon_roster.count(kind) == expected_summons[kind]
	check(exact_summons,"Boss evenly shares fifty points and fills the remainder with buckets: 18 buckets, 3 shields, 1 berserker, 4 imps")
	var stable_composition = true
	for seed_value in range(30):
		var random = RandomNumberGenerator.new()
		random.seed = seed_value
		var value = Boss.roster(random)
		stable_composition = stable_composition and value.size() == 26 and population.points(value) == 50
		for kind in expected_summons: stable_composition = stable_composition and value.count(kind) == expected_summons[kind]
	check(stable_composition,"Every random seed preserves the exact summon composition")
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
	check(sim.won and sim.wave == 10 and sim.zombies.all(func(z): return z.hp <= 0),"Boss death immediately clears the army and wins")
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

func validate_summon_cap(sim) -> void:
	sim.zombies.clear()
	sim.events.clear()
	sim.spawn(Vector2(8,23),"dancer")
	var boss: Dictionary = sim.zombies[-1]
	for index in 74: sim.spawn(Vector2(8,23),"normal")
	Boss.step(sim,10)
	check(sim.alive_count() == 75 and boss.summon_roster.is_empty() and boss.dance_remaining == 0 and not sim.events.any(func(event): return event.kind == "disco"),"75 living enemies plus 26 summons exceeds 100 and skips the entire dance")
	check(boss.summon_clock == 10,"Skipped summon resets the ten-second interval instead of retrying each frame")
	sim.zombies[-1].hp = 0
	Boss.step(sim,9.9)
	check(boss.summon_roster.is_empty(),"Dropping below the cap does not immediately retry a skipped summon")
	Boss.step(sim,.11)
	check(sim.alive_count() == 74 and boss.summon_roster.size() == 26 and boss.dance_remaining == 3,"74 living enemies plus 26 summons is exactly 100 and is allowed; dead bodies are excluded")
	Boss.step(sim,3)
	for tick in 20: Boss.step(sim,.016)
	check(sim.alive_count() == 100 and boss.summon_roster.is_empty(),"The accepted boundary summon releases its full quota and stops at 100")
	sim.zombies.clear()
	sim.events.clear()
	sim.spawn(Vector2(8,23),"dancer")
	boss = sim.zombies[-1]
	for index in 75: boss.summon_roster.append("bucket")
	Boss.step(sim,10)
	check(sim.alive_count()+boss.summon_roster.size() == 76 and boss.dance_remaining == 0 and not sim.events.any(func(event): return event.kind == "disco"),"Pending summons count towards admission; rejected calls still allow the existing backlog to release")
	sim.zombies.clear()
	sim.events.clear()
