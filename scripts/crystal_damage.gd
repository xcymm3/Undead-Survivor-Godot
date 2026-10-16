extends Node3D
var cracks: Node3D
var debris: Node3D
var fragments: Array = []

func line(a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var view = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 5
	view.mesh = mesh
	view.material_override = material
	view.position = (a+b)*.5
	view.basis = Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	cracks.add_child(view)

func _ready() -> void:
	name = "CrystalDamage"
	cracks = Node3D.new()
	cracks.name = "CrystalCracks"
	add_child(cracks)
	var dark = StandardMaterial3D.new()
	dark.albedo_color = Color("092a38")
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var glow = StandardMaterial3D.new()
	glow.albedo_color = Color("d7fcf2")
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for face in 6:
		var angle = (face+.5)*TAU/6
		var radial = Vector3(cos(angle),0,sin(angle))
		var tangent = Vector3(-sin(angle),0,cos(angle))
		var points: Array[Vector3] = []
		for entry in [[.62,.5,-.07],[1.1,.65,.09],[1.65,.89,-.10],[2.15,.78,.09],[2.65,.61,-.08]]:
			points.append(radial*(entry[1]*.866+.025)+Vector3.UP*entry[0]+tangent*entry[2])
		for i in points.size()-1:
			line(points[i],points[i+1],.037,dark)
			line(points[i]+radial*.01,points[i+1]+radial*.01,.011,glow)
		line(points[2],points[2]+tangent*.32+Vector3.UP*.22,.025,dark)
	debris = Node3D.new()
	debris.name = "CrystalFragments"
	add_child(debris)
	for i in 18:
		var fragment = MeshInstance3D.new()
		fragment.mesh = preload("res://scripts/crystal_art.gd").mesh()
		fragment.material_override = get_parent().get_node("FacetedCrystal").material_override
		var angle = i*2.39996
		var origin = Vector3(cos(angle)*.35,.5+float(i%5)*.42,sin(angle)*.35)
		fragment.position = origin
		fragment.scale = Vector3(.22+.04*(i%3),.20,.20)
		debris.add_child(fragment)
		fragments.append({"node":fragment,"origin":origin,"velocity":Vector3(cos(angle)*(.65+float(i%3)*.2),1.1+float(i%4)*.25,sin(angle)*(.65+float(i%3)*.2)),"spin":Vector3(.7+i*.1,1.3,-.6)})
	cracks.visible = false
	debris.visible = false

func sync(ratio: float, age: float, clock: float) -> void:
	cracks.visible = ratio > 0 and ratio <= .5
	cracks.scale = Vector3.ONE*(1.0+sin(clock*4)*.003)
	debris.visible = ratio <= 0
	for child in get_parent().get_children():
		if child is MeshInstance3D: child.visible = ratio > 0
	if ratio > 0: return
	var t = clampf(age,0,2.8)
	for item in fragments:
		var landing = (item.velocity.y+sqrt(item.velocity.y*item.velocity.y+18.0*(item.origin.y-.08)))/9.0
		var travel = minf(t,landing)
		item.node.position = item.origin+item.velocity*travel+Vector3.DOWN*(4.5*travel*travel)
		item.node.position.y = maxf(.08,item.node.position.y)
		item.node.rotation = item.spin*travel
