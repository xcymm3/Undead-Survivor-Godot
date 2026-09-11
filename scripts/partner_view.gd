extends Node3D
var avatar: Node3D
var animation: AnimationPlayer
var previous_position = Vector3.ZERO
var label: Label3D
var held: Node3D
var weapon_index = -1
var weapon_animation: AnimationPlayer
var axe_pivot: Node3D
var skeleton: Skeleton3D
var gun_model: Node3D
var flash: MeshInstance3D

func setup(p: Dictionary) -> void:
	var appearance: Array = p.appearance
	avatar = preload("res://scripts/survivor_model.gd").new()
	add_child(avatar)
	avatar.build(int(appearance[0]))
	label = Label3D.new()
	label.font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	label.text = p.name
	label.font_size = 36
	label.pixel_size = .008
	label.position.y = 2.2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("eadfc6")
	add_child(label)
	avatar.rotation.y = 0
	for node in avatar.find_children("*","Skeleton3D",true,false): skeleton = node
	flash = MeshInstance3D.new()
	var flash_mesh = SphereMesh.new()
	flash_mesh.radius = .025
	flash_mesh.height = .07
	flash.mesh = flash_mesh
	var flash_material = StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1,.73,.27)
	flash.material_override = flash_material
	flash.visible = false
	add_child(flash)
	held = Node3D.new()
	held.position = Vector3(.22,1.42,-.48)
	add_child(held)
	position = Vector3(p.pos.x,p.height,p.pos.y)
	previous_position = position
	update_weapon(p.weapon)

func update_weapon(index: int) -> void:
	if weapon_index == index: return
	weapon_index = index
	axe_pivot = null
	for node in held.get_children():
		held.remove_child(node)
		node.queue_free()
	var model = load("res://assets/models/%s.glb" % Data.weapons[index].id).instantiate() as Node3D
	gun_model = model
	model.scale = Vector3.ONE*.75
	held.add_child(model)
	if Data.weapons[index].id == "axe":
		var head = model.find_child("FireAxeHead",true,false)
		if head: axe_pivot = head.get_parent() as Node3D
	var finder = preload("res://scripts/weapon_view.gd").new()
	weapon_animation = finder.find_animation(model)
	finder.free()

func sync(p: Dictionary, dt: float) -> void:
	var destination = Vector3(p.pos.x,p.height,p.pos.y)
	var moving = destination.distance_squared_to(previous_position) > .00005
	previous_position = destination
	position = position.lerp(destination,1-exp(-dt*18))
	rotation.y = p.yaw
	visible = true
	update_weapon(int(p.weapon))
	held.visible = p.hp > 0
	held.rotation.x = p.pitch
	label.text = "%s  %d HP" % [p.name,p.hp]
	if skeleton: skeleton.clear_bones_global_pose_override()
	var w: Dictionary = Data.weapons[int(p.weapon)]
	if weapon_animation:
		var clip = "reload" if p.reloading else "fire"
		if weapon_animation.has_animation(clip):
			if weapon_animation.current_animation != clip: weapon_animation.play(clip)
			weapon_animation.pause()
			var progress = clampf(1-p.reload/maxf(.1,w.reloadDuration),0,1) if p.reloading else clampf(1-p.fire_anim/w.fireDuration,0,1) if p.fire_anim > 0 else 0.0
			if w.id == "axe": progress = 0.0
			weapon_animation.seek(progress*weapon_animation.get_animation(clip).length,true)
	if axe_pivot:
		preload("res://scripts/weapon_view.gd").sample_axe(axe_pivot,clampf(1-p.fire_anim/w.fireDuration,0,1) if p.fire_anim > 0 else 0.0)
	avatar.animate(p,moving,dt)

	if skeleton and p.hp > 0 and int(p.weapon) != 6:
		var lift = .06 if p.aim else 0.0
		pose_hand("R",Vector3(.20,1.23+lift,-.28))
		if int(p.weapon) not in [2,3]:
			pose_hand("L",Vector3(.14,1.12,-.25) if p.reloading else Vector3(.20,1.25+lift,-.47))
	# The grip follows the actual animated fist, never a fixed point near the face.
	if skeleton:
		var hand = skeleton.find_bone("Fist.R")
		if hand >= 0:
			held.position = to_local(skeleton.global_transform*skeleton.get_bone_global_pose(hand).origin)
			held.position += Vector3(0,.045,.04)
	if axe_pivot and skeleton and p.hp > 0:
		held.position = Vector3(.18,1.13,.05)
		var grip = axe_pivot.to_global(Vector3(0,-.13,0))
		pose_hand("R",to_local(grip))
		var hand = skeleton.find_bone("Fist.R")
		if hand >= 0:
			var hand_position = skeleton.global_transform*skeleton.get_bone_global_pose(hand).origin
			held.global_position += hand_position-grip
	flash.global_position = muzzle_position()
	flash.visible = p.hp > 0 and not p.reloading and p.fire_anim > w.fireDuration-.05 and w.get("kind","gun") != "melee"

func muzzle_position() -> Vector3:
	return gun_model.to_global(preload("res://scripts/weapon_view.gd").muzzle_offset(Data.weapons[weapon_index])) if gun_model else global_position

func pose_hand(side: String, target: Vector3) -> void:
	var fist = skeleton.find_bone("Fist."+side)
	var upper = skeleton.find_bone("UpperArm."+side)
	var lower = skeleton.find_bone("LowerArm."+side)
	if mini(fist,mini(upper,lower)) < 0: return
	var hand_pose = skeleton.get_bone_global_pose(fist)
	var shoulder = skeleton.get_bone_global_pose(upper).origin
	var elbow = skeleton.get_bone_global_pose(lower).origin
	var goal = skeleton.to_local(to_global(target))
	var length_a = shoulder.distance_to(elbow)
	var length_b = elbow.distance_to(hand_pose.origin)
	var direction = (goal-shoulder).normalized()
	var distance = clampf(shoulder.distance_to(goal),absf(length_a-length_b)+.001,length_a+length_b-.001)
	goal = shoulder+direction*distance
	var along = (length_a*length_a-length_b*length_b+distance*distance)/(2*distance)
	var down = skeleton.global_basis.inverse()*global_basis*Vector3.DOWN
	var bend = (down-direction*down.dot(direction)).normalized()
	var desired_elbow = shoulder+direction*along+bend*sqrt(maxf(0,length_a*length_a-along*along))
	for pair in [[upper,lower,desired_elbow],[lower,fist,goal]]:
		var pose = skeleton.get_bone_global_pose(pair[0])
		var current = skeleton.get_bone_global_pose(pair[1]).origin
		pose.basis = Basis(Quaternion((current-pose.origin).normalized(),(pair[2]-pose.origin).normalized()))*pose.basis
		skeleton.set_bone_global_pose_override(pair[0],pose,1.0,true)
		skeleton.force_update_all_bone_transforms()
	hand_pose.origin = skeleton.get_bone_global_pose(fist).origin
	skeleton.set_bone_global_pose_override(fist,hand_pose,1.0,true)
	skeleton.force_update_all_bone_transforms()

func grip_position() -> Vector3:
	return axe_pivot.to_global(Vector3(0,-.13,0)) if axe_pivot else held.to_global(Vector3(0,-.045,-.04))
