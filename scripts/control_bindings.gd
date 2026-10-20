extends RefCounted
const ACTIONS = [
	["forward","前进"],["back","后退"],["left","向左移动"],["right","向右移动"],
	["sprint","疾跑"],["fire","开枪 / 攻击"],["aim","开镜"],["shove","枪托攻击"],
	["interact","交互"],["ultimate","终极技能"],["jump","跳跃"],["crouch","蹲下"],["reload","换弹"],
	["weapon_0","装备栏 1"],["weapon_1","装备栏 2"],["weapon_2","装备栏 3"],["weapon_3","装备栏 4"]]
var defaults: Dictionary = {}

func initialize(saved: Dictionary) -> void:
	if defaults.is_empty():
		for spec in ACTIONS: defaults[spec[0]] = InputMap.action_get_events(spec[0]).duplicate()
	restore()
	for spec in ACTIONS:
		var value = saved.get(spec[0],"")
		if value is String:
			var event = decode(value)
			if event: rebind(spec[0],event)

func restore() -> void:
	for action in defaults:
		Input.action_release(action)
		InputMap.action_erase_events(action)
		for event in defaults[action]: InputMap.action_add_event(action,event)

func encode(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key > 0 and key != KEY_ESCAPE: return "k:"+str(key)
	if event is InputEventMouseButton and event.button_index in [1,2,3,8,9]: return "m:"+str(event.button_index)
	return ""

func decode(value: String) -> InputEvent:
	var parts = value.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int(): return null
	var code = int(parts[1])
	if parts[0] == "k" and code > 0 and code <= 8388607 and code != KEY_ESCAPE:
		var event = InputEventKey.new()
		event.physical_keycode = code
		return event
	if parts[0] == "m" and code in [1,2,3,8,9]:
		var event = InputEventMouseButton.new()
		event.button_index = code
		return event
	return null

func export_bindings() -> Dictionary:
	var result = {}
	for spec in ACTIONS: result[spec[0]] = encode(InputMap.action_get_events(spec[0])[0])
	return result

func assign(action: String, events: Array) -> void:
	Input.action_release(action)
	InputMap.action_erase_events(action)
	for event in events: InputMap.action_add_event(action,event)

func rebind(action: String, event: InputEvent) -> String:
	if not defaults.has(action): return "不可修改"
	var code = encode(event)
	if code.is_empty(): return "请使用键盘或鼠标键"
	# Preserve pause/fullscreen and unused weapon slots without duplicate actions.
	for other in ["pause","fullscreen","weapon_previous","weapon_next","weapon_4","weapon_5","weapon_6","weapon_7","weapon_8","weapon_9"]:
		for existing in InputMap.action_get_events(other):
			if encode(existing) == code: return "该按键已保留"
	var old = InputMap.action_get_events(action)
	for spec in ACTIONS:
		if spec[0] == action: continue
		for existing in InputMap.action_get_events(spec[0]):
			if encode(existing) == code: assign(spec[0],old)
	assign(action,[decode(code)])
	return ""

func label_for(action: String) -> String:
	var events = InputMap.action_get_events(action)
	if events.is_empty(): return "未绑定"
	var event = events[0]
	if event is InputEventMouseButton:
		return {1:"鼠标左键",2:"鼠标右键",3:"鼠标中键",8:"鼠标侧键 1",9:"鼠标侧键 2"}.get(event.button_index,"鼠标键")
	return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
