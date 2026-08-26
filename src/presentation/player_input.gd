## Lecture de l'entrée et traduction en commandes.
##
## Invariant 2 : c'est le SEUL endroit du projet qui a le droit de connaître le
## clavier et la souris. La simulation ne saura jamais qu'ils existent.
##
## Invariant 3 : rien ne sort d'ici qu'une commande sérialisable. Aucun appel
## direct à un acteur, aucune écriture dans le monde.
class_name PlayerInput
extends Node

@export var bootstrap_path: NodePath
@export var camera_rig_path: NodePath
@export var mouse_sensitivity: float = 0.0032

## Une direction de déplacement n'est renvoyée que si elle a changé, ou après
## ce délai. À 60 commandes par seconde on saturerait le lien pour répéter la
## même chose : l'intention persiste côté simulation jusqu'à contrordre.
const MOVE_RESEND_TICKS: int = 10
const MOVE_EPSILON: float = 0.08
## Portée du verrouillage côté présentation, en mètres. Volontairement un peu
## plus courte que celle de la simulation : on ne veut pas accrocher une cible
## que le monde relâchera au tick suivant.
const LOCK_REACH: float = 22.0

var _bootstrap: NetBootstrap
var _rig: CameraRig
var _last_direction: Vector2 = Vector2.ZERO
var _ticks_since_move: int = MOVE_RESEND_TICKS
var _pointer_captured: bool = false
## Appuis vus depuis le dernier tick simulé.
##
## `Input.is_action_just_pressed()` ne peut PAS servir ici. Elle répond « oui »
## pendant toute l'image de rendu courante : quand le moteur rattrape et
## execute deux pas physiques dans la même image, un seul clic part DEUX fois ;
## quand l'écran va plus vite que les 60 Hz de la simulation, un clic donné
## entre deux pas n'est jamais vu du tout. C'est-à-dire, du point de vue du
## joueur : des coups qui doublent, et des coups qui ne sortent pas.
##
## On note donc l'appui dans `_unhandled_input`, qui voit chaque événement une
## fois et une seule, et on le consomme au tick suivant.
var _pending: Dictionary[StringName, bool] = {}

func _ready() -> void:
	var node: Node = get_node_or_null(bootstrap_path)
	if node is NetBootstrap:
		_bootstrap = node as NetBootstrap
	var rig: Node = get_node_or_null(camera_rig_path)
	if rig is CameraRig:
		_rig = rig as CameraRig
	_capture_pointer(true)

func _capture_pointer(captured: bool) -> void:
	_pointer_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		_capture_pointer(false)
		_pending.clear()
		return
	if not _pointer_captured:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_capture_pointer(true)
			# Le clic qui reprend la main n'est PAS une attaque.
			_pending.clear()
		return
	if event is InputEventMouseMotion and _rig != null:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_rig.add_look(motion.relative, mouse_sensitivity)
		return
	for action: StringName in [&"dodge", &"attack", &"attack_secondary",
			&"interact", &"lock"]:
		if event.is_action_pressed(action, false, true):
			_pending[action] = true

## Vrai une seule fois par appui, quel que soit le nombre de pas physiques
## joués dans l'image.
func _took(action: StringName) -> bool:
	if not _pending.get(action, false):
		return false
	_pending[action] = false
	return true

func _physics_process(_delta: float) -> void:
	if _bootstrap == null or _rig == null:
		return
	var actor: Actor = _bootstrap.local_player()
	if actor == null:
		return
	_ticks_since_move += 1
	if not actor.is_alive():
		_send_direction(Vector2.ZERO, true)
		_pending.clear()
		return

	var raw: Vector2 = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var direction: Vector2 = _rig.planar_right() * raw.x + _rig.planar_forward() * raw.y
	if direction.length() > 1.0:
		direction = direction.normalized()
	_send_direction(direction, false)

	if _took(&"lock"):
		_toggle_lock(actor)
	if _took(&"dodge"):
		# On envoie la direction TELLE QUELLE, vide comprise. Elle était
		# remplacée par `actor.facing` quand le joueur ne poussait rien, ce qui
		# transformait toute esquive sur place en roulade avant — et rendait le
		# pas d'esquive arrière impossible à déclencher.
		_bootstrap.submit_command(Command.Type.DODGE, {"d": direction})
	# On frappe là où l'on va, ou à défaut là où l'on regarde. Sans cette visée,
	# un personnage à l'arrêt frapperait toujours dans la direction de son
	# dernier pas.
	var aim: Vector2 = direction if direction.length() > 0.1 else _rig.planar_forward()
	if _took(&"attack"):
		_bootstrap.submit_command(Command.Type.ATTACK, {"i": 0, "d": aim})
	if _took(&"attack_secondary"):
		_bootstrap.submit_command(Command.Type.ATTACK, {"i": 1, "d": aim})
	if _took(&"interact"):
		_bootstrap.submit_command(Command.Type.INTERACT, {})

## Verrouille sur l'adversaire le plus proche du centre de l'écran, ou relâche
## si l'on est déjà verrouillé.
##
## LE CHOIX DE LA CIBLE APPARTIENT À LA PRÉSENTATION, exactement comme la visée
## d'une attaque : « celui que je regarde » ne veut rien dire sans caméra, et
## la simulation n'a pas le droit d'en avoir une (invariant 2). Elle se
## contente de vérifier que la cible existe, qu'elle est vivante, qu'elle est
## d'un autre camp et qu'elle est à portée.
func _toggle_lock(actor: Actor) -> void:
	if actor.lock_target_id != 0:
		_bootstrap.submit_command(Command.Type.LOCK, {"t": 0})
		return
	var world: World = _bootstrap.world
	if world == null:
		return
	var forward: Vector2 = _rig.planar_forward()
	var best: int = 0
	var best_score: float = -1.0
	for other: Actor in world.actors.values():
		if other.id == actor.id or other.kind == actor.kind:
			continue
		if not other.is_alive():
			continue
		var toward: Vector2 = other.position - actor.position
		var distance: float = toward.length()
		if distance < 0.5 or distance > LOCK_REACH:
			continue
		# On classe par ANGLE d'abord, distance ensuite : verrouiller sur
		# l'ennemi le plus proche alors qu'on en regarde un autre est le
		# défaut le plus agaçant du genre.
		var alignment: float = forward.dot(toward / distance)
		if alignment < 0.15:
			continue
		var score: float = alignment - distance * 0.012
		if score > best_score:
			best_score = score
			best = other.id
	if best != 0:
		_bootstrap.submit_command(Command.Type.LOCK, {"t": best})

func _send_direction(direction: Vector2, force: bool) -> void:
	var changed: bool = direction.distance_to(_last_direction) > MOVE_EPSILON
	if not force and not changed and _ticks_since_move < MOVE_RESEND_TICKS:
		return
	if force and _last_direction.is_zero_approx() and not changed:
		return
	_last_direction = direction
	_ticks_since_move = 0
	_bootstrap.submit_command(Command.Type.MOVE, {"d": direction})
