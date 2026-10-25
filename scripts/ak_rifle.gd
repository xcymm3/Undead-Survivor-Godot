extends Node3D
## Original low-poly AK-style mesh, shared by first- and third-person views.
const MUZZLE = Vector3(0,.055,-1.03)
const RIGHT_GRIP = Vector3(0,-.17,.075)
const LEFT_GRIP = Vector3(-.025,-.04,-.52)
var magazine: Node3D
var bolt: MeshInstance3D
var materials: Dictionary = {}

func _init() -> void:
	name = "AK47"
	# Stamped receiver, raised dust cover and visible right-side charging handle.
	box(self,"Receiver",Vector3(0,.015,-.16),Vector3(.145,.16,.48),"303638")
	box(self,"DustCover",Vector3(0,.108,-.16),Vector3(.13,.055,.42),"495052")
	box(self,"EjectionPort",Vector3(.074,.035,-.13),Vector3(.006,.055,.19),"151b1c")
	bolt = box(self,"ChargingHandle",Vector3(.11,.047,-.11),Vector3(.09,.025,.055),"677071")
	box(self,"SafetyLever",Vector3(.078,-.01,-.09),Vector3(.012,.025,.23),"737774",-.12)
	for z in [-.29,-.01]: box(self,"ReceiverRivet",Vector3(.08,-.027,z),Vector3(.012,.014,.014),"9b9e92")
	# Warm wooden furniture, separate from the blued steel barrel/gas tube.
	box(self,"LowerHandguard",Vector3(0,-.005,-.53),Vector3(.17,.14,.28),"a16036")
	box(self,"UpperHandguard",Vector3(0,.107,-.51),Vector3(.125,.075,.24),"bd7844")
	for z in [-.60,-.55,-.50]:
		box(self,"WoodGroove",Vector3(.086,.005,z),Vector3(.007,.09,.012),"70452c")
	box(self,"FrontBand",Vector3(0,.014,-.677),Vector3(.18,.17,.038),"3b4243")
	box(self,"Barrel",Vector3(0,.055,-.825),Vector3(.056,.056,.32),"343c3f")
	box(self,"GasTube",Vector3(0,.132,-.73),Vector3(.048,.045,.25),"525b5a")
	box(self,"GasBlock",Vector3(0,.10,-.86),Vector3(.075,.14,.05),"30383b")
	box(self,"MuzzleBrake",Vector3(0,.055,-1.005),Vector3(.079,.075,.075),"565e5f")
	box(self,"Bore",MUZZLE+Vector3(0,0,-.014),Vector3(.042,.042,.004),"101718")
	box(self,"FrontSightBase",Vector3(0,.135,-.942),Vector3(.07,.14,.048),"343b3d")
	for x in [-.04,.04]: box(self,"FrontSightEar",Vector3(x,.21,-.942),Vector3(.016,.067,.035),"59615f")
	box(self,"FrontSightPost",Vector3(0,.195,-.942),Vector3(.009,.045,.018),"9fa48e")
	for x in [-.036,.036]: box(self,"RearSightNotch",Vector3(x,.174,-.355),Vector3(.037,.027,.04),"606966")
	box(self,"RearSightRamp",Vector3(0,.137,-.32),Vector3(.115,.04,.13),"454d4c")
	box(self,"StockNeck",Vector3(0,-.005,.15),Vector3(.115,.11,.22),"855030",-.08)
	box(self,"WoodStock",Vector3(0,-.055,.37),Vector3(.15,.20,.34),"a96539",-.12)
	box(self,"StockButt",Vector3(0,-.075,.55),Vector3(.165,.225,.034),"303637",-.12)
	box(self,"PistolGrip",RIGHT_GRIP,Vector3(.105,.235,.115),"955a36",-.27)
	box(self,"GripCap",RIGHT_GRIP+Vector3(0,-.118,.034),Vector3(.11,.026,.12),"3a3730",-.27)
	box(self,"Trigger",Vector3(0,-.116,-.053),Vector3(.016,.065,.022),"747b73",-.25)
	box(self,"TriggerGuardBottom",Vector3(0,-.152,-.04),Vector3(.027,.021,.135),"313939")
	box(self,"TriggerGuardFront",Vector3(0,-.108,-.108),Vector3(.027,.10,.023),"313939")
	# A stepped arc and longitudinal ribs give the distinctive curved magazine silhouette.
	magazine = Node3D.new()
	magazine.name = "CurvedMagazine"
	add_child(magazine)
	for i in 5:
		var t = float(i)/4
		var center = Vector3(0,-.13-t*.28,-.25-t*t*.10)
		box(magazine,"MagazineSegment",center,Vector3(.104,.082,.18),"333b3c",t*.43)
		for side in [-1,1]:
			for z in [-.05,.025]: box(magazine,"MagazineRib",center+Vector3(side*.055,0,z),Vector3(.012,.078,.017),"58605c",t*.43)
	box(magazine,"Floorplate",Vector3(0,-.447,-.356),Vector3(.122,.025,.19),"68706a",.43)

func box(parent: Node3D, title: String, at: Vector3, size: Vector3, color: String, tilt := 0.0) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.name = title
	var mesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.rotation.x = tilt
	if not materials.has(color):
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(color)
		material.roughness = .8
		materials[color] = material
	node.material_override = materials[color]
	parent.add_child(node)
	return node

func pose(reloading: bool, progress: float, recoil: float) -> void:
	magazine.position = Vector3(0,-.30*sin(progress*PI),.07*sin(progress*PI)) if reloading else Vector3.ZERO
	magazine.rotation.x = -.12*sin(progress*PI) if reloading else 0.0
	bolt.position.z = -.11+recoil*.05
