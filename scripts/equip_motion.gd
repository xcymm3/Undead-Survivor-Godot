extends RefCounted
## Shared animation phases and audio windows, measured in the same switch clock.
const DRAW_START = .25
const DRAW_SPAN = .75
const BOLT_START = .42
const BOLT_END = .78
const SPIN_END = .82

static func phase(remaining: float, duration: float) -> float:
	return clampf((1.0-remaining/maxf(.001,duration)-DRAW_START)/DRAW_SPAN,0,1)

static func bolt_offset(value: float) -> float:
	return .16*sin(PI*clampf((value-BOLT_START)/(BOLT_END-BOLT_START),0,1))

static func spin_angle(value: float) -> float:
	return TAU*smoothstep(0,SPIN_END,value)

static func window(weapon: int, duration: float) -> Vector2:
	var start = BOLT_START if weapon == 0 else 0.0
	var end = BOLT_END if weapon == 0 else SPIN_END
	return Vector2(duration*(DRAW_START+DRAW_SPAN*start),duration*DRAW_SPAN*(end-start))

static func audio_state(p: Dictionary) -> Dictionary:
	if p.is_empty() or p.get("hp",0) <= 0 or p.get("switch",0.0) <= 0 or p.get("pickup_remaining",0.0) > 0: return {}
	var weapon: int = int(p.get("weapon",-1))
	if weapon not in [0,2] or p.get("requested",-1) != weapon: return {}
	var duration: float = float(p.get("switch_duration",.4))
	var interval = window(weapon,duration)
	var age: float = duration-float(p.switch)-interval.x
	if age < 0 or age >= interval.y: return {}
	return {"cue":"equip-rifle-bolt" if weapon == 0 else "equip-pistol-spin","age":age,"duration":interval.y}
