extends RefCounted
## Permanent economy, separate from the disposable combat simulation.
const MAX_CURRENCY = 9000000000000000
const WEAPONS = ["rifle","revolver","axe"]
const TALENTS = ["strong","precise","swift","supply"]
const BUILDINGS = ["turret_left","turret_right","bridge_gate"]
const COIN_REWARDS = {"normal":1,"crawler":1,"cone":2,"bucket":3,"imp":3,"shield":5,"berserker":10,"giant":10,"football":20}
var path = ""
var dirty = false
var notice = ""
var data: Dictionary = defaults()

static func defaults() -> Dictionary:
	return {"version":1,"coins":0,"diamonds":0,"grenade_level":0,"weapons":{"rifle":0,"revolver":0,"axe":0},"talents":{"strong":0,"precise":0,"swift":0,"supply":0},"buildings":{"turret_left":{"owned":false,"level":0},"turret_right":{"owned":false,"level":0},"bridge_gate":{"owned":false,"level":0}},"best_wave":0,"cleared_total":0}

func _init(save_path := "") -> void:
	path = save_path
	if not path.is_empty(): load_save()

static func bounded_integer(value, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= maximum and float(value) == floor(float(value))

static func valid(value) -> bool:
	if not value is Dictionary or not value.has_all(defaults().keys()) or value.version != 1: return false
	for key in ["coins","diamonds","best_wave","cleared_total"]:
		if not bounded_integer(value[key],MAX_CURRENCY): return false
	if not bounded_integer(value.grenade_level,4): return false
	if not value.weapons is Dictionary or not value.talents is Dictionary or not value.buildings is Dictionary: return false
	for key in WEAPONS:
		if not value.weapons.has(key) or not bounded_integer(value.weapons[key],48): return false
	for key in TALENTS:
		if not value.talents.has(key) or not bounded_integer(value.talents[key],10): return false
	for key in BUILDINGS:
		var entry = value.buildings.get(key)
		if not entry is Dictionary or not entry.has_all(["owned","level"]) or not entry.owned is bool or not bounded_integer(entry.level,48) or (not entry.owned and entry.level != 0): return false
	return true

func read_save(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path): return {}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path)) != OK: return {}
	var parsed = parser.data
	return parsed if valid(parsed) else {}

func load_save() -> void:
	var loaded = read_save(path)
	if loaded.is_empty():
		loaded = read_save(path+".bak")
		if not loaded.is_empty():
			notice = "主存档损坏，已从备份恢复进度。"
			dirty = true
		elif FileAccess.file_exists(path):
			notice = "存档无法读取，已保留原文件并启用新进度。"
			DirAccess.copy_absolute(path,path+".corrupt-"+str(Time.get_unix_time_from_system()))
	if not loaded.is_empty(): data = loaded

func save() -> bool:
	if path.is_empty() or not dirty: return true
	var file = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file:
		notice = "进度保存失败：无法写入用户目录。"
		return false
	file.store_string(JSON.stringify(data,"\t"))
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK: return false
	if not read_save(path).is_empty() and DirAccess.copy_absolute(path,path+".bak") != OK: return false
	if DirAccess.rename_absolute(path+".tmp",path) != OK:
		notice = "进度保存失败：无法替换存档。"
		return false
	dirty = false
	return true

func award_kill(kind: String) -> int:
	var reward: int = COIN_REWARDS.get(kind,1)
	data.coins = mini(MAX_CURRENCY,int(data.coins)+reward)
	dirty = true
	return reward

func award_wave(wave: int) -> void:
	data.diamonds = mini(MAX_CURRENCY,int(data.diamonds)+1)
	data.cleared_total = mini(MAX_CURRENCY,int(data.cleared_total)+1)
	data.best_wave = maxi(int(data.best_wave),wave)
	dirty = true
	save()

func level(id: String) -> int:
	if id in WEAPONS: return int(data.weapons[id])
	if id in TALENTS: return int(data.talents[id])
	if id == "grenade": return int(data.grenade_level)
	if id in BUILDINGS: return int(data.buildings[id].level)
	return 0

func owned(id: String) -> bool:
	return id in BUILDINGS and data.buildings[id].owned

func currency(id: String) -> String:
	return "diamonds" if id in TALENTS else "coins"

func cost(id: String) -> int:
	var base = 20
	if id in TALENTS: return level(id)+1 if level(id) < 10 else -1
	if id == "grenade":
		if level(id) >= 4: return -1
		base = 30
	elif id in BUILDINGS:
		if not owned(id): return 80 if id == "bridge_gate" else 100
		base = 40 if id == "bridge_gate" else 50
	elif id not in WEAPONS: return -1
	var price = float(base)*pow(2,level(id))
	return int(price) if level(id) < 48 and price <= MAX_CURRENCY else -1

func purchase(id: String) -> bool:
	var price = cost(id)
	var wallet = currency(id)
	if price < 0 or data[wallet] < price: return false
	var previous = data.duplicate(true)
	data[wallet] = int(data[wallet])-price
	if id in WEAPONS: data.weapons[id] = level(id)+1
	elif id in TALENTS: data.talents[id] = level(id)+1
	elif id == "grenade": data.grenade_level = level(id)+1
	elif id in BUILDINGS:
		if owned(id): data.buildings[id].level = level(id)+1
		else: data.buildings[id].owned = true
	dirty = true
	if not save():
		data = previous
		dirty = true
		return false
	return true

func weapon_multiplier(id: String) -> float:
	return pow(1.1,level(id)) if id in WEAPONS else 1.0

func building_multiplier(id: String) -> float:
	return pow(1.1,level(id))

func max_health() -> int: return 100+10*level("strong")
func regen_rate() -> float: return float(level("strong"))
func head_multiplier() -> float: return 1.0+.1*level("precise")
func move_multiplier() -> float: return 1.0+.05*level("swift")
func reserve_multiplier() -> float: return 1.0+.1*level("supply")
func grenade_capacity() -> int: return 1+level("grenade")
