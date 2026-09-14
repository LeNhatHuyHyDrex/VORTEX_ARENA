extends Node
## Tầng vận chuyển mạng cho LAN 1v1.
##
## Mô hình: HOST LÀ MÁY CHỦ (host-authoritative).
##   - Máy khách chỉ gửi INPUT lên host (không tự quyết định kết quả đòn đánh).
##   - Host mô phỏng cả hai tướng rồi phát snapshot trạng thái xuống.
##   - Nhờ vậy hai bên luôn thấy cùng một sự thật, không bị lệch máu hay trúng đòn ảo.
##
## Trên LAN độ trễ thường 1-5ms nên không cần client-side prediction phức tạp —
## cảm giác vẫn tức thì.

signal hosting_started()
signal joined_ok()
signal join_failed(reason: String)
signal disconnected()
signal peers_changed()
signal server_list_changed(servers: Array)

const DISCOVERY_PORT := GameData.DEFAULT_PORT + 1
const BEACON_INTERVAL := 0.6
const SERVER_TIMEOUT := 2.5

var is_host := false
var is_online := false
var local_id := 1

## peer_id -> {"name": String, "champion": StringName, "ready": bool}
var players: Dictionary = {}

## Danh sách server tìm được qua broadcast: ip -> {"ip", "name", "last_seen"}
var _found_servers: Dictionary = {}
var _beacon: PacketPeerUDP = null
var _listener: PacketPeerUDP = null
var _beacon_timer := 0.0
var _discovering := false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	# Autoload này phải chạy kể cả khi không có ai kết nối.
	set_process(true)

func _process(delta: float) -> void:
	if is_host and is_online:
		_beacon_timer -= delta
		if _beacon_timer <= 0.0:
			_beacon_timer = BEACON_INTERVAL
			_send_beacon()
	if _discovering:
		_poll_discovery(delta)

# ---------------------------------------------------------------- host / join

func host_game(port: int = GameData.DEFAULT_PORT, server_name: String = "") -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 1)  # 1 client = tổng 2 người
	if err != OK:
		push_error("Không mở được server trên cổng %d (lỗi %d)" % [port, err])
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_online = true
	local_id = 1
	players.clear()
	players[1] = {"name": server_name if server_name != "" else "Host", "champion": &"fire_mage", "ready": false}
	_start_beacon(server_name)
	hosting_started.emit()
	peers_changed.emit()
	return OK

func join_game(ip: String, port: int = GameData.DEFAULT_PORT) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		join_failed.emit("Không tạo được kết nối tới %s:%d" % [ip, port])
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	is_online = true
	return OK

func leave() -> void:
	_stop_discovery()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_host = false
	is_online = false
	local_id = 1
	players.clear()

# ------------------------------------------------------------------ callbacks

func _on_peer_connected(id: int) -> void:
	if is_host:
		if not players.has(id):
			players[id] = {"name": "Player %d" % id, "champion": &"fire_mage", "ready": false}
		peers_changed.emit()

func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	peers_changed.emit()
	if is_host:
		# Đối thủ rời trận -> báo cho tầng game biết để kết thúc.
		disconnected.emit()

func _on_connected_to_server() -> void:
	local_id = multiplayer.get_unique_id()
	joined_ok.emit()

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	is_online = false
	join_failed.emit("Không kết nối được. Kiểm tra IP và tường lửa.")

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	is_online = false
	is_host = false
	players.clear()
	disconnected.emit()

# ---------------------------------------------------------------------- RPCs

## Máy khách gửi input của mình lên host. Không dùng reliable vì mất 1 frame
## input không sao, nhưng gửi lại sẽ gây khựng.
@rpc("any_peer", "call_remote", "unreliable_ordered", 0)
func submit_input(move: Vector2, aim: Vector2, cast_mask: int,
		target: Vector2 = Vector2.ZERO) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	var entry: Variant = players.get(sender)
	if entry == null:
		return
	entry["input"] = {"move": move, "aim": aim, "cast": cast_mask, "target": target}

## Host phát snapshot trạng thái xuống máy khách.
@rpc("authority", "call_remote", "unreliable_ordered", 0)
func push_snapshot(snapshot: Dictionary) -> void:
	if is_host:
		return
	snapshot_received.emit(snapshot)

