extends "res://scripts/world_geometry.gd"
const Catalog = preload("res://scripts/preparation_catalog.gd")
const Layout = preload("res://scripts/defense_layout.gd")
var stations: Dictionary = {}
var blueprints: Dictionary = {}
var price_icon: Sprite3D
var focus_label: Label3D
var station_prompt: Node3D
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
	station_prompt = preload("res://scripts/upgrade_station_prompt.gd").new()
	add_child(station_prompt)
	focus_label = station_prompt.focus_label
	price_icon = station_prompt.price_icon
	interaction_ring = station_prompt.ring
	money_flights = preload("res://scripts/coin_view.gd").new()
	add_child(money_flights)

func build_station(entry: Dictionary) -> void:
	var p: Vector3 = entry.position
	var root = Node3D.new()
	root.name = "Station_"+entry.id
	add_child(root)
	root.position = Vector3(p.x,3,p.z)
	root.add_child(preload("res://scripts/upgrade_station_base.gd").new())
	# Keep the same navigation obstacle as the original solid desk.
	get_parent().obstacles.append({"minX":p.x-.95,"maxX":p.x+.95,"minZ":p.z-.625,"maxZ":p.z+.625})
	var prop = Node3D.new()
	prop.name = "DisplayObject"
	root.add_child(prop)
	prop.position.y = 1.25
	if entry.id in ["rifle","pistol","axe","ultimate"]:
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
	elif entry.id in ["rifle_magazine","pistol_magazine"]:
		var origin = prop.global_position
		var before_parts = get_children()
		for x in [-.28,.28]:
			block("MagazineCase",origin+Vector3(x,0,0),Vector3(.23,.48,.18),"485650",false)
			for row in 3: block("MagazineRib",origin+Vector3(x,-.16+row*.14,-.1),Vector3(.25,.035,.04),"788579",false)
			cylinder(origin+Vector3(x,.28,0),.045,.12,"d1aa58")
		for child in get_children():
			if child not in before_parts: child.reparent(prop)
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
	var broken = Node3D.new()
	broken.name = "BrokenDisplay"
	root.add_child(broken)
	for index in 4:
		var shard = MeshInstance3D.new()
		shard.mesh = BoxMesh.new()
		shard.mesh.size = Vector3(.9,.10,.22)
		shard.material_override = material("483a2e")
		shard.position = Vector3(-.65+index*.42,.98+float(index%2)*.09,-.35+float(index%3)*.3)
		shard.rotation = Vector3(.12*index,.45*index,-.15+index*.1)
		broken.add_child(shard)
	for index in 3:
		var crack = MeshInstance3D.new()
		crack.mesh = BoxMesh.new()
		crack.mesh.size = Vector3(.045,.02,.85)
		crack.material_override = material("171d19")
		crack.position = Vector3(-.7+index*.65,.96,0)
		crack.rotation.y = -.3+index*.3
		broken.add_child(crack)
	broken.hide()
	stations[entry.id] = {"broken":broken,"root":root,"prop":prop,"cover":cover,"light":light,"display_basis":prop.basis,"energy_blade":prop.find_child("UltimateLongBlade",true,false)}

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
			var clock = cylinder(p+Vector3(0,.2,0),.42,.12,"d1b060")
			clock.rotation.x = PI/2
			block("ClockHand",p+Vector3(0,.32,-.08),Vector3(.05,.26,.04),"454b48",false)
		"supply":
			block("AmmoCase",p,Vector3(1,.4,.6),"52644a",false)
			for x in [-.3,0,.3]: cylinder(p+Vector3(x,.28,0),.055,.24,"d1aa58")
		"greed":
			block("CoinChest",p,Vector3(.9,.4,.6),"765338",false)
			for x in [-.25,0,.25]:
				for level in 3: cylinder(p+Vector3(x,.24+level*.055,0),.12,.05,"e8bc50")
	for child in get_children():
		if child not in before: child.reparent(parent)

func sync(state: Dictionary) -> void:
	var broken = preload("res://scripts/onboarding.gd").stage(state) == preload("res://scripts/onboarding.gd").FIRST_RUN
	# Narrative gates do not shutter visible merchandise.
	var closed: bool = state.get("started",false) or broken
	for id in stations:
		var station: Dictionary = stations[id]
		station.broken.visible = broken
		station.cover.visible = closed and not broken
		station.prop.visible = not closed
		station.light.light_energy = 0.0 if closed else 1.1
		if station.energy_blade:
			station.energy_blade.sync_energy(not closed,float(state.get("prop_clock",0.0)))
		if not closed and id in ["rifle","pistol","axe"]:
			station.prop.basis = Basis(Vector3.UP,float(state.get("prop_clock",0.0))*TAU/40.0)*station.display_basis
	for item in state.get("structures",[]):
		for marker in blueprints.get(item.id,[]): marker.visible = item.kind == "mine" and not item.get("owned",false) and not state.get("started",false) and preload("res://scripts/onboarding.gd").defenses_open(state)

