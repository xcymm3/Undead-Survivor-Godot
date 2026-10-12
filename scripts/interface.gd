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
var hit_flash = 0.0
var hurt_flash = 0.0
var message = ""
var portraits: Dictionary = {}
var native_hud
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
	Session.changed.connect(func():
		if current == "multiplayer": show_multiplayer())

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

func settings_option(option: OptionButton) -> void:
	option.custom_minimum_size.y = 42
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var popup = option.get_popup()
	popup.add_theme_stylebox_override("panel",settings_box(Color(.14,.10,.07,.97),SETTINGS_BRASS,8))
	popup.add_theme_stylebox_override("hover",settings_box(Color(.42,.28,.14,.96),Color.TRANSPARENT,6))
	popup.add_theme_color_override("font_color",SETTINGS_INK)
	popup.add_theme_color_override("font_hover_color",Color("fff0cf"))
	popup.add_theme_font_override("font",font)

func settings_toggle(parent: VBoxContainer, caption: String, initial: bool, callback: Callable) -> Button:
	var toggle = Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = initial
	toggle.text = "%s    %s" % [caption,"◆ 开启" if initial else "◇ 关闭"]
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.custom_minimum_size.y = 44
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(toggle)
	toggle.toggled.connect(func(value):
		toggle.text = "%s    %s" % [caption,"◆ 开启" if value else "◇ 关闭"]
		callback.call(value))
	return toggle

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
	var setup = HBoxContainer.new()
	setup.name = "DifficultySelection"
	setup.position = Vector2(0,642)
	setup.resized.connect(func(): setup.position.x = (stage.size.x-setup.size.x)*.5)
	setup.add_theme_constant_override("separation",12)
	stage.add_child(setup)
	for entry in [["easy","简单"],["normal","普通"],["hard","困难"]]:
		var option = home_button(setup,("◆ " if Data.settings.defense_difficulty == entry[0] else "")+entry[1],game.select_defense_difficulty.bind(entry[0]))
		option.custom_minimum_size = Vector2(135,44)
	var money = CheckBox.new()
	money.name = "InfiniteCoins"
	money.text = "无限金币 / 钻石 · 测试"
	money.button_pressed = Data.test_money
	money.toggled.connect(func(value): Data.test_money = value)
	setup.add_child(money)
	var actions = HBoxContainer.new()
	actions.name = "HomeActions"
	actions.position = Vector2(0,723)
	actions.resized.connect(func(): actions.position.x = (stage.size.x-actions.size.x)*.5)
	actions.add_theme_constant_override("separation",14)
	stage.add_child(actions)
	for item in [["开始防守",func(): game.start_solo("defense")],["设置",show_settings],["武器与操作",show_guide],["退出游戏",func(): game.quit_game()]]:
		var option = home_button(actions,item[0],item[1],item[0] == "开始防守")
		option.custom_minimum_size = Vector2(214,76)
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

func show_save_slots() -> void:
	var column = panel("选择存档","三个独立进度 · 选择后从第一波重新开始对局",720)
	current = "saves"
	for index in 3:
		var profile = Progress.slots[index]
		button(column,"存档 %d%s · 金币 %d · 钻石 %d · 最佳波次 %d" % [index+1,"（当前）" if index == Progress.active_slot else "",profile.data.coins,profile.data.diamonds,profile.data.best_wave],game.select_save_slot.bind(index),index == Progress.active_slot)
	button(column,"返回",show_home)

func show_pause() -> void:
	var column = panel("休息片刻", "合作对局仍在进行" if Session.playing else "行动计时已暂停",560)
	current = "pause"
	button(column,"继续游戏",func(): game.resume_game(),true)
	if not Session.playing: button(column,"重新开始",func(): game.start_solo(game.sim.mode))
	button(column,"设置",show_settings)
	button(column,"武器与操作",show_guide)
	button(column,"返回主菜单",func(): game.return_home())

func back() -> void:
	if game.running: show_pause()
	else: show_home()

