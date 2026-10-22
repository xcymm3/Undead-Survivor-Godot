extends RefCounted
# Hallmark · existing game palette / room directory · P5 H5 E4 S5 R5 V4
var owner_ref: WeakRef
var ui:
	get: return owner_ref.get_ref()
var stage: Control
var search: LineEdit
var body: VBoxContainer
var status: Label
var tally: Label
var mode_buttons: Array = []
var actions: Array = []
var dialog: Control
var preview = false
var was_active = false

func _init(owner_ui) -> void:
	owner_ref = weakref(owner_ui)

func show_page(qa_preview: bool) -> void:
	preview = qa_preview
	ui.clear_menu()
	ui.current = "multiplayer"
	ui.menu = Control.new()
	ui.menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.root.add_child(ui.menu)
	ui.menu.add_child(preload("res://scripts/menu_backdrop.gd").new())
	stage = Control.new()
	stage.name = "RoomBrowserStage"
	stage.size = Vector2(1440,900)
	ui.menu.add_child(stage)
	var fit = func():
		var factor = minf(ui.root.size.x/1440.0,ui.root.size.y/900.0)
		stage.scale = Vector2.ONE*factor
		stage.position = (ui.root.size-stage.size*factor)*.5
	ui.menu.resized.connect(fit)
	fit.call()
	var heading = put_label("多人合作",Vector2(72,54),Vector2(1000,64),46,ui.SETTINGS_INK)
	var display_font = FontVariation.new()
	display_font.base_font = ui.font
	display_font.variation_embolden = 1.1
	heading.add_theme_font_override("font",display_font)
	heading.add_theme_color_override("font_outline_color",ui.PAPER)
	heading.add_theme_constant_override("outline_size",4)
	put_label("寻找同伴，守住最后的防线",Vector2(72,119),Vector2(800,28),18,ui.SETTINGS_MUTED)
	search = input("按房间名称或地址搜索",ui.room_query)
	search.name = "RoomSearch"
	search.position = Vector2(72,163)
	search.size = Vector2(800,56)
	stage.add_child(search)
	search.text_changed.connect(func(value): ui.room_query = value; refresh_content())
	for i in 2:
		var mode = "steam" if i == 0 else "lan"
		var tab = ui.home_button(stage,"Steam 房间" if i == 0 else "局域网房间",set_mode.bind(mode))
		tab.name = "SteamMode" if i == 0 else "LanMode"
		tab.position = Vector2(896+i*240,163)
		tab.size = Vector2(232,56)
		mode_buttons.append(tab)
	var surface = PanelContainer.new()
	surface.name = "RoomDirectory"
	surface.position = Vector2(72,245)
	surface.size = Vector2(1296,452)
	surface.add_theme_stylebox_override("panel",ui.settings_box(ui.PAPER,ui.SETTINGS_MUTED.darkened(.5),22))
	stage.add_child(surface)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation",14)
	surface.add_child(body)
	tally = put_label("",Vector2(72,710),Vector2(1296,25),17,ui.SETTINGS_MUTED)
	status = put_label("",Vector2(72,741),Vector2(1296,28),18,ui.SETTINGS_BRASS)
	var footer = HBoxContainer.new()
	footer.name = "RoomActions"
	footer.position = Vector2(72,790)
	footer.size = Vector2(1296,66)
	footer.add_theme_constant_override("separation",18)
	stage.add_child(footer)
	for i in 4:
		var action = ui.home_button(footer,"",act.bind(i),i == 0)
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.custom_minimum_size = Vector2(0,66)
		action.add_theme_font_size_override("font_size",23)
		actions.append(action)
	sync()

