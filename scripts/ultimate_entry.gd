extends Node
## First-entry story -> independent native room -> opaque handoff -> shop fade-in.
const Intro = preload("res://scripts/first_attempt_intro.gd")
const HOLD_SECONDS = preload("res://scripts/preparation_catalog.gd").HOLD_SECONDS
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
var hold_time = 0.0
var station_prompt: Node3D
var interaction_ring: Node3D
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
var detail: Control
var hint_frame: CenterContainer

func _ready() -> void:
	profile = Progress.store
	old_environment = game.get_viewport().world_3d.environment
	old_fov = game.camera.fov
	room = Room.instantiate()
	add_child(room)
	station_prompt = preload("res://scripts/upgrade_station_prompt.gd").new()
	room.add_child(station_prompt)
	interaction_ring = station_prompt.ring
	station_prompt.hide()
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
	hint_frame = CenterContainer.new()
	hint_frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_frame.offset_top = 200
	root.add_child(hint_frame)
	var panel = PanelContainer.new()
	var enamel = StyleBoxFlat.new()
	enamel.bg_color = Color(.035,.065,.058,.94)
	enamel.border_color = Color("b89a59")
	enamel.set_border_width_all(2)
	enamel.border_width_bottom = 4
	enamel.content_margin_left = 28
	enamel.content_margin_right = 28
	enamel.content_margin_top = 9
	enamel.content_margin_bottom = 9
	enamel.shadow_color = Color(0,0,0,.5)
	enamel.shadow_size = 5
	panel.add_theme_stylebox_override("panel",enamel)
	hint_frame.add_child(panel)
	prompt = Label.new()
	prompt.text = "选择你的终极武器"
	prompt.add_theme_font_override("font",preload("res://scripts/tutorial_overlay.gd").StoryFont)
	prompt.add_theme_font_size_override("font_size",32)
	prompt.add_theme_color_override("font_color",Color("fff0cc"))
	prompt.add_theme_color_override("font_outline_color",Color("10191b"))
	prompt.add_theme_constant_override("outline_size",5)
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(prompt)
	detail = preload("res://scripts/upgrade_details.gd").new()
	detail.position = Vector2(28,235)
	root.add_child(detail)

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
	if game.paused:
		hold_time = 0.0
		return
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
		var previous_focus = focus
		focus = room.focused(yaw,pitch)
		var held: bool = command.get("interact",Input.is_action_pressed("interact"))
		var pressed = held or interact_pending
		interact_pending = false
		if focus != previous_focus or not held or focus != "blade": hold_time = 0.0
		if held and focus == "blade":
			hold_time = minf(HOLD_SECONDS,hold_time+dt)
			if hold_time >= HOLD_SECONDS:
				if not choose(focus): hold_time = 0.0
		elif pressed and not interact_latch: choose(focus)
		interact_latch = pressed
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
	if hold_time < HOLD_SECONDS: return false
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
	hint_frame.visible = in_room
	var dossier: Dictionary = {}
	if in_room and room.exhibits.has(focus):
		var item: Dictionary = room.exhibits[focus].item
		var ultimate = preload("res://scripts/ultimate.gd")
		var rows: Array = [["伤害",str(ultimate.DAMAGE[0]) if item.available else "--","--"],["持续时间",str(int(ultimate.DURATION))+"秒" if item.available else "--","--"],["冷却时间",str(int(ultimate.COOLDOWN))+"秒" if item.available else "--","--"]]
		dossier = {"title":item.label,"level":"LV--","rows":rows,"note":notice if notice_time > 0 else "长按 %s 确认选择" % Data.binding_label("interact") if item.available else "Demo版不可用"}
	detail.sync(dossier)
	station_prompt.visible = in_room and not focus.is_empty()
	if station_prompt.visible:
		var at: Vector3 = room.exhibits[focus].root.position+Vector3(0,.45,0)
		station_prompt.sync(at,game.camera.global_position,game.camera,room.exhibits[focus].item.label+"\n--","--",preload("res://scripts/currency_art.gd").coin(),hold_time/HOLD_SECONDS,focus == "blade","ready" if focus == "blade" else "disabled")
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
