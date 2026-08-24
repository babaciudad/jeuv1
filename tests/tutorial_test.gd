## Tutoriel : les runes doivent etre atteignables, lisibles, et sans doublon.
##
## Une rune posee dans un mur ne se declenche jamais. Rien ne planterait, rien
## n'apparaitrait dans les journaux : le joueur ne saurait simplement jamais
## qu'on avait quelque chose a lui dire. C'est exactement le genre de bug que
## seul un test attrape.
extends GdUnitTestSuite

const LEVEL: String = "res://data/level/vertical_slice.tres"
const DUMMY: String = "res://data/actors/mannequin.tres"

func _level() -> LevelData:
	return load(LEVEL)

func _tutorial() -> TutorialData:
	var level: LevelData = _level()
	var path: String = "res://data/tutorial/%s.tres" % level.id
	assert_bool(ResourceLoader.exists(path)) \
		.override_failure_message("Aucun tutoriel pour le niveau %s." % level.id) \
		.is_true()
	return load(path)

func _walkable(point: Vector2, level: LevelData) -> bool:
	var none: Array[Rect2] = []
	return SimMath.point_is_free(point, level.walkable, none)

func test_chaque_rune_est_dans_la_zone_praticable() -> void:
	var level: LevelData = _level()
	var data: TutorialData = _tutorial()
	assert_int(data.signs.size()).is_greater(0)
	for rune: TutorialSign in data.signs:
		assert_bool(_walkable(rune.position, level)) \
			.override_failure_message(
				"La rune %s est en (%.1f, %.1f), hors du praticable : "
				% [rune.id, rune.position.x, rune.position.y]
				+ "elle ne se declenchera jamais.") \
			.is_true()

func test_chaque_rune_a_un_texte_et_un_rayon() -> void:
	for rune: TutorialSign in _tutorial().signs:
		assert_str(rune.line) \
			.override_failure_message("La rune %s n'a pas de texte." % rune.id) \
			.is_not_empty()
		assert_float(rune.radius) \
			.override_failure_message("La rune %s a un rayon nul." % rune.id) \
			.is_greater(0.5)

func test_les_identifiants_de_runes_sont_uniques() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for rune: TutorialSign in _tutorial().signs:
		assert_bool(seen.has(rune.id)) \
			.override_failure_message("Deux runes portent l'identifiant %s." % rune.id) \
			.is_false()
		seen[rune.id] = true

## Les gestes qui coutent la vie doivent tous etre enseignes. Ajouter une
## mecanique sans sa rune, c'est la laisser se decouvrir dans le couloir.
func test_les_gestes_essentiels_sont_tous_enseignes() -> void:
	var taught: Dictionary[int, bool] = {}
	for rune: TutorialSign in _tutorial().signs:
		taught[rune.condition] = true
	var required: Array[TutorialSign.Condition] = [
		TutorialSign.Condition.LOOK,
		TutorialSign.Condition.MOVE,
		TutorialSign.Condition.DODGE,
		TutorialSign.Condition.ATTACK,
		TutorialSign.Condition.SECOND,
		TutorialSign.Condition.REST,
		TutorialSign.Condition.SHORTCUT,
	]
	for condition: TutorialSign.Condition in required:
		assert_bool(taught.has(condition)) \
			.override_failure_message(
				"Aucune rune n'enseigne la condition %d." % condition) \
			.is_true()

## Le mannequin est le seul adversaire inoffensif du jeu. S'il gagnait une
## attaque ou un rayon d'aggro, il tuerait le joueur pendant le tutoriel.
func test_le_mannequin_ne_peut_blesser_personne() -> void:
	var dummy: EnemyData = load(DUMMY)
	assert_object(dummy).is_not_null()
	assert_bool(dummy.is_training_dummy).is_true()
	assert_bool(dummy.is_boss).is_false()
	assert_int(dummy.attacks.size()) \
		.override_failure_message("Le mannequin a une attaque : il peut tuer.") \
		.is_equal(0)
	assert_float(dummy.aggro_radius) \
		.override_failure_message("Le mannequin a un rayon d'aggro : il poursuivra.") \
		.is_equal(0.0)
	assert_int(dummy.dummy_revive_ticks) \
		.override_failure_message("Un mannequin qui ne se releve pas ne sert qu'une fois.") \
		.is_greater(0)

func test_le_mannequin_est_pose_dans_la_nef() -> void:
	var level: LevelData = _level()
	assert_bool(level.training_dummy_position != Vector2.ZERO) \
		.override_failure_message("Aucun mannequin : le tutoriel n'a rien a frapper.") \
		.is_true()
	assert_bool(_walkable(level.training_dummy_position, level)) \
		.override_failure_message("Le mannequin est dans un mur.") \
		.is_true()

## Il se releve tout seul, et il ne compte jamais comme un ennemi vaincu.
func test_le_mannequin_se_releve() -> void:
	var world: World = World.new(self)
	world.authority = World.Authority.HOST
	var classes: Array[PlayerData] = []
	for path: String in NetBootstrap.CLASS_PATHS:
		classes.append(load(path))
	var enemies: Array[EnemyData] = [
		load("res://data/actors/gobelin.tres"),
		load("res://data/actors/warden.tres"),
		load(DUMMY),
	]
	world.configure(_level(), classes, enemies)
	world.spawn_enemies()

	var dummy: Actor = null
	for enemy: Actor in world.enemies():
		var data: EnemyData = world.data_for(enemy)
		if data != null and data.is_training_dummy:
			dummy = enemy
			break
	assert_object(dummy) \
		.override_failure_message("Le mannequin n'a pas ete cree.") \
		.is_not_null()

	dummy.health = 0
	dummy.enter_state(Actor.State.DEAD, world.tick)
	var fiche: EnemyData = load(DUMMY)
	var revive: int = fiche.dummy_revive_ticks
	for _i: int in revive + 5:
		world.step(world.tick + 1, [])
	assert_bool(dummy.is_alive()) \
		.override_failure_message("Le mannequin ne s'est pas releve.") \
		.is_true()
	assert_int(dummy.health).is_equal(dummy.max_health)

	for actor_id: int in world.actors.keys():
		world.remove_actor(actor_id)
