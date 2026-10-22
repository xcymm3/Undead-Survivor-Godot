extends Button
# Hallmark · component scope · pre-emit critique: P4 H5 E4 S5 R5 V4
const DANGER = Color("e06b61")
const FOCUS = preload("res://scripts/menu_button.gd").GOLD

func _ready() -> void:
	text = ""
	custom_minimum_size = Vector2(48,48)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
		var face = StyleBoxFlat.new()
		face.bg_color = Color.TRANSPARENT if state in ["normal","disabled","focus"] else DANGER.darkened(.72 if state == "hover" else .82)
		face.set_corner_radius_all(3)
		if state == "focus":
			face.set_border_width_all(2)
			face.border_color = FOCUS
		add_theme_stylebox_override(state,face)
	for changed in [mouse_entered,mouse_exited,focus_entered,focus_exited,button_down,button_up,resized]:
		changed.connect(queue_redraw)

func _draw() -> void:
	var tint = DANGER.darkened(.55) if disabled else DANGER.lightened(.18) if is_hovered() or has_focus() else DANGER
	var center = size*.5+Vector2(0,1 if is_pressed() else 0)
	draw_polyline(PackedVector2Array([center+Vector2(-9,-6),center+Vector2(-7,11),center+Vector2(7,11),center+Vector2(9,-6)]),tint,2.2,true)
	draw_line(center+Vector2(-12,-9),center+Vector2(12,-9),tint,2.2,true)
	draw_polyline(PackedVector2Array([center+Vector2(-5,-9),center+Vector2(-4,-13),center+Vector2(4,-13),center+Vector2(5,-9)]),tint,2.2,true)
	for x in [-3,3]: draw_line(center+Vector2(x,-3),center+Vector2(x,7),tint,1.7,true)
