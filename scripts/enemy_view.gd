extends Node3D
## Eight instanced batches, one per enemy kind. Limb animation runs on the GPU.
## Ray hits use the identical per-part poses below, independent of the rendering device.
var batches: Dictionary = {}
var kinds = ["normal","cone","bucket","imp","shield","berserker","giant","football"]

func _ready() -> void:
	var cube = BoxMesh.new().get_mesh_arrays()
	for kind_index in kinds.size():
		var kind: String = kinds[kind_index]
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in Data.parts:
			if part.has("kind") and part.kind != kind: continue
			var pos = Data.v3(part.position)
			var size = Data.v3(part.size)
			var flag = 2 if part.get("shield",false) else 1 if part.get("armor",false) else 3 if part.get("shirt",false) else 0
			for index in cube[Mesh.ARRAY_INDEX]:
				surface.set_normal(cube[Mesh.ARRAY_NORMAL][index])
				surface.set_color(Data.rgb(int(part.color)))
				surface.set_uv(Vector2(pos.y,pos.z))
				surface.set_uv2(Vector2(part.get("limb",0),flag))
				surface.add_vertex(cube[Mesh.ARRAY_VERTEX][index]*size+pos)
		var material = ShaderMaterial.new()
		material.shader = load("res://scripts/enemy_animation.gdshader")
		material.set_shader_parameter("kind",kind_index)
		var multi = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.use_colors = true
		multi.mesh = surface.commit()
		multi.instance_count = 256
		for i in 256: multi.set_instance_color(i,Color.WHITE)
		multi.visible_instance_count = 0
		var view = MultiMeshInstance3D.new()
		view.multimesh = multi
		view.material_override = material
		view.custom_aabb = AABB(Vector3(-90,-5,-250),Vector3(180,35,500))
		add_child(view)
		batches[kind] = multi

func clear() -> void:
	for multi in batches.values(): multi.visible_instance_count = 0

static func root_transform(z: Dictionary, elapsed: float, stationary: bool, stride: float) -> Transform3D:
	var basis = Basis(Vector3.UP,z.heading).scaled(Vector3.ONE*Data.enemy_scale(z.kind))
	var ground = Data.enemy_ground_height(z.pos,z.get("map_id","outpost"))
	var transform = Transform3D(basis,Vector3(z.pos.x,ground+absf(stride)*.04,z.pos.y))
	if z.hp > 0 and not z.get("guard_awake",true) and z.get("map_id","") == "graypine_night":
		# Root pose is shared by GPU instances and CPU ray boxes: no invisible hitbox motion.
		var breath = sin(elapsed*1.4+z.id*2.17)
		transform.origin.y += breath*.018
		transform.basis *= Basis(Vector3.RIGHT,.06+sin(elapsed*.65+z.id)*.045)
		transform.basis *= Basis(Vector3.BACK,breath*.025)
	if z.hp <= 0:
		transform.basis *= Basis(Vector3.RIGHT,-clampf((.85-z.down)/.65,0,1)*PI/2)
		transform.origin.y = ground-.15
	if z.state == "windup": transform.basis *= Basis(Vector3.RIGHT,-.22)
	if z.state == "charging": transform.basis *= Basis(Vector3.RIGHT,.28)
	if z.state == "stunned": transform.basis *= Basis(Vector3.BACK,sin(elapsed*16)*.08)
	return transform

static func transforms(z: Dictionary, elapsed: float, stationary: bool) -> Array:
	var result: Array = []
	var alive: bool = z.hp > 0
	var moving: bool = not stationary and alive and z.get("guard_awake",true) and z.attack_time <= 0 and z.state not in ["windup","stunned"] and z.rage_pause <= 0
	var pace: float = 1.6 if z.kind == "imp" else 1.35 if z.kind == "football" else 1.7 if z.rage else .75 if z.kind == "giant" else 1.0
	var stride = sin((elapsed-z.born)*5*pace+z.id*2) if moving else 0.0
	var idle: bool = alive and not z.get("guard_awake",true) and z.get("map_id","") == "graypine_night"
	if idle: stride = sin(elapsed*1.4+z.id*2.17)*.08
	var profile = Data.attack(z.kind,z.rage)
	var lunge = 0.0
	if z.attack_time > 0:
		lunge = z.attack_time / profile.x if z.attack_time <= profile.x else maxf(0,1-(z.attack_time-profile.x)/.35)
	var root = root_transform(z,elapsed,stationary,stride)
	for part in Data.parts:
		if (part.has("kind") and part.kind != z.kind) or (part.get("armor",false) and z.armor <= 0):
			result.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.00001), Vector3(0,-100,0)))
			continue
		var pos = Data.v3(part.position)
		var limb: float = part.get("limb",0)
		var rotation = 0.0
		if absf(limb) >= 1:
			pos.z += stride*limb*.2
			pos.y += maxf(0,stride*signf(limb))*.075
			rotation = stride*limb*.27
		elif limb != 0:
			pos.z += -stride*signf(limb)*.07+lunge*.28
			pos.y += sin(lunge*PI)*.16
			rotation = -stride*signf(limb)*.16
		if part.get("shield",false) and z.attack_time > 0 and z.attack_time < .45:
			pos.y -= .85
			pos.z -= .18
		if idle and absf(limb) > 0 and absf(limb) < 1:
			var pivot = Vector3(pos.x,1.35,0)
			var droop = 1.15+stride
			pos = pivot+Basis(Vector3.RIGHT,droop)*(pos-pivot)
			rotation += droop
		result.append(root * Transform3D(Basis(Vector3.RIGHT,rotation).scaled(Data.v3(part.size)),pos))
	return result

