extends Node3D
func _init() -> void:
	name = "UltimateLongBlade"
	piece("Blade",Vector3(0,.56,0),Vector3(.085,1.1,.025),Color("c1ced0"))
	piece("Edge",Vector3(.048,.56,0),Vector3(.012,1.08,.03),Color("f1f0dd"))
	piece("Guard",Vector3.ZERO,Vector3(.25,.045,.10),Color("b39753"))
	piece("Grip",Vector3(0,-.18,0),Vector3(.065,.32,.07),Color("342d2b"))
	for i in 7: piece("Wrap",Vector3(0,-.04-i*.043,0),Vector3(.073,.012,.078),Color("706049"))
	add_child(make_hand(true))

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
			part.mesh.size = Vector3(.012,1.15,.075) if plane == 0 else Vector3(.12,1.15,.012)
			part.position = Vector3(side*.06,-.575,0) if plane == 0 else Vector3(0,-.575,side*.0375)
			var material = StandardMaterial3D.new()
			material.albedo_color = Color("493c32")
			material.roughness = .8
			part.material_override = material
			part.layers = 2
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			result.add_child(part)
	for y in [-.06,-.87]:
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

static func make_hand(right: bool) -> Node3D:
	var result = Node3D.new()
	result.name = "GripHand" if right else "ScabbardHand"
	var shapes = [[Vector3(0,-.19,.015),Vector3(.18,.20,.18),"65614c"],
		[Vector3(0,-.31,.015),Vector3(.19,.065,.19),"293b46"],
		[Vector3(.095 if right else -.095,-.15,-.025),Vector3(.075,.13,.085),"81785b"]]
	for y in [-.12,-.18,-.24]: shapes.append([Vector3(0,y,-.085),Vector3(.17,.045,.055),"827a60"])
	for shape in shapes:
		var part = MeshInstance3D.new()
		part.mesh = BoxMesh.new()
		part.mesh.size = shape[1]
		part.position = shape[0]
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(shape[2])
		material.roughness = .8
		part.material_override = material
		part.layers = 2
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		result.add_child(part)
	return result

static func make_arm() -> MeshInstance3D:
	var result = MeshInstance3D.new()
	result.mesh = BoxMesh.new()
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("314652")
	material.roughness = .85
	result.material_override = material
	result.layers = 2
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result
