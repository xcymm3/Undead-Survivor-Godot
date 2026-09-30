extends RefCounted
## Exercise actual motion and holding transforms without a graphics process.

static func reset_pawn(sim, p: Dictionary) -> void:
	p.pos = Vector2(0,5)
	p.height = 3.0
	p.velocity = 0.0
	p.air = Vector2.ZERO
	p.crouch = 0.0
	p.hp = 100
	p.switch = 0.0
	p.fire_anim = 0.0
	p.shove_anim = 0.0
	p.reloading = false
	p.reload_queued = false
	p.reload = 0.0
	p.cooldown = 0.0
	p.ammo[0] = 20
	p.weapon = 0
	p.requested = 0
	p.slot = 1
	p.weapon_slot = 1
	sim.submit(p.id,{"yaw":0.0,"y":-1.0,"sprint":true})

static func validate(game, check: Callable) -> void:
	game.start_solo("defense",42)
	await game.get_tree().physics_frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	check.call(InputMap.action_get_events("sprint").any(func(event): return event is InputEventKey and event.physical_keycode == KEY_SHIFT),"Shift is bound to sprint through InputMap")
	var was_focused: bool = game.focused
	game.focused = true
	Input.action_press("sprint")
	check.call(game.input_state().sprint,"Held sprint reaches the real input path")
	game.pause_game()
	check.call(not game.input_state().sprint,"Pause suppresses sprint input")
	Input.action_release("sprint")
	game.resume_game()
	game.focused = was_focused
	reset_pawn(sim,p)
	p.input.sprint = false
	sim.update_pawn(p,.1)
	var walk_distance: float = 5-p.pos.y
	reset_pawn(sim,p)
	sim.update_pawn(p,.1)
	check.call(p.sprinting and absf((5-p.pos.y)-walk_distance*1.6) < .0001,"Sprint is 1.6 times walking speed within physics precision (walk %.6f, run %.6f)" % [walk_distance,5-p.pos.y])
	sim.progression.data.talents.swift = 2
	reset_pawn(sim,p)
	sim.update_pawn(p,.1)
	check.call(is_equal_approx(5-p.pos.y,4.2*1.1*1.6*.1),"Swift multiplies sprint speed")
	sim.progression.data.talents.swift = 0
	for action in ["fire","aim","reload","crouch","shove"]:
		reset_pawn(sim,p)
		p.input[action] = true
		var shots: int = p.shots
		sim.update_pawn(p,.01)
		check.call(not p.sprinting,"Action cancels sprint: "+action)
		if action == "fire": check.call(p.shots == shots+1,"Fire cancels sprint and fires immediately")
	reset_pawn(sim,p)
	p.input.y = 0.0
	sim.update_pawn(p,.02)
	check.call(not p.sprinting,"Shift without movement does not run")
	reset_pawn(sim,p)
	p.input_age = .5
	sim.update_pawn(p,.02)
	check.call(not p.sprinting,"Stale commands cannot keep sprint active")
	reset_pawn(sim,p)
	p.input.jump = true
	sim.update_pawn(p,.02)
	var takeoff: Vector2 = p.air
	check.call(not p.grounded and is_equal_approx(takeoff.length(),6.72),"Sprint jump retains full takeoff speed")
	sim.submit(p.id,{"x":1.0})
	sim.update_pawn(p,.05)
	check.call(p.air.length() >= takeoff.length()-.001,"Air steering after Shift release preserves sprint momentum")
	reset_pawn(sim,p)
	p.hp = 0
	sim.update_pawn(p,.02)
	check.call(not p.sprinting,"Dead players cannot sprint")
	p.hp = 100
	p.aim = false
	p.sprinting = false
	p.switch = 0.0
	p.fire_anim = 0.0
	for weapon in [0,3]:
		p.weapon = weapon
		p.sprinting = false
		game.weapon.reset_motion()
		game.weapon.sync(p,.2,1)
		var idle: Vector3 = game.weapon.position
		p.sprinting = true
		game.weapon.sync(p,.2,1)
		check.call(game.weapon.sprint_blend == 1 and game.weapon.position.y < idle.y-.09 and (game.weapon.quaternion*Vector3.FORWARD).y < -.1,"Sprint lowers the gun and muzzle: "+str(weapon))
		var running_pose: Transform3D = game.weapon.transform
		game.weapon.sync(p,.03,1.03)
		check.call(not running_pose.is_equal_approx(game.weapon.transform),"Sprint animates gun sway: "+str(weapon))
		p.sprinting = false
		game.weapon.sync(p,.2,1.23)
		check.call(game.weapon.sprint_blend == 0,"Sprint returns to a ready stance: "+str(weapon))
	game.start_solo("defense",42)
	await game.get_tree().physics_frame
	check.call(game.weapon.sprint_blend == 0 and game.weapon.sprint_phase == 0,"Restart clears sprint pose history")
