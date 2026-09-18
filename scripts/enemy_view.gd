extends Node3D
## Shared rigid-part skeletons use exactly the same transforms as authority ray hits.
var meshes: Dictionary = {}
var actors: Dictionary = {}
var skin: Skin
var material: StandardMaterial3D
var kinds = ["normal","crawler","cone","bucket","imp","shield","berserker","giant","football"]
const Wardrobe = preload("res://scripts/zombie_outfits.gd")

func _ready() -> void:
	skin = Skin.new()
	for part in 7: skin.add_bind(part,Transform3D.IDENTITY)
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0

func mesh_for(kind: String, palette: int, rage: bool, armor: bool, outfit := -1) -> ArrayMesh:
	var dressed = outfit >= 0 and kind in ["normal","crawler","cone","bucket"]
	var key = kind+str(outfit if dressed else palette)+str(rage)+str(armor)+str(dressed)
	if meshes.has(key): return meshes[key]
	var cube = BoxMesh.new().get_mesh_arrays()
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in Data.parts.size():
		var part: Dictionary = Data.parts[j]
		if (part.has("kind") and part.kind != kind) or (part.get("armor",false) and not armor): continue
		if dressed and j in [1,2]: continue # Replace old shirt patches with outfit details.
		var color = Data.rgb(int(part.color))
		if part.get("shirt",false):
			color = [Color(.349,.392,.314),Color(.424,.345,.353),Color(.329,.408,.467),Color(.510,.443,.341)][palette]
			color = {"imp":Color(.341,.251,.373),"shield":Color(.275,.365,.396),"berserker":Color(.714,.231,.173) if rage else Color(.494,.220,.184),"giant":Color(.443,.349,.263),"football":Color(.561,.157,.188)}.get(kind,color)
		if dressed: color = Wardrobe.part_color(outfit,part,color)
		for index in cube[Mesh.ARRAY_INDEX]:
			surface.set_normal(cube[Mesh.ARRAY_NORMAL][index])
			surface.set_color(color)
			surface.set_bones(PackedInt32Array([bone_for(part),0,0,0]))
			surface.set_weights(PackedFloat32Array([1,0,0,0]))
			surface.add_vertex(cube[Mesh.ARRAY_VERTEX][index]*Data.v3(part.size)+Data.v3(part.position))
	if dressed:
		for patch in Wardrobe.patches(outfit):
			for index in cube[Mesh.ARRAY_INDEX]:
				surface.set_normal(cube[Mesh.ARRAY_NORMAL][index])
				surface.set_color(patch.color)
				surface.set_bones(PackedInt32Array([0,0,0,0]))
				surface.set_weights(PackedFloat32Array([1,0,0,0]))
				surface.add_vertex(cube[Mesh.ARRAY_VERTEX][index]*patch.size+patch.position)
	surface.index()
	meshes[key] = surface.commit()
	return meshes[key]

func create_actor(z: Dictionary) -> Dictionary:
	var body = Node3D.new()
	add_child(body)
	var skeleton = Skeleton3D.new()
	skeleton.name = "Pose"
	body.add_child(skeleton)
	for j in 7:
		skeleton.add_bone("part_"+str(j))
		skeleton.set_bone_rest(j,Transform3D.IDENTITY)
	var view = MeshInstance3D.new()
	body.add_child(view)
	view.skeleton = NodePath("../Pose")
	view.skin = skin
	view.material_override = material
	view.custom_aabb = AABB(Vector3(-4,-3,-4),Vector3(8,9,8))
	return {"body":body,"skeleton":skeleton,"view":view,"kind":z.kind}

func clear() -> void:
	for actor in actors.values(): retire_actor(actor)
	actors.clear()

func retire_actor(actor: Dictionary) -> void:
	# Bone updates are deferred by Skeleton3D. Hide immediately, but release the
	# hierarchy at the frame boundary after pending engine notifications finish.
	actor.body.hide()
	actor.body.queue_free()

