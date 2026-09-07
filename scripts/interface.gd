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
const INK = Color("303a33")
const PAPER = Color("f0ece2")
const RUST = Color("ae573b")

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
	root.theme.set_stylebox("normal","Button",box(Color("e5e0d5"),10))
	root.theme.set_stylebox("hover","Button",box(Color("d9d3c4"),10))
	root.theme.set_stylebox("pressed","Button",box(Color("cbc0a9"),10))
	root.theme.set_stylebox("focus","Button",box(Color("e2d1b6"),10))
	add_child(root)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(hud)
	hud.draw.connect(_draw_hud)
	Session.changed.connect(func():
		if current == "multiplayer": show_multiplayer())

func box(color: Color, padding := 16) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style

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
	current = ""

func panel(title: String, subtitle: String, width := 700) -> VBoxContainer:
	clear_menu()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var shade = ColorRect.new()
	shade.color = Color(0.06,.1,.08,.68)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel",box(PAPER,28))
	card.custom_minimum_size.x = width
	center.add_child(card)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width-56,700)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",14)
	scroll.add_child(column)
	column.add_child(label(title,34))
	paragraph(column,subtitle,16,Color("797b6f"))
	return column

func show_home() -> void:
	clear_menu()
	current = "home"
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var gradient = Gradient.new()
	gradient.set_color(0,Color(.04,.08,.06,.22))
	gradient.set_color(1,Color(.02,.04,.035,.94))
	gradient.add_point(.42,Color(.04,.07,.05,.38))
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0,.5)
	texture.fill_to = Vector2(1,.5)
	var shade = TextureRect.new()
	shade.texture = texture
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var title_block = VBoxContainer.new()
	title_block.position = Vector2(86,560)
	title_block.add_theme_constant_override("separation",10)
	menu.add_child(title_block)
	title_block.add_child(label("灰松哨站",19,Color("bfccba")))
	var title = label("UNDEAD\nSURVIVOR",85,Color("f2ecdc"))
	title.add_theme_constant_override("line_spacing",-12)
	title_block.add_child(title)
	title_block.add_child(label("守住每一波，活到下一刻。",19,Color("d8dfce")))
	var actions = VBoxContainer.new()
	actions.position = Vector2(990,284)
	actions.custom_minimum_size.x = 340
	actions.add_theme_constant_override("separation",14)
	menu.add_child(actions)
	for item in [["练习模式",func(): game.start_solo("practice")],["单人模式",func(): game.start_solo("survival")],["多人模式",show_multiplayer]]:
		var option = button(actions,item[0],item[1])
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.custom_minimum_size.y = 76
		option.add_theme_font_size_override("font_size",36)
		option.add_theme_color_override("font_color",Color("f5efdf"))
		option.add_theme_color_override("font_hover_color",Color.WHITE)
		option.add_theme_color_override("font_focus_color",Color.WHITE)
		option.add_theme_stylebox_override("normal",box(Color.TRANSPARENT,20))
		option.add_theme_stylebox_override("hover",box(Color(.49,.1,.08,.83),20))
		option.add_theme_stylebox_override("focus",box(Color(.49,.1,.08,.83),20))
		option.add_theme_stylebox_override("pressed",box(Color(.38,.08,.06,.9),20))
	actions.add_child(HSeparator.new())
	for item in [["波次排行榜",show_scores],["武器与操作",show_guide],["退出游戏",func(): game.quit_game()]]:
		var option = button(actions,item[0],item[1])
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.add_theme_stylebox_override("normal",box(Color.TRANSPARENT,20))
		option.add_theme_color_override("font_color",Color("c3ccbb"))
	var toolbar = HBoxContainer.new()
	toolbar.position = Vector2(1040,32)
	toolbar.add_theme_constant_override("separation",12)
	menu.add_child(toolbar)
	for item in [["声音",func():
		Data.settings.muted = not Data.settings.muted
		Data.apply_settings()
		Data.save()],["全屏",func():
		Data.settings.fullscreen = not Data.settings.fullscreen
		Data.apply_settings()
		Data.save()],["设置",show_settings]]:
		var option = button(toolbar,item[0],item[1])
		option.add_theme_stylebox_override("normal",box(Color.TRANSPARENT,14))
		option.add_theme_color_override("font_color",Color("e7ebdc"))
	if not message.is_empty():
		var notice = paragraph(menu,message,18,Color("e9b79a"))
		notice.position = Vector2(86,65)
		notice.size.x = 650

