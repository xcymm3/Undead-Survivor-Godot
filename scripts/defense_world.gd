extends "res://scripts/campaign_world.gd"
const DefenseLayout = preload("res://scripts/defense_layout.gd")
var lever: Node3D
var crystal: Node3D
var crystal_core: MeshInstance3D
var crystal_light: OmniLight3D
var crystal_label: Label3D
var wave_label: Label3D

func _init() -> void:
	Layout = DefenseLayout

func beam_between(title: String, a: Vector3, b: Vector3, radius: float, color: String) -> MeshInstance3D:
	var beam = MeshInstance3D.new()
	beam.name = title
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	beam.mesh = mesh
	beam.material_override = material(color)
	beam.position = (a+b)*.5
	beam.basis = Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	add_child(beam)
	return beam

func make_crystal() -> void:
	crystal = Node3D.new()
	crystal.name = "DefenseCrystal"
	crystal.position = Vector3(DefenseLayout.CRYSTAL.x,3.0,DefenseLayout.CRYSTAL.y)
	add_child(crystal)
	block("CrystalPedestal",Vector3(0,3.45,46),Vector3(4.2,.9,4.2),"344d50",true,false)
	for side in [-1.0,1.0]:
		var cone = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.top_radius = 0.0 if side > 0 else 1.05
		mesh.bottom_radius = 1.05 if side > 0 else 0.0
		mesh.height = 2.5
		mesh.radial_segments = 6
		cone.mesh = mesh
		cone.position.y = 1.7+side*1.15
		crystal.add_child(cone)
		if side > 0: crystal_core = cone
	var glow = StandardMaterial3D.new()
	glow.albedo_color = Color("7ee6ff")
	glow.emission_enabled = true
	glow.emission = Color("38bddd")
	glow.emission_energy_multiplier = 2.7
	for child in crystal.get_children():
		if child is MeshInstance3D: child.material_override = glow
	crystal_light = OmniLight3D.new()
	crystal_light.position = Vector3(0,2.3,0)
	crystal_light.light_color = Color("65dff2")
	crystal_light.light_energy = 5.0
	crystal_light.omni_range = 13.0
	crystal_light.shadow_enabled = true
	crystal.add_child(crystal_light)
	crystal_label = sign_at("水晶 1500 / 1500",Vector3(0,7.8,46),4.6)

func make_bridge() -> void:
	# 连续碰撞板负责角色行走；独立木板、桥塔和垂索塑造吊桥轮廓。
	block("BridgeCollision",Vector3(0,-.22,-45),Vector3(8,.44,34),"493a2d",true,false)
	for z in range(-61,-27,2):
		block("BridgePlank",Vector3(0,.045,z),Vector3(7.7,.16,1.7),"76583b",false)
	for z in [-62,-28]:
		for x in [-4.2,4.2]:
			block("BridgeTower",Vector3(x,2.8,z),Vector3(.5,5.6,.5),"31393a",true,false)
		beam_between("TowerCrossbar",Vector3(-4.2,5.25,z),Vector3(4.2,5.25,z),.16,"5d6663")
	for x in [-4.15,4.15]:
		var previous = Vector3(x,5.0,-62)
		for step in range(1,18):
			var t = step/17.0
			var z = lerpf(-62,-28,t)
			var y = 5.0-3.0*sin(t*PI)
			var point = Vector3(x,y,z)
			beam_between("MainCable",previous,point,.07,"6f7772")
			if step < 17: beam_between("Suspender",point,Vector3(x,.55,z),.035,"6f7772")
			previous = point
		beam_between("Handrail",Vector3(x,1.15,-62),Vector3(x,1.15,-28),.07,"70634f")

func make_ramp() -> void:
	var angle = -atan2(3.0,18.0)
	var ramp = block("StoneRamp",Vector3(0,1.3,-19),Vector3(10,.5,18.25),"59605b",true,false)
	ramp.rotation.x = angle
	for x in [-5.2,5.2]:
		var rail = block("RampWall",Vector3(x,2.05,-19),Vector3(.45,1.2,18.4),"343f3e",true,false)
		rail.rotation.x = angle
	for z in [-27,-23,-19,-15,-11]:
		var y = DefenseLayout.height(Vector2(0,z))
		block("RampMark",Vector3(0,y+.28,z),Vector3(9.7,.06,.18),"8b7654",false)

func make_safe_zone() -> void:
	block("SafeZoneFloor",Vector3(0,3.035,60.5),Vector3(26,.06,17),"314c45",false)
	for x in [-13.0,13.0]: block("SafeLine",Vector3(x,3.075,60.5),Vector3(.12,.08,17),"7bd8aa",false)
	for z in [52.0,69.0]: block("SafeLine",Vector3(0,3.075,z),Vector3(26,.08,.12),"7bd8aa",false)
	for x in [-8.5,-4.25,0.0,4.25,8.5]:
		block("WeaponRack",Vector3(x,4.5,67.8),Vector3(3.2,2.8,.35),"293a38",true,false)
		for row in 3: block("RackRail",Vector3(x,3.8+row*.65,67.58),Vector3(2.7,.07,.08),"a7bbb0",false)
	sign_at("安全换装区 · 1—0 更换主武器",Vector3(0,6.5,67.45),9.0)

