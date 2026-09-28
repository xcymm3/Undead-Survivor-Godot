extends Node3D
var obstacles: Array = []
var materials: Dictionary = {}
var projectile_views: Dictionary = {}

func material(color: String) -> StandardMaterial3D:
	if not materials.has(color):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(color)
		mat.roughness = .85
		materials[color] = mat
	return materials[color]

func block(title: String, pos: Vector3, size: Vector3, color: String, solid := true, nav := true) -> Node3D:
	var item = StaticBody3D.new() if solid else Node3D.new()
	item.name = title
	item.position = pos
	var view = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	view.mesh = mesh
	view.material_override = material(color)
	item.add_child(view)
	if solid:
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = size
		shape.shape = box
		item.add_child(shape)
	add_child(item)
	if solid and nav: obstacles.append({"minX":pos.x-size.x/2,"maxX":pos.x+size.x/2,"minZ":pos.z-size.z/2,"maxZ":pos.z+size.z/2})
	return item

func sign_at(text: String, pos: Vector3, width := 4.0) -> Label3D:
	var backing = block("Sign",pos,Vector3(width,.55*text.split("\n").size()+.15,.18),"273e36",false)
	var label = Label3D.new()
	label.set_meta("backing",backing)
	label.text = text
	label.font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	label.font_size = 64
	var longest = 1
	for line in text.split("\n"): longest = maxi(longest,line.length())
	label.pixel_size = minf(.006,width*.82/(64*longest))
	label.position = pos+Vector3(0,0,.11)
	label.no_depth_test = false
	add_child(label)
	return label

func cylinder(pos: Vector3, radius: float, height: float, color: String, sideways := false) -> MeshInstance3D:
	var view = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	view.mesh = mesh
	view.material_override = material(color)
	view.position = pos
	if sideways: view.rotation.z = PI/2
	add_child(view)
	return view

func sync_projectiles(state: Dictionary) -> void:
	var live: Array = []
	for projectile in state.get("projectiles",[]):
		live.append(projectile.id)
		if not projectile_views.has(projectile.id):
			var prop = preload("res://scripts/equipment_props.gd").model(4)
			add_child(prop)
			projectile_views[projectile.id] = prop
		projectile_views[projectile.id].position = projectile.pos
		projectile_views[projectile.id].rotation.x = projectile.fuse*8
	for id in projectile_views.keys():
		if not live.has(id):
			projectile_views[id].queue_free()
			projectile_views.erase(id)

static func posed_bounds(model: Node3D) -> AABB:
	# Imported skins use a vertical bind pose but a horizontal displayed pose.
	# Fit the displayed vertices, not the unskinned import bounding box.
	var result = AABB()
	var first = true
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		var skeleton = mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		var transforms: Array[Transform3D] = []
		if mesh.skin and skeleton:
			for i in mesh.skin.get_bind_count():
				var bone: int = mesh.skin.get_bind_bone(i)
				if bone < 0: bone = skeleton.find_bone(mesh.skin.get_bind_name(i))
				transforms.append(skeleton.global_transform*skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(i) if bone >= 0 else mesh.global_transform)
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			for i in vertices.size():
				var point: Vector3 = mesh.global_transform*vertices[i]
				if not transforms.is_empty() and bones != null and weights != null and weights.size() > 0:
					point = Vector3.ZERO
					var count: int = weights.size()/vertices.size()
					for j in count:
						var bind: int = bones[i*count+j]
						if weights[i*count+j] > 0 and bind < transforms.size(): point += (transforms[bind]*vertices[i])*weights[i*count+j]
				# Reload-only cartridges are parked far below the imported gun.
				if point.distance_squared_to(model.global_position) > 16: continue
				result = AABB(point,Vector3.ZERO) if first else result.expand(point)
				first = false
	return result
