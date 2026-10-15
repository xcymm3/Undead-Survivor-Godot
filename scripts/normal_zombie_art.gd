extends RefCounted
## Ordinary enemies only: inexpensive rigid toy geometry and clean molded colours.
const Wardrobe = preload("res://scripts/zombie_outfits.gd")
const MECHANICAL_LEG_ANGLES = [-.52,-.52,.12,.58,.58,-.12]
const COLORS = [
	["ed8c39","e2d6b0","496273","403c33"],
	["e4d5a5","e4d5a5","376e94","484034"],
	["bb5c50","bb5c50","426986","463c35"],
	["e4e8d7","e4e8d7","4c9e98","707d73"],
	["48596b","48596b","364655","303b40"]]

static func part_size(part: Dictionary, kind: String) -> Vector3:
	var size = Vector3(part.size[0],part.size[1],part.size[2])
	if kind != "normal" or part.get("head",false): return size
	var limb: float = absf(float(part.get("limb",0.0)))
	if limb >= 1:
		return Vector3(.28,.16,.46) if part.position[1] < .2 else Vector3(.25,.71,.32)
	if limb > 0:
		return Vector3(.245,.245,.49) if part.get("shirt",false) else Vector3(.24,.24,.30)
	if part.get("shirt",false): return Vector3(.68,.7,.38)
	return size

static func color_for(part: Dictionary, index: int, outfit: int) -> Color:
	var colors: Array = COLORS[clampi(outfit,0,4)]
	if part.get("shirt",false): return Color(colors[1] if part.has("limb") else colors[0])
	if absf(float(part.get("limb",0.0))) >= 1: return Color(colors[3] if part.position[1] < .2 else colors[2])
	if index == 4: return Color("465239")
	if index in [5,6]: return Color("fff0c3")
	if index in [7,8]: return Color("994e35")
	if index == 9: return Color("35462c")
	if index == 10: return Color("f3ebd1")
	return Color("a2b96b")

static func patches(outfit: int) -> Array:
	var result: Array = Wardrobe.patches(clampi(outfit,0,4))
	if outfit == 2:
		# Broad checks rather than dozens of dark, noisy squares.
		result = []
		for face in [1.0,-1.0]:
			for x in [-.18,.18]: Wardrobe.add(result,x,1.18,.055,.61,"d9856b",face)
			for y in [1.02,1.28]: Wardrobe.add(result,0,y,.60,.05,"d9856b",face)
			Wardrobe.add(result,0,1.18,.025,.62,"f0d8ad",face,.004)
	for patch in result:
		patch.position.z += signf(patch.position.z)*.012
		if outfit == 1:
			patch.color = Color("3d789d") if patch.color == Color("355b88") else Color("2b5777") if patch.color == Color("274766") else Color("e4d09d")
	return result

static func bevel_for(part: Dictionary, size: Vector3) -> float:
	if minf(size.x,minf(size.y,size.z)) < .07: return 0.0
	return .012 if part.get("head",false) else .018

static func box_vertices(size: Vector3, bevel: float) -> Array:
	# Six planar faces, twelve chamfers and eight tiny corner triangles.
	# 44 triangles per solid part, still one cached skinned surface per outfit.
	var result: Array = []
	var h = size*.5
	var inner = h-Vector3.ONE*bevel
	for axis in 3:
		var b = (axis+1)%3
		var c = (axis+2)%3
		for sign in [-1.0,1.0]:
			var points: Array[Vector3] = []
			for pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var p = Vector3.ZERO
				p[axis] = sign*h[axis]
				p[b] = pair.x*inner[b]
				p[c] = pair.y*inner[c]
				points.append(p)
			var normal = Vector3.ZERO
			normal[axis] = sign
			face(result,points,normal)
	if bevel <= 0: return result
	for axis in 3:
		var b = (axis+1)%3
		var c = (axis+2)%3
		for sb in [-1.0,1.0]:
			for sc in [-1.0,1.0]:
				var points: Array[Vector3] = []
				for pair in [Vector2(-1,0),Vector2(1,0),Vector2(1,1),Vector2(-1,1)]:
					var p = Vector3.ZERO
					p[axis] = pair.x*inner[axis]
					p[b] = sb*(h[b] if pair.y == 0 else inner[b])
					p[c] = sc*(inner[c] if pair.y == 0 else h[c])
					points.append(p)
				var normal = Vector3.ZERO
				normal[b] = sb
				normal[c] = sc
				face(result,points,normal.normalized())
	for sx in [-1.0,1.0]:
		for sy in [-1.0,1.0]:
			for sz in [-1.0,1.0]:
				var signs = Vector3(sx,sy,sz)
				face(result,[Vector3(h.x,inner.y,inner.z)*signs,Vector3(inner.x,h.y,inner.z)*signs,Vector3(inner.x,inner.y,h.z)*signs],signs.normalized())
	# Weighted corner normals soften only the tiny bevels, with no extra faces.
	# The broad planes retain a nearly flat center and catch restrained plastic glints.
	for vertex in result:
		var direction: Vector3 = vertex.position
		var weights = (direction.abs()-inner+Vector3.ONE*(bevel*.22)).max(Vector3.ZERO)
		vertex.normal = (weights*direction.sign()).normalized()
	return result

