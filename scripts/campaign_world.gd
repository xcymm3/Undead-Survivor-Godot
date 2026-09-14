extends Node3D
const Layout = preload("res://scripts/campaign_layout.gd")
var obstacles: Array = []
var doors: Dictionary = {}
var supplies: Dictionary = {}
var supply_labels: Dictionary = {}
var materials: Dictionary = {}

func material(color: String) -> StandardMaterial3D:
	if not materials.has(color):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(color)
		mat.roughness = .85
		materials[color] = mat
	return materials[color]

func block(title: String, pos: Vector3, size: Vector3, color: String, solid := true, nav := true) -> Node3D:
	var item = StaticBody3D.new() if solid else Node3D.new()
	item.name = title
	item.position = pos
	var view = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	view.mesh = mesh
	view.material_override = material(color)
	item.add_child(view)
	if solid:
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = size
		shape.shape = box
		item.add_child(shape)
	add_child(item)
	if solid and nav: obstacles.append({"minX":pos.x-size.x/2,"maxX":pos.x+size.x/2,"minZ":pos.z-size.z/2,"maxZ":pos.z+size.z/2})
	return item

func sign_at(text: String, pos: Vector3, width := 4.0) -> Label3D:
	block("Sign",pos,Vector3(width,.55*text.split("\n").size()+.15,.18),"273e36",false)
	var label = Label3D.new()
	label.text = text
	label.font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	label.font_size = 64
	var longest = 1
	for line in text.split("\n"): longest = maxi(longest,line.length())
	label.pixel_size = minf(.006,width*.82/(64*longest))
	label.position = pos+Vector3(0,0,.11)
	label.no_depth_test = false
	add_child(label)
	return label

func cylinder(pos: Vector3, radius: float, height: float, color: String, sideways := false) -> MeshInstance3D:
	var view = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	view.mesh = mesh
	view.material_override = material(color)
	view.position = pos
	if sideways: view.rotation.z = PI/2
	add_child(view)
	return view

func room(center: Vector2, size: Vector2, title: String, south_door: bool) -> void:
	var z = center.y+size.y/2 if south_door else center.y-size.y/2
	block(title+"West",Vector3(center.x-size.x/2,2,center.y),Vector3(.5,4,size.y),"536255")
	block(title+"East",Vector3(center.x+size.x/2,2,center.y),Vector3(.5,4,size.y),"536255")
	block(title+"Back",Vector3(center.x,2,center.y-size.y/2 if south_door else center.y+size.y/2),Vector3(size.x,4,.5),"536255")
	for side in [-1,1]: block(title+"Front",Vector3(center.x+side*(size.x+3)/4,2,z),Vector3((size.x-3)/2,4,.5),"536255")
	block(title+"Roof",Vector3(center.x,4.2,center.y),Vector3(size.x+1,.4,size.y+1),"39483e",true,false)

