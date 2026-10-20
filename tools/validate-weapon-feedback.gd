extends RefCounted
## Exercise real shot events and presentation consumers without rendering a window.

static func casings_only(particles: Array, origin: Vector3) -> bool:
	return particles.all(func(p): return p.kind == "casing" and p.pos.distance_to(origin) < .2 and p.velocity.length() < 3 and p.get("gravity",true) and p.has("spin") and p.get("scale",Vector3.ONE*p.size).length() < .12)

static func validate(game, check: Callable) -> void:
	var data = game.get_node("/root/Data")
	var p: Dictionary = game.local_pawn().duplicate(true)
	p.hp = 100
	p.pos = Vector2(8,30)
	p.height = 3.0
	p.yaw = 0.0
	p.pitch = 0.0
	p.slot = 1
	p.aim = false
	p.reloading = false
	p.switch = 0.0
	p.pickup_remaining = 0.0
	var partner = load("res://scripts/partner_view.gd").new()
	game.add_child(partner)
	partner.setup(p)
	var saved_zombies: Array = game.sim.zombies
	var saved_events: Array = game.sim.events
	var saved_swings: Dictionary = game.sim.melee_swings.duplicate(true)
	game.sim.zombies = []
	game.sim.events = []
	for index in data.weapons.size():
		var w: Dictionary = data.weapons[index]
		p.weapon = index
		p.requested = index
		p.fire_anim = w.fireDuration
		game.weapon.sync(p,.016,0.0)
		partner.sync(p,.016)
		var gun: bool = w.get("kind","gun") == "gun"
		check.call(game.weapon.muzzle.visible == gun and partner.flash.visible == gun,w.id+": only firearms show a brief model-attached muzzle flash")
		game.effects.clear()
		game.sim.events.clear()
		game.sim.fire(p,w)
		var shots: Array = game.sim.events.filter(func(event): return event.kind == "shot")
		check.call(shots.size() == 1,w.id+": authority emits one weapon shot event")
		game.handle_effects(shots)
		if gun:
			var count = 0 if w.id == "revolver" else 1
			var casings: Array = game.effects.particles.filter(func(particle): return particle.get("kind","") == "casing")
			check.call(casings.size() == count and (casings_only(casings,game.weapon.muzzle_position()) or casings_only(casings,shots[0].from)),w.id+": ejects one spinning casing near the port except for the revolver")
			check.call(not game.effects.tracers.is_empty() and game.effects.flashes.size() == 1,w.id+": hitscan shot immediately draws tracer and muzzle flash")
			if w.id in ["shotgun","auto-shotgun"]:
				check.call(shots[0].pellet_ends.size() > 1 and game.effects.tracers.size() == shots[0].pellet_ends.size() and casings.size() == 1,w.id+": draws every pellet ray but ejects only one shell")
		else:
			check.call(game.effects.tracers.is_empty() and game.effects.flashes.is_empty(),w.id+": melee and flamethrower do not emit gun tracers")
		p.fire_anim = 0.0
		game.weapon.sync(p,.06,.06)
		partner.sync(p,.06)
		check.call(not game.weapon.muzzle.visible and not partner.flash.visible,w.id+": idle weapon has no muzzle glow")
	# Exercise real authority rays against cover and a live enemy, without stepping VFX.
	p.pos = Vector2(6,data.Maps.Defense.BOUNDS.end.y-5)
	p.height = 3
	p.yaw = PI
	p.aim = true
	p.weapon = 2
	game.sim.events.clear()
	game.sim.fire(p,data.weapons[2])
	var wall_shot: Dictionary = game.sim.events.filter(func(event): return event.kind == "shot")[0]
	check.call(wall_shot.get("surface_hits",[]).size() == 1 and wall_shot.to.is_equal_approx(wall_shot.surface_hits[0].position),"Authority ray includes a real surface impact at the tracer endpoint")
	game.sim.zombies.clear()
	game.sim.spawn(p.pos+Vector2(0,2),"normal")
	game.sim.zombies[0].hp = 2000
	game.sim.zombies[0].body = 2000
	game.sim.events.clear()
	game.sim.fire(p,data.weapons[2])
	var piercing_shot: Dictionary = game.sim.events.filter(func(event): return event.kind == "shot")[0]
	check.call(game.sim.zombies[0].hp < 2000 and piercing_shot.get("surface_hits",[]).size() == 1,"Piercing hitscan damages the enemy immediately and retains the wall endpoint beyond it")
	var pierced_health: float = game.sim.zombies[0].hp
	p.weapon = 3 # Revolver has no penetration; pistol retains its existing penetration.
	game.sim.events.clear()
	game.sim.fire(p,data.weapons[3])
	var enemy_shot: Dictionary = game.sim.events.filter(func(event): return event.kind == "shot")[0]
	var health: float = game.sim.zombies[0].hp
	check.call(health < pierced_health and enemy_shot.get("surface_hits",[]).is_empty(),"Nonpenetrating hitscan stops at the enemy without a false wall impact behind it")
	var session = game.get_node("/root/Session")
	var packet: Dictionary = bytes_to_var(session.encode_packet({"type":"effects","effects":[wall_shot]}).decompress_dynamic(2000000,FileAccess.COMPRESSION_DEFLATE))
	check.call(packet.effects[0].surface_hits[0].position == wall_shot.to,"Authoritative surface impacts survive the actual coop event encoding")
	game.effects.clear()
	game.handle_effects(game.sim.events)
	game.effects.step(.2)
	check.call(game.sim.zombies[0].hp == health,"Playing and expiring gun effects cannot apply damage again")
	var state: Dictionary = game.sim.defense.duplicate(true)
	var turret: Dictionary = state.structures[0]
	turret.owned = true
	turret.hp = turret.max_hp
	turret.fired_at = 1.0
	state.prop_clock = 1.0
	var structures = game.arena.scenery.structure_view
	structures.sync(state)
	check.call(structures.actors[turret.id].flash.is_visible_in_tree(),"Turret firing retains a small muzzle flash")
	game.effects.clear()
	var origin = Vector3(-6.3,4.55,-7)
	game.handle_effects([{"kind":"turret_shot","from":origin,"to":origin+Vector3(0,0,-100)}])
	check.call(game.effects.particles.size() == 1 and casings_only(game.effects.particles,origin) and game.effects.tracers.size() == 1,"Turret uses the same short tracer and single casing feedback")
	state.prop_clock = 1.06
	structures.sync(state)
	check.call(not structures.actors[turret.id].flash.visible,"Turret muzzle flash expires promptly")
	structures.sync(game.sim.defense)
	game.sim.zombies = saved_zombies
	game.sim.ray_index_valid = false
	game.sim.events = saved_events
	game.sim.melee_swings = saved_swings
	game.effects.clear()
	game.sound.clear_effects()
	game.weapon.sync(game.local_pawn(),.016,game.sim.elapsed)
	partner.free()
	validate_tracer_lifetime(game.effects,check)

