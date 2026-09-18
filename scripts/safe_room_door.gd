extends RefCounted
## Authored layered steelwork, shared by both faces and both safe rooms.
static func piece(parent: Node3D, pos: Vector3, size: Vector3, color: String, metal := true) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.metallic = .45 if metal else 0.0
	material.roughness = .78
	node.material_override = material
	parent.add_child(node)
	return node

static func bolt(parent: Node3D, pos: Vector3) -> void:
	var node = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = .037
	mesh.bottom_radius = .045
	mesh.height = .025
	mesh.radial_segments = 6
	node.mesh = mesh
	node.position = pos
	node.rotation.x = PI/2
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("555b54")
	material.metallic = .65
	material.roughness = .66
	node.material_override = material
	parent.add_child(node)

static func frame(parent: Node3D) -> void:
	for x in [-.10,3.10]:
		piece(parent,Vector3(x,2.06,0),Vector3(.22,4.12,.35),"60675d")
		piece(parent,Vector3(x,2.06,.19),Vector3(.07,4.12,.025),"868a78")
		for y in [.25,.85,1.45,2.05,2.65,3.25,3.85]: bolt(parent,Vector3(x,y,.20))
	piece(parent,Vector3(1.5,3.92,0),Vector3(3.42,.16,.35),"777c6b")
	for x in [.25,.75,1.25,1.75,2.25,2.75]: bolt(parent,Vector3(x,3.92,.20))
	piece(parent,Vector3(1.5,.035,0),Vector3(3,.07,.40),"434c47")

static func leaf(parent: Node3D) -> void:
	piece(parent,Vector3(1.5,.99,0),Vector3(2.4,1.7,.12),"402b26",false)
	# The upper aperture has recessed dark safety glass behind the bars.
	var pane = piece(parent,Vector3(1.5,2.74,0),Vector3(2.25,1.57,.045),"26342e",false)
	pane.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.material_override.albedo_color = Color(.10,.15,.12,.68)
	for face in [-1.0,1.0]:
		for x in [.35,2.65]: piece(parent,Vector3(x,2.75,face*.09),Vector3(.12,1.7,.08),"71372c",false)
		for x in [.17,2.83]: piece(parent,Vector3(x,2,face*.075),Vector3(.27,4,.14),"555e56")
		for y in [.14,1.88,3.62,3.9]: piece(parent,Vector3(1.5,y,face*.075),Vector3(2.6,.20,.14),"687064")
		# Uneven red panels and exposed dark joints below the viewing grille.
		for row in 5:
			var y = .37+row*.29
			piece(parent,Vector3(1.5,y,face*.065),Vector3(2.37,.27,.11),["652f29","73372f","542b28","783a30","63322b"][row],false)
			for mark in 5:
				var x = .40+fmod(row*.37+mark*.43,2.13)
				piece(parent,Vector3(x,y-.075+mark*.024,face*.124),Vector3(.08+fmod(mark*.071,.17),.015,.006),"8b7760",false)
		for y in [.62,1.25]:
			piece(parent,Vector3(1.5,y,face*.15),Vector3(2.65,.115,.07),"777c6b")
			for x in [.3,.85,2.15,2.7]: bolt(parent,Vector3(x,y,face*.20))
		# Deep grille rails and seven independent vertical rods.
		for y in [2.02,3.48]: piece(parent,Vector3(1.5,y,face*.13),Vector3(2.45,.11,.10),"939787")
		for x in [.48,.82,1.16,1.50,1.84,2.18,2.52]:
			piece(parent,Vector3(x,2.75,face*.13),Vector3(.065,1.52,.10),"818b7b")
		piece(parent,Vector3(1.5,2.63,face*.17),Vector3(2.43,.08,.07),"616e62")
		# Bolted diagonal reinforcement around, rather than covering, the window.
		for info in [[.62,3.45,-.48],[2.47,3.52,.72],[.43,2.10,.55]]:
			var brace = piece(parent,Vector3(info[0],info[1],face*.22),Vector3(.85,.14,.08),"92937d")
			brace.rotation.z = info[2]
			for side in [-1,1]: bolt(parent,brace.position+Vector3(cos(info[2])*.32*side,sin(info[2])*.32*side,face*.05))
		piece(parent,Vector3(1.5,3.78,face*.16),Vector3(2.36,.20,.045),"a49853",false)
		for i in 9:
			var stripe = piece(parent,Vector3(.48+i*.25,3.78,face*.188),Vector3(.12,.24,.008),"262d29",false)
			stripe.rotation.z = -.48
		piece(parent,Vector3(1.5,1.61,face*.15),Vector3(.94,.32,.03),"302f28",false)
		var label = Label3D.new()
		label.text = "EXIT"
		label.font_size = 80
		label.pixel_size = .0032
		label.modulate = Color("d0c4a7")
		label.outline_size = 0
		label.position = Vector3(1.5,1.61,face*.18)
		if face < 0: label.rotation.y = PI
		parent.add_child(label)
		# Rust along the edges and rivets define depth even in low light.
		for x in [.17,2.83]:
			for i in 9:
				var y = .25+i*.42
				piece(parent,Vector3(x-.075,y+.065,face*.151),Vector3(.045,.12,.008),"654632",false)
				bolt(parent,Vector3(x,y,face*.16))
		piece(parent,Vector3(2.65,1.67,face*.21),Vector3(.14,.39,.08),"414c47")
		piece(parent,Vector3(2.53,1.68,face*.29),Vector3(.31,.065,.09),"848877")
