extends SceneTree
var failures: Array[String] = []
var checks = 0
var game

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func validate_combat_revision() -> void:
	game.return_home()
	game.start_solo("campaign",71245)
	await physics_frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	var director = sim.campaign
	for station in director.state.medical_stations.values(): check(station.remaining == 1,"Each solo station guarantees one medical pack")
	p.pos = Vector2(-2,71)
	p.medkits = 0
	check(director.equipment.pickup(p,"medical:night_start"),"Weapon station includes a real medical pickup")
	p.medkits = 0
	check(not director.equipment.pickup(p,"medical:night_start"),"Consumed medical stock cannot refill itself")
	p.hp = 1
	p.medkits = 1
	p.slot = 5
	p.input = {"slot":5,"use_self":true}
	p.input_age = 0
	director.equipment.before_movement(.016)
	director.equipment.before_movement(3)
	check(p.hp == 100 and p.medkits == 0,"A completed kit restores even one HP to exactly 100")
	p.being_healed = false
	director.state.departed = true
	game.arena.sync_campaign(director.state)
	p.pos = Vector2(8,60)
	p.slot = 1
	p.primary = 4
	p.weapon = 4
	p.requested = 4
	p.switch = 0
	p.cooldown = 0
	p.fire_anim = 0
	p.ammo[4] = 2
	p.reserves[4] = 10
	p.reloading = true
	p.reload = .3
	var shots: int = p.shots
	sim.update_arsenal(p,{"fire":true,"slot":1},.016)
	check(not p.reloading and p.ammo[4] == 1 and p.shots == shots+1 and p.reserves[4] == 10,"Pump fires during reload without granting the unfinished shell")
	p.ammo[4] = 0
	p.reloading = true
	p.reload = .3
	p.cooldown = 0
	p.fire_anim = 0
	sim.update_arsenal(p,{"fire":true,"slot":1},.016)
	check(p.reloading and p.ammo[4] == 0,"Empty pump must finish loading a shell before firing")
	for kind in ["normal","cone","bucket","imp","shield","football","berserker"]:
		sim.zombies.clear()
		sim.spawn(Vector2(8,57),kind)
		var z: Dictionary = sim.zombies[0]
		if kind == "shield": check(z.hp == 1200 and z.body == 200 and z.armor == 1000,"Shield armor doubles without changing body health")
		var initial: Vector2 = z.pos
		z.shove_time = .4
		z.shove_velocity = Vector2(0,-5)
		sim.stun(z,1.5)
		sim.hit_enemy(z,1,false,p,Vector3(0,1,57))
		check(z.pos.distance_to(initial) > .15 and z.pos.distance_to(initial) < .25,"Nonlethal damage pushes "+kind)
		check(z.state_time >= 1.5 and z.shove_time == .4 and z.shove_velocity == Vector2(0,-5),"Weapon hit retains stronger shove control "+kind)
		initial = z.pos
		sim.hit_enemy(z,1,false,p,Vector3(0,1,57))
		check(z.pos == initial,"Same-volley pellets cannot multiply push "+kind)
	for kind in ["football","berserker"]:
		sim.zombies.clear()
		sim.spawn(Vector2(8,57),kind)
		var z: Dictionary = sim.zombies[0]
		check(z.hp == (9000 if kind == "football" else 3000),"Updated boss health "+kind)
		if kind == "football":
			check(z.body == 3000 and z.armor == 6000,"Football has six thousand armor and three thousand body health")
			check(z.chase_speed >= 4.6 and z.chase_speed <= 5.2,"Football pursuit uses the ordinary random speed range")
			z.state = "charging"
		else:
			z.hp = 1501
			z.body = 1501
			sim.hit_enemy(z,2,false,p,Vector3(0,1,57))
		check(z.pos == Vector2(8,57),"Charge or half-health rage prevents hit displacement "+kind)
		if kind == "berserker": check(z.rage,"Berserker rages at half of its three thousand health")
	sim.zombies.clear()
	sim.spawn(Vector2(8,57),"giant")
	var armored_giant: Dictionary = sim.zombies[0]
	check(armored_giant.hp == 6000 and armored_giant.body == 4000 and armored_giant.armor == 2000,"Giant splits unchanged total health into helmet armor and body health")
	var giant_position: Vector2 = armored_giant.pos
	var giant_torso_hit: Dictionary = load("res://scripts/enemy_view.gd").hit(armored_giant,Vector3(8,1.8,61),Vector3(0,0,-1),8,sim.elapsed,true)
	check(not giant_torso_hit.is_empty() and giant_torso_hit.armor,"Giant body hits use the same full-body armor rule as buckets and football zombies")
	sim.hit_enemy(armored_giant,100,true,p,Vector3(8,2,57))
	check(armored_giant.armor == 1900 and armored_giant.body == 4000 and armored_giant.pos == giant_position,"Any giant hit consumes armor first without firearm displacement")
	var calm_berserker: ArrayMesh = game.enemies.mesh_for("berserker",0,false,false)
	var raging_berserker: ArrayMesh = game.enemies.mesh_for("berserker",0,true,false)
	var glowing_eyes: StandardMaterial3D = raging_berserker.surface_get_material(1)
	check(calm_berserker.get_surface_count() == 1 and raging_berserker.get_surface_count() == 2 and glowing_eyes.emission_enabled and glowing_eyes.emission.r > .9,"Half-health berserker adds a distinct emissive red-eye surface")
	sim.zombies.clear()
	sim.spawn(Vector2(8,55),"football")
	var runner: Dictionary = sim.zombies[0]
	for armor in [6000,0]:
		runner.pos = Vector2(8,55)
		runner.armor = armor
		runner.state = "ready"
		runner.charge_cooldown = 99
		sim.update_zombie(runner,p,.1)
		check(is_equal_approx(runner.move_speed,runner.chase_speed),"Actual football pursuit uses its sampled speed with armor "+str(armor))
	runner.pos = Vector2(8,55)
	runner.state = "charging"
	runner.state_time = 1.0
	runner.charge_direction = Vector2(0,1)
	sim.update_zombie(runner,p,.1)
	check(is_equal_approx(runner.move_speed,sim.FOOTBALL_CHARGE_SPEED),"Football charge moves at 12 meters per second")
	var saved_speed_position: Vector2 = p.pos
	p.pos = Vector2(8,58)
	for kind in ["imp","berserker"]:
		sim.zombies.clear()
		sim.spawn(Vector2(8,55),kind)
		var speed_enemy: Dictionary = sim.zombies[0]
		speed_enemy.chase_speed = 5.0
		speed_enemy.charge_cooldown = 99
		sim.update_zombie(speed_enemy,p,.1)
		check(is_equal_approx(speed_enemy.move_speed,5.0*sim.IMP_SPEED_MULTIPLIER if kind == "imp" else 5.0),"Updated calm pursuit speed "+kind)
		if kind == "berserker":
			speed_enemy.pos = Vector2(8,55)
			speed_enemy.rage = true
			sim.update_zombie(speed_enemy,p,.1)
			check(is_equal_approx(speed_enemy.move_speed,sim.BERSERKER_RAGE_SPEED),"Berserker rage pursuit is fixed at 7.2 meters per second")
	p.pos = saved_speed_position
	for cue in ["grenade-throw","grenade-fuse","grenade-explosion"]:
		check(game.sound.streams.has(cue) and game.sound.streams[cue].get_length() > .05,"Grenade cue resource exists: "+cue)
	sim.events.clear()
	p.grenades = 3
	p.yaw = 0
	p.pitch = 0
	p.input = {"yaw":PI/2,"pitch":-.7}
	var grenade_time: float = sim.elapsed
	p.grenade_ready_at = grenade_time
	check(director.equipment.throw_grenade(p),"First grenade throw is accepted")
	var velocity: Vector3 = director.state.projectiles[-1].velocity
	check(velocity.x < -8 and absf(velocity.z) < .01 and velocity.y < 0,"Grenade follows current input aim instead of previous-frame gun aim")
	check(sim.events.any(func(e): return e.kind == "grenade_throw"),"Throw emits spatial sound event")
	var throws_before: int = director.state.projectiles.size()
	var events_before: int = sim.events.size()
	check(not director.equipment.throw_grenade(p) and p.grenades == 2 and director.state.projectiles.size() == throws_before and sim.events.size() == events_before,"Repeated grenade input is ignored during the one-second interval")
	sim.elapsed = grenade_time+.99
	check(not director.equipment.throw_grenade(p) and p.grenades == 2,"Grenade remains locked just before one second")
	sim.elapsed = grenade_time+1.0
	check(director.equipment.throw_grenade(p) and p.grenades == 1 and director.state.projectiles.size() == throws_before+1,"Grenade unlocks at exactly one second")
	director.equipment.step_projectiles(.4)
	check(sim.events.any(func(e): return e.kind == "grenade_fuse"),"Live fuse emits spatial warning event")
	director.equipment.step_projectiles(1.2)
	check(sim.events.any(func(e): return e.kind == "explosion") and director.state.projectiles.is_empty(),"Fuse ends and removes every thrown projectile")
	sim.elapsed = grenade_time
	sim.zombies.clear()
	director.state.exit_control = true
	game.arena.sync_campaign(director.state)
	p.pickup_latched = false
	p.pos = Vector2(12,-54.6)
	var driver = load("res://tools/campaign-unrestricted-driver.gd").new(game,false)
	driver.tasks = [[Vector2(12,-60),"finish"]]
	var command: Dictionary = driver.command(.05)
	check(Vector2(command.get("x",0),command.get("y",0)).length() > .1 and not command.get("interact",false),"Test player clears the doorway before attempting closure")
	p.pos = Vector2(12,-55.2)
	command = driver.command(.05)
	check(Vector2(command.get("x",0),command.get("y",0)).length() > .1 and not command.get("interact",false),"Test player clears the swinging door leaf, not just its closed threshold")
	p.pos = Vector2(12,-60)
	command = driver.command(.05)
	check(command.get("interact",false) and command.x == 0 and command.y == 0,"Test player closes the clear doorway after entering fully")
	director.state.departed = true
	game.arena.sync_campaign(director.state)
	p.pos = Vector2(0,60)
	p.primary = 9
	p.weapon = 9
	p.requested = 9
	p.slot = 1
	p.ammo[9] = int(root.get_node("Data").weapons[9].capacity)
	p.reserves[9] = root.get_node("Data").full_reserve(9)
	p.reserve = p.reserves[9]
	sim.spawn(Vector2(0,58.7),"crawler")
	driver.tasks = [[Vector2(0,50),""]]
	driver.test_weapon = 9
	command = driver.command(.05)
	check(command.get("weapon",-1) == 9 and command.get("slot",0) == 1 and command.get("fire",false) and command.get("pitch",0) < -.2,"Fixed gun comparison keeps downward aim on a close crawler instead of an axe command")
	game.return_home()
	game.start_solo("campaign",71245)
	await physics_frame

