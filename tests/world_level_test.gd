## Niveau : collision, raccourci, feu de camp, poursuite des ennemis.
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

func _push(world: World, actor_id: int, direction: Vector2, ticks: int) -> void:
	world.step(world.tick + 1, [Command.new(world.tick + 1, actor_id, Command.Type.MOVE, {"d": direction})])
	for _i: int in ticks:
		world.step(world.tick + 1, [])

func test_le_joueur_ne_traverse_pas_les_murs() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var player: Actor = world.spawn_player(1, 0)
	# z = -8 est la travee libre entre deux rangs de membrures : le test doit
	# mesurer le mur, pas un pilier.
	player.position = Vector2(0.0, -8.0)

	_push(world, 1, Vector2(1.0, 0.0), 400)

	# La halle va de x = -15 a x = 15.
	assert_float(player.position.x).is_less_equal(15.0 - player.radius + 0.01)
	assert_float(player.position.x) \
		.override_failure_message("Le joueur n'a pas traverse la halle.") \
		.is_greater(12.0)

## Les colonnes de la nef bloquent pour de vrai. Elles sont declarees dans la
## donnee de simulation, pas seulement dessinees : un pilier qu'on traverse
## est un decor qui ment, et personne ne saurait dire si c'est le reseau.
func test_les_colonnes_bloquent() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var player: Actor = world.spawn_player(1, 0)
	# Face a la membrure de droite, qui occupe x = 9.8 a 11.2.
	player.position = Vector2(2.0, -5.0)

	_push(world, 1, Vector2(1.0, 0.0), 240)

	assert_float(player.position.x) \
		.override_failure_message("Le joueur a traverse une membrure.") \
		.is_less(9.8)
	assert_float(player.position.x) \
		.override_failure_message("Le joueur n'a pas avance : le test ne prouve rien.") \
		.is_greater(3.0)

## Le niveau declare une hauteur par salle. Sans elle, la nef et le boyau se
## ressemblent, et c'est tout le propos de l'endroit qui tombe.
func test_les_salles_ont_des_hauteurs_distinctes() -> void:
	var level: LevelData = load(LEVEL)
	var halle: float = level.height_at(Vector2(0.0, -8.0))
	var seuil: float = level.height_at(Vector2(0.0, 108.0))
	assert_float(halle).is_greater(seuil + 2.0)
	# Une zone a ciel ouvert rend un degagement franchement plus grand que
	# n'importe quelle salle : c'est ce qui empeche la camera d'y chercher un
	# plafond.
	var parvis: float = level.height_at(Vector2(0.0, 20.0))
	assert_float(parvis).is_greater(halle + 5.0)
	assert_bool(level.is_open(Vector2(0.0, 20.0))).is_true()
	assert_bool(level.is_open(Vector2(0.0, -8.0))).is_false()
	# Un point hors du praticable retombe sur la hauteur par defaut plutot que
	# sur zero : un plafond a zero collerait au sol.
	assert_float(level.height_at(Vector2(500.0, 500.0))).is_greater(0.0)

func test_la_grille_bloque_le_raccourci_tant_qu_elle_est_fermee() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var player: Actor = world.spawn_player(1, 0)
	# Le couloir du raccourci occupe x = 26 à x = 33.
	player.position = Vector2(29.5, 100.0)

	_push(world, 1, Vector2(0.0, 1.0), 400)

	assert_bool(world.shortcut_open).is_false()
	# Il doit avoir avancé — sinon le test passerait aussi bien avec un joueur
	# coincé dans un mur, ce qui ne prouverait rien sur la grille.
	assert_float(player.position.y) \
		.override_failure_message("Le joueur n'a pas avance du tout : le test ne prouve rien.") \
		.is_greater(104.0)
	# Le raccourci s'arrete a z = 118, et la grille barre le passage vers
	# l'arene.
	assert_float(player.position.y).is_less(118.1)

