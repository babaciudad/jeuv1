## Transport décorateur qui simule latence et perte de paquets.
##
## Le retard est appliqué à la réception, pas à l'émission. Chaque machine
## ayant son propre tuyau, un aller-retour subit donc deux fois la latence
## configurée : --latency 120 signifie 120 ms dans chaque sens, soit 240 ms
## d'aller-retour. C'est la convention des simulateurs réseau usuels.
##
## Vit dans la couche transport, donc fonctionne en headless, sans droits
## administrateur et quel que soit le transport réel : c'est ce qui permet au
## test de convergence de s'exécuter dans tools/test.ps1.
class_name LatencyPipe
extends Transport

var _inner: Transport
var _latency_usec: int
var _loss: float
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## File d'attente, en deux tableaux parallèles plutôt qu'un tableau de paires :
## la latence étant constante, l'ordre d'arrivée est l'ordre de livraison.
var _queued: Array[NetPacket] = []
var _deliver_at_usec: PackedInt64Array = PackedInt64Array()

var _dropped: int = 0

var dropped: int:
	get:
		return _dropped

func _init(inner: Transport, latency_msec: int = 0, loss: float = 0.0, rng_seed: int = 0) -> void:
	_inner = inner
	_latency_usec = maxi(0, latency_msec) * 1000
	_loss = clampf(loss, 0.0, 1.0)
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

func poll() -> void:
	_inner.poll()
	var now: int = Time.get_ticks_usec()
	for packet: NetPacket in _inner.receive():
		if _loss > 0.0 and _rng.randf() < _loss:
			_dropped += 1
			continue
		_queued.append(packet)
		_deliver_at_usec.append(now + _latency_usec)

func send(peer_id: int, payload: PackedByteArray, mode: Mode = Mode.RELIABLE) -> Error:
	return _inner.send(peer_id, payload, mode)

func receive() -> Array[NetPacket]:
	var now: int = Time.get_ticks_usec()
	var due: Array[NetPacket] = []
	var due_count: int = 0
	for i: int in _queued.size():
		if _deliver_at_usec[i] > now:
			break
		due.append(_queued[i])
		due_count += 1
	if due_count > 0:
		_queued = _queued.slice(due_count)
		_deliver_at_usec = _deliver_at_usec.slice(due_count)
	return due

func peer_ids() -> PackedInt32Array:
	return _inner.peer_ids()

func local_peer_id() -> int:
	return _inner.local_peer_id()

func is_session_live() -> bool:
	return _inner.is_session_live()

func close() -> void:
	_inner.close()
	_queued.clear()
	_deliver_at_usec.clear()
