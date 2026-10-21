extends Control
## Retained native widgets; Canvas drawing is reserved for the aiming overlay.
var tutorial_overlay: Control
var upgrade_details: Control
var crystal_alert: Label
var grenade_ring: Control
var ultimate_ring: Control
var ultimate_notice: Label
var status_panel: Control
var wave_label: Label
var crystal_label: Label
var weapon_label: Label
var ammo_label: Label
var rest_label: Label
var spectator_label: Label
var network_label: Label
var network_detail: Label
var network_card: PanelContainer
var currency_label: Label
var diamond_label: Label
var wave_announcement: Label
var boss_title: Label
var boss_bar: ProgressBar
var health_row: HBoxContainer
var health_right: HBoxContainer
var cards: Dictionary = {}
var slots: Array[Label] = []
var equipment_slots: Array[Dictionary] = []
var equipment_arsenal: VBoxContainer
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
	status_panel = preload("res://scripts/hud_defense_status.gd").new()
	status_panel.name = "DefenseStatus"
	content.add_child(status_panel)
	status_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status_panel.offset_left = -328
	status_panel.offset_right = -28
	status_panel.offset_top = 28
	status_panel.offset_bottom = 174
	wave_label = status_panel.wave_label
	crystal_label = status_panel.crystal_label
	var column: VBoxContainer
	upgrade_details = preload("res://scripts/upgrade_details.gd").new()
	upgrade_details.position = Vector2(28,235)
	content.add_child(upgrade_details)
	var weapon_card = card(content,Vector2(226,0))
	weapon_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	weapon_card.offset_left = -254
	weapon_card.offset_right = -28
	weapon_card.offset_top = -230
	column = column_in(weapon_card)
	weapon_label = text(column,17)
	weapon_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ammo_label = text(column,36)
	arsenal = VBoxContainer.new()
	column.add_child(arsenal)
	for i in 10: slots.append(text(arsenal,13))
	equipment_arsenal = VBoxContainer.new()
	equipment_arsenal.add_theme_constant_override("separation",5)
	column.add_child(equipment_arsenal)
	for i in 4:
		var panel = card(equipment_arsenal,Vector2(174,62 if i < 3 else 48))
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
			"key":key,"selected":slot_style(true),"idle":slot_style(false)})
	# The ultimate itself stays on the exact screen centre line.
	ultimate_ring = preload("res://scripts/cooldown_ring.gd").new()
	ultimate_ring.name = "UltimateCharge"
	content.add_child(ultimate_ring)
	ultimate_ring.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	ultimate_ring.offset_left = -60
	ultimate_ring.offset_right = 60
	ultimate_ring.offset_top = -174
	ultimate_ring.offset_bottom = -38
	grenade_ring = preload("res://scripts/cooldown_ring.gd").new()
	grenade_ring.name = "GrenadeCharge"
	grenade_ring.kind = "grenade"
	grenade_ring.compact = true
	grenade_ring.custom_minimum_size = Vector2(68,68)
	var grenade_row = equipment_slots[3].icon.get_parent()
	equipment_slots[3].icon.hide()
	grenade_row.add_child(grenade_ring)
	grenade_row.move_child(grenade_ring,1)
	ultimate_notice = text(content,14)
	ultimate_notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ultimate_notice.offset_left = 520
	ultimate_notice.offset_right = -520
	ultimate_notice.offset_top = -204
	ultimate_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crystal_alert = text(content,28)
	crystal_alert.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	crystal_alert.offset_top = 110
	crystal_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crystal_alert.text = "水晶正在被攻击！"
	crystal_alert.add_theme_color_override("font_color",Color("ff785b"))
	crystal_alert.add_theme_constant_override("outline_size",4)
	crystal_alert.add_theme_color_override("font_outline_color",Color("191c1c"))
	health_row = HBoxContainer.new()
	health_right = HBoxContainer.new()
	for side in [health_row,health_right]:
		content.add_child(side)
		side.add_theme_constant_override("separation",8)
		side.alignment = BoxContainer.ALIGNMENT_BEGIN if side == health_row else BoxContainer.ALIGNMENT_END
		side.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT if side == health_row else Control.PRESET_BOTTOM_RIGHT)
		side.offset_left = 28 if side == health_row else -512
		side.offset_right = 512 if side == health_row else -28
		side.offset_top = -146
		side.offset_bottom = -52
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
	network_card = card(content,Vector2(210,0))
	network_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	network_card.offset_left = 28
	network_card.offset_top = 152
	column = column_in(network_card)
	network_label = text(column,14)
	network_detail = text(column,12)
	var wallet = card(content,Vector2(210,0))
	wallet.name = "PermanentWallet"
	wallet.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	wallet.offset_left = 28
	wallet.offset_right = 238
	wallet.offset_top = 28
	var wallet_column = column_in(wallet)
	for currency in ["coins","diamonds"]:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation",10)
		wallet_column.add_child(row)
		var icon = TextureRect.new()
		icon.name = "CoinIcon" if currency == "coins" else "DiamondIcon"
		icon.texture = preload("res://scripts/currency_art.gd").coin() if currency == "coins" else preload("res://scripts/currency_art.gd").diamond()
		icon.custom_minimum_size = Vector2(32,32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var number = text(row,24)
		if currency == "coins": currency_label = number
		else: diamond_label = number
	resized.connect(layout)
	var boss_column = VBoxContainer.new()
	boss_column.name = "DancerHealth"
	boss_column.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_column.offset_left = 380
	boss_column.offset_right = -380
	boss_column.offset_top = 32
	content.add_child(boss_column)
	boss_title = text(boss_column,22)
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size.y = 16
	boss_bar.add_theme_stylebox_override("fill",style(Color("b84739"),0))
	boss_column.add_child(boss_bar)
	wave_announcement = text(content,48)
	wave_announcement.name = "WaveAnnouncement"
	wave_announcement.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	wave_announcement.offset_left = 300
	wave_announcement.offset_right = -300
	wave_announcement.offset_top = 200
	wave_announcement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_announcement.add_theme_color_override("font_outline_color",Color(.035,.04,.05,.9))
	wave_announcement.add_theme_constant_override("outline_size",6)
	wave_announcement.visible = false
	tutorial_overlay = preload("res://scripts/tutorial_overlay.gd").new()
	add_child(tutorial_overlay)
	layout()
	ignore_mouse(self)

func layout() -> void:
	if not content: return
	var factor = maxf(.1,minf(size.x/1440.0,size.y/900.0))
	content.scale = Vector2.ONE*factor
	content.size = size/factor

static func announcement_alpha(age: float) -> float:
	return minf(clampf(age/.45,0,1),clampf((3.0-age)/.65,0,1)) if age >= 0 and age < 3.0 else 0.0

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
	visible = ui.game.running and ui.game.sim != null and not ui.game.finished
	if not visible: return
	ui.sync_portraits()
	var sim = ui.game.sim
	var bosses = sim.zombies.filter(func(z): return z.kind == "dancer" and z.hp > 0)
	boss_title.get_parent().visible = not bosses.is_empty()
	if not bosses.is_empty():
		var boss: Dictionary = bosses[0]
		boss_bar.max_value = boss.get("max_hp",Data.enemies.dancer.health)
		boss_bar.value = boss.hp
		boss_title.text = "Disco King    %d / %d" % [boss.hp,boss_bar.max_value]
	currency_label.text = str(floori(sim.progression.data.coins))
	diamond_label.text = str(sim.progression.data.diamonds)
	var p: Dictionary = ui.game.view_pawn()
	if p.is_empty():
		upgrade_details.sync({})
		return
	var catalog = preload("res://scripts/preparation_catalog.gd")
	var focus = catalog.focus(sim,p)
	upgrade_details.sync(catalog.upgrade_details(sim,focus.id) if not focus.is_empty() else {})
	var defense: Dictionary = sim.defense_state()
	var age: float = sim.elapsed-float(defense.get("wave_started_at",-100))
	var announcement_opacity: float = announcement_alpha(age) if defense.get("started",false) and not sim.failed and not sim.won else 0.0
	var intro = preload("res://scripts/first_attempt_intro.gd")
	var intro_active: bool = intro.active(defense)
	if intro_active: announcement_opacity = 0.0
	var local_pawn: Dictionary = ui.game.local_pawn()
	tutorial_overlay.sync(defense,not local_pawn.is_empty() and local_pawn.hp > 0 and not sim.failed,not bosses.is_empty())
	wave_announcement.visible = announcement_opacity > 0
	wave_announcement.modulate = Color(1,1,1,announcement_opacity)
	wave_announcement.text = "第10波-最后一波！" if sim.wave == 10 else "第%d波" % sim.wave
	if intro_active: wave_announcement.text = intro.caption(defense)
	wave_announcement.add_theme_color_override("font_color",Color("ffab62") if sim.wave == 10 and not intro_active else Color("ffe8ae"))
	status_panel.visible = sim.mode == "defense"
	status_panel.sync(sim.wave,int(defense.get("crystal_hp",0)),int(defense.get("crystal_max_hp",1)),bool(defense.get("started",false)),float(defense.get("crystal_alert_until",-1)) > sim.elapsed)
	crystal_alert.visible = float(defense.get("crystal_alert_until",-1)) > sim.elapsed
	ultimate_ring.visible = sim.mode == "defense" and preload("res://scripts/ultimate.gd").unlocked(p)
	var ultimate = preload("res://scripts/ultimate.gd")
	var unlocked: bool = ultimate.unlocked(p)
	var charge = 1.0-float(p.get("ultimate_cd",0.0))/ultimate.cooldown(sim.progression) if unlocked else 0.0
	ultimate_ring.sync(charge,"未解锁" if not unlocked else "%d%%" % floori(charge*100) if not ultimate.active(p) else Data.binding_label("ultimate"),"终极技能" if not unlocked else "终极技能 %ds" % ceili(p.ultimate_remaining) if ultimate.active(p) else "终极技能 · "+Data.binding_label("ultimate"),not unlocked)
	grenade_ring.visible = sim.mode == "defense"
	var grenade_capacity: int = p.get("grenade_capacity",0)
	var grenade_charge = 0.0 if grenade_capacity == 0 else 1.0 if p.grenades >= grenade_capacity else clampf(1.0-float(p.get("grenade_replenish",15.0))/15.0,0,1)
	grenade_ring.sync(grenade_charge,"","",grenade_capacity == 0)
	ultimate_notice.text = p.get("ultimate_notice","") if p.get("ultimate_notice_until",0.0) > sim.elapsed else ""
	var w: Dictionary = sim.combat_weapon(p)
	weapon_label.text = str(w.label)
	var infinite: bool = w.get("infiniteAmmo",false)
	ammo_label.text = "∞  近战" if infinite else "%02d / ∞" % p.ammo[int(p.weapon)]
	if sim.mode == "defense":
		weapon_label.text = "%s · %s" % [w.label,preload("res://scripts/preparation_catalog.gd").level_label(sim.progression,w.id)]
		if not infinite and not w.get("infiniteReserve",false): ammo_label.text = "%02d / %d" % [p.ammo[int(p.weapon)],p.reserves[int(p.weapon)]]
		if p.slot == 4:
			weapon_label.text = "手雷 · "+preload("res://scripts/preparation_catalog.gd").level_label(sim.progression,"grenade")
			ammo_label.text = "%d / %d" % [p.grenades,p.grenade_capacity]

	arsenal.visible = not (int(p.weapon) == 5 and p.get("slot",1) < 4 and ui.game.weapon.ads > .8)
	var shared_loadout: bool = sim.mode == "defense"
	equipment_arsenal.visible = shared_loadout and arsenal.visible
	arsenal.visible = not shared_loadout and arsenal.visible
	if shared_loadout:
		for i in 4:
			var item: Dictionary = equipment_slots[i]
			var index: int = p.weapon1 if i == 0 else p.weapon2 if i == 1 else 6
			var selected: bool = p.slot == i+1
			item.panel.visible = true
			var available: bool = i < 3 or p.grenades > 0
			item.panel.add_theme_stylebox_override("panel",item.selected if selected else item.idle)
			item.key.text = Data.binding_label("weapon_%d" % i)
			item.icon.kind = str(Data.weapons[index].id) if i < 3 else "grenade"
			item.icon.modulate = Color("c7ef8a") if selected and available else Color("f2eedf") if available else Color("647064")
			item.title.text = Data.weapons[index].label if i < 3 else "手雷  %d / %d" % [p.grenades,p.grenade_capacity]
			item.note.visible = i < 2
			item.note.text = "%d / %d" % [p.slot_ammo[i],p.slot_reserves[i]] if i < 2 else "无需弹药" if i == 2 else "商店购买解锁" if grenade_capacity == 0 else "每15秒补充1颗"
			if i < 2 and Data.weapons[index].get("infiniteAmmo",false): item.note.text = "无需弹药"
			item.icon.queue_redraw()
	else:
		for i in slots.size():
			slots[i].text = "%s %s  %s  %s" % ["›" if int(p.weapon) == i else " ",Data.binding_label("weapon_%d" % i),Data.weapons[i].label,"∞" if Data.weapons[i].get("infiniteAmmo",false) else str(p.ammo[i])]

	var ids: Array = sim.pawns.keys()
	ids.erase(Session.local_id)
	if sim.pawns.has(Session.local_id): ids.push_front(Session.local_id)
	for id in cards.keys():
		if not sim.pawns.has(id):
			cards[id].panel.queue_free()
			cards.erase(id)
	health_row.offset_top = -146
	health_right.offset_top = -146
	for i in ids.size():
		var pawn: Dictionary = sim.pawns[ids[i]]
		var item: Dictionary = cards[ids[i]] if cards.has(ids[i]) else health_card(ids[i])
		var side = health_row if i < 2 else health_right
		if item.panel.get_parent() != side: item.panel.reparent(side)
		side.move_child(item.panel,i%2)
		item.name.text = "我" if ids[i] == Session.local_id and not Session.playing else str(pawn.get("name",ids[i]))
		item.hp.text = "已断线" if not pawn.get("connected",true) else "+%d" % pawn.hp if pawn.hp > 0 else "阵亡"
		item.bar.max_value = pawn.get("max_hp",100)
		item.bar.value = pawn.hp
		item.bar.modulate = Color.WHITE if pawn.hp > 50 else Color("e0bc62") if pawn.hp > 25 else Color("dd6958")
		var key = str(pawn.appearance)
		if ui.portraits.has(key): item.portrait.texture = ui.portraits[key].get_texture()
	rest_label.visible = sim.rest > 0
	if rest_label.visible: rest_label.text = "整波清除 · 全员恢复   %.1f 秒后继续" % sim.rest
	if sim.mode == "defense":
		rest_label.visible = false
		rest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rest_label.add_theme_stylebox_override("normal",style(Color(.04,.055,.05,.8),8))
		rest_label.text = str(defense.get("objective",""))+"\n"+str(p.get("hint",""))
	var local: Dictionary = ui.game.local_pawn()
	spectator_label.visible = not local.is_empty() and local.hp <= 0 and Session.playing
	if spectator_label.visible: spectator_label.text = "本局已阵亡，不可复活 · 观战 %s · 左键切换队友" % p.name
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
