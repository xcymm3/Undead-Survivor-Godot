extends "res://tools/validate-balance.gd"
## Fixed solo trials: guns must win unaided; sniper must actually pick up A tier.
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	var data = root.get_node("Data")
	var p90_only = "--p90-only" in OS.get_cmdline_user_args()
	for weapon in ([1] if p90_only else [1,9] if "--spread-probe" in OS.get_cmdline_user_args() else [0,1,5,9,3]):
		for seed_value in [71245,71246]:
			await start(1,seed_value)
			var w: Dictionary = data.weapons[weapon]
			var needs_a: bool = w.tier == "B" and weapon != 3
			for loot in game.sim.campaign.state.loot:
				if weapon != 3 and (not needs_a or data.weapons[loot.weapon].tier != "A"): loot.weapon = weapon
			var p: Dictionary = game.sim.pawns.values()[0]
			p.ammo.fill(0)
			p.reserves.fill(0)
			if weapon == 3: p.secondary = weapon
			else: p.primary = weapon
			p.weapon = weapon
			p.requested = weapon
			p.slot = 2 if weapon == 3 else 1
			p.ammo[weapon] = int(w.capacity)
			p.reserves[weapon] = int(w.capacity)*5
			p.reserve = p.reserves[weapon]
			var driver = load("res://tools/campaign-unrestricted-driver.gd").new(Perspective.new(game,p.id),false)
			driver.test_weapon = weapon
			driver.allow_grenades = false
			var acquired = false
			var ads_shots = 0
			var hip_shots = 0
			for tick in 9600:
				acquired = needs_a and p.hp > 0 and data.weapons[p.primary].tier == "A" and game.sim.campaign.state.loot.any(func(loot): return loot.taken and loot.weapon == p.primary)
				if acquired or game.sim.won or game.sim.failed: break
				var command: Dictionary = driver.command(.05)
				# Ordinary ADS input beyond shove range; no spread prediction or aim compensation.
				var nearest = INF
				for z in game.sim.zombies:
					if z.hp > 0 and z.get("guard_awake",true): nearest = minf(nearest,z.pos.distance_to(p.pos))
				command.aim = nearest >= 2.4 and command.get("slot",1) < 4 and command.get("fire",false)
				var before: int = p.gun_shots[weapon]
				game.sim.submit(p.id,command)
				game.sim.step(.05)
				if p.aim: ads_shots += p.gun_shots[weapon]-before
				else: hip_shots += p.gun_shots[weapon]-before
				if tick%100 == 0: await process_frame
			for other in data.weapons.size():
				if other != weapon: check(p.gun_shots[other] == 0,"No fallback weapon")
			check(p.gun_shots[weapon] > 0,"Test weapon actually fired")
			check(ads_shots > 0 and hip_shots > 0,"Both ordinary ADS and hip shots exercised")
			var passed: bool = acquired if needs_a else game.sim.won
			if weapon != 3: check(passed,"Target achieved "+w.id+" seed "+str(seed_value))
			var result = {"weapon":weapon,"id":w.id,"seed":seed_value,"passed":passed,"won":game.sim.won,"acquired_a":acquired,"primary":p.primary,"seconds":game.sim.elapsed,"kills":game.sim.kills,"hp":p.hp,"ammo":p.ammo[weapon],"reserve":p.reserves[weapon],"task":driver.index,"shots":p.gun_shots,"ads_shots":ads_shots,"hip_shots":hip_shots,"required":weapon != 3,"rules":w.duplicate(true),"diagnostics":game.sim.campaign.diagnostics()}
			runs.append(result)
			print("TARGET BALANCE ",w.id," seed=",seed_value," passed=",passed," seconds=",result.seconds," kills=",result.kills," hp=",p.hp," task=",driver.index)
			var file = FileAccess.open("res://artifacts/p90-40-acceptance.json" if p90_only else "res://artifacts/spread-weapons-acceptance.json",FileAccess.WRITE)
			file.store_string(JSON.stringify({"runs":runs,"failures":failures,"boundary":"Unrestricted solo, two fixed seeds, normal movement/collision/ammo/reload/pickup/heal/shove. No other gun or grenades. B-tier stops on actual A-tier pickup. Revolver observational only. ADS when firing with nearest active threat at least 2.4m away; no prediction/compensation of spread."},"  "))
			file.close()
	game.return_home()
	game.queue_free()
	await process_frame
	await physics_frame
	quit(0 if failures.is_empty() else 1)
