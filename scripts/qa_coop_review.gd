extends Node
## Isolated Web recording of production simulation, partner views and round controls.
## Transport acknowledgements are fixtures; actual ENet is tested by validate-coop.gd.
const FPS = 12.0
const Ultimate = preload("res://scripts/ultimate.gd")
const TITLES = {
	"fire":"队友开火", "axe":"队友消防斧劈砍", "reload":"队友换弹",
	"switch":"队友换枪", "ultimate":"队友开大劈砍", "guest_death":"队友死亡",
	"retry_failure":"失败结算 → 房主带队重开", "retry_victory":"胜利结算 → 房主带队重开",
	"host_death":"客机视角：房主死亡", "spectate":"阵亡后切换队友视角"
}
const LENGTHS = {"fire":48,"axe":48,"reload":60,"switch":60,"ultimate":72,"guest_death":48,"retry_failure":108,"retry_victory":132,"host_death":72,"spectate":72}
var game
var scenario = ""
var callback: JavaScriptObject
var last_frame = -1
var caption: Label
var target_id = "2"
var restarted = false
var phases: Array = []

func stage(kind: String) -> void:
	if not Data.automation or not OS.has_feature("web") or not TITLES.has(kind): return
	scenario = kind
	Progress.store = preload("res://scripts/progression_store.gd").new()
	Progress.store.data.merge({"intro_seen":true,"tutorial_stage":5,"ultimate_unlocked":true},true)
	Session.set_process(false)
	Session.active = true
	Session.playing = true
	Session.local_id = "1"
	Session.host_id = "1"
	Session.transport = ""
	Session.nonce = "isolated-coop-review"
	Session.members = {"1":"房主","2":"队友阿岚","3":"队友小林"}
	game.start_coop()
	game.set_process(false)
	game.set_physics_process(false)
	await get_tree().physics_frame
	var sim = game.sim
	sim.random.seed = 491
	sim.defense.started = true
	sim.defense.waiting = true
	sim.defense.crystal_hp = sim.defense.crystal_max_hp
	var center: Vector2 = Data.Maps.Defense.CRYSTAL+Vector2(0,8)
	for id in sim.pawns:
		var p: Dictionary = sim.pawns[id]
		p.pos = center+Vector2(6,3) if id == "3" else center
		p.height = 3.0
		p.yaw = .4
		p.pitch = 0.0
		p.protection = 0.0
		p.appearance = [int(id)-1,0,0]
	if scenario == "host_death":
		Session.local_id = "2"
		target_id = "1"
	var observer: Dictionary = game.local_pawn()
	observer.pos = center+Vector2(3,-4)
	var direction: Vector2 = center-observer.pos
	observer.yaw = atan2(-direction.x,-direction.y)
	observer.pitch = -.08
	game.yaw = observer.yaw
	game.pitch = observer.pitch
	var target: Dictionary = sim.pawns[target_id]
	if scenario == "axe":
		target.slot = 3
		target.weapon = 6
		target.requested = 6
	if scenario == "reload":
		target.ammo[0] = 5
		target.slot_ammo[0] = 5
	if scenario == "spectate":
		Session.local_id = "2"
		sim.pawns["1"].pos = center+Vector2(-2,4)
		sim.pawns["1"].yaw = 0.0
		sim.pawns["3"].pos = center+Vector2(7,5)
		sim.pawns["3"].yaw = -.8
		observer = game.local_pawn()
		observer.pos = center+Vector2(2,-4)
		observer.yaw = PI
		game.yaw = observer.yaw
	game.focused = true
	game._process(0)
	game.first_person_layer.sync_view()
	game.arena.scenery.sync(sim.defense)
	var overlay = CanvasLayer.new()
	overlay.layer = 30
	add_child(overlay)
	caption = Label.new()
	caption.position = Vector2(20,82)
	caption.size = Vector2(920,68)
	caption.add_theme_font_override("font",game.ui.font)
	caption.add_theme_font_size_override("font_size",19)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x",2)
	caption.add_theme_constant_override("shadow_offset_y",2)
	overlay.add_child(caption)
	caption.text = TITLES[scenario]+"\n隔离软件渲染 · 脚本场景（非 Steam 双账号实录）"
	for index in 4: await get_tree().process_frame
	RenderingServer.render_loop_enabled = false
	RenderingServer.force_draw(true)
	callback = JavaScriptBridge.create_callback(draw_frame)
	JavaScriptBridge.get_interface("window").__drawCoopReview = callback
	JavaScriptBridge.eval("window.__coopFrame=-1",true)
	JavaScriptBridge.eval("window.__campaignReviewReady="+JSON.stringify({"scenario":scenario,"frames":LENGTHS[scenario],"fps":FPS,"transport":"fixture acknowledgements; ENet verified separately","renderer":"Godot Web / Chromium SwiftShader"}),true)

