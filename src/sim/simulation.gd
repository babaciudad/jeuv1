## Boucle de simulation à pas fixe.
##
## Invariant 1 : un tick est un entier partagé par toutes les machines ; tout
## événement de gameplay est daté en ticks. La simulation n'a aucune notion de
## secondes ni de delta.
##
## Invariant 2 : ce nœud ne lit jamais l'entrée, ne touche jamais la caméra,
## l'UI ni un nœud visuel. Il n'expose que des signaux, que la présentation
## consomme dans un sens unique.
##
## La simulation n'appelle pas _physics_process elle-même : c'est l'hôte de la
## boucle (NetBootstrap) qui l'avance, pour que l'ordre poll réseau puis pas de
## simulation soit explicite et non dépendant de l'ordre des nœuds.
class_name Simulation
extends Node

## Émis une fois par tick simulé, après application des commandes du tick.
signal tick_advanced(tick: int)
## Émis pour chaque commande appliquée. Le gameplay s'y branchera.
signal command_applied(command: Command)
## Émis quand le compteur de tick a été resynchronisé d'autorité.
signal tick_snapped(from_tick: int, to_tick: int)

## Écart, en ticks, en deçà duquel on ne corrige pas. Corriger dans le bruit
## ferait osciller le compteur en permanence.
const DEAD_ZONE_TICKS: int = 1
## Au-delà de cet écart, rattraper d'un tick par image prendrait trop
## longtemps : on resynchronise d'un coup. C'est le cas à la connexion.
const SNAP_THRESHOLD_TICKS: int = 12

var current_tick: int = 0
## Monde simule. Nul tant qu'aucun n'a ete installe : le noyau reste
## utilisable sans gameplay, ce qui garde ses tests independants.
var world: World = null
var _buffer: CommandBuffer = CommandBuffer.new()
## Tick visé, fourni par NetClock sur un client. -1 sur l'hôte, qui fait
## autorité sur son propre temps et ne se corrige jamais.
var _target_tick: int = -1

var buffer: CommandBuffer:
	get:
		return _buffer

## Fixe le tick que cette machine devrait être en train de simuler.
## Appelé par NetClock à chaque image physique sur un client.
func set_target_tick(target: int) -> void:
	_target_tick = target

## Abandonne toute cible : la machine redevient maîtresse de son temps.
func clear_target_tick() -> void:
	_target_tick = -1

## Écart courant entre la cible et le tick simulé. 0 si aucune cible.
func tick_error() -> int:
	if _target_tick < 0:
		return 0
	return _target_tick - current_tick

## Avance la simulation d'une image physique, soit 0, 1 ou 2 ticks selon la
## correction d'horloge en cours.
func advance() -> void:
	if _target_tick >= 0:
		var error: int = _target_tick - current_tick
		if absi(error) > SNAP_THRESHOLD_TICKS:
			var previous: int = current_tick
			current_tick = _target_tick
			tick_snapped.emit(previous, current_tick)
			_step(current_tick)
			return
	for _i: int in _steps_for_this_frame():
		current_tick += 1
		_step(current_tick)

## Nombre de ticks à simuler pendant cette image physique.
## En retard : on en simule deux pour rattraper. En avance : on en saute un.
func _steps_for_this_frame() -> int:
	if _target_tick < 0:
		return 1
	var error: int = _target_tick - current_tick
	if error > DEAD_ZONE_TICKS:
		return 2
	if error < -DEAD_ZONE_TICKS:
		return 0
	return 1

func _step(tick: int) -> void:
	var commands: Array[Command] = _buffer.take(tick)
	if world != null:
		world.step(tick, commands)
	else:
		for command: Command in commands:
			command_applied.emit(command)
	tick_advanced.emit(tick)
