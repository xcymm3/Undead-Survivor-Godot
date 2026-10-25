extends Node
## Explicit Web-only action review; production simulation and weapon poses are stepped at 60 Hz.
const FPS = 20.0
const LENGTHS = {"fire":80,"reload":110,"shove":80}
const TITLES = {"fire":"Blender AK · 开火","reload":"Blender AK · 换弹","shove":"Blender AK · 枪托攻击"}
var game
var scenario = ""
var last_frame = -1
var callback: JavaScriptObject

func stage(kind: String) -> void:
	if not Data.automation or not OS.has_feature("web") or not LENGTHS.has(kind): return
	scenario = kind
	Progress.store = preload("res://scripts/progression_store.gd").new()
	Progress.store.data.merge({"intro_seen":true,"tutorial_stage":5,"ultimate_unlocked":true},true)
	Progress.store.record_combat_controls({"aim":true,"shove":true})
	game.start_solo("defense",491)
	game.set_process(false)
	game.set_physics_process(false)
	await get_tree().physics_frame
	var sim = game.sim
	sim.roster.clear()
	sim.zombies.clear()
	sim.defense.started = true
	sim.defense.waiting = true
	sim.defense.crystal_hp = sim.defense.crystal_max_hp
	var p: Dictionary = game.local_pawn()
	p.pos = Vector2(12,20)
	p.height = 3.0
	p.yaw = 0.0
	p.pitch = -.025
	p.protection = 0.0
	game.yaw = p.yaw
	game.pitch = p.pitch
	game.requested_slot = 1
	game.requested_weapon = 0
	if scenario == "reload":
		p.ammo[0] = 7
		p.slot_ammo[0] = 7
	game.focused = true
	game._process(0)
	game.arena.scenery.sync(sim.defense)
	# A stationary neutral fill makes the authored metal/wood readable in the night map.
	var fill = OmniLight3D.new()
	fill.name = "AKReviewFill"
	fill.position = game.camera.position+Vector3(-.6,.5,-.6)
	fill.light_energy = 1.8
	fill.omni_range = 3.5
	fill.shadow_enabled = false
	game.add_child(fill)
	var overlay = CanvasLayer.new()
	overlay.layer = 30
	add_child(overlay)
	var caption = Label.new()
	caption.position = Vector2(20,74)
	caption.add_theme_font_override("font",game.ui.font)
	caption.add_theme_font_size_override("font_size",20)
	caption.add_theme_color_override("font_shadow_color",Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x",2)
	caption.add_theme_constant_override("shadow_offset_y",2)
	caption.text = TITLES[kind]+"\n隔离软件渲染 · 固定镜头 · 原生战斗逻辑"
	overlay.add_child(caption)
	for i in 4: await get_tree().process_frame
	game.first_person_layer.sync_view()
	RenderingServer.render_loop_enabled = false
	RenderingServer.force_draw(true)
	callback = JavaScriptBridge.create_callback(draw_frame)
	JavaScriptBridge.get_interface("window").__drawAKReview = callback
	var rifle = game.weapon.models[0]
	JavaScriptBridge.eval("window.__akFrame=-1;window.__campaignReviewReady="+JSON.stringify({"scenario":kind,"frames":LENGTHS[kind],"fps":FPS,"capacity":sim.weapon_capacity(0),"mag_y":rifle.magazine.position.y,"asset":rifle.get_meta("model_source"),"renderer":"Godot Web Compatibility / Chromium SwiftShader","fixture":"Fixed camera and neutral fill; input commands use the production 60 Hz simulation."}),true)

func draw_frame(args: Array) -> void:
	var frame = int(args[0])
	if frame != last_frame+1: return
	last_frame = frame
	var sim = game.sim
	var p: Dictionary = game.local_pawn()
	for step in 3:
		var command = {"yaw":p.yaw,"pitch":p.pitch,"slot":1,"weapon":0}
		command.fire = scenario == "fire" and frame >= 8 and frame < 48
		command.reload = scenario == "reload" and frame == 12 and step == 0
		command.shove = scenario == "shove" and frame in [12,36,60] and step == 0
		sim.submit(Session.local_id,command)
		sim.step(1.0/60)
		game.handle_effects(sim.events)
	game._process(1.0/FPS)
	game.first_person_layer.sync_view()
	for i in 2: await get_tree().process_frame
	for node in game.find_children("*","Node3D",true,false): node.force_update_transform()
	RenderingServer.force_draw(true)
	await get_tree().process_frame
	var rifle = game.weapon.models[0]
	var state = {"frame":frame,"shots":p.shots,"ammo":p.ammo[0],"reserve":p.reserves[0],"reload":p.reloading,"fire_anim":p.fire_anim,"flash":game.weapon.muzzle.visible,"mag_y":rifle.magazine.position.y,"bolt_z":rifle.bolt.position.z,"shove":p.shove_anim,"shoves":p.get("shoves",0),"weapon_yaw":game.weapon.rotation.y,"hp":p.hp}
	JavaScriptBridge.eval("window.__akState="+JSON.stringify(state)+";window.__akFrame="+str(frame),true)
