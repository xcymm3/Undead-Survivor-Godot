extends Node3D
## First-person-only articulated revolver without arms or hands. Never owns ammunition.
const MUZZLE = Vector3(0,.095,-.71)
const SUPPORT = Vector3(-.035,-.165,.22)
var gun: Node3D
var drum: Node3D
var crane: MeshInstance3D
var hammer: Node3D
var trigger: Node3D
var ejector: Node3D
var loader: Node3D
var shells: Node3D
var loader_anchor: Node3D
var materials: Dictionary = {}
var last_reload = false
var cancel_time = 0.0
var cancel_phase = 0.0
var previous_phase = 0.0
var motion = 0.0
var stride = 0.0
var sway = Vector2.ZERO
var previous_pos = Vector2.ZERO
var previous_angles = Vector2.ZERO
var tracked_id = ""
var preview_speed = -1.0
var preview_stride = 0.0
var state_name = "idle"
var cylinder_open = 0.0
var sight: Node3D

func material(color: String, metal := false) -> StandardMaterial3D:
	if not materials.has(color):
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(color)
		m.roughness = .38 if metal else .85
		m.metallic = .55 if metal else 0.0
		materials[color] = m
	return materials[color]

func mesh(parent: Node3D, title: String, shape: Mesh, at: Vector3, color: String, metal := false) -> MeshInstance3D:
	var part = MeshInstance3D.new()
	part.name = title
	part.mesh = shape
	part.position = at
	part.material_override = material(color,metal)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.layers = 2
	parent.add_child(part)
	return part

func box(parent: Node3D, title: String, at: Vector3, size: Vector3, color: String, metal := false) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = size
	return mesh(parent,title,shape,at,color,metal)

func tube(parent: Node3D, title: String, at: Vector3, radius: float, length: float, color: String, metal := false) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = length
	shape.radial_segments = 12
	var part = mesh(parent,title,shape,at,color,metal)
	part.rotation.x = PI/2
	return part

func segment(parent: Node3D, title: String, a: Vector3, b: Vector3, radius: float, color: String) -> MeshInstance3D:
	var shape = CapsuleMesh.new()
	shape.radius = radius
	shape.height = a.distance_to(b)+radius*2
	shape.radial_segments = 8
	shape.rings = 3
	var part = mesh(parent,title,shape,(a+b)/2,color)
	part.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return part

func pivot(parent: Node3D, title: String, at := Vector3.ZERO) -> Node3D:
	var node = Node3D.new()
	node.name = title
	node.position = at
	parent.add_child(node)
	return node

