extends "res://scripts/world_geometry.gd"
const Catalog = preload("res://scripts/preparation_catalog.gd")
const Layout = preload("res://scripts/defense_layout.gd")
var stations: Dictionary = {}
var blueprints: Dictionary = {}
var focus_label: Label3D
var alarm_light: OmniLight3D
var interaction_ring: Node3D
var money_flights

func _ready() -> void:
	for entry in Catalog.stations(): build_station(entry)
	for item in preload("res://scripts/defense_structures.gd").initial_state():
		var marker = Node3D.new()
		marker.name = "Construction_"+item.id
		marker.position = Vector3(-4.65 if item.kind == "gate" else item.pos.x,item.height,item.pos.y)
		add_child(marker)
		var base = block("BuildBase",marker.position+Vector3(0,.08,0),Vector3(1.1,.16,.85),"424a48",false)
		var chest = block("Toolbox",marker.position+Vector3(0,.32,0),Vector3(.78,.38,.48),"b2873e",false)
		var stripe = block("ToolboxStripe",marker.position+Vector3(0,.52,0),Vector3(.8,.04,.13),"ebc66b",false)
		blueprints[item.id] = [base,chest,stripe]
	focus_label = Label3D.new()
	focus_label.name = "FocusedInformation"
	focus_label.font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	focus_label.font_size = 36
	focus_label.pixel_size = .0026
	focus_label.outline_size = 5
	focus_label.modulate = Color("fff0ca")
	focus_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Visibility is gated by the authority's scenery ray; the owner's mesh must
	# not hide its own contextual text (notably the tall crystal).
	focus_label.no_depth_test = true
	focus_label.visible = false
	add_child(focus_label)
	interaction_ring = preload("res://scripts/interaction_ring.gd").new()
	add_child(interaction_ring)
	interaction_ring.hide()
	money_flights = preload("res://scripts/coin_view.gd").new()
	add_child(money_flights)

func build_station(entry: Dictionary) -> void:
	var p: Vector3 = entry.position
	var root = Node3D.new()
	root.name = "Station_"+entry.id
	add_child(root)
	root.position = Vector3(p.x,3,p.z)
	var before = get_children()
	block("StationFoot",Vector3(p.x,3.13,p.z),Vector3(2.2,.26,1.5),"303c3b",false)
	block("StationDesk",Vector3(p.x,3.52,p.z),Vector3(1.9,.65,1.25),"66513b",true,false)
	# Enemies can enter the shop; only actual solid furniture blocks their route.
	get_parent().obstacles.append({"minX":p.x-.95,"maxX":p.x+.95,"minZ":p.z-.625,"maxZ":p.z+.625})
	block("StationTop",Vector3(p.x,3.89,p.z),Vector3(2.12,.1,1.4),"b5a581",false)
	block("StationTrim",Vector3(p.x,3.95,p.z+.67),Vector3(2.12,.06,.07),"d1b060",false)
	for child in get_children():
		if child not in before: child.reparent(root)
	var prop = Node3D.new()
	prop.name = "DisplayObject"
	root.add_child(prop)
	prop.position.y = 1.25
	if entry.id in ["rifle","pistol","axe"]:
		var model = preload("res://scripts/weapon_view.gd").create_model(entry.id)
		prop.add_child(model)
		var bounds = preload("res://scripts/world_geometry.gd").posed_bounds(model)
		var center = model.to_local(bounds.get_center())
		var factor: float = 1.45/maxf(.01,bounds.size.length())
		model.scale *= factor
		model.position -= center*factor
		model.rotation.z = -.15
		if bounds.size.y > maxf(bounds.size.x,bounds.size.z): prop.rotation.z = PI/2
		elif bounds.size.z > bounds.size.x: prop.rotation.y = PI/2
		var fitted: AABB = preload("res://scripts/world_geometry.gd").posed_bounds(model)
		prop.position.y += maxf(0,3.98-fitted.position.y)
	elif entry.id == "grenade":
		for x in [-.45,0,.45]:
			var model = preload("res://scripts/equipment_props.gd").model(4)
			prop.add_child(model)
			model.position.x = x
	else:
		build_talent(prop,entry.id)
	var cover = MeshInstance3D.new()
	cover.name = "ClosedCover"
	var mesh = BoxMesh.new()
	mesh.size = Vector3(2.15,1.25,1.43)
	cover.mesh = mesh
	cover.material_override = material("3b474a")
	cover.position.y = 1.6
	root.add_child(cover)
	for side in [-1.0,1.0]:
		for level in 6:
			var rib = MeshInstance3D.new()
			var rib_mesh = BoxMesh.new()
			rib_mesh.size = Vector3(2.12,.035,.04)
			rib.mesh = rib_mesh
			rib.material_override = material("596568")
			rib.position = Vector3(0,-.5+level*.2,side*.73)
			cover.add_child(rib)
	cover.visible = false
	var light = OmniLight3D.new()
	light.position = Vector3(0,2.2,0)
	light.light_color = Color("ffdfa1")
	light.light_energy = 1.1
	light.omni_range = 3.8
	root.add_child(light)
	stations[entry.id] = {"root":root,"prop":prop,"cover":cover,"light":light,"display_basis":prop.basis}
	if entry.id == "alarm":
		alarm_light = light
		light.light_color = Color("72e6b0")

