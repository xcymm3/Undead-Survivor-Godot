extends Control
# Hallmark · pre-emit critique: P4 H4 E4 S4 R5 V4
var kind = "ultimate"
var icon: Control
var progress = 1.0
var locked = false
var caption = ""
var detail = ""
const RING_WIDTH = 8.0
const RADIUS = 27.0

func charge_color(fraction: float) -> Color:
	return Color("285ee8").lerp(Color("55dcff"),clampf(fraction,0,1))
func _init() -> void:
	custom_minimum_size = Vector2(94,112)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _ready() -> void:
	icon = preload("res://scripts/hud_equipment_icon.gd").new()
	icon.kind = kind
	icon.position = Vector2(27,12)
	icon.size = Vector2(40,40)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon)

func sync(value: float, title: String, note: String, unavailable := false) -> void:
	locked = unavailable
	progress = clampf(value,0,1)
	caption = title
	detail = note
	if icon: icon.modulate = Color("829084") if locked else Color("f2eedf")
	queue_redraw()
func _draw() -> void:
	var center = Vector2(size.x*.5,32)
	draw_arc(center,RADIUS,0,TAU,128,Color("303c35") if locked else Color("243c54"),RING_WIDTH,true)
	if progress > 0:
		var points = PackedVector2Array()
		var colors = PackedColorArray()
		var steps = maxi(2,ceili(progress*160))
		for index in steps+1:
			var fraction = progress*float(index)/steps
			var angle = -PI/2+TAU*fraction
			points.append(center+Vector2(cos(angle),sin(angle))*RADIUS)
			colors.append(charge_color(fraction))
		draw_polyline_colors(points,colors,RING_WIDTH,true)
	var font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	draw_string(font,Vector2((size.x-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x)/2,77),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("829084") if locked else Color("f2eedf"))
	draw_string(font,Vector2((size.x-font.get_string_size(detail,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x)/2,99 if not caption.is_empty() else 83),detail,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ddceb0"))
