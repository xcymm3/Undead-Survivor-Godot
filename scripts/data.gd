extends Node
## The source revision's balance values live in an automatically extracted resource.
var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/rules.json"))
var weapons: Array = rules.weapons
var enemies: Dictionary = rules.enemies
var parts: Array = rules.parts
signal settings_changed
var settings = {"sensitivity": 0.0022, "volume": 1.0, "muted": false, "quality": 3, "fullscreen": false, "resolution": 1.0, "aa": 1, "shadows": 3, "effects": 2, "distance": 2, "frame_limit": 60, "pixelated": false, "network_stats": true}
const GRAPHICS_PRESETS = [
    {"resolution":.5,"aa":0,"shadows":0,"effects":0,"distance":0,"frame_limit":60,"pixelated":true},
    {"resolution":.67,"aa":1,"shadows":1,"effects":0,"distance":1,"frame_limit":60,"pixelated":false},
    {"resolution":.75,"aa":1,"shadows":2,"effects":1,"distance":1,"frame_limit":60,"pixelated":false},
    {"resolution":1.0,"aa":1,"shadows":3,"effects":2,"distance":2,"frame_limit":60,"pixelated":false},
    {"resolution":1.0,"aa":3,"shadows":4,"effects":2,"distance":2,"frame_limit":0,"pixelated":false}
]
var scores: Array = []
var persistent = true
var automation = "--automation" in OS.get_cmdline_user_args()
const SAVE_PATH = "user://survivor-godot-v1.json"
const RIVER = [Vector2(-22,-14), Vector2(-17,-12), Vector2(-12,-14), Vector2(-6,-18), Vector2(0,-17), Vector2(6,-12), Vector2(12,-11), Vector2(17,-13), Vector2(22,-16)]
const SPAWNS = [Vector2(-13,-45), Vector2(1,-45), Vector2(12,-45), Vector2(19,-36), Vector2(19,-20), Vector2(19,-4)]
const PRACTICE = [Vector2(-5.8,-9.5), Vector2(.15,-22), Vector2(5.4,-21), Vector2(-1,-31)]
const MODELS = ["蓝衣青年", "棕衣大叔", "绿衣队员", "红衣女性"]
const PALETTE = [0x355747,0x365d73,0x794638,0x987f4c,0x663a4b,0x4b595b]

func _ready() -> void:
	if not automation and FileAccess.file_exists(SAVE_PATH):
		var loaded = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if loaded is Dictionary:
			if loaded.get("settings") is Dictionary:
				for key in settings:
					if loaded.settings.has(key) and (typeof(loaded.settings[key]) == typeof(settings[key]) or (typeof(settings[key]) == TYPE_INT and loaded.settings[key] is float)):
						settings[key] = loaded.settings[key]
			if loaded.get("scores") is Array:
				for entry in loaded.scores:
					if valid_score(entry): scores.append(entry)
	settings.sensitivity = clampf(settings.sensitivity, .00022, .0044)
	settings.volume = clampf(settings.volume, 0, 1)
	settings.quality = clampi(settings.quality, 0, 5)
	settings.resolution = clampf(settings.resolution,.5,1)
	for key in ["aa","shadows","effects","distance"]: settings[key] = clampi(settings[key],0,4 if key == "shadows" else 3 if key == "aa" else 2)
	if settings.frame_limit not in [0,30,60,120]: settings.frame_limit = 60
	if automation and OS.has_feature("web"):
		# Software WebGL in CI has no physical GPU; only render quality is reduced.
		settings.resolution = .5
		settings.aa = 0
		settings.shadows = 0
		settings.frame_limit = 20
		settings.quality = 5
	Engine.max_fps = 120
	apply_settings()
	var actions = {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "jump": KEY_SPACE, "reload": KEY_R}
	for action in actions:
		InputMap.add_action(action)
		var event = InputEventKey.new()
		event.physical_keycode = actions[action]
		InputMap.action_add_event(action, event)

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(.0001, settings.volume)))
	AudioServer.set_bus_mute(0, automation or settings.muted or DisplayServer.get_name() == "headless" or "--silent" in OS.get_cmdline_user_args())
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X,Viewport.MSAA_8X][int(settings.aa)]
	get_viewport().scaling_3d_scale = settings.resolution
	if not automation and DisplayServer.get_name() != "headless" and "--silent" not in OS.get_cmdline_user_args():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

	settings_changed.emit()

func set_preset(index: int) -> void:
	settings.quality = index
	if index < GRAPHICS_PRESETS.size():
		for key in GRAPHICS_PRESETS[index]: settings[key] = GRAPHICS_PRESETS[index][key]
	apply_settings()
	save()

func save() -> void:
	if automation: return
	var file = FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"settings": settings, "scores": scores}))
		file.close()
		persistent = DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH) == OK
	else: persistent = false

