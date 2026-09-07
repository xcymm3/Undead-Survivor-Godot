extends Node
var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var index = 0

func _ready() -> void:
	for cue in ["music","gun","flame","axe","reload","hurt","failure","death-0","death-1","death-2","cone-false","cone-true","bucket-false","bucket-true","shield-false","shield-true","football-false","football-true"]:
		streams[cue] = load("res://assets/audio/%s.wav" % cue)
	for i in range(24):
		var player = AudioStreamPlayer.new()
		player.max_polyphony = 1
		add_child(player)
		players.append(player)
	music = AudioStreamPlayer.new()
	music.stream = streams.music.duplicate()
	music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.stream.loop_end = int(music.stream.get_length()*music.stream.mix_rate)
	music.volume_db = -31
	add_child(music)

func set_playing(value: bool) -> void:
	if value and not music.playing: music.play()
	elif not value: music.stream_paused = true
	if value: music.stream_paused = false

func play(cue: String, gain := -9.0) -> void:
	if not streams.has(cue): return
	var player = players[index%players.size()]
	index += 1
	player.stream = streams[cue]
	player.volume_db = gain
	player.pitch_scale = randf_range(.95,1.05) if cue in ["gun","flame","reload"] else 1.0
	player.play()

func _exit_tree() -> void:
	music.stream_paused = false
	music.stop()
	music.stream = null
	for player in players:
		player.stop()
		player.stream = null
