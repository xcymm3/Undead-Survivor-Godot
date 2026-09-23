extends RefCounted
## Crystal Defense spends one exact ordinary-enemy budget per wave. Authored
## football bosses are added afterward and never consume this budget.
const Population = preload("res://scripts/night_population.gd")
const BASE_BUDGET = [52,83,111,138,162,184,205,223,239,253]
const DIFFICULTIES = ["easy","normal","hard"]
const DIFFICULTY_MULTIPLIERS = {"easy":.7,"normal":1.0,"hard":1.3}
const DIFFICULTY_LABELS = {"easy":"简单","normal":"普通","hard":"困难"}

static func normalize_difficulty(value: String) -> String:
	return value if value in DIFFICULTIES else "normal"

static func difficulty_multiplier(value: String) -> float:
	return float(DIFFICULTY_MULTIPLIERS[normalize_difficulty(value)])

static func difficulty_label(value: String) -> String:
	return str(DIFFICULTY_LABELS[normalize_difficulty(value)])

static func normal_budget(wave: int, party_size: int) -> int:
	var base: int = BASE_BUDGET[clampi(wave,1,BASE_BUDGET.size())-1]
	return roundi(base*Population.party_multiplier(party_size))

static func budget(wave: int, party_size: int, difficulty := "normal") -> int:
	return roundi(normal_budget(wave,party_size)*difficulty_multiplier(difficulty))

static func footballs(wave: int) -> int:
	return 1 if wave in [7,8] else 2 if wave in [9,10] else 0

static func kinds(wave: int) -> Array:
	if wave <= 2: return ["cone","bucket"]
	if wave <= 4: return ["cone","bucket","imp","shield"]
	return ["cone","bucket","imp","shield","berserker","giant"]

static func roster(wave: int, party_size: int, random: RandomNumberGenerator, difficulty := "normal") -> Array:
	var required_footballs := footballs(wave)
	var result: Array = Population.roster(budget(wave,party_size,difficulty),kinds(wave),random)
	# Boss positions are authored as wave progress, keeping two football zombies
	# separated instead of letting the random shuffle release both together.
	if required_footballs == 1:
		result.insert(roundi(result.size()*.6),"football")
	elif required_footballs == 2:
		result.insert(roundi(result.size()*.4),"football")
		result.insert(roundi(result.size()*.75),"football")
	return result