func valid_score(value) -> bool:
	if not value is Dictionary or not value.has_all(["waves","kills","duration","date"]) or not value.date is String: return false
	for key in ["waves","kills","duration"]:
		if not (value[key] is int or value[key] is float) or not is_finite(value[key]) or value[key] < 0: return false
	return true

func record(waves: int, kills: int, duration: float, shots: int, hits: int) -> void:
	scores.append({"waves": waves, "kills": kills, "duration": duration, "shots": shots, "hits": hits, "date": Time.get_datetime_string_from_system()})
	scores.sort_custom(func(a, b):
		if a.waves != b.waves: return a.waves > b.waves
		if a.kills != b.kills: return a.kills > b.kills
		return a.duration > b.duration)
	scores = scores.slice(0, 10)
	save()

static func wave_settings(wave: int) -> Dictionary:
	var count: int = 9 + (wave - 1) * 6 if wave <= 6 else 39 + (wave - 6) * 5 if wave <= 8 else 49 + (wave - 8) * 4 if wave <= 11 else 61 + (wave - 11) * 3
	return {"count": count, "speed": minf(2.8, 1.4 + (wave - 1) * .18), "rate": minf(2.8, 1.0 + (wave - 1) * .18)}

static func river_center(x: float) -> float:
	for i in range(1, RIVER.size()):
		if x <= RIVER[i].x:
			return lerpf(RIVER[i-1].y, RIVER[i].y, clampf((x - RIVER[i-1].x) / (RIVER[i].x - RIVER[i-1].x), 0, 1))
	return -16

static func water(p: Vector2, support := 0.0) -> bool:
	if p.x < -22 or p.x > 22 or absf(p.y - river_center(p.x)) >= 1.25: return false
	for x in [-10.0,10.0]:
		if absf(p.x-x) <= 2.6 and absf(p.y-river_center(x)) <= 3.6: return false
	if support > 0:
		for i in range(1,RIVER.size()):
			for side in [-1,1]:
				var a: Vector2 = RIVER[i-1]+Vector2(0,side*1.25)
				var b: Vector2 = RIVER[i]+Vector2(0,side*1.25)
				var t = clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1)
				if p.distance_to(a+(b-a)*t) <= support: return false
		for x in [-10.0,10.0]:
			if Vector2(maxf(0,absf(p.x-x)-2.6),maxf(0,absf(p.y-river_center(x))-3.6)).length() <= support: return false
	return true

static func enemy_scale(kind: String) -> float:
	return {"imp": .65, "shield": 1.05, "giant": 1.8, "football": 1.1}.get(kind, 1.0)

static func contact(kind: String) -> float:
	return {"imp": 1.0, "shield": 1.3, "giant": 1.8, "football": 1.35}.get(kind, 1.25)

static func attack(kind: String, rage := false) -> Vector2:
	return {"imp": Vector2(.18,.7), "shield": Vector2(.3,1), "berserker": Vector2(.15,.55) if rage else Vector2(.25,.85), "giant": Vector2(.65,1.5), "football": Vector2(.2,.7)}.get(kind, Vector2(.35,1.1))

static func from_matrix(m: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(m[0],m[1],m[2]),Vector3(m[4],m[5],m[6]),Vector3(m[8],m[9],m[10])),Vector3(m[12],m[13],m[14]))

static func v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

static func rgb(hex: int) -> Color:
	return Color.hex((hex << 8) | 255)

static func pellet(w: Dictionary, index: int, shot: int) -> Vector2:
	if w.id in ["shotgun", "auto-shotgun"]:
		# Stratified disk, rotated and jittered per shot; no fixed center pellet or rows.
		# A local seed keeps spread reproducible without consuming spawn/enemy randomness.
		var spread_random = RandomNumberGenerator.new()
		spread_random.seed = shot * 73856093 + index * 19349663 + int(w.pellets) * 83492791
		var radius = sqrt((index + spread_random.randf()) / float(w.pellets))
		var angle = index * 2.399963229728653 + shot * 1.61803398875 + spread_random.randf_range(-.35,.35)
		return Vector2(cos(angle) * w.spread, sin(angle) * w.spreadVertical) * radius
	if w.pellets == 1 and w.spread > 0:
		var angle = (shot + 1) * 2.399963229728653
		var radius: float = w.spread * sqrt(fmod((shot + 1) * .7548776662466927, 1))
		return Vector2(cos(angle), sin(angle)) * radius
	if index == 0: return Vector2.ZERO
	if not w.has("spreadVertical"):
		var angle = index * 2.399963229728653
		var radius = w.spread * sqrt(index / maxf(1,w.pellets-1))
		return Vector2(cos(angle),sin(angle))*radius
	var columns = ceili((w.pellets - 1) / 2.0)
	var horizontal = floorf((index - 1) / 2.0) / (columns - 1) * 2 - 1
	return Vector2(horizontal * w.spread, (-1 if (index - 1) % 2 == 0 else 1) * (1 - .3 * absf(horizontal)) * w.get("spreadVertical", w.spread))
