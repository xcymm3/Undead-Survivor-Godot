extends RefCounted
const Policy = preload("res://scripts/cpu_policy.gd")
const Recorder = preload("res://scripts/stutter_log.gd")
var pending: Dictionary = {}
var ready: Dictionary = {}
var clock = -INF
var used = 0
var peak = 0
var revision = -1

func begin(now: float, world) -> void:
	if revision != world.navigation_revision:
		Recorder.path_event("queue_navigation_invalidated",{"old_revision":revision,"revision":world.navigation_revision,"pending":pending.size(),"ready":ready.size()})
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
		ready[job.key] = execute(job,now,world)
		pending.erase(job.key)
		used += 1
	peak = maxi(peak,used)

func execute(job: Dictionary, now: float, world) -> Dictionary:
	var details: Dictionary = {}
	if Recorder.tracing():
		details = job.get("details",{}).duplicate()
		details.merge({"purpose":details.get("purpose",str(job.key).get_slice(":",0)),"enemy_id":int(str(job.key).get_slice(":",1)),
			"queue_age_ms":maxf(0,now-job.created)*1000,"pending":pending.size(),"used_this_tick":used,"simulation_time":now},true)
	return {"goal":job.goal,"from":job.from,"path":world.path_to(job.from,job.goal,details)}

func request(key: String, from: Vector2, goal: Vector2, priority: float, now: float, world, details: Dictionary = {}) -> Dictionary:
	var job = {"key":key,"from":from,"goal":goal,"priority":priority,"created":now,"details":details}
	if not Policy.PATH_BUDGET: return execute(job,now,world)
	begin(now,world)
	if ready.has(key):
		var result: Dictionary = ready[key]
		ready.erase(key)
		if result.goal.distance_squared_to(goal) < .01 or world.nearest_cell(result.goal) == world.nearest_cell(goal): return result
		Recorder.path_event("queued_goal_discarded",{"enemy_id":int(key.get_slice(":",1)),"purpose":key.get_slice(":",0),"old_goal":[result.goal.x,result.goal.y],"goal":[goal.x,goal.y]})
	if used < Policy.PATHS_PER_TICK:
		used += 1
		peak = maxi(peak,used)
		return execute(job,now,world)
	var created = pending.get(key,{}).get("created",now)
	job.created = created
	pending[key] = job
	Recorder.path_event("query_deferred",{"enemy_id":int(key.get_slice(":",1)),"purpose":key.get_slice(":",0),"pending":pending.size()})
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