func validate_flame() -> void:
	var fx = game.effects
	fx.clear()
	var original_query: Callable = fx.collision_query
	fx.collision_query = Callable()
	fx.flame(Vector3(0,2,0),Vector3(0,2,-12))
	for i in 24: fx.step(1.0/60)
	check(not fx.flame_particles.is_empty(),"Flame remains visible during its forward flight")
	check(fx.flame_particles.all(func(p): return p.pos.y > 1.55 and p.pos.z < -5),"Horizontal flame keeps forward momentum instead of falling under debris gravity")
	fx.step(1)
	check(fx.flame_particles.is_empty() and fx.flame_light.light_energy == 0 and not fx.flame_light.visible,"Released flame and local light fully expire and release the light slot")
	fx.collision_query = func(_from: Vector3,to: Vector3): return {"position":to} if to.z < -2 else {}
	fx.flame(Vector3(0,2,0),Vector3(0,2,-12))
	for i in 12: fx.step(1.0/60)
	check(fx.flame_particles.is_empty(),"Flame packets cannot cross a blocking surface")
	fx.collision_query = original_query
	game.return_home()
	game.start_solo("campaign",71245)
	await physics_frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	p.pos = Vector2(8,60)
	p.yaw = 0
	p.pitch = 0
	p.weapon = 7
	sim.zombies.clear()
	sim.spawn(Vector2(8,54),"normal")
	var z: Dictionary = sim.zombies[0]
	var before: float = z.hp
	sim.fire(p,root.get_node("Data").weapons[7])
	check(is_equal_approx(before-z.hp,45),"Overlapping flame rays apply damage only once per tick")
	sim.zombies.clear()
	sim.spawn(Vector2(8,52),"normal")
	sim.spawn(Vector2(8.65,50),"normal")
	var initial_hp: Array = sim.zombies.map(func(enemy): return enemy.hp)
	sim.fire(p,root.get_node("Data").weapons[7])
	check(sim.zombies[0].hp < initial_hp[0] and sim.zombies[1].hp < initial_hp[1],"Flame covers off-axis enemies and penetrates the front row")
	p.pos = Vector2(0,70)
	p.yaw = -PI/2
	sim.zombies.clear()
	sim.spawn(Vector2(8,70),"normal")
	before = sim.zombies[0].hp
	sim.fire(p,root.get_node("Data").weapons[7])
	check(sim.zombies[0].hp == before,"Widened flame cannot damage enemies through the safe-room wall")
	fx.clear()

func validate_sniper_penetration() -> void:
	game.return_home()
	game.start_solo("campaign",71245)
	await physics_frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	var w: Dictionary = root.get_node("Data").weapons[5].duplicate(true)
	# Isolate penetration from the standing pose's head/body intersection.
	w.headshotMultiplier = 1
	p.pos = Vector2(8,60)
	p.yaw = 0
	p.pitch = 0
	p.weapon = 5
	sim.zombies.clear()
	for depth in [54,52,50,48]:
		sim.spawn(Vector2(8,depth),"normal")
		sim.zombies[-1].hp = 2000
		sim.zombies[-1].body = 2000
	sim.fire(p,w)
	for index in 4:
		var expected: float = float(w.damage)*pow(.8,index) if index < 3 else 0.0
		check(is_equal_approx(2000-sim.zombies[index].hp,expected),"Sniper front-to-back attenuation and three-target limit "+str(index))
	p.pos = Vector2(0,70)
	p.yaw = -PI/2
	sim.zombies.clear()
	sim.spawn(Vector2(8,70),"normal")
	var health: float = sim.zombies[0].hp
	sim.fire(p,w)
	check(sim.zombies[0].hp == health,"Sniper cannot penetrate the safe-room wall")

