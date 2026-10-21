extends RefCounted
const Intro = preload("res://scripts/first_attempt_intro.gd")
const Tutorial = preload("res://scripts/onboarding.gd")
const Store = preload("res://scripts/progression_store.gd")
const Fixture = preload("res://tools/preparation-fixture.gd")
const Catalog = preload("res://scripts/preparation_catalog.gd")

static func validate(game, check: Callable) -> void:
	var progress = game.get_node("/root/Progress")
	var saved = progress.store
	var path = OS.get_cache_dir().path_join("intro-qa-"+str(Time.get_ticks_usec())+".json")
	progress.store = Store.new(path)
	game.start_solo("defense",491)
	game.set_process(false)
	game.set_physics_process(false)
	await game.get_tree().physics_frame
	var sim = game.sim
	var p = game.local_pawn()
	check.call(not p.ultimate_unlocked and p.grenades == 0 and p.grenade_capacity == 0,"A new save starts with locked ultimate and zero grenade capacity")
	game.ui.native_hud.sync()
	check.call(not game.ui.native_hud.ultimate_ring.visible and game.ui.native_hud.equipment_slots[3].title.text == "手雷  0 / 0","HUD shows the locked ultimate and 0/0 grenades together")
	var ultimate = preload("res://scripts/ultimate.gd")
	sim.defense.started = true
	ultimate.tick(sim,p,{"ultimate":true},0)
	check.call(not ultimate.active(p),"Ultimate input cannot bypass its initial lock")
	sim.defense.started = false

	check.call(Intro.active(sim.defense) and Intro.LINES.size() == 5,"New save starts five cumulative narrative rows")
	var story_font = game.ui.native_hud.tutorial_overlay.story_lines[0].get_theme_font("font")
	var all_glyphs = true
	for line in Intro.LINES:
		for character in line: all_glyphs = all_glyphs and story_font.has_char(character.unicode_at(0))
	check.call(all_glyphs,"The opening serif typeface contains every opening-story character")

	check.call(Intro.line_alpha(sim.defense,0) == 0,"Narrative caption starts transparent over black")
	var origin: Vector2 = p.pos
	var rounds: int = p.ammo[0]
	sim.submit(p.id,{"x":1,"y":1,"yaw":1,"pitch":1,"fire":true,"jump":true,"slot":2,"ultimate":true})
	sim.equipment.before_movement(.1)
	sim.update_pawn(p,.1)
	check.call(p.pos == origin and p.shots == 0 and p.ammo[0] == rounds and p.slot == 1 and is_zero_approx(p.yaw),"Authority blocks moving, looking, jumping, firing and switching during intro")
	for index in 5:
		sim.defense_director.interactions(1.5 if index == 0 else 3.0)
		game.ui.native_hud.sync()
		check.call(Intro.caption(sim.defense).split("\n").size() == index+1 and Intro.line_alpha(sim.defense,index) == 1.0,"Narrative card fully visible: "+str(index))
		check.call(game.ui.native_hud.tutorial_overlay.black.visible and game.ui.native_hud.tutorial_overlay.black.color == Color.BLACK and game.ui.native_hud.tutorial_overlay.caption.text == Intro.caption(sim.defense) and game.ui.native_hud.tutorial_overlay.story_lines.size() == 5,"Opaque full-screen black accompanies caption: "+str(index))
		check.call(Catalog.focus(sim,p).is_empty() and not sim.defense.started,"Interactions locked during caption: "+str(index))
	check.call(not sim.progression.data.intro_seen,"Incomplete narrative is not marked seen")
	check.call(Intro.line_alpha({"intro_elapsed":3.3},0) == 1 and Intro.line_alpha({"intro_elapsed":3.3},1) > 0 and Intro.line_alpha({"intro_elapsed":3.3},1) < 1 and Intro.line_alpha({"intro_elapsed":3.3},2) == 0 and Intro.alpha({"intro_elapsed":14.8}) < 1,"Earlier rows remain visible as new rows fade in every three seconds; all rows fade out at the end")
	sim.defense_director.interactions(1.5)
	check.call(not Intro.active(sim.defense) and Store.new(path).data.intro_seen,"Five cards finish and persist at fifteen seconds")
	game.ui.native_hud.sync()
	check.call(not game.ui.native_hud.tutorial_overlay.black.visible and Tutorial.hint_mode(sim.defense) == "movement","Black lifts and sprint/crouch tips appear")
	var world = game.arena.scenery
	world.sync(sim.defense)
	var dialogue_font = world.shop.owner_dialogue.font
	var dialogue_glyphs = true
	for line in Tutorial.SHOP_LINES+Tutorial.DEFENSE_LINES:
		for character in line: dialogue_glyphs = dialogue_glyphs and dialogue_font.has_char(character.unicode_at(0))
	check.call(dialogue_glyphs,"The shopkeeper typeface contains every dialogue character")
	check.call(not world.shop.owner_model.visible,"Shopkeeper initially absent")
	var shop = world.shop
	var pose = sim.defense.duplicate(true)
	pose.tutorial_dialogue = "shop"
	var layout = preload("res://scripts/defense_layout.gd")
	var speaker_offset = Basis(Vector3.UP,layout.SHOP_OWNER_YAW)*Vector3(2,0,-3)
	pose.tutorial_speaker_eye = Vector3(layout.SHOP_OWNER.x,4.7,layout.SHOP_OWNER.y)+speaker_offset
	pose.prop_clock = 0.0
	shop.sync(pose)
	pose.prop_clock = .1
	shop.sync(pose)
	check.call(shop.owner_head_yaw < 0 and shop.owner_head_yaw > -.3 and absf(shop.owner_chest.position.y) > 0,"Shopkeeper smoothly starts turning toward the speaker while breathing")
	pose.prop_clock = 1.0
	shop.sync(pose)
	var turned: float = shop.owner_head_yaw
	check.call(is_equal_approx(turned,atan2(-2.0,3.0)),"Shopkeeper head faces the actual speaker position")
	pose.erase("tutorial_dialogue")
	pose.prop_clock = 1.1
	shop.sync(pose)
	check.call(shop.owner_head_yaw > turned and shop.owner_head_yaw < 0,"Shopkeeper returns smoothly after dialogue")
	pose.prop_clock = 2.0
	shop.sync(pose)
	check.call(is_zero_approx(shop.owner_head_yaw),"Shopkeeper returns to the resting forward direction")
	shop.sync(sim.defense)
	var body = preload("res://scripts/player_body.gd").new()
	game.arena.add_child(body)
	await game.get_tree().physics_frame
	var owner_pos: Vector2 = preload("res://scripts/defense_layout.gd").SHOP_OWNER
	for elevation in [3.1,4.4,5.5]:
		for side in [false,true]:
			body.position = Vector3(owner_pos.x if side else owner_pos.x-4,elevation,layout.SHOP_COUNTER_FRONT_Z-2 if side else owner_pos.y)
			body.velocity = Vector3.ZERO
			for tick in 60: body.advance(Vector2(0,6) if side else Vector2(6,0),1.0/60)
			check.call(body.position.z < layout.SHOP_COUNTER_FRONT_Z-.3 if side else body.position.x < layout.SHOP_COUNTER_X-.6,"Counter movement barrier stops front/side entry at height "+str(elevation)+" side="+str(side))
	body.free()
	check.call(world.shop.has_node("Bedroom/BedFrame") and world.shop.has_node("Bedroom/Wardrobe") and world.shop.has_node("Bedroom/BedsideLight"),"Spawn room contains a bed, wardrobe and working lamp")

	check.call(world.preparation.stations.values().all(func(station): return station.broken.visible and not station.prop.visible and not station.cover.visible),"All stations are broken without display props")
	check.call(world.structure_view.actors.values().all(func(actor): return not actor.root.visible),"Tower and gate ghosts initially hidden")
	check.call(world.preparation.blueprints.values().all(func(markers): return markers.all(func(marker): return not marker.visible)),"Mine blueprint markers initially hidden")
	check.call(world.crystal_light.light_energy > 1 and world.crystal_damage.repair_sparks.emitting,"Crystal remnants retain light and particles")
	check.call(not Catalog.available(sim,"rifle") and not Catalog.available(sim,"turret_left") and Catalog.available(sim,"crystal"),"Only repair is initially available")
	Fixture.face(sim,p,"crystal")
	Fixture.hold(sim,p,1.01)
	check.call(sim.defense.started and Tutorial.hint_mode(sim.defense) == "combat" and not world.crystal_damage.repair_sparks.emitting,"Repair launches wave one and changes tips")
	sim.defense.wave = 2
	check.call(Tutorial.hint_mode(sim.defense) == "combat","Mouse tips last through wave two")
	sim.defense.wave = 3
	check.call(Tutorial.hint_mode(sim.defense).is_empty(),"Mouse tips disappear at wave three")
	check.call(game.ui.native_hud.tutorial_overlay.aim_icon.action == "aim" and game.ui.native_hud.tutorial_overlay.shove_icon.action == "shove","Combat guidance uses mouse icon controls")
	sim.spawn(preload("res://scripts/defense_layout.gd").CRYSTAL+Vector2(0,-2),"normal")
	var attacker: Dictionary = sim.zombies[-1]
	sim.damage_crystal(attacker,1)
	check.call(not p.ultimate_unlocked and not sim.progression.data.ultimate_unlocked,"One point of crystal damage no longer unlocks the skill")
	sim.damage_crystal(attacker,498)
	check.call(not p.ultimate_unlocked and not Store.new(path).data.ultimate_unlocked,"The skill stays locked through 499 crystal damage")
	sim.damage_crystal(attacker,1)
	game.ui.native_hud.sync()
	check.call(p.ultimate_unlocked and p.ultimate_cd == 0 and game.ui.native_hud.ultimate_ring.caption == "100%" and Tutorial.hint_mode(sim.defense) == "ultimate","Exactly 500 cumulative enemy crystal damage unlocks and fully charges the ultimate with a top hint")
	check.call(Store.new(path).data.ultimate_unlocked,"The ultimate unlock persists immediately in the save")
	p.ultimate_cd = 37.0
	sim.damage_crystal(attacker,1)
	check.call(p.ultimate_cd == 37,"Later crystal hits do not refill ultimate cooldown")
	p.ultimate_cd = 0.0
	ultimate.tick(sim,p,{"ultimate":true},0)
	check.call(ultimate.active(p) and not sim.defense.get("ultimate_tutorial_hint",false),"First successful ultimate use clears its teaching hint")
	p.ultimate_remaining = 0.0
	p.ultimate_sheathe = 0.0
	p.weapon = p.weapon1
	p.requested = p.weapon1
	p.slot = 1
	p.erase("ultimate_saved_slot")

	sim.failed = true
	sim.progression.data.coins = 50
	Tutorial.finish_attempt(sim)
	check.call(Tutorial.stage(sim.defense) == Tutorial.FIRST_RUN,"Exactly fifty coins does not unlock shop dialogue")
	sim.defense.erase("tutorial_settled")
	sim.progression.data.coins = 50.1
	Tutorial.finish_attempt(sim)
	check.call(Store.new(path).data.tutorial_stage == Tutorial.SHOP_PENDING,"More than fifty coins schedules shop dialogue")
	progress.store = Store.new(path)
	game.start_solo("defense",492)
	sim = game.sim
	p = game.local_pawn()
	world = game.arena.scenery
	await game.get_tree().physics_frame
	check.call(not Intro.active(sim.defense) and p.ultimate_unlocked and world.shop.owner_model.visible and world.shop.owner_alert.visible,"Reload shows merchant exclamation without replaying intro")
	sim.coop_host = p.id
	check.call(not Tutorial.begin_dialogue(sim,{"id":"guest"}) and not Tutorial.talking(sim.defense),"A guest cannot advance the host tutorial")
	sim.coop_host = ""
	var layout_rules = preload("res://scripts/defense_layout.gd")
	var inner_width: float = 12.75-(layout_rules.SHOP_COUNTER_X+layout_rules.SHOP_COUNTER_DEPTH/2)
	check.call(inner_width > .9 and inner_width < 1.2,"Cashier stall leaves only a little clearance around the merchant")
	for end_z in [layout_rules.SHOP_COUNTER_FRONT_Z-.65,layout_rules.SHOP_COUNTER_BACK_Z+.65]:
		var end_point = Vector2(layout_rules.SHOP_OWNER.x,end_z)
		check.call(end_point.distance_to(Vector2(layout_rules.SHOP_COUNTER_X,layout_rules.SHOP_OWNER.y)) > 2.7,"Both counter ends are beyond the merchant interaction range")
	check.call(is_equal_approx(world.shop.owner_model.rotation.y,PI/2),"Merchant rests facing left by ninety degrees")
	check.call(Catalog.stations().all(func(entry): return layout_rules.SHOP_AREA.grow(-1.1).has_point(Vector2(entry.position.x,entry.position.z)) and entry.position.x < layout_rules.SHOP_COUNTER_X-1.3),"Every stand stays inside the showroom and outside the cashier lane")
	var side_point = layout_rules.SHOP_OWNER+Vector2(0,-5)
	p.pos = side_point
	p.height = 3
	check.call(not Tutorial.begin_dialogue(sim,p),"Direct dialogue request from the side is rejected by authority")
	var anchor = Vector3(layout_rules.SHOP_COUNTER_X,4.6,layout_rules.SHOP_OWNER.y)
	var side_direction = (anchor-Vector3(p.pos.x,4.7,p.pos.y)).normalized()
	p.yaw = atan2(-side_direction.x,-side_direction.z)
	p.pitch = asin(side_direction.y)
	check.call(Catalog.focus(sim,p).get("id","") != "shopkeeper","Side approaches do not display a merchant interaction")
	Fixture.face(sim,p,"shopkeeper")
	check.call(Catalog.focus(sim,p).get("id","") == "shopkeeper","Normal gaze selection reaches merchant across counter")
	Fixture.hold(sim,p,1.01)
	check.call(Tutorial.talking(sim.defense) and not Catalog.available(sim,"rifle"),"Interaction starts first dialogue while commerce stays locked")
	var owner = preload("res://scripts/defense_layout.gd").SHOP_OWNER
	var toward = Vector3(owner.x,4.7,owner.y)-Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p),p.pos.y)
	var forward = Basis.from_euler(Vector3(p.pitch,p.yaw,0))*Vector3.FORWARD
	check.call(forward.dot(toward.normalized()) > .9999,"Starting dialogue forces authority view toward the shopkeeper's face")
	var dialogue_origin: Vector2 = p.pos
	var dialogue_ammo: int = p.ammo[0]
	game.yaw = 2.0
	game.pitch = -1.0
	game.sync_dialogue_camera(p)
	sim.submit(p.id,{"x":1,"y":1,"yaw":2,"pitch":-1,"fire":true,"jump":true,"slot":2,"shove":true,"ultimate":true})
	sim.equipment.before_movement(.1)
	sim.update_pawn(p,.1)
	check.call(p.pos == dialogue_origin and p.ammo[0] == dialogue_ammo and not p.aim and is_equal_approx(game.yaw,p.yaw) and is_equal_approx(game.pitch,p.pitch),"Dialogue locks movement, aiming, attacks and local camera while keeping the forced facing")

	sim.defense_director.interactions(.07)
	check.call(Tutorial.dialogue_frame(sim.defense).characters == 1,"Dialogue reveals characters individually")
	var first_duration: float = Tutorial.SHOP_LINES[0].length()/Tutorial.CHARACTERS_PER_SECOND+2
	sim.defense_director.interactions(first_duration-.08)
	check.call(Tutorial.dialogue_frame(sim.defense).line == 0 and Tutorial.dialogue_frame(sim.defense).text == Tutorial.SHOP_LINES[0],"Full line remains throughout two-second pause")
	sim.defense_director.interactions(.02)
	check.call(Tutorial.dialogue_frame(sim.defense).line == 1,"Next line starts after pause")
	sim.defense_director.interactions(Tutorial.duration(sim.defense))
	check.call(Tutorial.shop_open(sim.defense) and not Tutorial.defenses_open(sim.defense) and Catalog.available(sim,"rifle"),"First dialogue opens commerce but no construction")
	check.call(not Tutorial.blocked(sim.defense),"Controls unlock only after every dialogue line and its final pause finish")
	check.call(not world.shop.owner_alert.visible and not world.shop.owner_dialogue.visible and not world.preparation.stations.rifle.broken.visible,"First conversation restores stations and clears exclamation")
	sim.failed = true
	sim.progression.data.coins = 100
	Tutorial.finish_attempt(sim)
	check.call(Tutorial.stage(sim.defense) == Tutorial.SHOP_OPEN,"Exactly one hundred coins does not unlock blueprint dialogue")
	sim.defense.erase("tutorial_settled")
	sim.progression.data.coins = 100.5
	Tutorial.finish_attempt(sim)
	progress.store = Store.new(path)
	game.start_solo("defense",493)
	sim = game.sim
	p = game.local_pawn()
	await game.get_tree().physics_frame
	check.call(Tutorial.pending(sim.defense) and not Catalog.available(sim,"rifle") and not Catalog.available(sim,"bridge_gate"),"Second stage locks commerce and construction until dialogue finishes")
	Fixture.face(sim,p,"shopkeeper")
	Fixture.hold(sim,p,1.01)
	var payment_at: float = Tutorial.DEFENSE_LINES[0].length()/Tutorial.CHARACTERS_PER_SECOND+2
	sim.defense_director.interactions(payment_at+.01)
	check.call(is_equal_approx(sim.progression.data.coins,50.5) and Store.new(path).data.tutorial_blueprint_paid,"Blueprint line charges and persists exactly fifty coins")
	check.call(sim.defense.has("tutorial_payment_from") and sim.defense.has("tutorial_payment_at"),"Payment records coin flight endpoints")
	sim.defense_director.interactions(.2)
	game.arena.scenery.sync_focus(sim,p)
	check.call(game.arena.scenery.preparation.money_flights.multimesh.visible_instance_count > 0,"Payment animates coins from player to merchant")
	progress.store = Store.new(path)
	game.start_solo("defense",494)
	sim = game.sim
	p = game.local_pawn()
	await game.get_tree().physics_frame
	Fixture.face(sim,p,"shopkeeper")
	Fixture.hold(sim,p,1.01)
	sim.defense_director.interactions(Tutorial.duration(sim.defense)+.1)
	check.call(is_equal_approx(sim.progression.data.coins,50.5) and Tutorial.stage(sim.defense) == Tutorial.DEFENSE_OPEN,"Reload during paid dialogue cannot deduct again")
	check.call(Catalog.available(sim,"turret_left") and Catalog.available(sim,"bridge_gate") and Catalog.available(sim,"crystal_mine") and Tutorial.shop_open(sim.defense),"Second dialogue opens every defense category and commerce")
	check.call(game.arena.scenery.structure_view.actors.turret_left.root.visible and game.arena.scenery.structure_view.actors.bridge_gate.root.visible and game.arena.scenery.structure_view.actors.crystal_mine.root.visible and game.arena.scenery.structure_view.actors.crystal_mine.ghost,"Tower, gate and mine construction ghosts appear after dialogue")
	sim.failed = true
	Tutorial.finish_attempt(sim)
	check.call(Store.new(path).data.tutorial_stage == Tutorial.COMPLETE,"Next attempt ending permanently finishes tutorial")
	progress.store = Store.new(path)
	game.start_solo("defense",495)
	check.call(not Intro.active(game.sim.defense) and Tutorial.hint_mode(game.sim.defense).is_empty() and not Tutorial.pending(game.sim.defense) and Tutorial.defenses_open(game.sim.defense),"Completed tutorial never repeats on subsequent attempts")
	check.call(game.sim.snapshot().defense.tutorial_stage == Tutorial.COMPLETE,"Host snapshots contain authoritative tutorial stage")
	var malformed = Store.defaults()
	malformed.tutorial_stage = 6
	check.call(not Store.valid(malformed),"Malformed tutorial stages are rejected")
	check.call(game.sound.streams.has("typewriter") and not game.sound.streams.typewriter.data.is_empty(),"Typewriter audio is registered and nonempty")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	progress.store = saved
