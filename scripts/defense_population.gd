extends RefCounted
## Crystal Defense spends a bounded quarter-point budget per wave. Authored
## football bosses are added afterward and never consume this budget.
const Population = preload("res://scripts/enemy_population.gd")
const INITIAL_BUDGET = 138
const INITIAL_GROWTH = 31
const GROWTH_DECAY = .92
const GROWTH_OFFSET = 3
const MIN_GROWTH = 5
const FULL_SPECIAL_WAVE = 10
const INITIAL_SPECIAL_FRACTION = .25
const FINAL_SPECIAL_FRACTION = .5
const INITIAL_ADVANCED_FRACTION = .1
const FINAL_ADVANCED_FRACTION = .6
const FINAL_BUDGET_MULTIPLIER = .85
const DIFFICULTIES = ["easy","normal","hard"]
const DIFFICULTY_MULTIPLIERS = {"easy":.7,"normal":1.0,"hard":1.3}
const DIFFICULTY_LABELS = {"easy":"简单","normal":"普通","hard":"困难"}

static func normalize_difficulty(value: String) -> String:
	return value if value in DIFFICULTIES else "normal"

static func difficulty_multiplier(value: String) -> float:
	return float(DIFFICULTY_MULTIPLIERS[normalize_difficulty(value)])

static func difficulty_label(value: String) -> String:
	return str(DIFFICULTY_LABELS[normalize_difficulty(value)])

static func progression(wave: int) -> float:
	return clampf(float(wave-1)/float(FULL_SPECIAL_WAVE-1),0.0,1.0)

static func special_fraction(wave: int) -> float:
	return lerpf(INITIAL_SPECIAL_FRACTION,FINAL_SPECIAL_FRACTION,progression(wave))

static func advanced_fraction(wave: int) -> float:
	return lerpf(INITIAL_ADVANCED_FRACTION,FINAL_ADVANCED_FRACTION,progression(wave))

static func budget_multiplier(wave: int) -> float:
	return lerpf(1.0,FINAL_BUDGET_MULTIPLIER,progression(wave))

static func base_budget(wave: int) -> int:
	var target_wave = maxi(1,wave)
	var total = INITIAL_BUDGET
	var current = 2
	while current <= target_wave:
		var growth = maxi(MIN_GROWTH,roundi(INITIAL_GROWTH*pow(GROWTH_DECAY,current-2+GROWTH_OFFSET)))
		# Once the minimum is reached, sum the entire tail directly. Even a
		# very high wave evaluates only the short initial growth curve.
		if growth == MIN_GROWTH: return total+(target_wave-current+1)*MIN_GROWTH
		total += growth
		current += 1
	return total

static func normal_budget(wave: int, party_size: int) -> int:
	return roundi(base_budget(wave)*Population.party_multiplier(party_size)*budget_multiplier(wave))

static func budget(wave: int, party_size: int, difficulty := "normal") -> int:
	return roundi(normal_budget(wave,party_size)*difficulty_multiplier(difficulty))

static func footballs(wave: int, party_size: int) -> int:
	return maxi(1,party_size) if wave in [6,7] else maxi(1,party_size)*2 if wave >= 8 else 0

static func kinds(wave: int) -> Array:
	if wave <= 2: return ["cone","bucket"]
	if wave <= 4: return ["cone","bucket","imp","shield"]
	return ["cone","bucket","imp","shield","berserker","giant"]

static func roster(wave: int, party_size: int, random: RandomNumberGenerator, difficulty := "normal") -> Array:
	var required_footballs := footballs(wave,party_size)
	var result: Array = Population.roster(budget(wave,party_size,difficulty),kinds(wave),random,special_fraction(wave),advanced_fraction(wave))
	# Spread the authored bosses through the ordinary roster so multiplayer
	# waves do not release all of them together. Bosses spend no threat points.
	var ordinary_count := result.size()
	for index in required_footballs:
		result.insert(roundi(ordinary_count*float(index+1)/float(required_footballs+1))+index,"football")
	return result
