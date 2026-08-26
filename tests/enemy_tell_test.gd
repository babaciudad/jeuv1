## La mise en garde des ennemis : le TELL.
##
## Un ennemi qui frappe a l'instant ou il entre en portee ne donne rien a lire,
## et le joueur ne peut que subir. La marque du genre est qu'on VOIT le coup
## venir assez tot pour rouler et assez tard pour que ce soit un choix. Ces
## tests mesurent ce delai, et le fait qu'il se remet a zero quand il doit.
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

func _step(world: World) -> void:
	world.step(world.tick + 1, [])

## Colle un cristallise contre le joueur, a portee de coup, pret a frapper.
func _face_off(world: World) -> Array[Actor]:
	var player: Actor = world.spawn_player(1, 0)
	world.local_actor_id = 1
	world.spawn_enemies()
	var enemy: Actor = world.enemies()[0]
	player.position = Vector2(0.0, 16.0)
	player.facing = Vector2(0.0, 1.0)
	enemy.position = Vector2(0.0, 17.4)
	enemy.facing = Vector2(0.0, -1.0)
	enemy.last_attack_tick = -100000
	enemy.wind_up_tick = -1
	return [player, enemy]

## Combien de ticks entre la mise en portee et le coup.
func _ticks_avant_coup(world: World, enemy: Actor, limite: int) -> int:
	for tour: int in limite:
		_step(world)
		if enemy.state == Actor.State.ATTACKING:
			return tour + 1
	return -1

func test_l_ennemi_marque_un_temps_avant_de_frapper() -> void:
	var world: World = _make_world()
	var pair: Array[Actor] = _face_off(world)
	var data: EnemyData = load(GOBELIN)
	var delai: int = _ticks_avant_coup(world, pair[1], 120)
	assert_int(delai) \
		.override_failure_message("l'ennemi n'a jamais frappe").is_greater(0)
	# Il doit attendre au moins la moitie de son tell : en dessous, il n'y a
	# rien a lire.
	assert_int(delai) \
		.override_failure_message(
			"l'ennemi frappe apres %d ticks, tell regle a %d"
			% [delai, data.tell_ticks]) \
		.is_greater_equal(int(float(data.tell_ticks) * 0.5))

## Un ennemi frappe pendant sa mise en garde doit RECOMMENCER. Sinon, frapper
## en premier ne sert a rien.
func test_encaisser_interrompt_la_mise_en_garde() -> void:
	var world: World = _make_world()
	var pair: Array[Actor] = _face_off(world)
	var enemy: Actor = pair[1]
	for tour: int in 6:
		_step(world)
	assert_int(enemy.wind_up_tick) \
		.override_failure_message("l'ennemi ne s'est pas mis en garde") \
		.is_greater_equal(0)
	enemy.enter_state(Actor.State.STAGGERED, world.tick)
	_step(world)
	assert_int(enemy.wind_up_tick).is_equal(-1)

## S'eloigner desarme l'ennemi : il ne doit pas accumuler son tell a distance
## pour frapper a la premiere seconde ou l'on approche.
func test_s_eloigner_desarme_l_ennemi() -> void:
	var world: World = _make_world()
	var pair: Array[Actor] = _face_off(world)
	var enemy: Actor = pair[1]
	for tour: int in 6:
		_step(world)
	assert_int(enemy.wind_up_tick).is_greater_equal(0)
	pair[0].position = Vector2(0.0, 26.0)
	_step(world)
	assert_int(enemy.wind_up_tick).is_equal(-1)

## Punition du coup manque : contre une cible qui FRAPPE, la mise en garde est
## plus courte. C'est ce qui apprend a ne pas frapper au hasard.
##
## On interroge la cervelle DIRECTEMENT plutot que de faire tourner un monde :
## l'etat du joueur doit rester fige pendant toute la mesure, et un monde le
## ferait changer.
func test_l_ennemi_punit_un_joueur_qui_frappe() -> void:
	var data: EnemyData = load(GOBELIN)
	if data.punish_percent >= 100:
		return
	assert_int(_garde(data, Actor.State.IDLE)) \
		.override_failure_message("garde nulle contre une cible immobile") \
		.is_greater(0)
	assert_int(_garde(data, Actor.State.ATTACKING)) \
		.override_failure_message(
			"la garde contre une cible qui frappe n'est pas plus courte") \
		.is_less(_garde(data, Actor.State.IDLE))

## Ticks de mise en garde de la cervelle contre une cible dans cet etat.
func _garde(data: EnemyData, etat: Actor.State) -> int:
	var enemy: Actor = Actor.new()
	enemy.id = 2
	enemy.kind = Actor.Kind.ENEMY
	enemy.state = Actor.State.IDLE
	enemy.position = Vector2(0.0, 1.4)
	enemy.facing = Vector2(0.0, -1.0)
	enemy.health = data.max_health
	enemy.max_health = data.max_health
	enemy.last_attack_tick = -100000
	enemy.wind_up_tick = -1
	var cible: Actor = Actor.new()
	cible.id = 1
	cible.kind = Actor.Kind.PLAYER
	cible.state = etat
	cible.position = Vector2.ZERO
	cible.health = 100
	cible.max_health = 100
	var joueurs: Array[Actor] = [cible]
	for tour: int in 200:
		var choix: EnemyBrain.Decision = EnemyBrain.decide(
			enemy, data, joueurs, tour)
		if choix.attack_index >= 0:
			return tour
	return -1
