extends Node3D
## Camera-space cuboid arms. Fists follow weapon grips throughout ADS and recoil.
var right: Node3D
var left: Node3D
var forearms: Array[MeshInstance3D] = []
var sleeves: Array[MeshInstance3D] = []
var skin = StandardMaterial3D.new()
var cloth = StandardMaterial3D.new()
var profile_index = -1

func _ready() -> void:
	name = "BlockArms"
	skin.roughness = .95
	cloth.roughness = .95
	for side in [1,-1]:
		var hand = Node3D.new()
		hand.name = "RightHand" if side == 1 else "LeftHand"
		add_child(hand)
		piece(hand,Vector3(.16,.15,.18),Vector3.ZERO,skin)
		piece(hand,Vector3(.055,.09,.13),Vector3(-side*.09,.018,-.012),skin)
		forearms.append(piece(self,Vector3(.135,1,.15),Vector3.ZERO,skin))
		sleeves.append(piece(self,Vector3(.19,1,.21),Vector3.ZERO,cloth))
		if side == 1: right = hand
		else: left = hand

func piece(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = at
	node.material_override = material
	node.layers = 2
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func segment(node: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	node.position = (start+end)/2
	node.quaternion = Quaternion(Vector3.UP,(end-start).normalized())
	node.scale.y = start.distance_to(end)

func sync(p: Dictionary, w: Dictionary, reload_phase: float, axe: Node3D) -> void:
	var index = int(p.get("appearance",[0])[0])
	if profile_index != index:
		profile_index = index
		var profile: Dictionary = preload("res://scripts/survivor_model.gd").PROFILES[clampi(index,0,3)]
		skin.albedo_color = Color(profile.skin)
		cloth.albedo_color = Color(profile.shirt)
	var r = Vector3(.025,-.12,.015)
	var l = Vector3(-.055,-.09,-w.length*.40)
	if w.id == "rifle":
		r = preload("res://scripts/ak_rifle.gd").RIGHT_GRIP
		l = preload("res://scripts/ak_rifle.gd").LEFT_GRIP
	elif w.id in ["pistol","revolver"]:
		l = r+Vector3(-.11,-.025,-.035)
	elif w.id == "flamethrower":
		r = Vector3(.05,-.23,-.20)
		l = Vector3(.04,-.03,-.68)
	elif w.id == "auto-shotgun":
		r = Vector3(.036,-.16,-.014)
		l = Vector3(.036,-.08,-.43)
	elif w.id == "heavy-machine-gun":
		r = Vector3(.21,-.27,-.09)
		l = Vector3(-.14,-.11,-.70)
	if p.reloading:
		var reach = sin(reload_phase*PI)
		l = l.lerp(Vector3(-.12,-.41,-.22),reach)
		if w.id == "rifle": l = l.lerp(Vector3(-.08,-.20-.30*reach,-.25),reach)
	if w.id == "axe" and axe:
		r = to_local(axe.to_global(Vector3(0,-.13,0)))
		l = to_local(axe.to_global(Vector3(0,-.34,0)))
	right.position = r
	left.position = l
	right.rotation = Vector3(-.25,0,.08)
	left.rotation = Vector3(.15,0,-.18)
	for i in 2:
		var hand = r if i == 0 else l
		var shoulder = Vector3(.72,-.62,.66) if i == 0 else Vector3(-1.02,-.66,.55)
		var elbow = shoulder.lerp(hand,.52)+Vector3(0,-.10,.03)
		segment(sleeves[i],shoulder,elbow)
		segment(forearms[i],elbow,hand+Vector3(0,-.035,.065))
