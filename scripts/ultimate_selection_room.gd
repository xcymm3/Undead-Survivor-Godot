extends Node3D
## An independent, walkable scene above the defense world, with its own collisions.
const Geometry = preload("res://scripts/exhibit_geometry.gd")
const Weapons = preload("res://scripts/weapon_models.gd")
const WIDTH = 24.0
const DEPTH = 14.0
const SPAWN = Vector3(0,.04,5.8)
const EXHIBITS = [
	{"id":"rocket_launcher","label":"火箭炮","x":-8.0,"color":"39e1ec","available":false},
	{"id":"blade","label":"长刀","x":0.0,"color":"8cbfeb","available":true},
	{"id":"crimson_scepter","label":"猩红权杖","x":8.0,"color":"f04c72","available":false}
]
var g = Geometry.new()
var player
var exhibits: Dictionary = {}
var room_environment: Environment
var clock = 0.0

func _ready() -> void:
	name = "UltimateSelectionRoom"
	build_shell()
	build_tech()
	build_ancient()
	build_gothic()
	for item in EXHIBITS: build_exhibit(item)
	player = preload("res://scripts/player_body.gd").new()
	player.name = "Visitor"
	add_child(player)
	player.position = SPAWN
	room_environment = Environment.new()
	room_environment.background_mode = Environment.BG_COLOR
	room_environment.background_color = Color("070b14")
	room_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	room_environment.ambient_light_color = Color("9eabca")
	room_environment.ambient_light_energy = .48
	room_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-65,-25,0)
	fill.light_color = Color("d9dfed")
	fill.light_energy = .55
	fill.shadow_enabled = false
	add_child(fill)

func build_shell() -> void:
	g.solid(self,"Foundation",Vector3(0,-.22,0),Vector3(WIDTH,.44,DEPTH),"111524")
	g.solid(self,"Ceiling",Vector3(0,6.9,0),Vector3(WIDTH,.3,DEPTH),"101522")
	g.solid(self,"EntryWall",Vector3(0,3.4,7),Vector3(WIDTH,6.8,.35),"172030")
	for side in [-1,1]:
		g.solid(self,"SideWall",Vector3(side*12,3.4,0),Vector3(.35,6.8,DEPTH),"141c2a")
	for i in range(-5,6):
		g.box(self,"ThresholdSlab",Vector3(i*2.1,.015,4.8),Vector3(2.04,.03,3.6),"263044")
	for x in [-4.0,4.0]:
		g.solid(self,"DivisionFin",Vector3(x,3.1,-4.35),Vector3(.35,6.2,5.3),"080d19")
		g.box(self,"DivisionBlade",Vector3(x,3.1,-1.65),Vector3(.13,6.2,.12),"b2bdcc",.25)
	g.box(self,"ThresholdLine",Vector3(0,.04,3),Vector3(23,.025,.05),"9ba9be",.3)
	for item in EXHIBITS:
		var x: float = item.x
		g.solid(self,"ZoneFloor",Vector3(x,.025,-1.8),Vector3(7.65,.05,10.0),["142533","263b58","301521"][EXHIBITS.find(item)])
		g.solid(self,"ZoneBack",Vector3(x,3.4,-6.9),Vector3(7.8,6.8,.35),["111b2d","142842","211120"][EXHIBITS.find(item)])
		var light = OmniLight3D.new()
		light.name = str(item.id)+"Light"
		light.position = Vector3(x,4.3,-2.7)
		light.light_color = Color(item.color)
		light.light_energy = 2.8
		light.omni_range = 7.0
		light.omni_attenuation = 1.3
		add_child(light)

func build_tech() -> void:
	var bay = Node3D.new()
	bay.name = "NeonTechnology"
	bay.position.x = -8
	add_child(bay)
	for side in [-1,1]:
		g.box(bay,"SteelGantry",Vector3(side*3.2,3.1,-5.8),Vector3(.33,6.2,.55),"435567",0,.65)
		g.box(bay,"GantryNeon",Vector3(side*3.15,3.1,-5.48),Vector3(.065,5.9,.04),"2fe8e4",1.7)
		for n in 6:
			g.box(bay,"ServerUnit",Vector3(side*2.8,.6+n*.62,-6.47),Vector3(.8,.48,.55),"263749",0,.55)
			g.box(bay,"ServerStatus",Vector3(side*2.8,.6+n*.62,-6.17),Vector3(.56,.045,.035),"2bdad3",1.6)
		for z in [-5.0,-3.0,-1.0,1.0]:
			g.box(bay,"FloorCircuit",Vector3(side*2.4,.065,z),Vector3(.045,.02,1.4),"32d9e3",1.2)
			g.box(bay,"CircuitBranch",Vector3(side*2.1,.065,z+.5),Vector3(.65,.02,.045),"b95ce0",1.0)
		for y in [.5,1.1,1.7,2.3]:
			g.box(bay,"VentLouvre",Vector3(side*3.65,y,-3.7),Vector3(.06,.09,2.0),"6a8190",0,.6)
	g.box(bay,"GantryBeam",Vector3(0,6.1,-5.8),Vector3(6.7,.32,.55),"435567",0,.7)
	g.ring(bay,"ReactorOuter",Vector3(0,3.2,-6.57),1.9,.12,"3d6276",0,true)
	g.ring(bay,"ReactorNeon",Vector3(0,3.2,-6.40),1.65,.035,"37e7ea",2,true)
	for i in 12:
		var angle = i*TAU/12
		var bar = g.box(bay,"ReactorSegment",Vector3(cos(angle)*1.85,3.2+sin(angle)*1.85,-6.27),Vector3(.08,.32,.12),"ca5bec",1.4)
		bar.rotation.z = angle-PI/2
	for side in [-1,1]:
		g.rod(bay,"PowerPipe",Vector3(side*2.2,.15,-6.2),Vector3(side*2.2,5.5,-6.2),.10,"586a7f",0,.75)
		g.box(bay,"SuspendedDataPanel",Vector3(side*2.8,4.65,-4.8),Vector3(.75,1.05,.06),"254866",.25)
		for n in 4: g.box(bay,"DataLine",Vector3(side*2.8,4.3+n*.18,-4.75),Vector3(.53,.025,.025),"5be5df",1)

