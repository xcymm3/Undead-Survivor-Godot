extends Node3D
var models: Array[Node3D] = []
var animations: Array = []
var ads = 0.0
var active = 0
var muzzle: MeshInstance3D
var axe_pivot: Node3D

func _ready() -> void:
	scale = Vector3.ONE*.5
	for definition in Data.weapons:
		var scene: PackedScene = load("res://assets/models/%s.glb" % definition.id)
		var model: Node3D = scene.instantiate()
		add_child(model)
		model.visible = false
		models.append(model)
		animations.append(find_animation(model))
		if definition.id == "axe":
			var head = model.find_child("FireAxeHead",true,false)
			if head: axe_pivot = head.get_parent() as Node3D
		for child in model.find_children("*","MeshInstance3D",true,false):
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			child.layers = 2
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
	for i in models.size(): models[i].visible = i == active and not hide_scope
	var hip = Vector3(.19,-.16 if w.length < .6 else -.2,-.38)
	var aim = Data.v3(w.ads)
	position = hip.lerp(aim,ads)
	position.y += sin(elapsed*1.6)*.003
	var visual_target = aim_target.normalized()*maxf(6,aim_target.length())
	quaternion = Quaternion(Vector3.FORWARD,(visual_target-position).normalized())
	if p.switch > 0: position.y -= sin((1-p.switch/.4)*PI)*.5
	if p.reloading:
		var reload_pulse = sin(clampf(1-p.reload/maxf(.1,w.reloadDuration),0,1)*PI)
		position.y -= reload_pulse*.07
		rotation.z -= reload_pulse*.22
		rotation.x -= reload_pulse*.1
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
	if p.fire_anim > 0 and w.get("kind","gun") != "melee":
		var pulse = sin((1-p.fire_anim/w.fireDuration)*PI)
		position.z += pulse*.035*w.recoil
		rotation.x += pulse*.025*w.recoil
	muzzle.position = Vector3(0,0,-w.length*.72)
	muzzle.visible = not hide_scope and p.fire_anim > w.fireDuration-.035 and w.get("kind","gun") != "melee"
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
