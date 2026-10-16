extends SceneTree
var checks = 0
var failures = 0
var game
const Catalog = preload("res://scripts/preparation_catalog.gd")
const Body = preload("res://scripts/player_body.gd")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.start_solo("defense",42)
	game.sim.defense.erase("intro_elapsed") # Fixture starts after the narrative intro.
	await physics_frame
	var sim = game.sim
	var p: Dictionary = sim.pawns.solo
	for ultimate in [false,true]:
		p.slot = 3
		p.weapon = 6
		p.requested = 6
		p.switch = 0.0
		p.reloading = false
		p.shove_anim = 0.0
		p.fire_anim = 0.0
		p.cooldown = 0.0
		p.trigger = false
		p.melee_queued = false
		p.melee_idle = 0.0
		p.axe_next_direction = 1
		p.ultimate_remaining = 5.0 if ultimate else 0.0
		p.ultimate_age = 2.0
		var initial: int = p.shots
		for tick in 5:
			var click: bool = tick in [0,4]
			sim.submit("solo",{"slot":3,"weapon":6,"fire":click,"fire_pressed":click})
			sim.update_pawn(p,1.0/60)
		check(p.shots == initial+1 and p.melee_queued,"Early second click buffers one melee follow-up: "+str(ultimate))
		for tick in 45:
			sim.submit("solo",{"slot":3,"weapon":6})
			sim.update_pawn(p,1.0/60)
		check(p.shots == initial+2 and p.axe_direction == -1,"Released clicks produce exactly two alternating swings: "+str(ultimate))
		for tick in 65:
			sim.submit("solo",{"slot":3,"weapon":6})
			sim.update_pawn(p,1.0/60)
		check(p.shots == initial+2 and p.axe_next_direction == 1,"Idle stops the combo and resets the next swing: "+str(ultimate))
		var count: int = p.shots
		for tick in 85:
			sim.submit("solo",{"slot":3,"weapon":6,"fire":true,"fire_pressed":tick == 0})
			sim.update_pawn(p,1.0/60)
		check(p.shots >= count+3,"Holding fire still repeats melee attacks: "+str(ultimate))
	p.ultimate_remaining = 0.0
	p.fire_anim = .3
	p.cooldown = .3
	sim.submit("solo",{"slot":3,"weapon":6,"fire_pressed":true})
	sim.submit("solo",{"slot":3,"weapon":6})
	check(p.input.fire_pressed,"A newer release cannot erase an unconsumed melee click")
	var session = root.get_node("Session")
	session.received_edges.clear()
	var recovered: Dictionary = session.recover_input_edges("click-test",{"fire_pressed_seq":2})
	check(recovered.fire_pressed and not session.recover_input_edges("click-test",{"fire_pressed_seq":2}).fire_pressed,"Coalesced network clicks recover once without inventing authority")
	# Real capsule sweeps, from ground and an elevated gate-sized launch point.
	var body = Body.new()
	game.arena.add_child(body)
	await physics_frame
	for side in [-1.0,1.0]:
		for depth in [-61.8,-45.0,-28.2]:
			for launch in [.15,1.15]:
				body.position = Vector3(side*2.7,launch,depth)
				body.velocity = Vector3(0,Body.JUMP_SPEED,0)
				var safe = true
				for tick in 100:
					body.advance(Vector2(side*6.72,0),1.0/60)
					safe = safe and absf(body.position.x) < 3.45 and body.position.y > -.1
				check(safe,"Bridge guard blocks jumping from deck/gate at both ends and centre: %s / %s / %s" % [side,depth,launch])
	body.free()
	# The entire gate face works before purchase, and then again for upgrades.
	p.ultimate_remaining = 0.0
	p.ultimate_sheathe = 0.0
	p.slot = 1
	p.weapon = 0
	p.requested = 0
	for id in ["bridge_entry_gate","bridge_gate"]:
		var gate: Dictionary = sim.defense_director.structures.find(id)
		for built in [false,true]:
			sim.progression.data.buildings[id].owned = built
			sim.defense_director.structures.refresh_purchase(id)
			sim.defense_director.sync_world()
			await physics_frame
			for x in [-3.1,0.0,3.1]:
				for side in [-1.0,1.0]:
					p.pos = Vector2(x,gate.pos.y+side*2.0)
					p.height = preload("res://scripts/defense_layout.gd").height(p.pos)
					var eye = Vector3(x,p.height+Body.eye_height(p),p.pos.y)
					var direction = (Vector3(x,gate.height+.55,gate.pos.y)-eye).normalized()
					p.yaw = atan2(-direction.x,-direction.z)
					p.pitch = asin(direction.y)
					check(Catalog.focus(sim,p).get("id","") == id,"Full gate face is selectable from both sides before/after building: %s / %s / %s / %s" % [id,built,x,side])
		# Purchase from the right, away from the old interaction point.
		sim.progression.data.buildings[id] = {"owned":false,"level":0}
		sim.defense_director.structures.refresh_purchase(id)
		sim.progression.data.coins = 10000
		check(sim.purchase_upgrade(id,p) and sim.purchase_upgrade(id,p),"Right-hand gate section supports both construction and upgrade: "+id)
	var mine: Dictionary = sim.defense_director.structures.find("crystal_mine")
	mine.owned = true
	var scenery = game.arena.scenery
	sim.defense.prop_clock = 0.0
	scenery.sync(sim.defense)
	var actor: Dictionary = scenery.structure_view.actors.crystal_mine
	check(actor.root.find_child("ArmoredCase",true,false) != null and actor.root.find_children("CaseBolt*","MeshInstance3D",true,false).size() == 8,"Mine has an armored silhouette and eight visible bolts")
	check(actor.light.visible and actor.light.light_energy > 0,"Untriggered armed mine starts with a green indicator")
	sim.defense.prop_clock = .8
	scenery.sync(sim.defense)
	check(not actor.light.visible,"Armed mine indicator blinks off without an enemy trigger")
	mine.triggered = true
	mine.fuse = 1.45
	scenery.sync(sim.defense)
	check(actor.light.visible and actor.light.light_color == Color("ff4c26"),"Triggered mine flashes red using the fuse clock")
	mine.fuse = 1.35
	scenery.sync(sim.defense)
	check(not actor.light.visible,"Triggered mine has a distinct fast off phase")
	mine.triggered = false
	mine.fuse = sim.equipment.GRENADE_FUSE
	sim.zombies.clear()
	sim.spawn(mine.pos,"normal")
	sim.events.clear()
	sim.defense_director.structures.step_mine(mine,.01)
	check(sim.events.any(func(e): return e.kind == "grenade_fuse"),"Mine starts the shared grenade fuse audio event")
	sim.defense_director.structures.step_mine(mine,2.0)
	check(sim.events.any(func(e): return e.kind == "explosion"),"Mine uses the shared grenade explosion event")
	var population = preload("res://scripts/defense_population.gd")
	check(population.kinds(4) == ["cone","imp"] and not population.kinds(3).has("imp"),"First imp wave replaces commons with cones without moving the unlock")
	game.ui.settings_tab = 0
	game.ui.show_settings()
	await process_frame
	check(game.ui.menu.find_children("*","SpinBox",true,false).is_empty() and game.ui.menu.find_children("*","TabContainer",true,false).is_empty(),"Settings uses native field controls rather than form inputs and browser tabs")
	var slider = game.ui.menu.find_child("Sensitivity",true,false)
	slider.value = 137
	check(is_equal_approx(root.get_node("Data").settings.sensitivity,.0022*1.37),"Sensitivity slider still applies and persists its numeric value")
	game.ui.settings_tab = 1
	game.ui.show_settings()
	await process_frame
	check(game.ui.menu.find_children("*","OptionButton",true,false).is_empty(),"Graphics settings use arrow selectors instead of dropdown forms")
	var old_shadow: int = root.get_node("Data").settings.shadows
	for control in game.ui.menu.find_children("*","Button",true,false):
		if control.accessibility_name == "阴影：下一项": control.pressed.emit()
	check(root.get_node("Data").settings.shadows == (old_shadow+1)%5 and root.get_node("Data").settings.quality == 5,"Graphics arrows change the intended setting and mark the preset custom")
	game.ui.show_save_slots()
	await process_frame
	await process_frame
	var cards = game.ui.menu.find_children("SaveSlot*","PanelContainer",true,false)
	for card in cards:
		check(card.get_global_rect().end.y < game.ui.root.size.y and card.get_global_rect().end.x < game.ui.root.size.x,"Save dossier stays inside the viewport")
	check(cards.size() == 3,"All three persistent saves have dedicated dossier panels")
	game.ui.confirm_delete_slot(1)
	check(game.ui.current == "delete_save" and game.ui.menu.find_children("*","Button",true,false).size() == 2,"Save deletion still requires explicit confirmation and offers cancel")
	game.free()
	print("NOON FIXES: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
