## Transport ENet, pour le développement local.
##
## N'utilise ni MultiplayerAPI ni RPC : uniquement l'API paquet de
## MultiplayerPeer. C'est ce qui rend le remplacement par
## SteamMultiplayerPeer mécanique le jour venu — les deux exposent la même
## interface paquet — et ce qui garde la simulation hors de l'arbre de scène.
class_name EnetTransport
extends Transport

var _peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var _received: Array[NetPacket] = []
var _peers: PackedInt32Array = PackedInt32Array()
var _configured: bool = false

func host(port: int, max_clients: int) -> Error:
	var err: Error = _peer.create_server(port, max_clients)
	if err == OK:
		_configured = true
		_connect_signals()
	return err

func join(address: String, port: int) -> Error:
	var err: Error = _peer.create_client(address, port)
	if err == OK:
		_configured = true
		_connect_signals()
	return err

func _connect_signals() -> void:
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id: int) -> void:
	_remember_peer(id)

func _on_peer_disconnected(id: int) -> void:
	var index: int = _peers.find(id)
	if index >= 0:
		_peers.remove_at(index)

func _remember_peer(id: int) -> void:
	if id != 0 and _peers.find(id) < 0:
		_peers.append(id)

func poll() -> void:
	if not _configured:
		return
	_peer.poll()
	while _peer.get_available_packet_count() > 0:
		var from: int = _peer.get_packet_peer()
		var data: PackedByteArray = _peer.get_packet()
		_remember_peer(from)
		_received.append(NetPacket.new(from, data))

func send(peer_id: int, payload: PackedByteArray, mode: Mode = Mode.RELIABLE) -> Error:
	if not _configured:
		return ERR_UNCONFIGURED
	_peer.set_target_peer(peer_id)
	if mode == Mode.RELIABLE:
		_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	else:
		_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	return _peer.put_packet(payload)

func receive() -> Array[NetPacket]:
	var out: Array[NetPacket] = _received
	_received = []
	return out

func peer_ids() -> PackedInt32Array:
	return _peers

func local_peer_id() -> int:
	if not _configured:
		return 0
	return _peer.get_unique_id()

func is_session_live() -> bool:
	return _configured and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func close() -> void:
	if _configured:
		_peer.close()
		_configured = false
	_received.clear()
	_peers.clear()
