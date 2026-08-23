## Point d'entrée d'une instance : transport, simulation, monde et
## synchronisation d'état.
##
## C'est ce nœud qui avance la simulation, dans _physics_process (invariant 1),
## et dans un ordre explicite : lire le réseau, corriger l'horloge, appliquer
## l'autorité, interpoler, puis simuler. Laisser Simulation s'avancer toute
## seule ferait dépendre cet ordre de la position des nœuds dans l'arbre.
##
## Invariant 2 : aucun accès à l'entrée, à la caméra ou à un nœud visuel ici.
## La présentation pousse des commandes par submit_command() et lit le monde ;
## elle n'écrit jamais dedans.
class_name NetBootstrap
extends Node

signal session_failed(reason: String)
signal world_ready(world: World)

const LEVEL_PATH: String = "res://data/level/vertical_slice.tres"
const PLAYER_PATH: String = "res://data/actors/player.tres"
const GRUNT_PATH: String = "res://data/actors/grunt.tres"
const WARDEN_PATH: String = "res://data/actors/warden.tres"

## Intervalle entre deux sondes d'horloge, en images physiques.
const PING_INTERVAL_FRAMES: int = 10
## Intervalle entre deux instantanés, en ticks. Deux ticks font 30 Hz : le
## tampon d'interpolation absorbe l'écart et la bande passante est divisée
## par deux.
const SNAPSHOT_INTERVAL_TICKS: int = 2

var options: NetOptions
var simulation: Simulation
var transport: Transport
var clock: NetClock
var world: World
var sync: WorldSync
var history: CommandHistory = CommandHistory.new()

## Raison de l'échec de session, vide tant que tout va bien. Lue par
## l'interface : un joueur ne doit jamais rester devant un écran muet.
var failure_reason: String = ""

var _ping_seq: int = 0
var _frames_since_ping: int = PING_INTERVAL_FRAMES
var _started: bool = false
var _known_peers: PackedInt32Array = PackedInt32Array()

## À appeler avant l'entrée dans l'arbre pour piloter l'instance depuis un
## test plutôt que depuis la ligne de commande.
func configure(p_options: NetOptions) -> void:
	options = p_options

func is_host() -> bool:
	return options != null and options.role == NetOptions.Role.HOST

func local_player() -> Actor:
	return world.local_actor() if world != null else null

func _ready() -> void:
	if options == null:
		options = NetOptions.from_command_line()
	simulation = Simulation.new()
	simulation.name = "Simulation"
	add_child(simulation)

	var enet: EnetTransport = EnetTransport.new()
	var err: Error = OK
	if is_host():
		err = enet.host(options.port, SimConfig.MAX_PLAYERS - 1)
	else:
		err = enet.join(options.address, options.port)
	if err != OK:
		# Message actionnable, pas un code d'erreur : la cause la plus
		# fréquente est une instance déjà lancée sur le même port, et
		# l'écran doit le dire au lieu d'attendre indéfiniment.
		if is_host():
			failure_reason = "impossible d'ouvrir le port %d\nune autre instance l'utilise deja ?" \
				% options.port
		else:
			failure_reason = "connexion a %s:%d impossible" % [options.address, options.port]
		push_error(failure_reason)
		session_failed.emit(failure_reason)
		return

	# Toujours décoré, même sans latence ni perte : un seul chemin de code.
	transport = LatencyPipe.new(enet, options.latency_msec, options.loss, options.rng_seed)
	if not is_host():
		clock = NetClock.new()
		sync = WorldSync.new()
	_build_world()
	_started = true
	world_ready.emit(world)

func _build_world() -> void:
	world = World.new(self)
	world.authority = World.Authority.HOST if is_host() else World.Authority.CLIENT
	var level: LevelData = load(LEVEL_PATH)
	var player_data: PlayerData = load(PLAYER_PATH)
	var grunt: EnemyData = load(GRUNT_PATH)
	var warden: EnemyData = load(WARDEN_PATH)
	var enemies: Array[EnemyData] = [grunt, warden]
	world.configure(level, player_data, enemies)
	world.hit_declared.connect(_on_hit_declared)
	world.damage_reported.connect(_on_damage_reported)
	simulation.world = world
	if is_host():
		world.local_actor_id = SimConfig.HOST_PEER_ID
		world.spawn_player(SimConfig.HOST_PEER_ID, 0)
		world.spawn_enemies()

func _physics_process(_delta: float) -> void:
	if not _started:
		return
	transport.poll()
	var now_usec: int = Time.get_ticks_usec()
	_dispatch(transport.receive(), now_usec)

	if is_host():
		_reconcile_roster()
	else:
		_adopt_local_identity()
		_send_ping_if_due(now_usec)
		var target: int = clock.target_tick(now_usec)
		if target >= 0:
			simulation.set_target_tick(target)
		sync.apply(world, world.local_actor_id, history)
		sync.advance_render_tick()
		sync.integrate_remote(world)

	_log_if_due()
	simulation.advance()

	if is_host():
		_broadcast_snapshot_if_due()
	else:
		_record_prediction()