func sync(zombies: Array, elapsed: float, stationary: bool) -> void:
	var required: Dictionary = {}
	for z in zombies: required[z.kind] = required.get(z.kind,0)+1
	for kind in required:
		if required[kind] > batches[kind].instance_count:
			batches[kind].instance_count = nearest_po2(required[kind])
			for i in batches[kind].instance_count: batches[kind].set_instance_color(i,Color.WHITE)
	var counts: Dictionary = {}
	for kind in kinds: counts[kind] = 0
	for z in zombies: counts[z.kind] += 1
	for kind in kinds:
		var multi: MultiMesh = batches[kind]
		if counts[kind] > multi.instance_count:
			multi.instance_count = maxi(counts[kind],multi.instance_count*2)
			for i in multi.instance_count: multi.set_instance_color(i,Color.WHITE)
		counts[kind] = 0
	for z in zombies:
		var index: int = counts[z.kind]
		counts[z.kind] += 1
		var alive: bool = z.hp > 0
		var moving: bool = not stationary and alive and z.get("guard_awake",true) and z.attack_time <= 0 and z.state not in ["windup","stunned"] and z.rage_pause <= 0
		var pace = 1.6 if z.kind == "imp" else 1.35 if z.kind == "football" else 1.7 if z.rage else .75 if z.kind == "giant" else 1.0
		var stride = sin((elapsed-z.born)*5*pace+z.id*2) if moving else 0.0
		var idle: bool = alive and not z.get("guard_awake",true) and z.get("map_id","") == "graypine_night"
		if idle: stride = sin(elapsed*1.4+z.id*2.17)*.08
		var profile = Data.attack(z.kind,z.rage)
		var lunge = 0.0
		if z.attack_time > 0: lunge = z.attack_time/profile.x if z.attack_time <= profile.x else maxf(0,1-(z.attack_time-profile.x)/.35)
		var transform = root_transform(z,elapsed,stationary,stride)
		var flags = int(z.id)%4+(4 if z.rage else 0)+(8 if z.attack_time > 0 and z.attack_time < .45 else 0)
		if idle: flags += 16
		batches[z.kind].set_instance_transform(index,transform)
		batches[z.kind].set_instance_custom_data(index,Color(stride,lunge,1 if z.armor > 0 else 0,flags))
	for kind in kinds: batches[kind].visible_instance_count = counts[kind]

static func ray_box(origin: Vector3, direction: Vector3, transform: Transform3D, max_distance: float) -> float:
	var inverse = transform.affine_inverse()
	var start = inverse*origin
	var delta = inverse.basis*direction
	var near = 0.0
	var far = max_distance
	for axis in range(3):
		if absf(delta[axis]) < .0000001:
			if start[axis] < -.5 or start[axis] > .5: return INF
		else:
			var a = (-.5-start[axis])/delta[axis]
			var b = (.5-start[axis])/delta[axis]
			near = maxf(near,minf(a,b))
			far = minf(far,maxf(a,b))
			if near > far: return INF
	return near

static func hit(z: Dictionary, origin: Vector3, direction: Vector3, distance: float, elapsed: float, stationary: bool) -> Dictionary:
	var scale = Data.enemy_scale(z.kind)
	var broad = Transform3D(Basis.IDENTITY.scaled(Vector3(3*scale,3.2*scale,3*scale)),Vector3(z.pos.x,Data.enemy_ground_height(z.pos,z.get("map_id","outpost"))+1.4*scale,z.pos.y))
	if ray_box(origin,direction,broad,distance) == INF: return {}
	var poses = transforms(z,elapsed,stationary)
	var nearest = distance
	var selected = -1
	for j in Data.parts.size():
		var part: Dictionary = Data.parts[j]
		if (part.has("kind") and part.kind != z.kind) or (part.get("armor",false) and z.armor <= 0): continue
		var d = ray_box(origin,direction,poses[j],nearest)
		if d < nearest:
			nearest = d
			selected = j
	if selected < 0: return {}
	var shield = false
	if z.kind == "shield" and z.armor > 0 and not (z.attack_time > 0 and z.attack_time < .45):
		shield = Vector2(sin(z.heading),cos(z.heading)).dot((Vector2(origin.x,origin.z)-z.pos).normalized()) >= cos(deg_to_rad(75))
	return {"z":z,"distance":nearest,"head":Data.parts[selected].get("head",false) and not shield,"armor":shield if z.kind == "shield" else true}