func put_label(text: String, position: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var item = ui.label(text,font_size,color)
	item.position = position
	item.size = dimensions
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stage.add_child(item)
	return item

func input(placeholder: String, text: String) -> LineEdit:
	var item = LineEdit.new()
	item.placeholder_text = placeholder
	item.text = text
	item.max_length = 160
	item.custom_minimum_size.y = 52
	item.add_theme_font_size_override("font_size",20)
	item.add_theme_color_override("font_color",ui.SETTINGS_INK)
	item.add_theme_color_override("font_placeholder_color",ui.SETTINGS_MUTED)
	item.add_theme_stylebox_override("normal",ui.settings_box(ui.PAPER.darkened(.18),ui.SETTINGS_MUTED.darkened(.5),12))
	item.add_theme_stylebox_override("focus",ui.settings_box(ui.PAPER,ui.SETTINGS_BRASS,12))
	return item

func set_mode(mode: String) -> void:
	if Session.active: return
	Session.stop_room_search()
	Session.rooms.clear()
	ui.room_mode = mode
	Session.status = "点击刷新寻找 Steam 房间" if mode == "steam" else "点击刷新寻找同一局域网的房间"
	sync()
	if not preview: refresh_rooms()

func refresh_rooms() -> void:
	if Session.active or preview: return
	if OS.has_feature("web"):
		Session.status = "联机请使用 Windows 版"
		sync()
		return
	if ui.room_mode == "steam": Session.search_steam()
	else: Session.search_lan()

func sync() -> void:
	if not is_instance_valid(stage) or not stage.is_inside_tree(): return
	if Session.active: ui.room_mode = Session.transport
	search.editable = not Session.active
	for i in 2:
		mode_buttons[i].primary = (ui.room_mode == "steam") == (i == 0)
		mode_buttons[i].highlighted = mode_buttons[i].primary
		mode_buttons[i].disabled = Session.active
		if mode_buttons[i].face: mode_buttons[i].face.queue_redraw()
	if Session.active and not was_active: close_dialog()
	was_active = Session.active
	status.text = Session.status
	var labels = ["创建房间","直接连接","刷新","退出"]
	if Session.active:
		labels = ["开始合作" if Session.is_host() else "等待房主","邀请好友" if Session.transport == "steam" else "复制地址","离开房间","退出"]
	for i in 4:
		actions[i].text = labels[i]
		actions[i].disabled = false
	if Session.active:
		actions[0].disabled = not Session.is_host() or Session.members.size() < 2 or Session.loading
		actions[1].disabled = Session.loading
	else:
		actions[2].disabled = Session.searching
		if OS.has_feature("web") and not preview:
			for i in 3: actions[i].disabled = true
	for item in actions:
		if item.face: item.face.queue_redraw()
	refresh_content()

func clear_body() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

func refresh_content() -> void:
	if not is_instance_valid(body): return
	clear_body()
	if Session.active:
		render_lobby()
		return
	var header = HBoxContainer.new()
	body.add_child(header)
	column(header,"房间 / 地址",526,16,ui.SETTINGS_MUTED)
	column(header,"战场",270,16,ui.SETTINGS_MUTED)
	column(header,"人数",104,16,ui.SETTINGS_MUTED)
	column(header,"状态",170,16,ui.SETTINGS_MUTED)
	body.add_child(HSeparator.new())
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list = VBoxContainer.new()
	list.name = "RoomRows"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",10)
	scroll.add_child(list)
	var count = 0
	for room in Session.rooms:
		if room.get("transport",ui.room_mode) != ui.room_mode: continue
		var query = ui.room_query.strip_edges().to_lower()
		if not query.is_empty() and not (str(room.name)+" "+str(room.id)).to_lower().contains(query): continue
		room_row(list,room)
		count += 1
	if count == 0:
		var empty = VBoxContainer.new()
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		empty.add_theme_constant_override("separation",14)
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list.add_child(empty)
		var title = ui.label("正在寻找同伴…" if Session.searching else "没有找到匹配的房间",28,ui.SETTINGS_INK)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(title)
		var hint = ui.label("可以刷新列表，或创建房间邀请朋友加入",18,ui.SETTINGS_MUTED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(hint)
	tally.text = "%s · 显示 %d 个房间" % ["STEAM 大厅" if ui.room_mode == "steam" else "局域网",count]

func column(parent: Node, text: String, width: float, font_size: int, color: Color) -> Label:
	var item = ui.label(text,font_size,color)
	item.custom_minimum_size.x = width
	item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

func room_row(parent: Node, room: Dictionary) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.y = 88
	panel.add_theme_stylebox_override("panel",ui.settings_box(ui.PAPER.lightened(.035),ui.SETTINGS_MUTED.darkened(.65),12))
	parent.add_child(panel)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	panel.add_child(row)
	var title = VBoxContainer.new()
	title.custom_minimum_size.x = 502
	row.add_child(title)
	column(title,str(room.name).replace("\n"," ").replace("\r"," ").left(64),0,23,ui.SETTINGS_INK)
	column(title,str(room.id),0,15,ui.SETTINGS_MUTED)
	column(row,Data.Maps.definition(str(room.get("map_id","graypine_defense"))).title,270,20,ui.SETTINGS_INK)
	column(row,"%d / 4" % int(room.count),104,20,ui.SETTINGS_INK)
	column(row,"已满员" if room.count >= 4 else "等待加入",150,18,ui.SETTINGS_MUTED)
	var join = ui.home_button(row,"加入",join_room.bind(room))
	join.custom_minimum_size = Vector2(120,54)
	join.disabled = room.count >= 4

func render_lobby() -> void:
	body.add_child(ui.label("正在集合  /  "+("房主" if Session.is_host() else "队员"),19,ui.SETTINGS_BRASS))
	body.add_child(ui.label("房间  "+Session.room_code,28,ui.SETTINGS_INK))
	body.add_child(ui.label("保卫水晶 · 普通难度 · 最多4人",18,ui.SETTINGS_MUTED))
	body.add_child(HSeparator.new())
	var index = 0
	for id in Session.members:
		index += 1
		var row = HBoxContainer.new()
		row.custom_minimum_size.y = 54
		body.add_child(row)
		column(row,"%02d" % index,70,22,ui.SETTINGS_BRASS)
		column(row,str(Session.members[id]).replace("\n"," ").replace("\r"," ").left(32),730,23,ui.SETTINGS_INK)
		column(row,"房主" if id == Session.host_id else "已加入",170,18,ui.SETTINGS_MUTED)
	for i in range(index,4):
		var row = HBoxContainer.new()
		row.custom_minimum_size.y = 54
		body.add_child(row)
		column(row,"%02d" % (i+1),70,22,ui.SETTINGS_MUTED)
		column(row,"等待队员加入…",730,20,ui.SETTINGS_MUTED)
	tally.text = "房主成长共享 · 客机存档不变 · 客机阵亡后本局不可复活"

func act(index: int) -> void:
	if index == 3:
		Session.leave()
		ui.show_home()
		return
	if Session.active:
		if index == 0:
			if not preview: Session.begin_match()
		elif index == 1:
			if Session.transport == "steam":
				if not preview: Session.invite_friends()
			else: DisplayServer.clipboard_set(Session.room_code)
		elif index == 2:
			Session.leave()
			Session.status = "已离开房间"
			sync()
		return
	if index == 0:
		if preview: return
		if ui.room_mode == "steam": Session.host_steam()
		else: Session.host_lan(ui.player_name)
	elif index == 1: open_direct()
	elif index == 2: refresh_rooms()

func join_room(room: Dictionary) -> void:
	if preview: return
	if ui.room_mode == "steam": Session.join_steam(str(room.id))
	else: Session.join_lan(str(room.id),ui.player_name)

func close_dialog() -> void:
	if is_instance_valid(dialog):
		dialog.get_parent().remove_child(dialog)
		dialog.queue_free()
	dialog = null

func open_direct() -> void:
	close_dialog()
	dialog = Control.new()
	dialog.name = "DirectConnectOverlay"
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(dialog)
	var shade = ColorRect.new()
	shade.color = ui.PAPER.darkened(.8)
	shade.color.a = .86
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(shade)
	var frame = PanelContainer.new()
	frame.position = Vector2(360,210)
	frame.size = Vector2(720,460)
	frame.add_theme_stylebox_override("panel",ui.settings_box(ui.PAPER,ui.SETTINGS_BRASS,28))
	dialog.add_child(frame)
	var form = VBoxContainer.new()
	form.add_theme_constant_override("separation",16)
	frame.add_child(form)
	form.add_child(ui.label("直接连接",32,ui.SETTINGS_INK))
	form.add_child(ui.label("输入 Steam 房间号" if ui.room_mode == "steam" else "输入房主 IP 地址与端口",18,ui.SETTINGS_MUTED))
	var name_field = input("你的昵称",ui.player_name)
	name_field.name = "ConnectName"
	form.add_child(name_field)
	var target = input("Steam 房间号" if ui.room_mode == "steam" else "例如 192.168.1.108:27777",ui.steam_code if ui.room_mode == "steam" else ui.address)
	target.name = "ConnectTarget"
	form.add_child(target)
	var error = ui.label("",17,ui.RUST.lightened(.25))
	error.name = "ConnectError"
	form.add_child(error)
	var buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation",18)
	form.add_child(buttons)
	var submit = func():
		var value = target.text.strip_edges()
		if not valid_target(value,ui.room_mode):
			error.text = "请输入有效的数字房间号" if ui.room_mode == "steam" else "请输入有效的 IP 地址，端口范围为1～65535"
			return
		ui.player_name = name_field.text.strip_edges().left(32) if not name_field.text.strip_edges().is_empty() else "幸存者"
		if preview: return
		if ui.room_mode == "steam":
			ui.steam_code = value
			Session.join_steam(value)
		else:
			ui.address = value
			Session.join_lan(value,ui.player_name)
		if is_instance_valid(error): error.text = Session.status
	var connect_button = ui.home_button(buttons,"连接房间",submit,true)
	connect_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connect_button.custom_minimum_size.y = 60
	var cancel = ui.home_button(buttons,"取消",close_dialog)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.custom_minimum_size.y = 60
	target.text_submitted.connect(func(_value): submit.call())
	target.grab_focus()

static func valid_target(value: String, mode: String) -> bool:
	if mode == "steam": return value.is_valid_int() and value.length() <= 20 and value.to_int() > 0
	var parts = value.split(":")
	if parts.size() > 2 or not parts[0].is_valid_ip_address(): return false
	return parts.size() == 1 or parts[1].is_valid_int() and parts[1].to_int() >= 1 and parts[1].to_int() <= 65535
