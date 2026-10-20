extends "res://scripts/world_geometry.gd"
## Solid armory shell, rear sleeping room and an anonymous shopkeeper.
const Layout = preload("res://scripts/defense_layout.gd")
var owner_model: Node3D
var owner_head: Node3D
var owner_chest: Node3D
var owner_clock = 0.0
var owner_clock_ready = false
var owner_target = Vector3.ZERO
var owner_talking = false
var owner_head_yaw = 0.0
var owner_alert: Label3D
var owner_dialogue: Label3D

func _ready() -> void:
	var area: Rect2 = Layout.SHOP_AREA
	var front: float = Layout.SHOP_FRONT_Z
	var rear: float = area.end.y
	var middle: float = area.get_center().y
	var height: float = Layout.SHOP_CEILING_Y-3.0
	var y: float = 3.0+height*.5
	block("ShopFrontWall",Vector3(0,y,front),Vector3(26.6,height,.5),"8b8970")
	block("ShopRearWall",Vector3(0,y,rear),Vector3(26.6,height,.5),"8b8970")
	block("ShopWestWall",Vector3(-13,y,middle),Vector3(.5,height,20),"8b8970")
	# A side-facing door keeps the crystal hidden behind the opaque front wall.
	var a: float = Layout.SHOP_DOOR_Z-Layout.SHOP_DOOR_WIDTH/2
	var b: float = Layout.SHOP_DOOR_Z+Layout.SHOP_DOOR_WIDTH/2
	block("ShopEastWallFront",Vector3(13,y,(front+a)/2),Vector3(.5,height,a-front),"8b8970")
	block("ShopEastWallRear",Vector3(13,y,(rear+b)/2),Vector3(.5,height,rear-b),"8b8970")
	block("ShopDoorLintel",Vector3(13,6.95,Layout.SHOP_DOOR_Z),Vector3(.65,1.1,Layout.SHOP_DOOR_WIDTH),"554735",true,false)
	# Roof and overhead beams collide in 3D but never mark the floor as unwalkable.
	block("ShopRoof",Vector3(0,Layout.SHOP_CEILING_Y+.08,middle),Vector3(26.4,.16,20.4),"6b705b",true,false)
	for z in [front+2,front+8,front+14,front+19]:
		block("CeilingBeam",Vector3(0,7.3,z),Vector3(26,.25,.2),"625239",true,false)
	var exterior = preload("res://scripts/weapon_shop_exterior.gd").new()
	exterior.name = "Storefront"
	add_child(exterior)
	obstacles.append_array(exterior.obstacles)
	for x in [-12.65,12.65]:
		for z in [front+.35,rear-.35]:
			block("TimberCornerPost",Vector3(x,y,z),Vector3(.24,height,.24),"755b3c",false)
	# Offset passage forces a walk through the showroom rather than a rear exit.
	var left: float = Layout.SHOP_PASSAGE_X-2
	var right: float = Layout.SHOP_PASSAGE_X+2
	block("BackroomDividerLeft",Vector3((-13+left)/2,y,Layout.SHOP_PARTITION_Z),Vector3(left+13,height,.35),"4a5145")
	block("BackroomDividerRight",Vector3((right+13)/2,y,Layout.SHOP_PARTITION_Z),Vector3(13-right,height,.35),"4a5145")
	block("BackroomLintel",Vector3(Layout.SHOP_PASSAGE_X,7.0,Layout.SHOP_PARTITION_Z),Vector3(4,1,.4),"756043",true,false)
	for z in [a,b]:
		block("DoorFrame",Vector3(13.05,4.7,z),Vector3(.7,3.4,.16),"b29a64",false)
	block("DoorThreshold",Vector3(13,3.04,Layout.SHOP_DOOR_Z),Vector3(1.3,.08,4),"827656",false)
	var bedroom = preload("res://scripts/shop_bedroom.gd").new()
	bedroom.name = "Bedroom"
	add_child(bedroom)
	obstacles.append_array(bedroom.obstacles)
	for pos in [Vector3(-6,6.7,front+5),Vector3(6,6.7,front+5),Vector3(0,6.7,front+10),Vector3(-5,6.7,rear-2.5)]:
		block("WarmLampHousing",pos+Vector3(0,.14,0),Vector3(.85,.15,.6),"514b37",false)
		var panel = block("WarmLampGlass",pos,Vector3(.65,.06,.42),"ffe1a0",false)
		var lamp_mat = material("ffe1a0")
		lamp_mat.emission_enabled = true
		lamp_mat.emission = Color("ffd28a")
		panel.get_child(0).material_override = lamp_mat
		var light = OmniLight3D.new()
		light.position = pos-Vector3(0,.2,0)
		light.light_color = Color("ffd397")
		light.light_energy = 2.0
		light.omni_range = 10
		light.shadow_enabled = true
		add_child(light)
	build_owner()

