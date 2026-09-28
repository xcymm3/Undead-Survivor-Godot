extends Node
## Opt-in browser fixtures only stage enemies. Normal game physics performs all combat.
var game
var scenario = ""
var active = false
var time = 0.0
var explosions = 0
var prime_edges = 0
var primed = false
var bypass = false
var targeted = {}
var crossed = false
var second_id = -1
var spent_time = -1.0

func _ready() -> void:
	if not Data.automation or not OS.has_feature("web") or "--qa-defense-structures" not in OS.get_cmdline_user_args():
		queue_free()
		return
	scenario = str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('structureCase')",true))
	if scenario not in ["gate","kills","destroy","mine"]:
		queue_free()
		return
	call_deferred("stage")

func stage() -> void:
	game.start_solo("defense",42)
	game.sim.roster.clear()
	game.sim.defense.started = true
	game.sim.defense.waiting = false
	var manager = game.sim.defense_director.structures
	if scenario == "gate":
		var kinds: Array = Data.enemies.keys()
		for i in kinds.size()*2:
			game.sim.spawn(Vector2([-2.8,0.0,2.8][i%3],-34.0-floori(i/3)*2.5),kinds[i%kinds.size()])
	elif scenario == "kills":
		game.sim.spawn(manager.find("turret_left").pos+Vector2(0,4),"normal")
		game.sim.spawn(manager.find("turret_left").pos+Vector2(1,5),"crawler")
	elif scenario == "destroy":
		for i in 16:
			var angle = float(i)/15*PI
			var radius = 2.3+float(i%2)*1.3
			game.sim.spawn(manager.find("turret_left").pos+Vector2(cos(angle),sin(angle))*radius,"giant")
	else:
		game.sim.spawn(manager.find("crystal_mine").pos+Vector2(0,-2),"normal")
	game.ui.root.visible = false
	game.weapon.visible = false
	active = true

func _physics_process(dt: float) -> void:
	if not active: return
	time += dt
	var sim = game.sim
	var manager = sim.defense_director.structures
	var gate: Dictionary = manager.find("bridge_gate")
	var turret: Dictionary = manager.find("turret_left")
	var mine: Dictionary = manager.find("crystal_mine")
	for z in sim.zombies:
		if z.hp <= 0: continue
		targeted[z.get("target","")] = true
		if scenario == "gate" and z.pos.y > -30:
			if gate.hp > 0: bypass = true
			else: crossed = true
	for event in sim.events:
		if event.kind == "explosion": explosions += 1
	if mine.triggered and not primed: prime_edges += 1
	primed = mine.triggered
	if scenario == "mine" and mine.spent and second_id < 0:
		spent_time = time
		sim.spawn(mine.pos,"normal")
		second_id = sim.zombies[-1].id
	var survivor_hp = -1.0
	for z in sim.zombies:
		if z.id == second_id: survivor_hp = z.hp
	var actor: Dictionary = game.arena.scenery.structure_view.actors.turret_left
	var done = (scenario == "gate" and crossed) or (scenario == "kills" and sim.kills == 2) or (scenario == "destroy" and turret.hp == 0 and time-turret.destroyed_at > 1.0) or (scenario == "mine" and spent_time >= 0 and time-spent_time > 3.0)
	var report = {"case":scenario,"time":time,"done":done,"bypass":bypass,"crossed":crossed,"targets":targeted.keys(),"gate_hp":gate.hp,"turret_hp":turret.hp,"shots":turret.shots,"kills":sim.kills,"player_shots":sim.pawns.solo.shots,"wreck_visible":actor.root.visible,"wreck_tilt":actor.yaw.rotation.z,"wreck_collision":actor.body.collision_layer,"mine_triggered":mine.triggered,"mine_spent":mine.spent,"prime_edges":prime_edges,"explosions":explosions,"second_hp":survivor_hp,"normal_hp":Data.enemies.normal.health,"failed":sim.failed}
	JavaScriptBridge.eval("window.__structureReport="+JSON.stringify(report),true)
	if done or time > 90 or sim.failed:
		game.running = false
		active = false
		game.weapon.visible = false
		game.ui.root.visible = false
		game.enemies.sync(sim.zombies,sim.elapsed,false)
		RenderingServer.render_loop_enabled = true

func _process(_dt: float) -> void:
	if scenario.is_empty() or not game.sim: return
	game.camera.position = Vector3(14,12,-1) if scenario in ["kills","destroy"] else Vector3(10,8,-22) if scenario == "gate" else Vector3(6,9,33)
	game.camera.look_at(Vector3(0,3,-6) if scenario in ["kills","destroy"] else Vector3(0,0,-32) if scenario == "gate" else Vector3(0,3,39),Vector3.UP)
