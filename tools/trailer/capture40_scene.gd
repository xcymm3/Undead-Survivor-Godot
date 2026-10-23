extends Node
## Isolated promotional staging; never attached to production gameplay.
const Layout = preload("res://scripts/defense_layout.gd")
var game
var shot = ""
var frame = -1
var busy = false
var cues: Array = []
var actors: Array = []
var boss: Dictionary = {}
var light: OmniLight3D
var revision = 1

func _ready():
	call_deferred("initialize")

func initialize():
	revision = int(JavaScriptBridge.eval("window.__trailerRevision || 1",true))
	game.set_process(false)
	game.set_physics_process(false)
	light = OmniLight3D.new()
	light.omni_range = 17
	light.light_color = Color("a8cbff")
	light.light_energy = 1.1
	game.add_child(light)
	Data.settings.resolution = 1.0
	Data.settings.aa = 0
	Data.settings.shadows = 1
	Data.apply_settings()
	# Software transparent depth composition cannot faithfully composite the afterimage.
	# Keep the production animated blade and flowing energy; omit that overlay only.
	game.weapon.blade_trail.layers = 0
	RenderingServer.render_loop_enabled = false
	JavaScriptBridge.eval("window.__trailerReady=true",true)

func _process(_dt):
	if busy or not is_instance_valid(light): return
	var raw = JavaScriptBridge.eval("window.__trailerCommand ? JSON.stringify(window.__trailerCommand) : ''",true)
	if not raw is String or raw.is_empty(): return
	busy = true
	JavaScriptBridge.eval("window.__trailerCommand=null",true)
	var cmd = JSON.parse_string(raw)
	if cmd.shot != shot: await stage(cmd.shot)
	while frame < int(cmd.frame):
		frame += 1
		advance(float(frame)/24.0,1.0/24)
	game.first_person_layer.sync_view()
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	var p = game.local_pawn()
	var structures = game.sim.defense.get("structures",[]).filter(func(s): return s.get("owned",false) and s.hp > 0).size()
	JavaScriptBridge.eval("window.__trailerFrame="+JSON.stringify({"shot":shot,"frame":frame,"kills":game.sim.kills,"shots":p.shots,"alive":game.sim.alive_count(),"summoned":game.sim.zombies.filter(func(z):return z.get("summoned",false)).size(),"ultimate":p.get("ultimate_remaining",0),"team":actors.size(),"level":game.sim.progression.level("rifle"),"structures":structures,"crystalHP":game.sim.defense.crystal_hp,"cues":cues}),true)
	busy = false

