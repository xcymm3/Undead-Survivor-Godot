extends RefCounted
static func run(qa) -> void:
	await qa.start(1,104730)
	var sim = qa.game.sim
	var layout = load("res://scripts/campaign_layout.gd")
	var objectives = load("res://scripts/campaign_objectives.gd")
	for name in ["LoadingYard","PumpWorkstations","ExitServiceCorridor"]:
		qa.check(qa.game.arena.find_child(name,true,false) != null,"Native annex scene exists: "+name)
	var p: Dictionary = sim.pawns.solo
	for objective in objectives.NODES:
		p.pos = objective.pos
		sim.campaign.perform(p,objective.id)
		qa.check(not sim.campaign.state[objective.id],"Authority rejects out-of-order objective: "+objective.id)
	sim.zombies.clear()
	sim.campaign.state.pressure_until = 10000 # Isolate traversal, not a playthrough.
	sim.campaign.state.departed = true
	sim.campaign.state.shop_key = true
	sim.arena.sync_campaign(sim.campaign.state)
	p.pos = Vector2(-55,80)
	qa.check(await qa.objective_route(layout.LOADING_ROUTE),"Loading route is physically traversable")
	qa.check(sim.campaign.state.loading_power,"Loading power requires both local interactions")
	sim.campaign.state.gate_open = true
	sim.campaign.state.leak_closed = true
	sim.arena.sync_campaign(sim.campaign.state)
	p.pos = layout.LEAK
	qa.check(await qa.objective_route(layout.REPAIR_ROUTE),"Both workstations are physically traversable")
	sim.campaign.state.power_ready = true
	qa.check(not sim.campaign.state.exit_control,"Supply power alone cannot unlock the final door")
	p.pos = layout.VALVE
	qa.check(await qa.objective_route(layout.SERVICE_ROUTE),"Service corridor is physically traversable")
	qa.check(sim.campaign.state.exit_control and sim.arena.clear(Vector2(25,-117),Vector2(25,-123)),"Final control opens shared navigation and collision gate")
	# Captured from a cautious full run: NorthGround returned zero travel for
	# every tangent sweep despite an unobstructed path away from the console.
	p.pos = Vector2(19.59995,-200.2505)
	p.height = -.0490579419
	p.velocity = 0.0
	p.air = Vector2.ZERO
	await qa.hold(3.0,"")
	qa.check(await qa.move_party(Vector2(20,-195),3.0),"Stationary floor contact resumes movement away from final control")
	p.pos = Vector2(-52.30093,-109.3009)
	p.height = -.09164274
	p.velocity = 0.0
	var goal = Vector2(-52,-94)
	var driver = load("res://tools/campaign-input-driver.gd").new(qa.game,true)
	driver.tasks = [[goal,""]]
	driver.path = PackedVector2Array([goal]) # Stale pre-combat path across the pump.
	for attempt in 400:
		if p.pos.distance_to(goal) < .6: break
		sim.submit(p.id,driver.command(.05))
		sim.step(.05)
		if attempt % 100 == 0: await qa.process_frame
	qa.check(p.pos.distance_to(goal) < .6,"Input driver replans around equipment after combat retreat")
	p.pos = Vector2(-65,207)
	p.height = -.05
	p.velocity = 0.0
	driver = load("res://tools/campaign-input-driver.gd").new(qa.game,true)
	driver.tasks = [[Vector2(-65,205),""]]
	for attempt in 160:
		if driver.index > 0: break
		sim.submit(p.id,driver.command(.05))
		sim.step(.05)
	qa.check(driver.index == 1,"Replanning permits a physical approach into the interaction clearance margin")

	# Reproduce the ENet departure contact without involving transport timing.
	p.pos = Vector2(1.197477,104.2769)
	p.height = -.081322
	p.crouch = 1.0
	p.velocity = 0.0
	var body = sim.player_body(p)
	body.sync_from(p)
	for i in 5: body.update_stance(p,false,.05)
	qa.check(p.crouch < .1,"Floor recovery contact does not prevent standing up")
	var ceiling = StaticBody3D.new()
	var ceiling_shape = CollisionShape3D.new()
	var slab = BoxShape3D.new()
	slab.size = Vector3(2,.1,2)
	ceiling_shape.shape = slab
	ceiling.add_child(ceiling_shape)
	qa.game.arena.add_child(ceiling)
	ceiling.position = Vector3(p.pos.x,1.4,p.pos.y)
	await qa.physics_frame
	p.crouch = 1.0
	body.sync_from(p)
	for i in 5: body.update_stance(p,false,.05)
	qa.check(p.crouch > .9,"Actual overhead obstruction still prevents standing")
	ceiling.queue_free()
