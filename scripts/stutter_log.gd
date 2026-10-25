extends Node
## Passive native-game telemetry. No input, scene changes, screenshots or network.
const CAPACITY = 2048
const BEFORE_US = 5000000
const AFTER_US = 3000000
const MAX_CAPTURE_US = 10000000
const RETAIN_REPORTS = 20
static var instance
var enabled = false
var game_ref: WeakRef
var directory = "user://diagnostics/stutter"
var ring: Array = []
var cursor = 0
var size = 0
var previous_us = 0
var metrics: Dictionary = {}
var capture: Dictionary = {}
var slow_frames: Array = []
var next_capture_us = 0
var pending: Array = []
var writer: Thread
var last_error = ""
var metadata: Dictionary = {}

static func begin() -> int:
	return Time.get_ticks_usec() if instance != null and instance.enabled else 0

static func end(name: String, started: int) -> void:
	if started > 0 and instance != null and instance.enabled:
		instance.record(name,Time.get_ticks_usec()-started)

func _ready() -> void:
	instance = self
	process_priority = -1000
	ring.resize(CAPACITY)
	enabled = DisplayServer.get_name() != "headless" and not OS.has_feature("web") and "--automation" not in OS.get_cmdline_user_args()
	metadata = {"schema":1,"version":ProjectSettings.get_setting("application/config/version",""),
		"engine":Engine.get_version_info().string,"os":OS.get_name(),"os_version":OS.get_version(),
		"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name() if enabled else "not measured",
		"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method",""),
		"limitations":"CPU scopes overlap. GPU time is not measured. Node destruction measures enemy retirement requests, not deferred engine freeing. No screenshots, player names, IPs or save contents."}
	set_process(enabled)

func attach(game: Node) -> void:
	game_ref = weakref(game)

func record(name: String, duration_us: int) -> void:
	var value: Dictionary = metrics.get(name,{"count":0,"total_us":0,"max_us":0})
	value.count += 1
	value.total_us += maxi(0,duration_us)
	value.max_us = maxi(value.max_us,duration_us)
	metrics[name] = value

