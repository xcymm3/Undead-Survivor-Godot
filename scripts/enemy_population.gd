extends RefCounted
## Quarter-point accounting keeps ordinary discounts exact without float drift.
const POINT_SCALE = 4
const COST = {"normal":.75,"crawler":.75,"cone":2,"bucket":4,"imp":4,"shield":6,"berserker":12,"giant":12}
const ELITES = ["cone","bucket","imp","shield","berserker","giant"]
const PARTY_MULTIPLIER = [1.0,1.2,1.4,1.6]
const CRAWLER_INTERVAL = 20

static func party_multiplier(party_size: int) -> float:
	return PARTY_MULTIPLIER[clampi(party_size,1,PARTY_MULTIPLIER.size())-1]

static func population_kind(kind: String, ordinary_slot: int) -> String:
	return "crawler" if kind == "normal" and ordinary_slot%CRAWLER_INTERVAL == 0 else kind

static func point_units(roster: Array) -> int:
	var total = 0
	for kind in roster: total += roundi(float(COST.get(kind,0))*POINT_SCALE)
	return total

static func points(roster: Array) -> float:
	return float(point_units(roster))/POINT_SCALE

static func roster(budget: int, kinds: Array, random: RandomNumberGenerator, fraction := .25) -> Array:
	var result: Array = []
	var total_units = budget*POINT_SCALE
	var allowance = floori(total_units*clampf(fraction,0,1))
	var pool: Array = []
	for kind in kinds:
		if kind in ELITES and not pool.has(kind): pool.append(kind)
	# Spend the elite allowance without exceeding the wave budget.
	while not pool.is_empty():
		var spent = 0
		for kind in pool:
			var cost = roundi(float(COST[kind])*POINT_SCALE)
			if cost > allowance: continue
			result.append(kind)
			allowance -= cost
			spent += cost
		if spent == 0: break
	var used = point_units(result)
	var ordinary_units = roundi(COST.normal*POINT_SCALE)
	for i in maxi(0,floori(float(total_units-used)/ordinary_units)): result.append("normal")
	for i in result.size():
		var other = random.randi_range(i,result.size()-1)
		var swap = result[i]
		result[i] = result[other]
		result[other] = swap
	return result
