## Commande de gameplay sérialisable.
##
## Invariant 3 : toute action de gameplay est une commande {tick, acteur_id,
## type, charge utile} appliquée par la simulation. Aucune entité n'appelle
## directement une méthode d'une autre entité.
##
## Format binaire, petit-boutiste :
##   offset 0  : u32  tick
##   offset 4  : u32  actor_id
##   offset 8  : u8   type
##   offset 9  : u32  taille de la charge utile
##   offset 13 : charge utile encodée par var_to_bytes (objets interdits)
class_name Command
extends RefCounted

## Type de commande. Ces valeurs partent sur le réseau : on ne les réordonne
## jamais, on ne les recycle jamais, on ne fait qu'en ajouter à la fin.
##
## Les charges utiles portent des identifiants et des directions, jamais des
## résultats. Une déclaration de touche dit « j'ai touché cet acteur avec cette
## attaque », pas « inflige tant de dégâts » : l'hôte relit ses propres données
## et un client ne peut donc rien gonfler (invariant 5).
enum Type {
	NONE = 0,
	## {"d": Vector2} direction de déplacement souhaitée.
	MOVE = 1,
	## {"d": Vector2} direction de la roulade.
	DODGE = 2,
	## {"i": int, "d": Vector2} index de l'attaque et direction visée. La
	## visée vient de la présentation parce qu'elle dépend de la caméra, que
	## la simulation n'a pas le droit de connaître (invariant 2).
	ATTACK = 3,
	## {} interaction avec ce qui est à portée : feu de camp ou raccourci.
	INTERACT = 4,
	## {"t": int, "a": int} cible touchée et index de l'attaque. Émise par
	## l'attaquant, confirmée par l'hôte.
	DECLARE_HIT = 5,
	## {"s": int, "a": int} source des dégâts et index de son attaque. Émise
	## par la victime, contrôlée par l'hôte.
	REPORT_DAMAGE = 6,
	## {"t": int, "a": int} allié soigné et index de l'attaque. Émise par le
	## soigneur, confirmée par l'hôte. Contrairement aux dégâts reçus, un soin
	## n'a pas besoin d'être instantané pour rester juste : cent millisecondes
	## de retard sur un soin ne tuent personne, alors qu'un coup encaissé
	## après une esquive réussie, si.
	DECLARE_HEAL = 7,
	## {"c": int} classe choisie par le joueur. Envoyée à la connexion.
	SELECT_CLASS = 8,
}

const HEADER_SIZE: int = 13
const OFFSET_TICK: int = 0
const OFFSET_ACTOR: int = 4
const OFFSET_TYPE: int = 8
const OFFSET_PAYLOAD_SIZE: int = 9

## Tick auquel la commande doit être appliquée par la simulation.
var tick: int
## Identifiant de l'acteur qui émet la commande (peer id du joueur).
var actor_id: int
var type: Type
var payload: Dictionary

func _init(p_tick: int = 0, p_actor_id: int = 0, p_type: Type = Type.NONE, p_payload: Dictionary = {}) -> void:
	tick = p_tick
	actor_id = p_actor_id
	type = p_type
	payload = p_payload

## Sérialise la commande. Retourne un tableau vide si la commande est
## invalide : un tick négatif n'a pas de représentation sur le fil.
func to_bytes() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	if tick < 0 or actor_id < 0:
		push_error("Command.to_bytes : tick et actor_id doivent être positifs")
		return out
	var payload_bytes: PackedByteArray = var_to_bytes(payload)
	out.resize(HEADER_SIZE)
	out.encode_u32(OFFSET_TICK, tick)
	out.encode_u32(OFFSET_ACTOR, actor_id)
	out.encode_u8(OFFSET_TYPE, int(type))
	out.encode_u32(OFFSET_PAYLOAD_SIZE, payload_bytes.size())
	out.append_array(payload_bytes)
	return out

## Désérialise une commande. Retourne null si les octets sont malformés :
## un pair distant peut envoyer n'importe quoi, y compris volontairement.
static func from_bytes(bytes: PackedByteArray) -> Command:
	if bytes.size() < HEADER_SIZE:
		return null
	var payload_size: int = bytes.decode_u32(OFFSET_PAYLOAD_SIZE)
	if bytes.size() != HEADER_SIZE + payload_size:
		return null
	var decoded: Variant = bytes_to_var(bytes.slice(HEADER_SIZE))
	if typeof(decoded) != TYPE_DICTIONARY:
		return null
	var payload_dict: Dictionary = decoded
	var raw_type: int = bytes.decode_u8(OFFSET_TYPE)
	if not Type.values().has(raw_type):
		return null
	var command: Command = Command.new()
	command.tick = bytes.decode_u32(OFFSET_TICK)
	command.actor_id = bytes.decode_u32(OFFSET_ACTOR)
	command.type = raw_type as Type
	command.payload = payload_dict
	return command

func _to_string() -> String:
	return "Command(tick=%d, actor=%d, type=%d, payload=%s)" % [tick, actor_id, int(type), payload]