func show_pause() -> void:
	var column = panel("休息片刻", "合作对局仍在进行" if Session.playing else "战斗与坚守计时已暂停",560)
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
	var column = panel("设置", "声音、操控与画质会保存到本机")
	current = "settings"
	var network_toggle = CheckButton.new()
	network_toggle.text = "显示客机网络状态"
	network_toggle.button_pressed = Data.settings.network_stats
	network_toggle.toggled.connect(func(value):
		Data.settings.network_stats = value
		Data.save())
	column.add_child(network_toggle)
	column.add_child(label("鼠标灵敏度",20))
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
	row.add_child(value)
	slider.value_changed.connect(func(v):
		value.set_value_no_signal(v)
		Data.settings.sensitivity = v/100*.0022
		Data.save())
	value.value_changed.connect(func(v): slider.value = v)
	paragraph(column,"按住右键开镜时，转向灵敏度会随真实视野同步降低。",15,Color("74796c"))
	column.add_child(label("主音量",20))
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
	var mute = CheckButton.new()
	mute.text = "静音（M）"
	mute.button_pressed = Data.settings.muted
	column.add_child(mute)
	mute.toggled.connect(func(v):
		Data.settings.muted = v
		Data.apply_settings()
		Data.save())
	column.add_child(label("画质",20))
	var quality = OptionButton.new()
	for text in ["极限流畅","流畅","均衡","精细","极致画质","自定义"]: quality.add_item(text)
	quality.selected = int(Data.settings.quality)
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
		advanced.add_child(label(spec[0],17))
		var option = OptionButton.new()
		for text in spec[3]: option.add_item(text)
		option.selected = maxi(0,spec[2].find(Data.settings[spec[1]]))
		advanced.add_child(option)
		option.item_selected.connect(func(index):
			Data.settings[spec[1]] = spec[2][index]
			Data.settings.quality = 5
			quality.select(5)
			Data.apply_settings()
			Data.save())
	var pixelated = CheckButton.new()
	pixelated.text = "像素化显示"
	pixelated.button_pressed = Data.settings.pixelated
	column.add_child(pixelated)
	pixelated.toggled.connect(func(value):
		Data.settings.pixelated = value
		Data.settings.quality = 5
		quality.select(5)
		Data.apply_settings()
		Data.save())
	var fullscreen = CheckButton.new()
	fullscreen.text = "全屏（F11）"
	fullscreen.button_pressed = Data.settings.fullscreen
	column.add_child(fullscreen)
	fullscreen.toggled.connect(func(v):
		Data.settings.fullscreen = v
		Data.apply_settings()
		Data.save())
	paragraph(column,"渲染器：Godot Compatibility\n渲染设备：%s\n版本：%s" % [RenderingServer.get_video_adapter_name(),Engine.get_version_info().string],15,Color("74796c"))
	button(column,"返回",back,true)

