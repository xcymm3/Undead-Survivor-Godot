extends Node3D
## Three native authored annexes. All solid props use the world's shared navigation geometry.
@export var section = 0
const Objectives = preload("res://scripts/campaign_objectives.gd")

func _ready() -> void:
	var world = get_parent()
	var ids: Array = [["loading_release","loading_power"],["pump_fault_a","pump_fault_b"],["exit_relay","exit_control"]][section]
	for objective in Objectives.NODES:
		if not ids.has(objective.id): continue
		var p: Vector2 = objective.pos
		world.block("WorkCanopy",Vector3(p.x,4.5,p.y),Vector3(16,.25,12),["786848","526e76","69705e"][section],true,false)
		for side in [-1,1]: world.block("CanopyColumn",Vector3(p.x+side*7,2.2,p.y-4),Vector3(.35,4.4,.35),"505b54")
		world.block("ServiceConsole",Vector3(p.x,.65,p.y-.8),Vector3(.8,1.3,.5),"ba854c")
		world.block("PanelLamp",Vector3(p.x,1.5,p.y-.8),Vector3(.3,.2,.1),"efbc59",false)
		world.objective_labels[objective.id] = world.sign_at(objective.label,Vector3(p.x,3.5 if section == 2 else 2.6,p.y-.9),6)
		var light = OmniLight3D.new()
		light.position = Vector3(p.x,3.8,p.y)
		light.omni_range = 12
		light.light_energy = 1.8
		light.light_color = Color("f4dcb2")
		world.add_child(light)
	if section == 0:
		world.block("Warehouse",Vector3(-49,3,174),Vector3(10,6,25),"82745d")
		world.block("DeliveryTruck",Vector3(-55,1.3,216),Vector3(3,2.6,7),"ac8954")
		for p in [Vector2(-57,199),Vector2(-33,153),Vector2(-32,157)]: world.block("PalletStack",Vector3(p.x,.7,p.y),Vector3(2,1.4,2),"95744e")
		world.sign_at("卸货区 ↑ 货梯开关 → 配电间",Vector3(-70,3,130),7)
	elif section == 1:
		for p in [Vector2(-57,-207),Vector2(-7,-174)]:
			world.cylinder(Vector3(p.x,1.5,p.y),2,3,"687e82")
			var tank = world.block("PumpTankCollision",Vector3(p.x,1.5,p.y),Vector3(4,3,4),"687e82")
			tank.get_child(0).visible = false
			world.block("PumpMotor",Vector3(p.x,1,p.y+3),Vector3(3,2,2),"59737d")
		world.block("WorkAreaDivider",Vector3(-40,1.5,-183),Vector3(1,3,18),"6f7d6e")
		world.sign_at("西维修工位 ↑ → 备用回路",Vector3(-70,3,-145),7)
	else:
		world.block("ServicePartition",Vector3(7,2.5,-180),Vector3(1,5,70),"566a65")
		world.block("RelayCabin",Vector3(53,2,-228),Vector3(12,4,6),"667765")
		for x in [35,45]: world.block("CableRack",Vector3(x,2,-228),Vector3(5,4,2),"54655a")
		world.sign_at("维修通道 ↑ 继电器 → 门控台",Vector3(70,3,-164),7)
