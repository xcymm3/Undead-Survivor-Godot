extends Node3D
var arc: MeshInstance3D
var letter: Label3D
func _ready() -> void:
	arc = MeshInstance3D.new()
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	arc.material_override = material
	add_child(arc)
	letter = Label3D.new()
	letter.text = "E"
	letter.font_size = 44
	letter.pixel_size = .003
	letter.no_depth_test = true
	letter.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	letter.outline_size = 4
	add_child(letter)
func sync(progress: float, eye: Vector3, enabled: bool) -> void:
	if global_position.distance_squared_to(eye) > .0001: look_at(eye)
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 64:
		var color = Color("f2d38b") if enabled and float(i)/64 < progress else Color("53675d")
		mesh.surface_set_color(color)
		var a = PI/2-TAU*i/64.0
		var b = PI/2-TAU*(i+1)/64.0
		var points = [Vector3(cos(a),sin(a),0)*.2,Vector3(cos(b),sin(b),0)*.2,Vector3(cos(a),sin(a),0)*.175,Vector3(cos(b),sin(b),0)*.175]
		for index in [0,1,2,2,1,3]: mesh.surface_add_vertex(points[index])
	mesh.surface_end()
	arc.mesh = mesh
	letter.modulate = Color("fff0ca") if enabled else Color("88928a")
