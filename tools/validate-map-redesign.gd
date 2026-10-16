extends RefCounted
const Layout = preload("res://scripts/defense_layout.gd")
const Catalog = preload("res://scripts/preparation_catalog.gd")
const Fixture = preload("res://tools/preparation-fixture.gd")
const Store = preload("res://scripts/progression_store.gd")

static func validate(game, check: Callable) -> void:
	var progress = game.get_node("/root/Progress")
	var saved = progress.store
	progress.store = Store.new()
	game.start_solo("defense",20261016)
	await game.get_tree().physics_frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	check.call(p.pos.y < Layout.BRIDGE.position.y and Layout.BRIDGE.end.y < Layout.CRYSTAL.y and Layout.CRYSTAL.y < Layout.SHOP_AREA.position.y,"Spawn, bridge, crystal and shop follow the requested order")
	check.call(is_equal_approx(absf(p.yaw),PI) and p.height == 0 and game.arena.clear(p.pos,p.pos),"Player starts on the far-bank entrance facing the bridge")
	check.call(sim.defense.crystal_hp == 0 and sim.defense.crystal_repair_required and sim.defense.waiting and not sim.defense.started,"New match starts with a broken crystal and stopped waves")
	sim.step(.1)
	check.call(not sim.failed and sim.zombies.is_empty() and sim.elapsed == 0,"Broken preparation crystal does not cause defeat or spawn enemies")
	check.call(not Catalog.stations().any(func(entry): return entry.id == "alarm") and not game.arena.scenery.preparation.stations.has("alarm"),"No physical alarm station or lever remains")
	# Advance the actual player capsule from the entrance across the bridge/ramp.
	for tick in 1800:
		if p.pos.y >= Layout.CRYSTAL.y-4: break
		sim.submit(p.id,{"y":-1.0,"yaw":PI,"pitch":0.0,"slot":1,"weapon":0})
		sim.update_pawn(p,1.0/60)
	check.call(p.pos.y >= Layout.CRYSTAL.y-4 and p.height > 2.9 and p.hp == 100,"Actual capsule can walk from the new spawn across the bridge and ramp")
	Fixture.face(sim,p,"crystal")
	game.arena.scenery.sync_focus(sim,p)
	check.call(Catalog.focus(sim,p).get("id","") == "crystal" and game.arena.scenery.preparation.focus_label.text.contains("修复完成立即开始"),"Aiming at broken crystal shows the immediate-start repair warning")
	Fixture.hold(sim,p,.6)
	check.call(not sim.defense.started and sim.defense.crystal_hp == 0 and is_equal_approx(p.interact_time,.6),"Incomplete repair cannot start wave one")
	p.pitch = PI/2
	Fixture.hold(sim,p,.1)
	check.call(p.interaction.is_empty() and p.interact_time == 0,"Looking away cancels an incomplete crystal repair")
	Fixture.face(sim,p,"crystal")
	sim.events.clear()
	Fixture.hold(sim,p,1.01)
	check.call(sim.defense.started and not sim.defense.waiting and sim.defense.crystal_hp == 3000 and not sim.defense.crystal_repair_required and not sim.roster.is_empty(),"Completing E repair restores full crystal health and immediately launches wave one")
	check.call(sim.progression.data.coins == 0 and sim.progression.data.diamonds == 0,"Crystal repair is free even with an empty wallet")
	Fixture.hold(sim,p,2.0)
	check.call(sim.events.filter(func(event): return event.kind == "wave_start").size() == 1,"A continuous E hold cannot start duplicate waves or repairs")
	check.call(game.arena.scenery.crystal_core.visible and not game.arena.scenery.crystal_damage.debris.visible and game.arena.scenery.get_node("CrystalBody").collision_layer == 1,"Repair swaps settled toy fragments for the intact crystal and collider")
	check.call(game.arena.scenery.preparation.stations.rifle.cover.visible and not Catalog.available(sim,"rifle"),"Repair completion also closes preparation stands")
	sim.defense.crystal_hp = 2711
	sim.defense.wave = 2
	sim.defense_director.begin_wave()
	check.call(sim.defense.crystal_hp == 2711,"Later waves do not silently repair battle damage")
	sim.damage_crystal({},3000)
	sim.step(.02)
	check.call(sim.failed and sim.cause == "crystal","Crystal destruction after starting still causes defeat")
	for retry in 2:
		game.start_solo("defense",20261016+retry)
		await game.get_tree().physics_frame
		sim = game.sim
		p = game.local_pawn()
		check.call(not sim.failed and sim.defense.crystal_hp == 0 and sim.defense.crystal_repair_required and not sim.defense.started,"Re-entering after defeat/menu restores broken crystal: "+str(retry))
		check.call(p.pos.y == Layout.SPAWN.y and game.arena.scenery.crystal_damage.debris.visible and not game.arena.scenery.crystal_core.visible,"Restart returns to the bridge entrance with visible settled fragments: "+str(retry))
	var world = game.arena.scenery
	check.call(world.crystal.get_meta("art_style") == "toy" and world.crystal.has_node("ToyCrystalDock"),"Toy crystal retains its studded socket while broken")
	for id in ["turret_left","crystal_mine"]:
		var actor: Dictionary = world.structure_view.actors[id]
		check.call(actor.root.get_meta("art_style") == "toy" and not actor.root.find_children("ToyStud","MeshInstance3D",true,false).is_empty(),"Defense prop uses moulded plastic and studs: "+id)
	for station in world.preparation.stations.values():
		check.call(station.root.get_meta("art_style") == "toy" and station.root.has_node("ToyNamePlate"),"Preparation stand uses the shared toy style")
	progress.store = saved
	game.start_solo("defense",71245)
	await game.get_tree().physics_frame
