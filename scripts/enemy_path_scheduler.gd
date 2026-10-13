extends RefCounted
const Policy = preload("res://scripts/cpu_policy.gd")
var pending: Dictionary = {}
var ready: Dictionary = {}
var clock = -INF
var used = 0
var peak = 0
var revision = -1

func begin(now: float, world) -> void:
	if revision != world.navigation_revision:
		revision = world.navigation_revision
		pending.clear()
		ready.clear()
	if clock == now: return
	clock = now
	used = 0
	var jobs: Array = pending.values()
	# Age prevents starvation; blocked and nearby enemies get earlier service.
	jobs.sort_custom(func(a,b): return a.priority+(now-a.created)*100 > b.priority+(now-b.created)*100)
	for job in jobs:
		if used >= Policy.PATHS_PER_TICK: break
		ready[job.key] = {"goal":job.goal,"path":world.path_to(job.from,job.goal)}
		pending.erase(job.key)
		used += 1
	peak = maxi(peak,used)

func request(key: String, from: Vector2, goal: Vector2, priority: float, now: float, world) -> Dictionary:
	if not Policy.PATH_BUDGET: return {"path":world.path_to(from,goal)}
	begin(now,world)
	if ready.has(key):
		var result: Dictionary = ready[key]
		ready.erase(key)
		if result.goal.distance_squared_to(goal) < .01 or world.nearest_cell(result.goal) == world.nearest_cell(goal): return result
	if used < Policy.PATHS_PER_TICK:
		used += 1
		peak = maxi(peak,used)
		return {"path":world.path_to(from,goal)}
	var created = pending.get(key,{}).get("created",now)
	pending[key] = {"key":key,"from":from,"goal":goal,"priority":priority,"created":created}
	return {}

func clear() -> void:
	pending.clear()
	ready.clear()
	clock = -INF
	revision = -1

func prune(alive: Dictionary) -> void:
	for queue in [pending,ready]:
		for key in queue.keys():
			if not alive.has(int(key.get_slice(":",1))): queue.erase(key)
