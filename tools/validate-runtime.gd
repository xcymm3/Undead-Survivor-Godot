extends SceneTree
## Deliberate offline integration verification; never starts a visible window or writes a score.
var errors: Array[String] = []
var checks := 0
var game
class EmptyArena extends Node3D:
	func clear(a: Vector2, b: Vector2, _allow_water := false) -> bool:
		return minf(a.x,b.x) >= -21.05 and maxf(a.x,b.x) <= 21.05 and minf(a.y,b.y) >= -47.05 and maxf(a.y,b.y) <= 13.05

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
	check(p.get("grounded",false) and absf(p.height) < .08,"Capsule lands on actual ground surface")
	check(absf(p.pos.y-5.08) < .25,"Source jump travel distance")
	await validate_character_physics(simulation)
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
		var inside_cone = true
		var quadrants = {}
		for pellet in int(shotgun.pellets):
			var offset: Vector2 = data.pellet(shotgun,pellet,1)
			inside_cone = inside_cone and Vector2(offset.x/shotgun.spread,offset.y/shotgun.spreadVertical).length() <= 1.00001
			quadrants[Vector2(signf(offset.x),signf(offset.y))] = true
		check(inside_cone and quadrants.size() == 4,"Shotgun circular cone covers four quadrants %d" % weapon_index)
		check(data.pellet(shotgun,1,1) != data.pellet(shotgun,1,2),"Shotgun pattern varies per shot %d" % weapon_index)
		check(roundi(shotgun.damage*shotgun.pellets) == (280 if weapon_index == 4 else 192),"Shotgun aggregate damage %d" % weapon_index)
	# Exercise delayed melee through normal commands, including wide coverage and deduplication.
	var melee = simulation.new(game.arena)
	melee.mode = "practice"
	melee.add_pawn("solo","斧头验证",0)
	var attacker: Dictionary = melee.pawns.solo
	attacker.pos = Vector2(0,9)
	attacker.weapon = 6
	attacker.requested = 6
	for point in [Vector2(2,7.5),Vector2(0,5.8),Vector2(-2,7.5),Vector2(0,10.8),Vector2(0,4.5)]: melee.spawn(point,"normal")
	melee.submit("solo",{"weapon":6,"fire":true})
	melee.step(1.0/60)
	for i in 5: melee.step(1.0/60)
	check(melee.zombies.all(func(z): return z.hp == 100),"Axe windup cannot cause damage")
	for i in 25: melee.step(1.0/60)
	check(melee.zombies[0].hp == 0 and melee.zombies[1].hp == 0 and melee.zombies[2].hp == 0,"Axe sweep covers left center right and reaches beyond three units")
	check(melee.zombies[3].hp == 100 and melee.zombies[4].hp == 100,"Axe cannot hit behind or beyond reach")
	check(attacker.hits == 1,"Axe multi-target sweep counts once in accuracy")
	melee = simulation.new(game.arena)
	melee.mode = "practice"
	melee.add_pawn("solo","斧头验证",0)
	attacker = melee.pawns.solo
	attacker.pos = Vector2(0,9)
	attacker.weapon = 6
	attacker.requested = 6
	melee.spawn(Vector2(0,7),"giant")
	var initial_hp: float = melee.zombies[0].hp
	melee.submit("solo",{"weapon":6,"fire":true})
	for i in 35: melee.step(1.0/60)
	check(initial_hp-melee.zombies[0].hp == 300 or initial_hp-melee.zombies[0].hp == 450,"Axe damages each enemy only once per swing")
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
	check(football.state == "windup","Football charges with clear path")
	p.pos.x = 5
	sim.update_zombie(football,p,.1)
	check(football.charge_direction == Vector2.ZERO and football.charge_target == p.pos,"Windup tracks target without locking direction")
	var expected_direction: Vector2 = (p.pos-football.pos).normalized()
	sim.update_zombie(football,p,.25)
	check(football.state == "charging" and football.charge_direction.is_equal_approx(expected_direction),"Direction locks to current target at windup completion")
	check(is_equal_approx(football.state_time,4.0),"Charge starts with four second duration")
	p.pos.x = -5
	sim.update_zombie(football,p,.01)
	check(football.charge_direction.is_equal_approx(expected_direction),"Direction remains fixed after charge starts")
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
	check(football.state == "stunned" and is_equal_approx(football.state_time,2.0),"Solid obstacle stuns a charging football for two seconds")
	validate_charge_combat(simulation)
	# Reject client-authoritative fields and malformed numerical input.
	sim = simulation.new(game.arena)
	sim.add_pawn("solo","验证",0)
	sim.submit("solo",{"hp":999,"pos":Vector2(99,99),"kills":999,"x":50})
	check(sim.pawns.solo.hp == 100 and sim.pawns.solo.pos.x < 22 and sim.pawns.solo.kills == 0 and sim.pawns.solo.input.x == 1,"Input authority and movement clamp")
	sim.submit("solo",{"yaw":NAN})
	check(sim.pawns.solo.input.x == 1,"Reject nonfinite client command")
	# Spawning must not depend on one or several players' camera directions.
	for facing in [0.0,PI/2,PI,-PI/2]:
		var spawning = simulation.new(game.arena)
		spawning.add_pawn("solo","刷怪验证",0)
		spawning.pawns.solo.pos = Vector2(14.2,-9)
		spawning.pawns.solo.yaw = facing
		spawning.roster = ["normal"]
		spawning.credit = 1
		spawning.step(.001)
		check(spawning.spawned == 1,"Outward-facing player cannot stop spawning: "+str(facing))
	var spawning = simulation.new(game.arena)
	for i in 4:
		spawning.add_pawn(str(i),"队友",i)
		spawning.pawns[str(i)].yaw = i*PI/2
	spawning.roster = ["normal"]
	spawning.credit = 1
	spawning.step(.001)
	check(spawning.spawned == 1,"Opposing coop camera directions cannot block spawning")
	for wave_number in [7,9,11,30]:
		spawning = simulation.new(game.arena)
		spawning.wave = wave_number
		for i in 4: spawning.add_pawn(str(i),"队友",i)
		spawning.spawn(Vector2(0,-40),"football")
		spawning.roster = ["football","football","giant"]
		spawning.credit = 1
		spawning.step(.001)
		check(spawning.zombies.filter(func(z): return z.kind == "football" and z.hp > 0).size() == 2 and spawning.roster == ["football","giant"],"Second football spawns while first is alive at wave "+str(wave_number))
		spawning.credit = 1
		spawning.step(.001)
		check(spawning.zombies.filter(func(z): return z.kind == "football" and z.hp > 0).size() == 3,"Consecutive footballs spawn without a single-enemy cap")
		spawning.credit = 1
		spawning.step(.001)
		check(spawning.roster.is_empty() and spawning.zombies.any(func(z): return z.kind == "giant"),"Mixed roster preserves spawn order after multiple footballs")
	spawning = simulation.new(game.arena)
	spawning.add_pawn("solo","容量验证",0)
	for i in 256: spawning.spawn(Vector2(0,-40),"normal")
	spawning.roster = ["normal"]
	spawning.credit = 1
	spawning.step(.001)
	check(spawning.alive_count() == 257,"Ordinary enemies have no 256-unit gameplay cap")
	game.enemies.sync(spawning.zombies,0,false)
	check(game.enemies.batches.normal.visible_instance_count == 257,"All enemies beyond previous rendering capacity remain visible")
	# Cancelling a magazine and a shell reload preserves only completed ammunition.
	for index in [0,4]:
		var arsenal = simulation.new(game.arena)
		arsenal.add_pawn("solo","换弹验证",0)
		var soldier: Dictionary = arsenal.pawns.solo
		soldier.weapon = index
		soldier.requested = index
		soldier.ammo[index] = 1
		arsenal.update_arsenal(soldier,{"weapon":index,"reload":true},.01)
		arsenal.update_arsenal(soldier,{"weapon":index},.1)
		arsenal.update_arsenal(soldier,{"weapon":1},.01)
		check(not soldier.reloading and soldier.switch > 0 and soldier.ammo[index] == 1,"Switch cancels partial reload without free ammo: "+str(index))
		arsenal.update_arsenal(soldier,{"weapon":1},.4)
		check(soldier.weapon == 1,"Cancelled reload switches to requested weapon")
		arsenal.update_arsenal(soldier,{"weapon":index},.01)
		arsenal.update_arsenal(soldier,{"weapon":index},.4)
		arsenal.update_arsenal(soldier,{"weapon":index,"reload":true},.01)
		arsenal.update_arsenal(soldier,{"weapon":index},float(data.weapons[index].reloadDuration)+.01)
		var loaded: int = soldier.ammo[index]
		arsenal.update_arsenal(soldier,{"weapon":1},.01)
		check(loaded == (2 if index == 4 else 30) and soldier.ammo[index] == loaded,"Completed shell or magazine remains after switching")
	var session = root.get_node("Session")
	check(data.settings.network_stats,"Network panel defaults enabled")
	check(session.network_metrics(1000).quality == "测量中","No network sample cannot claim good quality")
	session.probes = {1:{"sent":1000,"rtt":-1},2:{"sent":2000,"rtt":-1}}
	session.record_snapshot(10,1000)
	session.receive_sequence = 10
	session.record_probe_reply(1,1040)
	check(session.network_metrics(2500).rtt == 40 and session.network_metrics(2500).loss == 0,"Probe RTT uses local clock; pending probe is not premature loss")
	check(session.network_metrics(5000).quality == "较差","Timed-out round trip marks connection poor")
	session.record_snapshot(13,5000)
	check(session.network_metrics(5000).loss == 50,"Missing world sequences measure actual synchronization loss")
	session.record_probe_reply(999,6000)
	check(session.probes.size() == 2,"Unsolicited replies cannot fabricate telemetry")
	check(session.network_metrics(40000).samples == 0,"Old samples expire from network window")
	session.probes.clear()
	session.snapshot_samples.clear()
	session.receive_sequence = -1
	session.last_probe_reply = 0
	# Nonuniform tracer scale must be applied in local space after orientation.
	for direction in [Vector3(1,.2,-2).normalized(),Vector3(-1,-.3,2).normalized(),Vector3(0,0,-1)]:
		var start = Vector3(3,1.2,8)
		var end = start+direction*20
		game.effects.particles.clear()
		game.effects.tracer(start,end,false)
		game.effects.step(0)
		var transform: Transform3D = game.effects.particle_transform(game.effects.particles[0])
		check((transform*Vector3(0,0,-.5)).distance_to(start) < .001 and (transform*Vector3(0,0,.5)).distance_to(end) < .001,"Tracer starts at muzzle and ends at impact for arbitrary headings")
	var survivors = load("res://scripts/survivor_model.gd").PROFILES
	check(survivors.size() == 4 and survivors.filter(func(v): return v.sex == "male").size() == 3 and survivors[3].sex == "female","Exactly three male survivors and one female")
	var assignment = simulation.new(game.arena)
	var seen: Dictionary = {}
	for i in 4:
		assignment.add_pawn(str(i),"Survivor",i)
		seen[assignment.pawns[str(i)].appearance[0]] = true
	check(seen.size() == 4,"Four-player roster randomly assigns distinct models")
	var before: Array = assignment.pawns["0"].appearance.duplicate()
	assignment.pawns.erase("1")
	assignment.add_pawn("replacement","Replacement",1)
	check(assignment.pawns["0"].appearance == before,"Joining player does not reroll existing avatars")
	seen.clear()
	for pawn in assignment.pawns.values(): seen[pawn.appearance[0]] = true
	check(seen.size() == 4,"Replacement player takes the free survivor")
	for model in 4:
		var actor = load("res://scripts/partner_view.gd").new()
		game.add_child(actor)
		p.hp = 100
		p.height = 0
		p.pitch = 0
		p.appearance = [model,0,0]
		actor.setup(p)
		for index in 10:
			p.weapon = index
			p.requested = index
			p.reloading = false
			p.fire_anim = 0
			actor.sync(p,.016)
			var hand = actor.skeleton.find_bone("Fist.R")
			var grip: Vector3 = actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(hand).origin
			check(actor.grip_position().distance_to(grip) < .08,"Third-person grip follows fist for weapon "+str(index))
			check(actor.muzzle_position().is_finite(),"Finite model muzzle for weapon "+str(index))
		actor.queue_free()
	# Exercise every menu without presenting it or changing persisted settings.
	for method in ["show_home","show_settings","show_guide","show_scores","show_multiplayer","show_pause"]:
		game.ui.call(method)
		await process_frame
	game.return_home()
	game.queue_free()
	await process_frame
	print("RUNTIME VALIDATION: %d checks; %d failures" % [checks,errors.size()])
	quit(0 if errors.is_empty() else 1)

