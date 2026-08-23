## Paquet réseau reçu, accompagné de l'identifiant du pair émetteur.
##
## Type volontairement anémique : le transport ne sait rien du contenu, il ne
## fait que transporter des octets (invariant 9).
class_name NetPacket
extends RefCounted

var peer_id: int
var payload: PackedByteArray

func _init(p_peer_id: int = 0, p_payload: PackedByteArray = PackedByteArray()) -> void:
	peer_id = p_peer_id
	payload = p_payload
