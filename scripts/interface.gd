extends CanvasLayer
var game
var root: Control
var menu: Control
var hud: Control
var current = ""
var font: Font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
var player_name = "幸存者"
var address = "127.0.0.1:27777"
var steam_code = ""
var room_mode = "steam"
var room_query = ""
var multiplayer_view
var hit_flash = 0.0
var hurt_flash = 0.0
var message = ""
var victory_caption: Label
var native_hud
var binding_action = ""
var binding_button: Button
var binding_confirmation: Control
var pending_binding: Dictionary = {}
var settings_tab = 0
var overlay_state: Array = []
const INK = Color("eee4c9")
const PAPER = Color("14231f")
const RUST = Color("ae573b")
const SETTINGS_INK = Color("f2e2bd")
const SETTINGS_MUTED = Color("c4ad86")
const SETTINGS_BRASS = Color("c59b62")
const SETTINGS_PAPER = Color(.055,.09,.075,.96)

func _ready() -> void:
	if not Session.resume_room.is_empty(): address = Session.resume_room
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Theme.new()
	root.theme.default_font = font
	root.theme.default_font_size = 18
	root.theme.set_color("font_color","Label",INK)
	root.theme.set_color("font_color","Button",INK)
	root.theme.set_color("font_hover_color","Button",INK)
	root.theme.set_color("font_focus_color","Button",INK)
	root.theme.set_stylebox("normal","Button",box(Color("293d32"),10))
	root.theme.set_stylebox("hover","Button",box(Color("415c47"),10))
	root.theme.set_stylebox("pressed","Button",box(Color("19291f"),10))
	root.theme.set_stylebox("focus","Button",box(Color("ae573b"),10))
	add_child(root)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(hud)
	hud.draw.connect(_draw_hud)
	native_hud = preload("res://scripts/hud_panel.gd").new()
	hud.add_child(native_hud)
	native_hud.setup(self)
	native_hud.visible = false
	victory_caption = label("已击败-DiscoKing",48)
	victory_caption.name = "BossDefeatedCaption"
	victory_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	victory_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory_caption.add_theme_color_override("font_color",Color("f2d796"))
	victory_caption.add_theme_color_override("font_outline_color",Color("151c24"))
	victory_caption.add_theme_constant_override("outline_size",8)
	root.add_child(victory_caption)
	victory_caption.hide()
	Session.changed.connect(func():
		if current == "multiplayer" and multiplayer_view: multiplayer_view.sync())

func box(color: Color, padding := 16) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.border_width_bottom = 3
	style.border_color = color.darkened(.4)
	return style

func settings_box(color: Color, border: Color, padding := 12) -> StyleBoxFlat:
	var style = box(color,padding)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style

func settings_theme() -> Theme:
	var theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	for kind in ["Button","OptionButton"]:
		theme.set_color("font_color",kind,SETTINGS_INK)
		theme.set_color("font_hover_color",kind,Color("fff0cf"))
		theme.set_color("font_pressed_color",kind,Color("fff0cf"))
		theme.set_color("font_focus_color",kind,SETTINGS_INK)
		theme.set_color("font_disabled_color",kind,SETTINGS_MUTED)
		theme.set_stylebox("normal",kind,settings_box(Color(.12,.09,.06,.72),Color(.55,.39,.21,.75)))
		theme.set_stylebox("hover",kind,settings_box(Color(.28,.18,.10,.9),SETTINGS_BRASS))
		theme.set_stylebox("pressed",kind,settings_box(Color(.38,.24,.12,.94),SETTINGS_BRASS))
		theme.set_stylebox("hover_pressed",kind,settings_box(Color(.44,.28,.14,.94),SETTINGS_BRASS))
		theme.set_stylebox("focus",kind,settings_box(Color.TRANSPARENT,Color(.95,.79,.49,.85),0))
	theme.set_constant("modulate_arrow","OptionButton",1)
	theme.set_color("font_color","Label",SETTINGS_INK)
	theme.set_color("font_color","LineEdit",SETTINGS_INK)
	theme.set_color("caret_color","LineEdit",SETTINGS_BRASS)
	theme.set_color("selection_color","LineEdit",Color(.65,.43,.19,.65))
	theme.set_stylebox("normal","LineEdit",settings_box(Color(.1,.08,.06,.76),Color(.57,.4,.22,.75),8))
	theme.set_stylebox("focus","LineEdit",settings_box(Color.TRANSPARENT,SETTINGS_BRASS,0))
	theme.set_stylebox("read_only","LineEdit",settings_box(Color(.1,.08,.06,.5),Color(.4,.3,.2,.65),8))
	theme.set_stylebox("separator","HSeparator",settings_box(Color(.65,.46,.24,.7),Color.TRANSPARENT,0))
	theme.set_stylebox("slider","HSlider",settings_box(Color(.1,.08,.06,.85),Color(.61,.44,.24,.75),3))
	theme.set_stylebox("grabber_area","HSlider",settings_box(Color(.72,.48,.22,.95),Color(.85,.68,.37,.85),3))
	theme.set_stylebox("grabber_area_highlight","HSlider",settings_box(Color(.86,.61,.28,.98),SETTINGS_BRASS,3))
	var grabber_image = Image.create_empty(14,14,false,Image.FORMAT_RGBA8)
	grabber_image.fill(SETTINGS_BRASS)
	var grabber = ImageTexture.create_from_image(grabber_image)
	theme.set_icon("grabber","HSlider",grabber)
	theme.set_icon("grabber_highlight","HSlider",grabber)
	theme.set_stylebox("scroll","VScrollBar",settings_box(Color(.09,.07,.05,.7),Color.TRANSPARENT,2))
	theme.set_stylebox("grabber","VScrollBar",settings_box(Color(.55,.39,.21,.9),Color(.78,.6,.35,.8),2))
	theme.set_stylebox("grabber_highlight","VScrollBar",settings_box(Color(.67,.48,.26,.95),SETTINGS_BRASS,2))
	theme.set_stylebox("grabber_pressed","VScrollBar",settings_box(Color(.75,.54,.29,.95),SETTINGS_BRASS,2))
	return theme

