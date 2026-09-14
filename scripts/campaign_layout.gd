extends RefCounted
## Shared authored coordinates for scenery, authority, navigation and QA.
const ID = "graypine_ferry"
const BOUNDS = Rect2(-80,-140,160,280)
const START = Vector2(0,115)
const EXIT = Vector2(25,-125)
const START_ROOM = Rect2(-5,110,10,10)
const EXIT_ROOM = Rect2(19,-131,12,12)
const GATE = Rect2(-2.5,-58,5,2)
const START_DOOR = Rect2(-1.5,109.5,3,1)
const EXIT_DOOR = Rect2(23.5,-119.5,3,1)
const CONTROL = Vector2(8,-16)
const ROUTE = [Vector2(0,115),Vector2(0,103),Vector2(18,96),Vector2(18,78),Vector2(-15,70),Vector2(-15,48),Vector2(8,30),Vector2(8,6),Vector2(0,-14),Vector2(0,-40),Vector2(0,-62),Vector2(20,-78),Vector2(36,-92),Vector2(8,-103),Vector2(25,-115),Vector2(25,-124)]
const ITEMS = [
	{"id":"yard_ammo","pos":Vector2(-44,40),"kind":"ammo"},
	{"id":"yard_med_0","pos":Vector2(-46,40),"kind":"med"},
	{"id":"yard_med_1","pos":Vector2(-48,40),"kind":"med","party":3},
	{"id":"bridge_ammo","pos":Vector2(11,-12),"kind":"ammo"},
	{"id":"shed_ammo","pos":Vector2(20,-77),"kind":"ammo"},
	{"id":"shed_med","pos":Vector2(23,-77),"kind":"med"}]
const ZONES = [
	{"id":"exit","rect":Rect2(-12,96,40,14),"budget":6,"kinds":["normal"],"points":[Vector2(-9,99),Vector2(29,100)]},
	{"id":"street","rect":Rect2(-30,45,65,51),"budget":22,"kinds":["normal","normal","cone","normal","bucket","normal","shield"],"points":[Vector2(-27,68),Vector2(28,78),Vector2(-26,48)]},
	{"id":"yard","rect":Rect2(-57,27,28,30),"budget":8,"kinds":["normal","normal","cone"],"points":[Vector2(-52,30),Vector2(-52,52)]},
	{"id":"drain","rect":Rect2(-22,-22,50,52),"budget":10,"kinds":["normal","normal","cone","bucket"],"points":[Vector2(-17,0),Vector2(23,-9),Vector2(-24,-18)]},
	{"id":"final","rect":Rect2(-10,-119,56,38),"budget":22,"kinds":["normal","cone","normal","imp"],"points":[Vector2(-8,-97),Vector2(43,-106),Vector2(4,-78)]}]
const BRIDGE_POINTS = [Vector2(-24,-18),Vector2(23,-9),Vector2(-17,0),Vector2(20,-31)]

static func bridge(p: Vector2) -> bool:
	return absf(p.x) <= 2.5 and absf(p.y+40) <= 9

static func height(p: Vector2) -> float:
	if bridge(p): return .04
	return lerpf(-.9,-.05,clampf((absf(p.y+40)/3.0-.7)/1.9,0,1))

static func water(p: Vector2) -> bool:
	return not bridge(p) and absf(p.y+40) < 6.26 and absf(p.x) < 80
