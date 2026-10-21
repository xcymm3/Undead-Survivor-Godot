extends Node
## Steam lobby/P2P and ENet LAN transports feed the exact same authoritative simulation.
signal changed
signal match_started
signal map_preparing
signal input_received(id: String, command: Dictionary)
signal world_received(state: Dictionary)
signal effects_received(effects: Array)
signal member_left(id: String)
signal member_rejoined(id: String)
signal invite_received
signal disconnected(message: String)
const PROTOCOL = "undead-survivor-godot-23"
const PORT = 27777
const DefensePopulation = preload("res://scripts/defense_population.gd")
var map_id = "graypine_defense"
var defense_difficulty = "normal"
var transport = ""
var local_id = "solo"
var host_id = ""
var members: Dictionary = {}
var rooms: Array = []
var lan_directory = preload("res://scripts/lan_room_directory.gd").new()
var searching = false
var search_transport = ""
var admission_metadata = ""
var active = false
var playing = false
var loading = false
var loading_started = 0
var ready_members: Dictionary = {}
var status = "可使用局域网，或通过 Steam 创建房间"
var room_code = ""
var nonce = ""
var peer: ENetMultiplayerPeer
var steam: Object
var lobby = 0
var steam_ready = false
var last_host = 0.0
var heartbeat = 0.0
var input_sequences: Dictionary = {}
var sent_edges = {"jump":0,"reload":0,"use_self":0,"shove":0,"wave_ready":0,"fire_pressed":0,"ultimate":0}
var received_edges: Dictionary = {}
var send_sequence = 0
var receive_sequence = -1
var packet_counts: Dictionary = {}
var rate_timer = 0.0
var probe_sequence = 0
var probes: Dictionary = {}
var last_probe = 0
var last_probe_reply = 0
var snapshot_samples: Array = []
var routes: Dictionary = {} # Stable member id -> current ENet peer id.
var resume_tokens: Dictionary = {} # Host-only secrets, never broadcast.
var pending_resumes: Dictionary = {}
var resume_room = ""
var resume_id = ""
var resume_secret = ""
var reconnecting = false
var admission_open: Callable

func _ready() -> void:
	if Data.automation: return
	var path = "user://coop-reconnect-v1.json"
	if not FileAccess.file_exists(path): return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not saved is Dictionary or not saved.get("room") is String or not saved.get("identity") is String or not saved.get("secret") is String or saved.secret.length() != 64: return
	resume_room = saved.room
	resume_id = saved.identity
	resume_secret = saved.secret

