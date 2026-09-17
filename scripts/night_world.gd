extends "res://scripts/campaign_world.gd"
var holdout_label: Label3D

func sync(state: Dictionary) -> void:
	super(state)
	if is_instance_valid(holdout_label):
		holdout_label.text = "门已解锁 · 进屋关门" if state.get("exit_control",false) else "坚守 %d 秒" % ceili(30-state.get("holdout_time",0.0)) if state.get("holdout_started",false) else "E 启动门锁 · 坚守 30 秒"

func _init() -> void:
	Layout = preload("res://scripts/night_layout.gd")

func lamp(pos: Vector3, color: String, energy := 2.0, radius := 10.0) -> void:
	block("Lamp",pos,Vector3(.65,.18,.4),color,false)
	var light = OmniLight3D.new()
	light.position = pos-Vector3(0,.3,0)
	light.light_color = Color(color)
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = true
	light.shadow_bias = .12
	light.shadow_normal_bias = 1.5
	# Closed solid scenery casts from its back faces, avoiding surface self-shadow
	# stripes without moving the whole shadow away with a large depth bias.
	light.shadow_reverse_cull_face = true
	add_child(light)

func van(pos: Vector2, color: String) -> void:
	block("AbandonedVan",Vector3(pos.x,.7,pos.y),Vector3(2.4,1.4,5),color)
	block("Cab",Vector3(pos.x,1.7,pos.y-.6),Vector3(2.2,.7,2.6),"29363f")
	for x in [-1.2,1.2]:
		for z in [-1.65,1.65]: cylinder(Vector3(pos.x+x,.4,pos.y+z),.42,.2,"121b23",true)
	block("Bumper",Vector3(pos.x,.4,pos.y+2.5),Vector3(2.5,.22,.15),"87918e",false)

