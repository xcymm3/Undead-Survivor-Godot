extends Node
## First-entry story -> independent native room -> opaque handoff -> shop fade-in.
const Intro = preload("res://scripts/first_attempt_intro.gd")
const Room = preload("res://scenes/ultimate_selection_room.tscn")
var game
var profile
var continuation: Callable
var room
var phase = "intro"
var elapsed = 0.0
var yaw = 0.0
var pitch = 0.0
var focus = ""
var notice = ""
var notice_time = 0.0
var interact_latch = false
var interact_pending = false
var handing_over = false
var restored = false
var old_environment: Environment
var old_fov = 61.0
var overlay: CanvasLayer
var black: ColorRect
var story: VBoxContainer
var prompt: Label
var detail: Label
var controls: Label

func _ready() -> void:
	profile = Progress.store
	old_environment = game.get_viewport().world_3d.environment
	old_fov = game.camera.fov
	room = Room.instantiate()
	add_child(room)
	game.arena.hide()
	game.get_viewport().world_3d.environment = room.room_environment
	game.weapon.hide()
	if game.equipment_prop: game.equipment_prop.hide()
	game.ui.native_hud.hide()
	game.sound.set_playing(false)
	phase = "reveal" if profile.data.intro_seen else "intro"
	build_overlay()
	if not Data.automation and DisplayServer.get_name() != "headless" and "--silent" not in OS.get_cmdline_user_args(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	prompt = ui_label("开始游戏前，选择你的终极武器",32)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	prompt.offset_top = 65
	prompt.offset_bottom = 122
	root.add_child(prompt)
	detail = ui_label("靠近展台，查看终极武器",25)
	detail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	detail.offset_left = 28
	detail.offset_right = 400
	detail.offset_top = -120
	detail.offset_bottom = -65
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(detail)
	var movement_keys = "%s %s %s %s" % [Data.binding_label("forward"),Data.binding_label("left"),Data.binding_label("back"),Data.binding_label("right")]
	controls = ui_label("%s 移动  ·  鼠标环视  ·  %s 选择" % [movement_keys,Data.binding_label("interact")],19)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 28
	controls.offset_top = -65
	controls.offset_bottom = -25
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(controls)

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

func step(dt: float, command: Dictionary = {}) -> void:
	if game.paused: return
	elapsed += dt
	notice_time = maxf(0,notice_time-dt)
	if phase == "intro":
		if elapsed >= Intro.DURATION:
			profile.data.intro_seen = true
			profile.dirty = true
			profile.save()
			phase = "reveal"
			elapsed = 0.0
	elif phase == "reveal":
		if elapsed >= .9: phase = "room"; elapsed = 0.0
	elif phase == "room":
		var movement: Vector2 = command.get("movement",Input.get_vector("left","right","forward","back"))
		var direction = Basis(Vector3.UP,yaw)*Vector3(movement.x,0,movement.y)
		room.player.advance(Vector2(direction.x,direction.z)*3.6,dt)
		focus = room.focused(yaw,pitch)
		var interact: bool = command.get("interact",Input.is_action_pressed("interact")) or interact_pending
		interact_pending = false
		if interact and not interact_latch: choose(focus)
		interact_latch = interact
	elif phase == "fade_out":
		if elapsed >= .9:
			restore_world()
			handing_over = true
			continuation.call()
			handing_over = false
			phase = "handoff"
			elapsed = 0.0
	elif phase == "handoff":
		if elapsed >= .2 and not Session.loading and (not game.running or game.sim != null):
			phase = "return"
			elapsed = 0.0
	elif phase == "return":
		if elapsed >= 1.0:
			phase = "done"
			game.entry_sequence = null
			queue_free()
	if is_instance_valid(room) and not restored: room.animate(dt,focus)

func choose(id: String) -> bool:
	if phase != "room" or not room.exhibits.has(id) or room.focused(yaw,pitch) != id: return false
	if id != "blade":
		notice = "Demo版不可用"
		notice_time = 1.8
		return false
	if not profile.select_ultimate(id):
		notice = profile.notice
		notice_time = 3.0
		return false
	game.reset_mouse_buttons()
	phase = "fade_out"
	elapsed = 0.0
	return true

func request_interaction() -> void:
	if phase == "room": interact_pending = true

func look(delta: Vector2) -> void:
	if phase != "room": return
	var limit = minf(180,deg_to_rad(25)/maxf(.000001,Data.settings.sensitivity))
	if absf(delta.x) <= limit: yaw = wrapf(yaw-delta.x*Data.settings.sensitivity,-PI,PI)
	if absf(delta.y) <= limit: pitch = clampf(pitch-delta.y*Data.settings.sensitivity,-1.3,1.3)

func render() -> void:
	if not overlay: return
	overlay.visible = not game.paused
	if not restored:
		game.camera.global_position = room.player.global_position+Vector3.UP*1.7
		game.camera.rotation = Vector3(pitch,yaw,0)
		game.camera.fov = 70
		game.weapon.hide()
		if game.equipment_prop: game.equipment_prop.hide()
	story.visible = phase == "intro"
	for i in story.get_child_count(): story.get_child(i).modulate.a = Intro.line_alpha({"intro_elapsed":elapsed},i)
	var in_room = phase in ["room","reveal"]
	prompt.visible = in_room
	detail.visible = in_room
	controls.visible = in_room
	if notice_time > 0: detail.text = notice
	elif room.exhibits.has(focus):
		var item: Dictionary = room.exhibits[focus].item
		detail.text = "%s  ·  %s" % [item.label,"按 %s 选择" % Data.binding_label("interact") if item.available else "Demo版不可用"]
	else: detail.text = "靠近展台，查看终极武器"
	var alpha = 1.0
	if phase == "reveal": alpha = 1.0-clampf(elapsed/.9,0,1)
	elif phase == "room": alpha = 0.0
	elif phase == "fade_out": alpha = clampf(elapsed/.9,0,1)
	elif phase == "return": alpha = 1.0-clampf(elapsed,0,1)
	black.color = Color(0,0,0,alpha)
	black.visible = alpha > 0

func restore_world() -> void:
	if restored: return
	restored = true
	room.hide()
	game.arena.show()
	game.get_viewport().world_3d.environment = old_environment
	game.camera.fov = old_fov

func cancel() -> void:
	restore_world()
	queue_free()
