## Règles de combat : déclaration de touche, autorité sur les dégâts,
## invulnérabilité de roulade, endurance, poise.
##
## Ces tests tournent sans réseau et sans affichage : le monde est une
## structure de données qu'on fait avancer d'un tick à la fois.
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

## Les quatre classes, dans l'ordre du menu et du réseau.
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

func _command(world: World, actor_id: int, type: Command.Type,
		payload: Dictionary = {}) -> Command:
	return Command.new(world.tick + 1, actor_id, type, payload)

## Place un ennemi juste devant le joueur, face à face, dans la salle du feu.
func _face_off(world: World) -> Array[Actor]:
	var player: Actor = world.spawn_player(1, 0)
	world.local_actor_id = 1
	world.spawn_enemies()
	var enemy: Actor = world.enemies()[0]
	player.position = Vector2(0.0, -4.0)
	player.facing = Vector2(0.0, 1.0)
	enemy.position = Vector2(0.0, -2.4)
	enemy.facing = Vector2(0.0, -1.0)
	return [player, enemy]

func test_l_attaque_du_joueur_declare_une_touche_sur_l_ennemi_a_portee() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var pair: Array[Actor] = _face_off(world)
	var enemy: Actor = pair[1]

	var declared: Array[int] = []
	world.hit_declared.connect(func(target_id: int, _index: int) -> void: declared.append(target_id))

	_step(world, [_command(world, 1, Command.Type.ATTACK, {"i": 0})])
	for _i: int in 30:
		_step(world)

	assert_array(declared).is_equal([enemy.id])

func test_l_hote_applique_les_degats_declares() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var pair: Array[Actor] = _face_off(world)
	var enemy: Actor = pair[1]
	var before: int = enemy.health

	world.hit_declared.connect(func(target_id: int, index: int) -> void:
		world.step(world.tick, [Command.new(world.tick, 1, Command.Type.DECLARE_HIT,
			{"t": target_id, "a": index})]))

	_step(world, [_command(world, 1, Command.Type.ATTACK, {"i": 0})])
	for _i: int in 30:
		_step(world)

	assert_int(enemy.health).is_less(before)

func test_un_client_ne_tranche_jamais_les_degats() -> void:
	var world: World = _make_world(World.Authority.CLIENT)
	var pair: Array[Actor] = _face_off(world)
	var enemy: Actor = pair[1]

	_step(world, [_command(world, 1, Command.Type.DECLARE_HIT,
		{"t": enemy.id, "a": 0})])

	assert_int(enemy.health).is_equal(enemy.max_health)

func test_une_touche_hors_de_portee_est_rejetee_par_l_hote() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var pair: Array[Actor] = _face_off(world)
	var enemy: Actor = pair[1]
	enemy.position = Vector2(0.0, 8.0)

	_step(world, [_command(world, 1, Command.Type.DECLARE_HIT,
		{"t": enemy.id, "a": 0})])

	assert_int(enemy.health).is_equal(enemy.max_health)

func test_une_touche_trop_ancienne_est_rejetee() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var pair: Array[Actor] = _face_off(world)
	var enemy: Actor = pair[1]
	for _i: int in 100:
		_step(world)

	var stale: Command = Command.new(1, 1, Command.Type.DECLARE_HIT,
		{"t": enemy.id, "a": 0})
	_step(world, [stale])

	assert_int(enemy.health).is_equal(enemy.max_health)

func test_l_ennemi_meurt_a_zero_point_de_vie() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var pair: Array[Actor] = _face_off(world)
	var enemy: Actor = pair[1]
	var deaths: Array[int] = []
	world.actor_died.connect(func(actor_id: int) -> void: deaths.append(actor_id))

	world.apply_damage(enemy, enemy.max_health, 0)

	assert_int(enemy.health).is_equal(0)
	assert_bool(enemy.is_alive()).is_false()
	assert_array(deaths).is_equal([enemy.id])

func test_la_poise_cassee_fait_chanceler() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var pair: Array[Actor] = _face_off(world)
	var enemy: Actor = pair[1]

	world.apply_damage(enemy, 1, enemy.max_poise)

	assert_int(int(enemy.state)).is_equal(int(Actor.State.STAGGERED))