func validate_crawler() -> void:
	game.return_home()
	game.start_solo("campaign",71245)
	await physics_frame
	var sim = game.sim
	var data = root.get_node("Data")
	var director = sim.campaign
	var ordinary = sim.zombies.filter(func(z): return z.original in ["normal","crawler"])
	check(ordinary.filter(func(z): return z.original == "crawler").size() == ordinary.size()/10,"Preplaced ordinary slots use nine normal per crawler")
	var before: int = director.ordinary_slots
	check(not director.spawn_one([game.local_pawn().pos],"normal") and before == director.ordinary_slots,"Blocked reinforcement does not advance crawler ratio")
	for i in 20:
		var expected = "crawler" if (before+i+1)%10 == 0 else "normal"
		check(director.population_kind("normal") == expected,"Crawler ratio carries across batches "+str(i))
	check(director.population_kind("football") == "football" and director.ordinary_slots == before+20,"Boss does not consume ordinary ratio")
	check(preload("res://scripts/night_population.gd").COST.crawler == 1,"Crawler costs one threat point")
	sim.zombies.clear()
	sim.spawn(Vector2(8,60),"crawler")
	var z: Dictionary = sim.zombies[-1]
	check(z.hp == root.get_node("Data").enemies.normal.health and z.armor == 0,"Crawler matches normal health and armor")
	check(z.chase_speed >= 4.6*.85 and z.chase_speed <= 5.2*.85,"Crawler chase speed is 85 percent of ordinary range")
	var view = load("res://scripts/enemy_view.gd")
	var ground = data.enemy_ground_height(z.pos)
	for phase in [0.0,PI/2,PI,PI*1.5]:
		z.gait = phase
		z.move_speed = 4.0
		for attack in [0.0,.25,.5,.8]:
			z.attack_time = attack
			var poses = view.transforms(z,sim.elapsed,false)
			var low = INF
			var high = -INF
			for j in data.parts.size():
				if data.parts[j].has("kind") or data.parts[j].get("armor",false): continue
				for x in [-.5,.5]:
					for y in [-.5,.5]:
						for depth in [-.5,.5]:
							var point: Vector3 = poses[j]*Vector3(x,y,depth)
							low = minf(low,point.y-ground)
							high = maxf(high,point.y-ground)
			check(low >= -.05 and high < .95,"Crawl/attack pose stays low without sinking")
	z.attack_time = 0
	check(view.hit(z,Vector3(8,ground+1.7,64),Vector3.FORWARD,8,0,false).is_empty(),"Standing head line passes above crawler")
	var head = view.hit(z,Vector3(8,ground+.53,64),Vector3.FORWARD,8,0,false)
	check(not head.is_empty() and head.head,"Lowered aim hits crawler head")
	var death_heads: Array = []
	var death_hands: Array = []
	z.hp = 0.0
	z.move_speed = 0.0
	for down in [.85,.55,.25]:
		z.down = down
		var death_poses: Array = view.transforms(z,sim.elapsed,false)
		death_heads.append(death_poses[3].origin)
		death_hands.append([death_poses[18].origin,death_poses[19].origin])
		var death_low = INF
		var death_high = -INF
		for j in data.parts.size():
			if data.parts[j].has("kind") or data.parts[j].get("armor",false): continue
			for x in [-.5,.5]:
				for y in [-.5,.5]:
					for depth in [-.5,.5]:
						var point: Vector3 = death_poses[j]*Vector3(x,y,depth)
						death_low = minf(death_low,point.y-ground)
						death_high = maxf(death_high,point.y-ground)
		check(death_low >= -.05 and death_high < .95,"Crawler death stage stays above ground and prone %s low=%.3f high=%.3f" % [str(down),death_low,death_high])
	check(death_heads[2].y < death_heads[0].y-.18 and death_heads[2].y-ground < .35,"Crawler death lowers the face to the ground")
	check(death_hands[2][0].z > death_hands[0][0].z+.15 and death_hands[2][1].z > death_hands[0][1].z+.15,"Crawler death extends both hands into a collapsed pose")
	z.hp = float(data.enemies.crawler.health)
	z.down = 0.0
	z.move_speed = 0.0
	z.attack_time = 0.0
	z.guard_awake = true
	var idle_crawl_a: Dictionary = view.pose_state(z,0.0,false)
	var idle_crawl_b: Dictionary = view.pose_state(z,1.0,false)
	check(not idle_crawl_a.root.is_equal_approx(idle_crawl_b.root),"Awake crawler has a subtle idle sway")
	sim.spawn(Vector2(10,60),"normal")
	var upright: Dictionary = sim.zombies[-1]
	upright.move_speed = 0.0
	upright.guard_awake = true
	var idle_stand_a: Dictionary = view.pose_state(upright,0.0,false)
	var idle_stand_b: Dictionary = view.pose_state(upright,1.0,false)
	check(not idle_stand_a.root.is_equal_approx(idle_stand_b.root),"Awake upright zombie has a subtle idle sway")
	sim.zombies.pop_back()
	game.enemies.sync(sim.zombies,sim.elapsed,false)
	var state = view.pose_state(z,sim.elapsed,false)
	var actor: Dictionary = game.enemies.actors[z.id]
	for bone in 7: check(actor.skeleton.get_bone_pose(bone).is_equal_approx(state.bones[bone]),"Crawler rendered and CPU bone match "+str(bone))

func validate_outfits() -> void:
	game.return_home()
	game.start_solo("campaign",71245)
	await physics_frame
	var sim = game.sim
	var counts = [0,0,0,0,0]
	var rng_before: int = sim.random.state
	sim.zombies.clear()
	for kind in ["normal","crawler","cone","bucket"]:
		for i in 100:
			sim.spawn(Vector2(8,60),kind)
			var z: Dictionary = sim.zombies[-1]
			check(z.outfit >= 0 and z.outfit < 5,"Eligible infected has valid outfit")
			counts[z.outfit] += 1
		check(sim.zombies.slice(-100).map(func(z): return z.outfit).any(func(style): return style != sim.zombies[-1].outfit),"Kind receives varied outfits "+kind)
	check(sim.random.state == rng_before,"Clothing RNG never changes encounter random state")
	check(counts.all(func(amount): return amount > 40 and amount < 120),"Five clothing variants all represented without deterministic cycling")
	var snapshot: Dictionary = bytes_to_var(var_to_bytes(sim.snapshot()))
	check(snapshot.zombies.map(func(z): return z.outfit) == sim.zombies.map(func(z): return z.outfit),"Outfit survives network snapshot serialization")
	var p: Dictionary = game.local_pawn()
	for kind in ["cone","bucket"]:
		sim.spawn(Vector2(8,60),kind)
		var z: Dictionary = sim.zombies[-1]
		var style: int = z.outfit
		sim.hit_enemy(z,z.armor,true,p,Vector3(8,1.5,60))
		check(z.kind == "normal" and z.outfit == style,"Armor break retains clothing "+kind)
		sim.hit_enemy(z,10000,false,p,Vector3(8,1,60))
		check(z.hp == 0 and z.outfit == style,"Death retains clothing "+kind)
	for kind in ["imp","shield","berserker","football"]:
		sim.spawn(Vector2(8,60),kind)
		check(not sim.zombies[-1].has("outfit"),"Special silhouette remains unchanged "+kind)
	for kind in ["normal","crawler","cone","bucket"]:
		var variants: Array = []
		for style in 5:
			var mesh = game.enemies.mesh_for(kind,0,false,kind in ["cone","bucket"],style)
			check(not variants.has(mesh),"Separate cached clothing mesh "+kind+str(style))
			variants.append(mesh)
			check(mesh == game.enemies.mesh_for(kind,3,false,kind in ["cone","bucket"],style),"Outfit cache independent of old palette")
	sim.zombies.clear()

