extends SceneTree
## Full ENet route, independently controlled clients, ordinary input/world protocol.
var game
var session
var driver
var host = false
var expected = 2
var began = 0
var completed = 0
var timer = 0.0
var snapshots = 0
var stopping = false
var last_task = -1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.get_node("Data").settings.map_id = "graypine_ferry"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	session = root.get_node("Session")
	host = "--host" in OS.get_cmdline_user_args()
	expected = 4 if "--four" in OS.get_cmdline_user_args() else 2
	began = Time.get_ticks_msec()
	session.world_received.connect(func(_state): snapshots += 1)
	session.match_started.connect(func():
		game.set_physics_process(false)
		driver = load("res://tools/campaign-input-driver.gd").new(game,expected == 4))
	if host:
		session.host_lan("战役验收房主")
		if session.active: print("CAMPAIGN NETWORK READY")
	else: session.join_lan("127.0.0.1:27777","战役验收队员")
	Engine.time_scale = 3.0

func _process(delta: float) -> bool:
	if stopping or not game or not session: return false
	if host and session.is_host() and session.members.size() == expected and not session.playing: session.begin_match()
	if driver and game.sim:
		if driver.index != last_task:
			last_task = driver.index
			print("CAMPAIGN NET PROGRESS: role=",("host" if host else "client")," task=",last_task," elapsed=",game.sim.elapsed," position=",game.local_pawn().get("pos"))
		var dt = minf(.05,delta)
		var command: Dictionary = driver.command(dt)
		if host:
			game.sim.submit(session.local_id,command)
			game.sim.step(dt)
			timer += dt
			if timer >= .1 or game.sim.won or game.sim.failed:
				timer = 0
				session.send_world(game.sim.snapshot(),[])
		else: session.send_input(command)
		if game.sim.failed:
			print("CAMPAIGN NETWORK FAILURE: task=",driver.index," local=",game.local_pawn())
			call_deferred("finish",false)
			stopping = true
		if game.sim.won:
			if completed == 0: completed = Time.get_ticks_msec()
			if not host or Time.get_ticks_msec()-completed > 2000:
				var good = host or (snapshots > 100 and game.sim.player_bodies.is_empty())
				print("CAMPAIGN NETWORK ROUTE: party=%d role=%s elapsed=%.2f kills=%d snapshots=%d" % [expected,"host" if host else "client",game.sim.elapsed,game.sim.kills,snapshots])
				call_deferred("finish",good)
				stopping = true
	if Time.get_ticks_msec()-began > 240000:
		print("CAMPAIGN NETWORK TIMEOUT: task=",driver.index if driver else -1," phase=",game.sim.campaign_state() if game.sim else {}," pawn=",game.local_pawn() if game.sim else {})
		call_deferred("finish",false)
		stopping = true
	return false

func finish(good: bool) -> void:
	print("CAMPAIGN NETWORK FULL: "+("PASS" if good else "FAIL"))
	Engine.time_scale = 1.0
	game.return_home()
	game.queue_free()
	driver = null
	await process_frame
	quit(0 if good else 1)
