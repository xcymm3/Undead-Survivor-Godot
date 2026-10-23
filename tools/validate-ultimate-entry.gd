extends SceneTree
const Store = preload("res://scripts/progression_store.gd")
var game
var checks = 0
var failures = 0
var files: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else: failures += 1; push_error(message)

func path_for(suffix: String) -> String:
	var path = OS.get_cache_dir().path_join("ultimate-entry-"+str(OS.get_process_id())+"-"+suffix+".json")
	files.append(path)
	return path

func face(entry, x: float, z := .3) -> void:
	entry.room.player.position = Vector3(x,.10,z)
	entry.room.player.velocity = Vector3.ZERO
	entry.yaw = 0.0
	entry.pitch = 0.0
	entry.step(.016,{"movement":Vector2.ZERO,"interact":false})
	entry.render()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var progress = root.get_node("Progress")
	var personal = progress.store
	var save_path = path_for("fresh")
	progress.store = Store.new(save_path)
	game.begin_game()
	await physics_frame
	var entry = game.entry_sequence
	check(entry != null and game.sim == null and entry.phase == "intro","Fresh menu entry begins the story before any battle simulation")
	check(entry.room.global_position.y == 80 and not game.arena.visible and entry.room.player.global_position.y > 79,"Selection scene and collisions are independent of the hidden defense terrain")
	check(entry.room.has_node("NeonTechnology") and entry.room.has_node("AzureMoonHall") and entry.room.has_node("CrimsonGothicChapel"),"Room builds three distinct architectural bays")
	check(entry.room.exhibits.size() == 3 and entry.room.exhibits.rocket_launcher.weapon.get_meta("weapon_id") == "rocket_launcher" and entry.room.exhibits.crimson_scepter.weapon.get_meta("weapon_id") == "crimson_scepter","Both new native display weapon models are instantiated alongside the existing blade")
	check(entry.prompt.text == "开始游戏前，选择你的终极武器","Selection prompt matches the requested text")
	entry.step(4.5)
	entry.render()
	check(entry.phase == "intro" and entry.black.color.a == 1 and game.sim == null and not progress.store.data.intro_seen,"Incomplete story stays opaque and does not start or save the main game")
	entry.step(4.5)
	check(entry.phase == "reveal" and Store.new(save_path).data.intro_seen and Store.new(save_path).needs_ultimate_choice(),"Completed story persists without falsely completing weapon selection")
	game.return_home()
	game.begin_game()
	entry = game.entry_sequence
	await physics_frame
	check(entry.phase == "reveal","Resuming after story completion skips narration and returns to selection")
	entry.step(1.0)
	entry.render()
	check(entry.phase == "room" and entry.black.color.a == 0,"Room reveals fully before selection controls enable")
	check(not entry.choose("blade"),"Blade cannot be selected from outside its interaction range")
	for id in ["rocket_launcher","crimson_scepter"]:
		face(entry,-8 if id == "rocket_launcher" else 8)
		check(entry.focus == id,"Proximity and gaze identify exhibit: "+id)
		entry.step(.016,{"movement":Vector2.ZERO,"interact":true})
		check(entry.phase == "room" and progress.store.needs_ultimate_choice() and entry.notice == "Demo版不可用" and game.sim == null,"Unavailable weapon cannot persist or leave the room: "+id)
	face(entry,0,5.8)
	for tick in 120: entry.step(1.0/60,{"movement":Vector2(0,-1),"interact":false})
	check(entry.room.player.position.z < .3 and entry.room.player.position.z > -2.0 and entry.room.player.position.y > -.05,"Native player movement reaches the blade and collides with its pedestal")
	face(entry,10.5,2)
	for tick in 120: entry.step(1.0/60,{"movement":Vector2(1,0),"interact":false})
	check(entry.room.player.position.x < 11.6,"Room side wall contains the native player capsule")
	face(entry,0)
	var valid_path: String = progress.store.path
	progress.store.path = OS.get_cache_dir().path_join("missing-ultimate-entry-"+str(OS.get_process_id())+"/save.json")
	check(not entry.choose("blade") and entry.phase == "room" and progress.store.needs_ultimate_choice(),"Failed disk write keeps selection open and rolls back its state")
	progress.store.path = valid_path
	# A complete tap may arrive between physics frames; retain that press once.
	var tap = InputEventAction.new()
	tap.action = "interact"
	tap.pressed = true
	game._unhandled_input(tap)
	tap.pressed = false
	game._unhandled_input(tap)
	entry.step(.016,{"movement":Vector2.ZERO,"interact":false})
	check(entry.phase == "fade_out" and Store.new(save_path).data.ultimate_choice == "blade","A press and release between physics frames selects and persists blade before the fade")
	check(not progress.store.data.ultimate_unlocked,"Choosing an ultimate does not bypass the existing unlock tutorial")
	entry.step(.45)
	entry.render()
	check(entry.black.color.a > .45 and entry.black.color.a < .55 and game.sim == null,"Selection fades to black before constructing the main simulation")
	entry.step(.5)
	entry.render()
	check(entry.phase == "handoff" and entry.black.color.a == 1 and game.sim != null and game.arena.visible and not entry.room.visible,"Scene handoff is opaque and restores the main world")
	check(not preload("res://scripts/first_attempt_intro.gd").active(game.sim.defense) and not game.sim.defense.started and game.local_pawn().hp == 100,"Shop starts in first-wave preparation without replaying the opening")
	entry.step(.25)
	entry.step(.5)
	entry.render()
	check(entry.phase == "return" and entry.black.color.a > .45 and entry.black.color.a < .55,"Main shop fades in after the handoff")
	entry.step(.6)
	await process_frame
	check(game.entry_sequence == null and game.sim != null and Store.new(save_path).data.ultimate_choice == "blade","Completed entry releases the room and retains its choice across disk reload")
	var second = Store.new(path_for("second-slot"))
	check(second.needs_ultimate_choice() and progress.store.data.ultimate_choice == "blade","A separate save still has its own unchosen ultimate")
	game.return_home()
	game.begin_game()
	check(game.entry_sequence == null and game.sim != null,"Subsequent starts bypass the completed selection room")
	game.return_home()
	var legacy_path = path_for("legacy")
	var legacy: Dictionary = Store.defaults()
	legacy.version = 9
	legacy.erase("ultimate_choice")
	legacy.intro_seen = true
	legacy.coins = 53.2
	var file = FileAccess.open(legacy_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy)); file.close()
	var migrated = Store.new(legacy_path)
	check(migrated.data.version == 10 and migrated.data.ultimate_choice == "blade" and is_equal_approx(migrated.data.coins,53.2),"Played version-nine saves retain blade and currency during migration")
	legacy.intro_seen = false
	legacy.coins = 0
	file = FileAccess.open(legacy_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy)); file.close()
	check(Store.new(legacy_path).needs_ultimate_choice(),"Untouched version-nine saves still enter the new selection")
	var invalid = Store.defaults()
	invalid.ultimate_choice = "rocket_launcher"
	check(not Store.valid(invalid) and not second.select_ultimate("crimson_scepter"),"Save validation and selection API both reject unavailable ultimate types")
	progress.store = personal
	game.queue_free()
	await process_frame
	for path in files:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	print("ULTIMATE ENTRY: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
