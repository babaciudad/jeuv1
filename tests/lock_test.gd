## Verrouillage et pas d'esquive arriere : les deux gestes qui separent une
## locomotion de souls-like d'une locomotion de jeu d'action.
##
## Verrouille, un personnage garde son adversaire de FACE et se deplace autour
## de lui — il recule, il tourne, il fait des pas chasses. Sans verrouillage il
## regarde toujours la ou il va, ne recule jamais, et la moitie des animations
## de deplacement ne sert a rien.
extends GdUnitTestSuite

const LEVEL: String = "res://data/level/vertical_slice.tres"
const GARDIEN: String = "res://data/classes/gardien.tres"
const MAGE: String = "res://data/classes/mage.tres"
const SOIGNEUR: String = "res://data/classes/soigneur.tres"
const ARCHER: String = "res://data/classes/archer.tres"
const GOBELIN: String = "res://data/actors/gobelin.tres"
const WARDEN: String = "res://data/actors/warden.tres"

var _worlds: Array[World] = []

func after_test() -> void:
	for world: World in _worlds:
		for actor_id: int in world.actors.keys():
			world.remove_actor(actor_id)
	_worlds.clear()

func _make_world() -> World:
	var world: World = World.new(self)
	world.authority = World.Authority.HOST
	var gardien: PlayerData = load(GARDIEN)
	var mage: PlayerData = load(MAGE)
	var soigneur: PlayerData = load(SOIGNEUR)
	var archer: PlayerData = load(ARCHER)
	var gobelin: EnemyData = load(GOBELIN)
	var warden: EnemyData = load(WARDEN)
	var level: LevelData = load(LEVEL)
	var classes: Array[PlayerData] = [gardien, mage, soigneur, archer]
	var enemies: Array[EnemyData] = [gobelin, warden]
	world.configure(level, classes, enemies)
	_worlds.append(world)
	return world

func _step(world: World, commands: Array[Command] = []) -> void:
	world.step(world.tick + 1, commands)

func _command(world: World, actor_id: int, type: Command.Type,
		payload: Dictionary = {}) -> Command:
	return Command.new(world.tick + 1, actor_id, type, payload)

## Un joueur et un ennemi face a face, dans la halle.
func _face_off(world: World) -> Array[Actor]:
	var player: Actor = world.spawn_player(1, 0)
	world.local_actor_id = 1
	world.spawn_enemies()
	var enemy: Actor = world.enemies()[0]
	player.position = Vector2(0.0, -6.0)
	player.facing = Vector2(0.0, 1.0)
	enemy.position = Vector2(0.0, -2.0)
	enemy.facing = Vector2(0.0, -1.0)
	return [player, enemy]

func test_le_verrou_accroche_un_ennemi_a_portee() -> void:
	var world: World = _make_world()
	var pair: Array[Actor] = _face_off(world)
	_step(world, [_command(world, 1, Command.Type.LOCK, {"t": pair[1].id})])
	assert_int(pair[0].lock_target_id).is_equal(pair[1].id)

## La presentation propose, la simulation dispose : un client ne peut pas se
## verrouiller sur un allie, sur un mort, ni sur quelqu'un a l'autre bout du
## niveau.
func test_le_verrou_refuse_une_cible_illegitime() -> void:
	var world: World = _make_world()
	var pair: Array[Actor] = _face_off(world)
	var ami: Actor = world.spawn_player(2, 1)
	ami.position = Vector2(1.0, -6.0)
	_step(world, [_command(world, 1, Command.Type.LOCK, {"t": ami.id})])
	assert_int(pair[0].lock_target_id) \
		.override_failure_message("verrouille sur un allie").is_equal(0)
	pair[1].position = Vector2(0.0, 120.0)
	_step(world, [_command(world, 1, Command.Type.LOCK, {"t": pair[1].id})])
	assert_int(pair[0].lock_target_id) \
		.override_failure_message("verrouille a cent metres").is_equal(0)

## Un verrou qui survit a sa cible est un personnage qui regarde un cadavre en
## reculant.
func test_le_verrou_se_relache_si_la_cible_meurt() -> void:
	var world: World = _make_world()
	var pair: Array[Actor] = _face_off(world)
	_step(world, [_command(world, 1, Command.Type.LOCK, {"t": pair[1].id})])
	assert_int(pair[0].lock_target_id).is_equal(pair[1].id)
	pair[1].health = 0
	pair[1].enter_state(Actor.State.DEAD, world.tick)
	_step(world)
	assert_int(pair[0].lock_target_id).is_equal(0)

