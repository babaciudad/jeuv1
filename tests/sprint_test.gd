## La course forcee : la troisieme allure.
##
## Trois allures valent mieux que deux — on marche pour lire un combat, on court
## pour se replacer, on force pour fuir ou rattraper. L'allure voyage dans la
## LONGUEUR de l'intention de deplacement, pas dans un champ separe : c'est ce
## qui permet de l'ajouter sans toucher au protocole.
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

func _command(world: World, actor_id: int, type: Command.Type,
		payload: Dictionary = {}) -> Command:
	return Command.new(world.tick + 1, actor_id, type, payload)

## Fait courir un joueur en ligne droite et renvoie la distance parcourue.
func _course(longueur: float, ticks: int) -> Array:
	var world: World = _make_world()
	var player: Actor = world.spawn_player(1, 0)
	world.local_actor_id = 1
	player.position = Vector2(0.0, 12.0)
	player.facing = Vector2(0.0, 1.0)
	var depart: Vector2 = player.position
	for tour: int in ticks:
		world.step(world.tick + 1, [_command(world, 1, Command.Type.MOVE,
			{"d": Vector2(0.0, 1.0) * longueur})])
	return [depart.distance_to(player.position), player.stamina_centi]

func test_forcer_l_allure_va_plus_vite() -> void:
	var normal: Array = _course(1.0, 40)
	var force: Array = _course(1.9, 40)
	var d_normal: float = normal[0]
	var d_force: float = force[0]
	assert_float(d_normal).is_greater(1.0)
	assert_float(d_force) \
		.override_failure_message(
			"course forcee %.2f m contre %.2f m en course normale"
			% [d_force, d_normal]) \
		.is_greater(d_normal * 1.2)

func test_forcer_l_allure_coute_de_l_endurance() -> void:
	var normal: Array = _course(1.0, 40)
	var force: Array = _course(1.9, 40)
	var s_normal: int = normal[1]
	var s_force: int = force[1]
	assert_int(s_force) \
		.override_failure_message(
			"forcer n'a rien coute : %d contre %d" % [s_force, s_normal]) \
		.is_less(s_normal)

## Sans endurance, forcer ne donne rien : on retombe a la course normale. C'est
## ce qui empeche la course forcee d'etre la seule allure du jeu.
func test_sans_endurance_on_ne_force_plus() -> void:
	var world: World = _make_world()
	var player: Actor = world.spawn_player(1, 0)
	world.local_actor_id = 1
	player.position = Vector2(0.0, 12.0)
	player.facing = Vector2(0.0, 1.0)
	player.stamina_centi = 0
	var depart: Vector2 = player.position
	for tour: int in 40:
		world.step(world.tick + 1, [_command(world, 1, Command.Type.MOVE,
			{"d": Vector2(0.0, 1.9)})])
	var a_sec: float = depart.distance_to(player.position)
	var plein: float = _course(1.0, 40)[0]
	# A dix pour cent pres : le freinage initial n'est pas exactement le meme.
	assert_float(a_sec) \
		.override_failure_message(
			"a sec, on a parcouru %.2f m contre %.2f m en course normale"
			% [a_sec, plein]) \
		.is_less(plein * 1.1)

## Un client ne peut pas envoyer l'allure qu'il veut : la longueur est bornee.
func test_une_intention_absurde_est_bornee() -> void:
	var honnete: float = _course(1.9, 40)[0]
	var tricheur: float = _course(40.0, 40)[0]
	assert_float(tricheur) \
		.override_failure_message(
			"une intention de longueur 40 a parcouru %.2f m contre %.2f m"
			% [tricheur, honnete]) \
		.is_less(honnete * 1.15)
