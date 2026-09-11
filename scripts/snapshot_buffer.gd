extends RefCounted
## Display-only history. Never submit these interpolated values to Simulation.
const DELAY = .1
const MAX_HISTORY = 12
var history: Array[Dictionary] = []
var clock = 0.0

func clear() -> void:
	history.clear()
	clock = 0.0

func push(state: Dictionary) -> void:
	if not history.is_empty() and state.elapsed <= history[-1].elapsed: return
	var frame = {"elapsed":state.elapsed,"pawns":state.pawns.duplicate(true),"zombies":state.zombies.duplicate(true)}
	if history.is_empty(): clock = state.elapsed-DELAY
	history.append(frame)
	while history.size() > MAX_HISTORY: history.pop_front()
	# Recover after a long stall instead of replaying obsolete movement.
	if state.elapsed-clock > .4: clock = state.elapsed-DELAY

func sample(dt: float) -> Dictionary:
	if history.is_empty(): return {}
	clock = minf(clock+dt,history[-1].elapsed)
	while history.size() > 2 and history[1].elapsed <= clock: history.pop_front()
	var a: Dictionary = history[0]
	if history.size() == 1 or clock <= a.elapsed: return a
	var b: Dictionary = history[1]
	var weight = clampf((clock-a.elapsed)/(b.elapsed-a.elapsed),0,1)
	var players = {}
	for id in a.pawns:
		players[id] = blend(a.pawns[id],b.pawns.get(id,a.pawns[id]),weight,true)
	if weight >= 1: players = b.pawns.duplicate(true)
	var next_enemies = {}
	for z in b.zombies: next_enemies[z.id] = z
	var enemies: Array = []
	for z in a.zombies:
		enemies.append(blend(z,next_enemies.get(z.id,z),weight,false))
	if weight >= 1: enemies = b.zombies.duplicate(true)
	return {"elapsed":lerpf(a.elapsed,b.elapsed,weight),"pawns":players,"zombies":enemies}

static func blend(a: Dictionary, b: Dictionary, weight: float, player: bool) -> Dictionary:
	if weight >= 1: return b.duplicate()
	var result = a.duplicate()
	# Respawns/teleports and death transitions must not sweep through the world.
	if a.pos.distance_squared_to(b.pos) > 16 or (a.hp > 0) != (b.hp > 0): return result
	result.pos = a.pos.lerp(b.pos,weight)
	var angle = "yaw" if player else "heading"
	result[angle] = lerp_angle(a[angle],b[angle],weight)
	if player:
		result.height = lerpf(a.height,b.height,weight)
		result.pitch = lerpf(a.pitch,b.pitch,weight)
		for key in ["fire_anim","reload","switch"]:
			if a.weapon == b.weapon and b[key] <= a[key]: result[key] = lerpf(a[key],b[key],weight)
	else:
		for key in ["attack_time","down","state_time","rage_pause"]:
			if a.get("state") == b.get("state") and a.has(key) and b.has(key) and absf(b[key]-a[key]) < .2:
				result[key] = lerpf(a[key],b[key],weight)
	return result
