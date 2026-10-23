extends RefCounted
const Fixture = preload("res://tools/preparation-fixture.gd")
const Body = preload("res://scripts/player_body.gd")
const Layout = preload("res://scripts/defense_layout.gd")

static func validate(game, check: Callable) -> void:
	game.start_solo("defense",817)
	Fixture.skip_tutorial(game.sim)
	await game.get_tree().physics_frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	var data = game.get_node("/root/Data")
	var prep = game.arena.scenery.preparation
	var shield: Dictionary = data.parts.filter(func(part): return part.get("shield",false))[0]
	check.call(is_equal_approx(shield.size[1],1.491*.98) and is_equal_approx(shield.position[1]-shield.size[1]/2,.54),"Shield shrinks exactly two percent while retaining its lower edge and shared hit geometry")
	sim.progression.data.coins = 10000
	sim.progression.data.weapons.rifle = 0
	Fixture.face(sim,p,"rifle")
	Fixture.hold(sim,p,1.01)
	check.call(sim.progression.level("rifle") == 1,"First held upgrade purchases a rifle level")
	p.input = {}
	sim.defense_director.interactions(0.01)
	Fixture.hold(sim,p,.25)
	game.arena.scenery.sync_focus(sim,p)
	check.call(prep.interaction_ring.state == "ready" and is_equal_approx(prep.interaction_ring.progress,.25),"Immediate second upgrade shows partial radial progress instead of previous green completion")
	Fixture.hold(sim,p,.76)
	check.call(sim.progression.level("rifle") == 2,"Second consecutive hold purchases the next level")
	var previous = data.controls.export_bindings()
	var key = InputEventKey.new()
	key.physical_keycode = KEY_F
	check.call(data.controls.rebind("interact",key).is_empty(),"Interaction binding accepts F")
	p.input = {}
	sim.defense_director.interactions(.01)
	game.arena.scenery.sync_focus(sim,p)
	game.ui.tick(0)
	check.call(prep.interaction_ring.letter.visible and prep.interaction_ring.letter.text == "F","World keycap updates to F immediately after remapping")
	Fixture.face(sim,p,"crystal")
	check.call(preload("res://scripts/preparation_catalog.gd").description(sim,"crystal").contains("F"),"Crystal instructions share the remapped interaction key")
	data.controls.initialize(previous)
	# Actual capsule motion checks frontal and sideways sprint/jump attempts.
	var body = Body.new()
	game.arena.add_child(body)
	await game.get_tree().physics_frame
	for horizontal in [Vector2(0,-6.72),Vector2(-6.72,0),Vector2(6.72,0)]:
		body.position = Vector3(0,.05,-65)
		body.velocity = Vector3(0,Body.JUMP_SPEED,0)
		for tick in 120: body.advance(horizontal,1.0/60)
		check.call(body.position.z > -67.6 and absf(body.position.x) < 5.6,"Player boundary stops bridgehead sprint and jumping: "+str(horizontal))
	body.free()
	check.call(game.arena.clear(Vector2(0,-70),Vector2(0,-64)),"Player-only boundary leaves the enemy approach unobstructed")
	check.call(game.arena.surface_hit(Vector3(0,1,-66),Vector3(0,1,-70)).is_empty(),"Player-only boundary does not block bullets")
	var rock = game.arena.scenery.find_child("FarForestBoulder0_0",true,false)
	check.call(rock != null and rock.get_child(1).shape is ConvexPolygonShape3D,"Spawn rocks use a convex collision matching the visible rock")
	var center = Vector2(rock.position.x,rock.position.z)
	check.call(not game.arena.clear(center+Vector2(-5,0),center+Vector2(5,0)),"Enemy movement rejects a segment through spawn rock")
	# A living local body must be visible to the actual crystal-failure camera.
	p.pos = Layout.CRYSTAL+Vector2(0,6)
	p.height = 3
	p.hp = 77
	sim.defense.started = true
	sim.failed = true
	sim.cause = "crystal"
	game.finish_run()
	game.update_finish_camera(2.4)
	check.call(game.partners.is_empty(),"Crystal defeat does not create a third-person body")
	check.call(game.camera.global_transform.is_equal_approx(game.finish_camera_start) and game.camera.is_position_in_frustum(Vector3(Layout.CRYSTAL.x,4.5,Layout.CRYSTAL.y)),"Crystal defeat holds a visible view of destruction instead of faking a player collapse")
