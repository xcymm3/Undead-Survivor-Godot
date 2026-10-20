extends Control
var action = "aim"

func _ready() -> void:
	custom_minimum_size = Vector2(53,64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*(64.0/44.0))
	var events = InputMap.action_get_events(action)
	var button = 0
	if not events.is_empty() and events[0] is InputEventMouseButton: button = events[0].button_index
	if button == 0:
		draw_string(preload("res://scripts/upgrade_art.gd").font(),Vector2(0,29),Data.binding_label(action),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffe4a2"))
		return
	var border = StyleBoxFlat.new()
	border.bg_color = Color("1a2528")
	border.border_color = Color("fff0cc")
	border.set_border_width_all(2)
	border.set_corner_radius_all(10)
	draw_style_box(border,Rect2(3,2,29,39))
	if button == MOUSE_BUTTON_RIGHT: draw_rect(Rect2(19,7,8,13),Color("f3c45a"))
	elif button == MOUSE_BUTTON_LEFT: draw_rect(Rect2(8,7,8,13),Color("f3c45a"))
	draw_line(Vector2(17.5,4),Vector2(17.5,22),Color("fff0cc"),1.5)
	draw_line(Vector2(5,23),Vector2(30,23),Color("fff0cc"),1.5)
	draw_rect(Rect2(15,9,5,10),Color("f3c45a") if button == MOUSE_BUTTON_MIDDLE else Color("b8bba7"))
