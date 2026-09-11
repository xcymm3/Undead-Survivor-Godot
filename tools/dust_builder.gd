extends Node3D
const Layout = preload("res://scripts/dust_layout.gd")
var regions: Array[PackedVector2Array] = Layout.polygons()
var obstacles: Array = []
var stone: ShaderMaterial
var trim: StandardMaterial3D
var wood: StandardMaterial3D
var iron: StandardMaterial3D
var sequence = 0

func _ready() -> void:
	name = "DesertCity"
	stone = ShaderMaterial.new()
	stone.resource_scene_unique_id = "Sandstone"
	stone.shader = preload("res://scripts/sandstone.gdshader")
	trim = material("StoneTrim",Color("b18b56"))
	wood = material("WeatheredWood",Color("715333"))
	iron = material("IronBands",Color("343e3d"))
	build_floor()
	build_boundary()
	for c in Layout.CRATES:
		if c[0] == 264: continue # Preserve the narrow hallway's movement clearance.
		crate(Layout.point(c[0],c[1]),Vector3(c[2]*Layout.SCALE,c[4],c[3]*Layout.SCALE))
	# The covered inverted-T hallway joins the two exterior approach routes.
	roof(285,295,392,330,5.8)
	roof(337,327,369,402,5.8)
	arch(Layout.point(269,258),4.6,0)
	arch(Layout.point(419,238),2.8,PI/2)
	arch(Layout.point(525,296),5.9,PI/2)
	arch(Layout.point(287,439),5.2,PI/2)
	for pixel in [Vector2(350,314),Vector2(353,371)]:
		var pos = Layout.point(pixel.x,pixel.y)
		var light = OmniLight3D.new()
		light.name = "TunnelLantern_%d" % sequence
		sequence += 1
		light.position = Vector3(pos.x,3.8,pos.y)
		light.light_color = Color("ffc57f")
		light.light_energy = 1.4
		light.omni_range = 12
		add_child(light)
		box("Lantern",light.position,Vector3(.28,.42,.28),material("Lamp_%d" % sequence,Color("ffcf89")),false)
	# Buildings occupy the closed blocks in the overview; parapets frame the skyline.
	building(219,334,26,121,10)
	building(404,330,19,131,8)
	building(575,357,31,41,7)
	building(652,356,60,46,6.5)
	marker("A",Layout.point(445,85),Color("a0492d"))
	marker("B",Layout.point(701,292),Color("a0492d"))
	signpost("A  →",Layout.point(455,273),PI,Color("985035"))
	signpost("←  B",Layout.point(456,350),PI/2,Color("985035"))
	set_meta("navigation_obstacles",obstacles)
	set_meta("map_id","dust")
	set_meta("reference","https://www.johnsto.co.uk/design/making-dust/")

func material(id: String, color: Color) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.resource_scene_unique_id = id
	result.albedo_color = color
	result.roughness = .92
	return result

func inside(p: Vector2) -> bool:
	for polygon in regions:
		if Geometry2D.is_point_in_polygon(p,polygon): return true
	return false

func build_floor() -> void:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces = PackedVector3Array()
	# Shared height function gives players, enemies and the visible slopes one surface.
	var cell = .35
	for iz in range(252):
		for ix in range(292):
			var p = Vector2(-50+ix*cell,-44+iz*cell)
			if not inside(p+Vector2.ONE*cell*.5): continue
			var corners: Array[Vector3] = []
			for offset in [Vector2.ZERO,Vector2(cell,0),Vector2(cell,cell),Vector2(0,cell)]:
				var point: Vector2 = p+offset
				corners.append(Vector3(point.x,Layout.height(point),point.y))
			for tri in [[0,1,2],[0,2,3]]:
				var normal = (corners[tri[2]]-corners[tri[0]]).cross(corners[tri[1]]-corners[tri[0]]).normalized()
				for i in tri:
					surface.set_normal(normal)
					surface.set_uv(Vector2(corners[i].x,corners[i].z)*.4)
					surface.add_vertex(corners[i])
					faces.append(corners[i])
	var view = MeshInstance3D.new()
	view.name = "CourtyardsAndSlopes"
	view.mesh = surface.commit()
	view.mesh.resource_scene_unique_id = "DustFloor"
	view.material_override = material("SandFloor",Color("c2a779"))
	add_child(view)
	var body = StaticBody3D.new()
	body.name = "FloorCollision"
	var shape = ConcavePolygonShape3D.new()
	shape.resource_scene_unique_id = "FloorShape"
	shape.backface_collision = true
	shape.set_faces(faces)
	var collider = CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	view.add_child(body)

