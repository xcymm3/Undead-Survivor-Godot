extends RefCounted
## Crystal Defense shares its budget equally across the authored wave types.
const Population = preload("res://scripts/enemy_population.gd")
const WAVE_BUDGETS = [20,25,45,100,100,125,125,150,180,150]
const DIFFICULTIES = ["easy","normal","hard"]
const DIFFICULTY_MULTIPLIERS = {"easy":.7,"normal":1.0,"hard":1.3}
const DIFFICULTY_LABELS = {"easy":"简单","normal":"普通","hard":"困难"}

static func normalize_difficulty(value: String) -> String:
	return value if value in DIFFICULTIES else "normal"

static func difficulty_multiplier(value: String) -> float:
	return float(DIFFICULTY_MULTIPLIERS[normalize_difficulty(value)])

static func difficulty_label(value: String) -> String:
	return str(DIFFICULTY_LABELS[normalize_difficulty(value)])

static func normal_budget(wave: int, _party_size: int) -> int:
	return WAVE_BUDGETS[clampi(wave,1,10)-1]

static func budget(wave: int, party_size: int, difficulty := "normal") -> int:
	return roundi(normal_budget(wave,party_size)*difficulty_multiplier(difficulty))

const WAVE_KINDS = [
	["normal"],
	["normal","cone"],
	["normal","cone","bucket"],
	["cone","imp"],
	["cone","bucket","shield"],
	["bucket","shield","imp"],
	["bucket","giant"],
	["bucket","shield","imp","berserker"],
	["shield","football","berserker","giant","imp","bucket"],
	["football","berserker","giant","imp","bucket"]
]

static func kinds(wave: int) -> Array:
	return WAVE_KINDS[clampi(wave,1,10)-1].duplicate()

static func roster(wave: int, party_size: int, random: RandomNumberGenerator, difficulty := "normal") -> Array:
	var result: Array = Population.roster(budget(wave,party_size,difficulty),kinds(wave),random)
	if wave == 10: result.push_front("dancer")
	return result
