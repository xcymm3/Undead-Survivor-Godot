extends RefCounted

static func validate(game, check: Callable) -> void:
	var progress = game.get_node("/root/Progress")
	var previous = progress.store
	progress.store = load("res://scripts/progression_store.gd").new()
	game.return_home()
	game.start_solo("defense",71245)
	preload("res://tools/preparation-fixture.gd").skip_tutorial(game.sim) # Fixture starts after the narrative intro.
	await game.get_tree().physics_frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	var equipment = sim.equipment
	check.call(p.weapon1 == 0 and p.weapon2 == 2 and p.slot_ammo == [30,15],"Fixed loadout starts with rifle and pistol")
	check.call(p.grenades == 0 and p.grenade_capacity == 0,"New progress starts without grenade capacity")
	check.call(not p.has("medkits") and not p.has("healing"),"Medical inventory remains removed")
	check.call(not equipment.pickup(p,"weapon:8") and not equipment.pickup(p,"weapon:0"),"Armory identifiers cannot exchange or refill guns")
	p.switch = 0.0
	p.fire_anim = 0.0
	sim.update_arsenal(p,{"fire":true},.01)
	check.call(p.slot_ammo == [29,15],"Firing the rifle preserves the pistol magazine")
	p.slot = 2
	equipment.select_weapon_slot(p,2)
	p.ammo[2] = 1
	p.switch = 0.0
	p.fire_anim = 0.0
	sim.update_arsenal(p,{"reload":true},.01)
	sim.update_arsenal(p,{},1.61)
	check.call(p.slot_ammo == [29,15] and p.slot_reserves == [180,76],"Pistol reload consumes fourteen reserve rounds without affecting rifle inventory")
	p.slot = 1
	equipment.select_weapon_slot(p,1)
	check.call(p.ammo[0] == 29 and p.reserves[0] == 180,"Switching back preserves the rifle inventory")
	p.input = {"slot":3}
	p.input_age = 0.0
	equipment.before_movement(.01)
	sim.update_arsenal(p,{},.01)
	sim.update_arsenal(p,{},.25)
	check.call(p.slot == 3 and p.requested == 6,"Fixed axe remains in slot three")
	p.hp = 35
	p.grenades = 0
	sim.defense_director.begin_wave()
	check.call(p.hp == 35 and p.grenades == 0,"Wave start preserves health and grenade stock")
	check.call(p.slot_ammo == [29,15] and p.slot_reserves == [180,76],"First wave start grants no extra firearm ammunition")
	p.input = {"yaw":0.0,"pitch":0.0}
	sim.progression.data.grenade_level = 1
	p.grenade_capacity = sim.progression.grenade_capacity()
	p.grenades = 1
	check.call(equipment.throw_grenade(p) and p.grenades == 0,"Throwing consumes a purchased grenade")
	sim.defense_director.finish_wave()
	check.call(p.grenades == 0,"Entering the next preparation does not refill grenades")
	p.pos = game.get_node("/root/Data").Maps.Defense.SPAWN
	check.call(not sim.shop_available(p),"Shop remains closed between later waves")
	sim.defense.wave = 2
	sim.defense_director.begin_wave()
	check.call(p.grenades == 0 and p.slot_ammo == [29,15] and p.slot_reserves == [240,106],"Second wave preserves loaded rounds and grenades while adding two reserve magazines")
	game.ui.native_hud.sync()
	check.call(game.ui.native_hud.equipment_slots.size() == 4,"HUD exposes four fixed equipment slots")
	check.call(game.ui.native_hud.equipment_slots[0].title.text == "步枪" and game.ui.native_hud.equipment_slots[1].title.text == "半自动手枪","HUD names both fixed guns")
	check.call(game.ui.native_hud.equipment_slots[2].title.text == "消防斧" and game.ui.native_hud.equipment_slots[3].title.text == "手雷  0 / 1","HUD displays axe and current grenade capacity")
	p.grenade_replenish = 15.0
	p.input = {}
	sim.update_pawn(p,7.5)
	game.ui.native_hud.sync()
	check.call(p.grenades == 0 and is_equal_approx(game.ui.native_hud.grenade_ring.progress,.5),"Grenade ring shows half charge after half the fifteen-second refill interval")
	sim.update_pawn(p,7.5)
	game.ui.native_hud.sync()
	check.call(p.grenades == 1 and game.ui.native_hud.grenade_ring.progress == 1.0,"Grenade refill and charge ring reach full capacity together")

	game.start_solo("defense",71245)
	preload("res://tools/preparation-fixture.gd").skip_tutorial(game.sim) # Fixture starts after the narrative intro.
	p = game.local_pawn()
	check.call(p.slot_ammo == [30,15] and p.slot_reserves == [180,90],"Restarting a run restores both firearms")
	game.return_home()
	progress.store = previous
	game.start_solo("defense",71245)
	preload("res://tools/preparation-fixture.gd").skip_tutorial(game.sim) # Fixture starts after the narrative intro.
	await game.get_tree().physics_frame
