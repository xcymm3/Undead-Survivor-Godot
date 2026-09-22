extends "res://scripts/campaign_world.gd"
const DefenseLayout = preload("res://scripts/defense_layout.gd")
const DefenseEnvironment = preload("res://scripts/defense_environment.gd")
const DISPLAYED_PRIMARY_WEAPONS := [0,1,4,5,7,8,9]
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
	# Continuous waist-high rails are physical, unlike the decorative suspension
	# cables, and keep both walking and knockback safely on the bridge deck.
	for x in [-3.86,3.86]:
		block("BridgeGuardRail",Vector3(x,.72,-45),Vector3(.28,1.45,34),"4b5049",true,false)
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
	# Low shelves catch a sideways step at the ramp. Their upper edge remains
	# three metres below the plateau, leaving the central ramp as the only route.
	block("RampShelfLeft",Vector3(-18.75,-.22,-19),Vector3(26.5,.44,18),"475048",true,false)
	block("RampShelfRight",Vector3(18.75,-.22,-19),Vector3(26.5,.44,18),"475048",true,false)
	var angle = -atan2(3.0,18.0)
	var ramp = block("StoneRamp",Vector3(0,1.3,-19),Vector3(10,.5,18.25),"59605b",true,false)
	ramp.rotation.x = angle
	DefenseEnvironment.build_ramp_fill(self)
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
	var shop_wall = block("WeaponShopWall",Vector3(0,7.2,67.85),Vector3(25.5,8.8,.65),"493a2d",true,false)
	shop_wall.set_meta("environment_feature","weapon_shop_wall")
	for row in 2:
		block("ShopRail%d" % row,Vector3(0,4.34+row*.64,67.48),Vector3(23.8,.08,.1),"a7bbb0",false)
	# Narrow trim breaks up the wood surface while preserving one continuous wall.
	for column in range(6):
		var x = -10.625+column*4.25
		block("ShopFrame%d" % column,Vector3(x,7.2,67.47),Vector3(.12,8.15,.1),"5d4934",false)
	block("ShopFrameTop",Vector3(0,11.52,67.47),Vector3(25.5,.18,.18),"5d4934",false)
	block("ShopFrameBottom",Vector3(0,3.08,67.47),Vector3(25.5,.18,.18),"5d4934",false)
	# Only primary weapons belong on the armory wall. Sidearms and the melee weapon
	# are always carried, so the display keeps them out of the player's loadout choice.
	# The tall upper wall is deliberately left open and every gun stays at eye level.
	for display_index in DISPLAYED_PRIMARY_WEAPONS.size():
		var weapon_index: int = DISPLAYED_PRIMARY_WEAPONS[display_index]
		var model = preload("res://scripts/weapon_view.gd").create_model(Data.weapons[weapon_index].id)
		add_child(model)
		model.name = "WeaponDisplay%02d" % (display_index+1)
		model.set_meta("weapon_display_index",weapon_index)
		model.set_meta("mount_height",4.65)
		model.set_meta("mount_x",10.2-display_index*3.4)
		model.rotation.y = PI/2
		var bounds = posed_bounds(model)
		var factor = minf(1.8/maxf(bounds.size.x,.01),.46/maxf(bounds.size.y,.01))
		model.scale *= factor
		var mount = Vector3(float(model.get_meta("mount_x")),float(model.get_meta("mount_height")),67.32)
		model.position = mount-bounds.get_center()*factor
		var key = "0" if weapon_index == 9 else str(weapon_index+1)
		var rack_label = sign_at("%s %s" % [key,Data.weapons[weapon_index].label],Vector3(mount.x,5.58,67.42),2.05)
		rack_label.rotation.y = PI
		rack_label.position.z -= .22
	for x in [-9.0,-3.0,3.0,9.0]:
		var light = OmniLight3D.new()
		light.position = Vector3(x,6.4,65.8)
		light.light_color = Color("d8ebd0")
		light.light_energy = 4.0
		light.omni_range = 10.0
		light.shadow_enabled = true
		add_child(light)
	var zone_label = sign_at("水晶防线军械库 · 仅陈列主武器",Vector3(0,10.25,67.45),12.0)
	zone_label.rotation.y = PI
	zone_label.position.z -= .22

func _ready() -> void:
	# 深谷、坡地与高地保持原有玩法尺寸，环境模块只提升表面与边界表现。
	DefenseEnvironment.build(self)
	# 二维寻路必须把深谷视为不可走区域。缓坡侧平台是玩家的防坠
	# 落脚点，但也设为导航禁区，保证所有敌人仍只能经中央缓坡靠近水晶。
	obstacles.append({"minX":-32.0,"maxX":-4.0,"minZ":-62.0,"maxZ":-28.0})
	obstacles.append({"minX":4.0,"maxX":32.0,"minZ":-62.0,"maxZ":-28.0})
	obstacles.append({"minX":-32.0,"maxX":-5.5,"minZ":-28.0,"maxZ":-10.0})
	obstacles.append({"minX":5.5,"maxX":32.0,"minZ":-28.0,"maxZ":-10.0})
	# The rear loadout zone is a true enemy-safe fallback. A retreating player
	# crosses this line, making the crystal both closer and reachable to the horde.
	obstacles.append({"minX":-32.0,"maxX":32.0,"minZ":52.0,"maxZ":72.0})
	make_bridge()
	make_ramp()
	make_safe_zone()
	make_crystal()
	# 有碰撞的自然掩体避开中央进攻通道；峡谷段保留无围墙的断崖轮廓。
	DefenseEnvironment.decorate(self)
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
