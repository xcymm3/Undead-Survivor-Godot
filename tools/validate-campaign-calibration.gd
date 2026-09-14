extends "res://tools/validate-campaign.gd"
## Outcomes and stage timings are observations, never padded to a target duration.
func calibrated(profile: String, seed_value: int) -> Dictionary:
	await start(1)
	game.sim.random.seed = seed_value
	var driver = load("res://tools/campaign-limited-driver.gd").new(game,true)
	if profile == "cautious":
		driver.turn_rate = deg_to_rad(85.0)
		driver.error_angle = deg_to_rad(1.2)
		driver.reaction = .4
		driver.observation = 3.0
	var stages: Array = []
	var last_stage = ""
	for i in 24000:
		if game.sim.won or game.sim.failed: break
		var state: Dictionary = game.sim.campaign_state()
		var stage: String = "departure" if not state.departed else "street_shop" if not state.shop_open else "yard_drain" if not state.milestones.has("bridge_start") else "bridge" if not state.gate_open else "pump" if not state.pump_ready else "valve" if not state.power_ready else "escape"
		if stage != last_stage:
			stages.append({"stage":stage,"at":game.sim.elapsed,"hp":game.local_pawn().hp,"kills":game.sim.kills})
			last_stage = stage
			print("CALIBRATION STAGE ",profile," seed=",seed_value," ",stages[-1])
		var input = driver.command(.05)
		check(absf(angle_difference(game.local_pawn().yaw,input.yaw)) <= driver.turn_rate*.05+.0001,"Bounded input respects turn rate")
		game.sim.submit("solo",input)
		game.sim.step(.05)
		if i % 100 == 0: await process_frame
	for i in stages.size(): stages[i]["seconds"] = (stages[i+1].at if i+1 < stages.size() else game.sim.elapsed)-stages[i].at
	var p: Dictionary = game.local_pawn()
	return {"profile":profile,"seed":seed_value,"won":game.sim.won,"failed":game.sim.failed,"timeout":not game.sim.won and not game.sim.failed,"seconds":game.sim.elapsed,"hp":p.hp,"kills":game.sim.kills,"shots":p.shots,"ammo":p.ammo[p.primary],"reserve":p.reserve,"task":driver.index,"stages":stages,"turn_degrees":rad_to_deg(driver.turn_rate),"aim_error_degrees":rad_to_deg(driver.error_angle),"reaction_seconds":driver.reaction,"observation_seconds":driver.observation}
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	var results: Array = []
	for profile in ["standard","cautious"]:
		for seed_value in [104730,104731]:
			var result = await calibrated(profile,seed_value)
			results.append(result)
			print("CALIBRATION RESULT ",JSON.stringify(result))
	var f = FileAccess.open("res://artifacts/campaign-calibration.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"runs":results,"input_violations":failures,"boundary":"Synthetic solo inputs with known route and enemy telemetry; not human 8-12 minute acceptance. Failure is retained, never rerolled."},"  "))
	f.close()
	game.return_home()
	game.queue_free()
	await process_frame
	print("CALIBRATION REPORT COMPLETE")
	quit(0 if failures.is_empty() else 1)
