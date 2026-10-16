extends RefCounted
const Motion = preload("res://scripts/axe_motion.gd")

static func validate(game, check: Callable) -> void:
	var data = game.get_node("/root/Data")
	var duration: float = data.weapons[6].fireDuration
	check.call(game.sim.MELEE_START == Motion.CUT_START and game.sim.MELEE_END == Motion.CUT_END,"Axe damage sector uses the presentation's cutting interval")
	for direction in [1,-1]:
		var previous = Motion.pose(Motion.CUT_START,direction)*Motion.EDGE_POINT
		var monotone = true
		var edge_leads = true
		var continuous = true
		var before = Motion.pose(0,direction)
		for frame in range(1,241):
			var phase = float(frame)/240
			var transform = Motion.pose(phase,direction)
			var point = transform*Motion.EDGE_POINT
			continuous = continuous and transform.origin.distance_to(before.origin) < .07*Motion.LATERAL_SCALE and transform.basis.determinant() > .999
			if phase > Motion.CUT_START and phase <= Motion.CUT_END:
				monotone = monotone and (point.x-previous.x)*direction <= .00001
				var next_point = Motion.pose(minf(1,phase+.001),direction)*Motion.EDGE_POINT
				edge_leads = edge_leads and (-transform.basis.x).dot((next_point-point).normalized()) > .15
				previous = point
			before = transform
		check.call(monotone,"Cutting edge traverses the hit sector once without reversing: "+str(direction))
		check.call(edge_leads,"Sharpened edge leads the cut instead of the axe pick: "+str(direction))
		check.call(continuous,"Authored axe path is continuous and preserves rigid scale: "+str(direction))
		var centre = Motion.pose(Motion.CUT_CENTRE,direction)*Motion.EDGE_POINT
		var chamber = Motion.pose(Motion.CUT_START,direction)*Motion.EDGE_POINT
		check.call(centre.z < chamber.z-.5 and absf(centre.x) < .03*Motion.LATERAL_SCALE,"Axe extends forward across the centre during damage: "+str(direction))
		var end = Motion.pose(1,direction)*Motion.EDGE_POINT
		check.call(end.x*direction < -.8,"Follow-through stays on the opposite side without rewinding the cut: "+str(direction))
		var cut_end = Motion.pose(Motion.CUT_END,direction)*Motion.EDGE_POINT
		var original_span = 1.57 if direction == 1 else 1.52
		check.call(is_equal_approx(absf(cut_end.x-chamber.x),original_span*1.65) and duration == .56 and data.weapons[6].interval == .6,"Axe travels 65 percent farther sideways in the same attack time: "+str(direction))
	# Shared view motion must follow authority at differing render rates, keep a
	# short combo gap and start the next wind-up from the displayed end pose.
	for fps in [30,60,144]:
		var motion = Motion.new()
		var pawn = {"hp":100,"weapon":6,"requested":6,"shots":1,"axe_direction":1,"fire_anim":duration}
		var first = motion.sample(pawn,0,duration)
		check.call(first.is_equal_approx(Motion.ready_pose()),"First axe wind-up starts at its displayed rest: "+str(fps))
		for frame in range(ceili(duration*fps)):
			pawn.fire_anim = maxf(.00001,duration-float(frame)/fps)
			motion.sample(pawn,1.0/fps,duration)
		var end: Transform3D = motion.current
		pawn.fire_anim = 0.0
		check.call(motion.sample(pawn,.04,duration).is_equal_approx(end),"40ms combo gap retains follow-through: "+str(fps))
		pawn.shots = 2
		pawn.axe_direction = -1
		pawn.fire_anim = duration
		check.call(motion.sample(pawn,0,duration).is_equal_approx(end),"Reverse axe wind-up starts without a pose snap: "+str(fps))
		pawn.fire_anim = duration*(1.0-Motion.CUT_START)
		check.call(motion.sample(pawn,1.0/fps,duration).is_equal_approx(Motion.pose(Motion.CUT_START,-1)),"Reverse wind-up reaches its own chamber before damage: "+str(fps))
		pawn.fire_anim = 0.0
		motion.sample(pawn,.30,duration)
		check.call(motion.current.is_equal_approx(Motion.ready_pose()),"Released axe settles back to rest: "+str(fps))
		pawn.fire_anim = duration*.5
		motion.sample(pawn,0,duration)
		pawn.switch = .2
		check.call(motion.sample(pawn,0,duration).is_equal_approx(Motion.ready_pose()),"Switch cancels axe motion without adding a switch animation: "+str(fps))
	var right = Motion.pose(.46,1)
	var left = Motion.pose(.46,-1)
	check.call(right.basis.x.dot(left.basis.x) < 0 and not is_equal_approx(right.origin.y,left.origin.y),"Two axe strokes have separate authored orientation and height")
	var shown: Dictionary = game.local_pawn().duplicate(true)
	shown.merge({"hp":100,"weapon":6,"requested":6,"slot":1,"switch":0.0,"reloading":false,"ultimate_remaining":0.0,"ultimate_sheathe":0.0,"pickup_remaining":0.0,"sprinting":false,"aim":false},true)
	var partner = load("res://scripts/partner_view.gd").new()
	game.add_child(partner)
	partner.setup(shown)
	for direction in [1,-1]:
		shown.axe_direction = direction
		for phase in [.22,.46,.66]:
			shown.fire_anim = duration*(1.0-phase)
			game.weapon.sync(shown,.016,0.0)
			partner.sync(shown,.016)
			var expected = Motion.pose(phase,direction)
			check.call(game.weapon.axe_pivot.transform.is_equal_approx(expected) and partner.axe_pivot.transform.is_equal_approx(expected),"First-person and partner consume the same directional axe stroke: %s / %s" % [direction,phase])
	partner.free()
	game.weapon.sync(game.local_pawn(),.016,game.sim.elapsed)
	var pawn = {"hp":100,"weapon":6,"requested":6,"shots":12,"fire_anim":duration*.54,"ultimate_remaining":0.0}
	var sound = game.sound
	sound.clear_effects()
	sound.sync_weapon_actions(pawn,true)
	check.call(sound.actions.axe.voice.stream == sound.streams["weapon-axe"] and sound.actions.axe.voice.pitch_scale == 1.0 and is_equal_approx(sound.actions.axe.offset,duration*.46),"Axe recording seeks to the same authoritative phase without pitch drift")
	var starts: int = sound.actions.axe.starts
	sound.sync_weapon_actions(pawn,true)
	check.call(sound.actions.axe.starts == starts,"Shot event and render sync cannot double-play axe whoosh")
	pawn.shots += 1
	sound.sync_weapon_actions(pawn,true)
	check.call(sound.actions.axe.starts == starts+1,"Each buffered axe stroke starts exactly one new recording")
	sound.sync_weapon_actions(pawn,false)
	check.call(sound.actions.axe.key.is_empty(),"Pause stops the axe recording")
	pawn.ultimate_remaining = 5.0
	pawn.ultimate_age = 2.0
	sound.sync_weapon_actions(pawn,true)
	check.call(sound.actions.axe.key.is_empty() and not sound.actions.blade.key.is_empty(),"Ultimate blade uses its own animation audio instead of the hidden axe")
	var cue: Dictionary = sound.cc0.cues["weapon-axe"]
	check.call(absf(float(cue.events[1].seconds)-duration*Motion.CUT_CENTRE) < .001,"Recorded axe whoosh landmark follows the cutting centre")
	sound.clear_effects()
