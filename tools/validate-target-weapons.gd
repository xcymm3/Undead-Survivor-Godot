extends "res://tools/validate-balance.gd"
## Fixed solo trials: guns must win unaided; sniper must actually pick up A tier.
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	var data = root.get_node("Data")
	for weapon in [0,8,5]:
		for seed_value in [71245,71246]:
			await start(1,seed_value)
			var w: Dictionary = data.weapons[weapon]
			for loot in game.sim.campaign.state.loot:
				if weapon != 5 or data.weapons[loot.weapon].tier != "A": loot.weapon = weapon
			var p: Dictionary = game.sim.pawns.values()[0]
			p.ammo.fill(0)
			p.reserves.fill(0)
			p.primary = weapon
			p.weapon = weapon
			p.requested = weapon
			p.slot = 1
			p.ammo[weapon] = int(w.capacity)
			p.reserves[weapon] = int(w.capacity)*5
			p.reserve = p.reserves[weapon]
			var driver = load("res://tools/campaign-unrestricted-driver.gd").new(Perspective.new(game,p.id),false)
			driver.test_weapon = weapon
			driver.allow_grenades = false
			var acquired = false
			for tick in 9600:
				acquired = weapon == 5 and data.weapons[p.primary].tier == "A" and game.sim.campaign.state.loot.any(func(loot): return loot.taken and loot.weapon == p.primary)
				if acquired or game.sim.won or game.sim.failed: break
				game.sim.submit(p.id,driver.command(.05))
				game.sim.step(.05)
				if tick%100 == 0: await process_frame
			for other in data.weapons.size():
				if other != weapon: check(p.gun_shots[other] == 0,"No fallback weapon")
			var passed: bool = acquired if weapon == 5 else game.sim.won
			check(passed,"Target achieved "+w.id+" seed "+str(seed_value))
			var result = {"weapon":weapon,"id":w.id,"seed":seed_value,"passed":passed,"won":game.sim.won,"acquired_a":acquired,"primary":p.primary,"seconds":game.sim.elapsed,"kills":game.sim.kills,"hp":p.hp,"ammo":p.ammo[weapon],"reserve":p.reserves[weapon],"task":driver.index,"shots":p.gun_shots,"rules":w.duplicate(true),"diagnostics":game.sim.campaign.diagnostics()}
			runs.append(result)
			print("TARGET BALANCE ",w.id," seed=",seed_value," passed=",passed," seconds=",result.seconds," kills=",result.kills," hp=",p.hp," task=",driver.index)
			var file = FileAccess.open("res://artifacts/target-weapons-acceptance.json",FileAccess.WRITE)
			file.store_string(JSON.stringify({"runs":runs,"failures":failures,"boundary":"Unrestricted solo, two fixed seeds, normal movement/collision/ammo/reload/pickup/heal/shove. No other gun or grenades. Sniper stops on actual A-tier pickup; not a full-clear claim."},"  "))
			file.close()
	game.return_home()
	game.queue_free()
	await process_frame
	await physics_frame
	quit(0 if failures.is_empty() else 1)
