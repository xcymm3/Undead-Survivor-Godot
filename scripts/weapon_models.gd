extends RefCounted
## One geometry and sight factory for first person, partners, displays and pickups.
const AXE_HEAD_PARTS = ["NeckGuard","FireAxeHead","FireAxeBlade","FireAxePick","PickTip","HeadSocket","HandleWedge"]

static func create(id: String, first_person := false) -> Node3D:
	var model: Node3D
	match id:
		"ultimate":
			model = Node3D.new()
			var grip = Node3D.new()
			grip.name = "UltimateGrip"
			model.add_child(grip)
			var blade = preload("res://scripts/long_blade.gd").new()
			blade.scale = Vector3.ONE*.8
			grip.add_child(blade)
			for mesh in blade.find_children("*","MeshInstance3D",true,false): mesh.layers = 1
		"axe":
			model = load("res://assets/models/axe.glb").instantiate()
			extend_axe_handle(model)
		"rifle": model = preload("res://scripts/ak_rifle.gd").new()
		"revolver":
			model = preload("res://scripts/revolver_view.gd").new() if first_person else preload("res://scripts/revolver_model.gd").new()
		_: model = load("res://assets/models/%s.glb" % id).instantiate()
	if id in ["p90","pistol","heavy-machine-gun"]: attach_sight(id,model)
	return model

static func extend_axe_handle(model: Node3D) -> void:
	# Lengthen only the shaft above the fixed lower grip; keep head geometry full size.
	var shaft = model.find_child("FiberglassHandle",true,false) as MeshInstance3D
	var bounds = shaft.mesh.get_aabb()
	const LENGTH_SCALE = 1.10
	shaft.scale.y *= LENGTH_SCALE
	shaft.position.y += bounds.position.y*(1.0-LENGTH_SCALE)
	var extension = bounds.size.y*(LENGTH_SCALE-1.0)
	for title in AXE_HEAD_PARTS:
		var part = model.find_child(title,true,false) as Node3D
		part.position.y += extension
	# Imported clips also key static child transforms. Keep their root choreography,
	# but prevent them from undoing the shaft extension on the first frame.
	for player in model.find_children("*","AnimationPlayer",true,false):
		for title in player.get_animation_library_list():
			var library = player.get_animation_library(title).duplicate(true) as AnimationLibrary
			for clip in library.get_animation_list():
				var animation = library.get_animation(clip)
				for track in range(animation.get_track_count()-1,-1,-1):
					var path = animation.track_get_path(track)
					if path.get_name_count() == 0: continue
					var target = str(path.get_name(path.get_name_count()-1))
					var type = animation.track_get_type(track)
					if (target == "FiberglassHandle" and type in [Animation.TYPE_POSITION_3D,Animation.TYPE_SCALE_3D]) or (target in AXE_HEAD_PARTS and type == Animation.TYPE_POSITION_3D):
						animation.remove_track(track)
			player.remove_animation_library(title)
			player.add_animation_library(title,library)

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
