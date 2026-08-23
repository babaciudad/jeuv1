## Encodage des messages de la couche réseau.
##
## Un message est un octet de genre suivi d'un corps. Les commandes de gameplay
## voyagent dans le genre COMMAND et ne sont pas relues ici : leur format
## appartient à Command (invariant 3).
##
## Toutes les valeurs sont petit-boutistes.
class_name NetMessage
extends RefCounted

enum Kind {
	PING = 1,
	PONG = 2,
	COMMAND = 3,
}

const PING_SIZE: int = 13
const PONG_SIZE: int = 17

## Sonde d'horloge émise par un client.
class Ping extends RefCounted:
	## Numéro de séquence, pour le diagnostic uniquement.
	var seq: int = 0
	## Horodatage local de l'émission, en microsecondes.
	var send_usec: int = 0

## Réponse de l'hôte à une sonde, renvoyant l'horodatage tel quel pour que le
## client calcule son aller-retour sans horloge partagée.
class Pong extends RefCounted:
	var seq: int = 0
	var send_usec: int = 0
	## Tick que l'hôte simulait au moment de répondre.
	var host_tick: int = 0

static func kind_of(bytes: PackedByteArray) -> int:
	if bytes.is_empty():
		return 0
	return bytes.decode_u8(0)

static func encode_ping(seq: int, send_usec: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(PING_SIZE)
	out.encode_u8(0, int(Kind.PING))
	out.encode_u32(1, seq)
	out.encode_u64(5, send_usec)
	return out

static func decode_ping(bytes: PackedByteArray) -> Ping:
	if bytes.size() != PING_SIZE or bytes.decode_u8(0) != int(Kind.PING):
		return null
	var ping: Ping = Ping.new()
	ping.seq = bytes.decode_u32(1)
	ping.send_usec = bytes.decode_u64(5)
	return ping

static func encode_pong(seq: int, send_usec: int, host_tick: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(PONG_SIZE)
	out.encode_u8(0, int(Kind.PONG))
	out.encode_u32(1, seq)
	out.encode_u64(5, send_usec)
	out.encode_u32(13, host_tick)
	return out

static func decode_pong(bytes: PackedByteArray) -> Pong:
	if bytes.size() != PONG_SIZE or bytes.decode_u8(0) != int(Kind.PONG):
		return null
	var pong: Pong = Pong.new()
	pong.seq = bytes.decode_u32(1)
	pong.send_usec = bytes.decode_u64(5)
	pong.host_tick = bytes.decode_u32(13)
	return pong

static func encode_command(command: Command) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(1)
	out.encode_u8(0, int(Kind.COMMAND))
	out.append_array(command.to_bytes())
	return out

static func decode_command(bytes: PackedByteArray) -> Command:
	if bytes.size() < 1 or bytes.decode_u8(0) != int(Kind.COMMAND):
		return null
	return Command.from_bytes(bytes.slice(1))
