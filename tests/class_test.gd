## Classes jouables : projectiles, soin, et choix de classe sur le réseau.
extends GdUnitTestSuite

const LEVEL: String = "res://data/level/vertical_slice.tres"
const GARDIEN: String = "res://data/classes/gardien.tres"
const MAGE: String = "res://data/classes/mage.tres"
const SOIGNEUR: String = "res://data/classes/soigneur.tres"
const ARCHER: String = "res://data/classes/archer.tres"
const GOBELIN: String = "res://data/actors/gobelin.tres"
const WARDEN: String = "res://data/actors/warden.tres"

## Index dans l'ordre de NetBootstrap.CLASS_PATHS.
const GARDIEN_INDEX: int = 0
const MAGE_INDEX: int = 1
const SOIGNEUR_INDEX: int = 2
const ARCHER_INDEX: int = 3

var _worlds: Array[World] = []

func after_test() -> void:
	for world: World in _worlds:
		for actor_id: int in world.actors.keys():
			world.remove_actor(actor_id)
	_worlds.clear()

func _classes() -> Array[PlayerData]:
	var gardien: PlayerData = load(GARDIEN)
	var mage: PlayerData = load(MAGE)
	var soigneur: PlayerData = load(SOIGNEUR)
	var archer: PlayerData = load(ARCHER)
	return [gardien, mage, soigneur, archer]

func _make_world(authority: World.Authority) -> World:
	var world: World = World.new(self)
	world.authority = authority
	var level: LevelData = load(LEVEL)
	var gobelin: EnemyData = load(GOBELIN)
	var warden: EnemyData = load(WARDEN)
	var enemies: Array[EnemyData] = [gobelin, warden]
	world.configure(level, _classes(), enemies)
	_worlds.append(world)
	return world

func _step(world: World, commands: Array[Command] = []) -> void:
	world.step(world.tick + 1, commands)

func _attack(world: World, actor_id: int, index: int, aim: Vector2) -> Command:
	return Command.new(world.tick + 1, actor_id, Command.Type.ATTACK,
		{"i": index, "d": aim})

# ---------------------------------------------------------------------------
# Fiches
# ---------------------------------------------------------------------------

func test_les_quatre_classes_existent_et_different() -> void:
	var classes: Array[PlayerData] = _classes()
	assert_int(classes.size()).is_equal(4)
	var noms: Array[String] = []
	for fiche: PlayerData in classes:
		assert_object(fiche).is_not_null()
		assert_int(fiche.attacks.size()).is_greater_equal(1)
		assert_bool(noms.has(fiche.display_name)).is_false()
		noms.append(fiche.display_name)
	# Le gardien encaisse davantage que le mage : sans cela le choix ne veut
	# rien dire.
	assert_int(classes[GARDIEN_INDEX].max_health) \
		.is_greater(classes[MAGE_INDEX].max_health)
	assert_float(classes[ARCHER_INDEX].move_speed) \
		.is_greater(classes[GARDIEN_INDEX].move_speed)

# ---------------------------------------------------------------------------
# Projectiles
# ---------------------------------------------------------------------------

func test_le_mage_tire_un_projectile_et_un_seul() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var mage: Actor = world.spawn_player(1, 0, MAGE_INDEX)
	world.local_actor_id = 1
	mage.position = Vector2(0.0, -4.0)
	mage.facing = Vector2(0.0, 1.0)

	_step(world, [_attack(world, 1, 0, Vector2(0.0, 1.0))])
	for _i: int in 30:
		_step(world)
		if not world.projectiles.is_empty():
			break

	assert_int(world.projectiles.size()) \
		.override_failure_message("Une activation de hitbox doit tirer exactement un projectile.") \
		.is_equal(1)

func test_le_projectile_touche_un_ennemi_et_le_tireur_declare() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var mage: Actor = world.spawn_player(1, 0, MAGE_INDEX)
	world.local_actor_id = 1
	world.spawn_enemies()
	var cible: Actor = world.enemies()[0]
	mage.position = Vector2(0.0, -6.0)
	mage.facing = Vector2(0.0, 1.0)
	cible.position = Vector2(0.0, 0.0)

	var declares: Array[int] = []
	world.hit_declared.connect(func(target_id: int, _index: int) -> void:
		declares.append(target_id))

	_step(world, [_attack(world, 1, 0, Vector2(0.0, 1.0))])
	for _i: int in 120:
		_step(world)
		if not declares.is_empty():
			break

	assert_array(declares) \
		.override_failure_message("Le tireur doit declarer la touche de son projectile.") \
		.is_equal([cible.id])
	assert_bool(world.projectiles.is_empty()) \
		.override_failure_message("Un projectile ne traverse pas sa cible.") \
		.is_true()

func test_le_projectile_s_arrete_sur_un_mur() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var mage: Actor = world.spawn_player(1, 0, MAGE_INDEX)
	world.local_actor_id = 1
	# Face au mur est de la salle du feu, qui est a x = 10.
	mage.position = Vector2(7.0, -4.0)
	mage.facing = Vector2(1.0, 0.0)

	_step(world, [_attack(world, 1, 0, Vector2(1.0, 0.0))])
	for _i: int in 120:
		_step(world)

	assert_bool(world.projectiles.is_empty()) \
		.override_failure_message("Un projectile ne traverse pas les murs.") \
		.is_true()