func build_boundary() -> void:
	var emitted = {}
	for polygon in regions:
		for i in polygon.size():
			var a = polygon[i]
			var b = polygon[(i+1)%polygon.size()]
			var delta = b-a
			var cuts: Array[float] = [0.0,1.0]
			for other in regions:
				for j in other.size():
					var c = other[j]
					var d = other[(j+1)%other.size()]
					var hit = Geometry2D.segment_intersects_segment(a,b,c,d)
					if hit != null: cuts.append(clampf((hit-a).dot(delta)/delta.length_squared(),0,1))
					var t = (c-a).dot(delta)/delta.length_squared()
					if t > 0 and t < 1 and (a+delta*t).distance_to(c) < .001: cuts.append(t)
			cuts.sort()
			for j in range(cuts.size()-1):
				var start = a+delta*cuts[j]
				var end = a+delta*cuts[j+1]
				if start.distance_to(end) < .02: continue
				var center = (start+end)*.5
				var normal = Vector2(-delta.y,delta.x).normalized()
				var left = inside(center+normal*.015)
				var right = inside(center-normal*.015)
				if left == right: continue
				var key = str(center.snapped(Vector2.ONE*.001))
				if emitted.has(key): continue
				emitted[key] = true
				center += normal*(-.28 if left else .28)
				var angle = -atan2(delta.y,delta.x)
				var length = start.distance_to(end)
				var plan = ((start+end)*.5)/Layout.SCALE+Layout.ORIGIN
				var overlook = plan.x > 347 and plan.x < 419 and plan.y >= 158 and plan.y <= 162
				var top = 1.05 if overlook else 7.4
				var bottom = -2.2
				box("Overlook" if overlook else "CityWall",Vector3(center.x,(top+bottom)*.5,center.y),Vector3(length+.08,top-bottom,.6),stone,true,angle,true)
				box("Parapet",Vector3(center.x,top,center.y),Vector3(length+.12,.22,.85),trim,false,angle)
				box("WallFoot",Vector3(center.x,.22,center.y),Vector3(length+.10,.38,.76),trim,false,angle)

func box(title: String, pos: Vector3, size: Vector3, mat: Material, collision: bool, angle := 0.0, navigation := false) -> MeshInstance3D:
	sequence += 1
	var view = MeshInstance3D.new()
	view.name = "%s_%03d" % [title,sequence]
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh.resource_scene_unique_id = "Box_%03d" % sequence
	view.mesh = mesh
	view.material_override = mat
	view.position = pos
	view.rotation.y = angle
	add_child(view)
	if collision:
		var body = StaticBody3D.new()
		body.name = "Collision"
		var shape = BoxShape3D.new()
		shape.size = size
		shape.resource_scene_unique_id = "Shape_%03d" % sequence
		var collider = CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		view.add_child(body)
	if navigation:
		var bounds = view.transform*AABB(-size*.5,size)
		obstacles.append({"minX":bounds.position.x,"maxX":bounds.end.x,"minZ":bounds.position.z,"maxZ":bounds.end.z})
	return view

func crate(p: Vector2, size: Vector3) -> void:
	var base = Layout.height(p)
	box("SupplyCrate",Vector3(p.x,base+size.y*.5,p.y),size,wood,true,0,true)
	for height in [.16,size.y-.16]:
		box("CrateBand",Vector3(p.x,base+height,p.y),Vector3(size.x+.04,.12,size.z+.04),iron,false)
	for offset in [-size.x*.35,size.x*.35]:
		box("CrateSlat",Vector3(p.x+offset,base+size.y*.5,p.y),Vector3(.1,size.y+.03,size.z+.04),trim,false)

func roof(x0: float, z0: float, x1: float, z1: float, height: float) -> void:
	var center = Layout.point((x0+x1)*.5,(z0+z1)*.5)
	box("TunnelVault",Vector3(center.x,height,center.y),Vector3((x1-x0)*Layout.SCALE,.55,(z1-z0)*Layout.SCALE),stone,true)

func arch(p: Vector2, width: float, angle: float) -> void:
	var basis = Basis(Vector3.UP,angle)
	var origin = Vector3(p.x,Layout.height(p)+3.7,p.y)
	for i in 14:
		var a = (i+.5)*PI/14
		var offset = Vector3(cos(a)*width*.5,sin(a)*width*.5,0)
		var view = box("ArchStone",origin+basis*offset,Vector3(width*PI/28+.04,.36,.85),trim,true)
		view.basis = basis*Basis(Vector3.BACK,a+PI/2)

func building(x: float, z: float, width: float, depth: float, height: float) -> void:
	var p = Layout.point(x,z)
	box("ClosedBuilding",Vector3(p.x,height*.5,p.y),Vector3(width*Layout.SCALE,height,depth*Layout.SCALE),stone,true,0,true)
	box("RoofCornice",Vector3(p.x,height,p.y),Vector3(width*Layout.SCALE+.3,.3,depth*Layout.SCALE+.3),trim,false)

func marker(title: String, p: Vector2, color: Color) -> void:
	var label = Label3D.new()
	label.name = "Site"+title
	label.text = title
	label.font_size = 180
	label.pixel_size = .02
	label.modulate = color
	label.outline_size = 0
	label.position = Vector3(p.x,Layout.height(p)+.04,p.y)
	label.rotation_degrees.x = -90
	add_child(label)

func signpost(title: String, p: Vector2, angle: float, color: Color) -> void:
	var label = Label3D.new()
	label.name = "Direction_%d" % sequence
	sequence += 1
	label.text = title
	label.font_size = 96
	label.pixel_size = .014
	label.modulate = color
	label.outline_size = 0
	label.position = Vector3(p.x,2.4,p.y)
	label.rotation.y = angle
	add_child(label)