func build_ancient() -> void:
	var bay = Node3D.new()
	bay.name = "AzureMoonHall"
	add_child(bay)
	for side in [-1,1]:
		g.cylinder(bay,"StoneColumnBase",Vector3(side*2.8,.17,-5.6),.48,.30,"778fa9",-1,0,0,8)
		g.cylinder(bay,"BlueTimberColumn",Vector3(side*2.8,2.6,-5.6),.19,4.8,"29496a",-1,0,.15,12)
		g.box(bay,"ColumnCapital",Vector3(side*2.8,5,-5.6),Vector3(.75,.25,.75),"9eb3be")
		g.box(bay,"PaperScreen",Vector3(side*2.8,2.65,-6.59),Vector3(1.5,3.3,.08),"5985a2",.1)
		for n in 5: g.box(bay,"ScreenLatticeVertical",Vector3(side*2.8-.63+n*.315,2.65,-6.49),Vector3(.035,3.3,.05),"213955")
		for n in 8: g.box(bay,"ScreenLatticeCross",Vector3(side*2.8,1.15+n*.42,-6.46),Vector3(1.5,.035,.05),"213955")
		g.rod(bay,"LanternCord",Vector3(side*2.7,5.8,-2),Vector3(side*2.7,4.5,-2),.025,"384c62")
		g.cylinder(bay,"BlueSilkLantern",Vector3(side*2.7,4.15,-2),.29,.65,"84c6ec",-1,.7,0,8)
		for y in [3.79,4.51]: g.cylinder(bay,"LanternCap",Vector3(side*2.7,y,-2),.34,.07,"274567",-1,0,.4,8)
		g.rod(bay,"LanternTassel",Vector3(side*2.7,3.75,-2),Vector3(side*2.7,3.30,-2),.035,"537fa1")
		g.box(bay,"GardenBasin",Vector3(side*2.9,.25,-.2),Vector3(1.15,.45,.85),"728296")
		g.rod(bay,"PlumTrunk",Vector3(side*2.9,.48,-.2),Vector3(side*2.9+.13,1.25,-.2),.08,"35425b")
		for i in 3:
			g.box(bay,"BonsaiCrown",Vector3(side*2.9+(i-1)*.28,1.15+i*.14,-.2),Vector3(.80,.14,.55),"466d89")
	g.ring(bay,"MoonGateStone",Vector3(0,3.1,-6.57),2.05,.17,"83a4bd",0,true)
	g.ring(bay,"MoonGateAzureInlay",Vector3(0,3.1,-6.34),1.84,.025,"91cfef",.8,true)
	g.box(bay,"TimberLintel",Vector3(0,5.65,-5.7),Vector3(7.0,.26,.9),"354e6c")
	for i in range(-12,13):
		var tile = g.box(bay,"GlazedEaveTile",Vector3(i*.28,5.9+absf(i)*.012,-5.5),Vector3(.265,.13,1.4),"2f597e",0,.25)
		tile.rotation.x = -.15
	for side in [-1,1]:
		g.rod(bay,"UpturnedEave",Vector3(side*3.1,5.9,-5.4),Vector3(side*3.7,6.25,-5.4),.09,"6083a4")
	for z in [-.5,1.0,2.5]: g.box(bay,"StoneApproachSlab",Vector3(0,.075,z),Vector3(2.7,.08,1.2),"7b91a7")
	for x in [-1.7,1.7]: g.box(bay,"AzureWaterChannel",Vector3(x,.061,-.2),Vector3(.25,.025,5.5),"4d9ac8",.45)

