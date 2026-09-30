extends RefCounted
## Exercise real presentation event routing; no mixer voices in silent/headless QA.

static func validate(game, check: Callable) -> void:
	var sound = game.sound
	var data = game.get_node("/root/Data")
	var local_id: String = game.get_node("/root/Session").local_id
	var hashes: Dictionary = {}
	var local_pool_size: int = sound.players.size()
	var world_pool_size: int = sound.spatial_players.size()
	var origin = Vector3(7,4,-8)
	sound.clear_effects()
	for weapon_index in data.weapons.size():
		var id: String = data.weapons[weapon_index].id
		var cue: String = "weapon-"+id
		var stream = sound.streams.get(cue)
		check.call(stream is AudioStreamWAV,id+": dedicated weapon audio is loaded")
		if not stream is AudioStreamWAV: continue
		check.call(stream.get_length() >= .14 and stream.get_length() <= .71,id+": cue has usable duration")
		var pcm_hash: String = FileAccess.get_sha256("res://assets/audio/"+cue+".wav")
		check.call(not hashes.has(pcm_hash),id+": waveform differs from all preceding weapons")
		hashes[pcm_hash] = true
		var slot: int = sound.index % local_pool_size
		var event = {"kind":"shot","player":local_id,"weapon":weapon_index,"from":origin,"to":origin+Vector3(0,0,-20)}
		game.handle_effects([event])
		var voice: AudioStreamPlayer = sound.players[slot]
		check.call(voice.stream == stream,id+": local firing event selects its own sound")
		check.call(voice.volume_db <= -8 and voice.volume_db >= -16 and voice.pitch_scale >= .985 and voice.pitch_scale <= 1.015,id+": mix has headroom and limited pitch variation")
		sound.clear_effects()
		event.player = "weapon_audio_remote_fixture"
		game.handle_effects([event])
		var spatial: AudioStreamPlayer3D = sound.spatial_players[0]
		check.call(spatial.stream == stream and spatial.global_position == origin,id+": remote firing event uses the same identity at its world position")
		sound.clear_effects()
		game.effects.clear()
	game.handle_effects([{"kind":"turret_shot","from":origin,"to":origin+Vector3(0,0,-12)}])
	check.call(sound.spatial_players[0].stream == sound.streams["weapon-rifle"],"Turret shots use the rifle report")
	check.call(hashes.size() == data.weapons.size(),"Every configured weapon has unique audio, including inactive loadout weapons")
	check.call(sound.players.size() == local_pool_size and sound.spatial_players.size() == world_pool_size,"Weapon events retain bounded audio voice pools")
	if DisplayServer.get_name() == "headless" or "--silent" in OS.get_cmdline_user_args():
		check.call(sound.players.all(func(p): return not p.playing) and sound.spatial_players.all(func(p): return not p.playing),"Headless weapon checks never start local or spatial playback")
	sound.clear_effects()
	game.effects.clear()
