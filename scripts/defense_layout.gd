extends RefCounted
## “断崖吊桥”防守地图的共享尺寸、目标点与高度函数。
const ID = "graypine_defense"
const BOUNDS = Rect2(-32,-78,64,150)
const SPAWN = Vector2(0,61)
const CRYSTAL = Vector2(0,46)
const LEVER = Vector2(6,49)
const FALL_RETURN = Vector2(-6,49)
const SAFE_ZONE = Rect2(-13,52,26,17)
const ENTRIES = [Vector2(-2,-71),Vector2(0,-73),Vector2(2,-70)]
const BRIDGE = Rect2(-4,-62,8,34)
const RAMP = Rect2(-5,-28,10,18)
const MAX_WAVES = 10
const CRYSTAL_MAX_HP = 1500
const PRIMARY_WEAPONS := [0,1,4,5,7,8,9]
const ARMORY_COLUMNS := [-7.2,-2.4,2.4,7.2]
const ARMORY_ROWS := [4.2,5.65]
const GRENADE_MOUNTS := [Vector3(-11.2,4.15,67.28),Vector3(-10.0,4.15,67.28),Vector3(-11.2,5.35,67.28),Vector3(-10.0,5.35,67.28)]
const MEDKIT_MOUNTS := [Vector3(10.0,4.15,67.28),Vector3(11.2,4.15,67.28),Vector3(10.0,5.35,67.28),Vector3(11.2,5.35,67.28)]

static func weapon_mount(display_index: int) -> Vector3:
	return Vector3(ARMORY_COLUMNS[display_index/2],ARMORY_ROWS[display_index%2],67.28)

static func height(p: Vector2) -> float:
	if p.y <= RAMP.position.y: return 0.0
	# The side shelves stay at the foot of the cliff. Only the central ramp reaches
	# the raised crystal plateau, so stepping onto a shelf cannot bypass the lane.
	if p.y < RAMP.end.y:
		return 3.0*(p.y-RAMP.position.y)/RAMP.size.y if p.x >= RAMP.position.x and p.x <= RAMP.end.x else 0.0
	return 3.0

static func in_safe_zone(p: Vector2) -> bool:
	return SAFE_ZONE.has_point(p)