func build_owner() -> void:
	var pos = Vector3(Layout.SHOP_OWNER.x,3,Layout.SHOP_OWNER.y)
	# Join the east wall and rear partition: no gap beside the counter.
	block("OwnerCounter",pos+Vector3(.3,.58,-1.05),Vector3(5.4,1.16,.9),"624c33")
	block("CounterReturnCabinet",pos+Vector3(-2.2,.66,.1),Vector3(.6,1.32,2.5),"624c33")
	block("CounterReturnTop",pos+Vector3(-2.2,1.36,.1),Vector3(.75,.12,2.65),"b2a079",false)
	for x in [-1.5,-.45,.6,1.65,2.55]:
		block("CounterCabinetDoor",pos+Vector3(x,.57,-1.515),Vector3(.88,.96,.06),"80613f",false)
		block("CounterDoorInset",pos+Vector3(x,.57,-1.555),Vector3(.68,.71,.03),"6d5034",false)
		block("CounterHandle",pos+Vector3(x+.25,.77,-1.60),Vector3(.05,.17,.06),"c2a16b",false)
	# Movement-only collision reaches the ceiling without blocking dialogue rays.
	for barrier in [["CounterFrontBarrier",Vector3(.3,2.25,-1.05),Vector3(5.4,4.5,.9)],["CounterSideBarrier",Vector3(-2.2,2.25,.1),Vector3(.6,4.5,2.5)]]:
		var wall = block(barrier[0],pos+barrier[1],barrier[2],"624c33",true,false)
		wall.collision_layer = preload("res://scripts/player_body.gd").MOVEMENT_BARRIER_LAYER
		wall.get_child(0).hide()
	block("OwnerCounterTop",pos+Vector3(.3,1.2,-1.05),Vector3(5.55,.12,1.05),"b2a079",false)
	for x in [-1.45,0,1.45]:
		block("CounterBrassTrim",pos+Vector3(x,.65,-1.51),Vector3(.07,.8,.03),"b39359",false)
	owner_model = Node3D.new()
	owner_model.name = "WeaponShopOwner"
	owner_model.position = pos
	owner_model.set_meta("npc_name","武器店老板")
	owner_model.set_meta("face_concealed",true)
	add_child(owner_model)
	owner_chest = Node3D.new()
	owner_chest.name = "BreathingTorso"
	owner_model.add_child(owner_chest)
	owner_head = Node3D.new()
	owner_head.name = "TurningHead"
	owner_head.position.y = 1.45
	owner_chest.add_child(owner_head)
	var before = get_children()
	# All head surfaces are opaque fabric: no eyes, mouth or skin underneath.
	block("OwnerBootLeft",pos+Vector3(-.16,.15,0),Vector3(.23,.3,.36),"262c29",false)
	block("OwnerBootRight",pos+Vector3(.16,.15,0),Vector3(.23,.3,.36),"262c29",false)
	var coat = cylinder(pos+Vector3(0,.82,0),.39,1.13,"333b32")
	coat.mesh.top_radius = .28
	block("OwnerShoulders",pos+Vector3(0,1.35,0),Vector3(.76,.27,.36),"41483b",false)
	block("OwnerApron",pos+Vector3(0,.95,-.25),Vector3(.48,.8,.08),"776044",false)
	block("ApronPocket",pos+Vector3(0,.91,-.3),Vector3(.33,.18,.04),"a18a5c",false)
	for side in [-1.0,1.0]:
		var arm = block("OwnerSleeve",pos+Vector3(side*.38,1.17,-.13),Vector3(.23,.53,.28),"41483b",false)
		arm.rotation.x = -.55
		block("OwnerGlove",pos+Vector3(side*.38,1.25,-.49),Vector3(.23,.16,.28),"292e29",false)
	var hood = cylinder(pos+Vector3(0,1.67,0),.3,.55,"2b332e")
	hood.mesh.top_radius = .22
	hood.mesh.radial_segments = 8
	block("OpaqueFaceWrap",pos+Vector3(0,1.65,-.255),Vector3(.37,.36,.08),"111b18",false)
	block("HoodBrow",pos+Vector3(0,1.86,-.2),Vector3(.5,.12,.25),"333b32",false)
	for child in get_children():
		if child not in before:
			if child == hood or child.name in ["OpaqueFaceWrap","HoodBrow"]: child.reparent(owner_head)
			elif child.name.begins_with("OwnerBoot"): child.reparent(owner_model)
			else: child.reparent(owner_chest)
	# The static NPC is not a combat pawn; the counter and body share nav cover.
	block("OwnerCollision",pos+Vector3(0,.9,0),Vector3(.8,1.8,.65),"333b32").get_child(0).hide()
	var title = Label3D.new()
	title.name = "OwnerName"
	title.text = "武器店老板"
	title.font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	title.font_size = 36
	title.pixel_size = .0045
	title.position = Vector3(0,2.28,0)
	title.modulate = Color("e4cf9b")
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	owner_model.add_child(title)

	owner_alert = Label3D.new()
	owner_alert.name = "TutorialExclamation"
	owner_alert.font = title.font
	owner_alert.text = "!"
	owner_alert.font_size = 100
	owner_alert.pixel_size = .005
	owner_alert.position.y = 2.9
	owner_alert.modulate = Color("ffd263")
	owner_alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	owner_model.add_child(owner_alert)
	owner_dialogue = Label3D.new()
	owner_dialogue.name = "OwnerDialogue"
	owner_dialogue.font = preload("res://assets/fonts/SmileySans-Oblique.otf")
	owner_dialogue.font_size = 42
	owner_dialogue.pixel_size = .003
	owner_dialogue.position.y = 2.85
	owner_dialogue.width = 1150
	owner_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner_dialogue.outline_size = 6
	owner_dialogue.modulate = Color("fff0d1")
	owner_dialogue.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	owner_model.add_child(owner_dialogue)
	sync({"tutorial_stage":0})

