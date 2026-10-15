extends Node3D
const EquipMotion = preload("res://scripts/equip_motion.gd")
var models: Array[Node3D] = []
var animations: Array = []
var sights: Array[Node3D] = []
var ads = 0.0
var sprint_blend = 0.0
var sprint_phase = 0.0
var active = 0
var muzzle: MeshInstance3D
var scabbard: Node3D
var blade: Node3D
var axe_pivot: Node3D
var blade_motion = preload("res://scripts/blade_motion.gd").new()
var blade_right_arm: MeshInstance3D
var blade_left_arm: MeshInstance3D
var blade_left_hand: Node3D

static func create_model(id: String, first_person := false) -> Node3D:
	return preload("res://scripts/weapon_models.gd").create(id,first_person)

func _ready() -> void:
	scale = Vector3.ONE*.5
	for definition in Data.weapons:
		var model: Node3D = create_model(definition.id,true)
		add_child(model)
		var first_person_scale: float = {"p90":1.55,"pistol":1.55,"revolver":1.25,"heavy-machine-gun":1.12}.get(definition.id,1.0)
		model.scale = Vector3.ONE*first_person_scale
		if definition.id == "heavy-machine-gun": model.position.y = -.04
		model.visible = false
		models.append(model)
		animations.append(find_animation(model))
		var sight: Node3D = model.find_child("TopIronSight",true,false)
		if not sight:
			sight = Node3D.new()
			model.add_child(sight)
		sight.visible = false
		sights.append(sight)
		if definition.id == "axe":
			var head = model.find_child("FireAxeHead",true,false)
			if head: axe_pivot = head.get_parent() as Node3D
		for child in model.find_children("*","MeshInstance3D",true,false):
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			child.layers = 2
	blade = preload("res://scripts/long_blade.gd").new()
	add_child(blade)
	blade.hide()
	scabbard = preload("res://scripts/long_blade.gd").make_scabbard()
	add_child(scabbard)
	scabbard.hide()
	blade_left_hand = preload("res://scripts/long_blade.gd").make_hand(false)
	add_child(blade_left_hand)
	blade_right_arm = preload("res://scripts/long_blade.gd").make_arm()
	blade_left_arm = preload("res://scripts/long_blade.gd").make_arm()
	add_child(blade_right_arm)
	add_child(blade_left_arm)
	blade_left_hand.hide()
	blade_right_arm.hide()
	blade_left_arm.hide()
	var sphere = SphereMesh.new()
	sphere.radius = .025
	sphere.height = .06
	muzzle = MeshInstance3D.new()
	muzzle.mesh = sphere
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1,.73,.27)
	muzzle.material_override = material
	muzzle.layers = 2
	muzzle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(muzzle)
	muzzle.visible = false

func find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found = find_animation(child)
		if found: return found
	return null

func reset_motion() -> void:
	ads = 0.0
	sprint_blend = 0.0
	sprint_phase = 0.0
	blade_motion.reset()
	if models.size() > 3: models[3].reset_motion()

