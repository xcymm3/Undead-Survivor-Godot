extends "res://tools/validate-balance.gd"
## Controlled comparison: one weapon at a time, identical seed and population.
## Fixtures only set the initial loadout and supply identities; no runtime gifts.
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	var data = root.get_node("Data")
	for weapon in data.weapons.size():
		for party in [1,2]:
			await start(party,71245)
			var w: Dictionary = data.weapons[weapon]
			for loot in game.sim.campaign.state.loot: loot.weapon = weapon
			var drivers: Dictionary = {}
			for p in game.sim.pawns.values():
				p.ammo.fill(0)
				p.reserves.fill(0)
				if weapon in [2,3]: p.secondary = weapon
				elif weapon != 6: p.primary = weapon
				p.weapon = weapon
				p.requested = weapon
				p.slot = 3 if weapon == 6 else 2 if weapon in [2,3] else 1
				p.ammo[weapon] = int(w.capacity)
				p.reserves[weapon] = int(w.capacity)*5
				p.reserve = p.reserves[p.primary]
				var driver = load("res://tools/campaign-unrestricted-driver.gd").new(Perspective.new(game,p.id),false)
				driver.test_weapon = weapon
				driver.allow_grenades = false
				if weapon == 6:
					driver.tasks = driver.tasks.filter(func(task): return task[1] not in ["night_start","night_shop","night_van"])
				drivers[p.id] = driver
			for tick in 9600:
				if game.sim.won or game.sim.failed: break
				for id in drivers: game.sim.submit(id,drivers[id].command(.05))
				game.sim.step(.05)
				if tick%100 == 0: await process_frame
			var shots = 0
			for p in game.sim.pawns.values():
				shots += p.gun_shots[weapon]
				for other in 10:
					if other != weapon: check(p.gun_shots[other] == 0,"No other weapon in comparison "+w.id)
			check(shots > 0,"Comparison actually fired "+w.id+" party "+str(party))
			var result = {"weapon":weapon,"id":w.id,"label":w.label,"tier":w.tier,"party":party,"seed":71245,"won":game.sim.won,"failed":game.sim.failed,"timeout":not game.sim.won and not game.sim.failed,"seconds":game.sim.elapsed,"kills":game.sim.kills,"shots":shots,"players":game.sim.pawns.values().map(func(p): return {"id":p.id,"hp":p.hp,"ammo":p.ammo[weapon],"reserve":p.reserves[weapon],"medkits":p.medkits,"task":drivers[p.id].index}),"diagnostics":game.sim.campaign.diagnostics()}
			runs.append(result)
			print("WEAPON RESULT ",w.id," party=",party," win=",result.won," seconds=",result.seconds," kills=",result.kills," shots=",shots)
			var file = FileAccess.open("res://artifacts/all-weapons-acceptance.json",FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks":count,"failures":failures,"runs":runs,"boundary":"Unrestricted synthetic inputs, one seed per weapon/party. Normal ammo, pickups, collision, cooldowns, medical and shove. No other weapons or grenades. Defeats/timeouts are comparative observations, not declared wins. Not human or Steam verification."},"  "))
			file.close()
	game.return_home()
	game.queue_free()
	await process_frame
	await physics_frame
	print("ALL WEAPONS: %d samples; %d failures" % [runs.size(),failures.size()])
	quit(0 if failures.is_empty() and runs.size() == 20 else 1)
