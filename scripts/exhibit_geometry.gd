extends RefCounted
## Shared low-poly construction for the self-contained prologue and display weapons.
var materials: Dictionary = {}

func material(color: String, emission := 0.0, metal := 0.0) -> StandardMaterial3D:
	var key = color+":"+str(emission)+":"+str(metal)
	if materials.has(key): return materials[key]
	var value = StandardMaterial3D.new()
	value.albedo_color = Color(color)
	value.metallic = metal
	value.roughness = .42 if metal > 0 else .82
	if emission > 0:
		value.emission_enabled = true
		value.emission = Color(color)
		value.emission_energy_multiplier = emission
	materials[key] = value
	return value

func mesh(parent: Node3D, title: String, shape: Mesh, at: Vector3, surface: Material) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.name = title
	node.mesh = shape
	node.material_override = surface
	node.position = at
	parent.add_child(node)
	return node

func box(parent: Node3D, title: String, at: Vector3, size: Vector3, color: String, emission := 0.0, metal := 0.0) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = size
	return mesh(parent,title,shape,at,material(color,emission,metal))

func cylinder(parent: Node3D, title: String, at: Vector3, radius: float, height: float, color: String, top := -1.0, emission := 0.0, metal := 0.0, sides := 12) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0 else top
	shape.height = height
	shape.radial_segments = sides
	return mesh(parent,title,shape,at,material(color,emission,metal))

func rod(parent: Node3D, title: String, a: Vector3, b: Vector3, radius: float, color: String, emission := 0.0, metal := 0.0) -> MeshInstance3D:
	var node = cylinder(parent,title,(a+b)*.5,radius,a.distance_to(b),color,-1,emission,metal,8)
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return node

func ring(parent: Node3D, title: String, at: Vector3, radius: float, width: float, color: String, emission := 0.0, vertical := false) -> MeshInstance3D:
	var shape = TorusMesh.new()
	shape.inner_radius = radius-width
	shape.outer_radius = radius+width
	shape.rings = 24
	shape.ring_segments = 6
	var node = mesh(parent,title,shape,at,material(color,emission,.35))
	if vertical: node.rotation.x = PI/2
	return node

func solid(parent: Node3D, title: String, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var node = box(parent,title,at,size,color)
	var body = StaticBody3D.new()
	body.collision_layer = 1
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	node.add_child(body)
	return node

func label(parent: Node3D, title: String, value: String, at: Vector3, color: String, font_size := 48, pixel_size := .004) -> Label3D:
	var node = Label3D.new()
	node.name = title
	node.text = value
	node.position = at
	node.font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	node.font_size = font_size
	node.pixel_size = pixel_size
	node.modulate = Color(color)
	node.outline_size = 6
	node.outline_modulate = Color("080c16")
	parent.add_child(node)
	return node
