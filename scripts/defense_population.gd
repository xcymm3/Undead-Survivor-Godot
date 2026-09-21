extends RefCounted
## Crystal Defense spends one exact ordinary-enemy budget per wave. Authored
## football bosses are added afterward and never consume this budget.
const COST = {
	"normal":1,
	"crawler":1,
	"cone":2,
	"bucket":4,
	"imp":4,
	"shield":8,
	"berserker":12,
	"giant":12,
	"football":24,
}
const BASE_BUDGET = [15,25,52,66,126,150,234,258,350,374]
const PARTY_MULTIPLIER = [1.0,1.35,1.65,1.9]
const CRAWLER_CHANCE = .1

static func budget(wave: int, party_size: int) -> int:
	var base: int = BASE_BUDGET[clampi(wave,1,BASE_BUDGET.size())-1]
	return roundi(base*PARTY_MULTIPLIER[clampi(party_size,1,PARTY_MULTIPLIER.size())-1])

static func footballs(wave: int) -> int:
	return 1 if wave in [7,8] else 2 if wave in [9,10] else 0

static func weights(wave: int) -> Dictionary:
	if wave <= 2: return {"normal":.60,"cone":.27,"bucket":.13}
	if wave <= 4: return {"normal":.48,"cone":.216,"bucket":.104,"imp":.12,"shield":.08}
	if wave <= 6: return {"normal":.384,"cone":.1728,"bucket":.0832,"imp":.156,"shield":.104,"berserker":.075,"giant":.025}
	if wave <= 8: return {"normal":.30,"cone":.135,"bucket":.065,"imp":.168,"shield":.112,"berserker":.1275,"giant":.0425}
	return {"normal":.228,"cone":.1026,"bucket":.0494,"imp":.18,"shield":.12,"berserker":.18,"giant":.06}

static func points(result: Array) -> int:
	var total = 0
	for kind in result: total += int(COST.get(kind,0))
	return total

static func budget_points(result: Array) -> int:
	var total = 0
	for kind in result:
		if kind != "football": total += int(COST.get(kind,0))
	return total

static func pick(pool: Array, table: Dictionary, random: RandomNumberGenerator) -> String:
	var total = 0.0
	for kind in pool: total += float(table[kind])
	var roll: float = random.randf()*total
	for kind in pool:
		roll -= float(table[kind])
		if roll < 0: return kind
	return pool[-1]

static func shuffle(result: Array, random: RandomNumberGenerator) -> void:
	for i in result.size():
		var other := random.randi_range(i,result.size()-1)
		var swap = result[i]
		result[i] = result[other]
		result[other] = swap

static func roster(wave: int, party_size: int, random: RandomNumberGenerator) -> Array:
	var required_footballs := footballs(wave)
	var remaining := budget(wave,party_size)
	var table := weights(wave)
	var result: Array = []
	while remaining > 0:
		var affordable: Array = []
		for kind in table:
			if COST[kind] <= remaining: affordable.append(kind)
		var kind := pick(affordable,table,random)
		remaining -= COST[kind]
		if kind == "normal" and random.randf() < CRAWLER_CHANCE: kind = "crawler"
		result.append(kind)
	shuffle(result,random)
	# Boss positions are authored as wave progress, keeping two football zombies
	# separated instead of letting the random shuffle release both together.
	if required_footballs == 1:
		result.insert(roundi(result.size()*.6),"football")
	elif required_footballs == 2:
		result.insert(roundi(result.size()*.4),"football")
		result.insert(roundi(result.size()*.75),"football")
	return result
