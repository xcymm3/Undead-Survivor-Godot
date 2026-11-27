extends Node
## First-visit prologue followed by the ordinary single-player or host spawn.
const Intro = preload("res://scripts/first_attempt_intro.gd")
var game
var continuation: Callable
var phase = "intro"
var elapsed = 0.0
var handing_over = false
var overlay: CanvasLayer
var black: ColorRect
var story: VBoxContainer

func _ready() -> void:
	game.weapon.hide()
	game.ui.native_hud.hide()
	game.sound.set_playing(false)
	build_overlay()
	if Progress.store.data.intro_seen: phase = "resume"
	render()

func build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 3
	add_child(overlay)
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(root)
	black = ColorRect.new()
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.color = Color.BLACK
	root.add_child(black)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	story = VBoxContainer.new()
	story.add_theme_constant_override("separation",24)
	center.add_child(story)
	for line in Intro.LINES:
		var label = ui_label(line,38)
		label.add_theme_font_override("font",preload("res://assets/fonts/SourceHanSerifSC-SemiBold.otf"))
		story.add_child(label)

func ui_label(value: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",preload("res://assets/fonts/NotoSansCJKsc-Regular.otf"))
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("e9effb"))
	label.add_theme_color_override("font_shadow_color",Color("040914"))
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func blocks_world() -> bool:
	return phase != "return" and phase != "done"

func step(dt: float) -> void:
	if game.paused: return
	elapsed += dt
	if phase == "resume" or (phase == "intro" and elapsed >= Intro.DURATION):
		var profile = Progress.store
		profile.data.intro_seen = true
		profile.data.ultimate_choice = "blade"
		profile.dirty = true
		profile.save()
		phase = "handoff"
		elapsed = 0.0
		handing_over = true
		continuation.call()
		handing_over = false
	elif phase == "handoff" and not Session.loading and elapsed >= .2:
		phase = "return"
		elapsed = 0.0
	elif phase == "return" and elapsed >= 1.0:
		game.entry_sequence = null
		queue_free()

func render() -> void:
	overlay.visible = not game.paused
	story.visible = phase == "intro"
	for i in story.get_child_count():
		story.get_child(i).modulate.a = Intro.line_alpha({"intro_elapsed":elapsed},i)
	black.color = Color(0,0,0,1.0-clampf(elapsed,0,1) if phase == "return" else 1.0)

func cancel() -> void:
	queue_free()