func validate_charge_combat(simulation) -> void:
	# Empty terrain isolates timing and impact; map boundary still clips knockback.
	var viewport = SubViewport.new()
	viewport.own_world_3d = true
	root.add_child(viewport)
	var world = EmptyArena.new()
	viewport.add_child(world)
	var sim = simulation.new(world)
	sim.add_pawn("solo","冲撞验证",0)
	var p: Dictionary = sim.pawns.solo
	p.pos = Vector2(0,9)
	sim.spawn(Vector2(-20,0),"football")
	var z: Dictionary = sim.zombies[0]
	z.state = "charging"
	z.state_time = 4.0
	z.charge_direction = Vector2.RIGHT
	for i in 39: sim.update_zombie(z,p,.1)
	check(z.state == "charging","Missed charge continues beyond old 1.9 second limit")
	sim.update_zombie(z,p,.101)
	check(z.state == "stunned" and is_equal_approx(z.state_time,.45),"Charge ends at four seconds with existing miss recovery")
	for protected in [false,true]:
		p.pos = Vector2(1.3,0)
		p.hp = 100
		p.protection = .3 if protected else 0.0
		z.pos = Vector2.ZERO
		z.state = "charging"
		z.state_time = 4.0
		sim.update_zombie(z,p,.01)
		check(p.hp == (100 if protected else 70),"Charge deals thirty damage and respects protection")
		check(p.pos.is_equal_approx(Vector2(1.3 if protected else 1.95,0)),"Successful charge knocks player back 0.65 metres only once")
		check(z.state == "ready" and z.charge_cooldown > 0,"Player impact ends charge")
	p.pos = Vector2(21,0)
	sim.charge_knockback(p,Vector2.RIGHT)
	check(p.pos.x <= 21.05,"Knockback cannot cross map boundary")
	p.hp = 20
	p.protection = 0
	sim.damage_pawn(p,z,30)
	check(p.hp == 0 and sim.culprit == z.id,"Lethal charge clamps health and records culprit")
	p.hp = 100
	p.protection = 0
	sim.damage_pawn(p,z)
	check(p.hp == 90,"Ordinary zombie attacks retain ten damage")
	sim.dispose()
	viewport.free()