func build_talent(parent: Node3D, id: String) -> void:
	var before = get_children()
	var p = parent.global_position
	match id:
		"strong":
			block("MedicalCase",p,Vector3(1,.5,.6),"dddac9",false)
			for side in [-1.0,1.0]:
				block("MedicalCrossH",p+Vector3(0,0,side*.31),Vector3(.45,.1,.02),"bf4e40",false)
				block("MedicalCrossV",p+Vector3(0,0,side*.32),Vector3(.1,.35,.02),"bf4e40",false)
		"precise":
			for side in [-1.0,1.0]:
				for r in [ .48,.32,.15 ]:
					var disk = cylinder(p+Vector3(0,.22,side*(.04+(.48-r)*.2)),r,.04,"e2d9bd" if r == .48 else "a94c3c" if r == .32 else "e2d9bd")
					disk.rotation = Vector3(PI/2,0,0)
		"swift":
			for x in [-.35,.35]:
				block("TrainingWeight",p+Vector3(x,0,0),Vector3(.2,.5,.5),"454b48",false)
			block("TrainingGrip",p,Vector3(.7,.1,.1),"b4b9b0",false)
		"supply":
			block("AmmoCase",p,Vector3(1,.4,.6),"52644a",false)
			for x in [-.3,0,.3]: cylinder(p+Vector3(x,.28,0),.055,.24,"d1aa58")
		"alarm":
			block("AlarmControl",p,Vector3(.55,.48,.25),"a94535",false)
			block("AlarmLever",p+Vector3(0,.3,.1),Vector3(.14,.35,.12),"efb46c",false)
	for child in get_children():
		if child not in before: child.reparent(parent)

func sync(state: Dictionary) -> void:
	var closed: bool = state.get("started",false)
	for id in stations:
		var station: Dictionary = stations[id]
		station.cover.visible = closed and id != "alarm"
		station.prop.visible = not closed or id == "alarm"
		station.light.light_energy = 0.0 if closed else 1.1
		if id in ["rifle","pistol","axe"]:
			station.prop.basis = Basis(Vector3.UP,float(state.get("prop_clock",0.0))*TAU/40.0)*station.display_basis
	if alarm_light:
		alarm_light.light_color = Color("ff654b") if closed else Color("72e6b0")
		alarm_light.light_energy = 1.5 if closed else 1.1
	for item in state.get("structures",[]):
		for marker in blueprints.get(item.id,[]): marker.visible = not item.get("owned",false) and not closed

func sync_focus(sim, p: Dictionary) -> void:
	var choice: Dictionary = Catalog.focus(sim,p)
	interaction_ring.visible = not choice.is_empty() and Catalog.available(sim,choice.get("id",""))
	var drops: Array = []
	if interaction_ring.visible:
		interaction_ring.position = choice.position+Vector3(0,.38,0)
		var price: int = sim.progression.cost(choice.id) if choice.id != "alarm" else 0
		var enabled: bool = sim.progression.data[sim.progression.currency(choice.id)] >= price
		var time: float = p.interact_time if p.get("interaction","") == choice.id else 0.0
		var eye = Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p),p.pos.y)
		interaction_ring.sync(time/Catalog.HOLD_SECONDS,eye,enabled)
		if enabled and price > 0:
			var from = eye+Basis.from_euler(Vector3(p.pitch,p.yaw,0))*Vector3(.3,-.35,-.6)
			var interval = Catalog.payment_interval(price)
			for i in ceili(time/interval):
				var age = time-i*interval
				if age <= 0 or age >= .8: continue
				var t = age/.8
				var point = from.lerp(choice.position,t)+Vector3(0,sin(t*PI)*.23,0)
				drops.append({"pos":point,"age":age,"value":1,"scale":.2,"arrival":maxf(0,(t-.8)*5)})
	money_flights.sync(drops)
	focus_label.visible = not choice.is_empty()
	if choice.is_empty(): return
	var text = Catalog.description(sim,choice.id)
	if Catalog.available(sim,choice.id):
		var price: int = sim.progression.cost(choice.id) if choice.id != "alarm" else 0
		var wallet = sim.progression.currency(choice.id)
		if sim.progression.data[wallet] < price: text += "\n钻石不足" if wallet == "diamonds" else "\n金币不足"
	if p.get("work_feedback_id","") == choice.id and p.get("work_feedback_until",0.0) > sim.defense.prop_clock: text += "\n"+p.work_feedback
	focus_label.text = text
	focus_label.position = choice.position+Vector3(0,.95,0)