func show_settings() -> void:
	var shell = panel("战场设置", "声音、操控与画质会保存到本机",700,true)
	current = "settings"
	var tabs = TabContainer.new()
	tabs.custom_minimum_size.y = 400
	tabs.add_theme_stylebox_override("panel",settings_box(Color(.05,.08,.065,.4),SETTINGS_BRASS.darkened(.5),14))
	tabs.add_theme_stylebox_override("tab_selected",settings_box(Color("314335"),SETTINGS_BRASS,10))
	tabs.add_theme_stylebox_override("tab_unselected",settings_box(Color("121f1a"),SETTINGS_BRASS.darkened(.5),10))
	shell.add_child(tabs)
	var column = settings_page(tabs,"操控与声音")
	settings_heading(column,"操控")
	column.add_child(label("鼠标灵敏度",18,SETTINGS_INK))
	var row = HBoxContainer.new()
	column.add_child(row)
	var slider = HSlider.new()
	slider.min_value = 10
	slider.max_value = 200
	slider.step = 1
	slider.value = Data.settings.sensitivity/.0022*100
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value = SpinBox.new()
	value.min_value = 10
	value.max_value = 200
	value.step = 1
	value.suffix = "%"
	value.value = slider.value
	value.add_theme_color_override("up_icon_modulate",SETTINGS_BRASS)
	value.add_theme_color_override("down_icon_modulate",SETTINGS_BRASS)
	value.get_line_edit().add_theme_color_override("font_color",SETTINGS_INK)
	row.add_child(value)
	slider.value_changed.connect(func(v):
		value.set_value_no_signal(v)
		Data.settings.sensitivity = v/100*.0022
		Data.save())
	value.value_changed.connect(func(v): slider.value = v)
	paragraph(column,"按中键切换开镜时，转向灵敏度会随真实视野同步降低。",15,SETTINGS_MUTED)
	settings_heading(column,"声音")
	column.add_child(label("主音量",18,SETTINGS_INK))
	var volume = HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.value = Data.settings.volume*100
	column.add_child(volume)
	volume.value_changed.connect(func(v):
		Data.settings.volume = v/100
		Data.apply_settings()
		Data.save())
	settings_toggle(column,"静音（M）",Data.settings.muted,func(v):
		Data.settings.muted = v
		Data.apply_settings()
		Data.save())
	column = settings_page(tabs,"画面")
	settings_heading(column,"画质")
	var quality = OptionButton.new()
	for text in ["极限流畅","流畅","均衡","精细","极致画质","自定义"]: quality.add_item(text)
	quality.selected = int(Data.settings.quality)
	settings_option(quality)
	column.add_child(quality)
	quality.item_selected.connect(func(v):
		Data.set_preset(v)
		show_settings())
	var advanced = GridContainer.new()
	advanced.columns = 2
	advanced.add_theme_constant_override("h_separation",24)
	advanced.add_theme_constant_override("v_separation",8)
	column.add_child(advanced)
	for spec in [
		["渲染比例","resolution",[.5,.67,.75,1.0],["50%","67%","75%","100%"]],
		["抗锯齿","aa",[0,1,2,3],["关闭","MSAA 2×","MSAA 4×","MSAA 8×"]],
		["阴影","shadows",[0,1,2,3,4],["关闭","低","中","高","极高"]],
		["特效","effects",[0,1,2],["低","中","高"]],
		["视距","distance",[0,1,2],["近","中","远"]],
		["帧率上限","frame_limit",[30,60,120,0],["30 FPS","60 FPS","120 FPS","不限"]]]:
		advanced.add_child(label(spec[0],17,SETTINGS_INK))
		var option = OptionButton.new()
		for text in spec[3]: option.add_item(text)
		option.selected = maxi(0,spec[2].find(Data.settings[spec[1]]))
		settings_option(option)
		advanced.add_child(option)
		option.item_selected.connect(func(index):
			Data.settings[spec[1]] = spec[2][index]
			Data.settings.quality = 5
			quality.select(5)
			Data.apply_settings()
			Data.save())
	settings_toggle(column,"像素化显示",Data.settings.pixelated,func(value):
		Data.settings.pixelated = value
		Data.settings.quality = 5
		quality.select(5)
		Data.apply_settings()
		Data.save())
	settings_toggle(column,"全屏（F11）",Data.settings.fullscreen,func(v):
		Data.settings.fullscreen = v
		Data.apply_settings()
		Data.save())
	paragraph(column,"渲染器：Godot Compatibility\n渲染设备：%s\n版本：%s" % [RenderingServer.get_video_adapter_name(),Engine.get_version_info().string],15,SETTINGS_MUTED)
	tabs.current_tab = settings_tab
	tabs.tab_changed.connect(func(index): settings_tab = index)
	button(shell,"返回",back)

func settings_page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",6)
	scroll.add_child(column)
	return column