func test_un_projectile_a_le_meme_identifiant_sur_deux_machines() -> void:
	# C'est ce qui empeche le tir predit par le client d'apparaitre en double
	# quand l'instantane de l'hote arrive.
	assert_int(Projectile.make_id(1234, 900)).is_equal(Projectile.make_id(1234, 900))
	assert_int(Projectile.make_id(1234, 900)).is_not_equal(Projectile.make_id(1234, 901))
	assert_int(Projectile.make_id(1234, 900)).is_not_equal(Projectile.make_id(1235, 900))

# ---------------------------------------------------------------------------
# Soin
# ---------------------------------------------------------------------------

func test_le_soigneur_declare_un_soin_sur_un_allie() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var soigneur: Actor = world.spawn_player(1, 0, SOIGNEUR_INDEX)
	var allie: Actor = world.spawn_player(2, 1, GARDIEN_INDEX)
	world.local_actor_id = 1
	soigneur.position = Vector2(0.0, -4.0)
	soigneur.facing = Vector2(0.0, 1.0)
	allie.position = Vector2(0.0, -2.0)
	allie.health = 20

	var soins: Array[int] = []
	world.heal_declared.connect(func(target_id: int, _index: int) -> void:
		soins.append(target_id))

	_step(world, [_attack(world, 1, 1, Vector2(0.0, 1.0))])
	for _i: int in 40:
		_step(world)

	assert_bool(soins.has(allie.id)) \
		.override_failure_message("L'allie a portee doit etre declare soigne.") \
		.is_true()
	assert_bool(soins.has(soigneur.id)) \
		.override_failure_message("Le soigneur se soigne aussi : il est au centre de son cone.") \
		.is_true()

func test_l_hote_applique_le_soin_declare() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var soigneur: Actor = world.spawn_player(1, 0, SOIGNEUR_INDEX)
	var allie: Actor = world.spawn_player(2, 1, GARDIEN_INDEX)
	world.local_actor_id = 1
	soigneur.position = Vector2(0.0, -4.0)
	allie.position = Vector2(0.0, -3.0)
	allie.health = 20

	_step(world, [Command.new(world.tick + 1, 1, Command.Type.DECLARE_HEAL,
		{"t": allie.id, "a": 1})])

	assert_int(allie.health).is_greater(20)

func test_un_client_n_applique_pas_les_soins() -> void:
	var world: World = _make_world(World.Authority.CLIENT)
	var soigneur: Actor = world.spawn_player(1, 0, SOIGNEUR_INDEX)
	var allie: Actor = world.spawn_player(2, 1, GARDIEN_INDEX)
	soigneur.position = Vector2(0.0, -4.0)
	allie.position = Vector2(0.0, -3.0)
	allie.health = 20

	_step(world, [Command.new(world.tick + 1, 1, Command.Type.DECLARE_HEAL,
		{"t": allie.id, "a": 1})])

	assert_int(allie.health).is_equal(20)

func test_un_soin_hors_de_portee_est_rejete() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var soigneur: Actor = world.spawn_player(1, 0, SOIGNEUR_INDEX)
	var allie: Actor = world.spawn_player(2, 1, GARDIEN_INDEX)
	soigneur.position = Vector2(0.0, -8.0)
	allie.position = Vector2(9.0, 4.0)
	allie.health = 20

	_step(world, [Command.new(world.tick + 1, 1, Command.Type.DECLARE_HEAL,
		{"t": allie.id, "a": 1})])

	assert_int(allie.health).is_equal(20)

# ---------------------------------------------------------------------------
# Choix de classe
# ---------------------------------------------------------------------------

func test_la_classe_annoncee_est_appliquee_par_l_hote() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var joueur: Actor = world.spawn_player(1, 0, GARDIEN_INDEX)
	var vie_gardien: int = joueur.max_health

	_step(world, [Command.new(world.tick + 1, 1, Command.Type.SELECT_CLASS,
		{"c": MAGE_INDEX})])

	assert_int(joueur.data_index).is_equal(MAGE_INDEX)
	assert_int(joueur.max_health).is_not_equal(vie_gardien)
	assert_int(joueur.health).is_equal(joueur.max_health)

func test_un_index_de_classe_absurde_ne_casse_rien() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var joueur: Actor = world.spawn_player(1, 0, GARDIEN_INDEX)

	_step(world, [Command.new(world.tick + 1, 1, Command.Type.SELECT_CLASS,
		{"c": 9999})])

	assert_int(joueur.data_index).is_between(0, 3)
	assert_int(joueur.health).is_greater(0)

func test_un_client_ne_change_pas_de_classe_de_son_propre_chef() -> void:
	var world: World = _make_world(World.Authority.CLIENT)
	var joueur: Actor = world.spawn_player(1, 0, GARDIEN_INDEX)

	_step(world, [Command.new(world.tick + 1, 1, Command.Type.SELECT_CLASS,
		{"c": MAGE_INDEX})])

	assert_int(joueur.data_index).is_equal(GARDIEN_INDEX)
