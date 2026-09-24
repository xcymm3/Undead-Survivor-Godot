extends Node3D
var models: Array[Node3D] = []
var animations: Array = []
var sights: Array[Node3D] = []
var ads = 0.0
var active = 0
var muzzle: MeshInstance3D
var axe_pivot: Node3D
var pistol_arms: Node3D
var pistol_profile = -1

static func create_model(id: String) -> Node3D:
	if id == "rifle": return preload("res://scripts/ak_rifle.gd").new()
	return load("res://assets/models/%s.glb" % id).instantiate()

func create_iron_sight(id: String, model: Node3D) -> Node3D:
	if id not in ["p90","pistol","heavy-machine-gun"]:
		var empty = Node3D.new()
		model.add_child(empty)
		return empty
	var sight = preload("res://scripts/iron_sight.gd").new(id)
	if id == "heavy-machine-gun":
		# Replace only the original two sight blocks; receiver/barrel/animation stay intact.
		var rear = model.find_child("RearSight",true,false)
		var front = model.find_child("FrontSight",true,false)
		rear.visible = false
		front.visible = false
		rear.get_parent().add_child(sight)
	else:
		# Follow the imported slide/control bone instead of floating over the weapon.
		var skeleton: Skeleton3D = model.find_children("*","Skeleton3D",true,false)[0]
		var bone_name = "Slide" if id == "pistol" else "Control"
		var bone = skeleton.find_bone(bone_name)
		var attachment = BoneAttachment3D.new()
		attachment.name = "SightAttachment"
		attachment.bone_name = bone_name
		skeleton.add_child(attachment)
		attachment.add_child(sight)
		var bone_in_model = model.global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_rest(bone)
		sight.transform = bone_in_model.affine_inverse()
	return sight

func _ready() -> void:
	scale = Vector3.ONE*.5
	for definition in Data.weapons:
		var model: Node3D = preload("res://scripts/revolver_view.gd").new() if definition.id == "revolver" else create_model(definition.id)
		add_child(model)
		var first_person_scale: float = {"p90":1.55,"pistol":1.55,"revolver":1.25,"heavy-machine-gun":1.12}.get(definition.id,1.0)
		model.scale = Vector3.ONE*first_person_scale
		if definition.id == "heavy-machine-gun": model.position.y = -.04
		model.visible = false
		models.append(model)
		animations.append(find_animation(model))
		var sight := create_iron_sight(definition.id,model)
		sight.visible = false
		sights.append(sight)
		if definition.id == "axe":
			var head = model.find_child("FireAxeHead",true,false)
			if head: axe_pivot = head.get_parent() as Node3D
		for child in model.find_children("*","MeshInstance3D",true,false):
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			child.layers = 2
	pistol_arms = preload("res://scripts/pistol_arms.gd").new()
	models[2].add_child(pistol_arms)
	pistol_arms.visible = false
	var sphere = SphereMesh.new()
	sphere.radius = .032
	sphere.height = .08
	muzzle = MeshInstance3D.new()
	muzzle.mesh = sphere
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1,.73,.27)
	muzzle.material_override = material
	muzzle.layers = 2
	add_child(muzzle)
	muzzle.visible = false

func find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found = find_animation(child)
		if found: return found
	return null