func show_guide() -> void:
	var column = panel("武器与操作", "水晶防线 · 十波连续进攻",1000)
	current = "guide"
	paragraph(column,"战前靠近并瞄准展台或施工点，长按 E 升级或建造。长按警报器启动进攻后，展台关闭；每波投放完等待10秒再自动接下一波。每清完所属波次的敌人获得 1 颗钻石、两把枪各 2 个备弹夹。第十波击败舞王后立即清除全部残敌并通关。",17)
	paragraph(column,"WASD 移动 / Shift 疾跑 / 鼠标瞄准 / 左键攻击 / 右键推击 / 中键开镜\n空格跳跃 / Ctrl 蹲下 / R 换弹 / 1—4 或滚轮切换装备 / Esc 暂停\n1 步枪 / 2 左轮 / 3 消防斧 / 4 手雷 / E 长按交互\n疾跑速度 ×1.6，无耐力限制；射击、开镜、换弹和蹲下取消疾跑。\n连续推击第 3 次后冷却 3.5 秒。每次清波两把枪各获得 2 个备弹夹，备弹可超上限，使用消防斧节省弹药。",17)
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
	paragraph(column,"生命、炮塔、栅栏和地雷状态跨波保留；手雷每15秒补充一颗至持有上限。没有强壮天赋时不会缓慢回血；学习后连续 5 秒未受伤开始恢复，期间可以攻击。商店也可被僵尸进入。首页可切换三个独立存档，并勾选测试金币。",17)
	button(column,"返回",back,true)

func show_multiplayer() -> void:
	show_home()
	return

func show_legacy_multiplayer() -> void:
	var column = panel("合作守卫", "水晶防线 · 房主模拟战斗 · 全员按 T 开始每波",850)
	current = "multiplayer"
	if OS.has_feature("web"):
		paragraph(column,"浏览器验收版仅支持单人模式。Steam 与局域网多人模式请使用 Windows 版。")
		button(column,"返回",show_home)
		return
	paragraph(column,Session.status,17,RUST)
	if Session.active:
		column.add_child(label("战场："+Data.Maps.definition(Session.map_id).title,22))
		if Session.map_id == "graypine_defense":
			var difficulty = preload("res://scripts/defense_population.gd")
			column.add_child(label("难度：%s（积分预算 × %.1f）" % [difficulty.difficulty_label(Session.defense_difficulty),difficulty.difficulty_multiplier(Session.defense_difficulty)],19,RUST))
		column.add_child(label("房间  "+Session.room_code,22))
		button(column,"复制房间地址 / 房间号",func(): DisplayServer.clipboard_set(Session.room_code))
		for id in Session.members:
			column.add_child(label("●  "+str(Session.members[id])+("   / 房主" if id == Session.host_id else ""),22))
		if Session.is_host():
			var start = button(column,"开始合作",func(): Session.begin_match(),true)
			start.disabled = Session.members.size() < 2 or Session.loading
		else: paragraph(column,"等待房主开始对局…",18)
		button(column,"离开房间",func(): Session.leave(); show_multiplayer())
	else:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation",14)
		column.add_child(row)
		button(row,"创建 Steam 房间",func(): Session.host_steam(),true)
		button(row,"搜索 Steam 房间",func(): Session.search_steam())
		var code = LineEdit.new()
		code.placeholder_text = "输入 Steam 房间号"
		code.text = steam_code
		code.text_changed.connect(func(value): steam_code = value)
		column.add_child(code)
		button(column,"按房间号加入",func(): Session.join_steam(steam_code))
		for room in Session.rooms:
			button(column,"%s  ·  %d / 4 人" % [room.name,room.count],func(): Session.join_steam(room.id))
		column.add_child(HSeparator.new())
		column.add_child(label("局域网直连",22))
		var name_input = LineEdit.new()
		name_input.placeholder_text = "玩家昵称"
		name_input.text = player_name
		name_input.text_changed.connect(func(value): player_name = value)
		column.add_child(name_input)
		var ip = LineEdit.new()
		ip.placeholder_text = "房主 IP:27777"
		ip.text = address
		ip.text_changed.connect(func(value): address = value)
		column.add_child(ip)
		var lan = HBoxContainer.new()
		lan.add_theme_constant_override("separation",14)
		column.add_child(lan)
		button(lan,"创建局域网房间",func(): Session.host_lan(player_name))
		button(lan,"加入局域网",func(): Session.join_lan(address,player_name))
	button(column,"返回",func(): Session.leave(); show_home())

