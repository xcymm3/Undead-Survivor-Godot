extends RefCounted
## Technical routing/timing checks only; this does not claim human listening.
static func validate(game, check: Callable) -> void:
	var sound = game.sound
	var data = game.get_node("/root/Data")
	var timeline = load("res://scripts/audio_timeline.gd")
	check.call(sound.cc0.license == "CC0-1.0" and sound.cc0.cues.size() == 54,"All replacement cues have an explicit CC0 catalog")
	for cue in sound.cc0.cues:
		check.call(sound.streams.get(cue) is AudioStreamWAV,"CC0 recording is loaded: "+cue)
	var pawn: Dictionary = game.local_pawn().duplicate(true)
	pawn.hp = 100
	pawn.switch = 0.0
	for weapon in data.weapons.size():
		var w: Dictionary = data.weapons[weapon]
		if w.id == "axe": continue
		pawn.weapon = weapon
		pawn.requested = weapon
		pawn.reloading = true
		var cue = "reload-"+str(w.id)
		check.call(is_equal_approx(sound.streams[cue].get_length(),w.reloadDuration),"Reload recording length matches the actual weapon duration: "+w.id)
		for fps in [30,60,144]:
			sound.sync_action("reload",{},false)
			var before: int = sound.actions.reload.starts
			for frame in range(ceili(w.reloadDuration*fps)):
				pawn.reload = maxf(.0001,w.reloadDuration-float(frame)/fps)
				sound.sync_weapon_actions(pawn,true)
			check.call(sound.actions.reload.starts == before+1,"One reload voice per cycle at "+str(fps)+" FPS: "+w.id)
			pawn.reloading = false
			sound.sync_weapon_actions(pawn,true)
			check.call(sound.actions.reload.key.is_empty() and sound.actions.reload.voice.stream == null,"Completing a reload clears the voice: "+w.id)
			pawn.reloading = true
		sound.sync_action("reload",{},false)
		pawn.reload = w.reloadDuration*.39
		sound.sync_weapon_actions(pawn,true)
		check.call(absf(sound.actions.reload.offset-w.reloadDuration*.61) < .0001 and sound.actions.reload.voice.pitch_scale == 1.0,"Late frame seeks to the authoritative reload time without pitch randomization: "+w.id)
		sound.sync_weapon_actions(pawn,false)
		check.call(sound.actions.reload.key.is_empty(),"Pause/focus loss stops reload audio: "+w.id)
		sound.sync_weapon_actions(pawn,true)
		pawn.requested = (weapon+1)%data.weapons.size()
		sound.sync_weapon_actions(pawn,true)
		check.call(sound.actions.reload.key.is_empty(),"Changing weapon cancels reload audio: "+w.id)
	pawn.weapon = 4
	pawn.requested = 4
	pawn.reloading = true
	pawn.reload = .04
	sound.sync_weapon_actions(pawn,true)
	var before: int = sound.actions.reload.starts
	pawn.reload = .39
	sound.sync_weapon_actions(pawn,true)
	check.call(sound.actions.reload.starts == before+1,"A new shotgun shell cycle restarts its own short recording")
	pawn.reloading = false
	pawn.ultimate_remaining = 5.0
	pawn.ultimate_age = .55
	pawn.ultimate_sheathe = 0.0
	pawn.weapon = 6
	pawn.requested = 6
	pawn.fire_anim = 0.0
	sound.sync_weapon_actions(pawn,true)
	check.call(sound.actions.blade.voice.stream == sound.streams["blade-draw"] and is_equal_approx(sound.actions.blade.offset,.55),"Drawing selects the dedicated unsheathing recording at its current time")
	pawn.ultimate_age = 2.0
	pawn.fire_anim = .20
	pawn.shots = 3
	sound.sync_weapon_actions(pawn,true)
	check.call(sound.actions.blade.voice.stream == sound.streams["blade-swing"],"A slash selects swish audio rather than unsheathing audio")
	pawn.ultimate_remaining = 0.0
	pawn.ultimate_sheathe = .5
	sound.sync_weapon_actions(pawn,true)
	check.call(sound.actions.blade.voice.stream == sound.streams["blade-sheathe"],"Sheathing replaces an interrupted slash/draw voice with its own recording")
	pawn.ultimate_sheathe = 0.0
	sound.sync_weapon_actions(pawn,true)
	check.call(sound.actions.blade.key.is_empty(),"Finished sheathing stops the action voice")
	pawn.ultimate_remaining = 5.0
	sound.sync_ultimate(pawn,true)
	check.call(sound.music.volume_db == -43 and sound.ultimate_music.stream.get_length() == 10.0,"Ultimate music has the skill's duration and ducks ordinary background music")
	pawn.ultimate_remaining = 0.0
	sound.sync_ultimate(pawn,true)
	check.call(sound.music.volume_db == -31,"Ending the ultimate restores ordinary background music level")
	check.call(sound.footstep_cue(Vector2(0,-45),0) == "enemy-step-wood-0" and sound.footstep_cue(Vector2(0,-19),1) == "enemy-step-1" and sound.footstep_cue(Vector2(0,-90),2) == "enemy-step-grass-2","Footstep material follows the shared bridge/ramp/field terrain")
	var previous = ""
	var distinct = true
	for index in 30:
		var cue: String = sound.death_cue()
		distinct = distinct and cue != previous and sound.streams.has(cue)
		previous = cue
	check.call(distinct,"Zombie deaths choose from six recordings without immediate repeats")
	sound.death_window = -1000
	check.call(sound.allow_death(0) and sound.allow_death(1) and sound.allow_death(2) and not sound.allow_death(3) and sound.allow_death(80),"Dense zombie deaths have a bounded three-voice onset budget")
	var armor_hashes = {}
	for armor in ["cone","bucket","shield","football"]:
		for broken in ["false","true"]:
			var cue = armor+"-"+broken
			armor_hashes[sound.cc0.cues[cue].sha256] = true
	check.call(armor_hashes.size() == 8,"Four armor materials retain distinct impact and break recordings")
	check.call(sound.actions.values().all(func(track): return not track.voice.playing) and not sound.ultimate_music.playing,"Silent/headless checks never start action or music playback")
	sound.clear_effects()