func command_for(frame: int) -> Dictionary:
	var p: Dictionary = game.sim.pawns[target_id]
	var command = {"yaw":p.yaw,"pitch":p.pitch,"slot":p.slot,"weapon":p.weapon}
	match scenario:
		"fire": command.fire = frame >= 8 and frame < 40
		"axe": command.fire_pressed = frame in [8,20,32]; command.fire = command.fire_pressed
		"reload": command.reload = frame == 8
		"switch":
			command.slot = 1 if frame < 12 or frame >= 48 else 2 if frame < 28 else 3
			command.weapon = 0 if command.slot == 1 else 2 if command.slot == 2 else 6
		"ultimate":
			command.ultimate = frame == 6
			command.fire = frame >= 24
	return command

func kill_pawn(id: String) -> void:
	var p: Dictionary = game.sim.pawns[id]
	p.protection = 0.0
	game.sim.damage_pawn(p,{"id":999,"kind":"normal","pos":p.pos+Vector2(0,-.5)},1000)

func draw_frame(args: Array) -> void:
	var frame = int(args[0])
	if frame != last_frame+1: return
	last_frame = frame
	var sim = game.sim
	if frame == 12:
		if scenario == "guest_death": kill_pawn("2")
		if scenario in ["host_death","retry_failure"]: kill_pawn("1"); sim.fail_from_player_death()
		if scenario == "spectate": kill_pawn("2")
		if scenario == "retry_victory":
			sim.wave = 10
			sim.defense.wave = 10
			sim.spawn(Data.Maps.Defense.CRYSTAL+Vector2(0,-7),"dancer")
			var boss: Dictionary = sim.zombies[-1]
			sim.hit_enemy(boss,boss.hp+1,false,sim.pawns["1"],Vector3(boss.pos.x,4.2,boss.pos.y))
	if scenario == "spectate" and frame in [30,48,60]: game.cycle_spectator()
	if (scenario == "retry_failure" and frame == 84) or (scenario == "retry_victory" and frame == 108):
		game.restart_coop()
		for index in 4: await get_tree().process_frame
		# Drive the production readiness receiver in this socket-free Web scene.
		for id in Session.members:
			if id != Session.host_id: Session.receive(id,Session.encode_packet({"type":"map_ready","map_id":Session.map_id}))
		await get_tree().process_frame
		restarted = game.running and not game.finished and Session.playing
		sim = game.sim
	if (sim.failed or sim.won) and not game.finished:
		game.handle_effects(sim.events)
		game.finish_run()
	if not game.finished:
		for step in 6:
			if not restarted:
				var command = command_for(frame)
				if step > 0: command.fire_pressed = false; command.reload = false; command.ultimate = false
				sim.submit(target_id,command)
			sim.step(1.0/FPS/6)
			game.handle_effects(sim.events)
			if sim.failed or sim.won:
				game.finish_run()
				break
	game._process(1.0/FPS)
	game.first_person_layer.sync_view()
	var p: Dictionary = sim.pawns[target_id]
	var view: Dictionary = game.view_pawn()
	var phase = "新一轮整备 · 三人存活" if restarted else "结算："+("胜利" if sim.won else "失败") if game.finished else "观战："+str(view.name) if game.local_pawn().hp <= 0 else "队友："+str(p.name)+" · "+str(int(p.hp))+" HP"
	caption.text = TITLES[scenario]+"  |  "+phase+"\n隔离软件渲染 · 脚本场景（非 Steam 双账号实录）"
	for index in 2: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var partner = game.partners.get(target_id)
	var state = {"frame":frame,"phase":phase,"hp":p.hp,"weapon":p.weapon,"slot":p.slot,"shots":p.shots,"reload":p.reloading,"ammo":p.ammo[p.weapon],"ultimate":Ultimate.active(p),"fire_anim":p.fire_anim,"view":view.id,"failed":sim.failed,"won":sim.won,"result":game.ui.current == "result","restarted":restarted,"members":Session.members.size(),"living":sim.pawns.values().filter(func(pawn): return pawn.hp > 0).size(),"held":partner.held.visible if partner else false}
	JavaScriptBridge.eval("window.__coopState="+JSON.stringify(state),true)
	JavaScriptBridge.eval("window.__coopFrame="+str(frame),true)
