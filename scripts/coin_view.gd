extends MultiMeshInstance3D
## One shared draw submission for the cosmetic magnetized coin drops.
const CAPACITY = 512

func _ready() -> void:
	var coin = CylinderMesh.new()
	coin.top_radius = .14
	coin.bottom_radius = .14
	coin.height = .055
	coin.radial_segments = 8
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("ffce48")
	material.metallic = .65
	material.emission_enabled = true
	material.emission = Color("d39117")
	material.emission_energy_multiplier = .5
	coin.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = coin
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bounds = Data.Maps.Defense.BOUNDS.grow(12)
	custom_aabb = AABB(Vector3(bounds.position.x,-10,bounds.position.y),Vector3(bounds.size.x,45,bounds.size.y))

func sync(drops: Array) -> void:
	if not multimesh: return
	multimesh.visible_instance_count = mini(drops.size(),CAPACITY)
	for index in multimesh.visible_instance_count:
		var drop: Dictionary = drops[index]
		var basis = Basis(Vector3.UP,drop.age*6)*Basis(Vector3.RIGHT,PI/2)
		basis = basis.scaled(Vector3.ONE*(1.0+.12*log(float(drop.value))))
		multimesh.set_instance_transform(index,Transform3D(basis,drop.pos))
