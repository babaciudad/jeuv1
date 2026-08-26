## Le cone que la simulation resout doit correspondre a ce que le fer balaie.
##
## C'est LE contrat d'un souls-like : tu meurs de tes erreurs, pas de celles du
## jeu. Mesure faite en jeu par `tools/frappe.gd`, sur l'epee du gardien :
##
##   passe 1 : fer de 1,35 a 1,80 m, balaie de +0 a +63 degres
##   passe 2 : fer de 1,22 a 1,82 m, balaie de +0 a +57 degres
##   fiche   : portee 2,60 m, demi-angle 60 degres, aucun decalage
##
## Deux passes independantes, qui s'accordent : le fer va a 1,8 m et balaie une
## trentaine de degres de part et d'autre de +30.
##
## Deux ecarts, tous deux visibles a l'ecran. La portee : la simulation
## touchait jusqu'a 2,60 m PLUS le rayon de la cible, soit trois metres, quand
## le fer va a 1,80 — on tuait un ennemi un metre au-dela de son epee. L'arc :
## le cone etait symetrique autour du cap alors que le coup est DIAGONAL, si
## bien que la moitie du cone frappait du cote ou le fer ne passe jamais.
##
## Ce test tient les deux bouts. Il ne remesure pas l'animation — cela demande
## un contexte de rendu, et la suite tourne sans — il verifie que les fiches
## declarent ce qui a ete mesure, et que le decalage d'arc fait vraiment ce
## qu'il dit.
extends GdUnitTestSuite

## Portee du fer mesuree en jeu, par geste, en metres.
const FER: Dictionary = {
	"gardien_lourd": 1.82,
}
## Balayage mesure en jeu : centre et demi-ouverture, en degres.
const BALAYAGE: Dictionary = {
	"gardien_lourd": Vector2(30.0, 30.0),
}
## Ce qu'on s'autorise en plus du fer, en metres. Un souls-like pardonne un
## peu — sinon on rate un coup qui a l'air d'avoir touche — mais un peu
## seulement : au-dela, c'est le jeu qui frappe, pas le joueur.
const INDULGENCE_PORTEE: float = 0.25
## Idem sur l'angle, en degres.
const INDULGENCE_ANGLE: float = 8.0

func test_les_fiches_ne_portent_pas_plus_loin_que_le_fer() -> void:
	for nom: String in FER.keys():
		var fiche: AttackData = load("res://data/attacks/%s.tres" % nom)
		assert_that(fiche).is_not_null()
		var mesure: float = FER[nom]
		assert_float(fiche.range_meters).is_less_equal(
			mesure + INDULGENCE_PORTEE)

func test_les_fiches_couvrent_le_balayage_sans_le_deborder() -> void:
	for nom: String in BALAYAGE.keys():
		var fiche: AttackData = load("res://data/attacks/%s.tres" % nom)
		assert_that(fiche).is_not_null()
		var mesure: Vector2 = BALAYAGE[nom]
		# Le cone est centre sur le balayage, a l'indulgence pres.
		assert_float(absf(fiche.arc_offset_degrees - mesure.x)).is_less_equal(
			INDULGENCE_ANGLE)
		assert_float(fiche.half_angle_degrees).is_less_equal(
			mesure.y + INDULGENCE_ANGLE)

func test_le_decalage_d_arc_deplace_vraiment_le_cone() -> void:
	var origine: Vector2 = Vector2.ZERO
	var cap: Vector2 = Vector2(0.0, 1.0)
	# Une cible a 45 degres a gauche, a un metre et demi.
	var cible: Vector2 = Vector2(0.0, 1.5).rotated(deg_to_rad(45.0))
	# Cone etroit centre sur le cap : elle est dehors.
	assert_bool(SimMath.cone_contains(origine, cap, 2.0, 20.0, cible, 0.0,
		0.0)).is_false()
	# Le meme cone, decale de 45 degres : elle est dedans.
	assert_bool(SimMath.cone_contains(origine, cap, 2.0, 20.0, cible, 0.0,
		45.0)).is_true()
	# Et decale du meme angle DANS L'AUTRE SENS, elle ressort — sans quoi le
	# decalage ne ferait qu'elargir le cone au lieu de le tourner.
	assert_bool(SimMath.cone_contains(origine, cap, 2.0, 20.0, cible, 0.0,
		-45.0)).is_false()
