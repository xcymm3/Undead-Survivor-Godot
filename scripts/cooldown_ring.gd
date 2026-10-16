extends Control
var progress = 1.0
var caption = ""
var detail = ""
const RING_WIDTH = 8.0
const RADIUS = 27.0

func charge_color(fraction: float) -> Color:
	return Color("285ee8").lerp(Color("55dcff"),clampf(fraction,0,1))
func _init() -> void:
	custom_minimum_size = Vector2(94,96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func sync(value: float, title: String, note: String) -> void:
	progress = clampf(value,0,1)
	caption = title
	detail = note
	queue_redraw()
func _draw() -> void:
	var center = Vector2(size.x*.5,32)
	draw_arc(center,RADIUS,0,TAU,128,Color("243c54"),RING_WIDTH,true)
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
	draw_string(font,Vector2((size.x-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x)/2,36),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f2eedf"))
	draw_string(font,Vector2((size.x-font.get_string_size(detail,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x)/2,77),detail,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ddceb0"))
