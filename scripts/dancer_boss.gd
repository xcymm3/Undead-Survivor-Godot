extends RefCounted
## Bounded authority summoning; animation uses the same timers as CPU hit poses.
const INTERVAL = 10.0
const DANCE_DURATION = 3.0
const EMERGE_DURATION = 1.4
const SUMMON_BUDGET = 50
const MAX_SUMMON_POPULATION = 100
const SUMMON_KINDS = ["bucket","shield","berserker","imp"]
const Population = preload("res://scripts/enemy_population.gd")

static func roster(random: RandomNumberGenerator) -> Array:
	return Population.roster(SUMMON_BUDGET,SUMMON_KINDS,random)

static func step(sim, dt: float) -> void:
	var data = sim.arena.get_node("/root/Data")
	for boss in sim.zombies.duplicate():
		if boss.hp <= 0 or boss.kind != "dancer": continue
		boss.summon_clock = boss.get("summon_clock",INTERVAL)-dt
		if boss.get("dance_remaining",0.0) > 0:
			boss.dance_remaining = maxf(0,boss.dance_remaining-dt)
		elif boss.summon_clock <= 0:
			boss.summon_clock = INTERVAL
			var incoming: Array = roster(sim.random)
			var committed: int = sim.alive_count()
			for other in sim.zombies:
				if other.hp > 0: committed += other.get("summon_roster",[]).size()
			if committed+incoming.size() <= MAX_SUMMON_POPULATION:
				boss.dance_remaining = DANCE_DURATION
				boss.summon_roster.append_array(incoming)
				boss.attack_time = 0.0
				boss.move_speed = 0.0
				sim.events.append({"kind":"disco","position":Vector3(boss.pos.x,data.enemy_ground_height(boss.pos,sim.map_id)+1.5,boss.pos.y)})
		if boss.get("dance_remaining",0.0) > 0 or boss.get("summon_roster",[]).is_empty(): continue
		var released = 0
		for attempt in 96:
			if boss.summon_roster.is_empty() or released >= 8: break
			var angle = sim.random.randf()*TAU
			var point: Vector2 = boss.pos+Vector2(cos(angle),sin(angle))*sim.random.randf_range(1.4,7.0)
			if not sim.arena.clear(boss.pos,point): continue
			sim.spawn(point,boss.summon_roster[0])
			boss.summon_roster.remove_at(0)
			var summoned: Dictionary = sim.zombies[-1]
			summoned.spawn_wave = int(boss.get("spawn_wave",10))
			summoned.emerge_remaining = EMERGE_DURATION
			summoned.summoned = true
			released += 1