# Hallmark · pre-emit critique: P4 H4 E4 S5 R5 V4
# Settings retain the home menu's enamel green, cut corners and brass accents.
func green_settings_theme() -> Theme:
	var theme = settings_theme()
	var art = preload("res://scripts/menu_button.gd")
	for kind in ["Button","OptionButton"]:
		theme.set_stylebox("normal",kind,settings_box(art.GREEN,art.GREEN.lightened(.3)))
		theme.set_stylebox("hover",kind,settings_box(art.GREEN.lightened(.2),art.GOLD))
		theme.set_stylebox("pressed",kind,settings_box(art.GREEN.darkened(.18),art.GOLD))
		theme.set_stylebox("hover_pressed",kind,settings_box(art.GREEN,art.GOLD))
		theme.set_color("font_color",kind,art.TEXT)
		theme.set_color("font_hover_color",kind,art.HOVER_TEXT)
	theme.set_stylebox("slider","HSlider",settings_box(art.DARK,art.GREEN.lightened(.3),3))
	theme.set_stylebox("grabber_area","HSlider",settings_box(art.GREEN,art.GREEN.lightened(.3),3))
	theme.set_stylebox("grabber_area_highlight","HSlider",settings_box(art.GREEN.lightened(.2),art.GOLD,3))
	theme.set_stylebox("scroll","VScrollBar",settings_box(art.DARK,Color.TRANSPARENT,2))
	theme.set_stylebox("grabber","VScrollBar",settings_box(art.GREEN,art.GREEN.lightened(.3),2))
	theme.set_stylebox("grabber_highlight","VScrollBar",settings_box(art.GREEN.lightened(.2),art.GOLD,2))
	theme.set_stylebox("grabber_pressed","VScrollBar",settings_box(art.GREEN.darkened(.18),art.GOLD,2))
	return theme

func label(text: String, size := 18, color := INK) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",color)
	return node

