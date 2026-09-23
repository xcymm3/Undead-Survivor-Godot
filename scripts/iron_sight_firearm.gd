extends Node3D
## Native furniture and working parts share the same sight coordinate system.
const Sight = preload("res://scripts/iron_sight.gd")
var weapon_id: String
var sight: Node3D
var slide: Node3D
var cover: Node3D
var muzzle_point: Vector3
var magazine: Node3D
var bolt: MeshInstance3D
var materials: Dictionary = {}

func _init(id := "pistol") -> void:
	weapon_id = id
	name = id.to_pascal_case()
	match id:
		"pistol": build_pistol()
		"p90": build_p90()
		"heavy-machine-gun": build_machine_gun()

func box(parent: Node3D, title: String, at: Vector3, size: Vector3, color: String, tilt := 0.0) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.name = title
	var shape = BoxMesh.new()
	shape.size = size
	node.mesh = shape
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

func pivot(title: String, at := Vector3.ZERO) -> Node3D:
	var node = Node3D.new()
	node.name = title
	node.position = at
	add_child(node)
	return node

func bevel(parent: Node3D, title: String, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var cut = minf(size.x,size.y)*.16
	var x = size.x*.5
	var y = size.y*.5
	var outline = PackedVector2Array([Vector2(-x,-y+cut),Vector2(-x+cut,-y),Vector2(x-cut,-y),Vector2(x,-y+cut),Vector2(x,y-cut),Vector2(x-cut,y),Vector2(-x+cut,y),Vector2(-x,y-cut)])
	var node = box(parent,title,at,size,color)
	node.mesh = Sight.extrude(outline,size.z)
	return node

func tube(parent: Node3D, title: String, at: Vector3, radius: float, length: float, color: String) -> MeshInstance3D:
	var node = box(parent,title,at,Vector3.ONE,color)
	var shape = CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = length
	shape.radial_segments = 12
	node.mesh = shape
	node.rotation.x = PI*.5
	return node

func build_pistol() -> void:
	bevel(self,"Frame",Vector3(0,.014,-.16),Vector3(.12,.092,.48),"3b4546")
	bevel(self,"DustCover",Vector3(0,-.022,-.31),Vector3(.105,.054,.20),"303b3b")
	box(self,"Grip",Vector3(0,-.142,.015),Vector3(.113,.245,.14),"353e3b",-.23)
	for side in [-1,1]:
		bevel(self,"GripPanel",Vector3(side*.058,-.14,.024),Vector3(.012,.17,.10),"222c2a")
		for y in [-.20,-.17,-.14,-.11]: box(self,"GripTexture",Vector3(side*.065,y,.024),Vector3(.003,.005,.083),"4b5550")
	box(self,"GuardBottom",Vector3(0,-.12,-.134),Vector3(.024,.023,.16),"3b4546")
	box(self,"GuardFront",Vector3(0,-.067,-.205),Vector3(.026,.12,.025),"3b4546",-.12)
	box(self,"Trigger",Vector3(0,-.064,-.109),Vector3(.016,.067,.02),"6a7470",-.2)
	tube(self,"Barrel",Vector3(0,.081,-.276),.027,.35,"616b69")
	muzzle_point = Vector3(0,.081,-.457)
	tube(self,"Bore",muzzle_point,.018,.005,"111a1c")
	slide = pivot("Slide")
	bevel(slide,"SlideHousing",Vector3(0,.102,-.183),Vector3(.123,.112,.53),"586260")
	box(slide,"EjectionPort",Vector3(.062,.121,-.14),Vector3(.003,.033,.10),"202b2b")
	for side in [-1,1]:
		for z in [.01,.026,.042,.058]: box(slide,"SlideSerration",Vector3(side*.062,.093,z),Vector3(.003,.053,.005),"303b3b")
	sight = Sight.new(.218,.051,-.411,.092,.019,.024,.012,.158)
	slide.add_child(sight)
	magazine = pivot("Magazine")
	bevel(magazine,"MagazineBody",Vector3(0,-.17,.012),Vector3(.087,.19,.104),"606966")
	bevel(magazine,"MagazineBase",Vector3(0,-.27,.040),Vector3(.125,.024,.151),"202a29")

func build_p90() -> void:
	# Bullpup stock, thumbhole and horizontal magazine retain the P90 silhouette.
	bevel(self,"UpperBody",Vector3(0,-.017,-.10),Vector3(.18,.16,.70),"414d40")
	bevel(self,"Butt",Vector3(0,-.095,.205),Vector3(.183,.30,.14),"3c473b")
	bevel(self,"ButtPad",Vector3(0,-.095,.282),Vector3(.19,.30,.026),"252e2b")
	bevel(self,"Grip",Vector3(0,-.171,-.046),Vector3(.115,.22,.11),"465144")
	bevel(self,"ThumbholeFloor",Vector3(0,-.269,.092),Vector3(.14,.036,.30),"3b473b")
	bevel(self,"Foregrip",Vector3(0,-.12,-.335),Vector3(.15,.20,.16),"424f42")
	box(self,"GuardFloor",Vector3(0,-.232,-.199),Vector3(.05,.031,.21),"354136")
	box(self,"Trigger",Vector3(0,-.13,-.12),Vector3(.02,.06,.025),"757e69",-.18)
	magazine = pivot("TopMagazine")
	bevel(magazine,"MagazineShell",Vector3(0,.092,.035),Vector3(.14,.063,.45),"756c48")
	for z in [-.16,-.11,-.06,-.01,.04,.09,.14,.19,.24]:
		box(magazine,"MagazineRib",Vector3(0,.127,z),Vector3(.126,.008,.01),"9c8e60")
	for z in [-.202,.272]: bevel(magazine,"MagazineCap",Vector3(0,.095,z),Vector3(.148,.07,.04),"333e38")
	# The compact bridge sits ahead of the magazine, leaving its upward reload path free.
	for z in [-.25,-.414]: bevel(self,"SightFoot",Vector3(0,.110,z),Vector3(.074,.094,.055),"3a4540")
	bevel(self,"SightRail",Vector3(0,.169,-.342),Vector3(.085,.024,.25),"4b5650")
	sight = Sight.new(.243,-.243,-.434,.10,.020,.025,.013,.181)
	add_child(sight)
	tube(self,"Barrel",Vector3(0,.01,-.49),.03,.14,"555f58")
	tube(self,"MuzzleCollar",Vector3(0,.01,-.553),.04,.046,"333e3a")
	muzzle_point = Vector3(0,.01,-.579)
	tube(self,"Bore",muzzle_point,.021,.005,"101a18")
	bolt = box(self,"ChargingHandle",Vector3(.112,.062,-.31),Vector3(.067,.029,.073),"687366")
	for side in [-1,1]: box(self,"BodySeam",Vector3(side*.091,-.013,-.16),Vector3(.003,.011,.44),"27332e")

func build_machine_gun() -> void:
	bevel(self,"Receiver",Vector3(0,-.026,-.30),Vector3(.26,.25,.56),"3b4545")
	cover = pivot("FeedCover",Vector3(0,.104,-.54))
	bevel(cover,"CoverPlate",Vector3(0,.019,.18),Vector3(.24,.055,.37),"59615b")
	for z in [.06,.14,.22,.30]: box(cover,"CoverRib",Vector3(0,.05,z),Vector3(.212,.008,.018),"70776a")
	# Rear sight bolts to a fixed receiver bridge behind the hinged feed cover.
	bevel(self,"RearSightBridge",Vector3(0,.137,-.103),Vector3(.22,.08,.104),"46504c")
	bevel(self,"StockNeck",Vector3(0,-.05,.055),Vector3(.135,.12,.18),"434c45")
	bevel(self,"Stock",Vector3(0,-.092,.23),Vector3(.18,.20,.25),"525942")
	bevel(self,"ButtPad",Vector3(0,-.092,.369),Vector3(.19,.215,.028),"252e2b")
	box(self,"Grip",Vector3(0,-.224,-.01),Vector3(.105,.22,.12),"343d32",-.22)
	box(self,"TriggerGuard",Vector3(0,-.226,-.14),Vector3(.026,.024,.15),"576057")
	box(self,"GuardFront",Vector3(0,-.177,-.211),Vector3(.026,.12,.025),"576057")
	tube(self,"HeavyBarrel",Vector3(0,.015,-.865),.041,.63,"414c4b")
	tube(self,"CoolingJacket",Vector3(0,.015,-.664),.067,.23,"59615b")
	for z in [-.59,-.64,-.69,-.74]: tube(self,"CoolingRing",Vector3(0,.015,z),.073,.013,"343f3e")
	tube(self,"MuzzleBrake",Vector3(0,.015,-1.166),.06,.081,"5d6661")
	muzzle_point = Vector3(0,.015,-1.209)
	tube(self,"Bore",muzzle_point,.03,.005,"121c1c")
	bevel(self,"FrontSightTower",Vector3(0,.127,-1.052),Vector3(.074,.18,.066),"46504c")
	sight = Sight.new(.270,-.107,-1.052,.116,.025,.030,.017,.174)
	add_child(sight)
	for side in [-1,1]:
		var ear = box(self,"FrontGuard",Vector3(side*.035,.244,-1.052),Vector3(.012,.067,.048),"5f6961")
		ear.rotation.z = side*-.14
	magazine = pivot("BeltBox")
	bevel(magazine,"AmmoBox",Vector3(-.16,-.27,-.28),Vector3(.28,.30,.27),"596046")
	box(magazine,"BoxLid",Vector3(-.16,-.112,-.28),Vector3(.296,.027,.282),"72785b")
	for i in 6:
		var at = Vector3(-.25+i*.031,.005-sin(float(i)/5*PI)*.02,-.22)
		tube(magazine,"BeltRound",at,.014,.10,"a18d58")
		box(magazine,"BeltLink",at,Vector3(.02,.035,.024),"3d4742")
	bolt = box(self,"ChargingHandle",Vector3(.165,.011,-.22),Vector3(.10,.026,.052),"7c8476")

func pose(reloading: bool, progress: float, recoil: float) -> void:
	var lift = sin(progress*PI) if reloading else 0.0
	var kick = sin((1-clampf(recoil,0,1))*PI) if recoil > 0 else 0.0
	match weapon_id:
		"pistol":
			slide.position.z = kick*.07
			magazine.position = Vector3(0,-.27,.045)*lift
			magazine.rotation.x = -.16*lift
		"p90":
			magazine.position = Vector3(.04,.18,.07)*lift
			magazine.rotation.x = -.20*lift
			bolt.position.z = -.31+kick*.025
		"heavy-machine-gun":
			cover.rotation.x = -.85*lift
			magazine.position = Vector3(-.14,-.22,.06)*lift
			bolt.position.z = -.22+kick*.065
