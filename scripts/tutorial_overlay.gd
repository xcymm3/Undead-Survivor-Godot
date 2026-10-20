extends Control
var black: ColorRect
var caption: Label
var hints: HBoxContainer
var movement: Label
var aim_icon: Control
var shove_icon: Control
const Intro = preload("res://scripts/first_attempt_intro.gd")
const Tutorial = preload("res://scripts/onboarding.gd")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	black = ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.offset_left = 90
	caption.offset_right = -90
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_override("font",preload("res://scripts/upgrade_art.gd").font())
	caption.add_theme_font_size_override("font_size",30)
	caption.add_theme_color_override("font_color",Color("f1eadc"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	hints = HBoxContainer.new()
	hints.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hints.offset_top = 24
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	hints.add_theme_constant_override("separation",16)
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hints)
	movement = label("")
	aim_icon = preload("res://scripts/tutorial_mouse_icon.gd").new()
	hints.add_child(aim_icon)
	var aim = label("开镜")
	aim.name = "AimLabel"
	shove_icon = preload("res://scripts/tutorial_mouse_icon.gd").new()
	shove_icon.action = "shove"
	hints.add_child(shove_icon)
	var shove = label("枪托攻击")
	shove.name = "ShoveLabel"
	sync({})

func label(value: String) -> Label:
	var view = Label.new()
	view.text = value
	view.add_theme_font_override("font",preload("res://scripts/upgrade_art.gd").font())
	view.add_theme_font_size_override("font_size",22)
	view.add_theme_color_override("font_color",Color("fff0cc"))
	view.add_theme_color_override("font_outline_color",Color("10191b"))
	view.add_theme_constant_override("outline_size",5)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.add_child(view)
	return view

func sync(state: Dictionary) -> void:
	if not black: return
	black.visible = Intro.active(state)
	caption.visible = black.visible
	caption.text = Intro.caption(state) if black.visible else ""
	caption.modulate.a = Intro.alpha(state)
	var mode = Tutorial.hint_mode(state)
	hints.visible = not mode.is_empty()
	movement.visible = mode == "movement"
	movement.text = "%s 疾跑     %s 蹲下" % [Data.binding_label("sprint"),Data.binding_label("crouch")]
	for child in hints.get_children():
		if child != movement: child.visible = mode == "combat"
	aim_icon.queue_redraw()
	shove_icon.queue_redraw()
