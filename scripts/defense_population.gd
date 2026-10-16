extends RefCounted
## Crystal Defense shares its budget equally across the authored wave types.
const Population = preload("res://scripts/enemy_population.gd")
const INITIAL_BUDGET = 138
const INITIAL_GROWTH = 31
const GROWTH_DECAY = .92
const GROWTH_OFFSET = 3
const MIN_GROWTH = 5
const FINAL_BALANCE_WAVE = 10
const FINAL_BUDGET_MULTIPLIER = .85
const WAVE_BUDGET_SCALE = .5
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
	return clampf(float(wave-1)/float(FINAL_BALANCE_WAVE-1),0.0,1.0)

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
	return floori(roundi(normal_budget(wave,party_size)*difficulty_multiplier(difficulty))*WAVE_BUDGET_SCALE)

const WAVE_KINDS = [
	["normal"],
	["normal","cone"],
	["normal","cone","bucket"],
	["cone","imp"],
	["cone","bucket","shield"],
	["bucket","shield","imp"],
	["cone","bucket","giant"],
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
