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
	check(entry.get_child_count()==1 and entry.story.get_child_count()==3,"Prologue contains only the story overlay")
	entry.step(4.5)
	entry.render()
	check(entry.phase=="intro" and entry.black.color.a==1 and game.sim==null,"Narration remains opaque and blocks spawning")
	entry.step(4.5)
	entry.render()
	check(entry.phase=="handoff" and game.sim!=null and entry.black.color.a==1,"Last story line leads directly into the map")
	check(game.local_pawn().pos.is_equal_approx(game.arena.definition.spawn),"Player enters at the map spawn")
	check(not preload("res://scripts/first_attempt_intro.gd").active(game.sim.defense),"Opening does not play twice")
	check(Store.new(save_path).data.ultimate_choice=="blade" and not progress.store.data.ultimate_unlocked,"Default blade persists without unlocking its combat ability")
	entry.step(.25)
	entry.step(1.1)
	check(game.entry_sequence==null,"Entry releases control to the player")
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
	check(Store.new(legacy_path).needs_ultimate_choice(),"Untouched version-nine saves remain eligible for the first prologue")
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
