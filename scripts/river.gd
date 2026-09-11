extends Node3D
## The bed mesh, its collision and enemy height sampling share Data's cross-section.
func _ready() -> void:
	name = "River"
	var bed = SurfaceTool.new()
	var water = SurfaceTool.new()
	bed.begin(Mesh.PRIMITIVE_TRIANGLES)
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offsets = [-Data.RIVER_BANK_HALF,-Data.RIVER_BED_HALF,Data.RIVER_BED_HALF,Data.RIVER_BANK_HALF]
	for i in 176:
		var x0 = -22+i*.25
		var x1 = x0+.25
		for j in 3:
			quad(bed,point(x0,offsets[j]),point(x1,offsets[j]),point(x1,offsets[j+1]),point(x0,offsets[j+1]),false)
		var half_width = Data.RIVER_WET_HALF
		quad(water,water_point(x0,-half_width),water_point(x1,-half_width),water_point(x1,half_width),water_point(x0,half_width),true)
	var bed_mesh = bed.commit()
	var view = MeshInstance3D.new()
	view.name = "BedAndBanks"
	view.mesh = bed_mesh
	var mud = StandardMaterial3D.new()
	mud.vertex_color_use_as_albedo = true
	mud.roughness = .95
	mud.cull_mode = BaseMaterial3D.CULL_DISABLED
	view.material_override = mud
	add_child(view)
	var body = StaticBody3D.new()
	body.name = "RiverbedCollision"
	var shape = ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(bed_mesh.get_faces())
	var collider = CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	var surface = MeshInstance3D.new()
	surface.name = "FlowingWater"
	surface.mesh = water.commit()
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ShaderMaterial.new()
	material.shader = preload("res://scripts/river_water.gdshader")
	surface.material_override = material
	add_child(surface)

func point(x: float, offset: float) -> Vector3:
	var p = Vector2(x,Data.river_center(x)+offset)
	return Vector3(x,Data.riverbed_height(p),p.y)

func water_point(x: float, offset: float) -> Vector3:
	return Vector3(x,Data.RIVER_WATER_Y,Data.river_center(x)+offset)

func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, water: bool) -> void:
	for triangle in [[a,b,c],[a,c,d]]:
		var normal: Vector3 = (triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).normalized()
		for p in triangle:
			surface.set_normal(normal)
			surface.set_uv(Vector2(p.x,(p.z-Data.river_center(p.x)+Data.RIVER_WET_HALF)/(2*Data.RIVER_WET_HALF)))
			var shallow = clampf((p.y-Data.RIVER_BED_Y)/(Data.RIVER_GROUND_Y-Data.RIVER_BED_Y),0,1)
			surface.set_color(Color.WHITE if water else Color("514d3c").lerp(Color("777259"),shallow))
			surface.add_vertex(p)
