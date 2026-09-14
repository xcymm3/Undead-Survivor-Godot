extends RefCounted
## Isolated regressions for player-clearance endpoints and control-pedestal detours.
static func run(qa) -> void:
	await qa.start(1,104730)
	var sim = qa.game.sim
	var arena = qa.game.arena
	var layout = load("res://scripts/campaign_layout.gd")
	for key in ["departed","shop_open","gate_open","power_ready"]: sim.campaign.state[key] = true
	arena.sync_campaign(sim.campaign.state)
	await qa.physics_frame
	var p: Dictionary = sim.pawns.solo
	for kind in ["normal","football"]:
		for points in [[Vector2(-40,-94),Vector2(-55.99863,-102.2498)],[Vector2(-56,-105),layout.PUMP],[Vector2(71,-76),layout.VALVE]]:
			sim.zombies.clear()
			sim.paths.clear()
			sim.crowd_buckets.clear()
			p.pos = points[1]
			p.height = 0
			p.hp = 100
			p.protection = 0
			sim.spawn(points[0],kind)
			var z: Dictionary = sim.zombies[-1]
			qa.check(not arena.path_to(z.pos,p.pos).is_empty(),"Margin target has a route: "+kind+str(p.pos))
			for i in 1200:
				sim.elapsed += .05
				sim.update_zombie(z,p,.05)
				if p.hp < 100: break
			qa.check(p.hp < 100,"Enemy reaches and attacks control-side target: "+kind+str(p.pos))
	qa.check(not arena.endpoint_link(Vector2(-56,-102.2498),Vector2(-56,-104.5)),"Endpoint projection cannot cross the physical control pedestal")
	sim.campaign.state.gate_open = false
	arena.sync_campaign(sim.campaign.state)
	qa.check(not arena.endpoint_link(Vector2(0,-56),Vector2(0,-59)),"Endpoint projection cannot cross a closed river gate")
	await qa.start(1,104730)
	sim = qa.game.sim
	sim.zombies.clear()
	sim.campaign.state.departed = true
	sim.campaign.state.gate_open = true
	sim.arena.sync_campaign(sim.campaign.state)
	sim.pawns.solo.pos = Vector2(-55.99863,-102.2498)
	for point in layout.PUMP_INTERIOR:
		qa.check(await qa.move_party(point,12.0),"Physical player follows pump detour without waypoint timeout: "+str(point))