func build_gothic() -> void:
	var bay = Node3D.new()
	bay.name = "CrimsonGothicChapel"
	bay.position.x = 8
	add_child(bay)
	for side in [-1,1]:
		g.box(bay,"Buttress",Vector3(side*3.2,2.8,-5.6),Vector3(.60,5.6,.8),"3b2b40")
		for x in [-.18,0,.18]: g.rod(bay,"FlutedColumn",Vector3(side*2.65+x,.2,-5.7),Vector3(side*2.65+x,4.7,-5.7),.075,"6d5068",0,.4)
		g.rod(bay,"PointedArchRib",Vector3(side*2.65,4.7,-5.7),Vector3(0,6.4,-5.7),.14,"916c83",0,.4)
		g.rod(bay,"WindowTracery",Vector3(side*1.8,4.45,-6.53),Vector3(0,5.9,-6.53),.06,"28192b",0,.4)
		g.box(bay,"RubyGlassLower",Vector3(side*.9,2.9,-6.57),Vector3(1.65,3.0,.05),"9c224a",.55)
		var facet = g.box(bay,"RubyGlassUpper",Vector3(side*.53,4.7,-6.55),Vector3(.82,1.65,.05),"df3d65",.65)
		facet.rotation.z = side*.48
		for y in [2,3,4]: g.box(bay,"GlassCrossBar",Vector3(side*.95,y,-6.45),Vector3(1.9,.055,.05),"26192c")
		g.cylinder(bay,"CandelabrumBase",Vector3(side*2.35,.10,-.4),.32,.16,"756474",-1,0,.7,8)
		g.rod(bay,"CandelabrumStem",Vector3(side*2.35,.2,-.4),Vector3(side*2.35,1.6,-.4),.055,"ac8698",0,.8)
		for offset in [-.3,0,.3]:
			g.rod(bay,"CandleArm",Vector3(side*2.35,1.2,-.4),Vector3(side*2.35+offset,1.5,-.4),.025,"ac8698",0,.7)
			g.cylinder(bay,"WaxCandle",Vector3(side*2.35+offset,1.66,-.4),.045,.30,"e4cab1",-1)
			g.cylinder(bay,"CandleFlame",Vector3(side*2.35+offset,1.86,-.4),.035,.10,"ffb373",0,1.8)
		for y in [4.8,5.1,5.4,5.7]: g.ring(bay,"HangingChain",Vector3(side*2.05,y,-3.1),.12,.022,"8c6b7e",0,true)
	g.box(bay,"CrimsonCarpet",Vector3(0,.08,.3),Vector3(2.9,.03,5.1),"731d39")
	for x in [-1.5,1.5]: g.box(bay,"CarpetSilverEdge",Vector3(x,.085,.3),Vector3(.045,.025,5.2),"bc899e")
	g.box(bay,"GlassCentralMullion",Vector3(0,3.6,-6.42),Vector3(.12,4.9,.06),"2a192c")
	for i in 4:
		var diamond = g.box(bay,"GlassDiamond",Vector3(0,2+i*.7,-6.38),Vector3(.42,.42,.05),"f35c7d",.5)
		diamond.rotation.z = PI/4

func build_exhibit(item: Dictionary) -> void:
	var base = Node3D.new()
	base.name = str(item.id)+"Exhibit"
	base.position = Vector3(item.x,0,-3.0)
	add_child(base)
	var color: String = item.color
	base.add_child(preload("res://scripts/upgrade_station_base.gd").new())
	var display = Node3D.new()
	base.add_child(display)
	display.position.y = -.16
	var model = Weapons.create("ultimate" if item.id == "blade" else str(item.id))
	model.name = "DisplayWeapon"
	display.add_child(model)
	if item.id == "rocket_launcher":
		model.position = Vector3(0,1.91,0)
		model.rotation = Vector3(.08,PI-.55,.03)
		for z in [-.53,.53]: g.rod(display,"LauncherSupport",Vector3(0,1.1,z),Vector3(0,1.72,z),.05,"8699ab",0,.6)
	elif item.id == "blade":
		model.position = Vector3(0,1.68,0)
		model.scale = Vector3.ONE*1.35
		for x in [-.32,.32]: g.rod(display,"SwordStand",Vector3(x,1.1,-.12),Vector3(x,1.7,-.12),.035,"b6a377",0,.5)
	else: model.position = Vector3(0,2.03,0)
	exhibits[item.id] = {"root":base,"weapon":model,"item":item,"display_basis":model.basis}

func focused(yaw: float, pitch: float) -> String:
	var eye: Vector3 = player.position+Vector3.UP*1.7
	var forward = Basis.from_euler(Vector3(pitch,yaw,0))*Vector3.FORWARD
	var best = .87
	var result = ""
	for item in EXHIBITS:
		var toward = Vector3(item.x,1.6,-2.8)-eye
		if toward.length() > 3.8: continue
		var alignment = forward.dot(toward.normalized())
		if alignment > best: best = alignment; result = item.id
	return result

func animate(dt: float, focus: String) -> void:
	clock += dt
	for exhibit in exhibits.values():
		exhibit.weapon.basis = Basis(Vector3.UP,clock*TAU/40.0)*exhibit.display_basis
	var blade = exhibits.blade.weapon.get_node("UltimateGrip/UltimateLongBlade")
	blade.sync_energy(true,clock)