# ---------------------------------------------------------------------------
# Commandes
# ---------------------------------------------------------------------------

## Unique porte de sortie du gameplay vers la simulation et le réseau
## (invariant 3). La présentation ne connaît rien d'autre.
func submit_command(type: Command.Type, payload: Dictionary = {}) -> void:
	if not _started or world.local_actor_id == 0:
		return
	var command: Command = Command.new(simulation.current_tick + 1,
		world.local_actor_id, type, payload)
	simulation.buffer.push(command)
	if type == Command.Type.MOVE or type == Command.Type.DODGE:
		history.record_command(command)
	if is_host():
		return
	transport.send(SimConfig.HOST_PEER_ID, NetMessage.encode_command(command),
		Transport.Mode.RELIABLE)

func _on_hit_declared(target_id: int, attack_index: int) -> void:
	submit_command(Command.Type.DECLARE_HIT, {"t": target_id, "a": attack_index})

func _on_damage_reported(source_id: int, attack_index: int) -> void:
	submit_command(Command.Type.REPORT_DAMAGE, {"s": source_id, "a": attack_index})

# ---------------------------------------------------------------------------
# Réseau
# ---------------------------------------------------------------------------

func _dispatch(packets: Array[NetPacket], now_usec: int) -> void:
	for packet: NetPacket in packets:
		match NetMessage.kind_of(packet.payload):
			int(NetMessage.Kind.PING):
				_answer_ping(packet)
			int(NetMessage.Kind.PONG):
				_absorb_pong(packet, now_usec)
			int(NetMessage.Kind.COMMAND):
				_absorb_command(packet)
			int(NetMessage.Kind.SNAPSHOT):
				_absorb_snapshot(packet)

func _absorb_command(packet: NetPacket) -> void:
	var command: Command = NetMessage.decode_command(packet.payload)
	if command == null:
		return
	# Un pair ne commande que son propre personnage. Sans ce contrôle,
	# n'importe quel client pourrait piloter celui d'un autre.
	if is_host() and command.actor_id != packet.peer_id:
		return
	simulation.buffer.push(command)

func _absorb_snapshot(packet: NetPacket) -> void:
	if sync == null:
		return
	sync.receive(WorldSnapshot.from_bytes(packet.payload))

func _broadcast_snapshot_if_due() -> void:
	if simulation.current_tick % SNAPSHOT_INTERVAL_TICKS != 0:
		return
	var peers: PackedInt32Array = transport.peer_ids()
	if peers.is_empty():
		return
	var payload: PackedByteArray = WorldSnapshot.capture(world).to_bytes()
	for peer_id: int in peers:
		transport.send(peer_id, payload, Transport.Mode.UNRELIABLE)

## Fait correspondre la liste des joueurs à celle des pairs connectés.
func _reconcile_roster() -> void:
	var peers: PackedInt32Array = transport.peer_ids()
	for peer_id: int in peers:
		if _known_peers.find(peer_id) < 0:
			_known_peers.append(peer_id)
			world.spawn_player(peer_id, _known_peers.size())
	var index: int = _known_peers.size() - 1
	while index >= 0:
		var known: int = _known_peers[index]
		if peers.find(known) < 0:
			world.remove_actor(known)
			_known_peers.remove_at(index)
		index -= 1

## Le client ne connaît son identifiant qu'une fois la session établie ; c'est
## celui que l'hôte voit arriver sur ses paquets, donc celui de son personnage.
func _adopt_local_identity() -> void:
	if world.local_actor_id != 0 or not transport.is_session_live():
		return
	world.local_actor_id = transport.local_peer_id()

func _record_prediction() -> void:
	var actor: Actor = world.local_actor()
	if actor == null:
		return
	history.record_position(simulation.current_tick, actor.position)
	history.prune(simulation.current_tick)

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

## Journalise l'état d'horloge sur la sortie standard. Sans cela, une instance
## lancée en headless par tools/netharness.ps1 serait muette et le banc
## invérifiable autrement qu'en regardant deux fenêtres.
func _log_if_due() -> void:
	var interval: int = options.log_ticks_interval
	if interval <= 0 or simulation.current_tick % interval != 0:
		return
	var label: String = options.label if not options.label.is_empty() else "instance"
	var actors: int = world.actors.size() if world != null else 0
	if clock == null:
		print("[%s] tick=%d role=hote acteurs=%d pairs=%d"
			% [label, simulation.current_tick, actors, transport.peer_ids().size()])
	else:
		print("[%s] tick=%d role=client ecart=%d aller_retour_ms=%.1f acteurs=%d recalages=%d"
			% [label, simulation.current_tick, simulation.tick_error(),
				float(clock.last_rtt_usec) / 1000.0, actors, sync.resyncs])

func _exit_tree() -> void:
	if transport != null:
		transport.close()
