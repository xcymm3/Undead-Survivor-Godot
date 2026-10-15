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
			if part.get("head",false): check.call(Toy.part_size(part,kind) == original,"Toy redesign retains head and helmet dimensions: "+kind)
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
	var bucket = game.enemies.mesh_for("bucket",0,false,true,1)
	check.call(bucket.get_surface_count() == 2 and bucket.surface_get_material(0) == game.enemies.toy_material and bucket.surface_get_material(1) == game.enemies.bucket_material,"Bucket shares toy skin but retains a separate metal surface")
	var sim = game.sim
	sim.spawn(Vector2(8,36),"normal")
	var z: Dictionary = sim.zombies[-1]
	for time in [0.0,.2,.7]:
		z.attack_time = time
		var state: Dictionary = View.pose_state(z,time,false)
		var poses: Array = View.transforms(z,time,false)
		for index in 20:
			if not Toy.part_visible(index,z.kind): continue
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
	check.call(not Toy.part_visible(4,"normal") and not Toy.part_visible(4,"bucket") and Toy.part_visible(4,"crawler"),"Active toys remove the old hair cap while the legacy crawler stays unchanged")
	var printed_face = Toy.face_vertices()
	var print_in_head = true
	for vertex in printed_face:
		print_in_head = print_in_head and absf(vertex.position.x) < .233 and vertex.position.y > 1.557 and vertex.position.y < 2.023 and vertex.position.z >= .225 and vertex.position.z <= .228
	check.call(printed_face.size() > 0 and print_in_head,"Printed toy face fits original head silhouette without a raised plate")
	check.call(not Toy.part_visible(11,"normal") and not Toy.part_visible(11,"bucket"),"Active toys share removal of raised cheek plates from mesh and hit boxes")
	z.attack_time = 0.0
	z.move_speed = 4.9
	z.gait = .05
	var early: Dictionary = View.pose_state(z,0,false)
	z.gait = .4
	var held: Dictionary = View.pose_state(z,0,false)
	check.call(early.bones[1].is_equal_approx(held.bones[1]) and early.bones[2].is_equal_approx(held.bones[2]),"Mechanical legs hold one rigid pose across part of a stride")
	z.gait = TAU*2.1/6.0
	var next: Dictionary = View.pose_state(z,0,false)
	check.call(not held.bones[1].is_equal_approx(next.bones[1]),"Next mechanical step changes leg pose abruptly")
	z.gait = PI/2
	var left: Dictionary = View.pose_state(z,0,false)
	z.gait = PI*1.5
	var right: Dictionary = View.pose_state(z,0,false)
	check.call(left.root.origin.x > z.pos.x and right.root.origin.x < z.pos.x and not left.root.basis.is_equal_approx(right.root.basis),"Ordinary walking rolls and sways to opposite sides")
	for phase in 48:
		z.gait = phase*TAU/48.0
		var state: Dictionary = View.pose_state(z,0,false)
		var poses: Array = View.transforms(z,0,false)
		var low = INF
		for index in [14,15]:
			for x in [-.5,.5]:
				for y in [-.5,.5]:
					for depth in [-.5,.5]: low = minf(low,(poses[index]*Vector3(x,y,depth)).y-data.enemy_ground_height(z.pos))
		check.call(low >= -.001 and low <= .025,"Mechanical supporting foot stays planted through cycle: "+str(phase))
	game.enemies.sync([z],0,false)
	var actor: Dictionary = game.enemies.actors[z.id]
	var authority: Dictionary = View.pose_state(z,0,false)
	check.call(actor.body.transform.is_equal_approx(authority.root),"Mechanical render root equals authoritative hit-pose root")
	for bone in 7: check.call(actor.skeleton.get_bone_pose(bone).is_equal_approx(authority.bones[bone]),"Mechanical render bone equals authoritative hit-pose bone")
	check.call(View.transforms(z,0,false)[11].origin.y == -100,"Removed cheek plate is absent from authoritative hit geometry")
	z.move_speed = 0.0
	z.gait = .1
	var idle_a: Dictionary = View.pose_state(z,0,false)
	z.gait = 2.5
	var idle_b: Dictionary = View.pose_state(z,0,false)
	check.call(idle_a.bones[1].is_equal_approx(idle_b.bones[1]),"Idle ordinary zombie does not keep stepping")
	validate_actions(game,z,check)
	validate_toy_roster(game,check)
	sim.zombies.clear()

