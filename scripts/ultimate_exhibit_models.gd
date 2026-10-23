extends RefCounted
## Display-only Demo weapons. These models add no attacks or inventory entries.
const Geometry = preload("res://scripts/exhibit_geometry.gd")

static func rocket_launcher() -> Node3D:
	var root = Node3D.new()
	root.name = "NeonRocketLauncher"
	root.set_meta("weapon_id","rocket_launcher")
	var g = Geometry.new()
	var tube = g.cylinder(root,"OctagonalLaunchTube",Vector3.ZERO,.215,1.72,"293b50",-1,0,.75,8)
	tube.rotation.x = PI/2
	for z in [-.77,-.46,.47,.76]:
		g.ring(root,"ReinforcedCollar",Vector3(0,0,z),.223,.033,"7c939e",0,true)
	g.cylinder(root,"RecessedMuzzle",Vector3(0,0,-.875),.176,.026,"050b12",-1,0,0,12).rotation.x = PI/2
	g.ring(root,"MuzzleLight",Vector3(0,0,-.89),.195,.014,"36e7ec",2,true)
	g.cylinder(root,"RearExhaust",Vector3(0,0,.91),.275,.22,"151d2b",.205,0,.65,8).rotation.x = PI/2
	for side in [-1,1]:
		g.box(root,"ProtectiveSideRail",Vector3(side*.225,.06,0),Vector3(.045,.13,1.04),"172333",0,.6)
		g.box(root,"CyanPowerConduit",Vector3(side*.254,.075,-.05),Vector3(.016,.032,.91),"34e5f1",2)
		for z in [-.25,-.10,.05]: g.box(root,"CoolingFin",Vector3(side*.25,-.035,z),Vector3(.055,.09,.035),"668b9b",0,.8)
	g.box(root,"ShoulderRest",Vector3(0,-.21,.55),Vector3(.30,.16,.50),"131c27")
	g.box(root,"RubberShoulderPad",Vector3(0,-.25,.79),Vector3(.34,.25,.09),"0b131b")
	g.box(root,"PistolGrip",Vector3(0,-.36,-.03),Vector3(.105,.30,.13),"17232e").rotation.x = -.18
	g.box(root,"TriggerGuard",Vector3(0,-.30,-.18),Vector3(.06,.15,.20),"8a9ba5",0,.8)
	g.box(root,"TriggerInset",Vector3(0,-.29,-.20),Vector3(.07,.085,.12),"101823")
	g.box(root,"ForwardGrip",Vector3(0,-.26,-.58),Vector3(.11,.18,.21),"131e2b")
	g.box(root,"TargetingRail",Vector3(0,.24,-.14),Vector3(.16,.08,.70),"667e90",0,.7)
	g.box(root,"OpticalSight",Vector3(0,.34,-.17),Vector3(.17,.14,.28),"182a3c",0,.65)
	g.box(root,"SightGlass",Vector3(0,.34,-.315),Vector3(.13,.10,.012),"63f5d9",1.5)
	g.box(root,"BatteryHousing",Vector3(.28,.02,.41),Vector3(.18,.22,.26),"35475b",0,.6)
	g.box(root,"ChargeReadout",Vector3(.375,.04,.40),Vector3(.014,.075,.16),"e26ce2",1.7)
	return root

static func crimson_scepter() -> Node3D:
	var root = Node3D.new()
	root.name = "CrimsonGothicScepter"
	root.set_meta("weapon_id","crimson_scepter")
	var g = Geometry.new()
	g.cylinder(root,"ObsidianShaft",Vector3(0,.15,0),.045,1.90,"191421",-1,0,.8,8)
	for y in [-.69,-.55,-.11,.05,.78,.97]:
		g.cylinder(root,"EngravedSilverCollar",Vector3(0,y,0),.067,.065,"837486",-1,0,.85,8)
	for i in 10:
		var y = -.45+i*.10
		var band = g.box(root,"CrimsonGripBinding",Vector3(0,y,.041),Vector3(.08,.023,.025),"72273b",0,.3)
		band.rotation.z = .45 if i%2 == 0 else -.45
	g.cylinder(root,"PommelSpike",Vector3(0,-.91,0),.065,.32,"a897a6",0,0,.8,8).rotation.z = PI
	g.cylinder(root,"CrownCup",Vector3(0,1.11,0),.09,.29,"5d3b50",.24,0,.8,8)
	g.ring(root,"GothicCrownRim",Vector3(0,1.27,0),.23,.032,"b59aa7")
	var orb = SphereMesh.new()
	orb.radius = .20
	orb.height = .40
	orb.radial_segments = 12
	orb.rings = 6
	g.mesh(root,"CrimsonHeart",orb,Vector3(0,1.46,0),g.material("e51f52",2.1,.2))
	for i in 6:
		var angle = TAU*i/6
		var radial = Vector3(cos(angle),0,sin(angle))
		g.rod(root,"CrownClawRoot",radial*.10+Vector3.UP*1.04,radial*.28+Vector3.UP*1.43,.026,"ad899c",0,.8)
		g.rod(root,"CrownClawPoint",radial*.28+Vector3.UP*1.43,radial*.12+Vector3.UP*1.79,.020,"c5a1b3",0,.8)
		g.rod(root,"BloodVein",radial*.048+Vector3.UP*.28,radial*.048+Vector3.UP*.80,.009,"e21d48",1.5)
	for side in [-1,1]:
		g.rod(root,"BatWing",Vector3(side*.06,.91,0),Vector3(side*.44,1.13,0),.037,"685266",0,.8)
		g.rod(root,"WingSpur",Vector3(side*.44,1.13,0),Vector3(side*.33,.91,.025),.024,"a38b9b",0,.7)
	return root
