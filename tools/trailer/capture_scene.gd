extends Node
## Promotional camera staging, copied only into the isolated export by capture.mjs.
## Combat, weapon poses, enemy meshes and summoning remain the project's native code.
var game
var shot := ""
var frame := -1
var busy := false
var boss: Dictionary = {}
var cue_log: Array = []
var flash: OmniLight3D
var key_light: OmniLight3D
var hero: Node3D
const FPS = 24.0

func _ready() -> void:
	if not Data.automation or not OS.has_feature("web"):
		queue_free()
		return
	call_deferred("initialize")

func initialize() -> void:
	game.set_process(false)
	game.set_physics_process(false)
	game.ui.root.hide()
	Data.settings.resolution = 1.0
	Data.settings.aa = 1
	Data.settings.shadows = 1
	Data.settings.effects = 2
	Data.settings.pixelated = false
	Data.apply_settings()
	game.get_viewport().scaling_3d_scale = 1.0
	RenderingServer.render_loop_enabled = false
	flash = OmniLight3D.new()
	flash.light_color = Color("ffb564")
	flash.omni_range = 12
	flash.light_energy = 0
	game.add_child(flash)
	key_light = OmniLight3D.new()
	key_light.light_color = Color("8ab9ff")
	key_light.omni_range = 18
	key_light.light_energy = 1.5
	game.add_child(key_light)
	JavaScriptBridge.eval("window.__trailerReady=true",true)

func _process(_dt: float) -> void:
	if busy or not is_instance_valid(flash): return
	var raw = JavaScriptBridge.eval("window.__trailerCommand ? JSON.stringify(window.__trailerCommand) : ''",true)
	if not raw is String or raw.is_empty(): return
	JavaScriptBridge.eval("window.__trailerCommand=null",true)
	var command = JSON.parse_string(raw)
	busy = true
	if command.get("shot",shot) != shot: await stage(str(command.shot))
	advance(int(command.get("frame",0)))
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	await get_tree().process_frame
	RenderingServer.force_draw(true)
	var report = {"shot":shot,"frame":frame,"alive":game.sim.alive_count(),"kills":game.sim.kills,"shots":game.local_pawn().shots,"cues":cue_log,"dancing":boss.get("dance_remaining",0),"summoned":game.sim.zombies.filter(func(z): return z.get("summoned",false)).size()}
	JavaScriptBridge.eval("window.__trailerFrame="+JSON.stringify(report),true)
	busy = false

func stage(id: String) -> void:
	shot = id
	frame = -1
	boss = {}
	cue_log = []
	game.start_solo("defense",20261014)
	await get_tree().physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.ui.root.hide()
	game.pixelation.hide()
	game.enemies.clear()
	game.sim.roster.clear()
	game.sim.zombies.clear()
	game.sim.defense.started = true
	game.sim.defense.waiting = true
	game.sim.defense.crystal_hp = game.sim.defense.crystal_max_hp
	game.weapon.reset_motion()
	if is_instance_valid(hero): hero.queue_free()
	hero = null
	game.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	game.camera.fov = 67
	game.camera.cull_mask = 3
	game.arena.sun.light_energy = .65
	game.arena.sun.shadow_enabled = true
	game.arena.sun.directional_shadow_max_distance = 36
	RenderingServer.directional_shadow_atlas_set_size(1024,true)
	for environment in game.arena.find_children("*","WorldEnvironment",true,false):
		environment.environment.ambient_light_energy = .36
		environment.environment.fog_density = .008
	var p = game.local_pawn()
	p.pos = Vector2(0,14)
	p.height = 3
	p.yaw = 0
	p.pitch = 0
	p.protection = 999
	p.reserves[0] = 510
	key_light.position = Vector3(-3,8,8)
	game.weapon.visible = id in ["rifle","axe","finale"]
	if id in ["horde","rifle","finale"]:
		var rows = 9 if id == "horde" else 7
		for row in rows:
			for column in 10:
				var x = (column-4.5)*1.28+game.sim.random.randf_range(-.15,.15)
				var z = 3.8-row*1.3+game.sim.random.randf_range(-.2,.2)
				game.sim.spawn(Vector2(x,z),"bucket" if (row+column)%7 == 0 else "cone" if (row+column)%5 == 0 else "normal")
				game.sim.zombies[-1].chase_speed = 1.3 if id == "horde" else 1.6
		if id == "finale":
			p.pos = Vector2(0,13)
			game.sim.equipment.initialize()
			p.protection = 999
			hero = preload("res://scripts/partner_view.gd").new()
			game.add_child(hero)
			hero.setup(p)
			hero.label.hide()
			hero.hide()
		elif id == "rifle":
			game.sim.progression.data.magazines.rifle_magazine = 5
			p.ammo[0] = game.sim.weapon_capacity(0)
			p.slot_ammo[0] = p.ammo[0]
	if id == "axe":
		p.pos = Vector2(0,9)
		p.slot = 3
		p.weapon = 6
		p.requested = 6
		for row in 5:
			for column in 7:
				game.sim.spawn(Vector2((column-3)*1.12,6.2-row*1.3),"normal")
				game.sim.zombies[-1].chase_speed = 1.05
		key_light.position = Vector3(-3,7,10)
	if id == "boss":
		p.pos = Vector2(0,26)
		game.sim.spawn(Vector2(0,5),"dancer")
		boss = game.sim.zombies[-1]
		boss.summon_clock = 1.8
		boss.heading = 0
		key_light.position = Vector3(-2.7,6.1,8)
		key_light.light_color = Color("ff87df")
		key_light.light_energy = 2.2
		for i in 8:
			game.sim.spawn(Vector2(-7+i*2,-4-(i%2)*2),"bucket" if i%2 == 0 else "normal")
	else:
		key_light.light_color = Color("8ab9ff")
		key_light.light_energy = 1.5
	if id == "armory":
		p.pos = Data.Maps.Defense.SHOP_POINT+Vector2(0,-4)
		p.height = 3
		game.sim.defense.started = false
	game.enemies.sync(game.sim.zombies,0,false)