func sync(p: Dictionary, dt: float, elapsed: float, aim_target := Vector3(0,0,-180)) -> void:
	active = int(p.weapon)
	var w: Dictionary = Data.weapons[active]
	ads = move_toward(ads,1.0 if p.aim else 0.0,dt*7)
	var hide_scope: bool = w.id == "sniper" and ads > .8
	for i in models.size(): models[i].visible = i == active and not hide_scope and p.get("pickup_remaining",0.0) <= .08
	for i in sights.size(): sights[i].visible = i == active and p.get("pickup_remaining",0.0) <= .08
	if active != 3: models[3].reset_motion()
	var hip = Vector3(.19,-.085 if w.length < .6 else -.10,-.46)
	if w.id == "rifle": hip = Vector3(.22,-.10,-.50)
	if w.id == "revolver": hip = Vector3(.18,-.10,-.58)
	if w.id == "heavy-machine-gun": hip = Vector3(.16,-.095,-.74)
	var aim = Data.v3(w.ads)
	if w.id == "rifle": aim = Vector3(0,-.103,-.48)
	if w.id == "revolver": aim = Vector3(0,-.115,-.58)
	# The bulky procedural receivers need clearance below the center sight line.
	if w.id in ["auto-shotgun","heavy-machine-gun"]: aim = Vector3(0,-.20,-.62)
	if w.id == "heavy-machine-gun": aim = Vector3(0,-.10,-.80)
	# Only the ADS eye line changes; hip placement, scale and all original animations remain.
	if w.id in ["p90","pistol","heavy-machine-gun"]:
		var line: Vector3 = models[active].position+sights[active].line*models[active].scale
		aim.x = -line.x*scale.x
		aim.y = -line.y*scale.y
	if w.id == "revolver": aim.y = -.2095*models[active].scale.y*scale.y
	if w.get("kind", "gun") == "flame": aim = hip
	position = hip.lerp(aim,ads)
	if w.id != "revolver": position.y += sin(elapsed*1.6)*.003
	var visual_target = aim_target.normalized()*maxf(6,aim_target.length())
	quaternion = Quaternion(Vector3.FORWARD,(visual_target-position).normalized())
	if w.id in ["p90","pistol","revolver","heavy-machine-gun"]: quaternion = quaternion.slerp(Quaternion.IDENTITY,ads)
	if p.switch > 0 and p.get("pickup_remaining",0.0) <= 0: position.y -= sin(clampf(1-p.switch/.4,0,1)*PI)*.5
	if p.reloading and w.id != "revolver":
		var reload_pulse = sin(clampf(1-p.reload/maxf(.1,w.reloadDuration),0,1)*PI)
		position.y -= reload_pulse*.07
		rotation.z -= reload_pulse*.22
		rotation.x -= reload_pulse*.1
	var reload_phase = clampf(1-p.get("reload",0.0)/maxf(.1,w.reloadDuration),0,1) if p.reloading else 0.0
	pistol_arms.visible = active == 2 and models[2].visible
	if active == 2:
		var profile: int = int(p.get("appearance",[0])[0])
		if profile != pistol_profile:
			pistol_arms.set_profile(profile)
			pistol_profile = profile
		pistol_arms.pose(elapsed,ads,p.reloading,reload_phase,clampf(1-p.fire_anim/w.fireDuration,0,1) if p.fire_anim > 0 else 0.0)
	if w.id == "rifle": models[active].pose(p.reloading,reload_phase,p.fire_anim/w.fireDuration)
	var player: AnimationPlayer = animations[active]
	if player:
		var clip = ""
		var progress = 0.0
		if p.reloading:
			clip = "reload"
			progress = clampf(1-p.reload/maxf(.1,w.reloadDuration),0,1)
		elif p.fire_anim > 0:
			clip = "fire"
			progress = clampf(1-p.fire_anim/w.fireDuration,0,1)
		else:
			clip = "fire"
			progress = 0
		if player.has_animation(clip):
			if player.current_animation != clip: player.play(clip)
			player.pause()
			# The imported axe clip swings in the screen plane; replace its pose below.
			if w.id == "axe": progress = 0.0
			player.seek(progress*player.get_animation(clip).length,true)
	if w.id == "axe" and axe_pivot:
		sample_axe(axe_pivot,clampf(1-p.fire_anim/w.fireDuration,0,1) if p.fire_anim > 0 else 0.0)
	if w.id == "revolver": models[3].sync_pose(p,dt,elapsed,ads)
	if p.fire_anim > 0 and w.get("kind","gun") != "melee" and w.id != "revolver":
		var pulse = sin((1-p.fire_anim/w.fireDuration)*PI)
		position.z += pulse*.035*w.recoil
		rotation.x += pulse*.025*w.recoil
	if p.get("shove_anim",0.0) > 0:
		var push = sin((1-p.shove_anim/.32)*PI)
		position.z -= push*.22
		rotation.x += push*.2
	muzzle.global_position = muzzle_position()
	muzzle.visible = not hide_scope and p.fire_anim > w.fireDuration-.035 and w.get("kind","gun") not in ["melee","flame"]
	muzzle.scale = Vector3.ONE*(2.3 if w.get("kind") == "flame" else 1.0)

static func sample_axe(pivot: Node3D, progress: float) -> void:
	# Sweep the grip and head together from upper right toward lower left and forward.
	# Modest pitch keeps the handle upright instead of folding the head onto the right.
	var times = [0.0,.22,.52,.66,.82,1.0]
	var positions = [
		Vector3(.08,-.10,-.46), Vector3(.18,.02,-.24),
		Vector3(-.50,-.20,-.60), Vector3(-.82,-.37,-.75),
		Vector3(-.24,-.30,-.57), Vector3(.08,-.10,-.46)]
	var angles = [
		Vector3(-.12,-.65,-.24), Vector3(.50,-1.05,-.12),
		Vector3(-.30,-.90,.38), Vector3(-.48,-.80,.50),
		Vector3(-.25,-.70,.12), Vector3(-.12,-.65,-.24)]
	for i in range(times.size()-1):
		if progress > times[i+1]: continue
		var weight = smoothstep(times[i],times[i+1],progress)
		pivot.position = positions[i].lerp(positions[i+1],weight)
		pivot.quaternion = Quaternion.from_euler(angles[i]).slerp(Quaternion.from_euler(angles[i+1]),weight)
		return

static func muzzle_offset(w: Dictionary) -> Vector3:
	match w.id:
		"rifle": return preload("res://scripts/ak_rifle.gd").MUZZLE
		"flamethrower": return Vector3(.04,.03,-1.01)
		"auto-shotgun": return Vector3(.05,.04,-1.09)*.72
		"heavy-machine-gun": return Vector3(.04,.04,-1.17)
	return Vector3(0,0,-w.length*.72)

func muzzle_position() -> Vector3:
	if active == 3: return models[3].gun.to_global(preload("res://scripts/revolver_view.gd").MUZZLE)
	return models[active].to_global(muzzle_offset(Data.weapons[active]))
