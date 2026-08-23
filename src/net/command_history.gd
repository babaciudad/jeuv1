## Mémoire des commandes émises localement et des positions prédites.
##
## Sert à la réconciliation : quand l'hôte contredit la prédiction au tick T,
## il faut savoir ce qu'on avait joué depuis, pour le rejouer.
##
## Les ticks du client et de l'hôte partagent la même numérotation. C'est tout
## l'intérêt de l'avance du client (voir NetClock) : sa commande pour le tick T
## arrive avant que l'hôte ne simule T, et l'hôte l'applique bien au tick T.
class_name CommandHistory
extends RefCounted

## Profondeur conservée, en ticks. Doit couvrir deux allers-retours plus une
## marge : un instantané du tick T revient au client vers T + 2 x avance.
const DEPTH_TICKS: int = 120

var _commands: Dictionary[int, Array] = {}
var _positions: Dictionary[int, Vector2] = {}

func record_command(command: Command) -> void:
	if not _commands.has(command.tick):
		_commands[command.tick] = []
	var bucket: Array = _commands[command.tick]
	bucket.append(command)

func record_position(tick: int, position: Vector2) -> void:
	_positions[tick] = position

func commands_at(tick: int) -> Array[Command]:
	var out: Array[Command] = []
	if not _commands.has(tick):
		return out
	var bucket: Array = _commands[tick]
	for entry: Variant in bucket:
		if entry is Command:
			out.append(entry)
	return out

func has_position(tick: int) -> bool:
	return _positions.has(tick)

func position_at(tick: int) -> Vector2:
	return _positions.get(tick, Vector2.ZERO)

## Oublie tout ce qui est plus vieux que la profondeur retenue.
func prune(current_tick: int) -> void:
	var horizon: int = current_tick - DEPTH_TICKS
	for tick: int in _commands.keys():
		if tick < horizon:
			_commands.erase(tick)
	for tick: int in _positions.keys():
		if tick < horizon:
			_positions.erase(tick)

func clear() -> void:
	_commands.clear()
	_positions.clear()