func save_resume_identity() -> void:
	if Data.automation: return
	# Connection credentials are separate from all three progression save slots.
	var file = FileAccess.open("user://coop-reconnect-v1.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"room":resume_room,"identity":resume_id,"secret":resume_secret}))

func preparation_packet() -> Dictionary:
	return {"type":"prepare","members":members,"nonce":nonce,"map_id":map_id,"defense_difficulty":defense_difficulty,"resume":true}

func accepts_new_members() -> bool:
	return not loading and (not playing or (admission_open.is_valid() and admission_open.call()))

func admit_lan(sender: String, packet: Dictionary) -> void:
	if not packet.get("name") is String: return
	if loading:
		send_to(sender,{"type":"rejected","reason":"房主正在加载战场，请稍后重新加入"},true)
		return
	var identity = str(packet.get("resume_id",""))
	var resuming = playing and members.has(identity)
	if resuming:
		if identity == host_id or not resume_tokens.has(identity) or packet.get("resume_secret") != resume_tokens[identity]:
			send_to(sender,{"type":"rejected","reason":"重连身份验证失败"},true)
			return
		if routes.has(identity):
			send_to(sender,{"type":"rejected","reason":"该队员仍在房间中"},true)
			return
	else:
		if not accepts_new_members() or members.size() >= 4:
			send_to(sender,{"type":"rejected","reason":"战斗已开始或房间已满，仅允许原成员重连"},true)
			return
		identity = sender
		members[identity] = packet.name.strip_edges().left(32)
		resume_tokens[identity] = Crypto.new().generate_random_bytes(32).hex_encode()
	routes[identity] = int(sender)
	send_to(identity,{"type":"welcome","identity":identity,"secret":resume_tokens[identity]},true)
	if playing:
		pending_resumes[identity] = Time.get_ticks_msec()
		broadcast({"type":"members","members":members,"map_id":map_id,"defense_difficulty":defense_difficulty},true)
		send_to(identity,preparation_packet(),true)
	else:
		broadcast({"type":"members","members":members,"map_id":map_id,"defense_difficulty":defense_difficulty},true)
	changed.emit()


func is_host() -> bool:
	return active and local_id == host_id

func enable_steam() -> bool:
	if steam_ready: return true
	if not Engine.has_singleton("Steam"):
		status = "Steam 需要 GodotSteam 4.5 引擎；双击 start-steam.cmd 可启动"
		changed.emit()
		return false
	steam = Engine.get_singleton("Steam")
	OS.set_environment("SteamAppId","480")
	OS.set_environment("SteamGameId","480")
	var result: Dictionary = steam.steamInitEx(480,false)
	if result.get("status",1) != 0:
		status = "Steam 初始化失败：请先登录 Steam。" + str(result.get("verbal",""))
		changed.emit()
		return false
	steam_ready = true
	steam.lobby_created.connect(_steam_created)
	steam.lobby_joined.connect(_steam_joined)
	steam.lobby_match_list.connect(_steam_rooms)
	steam.lobby_chat_update.connect(_steam_members_changed)
	steam.p2p_session_request.connect(_steam_request)
	if steam.has_signal("join_requested"): steam.connect("join_requested",_steam_join_requested)
	steam.allowP2PPacketRelay(true)
	return true

func invite_friends() -> void:
	if steam_ready and lobby != 0 and not playing: steam.activateGameOverlayInviteDialog(lobby)

func _steam_join_requested(id: int, _friend: int) -> void:
	if active:
		status = "请先离开当前房间，再接受好友邀请"
		changed.emit()
		return
	invite_received.emit()
	join_steam(str(id))

func initialize_invites() -> void:
	if Data.automation or DisplayServer.get_name() == "headless" or not Engine.has_singleton("Steam"): return
	if not enable_steam(): return
	var args = OS.get_cmdline_args()+OS.get_cmdline_user_args()
	for i in range(args.size()-1):
		if args[i] == "+connect_lobby" and args[i+1].is_valid_int():
			_steam_join_requested(int(args[i+1]),0)
			return

func host_lan(player_name: String, port: int = PORT) -> void:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port,3,2)
	if err != OK:
		status = "无法创建房间，端口 %d 被占用（%s）" % [port,error_string(err)]
		peer = null
		changed.emit()
		return
	transport = "lan"
	var advertised = lan_directory.start_host()
	local_id = "1"
	host_id = "1"
	active = true
	members = {"1":player_name.strip_edges().left(32) if not player_name.strip_edges().is_empty() else "房主"}
	room_code = "127.0.0.1:%d" % port
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10."):
			room_code = address+":"+str(port)
			break
	peer.peer_disconnected.connect(_lan_peer_left)
	status = "局域网房间已创建，等待队友加入" if advertised else "房间已创建，扫描不可用；请分享地址直接连接"
	changed.emit()

func join_lan(address: String, player_name: String) -> void:
	leave()
	var parts = address.strip_edges().split(":")
	var port = int(parts[1]) if parts.size() > 1 else PORT
	if parts[0].is_empty() or port < 1 or port > 65535:
		status = "请输入有效的 IP 地址与端口"
		changed.emit()
		return
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(parts[0],port,2)
	if err != OK:
		status = error_string(err)
		peer = null
		changed.emit()
		return
	transport = "lan"
	active = true
	host_id = "1"
	local_id = str(peer.get_unique_id())
	members = {local_id:player_name.strip_edges().left(32) if not player_name.strip_edges().is_empty() else "幸存者"}
	room_code = address
	last_host = Time.get_ticks_msec()/1000.0
	peer.peer_connected.connect(func(id):
		if id == 1:
			var same_room = resume_room == room_code
			send_to(host_id,{"type":"hello","name":player_name,"resume_id":resume_id if same_room else "","resume_secret":resume_secret if same_room else ""},true))
	peer.peer_disconnected.connect(_lan_peer_left)
	status = "正在连接房主…"
	changed.emit()

func host_steam() -> void:
	leave()
	if not enable_steam(): return
	transport = "steam"
	steam.createLobby(2,4)
	status = "正在创建 Steam 房间…"
	changed.emit()

func search_steam() -> void:
	if not enable_steam(): return
	steam.addRequestLobbyListStringFilter("game",PROTOCOL,0)
	steam.addRequestLobbyListStringFilter("admission","1",0)
	search_transport = "steam"
	searching = true
	rooms.clear()
	steam.requestLobbyList()
	status = "正在搜索 Steam 房间…"
	changed.emit()

func join_steam(code: String) -> void:
	if not code.is_valid_int():
		status = "Steam 房间号应为一串数字"
		changed.emit()
		return
	leave()
	if not enable_steam(): return
	transport = "steam"
	steam.joinLobby(int(code))
	status = "正在加入 Steam 房间…"
	changed.emit()

func _steam_created(result: int, id: int) -> void:
	if result != 1:
		status = "Steam 创建房间失败："+str(result)
		changed.emit()
		return
	lobby = id
	steam.setLobbyData(id,"game",PROTOCOL)
	steam.setLobbyData(id,"name",str(steam.getPersonaName())+" 的哨站")
	steam.setLobbyData(id,"playing","0")
	steam.setLobbyData(id,"admission","1")
	steam.setLobbyData(id,"map_id",map_id)
	steam.setLobbyData(id,"defense_difficulty",defense_difficulty)
	steam.setLobbyJoinable(id,true)