func stage(id):
	shot = id
	frame = -1
	boss = {}
	for actor in actors: actor.queue_free()
	actors.clear()
	Progress.store = preload("res://scripts/progression_store.gd").new()
	Progress.store.data.merge({"intro_seen":true,"tutorial_stage":preload("res://scripts/onboarding.gd").COMPLETE,"ultimate_unlocked":true,"ultimate_choice":"blade","coins":9000.0,"ultimate_level":4},true)
	if id == "build" or (id == "defense" and revision == 1):
		if revision == 1:
			for key in Progress.store.BUILDINGS: Progress.store.data.buildings[key].owned = true
		for key in Progress.store.MINES: Progress.store.data.mines[key] = true
	Progress.store.data.magazines.rifle_magazine = 6
	Progress.store.data.grenade_level = 1
	if id == "upgraded": Progress.store.data.weapons.rifle = 1
	if id == "ultimate": Progress.store.data.ultimate_level = 0
	game.start_solo("defense",20261023)
	await get_tree().physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.ui.clear_menu()
	game.ui.root.hide()
	game.pixelation.hide()
	game.sim.roster.clear()
	game.sim.defense.started = true
	game.sim.defense.waiting = true
	game.sim.defense.crystal_repair_required = false
	game.sim.defense.crystal_hp = 3000
	if revision == 2 and id == "build": game.sim.defense.waiting = false
	game.camera.fov = 66
	game.arena.sun.light_energy = .48
	game.arena.sun.shadow_enabled = true
	RenderingServer.directional_shadow_atlas_set_size(1024,true)
	for env in game.arena.find_children("*","WorldEnvironment",true,false): env.environment.ambient_light_energy = .34
	var p = game.local_pawn()
	p.pos = Vector2(0,13)
	p.height = 3
	p.protection = 999
	p.yaw = 0
	p.pitch = 0
	game.weapon.reset_motion()
	game.weapon.visible = id in ["rifle","ultimate","upgraded"]
	game.coins.visible = id != "ultimate"
	light.position = Vector3(-3,7,8)
	if id in ["rifle","ultimate","defense","build","team","upgraded"]:
		for row in 7:
			for col in 9:
				var point = Vector2((col-4)*1.2+game.sim.random.randf_range(-.25,.25),3-row*1.25)
				if id == "ultimate":
					var angle = (row*9+col)*TAU/63
					point = p.pos+Vector2(sin(angle),cos(angle))*(3.1+row*.27)
				if id == "build": point = Vector2((col-4)*.85,-12-row*1.1)
				if id == "defense": point.y = 6.8-row*1.2
				if revision == 2 and id in ["rifle","upgraded"]: point.y += 2.3
				if revision == 2 and id in ["defense","team"]: point.y = 12.0-row*1.25
				game.sim.spawn(point,"bucket" if col%4 == 0 else "normal")
				if (id == "team" or (revision == 2 and id == "defense")) and col%3 != 0:
					var durability = 5 if revision == 2 and id == "team" else 2
					game.sim.zombies[-1].hp *= durability
					game.sim.zombies[-1].body *= durability
				game.sim.zombies[-1].chase_speed = .65 if id == "ultimate" else 1.15
		if id == "ultimate":
			for i in 24:
				game.sim.spawn(Vector2((i%8-3.5)*1.1,5-floori(i/8.0)*1.3),"normal")
				game.sim.zombies[-1].chase_speed = 1.25
	if id == "boss":
		p.pos = Vector2(0,26)
		game.sim.spawn(Vector2(0,4),"dancer")
		boss = game.sim.zombies[-1]
		boss.summon_clock = .7
		light.position = Vector3(-3,7,8)
	if id == "upgrade":
		game.sim.defense.started = false
		var entry = preload("res://scripts/preparation_catalog.gd").stations()[0]
		p.pos = Vector2(entry.position.x,entry.position.z-2)
		var eye = Vector3(p.pos.x,4.65,p.pos.y)
		var dir = (entry.position-eye).normalized()
		p.yaw = atan2(-dir.x,-dir.z)
		p.pitch = asin(dir.y)
		light.position = entry.position+Vector3(1,2,-2)
	if id == "team" or (revision == 2 and id == "defense"):
		p.pos = Vector2(-4.2,12.2)
		if revision == 2: p.pos.y = 20.0
		for i in 3:
			var id2 = "film_"+str(i)
			game.sim.add_pawn(id2,"",i+1)
			game.sim.equipment.initialize_pawn(game.sim.pawns[id2])
			var other = game.sim.pawns[id2]
			other.pos = Vector2(-1.4+i*2.8,12.2)
			if revision == 2: other.pos.y = 20.0
			other.height = 3
			other.protection = 999
		for i in game.sim.pawns.size():
			var pawn = game.sim.pawns.values()[i]
			pawn.appearance[0] = i%4
			var actor = preload("res://scripts/partner_view.gd").new()
			game.add_child(actor)
			actor.setup(pawn)
			actor.label.hide()
			actors.append(actor)
	game.arena.scenery.sync(game.sim.defense)

