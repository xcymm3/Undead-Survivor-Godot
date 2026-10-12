extends Button
# Hallmark · pre-emit critique: P4 H4 E4 S5 R4 V4
const DARK = Color("17251e")
const GREEN = Color("436746")
const RUST = Color("b95530")
const GOLD = Color("d6af62")
const TEXT = Color("fff0c8")
const HOVER_TEXT = Color("fff9e5")
var primary = false
var highlighted = false
var motion: Tween
var face: Control
class Face extends Control:
	const DARK = Color("17251e")
	const GREEN = Color("436746")
	const RUST = Color("b95530")
	const GOLD = Color("d6af62")
	const DISABLED = Color("26322b")
	const SHADOW = Color("101913")
	func _draw() -> void:
		var owner_button = get_parent()
		var w: float = size.x
		var h: float = size.y-7
		var cut = minf(12,h*.2)
		var polygon = PackedVector2Array([Vector2(cut,0),Vector2(w-4,0),Vector2(w,h-cut),Vector2(w-cut,h),Vector2(0,h),Vector2(0,cut)])
		var lower = PackedVector2Array()
		for point in polygon: lower.append(point+Vector2(0,7))
		var color = RUST if owner_button.primary else GREEN
		if owner_button.disabled: color = DISABLED
		elif owner_button.highlighted: color = color.lightened(.2)
		if owner_button.is_pressed(): color = color.darkened(.18)
		draw_colored_polygon(lower,SHADOW)
		draw_colored_polygon(polygon,color)
		var rim = polygon.duplicate()
		rim.append(polygon[0])
		draw_polyline(rim,GOLD if owner_button.highlighted or owner_button.has_focus() else color.lightened(.3),2,true)
		draw_line(Vector2(18,4),Vector2(w-14,4),color.lightened(.45),2,true)
		for x in [9,w-10]:
			draw_circle(Vector2(x,h*.5),2,GOLD)
			draw_line(Vector2(x-2,h*.5),Vector2(x+2,h*.5),DARK,1,true)
func _ready() -> void:
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	add_theme_color_override("font_color",TEXT)
	add_theme_color_override("font_hover_color",HOVER_TEXT)
	add_theme_color_override("font_outline_color",DARK)
	add_theme_constant_override("outline_size",3)
	face = Face.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.show_behind_parent = true
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(face)
	resized.connect(func(): pivot_offset = size*.5; face.queue_redraw())
	pivot_offset = size*.5
	mouse_entered.connect(func(): animate_hover(true))
	mouse_exited.connect(func(): animate_hover(false))
	focus_entered.connect(func(): face.queue_redraw())
	focus_exited.connect(func(): face.queue_redraw())
	button_down.connect(func(): face.queue_redraw())
	button_up.connect(func(): face.queue_redraw())
func animate_hover(value: bool) -> void:
	if disabled: return
	highlighted = value
	if motion: motion.kill()
	motion = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.tween_property(self,"scale",Vector2.ONE*(1.055 if value else 1.0),.12)
	face.queue_redraw()