func show_guide() -> void:
	var column = panel("武器与操作", "十款武器全部可用 · 弹匣独立保留 · 备弹无限",1000)
	current = "guide"
	paragraph(column,"WASD 移动  /  鼠标瞄准  /  左键攻击  /  右键举枪\n空格跳跃  /  R 换弹  /  1—0 或滚轮切枪  /  Esc 暂停\n起跳锁定当前移动按键；空中转向仍有效。落水扣 10 血并回出生点。",17)
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation",24)
	grid.add_theme_constant_override("v_separation",12)
	column.add_child(grid)
	for heading in ["武器","等级","弹量","伤害 / 次","装填"]: grid.add_child(label(heading,16,RUST))
	for i in Data.weapons.size():
		var w: Dictionary = Data.weapons[i]
		for text in ["%d  %s" % [(i+1)%10,w.label],w.tier,"∞" if w.get("infiniteAmmo",false) else str(int(w.capacity)),str(roundi(w.damage*w.pellets)) if w.get("kind","gun") == "gun" else str(int(w.damage)),"—" if w.reloadDuration == 0 else "%.2f 秒%s" % [w.reloadDuration,"/发" if w.get("shellReload",false) else ""]]: grid.add_child(label(text,17))
	paragraph(column,"持盾者正面防御；攻击时放低盾牌。狂暴者半血加速。橄榄球蓄力后沿锁定方向冲锋，可侧移躲避。巨人拥有 6000 HP，并能范围砸击。",17)
	paragraph(column,"首波 9 只；每两波提升敌人阶位。清完整波全员恢复 100 HP，阵亡队友复活，休整 3 秒。僵尸只能通过两座桥渡河。",17)
	button(column,"返回",back,true)

func show_scores() -> void:
	var column = panel("坚守记录", "仅记录本机正式单人成绩 · 按清完波数、击杀和时长排序",850)
	current = "scores"
	if Data.scores.is_empty(): paragraph(column,"这里还没有记录。走进哨站，开始第一次坚守。",22)
	else:
		for i in Data.scores.size():
			var score: Dictionary = Data.scores[i]
			column.add_child(label("%02d     %d 波     %d 击杀     %s     %s" % [i+1,score.waves,score.kills,time_text(score.duration),str(score.date).left(10)],19))
	button(column,"返回",back,true)

func show_multiplayer() -> void:
	var column = panel("一起坚守", "房主模拟整场战斗 · 2—4 人合作 · 逐波复活",850)
	current = "multiplayer"
	if OS.has_feature("web"):
		paragraph(column,"浏览器验收版仅支持单人和练习。Steam 与局域网合作请使用 Windows 版。")
		button(column,"返回",show_home)
		return
	paragraph(column,Session.status,17,RUST)
	if Session.active:
		column.add_child(label("房间  "+Session.room_code,22))
		button(column,"复制房间地址 / 房间号",func(): DisplayServer.clipboard_set(Session.room_code))
		for id in Session.members:
			column.add_child(label("●  "+str(Session.members[id])+("   / 房主" if id == Session.host_id else ""),22))
		if Session.is_host():
			var start = button(column,"开始合作",func(): Session.begin_match(),true)
			start.disabled = Session.members.size() < 2
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

func show_result() -> void:
	var sim = game.sim
	var column = panel("坚守结束", "全队阵亡" if Session.playing else "落水耗尽生命" if sim.cause == "water" else "防线失守",640)
	current = "result"
	column.add_child(label("%d 波" % sim.cleared,74,RUST))
	paragraph(column,"已清完波数",18)
	column.add_child(label("%d 击杀   ·   %s" % [sim.kills,time_text(sim.elapsed)],27))
	var p: Dictionary = game.local_pawn()
	if not p.is_empty(): paragraph(column,"本局射击 %d 次，命中 %d 次" % [p.shots,p.hits],18)
	paragraph(column,"合作成绩不计入单人排行榜。" if Session.playing else "练习模式不记录排行榜。" if sim.mode == "practice" else "本局成绩已保存到本机波次排行榜。" if Data.persistent else "存档写入失败，本局成绩仅保留在当前会话。",16,Color("797b6f"))
	if not Session.playing: button(column,"再次坚守",func(): game.start_solo(sim.mode),true)
	button(column,"返回主菜单",func(): game.return_home())