func _steam_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		status = "Steam 加入房间失败："+str(response)
		changed.emit()
		return
	if steam.getLobbyData(id,"game") != PROTOCOL or not Data.Maps.valid(str(steam.getLobbyData(id,"map_id"))):
		steam.leaveLobby(id)
		status = "该房间版本不兼容或已开始"
		changed.emit()
		return
	lobby = id
	active = true
	local_id = str(steam.getSteamID())
	host_id = str(steam.getLobbyOwner(id))
	room_code = str(id)
	var selected_map = str(steam.getLobbyData(id,"map_id"))
	if Data.Maps.valid(selected_map): map_id = selected_map
	var selected_difficulty = str(steam.getLobbyData(id,"defense_difficulty"))
	if selected_difficulty in DefensePopulation.DIFFICULTIES: defense_difficulty = selected_difficulty
	last_host = Time.get_ticks_msec()/1000.0
	if steam.getLobbyData(id,"playing") == "1":
		# Steam authenticates the account id; the authority checks the sealed roster.
		members = {host_id:steam.getFriendPersonaName(int(host_id)),local_id:steam.getPersonaName()}
		send_to(host_id,{"type":"resume_request"},true)
	else: refresh_steam_members()
	status = "Steam 房间已连接"
	changed.emit()

func refresh_steam_members() -> void:
	if lobby == 0: return
	if playing or loading:
		var present: Array = []
		for i in int(steam.getNumLobbyMembers(lobby)): present.append(str(steam.getLobbyMemberByIndex(lobby,i)))
		if not present.has(host_id):
			_connection_lost("房主已离开，合作对局结束")
			return
		for id in members:
			if id != local_id and not present.has(id):
				if loading:
					_connection_lost("队员在加载期间离开，请重新创建房间")
					return
				member_left.emit(id)
		return
	var previous = members.duplicate()
	members.clear()
	for i in mini(4,int(steam.getNumLobbyMembers(lobby))):
		var id: int = steam.getLobbyMemberByIndex(lobby,i)
		members[str(id)] = str(steam.getFriendPersonaName(id)).left(128)
	for id in previous:
		if not members.has(id):
			if loading:
				_connection_lost("队员在加载期间离开，请重新创建房间")
				return
			member_left.emit(id)
	if active and not members.has(host_id):
		_connection_lost("房主已离开，合作对局结束")
		return
	changed.emit()

func _steam_members_changed(id: int, _changed: int, _making: int, _state: int) -> void:
	if id == lobby: refresh_steam_members()

func _steam_request(id: int) -> void:
	if not active: return
	for i in int(steam.getNumLobbyMembers(lobby)):
		if steam.getLobbyMemberByIndex(lobby,i) == id:
			steam.acceptP2PSessionWithUser(id)
			return

func _steam_rooms(ids: Array) -> void:
	if search_transport != "steam": return
	searching = false
	rooms.clear()
	for id in ids:
		if not Data.Maps.valid(str(steam.getLobbyData(id,"map_id"))): continue
		rooms.append({"id":str(id),"name":str(steam.getLobbyData(id,"name")),"count":steam.getNumLobbyMembers(id),"map_id":str(steam.getLobbyData(id,"map_id")),"transport":"steam"})
	status = "找到 %d 个 Steam 房间" % rooms.size()
	changed.emit()

func begin_match() -> void:
	if not is_host() or members.size() < 2 or members.size() > 4 or playing or loading: return
	loading = true
	if transport == "steam": steam.setLobbyData(lobby,"playing","1")
	loading_started = Time.get_ticks_msec()
	ready_members.clear()
	nonce = str(Time.get_unix_time_from_system())+"-"+str(randi())
	status = "正在加载战场，等待所有队员准备完成…"
	broadcast({"type":"prepare","members":members,"nonce":nonce,"map_id":map_id,"defense_difficulty":defense_difficulty},true)
	map_preparing.emit()
	changed.emit()

func confirm_map_ready() -> void:
	if not active or not loading: return
	if is_host():
		ready_members[local_id] = true
		finish_preparing()
	else: send_to(host_id,{"type":"map_ready","map_id":map_id},true)

func finish_preparing() -> void:
	if not is_host() or not loading or members.size() < 2: return
	for id in members:
		if not ready_members.has(id): return
	loading = false
	playing = true
	if transport == "steam":
		steam.setLobbyData(lobby,"playing","1")
		# Keep the lobby accessible for original members to reconnect; admission is authoritative.
		steam.setLobbyJoinable(lobby,true)
	broadcast({"type":"start","members":members,"nonce":nonce,"map_id":map_id,"defense_difficulty":defense_difficulty},true)
	match_started.emit()
	changed.emit()

