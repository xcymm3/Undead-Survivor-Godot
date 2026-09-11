extends Node
## Steam lobby/P2P and ENet LAN transports feed the exact same authoritative simulation.
signal changed
signal match_started
signal input_received(id: String, command: Dictionary)
signal world_received(state: Dictionary)
signal effects_received(effects: Array)
signal member_left(id: String)
signal disconnected(message: String)
const PROTOCOL = "undead-survivor-godot-1"
const PORT = 27777
var transport = ""
var local_id = "solo"
var host_id = ""
var members: Dictionary = {}
var rooms: Array = []
var active = false
var playing = false
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
var send_sequence = 0
var receive_sequence = -1
var packet_counts: Dictionary = {}
var rate_timer = 0.0
var probe_sequence = 0
var probes: Dictionary = {}
var last_probe = 0
var last_probe_reply = 0
var snapshot_samples: Array = []


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
	steam.allowP2PPacketRelay(true)
	return true

func host_lan(player_name: String) -> void:
	leave()
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT,3,2)
	if err != OK:
		status = "无法创建房间，端口 %d 被占用（%s）" % [PORT,error_string(err)]
		peer = null
		changed.emit()
		return
	transport = "lan"
	local_id = "1"
	host_id = "1"
	active = true
	members = {"1":player_name.strip_edges().left(32) if not player_name.strip_edges().is_empty() else "房主"}
	room_code = "127.0.0.1:%d" % PORT
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10."):
			room_code = address+":"+str(PORT)
			break
	peer.peer_disconnected.connect(_peer_left)
	status = "局域网房间已创建，等待队友加入"
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
		if id == 1: send_to(host_id,{"type":"hello","name":members[local_id]},true))
	peer.peer_disconnected.connect(_peer_left)
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
	steam.addRequestLobbyListStringFilter("playing","0",0)
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
	steam.setLobbyJoinable(id,true)

func _steam_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		status = "Steam 加入房间失败："+str(response)
		changed.emit()
		return
	if steam.getLobbyData(id,"game") not in ["",PROTOCOL] or steam.getLobbyData(id,"playing") == "1":
		steam.leaveLobby(id)
		status = "该房间版本不兼容或已开始"
		changed.emit()
		return
	lobby = id
	active = true
	local_id = str(steam.getSteamID())
	host_id = str(steam.getLobbyOwner(id))
	room_code = str(id)
	last_host = Time.get_ticks_msec()/1000.0
	refresh_steam_members()
	status = "Steam 房间已连接"
	changed.emit()

func refresh_steam_members() -> void:
	if lobby == 0: return
	var previous = members.duplicate()
	members.clear()
	for i in mini(4,int(steam.getNumLobbyMembers(lobby))):
		var id: int = steam.getLobbyMemberByIndex(lobby,i)
		members[str(id)] = str(steam.getFriendPersonaName(id)).left(128)
	for id in previous:
		if not members.has(id): member_left.emit(id)
	if active and not members.has(host_id):
		_connection_lost("房主已离开，合作对局结束")
		return
	changed.emit()

func _steam_members_changed(id: int, _changed: int, _making: int, _state: int) -> void:
	if id == lobby: refresh_steam_members()

func _steam_request(id: int) -> void:
	if active and members.has(str(id)): steam.acceptP2PSessionWithUser(id)

func _steam_rooms(ids: Array) -> void:
	rooms.clear()
	for id in ids:
		rooms.append({"id":str(id),"name":str(steam.getLobbyData(id,"name")),"count":steam.getNumLobbyMembers(id)})
	status = "找到 %d 个 Steam 房间" % rooms.size()
	changed.emit()

func begin_match() -> void:
	if not is_host() or members.size() < 2 or members.size() > 4 or playing: return
	playing = true
	nonce = str(Time.get_unix_time_from_system())+"-"+str(randi())
	if transport == "steam":
		steam.setLobbyData(lobby,"playing","1")
		steam.setLobbyJoinable(lobby,false)
	broadcast({"type":"start","members":members,"nonce":nonce},true)
	match_started.emit()
	changed.emit()

func send_to(id: String, packet: Dictionary, reliable := false) -> void:
	if id == local_id: return
	packet.protocol = PROTOCOL
	packet.session = nonce
	var bytes = var_to_bytes(packet).compress(FileAccess.COMPRESSION_DEFLATE)
	if transport == "lan" and peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var remote = peer.get_peer(int(id))
		if not remote or remote.get_state() != ENetPacketPeer.STATE_CONNECTED: return
		peer.set_target_peer(int(id))
		peer.transfer_channel = 0 if reliable else 1
		peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
		peer.put_packet(bytes)
	elif transport == "steam" and steam_ready:
		# Steam unreliable packets have a 1200-byte limit. World snapshots use reliable delivery.
		steam.sendP2PPacket(int(id),bytes,2 if reliable or bytes.size() > 1100 else 0,0)

