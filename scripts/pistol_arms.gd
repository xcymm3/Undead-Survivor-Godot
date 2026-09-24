extends Node3D
## Original first-person arms for the pistol. Coordinates are relative to its model.
## Both arms follow the weapon, while the support hand has its own reload pose.

const PROFILES = preload("res://scripts/survivor_model.gd").PROFILES

var right_upper: MeshInstance3D
var right_lower: MeshInstance3D
var right_cuff: MeshInstance3D
var right_hand: Node3D
var left_upper: MeshInstance3D
var left_lower: MeshInstance3D
var left_cuff: MeshInstance3D
var left_hand: Node3D
var spare_magazine: MeshInstance3D
var materials: Dictionary = {}

func _ready() -> void:
	right_upper = box(self, Vector3(.077,.18,.080), "shirt")
	right_lower = box(self, Vector3(.058,.18,.064), "skin")
	right_cuff = box(self, Vector3(.071,.035,.075), "shirt")
	left_upper = box(self, Vector3(.077,.18,.080), "shirt")
	left_lower = box(self, Vector3(.058,.18,.064), "skin")
	left_cuff = box(self, Vector3(.071,.035,.075), "shirt")
	right_hand = hand(1)
	left_hand = hand(-1)
	spare_magazine = box(left_hand, Vector3(.045,.09,.045), "metal")
	spare_magazine.position = Vector3(0,-.075,-.025)
	set_profile(0)
	pose(0.0,0.0,false,0.0,0.0)

func box(parent: Node3D, size: Vector3, tone: String) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	mesh.name = tone.capitalize()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.set_meta("tone",tone)
	mesh.layers = 2
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh

func hand(side: int) -> Node3D:
	var root = Node3D.new()
	root.name = "RightHand" if side == 1 else "LeftHand"
	add_child(root)
	var palm = box(root,Vector3(.062,.062,.059),"skin")
	palm.position = Vector3.ZERO
	for i in 4:
		var finger = box(root,Vector3(.014,.046,.019),"skin")
		finger.position = Vector3((i-1.5)*.014,-.043,-.014)
	var thumb = box(root,Vector3(.019,.048,.023),"skin")
	thumb.position = Vector3(-side*.035,-.005,-.008)
	thumb.rotation.z = side*.55
	return root

func set_profile(index: int) -> void:
	var profile: Dictionary = PROFILES[clampi(index,0,PROFILES.size()-1)]
	for mesh in find_children("*","MeshInstance3D",true,false):
		var tone: String = mesh.get_meta("tone","")
		var color: String = profile.get(tone,"252a2b")
		if not materials.has(color):
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(color)
			material.roughness = .9
			materials[color] = material
		mesh.material_override = materials[color]

func segment(mesh: MeshInstance3D, start: Vector3, end: Vector3, width: float) -> void:
	var delta = end-start
	mesh.position = (start+end)*.5
	mesh.quaternion = Quaternion(Vector3.UP,delta.normalized())
	mesh.scale = Vector3(width,delta.length()/.18,width)

func pose(elapsed: float, aim: float, reloading: bool, reload_phase: float, fire_phase: float) -> void:
	var breathe = sin(elapsed*1.6)*.003
	var right_wrist = Vector3(.039,-.073,.067)
	var right_elbow = Vector3(.115,-.12,.15)
	var right_shoulder = Vector3(.18,-.29,.24)
	var left_wrist = Vector3(-.052,-.043,-.045)
	var left_elbow = Vector3(-.13,-.12,.12)
	var left_shoulder = Vector3(-.19,-.29,.24)
	# The support hand holds the forward underside while aiming. During reload it
	# reaches the magazine well, withdraws the magazine, and returns to its grip.
	if reloading:
		var reach = smoothstep(.08,.27,reload_phase)*(1.0-smoothstep(.70,.91,reload_phase))
		var pull = smoothstep(.28,.47,reload_phase)*(1.0-smoothstep(.53,.72,reload_phase))
		left_wrist = left_wrist.lerp(Vector3(-.047,-.135,.07),reach)
		left_wrist += Vector3(-.12,.035,-.02)*pull
		left_elbow = left_elbow.lerp(Vector3(-.18,-.16,.16),reach)
		spare_magazine.visible = reload_phase > .32 and reload_phase < .68
	else:
		spare_magazine.visible = false
	var kick = sin(clampf(fire_phase,0,1)*PI)
	right_wrist += Vector3(0,.008,.018)*kick
	right_elbow += Vector3(0,.015,.018)*kick
	left_wrist += Vector3(0,.004,.008)*kick
	left_elbow += Vector3(0,.009,.01)*kick
	left_wrist.y += breathe
	right_wrist.y += breathe
	right_hand.position = right_wrist
	right_hand.rotation = Vector3(-.12,0,-.12)
	left_hand.position = left_wrist
	left_hand.rotation = Vector3(-.35,-.25,.30)
	if reloading: left_hand.rotation.z += sin(reload_phase*PI)*.45
	segment(right_upper,right_shoulder,right_elbow,1.0)
	segment(right_lower,right_elbow,right_wrist,1.0)
	segment(right_cuff,right_elbow.lerp(right_wrist,.72),right_elbow.lerp(right_wrist,.82),1.0)
	segment(left_upper,left_shoulder,left_elbow,1.0)
	segment(left_lower,left_elbow,left_wrist,1.0)
	segment(left_cuff,left_elbow.lerp(left_wrist,.72),left_elbow.lerp(left_wrist,.82),1.0)
