## Déroule le calendrier d'une attaque.
##
## Invariant 8 : la hitbox s'ouvre et se ferme exclusivement par des pistes
## d'appel de méthode dans un AnimationPlayer. Aucun minuteur parallèle, aucun
## compteur de ticks maison — s'il y en avait un, il finirait par diverger de
## l'animation et personne ne saurait pourquoi.
##
## L'AnimationPlayer est en mode MANUEL : ce n'est pas le moteur qui l'avance,
## c'est la simulation, d'exactement un tick à la fois. Les appels de méthode
## sont IMMÉDIATS et non différés, sinon ils tomberaient au mauvais tick.
##
## Nœud, et non RefCounted : un AnimationMixer doit être dans l'arbre pour
## résoudre ses pistes. Il n'a rien de visuel pour autant — pas de maillage,
## pas de matériau, seulement un calendrier.
class_name AttackRunner
extends Node

const LIBRARY_NAME: StringName = &""
const ANIMATION_NAME: StringName = &"attack"

var _player: AnimationPlayer
var _attack: AttackData
var _hitbox_open: bool = false
var _can_cancel: bool = false
var _finished: bool = true
var _elapsed_ticks: int = 0
## Cibles déjà touchées par l'activation en cours : une attaque ne touche
## jamais deux fois le même adversaire, même si la hitbox reste ouverte.
var _already_hit: PackedInt32Array = PackedInt32Array()

var attack: AttackData:
	get:
		return _attack

var hitbox_open: bool:
	get:
		return _hitbox_open

var can_cancel: bool:
	get:
		return _can_cancel

var finished: bool:
	get:
		return _finished

var elapsed_ticks: int:
	get:
		return _elapsed_ticks

func _ready() -> void:
	_player = AnimationPlayer.new()
	_player.name = "Timeline"
	add_child(_player)
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	# Les pistes de méthode visent NodePath(".") relatif à root_node, donc ce
	# nœud-ci : c'est lui qui porte open_hitbox() et les autres.
	_player.root_node = NodePath("..")

func start(attack_data: AttackData) -> bool:
	if attack_data == null or attack_data.timeline == null:
		push_error("AttackRunner.start : attaque sans calendrier")
		return false
	var library: AnimationLibrary = AnimationLibrary.new()
	var error: Error = library.add_animation(ANIMATION_NAME, attack_data.timeline)
	if error != OK:
		push_error("AttackRunner.start : calendrier illisible (%d)" % error)
		return false
	if _player.has_animation_library(LIBRARY_NAME):
		_player.remove_animation_library(LIBRARY_NAME)
	error = _player.add_animation_library(LIBRARY_NAME, library)
	if error != OK:
		push_error("AttackRunner.start : bibliotheque refusee (%d)" % error)
		return false

	_attack = attack_data
	_hitbox_open = false
	_can_cancel = false
	_finished = false
	_elapsed_ticks = 0
	_already_hit.clear()
	_player.play(ANIMATION_NAME)
	return true

## Avance le calendrier d'un tick. Les pistes de méthode déclenchent au passage.
func advance_tick() -> void:
	if _finished:
		return
	_elapsed_ticks += 1
	_player.advance(SimConfig.TICK_DURATION_SEC)
	# Un calendrier sans piste finish() explicite se termine avec l'animation.
	if not _player.is_playing():
		_finished = true
		_hitbox_open = false

func interrupt() -> void:
	_player.stop()
	_hitbox_open = false
	_can_cancel = false
	_finished = true

## Vrai si cette cible n'a pas encore été touchée par l'activation en cours.
## L'enregistre au passage.
func try_register_hit(target_id: int) -> bool:
	if _already_hit.has(target_id):
		return false
	_already_hit.append(target_id)
	return true

# --- Pistes d'appel de méthode. Appelées par l'AnimationPlayer, jamais
# --- directement par du code de gameplay.

func open_hitbox() -> void:
	_hitbox_open = true
	_already_hit.clear()

func close_hitbox() -> void:
	_hitbox_open = false

func allow_cancel() -> void:
	_can_cancel = true

func finish() -> void:
	_hitbox_open = false
	_finished = true
