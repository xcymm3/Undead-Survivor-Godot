extends RefCounted
## Native geometric props shared by world pickups and held equipment.
static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var view = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	view.mesh = mesh
	view.position = pos
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .8
	view.material_override = material
	parent.add_child(view)

static func model(_slot: int) -> Node3D:
	var root = Node3D.new()
	box(root,Vector3(.09,.13,.09),Vector3.ZERO,Color("53603b"))
	box(root,Vector3(.04,.045,.04),Vector3(0,.08,0),Color("9c9166"))
	box(root,Vector3(.025,.14,.025),Vector3(.057,.025,0),Color("aaa99a"))
	return root
