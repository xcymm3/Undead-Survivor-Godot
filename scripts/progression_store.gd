extends RefCounted
## Permanent economy, separate from the disposable combat simulation.
const MAX_CURRENCY = 9000000000000000
const SAVE_VERSION = 10
const DEATH_BONUS = 25
const MAX_UPGRADE_LEVEL = 10
const UPGRADE_PRICES = [25,100,150,200,300,450,650,1000,1500,2000]
const TALENT_PRICES = [1,2,3,4,5]
const GATE_BASE_HEALTH = 500
const ULTIMATE_PRICES = [250,500,1000,2000]
const GRENADE_PRICES = [300,450,650,1000]
const MINE_PRICES = {"crystal_mine":25,"gate_mine":200,"ramp_mine":650}
const MAGAZINES = ["rifle_magazine","pistol_magazine"]
const WEAPONS = ["rifle","pistol","axe"]
const OLD_WEAPONS = ["rifle","revolver","axe"]
const LEGACY_TALENTS = ["strong","precise","swift","supply"]
const TALENTS = ["strong","precise","swift","supply","greed"]
const LEGACY_BUILDINGS = ["turret_left","turret_right","bridge_gate"]
const GATES = ["bridge_gate","bridge_entry_gate"]
const BUILDINGS = ["turret_left","turret_right","bridge_gate","bridge_entry_gate"]
const MINES = ["crystal_mine","ramp_mine","gate_mine"]
const COIN_REWARDS = {"normal":1,"cone":2,"bucket":5,"imp":10,"shield":25,"berserker":100,"giant":150,"football":250,"dancer":2000}
var path = ""
var dirty = false
var notice = ""
var data: Dictionary = defaults()

static func defaults() -> Dictionary:
	return {"version":SAVE_VERSION,"ultimate_choice":"","total_coins_earned":0.0,"total_diamonds_earned":0,"victories":0,"ultimate_unlocked":false,"intro_seen":false,"tutorial_stage":0,"tutorial_blueprint_paid":false,"ultimate_level":0,"coins":0,"diamonds":0,"grenade_level":0,"magazines":{"rifle_magazine":0,"pistol_magazine":0},"weapons":{"rifle":0,"pistol":0,"axe":0},"talents":{"strong":0,"precise":0,"swift":0,"supply":0,"greed":0},"buildings":{"turret_left":{"owned":false,"level":0},"turret_right":{"owned":false,"level":0},"bridge_gate":{"owned":false,"level":0},"bridge_entry_gate":{"owned":false,"level":0}},"mines":{"crystal_mine":false,"ramp_mine":false,"gate_mine":false},"best_wave":0,"cleared_total":0}

func _init(save_path := "") -> void:
	path = save_path
	if not path.is_empty(): load_save()

