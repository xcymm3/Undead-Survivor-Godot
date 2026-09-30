extends RefCounted
## Quarter-point accounting keeps ordinary discounts exact without float drift.
const POINT_SCALE = 4
const COST = {"normal":.75,"crawler":.75,"cone":1,"bucket":1,"imp":4,"shield":6,"berserker":12,"giant":12}
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

static func roster(budget: int, kinds: Array, random: RandomNumberGenerator, fraction := .25, advanced_fraction := 0.0) -> Array:
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
	var remaining = maxi(0,total_units-used)
	var ratio = clampf(advanced_fraction,0,1) if "cone" in kinds and "bucket" in kinds else 0.0
	# Find the largest common horde matching the requested body-count share.
	# Both armored common types cost one point; rounding is in bodies, not points.
	var lower = 0
	var upper = floori(float(remaining)/ordinary_units)
	while lower < upper:
		var count = ceili(float(lower+upper)/2)
		var advanced = roundi(count*ratio)
		var units = (count-advanced)*ordinary_units+advanced*POINT_SCALE
		if units <= remaining: lower = count
		else: upper = count-1
	var advanced = roundi(lower*ratio)
	var buckets = roundi(float(advanced)/3)
	for i in lower-advanced: result.append("normal")
	for i in advanced-buckets: result.append("cone")
	for i in buckets: result.append("bucket")
	remaining -= (lower-advanced)*ordinary_units+advanced*POINT_SCALE
	# Spend any integer-rounding remainder on normals without exceeding budget.
	for i in floori(float(remaining)/ordinary_units): result.append("normal")
	for i in result.size():
		var other = random.randi_range(i,result.size()-1)
		var swap = result[i]
		result[i] = result[other]
		result[other] = swap
	return result
