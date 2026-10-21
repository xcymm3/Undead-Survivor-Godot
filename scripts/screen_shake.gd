extends RefCounted
## Local visual feedback only. Multiple blasts never accumulate beyond one impulse.
const DURATION = .72
const RADIUS = 15.0
const LIGHT_DEGREES = .75
const HORIZONTAL_HZ = 5.0
const VERTICAL_HZ = 3.5
var remaining = 0.0
var amplitude = 0.0
var clock = 0.0

func clear() -> void:
	remaining = 0.0
	amplitude = 0.0
	clock = 0.0

func trigger(distance: float, strength: int) -> void:
	if strength <= 0 or distance >= RADIUS: return
	var falloff = pow(clampf(1.0-distance/RADIUS,0.0,1.0),1.35)
	# Preserve the existing phase and residual strength when another blast arrives.
	# Simultaneous explosions still cannot multiply the maximum angle.
	if remaining <= 0: clock = 0.0
	amplitude = maxf(amplitude*pow(remaining/DURATION,1.35),deg_to_rad(LIGHT_DEGREES)*falloff)
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
	var envelope = pow(remaining/DURATION,1.35)
	# Vector2 is pitch/yaw: horizontal recoil is dominant, with a smaller vertical sway.
	return Vector2(.32*sin(clock*TAU*VERTICAL_HZ),sin(clock*TAU*HORIZONTAL_HZ)) * amplitude * envelope * (1.0 if strength == 1 else 1.6)
