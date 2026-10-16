extends RefCounted
## Audio reads the same authoritative clocks as the weapon presentation.
const Ultimate = preload("res://scripts/ultimate.gd")

static func reload_state(p: Dictionary, weapons: Array) -> Dictionary:
	if p.is_empty() or p.get("hp",0) <= 0 or not p.get("reloading",false) or p.get("switch",0.0) > 0: return {}
	var index: int = int(p.get("weapon",-1))
	if index < 0 or index >= weapons.size() or p.get("requested",index) != index: return {}
	var w: Dictionary = weapons[index]
	if w.id == "axe" or w.reloadDuration <= 0: return {}
	return {"cue":"reload-"+str(w.id),"serial":0,"age":clampf(w.reloadDuration-float(p.reload),0,w.reloadDuration)}

static func blade_state(p: Dictionary, weapons: Array) -> Dictionary:
	if p.is_empty() or p.get("hp",0) <= 0: return {}
	if p.get("ultimate_sheathe",0.0) > 0:
		return {"cue":"blade-sheathe","serial":0,"age":clampf(Ultimate.SHEATHE_TIME-float(p.ultimate_sheathe),0,Ultimate.SHEATHE_TIME)}
	if not Ultimate.active(p): return {}
	if p.get("ultimate_age",0.0) < Ultimate.DRAW_TIME:
		return {"cue":"blade-draw","serial":0,"age":maxf(0,float(p.ultimate_age))}
	if p.get("fire_anim",0.0) <= 0: return {}
	var variant: int = int(p.get("shots",0))%3
	return {"cue":"blade-swing"+("-"+str(variant) if variant > 0 else ""),"serial":int(p.get("shots",0)),"age":maxf(0,float(weapons[6].fireDuration)*.5-float(p.fire_anim))}