func sync_focus(sim, p: Dictionary) -> void:
	if not sim.defense.started:
		var id: String = Data.weapons[int(p.weapon)].id
		var station: Dictionary = stations.rifle
		if station.get("held","") != id and id in ["rifle","pistol","axe"]:
			station.held = id
			for old in station.prop.get_children():
				station.prop.remove_child(old)
				old.queue_free()
			var model = preload("res://scripts/weapon_view.gd").create_model(id)
			station.prop.add_child(model)
			var bounds = preload("res://scripts/world_geometry.gd").posed_bounds(model)
			var center = model.to_local(bounds.get_center())
			var factor = 1.4/maxf(.01,bounds.size.length())
			model.scale *= factor
			model.position -= center*factor
	var choice: Dictionary = Catalog.focus(sim,p)
	var shop = get_parent().shop
	if shop and shop.owner_model:
		shop.owner_model.get_node("OwnerName").visible = choice.get("id","") != "shopkeeper" and not preload("res://scripts/onboarding.gd").talking(sim.defense)
	station_prompt.visible = not choice.is_empty()
	interaction_ring.visible = not choice.is_empty()
	var drops: Array = []
	if interaction_ring.visible:
		interaction_ring.position = choice.position+Vector3(0,.45,0)
		var price: int = sim.progression.cost(choice.id) if choice.id not in ["crystal","shopkeeper"] else 0
		var enabled: bool = Catalog.available(sim,choice.id) and sim.progression.data[sim.progression.currency(choice.id)] >= price
		var time: float = p.interact_time if p.get("interaction","") == choice.id else 0.0
		var eye = Vector3(p.pos.x,p.height+preload("res://scripts/player_body.gd").eye_height(p),p.pos.y)
		var status = "ready" if enabled else "maxed" if price < 0 else "error"
		if time <= 0.0 and p.get("work_feedback_id","") == choice.id and p.get("work_feedback_until",0.0) > sim.defense.prop_clock and p.get("work_feedback","") == "完成": status = "complete"
		var currency: Texture2D
		if choice.id not in ["crystal","shopkeeper"] and price >= 0:
			currency = preload("res://scripts/currency_art.gd").diamond() if sim.progression.currency(choice.id) == "diamonds" else preload("res://scripts/currency_art.gd").coin()
		station_prompt.sync(interaction_ring.position,eye,get_viewport().get_camera_3d(),Catalog.prompt_description(sim,choice.id),str(price),currency,time/Catalog.HOLD_SECONDS,enabled,status)
		if enabled and price > 0:
			var from = Vector3(p.pos.x,p.height+.8,p.pos.y)
			var interval = Catalog.payment_interval(price)
			for i in ceili(time/interval):
				var age = time-i*interval
				if age <= 0 or age >= .8: continue
				var angle = i*2.39996
				var scatter = from+Vector3(cos(angle),0,sin(angle))*(.7+fmod(i*.37,.8))
				var t = clampf((age-.24)/.56,0,1)
				var point = from.lerp(scatter,minf(1,age/.24)) if age < .24 else scatter.lerp(choice.position,t*t)
				point.y += sin(minf(1,age/.24)*PI)*.5 if age < .24 else sin(t*PI)*.4
				drops.append({"pos":point,"age":age,"value":1,"scale":.25,"arrival":maxf(0,(t-.8)*5)})
	var payment_age: float = sim.defense.prop_clock-float(sim.defense.get("tutorial_payment_at",-100))
	if payment_age >= 0 and payment_age < 2.2:
		var source: Vector3 = sim.defense.get("tutorial_payment_from",Vector3.ZERO)
		var destination = Vector3(Layout.SHOP_OWNER.x,4.2,Layout.SHOP_OWNER.y)
		for index in 12:
			var age = payment_age-index*.07
			if age < 0 or age > 1.2: continue
			var progress = age/1.2
			var point = source.lerp(destination,smoothstep(0,1,progress))+Vector3.UP*sin(progress*PI)*.6
			drops.append({"pos":point,"age":age,"value":1,"scale":.25,"arrival":maxf(0,(progress-.8)*5)})
	money_flights.sync(drops)
	focus_label.visible = not choice.is_empty()
	if choice.is_empty(): price_icon.hide()
