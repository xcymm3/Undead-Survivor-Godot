extends RefCounted
## Batched foliage is opaque to spawn sight checks, while bullets and movement
## pass through leaves. Trunks and rocks share physical/navigation obstruction.
const SIGHT_LAYER = 8
const EnvironmentArt = preload("res://scripts/defense_environment.gd")
var world: Node3D
var random = RandomNumberGenerator.new()
var trunks: Array[Transform3D] = []
var leaves: Array[Transform3D] = []
var shrubs: Array[Transform3D] = []

func _init(owner: Node3D) -> void:
	world = owner
	random.seed = 20260930

func foliage(point: Vector3, radius: float, buffer: Array[Transform3D]) -> void:
	buffer.append(Transform3D(Basis.from_scale(Vector3.ONE*radius),point))
	var body = StaticBody3D.new()
	body.name = "FarForestSightCover"
	body.position = point
	body.collision_layer = SIGHT_LAYER
	body.collision_mask = 0
	body.set_meta("environment_feature","spawn_sight_cover")
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	collision.shape = sphere
	body.add_child(collision)
	world.add_child(body,true)

func tree(point: Vector2) -> void:
	var height = random.randf_range(6.8,10.0)
	var radius = random.randf_range(.22,.34)
	var body = StaticBody3D.new()
	body.name = "FarForestTrunk"
	body.position = Vector3(point.x,height*.5,point.y)
	body.set_meta("environment_feature","tree")
	var collision = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body,true)
	world.obstacles.append({"minX":point.x-radius,"maxX":point.x+radius,"minZ":point.y-radius,"maxZ":point.y+radius})
	trunks.append(Transform3D(Basis.from_scale(Vector3(radius,height,radius)),body.position))
	foliage(Vector3(point.x,height*.78,point.y),2.3,leaves)
	for side in [-1.0,1.0]:
		foliage(Vector3(point.x+side*1.3,height*.5,point.y+.2),1.9,leaves)
	# Dense low undergrowth hides the feet and torso behind the woodland edge.
	foliage(Vector3(point.x+random.randf_range(-.5,.5),1.35,point.y+1.3),1.7,shrubs)

func batch(title: String, mesh: Mesh, poses: Array[Transform3D], color: String) -> void:
	var view = MultiMeshInstance3D.new()
	view.name = title
	view.multimesh = MultiMesh.new()
	view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	view.multimesh.mesh = mesh
	view.multimesh.instance_count = poses.size()
	view.material_override = world.material(color)
	for i in poses.size(): view.multimesh.set_instance_transform(i,poses[i])
	world.add_child(view)

func build() -> void:
	var centers = [Vector2(-14,-87),Vector2(14,-87),Vector2(-34,-91),Vector2(34,-91),Vector2(0,-112),Vector2(-30,-116),Vector2(30,-116),Vector2(-13,-139),Vector2(13,-139),Vector2(-35,-143),Vector2(35,-143)]
	for index in centers.size():
		var center: Vector2 = centers[index]
		for offset in [Vector2(-4,0),Vector2(0,0),Vector2(4,0),Vector2(-5,-5),Vector2(0,-5),Vector2(5,-5),Vector2(0,5)]:
			tree(center+offset+Vector2(random.randf_range(-.5,.5),random.randf_range(-.5,.5)))
		for side in [-1.0,1.0]:
			var point = center+Vector2(side*6.5,2.5)
			var height = random.randf_range(3.1,4.4)
			EnvironmentArt.make_rock(world,"FarForestBoulder%d_%d" % [index,int(side+1)],Vector3(point.x,height*.43,point.y),Vector3(4.5,height,3.8),random.randf_range(-30,30),true,true)
	var bark = CylinderMesh.new()
	bark.top_radius = .75
	bark.bottom_radius = 1.0
	bark.height = 1.0
	bark.radial_segments = 7
	batch("FarForestTrunks",bark,trunks,"534333")
	var crown = SphereMesh.new()
	crown.radius = 1.0
	crown.height = 2.0
	crown.radial_segments = 10
	crown.rings = 5
	batch("FarForestLeaves",crown,leaves,"354a32")
	batch("FarForestUndergrowth",crown,shrubs,"526348")