func paragraph(parent: Node, text: String, size := 17, color := INK) -> Label:
	var node = label(text,size,color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func button(parent: Node, text: String, callback: Callable, primary := false) -> Button:
	var node = Button.new()
	node.text = text
	node.custom_minimum_size.y = 48
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		node.add_theme_stylebox_override("normal",box(RUST,12))
		node.add_theme_stylebox_override("hover",box(Color("97492f"),12))
		node.add_theme_color_override("font_color",Color("fff7e8"))
		node.add_theme_color_override("font_hover_color",Color.WHITE)
	parent.add_child(node)
	node.pressed.connect(callback)
	return node

func clear_menu() -> void:
	cancel_binding_swap(false)
	binding_action = ""
	if game: game.request_draw()
	if is_instance_valid(menu):
		root.remove_child(menu)
		menu.queue_free()
		menu = null
	current = ""
	if native_hud: native_hud.visible = game.running
	if hud: hud.queue_redraw()

func panel(title: String, subtitle: String, width := 700, warm := false) -> VBoxContainer:
	clear_menu()
	if warm and native_hud: native_hud.visible = false
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var shade = ColorRect.new()
	shade.color = Color(.07,.05,.035,.34) if warm else Color(0.06,.1,.08,.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var card = PanelContainer.new()
	var card_style = settings_box(SETTINGS_PAPER,SETTINGS_BRASS,28)
	card.theme = settings_theme()
	card_style.border_width_left = 5
	card_style.border_width_top = 2
	card_style.shadow_color = Color(0,0,0,.65)
	card_style.shadow_size = 12
	if warm:
		card.theme = settings_theme()
		card_style.border_width_left = 5
		card_style.border_width_top = 2
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.border_color = SETTINGS_BRASS
		card_style.shadow_color = Color(.02,.015,.01,.3)
		card_style.shadow_size = 14
	card.add_theme_stylebox_override("panel",card_style)
	card.custom_minimum_size.x = width
	center.add_child(card)
	card.add_child(preload("res://scripts/menu_plate.gd").new())
	var scroll = ScrollContainer.new()
	var height = 650 if warm or width >= 900 else 560 if title in ["游戏通关","水晶防线失守"] else 450
	scroll.custom_minimum_size = Vector2(minf(width-56,root.size.x-100),minf(height,root.size.y-160))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",14)
	scroll.add_child(column)
	column.add_child(label("断崖防线  /  FIELD CONTROL",13,SETTINGS_BRASS))
	column.add_child(HSeparator.new())
	column.add_child(label(title,34,SETTINGS_INK))
	paragraph(column,subtitle,16,SETTINGS_MUTED if warm else Color("797b6f"))
	return column

func settings_heading(parent: VBoxContainer, text: String) -> void:
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation",8)
	parent.add_child(separator)
	parent.add_child(label(text,20,SETTINGS_INK))

func home_button(parent: Node, text: String, callback: Callable, primary := false) -> Button:
	var node = preload("res://scripts/menu_button.gd").new()
	node.text = text
	node.primary = primary
	node.custom_minimum_size.y = 48
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(node)
	node.pressed.connect(callback)
	node.mouse_entered.connect(func():
		if not node.disabled: game.sound.play("menu-hover",-18))
	return node

func show_home() -> void:
	clear_menu()
	current = "home"
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	menu.add_child(preload("res://scripts/menu_backdrop.gd").new())
	var stage = Control.new()
	stage.name = "HomeStage"
	stage.size = Vector2(1440,900)
	menu.add_child(stage)
	var fit = func():
		var factor = minf(root.size.x/1440.0,root.size.y/900.0)
		stage.scale = Vector2.ONE*factor
		stage.position = (root.size-stage.size*factor)*.5
	menu.resized.connect(fit)
	fit.call()
	var edition = label("断崖防线  /  TEN WAVES • ONE LAST STAND",17,Color("adba9c"))
	edition.position = Vector2(58,42)
	stage.add_child(edition)
	var version = label("v"+str(ProjectSettings.get_setting("application/config/version","2.2.0")),16,Color("adba9c"))
	version.position = Vector2(1290,42)
	stage.add_child(version)
	var title = preload("res://scripts/menu_title.gd").new()
	var display_font = FontVariation.new()
	display_font.base_font = font
	display_font.variation_embolden = 1.1
	title.display_font = display_font
	title.name = "GameTitle"
	title.position = Vector2(140,175)
	title.size = Vector2(1160,310)
	stage.add_child(title)
	var subtitle = label("守住水晶，击败舞王",25,Color("bccaab"))
	subtitle.position = Vector2(300,505)
	subtitle.size.x = 840
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(subtitle)
	var emblem = TextureRect.new()
	emblem.name = "CrystalSigil"
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.texture = preload("res://scripts/currency_art.gd").diamond()
	emblem.position = Vector2(680,98)
	emblem.size = Vector2(80,80)
	stage.add_child(emblem)
	var actions = HBoxContainer.new()
	actions.name = "HomeActions"
	actions.position = Vector2(0,723)
	actions.resized.connect(func(): actions.position.x = (stage.size.x-actions.size.x)*.5)
	actions.add_theme_constant_override("separation",14)
	stage.add_child(actions)
	for item in [["单人游戏",func(): game.start_solo("defense")],["设置",show_settings],["退出游戏",func(): game.quit_game()]]:
		var option = home_button(actions,item[0],item[1],item[0] == "单人游戏")
		option.custom_minimum_size = Vector2(188,76)
		option.add_theme_font_size_override("font_size",25)
	var save = home_button(actions,"存档 %d" % (Progress.active_slot+1),show_save_slots)
	actions.move_child(save,0)
	save.custom_minimum_size = Vector2(168,76)
	var profile = label("金币 %d   ◆ 钻石 %d   最佳第 %d 波" % [Progress.store.data.coins,Progress.store.data.diamonds,Progress.store.data.best_wave],17,Color("b6c3a5"))
	profile.position = Vector2(120,827)
	profile.size.x = 1200
	profile.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(profile)
	if not message.is_empty():
		var notice = label(message,17,Color("e9b79a"))
		notice.position = Vector2(58,92)
		stage.add_child(notice)

# Hallmark · pre-emit critique: P4 H4 E4 S5 R4 V4
func field_shell(title: String, subtitle: String, dimensions := Vector2(1040,840)) -> VBoxContainer:
	clear_menu()
	if native_hud: native_hud.visible = false
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	menu.add_child(preload("res://scripts/menu_backdrop.gd").new())
	var stage = Control.new()
	stage.name = "FieldMenuStage"
	stage.size = Vector2(1120,900)
	menu.add_child(stage)
	var fit = func():
		var factor = minf(root.size.x/1120.0,root.size.y/900.0)
		stage.scale = Vector2.ONE*factor
		stage.position = (root.size-stage.size*factor)*.5
	menu.resized.connect(fit)
	fit.call()
	var frame = PanelContainer.new()
	frame.name = "FieldConsole"
	frame.position = (stage.size-dimensions)*.5
	frame.size = dimensions
	frame.theme = settings_theme()
	var style = settings_box(PAPER,SETTINGS_BRASS,28)
	style.border_width_top = 5
	style.border_width_bottom = 5
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	frame.add_theme_stylebox_override("panel",style)
	stage.add_child(frame)
	frame.add_child(preload("res://scripts/menu_plate.gd").new())
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	frame.add_child(column)
	column.add_child(label("断崖防线   /   生存行动",15,SETTINGS_BRASS))
	column.add_child(label(title,38,SETTINGS_INK))
	paragraph(column,subtitle,16,SETTINGS_MUTED)
	column.add_child(HSeparator.new())
	return column

func show_save_slots() -> void:
	var column = field_shell("幸存者档案","三个独立存档 · 切换后从第一波开始 · 成长进度永久保留")
	current = "saves"
	var files = HBoxContainer.new()
	files.name = "SaveDossiers"
	files.size_flags_vertical = Control.SIZE_EXPAND_FILL
	files.add_theme_constant_override("separation",18)
	column.add_child(files)
	for index in 3:
		var profile = Progress.slots[index]
		var active: bool = index == Progress.active_slot
		var card = PanelContainer.new()
		card.name = "SaveSlot%d" % (index+1)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style = settings_box(PAPER.lightened(.07) if active else PAPER.darkened(.15),SETTINGS_BRASS if active else SETTINGS_MUTED.darkened(.55),20)
		style.border_width_top = 4 if active else 1
		card.add_theme_stylebox_override("panel",style)
		files.add_child(card)
		var dossier = VBoxContainer.new()
		dossier.add_theme_constant_override("separation",15)
		card.add_child(dossier)
		dossier.add_child(label("档案  /  %02d" % (index+1),28,SETTINGS_BRASS))
		dossier.add_child(label("当前使用" if active else "待命存档",17,SETTINGS_INK))
		dossier.add_child(HSeparator.new())
		for entry in [["金币",floori(profile.data.coins)],["钻石",profile.data.diamonds],["最佳波次",profile.data.best_wave]]:
			var row = HBoxContainer.new()
			dossier.add_child(row)
			var caption = label(entry[0],17,SETTINGS_MUTED)
			caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(caption)
			row.add_child(label(str(entry[1]),25,SETTINGS_INK))
		var space = Control.new()
		space.size_flags_vertical = Control.SIZE_EXPAND_FILL
		dossier.add_child(space)
		home_button(dossier,"使用存档 %d" % (index+1),game.select_save_slot.bind(index),active)
		var remove = home_button(dossier,"永久删除存档 %d" % (index+1),confirm_delete_slot.bind(index))
		remove.add_theme_font_size_override("font_size",15)
	home_button(column,"返回主菜单",show_home)

func show_pause() -> void:
	var column = panel("休息片刻", "合作对局仍在进行" if Session.playing else "行动计时已暂停",560)
	current = "pause"
	var resume = home_button(column,"继续游戏",func(): game.resume_game())
	resume.selected = true
	if not Session.playing: home_button(column,"重新开始",func(): game.start_solo(game.sim.mode))
	home_button(column,"设置",show_settings)
	home_button(column,"结束房间并返回" if Session.is_host() else "离开房间" if Session.playing else "返回主菜单",func(): game.return_home())

func back() -> void:
	if current == "multiplayer" and multiplayer_view and is_instance_valid(multiplayer_view.dialog):
		multiplayer_view.close_dialog()
		return
	if current == "multiplayer": Session.leave()
	if game.running: show_pause()
	else: show_home()

func field_choice(parent: VBoxContainer, caption: String, options: Array, selected: int, callback: Callable) -> Label:
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 44
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	var heading = label(caption,18,SETTINGS_INK)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	var value = label(str(options[selected]),18,SETTINGS_BRASS)
	value.custom_minimum_size.x = 170
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var state = {"index":selected}
	var change = func(delta):
		state.index = posmod(state.index+delta,options.size())
		value.text = str(options[state.index])
		callback.call(state.index)
	var previous = home_button(row,"‹",change.bind(-1))
	previous.custom_minimum_size = Vector2(46,44)
	previous.accessibility_name = caption+"：上一项"
	row.add_child(value)
	var next = home_button(row,"›",change.bind(1))
	next.custom_minimum_size = Vector2(46,44)
	next.accessibility_name = caption+"：下一项"
	return value

func field_slider(parent: VBoxContainer, caption: String, minimum: float, maximum: float, initial: float, callback: Callable) -> void:
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 50
	row.add_theme_constant_override("separation",24)
	parent.add_child(row)
	var title = label(caption,18,SETTINGS_INK)
	title.custom_minimum_size.x = 170
	row.add_child(title)
	var slider = HSlider.new()
	slider.name = "Sensitivity" if minimum > 0 else "MasterVolume"
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 1
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value = label("%d %%" % initial,22,SETTINGS_BRASS)
	value.custom_minimum_size.x = 95
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	slider.value_changed.connect(func(v):
		value.text = "%d %%" % v
		callback.call(v))

func show_settings() -> void:
	binding_action = ""
	game.reset_mouse_buttons()
	Data.sync_window_mode()
	var shell = field_shell("战场设置","调整操控、声音与画面 · 更改自动保存")
	shell.get_parent().theme = green_settings_theme()
	current = "settings"
	var navigation = HBoxContainer.new()
	navigation.add_theme_constant_override("separation",16)
	shell.add_child(navigation)
	for index in 3:
		var tab = home_button(navigation,["操控设置","声音设置","画面设置"][index],func():
			settings_tab = index
			show_settings())
		tab.selected = settings_tab == index
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll = ScrollContainer.new()
	scroll.name = "FieldSettings"
	scroll.custom_minimum_size.y = 390
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12)
	scroll.add_child(column)
	if settings_tab == 0:
		settings_heading(column,"操控")
		field_slider(column,"鼠标灵敏度",10,200,Data.settings.sensitivity/.0022*100,func(v):
			Data.settings.sensitivity = v/100*.0022
			Data.save())
		field_choice(column,"镜头抖动",["关闭","轻度","标准"],int(Data.settings.screen_shake),func(v):
			Data.settings.screen_shake = v
			game.screen_shake.clear()
			Data.save())
		paragraph(column,"点击按键后输入新按键或鼠标键，Esc 取消；重复绑定需确认后互换。开镜为切换模式。",16,SETTINGS_MUTED)
		for spec in Data.Bindings.ACTIONS:
			var row = HBoxContainer.new()
			column.add_child(row)
			var title = label(spec[1],18,SETTINGS_INK)
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(title)
			var control = home_button(row,Data.binding_label(spec[0]),func(): pass)
			control.name = "Binding_"+spec[0]
			control.custom_minimum_size = Vector2(230,44)
			control.pressed.connect(func():
				if is_instance_valid(binding_button) and not binding_action.is_empty(): binding_button.text = Data.binding_label(binding_action)
				binding_action = spec[0]
				binding_button = control
				control.text = "请按键 · Esc 取消")
		home_button(column,"恢复默认键位",func():
			Data.reset_bindings()
			show_settings())
	elif settings_tab == 1:
		settings_heading(column,"声音")
		field_slider(column,"主音量",0,100,Data.settings.volume*100,func(v):
			Data.settings.volume = v/100
			Data.apply_settings()
			Data.save())
	else:
		var quality_label = field_choice(column,"画质预设",["极限流畅","流畅","均衡","精细","极致画质","自定义"],int(Data.settings.quality),func(v):
			Data.set_preset(v)
			show_settings())
		for spec in [
			["渲染比例","resolution",[.5,.67,.75,1.0],["50%","67%","75%","100%"]],
			["抗锯齿","aa",[0,1,2,3],["关闭","MSAA 2×","MSAA 4×","MSAA 8×"]],
			["阴影","shadows",[0,1,2,3,4],["关闭","低","中","高","极高"]],
			["特效","effects",[0,1,2],["低","中","高"]],
			["视距","distance",[0,1,2],["近","中","远"]],
			["帧率上限","frame_limit",[30,60,120,0],["30 FPS","60 FPS","120 FPS","不限"]],
			["像素化显示","pixelated",[false,true],["关闭","开启"]],
			["全屏（F11）","fullscreen",[false,true],["关闭","开启"]]]:
			field_choice(column,spec[0],spec[3],maxi(0,spec[2].find(Data.settings[spec[1]])),func(index):
				Data.settings[spec[1]] = spec[2][index]
				if spec[1] == "fullscreen":
					Data.set_fullscreen(spec[2][index])
				else:
					Data.settings.quality = 5
					quality_label.text = "自定义"
					Data.apply_settings()
				Data.save())
	home_button(shell,"返回",back)

func show_guide() -> void:
	var column = panel("武器与操作", "水晶防线 · 十波连续进攻",1000)
	current = "guide"
	paragraph(column,"战前靠近并瞄准展台或施工点，长按 %s 升级或建造。整备完毕，长按 %s 修复破损水晶后立即启动进攻，随后，展台关闭；每波投放完至少等待10秒，且场上存活僵尸少于10只时自动接下一波。每清完所属波次的敌人获得 1 颗钻石；第2波起，每波开始两把枪各补充2个当前容量的备弹匣。第十波击败舞王后立即清除全部残敌并通关。" % [Data.binding_label("interact"),Data.binding_label("interact")],17)
	paragraph(column,"%s/%s/%s/%s 移动 / %s 疾跑 / 鼠标瞄准 / %s 攻击 / %s 推击 / %s 开镜\n%s 跳跃 / %s 蹲下 / %s 换弹 / 滚轮切换装备 / Esc 暂停\n%s 步枪 / %s 手枪 / %s 消防斧 / %s 手雷 / %s 长按交互\n疾跑速度 ×1.6，无耐力限制；射击、开镜、换弹和蹲下取消疾跑。\n连续推击第 3 次后冷却 3.5 秒。第2波起每波开始两把枪各获得 2 个当前容量的备弹匣，备弹可超上限，使用消防斧节省弹药。" % [Data.binding_label("forward"),Data.binding_label("back"),Data.binding_label("left"),Data.binding_label("right"),Data.binding_label("sprint"),Data.binding_label("fire"),Data.binding_label("shove"),Data.binding_label("aim"),Data.binding_label("jump"),Data.binding_label("crouch"),Data.binding_label("reload"),Data.binding_label("weapon_0"),Data.binding_label("weapon_1"),Data.binding_label("weapon_2"),Data.binding_label("weapon_3"),Data.binding_label("interact")],17)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",24)
	grid.add_theme_constant_override("v_separation",12)
	column.add_child(grid)
	for heading in ["武器","弹量","伤害 / 次","装填"]: grid.add_child(label(heading,16,RUST))
	for i in [0,3,6]:
		var w: Dictionary = Data.weapons[i]
		for text in [w.label,"∞" if w.get("infiniteAmmo",false) else str(int(w.capacity)),str(roundi(w.damage*w.pellets)) if w.get("kind","gun") == "gun" else str(int(w.damage)),"—" if w.reloadDuration == 0 else "%.2f 秒%s" % [w.reloadDuration,"/发" if w.get("shellReload",false) else ""]]: grid.add_child(label(text,17))
	paragraph(column,"击杀会掉落自动飞向玩家的金币，特殊僵尸奖励更高。金币、钻石、升级和已购建筑永久保存；重新开始只重置波次、生命和战场。",17)
	paragraph(column,"生命、炮塔、栅栏和地雷状态跨波保留；手雷每15秒补充一颗至持有上限。没有强壮天赋时不会缓慢回血；学习后连续 5 秒未受伤开始恢复，期间可以攻击。商店也可被僵尸进入。首页可切换三个独立存档。",17)
	button(column,"返回",back,true)

func show_multiplayer(qa_preview := false) -> void:
	if not Data.automation:
		show_home()
		return
	multiplayer_view = preload("res://scripts/multiplayer_menu.gd").new(self)
	multiplayer_view.show_page(qa_preview)

func shop_description(profile, id: String) -> String:
	if id in profile.WEAPONS:
		var index: int = {"rifle":0,"pistol":2,"axe":6}[id]
		return "伤害 %.1f → %.1f · 每次 +%d%%，最高10级，采用固定价格表" % [Data.weapons[index].damage*profile.weapon_multiplier(id)*profile.damage_multiplier(),Data.weapons[index].damage*profile.weapon_multiplier(id)*profile.damage_multiplier()*(1.2 if id == "axe" else 1.25),20 if id == "axe" else 25]
	if id in profile.MAGAZINES:
		var base: int = int(Data.weapons[0 if id == "rifle_magazine" else 2].capacity)
		return "弹匣 %d → %d · 每级 +%d 发 · 上限10级，采用固定价格表" % [profile.magazine_capacity(id.trim_suffix("_magazine"),int(base)),profile.magazine_capacity(id.trim_suffix("_magazine"),int(base),profile.level(id)+1),5 if id == "rifle_magazine" else 3]
	if id == "grenade": return "持有上限 %d / 4 · 每次 +1 · 每15秒补充1颗" % profile.grenade_capacity()
	if id in profile.MINES: return "永久购买 · 无升级 · 每波恢复 · 僵尸触发后 1.5 秒爆炸"
	if id in profile.GATES: return "耐久 %d · 就地升级 +25%% · 价格与枪械相同，最高10级 · 战斗中不复活" % roundi(profile.GATE_BASE_HEALTH*profile.building_multiplier(id))
	if id in profile.BUILDINGS: return "每发伤害 %.1f · 就地升级伤害 +25%% · 价格与枪械相同，最高10级 · 战斗中不复活" % (60*profile.building_multiplier(id))
	match id:
		"strong": return "最大生命 %d · 脱战 5 秒后每秒回复 %.1f 生命 · 每级 +10 生命、+0.5 回复" % [profile.max_health(),profile.regen_rate()]
		"precise": return "本能 · 伤害 +%d%% · 每级 +10%%" % (profile.level(id)*10)
		"swift": return "极速 · 终极技能冷却 %.0f 秒 · 每级减少10%%" % preload("res://scripts/ultimate.gd").cooldown(profile)
		"supply": return "初始备弹匣 %d 个 · 每级增加2个初始备弹匣 · 第2波起开波补2弹匣" % profile.reserve_magazines()
		"greed": return "贪婪 · 金币获取 +%d%% · 每级 +20%%" % (profile.level(id)*20)
	return ""

# Hallmark · component: result modal · atmospheric · existing field palette
# Pre-emit critique: P4 H5 E4 S5 R4 V4
func show_result() -> void:
	var sim = game.sim
	if sim.mode != "defense": return
	var state: Dictionary = sim.defense_state()
	var guest = Session.playing and not Session.is_host()
	var result = field_shell("游戏通关" if sim.won else "防线失守","十波尸潮已清除 · 舞王已击败" if sim.won else "本次防守结束 · 你的个人存档未改变" if guest else "本次防守结束 · 成长进度已保留",Vector2(1040,780))
	current = "result"
	var banner = HBoxContainer.new()
	banner.add_theme_constant_override("separation",28)
	result.add_child(banner)
	var emblem = preload("res://scripts/result_emblem.gd").new()
	emblem.victorious = sim.won
	banner.add_child(emblem)
	var summary = VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_theme_constant_override("separation",12)
	banner.add_child(summary)
	summary.add_child(label("守住了最后的防线" if sim.won else "水晶被摧毁" if sim.cause == "crystal" else "房主阵亡" if Session.playing else "守卫阵亡",36,SETTINGS_BRASS if sim.won else RUST.lightened(.25)))
	paragraph(summary,"水晶仍然闪耀，这一轮防守已完成。" if sim.won else "水晶已失去光芒，再次点亮它，重新守住防线。" if sim.cause == "crystal" else "房主已阵亡，本次合作防守结束。" if Session.playing else "你倒下了。下次进入时，水晶将恢复为破损状态，需要重新修复。",19,SETTINGS_INK)
	paragraph(summary,"本局水晶  %d / %d" % [state.get("crystal_hp",0),state.get("crystal_max_hp",0)],15,SETTINGS_MUTED)
	result.add_child(HSeparator.new())
	var stats = HBoxContainer.new()
	stats.name = "ResultStatistics"
	stats.add_theme_constant_override("separation",32)
	result.add_child(stats)
	for entry in [["守住波次","%02d / 10" % sim.cleared],["击杀数量",str(sim.kills)],["防守时间",time_text(sim.elapsed)]]:
		var stat = VBoxContainer.new()
		stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(stat)
		stat.add_child(label(entry[0],15,SETTINGS_MUTED))
		stat.add_child(label(entry[1],38,SETTINGS_INK))
	var rewards = HBoxContainer.new()
	rewards.add_theme_constant_override("separation",20)
	rewards.custom_minimum_size.y = 62
	result.add_child(rewards)
	var heading = label("本局个人收益" if guest else "本局战利品",18,SETTINGS_MUTED)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rewards.add_child(heading)
	for currency in ["coins","diamonds"]:
		var row = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation",8)
		rewards.add_child(row)
		var icon = TextureRect.new()
		icon.texture = preload("res://scripts/currency_art.gd").coin() if currency == "coins" else preload("res://scripts/currency_art.gd").diamond()
		icon.custom_minimum_size = Vector2(32,32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var amount = label("+%d" % (0 if guest else sim.earned_coins if currency == "coins" else sim.earned_diamonds),28,SETTINGS_BRASS)
		amount.name = "EarnedCoins" if currency == "coins" else "EarnedDiamonds"
		amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(amount)
	var space = Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result.add_child(space)
	paragraph(result,"本局收益保存至房主，你的个人存档未改变。" if guest else "金币、钻石、武器升级、建筑所有权及天赋已永久保留。",16,SETTINGS_MUTED)
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation",24)
	result.add_child(actions)
	if not Session.playing:
		var retry = home_button(actions,"重新防守",func(): game.start_solo("defense"))
		retry.selected = true
		retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		retry.custom_minimum_size.y = 56
	var home = home_button(actions,"返回主菜单",func(): game.return_home())
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.custom_minimum_size.y = 56

static func time_text(value: float) -> String:
	return "%02d:%02d" % [floori(value/60),floori(value)%60]

func tick(dt: float) -> void:
	hit_flash = maxf(0,hit_flash-dt)
	hurt_flash = maxf(0,hurt_flash-dt)
	native_hud.sync()
	var pawn: Dictionary = game.view_pawn()
	var state = [game.running,current,pawn.get("weapon",-1),pawn.get("slot",1),pawn.get("aim",false),game.weapon.ads > .8,pawn.get("shove_cd",0.0),pawn.get("shove_gap",0.0),hit_flash,hurt_flash,pawn.get("damage_hint",0.0),pawn.get("healing_flash",0.0),game.yaw,hud.size]
	if state != overlay_state:
		overlay_state = state
		hud.queue_redraw()

func _draw_hud() -> void:
	if not game or not game.running or not game.sim or game.finished: return
	var sim = game.sim
	var p: Dictionary = game.view_pawn()
	if p.is_empty(): return
	var screen = hud.size
	var center = screen*.5
	var w: Dictionary = Data.weapons[int(p.weapon)]
	var scoped: bool = int(p.weapon) == 5 and p.get("slot",1) < 4 and game.weapon.ads > .8
	if scoped:
		var radius = minf(screen.x,screen.y)*.43
		var points = PackedVector2Array()
		# Fill the outside of the circular aperture with a triangle strip.
		for i in 128:
			var a = i*TAU/128
			var b = (i+1)*TAU/128
			var da = Vector2(cos(a),sin(a))
			var db = Vector2(cos(b),sin(b))
			hud.draw_colored_polygon(PackedVector2Array([center+da*radius,center+db*radius,center+db*3000,center+da*3000]),Color.BLACK)
		hud.draw_arc(center,radius,0,TAU,128,Color("232a24"),4,true)
		hud.draw_line(center-Vector2(radius,0),center+Vector2(radius,0),Color.BLACK,1.5)
		hud.draw_line(center-Vector2(0,radius),center+Vector2(0,radius),Color.BLACK,1.5)
		for i in range(-5,6):
			if i == 0: continue
			hud.draw_line(center+Vector2(i*28,-5),center+Vector2(i*28,5),Color.BLACK,1)
			hud.draw_line(center+Vector2(-5,i*28),center+Vector2(5,i*28),Color.BLACK,1)
	elif current.is_empty():
		var color = Color("eadfc6")
		if p.aim and w.get("kind", "gun") == "gun":
			hud.draw_circle(center,3.5,Color("242a24"))
			hud.draw_circle(center,1.8,Color("ff7253"))
		if not p.aim or w.get("kind", "gun") in ["melee","flame"]:
			for dir in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]: hud.draw_line(center+dir*5,center+dir*12,color,2)
	if current.is_empty() and p.hp > 0 and p.get("shove_cd",0.0) > 0:
		var ring = center-Vector2(0,32)
		hud.draw_arc(ring,11,0,TAU,48,Color("383e39"),3,true)
		var progress = 1.0-clampf(p.shove_cd/3.5,0,1)
		hud.draw_arc(ring,11,-PI/2,-PI/2+TAU*progress,48,Color("f0b46a"),3,true)
	if hit_flash > 0:
		for d in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]: hud.draw_line(center+d*7,center+d*13,Color.WHITE,2)
	if current.is_empty() and p.get("damage_hint",0.0) > 0:
		var direction: Vector2 = p.damage_dir.rotated(game.yaw)
		var tint = Color(1,.25,.12,minf(1,p.damage_hint))
		var side = direction.orthogonal()
		hud.draw_colored_polygon(PackedVector2Array([center+direction*82,center+direction*61+side*9,center+direction*61-side*9]),tint)
	if p.hp > 0 and p.get("healing_flash",0.0) > 0:
		var heal: float = p.healing_flash
		hud.draw_rect(Rect2(Vector2.ZERO,screen),Color(.08,.48,.19,heal*.08))
		for layer in 8:
			var inset = float(layer)*10.0
			hud.draw_rect(Rect2(Vector2.ONE*inset,screen-Vector2.ONE*inset*2),Color(.18,.6,.29,heal*.08*(1.0-layer/8.0)),false,24)
	if hurt_flash > 0:
		hud.draw_rect(Rect2(Vector2.ZERO,screen),Color(.55,.08,.04,hurt_flash*.3),false,20)