func _init() -> void:
	name = "RevolverFirstPerson"
	gun = pivot(self,"GunAndGrip")
	box(gun,"Frame",Vector3(0,.04,.005),Vector3(.135,.18,.17),"535e69",true)
	box(gun,"TopStrap",Vector3(0,.158,-.15),Vector3(.105,.028,.39),"65717e",true)
	tube(gun,"OctagonalBarrel",Vector3(0,.095,-.49),.046,.44,"647382",true)
	box(gun,"Underlug",Vector3(0,.033,-.46),Vector3(.075,.065,.43),"424e5b",true)
	tube(gun,"Crown",MUZZLE,.048,.022,"909ba5",true)
	tube(gun,"Bore",MUZZLE+Vector3(0,0,-.012),.027,.003,"111923")
	sight = preload("res://scripts/iron_sight.gd").new(.222,.035,-.67,.088,.017,.024,.012,.172)
	gun.add_child(sight)
	# Seat the blade on the barrel rib instead of leaving it suspended over the bore.
	box(gun,"FrontSightRib",Vector3(0,.154,-.647),Vector3(.045,.038,.103),"65717e",true)
	var grip = box(gun,"RubberGrip",Vector3(0,-.11,.095),Vector3(.105,.21,.13),"252d38")
	grip.rotation.x = -.22
	for side in [-1,1]:
		box(gun,"GripPanel",Vector3(side*.056,-.115,.10),Vector3(.011,.145,.102),"3f4a55")
		for y in [-.19,-.16,-.13,-.10]: box(gun,"GripCheckering",Vector3(side*.063,y,.11),Vector3(.004,.005,.08),"202a35")
		box(gun,"FrameScrew",Vector3(side*.07,.018,.037),Vector3(.008,.016,.016),"a4abb0",true)
	box(gun,"CylinderLatch",Vector3(-.076,.05,.045),Vector3(.018,.03,.05),"929ca3",true)
	segment(gun,"GuardFront",Vector3(0,-.06,-.135),Vector3(0,-.145,-.13),.014,"606d78")
	segment(gun,"GuardBottom",Vector3(0,-.145,-.13),Vector3(0,-.155,-.015),.014,"606d78")
	trigger = pivot(gun,"Trigger",Vector3(0,-.057,-.055))
	segment(trigger,"TriggerBlade",Vector3.ZERO,Vector3(0,-.065,-.015),.011,"959fa7")
	hammer = pivot(gun,"Hammer",Vector3(0,.10,.088))
	box(hammer,"HammerSpur",Vector3(0,.04,.025),Vector3(.035,.075,.048),"89959f",true)
	drum = pivot(gun,"SwingOutCylinder",Vector3(0,.065,-.16))
	crane = segment(gun,"CylinderCrane",Vector3.ZERO,Vector3.UP,.014,"8695a4")
	tube(drum,"Cylinder",Vector3.ZERO,.092,.21,"596775",true)
	for i in 6:
		var angle = TAU*i/6
		var radial = Vector3(cos(angle),sin(angle),0)*.055
		tube(drum,"Chamber",radial+Vector3(0,0,.108),.022,.005,"151e28")
		tube(drum,"Flute",radial.normalized()*.089,.012,.14,"394552",true)
		tube(drum,"CartridgeHead"+str(i),radial+Vector3(0,0,.112),.017,.006,"b99d58",true)
	ejector = pivot(drum,"Ejector")
	tube(ejector,"EjectorRod",Vector3(0,0,-.15),.012,.2,"abb3b7",true)
	tube(ejector,"ExtractorStar",Vector3(0,0,.12),.031,.012,"9ba6ac",true)
	shells = pivot(gun,"EjectedCases")
	for i in 6:
		var a = TAU*i/6
		tube(shells,"Case",Vector3(cos(a)*.055,sin(a)*.055,0),.017,.105,"c6a367",true)
	loader_anchor = pivot(gun,"LoaderAnchor")
	loader = pivot(loader_anchor,"Speedloader",Vector3(0,.012,-.105))
	tube(loader,"LoaderHandle",Vector3(0,0,.02),.028,.09,"252f3e")
	tube(loader,"LoaderDisc",Vector3(0,0,-.018),.084,.027,"4b5b69",true)
	for i in 6:
		var a = TAU*i/6
		tube(loader,"FreshRound"+str(i),Vector3(cos(a)*.055,sin(a)*.055,-.09),.017,.12,"c4a369",true)
	sample_pose(0.0,false,0.0,0.0,0)

func curve(t: float, times: Array, values: Array) -> Vector3:
	for i in range(times.size()-1):
		if t <= times[i+1]: return values[i].lerp(values[i+1],smoothstep(times[i],times[i+1],t))
	return values.back()

