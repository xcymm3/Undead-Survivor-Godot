extends RefCounted
## One geometry and sight factory for first person, partners, displays and pickups.

static func create(id: String, first_person := false) -> Node3D:
	var model: Node3D
	match id:
		"rifle": model = preload("res://scripts/ak_rifle.gd").new()
		"revolver":
			model = preload("res://scripts/revolver_view.gd").new() if first_person else preload("res://scripts/revolver_model.gd").new()
		_: model = load("res://assets/models/%s.glb" % id).instantiate()
	if id in ["p90","pistol","heavy-machine-gun"]: attach_sight(id,model)
	return model

static func attach_sight(id: String, model: Node3D) -> void:
	var sight = preload("res://scripts/iron_sight.gd").new(id)
	if id == "heavy-machine-gun":
		var rear = model.find_child("RearSight",true,false)
		model.find_child("FrontSight",true,false).visible = false
		rear.visible = false
		rear.get_parent().add_child(sight)
	else:
		var skeleton: Skeleton3D = model.find_children("*","Skeleton3D",true,false)[0]
		var bone_name = "Slide" if id == "pistol" else "Control"
		var attachment = BoneAttachment3D.new()
		attachment.name = "SightAttachment"
		attachment.bone_name = bone_name
		skeleton.add_child(attachment)
		attachment.add_child(sight)
		# Build in model coordinates before entering a scene tree or applying view scale.
		var skeleton_in_model = Transform3D.IDENTITY
		var node: Node3D = skeleton
		while node != model:
			skeleton_in_model = node.transform*skeleton_in_model
			node = node.get_parent() as Node3D
		sight.transform = (skeleton_in_model*skeleton.get_bone_global_rest(skeleton.find_bone(bone_name))).affine_inverse()
