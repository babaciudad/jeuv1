## Instantané d'état du monde, de l'hôte vers les clients.
##
## Invariant 4 : synchronisation d'état, pas de lockstep. L'hôte envoie ce
## qu'il croit vrai ; les clients s'y conforment pour tout ce qu'ils n'ont pas
## le droit de prédire (vie, poise, mort, progression) et corrigent le reste.
##
## Format binaire, petit-boutiste. En-tête de 7 octets puis 44 octets par
## acteur :
##    0  u32 identifiant
##    4  u8  nature (joueur ou ennemi)
##    5  u8  état
##    6  u32 tick d'entrée dans l'état
##   10  f32 position x, z
##   18  f32 vitesse x, z
##   26  f32 orientation x, z
##   34  u16 vie
##   36  u16 poise
##   38  u16 endurance, en points
##   40  s8  index d'attaque, -1 si aucune
##   41  u16 ticks écoulés dans l'attaque
##   43  s8  index de fiche : classe pour un joueur, espèce pour un ennemi
##
## Puis un octet de comptage et 25 octets par projectile en vol :
##    0  u32 tireur
##    4  u32 tick de départ
##    8  s8  index d'attaque
##    9  f32 origine x, z
##   17  f32 direction x, z
##
## Un projectile ne transporte pas sa position : elle se recalcule. Deux
## machines qui connaissent l'origine et le tick de départ obtiennent la même
## trajectoire, il n'y a donc rien à synchroniser après le tir.
class_name WorldSnapshot
extends RefCounted

const HEADER_SIZE: int = 7
const ACTOR_SIZE: int = 44
const PROJECTILE_SIZE: int = 25
const MAX_ACTORS: int = 255
const MAX_PROJECTILES: int = 255

var tick: int = 0
var shortcut_open: bool = false
var states: Array[ActorState] = []
var flights: Array[Projectile] = []

static func capture(world: World) -> WorldSnapshot:
	var snapshot: WorldSnapshot = WorldSnapshot.new()
	snapshot.tick = world.tick
	snapshot.shortcut_open = world.shortcut_open
	for actor: Actor in world.actors.values():
		snapshot.states.append(ActorState.from_actor(actor))
	for projectile: Projectile in world.projectiles.values():
		snapshot.flights.append(projectile)
	return snapshot

func to_bytes() -> PackedByteArray:
	var count: int = mini(states.size(), MAX_ACTORS)
	var flight_count: int = mini(flights.size(), MAX_PROJECTILES)
	var flights_at: int = HEADER_SIZE + count * ACTOR_SIZE
	var out: PackedByteArray = PackedByteArray()
	out.resize(flights_at + 1 + flight_count * PROJECTILE_SIZE)
	out.encode_u8(0, int(NetMessage.Kind.SNAPSHOT))
	out.encode_u32(1, maxi(0, tick))
	out.encode_u8(5, 1 if shortcut_open else 0)
	out.encode_u8(6, count)
	for index: int in count:
		WorldSnapshot._encode_actor(out, HEADER_SIZE + index * ACTOR_SIZE, states[index])
	out.encode_u8(flights_at, flight_count)
	for index: int in flight_count:
		WorldSnapshot._encode_projectile(out,
			flights_at + 1 + index * PROJECTILE_SIZE, flights[index])
	return out

static func from_bytes(bytes: PackedByteArray) -> WorldSnapshot:
	if bytes.size() < HEADER_SIZE:
		return null
	if bytes.decode_u8(0) != int(NetMessage.Kind.SNAPSHOT):
		return null
	var count: int = bytes.decode_u8(6)
	var flights_at: int = HEADER_SIZE + count * ACTOR_SIZE
	if bytes.size() < flights_at + 1:
		return null
	var flight_count: int = bytes.decode_u8(flights_at)
	if bytes.size() != flights_at + 1 + flight_count * PROJECTILE_SIZE:
		return null
	var snapshot: WorldSnapshot = WorldSnapshot.new()
	snapshot.tick = bytes.decode_u32(1)
	snapshot.shortcut_open = bytes.decode_u8(5) == 1
	for index: int in count:
		snapshot.states.append(
			WorldSnapshot._decode_actor(bytes, HEADER_SIZE + index * ACTOR_SIZE))
	for index: int in flight_count:
		snapshot.flights.append(WorldSnapshot._decode_projectile(
			bytes, flights_at + 1 + index * PROJECTILE_SIZE))
	return snapshot

