extends Node3D
var Layout = preload("res://scripts/night_layout.gd")
var obstacles: Array = []
var doors: Dictionary = {}
var supplies: Dictionary = {}
var supply_labels: Dictionary = {}
var objective_labels: Dictionary = {}
var materials: Dictionary = {}
var loot_views: Dictionary = {}
var grenade_views: Dictionary = {}
var projectile_views: Dictionary = {}

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
	pass
func sync(state: Dictionary) -> void:
	for loot in state.get("loot",[]):
		if not loot_views.has(loot.id):
			var model = preload("res://scripts/weapon_view.gd").create_model(Data.weapons[loot.weapon].id)
			add_child(model)
			model.position = Vector3(loot.pos.x,0,loot.pos.y+.4)
			model.scale = Vector3.ONE*.7
			model.rotation.z = PI/2
			# Models have different authored pivots. Rest the lowest vertex on the
			# 0.7 m night supply tabletop instead of burying small guns inside it.
			var bottom = INF
			for mesh in model.find_children("*","MeshInstance3D",true,false):
				var bounds: AABB = mesh.global_transform*mesh.get_aabb()
				bottom = minf(bottom,bounds.position.y)
			model.position.y = .72-bottom if is_finite(bottom) else .8
			loot_views[loot.id] = model
		loot_views[loot.id].visible = not loot.taken
	for item in Layout.ITEMS:
		if item.kind != "ammo": continue
		if not grenade_views.has(item.id):
			var prop = preload("res://scripts/campaign_props.gd").model(4)
			add_child(prop)
			prop.position = Vector3(item.pos.x-1,.65,item.pos.y)
			prop.scale = Vector3.ONE*2
			grenade_views[item.id] = prop
		grenade_views[item.id].visible = state.get("grenade_stations",{}).get(item.id,{}).get("remaining",0) > 0
	var live: Array = []
	for projectile in state.get("projectiles",[]):
		live.append(projectile.id)
		if not projectile_views.has(projectile.id):
			var prop = preload("res://scripts/campaign_props.gd").model(4)
			add_child(prop)
			projectile_views[projectile.id] = prop
		projectile_views[projectile.id].position = projectile.pos
		projectile_views[projectile.id].rotation.x = projectile.fuse*8
	for id in projectile_views.keys():
		if not live.has(id):
			projectile_views[id].queue_free()
			projectile_views.erase(id)
	for id in doors:
		var opened: bool = state.get("departed",false) if id == "start" else state.get("gate_open",false) if id == "gate" else state.get("shop_open",false) if id == "street" else state.get("exit_control",false) and not state.get("complete",false)
		var progress: float = float(state.get("bridge_time",0))/90.0 if id == "gate" and not opened else 0.0
		doors[id].position.y = 6.5 if opened else 2+minf(.8,progress)*1.0
		doors[id].collision_layer = 0 if opened else 1
	for item in Layout.ITEMS:
		var available = item.get("party",1) <= state.get("party",1)
		supplies[item.id].visible = available and not state.get("taken",{}).has(item.id)
		supply_labels[item.id].visible = available
		if state.get("taken",{}).has(item.id): supply_labels[item.id].text = "已取走"
		else:
			if item.kind == "med": supply_labels[item.id].text = "医疗 +"
			else:
				var left = state.get("loot",[]).filter(func(loot): return loot.station == item.id and not loot.taken).size()
				var grenades: int = state.get("grenade_stations",{}).get(item.id,{}).get("remaining",0)
				supply_labels[item.id].text = "%s级枪械 %d / 手雷 %d" % [item.tier,left,grenades]
