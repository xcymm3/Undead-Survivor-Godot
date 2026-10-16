extends Node
const WEAPON_GAINS = {"rifle":-10.0,"p90":-12.0,"pistol":-10.0,"revolver":-8.0,"shotgun":-8.0,"sniper":-8.0,"axe":-9.0,"flamethrower":-16.0,"auto-shotgun":-10.0,"heavy-machine-gun":-12.0}
var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var work: AudioStreamPlayer
var work_id = ""
var work_time = 0.0
var ultimate_music: AudioStreamPlayer
var music: AudioStreamPlayer
var index = 0
var spatial_players: Array[AudioStreamPlayer3D] = []
var spatial_index = 0
var music_position = 0.0
var step_clock = 0.0
var step_due: Dictionary = {}
var cc0: Dictionary = {}
var actions: Dictionary = {}
var death_last = -1
var death_window = -1000
var death_count = 0
const Timeline = preload("res://scripts/audio_timeline.gd")

func death_cue() -> String:
	var value = (death_last+randi_range(1,int(cc0.death_variants)-1))%int(cc0.death_variants)
	death_last = value
	return "death-"+str(value)

func allow_death(now: int) -> bool:
	if now-death_window >= 80:
		death_window = now
		death_count = 0
	if death_count >= 3: return false
	death_count += 1
	return true

func footstep_cue(point: Vector2, variant: int, map_id := "graypine_defense") -> String:
	var terrain = "grass"
	if map_id == "graypine_defense":
		if Data.Maps.Defense.BRIDGE.has_point(point): terrain = "wood"
		elif Data.Maps.Defense.RAMP.has_point(point) or Data.Maps.Defense.PLATEAU.has_point(point): terrain = "concrete"
	return "enemy-step-"+("" if terrain == "concrete" else terrain+"-")+str(posmod(variant,3))

func weapon_cue(weapon_index: int) -> String:
	if weapon_index < 0 or weapon_index >= Data.weapons.size(): return ""
	return "weapon-"+str(Data.weapons[weapon_index].id)

func weapon_gain(weapon_index: int) -> float:
	# Fast weapons overlap more voices; give each report enough headroom.
	if weapon_index < 0 or weapon_index >= Data.weapons.size(): return -10.0
	return float(WEAPON_GAINS.get(Data.weapons[weapon_index].id,-10.0))

func cue_pitch(cue: String) -> float:
	if cue.begins_with("weapon-"): return randf_range(.985,1.015)
	return randf_range(.95,1.05) if cue == "reload" else 1.0

func sync_enemy_steps(enemies: Array, listener: Vector3, dt: float, map_id := "graypine_defense") -> void:
	step_clock += dt
	var nearby = enemies.filter(func(z): return z.hp > 0 and z.get("move_speed",0.0) > .1 and z.pos.distance_to(Vector2(listener.x,listener.z)) < 16)
	nearby.sort_custom(func(a,b): return a.pos.distance_squared_to(Vector2(listener.x,listener.z)) < b.pos.distance_squared_to(Vector2(listener.x,listener.z)))
	var budget = 2
	for z in nearby.slice(0,8):
		if step_clock < step_due.get(z.id,0.0): continue
		step_due[z.id] = step_clock+clampf(.95/maxf(z.move_speed,1),.22,.8)
		play_at(footstep_cue(z.pos,int(z.id+floori(step_clock*4)),map_id),Vector3(z.pos.x,.15,z.pos.y),-9)
		budget -= 1
		if budget <= 0: break
	for id in step_due.keys():
		if step_clock-step_due[id] > 3: step_due.erase(id)

func _ready() -> void:
	cc0 = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/audio.json"))
	for cue in cc0.cues: streams[cue] = load("res://assets/audio/%s.wav" % cue)
	for id in ["reload","blade"]:
		var voice = AudioStreamPlayer.new()
		voice.max_polyphony = 1
		add_child(voice)
		actions[id] = {"voice":voice,"key":"","age":0.0,"offset":0.0,"starts":0}
	ultimate_music = AudioStreamPlayer.new()
	ultimate_music.stream = streams["ultimate-music"]
	ultimate_music.volume_db = -17
	add_child(ultimate_music)
	for cue in ["crystal-hit","coin-pickup","purchase"]: streams[cue] = preload("res://scripts/economy_audio.gd").make(cue)
	work = AudioStreamPlayer.new()
	work.stream = streams.purchase
	add_child(work)
	streams["menu-hover"] = preload("res://scripts/menu_audio.gd").hover()
	streams["disco"] = load("res://assets/audio/disco.wav")
	for cue in ["grenade-throw","grenade-fuse"]: streams[cue] = load("res://assets/audio/%s.wav" % cue)
	for weapon_index in Data.weapons.size():
		var cue = weapon_cue(weapon_index)
		streams[cue] = load("res://assets/audio/%s.wav" % cue)
	streams["heal"] = preload("res://scripts/mechanical_audio.gd").heal()
	for cue in ["enemy-step-0","enemy-step-1","rear-warning","shove","shove-hit","enemy-windup","enemy-impact","enemy-miss","grenade-explosion","wave-horn","victory","music","reload","hurt","failure","death-0","death-1","death-2","cone-false","cone-true","bucket-false","bucket-true","shield-false","shield-true","football-false","football-true"]:
		streams[cue] = load("res://assets/audio/%s.wav" % cue)
	for i in range(24):
		var player = AudioStreamPlayer.new()
		player.max_polyphony = 1
		add_child(player)
		players.append(player)
	for i in 32:
		var player = AudioStreamPlayer3D.new()
		player.unit_size = 4.0
		player.max_distance = 75.0
		player.max_polyphony = 1
		add_child(player)
		spatial_players.append(player)
	music = AudioStreamPlayer.new()
	music.stream = streams.music.duplicate()
	music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.stream.loop_end = int(music.stream.get_length()*music.stream.mix_rate)
	music.volume_db = -31
	add_child(music)

