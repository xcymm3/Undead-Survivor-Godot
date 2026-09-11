extends Node3D
## Render original meshes with native ArrayMesh/MultiMesh, using the source collision footprints.
var obstacles: Array = []
var instance_buffers: Dictionary = {}
var baked_ok = false
# Stable geometry IDs in the imported world: ground, road shoulders, road, markings.
const LAND_SURFACES = ["834d0ed6-de0b-4d94-bd39-b8fd8280b428","7f1a43fd-1349-47fd-b6e3-b3bb2a2cf153","25d16ccd-cae7-4edb-aba3-4fe3360a1323","8af03cfc-534c-49f9-ad83-6d9365fa6058","14eaefc6-2f2b-4eb7-b80c-cf2ddc64a2f4"]
const OLD_RIVER_SURFACES = ["77afc216-78d5-4040-a0cc-5b6627d15bb2","41a5a20e-a140-4e7b-b69a-744ee1006445"]
const OLD_FOAM_MATERIAL = "d92f72d7-d42c-4db5-859a-e040528c63dc"

func _ready() -> void:
	var data = get_node("/root/Data")
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/world.json"))
	obstacles = world.obstacles.filter(func(o): return o.minX < 22 and o.maxX > -22 and o.minZ < 14 and o.maxZ > -48)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/world-collisions.json"))
	if manifest.source_sha256 != FileAccess.get_sha256("res://assets/data/world.json") or manifest.meshes.size() != world.meshes.size():
		push_error("World changed: review collision manifest before baking")
		return
	var meshes = {}
	var mesh_faces = {}
	var materials = {}
	for id in world.materials:
		var source: Dictionary = world.materials[id]
		var material = StandardMaterial3D.new()
		material.resource_scene_unique_id = "Material_"+id.replace("-","_")
		material.albedo_color = Color(source.color[0],source.color[1],source.color[2]).linear_to_srgb()
		material.roughness = source.roughness
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if source.unshaded: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		materials[id] = material
	for id in world.geometries:
		var source: Dictionary = world.geometries[id]
		var vertices = PackedVector3Array()
		var normals = PackedVector3Array()
		for i in range(0, source.position.size(), 3):
			var vertex = Vector3(source.position[i],source.position[i+1],source.position[i+2])
			if id in LAND_SURFACES:
				var offset = vertex.z-data.river_center(vertex.x)
				if absf(absf(offset)-1.25) < .01:
					vertex.z += signf(offset)*(data.RIVER_BANK_HALF-1.25)
			vertices.append(vertex)
			normals.append(Vector3(source.normal[i],source.normal[i+1],source.normal[i+2]))
		var indices = PackedInt32Array(source.index)
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		# glTF/Three counterclockwise faces become Godot clockwise faces.
		for i in range(0, indices.size(), 3):
			var swap = indices[i+1]
			indices[i+1] = indices[i+2]
			indices[i+2] = swap
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh = ArrayMesh.new()
		mesh.resource_scene_unique_id = "Mesh_"+id.replace("-","_")
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		meshes[id] = mesh
		var triangles = PackedVector3Array()
		for index in indices: triangles.append(vertices[index])
		mesh_faces[id] = triangles
	for mesh_index in world.meshes.size():
		var source: Dictionary = world.meshes[mesh_index]
		var entry: Dictionary = manifest.meshes[mesh_index]
		var collision_instances = PackedInt32Array(entry.collision_instances)
		if entry.geometry != source.geometry or entry.material != source.material:
			push_error("Collision manifest no longer matches mesh %d" % mesh_index)
			return
		for index in collision_instances:
			if index < 0 or index >= source.transforms.size():
				push_error("Invalid collision instance on mesh %d" % mesh_index)
				return
		if source.geometry in OLD_RIVER_SURFACES or source.material == OLD_FOAM_MATERIAL: continue
		var instance = MultiMeshInstance3D.new()
		instance.name = "Scenery_%03d" % mesh_index
		var faces = PackedVector3Array()
		var buffer = PackedFloat32Array()
		var multi = MultiMesh.new()
		multi.resource_scene_unique_id = "MultiMesh_world_%03d" % mesh_index
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = meshes[source.geometry]
		multi.instance_count = source.transforms.size()
		for i in source.transforms.size():
			var transform = data.from_matrix(source.transforms[i])
			multi.set_instance_transform(i, transform)
			buffer.append_array(PackedFloat32Array([transform.basis.x.x,transform.basis.y.x,transform.basis.z.x,transform.origin.x,transform.basis.x.y,transform.basis.y.y,transform.basis.z.y,transform.origin.y,transform.basis.x.z,transform.basis.y.z,transform.basis.z.z,transform.origin.z]))
			var color = Color.WHITE
			if source.colors.size() > i:
				var c: Array = source.colors[i]
				color = Color(c[0],c[1],c[2]).linear_to_srgb()
			multi.set_instance_color(i,color)
			buffer.append_array(PackedFloat32Array([color.r,color.g,color.b,color.a]))
			# Membership is authored independently of batching and placement.
			if i in collision_instances:
				for vertex in mesh_faces[source.geometry]: faces.append(transform * vertex)
		instance.multimesh = multi
		instance.material_override = materials[source.material]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if source.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		instance_buffers[multi.resource_scene_unique_id] = buffer
		if not faces.is_empty():
			var body = StaticBody3D.new()
			body.name = "Collision"
			var collider = CollisionShape3D.new()
			collider.name = "Shape"
			var shape = ConcavePolygonShape3D.new()
			shape.resource_scene_unique_id = "Collision_%03d" % mesh_index
			shape.backface_collision = true
			shape.set_faces(faces)
			collider.shape = shape
			body.add_child(collider)
			instance.add_child(body)
	for sign_index in world.signs.size():
		var sign: Dictionary = world.signs[sign_index]
		var label = Label3D.new()
		label.name = "Sign_%02d" % sign_index
		label.text = sign.text + "\n" + sign.subtitle
		label.font_size = 42
		label.pixel_size = sign.width / 640.0
		label.modulate = Color("e4dfbd")
		label.outline_size = 5
		label.outline_modulate = Color("303e38")
		label.transform = data.from_matrix(sign.matrix)
		add_child(label)
	set_meta("navigation_obstacles", obstacles)
	baked_ok = true