func advance(target_frame: int) -> void:
	while frame < target_frame:
		frame += 1
		var t = float(frame)/FPS
		var dt = 1.0/FPS
		var sim = game.sim
		var p = game.local_pawn()
		cue_log = []
		if shot == "boss":
			sim.elapsed += dt
			sim.events.clear()
			preload("res://scripts/dancer_boss.gd").step(sim,dt)
			for zombie in sim.zombies:
				zombie.emerge_remaining = maxf(0,zombie.get("emerge_remaining",0.0)-dt)
				zombie.gait += dt*2
				zombie.heading = 0
			game.camera.fov = 51 if t < 4.75 else 64
			if t < 4.75:
				game.camera.position = Vector3(1.3-.28*t,5.0,11.5-.10*t)
				game.camera.look_at(Vector3(0,4.88,5))
			else:
				var k = smoothstep(4.75,7.4,t)
				game.camera.position = Vector3(0,5.0+5*k,11+8*k)
				game.camera.look_at(Vector3(0,4.88-.5*k,5))
			key_light.light_color = Color.from_hsv(fmod(t*.17+.78,1),.48,1)
			key_light.light_energy = 2.0+.35*sin(t*TAU*2)
		elif shot == "armory":
			sim.elapsed += dt
			sim.defense.prop_clock += dt
			var wall_z = preload("res://scripts/defense_layout.gd").SHOP_WALL_Z
			game.camera.position = Vector3(-11+t*.65,4.75,wall_z-5.6)
			game.camera.look_at(Vector3(-9,4.42,wall_z-2.3))
			game.camera.fov = 57
		else:
			var fire = shot in ["rifle","axe","finale"] and t > .4
			var aim = Vector3(0,4.45,1)
			if fire:
				var best = INF
				for zombie in sim.zombies:
					if zombie.hp <= 0 or zombie.pos.y >= p.pos.y-.5: continue
					var score = zombie.pos.distance_to(p.pos)+absf(zombie.pos.x-p.pos.x)*1.8
					if score < best:
						best = score
						aim = Vector3(zombie.pos.x,Data.enemy_ground_height(zombie.pos)+1.74,zombie.pos.y)
				var eye = Vector3(p.pos.x,p.height+1.65,p.pos.y)
				var direction = (aim-eye).normalized()
				p.yaw = lerp_angle(p.yaw,atan2(-direction.x,-direction.z),.5 if shot == "axe" else .32)
				p.pitch = lerpf(p.pitch,asin(direction.y),.4)
			if shot == "axe":
				p.pos.y = 9+minf(t*.14,.9)
			if shot == "finale":
				p.pos.x = sin(t*.5)*1.3
			sim.submit(p.id,{"x":0,"y":0,"yaw":p.yaw,"pitch":p.pitch,"weapon":p.weapon,"slot":p.slot,"fire":fire,"aim":shot == "rifle" and t > 3.9 and t < 6.5})
			sim.step(dt)
			game.camera.position = Vector3(p.pos.x,p.height+1.65,p.pos.y)
			game.camera.rotation = Vector3(p.pitch,p.yaw,0)
			if shot == "horde":
				game.camera.position = Vector3(-10+t*.9,8.8-t*.5,14-t*.9)
				game.camera.look_at(Vector3(0,4.1,-1+t*.3))
				game.camera.fov = 65
			elif shot == "finale" and t > 5.2:
				game.weapon.hide()
				hero.show()
				hero.sync(p,dt,false)
				hero.label.hide()
				game.camera.position = Vector3(-9-(t-5.2)*2,9+(t-5.2)*1.5,22+(t-5.2)*2)
				game.camera.look_at(Vector3(0,4.4,9))
			else:
				game.camera.fov = 66 if shot == "axe" else lerpf(65,54,game.weapon.ads)
				game.weapon.sync(p,dt,sim.elapsed,game.camera.to_local(aim))
		game.effects.step(dt)
		flash.light_energy = maxf(0,flash.light_energy-dt*55)
		for event in sim.events:
			var kind: String = str(event.kind)
			if kind == "shot":
				cue_log.append({"kind":"axe" if int(event.weapon) == 6 else "rifle","time":t})
				if int(event.weapon) != 6:
					var origin = game.weapon.muzzle_position()
					game.effects.eject_shell(origin,event.to-origin)
					flash.position = Vector3(p.pos.x,p.height+1.4,p.pos.y-1)
					flash.light_energy = 2.6
			elif kind in ["blood","death","armor"]:
				game.effects.burst(event.position,kind == "armor",event.get("broken",false))
				if kind == "death": cue_log.append({"kind":"impact","time":t})
			elif kind == "disco": cue_log.append({"kind":"disco","time":t})
		game.enemies.sync(sim.zombies,sim.elapsed,false)
		game.coins.sync(sim.coin_drops)
		game.arena.scenery.sync(sim.defense)