func shop_description(profile, id: String) -> String:
	if id in profile.WEAPONS:
		var index: int = {"rifle":0,"revolver":3,"axe":6}[id]
		return "伤害 %.1f → %.1f · 每次 +10%%，下次价格翻倍" % [Data.weapons[index].damage*profile.weapon_multiplier(id),Data.weapons[index].damage*profile.weapon_multiplier(id)*1.1]
	if id == "grenade": return "持有上限 %d / 5 · 每次 +1 · 每15秒补充1颗" % profile.grenade_capacity()
	if id in profile.MINES: return "永久购买 · 无升级 · 每波恢复 · 僵尸触发后 1.5 秒爆炸"
	if id in profile.GATES: return "耐久 %d · 就地升级 +10%% · 价格与枪械相同并逐次翻倍 · 战斗中不复活" % roundi(1000*profile.building_multiplier(id))
	if id in profile.BUILDINGS: return "每发伤害 %.1f · 就地升级伤害 +10%% · 价格与枪械相同并逐次翻倍 · 战斗中不复活" % (60*profile.building_multiplier(id))
	match id:
		"strong": return "最大生命 %d · 脱战 5 秒后每秒回复 %d 生命 · 每级 +10 生命、+1 回复" % [profile.max_health(),profile.level(id)]
		"precise": return "爆头倍率 +%d%% · 每级 +10%%" % (profile.level(id)*10)
		"swift": return "移速 +%d%% · 每级 +5%%" % (profile.level(id)*5)
		"supply": return "开局备弹 +%d%% · 每级 +10%% · 清波固定补 2 备弹夹" % (profile.level(id)*10)
	return ""

func show_result() -> void:
	var sim = game.sim
	if sim.mode == "defense":
		var state: Dictionary = sim.defense_state()
		var result = panel("游戏通关" if sim.won else "水晶防线失守","十波尸潮已清除 · 舞王已击败" if sim.won else "保卫水晶",640)
		current = "result"
		result.add_child(label("守住 %d 波 · %d 击杀 · %s" % [sim.cleared,sim.kills,time_text(sim.elapsed)],32))
		paragraph(result,("成功守住水晶。" if sim.won else "水晶被摧毁。" if sim.cause == "crystal" else "守卫者已失去行动能力。")+" 水晶剩余 %d / %d。" % [state.get("crystal_hp",0),state.get("crystal_max_hp",0)])
		paragraph(result,"本局获得   金币 +%d   ◆ 钻石 +%d" % [sim.earned_coins,sim.earned_diamonds],24,SETTINGS_BRASS)
		paragraph(result,"金币、钻石、武器升级、建筑所有权及天赋已永久保留。",17,SETTINGS_MUTED)
		if not Session.playing: button(result,"重新防守",func(): game.start_solo("defense"),true)
		button(result,"返回主菜单",func(): game.return_home())
		return
static func time_text(value: float) -> String:
	return "%02d:%02d" % [floori(value/60),floori(value)%60]

func tick(dt: float) -> void:
	sync_portraits()
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
		hud.draw_rect(Rect2(Vector2.ZERO,screen),Color(.08,.48,.19,heal*.035))
		for layer in 8:
			var inset = float(layer)*10.0
			hud.draw_rect(Rect2(Vector2.ONE*inset,screen-Vector2.ONE*inset*2),Color(.18,.6,.29,heal*.035*(1.0-layer/8.0)),false,24)
	if hurt_flash > 0:
		hud.draw_rect(Rect2(Vector2.ZERO,screen),Color(.55,.08,.04,hurt_flash*.3),false,20)

func sync_portraits() -> void:
	var needed: Dictionary = {}
	if game and game.running and game.sim:
		for pawn in game.sim.pawns.values():
			var key = str(pawn.appearance)
			needed[key] = true
			if not portraits.has(key): portraits[key] = create_portrait(pawn)
	for key in portraits.keys():
		if not needed.has(key):
			portraits[key].queue_free()
			portraits.erase(key)

func create_portrait(pawn: Dictionary) -> SubViewport:
	var viewport = SubViewport.new()
	viewport.size = Vector2i(168,216)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	# Reuse the in-world character construction so model and outfit colors agree.
	var partner = preload("res://scripts/partner_view.gd").new()
	viewport.add_child(partner)
	partner.setup(pawn)
	var avatar: Node3D = partner.avatar
	avatar.reparent(viewport)
	avatar.position = Vector3.ZERO
	avatar.rotation = Vector3(0,PI,0)
	if partner.animation:
		for clip in partner.animation.get_animation_list():
			if clip.to_lower().ends_with("idle"):
				partner.animation.play(clip)
				partner.animation.seek(0,true)
				partner.animation.pause()
				break
	partner.free()
	var bounds = AABB()
	var first = true
	for mesh in avatar.find_children("*","MeshInstance3D",true,false):
		var mesh_bounds: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = mesh_bounds if first else bounds.merge(mesh_bounds)
		first = false
	var camera = Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(.5,bounds.size.y*.53)
	var target = Vector3(bounds.get_center().x,bounds.end.y-bounds.size.y*.24,bounds.get_center().z)
	camera.position = target+Vector3(0,0,4)
	camera.look_at(target)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25,-25,0)
	light.light_energy = 1.2
	viewport.add_child(light)
	var world = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = .65
	viewport.add_child(world)
	return viewport
