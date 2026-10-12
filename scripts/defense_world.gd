extends "res://scripts/world_geometry.gd"
const DefenseLayout = preload("res://scripts/defense_layout.gd")
const Layout = DefenseLayout
const DefenseEnvironment = preload("res://scripts/defense_environment.gd")
var crystal: Node3D
var crystal_core: MeshInstance3D
var crystal_light: OmniLight3D
var preparation: Node3D
var pickup_animation: Node3D
var structure_view: Node3D

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
	var body = StaticBody3D.new()
	body.name = "CrystalBody"
	body.position = Vector3(DefenseLayout.CRYSTAL.x,4.8,DefenseLayout.CRYSTAL.y)
	var shape = CollisionShape3D.new()
	var cylinder = CylinderShape3D.new()
	cylinder.radius = DefenseLayout.CRYSTAL_RADIUS
	cylinder.height = 3.6
	shape.shape = cylinder
	body.add_child(shape)
	add_child(body)
	obstacles.append({"minX":DefenseLayout.CRYSTAL.x-DefenseLayout.CRYSTAL_RADIUS,"maxX":DefenseLayout.CRYSTAL.x+DefenseLayout.CRYSTAL_RADIUS,"minZ":DefenseLayout.CRYSTAL.y-DefenseLayout.CRYSTAL_RADIUS,"maxZ":DefenseLayout.CRYSTAL.y+DefenseLayout.CRYSTAL_RADIUS})
	crystal_core = preload("res://scripts/crystal_art.gd").build(crystal)
	crystal_light = OmniLight3D.new()
	crystal_light.position = Vector3(0,2.3,0)
	crystal_light.light_color = Color("65dff2")
	crystal_light.light_energy = 2.4
	crystal_light.omni_range = 13.0
	crystal_light.shadow_enabled = true
	crystal.add_child(crystal_light)

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
	var safe = DefenseLayout.SAFE_ZONE
	block("SafeZoneFloor",Vector3(0,3.035,safe.get_center().y),Vector3(26,.06,safe.size.y),"314c45",false)
	block("WeaponShopWall",Vector3(0,6,DefenseLayout.SHOP_WALL_Z),Vector3(25.5,6,.65),"493a2d",true,false)
	preparation = preload("res://scripts/preparation_world.gd").new()
	preparation.name = "PreparationWorld"
	add_child(preparation)

func sync_focus(sim, pawn: Dictionary) -> void:
	if preparation: preparation.sync_focus(sim,pawn)

func _ready() -> void:
	# 深谷、坡地与高地保持原有玩法尺寸，环境模块只提升表面与边界表现。
	DefenseEnvironment.build(self)
	# 二维寻路必须把深谷视为不可走区域。缓坡侧平台是玩家的防坠
	# 落脚点，但也设为导航禁区，保证所有敌人仍只能经中央缓坡靠近水晶。
	obstacles.append({"minX":DefenseLayout.BOUNDS.position.x,"maxX":-4.0,"minZ":-62.0,"maxZ":-28.0})
	obstacles.append({"minX":4.0,"maxX":DefenseLayout.BOUNDS.end.x,"minZ":-62.0,"maxZ":-28.0})
	# The expanded far bank does not add walkable ground beside the original plateau.
	obstacles.append({"minX":DefenseLayout.BOUNDS.position.x,"maxX":DefenseLayout.PLATEAU.position.x,"minZ":-28.0,"maxZ":DefenseLayout.BOUNDS.end.y})
	obstacles.append({"minX":DefenseLayout.PLATEAU.end.x,"maxX":DefenseLayout.BOUNDS.end.x,"minZ":-28.0,"maxZ":DefenseLayout.BOUNDS.end.y})
	obstacles.append({"minX":-32.0,"maxX":-5.5,"minZ":-28.0,"maxZ":-10.0})
	obstacles.append({"minX":5.5,"maxX":32.0,"minZ":-28.0,"maxZ":-10.0})
	# The side armory remains enemy-safe while leaving the central field open.
	var safe = DefenseLayout.SAFE_ZONE
	obstacles.append({"minX":safe.position.x,"maxX":safe.end.x,"minZ":safe.position.y,"maxZ":safe.end.y})
	make_bridge()
	make_ramp()
	make_safe_zone()
	make_crystal()
	structure_view = preload("res://scripts/defense_structure_view.gd").new()
	structure_view.name = "DefenseStructures"
	add_child(structure_view)
	structure_view.sync({})
	# 有碰撞的自然掩体避开中央进攻通道；峡谷段保留无围墙的断崖轮廓。
	DefenseEnvironment.decorate(self)
	for p in [DefenseLayout.CRYSTAL+Vector2(-12,-3),DefenseLayout.CRYSTAL+Vector2(13,-4)]:
		block("CrystalGuard",Vector3(p.x,4.0,p.y),Vector3(3.5,2,1.2),"46534a")
	for p in [Vector3(-4.2,5.5,-62),Vector3(4.2,5.5,-62),Vector3(-4.2,5.5,-28),Vector3(4.2,5.5,-28),Vector3(-11,6,DefenseLayout.CRYSTAL.y+2),Vector3(11,6,DefenseLayout.CRYSTAL.y+2)]:
		var light = OmniLight3D.new()
		light.position = p
		light.light_color = Color("ffc77d")
		light.light_energy = 2.5
		light.omni_range = 10
		light.shadow_enabled = true
		add_child(light)
	set_meta("navigation_obstacles",obstacles)

func sync(state: Dictionary) -> void:
	if preparation: preparation.sync(state)
	if is_instance_valid(structure_view): structure_view.sync(state)
	sync_projectiles(state)
	if not is_instance_valid(pickup_animation):
		pickup_animation = preload("res://scripts/interaction_motion.gd").new()
		add_child(pickup_animation)
	pickup_animation.sync(state)
	var hp: float = float(state.get("crystal_hp",DefenseLayout.CRYSTAL_MAX_HP))
	var maximum: float = float(state.get("crystal_max_hp",DefenseLayout.CRYSTAL_MAX_HP))
	var ratio = clampf(hp/maxf(1,maximum),0,1)
	var clock: float = float(state.get("prop_clock",0.0))
	crystal.rotation.y = fmod(clock,preload("res://scripts/crystal_art.gd").PERIOD)*TAU/preload("res://scripts/crystal_art.gd").PERIOD
	crystal.position.y = 3.0+sin(clock*TAU/6.0)*.045
	crystal.scale = Vector3.ONE*lerpf(.88,1.0,ratio)
	crystal_light.light_energy = lerpf(.35,2.4,ratio)
	crystal_light.light_color = Color("f05d4f") if ratio < .3 else Color("65dff2")
