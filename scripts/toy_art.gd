extends RefCounted
## Shared opaque moulded-plastic palette and native toy construction pieces.
const BLUE = "387cdc"
const CORAL = "ed6957"
const YELLOW = "ffd15c"
const CREAM = "fff0cd"
const MINT = "63d5bb"
const INK = "243e68"
static var palette: Dictionary = {}

static func material(color: String) -> StandardMaterial3D:
	if not palette.has(color):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(color)
		mat.roughness = .32
		mat.metallic = 0.0
		palette[color] = mat
	return palette[color]

static func box(parent: Node3D, title: String, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var view = MeshInstance3D.new()
	view.name = title
	var mesh = BoxMesh.new()
	mesh.size = size
	view.mesh = mesh
	view.position = at
	view.material_override = material(color)
	parent.add_child(view)
	return view

static func cylinder(parent: Node3D, title: String, at: Vector3, radius: float, height: float, color: String) -> MeshInstance3D:
	var view = MeshInstance3D.new()
	view.name = title
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	view.mesh = mesh
	view.position = at
	view.material_override = material(color)
	parent.add_child(view)
	return view

static func oval(parent: Node3D, title: String, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var view = MeshInstance3D.new()
	view.name = title
	var mesh = SphereMesh.new()
	mesh.radius = .5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 10
	view.mesh = mesh
	view.scale = size
	view.position = at
	view.material_override = material(color)
	parent.add_child(view)
	return view

static func label(parent: Node3D, title: String, text: String, at: Vector3, size: float, facing_back := false) -> Label3D:
	var view = Label3D.new()
	view.name = title
	view.text = text
	view.font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	view.font_size = 48
	view.pixel_size = size
	view.outline_size = 0
	view.modulate = Color(INK)
	view.position = at
	view.rotation.y = PI if facing_back else 0.0
	parent.add_child(view)
	return view
