extends RefCounted
## Compact encounter route. All cover participates in physical and navigation geometry.
const ID = "graypine_night"
const BOUNDS = Rect2(-35,-72,70,154)
const START = Vector2(0,70)
const EXIT = Vector2(12,-60)
const START_ROOM = Rect2(-5,65,10,12)
const EXIT_ROOM = Rect2(7,-66,10,12)
const START_DOOR = Rect2(-1.5,64.5,3,1)
const EXIT_DOOR = Rect2(10.5,-54.5,3,1)
const GUARDS = []
const ROUTE = [START,Vector2(0,60),Vector2(8,53),Vector2(8,40),Vector2(-9,33),Vector2(-9,21),Vector2(-9,7),Vector2(7,1),Vector2(17,-12),Vector2(7,-26),Vector2(-6,-34),Vector2(-6,-44),Vector2(12,-49),EXIT]
const ITEMS = [
	{"id":"night_start","pos":Vector2(-3,71),"kind":"ammo","tier":"B"},
	{"id":"night_shop","pos":Vector2(-14,25),"kind":"ammo","tier":"B"},
	{"id":"night_van","pos":Vector2(-12,-32),"kind":"ammo","tier":"A"},
	{"id":"night_med","pos":Vector2(-14,-32),"kind":"med"}]
# Broad off-route habitats keep the road readable without making clearing the map the goal.
const ZONES = [
	{"id":"street","rect":Rect2(-28,34,56,24),"budget":46,"kinds":["normal","normal","normal","normal","normal","normal","normal","normal","normal","cone"]},
	{"id":"shop","rect":Rect2(-28,5,55,26),"budget":44,"kinds":["normal","normal","normal","normal","normal","normal","normal","normal","normal","cone"]},
	{"id":"woods","rect":Rect2(-29,-29,58,30),"budget":68,"kinds":["normal","normal","normal","normal","normal","normal","normal","normal","normal","cone"]},
	{"id":"approach","rect":Rect2(-28,-51,56,19),"budget":42,"kinds":["normal","normal","normal","normal","normal","normal","normal","normal","cone","normal","bucket","normal"]}]
const ENTRIES = [Vector2(-27,43),Vector2(27,36),Vector2(-26,9),Vector2(27,12),Vector2(-27,-16),Vector2(27,-26),Vector2(-26,-44)]
const VIEWS = {"night_street":[Vector2(0,60),0.0,-.06],"night_shop":[Vector2(-9,27),0.0,-.03],"night_woods":[Vector2(13,-4),0.0,-.02],"night_exit":[Vector2(12,-49),0.0,0.0]}

static func water(_p: Vector2) -> bool: return false
static func height(_p: Vector2) -> float: return -.05

static func route_distance(p: Vector2) -> float:
	return p.distance_to(closest_route(p))

static func closest_route(p: Vector2) -> Vector2:
	var distance = INF
	var nearest = START
	for i in range(ROUTE.size()-1):
		var point = Geometry2D.get_closest_point_to_segment(p,ROUTE[i],ROUTE[i+1])
		if p.distance_to(point) < distance:
			distance = p.distance_to(point)
			nearest = point
	return nearest