func advance(t,dt):
	var sim = game.sim
	var p = game.local_pawn()
	cues = []
	if shot == "boss":
		sim.elapsed += dt
		sim.events.clear()
		preload("res://scripts/dancer_boss.gd").step(sim,dt)
		for z in sim.zombies: z.emerge_remaining = maxf(0,z.get("emerge_remaining",0)-dt)
		var k = smoothstep(3.6,5.8,t)
		game.camera.position = Vector3(1-t*.15,5.1+k*3,10+k*8)
		game.camera.look_at(Vector3(0,4.85,4))
		game.camera.fov = 51+12*k
		light.light_color = Color.from_hsv(fmod(t*.2+.7,1),.35,1)
	else:
		var fire = shot in ["rifle","ultimate","team","upgraded"] and (t > .2 or revision == 2)
		if revision == 2 and shot == "defense": fire = t > .5
		var aim = Vector3(0,4.5,0)
		var best = INF
		for z in sim.zombies:
			if z.hp <= 0 or z.pos.y > p.pos.y-.2: continue
			var score = z.pos.distance_to(p.pos)+absf(z.pos.x-p.pos.x)*1.1
			if score < best:
				best = score
				aim = Vector3(z.pos.x,Layout.height(z.pos)+1.8,z.pos.y)
		if shot != "upgrade":
			var dir = (aim-Vector3(p.pos.x,p.height+1.65,p.pos.y)).normalized()
			p.yaw = lerp_angle(p.yaw,atan2(-dir.x,-dir.z),.3)
			p.pitch = lerpf(p.pitch,asin(dir.y),.3)
		var draw_frame = 24 if revision == 2 else 34
		if shot == "ultimate" and frame < draw_frame: p.ammo[0] = mini(p.ammo[0],1)
		if shot == "ultimate" and frame >= draw_frame: p.reloading = false
		var command = {"x":0,"y":0,"yaw":p.yaw,"pitch":p.pitch,"weapon":p.weapon,"slot":p.slot,"fire":fire,"ultimate":shot == "ultimate" and frame == draw_frame,"aim":shot == "rifle" and t>2.5 and t<4,"interact":shot == "upgrade" and t > .5 and t < 1.7}
		sim.submit(p.id,command)
		if shot == "team" or (revision == 2 and shot == "defense"):
			for other in sim.pawns.values():
				if other.id == p.id: continue
				sim.submit(other.id,{"x":0,"y":0,"yaw":0,"pitch":0,"weapon":0,"slot":1,"fire":true})
		if shot == "rifle" and frame == 50: sim.equipment.throw_grenade(p)
		if revision == 2 and shot == "build": sim.defense.waiting = false
		if revision == 2 and shot == "build" and frame in [0,12,24]:
			var key = ["bridge_gate","turret_left","turret_right"][floori(frame/12.0)]
			if sim.progression.purchase(key): sim.defense_director.structures.refresh_purchase(key)
		sim.step(dt)
		game.camera.position = Vector3(p.pos.x,p.height+1.65,p.pos.y)
		game.camera.rotation = Vector3(p.pitch,p.yaw,0)
		game.camera.force_update_transform()
		game.weapon.sync(p,dt,sim.elapsed,game.camera.to_local(aim))
		if shot == "defense":
			game.camera.position = Vector3(8-t*.7,8,20-t*.6)
			game.camera.look_at(Vector3(0,4.3,10))
			if revision == 2:
				game.camera.position = Vector3(10-t*.9,7.2,25-t*.5)
				game.camera.look_at(Vector3(0,4.5,15.8))
		if shot == "build":
			game.camera.position = Vector3(10-t*.5,7,-3)
			game.camera.look_at(Vector3(0,3.5,-10))
		if shot == "upgrade":
			game.camera.fov = 54
			game.arena.scenery.sync_focus(sim,p)
		if shot == "team":
			var wide = sin(clampf(t/(6.5 if revision == 2 else 5.0),0,1)*PI)
			game.camera.position = Vector3(4+6*wide,6.4+4*wide,19+5*wide)
			game.camera.look_at(Vector3(0,4.4,11))
			if revision == 2:
				game.camera.position = Vector3(4+1.5*wide,6.8+wide,27)
				game.camera.look_at(Vector3(0,4.7,17.8))
			game.camera.fov = 64
			if revision == 2: game.camera.fov = 60
		if shot == "team" or (revision == 2 and shot == "defense"):
			for i in actors.size():
				actors[i].sync(sim.pawns.values()[i],dt,false)
				actors[i].label.hide()
	game.effects.step(dt)
	if revision == 2 and shot == "build" and frame in [0,12,24]: cues.append({"kind":"build","time":t})
	for event in sim.events:
		if event.kind == "turret_shot":
			game.effects.gunshot(event.from,event.to)
			cues.append({"kind":"rifle","time":t})
		elif event.kind == "shot":
			var is_blade = int(event.weapon) == 6
			cues.append({"kind":"blade" if is_blade else "rifle","time":t})
			if not is_blade:
				var origin = game.weapon.muzzle_position() if game.weapon.visible else event.from
				game.effects.gunshot(origin,event.to)
		elif event.kind in ["blood","death","armor"]:
			game.effects.burst(event.position,event.kind == "armor",event.get("broken",false))
		elif event.kind == "explosion":
			game.effects.explosion(event.position)
			cues.append({"kind":"explosion","time":t})
		elif event.kind in ["ultimate_start","disco","world_upgrade","crystal_hit"]: cues.append({"kind":event.kind,"time":t})
	game.enemies.sync(sim.zombies,sim.elapsed,false)
	game.coins.sync(sim.coin_drops)
	game.arena.scenery.sync(sim.defense)