static func time_text(value: float) -> String:
	return "%02d:%02d" % [floori(value/60),floori(value)%60]

func tick(dt: float) -> void:
	sync_portraits()
	hit_flash = maxf(0,hit_flash-dt)
	hurt_flash = maxf(0,hurt_flash-dt)
	hud.queue_redraw()

func text_at(text: String, pos: Vector2, size: int, color := Color("f2eedf")) -> void:
	hud.draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw_hud() -> void:
	if not game or not game.running or not game.sim: return
	var sim = game.sim
	var p: Dictionary = game.view_pawn()
	if p.is_empty(): return
	var screen = hud.size
	var center = screen*.5
	var w: Dictionary = Data.weapons[int(p.weapon)]
	var scoped: bool = int(p.weapon) == 5 and game.weapon.ads > .8
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
		if not p.aim or w.get("kind", "gun") in ["melee","flame"]:
			for dir in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]: hud.draw_line(center+dir*5,center+dir*12,color,2)
	if hit_flash > 0:
		for d in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]: hud.draw_line(center+d*7,center+d*13,Color.WHITE,2)
	if hurt_flash > 0:
		hud.draw_rect(Rect2(Vector2.ZERO,screen),Color(.55,.08,.04,hurt_flash*.3),false,20)
	# Scale the HUD independently from the camera and scope for smaller windows.
	var scale_factor = minf(screen.x / 1440.0, screen.y / 900.0)
	hud.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * scale_factor)
	var canvas = screen / scale_factor
	var pad = 28.0
	hud.draw_style_box(box(Color(.04,.055,.05,.76),14),Rect2(pad,pad,248,91))
	text_at("靶场练习" if sim.mode == "practice" else "第 %02d 波" % sim.wave,Vector2(pad+16,pad+31),24)
	text_at("击杀 %d  ·  场上 %d" % [sim.kills,sim.alive_count()],Vector2(pad+16,pad+57),16)
	text_at(time_text(sim.elapsed),Vector2(pad+16,pad+79),14,Color("b8c1a5"))
	var local: Dictionary = game.local_pawn()
	var owner: Dictionary = local if not local.is_empty() else p
	var bottom = canvas.y - 52
	draw_health_card(owner, Rect2(pad,bottom-82,240,82), true)
	var slot = 0
	for id in sim.pawns:
		var teammate: Dictionary = sim.pawns[id]
		if teammate.id == owner.id: continue
		if slot >= 3: break
		draw_health_card(teammate,Rect2(pad+252+slot*232,bottom-82,220,82),false)
		slot += 1
	var side = canvas.x - 178
	var top = maxf(150,canvas.y * .22)
	hud.draw_style_box(box(Color(.04,.055,.05,.30),12),Rect2(side,top,150,127))
	hud.draw_rect(Rect2(side,top,3,127),Color("bedc8d"))
	text_at(w.label,Vector2(side+12,top+27),19)
	var infinite: bool = w.get("infiniteAmmo",false)
	text_at("∞" if infinite else "%02d" % p.ammo[int(p.weapon)],Vector2(side+12,top+76),44)
	text_at("近战" if infinite else "/ ∞",Vector2(side+90,top+74),21,Color("bdc5b7"))
	var ammo_note = "无需装填" if infinite else "容量 %d · 备用 ∞" % w.capacity
	text_at(ammo_note,Vector2(side+12,top+104),12,Color("bdc5b7"))
	if not scoped:
		for i in 10:
			var row = top+136+i*24
			var selected = int(p.weapon) == i
			hud.draw_style_box(box(Color(.20,.26,.16,.40) if selected else Color(.04,.055,.05,.16),4),Rect2(side+12,row,138,22))
			if selected: hud.draw_rect(Rect2(side+12,row,2,22),Color("bedc8d"))
			text_at(str((i+1)%10),Vector2(side+21,row+16),12,Color("a8b09f"))
			text_at(["步枪","P90","手枪","左轮","单喷","狙击","消防斧","喷火","连喷","重机"][i],Vector2(side+42,row+16),13)
			text_at("∞" if i == 6 else str(p.ammo[i]),Vector2(side+115,row+16),12,Color("bedc8d") if selected else Color("b0b8a8"))
	if sim.rest > 0: text_at("整波清除 · 全员恢复   %.1f 秒后继续" % sim.rest,Vector2(canvas.x*.5-215,70),24)
	text_at("ESC 暂停   ·   R 换弹   ·   1—0 切换武器",Vector2(pad,canvas.y-24),14,Color("c8cfba"))
	if not local.is_empty() and local.hp <= 0 and Session.playing:
		text_at("正在观战 %s · 左键切换队友 · 清波后复活" % p.name,Vector2(pad,bottom-138),20)
	if Session.playing and not Session.is_host() and Data.settings.network_stats:
		var metrics = Session.network_metrics()
		var origin = Vector2(canvas.x-224,28)
		hud.draw_style_box(box(Color(.025,.04,.03,.22),6),Rect2(origin,Vector2(196,58)))
		text_at("网络状态："+metrics.quality,origin+Vector2(10,21),14,Color("ddcd93") if metrics.quality != "良好" else Color("c7dda9"))
		var detail = "正在采样…" if metrics.samples == 0 else "%d ms · 同步丢包 %.0f%%" % [metrics.rtt,metrics.loss]
		if metrics.samples > 0 and metrics.rtt < 0: detail = "延迟 -- · 同步丢包 %.0f%%" % metrics.loss
		if metrics.loss < 0: detail = "正在等待同步数据…"
		text_at(detail,origin+Vector2(10,44),12)
	hud.draw_set_transform(Vector2.ZERO)

