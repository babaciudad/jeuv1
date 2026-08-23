## Skins : chaque personnage doit en avoir un, et chaque skin doit porter une
## pièce d'arme.
##
## Ce n'est pas de la cosmétique. La pièce d'arme passe au jaune quand la
## hitbox s'ouvre, et c'est le SEUL repère de rythme du jeu — le tutoriel
## l'enseigne explicitement. Un personnage sans arme visible est illisible en
## combat, et rien d'autre que ce test ne l'empêcherait de passer.
extends GdUnitTestSuite

const CLASSES: Array[String] = [
	"res://data/classes/gardien.tres",
	"res://data/classes/mage.tres",
	"res://data/classes/soigneur.tres",
	"res://data/classes/archer.tres",
]
const ENEMIES: Array[String] = [
	"res://data/actors/gobelin.tres",
	"res://data/actors/warden.tres",
]

func _weapon_parts(skin: SkinData) -> int:
	var count: int = 0
	for part: SkinPart in skin.parts:
		if part.is_weapon:
			count += 1
	return count

func test_chaque_classe_a_un_skin_avec_une_arme() -> void:
	for path: String in CLASSES:
		var fiche: PlayerData = load(path)
		assert_object(fiche).is_not_null()
		var skin: SkinData = SkinLibrary.for_id(fiche.id)
		assert_object(skin) \
			.override_failure_message("Aucun skin pour la classe %s." % fiche.id) \
			.is_not_null()
		assert_int(skin.parts.size()) \
			.override_failure_message("Le skin de %s est vide." % fiche.id) \
			.is_greater(0)
		assert_int(_weapon_parts(skin)) \
			.override_failure_message(
				"Le skin de %s n'a aucune piece d'arme : son rythme sera illisible." % fiche.id) \
			.is_greater(0)

func test_chaque_ennemi_a_un_skin_avec_une_arme() -> void:
	for path: String in ENEMIES:
		var data: EnemyData = load(path)
		assert_object(data).is_not_null()
		var skin: SkinData = SkinLibrary.for_id(data.id)
		assert_object(skin) \
			.override_failure_message("Aucun skin pour %s." % data.id) \
			.is_not_null()
		assert_int(_weapon_parts(skin)) \
			.override_failure_message(
				"Le skin de %s n'a aucune piece d'arme." % data.id) \
			.is_greater(0)

func test_un_identifiant_inconnu_ne_casse_rien() -> void:
	# Un skin manquant doit rendre null, pas planter : la vue retombe alors
	# sur une silhouette par defaut.
	assert_object(SkinLibrary.for_id(&"personne_de_ce_nom")).is_null()
	assert_object(SkinLibrary.for_id(&"")).is_null()

func test_les_pieces_ont_des_dimensions_utilisables() -> void:
	var tout: Array[String] = []
	tout.append_array(CLASSES)
	tout.append_array(ENEMIES)
	for path: String in tout:
		var skin: SkinData = SkinLibrary.for_id(_id_of(path))
		assert_object(skin).is_not_null()
		for part: SkinPart in skin.parts:
			assert_float(part.size.x) \
				.override_failure_message("Piece de dimension nulle dans %s." % path) \
				.is_greater(0.0)
			# Aucune piece ne doit flotter sous le sol.
			assert_float(part.offset.y) \
				.override_failure_message("Piece sous le sol dans %s." % path) \
				.is_greater_equal(0.0)

## L'identifiant d'une fiche, quelle que soit sa nature.
func _id_of(path: String) -> StringName:
	if path.contains("/classes/"):
		var fiche: PlayerData = load(path)
		return fiche.id
	var data: EnemyData = load(path)
	return data.id
