extends MultiMeshInstance3D
## One shared draw submission for the cosmetic magnetized coin drops.
const CAPACITY = 512

func _ready() -> void:
	var coin = preload("res://scripts/currency_art.gd").mesh()
	var material = StandardMaterial3D.new()
	material.albedo_texture = preload("res://scripts/currency_art.gd").coin()
	material.metallic = .3
	material.roughness = .32
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_texture = preload("res://scripts/currency_art.gd").coin()
	material.emission_energy_multiplier = .4
	coin.surface_set_material(0,material)
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
		var basis = Basis(Vector3.UP,drop.age*9)*Basis(Vector3.RIGHT,PI/2+sin(drop.age*7)*.3)
		var arrival: float = clampf(drop.get("arrival",0.0),0,1)
		basis = basis.scaled(Vector3.ONE*(1.0+.12*log(float(drop.value)))*(1.0-arrival*.8))
		multimesh.set_instance_transform(index,Transform3D(basis,drop.pos))