func sync(state: Dictionary) -> void:
	if not owner_model: return
	var tutorial = preload("res://scripts/onboarding.gd")
	owner_talking = tutorial.talking(state)
	owner_target = state.get("tutorial_speaker_eye",Vector3(Layout.SHOP_OWNER.x,4.7,Layout.SHOP_OWNER.y-3))
	var clock: float = state.get("prop_clock",0.0)
	var dt = maxf(0,clock-owner_clock) if owner_clock_ready else 0.0
	owner_clock = clock
	owner_clock_ready = true
	pose_owner(dt,clock)
	owner_model.visible = tutorial.stage(state) != tutorial.FIRST_RUN
	owner_alert.visible = tutorial.pending(state) and not tutorial.talking(state)
	owner_alert.position.y = 2.9+sin(float(state.get("prop_clock",0))*3)*.06
	owner_model.get_node("OwnerName").visible = not tutorial.talking(state)
	owner_dialogue.visible = tutorial.talking(state)
	owner_dialogue.text = tutorial.dialogue_frame(state).text
	get_node("OwnerCollision").collision_layer = 1 if owner_model.visible else 0

func pose_owner(dt: float, clock: float) -> void:
	# Torso motion leaves boots, collision and dialogue lettering stationary.
	var breath = sin(clock*TAU/4.2)
	owner_chest.position.y = breath*.012
	owner_chest.rotation.z = sin(clock*TAU/5.6)*.008
	owner_chest.scale = Vector3(1.0+breath*.006,1.0,1.0+breath*.008)
	var target_yaw = 0.0
	if owner_talking:
		var toward = owner_target-Vector3(Layout.SHOP_OWNER.x,4.65,Layout.SHOP_OWNER.y)
		target_yaw = clampf(atan2(-toward.x,-toward.z),-1.22,1.22)
	owner_head_yaw = move_toward(owner_head_yaw,target_yaw,dt*2.4)
	owner_head.rotation.y = owner_head_yaw
	owner_head.rotation.x = sin(clock*3.2)*.018 if owner_talking else breath*.008
