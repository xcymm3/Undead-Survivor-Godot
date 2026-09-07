extends SceneTree
## Deliberate offline integration verification; never starts a visible window or writes a score.
var errors: Array[String] = []
var checks := 0
var game

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		errors.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.set_process(false)
	var data = root.get_node("Data")
	var simulation = load("res://scripts/simulation.gd")
	var sim = simulation.new(game.arena)
	sim.add_pawn("solo","验证",0)
	sim.pawns.solo.pos = Vector2(0,9)
	sim.start("practice")
	await physics_frame
	check(sim.zombies.size() == 4,"Practice must have all four source targets")
	for pair in [[1,9],[6,39],[7,44],[8,49],[9,53],[11,61],[12,64],[20,88]]:
		check(data.wave_settings(pair[0]).count == pair[1],"Wave count %s" % pair[0])
	check(data.wave_settings(20).speed == 2.8 and data.wave_settings(20).rate == 2.8,"Wave speed/spawn caps")
	check(data.water(Vector2(0,-17)),"River water data")
	check(not data.water(Vector2(-10,data.river_center(-10))),"Bridge support")
	var route = game.arena.path_to(Vector2(1,-30),Vector2(0,9))
	check(route.size() > 3,"Cross-river path must exist")
	for i in range(1,route.size()): check(game.arena.clear(route[i-1],route[i]),"Path segment must not cross a water/solid corner")
	var p: Dictionary = sim.pawns.solo
	p.pos = Vector2(0,-17)
	sim.step(1.0/60)
	check(p.hp == 90 and p.pos.y > 0,"Water damage and respawn")
	p.pos = Vector2(0,9)
	sim.submit("solo",{"jump":true,"y":-1.0})
	sim.step(1.0/60)
	var velocity: float = p.velocity
	sim.submit("solo",{"jump":true,"y":-1.0})
	sim.step(1.0/60)
	check(p.velocity < velocity,"No airborne double jump")
	for i in 60: sim.step(1.0/60)
	check(p.height == 0,"Jump lands")
	check(absf(p.pos.y-5.08) < .25,"Source jump travel distance")
	p.pos = Vector2(0,9)
	p.height = 0.0
	p.velocity = 0.0
	for i in data.weapons.size():
		p.weapon = i
		p.requested = i
		p.cooldown = 0.0
		p.fire_anim = 0.0
		p.trigger = false
		var initial: int = p.ammo[i]
		sim.submit("solo",{"weapon":i,"fire":true})
		sim.step(1.0/60)
		check(p.ammo[i] == initial-(0 if i == 6 else 1),"Weapon fires and consumes its own magazine %d" % i)
		game.weapon.sync(p,.016,sim.elapsed)
		check(game.weapon.animations[i] != null and game.weapon.animations[i].has_animation("fire") and game.weapon.animations[i].has_animation("reload"),"Imported native animations %d" % i)
		for j in 70:
			sim.submit("solo",{"weapon":i})
			sim.step(1.0/60)
		if i != 6:
			sim.submit("solo",{"weapon":i,"reload":true})
			sim.step(1.0/60)
			check(p.reloading,"Reload begins %d" % i)
			for j in 230:
				sim.submit("solo",{"weapon":i})
				sim.step(1.0/60)
			check(p.ammo[i] == data.weapons[i].capacity and not p.reloading,"Reload completes %d" % i)
	# Center-aimed hits use muzzle rays, actual animated cuboids and world occlusion.
	sim.zombies.clear()
	p.weapon = 0
	p.requested = 0
	p.cooldown = 0.0
	p.fire_anim = 0.0
	p.trigger = false
	p.pos = Vector2(0,9)
	sim.spawn(Vector2(0,3),"normal")
	sim.submit("solo",{"fire":true})
	sim.step(1.0/60)
	check(sim.zombies[0].hp == 0,"Rifle center ray headshot kills normal enemy")
	var dead = sim.zombies[0]
	for i in 181: sim.step(1.0/60)
	check(dead.hp == 100,"Practice target respawns after three seconds")
	# Native ray traversal: piercing stops at scenery and counts a shot only once.
	sim.zombies.clear()
	p.weapon = 7
	p.requested = 7
	p.pos = Vector2(0,9)
	p.pitch = 0.0
	p.yaw = 0.0
	p.cooldown = 0.0
	p.fire_anim = 0.0
	p.trigger = false
	sim.spawn(Vector2(0,3),"normal")
	sim.spawn(Vector2(0,0),"normal")
	var hits_before: int = p.hits
	sim.fire(p,data.weapons[7])
	check(sim.zombies[0].hp == 64 and sim.zombies[1].hp == 64,"Flame penetrates multiple targets without headshot bonus")
	check(p.hits == hits_before+1,"Multi-target attack counts as one landed shot")
	sim.zombies.clear()
	p.pos = Vector2(-13.5,-19)
	sim.spawn(Vector2(-13.5,-29),"normal")
	sim.fire(p,data.weapons[7])
	check(sim.zombies[0].hp == 100,"Flame must stop at the station wall")
	var enemy_view = load("res://scripts/enemy_view.gd")
	sim.zombies.clear()
	sim.spawn(Vector2(0,0),"shield")
	var front = enemy_view.hit(sim.zombies[0],Vector3(0,1.7,4),Vector3.FORWARD,10,sim.elapsed,true)
	var back = enemy_view.hit(sim.zombies[0],Vector3(0,1.7,-4),Vector3.BACK,10,sim.elapsed,true)
	check(not front.is_empty() and front.armor and not front.head,"Shield protects frontal rays")
	check(not back.is_empty() and not back.armor,"Shield does not protect rear rays")
	for weapon_index in [4,8]:
		var shotgun: Dictionary = data.weapons[weapon_index]
		var max_spread = 0.0
		for pellet in int(shotgun.pellets): max_spread = maxf(max_spread,absf(data.pellet(shotgun,pellet,1).x))
		check(is_equal_approx(max_spread,shotgun.spread),"Full-width shotgun fan %d" % weapon_index)
		check(roundi(shotgun.damage*shotgun.pellets) == (280 if weapon_index == 4 else 192),"Shotgun aggregate damage %d" % weapon_index)
	p.pos = Vector2(0,9)
	# Armor break, shield bypass, permanent rage, giant health and football locking.
	for kind in data.enemies:
		sim.zombies.clear()
		sim.spawn(Vector2(0,0),kind)
		var z: Dictionary = sim.zombies[0]
		check(z.hp == data.enemies[kind].health,"Exact enemy HP "+kind)
		game.enemies.sync(sim.zombies,sim.elapsed,false)
		if kind in ["cone","bucket"]:
			sim.hit_enemy(z,z.armor,true,p,Vector3.ZERO)
			check(z.kind == "normal" and z.body == 100,"Armor transforms "+kind)
		if kind == "shield":
			sim.hit_enemy(z,200,false,p,Vector3.ZERO)
			check(z.hp == 0,"Shield can be bypassed from exposed body")
		if kind == "berserker":
			sim.hit_enemy(z,600,true,p,Vector3.ZERO)
			check(z.rage and z.rage_pause > 0,"Permanent half-health rage")
	sim = simulation.new(game.arena)
	sim.add_pawn("solo","验证",0)
	sim.start("survival")
	sim.wave = 7
	sim.prepare_wave()
	check(sim.roster.has("football"),"Wave seven guarantees football")
	p = sim.pawns.solo
	p.pos = Vector2(0,9)
	sim.zombies.clear()
	sim.spawn(Vector2(0,0),"football")
	var football: Dictionary = sim.zombies[0]
	sim.update_zombie(football,p,.01)
	var locked: Vector2 = football.charge_direction
	check(football.state == "windup","Football charges with clear path")
	p.pos.x = 5
	sim.update_zombie(football,p,.1)
	check(football.charge_direction == locked,"Football must not retarget during windup")
	sim.zombies.clear()
	sim.roster.clear()
	p.hp = 20
	sim.add_pawn("peer","队友",1)
	sim.pawns.peer.hp = 0
	sim.step(.016)
	check(sim.cleared == 7 and sim.rest > 0 and p.hp == 100 and sim.pawns.peer.hp == 100,"Wave clear heals and revives everyone")
	p.hp = 0
	sim.pawns.peer.hp = 100
	sim.step(.016)
	check(not sim.failed,"One teammate death does not end coop")
	sim.pawns.peer.hp = 0
	sim.step(.016)
	check(sim.failed,"Entire party death ends coop")
	# Charge cancellation at water differs from obstacle stun.
	sim = simulation.new(game.arena)
	sim.add_pawn("solo","验证",0)
	sim.wave = 7
	sim.spawn(Vector2(0,-14.6),"football")
	football = sim.zombies[0]
	football.state = "charging"
	football.state_time = 1.0
	football.charge_direction = Vector2(0,-1)
	sim.update_zombie(football,sim.pawns.solo,.1)
	check(football.state == "ready" and football.charge_cooldown > 0,"Water cancels a charge without stun")
	football.pos = Vector2(0,-37.8)
	football.state = "charging"
	football.state_time = 1.0
	sim.update_zombie(football,sim.pawns.solo,.15)
	check(football.state == "stunned","Solid obstacle stuns a charging football")
	# Reject client-authoritative fields and malformed numerical input.
	sim = simulation.new(game.arena)
	sim.add_pawn("solo","验证",0)
	sim.submit("solo",{"hp":999,"pos":Vector2(99,99),"kills":999,"x":50})
	check(sim.pawns.solo.hp == 100 and sim.pawns.solo.pos.x < 22 and sim.pawns.solo.kills == 0 and sim.pawns.solo.input.x == 1,"Input authority and movement clamp")
	sim.submit("solo",{"yaw":NAN})
	check(sim.pawns.solo.input.x == 1,"Reject nonfinite client command")
	# Exercise every menu without presenting it or changing persisted settings.
	for method in ["show_home","show_settings","show_guide","show_scores","show_multiplayer","show_pause"]:
		game.ui.call(method)
		await process_frame
	game.return_home()
	game.queue_free()
	await process_frame
	print("RUNTIME VALIDATION: %d checks; %d failures" % [checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
