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

static func model(slot: int) -> Node3D:
	var root = Node3D.new()
	if slot == 5:
		box(root,Vector3(.32,.24,.12),Vector3.ZERO,Color("b24d3f"))
		box(root,Vector3(.05,.15,.015),Vector3(0,0,-.068),Color("eee4cd"))
		box(root,Vector3(.15,.05,.015),Vector3(0,0,-.069),Color("eee4cd"))
		box(root,Vector3(.14,.035,.04),Vector3(0,.14,0),Color("504337"))
	else:
		box(root,Vector3(.09,.13,.09),Vector3.ZERO,Color("53603b"))
		box(root,Vector3(.04,.045,.04),Vector3(0,.08,0),Color("9c9166"))
		box(root,Vector3(.025,.14,.025),Vector3(.057,.025,0),Color("aaa99a"))
	return root