func test_les_iframes_de_roulade_empechent_la_declaration_de_degats() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var pair: Array[Actor] = _face_off(world)
	var player: Actor = pair[0]

	# Sans roulade, la victime déclare bien avoir été touchée.
	var reported: Array[int] = []
	world.damage_reported.connect(func(source_id: int, _index: int) -> void:
		reported.append(source_id))
	assert_bool(world.is_invulnerable(player)).is_false()

	player.enter_state(Actor.State.DODGING, world.tick)
	var fiche: PlayerData = load(GARDIEN)
	for _i: int in fiche.dodge_invulnerable_from_tick:
		_step(world)
	assert_bool(world.is_invulnerable(player)).is_true()

func test_l_attaque_coute_de_l_endurance_et_est_refusee_a_vide() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var pair: Array[Actor] = _face_off(world)
	var player: Actor = pair[0]
	var data: PlayerData = load(GARDIEN)
	var before: int = player.stamina_centi

	_step(world, [_command(world, 1, Command.Type.ATTACK, {"i": 0})])
	assert_int(player.stamina_centi).is_equal(before - data.attacks[0].stamina_cost * Actor.CENTI)
	assert_int(int(player.state)).is_equal(int(Actor.State.ATTACKING))

	# À vide, l'attaque ne part pas.
	for _i: int in 60:
		_step(world)
	player.stamina_centi = 0
	_step(world, [_command(world, 1, Command.Type.ATTACK, {"i": 0})])
	assert_int(int(player.state)).is_not_equal(int(Actor.State.ATTACKING))

func test_la_roulade_coute_de_l_endurance_et_deplace() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var pair: Array[Actor] = _face_off(world)
	var player: Actor = pair[0]
	var start: Vector2 = player.position

	_step(world, [_command(world, 1, Command.Type.DODGE, {"d": Vector2(-1.0, 0.0)})])
	for _i: int in 10:
		_step(world)

	assert_int(int(player.state)).is_equal(int(Actor.State.DODGING))
	assert_float(player.position.x).is_less(start.x - 0.5)

func test_la_roulade_part_vite_et_finit_lentement() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var pair: Array[Actor] = _face_off(world)
	var player: Actor = pair[0]
	var fiche: PlayerData = world.class_for(player)

	_step(world, [_command(world, 1, Command.Type.DODGE, {"d": Vector2(-1.0, 0.0)})])
	var depart: float = player.velocity.length()
	for _i: int in fiche.dodge_duration_ticks - 3:
		_step(world)
	var fin: float = player.velocity.length()

	# Une roulade est une impulsion, pas un déplacement à vitesse constante :
	# c'était le vrai défaut de sensation du jeu.
	assert_float(depart).is_greater(fiche.dodge_speed)
	assert_float(fin).is_less(depart * 0.5)

func test_on_sort_de_roulade_en_marchant_et_non_a_l_arret() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var pair: Array[Actor] = _face_off(world)
	var player: Actor = pair[0]
	var fiche: PlayerData = world.class_for(player)

	_step(world, [_command(world, 1, Command.Type.DODGE, {"d": Vector2(-1.0, 0.0)})])
	for _i: int in fiche.dodge_duration_ticks + 1:
		_step(world)

	assert_int(int(player.state)).is_equal(int(Actor.State.IDLE))
	# Couper à zéro fige le personnage sur place et casse l'enchaînement.
	assert_float(player.velocity.length()).is_greater(0.5)

func test_l_avancement_de_roulade_va_de_zero_a_un() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var pair: Array[Actor] = _face_off(world)
	var player: Actor = pair[0]
	var fiche: PlayerData = world.class_for(player)

	assert_float(world.dodge_progress(player)).is_equal_approx(0.0, 0.001)
	_step(world, [_command(world, 1, Command.Type.DODGE, {"d": Vector2(-1.0, 0.0)})])
	assert_float(world.dodge_progress(player)).is_less(0.2)
	for _i: int in fiche.dodge_duration_ticks - 2:
		_step(world)
	assert_float(world.dodge_progress(player)).is_greater(0.8)
