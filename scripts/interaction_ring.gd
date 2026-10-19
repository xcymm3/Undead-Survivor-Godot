extends Node3D
# Hallmark · component: hold key · atmospheric · existing field palette
# Pre-emit critique: P4 H4 E4 S5 R5 V4
# States: aimed focus, pressed, filling, unavailable, error, complete, maxed; hidden when unfocused.
const INK = Color("13221d")
const FRAME = Color("fff0ca")
const PAPER = Color("d8ddd3")
const FILL = Color("efbd48")
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
	hint = make_label("长按",22,.003,FRAME)
	hint.position = Vector3(0,-.18,.006)

func make_label(text: String, font_size: int, pixel_size: float, color: Color) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.no_depth_test = true
	label.outline_size = 0
	add_child(label)
	return label

static func eased_progress(value: float) -> float:
	return 1.0-pow(1.0-clampf(value,0,1),3)

static func fill_rect(value: float) -> Rect2:
	var height = INNER*2*eased_progress(value)
	return Rect2(-INNER,-INNER,INNER*2,height)

func rectangle(mesh: ImmediateMesh, rect: Rect2, color: Color, depth: float) -> void:
	mesh.surface_set_color(color)
	var points = [Vector3(rect.position.x,rect.position.y,depth),Vector3(rect.end.x,rect.position.y,depth),Vector3(rect.position.x,rect.end.y,depth),Vector3(rect.end.x,rect.end.y,depth)]
	for index in [0,1,2,2,1,3]: mesh.surface_add_vertex(points[index])

func sync(value: float, eye: Vector3, enabled: bool, status := "ready") -> void:
	if global_position.distance_squared_to(eye) > .0001: look_at(eye,Vector3.UP,true)
	progress = clampf(value,0,1) if enabled else 0.0
	state = status
	if status == "complete": progress = 1.0
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	rectangle(mesh,Rect2(-HALF-.018,-HALF-.018,2*HALF+.036,2*HALF+.036),INK,0)
	rectangle(mesh,Rect2(-HALF,-HALF,2*HALF,2*HALF),SUCCESS if status == "complete" else ERROR if status == "error" else FRAME if enabled else MUTED,.001)
	rectangle(mesh,Rect2(-INNER,-INNER,2*INNER,2*INNER),PAPER if enabled else MUTED,.002)
	if progress > 0:
		rectangle(mesh,fill_rect(progress),SUCCESS if status == "complete" else FILL,.003)
	mesh.surface_end()
	arc.mesh = mesh
	letter.text = "E"
	hint.text = {"complete":"完成","maxed":"满级","error":"不足","disabled":"不可用"}.get(status,"长按")
	hint.modulate = SUCCESS if status == "complete" else ERROR if status == "error" else FRAME if enabled else MUTED
