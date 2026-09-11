extends RefCounted
## CS 1.6 de_dust overview traced in plan coordinates (Dave Johnston's published overview).
## All game geometry is built natively; no BSP or original textures are loaded.
const SCALE = .14
const ORIGIN = Vector2(400,300)
const ZONES = [
	[60,96,200,96,200,365,60,365],
	[185,220,286,220,286,258,185,258],
	[252,242,287,242,287,522,252,522],
	[86,355,138,355,138,409,267,409,267,522,210,522,210,553,192,598,178,598,178,493,137,493,137,530,86,530],
	[368,161,392,161,392,230,419,230,419,246,392,246,392,342,369,342,369,420,346,420,346,460,285,460,285,418,337,418,337,283,368,283],
	[285,298,350,298,350,327,285,327],
	[376,4,488,4,488,42,479,42,479,66,488,66,488,217,418,217,418,159,347,159,347,98,376,98],
	[418,212,481,212,481,273,526,273,526,320,480,320,480,472,346,472,346,402,419,402],
	[525,215,558,215,558,224,585,224,585,215,615,215,615,224,646,224,646,215,752,215,752,270,744,270,744,294,752,294,752,408,646,408,646,385,617,385,617,345,596,345,596,380,556,380,556,343,525,343],
	[480,345,524,345,524,374,555,374,555,390,646,390,646,411,524,411,524,450,480,450]
]
const CRATES = [
	[94,139,15,15,2.0],[113,139,15,15,2.0],[94,159,15,15,2.0],
	[169,272,18,24,2.4],[110,458,19,19,2.2],[217,458,18,18,1.7],
	[264,369,12,16,1.5],[363,316,12,12,1.5],[363,375,12,15,1.5],
	[395,127,18,18,2.4],[455,34,17,16,2.3],[453,112,13,13,1.2],
	[450,429,17,17,2.0],[542,247,15,15,1.8],[599,242,14,14,2.2],
	[704,249,18,18,2.2],[725,363,17,17,2.3],[703,363,17,17,2.3]
]

static func point(x: float, y: float) -> Vector2:
	return (Vector2(x,y)-ORIGIN)*SCALE

static func polygons() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for zone in ZONES:
		var polygon = PackedVector2Array()
		for i in range(0,zone.size(),2): polygon.append(point(zone[i],zone[i+1]))
		result.append(polygon)
	return result

static func height(p: Vector2) -> float:
	var pixel = p/SCALE+ORIGIN
	if pixel.x >= 285 and pixel.x < 419 and pixel.y >= 161 and pixel.y < 472:
		var west = clampf((pixel.x-285)/52,0,1)
		var east = clampf((419-pixel.x)/29,0,1)
		var south = clampf((460-pixel.y)/60,0,1)
		return -1.6*minf(west,minf(east,south))
	# Raised platform at the end of the terrorist courtyard, approached by its ramp.
	if pixel.x >= 150 and pixel.x <= 197 and pixel.y <= 196:
		return .8*clampf((196-pixel.y)/34,0,1)
	return 0.0
