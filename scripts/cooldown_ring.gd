extends Control
var progress = 1.0
var caption = ""
var detail = ""
var tint = Color("dfc17b")
func _init() -> void:
	custom_minimum_size = Vector2(94,96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func sync(value: float, title: String, note: String) -> void:
	progress = clampf(value,0,1)
	caption = title
	detail = note
	queue_redraw()
func _draw() -> void:
	var center = Vector2(size.x*.5,30)
	draw_arc(center,25,0,TAU,64,Color(.2,.24,.23,.85),4,true)
	if progress > 0: draw_arc(center,25,-PI/2,-PI/2+TAU*progress,64,tint,4,true)
	var font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	draw_string(font,Vector2((size.x-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x)/2,36),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f2eedf"))
	draw_string(font,Vector2((size.x-font.get_string_size(detail,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x)/2,77),detail,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ddceb0"))