func physics_box(parent: Node3D, center: Vector3, size: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	var collider = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)
	body.position = center
	parent.add_child(body)
	return body

func validate_character_physics(simulation) -> void:
	var viewport = SubViewport.new()
	viewport.own_world_3d = true
	root.add_child(viewport)
	var world = EmptyArena.new()
	viewport.add_child(world)
	physics_box(world,Vector3(0,-.5,0),Vector3(42,1,60))
	physics_box(world,Vector3(3,.4,0),Vector3(2,.8,2))
	physics_box(world,Vector3(-3,2,0),Vector3(.3,4,4))
	physics_box(world,Vector3(0,2.3,0),Vector3(2,.2,2))
	var ramp = physics_box(world,Vector3(7,.5,5),Vector3(4,.2,4))
	ramp.rotation.z = .2
	await physics_frame
	var sim = simulation.new(world)
	sim.add_pawn("solo","物理验证",0)
	var p: Dictionary = sim.pawns.solo
	p.pos = Vector2(0,6)
	sim.submit("solo",{"jump":true})
	sim.submit("solo",{"jump":false})
	sim.update_pawn(p,1.0/60)
	check(p.velocity > 8,"Queued jump survives a newer input packet before the physics tick")
	check(sim.player_bodies.solo is CharacterBody3D,"Player movement owns a native CharacterBody3D")
	check(sim.player_bodies.solo.get_child(0).shape is CapsuleShape3D,"Native capsule provides player collision volume")
	var peak: float = p.height
	for i in 65:
		sim.update_pawn(p,1.0/60)
		peak = maxf(peak,p.height)
	check(peak > 1.9 and peak < 2.02 and p.grounded,"Native jump preserves height and lands without a y=0 clamp")
	p.pos = Vector2(0,0)
	p.height = 0
	p.velocity = 0
	sim.submit("solo",{"jump":true})
	peak = 0
	for i in 60:
		sim.update_pawn(p,1.0/60)
		peak = maxf(peak,p.height)
	check(peak > .1 and peak < .45 and p.grounded,"Low ceiling stops upward motion and player falls back down")
	p.pos = Vector2(3,0)
	p.height = 2
	p.velocity = -1
	for i in 60: sim.update_pawn(p,1.0/60)
	check(p.grounded and absf(p.height-.8) < .01,"Capsule lands on elevated platform at its actual height")
	sim.submit("solo",{"jump":true})
	sim.update_pawn(p,1.0/60)
	check(p.velocity > 8 and p.height > .9,"Player can jump again from an elevated platform")
	p.pos = Vector2(-2,0)
	p.height = 0
	p.velocity = 0
	for i in 30:
		sim.submit("solo",{"x":-1.0,"y":1.0})
		sim.update_pawn(p,1.0/60)
	check(p.pos.x > -2.56 and p.pos.y > 1,"Native capsule stops at wall and slides tangentially")
	p.pos = Vector2(-2,0)
	p.height = 0
	p.velocity = 0
	sim.charge_knockback(p,Vector2.LEFT)
	check(p.pos.x > -2.56 and p.pos.x < -2.1,"Charge knockback sweeps capsule and cannot push through wall")
	p.pos = Vector2(7,5)
	p.height = 2
	p.velocity = -1
	p.air = Vector2.ZERO
	sim.submit("solo",{})
	for i in 60: sim.update_pawn(p,1.0/60)
	check(p.grounded and p.height > .5 and p.height < .7,"Capsule detects support on a walkable slope")
	var slope_start: float = p.height
	for i in 10:
		sim.submit("solo",{"x":1.0})
		sim.update_pawn(p,1.0/60)
	check(p.grounded and p.height > slope_start+.08,"Native movement climbs a slope without losing support")
	var snapshot: Dictionary = sim.snapshot()
	check(snapshot.pawns.solo.grounded and not snapshot.pawns.solo.has("body"),"Snapshots carry results without physical node references")
	var client = simulation.new(world)
	client.apply_snapshot(snapshot)
	check(client.player_bodies.is_empty() and client.pawns.solo.pos == p.pos,"Receiving client does not run authoritative character bodies")
	var capsule = sim.player_bodies.solo
	sim.pawns.erase("solo")
	sim.step(.01)
	check(not is_instance_valid(capsule) and sim.player_bodies.is_empty(),"Leaving player removes native body")
	sim.dispose()
	viewport.free()
	var bridge_sim = simulation.new(game.arena)
	bridge_sim.add_pawn("solo","桥面验证",0)
	var walker: Dictionary = bridge_sim.pawns.solo
	walker.pos = Vector2(-10,-19.5)
	for i in 120:
		bridge_sim.submit("solo",{"y":1.0})
		bridge_sim.update_pawn(walker,1.0/60)
	check(walker.pos.y > -12 and walker.hp == 100,"Native capsule crosses actual bridge without water damage")
	var remaining_body = bridge_sim.player_bodies.solo
	bridge_sim.dispose()
	check(not is_instance_valid(remaining_body),"Reset disposes remaining native bodies")
