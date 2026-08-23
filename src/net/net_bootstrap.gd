## Point d'entrée d'une instance : monte le transport, la simulation et,
## côté client, la synchronisation d'horloge.
##
## C'est ce nœud qui avance la simulation, dans _physics_process (invariant 1),
## et dans un ordre explicite : lire le réseau, corriger l'horloge, puis
## simuler. Laisser Simulation s'avancer toute seule ferait dépendre cet ordre
## de la position des nœuds dans l'arbre.
##
## Invariant 2 : aucun accès à l'entrée, à la caméra ou à un nœud visuel ici.
class_name NetBootstrap
extends Node

signal session_failed(reason: String)

## Intervalle entre deux sondes d'horloge, en images physiques. Six par
## seconde : assez pour remplir la fenêtre d'échantillons en 1,3 s, assez peu
## pour rester négligeable dans le trafic.
const PING_INTERVAL_FRAMES: int = 10

var options: NetOptions
var simulation: Simulation
var transport: Transport
var clock: NetClock

var _ping_seq: int = 0
var _frames_since_ping: int = PING_INTERVAL_FRAMES
var _started: bool = false

## À appeler avant l'entrée dans l'arbre pour piloter l'instance depuis un
## test plutôt que depuis la ligne de commande.
func configure(p_options: NetOptions) -> void:
	options = p_options

func _ready() -> void:
	if options == null:
		options = NetOptions.from_command_line()
	simulation = Simulation.new()
	simulation.name = "Simulation"
	add_child(simulation)

	var enet: EnetTransport = EnetTransport.new()
	var err: Error = OK
	if options.role == NetOptions.Role.HOST:
		err = enet.host(options.port, SimConfig.MAX_PLAYERS - 1)
	else:
		err = enet.join(options.address, options.port)
	if err != OK:
		session_failed.emit("transport ENet indisponible (erreur %d)" % err)
		return

	# Toujours décoré, même sans latence ni perte : un seul chemin de code.
	transport = LatencyPipe.new(enet, options.latency_msec, options.loss, options.rng_seed)
	if options.role == NetOptions.Role.CLIENT:
		clock = NetClock.new()
	_started = true

func _physics_process(_delta: float) -> void:
	if not _started:
		return
	transport.poll()
	var now_usec: int = Time.get_ticks_usec()
	_dispatch(transport.receive(), now_usec)
	if clock != null:
		_send_ping_if_due(now_usec)
		var target: int = clock.target_tick(now_usec)
		if target >= 0:
			simulation.set_target_tick(target)
	# Journalisation avant l'avancement : l'écart affiché est alors celui sur
	# lequel la correction s'appuie. Journaliser après lirait une cible fixée
	# avant l'avancement, donc décalée d'un tick.
	_log_if_due()
	simulation.advance()

func _dispatch(packets: Array[NetPacket], now_usec: int) -> void:
	for packet: NetPacket in packets:
		match NetMessage.kind_of(packet.payload):
			int(NetMessage.Kind.PING):
				_answer_ping(packet)
			int(NetMessage.Kind.PONG):
				_absorb_pong(packet, now_usec)
			int(NetMessage.Kind.COMMAND):
				var command: Command = NetMessage.decode_command(packet.payload)
				if command != null:
					simulation.buffer.push(command)

func _answer_ping(packet: NetPacket) -> void:
	var ping: NetMessage.Ping = NetMessage.decode_ping(packet.payload)
	if ping == null:
		return
	var reply: PackedByteArray = NetMessage.encode_pong(
		ping.seq, ping.send_usec, simulation.current_tick)
	transport.send(packet.peer_id, reply, Transport.Mode.UNRELIABLE)

func _absorb_pong(packet: NetPacket, now_usec: int) -> void:
	if clock == null:
		return
	var pong: NetMessage.Pong = NetMessage.decode_pong(packet.payload)
	if pong != null:
		clock.on_pong(pong, now_usec)

func _send_ping_if_due(now_usec: int) -> void:
	_frames_since_ping += 1
	if _frames_since_ping < PING_INTERVAL_FRAMES:
		return
	if not transport.is_session_live():
		return
	_frames_since_ping = 0
	_ping_seq += 1
	transport.send(
		SimConfig.HOST_PEER_ID,
		NetMessage.encode_ping(_ping_seq, now_usec),
		Transport.Mode.UNRELIABLE)

## Émet une commande vers l'hôte. Unique porte de sortie du gameplay vers le
## réseau (invariant 3).
func submit_command(command: Command) -> Error:
	if not _started:
		return ERR_UNCONFIGURED
	simulation.buffer.push(command)
	if options.role == NetOptions.Role.HOST:
		return OK
	return transport.send(
		SimConfig.HOST_PEER_ID, NetMessage.encode_command(command), Transport.Mode.RELIABLE)

## Journalise l'état d'horloge sur la sortie standard. Sans cela, une instance
## lancée en headless par tools/netharness.ps1 serait muette et le banc
## invérifiable autrement qu'en regardant deux fenêtres.
func _log_if_due() -> void:
	var interval: int = options.log_ticks_interval
	if interval <= 0 or simulation.current_tick % interval != 0:
		return
	var name_part: String = options.label if not options.label.is_empty() else "instance"
	if clock == null:
		print("[%s] tick=%d role=hote pairs=%d"
			% [name_part, simulation.current_tick, transport.peer_ids().size()])
	else:
		print("[%s] tick=%d role=client ecart=%d aller_retour_ms=%.1f retards=%d"
			% [name_part, simulation.current_tick, simulation.tick_error(),
				float(clock.last_rtt_usec) / 1000.0, simulation.buffer.dropped_late])

func _exit_tree() -> void:
	if transport != null:
		transport.close()
