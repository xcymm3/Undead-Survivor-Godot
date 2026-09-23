extends Control
## Retained native widgets; Canvas drawing is reserved for the aiming overlay.
var controls_hint: Label
var wave_label: Label
var count_label: Label
var time_label: Label
var crystal_label: Label
var crystal_bar: ProgressBar
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
var equipment_slots: Array[Dictionary] = []
var campaign_arsenal: VBoxContainer
const EquipmentIcon = preload("res://scripts/hud_equipment_icon.gd")
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
	crystal_label = text(column,15)
	crystal_bar = ProgressBar.new()
	crystal_bar.show_percentage = false
	crystal_bar.custom_minimum_size.y = 9
	column.add_child(crystal_bar)
	var weapon_card = card(content,Vector2(226,0))
	weapon_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	weapon_card.offset_left = -254
	weapon_card.offset_right = -28
	weapon_card.offset_top = -230
	column = column_in(weapon_card)
	weapon_label = text(column,17)
	weapon_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ammo_label = text(column,36)
	ammo_note = text(column,12)
	arsenal = VBoxContainer.new()
	column.add_child(arsenal)
	for i in 10: slots.append(text(arsenal,13))
	campaign_arsenal = VBoxContainer.new()
	campaign_arsenal.add_theme_constant_override("separation",5)
	column.add_child(campaign_arsenal)
	for i in 5:
		var panel = card(campaign_arsenal,Vector2(174,62 if i < 3 else 36))
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		panel.add_child(row)
		var key = text(row,15)
		key.text = str(i+1)
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var icon = EquipmentIcon.new()
		icon.custom_minimum_size = Vector2(78,40) if i < 3 else Vector2(25,25)
		row.add_child(icon)
		var detail = column_in(row)
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.alignment = BoxContainer.ALIGNMENT_CENTER
		var title = text(detail,13)
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.custom_minimum_size.x = 40
		var note = text(detail,12)
		equipment_slots.append({"panel":panel,"icon":icon,"title":title,"note":note,
			"selected":slot_style(true),"idle":slot_style(false)})
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
	controls_hint = hint
	hint.text = "ESC 暂停 · R 换弹 · E 交互/救援"
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
	var panel = card(health_row,Vector2(236,86))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	var row = HBoxContainer.new()
	panel.add_child(row)
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(44,58)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var column = column_in(row)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title = text(column,15)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.x = 90
	var hp = text(column,21)
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
	var campaign: Dictionary = sim.campaign_state()
	var defense: Dictionary = sim.defense_state()
	crystal_label.visible = sim.mode == "defense"
	crystal_bar.visible = sim.mode == "defense"
	if sim.mode == "defense":
		var defense_wave: int = int(defense.get("wave",sim.wave))
		var countdown: float = float(defense.get("countdown",0.0))
		wave_label.text = "等待拉杆" if not defense.get("started",false) else "第 %02d 波 · %d 秒准备" % [defense_wave,ceili(countdown)] if countdown > 0 else "第 %02d / %02d 波" % [sim.wave,Data.Maps.Defense.MAX_WAVES]
		count_label.text = "击杀 %d · 场上 %d" % [sim.kills,sim.alive_count()]
		crystal_label.text = "水晶  %d / %d" % [defense.get("crystal_hp",0),defense.get("crystal_max_hp",0)]
		crystal_bar.max_value = defense.get("crystal_max_hp",1)
		crystal_bar.value = defense.get("crystal_hp",0)
		crystal_bar.modulate = Color("7fe7ef") if crystal_bar.value > crystal_bar.max_value*.3 else Color("ee6658")
	if sim.mode == "campaign":
		wave_label.text = "灰松夜路" if sim.map_id == "graypine_night" else "灰松渡口"
		count_label.text = "击杀 %d · 医疗包 %d" % [sim.kills,p.get("medkits",0)]
	var w: Dictionary = Data.weapons[int(p.weapon)]
	weapon_label.text = "%s · %s级" % [w.label,w.tier]
	var infinite: bool = w.get("infiniteAmmo",false)
	ammo_label.text = "∞  近战" if infinite else "%02d / ∞" % p.ammo[int(p.weapon)]
	ammo_note.text = "无需装填" if infinite else "容量 %d · 备用 ∞" % w.capacity
	controls_hint.text = "ESC 暂停 · R 换弹 · 1—0 武器"
	if sim.mode in ["campaign","defense"]:
		controls_hint.text = "1 主武器 · 2 副武器 · 3 斧 · 4 手雷 · 5 医疗包 · E 拾取/交互"
		if not infinite and not w.get("infiniteReserve",false): ammo_label.text = "%02d / %d" % [p.ammo[int(p.weapon)],p.reserves[int(p.weapon)]]
		ammo_note.text = "无需弹药" if infinite else "R 换弹 · 无限备弹" if w.get("infiniteReserve",false) else "R 换弹 · 补给点换枪"
		if p.slot >= 4:
			weapon_label.text = "手雷" if p.slot == 4 else "医疗包"
			ammo_label.text = str(p.grenades if p.slot == 4 else p.medkits)
			ammo_note.text = "左键投掷 · 1.5 秒引信" if p.slot == 4 else "左键自己 · 右键队友"

	arsenal.visible = not (int(p.weapon) == 5 and p.get("slot",1) < 4 and ui.game.weapon.ads > .8)
	var shared_loadout: bool = sim.mode in ["campaign","defense"]
	campaign_arsenal.visible = shared_loadout and arsenal.visible
	arsenal.visible = not shared_loadout and arsenal.visible
	if shared_loadout:
		for i in 5:
			var item: Dictionary = equipment_slots[i]
			var index: int = p.primary if i == 0 else p.secondary if i == 1 else 6
			var selected: bool = p.slot == i+1
			var available: bool = i < 3 or (p.grenades if i == 3 else p.medkits) > 0
			item.panel.add_theme_stylebox_override("panel",item.selected if selected else item.idle)
			item.icon.kind = str(Data.weapons[index].id) if i < 3 else "grenade" if i == 3 else "medkit"
			item.icon.modulate = Color("c7ef8a") if selected and available else Color("f2eedf") if available else Color("647064")
			item.title.text = str(Data.weapons[index].label) if i < 3 else "手雷" if i == 3 else "医疗包"
			item.note.visible = i < 3
			item.note.text = str(Data.weapons[index].tier)+" 级"
			if i >= 3: item.title.text += ("  %d / %d" % [p.grenades if i == 3 else p.medkits,3 if i == 3 else 1]) if available else "  空"
			item.icon.queue_redraw()
	else:
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
		item.hp.text = "+%d" % pawn.hp if pawn.hp > 0 else "阵亡"
		if pawn.get("downed",false): item.hp.text = "倒地 %d 秒" % ceili(pawn.get("bleed",0))
		item.bar.value = pawn.hp
		item.bar.modulate = Color.WHITE if pawn.hp > 50 else Color("e0bc62") if pawn.hp > 25 else Color("dd6958")
		var key = str(pawn.appearance)
		if ui.portraits.has(key): item.portrait.texture = ui.portraits[key].get_texture()
	rest_label.visible = sim.rest > 0
	if rest_label.visible: rest_label.text = "整波清除 · 全员恢复   %.1f 秒后继续" % sim.rest
	if sim.mode == "defense":
		rest_label.visible = true
		rest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rest_label.add_theme_stylebox_override("normal",style(Color(.04,.055,.05,.8),8))
		rest_label.text = str(defense.get("objective",""))+"\n"+str(p.get("hint",""))
		if sim.rest > 0: rest_label.text += "\n下一波倒计时 %.1f 秒" % sim.rest
	if sim.mode == "campaign":
		rest_label.visible = true
		rest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rest_label.add_theme_stylebox_override("normal",style(Color(.04,.055,.05,.8),8))
		rest_label.text = campaign.get("objective","")+"\n"+p.get("hint","")
		if campaign.get("phase") == "BRIDGE_ACTIVE": rest_label.text += "\n闸门开启 %.0f / 90 秒" % campaign.get("bridge_time",0)
	var local: Dictionary = ui.game.local_pawn()
	spectator_label.visible = not local.is_empty() and local.hp <= 0 and Session.playing
	if spectator_label.visible: spectator_label.text = "正在观战 %s · 左键切换队友 · 清波后复活" % p.name
	if sim.mode == "campaign" and spectator_label.visible: spectator_label.text = "等待队友救援" if local.get("downed",false) else "正在观战 · 本关不复活"
	network_card.visible = Session.playing and not Session.is_host() and Data.settings.network_stats
	if network_card.visible:
		var metrics = Session.network_metrics()
		network_label.text = "网络状态："+metrics.quality
		network_detail.text = "正在采样…" if metrics.samples == 0 or metrics.loss < 0 else "%d ms · 同步丢包 %.0f%%" % [metrics.rtt,metrics.loss]

static func slot_style(selected: bool) -> StyleBoxFlat:
	var result = style(Color("283727") if selected else Color(.08,.1,.08,.8),6)
	result.border_color = Color("b4dd7a") if selected else Color("384335")
	result.border_width_left = 3 if selected else 1
	return result