static func victory_caption_alpha(age: float) -> float:
	if age < 0 or age >= 5.8: return 0.0
	return smoothstep(0.0,.8,age) if age < .8 else 1.0-smoothstep(5.0,5.8,age)

func sync_victory_caption(age: float, enabled: bool) -> void:
	victory_caption.modulate.a = victory_caption_alpha(age)
	victory_caption.visible = enabled and age < 5.8 and current != "result"

func confirm_delete_slot(index: int) -> void:
	var column = field_shell("永久删除存档 %d？" % (index+1),"金币、钻石、所有升级和备份将永久删除，无法恢复。")
	current = "delete_save"
	var space = Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(space)
	home_button(column,"取消，保留存档",show_save_slots,true)
	home_button(column,"确认永久删除",delete_confirmed_slot.bind(index))

func delete_confirmed_slot(index: int) -> void:
	if Progress.delete_slot(index): show_save_slots()
	else:
		var column = panel("删除失败","无法访问存档文件，请检查用户目录权限。")
		button(column,"返回",show_save_slots)

func capture_binding(event: InputEvent) -> bool:
	if is_instance_valid(binding_confirmation):
		if event is InputEventKey and event.is_pressed() and event.physical_keycode == KEY_ESCAPE:
			cancel_binding_swap()
			return true
		return false
	if current != "settings" or binding_action.is_empty(): return false
	if event is InputEventMouseMotion: return false
	if not event.is_pressed() or event.is_echo(): return true
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		binding_button.text = Data.binding_label(binding_action)
		binding_action = ""
		return true
	var error = Data.controls.binding_error(binding_action,event)
	if not error.is_empty():
		binding_button.text = error+" · 重试"
		return true
	var conflict = Data.controls.conflict_for(binding_action,event)
	if not conflict.is_empty():
		show_binding_conflict(event,conflict)
		return true
	var result = Data.rebind(binding_action,event)
	if result.is_empty(): refresh_binding_settings()
	else: binding_button.text = result+" · 重试"
	return true