func _ready() -> void:
	# 深谷底部让桥的高度关系清楚可见，导航障碍只留下八米宽的桥面通路。
	block("RiverBed",Vector3(0,-8.5,-45),Vector3(64,1,34),"17282d",true,false)
	block("Water",Vector3(0,-7.92,-45),Vector3(64,.08,34),"245d68",false)
	block("FarCliff",Vector3(0,-.5,-70),Vector3(64,1,16),"4d5146",true,false)
	block("DefensePlateau",Vector3(0,1.5,31),Vector3(64,3,82),"3d4b3e",true,false)
	block("ApproachRoad",Vector3(0,3.035,18),Vector3(11,.07,56),"756c55",false)
	for z in range(-8,47,9):
		block("RoadChevronLeft",Vector3(-3.2,3.09,z),Vector3(2.2,.06,.22),"d1b873",false).rotation.y = -.42
		block("RoadChevronRight",Vector3(3.2,3.09,z),Vector3(2.2,.06,.22),"d1b873",false).rotation.y = .42
	# 二维寻路必须把深谷视为不可走区域，物理层仍允许看见低处河床。
	obstacles.append({"minX":-32.0,"maxX":-4.0,"minZ":-62.0,"maxZ":-28.0})
	obstacles.append({"minX":4.0,"maxX":32.0,"minZ":-62.0,"maxZ":-28.0})
	make_bridge()
	make_ramp()
	make_safe_zone()
	make_crystal()
	# 断崖边界、平原围栏和稀疏掩体既限制出界，也保留开阔射界。
	for x in [-31.5,31.5]: block("BoundaryWall",Vector3(x,4.5,5),Vector3(1,3,134),"26352f")
	for z in [-77.5,71.5]: block("BoundaryWall",Vector3(0,3,z),Vector3(64,6,1),"26352f")
	for x in [-19.0,19.0]:
		block("CliffPillar",Vector3(x,-1.5,-28),Vector3(18,9,2),"343a35",true,false)
		block("CliffPillar",Vector3(x,-1.5,-62),Vector3(18,9,2),"343a35",true,false)
	for p in [Vector2(-18,7),Vector2(17,13),Vector2(-20,28),Vector2(19,34)]:
		block("LowRock",Vector3(p.x,3.7,p.y),Vector3(3.2,1.4,2.5),"50594f")
	for p in [Vector2(-12,43),Vector2(13,42)]:
		block("CrystalGuard",Vector3(p.x,4.0,p.y),Vector3(3.5,2,1.2),"46534a")
	lever = Node3D.new()
	lever.name = "WaveLever"
	lever.position = Vector3(DefenseLayout.LEVER.x,4.0,DefenseLayout.LEVER.y)
	add_child(lever)
	preload("res://scripts/campaign_props.gd").box(lever,Vector3(.75,1.5,.55),Vector3.ZERO,Color("3b4d4b"))
	preload("res://scripts/campaign_props.gd").box(lever,Vector3(.12,1.15,.12),Vector3(0,.9,0),Color("b7c0b8"))
	preload("res://scripts/campaign_props.gd").box(lever,Vector3(.42,.18,.18),Vector3(0,1.47,0),Color("b94735"))
	wave_label = sign_at("E 拉下拉杆 · 开始防守",Vector3(6,6.5,49),5.7)
	for p in [Vector3(-4.2,5.5,-62),Vector3(4.2,5.5,-62),Vector3(-4.2,5.5,-28),Vector3(4.2,5.5,-28),Vector3(-11,6,48),Vector3(11,6,48)]:
		var light = OmniLight3D.new()
		light.position = p
		light.light_color = Color("ffc77d")
		light.light_energy = 2.5
		light.omni_range = 10
		light.shadow_enabled = true
		add_child(light)
	set_meta("navigation_obstacles",obstacles)

func sync(state: Dictionary) -> void:
	if not is_instance_valid(lever): return
	var started: bool = state.get("started",false)
	lever.rotation.x = -1.05 if started else 0.0
	var hp: float = float(state.get("crystal_hp",DefenseLayout.CRYSTAL_MAX_HP))
	var maximum: float = float(state.get("crystal_max_hp",DefenseLayout.CRYSTAL_MAX_HP))
	var ratio = clampf(hp/maxf(1,maximum),0,1)
	crystal.scale = Vector3.ONE*lerpf(.88,1.0,ratio)
	crystal_light.light_energy = lerpf(.35,5.0,ratio)
	crystal_light.light_color = Color("f05d4f") if ratio < .3 else Color("65dff2")
	crystal_label.text = "水晶 %d / %d" % [ceili(hp),ceili(maximum)]
	wave_label.text = "等待拉杆启动" if not started else "第 %d / %d 波" % [state.get("wave",1),DefenseLayout.MAX_WAVES]
