extends RefCounted
## Threat points replace ordinary bodies, never add elites on top of the budget.
const COST = {"normal":1,"crawler":1,"cone":2,"bucket":4,"imp":4,"shield":8,"berserker":12}
const SPECIALS = ["cone","bucket","imp","shield","berserker"]

static func points(roster: Array) -> int:
	var total = 0
	for kind in roster: total += int(COST.get(kind,0))
	return total

static func roster(budget: int, kinds: Array, random: RandomNumberGenerator, fraction := .5) -> Array:
	var result: Array = []
	var allowance = floori(budget*clampf(fraction,0,1))
	var pool: Array = []
	for kind in kinds:
		if kind in SPECIALS and not pool.has(kind): pool.append(kind)
	# One of each affordable eligible type before repeats. Route-level coverage
	# is verified across habitats; a single habitat need not afford every type.
	while not pool.is_empty():
		var spent = 0
		for kind in pool:
			var cost: int = COST[kind]
			if cost > allowance: continue
			result.append(kind)
			allowance -= cost
			spent += cost
		if spent == 0: break
	var used = points(result)
	for i in maxi(0,budget-used): result.append("normal")
	for i in result.size():
		var other = random.randi_range(i,result.size()-1)
		var swap = result[i]
		result[i] = result[other]
		result[other] = swap
	return result
