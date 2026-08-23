## Application des instantanés côté client.
##
## Trois responsabilités, dans cet ordre à chaque tick :
##   1. adopter ce que l'hôte annonce et abandonner ce qu'il ne mentionne plus ;
##   2. interpoler les acteurs distants dans le passé, d'environ 100 ms
##      (invariant 4), pour qu'ils bougent sans à-coups entre deux instantanés ;
##   3. réconcilier le personnage local quand l'hôte contredit la prédiction.
##
## Le client ne recalcule jamais la vie, la poise ni la mort : il les recopie
## (invariant 6).
class_name WorldSync
extends RefCounted

## Profondeur du tampon d'instantanés.
const MAX_FRAMES: int = 48
## Retard de rendu des acteurs distants, en ticks. 6 ticks = 100 ms, soit
## SimConfig.INTERPOLATION_BUFFER_MSEC.
const INTERPOLATION_TICKS: int = 6
## Au-delà de cet écart, le temps de rendu est recalé d'un coup plutôt que
## rattrapé : c'est le cas à la connexion et après une coupure.
const RENDER_RESYNC_TICKS: float = 12.0
## Fraction de l'écart résorbée par tick quand le recalage est doux.
const RENDER_SMOOTHING: float = 0.12
## Écart de position, en mètres, en deçà duquel on laisse la prédiction
## tranquille. Corriger dans le bruit ferait vibrer le personnage.
const RECONCILE_EPSILON: float = 0.25
## Ancienneté maximale, en ticks, d'une attaque distante encore rattrapable.
## Au-delà, on renonce à la rejouer : ouvrir sa hitbox en retard produirait
## une touche fantôme.
const ATTACK_CATCHUP_LIMIT: int = 8

var _frames: Array[WorldSnapshot] = []
var _render_tick: float = -1.0
var _applied_tick: int = -1
var _resyncs: int = 0

var resyncs: int:
	get:
		return _resyncs

func receive(frame: WorldSnapshot) -> void:
	if frame == null:
		return
	# UDP peut livrer dans le désordre : un instantané plus vieux que le
	# dernier reçu n'apprend rien et fausserait l'interpolation.
	if not _frames.is_empty() and frame.tick <= _frames[_frames.size() - 1].tick:
		return
	_frames.append(frame)
	while _frames.size() > MAX_FRAMES:
		_frames.remove_at(0)

func has_frames() -> bool:
	return not _frames.is_empty()

func latest_tick() -> int:
	return _frames[_frames.size() - 1].tick if not _frames.is_empty() else -1

func render_tick() -> float:
	return _render_tick

# ---------------------------------------------------------------------------
# 1. Autorité
# ---------------------------------------------------------------------------

func apply(world: World, local_id: int, history: CommandHistory) -> void:
	if _frames.is_empty():
		return
	var frame: WorldSnapshot = _frames[_frames.size() - 1]
	if frame.tick == _applied_tick:
		return
	_applied_tick = frame.tick
	world.shortcut_open = frame.shortcut_open

	var present: PackedInt32Array = PackedInt32Array()
	for state: ActorState in frame.states:
		present.append(state.id)
		var actor: Actor = world.actor_or_null(state.id)
		if actor == null:
			actor = _adopt(world, state, local_id)
			if actor == null:
				continue
		if state.id == local_id:
			_apply_local(world, actor, state, frame.tick, history)
		else:
			_apply_remote(world, actor, state)

	for actor_id: int in world.actors.keys():
		if present.find(actor_id) < 0:
			world.remove_actor(actor_id)

	# Les projectiles annoncés qu'on ne connaît pas encore : on les adopte.
	# On ne retire jamais ceux que l'hôte ne mentionne plus — leur durée de vie
	# et leurs collisions les font expirer localement, et un instantané perdu
	# ne doit pas faire disparaître un tir en plein vol.
	for flight: Projectile in frame.flights:
		if not world.projectiles.has(flight.id):
			world.projectiles[flight.id] = flight

func _adopt(world: World, state: ActorState, local_id: int) -> Actor:
	var actor: Actor = null
	if state.kind == int(Actor.Kind.PLAYER):
		actor = world.spawn_player(state.id, 0, state.data_index)
	else:
		actor = world.adopt_enemy(state.id, state.data_index, state.position)
	if actor == null:
		return null
	actor.position = state.position
	actor.facing = state.facing
	actor.simulated = state.id == local_id
	return actor