## Sự kiện rời rạc (đòn đánh trúng, chết, hiệu ứng) — phải tới nơi chắc chắn.
@rpc("authority", "call_remote", "reliable", 1)
func push_event(event: Dictionary) -> void:
	if is_host:
		return
	game_event.emit(event)

## Máy khách báo tên + tướng đã chọn lên host.
@rpc("any_peer", "call_remote", "reliable", 1)
func register_player(display_name: String, champion_id: String) -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if not players.has(sender):
		players[sender] = {}
	players[sender]["name"] = display_name
	players[sender]["champion"] = StringName(champion_id)
	peers_changed.emit()
	# Gửi lại danh sách đầy đủ cho mọi người.
	_sync_roster.rpc(players)

@rpc("authority", "call_remote", "reliable", 1)
func _sync_roster(roster: Dictionary) -> void:
	players = roster.duplicate(true)
	peers_changed.emit()

signal snapshot_received(snapshot: Dictionary)
signal game_event(event: Dictionary)

func send_input(move: Vector2, aim: Vector2, cast_mask: int,
		target: Vector2 = Vector2.ZERO) -> void:
	if is_host or not is_online:
		return
	submit_input.rpc_id(1, move, aim, cast_mask, target)

func send_register(display_name: String, champion_id: StringName) -> void:
	if is_host or not is_online:
		return
	register_player.rpc_id(1, display_name, String(champion_id))

func broadcast_snapshot(snapshot: Dictionary) -> void:
	if not is_host:
		return
	push_snapshot.rpc(snapshot)

func broadcast_event(event: Dictionary) -> void:
	if not is_host:
		return
	push_event.rpc(event)

func opponent_id() -> int:
	for id in players.keys():
		if id != local_id:
			return id
	return 0

# ------------------------------------------------------------- LAN discovery

func start_discovery() -> void:
	if _discovering:
		return
	_listener = PacketPeerUDP.new()
	var err := _listener.bind(DISCOVERY_PORT)
	if err != OK:
		push_warning("Không mở được cổng dò tìm LAN (%d)" % err)
		_listener = null
		return
	_discovering = true
	_found_servers.clear()

func stop_discovery() -> void:
	_discovering = false
	_stop_discovery()

func _stop_discovery() -> void:
	_discovering = false
	if _listener != null:
		_listener.close()
		_listener = null
	if _beacon != null:
		_beacon.close()
		_beacon = null

func _start_beacon(server_name: String) -> void:
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_beacon_payload = JSON.stringify({"n": server_name if server_name != "" else "Combo Arena", "p": GameData.DEFAULT_PORT})
	_beacon_timer = 0.0

var _beacon_payload := ""

func _send_beacon() -> void:
	if _beacon == null:
		return
	_beacon.put_packet(_beacon_payload.to_utf8_buffer())

func _poll_discovery(_delta: float) -> void:
	if _listener == null:
		return
	var changed := false
	while _listener.get_available_packet_count() > 0:
		var packet := _listener.get_packet()
		var from_ip := _listener.get_packet_ip()
		var parsed: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if parsed is Dictionary:
			var previous: Variant = _found_servers.get(from_ip)
			var label := str(parsed.get("n", "Combo Arena"))
			# Chỉ coi là thay đổi khi server mới xuất hiện hoặc đổi tên.
			if previous == null or str(previous["name"]) != label:
				changed = true
			_found_servers[from_ip] = {
				"ip": from_ip,
				"name": label,
				"port": int(parsed.get("p", GameData.DEFAULT_PORT)),
				"last_seen": Time.get_ticks_msec() / 1000.0,
			}
	# Dọn server đã tắt (không còn phát beacon).
	var now := Time.get_ticks_msec() / 1000.0
	for ip in _found_servers.keys():
		if now - float(_found_servers[ip]["last_seen"]) > SERVER_TIMEOUT:
			_found_servers.erase(ip)
			changed = true
	if changed:
		server_list_changed.emit(found_servers())

func found_servers() -> Array:
	var out: Array = []
	for ip in _found_servers.keys():
		out.append(_found_servers[ip])
	return out
