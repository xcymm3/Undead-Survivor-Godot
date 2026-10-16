extends RefCounted
## Opaque flat facets keep the night crystal readable without transparency sorting.
const PERIOD = 36.0
const Toy = preload("res://scripts/toy_art.gd")

static func mesh() -> ArrayMesh:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings = [Vector2(0,.12),Vector2(.48,.65),Vector2(.9,1.7),Vector2(.62,2.62),Vector2(0,3.48)]
	var colors = [Color("baf9ef"),Color("4bbce1"),Color("72e9d0"),Color("398be0"),Color("52c9e8"),Color("a9f1e1")]
	for tier in range(rings.size()-1):
		for i in 6:
			var a = i*TAU/6
			var b = (i+1)*TAU/6
			var p0 = Vector3(cos(a)*rings[tier].x,rings[tier].y,sin(a)*rings[tier].x)
			var p1 = Vector3(cos(b)*rings[tier].x,rings[tier].y,sin(b)*rings[tier].x)
			var p2 = Vector3(cos(a)*rings[tier+1].x,rings[tier+1].y,sin(a)*rings[tier+1].x)
			var p3 = Vector3(cos(b)*rings[tier+1].x,rings[tier+1].y,sin(b)*rings[tier+1].x)
			for triangle in [[p0,p2,p1],[p1,p2,p3]]:
				var normal: Vector3 = (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
				if normal.length_squared() < .1: continue
				for point in triangle:
					surface.set_normal(normal)
					surface.set_color(colors[i].lightened(.08 if tier == 3 else 0.0))
					surface.add_vertex(point)
	return surface.commit()

static func build(parent: Node3D) -> MeshInstance3D:
	parent.set_meta("art_style","toy")
	var dock = Node3D.new()
	dock.name = "ToyCrystalDock"
	parent.add_child(dock)
	Toy.cylinder(dock,"BlueSocket",Vector3(0,.13,0),1.02,.26,Toy.BLUE)
	Toy.cylinder(dock,"CreamRim",Vector3(0,.30,0),.94,.11,Toy.CREAM)
	Toy.cylinder(dock,"PowerRing",Vector3(0,.39,0),.76,.10,Toy.YELLOW)
	for i in 6:
		var angle = TAU*i/6
		Toy.cylinder(dock,"ToyStud",Vector3(cos(angle)*.82,.41,sin(angle)*.82),.105,.13,Toy.CORAL)
	Toy.box(dock,"PowerLabel",Vector3(0,.23,-.96),Vector3(.66,.25,.08),Toy.CREAM)
	Toy.label(dock,"PowerText","POWER",Vector3(0,.23,-1.005),.0019,true)
	var core = MeshInstance3D.new()
	core.name = "FacetedCrystal"
	core.mesh = mesh()
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = .27
	material.metallic = 0.0
	material.emission_enabled = true
	material.emission = Color("278dac")
	material.emission_energy_multiplier = .35
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	core.material_override = material
	parent.add_child(core)
	var halo = MeshInstance3D.new()
	halo.name = "EnergyHalo"
	var ring = TorusMesh.new()
	ring.inner_radius = .94
	ring.outer_radius = 1.02
	ring.rings = 12
	ring.ring_segments = 6
	halo.mesh = ring
	halo.position.y = .7
	var glow = StandardMaterial3D.new()
	glow.albedo_color = Color("68b7c5")
	glow.emission_enabled = true
	glow.emission = Color("41a1ba")
	glow.emission_energy_multiplier = .65
	halo.material_override = glow
	parent.add_child(halo)
	for i in 3:
		var shard = MeshInstance3D.new()
		shard.name = "OrbitShard%d" % i
		shard.mesh = core.mesh
		shard.material_override = core.material_override
		shard.scale = Vector3(.15,.15,.15)
		shard.position = Vector3(cos(i*TAU/3)*.95,1.35,sin(i*TAU/3)*.95)
		shard.rotation.z = .18
		parent.add_child(shard)
	return core
