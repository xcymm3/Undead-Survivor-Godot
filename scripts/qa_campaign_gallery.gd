extends Node
## Opt-in, software-Web staged screenshots. These are not gameplay traversal evidence.
var game
var last_request = ""
var pending_frames = 0
const VIEWS = {
	"shop":[Vector2(-55,78),0.0,0.0],
	"pump":[Vector2(-52,-109),0.0,0.0],
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
	Data.settings.map_id = "graypine_ferry"
	game.start_solo("campaign")
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
		p.pos = view[0]
		p.height = Data.enemy_ground_height(p.pos,"graypine_ferry")
		game.yaw = view[1]
		game.pitch = view[2]
		game.sim.campaign.state.departed = value.name != "start"
		game.sim.campaign.state.power_ready = value.name == "exit"
		game.sim.campaign.state.shop_open = value.name != "shop"
		game.sim.campaign.state.gate_open = value.get("opened",false)
		game.sim.campaign.state.phase = "BRIDGE_ACTIVE" if value.name in ["control","bridge","gate"] else "PREPARE" if value.name == "start" else "STREET"
		game.sim.campaign.state.objective = "等待检修闸门打开" if value.name in ["control","bridge","gate"] else "在值班室选择武器，E 开门出发" if value.name == "start" else "前往泵站安全屋"
		p.hint = "E 交互 / 救援 · H 治疗"
		game.arena.sync_campaign(game.sim.campaign.state)
		pending_frames = 2
		RenderingServer.render_loop_enabled = true
	game._process(1.0/60)
