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

var _bootstrap: NetBootstrap
var _rig: CameraRig
var _last_direction: Vector2 = Vector2.ZERO
var _ticks_since_move: int = MOVE_RESEND_TICKS
var _pointer_captured: bool = false

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
		return
	if not _pointer_captured:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_capture_pointer(true)
		return
	if event is InputEventMouseMotion and _rig != null:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_rig.add_look(motion.relative, mouse_sensitivity)

func _physics_process(_delta: float) -> void:
	if _bootstrap == null or _rig == null:
		return
	var actor: Actor = _bootstrap.local_player()
	if actor == null:
		return
	_ticks_since_move += 1
	if not actor.is_alive():
		_send_direction(Vector2.ZERO, true)
		return

	var raw: Vector2 = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	var direction: Vector2 = _rig.planar_right() * raw.x + _rig.planar_forward() * raw.y
	if direction.length() > 1.0:
		direction = direction.normalized()
	_send_direction(direction, false)

	if Input.is_action_just_pressed("dodge"):
		var dodge: Vector2 = direction if direction.length() > 0.1 else actor.facing
		_bootstrap.submit_command(Command.Type.DODGE, {"d": dodge})
	if Input.is_action_just_pressed("attack"):
		# On frappe là où l'on va, ou à défaut là où l'on regarde. Sans cette
		# visée, un personnage à l'arrêt frapperait toujours dans la direction
		# de son dernier pas.
		var aim: Vector2 = direction if direction.length() > 0.1 else _rig.planar_forward()
		_bootstrap.submit_command(Command.Type.ATTACK, {"i": 0, "d": aim})
	if Input.is_action_just_pressed("interact"):
		_bootstrap.submit_command(Command.Type.INTERACT, {})

func _send_direction(direction: Vector2, force: bool) -> void:
	var changed: bool = direction.distance_to(_last_direction) > MOVE_EPSILON
	if not force and not changed and _ticks_since_move < MOVE_RESEND_TICKS:
		return
	if force and _last_direction.is_zero_approx() and not changed:
		return
	_last_direction = direction
	_ticks_since_move = 0
	_bootstrap.submit_command(Command.Type.MOVE, {"d": direction})
