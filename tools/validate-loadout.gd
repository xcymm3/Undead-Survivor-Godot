extends RefCounted

static func validate(game, check: Callable) -> void:
	var progress = game.get_node("/root/Progress")
	var previous = progress.store
	progress.store = load("res://scripts/progression_store.gd").new()
	game.return_home()
	game.start_solo("defense",71245)
	await game.get_tree().physics_frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	var equipment = sim.equipment
	check.call(p.weapon1 == 0 and p.weapon2 == 3 and p.slot_ammo == [30,6],"Fixed loadout starts with rifle and revolver")
	check.call(p.grenades == 1 and p.grenade_capacity == 1,"New progress carries one grenade")
	check.call(not p.has("medkits") and not p.has("healing"),"Medical inventory remains removed")
	check.call(not equipment.pickup(p,"weapon:8") and not equipment.pickup(p,"weapon:0"),"Armory identifiers cannot exchange or refill guns")
	p.switch = 0.0
	p.fire_anim = 0.0
	sim.update_arsenal(p,{"fire":true},.01)
	check.call(p.slot_ammo == [29,6],"Firing the rifle preserves the revolver magazine")
	p.slot = 2
	equipment.select_weapon_slot(p,2)
	p.ammo[3] = 1
	p.switch = 0.0
	p.fire_anim = 0.0
	sim.update_arsenal(p,{"reload":true},.01)
	sim.update_arsenal(p,{},1.61)
	check.call(p.slot_ammo == [29,6] and p.slot_reserves == [510,97],"Revolver reload consumes five reserve rounds without affecting rifle inventory")
	p.slot = 1
	equipment.select_weapon_slot(p,1)
	check.call(p.ammo[0] == 29 and p.reserves[0] == 510,"Switching back preserves the rifle inventory")
	p.input = {"slot":3}
	p.input_age = 0.0
	equipment.before_movement(.01)
	sim.update_arsenal(p,{},.01)
	sim.update_arsenal(p,{},.25)
	check.call(p.slot == 3 and p.requested == 6,"Fixed axe remains in slot three")
	p.hp = 35
	p.grenades = 0
	sim.defense_director.begin_wave()
	check.call(p.hp == 100 and p.grenades == 1,"Wave start restores health and the purchased grenade capacity")
	check.call(p.slot_ammo == [29,6] and p.slot_reserves == [510,97],"Wave start never refills firearm ammunition")
	p.input = {"yaw":0.0,"pitch":0.0}
	check.call(equipment.throw_grenade(p) and p.grenades == 0,"Throwing consumes the initial one-grenade stock")
	sim.defense_director.finish_wave()
	check.call(p.grenades == 0,"Entering the next preparation does not refill grenades")
	p.pos = game.get_node("/root/Data").Maps.Defense.SPAWN
	check.call(not sim.shop_available(p) and not game.open_shop(),"Shop remains closed between later waves")
	sim.defense_director.begin_wave()
	check.call(p.grenades == 1 and p.slot_ammo == [29,6] and p.slot_reserves == [510,97],"Later waves refill only grenades, never firearm rounds")
	game.ui.native_hud.sync()
	check.call(game.ui.native_hud.equipment_slots.size() == 4,"HUD exposes four fixed equipment slots")
	check.call(game.ui.native_hud.equipment_slots[0].title.text == "步枪" and game.ui.native_hud.equipment_slots[1].title.text == "左轮手枪","HUD names both fixed guns")
	check.call(game.ui.native_hud.equipment_slots[2].title.text == "消防斧" and game.ui.native_hud.equipment_slots[3].title.text == "手雷  1 / 1","HUD displays axe and current grenade capacity")
	game.start_solo("defense",71245)
	p = game.local_pawn()
	check.call(p.slot_ammo == [30,6] and p.slot_reserves == [510,102],"Restarting a run restores both firearms")
	game.return_home()
	progress.store = previous
	game.start_solo("defense",71245)
	await game.get_tree().physics_frame
