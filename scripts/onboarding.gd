extends RefCounted
## Save-backed tutorial stages. Only the host advances stages or spends money.
const FIRST_RUN = 0
const SHOP_PENDING = 1
const SHOP_OPEN = 2
const DEFENSE_PENDING = 3
const DEFENSE_OPEN = 4
const COMPLETE = 5
const CHARACTERS_PER_SECOND = 16.0
const LINE_PAUSE = 2.0
const SHOP_LINES = [
	"要对付僵尸，光靠勇气可不够，你还得有好的武器",
	"来吧，在我的商店里随便挑，只要你钱够的话..."
]
const DEFENSE_LINES = [
	"要守住水晶，你还需要一些防御设施",
	"正好我这里有些图纸，只要给我点金币，它就是你的了",
	"去桥头看看吧，我在这等你..."
]

static func stage(state: Dictionary) -> int:
	return int(state.get("tutorial_stage",COMPLETE))

static func shop_open(state: Dictionary) -> bool:
	return stage(state) in [SHOP_OPEN,DEFENSE_OPEN,COMPLETE] and not talking(state)

static func defenses_open(state: Dictionary) -> bool:
	return stage(state) >= DEFENSE_OPEN

static func pending(state: Dictionary) -> bool:
	return stage(state) in [SHOP_PENDING,DEFENSE_PENDING]

static func talking(state: Dictionary) -> bool:
	return not str(state.get("tutorial_dialogue","")).is_empty()

static func blocked(state: Dictionary) -> bool:
	return preload("res://scripts/first_attempt_intro.gd").active(state) or talking(state)

static func initialize(sim) -> void:
	sim.defense["tutorial_stage"] = int(sim.progression.data.get("tutorial_stage",COMPLETE))
	if stage(sim.defense) != COMPLETE and not sim.progression.data.get("intro_seen",false): sim.defense["intro_elapsed"] = 0.0
	sim.defense_director.sync_world()

static func lines(state: Dictionary) -> Array:
	return DEFENSE_LINES if state.get("tutorial_dialogue","") == "defenses" else SHOP_LINES

static func line_duration(state: Dictionary, index: int) -> float:
	# Hold the money sentence 1s before payment, then 2s for the flight.
	var pause = 3.0 if state.get("tutorial_dialogue","") == "defenses" and index == 1 else LINE_PAUSE
	return lines(state)[index].length()/CHARACTERS_PER_SECOND+pause

static func payment_time() -> float:
	return DEFENSE_LINES[0].length()/CHARACTERS_PER_SECOND+LINE_PAUSE+DEFENSE_LINES[1].length()/CHARACTERS_PER_SECOND+1.0

static func duration(state: Dictionary) -> float:
	var seconds = 0.0
	for index in lines(state).size(): seconds += line_duration(state,index)
	return seconds

static func dialogue_frame(state: Dictionary) -> Dictionary:
	if not talking(state): return {"line":-1,"characters":0,"text":""}
	var remaining: float = state.get("tutorial_dialogue_elapsed",0.0)
	var values = lines(state)
	for index in values.size():
		var seconds: float = line_duration(state,index)
		if remaining < seconds:
			var count = mini(values[index].length(),floori(remaining*CHARACTERS_PER_SECOND))
			return {"line":index,"characters":count,"text":values[index].left(count)}
		remaining -= seconds
	return {"line":-1,"characters":0,"text":""}

static func begin_dialogue(sim, pawn: Dictionary) -> bool:
	if not sim.can_manage(pawn) or sim.defense.started or not pending(sim.defense) or talking(sim.defense): return false
	if not preload("res://scripts/defense_layout.gd").owner_front(pawn.get("pos",Vector2.ZERO)): return false
	sim.defense["tutorial_dialogue"] = "defenses" if stage(sim.defense) == DEFENSE_PENDING else "shop"
	sim.defense["tutorial_speaker"] = pawn.id
	sim.defense["tutorial_dialogue_elapsed"] = 0.0
	var owner = preload("res://scripts/defense_layout.gd").SHOP_OWNER
	var eye = Vector3(pawn.pos.x,pawn.height+preload("res://scripts/player_body.gd").eye_height(pawn),pawn.pos.y)
	sim.defense["tutorial_speaker_eye"] = eye
	var toward = Vector3(owner.x,4.7,owner.y)-eye
	pawn.yaw = atan2(-toward.x,-toward.z)
	pawn.pitch = atan2(toward.y,Vector2(toward.x,toward.z).length())
	pawn.input = {}
	pawn.aim = false
	return true

