extends Node
var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var index = 0
var spatial_players: Array[AudioStreamPlayer3D] = []
var spatial_index = 0
var music_position = 0.0

func _ready() -> void:
	for cue in ["music","gun","flame","axe","reload","hurt","failure","death-0","death-1","death-2","cone-false","cone-true","bucket-false","bucket-true","shield-false","shield-true","football-false","football-true"]:
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