func broadcast(packet: Dictionary, reliable := false) -> void:
	for id in members:
		if id != local_id: send_to(id,packet.duplicate(),reliable)

func send_input(command: Dictionary) -> void:
	if not active or not playing or is_host(): return
	send_sequence += 1
	send_to(host_id,{"type":"input","command":command,"seq":send_sequence})

func send_world(state: Dictionary, effects: Array) -> void:
	if not is_host(): return
	send_sequence += 1
	broadcast({"type":"world","state":state,"seq":send_sequence},state.failed)
	if not effects.is_empty(): broadcast({"type":"effects","effects":effects},true)

func _process(dt: float) -> void:
	rate_timer += dt
	if rate_timer >= 1:
		rate_timer = 0
		packet_counts.clear()
	if steam_ready: steam.run_callbacks()
	if not active: return
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
	if packet.get("type") == "hello" and is_host() and transport == "lan" and not playing and members.size() < 4:
		if not packet.get("name") is String: return
		members[sender] = packet.name.left(32)
		broadcast({"type":"members","members":members},true)
		changed.emit()
		return
	if sender != host_id and not members.has(sender): return
	if sender == host_id: last_host = Time.get_ticks_msec()/1000.0
	match packet.get("type"):
		"net_probe":
			if is_host() and playing and packet.get("session") == nonce and packet.get("seq") is int:
				send_to(sender,{"type":"net_reply","seq":packet.seq},true)
		"net_reply":
			if sender == host_id and playing and packet.get("session") == nonce and packet.get("seq") is int:
				record_probe_reply(packet.seq,Time.get_ticks_msec())
		"members":
			if sender == host_id and packet.get("members") is Dictionary and packet.members.size() <= 4:
				members = packet.members
				status = "房间已连接，等待房主开始"
				changed.emit()
		"start":
			if sender == host_id and not playing and packet.get("members") is Dictionary and packet.members.size() in [2,3,4] and packet.get("nonce") is String:
				nonce = packet.nonce
				members = packet.members
				playing = true
				match_started.emit()
		"input":
			if is_host() and playing and packet.get("session") == nonce and packet.get("command") is Dictionary and packet.get("seq") is int:
				if packet.seq > input_sequences.get(sender,-1):
					input_sequences[sender] = packet.seq
					input_received.emit(sender,packet.command)
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
	if not value is Dictionary or not value.has_all(["pawns","zombies","mode","elapsed","wave","cleared","spawned","kills","rest","failed","cause","culprit"]): return false
	if not value.pawns is Dictionary or value.pawns.size() > 4 or not value.zombies is Array: return false
	for key in ["elapsed","wave","cleared","spawned","kills","rest","culprit"]:
		if not (value[key] is int or value[key] is float) or not is_finite(value[key]): return false
	for id in value.pawns:
		var p = value.pawns[id]
		if not members.has(id) or not p is Dictionary or not p.has_all(["pos","hp","height","yaw","pitch","weapon","ammo","appearance","fire_anim","switch","reload","reloading","aim","hits","shots","kills","protection","requested","id","name"]): return false
		if not p.pos is Vector2 or not p.pos.is_finite() or not p.ammo is Array or p.ammo.size() != 10 or not p.appearance is Array or p.appearance.size() != 3: return false
		if not p.appearance[0] is int or int(p.appearance[0]) < 0 or int(p.appearance[0]) >= Data.MODELS.size(): return false
		for key in ["hp","height","yaw","pitch","weapon","fire_anim","switch","reload","hits","shots","kills","protection","requested"]:
			if not (p[key] is int or p[key] is float) or not is_finite(p[key]): return false
		if p.hp < 0 or p.hp > 100 or p.weapon < 0 or p.weapon > 9 or p.height < -2 or p.height > 32: return false
	for z in value.zombies:
		if not z is Dictionary or not z.has_all(["id","pos","kind","hp","armor","down","born","heading","attack_time","rage","rage_pause","state"]): return false
		if not z.pos is Vector2 or not z.pos.is_finite() or not Data.enemies.has(z.kind): return false
		for key in ["id","hp","armor","down","born","heading","attack_time","rage_pause"]:
			if not (z[key] is int or z[key] is float) or not is_finite(z[key]): return false
	return true

func _peer_left(id: int) -> void:
	if not active: return
	var key = str(id)
	if key == host_id and not is_host():
		_connection_lost("房主已断开连接")
		return
	members.erase(key)
	member_left.emit(key)
	if is_host(): broadcast({"type":"members","members":members},true)
	changed.emit()

func _connection_lost(message: String) -> void:
	leave()
	status = message
	disconnected.emit(message)
	changed.emit()

func leave() -> void:
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
	input_sequences.clear()
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
