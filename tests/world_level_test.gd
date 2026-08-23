## Niveau : collision, raccourci, feu de camp, poursuite des ennemis.
extends GdUnitTestSuite

const LEVEL: String = "res://data/level/vertical_slice.tres"
const PLAYER: String = "res://data/actors/player.tres"
const GRUNT: String = "res://data/actors/grunt.tres"
const WARDEN: String = "res://data/actors/warden.tres"

var _worlds: Array[World] = []

func after_test() -> void:
	for world: World in _worlds:
		for actor_id: int in world.actors.keys():
			world.remove_actor(actor_id)
	_worlds.clear()

func _make_world(authority: World.Authority) -> World:
	var world: World = World.new(self)
	world.authority = authority
	var level: LevelData = load(LEVEL)
	var player_data: PlayerData = load(PLAYER)
	var grunt: EnemyData = load(GRUNT)
	var warden: EnemyData = load(WARDEN)
	var enemies: Array[EnemyData] = [grunt, warden]
	world.configure(level, player_data, enemies)
	_worlds.append(world)
	return world

func _push(world: World, actor_id: int, direction: Vector2, ticks: int) -> void:
	world.step(world.tick + 1, [Command.new(world.tick + 1, actor_id, Command.Type.MOVE, {"d": direction})])
	for _i: int in ticks:
		world.step(world.tick + 1, [])

func test_le_joueur_ne_traverse_pas_les_murs() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var player: Actor = world.spawn_player(1, 0)
	player.position = Vector2(0.0, -4.0)

	_push(world, 1, Vector2(1.0, 0.0), 240)

	# La salle du feu va de x = -10 à x = 10.
	assert_float(player.position.x).is_less_equal(10.0 - player.radius + 0.01)
	assert_float(player.position.x).is_greater(8.0)

func test_la_grille_bloque_le_raccourci_tant_qu_elle_est_fermee() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var player: Actor = world.spawn_player(1, 0)
	player.position = Vector2(-11.0, 32.0)

	_push(world, 1, Vector2(0.0, 1.0), 240)

	assert_bool(world.shortcut_open).is_false()
	# La grille occupe z = 36 à z = 40.
	assert_float(player.position.y).is_less(36.0)

func test_le_raccourci_ouvert_laisse_passer() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var player: Actor = world.spawn_player(1, 0)
	player.position = Vector2(-11.0, 32.0)
	world.shortcut_open = true

	_push(world, 1, Vector2(0.0, 1.0), 240)

	assert_float(player.position.y).is_greater(40.0)

func test_l_interaction_ouvre_le_raccourci_depuis_l_arene() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var player: Actor = world.spawn_player(1, 0)
	var level: LevelData = load(LEVEL)
	player.position = level.shortcut_switch_position
	var opened: Array[bool] = []
	world.shortcut_opened.connect(func() -> void: opened.append(true))

	world.step(world.tick + 1, [Command.new(world.tick + 1, 1, Command.Type.INTERACT, {})])

	assert_bool(world.shortcut_open).is_true()
	assert_int(opened.size()).is_equal(1)

func test_un_client_n_ouvre_pas_le_raccourci() -> void:
	var world: World = _make_world(World.Authority.CLIENT)
	var player: Actor = world.spawn_player(1, 0)
	var level: LevelData = load(LEVEL)
	player.position = level.shortcut_switch_position

	world.step(world.tick + 1, [Command.new(world.tick + 1, 1, Command.Type.INTERACT, {})])

	assert_bool(world.shortcut_open).is_false()

func test_le_repos_au_feu_soigne_et_replace_les_ennemis() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var player: Actor = world.spawn_player(1, 0)
	world.spawn_enemies()
	var enemy: Actor = world.enemies()[0]
	var home: Vector2 = enemy.home_position

	player.health = 5
	player.stamina_centi = 0
	enemy.health = 1
	enemy.position = Vector2(0.0, 20.0)
	world.shortcut_open = true

	var level: LevelData = load(LEVEL)
	player.position = level.bonfire_position
	world.step(world.tick + 1, [Command.new(world.tick + 1, 1, Command.Type.INTERACT, {})])

	assert_int(player.health).is_equal(player.max_health)
	assert_int(player.stamina_centi).is_equal(player.max_stamina_centi)
	assert_int(enemy.health).is_equal(enemy.max_health)
	assert_vector(enemy.position).is_equal(home)
	# La progression, elle, ne se perd pas.
	assert_bool(world.shortcut_open).is_true()

func test_le_repos_ressuscite_un_joueur_mort() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var player: Actor = world.spawn_player(1, 0)
	world.apply_damage(player, player.max_health, 0)
	assert_bool(player.is_alive()).is_false()

	world.rest_at_bonfire()

	assert_bool(player.is_alive()).is_true()
	assert_int(player.health).is_equal(player.max_health)

func test_un_ennemi_poursuit_un_joueur_a_portee_d_aggro() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var player: Actor = world.spawn_player(1, 0)
	world.spawn_enemies()
	var enemy: Actor = world.enemies()[0]
	player.position = Vector2(0.0, 8.0)
	enemy.position = Vector2(0.0, 16.0)
	var distance_before: float = enemy.position.distance_to(player.position)

	for _i: int in 60:
		world.step(world.tick + 1, [])

	assert_int(enemy.target_id).is_equal(1)
	assert_float(enemy.position.distance_to(player.position)).is_less(distance_before)

func test_un_ennemi_sans_cible_rentre_chez_lui() -> void:
	var world: World = _make_world(World.Authority.HOST)
	world.spawn_enemies()
	var enemy: Actor = world.enemies()[0]
	var home: Vector2 = enemy.home_position
	enemy.position = home + Vector2(0.0, 6.0)

	for _i: int in 180:
		world.step(world.tick + 1, [])

	assert_float(enemy.position.distance_to(home)).is_less(1.0)

func test_le_boss_enchaine_plus_vite_en_phase_deux() -> void:
	var warden: EnemyData = load(WARDEN)
	var boss: Actor = Actor.new()
	boss.max_health = warden.max_health
	boss.health = warden.max_health

	var full: int = EnemyBrain.attack_cooldown(boss, warden)
	boss.health = int(float(warden.max_health) * 0.3)
	var wounded: int = EnemyBrain.attack_cooldown(boss, warden)

	assert_int(full).is_equal(warden.attack_cooldown_ticks)
	assert_int(wounded).is_less(full)
