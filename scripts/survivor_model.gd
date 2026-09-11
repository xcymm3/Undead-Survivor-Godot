extends Node3D
## Original block-built survivors. All dimensions are in game metres, facing -Z.
## Rigid bone attachments deliberately match the enemies' cuboid visual language.
const PROFILES = [
	{"name":"蓝衣青年","sex":"male","skin":"d6a077","shirt":"527c97","pants":"303e4a","hair":"35291f"},
	{"name":"棕衣大叔","sex":"male","skin":"bc8563","shirt":"97704e","pants":"394342","hair":"49362c"},
	{"name":"绿衣队员","sex":"male","skin":"80553f","shirt":"617255","pants":"333a32","hair":"241f1c"},
	{"name":"红衣女性","sex":"female","skin":"e0ac87","shirt":"a7544e","pants":"394557","hair":"553828"}
]
var skeleton: Skeleton3D
var clock = 0.0
var materials: Dictionary = {}

func build(index: int) -> void:
	var profile: Dictionary = PROFILES[clampi(index,0,3)]
	name = "Survivor%d" % index
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	add_child(skeleton)
	bone("Hips","",Vector3(0,.88,0))
	bone("Chest","Hips",Vector3(0,1.27,0))
	bone("Head","Chest",Vector3(0,1.58,0))
	var width = .39 if index == 3 else .47 if index == 1 else .43
	box("Hips",Vector3(0,.025,0),Vector3(width*.9,.19,.25),profile.pants)
	box("Chest",Vector3(0,-.06,0),Vector3(width,.43,.27),profile.shirt)
	box("Chest",Vector3(0,-.235,0),Vector3(width*.95,.055,.285),"302d28")
	box("Chest",Vector3(.04,-.235,-.151),Vector3(.07,.043,.018),"b6a58a")
	box("Chest",Vector3(0,.215,0),Vector3(.14,.12,.15),profile.skin)
	box("Head",Vector3(0,.08,0),Vector3(.245,.31,.235),profile.skin)
	# Jaw, ears, nose and small dark eyes distinguish people from the undead.
	box("Head",Vector3(0,-.055,-.014),Vector3(.205,.075,.205),profile.skin)
	for side in [-1,1]:
		box("Head",Vector3(side*.133,.07,0),Vector3(.036,.08,.065),profile.skin)
		box("Head",Vector3(side*.055,.098,-.12),Vector3(.043,.022,.014),"e4ded0")
		box("Head",Vector3(side*.055,.097,-.13),Vector3(.018,.021,.01),"292522")
		box("Head",Vector3(side*.055,.133,-.124),Vector3(.052,.016,.016),profile.hair)
	box("Head",Vector3(0,.04,-.135),Vector3(.043,.057,.045),profile.skin)
	box("Head",Vector3(0,-.016,-.12),Vector3(.068,.012,.012),"925e4c")
	box("Head",Vector3(0,.228,.005),Vector3(.262,.065,.255),profile.hair)
	box("Head",Vector3(0,.15,.113),Vector3(.25,.15,.04),profile.hair)
	if index == 0:
		box("Head",Vector3(-.07,.195,-.10),Vector3(.12,.08,.075),profile.hair)
	elif index == 1:
		box("Head",Vector3(0,-.052,-.103),Vector3(.19,.07,.055),profile.hair)
		box("Head",Vector3(0,.005,-.13),Vector3(.085,.022,.025),profile.hair)
	elif index == 2:
		box("Chest",Vector3(0,.02,-.151),Vector3(width*.78,.28,.06),"414f3c")
		for x in [-.10,.10]: box("Chest",Vector3(x,-.06,-.20),Vector3(.13,.105,.065),"78806a")
	else:
		box("Head",Vector3(.095,.165,-.105),Vector3(.065,.14,.055),profile.hair)
		box("Head",Vector3(0,.13,.17),Vector3(.13,.13,.11),profile.hair)
		box("Head",Vector3(0,-.015,.21),Vector3(.105,.23,.105),profile.hair)
		box("Head",Vector3(0,.10,.18),Vector3(.137,.035,.115),"be9a59")
	for side in ["R","L"]:
		var sign_x = 1 if side == "R" else -1
		bone("UpperArm."+side,"Chest",Vector3(sign_x*(width/2+.045),1.40,0))
		bone("LowerArm."+side,"UpperArm."+side,Vector3(sign_x*(width/2+.055),1.10,0))
		bone("Fist."+side,"LowerArm."+side,Vector3(sign_x*(width/2+.055),.82,0))
		box("UpperArm."+side,Vector3(0,-.14,0),Vector3(.14,.30,.17),profile.shirt)
		box("LowerArm."+side,Vector3(0,-.13,0),Vector3(.105,.28,.12),profile.skin)
		box("Fist."+side,Vector3(0,-.025,0),Vector3(.095,.105,.10),profile.skin)
		bone("Thigh."+side,"Hips",Vector3(sign_x*.115,.84,0))
		bone("Shin."+side,"Thigh."+side,Vector3(sign_x*.115,.47,0))
		bone("Foot."+side,"Shin."+side,Vector3(sign_x*.115,.10,0))
		box("Thigh."+side,Vector3(0,-.17,0),Vector3(.17,.40,.225),profile.pants)
		box("Shin."+side,Vector3(0,-.17,0),Vector3(.145,.38,.185),profile.pants)
		box("Foot."+side,Vector3(0,-.035,-.052),Vector3(.18,.13,.30),"302d2a")
	skeleton.reset_bone_poses()
	skeleton.force_update_all_bone_transforms()

func bone(title: String, parent: String, position: Vector3) -> void:
	var index = skeleton.get_bone_count()
	skeleton.add_bone(title)
	var origin = position
	if not parent.is_empty():
		var parent_index = skeleton.find_bone(parent)
		skeleton.set_bone_parent(index,parent_index)
		origin -= skeleton.get_bone_global_rest(parent_index).origin
	skeleton.set_bone_rest(index,Transform3D(Basis.IDENTITY,origin))

func box(parent: String, offset: Vector3, size: Vector3, color: String) -> void:
	var attachment = BoneAttachment3D.new()
	attachment.bone_name = parent
	skeleton.add_child(attachment)
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = offset
	if not materials.has(color):
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(color)
		material.roughness = .92
		materials[color] = material
	mesh.material_override = materials[color]
	attachment.add_child(mesh)

func animate(p: Dictionary, moving: bool, dt: float) -> void:
	clock += dt
	skeleton.reset_bone_poses()
	rotation.x = -PI/2 if p.hp <= 0 else 0.0
	position.y = .14 if p.hp <= 0 else 0.0
	var stride = sin(clock*9)*.55 if moving else 0.0
	for side in ["R","L"]:
		var swing = stride*(1 if side == "R" else -1)
		skeleton.set_bone_pose_rotation(skeleton.find_bone("Thigh."+side),Quaternion(Vector3.RIGHT,swing if p.height <= .06 else -.35))
		skeleton.set_bone_pose_rotation(skeleton.find_bone("Shin."+side),Quaternion(Vector3.RIGHT,maxf(0,-swing)*.8 if p.height <= .06 else .7))
	skeleton.force_update_all_bone_transforms()
