# Hallmark · pre-emit critique: P4 H5 E4 S5 R5 V4
extends Control
## Transparent wave counter and a separate native crystal health strip.
const GREEN = Color("79d98d")
const YELLOW = Color("edc65b")
const RED = Color("f06c5b")
const WHITE = Color("f4eedb")
const INK = Color("10191b")
const TRACK = Color("27352b")
var wave_label: Label
var crystal_label: Label
var crystal_bar: ProgressBar
var crystal_panel: VBoxContainer
var crystal_fill: StyleBoxFlat

func _init() -> void:
	custom_minimum_size = Vector2(300,50)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_label = Label.new()
	wave_label.add_theme_font_size_override("font_size",28)
	wave_label.add_theme_color_override("font_color",WHITE)
	wave_label.add_theme_color_override("font_outline_color",INK)
	wave_label.add_theme_constant_override("outline_size",4)
	add_child(wave_label)
	crystal_panel = VBoxContainer.new()
	crystal_panel.name = "CrystalHealth"
	crystal_panel.add_theme_constant_override("separation",4)
	add_child(crystal_panel)
	crystal_label = Label.new()
	crystal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crystal_label.add_theme_font_size_override("font_size",22)
	crystal_label.add_theme_color_override("font_color",WHITE)
	crystal_label.add_theme_color_override("font_outline_color",INK)
	crystal_label.add_theme_constant_override("outline_size",2)
	crystal_panel.add_child(crystal_label)
	crystal_bar = ProgressBar.new()
	crystal_bar.show_percentage = false
	crystal_bar.custom_minimum_size.y = 16
	var background = StyleBoxFlat.new()
	background.bg_color = TRACK
	crystal_bar.add_theme_stylebox_override("background",background)
	crystal_fill = StyleBoxFlat.new()
	crystal_fill.bg_color = GREEN
	crystal_bar.add_theme_stylebox_override("fill",crystal_fill)
	crystal_panel.add_child(crystal_bar)

static func health_color(ratio: float) -> Color:
	return RED if ratio < .25 else YELLOW if ratio < .5 else GREEN

func sync(current_wave: int, hp: int, maximum: int, _started: bool, _under_attack: bool) -> void:
	wave_label.text = "波数 %d/10" % current_wave
	crystal_panel.visible = visible
	crystal_label.text = "水晶    %d / %d" % [hp,maximum]
	crystal_bar.max_value = maxi(1,maximum)
	crystal_bar.value = hp
	crystal_fill.bg_color = health_color(float(hp)/maxi(1,maximum))