func refresh_binding_settings() -> void:
	var scroll_position: int = menu.find_child("FieldSettings",true,false).scroll_vertical
	show_settings()
	menu.find_child("FieldSettings",true,false).set_deferred("scroll_vertical",scroll_position)

func show_binding_conflict(event: InputEvent, conflict: String) -> void:
	pending_binding = {"action":binding_action,"event":Data.controls.encode(event),"conflict":conflict,
		"old":Data.controls.encode(InputMap.action_get_events(binding_action)[0])}
	binding_button.text = Data.binding_label(binding_action)
	binding_action = ""
	binding_confirmation = Control.new()
	binding_confirmation.name = "BindingConflict"
	binding_confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	binding_confirmation.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.add_child(binding_confirmation)
	var shade = ColorRect.new()
	shade.color = Color(0,0,0,.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	binding_confirmation.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	binding_confirmation.add_child(center)
	var card = PanelContainer.new()
	card.theme = green_settings_theme()
	card.custom_minimum_size.x = minf(600,root.size.x-48)
	card.add_theme_stylebox_override("panel",settings_box(SETTINGS_PAPER,SETTINGS_BRASS,24))
	center.add_child(card)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",20)
	card.add_child(column)
	column.add_child(label("按键冲突",28,SETTINGS_INK))
	var question = paragraph(column,"检测到按键冲突：%s %s，是否确认互换按键？" % [Data.controls.action_name(conflict),Data.binding_label(conflict)],21,SETTINGS_INK)
	question.name = "ConflictQuestion"
	question.custom_minimum_size.x = minf(552,root.size.x-96)
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation",16)
	column.add_child(actions)
	var cancel = home_button(actions,"取消",cancel_binding_swap)
	cancel.name = "CancelSwap"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var confirm = home_button(actions,"确认互换",confirm_binding_swap,true)
	confirm.name = "ConfirmSwap"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in [cancel,confirm]:
		var other: Button = confirm if item == cancel else cancel
		item.focus_next = item.get_path_to(other)
		item.focus_previous = item.get_path_to(other)
		item.focus_neighbor_left = item.get_path_to(other)
		item.focus_neighbor_right = item.get_path_to(other)
		item.focus_neighbor_top = item.get_path_to(other)
		item.focus_neighbor_bottom = item.get_path_to(other)
	cancel.grab_focus()

func cancel_binding_swap(restore_focus := true) -> void:
	if is_instance_valid(binding_confirmation):
		binding_confirmation.hide()
		binding_confirmation.queue_free()
	binding_confirmation = null
	pending_binding = {}
	if restore_focus and is_instance_valid(binding_button): binding_button.grab_focus()

func confirm_binding_swap() -> void:
	if current != "settings" or pending_binding.is_empty(): return
	var request = pending_binding.duplicate()
	var event = Data.controls.decode(request.event)
	# A stale dialog cannot approve a different mapping changed in the meantime.
	var unchanged: bool = Data.controls.encode(InputMap.action_get_events(request.action)[0]) == request.old and Data.controls.conflict_for(request.action,event) == request.conflict
	cancel_binding_swap(false)
	if not unchanged:
		refresh_binding_settings()
		return
	var result = Data.rebind(request.action,event,true)
	if result.is_empty(): refresh_binding_settings()
	elif is_instance_valid(binding_button): binding_button.text = result+" · 重试"
