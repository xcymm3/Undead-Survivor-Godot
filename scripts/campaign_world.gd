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
var medical_views: Dictionary = {}
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
	var backing = block("Sign",pos,Vector3(width,.55*text.split("\n").size()+.15,.18),"273e36",false)
	var label = Label3D.new()
	label.set_meta("backing",backing)
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
	for prop in medical_views.values(): prop.visible = false
	for loot in state.get("loot",[]):
		if not loot_views.has(loot.id):
			var model = preload("res://scripts/weapon_view.gd").create_model(Data.weapons[loot.weapon].id)
			add_child(model)
			# Wall-mounted side profile; normalize authored model pivots and sizes.
			model.rotation.y = PI/2
			var bounds = posed_bounds(model)
			var factor = minf(1.1/maxf(bounds.size.x,.01),.42/maxf(bounds.size.y,.01))
			model.scale *= factor
			model.position = Vector3(loot.pos.x,loot.get("mount_height",1.5),loot.pos.y)-bounds.get_center()*factor
			loot_views[loot.id] = model
		loot_views[loot.id].visible = not loot.taken
	for item in Layout.ITEMS:
		for index in int(state.get("party",1)):
			var id = item.id+"_medical_"+str(index)
			if not medical_views.has(id):
				var prop = preload("res://scripts/campaign_props.gd").model(5)
				add_child(prop)
				medical_views[id] = prop
			var point: Vector2 = item.pos+Vector2(1,0) if item.kind == "ammo" else item.pos
			var offset = Vector2((index%2-.5)*.36 if state.get("party",1) > 1 else 0,floori(index/2.0)*.34)
			medical_views[id].position = Vector3(point.x+offset.x,.83,point.y+offset.y)
			medical_views[id].rotation.y = PI
			medical_views[id].visible = index < state.get("medical_stations",{}).get(item.id,{}).get("remaining",0)
		if item.kind != "ammo": continue
		if not grenade_views.has(item.id):
			var prop = preload("res://scripts/campaign_props.gd").model(4)
			add_child(prop)
			prop.position = Vector3(item.pos.x-1,.85,item.pos.y)
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
			if item.kind == "med": supply_labels[item.id].text = "医疗包 %d" % state.get("medical_stations",{}).get(item.id,{}).get("remaining",0)
			else:
				supply_labels[item.id].position.y = 2.2+maxi(0,int(state.get("party",1))-1)*.55
				supply_labels[item.id].get_meta("backing").position.y = supply_labels[item.id].position.y
				var left = state.get("loot",[]).filter(func(loot): return loot.station == item.id and not loot.taken).size()
				var grenades: int = state.get("grenade_stations",{}).get(item.id,{}).get("remaining",0)
				supply_labels[item.id].text = "E 换枪 · %s级 %d / 手雷 %d / 医疗 %d" % [item.tier,left,grenades,state.get("medical_stations",{}).get(item.id,{}).get("remaining",0)]
		var width = 3.0 if item.kind == "ammo" else 1.4
		supply_labels[item.id].pixel_size = minf(.006,width*.82/(64*maxi(1,supply_labels[item.id].text.length())))

static func posed_bounds(model: Node3D) -> AABB:
	# Imported skins use a vertical bind pose but a horizontal displayed pose.
	# Fit the displayed vertices, not the unskinned import bounding box.
	var result = AABB()
	var first = true
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		var skeleton = mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
		var transforms: Array[Transform3D] = []
		if mesh.skin and skeleton:
			for i in mesh.skin.get_bind_count():
				var bone: int = mesh.skin.get_bind_bone(i)
				if bone < 0: bone = skeleton.find_bone(mesh.skin.get_bind_name(i))
				transforms.append(skeleton.global_transform*skeleton.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(i) if bone >= 0 else mesh.global_transform)
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones = arrays[Mesh.ARRAY_BONES]
			var weights = arrays[Mesh.ARRAY_WEIGHTS]
			for i in vertices.size():
				var point: Vector3 = mesh.global_transform*vertices[i]
				if not transforms.is_empty() and bones != null and weights != null and weights.size() > 0:
					point = Vector3.ZERO
					var count: int = weights.size()/vertices.size()
					for j in count:
						var bind: int = bones[i*count+j]
						if weights[i*count+j] > 0 and bind < transforms.size(): point += (transforms[bind]*vertices[i])*weights[i*count+j]
				# Reload-only cartridges are parked far below the imported gun.
				if point.distance_squared_to(model.global_position) > 16: continue
				result = AABB(point,Vector3.ZERO) if first else result.expand(point)
				first = false
	return result
