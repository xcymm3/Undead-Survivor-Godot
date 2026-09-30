extends RefCounted
## Exercise real shot events and presentation consumers without rendering a window.

static func casings_only(particles: Array, origin: Vector3) -> bool:
	return particles.all(func(p): return p.pos.distance_to(origin) < .01 and p.velocity.length() < 3 and p.get("gravity",true) and p.get("scale",Vector3.ONE*p.size).length() < .12)

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
			check.call(game.effects.particles.size() == count and casings_only(game.effects.particles,game.weapon.muzzle_position()),w.id+": firing emits only spent casings, no beam or flying bullet streaks")
			if w.id in ["shotgun","auto-shotgun"]:
				check.call(shots[0].pellet_ends.size() > 1 and game.effects.particles.size() == 1,w.id+": multiple pellet trajectories remain authoritative but are not drawn")
		p.fire_anim = 0.0
		game.weapon.sync(p,.06,.06)
		partner.sync(p,.06)
		check.call(not game.weapon.muzzle.visible and not partner.flash.visible,w.id+": idle weapon has no muzzle glow")
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
	check.call(game.effects.particles.size() == 1 and casings_only(game.effects.particles,origin),"Turret fire has no visible bullet trajectory")
	state.prop_clock = 1.06
	structures.sync(state)
	check.call(not structures.actors[turret.id].flash.visible,"Turret muzzle flash expires promptly")
	structures.sync(game.sim.defense)
	game.sim.zombies = saved_zombies
	game.sim.events = saved_events
	game.sim.melee_swings = saved_swings
	game.effects.clear()
	game.sound.clear_effects()
	game.weapon.sync(game.local_pawn(),.016,game.sim.elapsed)
	partner.free()