func context() -> Dictionary:
	var game = game_ref.get_ref() if game_ref else null
	if not is_instance_valid(game): return {"active":false}
	var sim = game.sim
	var data = get_node_or_null("/root/Data")
	var session = get_node_or_null("/root/Session")
	return {"active":game.running and game.focused and not game.paused and not game.finished and game.entry_sequence == null and game.ending_sequence == null and sim != null,
		"wave":sim.wave if sim else 0,"alive":sim.alive_count() if sim else 0,
		"queued":sim.roster.size() if sim else 0,"map":game.arena.map_id,
		"mode":"client" if session and session.playing and not session.is_host() else "host" if session and session.playing else "solo",
		"party":session.members.size() if session and session.playing else 1,
		"frame_limit":int(data.settings.frame_limit) if data else 60,
		"quality":data.settings.quality if data else -1,"resolution":data.settings.resolution if data else 1.0,
		"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC))}

func _process(_dt: float) -> void:
	var now = Time.get_ticks_usec()
	if previous_us > 0:
		sample(now,now-previous_us,context())
	previous_us = now
	pump_writer()

func sample(now: int, frame_us: int, state: Dictionary) -> void:
	var row = {"at_us":now,"frame_us":frame_us,"metrics":metrics,"state":state}
	metrics = {}
	ring[cursor] = row
	cursor = (cursor+1)%CAPACITY
	size = mini(size+1,CAPACITY)
	var target_us = 1000000.0/maxi(1,int(state.get("frame_limit",60))) if int(state.get("frame_limit",60)) > 0 else 16667.0
	var slow = state.get("active",false) and frame_us >= maxf(40000,target_us*1.8)
	while not slow_frames.is_empty() and now-int(slow_frames[0]) > 1000000: slow_frames.pop_front()
	if slow: slow_frames.append(now)
	var trigger = slow and (frame_us >= maxf(100000,target_us*3.0) or slow_frames.size() >= 3)
	if capture.is_empty() and trigger and now >= next_capture_us:
		capture = {"trigger_us":now,"trigger_state":state,"last_slow_us":now,"wall_time":Time.get_datetime_string_from_system(),"frames":history(now-frame_us-BEFORE_US)}
	elif not capture.is_empty():
		if capture.frames.size() < CAPACITY: capture.frames.append(row)
		if slow: capture.last_slow_us = now
	if not capture.is_empty() and (now-int(capture.last_slow_us) >= AFTER_US or now-int(capture.trigger_us) >= MAX_CAPTURE_US or capture.frames.size() >= CAPACITY):
		finish_capture(now)

func history(since: int) -> Array:
	var result: Array = []
	for index in size:
		var row: Dictionary = ring[(cursor-size+index+CAPACITY)%CAPACITY]
		if int(row.at_us) >= since: result.append(row)
	return result

func finish_capture(now: int) -> void:
	if capture.is_empty(): return
	if pending.size() < 2:
		capture["metadata"] = metadata.duplicate(true)
		pending.append(capture)
	capture = {}
	slow_frames.clear()
	next_capture_us = now+5000000

func pump_writer() -> void:
	if writer:
		if writer.is_alive(): return
		last_error = str(writer.wait_to_finish())
		writer = null
		if not last_error.is_empty(): push_warning(last_error)
	if pending.is_empty(): return
	var report: Dictionary = pending.pop_front()
	writer = Thread.new()
	var error = writer.start(write_report.bind(report,ProjectSettings.globalize_path(directory)))
	if error != OK:
		last_error = "Could not start diagnostics writer: "+str(error)
		writer = null
		push_warning(last_error)

static func summary(report: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	var peak = 0
	var over_50 = 0
	var over_100 = 0
	for frame in report.frames:
		peak = maxi(peak,int(frame.frame_us))
		if frame.frame_us >= 50000: over_50 += 1
		if frame.frame_us >= 100000: over_100 += 1
		for key in frame.metrics:
			var value: Dictionary = frame.metrics[key]
			var entry: Dictionary = totals.get(key,{"count":0,"total_us":0,"max_us":0})
			entry.count += value.count
			entry.total_us += value.total_us
			entry.max_us = maxi(entry.max_us,int(value.max_us))
			totals[key] = entry
	return {"peak_frame_ms":peak/1000.0,"frames_over_50ms":over_50,"frames_over_100ms":over_100,"scopes":totals}

static func write_report(report: Dictionary, folder: String) -> String:
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return "Could not create diagnostics directory"
	report["summary"] = summary(report)
	var stamp = str(report.wall_time).replace(":","-")
	var base = folder.path_join("stutter_"+stamp+"_"+str(report.trigger_us))
	var json = FileAccess.open(base+".json",FileAccess.WRITE)
	if not json: return "Could not write diagnostics JSON"
	json.store_string(JSON.stringify(report))
	var error = json.get_error()
	json.close()
	if error != OK: return "Diagnostics JSON write failed"
	var text = "自动卡顿记录（非根因结论）\n时间：%s\n版本：%s\n最大帧耗时：%.2f ms\n超过50ms：%d帧；超过100ms：%d帧\n" % [report.wall_time,report.metadata.get("version","test"),report.summary.peak_frame_ms,report.summary.frames_over_50ms,report.summary.frames_over_100ms]
	var state: Dictionary = report.get("trigger_state",{})
	text += "触发场景：第%d波，存活%d只，待投放%d只，模式%s\n" % [state.get("wave",0),state.get("alive",0),state.get("queued",0),state.get("mode","unknown")]
	for key in report.summary.scopes:
		var scope: Dictionary = report.summary.scopes[key]
		text += "%s：%d次，累计%.2f ms，单次最大%.2f ms\n" % [key,scope.count,scope.total_us/1000.0,scope.max_us/1000.0]
	text += "\n详细帧序列见同名JSON。各计时范围有包含关系，不能相加。GPU耗时未测量；enemy_retire仅是敌人节点销毁请求，不代表引擎延迟释放耗时。文件写入由后台线程执行。\n"
	var plain = FileAccess.open(base+".txt",FileAccess.WRITE)
	if not plain: return "Could not write diagnostics summary"
	plain.store_string(text)
	error = plain.get_error()
	plain.close()
	if error != OK: return "Diagnostics summary write failed"
	var files: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.begins_with("stutter_") and file.ends_with(".json"): files.append(file)
	files.sort()
	while files.size() > RETAIN_REPORTS:
		var old: String = files.pop_front()
		DirAccess.remove_absolute(folder.path_join(old))
		DirAccess.remove_absolute(folder.path_join(old.trim_suffix(".json")+".txt"))
	return ""

func _exit_tree() -> void:
	if enabled:
		finish_capture(Time.get_ticks_usec())
		if writer: writer.wait_to_finish()
		writer = null
		# Shutdown may wait for disk; active gameplay never waits for the writer.
		for report in pending: write_report(report,ProjectSettings.globalize_path(directory))
	if instance == self: instance = null
