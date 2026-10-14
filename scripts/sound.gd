extends Node
const WEAPON_GAINS = {"rifle":-10.0,"p90":-12.0,"pistol":-10.0,"revolver":-8.0,"shotgun":-8.0,"sniper":-8.0,"axe":-9.0,"flamethrower":-16.0,"auto-shotgun":-10.0,"heavy-machine-gun":-12.0}
var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var work: AudioStreamPlayer
var work_id = ""
var work_time = 0.0
var equip: AudioStreamPlayer
var equip_id = ""
var equip_time = 0.0
var equip_starts = 0
var equip_offset = 0.0
var music: AudioStreamPlayer
var index = 0
var spatial_players: Array[AudioStreamPlayer3D] = []
var spatial_index = 0
var music_position = 0.0
var step_clock = 0.0
var step_due: Dictionary = {}

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

func sync_enemy_steps(enemies: Array, listener: Vector3, dt: float) -> void:
	step_clock += dt
	var nearby = enemies.filter(func(z): return z.hp > 0 and z.get("move_speed",0.0) > .1 and z.pos.distance_to(Vector2(listener.x,listener.z)) < 16)
	nearby.sort_custom(func(a,b): return a.pos.distance_squared_to(Vector2(listener.x,listener.z)) < b.pos.distance_squared_to(Vector2(listener.x,listener.z)))
	var budget = 2
	for z in nearby.slice(0,8):
		if step_clock < step_due.get(z.id,0.0): continue
		step_due[z.id] = step_clock+clampf(.95/maxf(z.move_speed,1),.22,.8)
		play_at("enemy-step-"+str(int(z.id+floori(step_clock*4))%2),Vector3(z.pos.x,.15,z.pos.y),-5)
		budget -= 1
		if budget <= 0: break
	for id in step_due.keys():
		if step_clock-step_due[id] > 3: step_due.erase(id)

func _ready() -> void:
	streams["equip-rifle-bolt"] = preload("res://scripts/equip_audio.gd").make(0)
	streams["equip-pistol-spin"] = preload("res://scripts/equip_audio.gd").make(2)
	equip = AudioStreamPlayer.new()
	equip.max_polyphony = 1
	equip.pitch_scale = 1.0
	add_child(equip)
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
		streams["reload-"+str(Data.weapons[weapon_index].id)] = preload("res://scripts/mechanical_audio.gd").make(weapon_index)
	streams["heal"] = preload("res://scripts/mechanical_audio.gd").make(0,true)
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
	sync_equip({},false)
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
	equip.stop()
	equip.stream = null
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

func sync_equip(p: Dictionary, enabled: bool) -> void:
	var state = preload("res://scripts/equip_motion.gd").audio_state(p) if enabled else {}
	if state.is_empty():
		equip.stop()
		equip_id = ""
		equip_time = 0.0
		return
	if state.cue != equip_id or state.age < equip_time:
		equip.stop()
		equip.stream = streams[state.cue]
		equip.volume_db = -11 if state.cue == "equip-rifle-bolt" else -15
		equip.pitch_scale = .9/maxf(.001,float(p.get("switch_duration",.4)))
		equip_offset = minf(state.age*equip.pitch_scale,equip.stream.get_length()-.001)
		equip_starts += 1
		# Seek into the matching animation phase when a frame arrives late.
		if playback_enabled(): equip.play(equip_offset)
	equip_id = state.cue
	equip_time = state.age