static func root_transform(z: Dictionary, elapsed: float, stationary: bool, stride: float) -> Transform3D:
	var basis = Basis(Vector3.UP,z.heading).scaled(Vector3.ONE*Data.enemy_scale(z.kind))
	var ground = Data.enemy_ground_height(z.pos,z.get("map_id","graypine_night"))
	var transform = Transform3D(basis,Vector3(z.pos.x,ground+absf(stride)*.04,z.pos.y))
	if z.hp > 0 and not z.get("guard_awake",true) and z.get("move_speed",0.0) <= .05 and z.get("map_id","") == "graypine_night":
		# Root pose is shared by skeleton rendering and CPU ray boxes: no invisible hitbox motion.
		var breath = sin(elapsed*1.4+z.id*2.17)
		transform.origin.y += breath*.018
		transform.basis *= Basis(Vector3.RIGHT,.06+sin(elapsed*.65+z.id)*.045)
		transform.basis *= Basis(Vector3.BACK,breath*.025)
	if z.hp <= 0:
		transform.basis *= Basis(Vector3.RIGHT,-clampf((.85-z.down)/.65,0,1)*PI/2)
		transform.origin.y = ground-.15
	var attack_advancing: bool = z.attack_time > 0 and z.attack_time < Data.attack(z.kind,z.rage).x
	if z.get("move_speed",0.0) > 3.5 and (z.attack_time <= 0 or attack_advancing): transform.basis *= Basis(Vector3.RIGHT,.12)
	if z.attack_time > 0:
		var strike = sin(clampf(z.attack_time/Data.attack(z.kind,z.rage).x,0,1)*PI/2)
		transform.basis *= Basis(Vector3.RIGHT,strike*.10)
	if z.state == "windup": transform.basis *= Basis(Vector3.RIGHT,-.22)
	if z.state == "charging": transform.basis *= Basis(Vector3.RIGHT,.28)
	if z.state == "stunned": transform.basis *= Basis(Vector3.BACK,sin(elapsed*16)*.08)
	return transform

static func bone_for(part: Dictionary) -> int:
	if part.get("head",false): return 6
	if part.get("shield",false): return 5
	var limb: float = part.get("limb",0.0)
	if absf(limb) >= 1: return 1 if limb > 0 else 2
	if limb != 0: return 3 if limb > 0 else 4
	return 0

static func pose_state(z: Dictionary, elapsed: float, stationary: bool) -> Dictionary:
	if z.kind == "crawler": return crawl_pose(z,elapsed,stationary)
	var attack_advancing: bool = z.attack_time > 0 and z.attack_time < Data.attack(z.kind,z.rage).x
	var moving: bool = not stationary and z.get("move_speed",0.0) > .05 and z.hp > 0 and (z.attack_time <= 0 or attack_advancing) and z.state not in ["windup","stunned"] and z.rage_pause <= 0
	var stride = sin(z.get("gait",(elapsed-z.born)*5+z.id*2)) if moving else 0.0
	var idle: bool = z.hp > 0 and not z.get("guard_awake",true) and z.get("move_speed",0.0) <= .05 and z.get("map_id","") == "graypine_night"
	if idle: stride = sin(elapsed*1.4+z.id*2.17)*.08
	var running: bool = moving and z.get("move_speed",0.0) > 3.5
	var bones: Array[Transform3D] = [Transform3D.IDENTITY]
	for side in [1.0,-1.0]:
		var pivot = Vector3(-side*.19,.83,0.0)
		var rotation = Basis(Vector3.RIGHT,stride*side*(.75 if running else .35))
		bones.append(Transform3D(rotation,pivot-rotation*pivot))
	for side in [1.0,-1.0]:
		var angle = .85-stride*side*.6 if running else .65-stride*side*.2
		if idle: angle = 1.15+stride
		if z.attack_time > 0:
			var hit_at: float = Data.attack(z.kind,z.rage).x
			var progress: float = z.attack_time/hit_at
			if progress <= .6: angle = lerpf(.65,-.75,smoothstep(0.0,.6,progress))
			elif progress <= 1: angle = lerpf(-.75,.35,smoothstep(.6,1.0,progress))
			else: angle = lerpf(.35,.65,clampf((z.attack_time-hit_at)/.35,0,1))
		var pivot = Vector3(-side*.43,1.35,-.045)
		var rotation = Basis(Vector3.RIGHT,angle)
		bones.append(Transform3D(rotation,pivot-rotation*pivot))
	bones.append(Transform3D(Basis.IDENTITY,Vector3(0,-.85,-.18)) if z.attack_time > 0 and z.attack_time < .45 else Transform3D.IDENTITY)
	bones.append(Transform3D.IDENTITY)
	return {"root":root_transform(z,elapsed,stationary,stride),"bones":bones}

