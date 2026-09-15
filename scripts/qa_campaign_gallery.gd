extends Node
## Opt-in, software-Web staged screenshots. These are not gameplay traversal evidence.
var game
var last_request = ""
var pending_frames = 0
var VIEWS = {
	"loading":[Vector2(-65,215),0.0,-.1],
	"repair":[Vector2(-65,-190),0.0,-.1],
	"service":[Vector2(65,-208),0.0,-.1],
	"pump_detour":[Vector2(-53.5,-99),0.0,-.6],
	"axe":[Vector2(0,114),0.0,0.0],
	"loot":[Vector2(-58,79),0.0,0.0],
	"grenade":[Vector2(0,114),0.0,0.0],
	"medkit":[Vector2(0,114),0.0,0.0],
	"heal_self":[Vector2(0,114),0.0,0.0],
	"heal_other":[Vector2(0,114),0.0,0.0],
	"shop":[Vector2(-55,78),0.0,0.0],
	"pump":[Vector2(-47,-115),1.57,0.0],
	"valve":[Vector2(70,-119),0.0,0.0],
	"checkpoint":[Vector2(60,71),0.0,0.0],
	"start":[Vector2(0,114),0.0,0.0],
	"street":[Vector2(18,96),0.0,-.08],
	"yard":[Vector2(-44,48),0.0,-.06],
	"control":[Vector2(8,-12),0.0,-.1],
	"bridge":[Vector2(0,-28),0.0,-.08],
	"river":[Vector2(7,-39),-PI/2,-.08],
	"gate":[Vector2(0,-50),0.0,0.0],
	"shed":[Vector2(20,-72),0.0,0.0],
	"exit":[Vector2(25,-114),0.0,0.0]}

func _ready() -> void:
	if not Data.automation or not OS.has_feature("web") or "--qa-campaign-gallery" not in OS.get_cmdline_user_args():
		queue_free()
		return
	if "--qa-night-gallery" in OS.get_cmdline_user_args():
		VIEWS = preload("res://scripts/night_layout.gd").VIEWS.duplicate()
		Data.settings.map_id = "graypine_night"
	else: Data.settings.map_id = "graypine_ferry"
	game.start_solo("campaign",71245)
	game.set_process(false)
	game.set_physics_process(false)
	Data.settings.resolution = 1.0
	Data.settings.pixelated = false
	game.apply_graphics()
	RenderingServer.render_loop_enabled = false
	RenderingServer.frame_post_draw.connect(func():
		if pending_frames <= 0: return
		pending_frames -= 1
		if pending_frames == 0:
			RenderingServer.render_loop_enabled = false
			JavaScriptBridge.eval("window.__campaignRendered="+last_request,true))
	JavaScriptBridge.eval("window.__campaignGalleryReady=true",true)

func _process(_dt: float) -> void:
	var request = str(JavaScriptBridge.eval("JSON.stringify(window.__campaignView || {})",true))
	if request != last_request:
		var value = JSON.parse_string(request)
		if not value is Dictionary or not VIEWS.has(value.get("name","")): return
		last_request = request
		var view: Array = VIEWS[value.name]
		var p: Dictionary = game.local_pawn()
		p.pos = Vector2(value.position[0],value.position[1]) if value.has("position") else view[0]
		p.height = Data.enemy_ground_height(p.pos,game.sim.map_id)
		game.yaw = float(value.get("yaw",view[1]))
		game.pitch = float(value.get("pitch",view[2]))
		p.yaw = game.yaw
		p.pitch = game.pitch
		Data.settings.shadows = int(value.get("shadows",3))
		game.apply_graphics()
		# Explicit software-gallery controls for isolating light/depth artifacts.
		if value.has("flash_shadow"): game.flashlight.shadow_enabled = value.flash_shadow
		for light in game.arena.scenery.find_children("*","OmniLight3D",true,false):
			if value.has("lamp_shadow"): light.shadow_enabled = value.lamp_shadow
		p.slot = 3 if value.name == "axe" else 4 if value.name == "grenade" else 5 if value.name in ["medkit","heal_self","heal_other"] else 1
		p.weapon = 6 if value.name == "axe" else p.primary
		p.requested = p.weapon
		p.healing = p.id if value.name == "heal_self" else "gallery_target" if value.name == "heal_other" else ""
		p.heal_time = 1.4 if not p.healing.is_empty() else 0.0
		p.being_healed = false
		p.grenades = 1
		p.hp = 60 if value.name.begins_with("heal_") else 100
		if value.name == "heal_other":
			var target: Dictionary = p.duplicate(true)
			target.id = "gallery_target"
			target.name = "受治疗队友"
			target.pos = p.pos+Vector2(0,-1.4)
			target.healing = ""
			target.being_healed = true
			game.sim.pawns[target.id] = target
		else: game.sim.pawns.erase("gallery_target")
		for id in game.sim.pawns.keys():
			if str(id).begins_with("hud_peer_"): game.sim.pawns.erase(id)
		for i in int(value.get("party",1))-1:
			var peer: Dictionary = p.duplicate(true)
			peer.id = "hud_peer_"+str(i)
			peer.name = ["队友 · 林", "队友 · 陈", "队友 · 周"][i]
			peer.hp = [78,42,18][i]
			peer.pos = p.pos+Vector2(3+i*2,2)
			game.sim.pawns[peer.id] = peer
		if value.get("empty",false):
			p.grenades = 0
			p.medkits = 0
		else: p.medkits = 1
		game.sim.campaign.state.departed = value.name != "start"
		game.sim.campaign.state.power_ready = value.name == "exit"
		game.sim.campaign.state.shop_open = value.name != "shop"
		game.sim.campaign.state.gate_open = value.get("opened",false)
		game.sim.campaign.state.phase = "BRIDGE_ACTIVE" if value.name in ["control","bridge","gate"] else "PREPARE" if value.name == "start" else "STREET"
		game.sim.campaign.state.objective = "等待检修闸门打开" if value.name in ["control","bridge","gate"] else "检查装备，E 开门出发" if value.name == "start" else "前往泵站安全屋"
		p.hint = "E 交互 / 救援 · 5 医疗包"
		if game.sim.map_id == "graypine_night":
			game.sim.campaign.state.gate_open = true
			game.sim.campaign.state.exit_control = true
			game.sim.campaign.state.objective = "沿绿灯前往安全屋 · 无需清光尸群"
			game.sim.elapsed = float(value.get("time",2.0))
		game.arena.sync_campaign(game.sim.campaign.state)
		pending_frames = 2
		RenderingServer.render_loop_enabled = true
	game._process(1.0/60)
	JavaScriptBridge.eval("window.__lightingState="+JSON.stringify({"flash_shadow":game.flashlight.shadow_enabled,"energy":game.flashlight.light_energy,"world_shadows":game.arena.find_children("*","Light3D",true,false).map(func(light): return light.shadow_enabled)}),true)
