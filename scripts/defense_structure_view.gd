extends Node3D
## Snapshot-driven models, collapse motion and persistent nonblocking wreckage.
const Structures = preload("res://scripts/defense_structures.gd")
var actors: Dictionary = {}
var materials: Dictionary = {}
const DAMAGE_THRESHOLD = .5

func smoke_material() -> StandardMaterial3D:
	if materials.has("smoke"): return materials.smoke
	var texture = Image.create(64,64,false,Image.FORMAT_RGBA8)
	var noise = FastNoiseLite.new()
	noise.seed = 2718
	noise.frequency = .12
	for y in 64:
		for x in 64:
			var radius = Vector2(x-31.5,y-31.5).length()/31.5
			var alpha = pow(maxf(0,1-radius),.7)*clampf(.7+noise.get_noise_2d(x,y),0,1)*.7
			texture.set_pixel(x,y,Color(.24,.26,.27,alpha))
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(texture)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials.smoke = mat
	return mat

func create_smoke(parent: Node3D) -> Node3D:
	var smoke = Node3D.new()
	smoke.name = "DamageSmoke"
	parent.add_child(smoke)
	for index in 7:
		var puff = MeshInstance3D.new()
		puff.name = "SmokePuff%d" % index
		puff.mesh = QuadMesh.new()
		puff.material_override = smoke_material()
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		smoke.add_child(puff)
	smoke.visible = false
	return smoke

func update_smoke(smoke: Node3D, clock: float) -> void:
	for index in smoke.get_child_count():
		var puff = smoke.get_child(index)
		var age = fposmod(clock/2.7+index/7.0,1.0)
		puff.position = Vector3(sin(clock*.6+index)*.13+age*.35,1.8+age*2.8,.12+age*.18)
		puff.scale = Vector3.ONE*(.6+age*1.65)
		puff.transparency = age*age*.95

func material(color: String, glow := false) -> StandardMaterial3D:
	var key = color+str(glow)
	if not materials.has(key):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(color)
		mat.roughness = .8
		if color in ["58636b","798791","343e46","a4afb5"]:
			mat.metallic = .8
			mat.roughness = .38
		if glow:
			mat.emission_enabled = true
			mat.emission = Color(color)
			mat.emission_energy_multiplier = 2.0
		materials[key] = mat
	return materials[key]

