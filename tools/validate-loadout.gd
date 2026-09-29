extends RefCounted

static func aim_at_mount(p: Dictionary, point: Vector3) -> void:
	p.pos = Vector2(point.x,point.z-1.65)
	p.yaw = PI
	p.pitch = atan2(point.y-p.height-preload("res://scripts/player_body.gd").eye_height(p),1.65)

static func validate(game, check: Callable) -> void:
	game.return_home()
	game.start_solo("defense",71245)
	await game.get_tree().physics_frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	var data = game.get_node("/root/Data")
	var layout = data.Maps.Defense
	var equipment = sim.equipment
	check.call(p.weapon1 == 0 and p.weapon2 == 8 and p.slot_ammo == [30,16],"Two weapon slots start with rifle and automatic shotgun")
	check.call(not p.has("medkits") and not p.has("healing"),"Medical inventory and treatment are removed")
	check.call(layout.ARMORY_WEAPONS == [0,8,7,5],"Armory offers exactly four guns")
	check.call(game.weapon.models[2].find_children("*Forearm*","",true,false).is_empty() and game.weapon.models[2].find_children("RightHand","",true,false).is_empty(),"First-person pistol has no hands or arms")
	for slot in [1,2]:
		p.slot = slot
		equipment.select_weapon_slot(p,slot)
		for display_index in 4:
			var weapon: int = layout.ARMORY_WEAPONS[display_index]
			var retained: int = p.weapon2 if slot == 1 else p.weapon1
			aim_at_mount(p,layout.weapon_mount(display_index))
			check.call(equipment.pickup(p,"weapon:"+str(weapon)),"Each armory gun is available in weapon slot "+str(slot))
			check.call(p.weapon == weapon and (p.weapon2 if slot == 1 else p.weapon1) == retained,"Replacing one weapon preserves the other slot")
			check.call(p.slot_ammo[slot-1] == data.weapons[weapon].capacity and p.slot_reserves[slot-1] == data.defense_full_reserve(weapon),"Pickup fully supplies only the selected slot")
	# Two copies must not share their loaded rounds or reserves.
	for slot in [1,2]:
		p.slot = slot
		equipment.select_weapon_slot(p,slot)
		aim_at_mount(p,layout.weapon_mount(0))
		equipment.pickup(p,"weapon:0")
	p.slot = 1
	equipment.select_weapon_slot(p,1)
	p.switch = 0.0
	p.cooldown = 0.0
	p.fire_anim = 0.0
	p.interaction = ""
	p.pickup_remaining = 0.0
	sim.update_arsenal(p,{"fire":true},.01)
	check.call(p.slot_ammo == [29,30],"Two identical rifles have independent magazines")
	p.slot = 2
	equipment.select_weapon_slot(p,2)
	p.ammo[0] = 25
	p.switch = 0.0
	p.fire_anim = 0.0
	sim.update_arsenal(p,{"reload":true},.01)
	sim.update_arsenal(p,{},data.weapons[0].reloadDuration+.01)
	check.call(p.slot_ammo == [29,30] and p.slot_reserves == [510,505],"Reloading one rifle does not consume the other rifle's reserve")
	p.slot = 1
	equipment.select_weapon_slot(p,1)
	check.call(p.ammo[0] == 29 and p.reserves[0] == 510,"Switching back restores the first rifle's exact inventory")
	p.input = {"slot":3}
	p.input_age = 0.0
	equipment.before_movement(.01)
	sim.update_arsenal(p,{},.01)
	sim.update_arsenal(p,{},.25)
	check.call(p.slot == 3 and p.requested == 6,"Fixed axe remains in slot three")
	p.input = {"slot":1}
	equipment.before_movement(.01)
	check.call(p.weapon == 0 and p.ammo[0] == 29,"Returning from the axe preserves weapon inventory")
	check.call(not equipment.pickup(p,"grenade:0") and not equipment.pickup(p,"medkit:0") and not equipment.pickup(p,"weapon:2"),"Removed armory supplies and guns cannot be claimed")
	sim.add_pawn("loadout_peer","队友",1)
	sim.start("defense")
	p = sim.pawns.solo
	var peer: Dictionary = sim.pawns.loadout_peer
	p.grenades = 0
	peer.grenades = 1
	sim.defense_director.begin_wave()
	check.call(p.grenades == 3 and peer.grenades == 3,"Actual wave start restores every player's grenades to three")
	p.input = {"yaw":0.0,"pitch":0.0}
	equipment = sim.equipment
	check.call(equipment.throw_grenade(p) and p.grenades == 2,"Throwing consumes one of the wave's three grenades")
	sim.defense_director.finish_wave()
	sim.defense_director.interactions(.01)
	check.call(p.grenades == 2,"Entering preparation does not refill grenades")
	p.input = {"wave_ready":true}
	p.input_age = 0.0
	sim.defense_director.interactions(.01)
	check.call(sim.defense.waiting and p.grenades == 2,"One ready coop player cannot refill before the wave starts")
	peer.input = {"wave_ready":true}
	peer.input_age = 0.0
	sim.defense_director.interactions(.01)
	check.call(not sim.defense.waiting and p.grenades == 3 and peer.grenades == 3,"All ready coop players start the wave and refill grenades")
	game.ui.native_hud.sync()
	check.call(game.ui.native_hud.equipment_slots.size() == 4,"HUD exposes two weapons, axe and grenade slots")
	check.call(game.ui.native_hud.equipment_slots[0].title.text.begins_with("武器1") and game.ui.native_hud.equipment_slots[1].title.text.begins_with("武器2"),"HUD names the two unrestricted weapon slots")
	check.call(game.ui.native_hud.equipment_slots[2].title.text == "消防斧" and game.ui.native_hud.equipment_slots[3].title.text == "手雷  3 / 3","HUD retains the fixed axe and displays wave grenade stock")
	var session = game.get_node("/root/Session")
	session.members = {"solo":{"name":"玩家"},"loadout_peer":{"name":"队友"}}
	var world: Dictionary = sim.snapshot()
	check.call(session.valid_world(world),"New two-weapon inventory passes coop snapshot validation")
	world.pawns.solo.slot_reserves[0] = 999999
	check.call(not session.valid_world(world),"Coop rejects oversized per-slot reserves")
	game.return_home()
	game.start_solo("defense",71245)
	await game.get_tree().physics_frame