func test_le_raccourci_ouvert_laisse_passer() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var player: Actor = world.spawn_player(1, 0)
	player.position = Vector2(26.8, 114.5)
	world.shortcut_open = true

	_push(world, 1, Vector2(-1.0, 0.0), 240)

	# Grille ouverte, le passage laisse rejoindre l'arene, a l'ouest de x = 25.
	assert_float(player.position.x).is_less(24.0)

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

## LE RACCOURCI N'EST PLUS UNE LIGNE DROITE. Quatre masses le barrent en
## alternance : une pile d'arcade tombee, deux blocs de la voute effondree, un
## bloc de sel. On ne le traverse qu'en changeant de bord.
##
## C'est de la geometrie de simulation, pas du decor : un eboulement qu'on
## traverse ne rythme rien du tout, et cent-neuf metres qu'on parcourt pouce en
## avant ne sont pas un couloir, ce sont des secondes de marche.
func test_le_raccourci_est_barre_et_oblige_a_contourner() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var player: Actor = world.spawn_player(1, 0)
	world.shortcut_open = true
	# Droit sur la premiere masse, qui tient x = 29,4 a 33 sur z = 25 a 26,6.
	player.position = Vector2(31.2, 20.0)

	_push(world, 1, Vector2(0.0, 1.0), 240)

	assert_float(player.position.y) \
		.override_failure_message(
			"Plus rien n'arrete dans le raccourci : le couloir est redevenu "
			+ "une ligne droite.") \
		.is_less(25.0)
	assert_float(player.position.y) \
		.override_failure_message(
			"Le joueur n'a pas avance : le test ne prouve rien.") \
		.is_greater(23.0)

## ... et il reste franchissable en longeant l'autre bord. Un obstacle qui
## bouche tout un couloir n'est pas un obstacle, c'est un mur — et le
## raccourci, qui est la seule victoire acquise du niveau, ne servirait plus.
func test_le_raccourci_se_franchit_en_longeant_l_autre_bord() -> void:
	var world: World = _make_world(World.Authority.HOST)
	var player: Actor = world.spawn_player(1, 0)
	world.shortcut_open = true
	player.position = Vector2(27.2, 20.0)

	_push(world, 1, Vector2(0.0, 1.0), 400)

	assert_float(player.position.y) \
		.override_failure_message(
			"Le bord ouest ne passe plus a cote de la premiere masse.") \
		.is_greater(45.0)

## Chaque masse laisse une voie libre a cote d'elle, plus large qu'un joueur.
## C'est la seule chose que cette geometrie DOIVE garantir : une masse posee au
## travers de toute la largeur ferait du raccourci un cul-de-sac, et personne
## ne saurait dire si c'est voulu.
func test_chaque_masse_du_raccourci_laisse_passer() -> void:
	var level: LevelData = load(LEVEL)
	# Le couloir du raccourci, tel qu'il est declare dans le niveau.
	var couloir: Rect2 = Rect2(26.0, 9.0, 7.0, 109.0)
	var masses: int = 0
	for masse: Rect2 in level.obstacles:
		if not couloir.encloses(masse):
			continue
		masses += 1
		var ouest: float = masse.position.x - couloir.position.x
		var est: float = couloir.end.x - masse.end.x
		assert_float(maxf(ouest, est)) \
			.override_failure_message(
				"La masse en z = %.0f ne laisse que %.2f m a l'ouest et "
				% [masse.position.y, ouest]
				+ "%.2f m a l'est : le raccourci est bouche." % est) \
			.is_greater(1.0)
	assert_int(masses) \
		.override_failure_message(
			"Le raccourci n'a plus une seule masse : c'est de nouveau cent "
			+ "neuf metres sans un evenement.") \
		.is_greater_equal(3)

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
	# En plein parvis, loin de tout muret : pose sur un bord, un acteur
	# chevauche le mur et ne peut plus bouger du tout.
	player.position = Vector2(0.0, 14.0)
	enemy.position = Vector2(0.0, 20.0)
	var distance_before: float = enemy.position.distance_to(player.position)
	# La distance doit etre STRICTEMENT sous le rayon d'aggro, sinon le test ne
	# mesure que le hasard du premier pas.
	assert_float(distance_before).is_less(8.0)

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
