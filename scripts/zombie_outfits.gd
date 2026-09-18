extends RefCounted
## Cloth colours and thin sewn details; cosmetic only, all follow torso bone 0.
const NAMES = ["反光背心工人","蓝色背带工装","红色格纹衬衫","白色医护服","深色西装"]
const COLORS = [
	["df762d","525957","343d46","332d27"],
	["b7a57c","b7a57c","334e74","302d2a"],
	["923e3b","923e3b","3c526a","49372b"],
	["c9d5c7","c9d5c7","387b76","b0b7aa"],
	["303847","303847","29303c","24262b"]]
static func part_color(outfit: int, part: Dictionary, fallback: Color) -> Color:
	var colors = COLORS[clampi(outfit,0,4)]
	if part.get("shirt",false): return Color(colors[1] if part.has("limb") else colors[0])
	if absf(part.get("limb",0.0)) >= 1: return Color(colors[3] if part.position[1] < .2 else colors[2])
	return fallback

static func patches(outfit: int) -> Array:
	var result: Array = []
	for face in [1.0,-1.0]:
		match outfit:
			0:
				for x in [-.20,.20]: add(result,x,1.20,.055,.62,"ded890",face)
				add(result,0,1.03,.62,.055,"ded890",face)
				add(result,0,.89,.62,.045,"ded890",face)
			1:
				add(result,0,1.08,.48,.45,"355b88",face)
				for x in [-.19,.19]:
					add(result,x,1.37,.065,.29,"355b88",face)
					add(result,x,1.255,.042,.035,"c8b983",face,.004)
				add(result,0,1.16,.20,.14,"274766",face,.004)
			2:
				# Broad alternating plaid panels remain legible at gameplay distance.
				for x in 6:
					for y in 7:
						var color = "482f38" if x%3 == 0 or y%3 == 0 else "b85a4d" if (x+y)%2 == 0 else "853936"
						add(result,-.25+x*.1,.89+y*.095,.098,.093,color,face)
				add(result,0,1.18,.02,.64,"d8be92",face,.004)
			3:
				add(result,0,1.19,.025,.64,"7d9691",face)
				add(result,.18,1.08,.15,.13,"a7bab2",face)
				if face > 0:
					add(result,-.16,1.35,.12,.035,"358f83",face)
					add(result,-.16,1.35,.035,.12,"358f83",face,.004)
			4:
				if face > 0:
					add(result,0,1.28,.15,.44,"d3d0bc",face)
					add(result,0,1.25,.045,.34,"9a4242",face,.004)
					for x in [-.13,.13]: add(result,x,1.38,.055,.26,"515a69",face)
					add(result,-.2,1.10,.13,.035,"737c86",face)
				else: add(result,0,1.18,.02,.62,"444d5d",face)
	return result

static func add(result: Array, x: float, y: float, width: float, height: float, color: String, face: float, layer := 0.0) -> void:
	result.append({"position":Vector3(x,y,face*(.18+layer)),"size":Vector3(width,height,.004),"color":Color(color)})
