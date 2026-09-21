extends RefCounted
## “断崖吊桥”防守地图的共享尺寸、目标点与高度函数。
const ID = "graypine_defense"
const BOUNDS = Rect2(-32,-78,64,150)
const SPAWN = Vector2(0,61)
const CRYSTAL = Vector2(0,46)
const LEVER = Vector2(6,49)
const SAFE_ZONE = Rect2(-13,52,26,17)
const ENTRIES = [Vector2(-2,-71),Vector2(0,-73),Vector2(2,-70)]
const BRIDGE = Rect2(-4,-62,8,34)
const RAMP = Rect2(-5,-28,10,18)
const MAX_WAVES = 10
const CRYSTAL_MAX_HP = 1500

static func height(p: Vector2) -> float:
	if p.y <= RAMP.position.y: return 0.0
	if p.y < RAMP.end.y: return 3.0*(p.y-RAMP.position.y)/RAMP.size.y
	return 3.0

static func in_safe_zone(p: Vector2) -> bool:
	return SAFE_ZONE.has_point(p)
