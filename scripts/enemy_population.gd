extends RefCounted
## Equal budget shares with integer body counts and one-point remainder fill.
const POINT_SCALE = 4
const COST = {"normal":1,"crawler":1,"cone":1,"bucket":1,"imp":3,"shield":4,"berserker":8,"giant":8,"football":12}
const ORDINARY = ["normal","cone","bucket"]
const ELITES = ["imp","shield","berserker","giant"]
const PARTY_MULTIPLIER = [1.0,1.2,1.4,1.6]

static func party_multiplier(party_size: int) -> float:
	return PARTY_MULTIPLIER[clampi(party_size,1,PARTY_MULTIPLIER.size())-1]

static func population_kind(kind: String) -> String:
	# Legacy crawler slots become normal zombies; special types keep their slots.
	return "normal" if kind == "crawler" else kind

static func point_units(roster: Array) -> int:
	var total = 0
	for kind in roster: total += roundi(float(COST.get(kind,0))*POINT_SCALE)
	return total

static func points(roster: Array) -> float:
	return float(point_units(roster))/POINT_SCALE

static func roster(budget: int, kinds: Array, random: RandomNumberGenerator) -> Array:
	var pool: Array = []
	var fillers: Array = []
	for kind in kinds:
		if kind == "crawler" or not COST.has(kind) or pool.has(kind): continue
		pool.append(kind)
		if COST[kind] == 1: fillers.append(kind)
	var result: Array = []
	if pool.is_empty(): return result
	var remaining = maxi(0,budget)
	for kind in pool:
		# Floor each equal share before redistributing any unspent points.
		var count = floori(float(maxi(0,budget))/float(pool.size()*COST[kind]))
		for index in count: result.append(kind)
		remaining -= count*int(COST[kind])
	# Only one-point types in this wave may receive the rounding remainder.
	if not fillers.is_empty():
		for index in remaining: result.append(fillers[index % fillers.size()])
	for i in result.size():
		var other = random.randi_range(i,result.size()-1)
		var swap = result[i]
		result[i] = result[other]
		result[other] = swap
	return result
