extends RefCounted
const Toy = preload("res://scripts/normal_zombie_art.gd")
const View = preload("res://scripts/enemy_view.gd")
static func validate(game, check: Callable) -> void:
	var data = game.get_node("/root/Data")
	for part in data.parts:
		var original = data.v3(part.size)
		if part.get("head",false):
			check.call(Toy.part_size(part,"normal") == original,"Ordinary toy retains exact original head/face dimensions")
		for kind in ["cone","bucket","giant","dancer"]:
			check.call(Toy.part_size(part,kind) == original,"Special enemy geometry remains unchanged: "+kind)
	check.call(Toy.part_size(data.parts[18],"normal").x > data.parts[18].size[0] and Toy.part_size(data.parts[14],"normal").z > data.parts[14].size[2],"Ordinary hands and boots gain a modest toy silhouette")
	for outfit in 5:
		var mesh = game.enemies.mesh_for("normal",0,false,false,outfit)
		check.call(mesh.get_surface_count() == 1,"Toy variant stays one cached draw surface")
		var material = mesh.surface_get_material(0)
		check.call(material == game.enemies.toy_material and is_equal_approx(material.roughness,.30) and material.metallic == 0,"Ordinary surface uses satin nonmetallic plastic")
		var arrays: Array = mesh.surface_get_arrays(0)
		check.call(arrays[Mesh.ARRAY_INDEX].size()/3 < 1100,"Toy stays below eleven hundred triangles per outfit")
		check.call(mesh == game.enemies.mesh_for("normal",3,false,false,outfit),"Ordinary mesh is reused across spawns")
		var valid_bones = true
		for bone in arrays[Mesh.ARRAY_BONES]: valid_bones = valid_bones and bone >= 0 and bone < 7
		check.call(valid_bones,"Toy retains original seven-bone rig")
	check.call(game.enemies.mesh_for("bucket",0,false,true,1).surface_get_material(0) == game.enemies.material and game.enemies.material.roughness == 1.0,"Armored enemies retain their original matte material")
	var sim = game.sim
	sim.spawn(Vector2(8,36),"normal")
	var z: Dictionary = sim.zombies[-1]
	for time in [0.0,.2,.7]:
		z.attack_time = time
		var state: Dictionary = View.pose_state(z,time,false)
		var poses: Array = View.transforms(z,time,false)
		for index in 20:
			var part: Dictionary = data.parts[index]
			var size = Toy.part_size(part,"normal")
			var verts: Array = Toy.box_vertices(size,Toy.bevel_for(part,size))
			var within_bounds = true
			for vertex in verts:
				var rendered: Vector3 = state.root*state.bones[View.bone_for(part)]*(vertex.position+data.v3(part.position))
				var local: Vector3 = poses[index].affine_inverse()*rendered
				within_bounds = within_bounds and local.abs().x <= .5005 and local.abs().y <= .5005 and local.abs().z <= .5005
			check.call(within_bounds,"Rendered bevels fit matching authoritative box during attack: "+str(index))
	var vertices: Array = Toy.box_vertices(Vector3(.49,.49,.45),.012)
	var winding = true
	for index in range(0,vertices.size(),3):
		var a: Vector3 = vertices[index].position
		var b: Vector3 = vertices[index+1].position
		var c: Vector3 = vertices[index+2].position
		winding = winding and (b-a).cross(c-a).dot(vertices[index].normal) < 0
	check.call(vertices.size() == 132 and winding,"Beveled primitive has forty-four outward clockwise triangles")
	sim.zombies.clear()
