extends RefCounted
## Explicit state fixtures only. Executed by Campaign verification, never by Parse mode.
static func run(qa) -> void:
	for party in [1,2,4]:
		await qa.start(party)
		var sim = qa.game.sim
		qa.check(sim.campaign.state.zones.values().all(func(zone): return zone.preplaced == zone.requested),"All planned ambient enemies fit before departure (%d)" % party)
		qa.check(sim.zombies.all(func(z): return z.has("guard_awake") and not z.guard_awake),"All initial enemies wait for contact (%d)" % party)
		qa.check(Data.weapons[sim.pawns.solo.primary].tier == "B" and Data.weapons[sim.pawns.solo.secondary].tier == "B","Both starting firearms are B tier")
		for item in preload("res://scripts/campaign_layout.gd").ITEMS:
			if item.kind != "ammo": continue
			var loot: Array = sim.campaign.state.loot.filter(func(g): return g.station == item.id)
			var kinds: Dictionary = {}
			for gun in loot: kinds[gun.weapon] = true
			qa.check(loot.all(func(gun): return Data.weapons[gun.weapon].tier == item.tier and gun.tier == item.tier),"Station cannot roll weapons outside its progression tier")
			qa.check(loot.size() == party*2 and kinds.size() == mini(4,party*2),"Each station keeps twice party size while exhausting four tier types before repeats")
			qa.check(sim.campaign.state.grenade_stations[item.id].remaining == party,"Each station starts with one grenade per player")
	await qa.start(1)
	var gate_sim = qa.game.sim
	var early_player: Dictionary = gate_sim.pawns.solo
	var a_gun: Dictionary = gate_sim.campaign.state.loot.filter(func(g): return g.station == "shed_ammo")[0]
	early_player.pos = a_gun.pos
	qa.check(not gate_sim.campaign.equipment.pickup(early_player,a_gun.id) and not a_gun.taken,"Authority rejects A-tier pickup before the bridge opens")
	gate_sim.campaign.state.gate_open = true
	qa.check(gate_sim.campaign.equipment.pickup(early_player,a_gun.id),"A-tier equipment unlocks after the bridge")
	var early_cap: int = gate_sim.campaign.cap()
	gate_sim.campaign.state.departed = true
	early_player.pos = Vector2(36,-84)
	gate_sim.campaign.step(.05)
	qa.check(gate_sim.campaign.state.late_stage and gate_sim.campaign.cap() > early_cap,"Leaving the rearming area raises pressure once")
	qa.check(Data.weapons[6].damage == Data.enemies.normal.health and Data.weapons[6].headshotMultiplier == 1 and Data.weapons[6].tier == "C","Axe damage exactly matches ordinary zombie HP at C tier")
	await qa.start(2)
	var sim = qa.game.sim
	var equipment = sim.campaign.equipment
	sim.zombies.clear() # Isolate mechanics from combat difficulty.
	sim.campaign.state.departed = true
	var p: Dictionary = sim.pawns.solo
	var q: Dictionary = sim.pawns.qa1
	p.pos = Vector2(0,112)
	q.pos = Vector2(0,111)
	p.hp = 40
	var start_pos: Vector2 = p.pos
	for i in 20:
		sim.submit(p.id,{"slot":5,"fire":i == 0,"x":1.0,"y":-1.0,"jump":true})
		sim.step(.05)
	qa.check(p.pos.distance_to(start_pos) < .001 and not p.healing.is_empty(),"Click-to-heal locks movement after the mouse is released")
	for i in 45:
		sim.submit(p.id,{"slot":5})
		sim.step(.05)
	qa.check(p.hp == 90 and p.medkits == 0 and p.healing == "","Self treatment consumes exactly one pack and restores 50 HP")
	p.medkits = 1
	q.hp = 40
	var target_pos: Vector2 = q.pos
	for i in 65:
		sim.submit(p.id,{"slot":5,"aim":i == 0,"yaw":0.0})
		sim.submit(q.id,{"slot":1,"x":1.0,"fire":true})
		sim.step(.05)
	qa.check(q.hp == 90 and p.medkits == 0,"Right click heals a visible nearby teammate using the healer's pack")
	# Movement is locked during treatment; the recipient can move again on completion.
	qa.check(q.pos.distance_to(target_pos) < 1.0,"Recipient movement stays locked for the treatment interval")
	p.medkits = 1
	p.hp = 40
	sim.submit(p.id,{"slot":5,"use_self":true})
	sim.step(.05)
	sim.submit(p.id,{"slot":1})
	sim.step(.05)
	qa.check(p.healing == "" and p.medkits == 1,"Changing equipment cancels treatment without consuming the pack")
	p.pos = Vector2(-45,40)
	q.pos = p.pos
	qa.check(equipment.pickup(p,"grenade:yard_ammo") and equipment.pickup(q,"grenade:yard_ammo"),"Every teammate can claim a station grenade")
	qa.check(not equipment.pickup(p,"grenade:yard_ammo") and sim.campaign.state.grenade_stations.yard_ammo.remaining == 0,"Grenade allocation cannot be farmed")
	# A full inventory must neither consume stock nor accept a second item.
	p.pos = Vector2(-59,73)
	var stock: int = sim.campaign.state.grenade_stations.shop_ammo.remaining
	qa.check(not equipment.pickup(p,"grenade:shop_ammo") and sim.campaign.state.grenade_stations.shop_ammo.remaining == stock and p.grenades == 1,"A carried grenade blocks another pickup without consuming stock")
	p.grenades = 0 # Named empty-slot fixture; throwing is exercised immediately below.
	qa.check(equipment.pickup(p,"grenade:shop_ammo") and p.grenades == 1,"Empty grenade slot can be replenished")
	p.grenades = 0
	qa.check(equipment.pickup(p,"grenade:shop_ammo") and sim.campaign.state.grenade_stations.shop_ammo.remaining == 0,"After consumption the same station may supply its remaining finite stock")
	var med: Dictionary = preload("res://scripts/campaign_layout.gd").ITEMS.filter(func(item): return item.kind == "med")[0]
	p.pos = med.pos
	p.medkits = 1
	sim.campaign.perform(p,med.id)
	qa.check(p.medkits == 1 and not sim.campaign.state.taken.has(med.id),"Full medical slot leaves the world pack untouched")
	p.medkits = 0
	sim.campaign.perform(p,med.id)
	qa.check(p.medkits == 1 and sim.campaign.state.taken.has(med.id),"Empty medical slot accepts exactly one pack")
	p.pos = Vector2(0,103)
	q.pos = Vector2(3,103)
	for i in 5:
		sim.submit(p.id,{"slot":4,"fire":true})
		sim.step(.05)
	qa.check(p.grenades == 0 and sim.campaign.state.projectiles.size() == 1,"Holding throw consumes only one grenade")
	qa.check(sim.campaign.state.projectiles[0].fuse > 2.5,"Thrown grenade keeps its delayed fuse")
	for i in 65:
		sim.submit(p.id,{"slot":4})
		sim.step(.05)
	qa.check(sim.campaign.state.projectiles.is_empty(),"Expired grenade is removed after detonation")
	sim.spawn(Vector2(1,100),"normal")
	var near_enemy: Dictionary = sim.zombies[-1]
	sim.spawn(Vector2(12,100),"normal")
	var far_enemy: Dictionary = sim.zombies[-1]
	var far_health: float = far_enemy.hp
	equipment.explode({"pos":Vector3(0,1,100),"owner":p.id})
	qa.check(near_enemy.hp <= 0 and far_enemy.hp == far_health,"Explosion damages nearby enemies but respects its radius")
	sim.spawn(Vector2(0,56),"normal")
	var sheltered: Dictionary = sim.zombies[-1]
	var sheltered_hp: float = sheltered.hp
	equipment.explode({"pos":Vector3(0,1,62),"owner":p.id})
	qa.check(sheltered.hp == sheltered_hp,"Solid street fence blocks blast damage")
	sim.campaign.queue_batch("blocked_fixture",7,["normal"])
	var batch: Dictionary = sim.campaign.reinforcement_batches[-1]
	var expected_batch = roundi(7*sim.campaign.multiply())
	sim.campaign.credit = 0.0
	for i in 10: sim.campaign.reinforcements()
	qa.check(batch.roster.size() == expected_batch and batch.spawned == 0,"Unavailable spawn capacity retains all pending enemies")
	sim.elapsed = 1000
	sim.campaign.reinforcements()
	qa.check(batch.roster.size() == expected_batch,"Pending batch does not expire with time")
	sim.campaign.queue_batch("blocked_fixture",7,["normal"])
	qa.check(sim.campaign.reinforcement_batches.filter(func(b): return b.id == "blocked_fixture").size() == 1,"Event reentry cannot enqueue the same batch twice")