static func validate_tracer_lifetime(fx, check: Callable) -> void:
	fx.clear()
	var saved_query: Callable = fx.collision_query
	fx.collision_query = Callable()
	var start = Vector3(0,4,0)
	var end = Vector3(0,4,-20)
	fx.gunshot(start,end)
	var transform: Transform3D = fx.tracer_transform(fx.tracers[0])
	check.call(transform.origin.is_equal_approx((start+end)*.5) and is_equal_approx(transform.basis.y.length(),20),"Tracer draws the full muzzle-to-target line immediately")
	fx.step(.04)
	check.call(fx.tracers.size() == 1 and fx.tracer_start(fx.tracers[0]).is_equal_approx(start),"Full line remains unchanged for forty milliseconds")
	check.call(fx.flashes.is_empty(),"Muzzle flash expires without lingering glow")
	fx.step(.03)
	check.call(fx.tracer_start(fx.tracers[0]).is_equal_approx((start+end)*.5) and fx.tracers[0].to == end,"Retraction moves only the start towards the fixed hit endpoint")
	var casing: Dictionary = fx.particles[0]
	check.call(not casing.basis.is_equal_approx(Basis.IDENTITY) and casing.pos.x > start.x,"Casing spins and ejects sideways under gravity")
	fx.step(.031)
	check.call(fx.tracers.is_empty() and fx.gun_mesh.visible_instance_count == 0,"Tracer is removed after the hold and retraction phases")
	fx.step(1)
	check.call(fx.particles.is_empty(),"Spent casing expires independently of tracer timing")
	fx.collision_query = func(_from, _to): return {"position":Vector3(0,4,-2),"normal":Vector3.BACK}
	fx.gunshot(start,end,[],[{"position":Vector3(0,4,-2),"normal":Vector3.BACK}])
	check.call(fx.tracers[0].to == Vector3(0,4,-2) and fx.particles.any(func(p): return p.get("kind","") == "surface"),"Cosmetic tracer clips to cover and wall hit emits bounded impact particles")
	fx.clear()
	fx.collision_query = Callable()
	for index in fx.TRACER_LIMIT+4: fx.gunshot(start,end)
	check.call(fx.tracers.size() == fx.TRACER_LIMIT and fx.flashes.size() == fx.FLASH_LIMIT,"Sustained fire keeps tracer and muzzle flash pools bounded")
	fx.clear()
	check.call(fx.gun_mesh.visible_instance_count == 0 and fx.tracers.is_empty() and fx.flashes.is_empty(),"Returning to menu clears all transient gun visuals")
	fx.collision_query = saved_query