static func tick(sim, dt: float) -> void:
	var state: Dictionary = sim.defense
	if not talking(state): return
	state.tutorial_dialogue_elapsed += dt
	if state.tutorial_dialogue == "defenses":
		var payment_at: float = payment_time()
		if state.tutorial_dialogue_elapsed >= payment_at and not sim.progression.data.get("tutorial_blueprint_paid",false):
			# Persist payment separately so quitting during the last lines cannot charge twice.
			if sim.progression.data.coins < 50: return
			var previous = sim.progression.data.duplicate(true)
			sim.progression.data.coins -= 50
			sim.progression.data["tutorial_blueprint_paid"] = true
			sim.progression.dirty = true
			if not sim.progression.save():
				sim.progression.data = previous
				return
			state["tutorial_payment_at"] = state.prop_clock+dt
			var pawn: Dictionary = sim.pawns.get(state.tutorial_speaker,{})
			if not pawn.is_empty(): state["tutorial_payment_from"] = Vector3(pawn.pos.x,pawn.height+1,pawn.pos.y)
			sim.events.append({"kind":"tutorial_payment","player":state.tutorial_speaker})
	if state.tutorial_dialogue_elapsed < duration(state): return
	var next = DEFENSE_OPEN if state.tutorial_dialogue == "defenses" else SHOP_OPEN
	sim.progression.data["tutorial_stage"] = next
	sim.progression.dirty = true
	sim.progression.save()
	state.tutorial_stage = next
	state.erase("tutorial_dialogue")

static func finish_attempt(sim) -> void:
	if sim.defense.get("tutorial_settled",false) or (not sim.failed and not sim.won): return
	sim.defense["tutorial_settled"] = true
	if sim.mode == "defense" and sim.failed and sim.pawns.values().any(func(pawn): return pawn.hp <= 0):
		# A fixed additive death reward; Greed only multiplies kill income.
		var bonus: float = sim.progression.award_coins(sim.progression.DEATH_BONUS)
		sim.earned_coins = snappedf(sim.earned_coins+bonus,.1)
		sim.defense["death_bonus"] = bonus
	if sim.won: sim.progression.award_victory()
	var current = stage(sim.defense)
	var next = current
	if current == FIRST_RUN and sim.progression.data.coins >= 25: next = SHOP_PENDING
	elif current == SHOP_OPEN and sim.progression.data.coins > 100: next = DEFENSE_PENDING
	elif current == DEFENSE_OPEN: next = COMPLETE
	sim.defense.tutorial_stage = next
	sim.progression.data["tutorial_stage"] = next
	sim.progression.dirty = true
	sim.progression.save()

static func unlock_ultimate(sim, zombie: Dictionary, damage_taken: int) -> void:
	if sim.progression.data.get("ultimate_unlocked",false) or not sim.defense.get("started",false): return
	if not zombie.has_all(["id","kind"]) or damage_taken <= 0: return
	sim.defense["ultimate_crystal_damage"] = int(sim.defense.get("ultimate_crystal_damage",0))+damage_taken
	if sim.defense.ultimate_crystal_damage < 500: return
	grant_ultimate(sim)

static func unlock_from_health(sim, pawn: Dictionary) -> void:
	if sim.mode == "defense" and float(pawn.get("hp",100)) < 50.0:
		if not sim.progression.data.get("ultimate_unlocked",false) and stage(sim.defense) != COMPLETE:
			# Let the new player survive the unlock beat, including a lethal triggering hit.
			pawn.hp = maxf(1,pawn.hp)
			pawn["tutorial_guard_remaining"] = 5.0
		grant_ultimate(sim)

static func grant_ultimate(sim) -> void:
	if sim.progression.data.get("ultimate_unlocked",false): return
	sim.progression.data["ultimate_unlocked"] = true
	sim.progression.dirty = true
	sim.progression.save()
	for pawn in sim.pawns.values():
		pawn["ultimate_unlocked"] = true
		pawn["ultimate_cd"] = 0.0
	sim.defense["combat_hint_overridden"] = true
	sim.defense["ultimate_tutorial_hint"] = true
	sim.events.append({"kind":"ultimate_unlocked"})

static func hint_mode(state: Dictionary, alive := true) -> String:
	if not alive or blocked(state): return ""
	if state.get("ultimate_tutorial_hint",false): return "ultimate"
	if stage(state) == COMPLETE or state.get("combat_hint_overridden",false): return ""
	if not state.get("started",false): return "movement"
	return "combat"