func send_to(id: String, packet: Dictionary, reliable := false) -> void:
	if id == local_id: return
	send_bytes(id,encode_packet(packet),reliable)

func encode_packet(packet: Dictionary) -> PackedByteArray:
	var envelope = packet.duplicate()
	envelope.protocol = PROTOCOL
	envelope.session = nonce
	return var_to_bytes(envelope).compress(FileAccess.COMPRESSION_DEFLATE)

func send_bytes(id: String, bytes: PackedByteArray, reliable: bool) -> void:
	# Defense state plus a horde can exceed one datagram on either transport.
	reliable = reliable or bytes.size() > 1100
	if transport == "lan" and peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if is_host() and members.has(id) and not routes.has(id): return
		var destination = int(routes.get(id,int(id)))
		var remote = peer.get_peer(destination)
		if not remote or remote.get_state() != ENetPacketPeer.STATE_CONNECTED: return
		peer.set_target_peer(destination)
		peer.transfer_channel = 0 if reliable else 1
		peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
		peer.put_packet(bytes)
	elif transport == "steam" and steam_ready:
		# Steam unreliable packets have a 1200-byte limit. World snapshots use reliable delivery.
		steam.sendP2PPacket(int(id),bytes,2 if reliable or bytes.size() > 1100 else 0,0)

func broadcast(packet: Dictionary, reliable := false) -> void:
	var bytes = encode_packet(packet)
	for id in members:
		if id != local_id: send_bytes(id,bytes,reliable)

func send_input(command: Dictionary) -> void:
	if not active or not playing or is_host(): return
	send_sequence += 1
	var payload = command.duplicate()
	# Every later input carries these counters, so ordered-unreliable coalescing
	# cannot erase a one-frame jump/reload when several physics ticks share a frame.
	for action in sent_edges:
		if command.get(action,false): sent_edges[action] += 1
		payload[action+"_seq"] = sent_edges[action]
	send_to(host_id,{"type":"input","command":payload,"seq":send_sequence})

func recover_input_edges(id: String, command: Dictionary) -> Dictionary:
	var clean = command.duplicate()
	var previous: Dictionary = received_edges.get(id,{"jump":0,"reload":0,"use_self":0,"shove":0,"wave_ready":0,"fire_pressed":0,"ultimate":0})
	for action in previous:
		var sequence = command.get(action+"_seq",0)
		if not sequence is int or sequence < 0: return {}
		clean[action] = sequence > previous[action] if command.has(action+"_seq") else command.get(action,false)
		previous[action] = maxi(previous[action],sequence)
	received_edges[id] = previous
	return clean

func send_world(state: Dictionary, effects: Array, reliable := false) -> void:
	if not is_host(): return
	if transport == "steam":
		var admission = "1" if accepts_new_members() else "0"
		if admission != admission_metadata:
			admission_metadata = admission
			steam.setLobbyData(lobby,"admission",admission)
	send_sequence += 1
	broadcast({"type":"world","state":state,"seq":send_sequence},reliable or state.failed or state.get("won",false))
	if not effects.is_empty(): broadcast({"type":"effects","effects":effects},true)

func search_lan() -> void:
	search_transport = "lan"
	rooms.clear()
	searching = lan_directory.search(PROTOCOL)
	status = "正在搜索局域网房间…" if searching else "无法扫描局域网，请尝试直接连接"
	changed.emit()

func stop_room_search() -> void:
	lan_directory.stop_search()
	searching = false
	search_transport = ""

func _process(dt: float) -> void:
	var advertisement: Dictionary = {}
	if is_host() and transport == "lan" and accepts_new_members():
		advertisement = {"name":str(members.get(host_id,"房主"))+"的防线","port":int(room_code.get_slice(":",1)),"count":members.size(),"map_id":map_id}
	if lan_directory.step(dt,PROTOCOL,advertisement) and search_transport == "lan":
		rooms = lan_directory.rooms.values().filter(func(room): return Data.Maps.valid(room.map_id))
		searching = lan_directory.scanning
		status = "正在搜索局域网房间…" if searching else "找到 %d 个局域网房间" % rooms.size()
		changed.emit()
	rate_timer += dt
	if rate_timer >= 1:
		rate_timer = 0
		packet_counts.clear()
	if steam_ready: steam.run_callbacks()
	if not active: return
	for id in pending_resumes.keys():
		if Time.get_ticks_msec()-pending_resumes[id] > 30000:
			pending_resumes.erase(id)
			_peer_left(int(id))
	if loading and Time.get_ticks_msec()-loading_started > 30000:
		_connection_lost("战场加载超时，请重新创建房间")
		return
	if transport == "lan" and peer:
		peer.poll()
		var budget = 128
		while is_instance_valid(peer) and peer.get_available_packet_count() > 0 and budget > 0:
			var sender = str(peer.get_packet_peer())
			var bytes = peer.get_packet()
			receive(sender,bytes)
			budget -= 1
	elif transport == "steam" and steam_ready:
		for i in range(128):
			var size: int = steam.getAvailableP2PPacketSize(0)
			if size <= 0: break
			var packet: Dictionary = steam.readP2PPacket(size,0)
			if not packet.is_empty(): receive(str(packet.remote_steam_id),packet.data)
	if not active: return
	update_network_probes(Time.get_ticks_msec())
	heartbeat += dt
	if heartbeat >= 1:
		heartbeat = 0
		if is_host(): broadcast({"type":"ping"})
		elif active: send_to(host_id,{"type":"ping"})
	if not is_host() and Time.get_ticks_msec()/1000.0-last_host > 12:
		_connection_lost("连接房主超时，请检查网络后重新加入")

