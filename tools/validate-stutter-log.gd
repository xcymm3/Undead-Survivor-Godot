extends RefCounted
const Recorder = preload("res://scripts/stutter_log.gd")

static func validate(game, check: Callable) -> void:
	var automatic = game.get_node("/root/StutterLog")
	check.call(not automatic.enabled,"Headless automation does not create runtime stutter reports")
	var recorder = Recorder.new()
	recorder.ring.resize(Recorder.CAPACITY)
	recorder.metadata = {"version":"test"}
	var folder = "res://artifacts/stutter-test-"+str(Time.get_ticks_usec())
	recorder.directory = folder
	var state = {"active":true,"frame_limit":60,"wave":7,"alive":10}
	var now = 1000000
	for index in 400:
		now += 16667
		recorder.sample(now,16667,state)
	recorder.record("logic",8000)
	recorder.record("pathfinding",6000)
	now += 200000
	recorder.sample(now,200000,state)
	check.call(not recorder.capture.is_empty() and recorder.capture.frames.size() >= 290,"A 200ms frame retains approximately five seconds of pre-hitch history")
	check.call(recorder.capture.frames[-1].metrics.pathfinding.count == 1 and recorder.capture.frames[-1].metrics.logic.total_us == 8000,"Per-frame nested logic/path measurements retain counts and durations")
	check.call(not DirAccess.dir_exists_absolute(folder),"Capturing a hitch performs no synchronous filesystem writes")
	for index in 190:
		now += 16667
		recorder.sample(now,16667,state)
	check.call(recorder.capture.is_empty() and recorder.pending.size() == 1,"Recovery captures three subsequent seconds and queues exactly one report")
	recorder.pump_writer()
	while recorder.writer and recorder.writer.is_alive(): await game.get_tree().process_frame
	recorder.pump_writer()
	var files = DirAccess.get_files_at(folder)
	check.call(recorder.last_error.is_empty() and files.size() == 2,"The worker emits one JSON and one human-readable summary")
	for file in files:
		if not file.ends_with(".json"): continue
		var report = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file)))
		check.call(report.summary.peak_frame_ms == 200 and report.summary.frames_over_100ms == 1 and report.frames[-1].state.alive == 10,"Saved report preserves the actual hitch and low-enemy context")
	# Continuous slow frames merge, but ten seconds impose a bounded capture.
	now += 6000000
	for index in 110:
		now += 100000
		recorder.sample(now,100000,state)
	check.call(recorder.pending.size() == 1 and recorder.capture.is_empty(),"Continuous hitches terminate at the maximum duration instead of growing indefinitely")
	recorder.pending.clear()
	recorder.capture = {}
	recorder.next_capture_us = 0
	recorder.slow_frames.clear()
	for index in 20:
		now += 50000
		recorder.sample(now,50000,{"active":false,"frame_limit":60})
	check.call(recorder.capture.is_empty(),"Menus and inactive windows cannot trigger reports")
	for index in 20:
		now += 33333
		recorder.sample(now,33333,{"active":true,"frame_limit":30})
	check.call(recorder.capture.is_empty(),"An intentional 30FPS cap is not diagnosed as stutter")
	for index in 3:
		now += 45000
		recorder.sample(now,45000,state)
	check.call(not recorder.capture.is_empty(),"Three consecutive slow frames trigger even without a single 100ms spike")
	recorder.capture = {}
	recorder.slow_frames.clear()
	for index in 2200:
		now += 16667
		recorder.sample(now,16667,state)
	check.call(recorder.size == Recorder.CAPACITY and recorder.ring.size() == Recorder.CAPACITY,"Long sessions use a fixed-capacity history ring")
	# Retention removes only diagnostic report pairs, preserving unrelated files.
	var sentinel = FileAccess.open(folder.path_join("keep.txt"),FileAccess.WRITE)
	sentinel.store_string("keep")
	sentinel.close()
	var tiny = {"wall_time":"2026-10-25T00-00-00","trigger_us":0,"metadata":{"version":"test"},"frames":[{"frame_us":200000,"metrics":{},"state":state}]}
	var writes_ok = true
	for index in 22:
		tiny.trigger_us = 100000+index
		writes_ok = writes_ok and Recorder.write_report(tiny,ProjectSettings.globalize_path(folder)).is_empty()
	var remaining = Array(DirAccess.get_files_at(folder))
	check.call(writes_ok and remaining.filter(func(file): return file.ends_with(".json")).size() == 20 and remaining.size() == 41 and FileAccess.file_exists(folder.path_join("keep.txt")),"Rotation retains twenty report pairs and never deletes unrelated files")
	check.call(Recorder.begin() == 0,"Disabled diagnostics has a zero-token fast path")
	automatic.enabled = true
	automatic.metrics.clear()
	game.arena.path_to(Vector2(0,30),Vector2(0,31))
	var store = preload("res://scripts/progression_store.gd").new(folder.path_join("absent/save.json"))
	store.dirty = true
	check.call(not store.save(),"The instrumentation fixture follows a real failed save path")
	var view = preload("res://scripts/enemy_view.gd").new()
	game.add_child(view)
	view.mesh_for("normal",0,false,false,0)
	var actor: Dictionary = view.create_actor({"kind":"normal"})
	view.retire_actor(actor)
	check.call(automatic.metrics.pathfinding.count == 1 and automatic.metrics.save.count == 1 and automatic.metrics.mesh_build.count == 1 and automatic.metrics.enemy_create.count == 1 and automatic.metrics.enemy_retire.count == 1,"Real path, failed-save, mesh creation and retirement paths feed diagnostics")
	automatic.enabled = false
	automatic.metrics.clear()
	await game.get_tree().process_frame
	view.free()
	recorder.free()