func _ready() -> void:
	# Ground is split around the river; no invisible floor spans the water.
	block("SouthGround",Vector3(0,-.55,53.9),Vector3(160,1,172.2),"72775a",true,false)
	block("NorthGround",Vector3(0,-.55,-93.9),Vector3(160,1,92.2),"72775a",true,false)
	for i in range(Layout.ROUTE.size()-1):
		var a: Vector2 = Layout.ROUTE[i]
		var b: Vector2 = Layout.ROUTE[i+1]
		if minf(a.y,b.y) < -31 and maxf(a.y,b.y) > -49: continue
		var road = block("Road",Vector3((a.x+b.x)/2,-.035,(a.y+b.y)/2),Vector3(8,.025,a.distance_to(b)+1),"4d5550",false)
		road.rotation.y = atan2(b.x-a.x,b.y-a.y)
	room(Layout.START,Vector2(10,10),"Start",false)
	room(Layout.EXIT,Vector2(12,12),"Exit",true)
	block("StartBench",Vector3(-3,.45,115),Vector3(1,.9,3),"6c5238")
	block("StartSupplies",Vector3(-3,1.1,115),Vector3(.6,.4,.9),"9d8757",false)
	block("ExitBench",Vector3(28,.45,-127),Vector3(1,.9,3),"6c5238")
	for pos in [Vector3(0,3.8,115),Vector3(25,3.8,-125)]: block("CeilingLamp",pos,Vector3(1.4,.15,.3),"f0da9a",false)
	for data in [["start",Layout.START_DOOR],["gate",Layout.GATE],["exit",Layout.EXIT_DOOR]]:
		var rect: Rect2 = data[1]
		doors[data[0]] = block(data[0],Vector3(rect.get_center().x,2,rect.get_center().y),Vector3(rect.size.x,4,rect.size.y),"a77843",true,false)
		for h in [.3,1.1,1.9,2.7,3.5]:
			var brace = MeshInstance3D.new()
			var brace_mesh = BoxMesh.new()
			brace_mesh.size = Vector3(rect.size.x-.15,.08,rect.size.y+.02)
			brace.mesh = brace_mesh
			brace.material_override = material("514f3f")
			brace.position.y = h-2
			doors[data[0]].add_child(brace)
	doors.exit.position.y = 6.5
	doors.exit.collision_layer = 0
	# Full-width north fence makes the event mandatory while leaving both river banks accessible.
	for side in [-1,1]: block("NorthFence",Vector3(side*41.25,2.6,-57),Vector3(77.5,5.2,1.2),"5d6559")
	for side in [-1,1]: block("Boundary",Vector3(side*79,3,0),Vector3(2,6,280),"425747")
	for z in [-139,139]: block("Boundary",Vector3(0,3,z),Vector3(160,6,2),"425747")
	block("Bridge",Vector3(0,-.16,-40),Vector3(5,.4,18),"777b70",true,false)
	for x in [-2.8,2.8]: block("BridgeRail",Vector3(x,.55,-40),Vector3(.2,1.2,18),"686b60")
	var river = preload("res://scripts/river.gd").new()
	river.campaign = true
	add_child(river)
	# Buildings frame the route, break sightlines and hide the authored spawn entrances.
	for b in [[-25,95,25,16],[35,58,22,30],[-7,83,24,10],[-35,15,20,24],[35,12,20,30],[-42,-19,23,18],[-20,-90,14,18],[51,-102,14,24],[2,-116,14,9]]:
		block("Building",Vector3(b[0],3,b[1]),Vector3(b[2],6,b[3]),"64695b")
		block("Roof",Vector3(b[0],6.15,b[1]),Vector3(b[2]+1,.3,b[3]+1),"414d45",false)
		for dx in range(-int(b[2])/2+3,int(b[2])/2,5):
			for side in [-1,1]:
				block("WindowFrame",Vector3(b[0]+dx,3.4,b[1]+side*(b[3]/2+.04)),Vector3(2.4,1.9,.12),"b1a88b",false)
				block("DarkWindow",Vector3(b[0]+dx,3.4,b[1]+side*(b[3]/2+.12)),Vector3(2.1,1.6,.07),"354949",false)
		for side in [-1,1]:
			block("ServiceDoor",Vector3(b[0]+side*(b[2]/2+.05),1.3,b[1]),Vector3(.1,2.6,1.5),"3f5146",false)
			block("WallBand",Vector3(b[0]+side*(b[2]/2+.06),.45,b[1]),Vector3(.12,.9,b[3]),"505647",false)
	# Courtyard walls leave a main-road entrance and a separate return exit.
	block("YardWest",Vector3(-57,2,42),Vector3(1,4,30),"74745f")
	block("YardNorth",Vector3(-44,2,27),Vector3(26,4,1),"74745f")
	block("YardSouth",Vector3(-44,2,57),Vector3(26,4,1),"74745f")
	block("YardDivider",Vector3(-31,2,42),Vector3(1,4,12),"74745f")
	for pos in [Vector2(20,88),Vector2(-10,61),Vector2(9,-22),Vector2(-9,-14),Vector2(35,-87)]:
		block("AbandonedVan",Vector3(pos.x,.8,pos.y),Vector3(2.3,1.6,4.8),"867c5f")
		block("VanCab",Vector3(pos.x,1.8,pos.y-.7),Vector3(2, .6,2),"3e514d",false)
		for side in [-1,1]:
			for z in [-1.5,1.5]: cylinder(Vector3(pos.x+side*1.16,.4,pos.y+z),.42,.22,"30352e",true)
		block("Headlamps",Vector3(pos.x,.9,pos.y-2.43),Vector3(1.7,.2,.08),"bcb795",false)
	block("Winch",Vector3(8,.75,-16),Vector3(1.2,1.5,1.2),"bb8146")
	cylinder(Vector3(8,1.65,-16),.42,.9,"4b5550",true)
	for x in [7.5,8.5]: cylinder(Vector3(x,1.65,-16),.5,.09,"a77843",true)
	block("WinchButton",Vector3(8,1.05,-15.38),Vector3(.22,.22,.08),"b4d47e",false)
	block("Cable",Vector3(8,4,-36),Vector3(.06,.06,40),"302f2a",false)
	block("ToolShedRoof",Vector3(21,3.2,-78),Vector3(12,.3,10),"4c5a50",true,false)
	block("ToolShedBack",Vector3(21,1.5,-83),Vector3(12,3,.5),"5d6d5c")
	block("PumpTower",Vector3(41,9,-127),Vector3(7,18,7),"7e8778")
	cylinder(Vector3(41,19,-127),5,5,"899588")
	for x in [37,45]: block("PumpPipe",Vector3(x,3,-122),Vector3(.65,6,.65),"797558",false)
	for pos in [Vector2(-50,36),Vector2(-50,38),Vector2(24,-80),Vector2(26,-80)]:
		var collider = block("BarrelCollision",Vector3(pos.x,.6,pos.y),Vector3(1,1.2,1),"82674d")
		collider.get_child(0).visible = false
		cylinder(Vector3(pos.x,.6,pos.y),.5,1.2,"82674d")
		for y in [.18,1.0]: cylinder(Vector3(pos.x,y,pos.y),.52,.08,"444d41")
	for x in [-2.8,2.8]:
		for z in [-48,-40,-32]: block("BridgePost",Vector3(x,1.1,z),Vector3(.3,2.2,.3),"616957",false)
	for pos in [Vector2(22,99),Vector2(-19,71),Vector2(13,20),Vector2(-15,-12),Vector2(28,-102)]:
		block("StreetLampPost",Vector3(pos.x,3,pos.y),Vector3(.2,6,.2),"455245")
		block("StreetLampArm",Vector3(pos.x-1,5.9,pos.y),Vector3(2,.15,.15),"455245",false)
		block("StreetLamp",Vector3(pos.x-1.8,5.8,pos.y),Vector3(.7,.15,.4),"d5c68f",false)
	for x in [-65,65]:
		for z in range(-120,130,22):
			block("PineTrunk",Vector3(x,2,z),Vector3(.6,4,.6),"584d39")
			var tree = MeshInstance3D.new()
			var crown = CylinderMesh.new()
			crown.top_radius = 0
			crown.bottom_radius = 3
			crown.height = 8
			tree.mesh = crown
			tree.material_override = material("405d44")
			tree.position = Vector3(x,7,z)
			add_child(tree)
	for item in Layout.ITEMS:
		supplies[item.id] = block(item.id,Vector3(item.pos.x,.45,item.pos.y),Vector3(.7,.9,.6),"b56c4a" if item.kind == "med" else "b6ab73",false)
		supply_labels[item.id] = sign_at("医疗 +" if item.kind == "med" else "弹药",Vector3(item.pos.x,1.6,item.pos.y),1.8)
	for info in [["公路值班室\nE 开门出发",Vector3(0,2.9,110.6),2.6],["泵站避难点 ↑",Vector3(12,2.6,94),4],["维修院落 ← 医疗",Vector3(-23,2.6,55),4],["河桥控制台 ↑",Vector3(8,2.6,15),4],["E 启动卷扬机",Vector3(8,2.6,-17),2.6],["检修闸门",Vector3(0,5.4,-57),4],["泵站避难点 →",Vector3(20,2.6,-82),4],["泵站安全屋",Vector3(25,3.4,-118.8),3.2]]: sign_at(info[0],info[1],info[2])
	set_meta("navigation_obstacles",obstacles)
	for pos in [Vector3(0,3,115),Vector3(8,3,-16),Vector3(25,3,-125)]:
		var light = OmniLight3D.new()
		light.position = pos
		light.light_color = Color("ffd18a")
		light.light_energy = 1.6
		light.omni_range = 10
		add_child(light)

func sync(state: Dictionary) -> void:
	for id in doors:
		var opened: bool = state.get("departed",false) if id == "start" else state.get("gate_open",false) if id == "gate" else not state.get("complete",false)
		var progress: float = float(state.get("bridge_time",0))/90.0 if id == "gate" and not opened else 0.0
		doors[id].position.y = 6.5 if opened else 2+minf(.8,progress)*1.0
		doors[id].collision_layer = 0 if opened else 1
	for item in Layout.ITEMS:
		var available = item.get("party",1) <= state.get("party",1)
		supplies[item.id].visible = available and not state.get("taken",{}).has(item.id)
		supply_labels[item.id].visible = available
		if state.get("taken",{}).has(item.id): supply_labels[item.id].text = "已取走"
		else: supply_labels[item.id].text = "医疗 +" if item.kind == "med" else "弹药"
