extends SceneTree
## Shotgun-only supply fixture. Traversal uses limited inputs and normal authority.
class Perspective extends RefCounted:
	var sim
	var arena
	var id: String
	func _init(game, pawn_id: String):
		sim = game.sim
		arena = game.arena
		id = pawn_id
	func local_pawn() -> Dictionary: return sim.pawns[id]

var game
var failures: Array[String] = []
var runs: Array = []
var checks = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("SHOTGUN FAIL: ",message)
func _initialize() -> void: call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	game.start_solo("campaign",71245)
	var data = root.get_node("Data")
	for w in data.weapons:
		if w.id not in ["shotgun","auto-shotgun"]: continue
		check(is_equal_approx(game.sim.shotgun_damage_scale(w,5),1),"Full close damage "+w.id)
		check(is_equal_approx(game.sim.shotgun_damage_scale(w,16),.6),"Mid distance decay "+w.id)
		check(is_equal_approx(game.sim.shotgun_damage_scale(w,30),.2),"Far damage floor "+w.id)
	await ballistics()
	for party in [1,2]:
		for seed_value in [71245,71246]:
			game.return_home()
			game.start_solo("campaign",seed_value)
			if party == 2:
				game.sim.campaign = null
				game.sim.add_pawn("qa1","队友",1)
				game.sim.random.seed = seed_value
				game.sim.start("campaign")
			# Initial fixture only: preserve tiers, counts and normal ammo budgets.
			var pump = -1
			var auto = -1
			for i in data.weapons.size():
				if data.weapons[i].id == "shotgun": pump = i
				if data.weapons[i].id == "auto-shotgun": auto = i
			for loot in game.sim.campaign.state.loot: loot.weapon = auto if loot.tier == "A" else pump
			var drivers: Dictionary = {}
			for p in game.sim.pawns.values():
				p.ammo[p.primary] = 0
				p.reserves[p.primary] = 0
				# No hidden sidearm fallback in the all-shotgun firearm fixture.
				p.ammo[p.secondary] = 0
				p.reserves[p.secondary] = 0
				p.primary = pump
				p.weapon = pump
				p.requested = pump
				p.ammo[pump] = int(data.weapons[pump].capacity)
				p.reserve = int(data.weapons[pump].capacity)*5
				p.reserves[pump] = p.reserve
				var driver = load("res://tools/campaign-limited-driver.gd").new(Perspective.new(game,p.id),false)
				driver.prefer_shotgun = true
				drivers[p.id] = driver
			await physics_frame
			var timings: Array = []
			var previous: Dictionary = {}
			var multi_kill_steps = 0
			for tick in 9600:
				if game.sim.won or game.sim.failed: break
				for id in drivers:
					if previous.get(id,-1) != drivers[id].index:
						previous[id] = drivers[id].index
						timings.append({"player":id,"task":drivers[id].index,"at":game.sim.elapsed,"hp":game.sim.pawns[id].hp})
					game.sim.submit(id,drivers[id].command(.05))
				var before: int = game.sim.kills
				game.sim.step(.05)
				if game.sim.kills-before >= 2: multi_kill_steps += 1
				if tick % 100 == 0: await process_frame
			var players: Array = []
			for p in game.sim.pawns.values():
				for index in [0,1,2,3,5,7,9]: check(p.gun_shots[index] == 0,"No non-shotgun firearm used")
				players.append({"id":p.id,"hp":p.hp,"shots":p.gun_shots,"kills":p.kills,"primary":p.primary,"ammo":p.ammo[p.primary],"reserve":p.reserve,"task":drivers[p.id].index})
			var result = {"party":party,"seed":seed_value,"won":game.sim.won,"failed":game.sim.failed,"seconds":game.sim.elapsed,"kills":game.sim.kills,"players":players,"timings":timings,"multi_kill_steps_including_grenades":multi_kill_steps,"diagnostics":game.sim.campaign.diagnostics()}
			runs.append(result)
			print("SHOTGUN RESULT ",JSON.stringify(result))
			# Survival is an observation, never discard a death or loosen input limits.
			check(game.sim.won or game.sim.failed,"Sample resolves within eight minutes")
	var report = {"checks":checks,"failures":failures,"all_samples_won":runs.all(func(result): return result.won),"runs":runs,"boundary":"Limited synthetic solo/duo shared-authority samples; not human or Steam verification. All A/B supplies are shotguns only in this fixture. Axe and grenades remain available; no non-shotgun firearm ammunition."}
	var f = FileAccess.open("res://artifacts/shotgun-acceptance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "))
	f.close()
	game.return_home()
	game.queue_free()
	await process_frame
	await physics_frame
	print("SHOTGUN TRAVERSAL: %d/%d wins" % [runs.filter(func(result): return result.won).size(),runs.size()])
	print("SHOTGUN VALIDATION: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func ballistics() -> void:
	# Actual animated hit geometry and fire path, isolated from horde movement.
	var data = root.get_node("Data")
	var p: Dictionary = game.local_pawn()
	p.pos = Vector2(0,60)
	p.yaw = 0
	p.pitch = -.08
	game.sim.campaign.state.departed = true
	game.arena.sync_campaign(game.sim.campaign.state)
	await physics_frame
	var w: Dictionary = data.weapons.filter(func(gun): return gun.id == "shotgun")[0].duplicate(true)
	p.weapon = data.weapons.find(data.weapons.filter(func(gun): return gun.id == "shotgun")[0])
	# A single straight pellet isolates per-pellet attenuation and target cap.
	w.pellets = 1
	w.spread = 0
	w.spreadVertical = 0
	game.sim.zombies.clear()
	for z in [55.0,54.2,53.4]: game.sim.spawn(Vector2(0,z),"normal")
	game.sim.fire(p,w)
	check(game.sim.zombies[0].hp < 100 and game.sim.zombies[1].hp < 100,"One pellet penetrates a second ordinary infected")
	check(game.sim.zombies[2].hp == 100,"One pellet cannot damage a third infected")
	check(is_equal_approx(100-game.sim.zombies[1].hp,(100-game.sim.zombies[0].hp)*.65),"Second body receives 65 percent pellet damage")
	var z: Dictionary = game.sim.zombies[0]
	z.body = 1000
	z.hp = 1000
	game.sim.stun(z,2.4)
	z.shove_velocity = Vector2(0,-8)
	z.shotgun_stagger_ready = -1
	game.sim.fire(p,w)
	check(z.state_time >= 2.4 and z.shove_velocity == Vector2(0,-8),"Shotgun flinch preserves shove duration and displacement")
	game.sim.zombies.clear()
	game.sim.spawn(Vector2(0,55),"football")
	game.sim.spawn(Vector2(0,54.2),"normal")
	game.sim.fire(p,w)
	check(game.sim.zombies[0].hp < float(data.enemies.football.health) and game.sim.zombies[1].hp == 100,"Football armor stops penetration")
	game.sim.zombies.clear()
	game.sim.spawn(Vector2(0,65),"normal")
	p.pos = Vector2(0,70)
	game.sim.campaign.state.departed = false
	game.arena.sync_campaign(game.sim.campaign.state)
	await physics_frame
	game.sim.fire(p,w)
	check(game.sim.zombies[0].hp == 100,"Closed departure door stops every pellet")
	game.sim.campaign.state.departed = true
	game.arena.sync_campaign(game.sim.campaign.state)
	p.pos = Vector2(0,60)
	await physics_frame
	var groups: Array = []
	for gun in data.weapons:
		if gun.id not in ["shotgun","auto-shotgun"]: continue
		p.weapon = data.weapons.find(gun)
		for distance in [4.0,6.0,12.0,24.0]:
			var kills: Array = []
			for shot in 12:
				game.sim.zombies.clear()
				for row in 2:
					for column in 3: game.sim.spawn(Vector2((column-1)*.65,60-distance-row*.8),"normal")
				p.gun_shots[p.weapon] = shot
				# Chest aim derived from target range; no bonus health or hitbox changes.
				p.pitch = atan2(1.2-(p.height+preload("res://scripts/player_body.gd").eye_height(p)),distance)
				var before: int = game.sim.kills
				game.sim.fire(p,gun)
				kills.append(game.sim.kills-before)
			groups.append({"weapon":gun.id,"distance":distance,"kills":kills})
	print("SHOTGUN GROUPS ",JSON.stringify(groups))
	var f = FileAccess.open("res://artifacts/shotgun-ballistics.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(groups,"  "))
	f.close()
