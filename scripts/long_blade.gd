extends Node3D
const TIP = 1.55
const SHEATH_LENGTH = 1.61
const CURVE = .065
const TIP_POINT = Vector3(CURVE+.027,TIP,0)
const SHEATH_INNER_WIDTH = .098
const SHEATH_INNER_DEPTH = .034

func _init() -> void:
	name = "UltimateLongBlade"
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var rings = [Vector2(.025,.039),Vector2(.35,.038),Vector2(.70,.037),Vector2(1.05,.035),Vector2(1.36,.032),Vector2(1.40,.027),Vector2(TIP,0)]
	var colors = [Color("eef2ed"),Color("a3b3bf"),Color("657783"),Color("a3b3bf"),Color("eef2ed")]
	for i in rings.size()-1:
		var a = section(rings[i])
		var b = section(rings[i+1])
		for side in a.size():
			var next = (side+1)%a.size()
			surface.set_color(colors[side])
			triangle(surface,a[side],b[next],a[next])
			if not b[side].is_equal_approx(b[next]): triangle(surface,a[side],b[side],b[next])
	var steel = material(Color.WHITE,.72,.29)
	steel.vertex_color_use_as_albedo = true
	attach(self,"Blade",surface,steel)
	var guard = MeshInstance3D.new()
	guard.name = "Guard"
	var disc = CylinderMesh.new()
	disc.top_radius = .103
	disc.bottom_radius = .103
	disc.height = .025
	disc.radial_segments = 20
	guard.mesh = disc
	guard.material_override = material(Color("343039"),.65,.38)
	configure(guard)
	add_child(guard)
	piece("Habaki",Vector3(0,.035,0),Vector3(.088,.055,.046),Color("b69a5b"))
	piece("Grip",Vector3(0,-.18,0),Vector3(.068,.31,.070),Color("c9c5ac"))
	# Diagonal black bands leave light diamond-shaped openings on both grip faces.
	for i in 7:
		for face in [-1.0,1.0]:
			for diagonal in [-1.0,1.0]:
				var wrap = piece("Wrap",Vector3(0,-.047-i*.043,face*.037),Vector3(.088,.015,.008),Color("242730"))
				wrap.rotation.z = diagonal*.64
	piece("Fuchi",Vector3(0,-.028,0),Vector3(.078,.025,.080),Color("a78b51"))
	piece("Pommel",Vector3(0,-.35,0),Vector3(.078,.032,.080),Color("a78b51"))

static func bend(y: float) -> float:
	return CURVE*pow(clampf(y/TIP,0,1),2)

static func section(ring: Vector2) -> Array[Vector3]:
	if is_zero_approx(ring.y): return [TIP_POINT,TIP_POINT,TIP_POINT,TIP_POINT,TIP_POINT]
	var x = bend(ring.x)
	# Only the left edge is sharpened; the opposite side retains a flat spine.
	return [Vector3(x-ring.y,ring.x,0),Vector3(x-ring.y+.013,ring.x,.014),Vector3(x+ring.y,ring.x,.014),Vector3(x+ring.y,ring.x,-.014),Vector3(x-ring.y+.013,ring.x,-.014)]

static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for vertex in [a,b,c]: surface.add_vertex(vertex)

static func material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result

static func configure(part: MeshInstance3D) -> void:
	part.layers = 2
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func attach(parent: Node3D, title: String, surface: SurfaceTool, finish: StandardMaterial3D) -> void:
	surface.generate_normals()
	var part = MeshInstance3D.new()
	part.name = title
	part.mesh = surface.commit()
	part.material_override = finish
	configure(part)
	parent.add_child(part)

func piece(title: String, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var part = MeshInstance3D.new()
	part.name = title
	part.mesh = BoxMesh.new()
	part.mesh.size = size
	part.material_override = material(color,.45,.45)
	part.position = at
	configure(part)
	add_child(part)
	return part

static func sheath_ring(depth: float, width: float, thickness: float) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in 16:
		var angle = TAU*i/16
		result.append(Vector3(-bend(depth)-cos(angle)*width,-depth,sin(angle)*thickness))
	return result

static func make_scabbard() -> Node3D:
	var result = Node3D.new()
	result.name = "LongBladeScabbard"
	var shell = SurfaceTool.new()
	shell.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in 12:
		var a = sheath_ring(SHEATH_LENGTH*step/12,.110,.046)
		var b = sheath_ring(SHEATH_LENGTH*(step+1)/12,.110,.046)
		for i in 16:
			var n = (i+1)%16
			triangle(shell,a[i],a[n],b[n])
			triangle(shell,a[i],b[n],b[i])
	# Close the bottom while leaving the mouth open for the actual blade.
	var bottom = sheath_ring(SHEATH_LENGTH,.110,.046)
	for i in 16: triangle(shell,Vector3(-bend(SHEATH_LENGTH),-SHEATH_LENGTH,0),bottom[i],bottom[(i+1)%16])
	attach(result,"LacqueredSaya",shell,material(Color("191e29"),.25,.24))
	var inner = SurfaceTool.new()
	inner.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in 12:
		var a = sheath_ring(SHEATH_LENGTH*step/12,SHEATH_INNER_WIDTH,SHEATH_INNER_DEPTH)
		var b = sheath_ring(SHEATH_LENGTH*(step+1)/12,SHEATH_INNER_WIDTH,SHEATH_INNER_DEPTH)
		for i in 16:
			var n = (i+1)%16
			triangle(inner,a[i],b[n],a[n])
			triangle(inner,a[i],b[i],b[n])
	attach(result,"SayaInterior",inner,material(Color("24212a"),0,.85))
	for depth in [0.0,SHEATH_LENGTH-.055]:
		var rim = SurfaceTool.new()
		rim.begin(Mesh.PRIMITIVE_TRIANGLES)
		var outer = sheath_ring(depth,.113,.049)
		var inside = sheath_ring(depth,SHEATH_INNER_WIDTH,SHEATH_INNER_DEPTH)
		var lower = sheath_ring(depth+.035,.113,.049)
		for i in 16:
			var n = (i+1)%16
			triangle(rim,outer[i],inside[i],inside[n])
			triangle(rim,outer[i],inside[n],outer[n])
			triangle(rim,outer[i],outer[n],lower[n])
			triangle(rim,outer[i],lower[n],lower[i])
		attach(result,"SayaRim",rim,material(Color("a58a52"),.65,.36))
	return result
