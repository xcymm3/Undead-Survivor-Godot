extends RefCounted
## Local visual feedback only. Multiple blasts never accumulate beyond one impulse.
const DURATION = .22
const RADIUS = 15.0
var remaining = 0.0
var amplitude = 0.0
var clock = 0.0

func clear() -> void:
	remaining = 0.0
	amplitude = 0.0
	clock = 0.0

func trigger(distance: float, strength: int) -> void:
	if strength <= 0 or distance >= RADIUS: return
	var falloff = pow(clampf(1.0-distance/RADIUS,0.0,1.0),2)
	amplitude = maxf(amplitude*pow(remaining/DURATION,2),deg_to_rad(.3)*falloff)
	remaining = DURATION

func step(dt: float, strength: int) -> Vector2:
	if strength <= 0:
		clear()
		return Vector2.ZERO
	remaining = maxf(0.0,remaining-dt)
	clock += dt
	if remaining <= 0:
		amplitude = 0.0
		return Vector2.ZERO
	var envelope = pow(remaining/DURATION,2)
	return Vector2(sin(clock*113.0),sin(clock*151.0)) * amplitude * envelope * (1.0 if strength == 1 else 1.6)
