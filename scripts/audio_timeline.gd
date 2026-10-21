extends RefCounted
## Audio reads the same authoritative clocks as the weapon presentation.
const Ultimate = preload("res://scripts/ultimate.gd")

static func axe_state(p: Dictionary, weapons: Array) -> Dictionary:
	if p.is_empty() or p.get("hp",0) <= 0 or p.get("weapon",-1) != 6 or p.get("requested",6) != 6: return {}
	if Ultimate.locked(p) or p.get("switch",0.0) > 0 or p.get("reloading",false) or p.get("fire_anim",0.0) <= 0: return {}
	return {"cue":"weapon-axe","serial":int(p.get("shots",0)),"age":maxf(0,float(weapons[6].fireDuration)-float(p.fire_anim))}

static func reload_state(p: Dictionary, weapons: Array) -> Dictionary:
	if p.is_empty() or p.get("hp",0) <= 0 or not p.get("reloading",false) or p.get("switch",0.0) > 0: return {}
	var index: int = int(p.get("weapon",-1))
	if index < 0 or index >= weapons.size() or p.get("requested",index) != index: return {}
	var w: Dictionary = weapons[index]
	if w.id == "axe" or w.reloadDuration <= 0: return {}
	return {"cue":"reload-"+str(w.id),"serial":0,"age":clampf(w.reloadDuration-float(p.reload),0,w.reloadDuration)}

static func blade_state(p: Dictionary, weapons: Array) -> Dictionary:
	# Keep the existing action voice channel; its content now follows the axe trial.
	if p.is_empty() or p.get("hp",0) <= 0 or not Ultimate.active(p): return {}
	if p.get("ultimate_age",0.0) < Ultimate.DRAW_TIME or p.get("fire_anim",0.0) <= 0: return {}
	return {"cue":"weapon-axe","serial":int(p.get("shots",0)),"pitch":2.0,"age":maxf(0,float(weapons[6].fireDuration)-float(p.fire_anim)*2.0)}