static func bounded_integer(value, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value <= maximum and float(value) == floor(float(value))

static func valid(value) -> bool:
	if not value is Dictionary or not value.has_all(["version","coins","diamonds","grenade_level","weapons","talents","buildings","best_wave","cleared_total"]) or not bounded_integer(value.version,SAVE_VERSION) or value.version < 1: return false
	if value.has("tutorial_stage") and not bounded_integer(value.tutorial_stage,5): return false
	if value.has("tutorial_blueprint_paid") and not value.tutorial_blueprint_paid is bool: return false
	if value.version >= 8 and not value.get("ultimate_unlocked") is bool: return false
	if value.version >= 10 and value.get("ultimate_choice") not in ["","blade"]: return false
	if value.has("intro_seen") and not value.intro_seen is bool: return false
	if not (value.coins is int or value.coins is float) or not is_finite(float(value.coins)) or value.coins < 0 or value.coins > MAX_CURRENCY: return false
	if value.version < 7 and not bounded_integer(value.coins,MAX_CURRENCY): return false
	if value.version >= 9:
		var total = value.get("total_coins_earned")
		if not (total is int or total is float) or not is_finite(float(total)) or total < 0 or total > MAX_CURRENCY: return false
		for key in ["total_diamonds_earned","victories"]:
			if not bounded_integer(value.get(key),MAX_CURRENCY): return false
	for key in ["diamonds","best_wave","cleared_total"]:
		if not bounded_integer(value[key],MAX_CURRENCY): return false
	if not bounded_integer(value.grenade_level,4): return false
	if not value.weapons is Dictionary or not value.talents is Dictionary or not value.buildings is Dictionary: return false
	for key in OLD_WEAPONS if value.version < 3 else WEAPONS:
		if not value.weapons.has(key) or not bounded_integer(value.weapons[key],48 if value.version < 4 else MAX_UPGRADE_LEVEL): return false
	for key in LEGACY_TALENTS if value.version < 7 else TALENTS:
		if not value.talents.has(key) or not bounded_integer(value.talents[key],10 if value.version < 5 else TALENT_PRICES.size()): return false
	for key in LEGACY_BUILDINGS if value.version == 1 else BUILDINGS:
		var entry = value.buildings.get(key)
		if not entry is Dictionary or not entry.has_all(["owned","level"]) or not entry.owned is bool or not bounded_integer(entry.level,48 if value.version < 4 else MAX_UPGRADE_LEVEL) or (not entry.owned and entry.level != 0): return false
	if value.version >= 2:
		if not value.get("mines") is Dictionary: return false
		for key in MINES:
			if not value.mines.get(key) is bool: return false
	if value.version >= 4:
		if not value.get("magazines") is Dictionary: return false
		for key in MAGAZINES:
			if not bounded_integer(value.magazines.get(key),MAX_UPGRADE_LEVEL): return false
	if value.version >= 6 and not bounded_integer(value.get("ultimate_level"),4): return false
	return true

func read_save(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path): return {}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path)) != OK: return {}
	var parsed = parser.data
	if not valid(parsed): return {}
	# JSON numbers deserialize as floats. Restore validated integer fields before
	# migration so a second reload has exactly the same permanent state.
	for key in ["version","diamonds","best_wave","cleared_total","grenade_level"]: parsed[key] = int(parsed[key])
	if parsed.version >= 9:
		for key in ["total_diamonds_earned","victories"]: parsed[key] = int(parsed[key])
	if parsed.version >= 6: parsed.ultimate_level = int(parsed.ultimate_level)
	if parsed.has("tutorial_stage"): parsed.tutorial_stage = int(parsed.tutorial_stage)
	for key in OLD_WEAPONS if parsed.version < 3 else WEAPONS: parsed.weapons[key] = int(parsed.weapons[key])
	for key in LEGACY_TALENTS if parsed.version < 7 else TALENTS: parsed.talents[key] = int(parsed.talents[key])
	for key in LEGACY_BUILDINGS if parsed.version == 1 else BUILDINGS: parsed.buildings[key].level = int(parsed.buildings[key].level)
	if parsed.version >= 4:
		for key in MAGAZINES: parsed.magazines[key] = int(parsed.magazines[key])
	return parsed

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
	if not loaded.is_empty():
		data = loaded
		# Existing saves keep their access; new saves start the staged tutorial.
		if not data.has("tutorial_stage"):
			data["tutorial_stage"] = 5 if data.get("intro_seen",false) or data.coins > 0 or data.cleared_total > 0 or data.weapons.values().any(func(level): return level > 0) else 0
			data["tutorial_blueprint_paid"] = false
			dirty = true
		if data.version == 1:
			# The old mine was free. Preserve its ownership once when migrating.
			data.version = 2
			data.buildings.bridge_entry_gate = {"owned":false,"level":0}
			data.mines = defaults().mines
			data.mines.crystal_mine = true
			dirty = true
		if data.version == 2:
			data.weapons.pistol = data.weapons.revolver
			data.weapons.erase("revolver")
			data.version = 3
			dirty = true

		if data.version == 3:
			data.magazines = defaults().magazines
			for key in WEAPONS: data.weapons[key] = mini(MAX_UPGRADE_LEVEL,int(data.weapons[key]))
			for key in BUILDINGS: data.buildings[key].level = mini(MAX_UPGRADE_LEVEL,int(data.buildings[key].level))
			data.version = 4
			dirty = true

		if data.version == 4:
			for key in LEGACY_TALENTS: data.talents[key] = mini(TALENT_PRICES.size(),int(data.talents[key]))
			data.version = 5
			dirty = true
		if data.version == 5:
			data.ultimate_level = 0
			data.version = 6
			dirty = true

		if data.version == 6:
			# Existing precise/swift levels now grant instinct/cooldown effects.
			data.talents["greed"] = 0
			data.version = 7
			dirty = true

		if data.version == 7:
			# Veterans retain access; untouched saves still experience the unlock beat.
			data["ultimate_unlocked"] = data.get("ultimate_level",0) > 0 or data.get("tutorial_stage",0) > 0 or data.best_wave > 0 or data.cleared_total > 0 or data.coins > 0 or data.grenade_level > 0 or data.weapons.values().any(func(rank): return rank > 0) or data.talents.values().any(func(rank): return rank > 0)
			data.version = 8
			dirty = true

		if data.version == 8:
			# Earlier saves contain balances and cleared waves, not lifetime earnings/wins.
			data["total_coins_earned"] = float(data.coins)
			data["total_diamonds_earned"] = int(data.diamonds)
			data["victories"] = 0
			data.version = 9
			dirty = true
		if data.version == 9:
			# Existing played saves retain the only previously available ultimate.
			data["ultimate_choice"] = "blade" if data.get("intro_seen",false) or data.get("tutorial_stage",0) > 0 or data.coins > 0 or data.best_wave > 0 or data.ultimate_unlocked else ""
			data.version = SAVE_VERSION
			dirty = true

