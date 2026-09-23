extends Node3D
## Physical, open-top U notch. The marker line passes through the blade tip.
var rear: Marker3D
var front: Marker3D

func _init(height: float, rear_z: float, front_z: float, width := .09, gap := .019, notch := .024, blade := .012, mount_y := .15) -> void:
	name = "IronSight"
	var radius = gap*.5
	var bottom = -notch-.012
	var outline = PackedVector2Array([
		Vector2(-width*.5,bottom),Vector2(width*.5,bottom),
		Vector2(width*.5,-.008),Vector2(width*.5-.008,0),Vector2(radius,0)])
	# A rounded floor with straight sides reads as a machined U, not three floating blocks.
	for i in 9:
		var angle = -PI*float(i)/8.0
		outline.append(Vector2(cos(angle)*radius,-notch+radius+sin(angle)*radius))
	outline.append(Vector2(-radius,0))
	outline.append(Vector2(-width*.5+.008,0))
	outline.append(Vector2(-width*.5,-.008))
	var rear_part = part("RearNotch",extrude(outline,.028),Vector3(0,height,rear_z),"48504e")
	# The base meets the receiver; all material stays below the open sight line.
	box("RearMount",Vector3(0,(height+bottom+mount_y)*.5,rear_z),Vector3(width+.012,height+bottom-mount_y,.064),"353d3d")
	box("FrontRamp",Vector3(0,(height-.032+mount_y)*.5,front_z),Vector3(.046,height-.032-mount_y,.064),"353d3d")
	box("FrontBlade",Vector3(0,height-.019,front_z),Vector3(blade,.038,.024),"737b70")
	# A small, non-emissive ivory insert on the face toward the eye, below the aiming edge.
	box("FrontInlay",Vector3(0,height-.009,front_z+.0125),Vector3(blade*.55,.006,.001),"c5c0a0")
	for side in [-1,1]:
		box("RearSerration",Vector3(side*(radius+.012),height-.014,rear_z+.0145),Vector3(.012,.002,.001),"242d2d")
	rear = Marker3D.new()
	rear.name = "RearAim"
	rear.position = Vector3(0,height,rear_z)
	add_child(rear)
	front = Marker3D.new()
	front.name = "FrontAim"
	front.position = Vector3(0,height,front_z)
	add_child(front)
	rear_part.set_meta("gap",gap)

func part(title: String, shape: Mesh, at: Vector3, color: String) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.name = title
	node.mesh = shape
	node.position = at
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = .82
	material.metallic = .15
	node.material_override = material
	add_child(node)
	return node

func box(title: String, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = size
	return part(title,shape,at,color)

static func extrude(outline: PackedVector2Array, depth: float) -> ArrayMesh:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices = Geometry2D.triangulate_polygon(outline)
	for side in [-1.0,1.0]:
		for i in range(0,indices.size(),3):
			for corner in ([2,1,0] if side < 0 else [0,1,2]):
				var point = outline[indices[i+corner]]
				surface.set_normal(Vector3(0,0,side))
				surface.add_vertex(Vector3(point.x,point.y,side*depth*.5))
	for i in outline.size():
		var a = outline[i]
		var b = outline[(i+1)%outline.size()]
		var normal = Vector3(b.y-a.y,a.x-b.x,0).normalized()
		for point in [Vector3(a.x,a.y,-depth*.5),Vector3(b.x,b.y,-depth*.5),Vector3(b.x,b.y,depth*.5),Vector3(a.x,a.y,-depth*.5),Vector3(b.x,b.y,depth*.5),Vector3(a.x,a.y,depth*.5)]:
			surface.set_normal(normal)
			surface.add_vertex(point)
	# Godot front faces use clockwise winding.
	var mesh = surface.commit()
	var arrays = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(0,vertices.size(),3):
		var swap = vertices[i]
		vertices[i] = vertices[i+2]
		vertices[i+2] = swap
		var normal_swap = normals[i]
		normals[i] = normals[i+2]
		normals[i+2] = normal_swap
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var result = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
