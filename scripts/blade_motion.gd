extends RefCounted
## Camera-space choreography; the scabbard axis and the blade insertion axis oppose.
const SIZE = .56
const LENGTH = 1.11*SIZE
const MOUTH = Vector3(.36,-.21,-1.08)
const PULL = Vector3(-.76,.47,-.45)
static var slash_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/blade-slashes.json"))
var current = ready_pose()
var sheath_from = ready_pose()
var swing_from = ready_pose()
var sheathing = false
var firing = false
var side = 1
var resting = 0.0

static func pose(grip: Vector3, axis: Vector3) -> Transform3D:
	var y = axis.normalized()
	var x = y.cross(Vector3.BACK).normalized()
	return Transform3D(Basis(x,y,x.cross(y)).scaled(Vector3.ONE*SIZE),grip)

static func ready_pose() -> Transform3D:
	return pose(Vector3(.34,-.24,-1.04),Vector3(.64,.56,-.53))

static func sheath_pose() -> Transform3D:
	return pose(MOUTH,PULL)

static func inserted_pose() -> Transform3D:
	return pose(MOUTH,-PULL)

static func extracted_pose() -> Transform3D:
	return pose(MOUTH+PULL.normalized()*(LENGTH+.12),-PULL)

static func draw_pose(progress: float) -> Transform3D:
	if progress < .16: return inserted_pose()
	if progress < .74:
		return inserted_pose().interpolate_with(extracted_pose(),smoothstep(.16,.74,progress))
	return extracted_pose().interpolate_with(ready_pose(),smoothstep(.74,1.0,progress))

static func swing_pose(progress: float, direction: int) -> Transform3D:
	var keys: Array = slash_data.clips[0 if direction == 1 else 1].samples
	var cursor = clampf(progress,0,1)*(keys.size()-1)
	var index = mini(int(cursor),keys.size()-2)
	var a: Array = keys[index]
	var b: Array = keys[index+1]
	var blend = cursor-index
	var position = Vector3(a[0],a[1],a[2]).lerp(Vector3(b[0],b[1],b[2]),blend)
	var rotation = Quaternion(a[3],a[4],a[5],a[6]).slerp(Quaternion(b[3],b[4],b[5],b[6]),blend)
	return Transform3D(Basis(rotation).scaled(Vector3.ONE*SIZE),position)

func reset() -> void:
	current = ready_pose()
	sheathing = false
	firing = false
	resting = 0.0

func sample(p: Dictionary, dt: float, fire_duration: float) -> Dictionary:
	var ultimate = preload("res://scripts/ultimate.gd")
	var remaining: float = p.get("ultimate_sheathe",0.0)
	var drawing: bool = ultimate.active(p) and p.get("ultimate_age",0.0) < ultimate.DRAW_TIME
	var sheath = sheath_pose()
	if remaining > 0:
		if not sheathing: sheath_from = current
		sheathing = true
		var t = clampf(1.0-remaining/ultimate.SHEATHE_TIME,0,1)
		if t < .38:
			current = sheath_from.interpolate_with(extracted_pose(),smoothstep(0,.38,t))
		else:
			current = extracted_pose().interpolate_with(inserted_pose(),smoothstep(.38,.83,t))
		var lower = Vector3(.10,-.48,.08)*smoothstep(.83,1,t)
		current.origin += lower
		sheath.origin += lower
	elif drawing:
		var t = clampf(float(p.ultimate_age)/ultimate.DRAW_TIME,0,1)
		current = draw_pose(t)
		var lift = Vector3(.10,-.48,.08)*(1.0-smoothstep(0,.16,t))
		current.origin += lift
		sheath.origin += lift
		sheathing = false
		firing = false
	elif p.fire_anim > 0:
		var direction: int = p.get("axe_direction",1)
		var progress = clampf(1.0-p.fire_anim/fire_duration,0,1)
		if not firing or side != direction: swing_from = current
		var target = swing_pose(progress,direction)
		# Wind-up starts from the actually displayed pose, including a stopped combo.
		current = swing_from.interpolate_with(target,smoothstep(0,.22,progress)) if progress < .22 else target
		firing = true
		side = direction
		resting = 0.0
	else:
		firing = false
		resting += dt
		if resting > .10: current = current.interpolate_with(ready_pose(),1.0-exp(-dt*9))
	return {"blade":current,"sheath":sheath}
