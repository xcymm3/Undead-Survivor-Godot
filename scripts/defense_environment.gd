extends RefCounted
## Crystal Defense environmental art. Gameplay dimensions stay in
## defense_layout.gd; this module adds materials, believable boundaries and
## sparse cover without changing the bridge -> ramp -> plateau route.

const SURFACE_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 dark_color : source_color;
uniform vec4 light_color : source_color;
uniform float grain_scale = 0.35;
uniform float roughness_value = 0.9;
uniform float strata_strength = 0.0;
varying vec3 world_position;

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), local.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), local.x),
		local.y
	);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 sample_point = world_position.xz + vec2(world_position.y * 0.71, world_position.y * 0.43);
	float broad = value_noise(sample_point * grain_scale);
	float detail = value_noise(sample_point * grain_scale * 5.3);
	float strata = sin(world_position.y * 10.5 + broad * 2.0) * 0.5 + 0.5;
	float blend = clamp(broad * 0.72 + detail * 0.28 - strata * strata_strength, 0.0, 1.0);
	ALBEDO = mix(dark_color.rgb, light_color.rgb, blend);
	ROUGHNESS = roughness_value;
	SPECULAR = 0.18;
}
"""

static func surface_material(world: Node3D, key: String, dark: String, light: String, scale: float, roughness := .92, strata := 0.0) -> ShaderMaterial:
	var cache_key = "defense_surface_"+key
	if world.materials.has(cache_key): return world.materials[cache_key]
	var shader = Shader.new()
	shader.code = SURFACE_SHADER
	var result = ShaderMaterial.new()
	result.shader = shader
	result.set_shader_parameter("dark_color",Color(dark))
	result.set_shader_parameter("light_color",Color(light))
	result.set_shader_parameter("grain_scale",scale)
	result.set_shader_parameter("roughness_value",roughness)
	result.set_shader_parameter("strata_strength",strata)
	world.materials[cache_key] = result
	return result

static func apply_material(node: Node3D, value: Material) -> Node3D:
	for child in node.get_children():
		if child is MeshInstance3D: child.material_override = value
	return node

static func textured_block(world: Node3D, title: String, pos: Vector3, size: Vector3, value: Material, solid := true, nav := true) -> Node3D:
	return apply_material(world.block(title,pos,size,"ffffff",solid,nav),value)

static func make_rock(world: Node3D, title: String, pos: Vector3, size: Vector3, yaw: float, solid := true, nav := true) -> Node3D:
	var rock: Node3D = StaticBody3D.new() if solid else Node3D.new()
	rock.name = title
	rock.position = pos
	rock.rotation_degrees = Vector3(-6.0+fmod(absf(pos.x*7.0+pos.z*3.0),13.0),yaw,4.0-fmod(absf(pos.z),9.0))
	rock.set_meta("environment_feature","boulder")
	var view = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 5
	view.mesh = mesh
	view.scale = size*.5
	view.material_override = surface_material(world,"rock","343936","697066",.58,.98,.08)
	rock.add_child(view)
	if solid:
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size*Vector3(.72,.72,.72)
		collision.shape = shape
		rock.add_child(collision)
	world.add_child(rock)
	if solid and nav:
		world.obstacles.append({"minX":pos.x-size.x*.43,"maxX":pos.x+size.x*.43,"minZ":pos.z-size.z*.43,"maxZ":pos.z+size.z*.43})
	return rock

static func make_grass_tuft(world: Node3D, point: Vector2, height: float, tint: String) -> void:
	var tuft = Node3D.new()
	tuft.name = "GrassTuft"
	tuft.position = Vector3(point.x,height,point.y)
	tuft.set_meta("environment_feature","vegetation")
	for index in 3:
		var blade = MeshInstance3D.new()
		var mesh = CylinderMesh.new()
		mesh.top_radius = .015
		mesh.bottom_radius = .11
		mesh.height = .48+index*.09
		mesh.radial_segments = 4
		blade.mesh = mesh
		blade.material_override = world.material(tint)
		blade.position = Vector3((index-1)*.12,mesh.height*.5,(index%2)*.09)
		blade.rotation_degrees.z = (index-1)*10.0
		tuft.add_child(blade)
	world.add_child(tuft)

static func build_base(world: Node3D) -> void:
	var soil = surface_material(world,"soil","29362f","52604d",.23,.98,.05)
	var grass = surface_material(world,"grass","293d32","607358",.34,.97,.03)
	var road = surface_material(world,"road","514c40","817761",.52,.96,.04)
	var cliff = surface_material(world,"cliff","303733","5c6258",.44,.99,.18)
	var riverbed = surface_material(world,"riverbed","101d21","293a3a",.38,.96,.10)
	textured_block(world,"RiverBed",Vector3(0,-8.5,-45),Vector3(64,1,34),riverbed,true,false)
	var water = world.block("Water",Vector3(0,-7.92,-45),Vector3(64,.08,34),"245d68",false)
	var water_material = ShaderMaterial.new()
	water_material.shader = load("res://scripts/river_water.gdshader")
	apply_material(water,water_material)
	textured_block(world,"FarCliff",Vector3(0,-.5,-70),Vector3(64,1,16),soil,true,false)
	textured_block(world,"DefensePlateau",Vector3(0,1.5,31),Vector3(64,3,82),grass,true,false)
	textured_block(world,"ApproachRoad",Vector3(0,3.035,18),Vector3(11,.07,56),road,false)
	# Exposed strata and talus make both bridge-side drops read as natural cliffs.
	for z in [-62.0,-28.0]:
		for side in [-1.0,1.0]:
			textured_block(world,"CliffFace",Vector3(side*18.5,-1.5,z),Vector3(27,8.5,1.4),cliff,true,false)
			for offset in [-9.0,-3.0,4.0,9.0]:
				make_rock(world,"CliffTalus",Vector3(side*18.5+offset*.62,-6.9,z+(-1.8 if z < -40 else 1.8)),Vector3(2.8,1.7,2.1),offset*9.0,false,false)
	# Muted edge markers retain long-range readability without looking painted on.
	for z in range(-8,47,9):
		textured_block(world,"RoadEdgeStone",Vector3(-4.85,3.09,z),Vector3(.28,.09,3.6),cliff,false)
		textured_block(world,"RoadEdgeStone",Vector3(4.85,3.09,z),Vector3(.28,.09,3.6),cliff,false)

static func make_wall_run(world: Node3D, center: Vector3, size: Vector3, posts_along_x: bool) -> void:
	var stone = surface_material(world,"wall","303a35","657064",.7,.98,.12)
	var cap = surface_material(world,"wall_cap","4a5149","7a8175",.9,.96,.06)
	var wall = textured_block(world,"PerimeterWall",center,size,stone,true,false)
	wall.set_meta("environment_feature","perimeter_wall")
	var cap_size = Vector3(size.x+.16,.22,size.z+.16)
	textured_block(world,"WallCap",center+Vector3(0,size.y*.5+.11,0),cap_size,cap,false,false)
	var length = size.x if posts_along_x else size.z
	var count = maxi(1,floori(length/8.0))
	for index in count+1:
		var t = float(index)/count-.5
		var offset = Vector3(t*length,0,0) if posts_along_x else Vector3(0,0,t*length)
		textured_block(world,"WallButtress",center+offset+Vector3(0,.15,0),Vector3(.85,size.y+.3,.85),stone,true,false)

static func build_boundaries(world: Node3D) -> void:
	# Side walls stop at the chasm. The bridge flanks remain exposed cliff edges,
	# while every playable outer edge is visibly and physically enclosed.
	for x in [-31.45,31.45]:
		make_wall_run(world,Vector3(x,4.1,-70),Vector3(1.1,2.2,16),false)
		make_wall_run(world,Vector3(x,4.1,22),Vector3(1.1,2.2,100),false)
	make_wall_run(world,Vector3(0,2.1,-77.45),Vector3(64,3.2,1.1),true)
	make_wall_run(world,Vector3(0,4.1,71.45),Vector3(64,2.2,1.1),true)

static func build_spawn_shelter(world: Node3D) -> void:
	# A roof and staggered stone screens hide every spawn from the bridge lane.
	# The central portal remains wide enough for the enemy navigation grid.
	var stone = surface_material(world,"spawn_shelter","202a2b","384541",.58,.98,.16)
	textured_block(world,"FarSpawnRoof",Vector3(0,6.5,-70.5),Vector3(64,1.0,15),stone,true,false)
	for side in [-1.0,1.0]:
		textured_block(world,"FarSpawnFacade",Vector3(side*18.25,3.1,-63.5),Vector3(27.5,6.2,1.0),stone)
		textured_block(world,"FarSpawnSideCap",Vector3(side*31.45,5.6,-70),Vector3(1.1,1.6,16),stone,true,false)
	textured_block(world,"FarSpawnRearCap",Vector3(0,5.0,-77.45),Vector3(64,2.8,1.1),stone,true,false)
	textured_block(world,"FarSpawnScreen",Vector3(0,3.0,-68.8),Vector3(10,6.0,1.0),stone)
	for side in [-1.0,1.0]:
		var lamp = OmniLight3D.new()
		lamp.name = "BridgeMouthLight"
		lamp.position = Vector3(side*4.7,3.6,-62.3)
		lamp.light_color = Color("b9cabe")
		lamp.light_energy = 1.2
		lamp.omni_range = 6.0
		world.add_child(lamp)

static func build_ramp_fill(world: Node3D) -> StaticBody3D:
	# A convex earthen wedge fills the entire volume below the authored ramp.
	# It reaches the side shelves so there is no physical seam beside the rails.
	var points = PackedVector3Array([
		Vector3(-5.5,0,-28),Vector3(5.5,0,-28),
		Vector3(-5.5,-.2,-28),Vector3(5.5,-.2,-28),
		Vector3(-5.5,-.2,-10),Vector3(5.5,-.2,-10),
		Vector3(-5.5,3,-10),Vector3(5.5,3,-10)
	])
	var triangles = PackedInt32Array([
		0,7,1, 0,6,7,
		2,3,5, 2,5,4,
		0,1,3, 0,3,2,
		4,5,7, 4,7,6,
		0,2,4, 0,4,6,
		1,7,5, 1,5,3
	])
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in triangles: builder.add_vertex(points[index])
	builder.generate_normals()
	var body = StaticBody3D.new()
	body.name = "RampSolidFill"
	body.set_meta("environment_feature","ramp_fill")
	var view = MeshInstance3D.new()
	view.mesh = builder.commit()
	view.material_override = surface_material(world,"ramp_earth","343d37","62695e",.62,.99,.16)
	body.add_child(view)
	var collision = CollisionShape3D.new()
	var shape = ConvexPolygonShape3D.new()
	shape.points = points
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body

static func build_ramp_detail(world: Node3D) -> void:
	var packed_stone = surface_material(world,"ramp","4a504b","75786d",.82,.98,.12)
	var angle = -atan2(3.0,18.0)
	# Broad irregular paving bands follow the original continuous collision ramp.
	for z in range(-27,-10,2):
		var y = world.Layout.height(Vector2(0,z))
		var band = textured_block(world,"RampPaver",Vector3(0,y+.075,z),Vector3(9.6,.12,1.72),packed_stone,false)
		band.rotation.x = angle
	# Dry-stacked retaining stones and drainage channels sell the constructed slope.
	for x in [-5.35,5.35]:
		var channel = textured_block(world,"RampDrain",Vector3(x,1.28,-19),Vector3(.5,.22,18.2),packed_stone,false)
		channel.rotation.x = angle
		for z in [-26.0,-22.0,-18.0,-14.0,-10.5]:
			var y = world.Layout.height(Vector2(x,z))
			make_rock(world,"RampRiprap",Vector3(x+signf(x)*1.15,y*.55+.35,z),Vector3(2.0,1.15,1.65),z*5.0,false,false)

static func build_cover(world: Node3D) -> void:
	# Cover is intentionally asymmetric and kept outside the eleven-metre road.
	var rocks = [
		[Vector3(-21,3.75,-3),Vector3(4.6,2.0,3.5),18.0],
		[Vector3(22,3.65,4),Vector3(3.8,1.7,3.1),-27.0],
		[Vector3(-18,3.7,13),Vector3(3.4,1.55,2.8),42.0],
		[Vector3(19,3.85,20),Vector3(4.2,2.2,3.0),-12.0],
		[Vector3(-23,3.65,31),Vector3(3.7,1.7,3.4),31.0],
		[Vector3(22,3.7,40),Vector3(3.5,1.8,2.7),-36.0],
		[Vector3(-18,3.6,48),Vector3(3.0,1.45,2.6),11.0],
		[Vector3(18,3.65,49),Vector3(3.3,1.55,2.5),-18.0],
		[Vector3(-18,.65,-70),Vector3(4.0,2.1,3.2),24.0],
		[Vector3(18,.65,-68),Vector3(3.5,1.8,2.8),-20.0]
	]
	for index in rocks.size():
		var entry: Array = rocks[index]
		make_rock(world,"FieldBoulder%02d" % index,entry[0],entry[1],entry[2],true,true)
	# Small companion stones break up the unmistakable single-primitive silhouette.
	for point in [Vector3(-23,3.35,-1),Vector3(24,3.32,5),Vector3(-20,3.34,15),Vector3(21,3.34,22),Vector3(-25,3.34,33),Vector3(24,3.34,41)]:
		make_rock(world,"ScatterStone",point,Vector3(1.25,.72,1.0),point.x*4.0,false,false)

static func build_vegetation(world: Node3D) -> void:
	var patches = [
		Vector2(-27,-7),Vector2(-14,-4),Vector2(14,-2),Vector2(27,1),
		Vector2(-26,9),Vector2(-12,8),Vector2(13,11),Vector2(27,15),
		Vector2(-28,23),Vector2(-14,25),Vector2(15,28),Vector2(27,31),
		Vector2(-28,39),Vector2(-15,40),Vector2(14,38),Vector2(28,47),
		Vector2(-27,57),Vector2(20,59),Vector2(-21,66),Vector2(25,67),
		Vector2(-26,-72),Vector2(25,-71),Vector2(-14,-66),Vector2(13,-65)
	]
	for index in patches.size():
		var point: Vector2 = patches[index]
		make_grass_tuft(world,point,world.Layout.height(point)+.03,"526448" if index%3 else "6c7350")

static func decorate_existing(world: Node3D) -> void:
	var timber = surface_material(world,"timber","3f2d22","866445",.78,.94,.02)
	var metal = surface_material(world,"metal","242b2b","59605d",1.15,.72,.03)
	var ramp = surface_material(world,"ramp_base","424a45","687068",.65,.98,.12)
	var concrete = surface_material(world,"safe_concrete","283a34","53645a",.82,.96,.08)
	for node in world.get_children():
		if not node is Node3D: continue
		var title: String = node.name
		if title.begins_with("BridgePlank") or title == "BridgeCollision" or title == "WeaponShopWall" or title.begins_with("ShopFrame"): apply_material(node,timber)
		elif title.begins_with("BridgeTower") or title.begins_with("BridgeGuardRail") or title.begins_with("ShopRail"): apply_material(node,metal)
		elif title == "StoneRamp" or title.begins_with("RampShelf") or title.begins_with("RampWall"): apply_material(node,ramp)
		elif title == "SafeZoneFloor": apply_material(node,concrete)

static func build(world: Node3D) -> void:
	build_base(world)
	build_boundaries(world)
	build_spawn_shelter(world)

static func decorate(world: Node3D) -> void:
	decorate_existing(world)
	build_ramp_detail(world)
	build_cover(world)
	build_vegetation(world)
