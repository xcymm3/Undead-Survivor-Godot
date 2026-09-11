extends Control
## Retained native widgets; Canvas drawing is reserved for the aiming overlay.
var wave_label: Label
var count_label: Label
var time_label: Label
var weapon_label: Label
var ammo_label: Label
var ammo_note: Label
var rest_label: Label
var spectator_label: Label
var network_label: Label
var network_detail: Label
var network_card: PanelContainer
var health_row: HBoxContainer
var cards: Dictionary = {}
var slots: Array[Label] = []
var arsenal: VBoxContainer
var content: Control
var ui

func setup(owner_ui) -> void:
	ui = owner_ui
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content = Control.new()
	add_child(content)
	var theme_resource = Theme.new()
	theme_resource.default_font = ui.font
	theme_resource.default_font_size = 16
	theme_resource.set_color("font_color","Label",Color("f2eedf"))
	theme_resource.set_stylebox("panel","PanelContainer",style(Color(.04,.055,.05,.65)))
	theme_resource.set_stylebox("background","ProgressBar",style(Color("27352b"),0))
	theme_resource.set_stylebox("fill","ProgressBar",style(Color("afd778"),0))
	theme = theme_resource
	var status = card(content,Vector2(248,0))
	status.position = Vector2(28,28)
	var column = column_in(status)
	wave_label = text(column,24)
	count_label = text(column)
	time_label = text(column,14)
	var weapon_card = card(content,Vector2(158,0))
	weapon_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	weapon_card.offset_left = -186
	weapon_card.offset_top = -235
	column = column_in(weapon_card)
	weapon_label = text(column,19)
	ammo_label = text(column,36)
	ammo_note = text(column,12)
	arsenal = VBoxContainer.new()
	column.add_child(arsenal)
	for i in 10: slots.append(text(arsenal,13))
	health_row = HBoxContainer.new()
	health_row.add_theme_constant_override("separation",12)
	health_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	health_row.offset_left = 28
	health_row.offset_right = -210
	health_row.offset_top = -146
	health_row.offset_bottom = -52
	content.add_child(health_row)
	rest_label = text(content,22)
	rest_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rest_label.offset_left = 290
	rest_label.offset_right = -260
	rest_label.offset_top = 40
	rest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spectator_label = text(content,18)
	spectator_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	spectator_label.offset_left = 28
	spectator_label.offset_top = -185
	var hint = text(content,14)
	hint.text = "ESC 暂停   ·   R 换弹   ·   1—0 切换武器"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left = 28
	hint.offset_top = -36
	network_card = card(content,Vector2(210,0))
	network_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	network_card.offset_left = -238
	network_card.offset_top = 28
	column = column_in(network_card)
	network_label = text(column,14)
	network_detail = text(column,12)
	resized.connect(layout)
	layout()
	ignore_mouse(self)

func layout() -> void:
	if not content: return
	var factor = maxf(.1,minf(size.x/1440.0,size.y/900.0))
	content.scale = Vector2.ONE*factor
	content.size = size/factor

static func ignore_mouse(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): ignore_mouse(child)

static func style(color: Color, padding := 12) -> StyleBoxFlat:
	var result = StyleBoxFlat.new()
	result.bg_color = color
	result.set_content_margin_all(padding)
	result.set_corner_radius_all(3)
	return result

func card(parent: Node, minimum: Vector2) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = minimum
	parent.add_child(panel)
	return panel

func column_in(parent: Node) -> VBoxContainer:
	var result = VBoxContainer.new()
	result.add_theme_constant_override("separation",4)
	parent.add_child(result)
	return result

func text(parent: Node, font_size := 16) -> Label:
	var result = Label.new()
	result.add_theme_font_size_override("font_size",font_size)
	parent.add_child(result)
	return result

func health_card(id: String) -> Dictionary:
	var panel = card(health_row,Vector2(210,94))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row = HBoxContainer.new()
	panel.add_child(row)
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(50,66)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var column = column_in(row)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title = text(column,15)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.x = 90
	var hp = text(column,24)
	var bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 7
	column.add_child(bar)
	ignore_mouse(panel)
	var result = {"panel":panel,"portrait":portrait,"name":title,"hp":hp,"bar":bar}
	cards[id] = result
	return result

func sync() -> void:
	visible = ui.game.running and ui.game.sim != null
	if not visible: return
	var sim = ui.game.sim
	var p: Dictionary = ui.game.view_pawn()
	if p.is_empty(): return
	wave_label.text = "第 %02d 波" % sim.wave
	count_label.text = "击杀 %d  ·  场上 %d" % [sim.kills,sim.alive_count()]
	time_label.text = ui.time_text(sim.elapsed)
	var w: Dictionary = Data.weapons[int(p.weapon)]
	weapon_label.text = w.label
	var infinite: bool = w.get("infiniteAmmo",false)
	ammo_label.text = "∞  近战" if infinite else "%02d / ∞" % p.ammo[int(p.weapon)]
	ammo_note.text = "无需装填" if infinite else "容量 %d · 备用 ∞" % w.capacity
	arsenal.visible = not (int(p.weapon) == 5 and ui.game.weapon.ads > .8)
	for i in slots.size():
		slots[i].text = "%s %d  %s  %s" % ["›" if int(p.weapon) == i else " ",(i+1)%10,Data.weapons[i].label,"∞" if Data.weapons[i].get("infiniteAmmo",false) else str(p.ammo[i])]
	var ids: Array = sim.pawns.keys()
	ids.erase(Session.local_id)
	if sim.pawns.has(Session.local_id): ids.push_front(Session.local_id)
	for id in cards.keys():
		if not sim.pawns.has(id):
			cards[id].panel.queue_free()
			cards.erase(id)
	for i in ids.size():
		var pawn: Dictionary = sim.pawns[ids[i]]
		var item: Dictionary = cards[ids[i]] if cards.has(ids[i]) else health_card(ids[i])
		health_row.move_child(item.panel,i)
		item.name.text = "我" if ids[i] == Session.local_id and not Session.playing else str(pawn.get("name",ids[i]))
		item.hp.text = "%d  %s" % [pawn.hp,"生命" if pawn.hp > 0 else "阵亡"]
		item.bar.value = pawn.hp
		item.bar.modulate = Color.WHITE if pawn.hp > 50 else Color("e0bc62") if pawn.hp > 25 else Color("dd6958")
		var key = str(pawn.appearance)
		if ui.portraits.has(key): item.portrait.texture = ui.portraits[key].get_texture()
	rest_label.visible = sim.rest > 0
	if rest_label.visible: rest_label.text = "整波清除 · 全员恢复   %.1f 秒后继续" % sim.rest
	var local: Dictionary = ui.game.local_pawn()
	spectator_label.visible = not local.is_empty() and local.hp <= 0 and Session.playing
	if spectator_label.visible: spectator_label.text = "正在观战 %s · 左键切换队友 · 清波后复活" % p.name
	network_card.visible = Session.playing and not Session.is_host() and Data.settings.network_stats
	if network_card.visible:
		var metrics = Session.network_metrics()
		network_label.text = "网络状态："+metrics.quality
		network_detail.text = "正在采样…" if metrics.samples == 0 or metrics.loss < 0 else "%d ms · 同步丢包 %.0f%%" % [metrics.rtt,metrics.loss]
