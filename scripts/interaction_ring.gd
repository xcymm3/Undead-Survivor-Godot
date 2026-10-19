extends Node3D
# Hallmark · component: hold key · atmospheric · existing field palette
# Pre-emit critique: P4 H4 E4 S5 R5 V4
# States: aimed focus, pressed, filling, unavailable, error, complete, maxed; hidden when unfocused.
const Art = preload("res://scripts/upgrade_art.gd")
const INK = Art.INK
const FRAME = Art.PAPER
const PAPER = Color("d8ddd3")
const FILL = Art.GOLD
const MUTED = Color("78847b")
const SUCCESS = Color("8fce83")
const ERROR = Color("d98870")
const HALF = .11
const INNER = .08
var arc: MeshInstance3D
var letter: Label3D
var hint: Label3D
var progress = 0.0
var state = "ready"

func _ready() -> void:
	arc = MeshInstance3D.new()
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	arc.material_override = material
	add_child(arc)
	letter = make_label("E",40,.003,INK)
	letter.position.z = .006
	letter.hide() # The E itself is drawn as a crisp five-by-seven pixel glyph.
	hint = make_label("长按",22,.003,FRAME)
	hint.position = Vector3(0,-.18,.006)
	hint.hide() # Only the key, upgrade name and price remain beside the stand.

func make_label(text: String, font_size: int, pixel_size: float, color: Color) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.font = Art.font()
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.no_depth_test = true
	label.outline_size = 0
	add_child(label)
	return label

static func sector_angle(value: float) -> float:
	return clampf(value,0,1)*TAU

static func sector_edge(value: float) -> Vector2:
	# A clockwise radial wipe, clipped to the square's inside edge.
	var angle = PI/2-sector_angle(value)
	var ray = Vector2(cos(angle),sin(angle))
	return ray*INNER/maxf(absf(ray.x),absf(ray.y))

func sector(mesh: ImmediateMesh, value: float, color: Color) -> void:
	var end = clampf(value,0,1)
	mesh.surface_set_color(color)
	for i in ceili(end*64):
		var a = sector_edge(float(i)/64)
		var b = sector_edge(minf(float(i+1)/64,end))
		for point in [Vector2.ZERO,a,b]: mesh.surface_add_vertex(Vector3(point.x,point.y,.006))

func rectangle(mesh: ImmediateMesh, rect: Rect2, color: Color, depth: float) -> void:
	mesh.surface_set_color(color)
	var points = [Vector3(rect.position.x,rect.position.y,depth),Vector3(rect.end.x,rect.position.y,depth),Vector3(rect.position.x,rect.end.y,depth),Vector3(rect.end.x,rect.end.y,depth)]
	for index in [0,1,2,2,1,3]: mesh.surface_add_vertex(points[index])

func bevel(mesh: ImmediateMesh, half: float, corner: float, color: Color, depth: float) -> void:
	var points = [Vector2(-half+corner,-half),Vector2(half-corner,-half),Vector2(half,-half+corner),Vector2(half,half-corner),Vector2(half-corner,half),Vector2(-half+corner,half),Vector2(-half,half-corner),Vector2(-half,-half+corner)]
	mesh.surface_set_color(color)
	for i in points.size():
		for point in [Vector2.ZERO,points[i],points[(i+1)%points.size()]]:
			mesh.surface_add_vertex(Vector3(point.x,point.y,depth))

func pixel_letter(mesh: ImmediateMesh) -> void:
	var rows = ["11111","11000","11000","11110","11000","11000","11111"]
	for y in rows.size():
		for x in 5:
			if rows[y][x] == "1": rectangle(mesh,Rect2(-.045+x*.018,.063-(y+1)*.018,.018,.018),INK,.009)

func sync(value: float, eye: Vector3, enabled: bool, status := "ready") -> void:
	if global_position.distance_squared_to(eye) > .0001: look_at(eye,Vector3.UP,true)
	progress = clampf(value,0,1) if enabled else 0.0
	state = status
	if status == "complete": progress = 1.0
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	bevel(mesh,HALF+.027,.036,INK,0)
	bevel(mesh,HALF+.012,.029,Art.RUST,.001)
	bevel(mesh,HALF,.024,SUCCESS if status == "complete" else ERROR if status == "error" else FRAME if enabled else MUTED,.002)
	rectangle(mesh,Rect2(-.075,.084,.15,.012),Color.WHITE,.003)
	rectangle(mesh,Rect2(-.096,-.075,.012,.15),Art.STEEL,.003)
	rectangle(mesh,Rect2(-INNER-.006,-INNER-.006,2*INNER+.012,2*INNER+.012),INK,.004)
	rectangle(mesh,Rect2(-INNER,-INNER,2*INNER,2*INNER),PAPER if enabled else MUTED,.005)
	if progress > 0:
		sector(mesh,progress,SUCCESS if status == "complete" else FILL)
	pixel_letter(mesh)
	mesh.surface_end()
	arc.mesh = mesh
	letter.text = "E"
	hint.text = {"complete":"完成","maxed":"满级","error":"不足","disabled":"不可用"}.get(status,"长按")
	hint.modulate = SUCCESS if status == "complete" else ERROR if status == "error" else FRAME if enabled else MUTED