func set_playing(value: bool) -> void:
	ultimate_music.stream_paused = not value
	if not playback_enabled(): return
	if value:
		if not music.playing: music.play(music_position)
	elif music.playing:
		music_position = music.get_playback_position()
		music.stop()

func play(cue: String, gain := -9.0) -> void:
	if not streams.has(cue): return
	var player = players[index%players.size()]
	index += 1
	player.stream = streams[cue]
	player.volume_db = gain
	player.pitch_scale = cue_pitch(cue)
	if playback_enabled(): player.play()

func play_at(cue: String, position: Vector3, gain := -9.0) -> void:
	if not streams.has(cue): return
	if cue.begins_with("death-") and not allow_death(Time.get_ticks_msec()): return
	var player = spatial_players[spatial_index % spatial_players.size()]
	# Prefer a free voice; only steal when the entire bounded pool is busy.
	for candidate in spatial_players:
		if not candidate.playing:
			player = candidate
			break
	spatial_index += 1
	player.stop()
	player.global_position = position
	player.stream = streams[cue]
	player.volume_db = gain
	player.pitch_scale = cue_pitch(cue)
	if playback_enabled(): player.play()

func playback_enabled() -> bool:
	# Silent/headless checks inspect routing and resources without starting mixer voices.
	return DisplayServer.get_name() != "headless" and "--silent" not in OS.get_cmdline_user_args()

func clear_effects() -> void:
	ultimate_music.stop()
	if music: music.volume_db = -31
	for id in actions: sync_action(id,{},false)
	death_count = 0
	death_window = -1000
	sync_work({},false)
	step_due.clear()
	step_clock = 0.0
	for player in players:
		player.stop()
		player.stream = null
	for player in spatial_players:
		player.stop()
		player.stream = null

func _exit_tree() -> void:
	for id in actions:
		actions[id].voice.stop()
		actions[id].voice.stream = null
	ultimate_music.stop()
	ultimate_music.stream = null
	music.stop()
	music.stream_paused = false
	music.stream = null
	for player in players:
		player.stop()
		player.stream = null
	for player in spatial_players:
		player.stop()
		player.stream = null

func sync_work(p: Dictionary, enabled: bool) -> void:
	var id = str(p.get("interaction","")) if enabled and p.get("hp",0) > 0 else ""
	var time = float(p.get("interact_time",0.0))
	if id.is_empty():
		work.stop()
		work_id = ""
		work_time = 0.0
		return
	work.volume_db = -28+14*clampf(time/preload("res://scripts/preparation_catalog.gd").HOLD_SECONDS,0,1)
	if (id != work_id or time < work_time) and playback_enabled(): work.play(minf(time,preload("res://scripts/preparation_catalog.gd").HOLD_SECONDS-.01))
	work_id = id
	work_time = time

func sync_action(id: String, state: Dictionary, enabled: bool) -> void:
	var track: Dictionary = actions[id]
	var voice: AudioStreamPlayer = track.voice
	if not enabled or state.is_empty():
		voice.stop()
		voice.stream = null
		track.key = ""
		track.age = 0.0
		track.offset = 0.0
		return
	var key = state.cue+":"+str(state.serial)
	if track.key != key or state.age < track.age-.0001:
		voice.stop()
		voice.stream = streams[state.cue]
		voice.volume_db = -13 if id == "reload" else -11
		voice.pitch_scale = 1.0
		track.offset = minf(state.age,maxf(0,voice.stream.get_length()-.001))
		track.starts += 1
		if playback_enabled(): voice.play(track.offset)
	track.key = key
	track.age = state.age

func sync_weapon_actions(p: Dictionary, enabled: bool) -> void:
	sync_action("reload",Timeline.reload_state(p,Data.weapons),enabled)
	sync_action("blade",Timeline.blade_state(p,Data.weapons),enabled)

func sync_ultimate(p: Dictionary, enabled: bool) -> void:
	var active: bool = preload("res://scripts/ultimate.gd").active(p) and p.get("hp",0) > 0
	music.volume_db = -43 if active else -31
	if not active:
		ultimate_music.stop()
		return
	ultimate_music.stream_paused = not enabled
	if enabled and not ultimate_music.playing and playback_enabled(): ultimate_music.play(float(p.get("ultimate_age",0.0)))
