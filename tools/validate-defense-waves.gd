extends SceneTree
## Validate quarter-point composition and thirty-second bursts, then observe a
## normal solo first wave through the real authority physics and structures.
const Population = preload("res://scripts/enemy_population.gd")
const Defense = preload("res://scripts/defense_population.gd")
var checks = 0
var failures = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if value: print("PASS: "+message)
	else:
		failures += 1
		push_error("FAIL: "+message)

func counts(value: Array) -> Dictionary:
	var result = {}
	for kind in value: result[kind] = result.get(kind,0)+1
	return result

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	root.get_node("Data").settings.defense_difficulty = "normal"
	game.start_solo("defense",20260928)
	game.running = false
	await physics_frame
	var sim = game.sim
	var planner = sim.defense_spawner
	for count in [1,3,7,20,150,151,300,1000]:
		planner.reset(count)
		var previous = 0
		var complete = true
		for batch in range(1,planner.batches+1):
			var quota: int = planner.scheduled_count(planner.interval*batch)
			complete = complete and quota > previous and quota-previous <= planner.batch_size
			previous = quota
		check(complete and previous == count and planner.scheduled_count(29.999) < count and planner.scheduled_count(30) == count,"Dynamic batches release all %d bodies at thirty seconds without oversized bursts" % count)
	var composition_valid = true
	var crawler_free = true
	var late_special_share = true
	var advanced_share_valid = true
	check(Population.COST.cone == 1 and Population.COST.bucket == 1 and "cone" in Population.ORDINARY and "bucket" in Population.ORDINARY and not "cone" in Population.ELITES and not "bucket" in Population.ELITES,"Cones and buckets are ordinary zombies costing one point each")
	for wave in range(1,31):
		check(is_equal_approx(Defense.advanced_fraction(wave),.1+minf(9,wave-1)*(.5/9)),"Armored ordinary share rises from ten to sixty percent then caps: wave "+str(wave))
	for party in range(1,5):
		for difficulty in Defense.DIFFICULTIES:
			for wave in [1,2,3,4,5,6,7,8,9,10,11,20,100]:
				var random = RandomNumberGenerator.new()
				random.seed = 20260928+wave
				var value = Defense.roster(wave,party,random,difficulty)
				var budget = Defense.budget(wave,party,difficulty)
				var spent = Population.points(value)
				var specials = value.filter(func(kind): return kind in Population.ELITES)
				var common = value.filter(func(kind): return kind in Population.ORDINARY)
				var advanced_count = common.count("cone")+common.count("bucket")
				advanced_share_valid = advanced_share_valid and absf(advanced_count-common.size()*Defense.advanced_fraction(wave)) <= 1.5 and absf(common.count("cone")-2*common.count("bucket")) <= 1.0
				crawler_free = crawler_free and value.all(func(kind): return sim.defense_population_kind(kind) != "crawler")
				composition_valid = composition_valid and spent <= budget and budget-spent < .75 and Population.points(specials) <= budget*Defense.special_fraction(wave) and value.count("football") == Defense.footballs(wave,party)
				if wave >= 10: late_special_share = late_special_share and Population.points(specials) >= budget*.48
	check(composition_valid,"All difficulties and one-to-four players respect the rising special cap and independent bosses")
	check(late_special_share,"Available elite types use almost half of wave points from wave ten across parties and difficulties")
	check(crawler_free,"All difficulties, party sizes and sampled early-to-endless waves spawn no crawlers")
	check(advanced_share_valid,"Ordinary armored body share and the two-to-one cone/bucket ratio hold across waves, difficulties and party sizes")
	sim.defense_director.begin_wave()
	var initial_roster: Array = sim.roster.duplicate()
	var first_plan: Dictionary = planner.describe().duplicate()
	check(sim.wave_total == 178 and counts(initial_roster) == {"normal":160,"cone":12,"bucket":6},"Normal solo first wave contains 160 normals, twelve cones and six buckets")
	check(sim.defense.wave_budget == 138 and Population.points(initial_roster) == 138,"First wave spends exactly 138 points")
	check(planner.batches == 30 and is_equal_approx(planner.interval,1.0) and planner.batch_size == 6,"First wave schedules five or six bodies each second for thirty batches")
	var before_clock: float = planner.clock
	sim.defense.waiting = true
	sim.step(.25)
	check(planner.clock == before_clock and sim.spawned == 0,"Preparation pauses the spawn clock and quota")
	sim.defense.waiting = false
	var batches: Array = []
	var all_spawned: Array = []
	var last_id: int = sim.next_id
	var safe = true
	var spawn_issues: Array = []
	for tick in 1860:
		sim.step(1.0/60)
		var new_kinds: Array = []
		var positions: Array = []
		for z in sim.zombies:
			if z.id < last_id: continue
			new_kinds.append(z.original)
			all_spawned.append(z.original)
			positions.append({"x":z.pos.x,"z":z.pos.y})
			var newborn_safe: bool = sim.arena.clear(z.pos,z.pos) and root.get_node("Data").Maps.Defense.enemy_spawn_allowed(z.pos) and planner.hidden_from_players(z.pos,z.kind,sim.pawns.values())
			safe = safe and newborn_safe
			if not newborn_safe:
				spawn_issues.append({"id":z.id,"kind":z.original,"time":planner.clock,"pos":str(z.pos)})
		if not new_kinds.is_empty():
			batches.append({"time":planner.clock,"count":new_kinds.size(),"kinds":counts(new_kinds),"positions":positions})
		last_id = sim.next_id
		await physics_frame
		if sim.roster.is_empty(): break
	check(sim.spawned == 178 and sim.roster.is_empty() and planner.clock <= 30.02,"Real first-wave simulation releases all enemies by thirty seconds")
	var on_time = batches.size() == 30
	for index in batches.size():
		on_time = on_time and batches[index].count == planner.scheduled_count(index+1)-planner.scheduled_count(index) and absf(batches[index].time-(index+1)) <= .02
	check(on_time,"Real releases follow all thirty scheduled quotas at one-second intervals")
	check(counts(all_spawned) == counts(initial_roster),"Actual spawns match the complete ordinary composition with no crawlers")
	check(safe,"Every newborn position is outside the 2D scenery clearance margin")
	check(sim.pawns.solo.shots == 0 and sim.pawns.solo.shoves == 0,"The spawn observation performs no player firing or shoving")
	# An occupied platform must retain its backlog and resume safely later.
	planner.reset(5)
	sim.spawned = 0
	sim.roster = ["crawler","normal","normal","normal","normal"]
	sim.zombies.clear()
	var saved_region: Rect2 = planner.spawn_region
	var blocked_point = Vector2(-10,-105)
	planner.spawn_region = Rect2(blocked_point-Vector2.ONE*.05,Vector2.ONE*.1)
	sim.spawn(blocked_point,"normal")
	planner.step(30,sim.pawns.values())
	check(sim.spawned == 0 and sim.roster.size() == 5,"Occupied spawn ground retains quota according to the spawn spacing policy")
	sim.zombies.clear()
	planner.spawn_region = saved_region
	planner.step(.1,sim.pawns.values())
	check(sim.spawned == 5 and sim.roster.is_empty(),"Blocked quota resumes after safe ground becomes available")
	check(sim.zombies.all(func(z): return z.kind == "normal"),"Actual spawner replaces a legacy crawler entry with a normal zombie")
	var output = {"seed":20260928,"mode":"solo","difficulty":"normal","budget":138,"spent":Population.points(initial_roster),"unspent":138-Population.points(initial_roster),"plan":first_plan,"counts":counts(all_spawned),"batches":batches,"spawn_safe":safe,"spawn_issues":spawn_issues,"checks":checks,"failures":failures,"scope":"actual authority physics; no browser, no full wave survival result"}
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var file = FileAccess.open("res://artifacts/first-wave-horde.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t"))
	file.close()
	print("DEFENSE WAVES: %d checks; %d failures" % [checks,failures])
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
