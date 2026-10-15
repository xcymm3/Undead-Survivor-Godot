extends Node3D
const TIP = 1.55
const SHEATH_LENGTH = 1.61

func _init() -> void:
	name = "UltimateLongBlade"
	# Diamond cross-sections form real bevels; the final ring converges to one tip.
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var rings = [Vector2(.025,.052),Vector2(1.22,.043),Vector2(1.39,.027),Vector2(TIP,0)]
	for i in rings.size()-1:
		var a = section(rings[i])
		var b = section(rings[i+1])
		for side in 4:
			var next = (side+1)%4
			var vertices = [a[side],b[next],a[next]]
			if not b[side].is_equal_approx(b[next]): vertices.append_array([a[side],b[side],b[next]])
			for vertex in vertices:
				surface.add_vertex(vertex)
	surface.generate_normals()
	var blade = MeshInstance3D.new()
	blade.name = "Blade"
	blade.mesh = surface.commit()
	var steel = StandardMaterial3D.new()
	steel.albedo_color = Color("cad8de")
	steel.metallic = .78
	steel.roughness = .28
	blade.material_override = steel
	blade.layers = 2
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blade)
	piece("Guard",Vector3.ZERO,Vector3(.25,.045,.10),Color("b39753"))
	piece("Grip",Vector3(0,-.18,0),Vector3(.065,.32,.07),Color("342d2b"))
	for i in 7: piece("Wrap",Vector3(0,-.04-i*.043,0),Vector3(.073,.012,.078),Color("706049"))
	piece("Pommel",Vector3(0,-.35,0),Vector3(.086,.05,.09),Color("b39753"))

static func section(ring: Vector2) -> Array[Vector3]:
	var thickness = .018*minf(1,ring.y/.027)
	return [Vector3(-ring.y,ring.x,0),Vector3(0,ring.x,thickness),Vector3(ring.y,ring.x,0),Vector3(0,ring.x,-thickness)]

func piece(title: String, at: Vector3, size: Vector3, color: Color) -> void:
	var part = MeshInstance3D.new()
	part.name = title
	part.mesh = BoxMesh.new()
	part.mesh.size = size
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = .5
	material.roughness = .55
	part.material_override = material
	part.position = at
	part.layers = 2
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)

static func make_scabbard() -> Node3D:
	var result = Node3D.new()
	result.name = "LongBladeScabbard"
	for side in [-1.0,1.0]:
		for plane in 2:
			var part = MeshInstance3D.new()
			part.mesh = BoxMesh.new()
			part.mesh.size = Vector3(.012,SHEATH_LENGTH,.075) if plane == 0 else Vector3(.12,SHEATH_LENGTH,.012)
			part.position = Vector3(side*.06,-SHEATH_LENGTH*.5,0) if plane == 0 else Vector3(0,-SHEATH_LENGTH*.5,side*.0375)
			var material = StandardMaterial3D.new()
			material.albedo_color = Color("493c32")
			material.roughness = .8
			part.material_override = material
			part.layers = 2
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			result.add_child(part)
	for y in [-.035,-SHEATH_LENGTH+.10]:
		var metal = StandardMaterial3D.new()
		metal.albedo_color = Color("a89460")
		metal.metallic = .65
		metal.roughness = .4
		# Four open sides: the mouth must not be a solid cap hiding the blade.
		for side in [-1.0,1.0]:
			for plane in 2:
				var edge = MeshInstance3D.new()
				edge.mesh = BoxMesh.new()
				edge.mesh.size = Vector3(.018,.055,.10) if plane == 0 else Vector3(.145,.055,.018)
				edge.position = Vector3(side*.064,y,0) if plane == 0 else Vector3(0,y,side*.046)
				edge.material_override = metal
				edge.layers = 2
				edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				result.add_child(edge)
	return result