static func validate_actions(game, base: Dictionary, check: Callable) -> void:
	var motion = preload("res://scripts/normal_zombie_motion.gd")
	var data = game.get_node("/root/Data")
	var states = {
		"idle":{"move_speed":0.0},
		"walk":{"move_speed":4.9,"gait":1.2},
		"attack":{"attack_time":.5},
		"hit":{"toy_hit_at":9.95,"toy_hit_side":.8},
		"shove":{"state":"stunned","state_time":2.12,"toy_shove_at":9.0,"toy_shove_until":12.12},
		"stunned":{"state":"stunned","state_time":1.0},
		"death":{"hp":0.0,"down":.3},
		"emerge":{"emerge_remaining":.8}}
	for name in states:
		var z = base.duplicate(true)
		z.move_speed = 0.0
		z.state = "ready"
		z.attack_time = 0.0
		z.merge(states[name],true)
		var before = z.duplicate(true)
		var authority = View.pose_state(z,10,false)
		check.call(authority.animation == name,"Mechanical state selects correct exclusive action: "+name)
		check.call(z == before,"Pose sampling never mutates gameplay state: "+name)
		game.enemies.sync([z],10,false)
		var actor: Dictionary = game.enemies.actors[z.id]
		var matches: bool = actor.body.transform.is_equal_approx(authority.root)
		for bone in 7: matches = matches and actor.skeleton.get_bone_pose(bone).is_equal_approx(authority.bones[bone])
		check.call(matches,"Render and authoritative joints agree for action: "+name)
		var poses = View.transforms(z,10,false)
		var low = INF
		for index in 20:
			if not Toy.part_visible(index,"normal"): continue
			for x in [-.5,.5]:
				for y in [-.5,.5]:
					for depth in [-.5,.5]: low = minf(low,(poses[index]*Vector3(x,y,depth)).y-data.enemy_ground_height(z.pos))
		if name != "emerge": check.call(low >= -.001 and low <= .025,"Mechanical toy stays grounded: "+name)
	check.call(is_equal_approx(motion.emerge_height(0),-2.5) and is_equal_approx(motion.emerge_height(1),0.0),"Continuous emergence retains buried and standing endpoints")
	var smooth_rise = true
	var previous: float = motion.emerge_height(0)
	for frame in range(1,101):
		var height: float = motion.emerge_height(frame/100.0)
		smooth_rise = smooth_rise and height > previous and height-previous < .04
		previous = height
	check.call(smooth_rise,"Emergence rises continuously without held steps or sudden jumps")
	var hit_at: float = data.attack("normal").x
	check.call(is_equal_approx(motion.track(.35/hit_at,motion.ATTACK_TIMES,motion.ATTACK_ARMS),-.85),"Mechanical windup holds its loaded pose")
	check.call(is_equal_approx(motion.track(hit_at/hit_at,motion.ATTACK_TIMES,motion.ATTACK_ARMS),.35),"Mechanical strike aligns with unchanged damage timestamp")
	check.call(is_equal_approx(motion.track(data.attack("normal").y/hit_at,motion.ATTACK_TIMES,motion.ATTACK_ARMS),.72),"Mechanical recovery completes at unchanged attack cycle")
	check.call(motion.track(.05,motion.RECOIL_TIMES,motion.RECOIL_WEIGHT) == motion.track(.1,motion.RECOIL_TIMES,motion.RECOIL_WEIGHT),"Hit reaction holds its rigid impact pose")
	var z = base.duplicate(true)
	z.hp = 0.0
	for frame in 35:
		z.down = .85-float(frame)/40.0
		var transforms = View.transforms(z,10,false)
		var low = INF
		for index in 20:
			if not Toy.part_visible(index,"normal"): continue
			var pose: Transform3D = transforms[index]
			low = minf(low,pose.origin.y-.5*(absf(pose.basis.x.y)+absf(pose.basis.y.y)+absf(pose.basis.z.y))-data.enemy_ground_height(z.pos))
		check.call(low >= -.001 and low <= .025,"Rigid death stays above terrain throughout fall: "+str(frame))

static func validate_toy_roster(game, check: Callable) -> void:
	var data = game.get_node("/root/Data")
	var sim = game.sim
	for kind in preload("res://scripts/zombie_toy_styles.gd").KINDS:
		sim.zombies.clear()
		sim.spawn(Vector2(8,36),kind)
		var z: Dictionary = sim.zombies[-1]
		z.heading = -.18
		var mesh = game.enemies.mesh_for(kind,0,false,z.armor > 0,int(z.get("outfit",-1)))
		var bones_valid = true
		var triangles = 0
		for surface in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size()/3
			for bone in arrays[Mesh.ARRAY_BONES]: bones_valid = bones_valid and bone >= 0 and bone < 7
		check.call(bones_valid and mesh.get_surface_count() <= 2 and triangles < 1800,"Toy roster keeps seven bones and bounded cached geometry: "+kind)
		check.call(mesh.surface_get_material(0) == (game.enemies.dancer_material if kind == "dancer" else game.enemies.toy_material),"Toy roster uses shared molded material: "+kind)
		for time in [0.0,.25,.7]:
			z.attack_time = time
			var state = View.pose_state(z,time,false)
			var poses = View.transforms(z,time,false)
			var matching = true
			for index in data.parts.size():
				var part: Dictionary = data.parts[index]
				if not Toy.part_visible(index,kind) or (part.has("kind") and part.kind != kind) or (part.get("armor",false) and z.armor <= 0): continue
				if index not in [0,3,14,18] and not part.has("kind"): continue
				var size = Toy.part_size(part,kind)
				var render: Transform3D = state.root*state.bones[View.bone_for(part)]*Toy.part_frame(part,kind)
				var inverse: Transform3D = poses[index].affine_inverse()
				for vertex in Toy.box_vertices(size,Toy.bevel_for(part,size)):
					var local: Vector3 = inverse*(render*vertex.position)
					matching = matching and local.abs().x <= .5005 and local.abs().y <= .5005 and local.abs().z <= .5005
			check.call(matching,"Toy mesh and authority agree for resized bodies and tilted equipment: "+kind+" / "+str(time))
		z.attack_time = 0.0
		var state = View.pose_state(z,0,false)
		var head: Vector3 = state.root*state.bones[6]*data.v3(data.parts[3].position)
		var forward: Vector3 = state.root.basis.z.normalized()
		var hit = View.hit(z,head+forward*5,-forward,10,0,false)
		check.call(not hit.is_empty() and hit.z.id == z.id,"Head remains hittable after cosmetic redesign: "+kind)
	var football_bare = game.enemies.mesh_for("football",0,false,false)
	check.call(football_bare != game.enemies.mesh_for("football",0,false,true),"Football armor break selects an independently cached bare model")
