extends Control
# Hallmark · component: game result emblem · existing field palette
# Pre-emit critique: P4 H5 E4 S5 R4 V4
const BACKGROUND = Color("101c19")
const FAILURE = Color("c86d4c")
const SUCCESS = Color("77d5bb")
const BORDER = Color("c59b62")
var victorious = false

func _ready() -> void:
	custom_minimum_size = Vector2(152,142)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center = size*.5
	var tint = SUCCESS if victorious else FAILURE
	var plate = PackedVector2Array()
	for i in 6:
		var angle = PI/6+TAU*i/6
		plate.append(center+Vector2(cos(angle),sin(angle))*62)
	draw_colored_polygon(plate,BACKGROUND)
	plate.append(plate[0])
	draw_polyline(plate,BORDER,2,true)
	var top = center+Vector2(0,-43)
	var left = center+Vector2(-25,0)
	var right = center+Vector2(25,0)
	var bottom = center+Vector2(0,43)
	draw_colored_polygon(PackedVector2Array([top,left,bottom]),tint.darkened(.25))
	draw_colored_polygon(PackedVector2Array([top,right,bottom]),tint)
	draw_line(top,bottom,BORDER,1,true)
	if not victorious:
		draw_polyline(PackedVector2Array([center+Vector2(-23,-9),center+Vector2(5,-3),center+Vector2(-5,8),center+Vector2(21,12)]),BACKGROUND,6,true)
	else:
		draw_polyline(PackedVector2Array([center+Vector2(-34,3),center+Vector2(-12,25),center+Vector2(36,-23)]),BORDER,6,true)
