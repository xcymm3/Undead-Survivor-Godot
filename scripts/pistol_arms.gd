extends Node3D
## Two rigid square-section arms. Each arm is one continuous box from the
## camera edge to the pistol; the material paints a sleeve on the near end.

const PROFILES = preload("res://scripts/survivor_model.gd").PROFILES
const ARM_WIDTH = .065

var right_arm: MeshInstance3D
var left_arm: MeshInstance3D
var spare_magazine: MeshInstance3D
var arm_material: ShaderMaterial

func _ready() -> void:
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
uniform vec4 skin_color : source_color;
uniform vec4 sleeve_color : source_color;
varying float arm_height;
void vertex() {
	arm_height = VERTEX.y;
}
void fragment() {
	ALBEDO = mix(sleeve_color.rgb, skin_color.rgb, step(0.02, arm_height));
	ROUGHNESS = 0.9;
}
"""
	arm_material = ShaderMaterial.new()
	arm_material.shader = shader
	right_arm = make_arm("RightArm")
	left_arm = make_arm("LeftArm")
	spare_magazine = MeshInstance3D.new()
	spare_magazine.name = "SpareMagazine"
	var magazine_shape = BoxMesh.new()
	magazine_shape.size = Vector3(.04,.11,.035)
	spare_magazine.mesh = magazine_shape
	var magazine_material = StandardMaterial3D.new()
	magazine_material.albedo_color = Color("303532")
	magazine_material.roughness = .8
	spare_magazine.material_override = magazine_material
	spare_magazine.layers = 2
	spare_magazine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spare_magazine)
	set_profile(0)
	pose(0.0,0.0,false,0.0,0.0)

func make_arm(title: String) -> MeshInstance3D:
	var arm = MeshInstance3D.new()
	arm.name = title
	var shape = BoxMesh.new()
	shape.size = Vector3(ARM_WIDTH,1.0,ARM_WIDTH)
	arm.mesh = shape
	arm.material_override = arm_material
	arm.layers = 2
	arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arm)
	return arm

func set_profile(index: int) -> void:
	var profile: Dictionary = PROFILES[clampi(index,0,PROFILES.size()-1)]
	arm_material.set_shader_parameter("skin_color",Color(profile.skin))
	arm_material.set_shader_parameter("sleeve_color",Color(profile.shirt))

func place_arm(arm: MeshInstance3D, start: Vector3, tip: Vector3) -> void:
	var direction = tip-start
	arm.position = (start+tip)*.5
	arm.quaternion = Quaternion(Vector3.UP,direction.normalized())
	arm.scale = Vector3(1.0,direction.length(),1.0)

func pose(elapsed: float, _aim: float, reloading: bool, reload_phase: float, fire_phase: float) -> void:
	var breathe = sin(elapsed*1.6)*.003
	var right_start = Vector3(.18,-.29,.24)
	var right_tip = Vector3(.041,-.074,.070)
	var left_start = Vector3(-.19,-.29,.24)
	var left_tip = Vector3(-.052,-.046,-.045)
	if reloading:
		var reach = smoothstep(.08,.27,reload_phase)*(1.0-smoothstep(.70,.91,reload_phase))
		var pull = smoothstep(.28,.47,reload_phase)*(1.0-smoothstep(.53,.72,reload_phase))
		left_tip = left_tip.lerp(Vector3(-.047,-.135,.07),reach)
		left_tip += Vector3(-.12,.035,-.02)*pull
		spare_magazine.visible = reload_phase > .32 and reload_phase < .68
		spare_magazine.position = left_tip+Vector3(0,-.065,-.012)
	else:
		spare_magazine.visible = false
	var kick = sin(clampf(fire_phase,0,1)*PI)
	right_tip += Vector3(0,.009,.018)*kick
	left_tip += Vector3(0,.005,.008)*kick
	right_tip.y += breathe
	left_tip.y += breathe
	place_arm(right_arm,right_start,right_tip)
	place_arm(left_arm,left_start,left_tip)