func needs_ultimate_choice() -> bool:
	return data.get("ultimate_choice","").is_empty()

func select_ultimate(id: String) -> bool:
	if id != "blade": return false
	var previous: Dictionary = data.duplicate(true)
	var was_dirty = dirty
	data.ultimate_choice = id
	data.intro_seen = true
	dirty = true
	if save():
		notice = ""
		return true
	data = previous
	dirty = was_dirty
	notice = "终极武器选择保存失败，请重试"
	return false

func save() -> bool:
	var stamp = preload("res://scripts/stutter_log.gd").begin()
	var result = _save_measured()
	preload("res://scripts/stutter_log.gd").end("save",stamp)
	return result

func _save_measured() -> bool:
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

func award_coins(amount: float) -> float:
	var reward = maxf(0,snappedf(amount,.1))
	data.coins = minf(MAX_CURRENCY,snappedf(float(data.coins)+reward,.1))
	data.total_coins_earned = minf(MAX_CURRENCY,snappedf(float(data.total_coins_earned)+reward,.1))
	dirty = true
	return reward

func award_kill(kind: String) -> float:
	return award_coins(float(COIN_REWARDS.get(kind,1))*coin_multiplier())

func award_victory() -> void:
	data.victories = mini(MAX_CURRENCY,int(data.victories)+1)
	dirty = true

func award_wave(wave: int) -> void:
	data.diamonds = mini(MAX_CURRENCY,int(data.diamonds)+1)
	data.total_diamonds_earned = mini(MAX_CURRENCY,int(data.total_diamonds_earned)+1)
	data.cleared_total = mini(MAX_CURRENCY,int(data.cleared_total)+1)
	data.best_wave = maxi(int(data.best_wave),wave)
	dirty = true
	save()

func level(id: String) -> int:
	if id in WEAPONS: return int(data.weapons[id])
	if id in MAGAZINES: return int(data.magazines[id])
	if id in TALENTS: return int(data.talents[id])
	if id == "grenade": return int(data.grenade_level)
	if id == "ultimate": return int(data.get("ultimate_level",0))
	if id in BUILDINGS: return int(data.buildings[id].level)
	return 0

func owned(id: String) -> bool:
	if id in MINES: return data.mines[id]
	return id in BUILDINGS and data.buildings[id].owned

func currency(id: String) -> String:
	return "diamonds" if id in TALENTS else "coins"

func cost(id: String) -> int:
	if id in MINES: return -1 if owned(id) else int(MINE_PRICES[id])
	if id in TALENTS: return int(TALENT_PRICES[level(id)]) if level(id) < TALENT_PRICES.size() else -1
	if id in ["grenade","ultimate"]:
		var prices = ULTIMATE_PRICES if id == "ultimate" else GRENADE_PRICES
		return int(prices[level(id)]) if level(id) < prices.size() else -1
	elif id in BUILDINGS:
		if not owned(id): return 25
	elif id not in WEAPONS and id not in MAGAZINES: return -1
	return int(UPGRADE_PRICES[level(id)]) if level(id) < MAX_UPGRADE_LEVEL else -1

func purchase(id: String) -> bool:
	var price = cost(id)
	var wallet = currency(id)
	if price < 0 or data[wallet] < price: return false
	var previous = data.duplicate(true)
	data[wallet] = data[wallet]-price
	if id in WEAPONS: data.weapons[id] = level(id)+1
	elif id in MAGAZINES: data.magazines[id] = level(id)+1
	elif id in TALENTS: data.talents[id] = level(id)+1
	elif id == "grenade": data.grenade_level = level(id)+1
	elif id == "ultimate": data.ultimate_level = level(id)+1
	elif id in MINES: data.mines[id] = true
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
	return pow(1.25 if id in ["rifle","pistol"] else 1.2,level(id)) if id in WEAPONS else 1.0

func building_multiplier(id: String) -> float:
	return pow(1.25,level(id))

func max_health() -> int: return 100+10*level("strong")
func regen_rate() -> float: return .5*level("strong")
func damage_multiplier() -> float: return 1.0+.1*level("precise")
func ultimate_cooldown_multiplier() -> float: return 1.0-.1*level("swift")
func reserve_magazines() -> int: return 6+2*level("supply")
func coin_multiplier() -> float: return 1.0+.2*level("greed")
func grenade_capacity() -> int: return level("grenade")

func magazine_capacity(weapon: String, base: int, rank := -1) -> int:
	var upgrade_rank = level(weapon+"_magazine") if rank < 0 else rank
	return base+int({"rifle":5,"pistol":3}.get(weapon,0))*upgrade_rank