static func _encode_actor(out: PackedByteArray, at: int, state: ActorState) -> void:
	out.encode_u32(at + 0, maxi(0, state.id))
	out.encode_u8(at + 4, clampi(state.kind, 0, 255))
	out.encode_u8(at + 5, clampi(state.state, 0, 255))
	out.encode_u32(at + 6, maxi(0, state.state_entered_tick))
	out.encode_float(at + 10, state.position.x)
	out.encode_float(at + 14, state.position.y)
	out.encode_float(at + 18, state.velocity.x)
	out.encode_float(at + 22, state.velocity.y)
	out.encode_float(at + 26, state.facing.x)
	out.encode_float(at + 30, state.facing.y)
	out.encode_u16(at + 34, clampi(state.health, 0, 65535))
	out.encode_u16(at + 36, clampi(state.poise, 0, 65535))
	out.encode_u16(at + 38, clampi(state.stamina_points, 0, 65535))
	out.encode_s8(at + 40, clampi(state.attack_index, -1, 127))
	out.encode_u16(at + 41, clampi(state.attack_elapsed, 0, 65535))
	out.encode_s8(at + 43, clampi(state.data_index, -1, 127))

static func _decode_actor(bytes: PackedByteArray, at: int) -> ActorState:
	var state: ActorState = ActorState.new()
	state.id = bytes.decode_u32(at + 0)
	state.kind = bytes.decode_u8(at + 4)
	state.state = bytes.decode_u8(at + 5)
	state.state_entered_tick = bytes.decode_u32(at + 6)
	state.position = Vector2(bytes.decode_float(at + 10), bytes.decode_float(at + 14))
	state.velocity = Vector2(bytes.decode_float(at + 18), bytes.decode_float(at + 22))
	state.facing = Vector2(bytes.decode_float(at + 26), bytes.decode_float(at + 30))
	state.health = bytes.decode_u16(at + 34)
	state.poise = bytes.decode_u16(at + 36)
	state.stamina_points = bytes.decode_u16(at + 38)
	state.attack_index = bytes.decode_s8(at + 40)
	state.attack_elapsed = bytes.decode_u16(at + 41)
	state.data_index = bytes.decode_s8(at + 43)
	return state

static func _encode_projectile(out: PackedByteArray, at: int, projectile: Projectile) -> void:
	out.encode_u32(at + 0, maxi(0, projectile.owner_id))
	out.encode_u32(at + 4, maxi(0, projectile.spawn_tick))
	out.encode_s8(at + 8, clampi(projectile.attack_index, -1, 127))
	out.encode_float(at + 9, projectile.origin.x)
	out.encode_float(at + 13, projectile.origin.y)
	out.encode_float(at + 17, projectile.direction.x)
	out.encode_float(at + 21, projectile.direction.y)

static func _decode_projectile(bytes: PackedByteArray, at: int) -> Projectile:
	var projectile: Projectile = Projectile.new()
	projectile.owner_id = bytes.decode_u32(at + 0)
	projectile.spawn_tick = bytes.decode_u32(at + 4)
	projectile.id = Projectile.make_id(projectile.owner_id, projectile.spawn_tick)
	projectile.attack_index = bytes.decode_s8(at + 8)
	projectile.origin = Vector2(bytes.decode_float(at + 9), bytes.decode_float(at + 13))
	projectile.direction = Vector2(bytes.decode_float(at + 17), bytes.decode_float(at + 21))
	return projectile

## Recherche linéaire : au plus huit acteurs, un dictionnaire coûterait plus
## cher à construire qu'à consulter.
func state_for(actor_id: int) -> ActorState:
	for state: ActorState in states:
		if state.id == actor_id:
			return state
	return null
