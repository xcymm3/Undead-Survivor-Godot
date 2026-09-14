extends Control
## Original flat silhouettes, drawn natively so HUD icons remain crisp at any scale.
var kind := "rifle"

func _draw() -> void:
	var item: bool = kind in ["grenade","medkit"]
	var canvas = Vector2(60 if item else 100,50)
	var factor = minf(size.x/canvas.x,size.y/canvas.y)
	draw_set_transform((size-canvas*factor)*.5-Vector2(20 if item else 0,0)*factor,0,Vector2.ONE*factor)
	var white = Color.WHITE
	match kind:
		"grenade":
			draw_rect(Rect2(39,4,21,7),white)
			draw_line(Vector2(60,6),Vector2(70,24),white,5)
			draw_circle(Vector2(49,30),18,white)
			for y in [23,33]: draw_line(Vector2(35,y),Vector2(63,y),Color(.12,.16,.12),2)
		"medkit":
			draw_rect(Rect2(34,3,32,9),white,false,4)
			draw_style_box(box(),Rect2(23,12,54,36))
			draw_rect(Rect2(46,19,8,23),white)
			draw_rect(Rect2(38,27,24,7),white)
		"axe":
			draw_line(Vector2(29,46),Vector2(61,5),white,6)
			draw_colored_polygon(PackedVector2Array([Vector2(48,4),Vector2(65,1),Vector2(80,11),Vector2(71,26),Vector2(58,16)]),white)
		"pistol", "revolver":
			draw_rect(Rect2(19,13,65,10),white)
			draw_colored_polygon(PackedVector2Array([Vector2(25,23),Vector2(42,23),Vector2(35,45),Vector2(19,45)]),white)
			draw_rect(Rect2(40,23,18,12),white,false,3)
			if kind == "revolver": draw_circle(Vector2(44,20),8,white)
		"p90":
			draw_style_box(box(),Rect2(8,14,66,23))
			draw_rect(Rect2(7,8,62,6),white)
			draw_rect(Rect2(72,19,22,5),white)
			draw_line(Vector2(46,27),Vector2(42,39),white,6)
		_:
			draw_colored_polygon(PackedVector2Array([Vector2(3,18),Vector2(21,22),Vector2(23,16),Vector2(67,16),Vector2(69,27),Vector2(22,27),Vector2(3,34)]),white)
			draw_rect(Rect2(67,18,29,5),white)
			draw_colored_polygon(PackedVector2Array([Vector2(29,26),Vector2(38,26),Vector2(34,40),Vector2(25,40)]),white)
			if kind in ["sniper", "awp"]:
				draw_rect(Rect2(32,7,28,6),white)
				draw_line(Vector2(46,12),Vector2(46,18),white,3)
			elif kind in ["shotgun", "auto-shotgun"]:
				draw_rect(Rect2(58,25,28,4),white)
			else:
				draw_colored_polygon(PackedVector2Array([Vector2(44,27),Vector2(56,27),Vector2(60,41),Vector2(49,44)]),white)

func box() -> StyleBoxFlat:
	var result = StyleBoxFlat.new()
	result.bg_color = Color(.12,.16,.12)
	result.border_color = Color.WHITE
	result.set_border_width_all(3)
	result.set_corner_radius_all(4)
	return result
