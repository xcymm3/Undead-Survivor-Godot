extends RefCounted
## Faceted woodland. Visible woody/leaf volumes share collision and navigation.
const SIGHT_LAYER = 8
const EnvironmentArt = preload("res://scripts/defense_environment.gd")
var world: Node3D
var random = RandomNumberGenerator.new()
var trunks: Array[Transform3D] = []
var branches: Array[Transform3D] = []
var leaves: Array[Transform3D] = []
var shrubs: Array[Transform3D] = []
var crown: ArrayMesh
var brush: ArrayMesh

func _init(owner: Node3D) -> void:
	world = owner
	random.seed = 20260930
	crown = leaf_mass(false)
	brush = leaf_mass(true)

func triangle(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, shade: float) -> void:
	builder.set_color(Color(shade,shade,shade))
	# Orient each closed hull outwards, keeping lighting and backface culling correct.
	for vertex in [a,c,b]: builder.add_vertex(vertex)

func leaf_mass(low: bool) -> ArrayMesh:
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Broken, staggered polygon tiers replace round spheres. Shrubs use several
	# separate pointed sprays, with gaps between them, rather than one smooth ball.
	var lobes = 5 if low else 1
	for lobe in lobes:
		var offset = Vector3(cos(lobe*2.4)*.48,0,sin(lobe*2.4)*.48) if low else Vector3.ZERO
		var width = .48 if low else 1.0
		var height = .72+fmod(lobe*.19,.4) if low else 1.0
		var rings = [Vector2(0,.22),Vector2(.24,.80),Vector2(.57,1.0),Vector2(.86,.68),Vector2(1.12,0)]
		var count = 7 if low else 9
		for tier in rings.size()-1:
			for side in count:
				var points: Array[Vector3] = []
				for entry in [Vector2i(tier,side),Vector2i(tier,side+1),Vector2i(tier+1,side+1),Vector2i(tier+1,side)]:
					var angle = posmod(entry.y,count)*TAU/count
					var radius = rings[entry.x].y*(1.0+.15*sin(angle*3.0+entry.x*1.7+lobe))
					var y = rings[entry.x].x*height
					points.append(offset+Vector3(cos(angle)*radius*width,y,sin(angle)*radius*width))
				var shade = .74+.22*float(tier)/3.0+.06*sin(side*2.7+lobe)
				triangle(builder,points[0],points[2],points[1],shade)
				triangle(builder,points[0],points[3],points[2],shade)
		# Close the underside so the rendered silhouette and convex collision agree.
		for side in count:
			var a = side*TAU/count
			var b = (side+1)*TAU/count
			triangle(builder,offset,offset+Vector3(cos(a)*.22*width,0,sin(a)*.22*width),offset+Vector3(cos(b)*.22*width,0,sin(b)*.22*width),.65)
	builder.generate_normals()
	return builder.commit()

func obstacle(body: StaticBody3D, bounds: AABB) -> void:
	body.collision_layer = 1 | SIGHT_LAYER
	body.collision_mask = 0
	var rect = {"minX":bounds.position.x,"maxX":bounds.end.x,"minZ":bounds.position.z,"maxZ":bounds.end.z}
	body.set_meta("forest_obstacle",rect)
	world.obstacles.append(rect)
	world.add_child(body,true)

func wood(a: Vector3, b: Vector3, radius: float, trunk := false) -> void:
	var length = a.distance_to(b)
	var rotation = Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	var pose = Transform3D(rotation*Basis.from_scale(Vector3(radius,length,radius)),(a+b)*.5)
	if trunk: trunks.append(pose)
	else: branches.append(pose)
	var body = StaticBody3D.new()
	body.name = "FarForestTrunk" if trunk else "FarForestBranch"
	body.transform = Transform3D(rotation,pose.origin)
	body.set_meta("environment_feature","tree" if trunk else "branch")
	var collision = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = radius
	shape.height = length
	collision.shape = shape
	body.add_child(collision)
	obstacle(body,body.transform*AABB(Vector3(-radius,-length*.5,-radius),Vector3(radius*2,length,radius*2)))

func foliage(point: Vector3, size: Vector3, low := false) -> void:
	var rotation = Basis(Vector3.UP,random.randf_range(-PI,PI))
	var pose = Transform3D(rotation*Basis.from_scale(size),point)
	if low: shrubs.append(pose)
	else: leaves.append(pose)
	var mesh = brush if low else crown
	var body = StaticBody3D.new()
	body.name = "FarForestShrub" if low else "FarForestCrown"
	body.transform = Transform3D(rotation,point)
	body.set_meta("environment_feature","shrub" if low else "tree_crown")
	body.set_meta("forest_render_vertices",mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	body.set_meta("forest_render_pose",pose)
	var collision = CollisionShape3D.new()
	var shape = ConvexPolygonShape3D.new()
	var points = PackedVector3Array()
	for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: points.append(vertex*size)
	shape.points = points
	collision.shape = shape
	body.add_child(collision)
	# Also reserve the canopy footprint. Even tall giants cannot walk through
	# hanging leaves; every route segment uses this same conservative footprint.
	obstacle(body,pose*mesh.get_aabb())

func tree(point: Vector2) -> void:
	var height = random.randf_range(7.0,9.5)
	var radius = random.randf_range(.22,.34)
	var base = Vector3(point.x,0,point.y)
	wood(base,base+Vector3(.15,height*.83,.08),radius,true)
	for side in [-1.0,1.0]:
		var direction = Vector3(side*1.45,height*.61,random.randf_range(-.65,.65))
		wood(base+Vector3(0,height*.20,0),base+direction,radius*.55)
		foliage(base+Vector3(direction.x,height*.38,direction.z),Vector3(random.randf_range(1.8,2.3),height*.40,random.randf_range(1.65,2.15)))
		wood(base+Vector3(side*.65,height*.48,0),base+Vector3(side*1.55,height*.7,side*.65),radius*.30)
	foliage(base+Vector3(.1,height*.61,0),Vector3(2.0,height*.36,1.8))
	# Flared roots and a lower, dispersed brush silhouette make ground obstacles legible.
	for side in [-1.0,1.0]:
		wood(base+Vector3(side*.65,.05,.22),base+Vector3(0,.85,0),radius*.52)
		foliage(base+Vector3(side*1.25,0,1.0+side*.45),Vector3(1.05,random.randf_range(1.35,1.85),1.0),true)

func batch(title: String, mesh: Mesh, poses: Array[Transform3D], color: String) -> void:
	var view = MultiMeshInstance3D.new()
	view.name = title
	view.multimesh = MultiMesh.new()
	view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	view.multimesh.use_colors = true
	view.multimesh.mesh = mesh
	view.multimesh.instance_count = poses.size()
	var finish = world.material(color).duplicate()
	finish.vertex_color_use_as_albedo = true
	finish.roughness = 1.0
	view.material_override = finish
	for i in poses.size():
		view.multimesh.set_instance_transform(i,poses[i])
		var shade = .85+.15*fmod(i*.618,1.0)
		view.multimesh.set_instance_color(i,Color(shade,shade,shade))
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
	batch("FarForestTrunks",bark,trunks,"92714e")
	batch("FarForestBranches",bark,branches,"92714e")
	batch("FarForestLeaves",crown,leaves,"75935b")
	batch("FarForestUndergrowth",brush,shrubs,"859950")
