## Estimation, côté client, du tick que cette machine doit simuler.
##
## Le client ne partage pas le compteur de l'hôte : il le devance. Deux raisons
## cumulées, chacune valant un aller simple de latence — l'hôte a avancé depuis
## qu'il a répondu, et une commande émise maintenant mettra encore un aller à
## lui parvenir. Le client vise donc l'hôte plus un aller-retour complet, plus
## une marge de sécurité.
##
## Le tick visé est ancré sur l'horloge murale, jamais sur notre propre
## compteur : sinon corriger le compteur déplacerait la cible d'autant et
## l'écart ne se résorberait jamais.
##
## Les échantillons sont agrégés par la médiane et non par la moyenne. Un pic
## de latence isolé produit un échantillon aberrant ; la moyenne le propage,
## la médiane l'ignore.
class_name NetClock
extends RefCounted

## Nombre d'échantillons conservés. À une sonde tous les 10 ticks, cela
## représente environ 1,3 seconde d'historique.
const SAMPLE_COUNT: int = 8

var _anchor_target: PackedInt64Array = PackedInt64Array()
var _anchor_usec: PackedInt64Array = PackedInt64Array()
var _last_rtt_usec: int = 0

## Dernier aller-retour mesuré, en microsecondes. Diagnostic uniquement.
var last_rtt_usec: int:
	get:
		return _last_rtt_usec

func on_pong(pong: NetMessage.Pong, now_usec: int) -> void:
	var rtt_usec: int = now_usec - pong.send_usec
	if rtt_usec < 0:
		return
	_last_rtt_usec = rtt_usec
	var target_now: int = pong.host_tick \
		+ SimConfig.usec_to_ticks(rtt_usec) \
		+ SimConfig.CLIENT_LEAD_SAFETY_TICKS
	_anchor_target.append(target_now)
	_anchor_usec.append(now_usec)
	if _anchor_target.size() > SAMPLE_COUNT:
		_anchor_target.remove_at(0)
		_anchor_usec.remove_at(0)

func has_estimate() -> bool:
	return not _anchor_target.is_empty()

## Tick que le client devrait simuler à cet instant, ou -1 si aucune sonde
## n'a encore abouti.
func target_tick(now_usec: int) -> int:
	if _anchor_target.is_empty():
		return -1
	var projections: PackedInt64Array = PackedInt64Array()
	for i: int in _anchor_target.size():
		var elapsed: int = SimConfig.usec_to_elapsed_ticks(now_usec - _anchor_usec[i])
		projections.append(_anchor_target[i] + elapsed)
	projections.sort()
	return projections[projections.size() >> 1]

func reset() -> void:
	_anchor_target.clear()
	_anchor_usec.clear()
	_last_rtt_usec = 0
