extends RefCounted
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/onboarding.gd")
const Fixture = preload("res://tools/preparation-fixture.gd")

static func validate(game, check: Callable) -> void:
	var progress = game.get_node("/root/Progress")
	var saved = progress.store
	var path = OS.get_cache_dir().path_join("lifetime-rewards-"+str(Time.get_ticks_usec())+".json")
	# Old balances are a known baseline; previous spending and wins cannot be inferred.
	var old = Store.defaults()
	old.version = 8
	for key in ["total_coins_earned","total_diamonds_earned","victories"]: old.erase(key)
	old.coins = 75.5
	old.diamonds = 7
	old.cleared_total = 27
	old.best_wave = 10
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var migrated = Store.new(path)
	check.call(migrated.data.version == Store.SAVE_VERSION and migrated.data.total_coins_earned == 75.5 and migrated.data.total_diamonds_earned == 7 and migrated.data.victories == 0,"Legacy balances seed lifetime earnings without inventing historical wins")
	check.call(migrated.save() and Store.new(path).data == migrated.data,"Lifetime baseline persists once through a second reload")
	check.call(migrated.purchase("rifle") and migrated.purchase("strong") and migrated.data.total_coins_earned == 75.5 and migrated.data.total_diamonds_earned == 7,"Purchases do not reduce lifetime coins or diamonds")
	var reloaded = Store.new(path)
	check.call(reloaded.data.coins == 50.5 and reloaded.data.diamonds == 6 and reloaded.data.total_coins_earned == 75.5,"Reload never rebuilds cumulative income from a spent-down balance")
	for key in ["total_coins_earned","total_diamonds_earned","victories"]:
		for invalid in [-1,INF,"5"]:
			var malformed = Store.defaults()
			malformed[key] = invalid
			check.call(not Store.valid(malformed),"Invalid cumulative field is rejected: "+key+" / "+str(invalid))
	for scenario in ["zero","kills","crystal","victory"]:
		progress.store = Store.new()
		progress.store.data.intro_seen = true
		game.start_solo("defense",611)
		game.set_process(false)
		game.set_physics_process(false)
		await game.get_tree().physics_frame
		var sim = game.sim
		var p: Dictionary = game.local_pawn()
		if scenario == "kills":
			sim.progression.data.talents.greed = 1
			for index in 10:
				sim.spawn(p.pos+Vector2(0,-5-index),"normal")
				var enemy: Dictionary = sim.zombies[-1]
				sim.hit_enemy(enemy,enemy.hp+1,false,p,Vector3(enemy.pos.x,p.height+1,enemy.pos.y))
			check.call(is_equal_approx(sim.earned_coins,12) and is_equal_approx(sim.progression.data.total_coins_earned,12),"Greed-adjusted kill income is recorded exactly once")
		if scenario == "victory":
			sim.progression.award_wave(10)
			sim.earned_diamonds = 1
			sim.won = true
		else:
			sim.failed = true
			sim.cause = "crystal" if scenario == "crystal" else "zombie"
			if scenario != "crystal": p.hp = 0
		var before: float = sim.earned_coins
		game.finish_run()
		var reward = 25 if scenario in ["zero","kills"] else 0
		check.call(is_equal_approx(sim.earned_coins,before+reward) and is_equal_approx(sim.progression.data.coins,before+reward) and is_equal_approx(sim.progression.data.total_coins_earned,before+reward),"Settlement adds only the fixed death bonus: "+scenario)
		check.call(sim.progression.data.victories == (1 if scenario == "victory" else 0),"Only full victory increments completed runs: "+scenario)
		if scenario == "zero":
			check.call(sim.progression.data.coins == 25 and Tutorial.stage(sim.defense) == Tutorial.SHOP_PENDING,"Zero-income tutorial death grants twenty-five and schedules the shop")
		if scenario == "victory":
			check.call(sim.progression.data.total_diamonds_earned == 1 and sim.progression.data.cleared_total == 1,"Wave diamond earnings and cleared-wave count stay separate from run victories")
		game.finish_run()
		Tutorial.finish_attempt(sim)
		check.call(is_equal_approx(sim.earned_coins,before+reward) and sim.progression.data.victories == (1 if scenario == "victory" else 0),"Repeated terminal updates cannot duplicate rewards: "+scenario)
		game.update_finish_camera(6.0)
		var amount = game.ui.menu.find_child("EarnedCoins",true,false)
		check.call(amount != null and amount.text == "+%d" % (before+reward),"Results display the death bonus as part of total run income: "+scenario)
	progress.store = saved
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
