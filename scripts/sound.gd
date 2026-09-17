extends Node
var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var index = 0
var spatial_players: Array[AudioStreamPlayer3D] = []
var spatial_index = 0
var music_position = 0.0
var step_clock = 0.0
var step_due: Dictionary = {}

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
	for cue in ["grenade-throw","grenade-fuse"]: streams[cue] = load("res://assets/audio/%s.wav" % cue)
	for cue in ["enemy-step-0","enemy-step-1","rear-warning","shove","shove-hit","enemy-windup","enemy-impact","enemy-miss","grenade-explosion","campaign-winch","campaign-horde","campaign-gate","music","gun","flame","axe","reload","hurt","failure","death-0","death-1","death-2","cone-false","cone-true","bucket-false","bucket-true","shield-false","shield-true","football-false","football-true"]:
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
	player.pitch_scale = randf_range(.95,1.05) if cue in ["gun","flame","reload"] else 1.0
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
	player.pitch_scale = randf_range(.95,1.05) if cue in ["gun","flame","reload"] else 1.0
	if playback_enabled(): player.play()

func playback_enabled() -> bool:
	# Silent/headless checks inspect routing and resources without starting mixer voices.
	return DisplayServer.get_name() != "headless" and "--silent" not in OS.get_cmdline_user_args()

func clear_effects() -> void:
	step_due.clear()
	step_clock = 0.0
	for player in players:
		player.stop()
		player.stream = null
	for player in spatial_players:
		player.stop()
		player.stream = null

func _exit_tree() -> void:
	music.stop()
	music.stream_paused = false
	music.stream = null
	for player in players:
		player.stop()
		player.stream = null
	for player in spatial_players:
		player.stop()
		player.stream = null
