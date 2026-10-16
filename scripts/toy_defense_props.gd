extends RefCounted
const Toy = preload("res://scripts/toy_art.gd")

static func mine(owner: Node3D, root: Node3D, actor: Dictionary) -> void:
	root.set_meta("art_style","toy")
	Toy.cylinder(root,"MineBase",Vector3(0,.12,0),.66,.24,Toy.BLUE)
	Toy.cylinder(root,"ArmoredCase",Vector3(0,.25,0),.59,.18,Toy.CORAL)
	Toy.cylinder(root,"WarningRim",Vector3(0,.35,0),.52,.045,Toy.YELLOW)
	Toy.cylinder(root,"PressureCap",Vector3(0,.395,0),.40,.075,Toy.CREAM)
	for i in 8:
		var angle = TAU*i/8.0
		Toy.cylinder(root,"CaseBolt%d" % i,Vector3(cos(angle)*.53,.36,sin(angle)*.53),.045,.055,Toy.YELLOW)
	for x in [-.19,.19]:
		for z in [-.17,.17]: Toy.cylinder(root,"ToyStud",Vector3(x,.448,z),.07,.05,Toy.MINT)
	for side in [-1.0,1.0]:
		Toy.oval(root,"CarryMount",Vector3(side*.64,.19,0),Vector3(.22,.19,.35),Toy.BLUE)
	Toy.box(root,"FuseHousing",Vector3(0,.46,0),Vector3(.20,.14,.24),Toy.INK)
	actor.led = Toy.cylinder(root,"FuseLight",Vector3(0,.56,0),.095,.09,"79e7a1")
	var light = OmniLight3D.new()
	light.name = "ArmedIndicator"
	light.position = Vector3(0,.67,0)
	light.omni_range = 1.8
	light.shadow_enabled = false
	root.add_child(light)
	actor.light = light

static func turret(owner: Node3D, root: Node3D, actor: Dictionary) -> void:
	root.set_meta("art_style","toy")
	actor.body = owner.collider(root,{"kind":"turret"})
	Toy.box(root,"AnchorPlate",Vector3(0,.12,0),Vector3(1.3,.24,1.3),Toy.BLUE)
	Toy.box(root,"BaseTrim",Vector3(0,.27,0),Vector3(1.16,.08,1.16),Toy.CREAM)
	for x in [-.43,.43]:
		for z in [-.43,.43]: Toy.cylinder(root,"ToyStud",Vector3(x,.35,z),.115,.10,Toy.YELLOW)
	Toy.cylinder(root,"Pedestal",Vector3(0,.80,0),.27,1.0,Toy.CORAL)
	Toy.cylinder(root,"Turntable",Vector3(0,1.29,0),.42,.18,Toy.YELLOW)
	var yaw = Node3D.new()
	yaw.name = "TrackingHead"
	yaw.position.y = 1.55
	root.add_child(yaw)
	var pitch = Node3D.new()
	yaw.add_child(pitch)
	var intact = Node3D.new()
	intact.name = "IntactHousing"
	pitch.add_child(intact)
	Toy.oval(intact,"Receiver",Vector3(0,.04,.08),Vector3(.95,.69,.93),Toy.BLUE)
	Toy.box(intact,"FacePanel",Vector3(0,.02,-.31),Vector3(.65,.35,.16),Toy.CREAM)
	for side in [-1.0,1.0]:
		var knob = Toy.cylinder(intact,"WindingKnob",Vector3(side*.49,.06,.12),.19,.12,Toy.YELLOW)
		knob.rotation.z = PI/2
	Toy.box(intact,"AmmunitionBox",Vector3(.47,-.15,.22),Vector3(.29,.36,.48),Toy.CORAL)
	Toy.label(intact,"ToyNumber","01",Vector3(0,.16,.545),.003)
	var damaged = Node3D.new()
	damaged.name = "DamagedHousing"
	pitch.add_child(damaged)
	Toy.box(damaged,"ExposedMechanism",Vector3(0,-.10,.08),Vector3(.67,.26,.7),Toy.INK)
	for x in [-.20,.20]: Toy.cylinder(damaged,"LooseStud",Vector3(x,.08,.13),.11,.15,Toy.YELLOW)
	var loose = Toy.box(damaged,"LoosePlasticShell",Vector3(-.25,.24,.10),Vector3(.39,.12,.70),Toy.BLUE)
	loose.rotation.z = -.55
	var cover = Toy.box(damaged,"HangingSideCover",Vector3(.47,-.30,.18),Vector3(.1,.42,.46),Toy.CORAL)
	cover.rotation.z = -.4
	damaged.visible = false
	Toy.box(pitch,"Barrel",Vector3(0,0,-.61),Vector3(.21,.21,.77),Toy.INK)
	actor.shroud = Toy.box(pitch,"BarrelShroud",Vector3(0,0,-.38),Vector3(.34,.34,.34),Toy.CREAM)
	for z in [-.56,-.74,-.93]:
		var ring = Toy.cylinder(pitch,"SafetyMuzzleRing",Vector3(0,0,z),.175,.09,Toy.CORAL if z == -.93 else Toy.YELLOW)
		ring.rotation.x = PI/2
	var lens = Toy.box(pitch,"Sensor",Vector3(-.24,.18,-.38),Vector3(.14,.12,.045),Toy.MINT)
	lens.material_override = owner.material("67d4b2",true)
	var flash = Toy.box(pitch,"MuzzleFlash",Vector3(0,0,-1.04),Vector3(.07,.07,.10),Toy.YELLOW)
	flash.material_override = owner.material("ffcc67",true)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	actor.merge({"yaw":yaw,"pitch":pitch,"intact":intact,"damaged":damaged,"sensor":lens,"flash":flash,"smoke":owner.create_smoke(root)})