func _apply_remote(world: World, actor: Actor, state: ActorState) -> void:
	actor.health = state.health
	actor.poise = state.poise
	actor.velocity = state.velocity
	if actor.kind == Actor.Kind.PLAYER and actor.data_index != state.data_index:
		world.apply_class(actor, state.data_index)
	var remote_state: Actor.State = state.state as Actor.State
	if actor.state != remote_state:
		actor.state = remote_state
		actor.state_entered_tick = state.state_entered_tick
		if actor.state != Actor.State.ATTACKING and actor.runner != null \
				and not actor.runner.finished:
			actor.runner.interrupt()
	_sync_attack(world, actor, state)

## Rejoue localement le calendrier d'une attaque distante. C'est ce qui permet
## à la victime de savoir quand la hitbox de l'ennemi s'ouvre, donc de déclarer
## les dégâts qu'elle encaisse (invariant 5), sans que le client ait pour
## autant le moindre mot à dire sur le comportement de l'ennemi.
func _sync_attack(world: World, actor: Actor, state: ActorState) -> void:
	if actor.runner == null or state.attack_index < 0:
		return
	var already_running: bool = not actor.runner.finished \
		and actor.attack_index == state.attack_index
	if already_running:
		return
	if state.attack_elapsed > ATTACK_CATCHUP_LIMIT:
		return
	var attacks: Array[AttackData] = world.attacks_for(actor)
	if state.attack_index >= attacks.size():
		return
	if not actor.runner.start(attacks[state.attack_index]):
		return
	actor.attack_index = state.attack_index
	for _i: int in state.attack_elapsed:
		actor.runner.advance_tick()

func _apply_local(world: World, actor: Actor, state: ActorState, frame_tick: int,
		history: CommandHistory) -> void:
	# Vie, poise, mort et chancellement viennent de l'hôte, toujours.
	actor.health = state.health
	actor.poise = state.poise
	var authoritative: Actor.State = state.state as Actor.State
	var reactive: bool = authoritative == Actor.State.DEAD \
		or authoritative == Actor.State.STAGGERED
	if reactive and actor.state != authoritative:
		if actor.runner != null:
			actor.runner.interrupt()
		actor.attack_index = -1
		actor.velocity = Vector2.ZERO
		actor.enter_state(authoritative, world.tick)
	elif not reactive and (actor.state == Actor.State.DEAD
			or actor.state == Actor.State.STAGGERED):
		actor.enter_state(Actor.State.IDLE, world.tick)

	if not history.has_position(frame_tick):
		# Rien de prédit pour ce tick : on prend ce que dit l'hôte.
		actor.position = state.position
		actor.velocity = state.velocity
		return
	if history.position_at(frame_tick).distance_to(state.position) <= RECONCILE_EPSILON:
		return
	_resyncs += 1
	actor.position = state.position
	actor.velocity = state.velocity
	actor.stamina_centi = state.stamina_points * Actor.CENTI
	world.replay_local(actor, history, frame_tick + 1, world.tick)

# ---------------------------------------------------------------------------
# 2. Interpolation
# ---------------------------------------------------------------------------

func advance_render_tick() -> void:
	if _frames.is_empty():
		return
	var target: float = float(latest_tick() - INTERPOLATION_TICKS)
	if _render_tick < 0.0 or absf(target - _render_tick) > RENDER_RESYNC_TICKS:
		_render_tick = target
		return
	_render_tick += 1.0
	_render_tick = lerpf(_render_tick, target, RENDER_SMOOTHING)

func integrate_remote(world: World) -> void:
	if _frames.is_empty() or _render_tick < 0.0:
		return
	var older: WorldSnapshot = _frames[0]
	var newer: WorldSnapshot = _frames[_frames.size() - 1]
	for index: int in _frames.size():
		var frame: WorldSnapshot = _frames[index]
		if float(frame.tick) <= _render_tick:
			older = frame
			newer = _frames[mini(index + 1, _frames.size() - 1)]
	var span: float = float(newer.tick - older.tick)
	var ratio: float = 0.0 if span <= 0.0 else clampf((_render_tick - float(older.tick)) / span, 0.0, 1.0)

	for actor: Actor in world.actors.values():
		if actor.simulated:
			continue
		var from_state: ActorState = older.state_for(actor.id)
		var to_state: ActorState = newer.state_for(actor.id)
		if from_state == null and to_state == null:
			continue
		if from_state == null:
			actor.position = to_state.position
			actor.facing = to_state.facing
			continue
		if to_state == null:
			actor.position = from_state.position
			actor.facing = from_state.facing
			continue
		actor.position = from_state.position.lerp(to_state.position, ratio)
		actor.facing = from_state.facing.slerp(to_state.facing, ratio)