func sync(p: Dictionary, dt: float, elapsed: float, aim_target := Vector3(0,0,-180)) -> void:
	active = int(p.weapon)
	var ultimate = preload("res://scripts/ultimate.gd")
	var ultimate_locked: bool = ultimate.locked(p)
	var w: Dictionary = ultimate.weapon(p,Progress.store,Data.weapons[active])
	var sprinting: bool = p.get("sprinting",false)
	ads = move_toward(ads,1.0 if p.aim and not sprinting else 0.0,dt*7)
	sprint_blend = move_toward(sprint_blend,1.0 if sprinting else 0.0,dt*9)
	sprint_phase += dt*12.0
	var hide_scope: bool = w.id == "sniper" and ads > .8
	for i in models.size(): models[i].visible = i == active and not ultimate_locked and not hide_scope and p.get("pickup_remaining",0.0) <= .08
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
	var equip_phase = -1.0
	if p.switch > 0 and p.get("pickup_remaining",0.0) <= 0:
		var total: float = float(p.get("switch_duration",.4))
		var phase = clampf(1-p.switch/total,0,1)
		if p.weapon != p.requested:
			position.y -= smoothstep(0,.25,phase)*.35
		else:
			equip_phase = EquipMotion.phase(p.switch,total)
			var lift = sin(PI*equip_phase)
			if w.id == "rifle":
				position += Vector3(-.08,-.12,-.30)*lift
				rotation.x += .95*lift
			elif w.id == "pistol":
				position += Vector3(-.09,-.09,-.35)*lift
				rotation.x += EquipMotion.spin_angle(equip_phase)
			else: position.y -= lift*.5
	models[active].rotation = Vector3.ZERO
	if p.reloading and w.id != "revolver":
		var reload_pulse = sin(clampf(1-p.reload/maxf(.1,w.reloadDuration),0,1)*PI)
		models[active].rotation.z = -reload_pulse*.22
		models[active].rotation.x = -reload_pulse*.1
	var reload_phase = clampf(1-p.get("reload",0.0)/maxf(.1,w.reloadDuration),0,1) if p.reloading else 0.0
	if w.id == "rifle":
		models[active].pose(p.reloading,reload_phase,p.fire_anim/w.fireDuration)
		models[active].rack_hand.visible = equip_phase >= EquipMotion.BOLT_START and equip_phase <= EquipMotion.BOLT_END
		if equip_phase >= 0:
			models[active].bolt.position.z += EquipMotion.bolt_offset(equip_phase)
			models[active].rack_hand.position.z = models[active].bolt.position.z
			rotation.z -= .4*sin(PI*equip_phase)
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
		sample_axe(axe_pivot,clampf(1-p.fire_anim/w.fireDuration,0,1) if p.fire_anim > 0 else 0.0,int(p.get("axe_direction",1)))
	if w.id == "revolver": models[3].sync_pose(p,dt,elapsed,ads)
	if p.fire_anim > 0 and w.get("kind","gun") != "melee" and w.id != "revolver":
		var pulse = sin((1-p.fire_anim/w.fireDuration)*PI)
		position.z += pulse*.035*w.recoil
		rotation.x += pulse*.025*w.recoil
	if p.get("shove_anim",0.0) > 0:
		var push = sin((1-p.shove_anim/.32)*PI)
		position.z -= push*.22
		rotation.x += push*.2
		if w.id == "axe":
			position.x -= push*.13
			rotation.z -= push*.55
			position.z -= push*.12
	# Carry the gun low and across the body; hands follow their shared weapon root.
	# The two-foot rhythm adds vertical bounce and a slower lateral sway.
	if sprint_blend > 0 and not ultimate_locked:
		var bob = Vector3(sin(sprint_phase)*.018,absf(cos(sprint_phase))*.022,sin(sprint_phase*2)*.009)
		position += (Vector3(.045,-.13,.08)+bob)*sprint_blend
		quaternion *= Quaternion.from_euler(Vector3(-.38,.42,-.24+sin(sprint_phase)*.04)*sprint_blend)
	scabbard.visible = ultimate_locked
	blade.visible = ultimate_locked
	blade_right_arm.visible = ultimate_locked
	blade_left_hand.visible = false
	blade_left_arm.visible = false
	if ultimate_locked:
		var motion = blade_motion.sample(p,dt,w.fireDuration)
		var inverse = transform.affine_inverse()
		blade.transform = inverse*motion.blade
		scabbard.transform = inverse*motion.sheath
		var wrist: Vector3 = motion.blade*Vector3(0,-.24,0)
		pose_blade_arm(blade_right_arm,Vector3(.48,-.58,-.48),wrist,inverse)
		if motion.support > .001:
			blade_left_hand.visible = true
			blade_left_arm.visible = true
			var hand: Transform3D = motion.sheath
			hand.origin += Vector3(-.23,-.26,.14)*(1.0-motion.support)
			blade_left_hand.transform = inverse*hand
			pose_blade_arm(blade_left_arm,Vector3(-.30,-.62,-.52),hand*Vector3(0,-.18,0),inverse)
	else:
		blade_motion.reset()
	muzzle.global_position = muzzle_position()
	muzzle.visible = not hide_scope and p.hp > 0 and not p.reloading and p.fire_anim > w.fireDuration-.035 and w.get("kind","gun") == "gun"

static func pose_blade_arm(arm: MeshInstance3D, elbow: Vector3, wrist: Vector3, inverse: Transform3D) -> void:
	var direction = wrist-elbow
	# Scale along the arm's local axis; world-axis scaling shears its wrist endpoint.
	var pose = Transform3D(Basis.looking_at(direction.normalized())*Basis.from_scale(Vector3(.105,.105,direction.length())),(elbow+wrist)*.5)
	arm.transform = inverse*pose

static func sample_axe(pivot: Node3D, progress: float, direction := 1) -> void:
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
	if direction == -1:
		# Reverse the stroke while returning both hands to the same resting pose.
		for index in range(1,positions.size()-1):
			positions[index].x *= -1
			angles[index].y *= -1
			angles[index].z *= -1
	for i in range(times.size()-1):
		if progress > times[i+1]: continue
		var weight = smoothstep(times[i],times[i+1],progress)
		pivot.position = positions[i].lerp(positions[i+1],weight)
		pivot.quaternion = Quaternion.from_euler(angles[i]).slerp(Quaternion.from_euler(angles[i+1]),weight)
		return

static func muzzle_offset(w: Dictionary) -> Vector3:
	match w.id:
		"rifle": return preload("res://scripts/ak_rifle.gd").MUZZLE
		"revolver": return preload("res://scripts/revolver_model.gd").MUZZLE
		"flamethrower": return Vector3(.04,.03,-1.01)
		"auto-shotgun": return Vector3(.05,.04,-1.09)*.72
		"heavy-machine-gun": return Vector3(.04,.04,-1.17)
	return Vector3(0,0,-w.length*.72)

func muzzle_position() -> Vector3:
	if active == 3: return models[3].gun.to_global(preload("res://scripts/revolver_view.gd").MUZZLE)
	return models[active].to_global(muzzle_offset(Data.weapons[active]))
