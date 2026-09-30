extends RefCounted
## “断崖吊桥”防守地图的共享尺寸、目标点与高度函数。
const ID = "graypine_defense"
const PLATEAU = Rect2(-32,-10,64,82.0*2.0/3.0)
const BOUNDS = Rect2(-32,-78,64,PLATEAU.end.y+78)
const SPAWN = Vector2(25,6)
const CRYSTAL = Vector2(0,PLATEAU.position.y+PLATEAU.size.y/2)
const CRYSTAL_RADIUS = 1.05
const CRYSTAL_CONTACT_RADIUS = 2.3 # Crystal body plus enemy navigation clearance.
const FALL_RETURN = CRYSTAL+Vector2(-6,3)
const SAFE_ZONE = Rect2(18,-7,12.9,26)
const ARMORY_WALL_X = 30.575 # Flush against the inner face of the right perimeter.
const ARMORY_CENTER_Z = 6.0
const SHOP_POINT = Vector2(28.7,6.0)
const BRIDGE = Rect2(-4,-62,8,34)
const ENEMY_SPAWN_REGION = Rect2(BOUNDS.position,Vector2(BOUNDS.size.x,BRIDGE.position.y-BOUNDS.position.y))
const ENEMY_BRIDGE_SPAWN_DISTANCE = 8.0
const RAMP = Rect2(-5,-28,10,18)
const CRYSTAL_MAX_HP = 1500
const ARMORY_WEAPONS := [0,8,7,5]
const ARMORY_COLUMNS := [-7.2,-2.4,2.4,7.2]
const ARMORY_ROWS := [5.65]

static func weapon_mount(display_index: int) -> Vector3:
	return armory_transform()*Vector3(ARMORY_COLUMNS[display_index],ARMORY_ROWS[0],67.28)

static func armory_transform() -> Transform3D:
	var basis = Basis(Vector3.UP,PI/2)
	return Transform3D(basis,Vector3(ARMORY_WALL_X,0,ARMORY_CENTER_Z)-basis*Vector3(0,0,67.85))

static func plateau_depth(old_depth: float) -> float:
	return PLATEAU.position.y+(old_depth+10)*2.0/3.0

static func height(p: Vector2) -> float:
	if p.y <= RAMP.position.y: return 0.0
	# The side shelves stay at the foot of the cliff. Only the central ramp reaches
	# the raised crystal plateau, so stepping onto a shelf cannot bypass the lane.
	if p.y < RAMP.end.y:
		return 3.0*(p.y-RAMP.position.y)/RAMP.size.y if p.x >= RAMP.position.x and p.x <= RAMP.end.x else 0.0
	return 3.0

static func in_safe_zone(p: Vector2) -> bool:
	return SAFE_ZONE.has_point(p)

static func enemy_spawn_allowed(p: Vector2) -> bool:
	if not ENEMY_SPAWN_REGION.has_point(p): return false
	var mouth = Vector2(clampf(p.x,BRIDGE.position.x,BRIDGE.end.x),BRIDGE.position.y)
	return p.distance_squared_to(mouth) >= ENEMY_BRIDGE_SPAWN_DISTANCE*ENEMY_BRIDGE_SPAWN_DISTANCE