static func crawl_pose(z: Dictionary, elapsed: float, stationary: bool) -> Dictionary:
	var moving: bool = z.hp > 0 and not stationary and z.get("move_speed",0.0) > .05 and z.state != "stunned"
	var phase: float = z.get("gait",elapsed*5+z.id)
	var stride = sin(phase) if moving else 0.0
	var ground = Data.enemy_ground_height(z.pos,z.get("map_id","graypine_night"))
	var death: float = smoothstep(0.0,1.0,clampf((.85-float(z.get("down",.85)))/.6,0,1)) if z.hp <= 0 else 0.0
	var root = Transform3D(Basis(Vector3.UP,z.heading),Vector3(z.pos.x,ground+lerpf(.36,.27,death)+absf(stride)*.015,z.pos.y))
	var flat = Basis(Vector3.RIGHT,PI/2)
	var bones: Array[Transform3D] = [Transform3D(flat,-(flat*Vector3(0,1.18,0)))]
	for side in [1.0,-1.0]:
		var rotation = Basis(Vector3.UP,stride*side*.12)*flat
		var pivot = Vector3(-side*.19,.83,0)
		bones.append(Transform3D(rotation,Vector3(-side*.19,0,-.35)-rotation*pivot))
	for side in [1.0,-1.0]:
		var pull = stride*side*(1.0-death)
		var reach = sin(clampf(z.attack_time/Data.attack(z.kind).y,0,1)*PI) if z.hp > 0 and z.attack_time > 0 else 0.0
		var rotation = Basis(Vector3.UP,pull*.2+side*death*.08)
		var pivot = Vector3(-side*.43,1.3,.2)
		var target = Vector3(-side*lerpf(.43,.46,death),lerpf(-.13,0,death)+maxf(0,pull)*.04,lerpf(.25,.48,death)+pull*.16+reach*.28)
		bones.append(Transform3D(rotation,target-rotation*pivot))
	bones.append(Transform3D.IDENTITY)
	# The living crawler lifts its face; on death both hands lose support and
	# extend forward while the head lowers face-first until it touches ground.
	var head = Basis(Vector3.RIGHT,lerpf(-.12,PI/2,death))
	var head_target = Vector3(0,lerpf(.17,.04,death),lerpf(.65,.53,death))
	bones.append(Transform3D(head,head_target-head*Vector3(0,1.79,0)))
	return {"root":root,"bones":bones}

static func transforms(z: Dictionary, elapsed: float, stationary: bool) -> Array:
	var state = pose_state(z,elapsed,stationary)
	var result: Array = []
	for part in Data.parts:
		if (part.has("kind") and part.kind != z.kind) or (part.get("armor",false) and z.armor <= 0):
			result.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.00001),Vector3(0,-100,0)))
		else:
			result.append(state.root * state.bones[bone_for(part)] * Transform3D(Basis.IDENTITY.scaled(Data.v3(part.size)),Data.v3(part.position)))
	return result

func sync(zombies: Array, elapsed: float, stationary: bool) -> void:
	var present: Dictionary = {}
	for z in zombies:
		present[z.id] = true
		if not actors.has(z.id): actors[z.id] = create_actor(z)
		var actor: Dictionary = actors[z.id]
		actor.kind = z.kind
		var state = pose_state(z,elapsed,stationary)
		actor.body.transform = state.root
		actor.view.mesh = mesh_for(z.kind,int(z.id)%4,z.rage,z.armor > 0,int(z.get("outfit",-1)))
		for j in 7: actor.skeleton.set_bone_pose(j,state.bones[j])
		actor.skeleton.force_update_all_bone_transforms()
	for id in actors.keys():
		if not present.has(id):
			retire_actor(actors[id])
			actors.erase(id)

func visible_count(kind: String) -> int:
	return actors.values().filter(func(actor): return actor.kind == kind and actor.body.is_visible_in_tree()).size()

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
	var broad = Transform3D(Basis.IDENTITY.scaled(Vector3(3*scale,3.2*scale,3*scale)),Vector3(z.pos.x,Data.enemy_ground_height(z.pos,z.get("map_id","graypine_night"))+1.4*scale,z.pos.y))
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