func draw_health_card(pawn: Dictionary, rect: Rect2, is_local: bool) -> void:
	var hp = clampf(float(pawn.hp),0,100)
	var accent = Color("afd778") if hp > 50 else Color("e0bc62") if hp > 25 else Color("dd6958")
	if hp <= 0: accent = Color("838980")
	hud.draw_style_box(box(Color(.035,.05,.04,.38),8),rect)
	hud.draw_rect(Rect2(rect.position,Vector2(rect.size.x,2)),accent)
	var portrait = Rect2(rect.position+Vector2(4,6),Vector2(56,72))
	var key = str(pawn.appearance)
	if portraits.has(key): hud.draw_texture_rect(portraits[key].get_texture(),portrait,false)
	var left = rect.position.x+66
	var width = rect.size.x-76
	var name_text = "我" if is_local and not Session.playing else str(pawn.id) if Session.transport == "steam" else str(pawn.get("name","幸存者"))
	var name_size = 13 if Session.transport == "steam" else 15
	while font.get_string_size(name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x > width and name_size > 10:
		name_size -= 1
	if font.get_string_size(name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x > width:
		while font.get_string_size(name_text+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x > width and name_text.length() > 1:
			name_text = name_text.left(name_text.length()-1)
		name_text += "…"
	text_at(name_text,Vector2(left,rect.position.y+23),name_size)
	text_at(str(int(hp)),Vector2(left,rect.position.y+53),26,accent)
	text_at("生命" if hp > 0 else "阵亡",Vector2(left+52,rect.position.y+50),12,Color("d2d9c9"))
	var bar = Rect2(left,rect.end.y-17,width,7)
	hud.draw_rect(bar,Color(.12,.16,.12,.45))
	hud.draw_rect(Rect2(bar.position,Vector2(width*hp/100,bar.size.y)),accent)
	for segment in range(1,10):
		var x = left+width*segment/10.0
		hud.draw_line(Vector2(x,bar.position.y),Vector2(x,bar.end.y),Color(.04,.06,.04,.35),1)

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
	avatar.rotation = Vector3.ZERO
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