func receive(sender: String, bytes: PackedByteArray) -> void:
	if bytes.size() > 262144: return
	packet_counts[sender] = packet_counts.get(sender,0)+1
	if packet_counts[sender] > 180: return
	var raw = bytes.decompress_dynamic(2_000_000,FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty(): return
	var packet = bytes_to_var(raw) # Objects are intentionally prohibited.
	if not packet is Dictionary or packet.get("protocol") != PROTOCOL: return
	if packet.get("type") == "hello" and is_host() and transport == "lan":
		admit_lan(sender,packet)
		return
	if is_host() and transport == "lan":
		var identity = ""
		for id in routes:
			if str(routes[id]) == sender: identity = id; break
		if identity.is_empty(): return
		sender = identity
	if sender == host_id and not is_host() and packet.get("type") == "welcome":
		if not packet.get("identity") is String or not packet.get("secret") is String or packet.secret.length() != 64: return
		local_id = packet.identity
		resume_room = room_code
		resume_id = local_id
		resume_secret = packet.secret
		save_resume_identity()
		return
	if sender == host_id and not is_host() and packet.get("type") == "rejected":
		_connection_lost(str(packet.get("reason","房间拒绝加入")))
		return
	if packet.get("type") == "resume_request" and is_host() and transport == "steam" and playing:
		if not members.has(sender):
			if not accepts_new_members() or members.size() >= 4:
				send_to(sender,{"type":"rejected","reason":"战斗已开始或房间已满，仅允许原成员重连"},true)
				return
			members[sender] = str(steam.getFriendPersonaName(int(sender))).left(32)
			broadcast({"type":"members","members":members,"map_id":map_id,"defense_difficulty":defense_difficulty},true)
		if sender == host_id: return
		pending_resumes[sender] = Time.get_ticks_msec()
		send_to(sender,preparation_packet(),true)
		return
	if sender != host_id and not members.has(sender): return
	if sender == host_id: last_host = Time.get_ticks_msec()/1000.0
	match packet.get("type"):
		"prepare":
			if sender == host_id and not playing and packet.get("members") is Dictionary and packet.members.size() in [2,3,4] and packet.get("nonce") is String and Data.Maps.valid(packet.get("map_id")) and packet.get("defense_difficulty") in DefensePopulation.DIFFICULTIES:
				map_id = packet.map_id
				defense_difficulty = packet.defense_difficulty
				nonce = packet.nonce
				members = packet.members
				reconnecting = packet.get("resume",false) == true
				receive_sequence = -1
				loading = true
				loading_started = Time.get_ticks_msec()
				status = "正在加载房主选择的战场…"
				map_preparing.emit()
				changed.emit()
		"map_ready":
			if is_host() and playing and pending_resumes.has(sender) and packet.get("session") == nonce and packet.get("map_id") == map_id:
				pending_resumes.erase(sender)
				input_sequences.erase(sender)
				received_edges.erase(sender)
				send_to(sender,{"type":"start","members":members,"nonce":nonce,"map_id":map_id,"defense_difficulty":defense_difficulty},true)
				member_rejoined.emit(sender)
				return
			if is_host() and loading and members.has(sender) and packet.get("session") == nonce and packet.get("map_id") == map_id:
				ready_members[sender] = true
				finish_preparing()
		"net_probe":
			if is_host() and playing and packet.get("session") == nonce and packet.get("seq") is int:
				send_to(sender,{"type":"net_reply","seq":packet.seq},true)
		"net_reply":
			if sender == host_id and playing and packet.get("session") == nonce and packet.get("seq") is int:
				record_probe_reply(packet.seq,Time.get_ticks_msec())
		"members":
			if sender == host_id and packet.get("members") is Dictionary and packet.members.size() <= 4 and Data.Maps.valid(packet.get("map_id")) and packet.get("defense_difficulty") in DefensePopulation.DIFFICULTIES:
				map_id = packet.map_id
				defense_difficulty = packet.defense_difficulty
				members = packet.members
				status = "房间已连接，等待房主开始"
				changed.emit()
		"start":
			if sender == host_id and loading and not playing and packet.get("nonce") == nonce and packet.get("map_id") == map_id and packet.get("defense_difficulty") == defense_difficulty and packet.get("members") is Dictionary and packet.members.size() in [2,3,4]:
				map_id = packet.map_id
				nonce = packet.nonce
				members = packet.members
				playing = true
				loading = false
				match_started.emit()
		"input":
			if is_host() and playing and not pending_resumes.has(sender) and packet.get("session") == nonce and packet.get("command") is Dictionary and packet.get("seq") is int:
				if packet.seq > input_sequences.get(sender,-1):
					input_sequences[sender] = packet.seq
					input_received.emit(sender,recover_input_edges(sender,packet.command))
		"world":
			if sender == host_id and playing and packet.get("session") == nonce and packet.get("seq") is int and packet.seq > receive_sequence:
				if valid_world(packet.get("state")):
					record_snapshot(packet.seq,Time.get_ticks_msec())
					receive_sequence = packet.seq
					world_received.emit(packet.state)
		"effects":
			if sender == host_id and playing and packet.get("session") == nonce and packet.get("effects") is Array and packet.effects.size() < 1024: effects_received.emit(packet.effects)
		"leave":
			if sender == host_id: _connection_lost("房主已结束房间")
			elif is_host(): _peer_left(int(sender))

func valid_world(value) -> bool:
	if not value is Dictionary or value.get("map_id") != map_id: return false
	var shared = value.get("shared_progression")
	var Store = preload("res://scripts/progression_store.gd")
	if not Store.valid(shared) or shared.version != 8 or shared.coins != 0 or shared.diamonds != 0: return false
	var profile = Store.new()
	profile.data = shared
	if not value.get("coop_host","") is String: return false
	if not value.get("coin_drops",[]) is Array or value.get("coin_drops",[]).size() > 512: return false
	for drop in value.get("coin_drops",[]):
		if not drop is Dictionary or not drop.get("owner") is String: return false
		for field in ["pos","origin","scatter"]:
			if not drop.get(field) is Vector3 or not drop[field].is_finite(): return false
		for field in ["age","value"]:
			if not (drop.get(field) is int or drop.get(field) is float) or not is_finite(drop[field]): return false
	if not value is Dictionary or not value.has_all(["pawns","zombies","mode","elapsed","wave","cleared","spawned","kills","rest","failed","cause","culprit"]): return false
	if not value.pawns is Dictionary or value.pawns.size() > 4 or not value.zombies is Array: return false
	if value.get("coop_host","") != "" and (not members.has(value.coop_host) or not value.get("pawns",{}).has(value.coop_host)): return false
	if value.mode != "defense" or not value.get("won",false) is bool: return false
	if value.mode == "defense":
		if map_id != "graypine_defense" or not value.get("defense") is Dictionary: return false
		var defense_state: Dictionary = value.defense
		if not defense_state.has_all(["started","crystal_hp","crystal_max_hp","wave","objective","difficulty","difficulty_multiplier"]): return false
		if not defense_state.started is bool or not defense_state.objective is String or defense_state.objective.length() > 160: return false
		if not defense_state.difficulty is String or defense_state.difficulty not in DefensePopulation.DIFFICULTIES: return false
		if not (defense_state.difficulty_multiplier is int or defense_state.difficulty_multiplier is float) or not is_equal_approx(float(defense_state.difficulty_multiplier),DefensePopulation.difficulty_multiplier(defense_state.difficulty)): return false
		for key in ["crystal_hp","crystal_max_hp","wave"]:
			if not (defense_state[key] is int or defense_state[key] is float) or not is_finite(defense_state[key]): return false
		if defense_state.crystal_hp < 0 or defense_state.crystal_hp > defense_state.crystal_max_hp or defense_state.crystal_max_hp != Data.Maps.Defense.CRYSTAL_MAX_HP: return false
		if not valid_defense_equipment(defense_state): return false
		if not preload("res://scripts/defense_structures.gd").valid_state(defense_state.get("structures")): return false
		if defense_state.wave < 1 or defense_state.wave != floor(defense_state.wave): return false
	for key in ["elapsed","wave","cleared","spawned","kills","rest","culprit"]:
		if not (value[key] is int or value[key] is float) or not is_finite(value[key]): return false
	for id in value.pawns:
		var p = value.pawns[id]
		if not members.has(id) or not p is Dictionary or not p.has_all(["pos","hp","height","yaw","pitch","weapon","ammo","appearance","fire_anim","switch","reload","reloading","aim","hits","shots","kills","protection","requested","id","name"]): return false
		for field in ["shove_cd","shove_gap","shove_anim","shove_window","damage_hint"]:
			if not (p.get(field) is float or p.get(field) is int) or not is_finite(p[field]) or p[field] < 0 or p[field] > 3.5: return false
		if not p.get("shove_count") is int or p.shove_count < 0 or p.shove_count > 2: return false
		if value.mode == "defense":
			if not p.has_all(["reserve","weapon1","weapon2","weapon_slot","slot","reserves","slot_ammo","slot_reserves","grenades","hint"]): return false
			for field in ["reserve","weapon1","weapon2","weapon_slot","slot","grenades"]:
				if not p[field] is int: return false
			if not p.get("ultimate_unlocked") is bool or p.ultimate_unlocked != shared.ultimate_unlocked: return false
			if p.weapon1 < 0 or p.weapon1 >= Data.weapons.size() or p.weapon2 < 0 or p.weapon2 >= Data.weapons.size(): return false
			if p.weapon_slot not in [1,2] or p.slot < 1 or p.slot > 4 or p.grenades < 0 or p.grenades > profile.grenade_capacity() or p.reserve < 0: return false
			if not p.reserves is Array or p.reserves.size() != 10: return false
			for index in 10:
				if not p.reserves[index] is int or p.reserves[index] < 0 or p.reserves[index] > 1000000000: return false
			for field in ["slot_ammo","slot_reserves"]:
				if not p[field] is Array or p[field].size() != 2: return false
				for index in 2:
					var weapon: int = p.weapon1 if index == 0 else p.weapon2
					var limit: int = profile.magazine_capacity(str(Data.weapons[weapon].id),int(Data.weapons[weapon].capacity)) if field == "slot_ammo" else 1000000000
					if not p[field][index] is int or p[field][index] < 0 or p[field][index] > limit: return false
			if p.reserve > 1000000000: return false
			if not p.hint is String or p.hint.length() > 160: return false
		if not p.get("crouch",0.0) is float and not p.get("crouch",0.0) is int: return false
		if not is_finite(p.get("crouch",0.0)) or p.get("crouch",0.0) < 0 or p.get("crouch",0.0) > 1: return false
		if not p.get("damage_dir") is Vector2 or not p.damage_dir.is_finite() or p.damage_dir.length() > 1.01 or not p.get("damage_rear") is bool: return false
		if not p.pos is Vector2 or not p.pos.is_finite() or not p.ammo is Array or p.ammo.size() != 10 or not p.appearance is Array or p.appearance.size() != 3: return false
		if not p.appearance[0] is int or int(p.appearance[0]) < 0 or int(p.appearance[0]) >= Data.MODELS.size(): return false
		for key in ["hp","height","yaw","pitch","weapon","fire_anim","switch","reload","hits","shots","kills","protection","requested"]:
			if not (p[key] is int or p[key] is float) or not is_finite(p[key]): return false
		if p.has("connected") and not p.connected is bool: return false
		for field in ["ultimate_cd","ultimate_remaining","ultimate_sheathe"]:
			if not (p.get(field,0.0) is int or p.get(field,0.0) is float) or not is_finite(float(p.get(field,0.0))) or p.get(field,0.0) < 0 or p.get(field,0.0) > 100: return false
		if p.get("ultimate_remaining",0.0) > 10: return false
		if p.hp < 0 or p.hp > profile.max_health() or p.weapon < 0 or p.weapon > 9 or p.height < -2 or p.height > 32: return false
	for z in value.zombies:
		if not z is Dictionary or not z.has_all(["id","pos","kind","hp","armor","down","born","heading","attack_time","rage","rage_pause","state"]): return false
		if z.get("map_id") != map_id: return false
		for field in ["chase_speed","move_speed"]:
			if not (z.get(field) is float or z.get(field) is int) or not is_finite(z[field]) or z[field] < 0 or z[field] > 15: return false
		if not z.pos is Vector2 or not z.pos.is_finite() or not Data.enemies.has(z.kind): return false
		for key in ["id","hp","armor","down","born","heading","attack_time","rage_pause"]:
			if not (z[key] is int or z[key] is float) or not is_finite(z[key]): return false
	return true

func _lan_peer_left(id: int) -> void:
	if not is_host():
		_peer_left(id)
		return
	for identity in routes.keys():
		if routes[identity] == id:
			_peer_left(int(identity))
			return

func _peer_left(id: int) -> void:
	if not active: return
	var key = str(id)
	if loading and members.has(key):
		_connection_lost("队员在加载期间离开，请重新创建房间")
		return
	if key == host_id and not is_host():
		_connection_lost("房主已断开连接")
		return
	routes.erase(key)
	pending_resumes.erase(key)
	if not playing:
		members.erase(key)
		resume_tokens.erase(key)
	received_edges.erase(key)
	input_sequences.erase(key)
	member_left.emit(key)
	if is_host(): broadcast({"type":"members","members":members,"map_id":map_id,"defense_difficulty":defense_difficulty},true)
	changed.emit()

func _connection_lost(message: String) -> void:
	leave()
	status = message
	disconnected.emit(message)
	changed.emit()

func leave() -> void:
	lan_directory.stop_host()
	stop_room_search()
	admission_metadata = ""
	map_id = Data.settings.map_id
	defense_difficulty = DefensePopulation.normalize_difficulty(Data.settings.defense_difficulty)
	loading = false
	ready_members.clear()
	if active:
		if is_host(): broadcast({"type":"leave"},true)
		else: send_to(host_id,{"type":"leave"},true)
	active = false
	if peer:
		peer.close()
		peer = null
	if steam_ready and lobby != 0:
		for id in members:
			if id != local_id: steam.closeP2PSessionWithUser(int(id))
		steam.leaveLobby(lobby)
	lobby = 0
	active = false
	playing = false
	transport = ""
	local_id = "solo"
	host_id = ""
	members.clear()
	routes.clear()
	resume_tokens.clear()
	pending_resumes.clear()
	reconnecting = false
	input_sequences.clear()
	sent_edges = {"jump":0,"reload":0,"use_self":0,"shove":0,"wave_ready":0,"fire_pressed":0,"ultimate":0}
	received_edges.clear()
	room_code = ""
	nonce = ""
	send_sequence = 0
	receive_sequence = -1
	probes.clear()
	snapshot_samples.clear()
	probe_sequence = 0
	last_probe = 0
	last_probe_reply = 0
	changed.emit()

# Reliable round-trip probes measure latency without being superseded by input.
# Loss comes from missing authoritative world sequence numbers, not probe timeouts.
func update_network_probes(now: int) -> void:
	if not playing or is_host(): return
	for seq in probes.keys():
		if now - probes[seq].sent > 30000: probes.erase(seq)
	if now - last_probe < 1000: return
	last_probe = now
	probe_sequence += 1
	probes[probe_sequence] = {"sent":now,"rtt":-1}
	send_to(host_id,{"type":"net_probe","seq":probe_sequence},true)

func record_probe_reply(seq: int, now: int) -> void:
	if not probes.has(seq) or probes[seq].rtt >= 0: return
	probes[seq].rtt = maxi(0,now-probes[seq].sent)
	last_probe_reply = now

func network_metrics(now: int = -1) -> Dictionary:
	if now < 0: now = Time.get_ticks_msec()
	var total = 0
	var unanswered = 0
	var sum_rtt = 0.0
	var received = 0
	for probe in probes.values():
		if now-probe.sent > 30000: continue
		if probe.rtt >= 0:
			total += 1
			received += 1
			sum_rtt += probe.rtt
		elif now-probe.sent >= 3000:
			total += 1
			unanswered += 1
	var rtt = sum_rtt / received if received > 0 else -1.0
	var expected_updates = 0
	var missing_updates = 0
	for sample in snapshot_samples:
		if now-sample.time <= 30000:
			expected_updates += sample.expected
			missing_updates += sample.missing
	var loss = 100.0 * missing_updates / expected_updates if expected_updates > 0 else -1.0
	var quality = "测量中"
	if total > 0:
		quality = "良好" if rtt >= 0 and rtt < 100 and loss >= 0 and loss < 3 else "一般" if rtt >= 0 and rtt < 200 and loss >= 0 and loss < 10 else "较差"
		if unanswered > 0 or (last_probe_reply > 0 and now-last_probe_reply > 3000): quality = "较差"
	return {"rtt":rtt,"loss":loss,"samples":total,"quality":quality}

func record_snapshot(seq: int, now: int) -> void:
	var expected = seq-receive_sequence if receive_sequence >= 0 else 1
	if expected <= 0: return
	snapshot_samples.append({"time":now,"expected":expected,"missing":expected-1})
	while not snapshot_samples.is_empty() and now-snapshot_samples[0].time > 30000:
		snapshot_samples.pop_front()

func valid_defense_equipment(state: Dictionary) -> bool:
	var ids: Dictionary = {}
	if not state.get("projectiles") is Array or state.projectiles.size() > 24: return false
	for grenade in state.projectiles:
		if not grenade is Dictionary or not grenade.has_all(["id","owner","pos","velocity","fuse"]): return false
		if not grenade.id is int or ids.has(grenade.id) or not grenade.owner is String: return false
		ids[grenade.id] = true
		if not grenade.pos is Vector3 or not grenade.pos.is_finite() or not grenade.velocity is Vector3 or not grenade.velocity.is_finite(): return false
		if not grenade.fuse is float or not is_finite(grenade.fuse) or grenade.fuse < 0 or grenade.fuse > 1.5: return false
	return true
