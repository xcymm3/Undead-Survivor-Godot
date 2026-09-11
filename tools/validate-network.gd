extends SceneTree
var game
var session
var host := false
var begun := 0
var started := 0
var remote_moved := false
var remote_jumped := false
var remote_landed := false
var sent_jump := false
var full_party_bodies := false
var snapshots := 0
var remote_shots := 0
var sent_stop := false
var expected := 2
var stopping := false
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	session = root.get_node("Session")
	host = "--host" in OS.get_cmdline_user_args()
	if "--four" in OS.get_cmdline_user_args(): expected = 4
	begun = Time.get_ticks_msec()
	if host:
		session.host_lan("验证房主")
		if session.active: print("NETWORK READY")
	else:
		session.join_lan("127.0.0.1:27777","验证队友")
		session.world_received.connect(func(_state): snapshots += 1)
	session.match_started.connect(func():
		started = Time.get_ticks_msec()
		if host:
			game.sim.roster.clear()
			game.sim.spawn(Vector2(1.4,0),"giant")
		else: Input.action_press("forward"))

func _process(_dt: float) -> bool:
	if stopping or not game or not session: return false
	if host and session.is_host() and session.members.size() == expected and not session.playing: session.begin_match()
	if started > 0 and game.sim:
		var age = (Time.get_ticks_msec()-started)/1000.0
		if host and game.sim.player_bodies.size() == expected: full_party_bodies = true
		if not host and age > .6 and not sent_jump:
			game.jump_pending = true
			sent_jump = true
		if not host and age < 2:
			game.fire_pending = true
		elif not host and not sent_stop:
			Input.action_release("forward")
			sent_stop = true
		for id in game.sim.pawns:
			if id != session.host_id:
				var p: Dictionary = game.sim.pawns[id]
				remote_moved = remote_moved or p.pos.y < 7
				remote_jumped = remote_jumped or p.height > .3
				remote_landed = remote_landed or (remote_jumped and p.get("grounded",false))
				remote_shots = maxi(remote_shots,int(p.shots))
		if age > (5.0 if host else 4.5):
			var metrics: Dictionary = session.network_metrics()
			var body_authority: bool = full_party_bodies and game.sim.player_bodies.size() == game.sim.pawns.size() if host else game.sim.player_bodies.is_empty()
			var good = remote_moved and remote_jumped and remote_landed and body_authority and remote_shots > 0 and (host or (snapshots >= 20 and metrics.samples >= 2 and metrics.rtt >= 0 and metrics.loss >= 0))
			print("NETWORK PHYSICS: jumped=%s landed=%s authority=%s" % [remote_jumped,remote_landed,body_authority])
			print("NETWORK METRICS: "+JSON.stringify(metrics))
			print("NETWORK %s: moved=%s shots=%d snapshots=%d result=%s" % ["HOST" if host else "CLIENT",remote_moved,remote_shots,snapshots,"PASS" if good else "FAIL"])
			stopping = true
			call_deferred("finish",0 if good else 1)
	if Time.get_ticks_msec()-begun > 16000:
		push_error("Network validation timed out: "+session.status)
		quit(1)
	return false

func finish(code: int) -> void:
	game.return_home()
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(.15).timeout
	quit(code)