## LE TEST QUI COMPTE : verrouille, on marche en arriere sans se retourner.
func test_verrouille_on_recule_sans_se_retourner() -> void:
	var world: World = _make_world()
	var pair: Array[Actor] = _face_off(world)
	var player: Actor = pair[0]
	_step(world, [_command(world, 1, Command.Type.LOCK, {"t": pair[1].id})])
	# On pousse vers l'ARRIERE, en s'eloignant de la cible.
	for tour: int in 24:
		_step(world, [_command(world, 1, Command.Type.MOVE,
			{"d": Vector2(0.0, -1.0)})])
	assert_float(player.position.y) \
		.override_failure_message("le joueur n'a pas recule") \
		.is_less(-6.2)
	# Et il regarde TOUJOURS la cible.
	var toward: Vector2 = (pair[1].position - player.position).normalized()
	assert_float(player.facing.dot(toward)) \
		.override_failure_message("le joueur s'est retourne en reculant") \
		.is_greater(0.9)

## Sans verrou, le meme deplacement retourne le personnage : c'est la
## difference, et elle doit se mesurer.
func test_sans_verrou_on_se_retourne() -> void:
	var world: World = _make_world()
	var pair: Array[Actor] = _face_off(world)
	var player: Actor = pair[0]
	for tour: int in 24:
		_step(world, [_command(world, 1, Command.Type.MOVE,
			{"d": Vector2(0.0, -1.0)})])
	assert_float(player.facing.y) \
		.override_failure_message("le joueur devrait regarder vers l'arriere") \
		.is_less(-0.9)

## Esquive SANS direction : on saute en arriere sans se retourner. C'est le
## geste de garde du genre, et il n'existait pas — toute esquive partait vers
## l'avant, y compris quand le joueur ne poussait rien.
func test_esquive_sans_direction_est_un_pas_arriere() -> void:
	var world: World = _make_world()
	var pair: Array[Actor] = _face_off(world)
	var player: Actor = pair[0]
	var depart: Vector2 = player.position
	var cap: Vector2 = player.facing
	_step(world, [_command(world, 1, Command.Type.DODGE,
		{"d": Vector2.ZERO})])
	assert_bool(player.dodge_backstep).is_true()
	for tour: int in 20:
		_step(world)
	assert_float(player.facing.dot(cap)) \
		.override_failure_message("le pas arriere a retourne le personnage") \
		.is_greater(0.95)
	assert_float((player.position - depart).dot(cap)) \
		.override_failure_message("le pas arriere est parti en avant") \
		.is_less(-0.5)

## Avec une direction, c'est une roulade : elle part vers cette direction et le
## personnage s'y tourne.
func test_esquive_dirigee_reste_une_roulade() -> void:
	var world: World = _make_world()
	var pair: Array[Actor] = _face_off(world)
	var player: Actor = pair[0]
	var depart: Vector2 = player.position
	_step(world, [_command(world, 1, Command.Type.DODGE,
		{"d": Vector2(1.0, 0.0)})])
	assert_bool(player.dodge_backstep).is_false()
	assert_float(player.facing.x).is_greater(0.9)
	for tour: int in 20:
		_step(world)
	assert_float(player.position.x - depart.x).is_greater(1.0)

## Un pas arriere coute moins d'endurance qu'une roulade et va moins loin :
## c'est ce qui en fait un geste de garde et non une esquive complete.
func test_le_pas_arriere_coute_moins_et_va_moins_loin() -> void:
	var world: World = _make_world()
	var a: Array[Actor] = _face_off(world)
	var recule: Actor = a[0]
	var avant: int = recule.stamina_centi
	_step(world, [_command(world, 1, Command.Type.DODGE, {"d": Vector2.ZERO})])
	var cout_pas: int = avant - recule.stamina_centi
	var depart: Vector2 = recule.position
	for tour: int in 30:
		_step(world)
	var portee_pas: float = depart.distance_to(recule.position)

	var monde2: World = _make_world()
	var b: Array[Actor] = _face_off(monde2)
	var roule: Actor = b[0]
	var avant2: int = roule.stamina_centi
	_step(monde2, [_command(monde2, 1, Command.Type.DODGE,
		{"d": Vector2(0.0, 1.0)})])
	var cout_roulade: int = avant2 - roule.stamina_centi
	var depart2: Vector2 = roule.position
	for tour: int in 30:
		_step(monde2)
	var portee_roulade: float = depart2.distance_to(roule.position)

	assert_int(cout_pas).is_less(cout_roulade)
	assert_float(portee_pas).is_less(portee_roulade)
