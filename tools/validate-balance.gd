extends "res://tools/validate-night.gd"
## Same ordinary inputs and seeds in solo and shared-authority duo. No equipment override.
class Perspective extends RefCounted:
	var sim
	var arena
	var id: String
	func _init(current, pawn_id: String):
		sim = current.sim
		arena = current.arena
		id = pawn_id
	func local_pawn() -> Dictionary: return sim.pawns[id]

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	for party in [1,2]:
		for seed_value in [71245,71246]:
			await start(party,seed_value)
			var drivers: Dictionary = {}
			var timings: Array = []
			var previous: Dictionary = {}
			for id in game.sim.pawns:
				drivers[id] = load("res://tools/campaign-limited-driver.gd").new(Perspective.new(game,id),false)
			for tick in 9600:
				if game.sim.won or game.sim.failed: break
				for id in drivers:
					if previous.get(id,-1) != drivers[id].index:
						previous[id] = drivers[id].index
						timings.append({"player":id,"task":drivers[id].index,"at":game.sim.elapsed,"hp":game.sim.pawns[id].hp})
					game.sim.submit(id,drivers[id].command(.05))
				game.sim.step(.05)
				if tick%100 == 0: await process_frame
			var result = {"party":party,"seed":seed_value,"won":game.sim.won,"failed":game.sim.failed,"seconds":game.sim.elapsed,"kills":game.sim.kills,"players":game.sim.pawns.values().map(func(p): return {"id":p.id,"hp":p.hp,"medkits":p.medkits,"grenades":p.grenades,"task":drivers[p.id].index}),"diagnostics":game.sim.campaign.diagnostics()}
			runs.append(result)
			result["timings"] = timings
			result["boss_remaining"] = game.sim.zombies.filter(func(z): return z.kind == "football" and z.hp > 0).map(func(z): return {"hp":z.hp,"armor":z.armor})
			print("BALANCE RESULT ",JSON.stringify(result))
			check(result.won,"Fixed solo/duo seed reaches safe room: "+str(party)+"/"+str(seed_value))
			if party == 1: check(result.won and result.seconds >= 150 and result.seconds <= 270,"Solo wins within 150-270 seconds: "+str(seed_value))
	var f = FileAccess.open("res://artifacts/balance-acceptance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":count,"failures":failures,"runs":runs,"profile":{"turn_limit":false,"aim_error_degrees":.35,"fire_wait":0,"observation":1.5,"grenade_strategy":"reserve-two-predict-approach-v3"},"budget":{"duo_burst_size":Layout.DUO_BURST_SIZE,"duo_reinforcement_scale":Layout.DUO_REINFORCEMENT_SCALE,"zones":Layout.ZONES,"woods":Layout.WOODS_BUDGET,"timer":Layout.TIMER_BUDGET,"holdout":Layout.HOLDOUT_BUDGET},"boundary":"Synthetic inputs; duo shared authority is separate from ENet/Steam. All failures retained."},"  "))
	f.close()
	game.return_home()
	game.queue_free()
	await process_frame
	await physics_frame
	print("BALANCE VALIDATION: %d checks; %d failures" % [count,failures.size()])
	quit(0 if failures.is_empty() else 1)
