extends RefCounted
## Discovery only; gameplay and reconnect authentication stay on ENet.
var responder: PacketPeerUDP
var browser: PacketPeerUDP
var rooms: Dictionary = {}
var scanning = false
var remaining = 0.0
var probe_clock = 0.0
var port = 27778
var query = ""
var instance = ""
var seen_queries: Dictionary = {}

func start_host() -> bool:
	stop_host()
	instance = Crypto.new().generate_random_bytes(12).hex_encode()
	responder = PacketPeerUDP.new()
	if responder.bind(port,"0.0.0.0") != OK:
		responder = null
		return false
	return true

func stop_host() -> void:
	if responder: responder.close()
	responder = null
	seen_queries.clear()

func search(protocol: String) -> bool:
	stop_search()
	rooms.clear()
	browser = PacketPeerUDP.new()
	if browser.bind(0,"0.0.0.0") != OK:
		browser = null
		return false
	browser.set_broadcast_enabled(true)
	query = Crypto.new().generate_random_bytes(12).hex_encode()
	scanning = true
	remaining = 2.5
	probe_clock = 0.0
	send_probe(protocol)
	return true

func stop_search() -> void:
	if browser: browser.close()
	browser = null
	scanning = false

func send_probe(protocol: String) -> void:
	if not browser: return
	var bytes = JSON.stringify({"protocol":protocol,"type":"discover","query":query}).to_utf8_buffer()
	for address in ["255.255.255.255","127.0.0.1"]:
		if browser.set_dest_address(address,port) == OK: browser.put_packet(bytes)

func step(dt: float, protocol: String, advertisement: Dictionary) -> bool:
	var changed = false
	if responder:
		for i in 32:
			if responder.get_available_packet_count() <= 0: break
			var bytes = responder.get_packet()
			var address = responder.get_packet_ip()
			var remote_port = responder.get_packet_port()
			if bytes.size() > 512 or advertisement.is_empty(): continue
			var request = JSON.parse_string(bytes.get_string_from_utf8())
			if not request is Dictionary or request.get("protocol") != protocol or request.get("type") != "discover" or not request.get("query") is String or request.query.length() != 24: continue
			var key = address+":"+str(remote_port)
			var now = Time.get_ticks_msec()
			if now-int(seen_queries.get(key,-1000)) < 300: continue
			if seen_queries.size() > 256: seen_queries.clear()
			seen_queries[key] = now
			var reply = advertisement.duplicate(true)
			reply.protocol = protocol
			reply.type = "room"
			reply.query = request.query
			reply.instance = instance
			if responder.set_dest_address(address,remote_port) == OK: responder.put_packet(JSON.stringify(reply).to_utf8_buffer())
	if browser and scanning:
		probe_clock += dt
		remaining -= dt
		if probe_clock >= .8:
			probe_clock = 0.0
			send_probe(protocol)
		for i in 32:
			if browser.get_available_packet_count() <= 0: break
			var bytes = browser.get_packet()
			var address = browser.get_packet_ip()
			if bytes.size() > 2048: continue
			var reply = JSON.parse_string(bytes.get_string_from_utf8())
			if not reply is Dictionary or reply.get("protocol") != protocol or reply.get("query") != query or reply.get("type") != "room": continue
			if not reply.get("name") is String or reply.name.length() > 64 or not reply.get("map_id") is String: continue
			if not (reply.get("port") is int or reply.get("port") is float) or reply.port < 1 or reply.port > 65535 or reply.port != floor(reply.port): continue
			if not (reply.get("count") is int or reply.get("count") is float) or reply.count < 1 or reply.count > 4 or reply.count != floor(reply.count): continue
			if not reply.get("instance") is String or reply.instance.length() != 24: continue
			var id = address+":"+str(int(reply.port))
			if address == "127.0.0.1" and rooms.has(reply.instance): continue
			var entry = {"id":id,"name":reply.name,"count":int(reply.count),"map_id":reply.map_id,"transport":"lan"}
			if rooms.get(reply.instance,{}) != entry:
				rooms[reply.instance] = entry
				changed = true
		if remaining <= 0:
			stop_search()
			changed = true
	return changed