func sample_pose(t: float, reload_active: bool, fire: float, aim: float, shots: int) -> void:
	var amount = smoothstep(0.0,.15,t)*(1-smoothstep(.80,1.0,t)) if reload_active else 0.0
	gun.position = Vector3(-.055,.075,.10)*amount
	gun.rotation = Vector3(.18,-.28,.55)*amount
	var kick = exp(-fire*9)*sin(minf(fire*8,PI)) if fire > 0 else 0.0
	gun.position.z += kick*.065
	gun.rotation.x += kick*.23
	gun.rotation.z -= kick*.025
	cylinder_open = smoothstep(.10,.23,t)*(1-smoothstep(.78,.88,t)) if reload_active else 0.0
	drum.position = Vector3(-.245*cylinder_open,.065-.012*cylinder_open,-.16)
	var base = Vector3(-.06,-.04,-.09)
	var end = drum.position+Vector3(0,-.077,.05)
	crane.position = (base+end)/2
	crane.quaternion = Quaternion(Vector3.UP,(end-base).normalized())
	crane.scale.y = base.distance_to(end)/1.028
	drum.rotation.z = -shots*TAU/6
	hammer.rotation.x = -.55*(1-smoothstep(0.0,.12,fire)) if fire > 0 else -.08
	trigger.rotation.x = -.3*kick
	ejector.position.z = .085*sin(PI*clampf((t-.25)/.16,0,1)) if reload_active else 0.0
	shells.visible = reload_active and t >= .30 and t < .49
	var fall = clampf((t-.30)/.19,0,1)
	shells.position = drum.position+Vector3(-.09*fall,-.5*fall*fall,.14+.35*fall)
	shells.rotation = Vector3(fall*.6,0,fall)
	for part in drum.get_children():
		if str(part.name).begins_with("CartridgeHead"): part.visible = not reload_active or t < .31 or t >= .67
	var loader_pos = SUPPORT
	var loader_rot = Vector3(.08,-.25,-.18)
	if reload_active:
		var times = [0.0,.10,.22,.32,.43,.51,.61,.69,.76,.86,1.0]
		loader_pos = curve(t,times,[SUPPORT,Vector3(-.08,.02,.12),Vector3(-.24,.01,-.10),Vector3(-.24,.01,-.25),Vector3(-.52,-.50,.32),Vector3(-.48,-.36,.40),Vector3(-.245,.04,.20),Vector3(-.245,.04,.11),Vector3(-.42,-.23,.30),Vector3(-.18,-.01,.02),SUPPORT])
		loader_rot = curve(t,times,[loader_rot,Vector3(.1,-.2,.1),Vector3(.25,0,.3),Vector3(.25,0,.3),Vector3(.3,-.5,-.4),Vector3(.1,-.2,-.2),Vector3.ZERO,Vector3.ZERO,Vector3(.2,-.2,-.3),Vector3(0,-.2,-.25),loader_rot])
	loader.visible = reload_active and t >= .48 and t < .77
	for part in loader.get_children():
		if str(part.name).begins_with("FreshRound"): part.visible = t < .67
	loader_anchor.position = loader_pos
	loader_anchor.rotation = loader_rot
	state_name = "reload" if reload_active else "fire" if fire > 0 else "aim" if aim > .5 else "walk" if motion > .1 else "idle"

func reset_motion() -> void:
	tracked_id = ""
	last_reload = false
	cancel_time = 0.0
	previous_phase = 0.0
	motion = 0.0
	sway = Vector2.ZERO

func sync_pose(p: Dictionary, dt: float, elapsed: float, aim: float) -> void:
	var angles = Vector2(float(p.get("yaw",0)),float(p.get("pitch",0)))
	var pos: Vector2 = p.pos
	if tracked_id != str(p.id):
		tracked_id = str(p.id)
		previous_pos = pos
		previous_angles = angles
	var speed = minf(5.0,pos.distance_to(previous_pos)/maxf(dt,.001))
	if preview_speed >= 0: speed = preview_speed
	motion = lerpf(motion,speed,1-exp(-dt*12))
	stride += motion*dt*3.1
	if preview_speed >= 0: stride = preview_stride
	var turn = Vector2(angle_difference(previous_angles.x,angles.x),angles.y-previous_angles.y)/maxf(dt,.001)
	sway = sway.lerp(turn.limit_length(3.0),1-exp(-dt*10))
	previous_pos = pos
	previous_angles = angles
	var phase = clampf(1-float(p.reload)/Data.weapons[3].reloadDuration,0,1) if p.reloading else 0.0
	if last_reload and not p.reloading and previous_phase < .97:
		cancel_time = .13
		cancel_phase = previous_phase
	var cancellation = cancel_time > 0 and not p.reloading
	if cancellation:
		phase = lerpf(cancel_phase,1.0,1-cancel_time/.13)
		cancel_time = maxf(0,cancel_time-dt)
	var fire = clampf(1-float(p.fire_anim)/Data.weapons[3].fireDuration,0.001,1) if p.fire_anim > 0 else 0.0
	sample_pose(phase,p.reloading or cancellation,fire,aim,int(p.get("shots",0)))
	var strength = minf(motion/4.2,1.0)*(1-aim*.88)*(0.2 if p.reloading else 1.0)
	position = Vector3(sin(stride)*.014,absf(cos(stride))*.013,-absf(sin(stride))*.008)*strength
	position.y += sin(elapsed*1.7)*.002*(1-aim)
	rotation = Vector3(-sway.y*.012,-sway.x*.013,sin(stride)*.013*strength+sway.x*.006)*(1-aim*.75)
	if p.switch > 0:
		rotation.z -= sin((1-p.switch/.4)*PI)*.3
		state_name = "switch"
	if cancellation: state_name = "cancel"
	if p.hp <= 0: visible = false
	last_reload = p.reloading
	previous_phase = phase
