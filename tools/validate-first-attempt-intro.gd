extends RefCounted
const Intro = preload("res://scripts/first_attempt_intro.gd")
const Store = preload("res://scripts/progression_store.gd")
const Fixture = preload("res://tools/preparation-fixture.gd")
const Catalog = preload("res://scripts/preparation_catalog.gd")

static func validate(game, check: Callable) -> void:
	var progress = game.get_node("/root/Progress")
	var saved = progress.store
	var path = OS.get_cache_dir().path_join("intro-qa-"+str(Time.get_ticks_usec())+".json")
	progress.store = Store.new(path)
	game.start_solo("defense",491)
	await game.get_tree().physics_frame
	var sim = game.sim
	var p = game.local_pawn()
	check.call(Intro.active(sim.defense) and is_equal_approx(absf(p.yaw),PI),"First entry starts the narrative facing the bridge")
	check.call(Intro.alpha(sim.defense) == 0,"Intro fades in from transparent")
	Fixture.face(sim,p,"crystal")
	for index in 4:
		Fixture.hold(sim,p,2.5 if index == 0 else 5.0)
		game.arena.scenery.sync_focus(sim,p)
		game.ui.native_hud.sync()
		check.call(Intro.caption(sim.defense) == Intro.LINES[index] and Intro.alpha(sim.defense) == 1.0,"Caption holds for its five-second slot: "+str(index))
		check.call(not sim.defense.started and p.interact_time == 0 and Catalog.focus(sim,p).is_empty(),"E cannot repair the crystal during caption: "+str(index))
		check.call(not game.arena.scenery.preparation.focus_label.visible and not game.arena.scenery.preparation.interaction_ring.visible and not game.ui.native_hud.controls_hint.text.contains("E "),"No E prompt or interaction ring during caption: "+str(index))
	check.call(not sim.progression.data.intro_seen,"Incomplete narrative is not marked seen")
	var state = {"intro_elapsed":4.8}
	check.call(Intro.alpha(state) > 0 and Intro.alpha(state) < 1,"Each caption fades out before the next")
	state.intro_elapsed = 5.0
	check.call(Intro.caption(state) == Intro.LINES[1] and Intro.alpha(state) == 0,"Next caption starts a new fade at five seconds")
	Fixture.hold(sim,p,2.5)
	check.call(not Intro.active(sim.defense) and not sim.defense.started and Store.new(path).data.intro_seen,"Twenty seconds completes and persists the narrative without auto-repair")
	Fixture.hold(sim,p,1.1)
	check.call(not sim.defense.started,"Holding E through the ending requires releasing before repair")
	p.input = {}
	sim.defense_director.interactions(.01)
	game.arena.scenery.sync_focus(sim,p)
	check.call(game.arena.scenery.preparation.focus_label.visible and Catalog.available(sim,"crystal"),"Repair prompt appears after the final fade")
	Fixture.hold(sim,p,1.01)
	check.call(sim.defense.started,"Fresh E hold repairs the crystal after the narrative")
	progress.store = Store.new(path)
	game.start_solo("defense",491)
	check.call(not Intro.active(game.sim.defense),"Reloading the same save does not replay the narrative")
	var legacy = Store.defaults()
	legacy.erase("intro_seen")
	check.call(Store.valid(legacy),"Older saves without the intro flag remain valid")
	legacy.intro_seen = "false"
	check.call(not Store.valid(legacy),"Malformed intro flags are rejected")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	progress.store = saved
