extends SceneTree
const Store = preload("res://scripts/progression_store.gd")
const Ultimate = preload("res://scripts/ultimate.gd")
const Fixture = preload("res://tools/preparation-fixture.gd")
var game
var net
var checks = 0
var failures = 0
var role = ""
var address = ""
var acknowledgements: Dictionary = {}
var last_publish = 0
var host_save_path = ""

class SteamFixture:
	extends RefCounted
	var sent: Array = []
	var invited = false
	func sendP2PPacket(id, bytes, _mode, _channel):
		sent.append({"id":str(id),"packet":bytes_to_var(bytes.decompress_dynamic(2000000,FileAccess.COMPRESSION_DEFLATE))})
		return true
	func activateGameOverlayInviteDialog(_lobby): invited = true


func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: "+message)
	else:
		failures += 1
		push_error(message)

func until(predicate: Callable, label: String, seconds := 15.0) -> bool:
	var start = Time.get_ticks_msec()
	while not predicate.call():
		if Time.get_ticks_msec()-start > seconds*1000:
			check(false,"Timeout: "+label)
			return false
		if role == "host" and game and game.running and game.sim and game.sim.defense.has("qa_phase") and Time.get_ticks_msec()-last_publish > 100:
			last_publish = Time.get_ticks_msec()
			net.send_world(game.sim.snapshot(),[])
		await process_frame
	return true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--coop-role="): role = arg.get_slice("=",1)
		if arg.begins_with("--coop-address="): address = arg.get_slice("=",1)
	net = root.get_node("Session")
	net.lan_directory.port = int(address.get_slice(":",1))+1
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	net.input_received.connect(func(_id,command):
		if command.has("qa_ack"): acknowledgements[command.qa_ack] = true)
	if role == "host": await host_test()
	else: await client_test()
	game.return_home()
	if not host_save_path.is_empty():
		check(Store.new(host_save_path).data == root.get_node("Progress").store.data,"Leaving the host room preserves all earned progress on disk")
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(host_save_path+suffix): DirAccess.remove_absolute(host_save_path+suffix)
	game.queue_free()
	await process_frame
	print("COOP "+role.to_upper()+": %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)

func publish(phase: String) -> void:
	game.sim.defense["qa_phase"] = phase
	net.send_world(game.sim.snapshot(),[])

func validate_steam_protocol() -> void:
	var session = load("res://scripts/session.gd").new()
	root.add_child(session)
	session.set_process(false)
	var steam = SteamFixture.new()
	session.steam = steam
	session.steam_ready = true
	session.active = true
	session.playing = true
	session.transport = "steam"
	session.local_id = "100"
	session.host_id = "100"
	session.nonce = "steam-fixture"
	session.members = {"100":"房主","200":"客机"}
	session.receive("300",session.encode_packet({"type":"resume_request"}))
	check(steam.sent[-1].packet.type == "rejected" and not session.pending_resumes.has("300"),"Steam protocol rejects new accounts after roster is sealed (mock transport)")
	session.receive("200",session.encode_packet({"type":"resume_request"}))
	check(session.pending_resumes.has("200") and steam.sent[-1].packet.type == "prepare","Steam protocol admits original account for state-preserving resume (mock transport)")
	var stale = session.encode_packet({"type":"map_ready","map_id":session.map_id,"session":"old-session"})
	# encode_packet owns the session envelope; explicitly serialize a stale envelope.
	stale = var_to_bytes({"type":"map_ready","map_id":session.map_id,"protocol":session.PROTOCOL,"session":"old-session"}).compress(FileAccess.COMPRESSION_DEFLATE)
	session.receive("200",stale)
	check(session.pending_resumes.has("200"),"Steam resume requires the current match nonce")
	session.receive("200",session.encode_packet({"type":"map_ready","map_id":session.map_id}))
	check(not session.pending_resumes.has("200") and steam.sent[-1].packet.type == "start","Steam resume completes the preparation handshake (mock transport)")
	var edge = session.recover_input_edges("200",{"ultimate_seq":1})
	check(edge.ultimate and not session.recover_input_edges("200",{"ultimate_seq":1}).ultimate,"Network ultimate edge survives coalescing without duplicate activation")
	session.playing = false
	session.lobby = 123
	session.invite_friends()
	check(steam.invited,"Steam friend invite button routes to the invite overlay API (mock transport)")
	session.steam_ready = false
	session.active = false
	session.queue_free()

func host_test() -> void:
	validate_steam_protocol()
	var profile = root.get_node("Progress").store
	host_save_path = OS.get_cache_dir().path_join("coop-host-"+str(OS.get_process_id())+".json")
	profile.path = host_save_path
	profile.data["tutorial_stage"] = 5
	profile.data["intro_seen"] = true
	profile.data.weapons.rifle = 5
	profile.data.magazines.rifle_magazine = 10
	profile.data.talents.strong = 5
	profile.data.talents.supply = 5
	profile.data.talents.swift = 5
	profile.data.talents.greed = 1
	profile.data.grenade_level = 4
	profile.data.ultimate_level = 4
	profile.data.ultimate_unlocked = true
	profile.data.coins = 10000.0
	profile.data.diamonds = 5
	net.host_lan("房主",int(address.get_slice(":",1)))
	check(net.is_host(),"LAN host opens a real ENet server")
	game.ui.show_multiplayer()
	check(game.ui.current == "multiplayer" and game.ui.menu.find_children("*","Button",true,false).any(func(button): return button.text == "开始合作"),"Host lobby exposes the actual cooperative start action")
	print("COOP HOST READY")
	if not await until(func(): return net.members.size() == 2,"initial admission"): return
	net.begin_match()
	if not await until(func(): return game.running and net.playing,"map handshake"): return
	var sim = game.sim
	var guest = net.members.keys().filter(func(id): return id != net.host_id)[0]
	var host: Dictionary = sim.pawns[net.host_id]
	var p: Dictionary = sim.pawns[guest]
	publish("preparation")
	if not await until(func(): return acknowledgements.has("preparation"),"guest joining during world preparation"): return
	check(sim.progression == profile and sim.coop_host == net.host_id,"Authority uses the selected host Store")
	check(p.hp == 150 and p.ultimate_unlocked and p.grenades == 4 and p.ammo[0] == sim.weapon_capacity(0),"Guests inherit health, grenade and magazine upgrades")
	check(sim.progression.level("rifle") == 5,"Shared weapon rank follows host")
	sim.prepare_wave()
	check(sim.defense.wave_budget == preload("res://scripts/defense_population.gd").budget(1,1),"Coop population budget remains identical to solo")
	Fixture.face(sim,p,"rifle")
	var wallet = profile.data.coins
	check(not sim.purchase_upgrade("rifle",p) and profile.data.coins == wallet,"Guest cannot spend the host wallet")
	p.input = {"interact":true}
	sim.defense_director.interactions(2)
	check(not sim.defense.started,"Guest cannot start the battle")
	Fixture.face(sim,host,"strong")
	profile.data.talents.strong = 4
	for pawn in sim.pawns.values(): pawn.hp = 140; pawn.max_hp = 140
	check(sim.purchase_upgrade("strong",host) and p.max_hp == 150 and p.hp == 150,"Host talent purchase immediately updates every pawn")
	sim.defense.started = true
	sim.defense.crystal_hp = sim.defense.crystal_max_hp
	sim.defense.waiting = false
	p.input = {"ultimate":true}
	Ultimate.tick(sim,p,p.input,.01)
	check(Ultimate.active(p) and not Ultimate.active(host),"Ultimate activation is independent per player")
	p.ultimate_remaining = 0.0
	p.ultimate_sheathe = 0.0
	p.erase("ultimate_saved_slot")
	p.slot = 1
	p.weapon_slot = 1
	p.weapon = 0
	p.requested = 0
	var host_ammo = host.ammo.duplicate()
	var host_grenades = host.grenades
	var guest_ammo: int = p.ammo[0]
	p.switch = 0.0
	p.input_age = 0.0
	sim.update_arsenal(p,{"fire":true},.01)
	check(p.ammo[0] == guest_ammo-1 and host.ammo == host_ammo,"Guest gunfire consumes only guest ammunition")
	check(sim.equipment.throw_grenade(p) and p.grenades == 3 and host.grenades == host_grenades,"Guest grenade throw consumes only guest grenades")
	sim.defense.projectiles.clear()
	host.pos = Vector2(10,23)
	p.pos = Vector2(9,23)
	for pawn in sim.pawns.values(): pawn.height = 3.0
	sim.spawn(Vector2(8,23),"normal")
	var attacker: Dictionary = sim.zombies[-1]
	sim.path_scheduler.begin(sim.elapsed,sim.arena)
	check(sim.choose_zombie_target(attacker,[host,p]).id == p.id and sim.original_choose_zombie_target(attacker,[host,p]).id == p.id,"Both targeting paths choose the closest reachable player regardless of list order")
	p.hp = 0
	check(sim.choose_zombie_target(attacker,[host,p]).id == host.id,"Dead guests are excluded from target selection")
	p.hp = 150
	p["connected"] = false
	check(sim.choose_zombie_target(attacker,[host,p]).id == host.id,"Disconnected guests are excluded from target selection")
	p.connected = true
	for kind in ["imp","giant","dancer"]:
		attacker.kind = kind
		var target: Dictionary = sim.choose_zombie_target(attacker,[host,p])
		check(target.get("is_structure",false) or target.get("is_crystal",false),"Special enemy preserves building-only targeting: "+kind)
	sim.zombies.clear()
	sim.spawn(Vector2(8,25),"normal")
	var coins: float = profile.data.coins
	sim.hit_enemy(sim.zombies[-1],10000,false,p,Vector3(8,4,25))
	check(is_equal_approx(profile.data.coins,coins+1.1) and sim.coin_drops.all(func(drop): return drop.owner == net.host_id),"Guest kills credit host greed and route every coin to host")
	sim.zombies.clear()
	sim.roster.clear()
	sim.defense_director.launched_waves = {1:true}
	sim.defense_director.reward_finished_waves()
	check(profile.data.diamonds == 1 and sim.earned_diamonds == 1,"Wave diamonds belong only to host after one strong purchase")
	check(profile.save() and Store.new(host_save_path).data == profile.data,"Host rewards persist through actual disk reload")
	# A dead guest stays dead through a wave start.
	p.hp = 0
	sim.defense.wave = 2
	sim.defense_director.begin_wave()
	check(p.hp == 0 and not sim.failed,"Wave transition never revives a guest")
	# Controlled alive fixture for reconnection preservation, not a gameplay revival.
	p.hp = 57
	p.pos = Vector2(8,25)
	p.height = 3.0
	host.pos = Vector2(12,25)
	host.height = 3.0
	p.ammo[0] = 7
	p.slot_ammo[0] = 7
	p.reserves[0] = 333
	p.slot_reserves[0] = 333
	p.slot = 2
	p.weapon_slot = 2
	p.weapon = 2
	p.requested = 2
	p.reserve = p.reserves[2]
	p.yaw = 1.2
	p.pitch = .12
	p.grenades = 2
	p.ultimate_cd = 37.0
	p.grenade_replenish = 4.0
	check(net.valid_world(sim.snapshot()),"Upgraded HP, magazines, grenades, reserves and cooldown pass wire validation")
	publish("alive")
	if not await until(func(): return acknowledgements.has("alive"),"client shared-state assertions"): return
	if not await until(func(): return not p.get("connected",true),"alive guest disconnect"): return
	var preserved = [p.hp,p.ammo.duplicate(),p.reserves.duplicate(),p.grenades,p.ultimate_cd,p.grenade_replenish]
	sim.update_pawn(host,.01)
	check([p.hp,p.ammo,p.reserves,p.grenades,p.ultimate_cd,p.grenade_replenish] == preserved,"Disconnected guest inventory and cooldown stay frozen")
	sim.defense["qa_phase"] = "alive_return"
	if not await until(func(): return p.get("connected",false),"authenticated alive reconnect"): return
	check([p.hp,p.ammo,p.reserves,p.grenades,p.ultimate_cd,p.grenade_replenish] == preserved,"Reconnection restores the same pawn without reinitialization")
	publish("alive_return")
	if not await until(func(): return acknowledgements.has("alive_return"),"alive reconnect client confirmation"): return
	p.hp = 0
	publish("dead")
	if not await until(func(): return acknowledgements.has("dead"),"dead client acknowledgement"): return
	if not await until(func(): return not p.get("connected",true),"dead guest disconnect"): return
	sim.defense["qa_phase"] = "dead_return"
	if not await until(func(): return p.get("connected",false),"authenticated dead reconnect"): return
	check(p.hp == 0,"Dead guest cannot bypass death through reconnect")
	publish("dead_return")
	if not await until(func(): return acknowledgements.has("dead_return"),"dead spectator confirmation"): return
	host.hp = 0
	# Leave one living guest to demonstrate that host death alone ends the match.
	p.hp = 57
	sim.step(.01)
	check(sim.failed,"Host death ends the match even with a living guest")
	publish("failed")
	await until(func(): return acknowledgements.has("finished"),"client receives terminal snapshot")

func phase(name: String) -> bool:
	return game.running and game.sim and game.sim.defense.get("qa_phase","") == name

func reconnect() -> void:
	await create_timer(.15).timeout
	game.return_home()
	await create_timer(.35).timeout
	net.join_lan(address,"客机")

func client_test() -> void:
	var personal = root.get_node("Progress").store
	personal.data.weapons.rifle = 2
	personal.data.coins = 123.4
	personal.data.diamonds = 8
	personal.dirty = true
	personal.save()
	var before = personal.data.duplicate(true)
	var secret_path = OS.get_cache_dir().path_join("coop-guest-"+str(OS.get_process_id())+".json")
	personal.path = secret_path
	personal.dirty = true
	personal.save()
	var bytes_before = FileAccess.get_file_as_bytes(secret_path)
	net.search_lan()
	if not await until(func(): return not net.searching and not net.rooms.is_empty(),"LAN discovery response"): return
	check(net.rooms.size() == 1 and str(net.rooms[0].id).ends_with(":"+address.get_slice(":",1)) and net.rooms[0].count == 1,"Real UDP discovery finds the ENet host with correct address and player count")
	game.ui.room_mode = "lan"
	game.ui.show_multiplayer()
	check(game.ui.menu.has_node("RoomBrowserStage/RoomActions") and not game.ui.menu.has_node("FieldMenuStage"),"Multiplayer browser is an independent page with pinned footer actions")
	var view = game.ui.multiplayer_view
	var search_id: int = view.search.get_instance_id()
	view.search.text = "没有这个房间"
	view.search.text_changed.emit(view.search.text)
	net.changed.emit()
	check(view.search.get_instance_id() == search_id and view.search.text == "没有这个房间" and view.tally.text.contains("0 个"),"Search filters rooms and survives live network updates without losing the input")
	view.open_direct()
	check(is_instance_valid(view.dialog) and game.ui.current == "multiplayer","Direct connection opens an overlay over the room page")
	game.ui.back()
	check(not is_instance_valid(view.dialog) and game.ui.current == "multiplayer","Escape closes only the direct connection overlay")
	var menu_type = load("res://scripts/multiplayer_menu.gd")
	check(menu_type.valid_target("192.168.1.20:27777","lan") and not menu_type.valid_target("192.168.1.20:70000","lan") and not menu_type.valid_target("broken","lan") and menu_type.valid_target("109775244906512345","steam") and not menu_type.valid_target("0","steam"),"Direct connection validates IP, port and Steam room id")
	game.ui.room_query = ""
	net.join_lan(address,"客机")
	if not await until(func(): return phase("preparation"),"preparation snapshot"): return
	var early = load("res://scripts/session.gd").new()
	root.add_child(early)
	early.map_preparing.connect(early.confirm_map_ready)
	var joined_world = [false]
	early.world_received.connect(func(state): joined_world[0] = state.pawns.has(early.local_id) and state.pawns[early.local_id].hp == 150 and state.pawns[early.local_id].grenades == 4)
	early.join_lan(address,"战前加入队员")
	await until(func(): return early.playing and joined_world[0],"new member joins while host is already preparing in-world")
	check(early.playing and joined_world[0],"New guest can join the preparation scene and inherits current host upgrades")
	early.leave()
	early.queue_free()
	net.send_input({"qa_ack":"preparation"})
	if not await until(func(): return phase("alive"),"first host snapshot"): return
	var original_id = net.local_id
	var p = game.local_pawn()
	check(game.sim.progression != personal and game.sim.progression.path.is_empty(),"Guest owns an ephemeral progression Store")
	check(game.sim.progression.level("rifle") == 5 and personal.level("rifle") == 2,"Host rank overrides guest only inside the room")
	check(game.sim.progression.data.coins == 0 and game.sim.progression.data.diamonds == 0,"Guest wallet stays zero despite host rewards")
	check(p.hp == 57 and p.ammo[0] == 7 and p.grenades == 2 and p.ultimate_cd == 37,"Guest receives independent battle inventory")
	check(game.sim.progression.grenade_capacity() == 4 and p.ultimate_unlocked and p.max_hp == 150,"Client renders host talent and capacity upgrades")
	var stranger = load("res://scripts/session.gd").new()
	root.add_child(stranger)
	var rejected = [false]
	stranger.disconnected.connect(func(_message): rejected[0] = true)
	stranger.join_lan(address,"陌生玩家")
	await until(func(): return rejected[0],"reject new member after battle start")
	check(rejected[0],"Sealed room rejects a new LAN identity")
	stranger.leave()
	stranger.queue_free()
	net.send_input({"qa_ack":"alive"})
	await reconnect()
	if not await until(func(): return phase("alive_return"),"alive resume snapshot"): return
	p = game.local_pawn()
	check(net.local_id == original_id and p.hp == 57 and p.ammo[0] == 7 and p.reserves[0] == 333 and p.grenades == 2 and p.ultimate_cd == 37 and p.grenade_replenish == 4,"Authenticated reconnect preserves identity and all combat resources")
	check(game.requested_slot == 2 and game.requested_weapon == 2 and is_equal_approx(game.yaw,1.2) and is_equal_approx(game.pitch,.12) and not game.awaiting_coop_snapshot,"Resume restores selected weapon and view before sending new local input")
	game._physics_process(.01)
	net.send_input({"qa_ack":"alive_return"})
	if not await until(func(): return phase("dead"),"guest death snapshot"): return
	check(game.local_pawn().hp == 0 and game.view_pawn().id == net.host_id,"Dead guest spectates the host")
	net.send_input({"qa_ack":"dead"})
	await reconnect()
	if not await until(func(): return phase("dead_return"),"dead resume snapshot"): return
	check(game.local_pawn().hp == 0 and game.view_pawn().id == net.host_id,"Dead reconnect returns to spectator mode")
	net.send_input({"qa_ack":"dead_return"})
	if not await until(func(): return game.finished,"host death failure"): return
	check(game.sim.failed,"Host death reaches client terminal state")
	game.ui.show_result()
	check(game.ui.menu.find_child("EarnedCoins",true,false).text == "+0" and game.ui.menu.find_child("EarnedDiamonds",true,false).text == "+0","Guest result UI shows zero personal coin and diamond earnings")
	check(personal.data == before and FileAccess.get_file_as_bytes(secret_path) == bytes_before,"Client local progress is byte-for-byte unchanged across joins, rewards, disconnects and defeat")
	net.send_input({"qa_ack":"finished"})
	await create_timer(.2).timeout
	game.return_home()
	game.start_solo()
	check(game.sim.progression == personal and game.sim.progression.level("rifle") == 2 and is_equal_approx(game.sim.progression.data.coins,123.4),"Returning to solo restores untouched personal progress")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(secret_path+suffix): DirAccess.remove_absolute(secret_path+suffix)
	personal.path = ""
