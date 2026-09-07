extends Node3D
var avatar: Node3D
var animation: AnimationPlayer
var previous_position = Vector3.ZERO
var label: Label3D
var held: Node3D
var weapon_index = -1
var weapon_animation: AnimationPlayer
var axe_pivot: Node3D

func setup(p: Dictionary) -> void:
	var appearance: Array = p.appearance
	var model_name: String = Data.MODELS[clampi(int(appearance[0]),0,5)]
	avatar = load("res://assets/models/characters/%s.gltf" % model_name).instantiate()
	add_child(avatar)
	# Preserve the original character scale and material assignments.
	avatar.scale = Vector3.ONE*.61
	for mesh in avatar.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(surface)
			if not material is StandardMaterial3D: continue
			var copy: StandardMaterial3D = material.duplicate()
			copy.roughness = .82
			copy.metallic = .02
			var mat_name = material.resource_name.to_lower()
			var primary: Array = [["main","helmet"],["main"],["shirt"],["shirt"],["vest","hat"],["vest","hat"]][clampi(int(appearance[0]),0,5)]
			var accent: Array = [["darkgreen"],["darkgreen","hair"],["pants","belt"],["pants","belt"],["shirt","pants"],["shirt","pants"]][clampi(int(appearance[0]),0,5)]
			if mat_name in primary: copy.albedo_color = Data.rgb(Data.PALETTE[clampi(int(appearance[1]),0,5)])
			elif mat_name in accent: copy.albedo_color = Data.rgb(Data.PALETTE[clampi(int(appearance[2]),0,5)])
			mesh.set_surface_override_material(surface,copy)
	var finder = preload("res://scripts/weapon_view.gd").new()
	animation = finder.find_animation(avatar)
	finder.free()
	label = Label3D.new()
	label.font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	label.text = p.name
	label.font_size = 36
	label.pixel_size = .008
	label.position.y = 2.2
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("eadfc6")
	add_child(label)
	avatar.rotation.y = PI
	held = Node3D.new()
	held.position = Vector3(.22,1.42,-.48)
	add_child(held)
	position = Vector3(p.pos.x,p.height,p.pos.y)
	update_weapon(p.weapon)

func update_weapon(index: int) -> void:
	if weapon_index == index: return
	weapon_index = index
	axe_pivot = null
	for node in held.get_children():
		held.remove_child(node)
		node.queue_free()
	var model = load("res://assets/models/%s.glb" % Data.weapons[index].id).instantiate() as Node3D
	model.scale = Vector3.ONE*.5
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
	if animation:
		var action = "Death" if p.hp <= 0 else "PickUp" if p.reloading else "Shoot_OneHanded" if p.fire_anim > w.fireDuration-.08 else "Jump" if p.height > .06 else "Run_Carry" if moving else "Idle"
		for clip in animation.get_animation_list():
			if clip.to_lower() == action.to_lower() or clip.to_lower().ends_with("/"+action.to_lower()):
				if animation.current_animation != clip:
					animation.get_animation(clip).loop_mode = Animation.LOOP_NONE if action in ["Death","Jump","Shoot_OneHanded","PickUp"] else Animation.LOOP_LINEAR
					animation.play(clip,.12)
				if p.reloading:
					animation.pause()
					animation.seek(clampf(1-p.reload/maxf(.1,w.reloadDuration),0,1)*animation.get_animation(clip).length,true)
				return