func validate_interaction_motion() -> void:
	game.return_home()
	game.start_solo("campaign",71245)
	await physics_frame
	var sim = game.sim
	var d = sim.campaign
	var p: Dictionary = game.local_pawn()
	p.pos = Vector2(0,66.5)
	p.input = {"interact":true}
	p.input_age = 0
	d.interactions(.05)
	check(d.state.get("bar_removed",false) and not d.state.departed,"First E removes the bar without opening the door")
	d.interactions(1)
	check(not d.state.get("start_opening",false),"Holding E cannot trigger the second door action")
	p.input = {}
	d.interactions(.05)
	p.input = {"interact":true}
	d.interactions(.05)
	d.step_props(.55)
	game.arena.scenery.sync(d.state)
	check(not d.state.departed and absf(game.arena.scenery.doors.start.rotation.y) > .1,"Door rotates visibly before departure is permitted")
	check(not game.arena.clear(Vector2(0,67),Vector2(0,63)),"Partially open door remains blocked to navigation")
	d.step_props(.6)
	check(d.state.departed and game.arena.scenery.door_blockers.start.collision_layer == 0,"Fully opened door releases the threshold")
	var gun: Dictionary = d.state.loot[0]
	p.pos = gun.pos
	var old: int = p.primary
	check(d.equipment.pickup(p,gun.id),"Animated gun exchange consumes one rack gun")
	var motion: Dictionary = d.state.pickup_motion[-1]
	check(motion.old == old and motion.weapon == gun.weapon and p.switch >= .65,"Gun exchange records both models and blocks immediate shooting")
	var copy: Dictionary = bytes_to_var(var_to_bytes(sim.snapshot()))
	check(copy.campaign.pickup_motion[-1].id == motion.id,"Pickup animation identity survives network snapshot serialization")
	d.step_props(.7)
	check(p.pickup_remaining == 0,"Pickup animation completes on authority clock")
	sim.zombies.clear()
	p.pos = Vector2(12,-60)
	d.state.exit_control = true
	d.step_props(1.2)
	d.perform(p,"finish")
	d.step_props(.4)
	check(not d.state.complete and d.state.exit_motion > 0 and d.state.exit_motion < 1,"Closing door does not complete the level midway")
	p.pos = Vector2(12,-56)
	d.step_props(.1)
	check(not d.state.exit_closing and not d.state.complete,"Door reopens when a survivor enters its swing area")
	p.pos = Vector2(12,-60)
	d.step_props(1.2)
	d.perform(p,"finish")
	d.step_props(1.2)
	check(d.state.complete and d.state.exit_motion == 0,"Victory waits for the door to close fully")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/main.tscn")
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var maps = load("res://scripts/map_catalog.gd")
	check(maps.IDS == ["graypine_defense","graypine_night"] and game.arena.map_id == "graypine_night","Defense and campaign maps are registered; automation keeps the campaign fixture")
	for retired in ["outpost","dust","graypine_ferry"]: check(not maps.valid(retired),"Retired map rejected: "+retired)
	check(not game.arena.obstacles.is_empty(),"Native scene retains navigation footprints")
	var ray = game.arena.surface_hit(Vector3(0,5,9),Vector3(0,-2,9))
	check(not ray.is_empty(),"Baked ground participates in native physics rays")
	check(RenderingServer.render_loop_enabled,"Normal rendering uses the engine loop")
	game.start_solo("campaign")
	game.ui.tick(.016)
	check(game.ui.native_hud.visible,"Native HUD appears on game start")
	check(game.ui.native_hud.cards.has("solo"),"Player card is a retained control")
	var card: Dictionary = game.ui.native_hud.cards.solo
	check(card.bar is ProgressBar and card.name is Label,"Health and name use native widgets")
	var pawn: Dictionary = game.local_pawn()
	pawn.hp = 42
	game.ui.tick(.016)
	check(card.bar.value == 42 and card.hp.text == "+42","Native health widget updates from authority")
	check(card.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE,"HUD does not capture combat input")
	await process_frame
	await process_frame
	var single_width: float = card.panel.size.x
	check(single_width >= 210 and single_width <= 260,"Single health card stays compact")
	for i in 1:
		var peer: Dictionary = pawn.duplicate(true)
		peer.id = "hud_fixture_"+str(i)
		peer.name = "队友长名字布局验证"
		game.sim.pawns[peer.id] = peer
	game.ui.tick(.016)
	await process_frame
	await process_frame
	check(game.ui.native_hud.cards.size() == 2 and is_equal_approx(card.panel.size.x,single_width),"Each teammate gets a separate card without stretching the local card")
	for id in game.sim.pawns.keys():
		if str(id).begins_with("hud_fixture_"): game.sim.pawns.erase(id)
	game.ui.tick(.016)

	game.ui.native_hud.size = Vector2(960,540)
	game.ui.native_hud.layout()
	check(game.ui.native_hud.content.size.x >= 1440,"HUD maintains readable layout at smaller viewport sizes")
	var original = InputMap.action_get_events("jump")
	InputMap.action_erase_events("jump")
	var rebound = InputEventKey.new()
	rebound.physical_keycode = KEY_J
	InputMap.action_add_event("jump",rebound)
	rebound.pressed = true
	game._unhandled_input(rebound)
	check(game.input_state().jump,"Jump obeys an InputMap rebind")
	var space = InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	game._unhandled_input(space)
	check(not game.input_state().jump,"Old jump key is no longer hard-coded")
	InputMap.action_erase_events("jump")
	for event in original: InputMap.action_add_event("jump",event)
	check(InputMap.action_get_events("start_wave").any(func(event): return event is InputEventKey and event.physical_keycode == KEY_T),"T is bound to the wave start action")
	var fire = InputEventAction.new()
	fire.action = "fire"
	fire.pressed = true
	game._input(fire)
	check(game.input_state().fire,"Attack accepts an action independent of device")
	game.pause_game()
	check(not game.input_state().fire,"Pause clears held attack")
	game.resume_game()
	var fullscreen = InputEventKey.new()
	fullscreen.physical_keycode = KEY_F11
	fullscreen.pressed = true
	check(fullscreen.is_action_pressed("fullscreen"),"Fullscreen default maps to F11")
	game.sound.play_at("gun",Vector3(7,2,-8))
	check(game.sound.spatial_players[0].global_position == Vector3(7,2,-8),"World audio retains the event position")
	check(game.sound.spatial_players[0].max_distance > 0,"World audio has distance attenuation")
	check(game.sound.streams.has("campaign-horde") and game.sound.streams.has("campaign-growl") and game.sound.streams["campaign-horde"] != game.sound.streams["campaign-growl"],"Reinforcement horn and nearby zombie growl use distinct audio streams")
	game.sound.clear_effects()
	check(game.sound.spatial_players.all(func(p): return p.stream == null),"World voice resources clear on scene reset")
	await validate_equipment()
	await validate_inventory_and_heal()
	await validate_combat_revision()
	await validate_outfits()
	await validate_interaction_motion()
	await validate_crawler()
	await validate_flame()
	await validate_sniper_penetration()
	validate_close_combat()
	validate_revolver()
	validate_sight_only_changes()
	validate_buffer()
	var session = root.get_node("Session")
	var packet = {"type":"probe","state":{"test":123}}
	var encoded = session.encode_packet(packet)
	var decoded = bytes_to_var(encoded.decompress_dynamic(2000000,FileAccess.COMPRESSION_DEFLATE))
	check(decoded.state.test == 123 and decoded.has("protocol"),"Shared packet encoding preserves wire payload")
	check(not packet.has("protocol"),"Encoding does not mutate caller state")
	# Exercise the actual receiver/render integration without opening a network port.
	game.sim.spawn(Vector2(0,3),"normal")
	session.playing = true
	var world: Dictionary = game.sim.snapshot()
	world.elapsed = 2.0
	session.world_received.emit(world)
	world = world.duplicate(true)
	world.elapsed = 2.1
	world.zombies[0].pos.x += 1
	session.world_received.emit(world)
	game.display_buffer.clock = 2.05
	game._process(0)
	check(game.display_buffer.history.size() == 2,"World receiver feeds the display buffer")
	check(game.sim.zombies[0].pos == world.zombies[0].pos,"Rendering retains the latest authoritative enemy position")
	session.playing = false
	game.return_home()
	check(not game.ui.native_hud.visible,"HUD hides on return to menu")
	check(game.display_buffer.history.is_empty(),"Leaving clears interpolation history")
	game.free()
	# Allow the audio thread to release stopped voices before the test exits.
	await create_timer(.15).timeout
	print("NATIVE COMPONENTS: %d checks; %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func validate_revolver() -> void:
	var p: Dictionary = game.local_pawn().duplicate(true)
	p.weapon = 3
	p.requested = 3
	p.switch = 0.0
	p.hp = 100
	p.aim = false
	p.reloading = false
	p.fire_anim = 0.0
	var rig = game.weapon.models[3]
	var before = p.duplicate(true)
	game.weapon.sync(p,.016,0)
	check(p == before,"Revolver presentation never mutates authoritative ammo or input")
	check(rig.find_children("RightHand","",true,false).is_empty() and rig.find_children("LeftHand","",true,false).is_empty() and rig.find_children("*Forearm*","",true,false).is_empty(),"Revolver first-person model contains no hands or forearms")
	var states = []
	for phase in [.1,.3,.5,.65,.85]:
		p.reloading = true
		p.reload = 1.6*(1-phase)
		game.weapon.sync(p,.016,phase)
		states.append(rig.loader_anchor.position)
	check(states[0].distance_to(states[2]) > .2,"Reload reaches from cylinder latch to fresh-round retrieval")
	check(states[2].distance_to(states[3]) > .15,"Speedloader returns to the open cylinder")
	p.reloading = false
	p.switch = .4
	game.weapon.sync(p,.016,1)
	check(rig.state_name == "cancel","Interrupted reload begins a finite visual recovery")
	for i in 20: game.weapon.sync(p,.016,1+i*.016)
	check(rig.cylinder_open == 0 and not rig.loader.visible and not rig.shells.visible,"Cancellation removes loose props and closes the cylinder")
	p.weapon = 0
	game.weapon.sync(p,.016,2)
	check(not rig.visible,"Switching to other weapons hides the revolver model")
	p.weapon = 3
	p.hp = 0
	game.weapon.sync(p,.016,2)
	check(not rig.visible,"Death cannot leave a live revolver model on screen")
	# Exercise real authority interruption separately from the presentation sampler.
	for phase in [.2,.5,.85]:
		var state: Dictionary = game.local_pawn().duplicate(true)
		state.weapon = 3
		state.requested = 3
		state.ammo[3] = 1
		state.reloading = true
		state.reload = 1.6*(1-phase)
		state.fire_anim = 0.0
		state.switch = 0.0
		state.slot = 1
		game.sim.update_arsenal(state,{"slot":1},.016)
		check(not state.reloading and state.ammo[3] == 1,"Switching cancels revolver reload without granting rounds at phase "+str(phase))
	game.weapon.sync(game.local_pawn(),.016,0)

func validate_sight_only_changes() -> void:
	var p: Dictionary = game.local_pawn().duplicate(true)
	p.switch = 0.0
	p.reloading = false
	p.fire_anim = 0.0
	p.shove_anim = 0.0
	p.pickup_remaining = 0.0
	for index in game.weapon.models.size():
		var id: String = root.get_node("Data").weapons[index].id
		if id not in ["p90","pistol","heavy-machine-gun"]: continue
		var model: Node3D = game.weapon.models[index]
		var original = load("res://assets/models/"+id+".glb").instantiate()
		check(model.scene_file_path == original.scene_file_path,id+": first person keeps the original imported weapon")
		for mesh in original.find_children("*","MeshInstance3D",true,false):
			var retained = model.get_node(original.get_path_to(mesh))
			check(retained.mesh == mesh.mesh and retained.skin == mesh.skin and retained.material_override == mesh.material_override,id+": sight fittings do not replace body geometry, skin or material")
		var animation: AnimationPlayer = game.weapon.animations[index]
		check(animation != null and animation.has_animation("fire") and animation.has_animation("reload"),id+": original firing and reload clips remain available")
		var sight: Node3D = game.weapon.sights[index]
		if id != "heavy-machine-gun":
			check(sight.get_parent() is BoneAttachment3D,id+": added sight follows an original animation bone")
			check(sight.get_parent().bone_name == ("Slide" if id == "pistol" else "Control"),id+": sight follows the correct rigid part")
		else:
			check(not model.find_child("RearSight",true,false).visible and not model.find_child("FrontSight",true,false).visible,"Machine gun replaces only the two original solid sight blocks")
		p.weapon = index
		p.requested = index
		p.aim = false
		game.weapon.sync(p,1.0,0.0)
		check(sight.visible,id+": top sights remain attached in hip view")
		var expected_hip: Vector3 = {"p90":Vector3(.19,-.10,-.46),"pistol":Vector3(.19,-.085,-.46),"heavy-machine-gun":Vector3(.16,-.095,-.74)}[id]
		check(game.weapon.position.is_equal_approx(expected_hip),id+": original hip placement is unchanged")
		p.aim = true
		game.weapon.sync(p,1.0,0.0)
		var line: Vector3 = model.position+sight.line*model.scale
		var eye_line: Vector3 = game.weapon.transform*line
		check(Vector2(eye_line.x,eye_line.y).length() < .00001,id+": only ADS placement aligns the new top sight with the eye")
		original.free()
	game.weapon.sync(game.local_pawn(),1.0,0.0)

func validate_buffer() -> void:
	var buffer = load("res://scripts/snapshot_buffer.gd").new()
	var a = {"elapsed":1.0,"pawns":{},"zombies":[{"id":1,"pos":Vector2.ZERO,"hp":10,"heading":deg_to_rad(179),"gait":1.0,"state":"ready","attack_time":0.0}]}
	var b: Dictionary = a.duplicate(true)
	b.elapsed = 1.1
	b.zombies[0].pos = Vector2(1,0)
	b.zombies[0].heading = deg_to_rad(-179)
	b.zombies[0].gait = 2.0
	buffer.push(a)
	buffer.push(b)
	buffer.clock = 1.05
	var sample: Dictionary = buffer.sample(0)
	check(absf(sample.zombies[0].pos.x-.5) < .001,"Enemy positions interpolate between timestamped snapshots")
	check(is_equal_approx(sample.zombies[0].gait,1.5),"Running gait interpolates across cooperative snapshots without changing authority")
	check(absf(absf(sample.zombies[0].heading)-PI) < .01,"Heading interpolation takes the short arc")
	check(a.zombies[0].pos == Vector2.ZERO and b.zombies[0].pos == Vector2(1,0),"Display interpolation leaves authority snapshots untouched")
	buffer.push(a)
	check(buffer.history.size() == 2,"Out-of-order snapshots are rejected")
	var teleported: Dictionary = b.duplicate(true)
	teleported.zombies[0].pos = Vector2(20,0)
	var frozen: Dictionary = buffer.blend(a.zombies[0],teleported.zombies[0],.5,false)
	check(frozen.pos == Vector2.ZERO,"Teleports never interpolate through obstacles")
	var dead: Dictionary = b.zombies[0].duplicate()
	dead.hp = 0
	check(buffer.blend(a.zombies[0],dead,.5,false).hp == 10,"Death transitions wait for their snapshot boundary")
	var last: Dictionary = buffer.sample(1)
	check(last.zombies[0].pos == Vector2(1,0),"Missing packets freeze at the newest state without extrapolating")
	buffer.clear()
	check(buffer.sample(.016).is_empty(),"Reset removes stale display entities")

func validate_close_combat() -> void:
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	var saved = p.duplicate(true)
	var original_zombies: Array = sim.zombies.duplicate(true)
	sim.zombies.clear()
	sim.campaign.state.departed = true
	game.arena.sync_campaign(sim.campaign.state)
	p.slot = 1
	p.healing = ""
	p.interaction = ""
	p.pos = Vector2(0,70)
	p.height = 0.0
	p.hp = 100
	p.yaw = 0.0
	p.switch = 0.0
	p.weapon = p.primary
	p.requested = p.primary
	p.shove_gap = 0.0
	p.shove_cd = 0.0
	p.shove_count = 0
	sim.spawn(Vector2(0,67.1),"normal")
	sim.spawn(Vector2(0,71.35),"normal")
	var front: Dictionary = sim.zombies[0]
	var rear: Dictionary = sim.zombies[1]
	# Magazine, revolver and shell reloads continue through right-click shove.
	for gun in [0,3,4]:
		p.weapon = gun
		p.primary = gun
		p.requested = gun
		p.ammo[gun] = 0
		p.reserves[gun] = 10
		p.reloading = true
		p.reload = .2
		p.shove_gap = 0.0
		p.shove_cd = 0.0
		p.shove_count = 0
		check(sim.try_shove(p) and p.reloading and p.reload == .2,"Shove preserves active reload gun "+str(gun))
		sim.update_arsenal(p,{"weapon":gun},.1)
		check(p.reloading and is_equal_approx(p.reload,.1),"Reload clock advances during shove gun "+str(gun))
		sim.update_arsenal(p,{"weapon":gun},.11)
		check(p.ammo[gun] > 0 and (p.reserves[gun] == 10 if gun == 3 else p.ammo[gun]+p.reserves[gun] == 10),"Reload transfers rounds exactly once gun "+str(gun))
	p.primary = saved.primary
	p.weapon = p.primary
	p.requested = p.primary
	p.reloading = false
	p.shove_gap = 0.0
	p.shove_cd = 0.0
	p.shove_count = 0
	front.attack_time = .2
	check(sim.try_shove(p),"First shove is accepted")
	check(front.state == "stunned" and front.attack_time == 0 and rear.state == "ready","Frontal shove interrupts windup without hitting enemies behind")
	check(is_equal_approx(front.state_time,sim.SHOVE_STUN),"Ordinary shove control duration increases by 30 percent")
	sim.hit_enemy(front,1.0,false,p,Vector3(front.pos.x,1,front.pos.y))
	check(is_equal_approx(front.state_time,sim.SHOVE_STUN),"A subsequent bullet flinch does not shorten shove control")
	var old = front.pos
	sim.update_zombie(front,p,.26)
	check(front.pos.distance_to(old) > 2.7 and game.arena.clear(old,front.pos),"Shove displacement is clipped through real terrain")
	check(not sim.try_shove(p),"Shove rejects immediate repeated input")
	for i in 2:
		p.shove_gap = 0.0
		check(sim.try_shove(p),"Accepted spaced shove "+str(i))
	check(p.shove_cd == sim.SHOVE_COOLDOWN and not sim.try_shove(p),"Three rapid shoves trigger cooldown")
	p.input = {}
	sim.update_pawn(p,sim.SHOVE_COOLDOWN+.01)
	check(p.shove_cd == 0 and p.shove_count == 0 and sim.try_shove(p),"Cooldown expires and restores shove")
	p.shove_gap = 0.0
	p.shove_cd = 0.0
	p.shove_count = 0
	sim.zombies.clear()
	sim.spawn(Vector2(0,66),"normal")
	var extended: Dictionary = sim.zombies[0]
	check(sim.try_shove(p) and extended.state == "stunned","Shove reaches a target four metres away after the 30-percent range increase")
	p.shove_gap = 0.0
	p.shove_cd = 0.0
	p.shove_count = 0
	sim.zombies.clear()
	sim.spawn(Vector2(0,65.83),"normal")
	var beyond: Dictionary = sim.zombies[0]
	check(sim.try_shove(p) and beyond.state == "ready","Shove still rejects a target beyond 4.16 metres")
	for kind in ["shield","football","giant","berserker"]:
		p.shove_gap = 0.0
		p.shove_cd = 0.0
		p.shove_count = 0
		sim.zombies.clear()
		sim.spawn(Vector2(0,68.65),kind)
		var shoved: Dictionary = sim.zombies[0]
		if kind == "berserker": shoved.rage = true
		shoved.attack_time = .2
		var shove_start: Vector2 = shoved.pos
		var hit_count: int = p.shove_hits
		check(sim.try_shove(p),"Shove is accepted against "+kind)
		check(shoved.state == "ready" and shoved.attack_time == 0 and is_equal_approx(shoved.shove_time,.26) and is_equal_approx(shoved.shove_velocity.length(),2.8/.26) and p.shove_hits == hit_count+1,"Shove gives normal knockback without stun to "+kind)
		sim.update_zombie(shoved,p,.1)
		check(shoved.pos.distance_to(shove_start) > .1 and shoved.state != "stunned","Shove moves "+kind+" without stunning it")
	p.shove_gap = 0.0
	p.shove_cd = 0.0
	p.shove_count = 0
	sim.zombies.clear()
	sim.spawn(Vector2(0,68.65),"berserker")
	var calm_shove_target: Dictionary = sim.zombies[0]
	check(sim.try_shove(p) and calm_shove_target.state == "stunned" and is_equal_approx(calm_shove_target.state_time,sim.SHOVE_STUN),"Berserker can still be stunned before raging")
	for charge_state in ["windup","charging"]:
		p.shove_gap = 0.0
		p.shove_cd = 0.0
		p.shove_count = 0
		sim.zombies.clear()
		sim.spawn(Vector2(0,68.65),"football")
		var football: Dictionary = sim.zombies[0]
		football.state = charge_state
		football.state_time = .2
		football.attack_time = .1
		var charge_start: Vector2 = football.pos
		var charge_hit_count: int = p.shove_hits
		check(sim.try_shove(p) and football.state == charge_state and is_equal_approx(football.state_time,.2) and is_equal_approx(football.attack_time,.1) and football.pos == charge_start and football.shove_time == 0 and p.shove_hits == charge_hit_count,"Football "+charge_state+" is immune to shove")
	# Use an existing native collider: the pushed body must stop at its clearance.
	var wall_checked = false
	for obstacle in game.arena.obstacles:
		var edge = Vector2(obstacle.minX,(obstacle.minZ+obstacle.maxZ)*.5)
		var start = edge-Vector2(1.15,0)
		var player_start = edge-Vector2(2.5,0)
		if not game.arena.clear(player_start,start): continue
		if game.arena.surface_hit(Vector3(edge.x-.3,1.1,edge.y),Vector3(edge.x+.3,1.1,edge.y)).is_empty(): continue
		sim.zombies.clear()
		sim.spawn(start,"normal")
		var blocked: Dictionary = sim.zombies[0]
		p.pos = player_start
		p.yaw = -PI/2
		p.shove_cd = 0.0
		p.shove_gap = 0.0
		sim.try_shove(p)
		sim.update_zombie(blocked,p,.18)
		check(blocked.pos.x <= edge.x-.95 and blocked.pos.distance_to(start) < .3,"A shove against a real wall stops before its clearance margin")
		p.pos = edge-Vector2(.3,0)
		blocked.pos = edge+Vector2(.3,0)
		blocked.state = "ready"
		blocked.shove_time = 0.0
		p.shove_cd = 0.0
		p.shove_gap = 0.0
		sim.try_shove(p)
		check(blocked.state == "ready" and blocked.shove_time == 0,"A wall blocks the shove hit itself")
		wall_checked = true
		break
	check(wall_checked,"Close-combat obstruction fixture found a native wall")
	p.pos = Vector2(0,70)
	p.yaw = 0.0
	sim.zombies.clear()
	for i in 24: sim.spawn(Vector2(i*.02,66),"normal")
	var speeds = sim.zombies.map(func(z): return z.chase_speed)
	check(speeds.min() >= 4.6 and speeds.max() <= 5.2 and speeds.max()-speeds.min() > .3,"Spawned normal speeds vary within the faster-than-player range")
	var goals = sim.zombies.map(func(z): return sim.approach_goal(z,p))
	check(goals[0].distance_to(goals[1]) > 1 and goals[1].distance_to(goals[2]) > 1,"Nearby enemies choose distributed approach slots")
	sim.zombies.clear()
	sim.spawn(Vector2(0,68.8),"normal")
	var attacker: Dictionary = sim.zombies[0]
	p.pos = Vector2(0,70)
	p.protection = 0.0
	sim.events.clear()
	sim.update_zombie(attacker,p,.1)
	check(p.hp == 100 and attacker.attack_time > 0 and sim.events.any(func(e): return e.kind == "enemy_windup"),"Attack announces a windup before dealing damage")
	p.pos = Vector2(4,70)
	sim.update_zombie(attacker,p,.45)
	check(p.hp == 100 and sim.events.any(func(e): return e.kind == "enemy_miss"),"Lateral movement can evade the limited-turn attack advance")
	attacker.attack_time = 0.0
	p.pos = Vector2(0,70)
	attacker.pos = Vector2(0,68.8)
	attacker.chase_speed = 4.8
	sim.events.clear()
	sim.update_zombie(attacker,p,.01)
	for i in 5:
		p.pos.y += sim.PLAYER_MOVE_SPEED*.1
		sim.update_zombie(attacker,p,.1)
	check(p.hp == 90 and sim.events.any(func(e): return e.kind == "enemy_impact"),"A faster enemy advances through windup and hits a continuously retreating player")
	p.protection = 0.0
	attacker.pos = p.pos+Vector2(0,1)
	sim.damage_pawn(p,attacker)
	check(p.damage_rear and p.damage_hint == 1.8 and p.damage_dir.y > .9,"Rear damage records direction and warning on authority")
	check(p.protection == .65 and not sim.damage_pawn(p,attacker),"Rear warning includes a reaction window against overlapping hits")
	p.protection = 0.0
	attacker.pos = p.pos-Vector2(0,1)
	sim.damage_pawn(p,attacker)
	check(not p.damage_rear,"Frontal hit does not falsely report a rear attack")
	attacker.move_speed = 4.8
	game.sound.clear_effects()
	var old_voice: int = game.sound.spatial_index
	game.sound.sync_enemy_steps([attacker],Vector3(p.pos.x,1,p.pos.y),.1)
	check(game.sound.spatial_index == old_voice+1,"Moving nearby zombie routes a spatial footstep")
	game.sound.sync_enemy_steps([attacker],Vector3(p.pos.x,1,p.pos.y),.01)
	check(game.sound.spatial_index == old_voice+1,"Footstep cadence prevents frame-rate spam")
	attacker.move_speed = 0.0
	game.sound.sync_enemy_steps([attacker],Vector3(p.pos.x,1,p.pos.y),1.0)
	check(game.sound.spatial_index == old_voice+1,"Stationary zombie does not produce walking sounds")
	for cue in ["enemy-step-0","enemy-step-1","rear-warning","enemy-windup","enemy-impact","enemy-miss","shove","shove-hit"]:
		check(game.sound.streams.has(cue) and game.sound.streams[cue].get_length() > .15,"Close-combat sound resource exists: "+cue)
	var middle = InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	game.reset_mouse_buttons()
	game._input(middle)
	check(game.input_state().aim,"Middle click toggles aim on")
	middle.pressed = false
	game._input(middle)
	check(game.input_state().aim,"Aim remains enabled after middle release")
	middle.pressed = true
	game._input(middle)
	check(not game.input_state().aim,"Second middle click toggles aim off")
	for weapon_index in [4,6,7,8]:
		p.primary = weapon_index
		p.weapon = weapon_index
		p.requested = weapon_index
		p.slot = 1
		p.switch = 0.0
		game.requested_weapon = weapon_index
		game.reset_mouse_buttons()
		game._input(middle)
		check(not game.input_state().aim,"Middle click has no effect for non-ADS weapon "+str(weapon_index))
		p.aim = true
		sim.update_arsenal(p,{"weapon":weapon_index,"aim":true},.01)
		check(not p.aim,"Authority rejects ADS state for non-ADS weapon "+str(weapon_index))
	p.primary = saved.primary
	p.weapon = p.primary
	p.requested = p.primary
	p.slot = 1
	game.requested_weapon = p.primary
	var right = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	game._input(right)
	check(game.input_state().shove and not game.input_state().shove,"Right click produces one consumed shove edge")
	var session = root.get_node("Session")
	var recovered = session.recover_input_edges("shove_fixture",{"shove":false,"shove_seq":1})
	check(recovered.shove and not session.recover_input_edges("shove_fixture",{"shove_seq":1}).shove,"Network retains a lost shove edge and does not replay duplicate counters")
	session.received_edges.erase("shove_fixture")
	var ready_recovered = session.recover_input_edges("ready_fixture",{"wave_ready":false,"wave_ready_seq":1})
	check(ready_recovered.wave_ready and not session.recover_input_edges("ready_fixture",{"wave_ready_seq":1}).wave_ready,"Network retains a lost T press and does not replay duplicate counters")
	session.received_edges.erase("ready_fixture")
	game.reset_mouse_buttons()
	for key in saved: p[key] = saved[key]
	sim.zombies = original_zombies

func validate_inventory_and_heal() -> void:
	game.return_home()
	game.start_solo("campaign",71245)
	await physics_frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	var equipment = sim.campaign.equipment
	check(sim.campaign.state.loot.all(func(g): return g.weapon != 3),"No revolver supply appears on route")
	p.slot = 2
	p.weapon = 3
	p.requested = 3
	p.ammo[3] = 0
	p.reserves[3] = 0
	p.switch = 0.0
	sim.update_arsenal(p,{"reload":true},.01)
	check(p.reloading,"Revolver can reload with zero reserve")
	sim.update_arsenal(p,{},2.0)
	check(p.ammo[3] == 6 and p.reserves[3] == 0,"Infinite reserve refills six chambers without negative inventory")
	p.slot = 1
	p.grenades = 0
	p.medkits = 0
	for slot in [4,5]:
		p.input = {"slot":slot}
		p.input_age = 0.0
		equipment.before_movement(.016)
		check(p.slot == 1,"Authority rejects empty item slot "+str(slot))
		game.requested_slot = 1
		var key = InputEventKey.new()
		key.pressed = true
		key.physical_keycode = KEY_4 if slot == 4 else KEY_5
		game._unhandled_input(key)
		check(game.requested_slot == 1,"Shortcut rejects empty item slot "+str(slot))
	game.requested_slot = 3
	game.cycle_equipment(1)
	check(game.requested_slot == 1,"Wheel skips both empty items")
	p.pos = preload("res://scripts/night_layout.gd").ITEMS[0].pos+Vector2(-1,0)
	sim.campaign.state.grenade_stations.night_start.remaining = 4
	for i in 3: check(equipment.pickup(p,"grenade:night_start") and p.grenades == i+1,"Grenade stacks to "+str(i+1))
	check(not equipment.pickup(p,"grenade:night_start") and sim.campaign.state.grenade_stations.night_start.remaining == 1,"Fourth grenade is rejected without consuming supply")
	p.pos = Vector2(0,70)
	p.yaw = 0.0
	p.pitch = 0.0
	p.slot = 5
	p.medkits = 1
	p.hp = 40
	p.interaction = ""
	p.input_age = 0.0
	p.input = {"slot":5,"use_self":true,"yaw":2.0,"x":1.0}
	equipment.before_movement(.016)
	sim.update_pawn(p,.2)
	check(p.yaw == 0 and p.crouch > .9 and p.pos.distance_to(Vector2(0,70)) < .01,"Self healing crouches and locks movement and facing")
	game.yaw = 0
	game.medical_camera_active = false
	game._process(.016)
	var old_camera: Vector3 = game.camera.position
	for i in 14:
		var motion = InputEventMouseMotion.new()
		motion.screen_relative = Vector2(100,0)
		game._unhandled_input(motion)
	game._process(.016)
	check(p.yaw == 0 and game.camera.position.distance_to(old_camera) > 2 and game.camera.position.z < p.pos.y,"Medical mouse orbit reaches character front without rotating pawn")
	var actor = game.partners[p.id]
	p.heal_time = 1.4
	actor.sync(p,.016)
	check(actor.bandage.visible and actor.bandage_roll.visible and not actor.held.visible,"Healing displays bandage and hides the gun")
	var previous = actor.medical_hands(0,1.0,true)
	var continuous = true
	for i in range(1,301):
		var hands = actor.medical_hands(i*.01,1.0,true)
		if hands.left.distance_to(previous.left) > .08 or hands.right.distance_to(previous.right) > .08: continuous = false
		previous = hands
	check(continuous,"Bandaging hand targets stay continuous across retrieval and wrapping phases")
	p.input = {"slot":5}
	equipment.before_movement(2.0)
	check(p.medkits == 0 and p.slot == 1,"Last medkit consumption returns to primary slot")
	# Full real swing: the expanded reach hits at 3 m but still misses at 4 m.
	sim.campaign.state.departed = true
	sim.zombies.clear()
	p.slot = 3
	p.weapon = 6
	p.requested = 6
	p.reloading = false
	p.crouch = 0
	p.being_healed = false
	p.healing = ""
	for distance in [4.0,3.0,1.8]:
		sim.zombies.clear()
		sim.spawn(p.pos+Vector2(0,-distance),"normal")
		var w: Dictionary = root.get_node("Data").weapons[6]
		p.fire_anim = w.fireDuration
		sim.fire(p,w)
		for step in 10:
			p.fire_anim = maxf(0,p.fire_anim-.056)
			sim.update_melee_swing(p,w)
		check((sim.zombies[0].hp > 0) == (distance > 3.5),"Axe expanded reach with unchanged lethal damage at "+str(distance))
	game.return_home()
	game.start_solo("campaign",71245)
	await physics_frame

func validate_equipment() -> void:
	var layout = load("res://scripts/night_layout.gd")
	for party in [1,2]:
		game.return_home()
		game.start_solo("campaign",71245)
		if party == 2:
			game.sim.campaign = null
			game.sim.add_pawn("equipment_peer","队友",1)
			game.sim.start("campaign")
		await physics_frame
		await process_frame
		var sim = game.sim
		var director = sim.campaign
		var equipment = director.equipment
		var p: Dictionary = game.local_pawn()
		game.arena.sync_campaign(director.state)
		for model in game.arena.scenery.loot_views.values():
			var bounds: AABB = game.arena.scenery.posed_bounds(model)
			check(bounds.size.x > .5 and bounds.size.x < 1.12 and bounds.position.y > 1.0,"Wall gun has readable displayed size and is above the supply table")
		for item in layout.ITEMS:
			check(director.state.medical_stations[item.id].remaining == party,"Guaranteed medical stock equals party at "+item.id)
			if item.kind != "ammo": continue
			var guns: Array = director.state.loot.filter(func(g): return g.station == item.id)
			check(guns.size() == party*2,"Night supply gun count is players x2: "+str(party)+" "+item.id)
			check(guns.all(func(g): return root.get_node("Data").weapons[g.weapon].tier == item.tier),"Night supply respects weapon tier: "+item.id)
			check(director.state.grenade_stations[item.id].remaining == party,"Night supply grenade count equals players")
		p.pos = layout.ITEMS[0].pos+Vector2(-1,0)
		p.grenades = 0
		check(equipment.pickup(p,"grenade:night_start") and p.grenades == 1,"Night grenade pickup fills one slot")
		p.grenades = 3
		var remaining: int = director.state.grenade_stations.night_start.remaining
		check(not equipment.pickup(p,"grenade:night_start") and director.state.grenade_stations.night_start.remaining == remaining,"Three-grenade capacity preserves remaining supply")
		if party == 2:
			var lower: Dictionary = director.state.loot[0]
			var upper: Dictionary = director.state.loot[2]
			p.pos = lower.pos+Vector2(0,1.8)
			p.yaw = 0.0
			p.grenades = 1
			for target in [upper,lower]:
				p.pitch = atan2(target.mount_height-p.height-preload("res://scripts/player_body.gd").eye_height(p),1.8)
				check(equipment.pickup_target(p).get("id","") == target.id,"Pitch independently selects upper and lower wall guns")
		var gun: Dictionary = director.state.loot[0]
		p.pos = gun.pos
		check(equipment.pickup(p,gun.id) and gun.taken,"Night gun can be replaced through the authority pickup")
		check(not equipment.pickup(p,gun.id),"Consumed gun cannot be picked up again")
		if party == 2:
			var peer: Dictionary = sim.pawns.equipment_peer
			p.pos = layout.ITEMS[0].pos+Vector2(1,0)
			peer.pos = p.pos
			p.medkits = 0
			peer.medkits = 0
			check(equipment.pickup(p,"medical:night_start") and equipment.pickup(peer,"medical:night_start"),"Both peers collect distinct guaranteed medical packs")
			p.medkits = 0
			check(not equipment.pickup(p,"medical:night_start") and director.state.medical_stations.night_start.remaining == 0,"Consumed duo medical stock cannot be duplicated")
		var med: Dictionary = layout.ITEMS[-1]
		p.pos = med.pos
		p.medkits = 1
		director.perform(p,med.id)
		check(p.medkits == 1 and not director.state.taken.has(med.id),"Full medical slot preserves the world medical pack")
		p.medkits = 0
		director.perform(p,med.id)
		check(p.medkits == 1 and director.state.medical_stations[med.id].remaining == party-1,"Empty medical slot can collect one medical pack")
		p.pos = Vector2(0,70)
		p.hp = 40
		p.slot = 5
		p.interaction = ""
		p.input_age = 0.0
		p.input = {"slot":5,"use_self":true,"y":-1}
		equipment.before_movement(.016)
		check(p.healing == p.id,"Left medical input starts self healing")
		var before: Vector2 = p.pos
		sim.update_pawn(p,.1)
		check(p.pos.distance_to(before) < .01,"Healing blocks movement")
		equipment.before_movement(3.0)
		check(p.hp == 100 and p.medkits == 0 and p.healing == "","Completed healing consumes one kit")
		if party == 2:
			var q: Dictionary = sim.pawns.equipment_peer
			q.pos = Vector2(0,68.5)
			q.hp = 40
			p.yaw = 0.0
			p.medkits = 1
			p.input = {"slot":5,"use_other":true}
			equipment.before_movement(.016)
			check(p.healing == q.id and q.being_healed,"Right medical input selects the nearby teammate")
			equipment.before_movement(3.0)
			check(q.hp == 100 and p.medkits == 0,"Teammate healing consumes the healer's single kit")
		p.slot = 1
		p.grenades = 1
		var old_hp: int = p.hp
		sim.zombies.clear()
		sim.spawn(Vector2(0,68.7),"normal")
		equipment.throw_grenade(p)
		check(p.grenades == 0 and director.state.projectiles[0].fuse == 1.5,"Thrown grenade empties slot and has a 1.5-second fuse")
		sim.spawn(Vector2(0,59.5),"normal")
		equipment.explode({"owner":p.id,"pos":Vector3(0,1,69)})
		check(sim.zombies[1].hp > 0,"Closed safe-room door blocks the expanded blast")
		director.state.departed = true
		game.arena.sync_campaign(director.state)
		equipment.explode({"owner":p.id,"pos":Vector3(0,1,69)})
		check(sim.zombies[1].hp <= 0,"Expanded blast reaches an unobstructed enemy 9.5 metres away")
		check(sim.zombies[0].hp <= 0 and p.hp == old_hp,"Close grenade kills ordinary infected without self damage")
		if party == 2: check(sim.pawns.equipment_peer.hp == 100,"Grenade does not damage teammate")
	game.return_home()
	game.start_solo("campaign",71245)
	await physics_frame
	await process_frame