static func face(result: Array, points: Array, normal: Vector3) -> void:
	for i in range(1,points.size()-1):
		var a: Vector3 = points[0]
		var b: Vector3 = points[i]
		var c: Vector3 = points[i+1]
		# Godot front faces use clockwise winding when viewed from outside.
		if (b-a).cross(c-a).dot(normal) > 0:
			var swap = b
			b = c
			c = swap
		for p in [a,b,c]: result.append({"position":p,"normal":normal})

static func part_visible(index: int, kind: String) -> bool:
	# Bald head; replace the raised old face with flat molded-on toy printing.
	return kind != "normal" or index < 4 or index > 11

static func face_vertices() -> Array:
	# Simple printed features retain the existing molded plastic head.
	var result: Array = []
	for side in [-1.0,1.0]:
		var x = side*.104
		face_print(result,[Vector3(x-.060,1.7975,.2265),Vector3(x-.060,1.8525,.2265),Vector3(x+.060,1.8525,.2265),Vector3(x+.060,1.7975,.2265)],Color.BLACK)
	# Stepped, slightly uneven opening based on the blocky zombie reference.
	# 0 = skin, 1 = complete dark border, 2 = muted red interior; no teeth.
	var mouth = ["0000111000","0011111100","0011222110","0112222210","1122222211","1111111111"]
	for row in mouth.size():
		for column in mouth[row].length():
			var pixel: String = mouth[row][column]
			if pixel == "0": continue
			var left = (column-5)*.024
			var right = left+.024
			var top = 1.745-row*.020
			var bottom = top-.020
			face_print(result,[Vector3(left,top,.2265),Vector3(left,bottom,.2265),Vector3(right,bottom,.2265),Vector3(right,top,.2265)],Color("242821") if pixel == "1" else Color("854e4c"))
	return result

static func face_print(result: Array, points: Array, color: Color) -> void:
	var vertices: Array = []
	face(vertices,points,Vector3.BACK)
	for vertex in vertices:
		vertex.color = color
		result.append(vertex)

static func walk_sample(phase: float) -> Vector3:
	# Six clockwork poses per gait cycle: two long holds and abrupt leg changes.
	# Distance-driven phase is unchanged, so stopping movement freezes the cycle.
	var frame = floori(fposmod(phase,TAU)/TAU*6.0)%6
	return Vector3(MECHANICAL_LEG_ANGLES[frame],MECHANICAL_LEG_ANGLES[(frame+3)%6],sin(phase))

static func plant_feet(root: Transform3D, bones: Array, parts: Array, ground: float) -> Transform3D:
	# Two transformed-box support points; no raycasts or extra physics bodies.
	var low = INF
	for index in [14,15]:
		var part: Dictionary = parts[index]
		var point = Vector3(part.position[0],part.position[1],part.position[2])
		var half_size = part_size(part,"normal")*.5
		var pose: Transform3D = root*bones[1 if index == 14 else 2]
		var center: Vector3 = pose*point
		var radius = absf(pose.basis.x.y)*half_size.x+absf(pose.basis.y.y)*half_size.y+absf(pose.basis.z.y)*half_size.z
		low = minf(low,center.y-radius)
	root.origin.y += ground+.015-low
	return root