func _ready() -> void:
	block("Ground",Vector3(0,-.55,5),Vector3(70,1,154),"29352f",true,false)
	for i in range(Layout.ROUTE.size()-1):
		var a: Vector2 = Layout.ROUTE[i]
		var b: Vector2 = Layout.ROUTE[i+1]
		var road = block("WetAsphalt",Vector3((a.x+b.x)/2,-.035,(a.y+b.y)/2),Vector3(7,.025,a.distance_to(b)+2),"41464a",false)
		road.rotation.y = atan2(b.x-a.x,b.y-a.y)
	for x in [-34.5,34.5]: block("BoundaryWall",Vector3(x,3,5),Vector3(1,6,154),"1d2a30")
	for z in [-71.5,81.5]: block("BoundaryWall",Vector3(0,3,z),Vector3(70,6,1),"1d2a30")
	room(Layout.START+Vector2(0,1),Vector2(10,12),"Start",false)
	room(Layout.EXIT,Vector2(10,12),"Exit",true)
	for entry in [["start",Layout.START_DOOR],["exit",Layout.EXIT_DOOR]]:
		var r: Rect2 = entry[1]
		doors[entry[0]] = block(entry[0],Vector3(r.get_center().x,2,r.get_center().y),Vector3(r.size.x,4,r.size.y),"9c6336",true,false)
	# Buildings and deep returns occlude the route; openings remain physically passable.
	for b in [[-19,46,38,10],[20,33,32,7],[-24,-1,12,24],[25,-42,15,16],[-24,-55,15,13]]:
		block("BrickBuilding",Vector3(b[0],3,b[1]),Vector3(b[2],6,b[3]),"414b50")
		block("Roof",Vector3(b[0],6.15,b[1]),Vector3(b[2]+.7,.3,b[3]+.7),"17232c",false)
		for dx in range(-int(b[2])/2+2,int(b[2])/2,4):
			block("Window",Vector3(b[0]+dx,3.4,b[1]+b[3]/2+.03),Vector3(1.5,1.4,.06),"15212b",false)
	# Walk-through convenience shop: front and back openings, shelves create two lanes.
	for x in [-19,1]: block("ShopSide",Vector3(x,2.2,17),Vector3(.6,4.4,24),"55534a")
	for z in [5,29]:
		for x in [-15.5,-2.5]: block("ShopFront",Vector3(x,2.2,z),Vector3(7,4.4,.6),"55534a")
	block("ShopCeiling",Vector3(-9,4.6,17),Vector3(21,.4,25),"1e292d",true,false)
	# A central display breaks the open firing corridor; both side aisles remain usable.
	block("ShopIsland",Vector3(-9,.9,17),Vector3(4,1.8,5),"394944")
	for x in [-10,-8]:
		for z in [15.5,17,18.5]: block("IslandGoods",Vector3(x,1.95,z),Vector3(.7,.3,.6),"826647",false)
	for x in [-15,-3]:
		block("Shelf",Vector3(x,.9,17),Vector3(1.4,1.8,9),"474b41")
		for y in [.5,1.1,1.7]:
			for z in [13,15,17,19,21]: block("ShelfGoods",Vector3(x,y,z),Vector3(1.5,.25,.6),"79624b",false)
	for p in [Vector2(2,54),Vector2(13,44),Vector2(-3,36),Vector2(8,19),Vector2(21,9),Vector2(3,-5),Vector2(-1,-29),Vector2(-16,-35),Vector2(4,-47)]: van(p,"545d55")
	# Solid hedges, trunks and alcoves hide idle infected without phantom collision.
	for p in [Vector2(-16,57),Vector2(25,52),Vector2(24,21),Vector2(-25,17),Vector2(-11,-8),Vector2(10,-16),Vector2(-16,-22),Vector2(22,-28),Vector2(-18,-42)]:
		block("Hedge",Vector3(p.x,1.25,p.y),Vector3(4,2.5,2.5),"203d32")
	var rng = RandomNumberGenerator.new()
	rng.seed = 71245
	for i in 100:
		var p = Vector2(rng.randf_range(-31,31),rng.randf_range(-50,59))
		if Layout.route_distance(p) < 4.8 or (Rect2(-21,2,24,30).has_point(p)) or obstacles.any(func(o): return Rect2(o.minX-2,o.minZ-2,o.maxX-o.minX+4,o.maxZ-o.minZ+4).has_point(p)): continue
		block("TreeTrunk",Vector3(p.x,1.6,p.y),Vector3(.6,3.2,.6),"30332b")
		for j in 3:
			var crown = MeshInstance3D.new()
			var mesh = CylinderMesh.new()
			mesh.top_radius = 0
			mesh.bottom_radius = 2.5-j*.5
			mesh.height = 3.4
			mesh.radial_segments = 5
			crown.mesh = mesh
			crown.material_override = material("172f29" if i%2 == 0 else "25382f")
			crown.position = Vector3(p.x,3.3+j*1.5,p.y)
			add_child(crown)
		# Low irregular understory, physically solid and included in navigation.
		if i%3 == 0:
			block("Understory",Vector3(p.x+.5,.6,p.y+.5),Vector3(2.1,1.2,1.8),"223c31")
	for item in Layout.ITEMS:
		supplies[item.id] = block("Supplies",Vector3(item.pos.x,.35,item.pos.y),Vector3(3.0 if item.kind == "ammo" else 1.6,.7,1.2),"685946",false)
		if item.kind == "ammo":
			block("WeaponRackWall",Vector3(item.pos.x,1.8,item.pos.y-.95),Vector3(3.3,3.6,.2),"344c48")
			for x in [-1.5,1.5]: block("RackFrame",Vector3(item.pos.x+x,1.8,item.pos.y-.78),Vector3(.08,3.4,.1),"a5bba5",false)
			for row in 4: block("RackRail",Vector3(item.pos.x,1.15+row*.55,item.pos.y-.77),Vector3(2.9,.055,.08),"a5bba5",false)
			lamp(Vector3(item.pos.x,3.5,item.pos.y+.35),"c2e7ab",1.3,4)
			supply_labels[item.id] = sign_at("挂墙武器 · E 更换",Vector3(item.pos.x,3.35,item.pos.y-.7),3.0)
		else: supply_labels[item.id] = sign_at("补给",Vector3(item.pos.x-.6,1.0,item.pos.y),1.4)
	block("DoorControl",Vector3(14.4,1,-50),Vector3(.6,2,.5),"a87938",false)
	# Left approach hides new reinforcement entries behind real navigable cover.
	block("LeftServiceWall",Vector3(0,1.7,-55),Vector3(8,3.4,1),"414b50")
	var sign_index = get_child_count()
	holdout_label = sign_at("E 启动门锁 · 坚守 30 秒",Vector3(12,2.7,-53.25),3.0)
	# Both backing and text sit outside the closed door and rise with it.
	var sign_back = get_child(sign_index)
	sign_back.reparent(doors.exit,true)
	holdout_label.reparent(doors.exit,true)
	for info in [["E 开门 · 沿绿灯前往安全屋",Vector3(0,2.8,65.2),3.0],["林边诊所 ↑",Vector3(8,2.6,39),3.0],["穿过店内 ↑",Vector3(-9,3.1,29.4),3.8],["安全屋 →",Vector3(-8,2.4,3),2.8],["安全屋 ←",Vector3(19,2.4,-24),2.8]]:
		sign_at(info[0],info[1],info[2])
	for p in [Vector3(0,3.6,70),Vector3(-9,3.8,24),Vector3(-14,3.8,11),Vector3(-12,3,-32),Vector3(12,3.7,-60),Vector3(12,3.6,-52)]: lamp(p,"ffcb85",2.6,11)
	for p in [Vector3(8,3.5,51),Vector3(-9,3.5,32),Vector3(16,3,-9),Vector3(7,3,-25),Vector3(-6,3,-43)]:
		block("LampPost",p/Vector3(1,2,1),Vector3(.14,p.y,.14),"43524e",false)
		lamp(p,"91bdab",1.5,9)
	set_meta("navigation_obstacles",obstacles)
