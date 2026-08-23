## Interface de transport.
##
## Invariant 9 : la couche gameplay ignore quel transport est actif. ENet en
## développement local, SteamMultiplayerPeer en production, et LatencyPipe en
## test : tous se présentent sous ce type et sous aucun autre.
##
## Classe de base concrète plutôt qu'abstraite : les implémentations vides
## rendent tout appel sûr, y compris sur un transport non configuré.
class_name Transport
extends RefCounted

enum Mode {
	## Livraison garantie et ordonnée. Pour les commandes de gameplay.
	RELIABLE,
	## Sans garantie. Pour ce qui est daté et se périme, comme la synchro
	## d'horloge : retransmettre un ping vieux de 200 ms n'a aucun intérêt.
	UNRELIABLE,
}

## Fait avancer le transport : lit les sockets et empile ce qui est arrivé.
func poll() -> void:
	pass

func send(_peer_id: int, _payload: PackedByteArray, _mode: Mode = Mode.RELIABLE) -> Error:
	return ERR_UNCONFIGURED

## Retire et retourne tout ce qui est arrivé depuis le dernier appel.
func receive() -> Array[NetPacket]:
	return []

## Identifiants des pairs connus, hors soi-même.
func peer_ids() -> PackedInt32Array:
	return PackedInt32Array()

## Identifiant de cette machine. SimConfig.HOST_PEER_ID sur l'hôte.
func local_peer_id() -> int:
	return 0

func is_session_live() -> bool:
	return false

func close() -> void:
	pass
