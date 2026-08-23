## File des commandes en attente d'application, classées par tick.
##
## Une commande arrivée après le tick auquel elle devait s'appliquer est
## abandonnée, jamais appliquée en retard : l'appliquer décalerait la
## simulation locale par rapport à celle de l'hôte. Les abandons sont
## comptés, car un compteur qui monte est le symptôme d'une avance client
## insuffisante (voir SimConfig.CLIENT_LEAD_SAFETY_TICKS).
class_name CommandBuffer
extends RefCounted

var _pending: Array[Command] = []
var _dropped_late: int = 0

## Nombre de commandes arrivées trop tard depuis la création du tampon.
var dropped_late: int:
	get:
		return _dropped_late

func push(command: Command) -> void:
	_pending.append(command)

## Retire et retourne les commandes dues à ce tick. Purge au passage celles
## dont le tick est déjà dépassé.
func take(tick: int) -> Array[Command]:
	var due: Array[Command] = []
	var kept: Array[Command] = []
	for command: Command in _pending:
		if command.tick == tick:
			due.append(command)
		elif command.tick > tick:
			kept.append(command)
		else:
			_dropped_late += 1
	_pending = kept
	return due

func size() -> int:
	return _pending.size()

func clear() -> void:
	_pending.clear()