func box(parent: Node3D, title: String, point: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var view = MeshInstance3D.new()
	view.name = title
	var mesh = BoxMesh.new()
	mesh.size = size
	view.mesh = mesh
	view.material_override = material(color)
	view.position = point
	parent.add_child(view)
	return view

func cylinder(parent: Node3D, title: String, point: Vector3, radius: float, height: float, color: String) -> MeshInstance3D:
	var view = MeshInstance3D.new()
	view.name = title
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	view.mesh = mesh
	view.material_override = material(color)
	view.position = point
	parent.add_child(view)
	return view

func collider(parent: Node3D, item: Dictionary) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.name = "StructureCollision"
	var shape = CollisionShape3D.new()
	var bounds = BoxShape3D.new()
	bounds.size = Vector3(Structures.GATE_WIDTH,Structures.GATE_HEIGHT,Structures.GATE_DEPTH) if item.kind == "gate" else Vector3(1.3,1.4,1.3)
	shape.shape = bounds
	body.position.y = bounds.size.y*.5
	body.add_child(shape)
	parent.add_child(body)
	return body

func create_actor(item: Dictionary) -> Dictionary:
	var root = Node3D.new()
	root.name = item.id.to_pascal_case()
	root.position = Vector3(item.pos.x,item.height,item.pos.y)
	add_child(root)
	var actor = {"root":root,"parts":[]}
	if item.kind == "mine":
		cylinder(root,"BuriedPlate",Vector3(0,.05,0),.46,.08,"4a4c33")
		cylinder(root,"PressureCap",Vector3(0,.105,0),.28,.045,"777958")
		var led = box(root,"FuseLight",Vector3(.18,.14,.1),Vector3(.075,.025,.075),"d94b30")
		led.material_override = material("ff4c26",true)
		actor.led = led
	elif item.kind == "turret":
		actor.body = collider(root,item)
		cylinder(root,"AnchorPlate",Vector3(0,.14,0),.68,.22,"3b4139")
		for side in [-1.0,1.0]:
			var foot = box(root,"Stabilizer",Vector3(side*.45,.3,0),Vector3(.28,.55,1.05),"586354")
			foot.rotation.z = side*.25
		cylinder(root,"Pedestal",Vector3(0,.8,0),.22,1.15,"64715e")
		cylinder(root,"Turntable",Vector3(0,1.29,0),.42,.16,"a18c55")
		var yaw = Node3D.new()
		yaw.name = "TrackingHead"
		yaw.position.y = 1.55
		root.add_child(yaw)
		var pitch = Node3D.new()
		yaw.add_child(pitch)
		box(pitch,"Receiver",Vector3(0,0,.06),Vector3(.72,.45,.78),"45574a")
		box(pitch,"AmmunitionBox",Vector3(.48,-.08,.15),Vector3(.32,.4,.55),"8d7950")
		box(pitch,"Barrel",Vector3(0,0,-.61),Vector3(.16,.16,.77),"282e2b")
		box(pitch,"BarrelShroud",Vector3(0,0,-.38),Vector3(.26,.26,.3),"626d60")
		for z in [-.55,-.7,-.85]:
			var ring = cylinder(pitch,"CoolingRing",Vector3(0,0,z),.12,.055,"788073")
			ring.rotation.x = PI/2
		box(pitch,"SensorMount",Vector3(-.23,.2,-.12),Vector3(.15,.14,.37),"2d3832")
		var lens = box(pitch,"Sensor",Vector3(-.23,.12,-.34),Vector3(.12,.12,.03),"67d4b2")
		lens.material_override = material("67d4b2",true)
		var flash = box(pitch,"MuzzleFlash",Vector3(0,0,-1.04),Vector3(.19,.19,.23),"ffcc67")
		flash.material_override = material("ffcc67",true)
		flash.visible = false
		actor.yaw = yaw
		actor.pitch = pitch
		actor.flash = flash
		actor.smoke = create_smoke(root)
	else:
		actor.body = collider(root,item)
		var panel = Node3D.new()
		panel.name = "BreakablePanel"
		root.add_child(panel)
		for x in [-Structures.GATE_WIDTH*.5+.145,Structures.GATE_WIDTH*.5-.145]:
			box(panel,"GatePost",Vector3(x,.525,0),Vector3(.28,1.05,.32),"343e46")
			box(panel,"PostCap",Vector3(x,1.06,0),Vector3(.34,.08,.37),"a4afb5")
		var intact = Node3D.new()
		intact.name = "IntactSteelwork"
		panel.add_child(intact)
		for x in range(-8,9):
			box(intact,"SteelBar",Vector3(x*(Structures.GATE_WIDTH-.6)/16,.48,0),Vector3(.14,.95,.17),"798791")
		for x in range(-8,9):
			for y in [.25,.76]:
				box(intact,"Rivet",Vector3(x*(Structures.GATE_WIDTH-.6)/16,y,.235),Vector3(.07,.07,.045),"a4afb5")
		for y in [.25,.76]: box(intact,"CrossRail",Vector3(0,y,.11),Vector3(Structures.GATE_WIDTH-.05,.17,.2),"58636b")
		var brace = box(intact,"DiagonalBrace",Vector3(0,.49,.22),Vector3(Structures.GATE_WIDTH-.6,.12,.14),"798791")
		brace.rotation.z = .09
		var damaged = Node3D.new()
		damaged.name = "DamagedSteelwork"
		panel.add_child(damaged)
		for x in range(-8,9):
			var shortened = x in [-4,-1,0,3,6]
			var bar = box(damaged,"BentBar",Vector3(x*(Structures.GATE_WIDTH-.6)/16,.4 if shortened else .48,.08*sin(x)),Vector3(.14,.48 if shortened else .9,.17),"58636b")
			bar.rotation.z = sin(x*2.3)*.32
			bar.rotation.x = cos(x*1.7)*.24
		for side in [-1.0,1.0]:
			var rail = box(damaged,"BuckledRail",Vector3(side*2.65,.64,.17),Vector3(5.0,.17,.2),"58636b")
			rail.rotation.z = side*.07
		box(damaged,"LowerRail",Vector3(0,.25,.11),Vector3(Structures.GATE_WIDTH-.05,.17,.2),"58636b")
		var hanging = box(damaged,"LooseBrace",Vector3(-1.8,.33,.25),Vector3(4.9,.12,.14),"798791")
		hanging.rotation.z = -.16
		damaged.visible = false
		actor.intact = intact
		actor.damaged = damaged
		actor.panel = panel
	actors[item.id] = actor
	return actor

func collision_rids(id: String) -> Array[RID]:
	var result: Array[RID] = []
	if actors.has(id) and actors[id].has("body"): result.append(actors[id].body.get_rid())
	return result

func sync(state: Dictionary) -> void:
	var clock: float = state.get("prop_clock",0.0)
	for item in state.get("structures",Structures.initial_state()):
		var actor: Dictionary = actors.get(item.id,{})
		if actor.is_empty(): actor = create_actor(item)
		if item.kind == "mine":
			actor.root.visible = not item.spent
			actor.led.visible = item.triggered and fmod(item.fuse,.4) < .2
			continue
		actor.body.collision_layer = 1 if item.hp > 0 else 0
		var collapse = clampf((clock-item.destroyed_at)/.8,0,1) if item.hp <= 0 else 0.0
		var damaged: bool = item.hp <= item.max_hp*DAMAGE_THRESHOLD
		if item.kind == "turret":
			actor.smoke.visible = damaged and item.hp > 0
			if actor.smoke.visible: update_smoke(actor.smoke,clock)
			actor.yaw.rotation.y = item.yaw
			actor.yaw.rotation.z = collapse*1.1
			actor.yaw.position = Vector3(collapse*.48,1.55-collapse*.95,0)
			actor.pitch.rotation.x = item.pitch-collapse*.35
			actor.flash.visible = item.hp > 0 and clock-item.get("fired_at",-1.0) < .055
			actor.pitch.position.z = .045*maxf(0,1-(clock-item.get("fired_at",-1.0))/.12) if item.hp > 0 else 0.0
		else:
			actor.intact.visible = not damaged
			actor.damaged.visible = damaged
			actor.panel.rotation.x = collapse*1.48
			# Keep fallen steel above the bridge planks instead of burying them.
			actor.panel.position.y = collapse*.18
