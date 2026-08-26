## Les fiches de modèles : noms de clips, vitesses au sol, instants de contact.
##
## Ces trois familles de nombres étaient toutes fausses en même temps, et rien
## ne le disait — un nom de clip inconnu ne lève rien dans Godot, une vitesse
## fausse se voit seulement en jouant, et un contact désaligné passe pour un
## défaut de « feeling ». Ce fichier les vérifie une fois pour toutes.
extends GdUnitTestSuite

const IDS: Array[String] = ["gardien", "archer", "mage", "soigneur",
	"gobelin", "mannequin", "warden"]
## Vitesses simulées, lues dans data/classes et data/actors. Un modèle dont la
## course est plus lente que le personnage force le mélangeur à accélérer le
## film, et les pieds repartent en patinage.
const VITESSES: Dictionary = {
	"gardien": 4.2, "archer": 5.3, "mage": 4.8, "soigneur": 4.9,
	"gobelin": 3.4, "warden": 3.4,
}

func _lecteur(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _lecteur(child)
		if found != null:
			return found
	return null

## Monte le corps et sa bibliothèque d'appoint, comme le fait SaltAnimator.
func _banc(model: ModelData) -> AnimationPlayer:
	var corps: Node = auto_free(model.scene.instantiate())
	add_child(corps)
	var lecteur: AnimationPlayer = _lecteur(corps)
	if lecteur == null or model.extra_animations == null:
		return lecteur
	var appoint: Node = auto_free(model.extra_animations.instantiate())
	var source: AnimationPlayer = _lecteur(appoint)
	if source == null:
		return lecteur
	for nom: StringName in source.get_animation_library_list():
		lecteur.add_animation_library(model.extra_prefix,
			source.get_animation_library(nom))
		break
	return lecteur

func _modeles() -> Array[ModelData]:
	var out: Array[ModelData] = []
	for id: String in IDS:
		var model: ModelData = load("res://models/%s.tres" % id)
		assert_object(model).is_not_null()
		out.append(model)
	return out

## Tout clip nommé dans une fiche doit exister. Le gardien et le boss ont vécu
## des jours sans animation de marche parce que la leur s'appelait
## « Walk_Large » au lieu de « plus/Walk_Large », et jouer une animation
## absente ne lève rien.
func test_tous_les_clips_existent() -> void:
	for model: ModelData in _modeles():
		var lecteur: AnimationPlayer = _banc(model)
		assert_object(lecteur).is_not_null()
		var noms: Array[StringName] = [model.idle, model.walk, model.run,
			model.walk_back, model.strafe_left, model.strafe_right,
			model.dodge, model.hurt, model.hurt_alt, model.death,
			model.death_alt, model.attack]
		for clip: StringName in model.attack_clips.values():
			noms.append(clip)
		for clip: StringName in noms:
			assert_bool(lecteur.has_animation(clip)) \
				.override_failure_message("%s : clip absent « %s »"
					% [model.id, clip]).is_true()

## La course d'un modèle doit être au moins aussi rapide que le personnage.
## En dessous, le mélangeur n'a plus de clip assez rapide et accélère le film,
## ce qui est exactement le patinage qu'on cherche à éviter.
func test_la_course_couvre_la_vitesse_du_personnage() -> void:
	for id: String in VITESSES.keys():
		var model: ModelData = load("res://models/%s.tres" % id)
		var vitesse: float = VITESSES[id]
		assert_float(model.run_clip_speed) \
			.override_failure_message(
				"%s court a %.1f m/s mais son clip n'en produit que %.2f"
				% [id, vitesse, model.run_clip_speed]) \
			.is_greater_equal(vitesse * 0.95)

## Une course ne doit pas être BEAUCOUP plus rapide que le personnage non plus.
##
## Le test précédent pose le plancher ; celui-ci pose le plafond, et il a été
## écrit après coup, une mesure en jeu à la main. Le cristallisé a reçu une
## course voûtée qui lui allait parfaitement — « Run_Stealth », posture juste —
## sauf qu'elle court à 8,46 m/s pour un personnage qui en fait 3,40. Le
## mélangeur la dose alors à un tiers contre deux tiers de pas de zombie, et
## deux clips dont les vitesses sont dans un rapport de neuf n'ont plus aucune
## phase commune : les jambes se compensent au lieu de s'ajouter, et le pied
## d'appui n'a plus reculé qu'à 1,11 m/s au lieu de 3,40. Soit 67 % de
## patinage, invisible partout ailleurs que dans une mesure en rendu.
##
## Un point de mélange trop loin devant est donc aussi faux qu'un point trop
## près : il faut que la course soit à PORTÉE de l'allure du personnage.
func test_la_course_n_est_pas_hors_de_portee() -> void:
	for id: String in VITESSES.keys():
		var model: ModelData = load("res://models/%s.tres" % id)
		var vitesse: float = VITESSES[id]
		assert_float(model.run_clip_speed) \
			.override_failure_message(
				"%s court a %.1f m/s mais son clip en produit %.2f : le melange"
				% [id, vitesse, model.run_clip_speed]
				+ " n'aura plus de phase commune et les pieds patineront") \
			.is_less_equal(vitesse * 1.6)

## Toute animation d'attente doit tenir DEBOUT.
##
## Le rig apporte des poses au sol — « Tired Hunched » met le bassin a quarante
## centimetres, « Kneeling Tired » a quarante et un — et rien ne distingue leur
## nom de celui d'une attente ordinaire. Le mannequin d'entrainement a passe
## une version couche par terre a cause de ca, et une autre en croix parce que
## « Rest Pose » est la pose en T du rig.
func test_les_attentes_tiennent_debout() -> void:
	for id: String in IDS:
		var model: ModelData = load("res://models/%s.tres" % id)
		var lecteur: AnimationPlayer = _banc(model)
		var os: Skeleton3D = _squelette(lecteur.get_parent())
		if os == null:
			os = _squelette(lecteur.get_node(lecteur.root_node))
		assert_object(os).is_not_null()
		var chemin: String = ClipMeasure.prefix_for(lecteur, os)
		var bassin: int = os.find_bone("pelvis")
		var tete: int = os.find_bone("head")
		var main: int = os.find_bone("hand_l")
		if not lecteur.has_animation(model.idle):
			continue
		var anim: Animation = lecteur.get_animation(model.idle)
		var pose: Array[Transform3D] = ClipMeasure.poses(
			os, chemin, anim, anim.length * 0.4)
		assert_float(pose[bassin].origin.y) \
			.override_failure_message("%s : bassin a %.2f m dans « %s »"
				% [id, pose[bassin].origin.y, model.idle]) \
			.is_greater(0.70)
		assert_float(pose[tete].origin.y) \
			.override_failure_message("%s : tete a %.2f m dans « %s »"
				% [id, pose[tete].origin.y, model.idle]) \
			.is_greater(1.15)
		# Et pas en croix : la pose en T du rig ecarte la main de 74 cm.
		assert_float(absf(pose[main].origin.x)) \
			.override_failure_message("%s : bras en croix dans « %s »"
				% [id, model.idle]) \
			.is_less(0.55)

## Marche strictement plus lente que course, et les deux non nulles : deux
## points de mélange au même endroit rendent le mélange indéfini.
func test_les_allures_sont_ordonnees() -> void:
	for id: String in VITESSES.keys():
		var model: ModelData = load("res://models/%s.tres" % id)
		assert_float(model.walk_clip_speed).is_greater(0.2)
		assert_float(model.run_clip_speed) \
			.is_greater(model.walk_clip_speed + 0.3)
		assert_float(model.back_clip_speed).is_greater(0.2)
		assert_float(model.strafe_clip_speed).is_greater(0.2)

func _squelette(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _squelette(child)
		if found != null:
			return found
	return null

## Les nombres écrits dans les fiches doivent correspondre aux clips.
##
## C'est LE test de non-régression de tout ce dossier : `make_models` et ce
## test appellent le même `ClipMeasure`, donc une fiche modifiée à la main, un
## clip remplacé sans régénérer, ou un rig aux proportions retouchées font
## échouer ici au lieu de sortir en jeu sous forme de pieds qui patinent.
func test_les_fiches_correspondent_aux_clips() -> void:
	for id: String in IDS:
		var model: ModelData = load("res://models/%s.tres" % id)
		var lecteur: AnimationPlayer = _banc(model)
		assert_object(lecteur).is_not_null()
		var os: Skeleton3D = _squelette(lecteur.get_parent())
		if os == null:
			os = _squelette(lecteur.get_node(lecteur.root_node))
		assert_object(os).is_not_null()
		var chemin: String = ClipMeasure.prefix_for(lecteur, os)
		var bassin: int = os.find_bone("pelvis")
		var gauche: int = os.find_bone("ball_l")
		var droite: int = os.find_bone("ball_r")
		var main: int = os.find_bone("hand_r")
		assert_int(bassin).is_greater_equal(0)
		assert_int(gauche).is_greater_equal(0)
		assert_int(main).is_greater_equal(0)
		var paires: Array = [
			[model.walk, model.walk_clip_speed, "marche"],
			[model.run, model.run_clip_speed, "course"],
			[model.walk_back, model.back_clip_speed, "recul"],
		]
		for paire: Array in paires:
			var clip: StringName = paire[0]
			var declare: float = paire[1]
			if not lecteur.has_animation(clip):
				continue
			var mesure: float = ClipMeasure.ground_speed(os, chemin,
				lecteur.get_animation(clip), bassin, gauche, droite)
			assert_float(absf(mesure - declare)) \
				.override_failure_message(
					"%s %s (%s) : fiche %.2f m/s, clip %.2f m/s"
					% [id, paire[2], clip, declare, mesure]) \
				.is_less(0.05)
		for clip: StringName in model.attack_contact.keys():
			if not lecteur.has_animation(clip):
				continue
			var declare: float = model.attack_contact[clip]
			var mesure: float = ClipMeasure.contact_time(os, chemin,
				lecteur.get_animation(clip), bassin, main)
			assert_float(absf(mesure - declare)) \
				.override_failure_message(
					"%s contact de %s : fiche %.3f s, clip %.3f s"
					% [id, clip, declare, mesure]) \
				.is_less(0.01)

## Chaque geste d'attaque doit pouvoir montrer son contact à l'instant où la
## hitbox s'ouvre. C'est ce qui distingue un coup qui porte d'un coup mou.
##
## Le mélangeur y arrive en jouant le clip à `contact / ouverture`. Cette
## vitesse est bornée à [0,25 ; 4] — au-delà, le geste serait illisible — et
## c'est donc la BORNE qu'il faut surveiller : tant qu'elle ne mord pas,
## l'alignement est exact par construction. Un clip dont le contact tombe à
## 96 % de sa durée face à une hitbox qui s'ouvre à 12 % demanderait un
## facteur 8, et le coup repartirait de plusieurs centaines de millisecondes.
func test_le_contact_tombe_sur_la_hitbox() -> void:
	var dossier: DirAccess = DirAccess.open("res://data/attacks")
	assert_object(dossier).is_not_null()
	var vus: int = 0
	for fichier: String in dossier.get_files():
		if not fichier.ends_with(".tres"):
			continue
		var attaque: AttackData = load("res://data/attacks/%s" % fichier)
		if attaque == null or attaque.timeline == null:
			continue
		var ouverture: float = SaltAnimator._hitbox_opening(attaque)
		if ouverture <= 0.001:
			continue
		for model: ModelData in _modeles():
			if not model.attack_clips.has(attaque.id):
				continue
			var clip: StringName = model.attack_clips[attaque.id]
			if not model.attack_contact.has(clip):
				continue
			var contact: float = model.attack_contact[clip]
			assert_float(contact).is_greater(0.001)
			var tempo: float = contact / ouverture
			vus += 1
			assert_float(tempo) \
				.override_failure_message(
					"%s (%s) : il faudrait lire le clip a %.2f fois sa vitesse"
					% [attaque.id, clip, tempo]).is_between(0.25, 4.0)
	assert_int(vus).is_greater(5)

# ---------------------------------------------------------------------------
# Le mélangeur : demi-tour sur place, arrêt franc, enchaînement
# ---------------------------------------------------------------------------
#
# Ces trois-là ne se voient pas sur une fiche : ils vivent dans le pilotage de
# l'arbre. On monte donc un animateur complet et on le pilote image par image,
# exactement comme la vue le fait, puis on relit le mélange qu'il a posé.

const IMAGE: float = 1.0 / 60.0
## Régime d'un demi-tour dans ce jeu : 12 degrés par tick, soit 720 par
## seconde. C'est la valeur de `turn_degrees_per_tick`, et elle monte à 19,2
## quand on est verrouillé.
const TOUR_PAR_TICK: float = 12.0

## Monte un animateur sur un rig, comme le fait la vue.
func _animateur(id: String) -> SaltAnimator:
	var model: ModelData = load("res://models/%s.tres" % id)
	var rig: Node = auto_free(model.scene.instantiate())
	add_child(rig)
	return SaltAnimator.build(rig as Node3D, model)

## Fait tourner le cap sans avancer d'un centimètre, et relit le mélange.
func _pivoter(animateur: SaltAnimator, degres_par_tick: float,
		images: int) -> Vector2:
	var cap: Vector2 = Vector2(0.0, 1.0)
	for image: int in images:
		animateur.tick_freeze(IMAGE)
		animateur._drive_ground(Vector2.ZERO, cap)
		# `rotated` d'un angle NÉGATIF tourne vers la droite du personnage :
		# l'axe latéral du mélange y est positif.
		cap = cap.rotated(-deg_to_rad(degres_par_tick))
	return animateur.ground_blend()

## DEMI-TOUR SUR PLACE. Un personnage qui pivote sans avancer doit remuer les
## pieds : sans ça le corps tourne et la pose reste plantée, ce qui est le
## défaut qu'on remarque en premier dans un souls-like.
func test_le_demi_tour_remue_les_pieds() -> void:
	var animateur: SaltAnimator = _animateur("gardien")
	assert_bool(animateur.ready()).is_true()
	var droite: Vector2 = _pivoter(animateur, TOUR_PAR_TICK, 20)
	assert_float(droite.x) \
		.override_failure_message(
			"pivot a droite : le melange lateral vaut %.3f m/s" % droite.x) \
		.is_greater(0.3)
	# Un pivot n'AVANCE pas : l'axe de face doit rester à zéro.
	assert_float(absf(droite.y)).is_less(0.01)
	# Et le pivot inverse remue les pieds dans l'autre sens.
	var gauche: Vector2 = _pivoter(_animateur("gardien"), -TOUR_PAR_TICK, 20)
	assert_float(gauche.x) \
		.override_failure_message(
			"pivot a gauche : le melange lateral vaut %.3f m/s" % gauche.x) \
		.is_less(-0.3)

## Un cap IMMOBILE ne doit rien remuer du tout. Sans ce garde-fou, le moindre
## tremblement de cap ferait piétiner un personnage à l'arrêt en permanence.
func test_un_cap_immobile_ne_pivote_pas() -> void:
	var animateur: SaltAnimator = _animateur("gardien")
	var fixe: Vector2 = _pivoter(animateur, 0.0, 20)
	assert_float(fixe.length()) \
		.override_failure_message(
			"a l'arret, cap fixe : le melange vaut %.3f m/s" % fixe.length()) \
		.is_less(0.01)

## ARRÊT FRANC. Le passage de la course à l'attente était un simple retour du
## mélange à l'origine : la pose sautait de la foulée à l'attente en une image.
## On veut un temps d'arrêt — la foulée TIENT, la cadence tombe — puis un
## retour propre à l'attente.
func test_l_arret_franc_tient_la_foulee() -> void:
	var animateur: SaltAnimator = _animateur("gardien")
	var cap: Vector2 = Vector2(0.0, 1.0)
	for image: int in 12:
		animateur.tick_freeze(IMAGE)
		animateur._drive_ground(Vector2(0.0, 4.2), cap)
	assert_float(animateur.ground_blend().y).is_greater(3.0)
	# Première image à l'arrêt : la foulée doit tenir, pas disparaître.
	animateur.tick_freeze(IMAGE)
	animateur._drive_ground(Vector2.ZERO, cap)
	assert_float(animateur.ground_blend().y) \
		.override_failure_message(
			"arret : la foulee est tombee a %.2f des la premiere image"
			% animateur.ground_blend().y).is_greater(3.0)
	# ... et les appuis se figent, au lieu de continuer à pédaler.
	assert_float(animateur.ground_scale()) \
		.override_failure_message("arret : la cadence vaut %.2f"
			% animateur.ground_scale()).is_less(0.2)
	# Puis, le temps d'arrêt passé, on revient bel et bien à l'attente.
	for image: int in 30:
		animateur.tick_freeze(IMAGE)
		animateur._drive_ground(Vector2.ZERO, cap)
	assert_float(animateur.ground_blend().length()) \
		.override_failure_message(
			"apres l'arret, le melange devrait etre nul, il vaut %.3f"
			% animateur.ground_blend().length()).is_less(0.01)

## Un arrêt depuis la MARCHE ne se plante pas : on ne marque que ce qui pesait.
func test_un_arret_de_marche_ne_se_plante_pas() -> void:
	var animateur: SaltAnimator = _animateur("gardien")
	var cap: Vector2 = Vector2(0.0, 1.0)
	for image: int in 12:
		animateur.tick_freeze(IMAGE)
		animateur._drive_ground(Vector2(0.0, 0.6), cap)
	animateur.tick_freeze(IMAGE)
	animateur._drive_ground(Vector2.ZERO, cap)
	assert_float(animateur.ground_blend().length()) \
		.override_failure_message(
			"arret de marche : le melange vaut %.3f au lieu de zero"
			% animateur.ground_blend().length()).is_less(0.01)

## ENCHAÎNEMENT. Le deuxième coup d'une combo ne doit pas rejouer le geste du
## premier.
##
## Le geste ne se déclenchait que sur le front « ne frappait pas » -> « frappe ».
## Une fenêtre d'annulation laisse le deuxième coup partir AVANT que le premier
## soit fini : le front n'existe alors pas, et toute la combo ne montrait qu'un
## seul geste, celui d'ouverture, au tempo d'ouverture.
func test_un_enchainement_change_de_geste() -> void:
	var animateur: SaltAnimator = _animateur("gardien")
	var acteur: Actor = Actor.new()
	var runner: AttackRunner = auto_free(AttackRunner.new())
	add_child(runner)
	acteur.runner = runner
	acteur.state = Actor.State.ATTACKING
	var lourd: AttackData = load("res://data/attacks/gardien_lourd.tres")
	var rapide: AttackData = load("res://data/attacks/gardien_rapide.tres")
	assert_object(lourd).is_not_null()
	assert_object(rapide).is_not_null()

	assert_bool(runner.start(lourd)).is_true()
	animateur.tick_freeze(IMAGE)
	animateur.drive(acteur, Vector2.ZERO, Vector2(0.0, 1.0))
	var premier: StringName = animateur.attack_clip()
	assert_str(premier).is_not_empty()

	# Le deuxième coup part alors que le premier N'EST PAS fini : c'est le cas
	# qui ne marchait pas.
	runner.advance_tick()
	assert_bool(runner.finished).is_false()
	assert_bool(runner.start(rapide)).is_true()
	animateur.tick_freeze(IMAGE)
	animateur.drive(acteur, Vector2.ZERO, Vector2(0.0, 1.0))
	assert_str(animateur.attack_clip()) \
		.override_failure_message(
			"enchainement : le deuxieme coup rejoue « %s »" % premier) \
		.is_not_equal(premier)

## Le MÊME coup relancé deux fois de suite doit lui aussi repartir : son
## identifiant ne change pas, seul son avancement le trahit.
func test_le_meme_coup_relance_repart() -> void:
	var animateur: SaltAnimator = _animateur("gardien")
	var acteur: Actor = Actor.new()
	var runner: AttackRunner = auto_free(AttackRunner.new())
	add_child(runner)
	acteur.runner = runner
	acteur.state = Actor.State.ATTACKING
	var lourd: AttackData = load("res://data/attacks/gardien_lourd.tres")
	assert_bool(runner.start(lourd)).is_true()
	for tick: int in 3:
		runner.advance_tick()
	animateur.tick_freeze(IMAGE)
	animateur.drive(acteur, Vector2.ZERO, Vector2(0.0, 1.0))
	assert_int(runner.elapsed_ticks).is_greater(0)
	# Le geste est parti UNE fois, et rester dans la même attaque ne le relance
	# pas : une attaque qui se redéclenche à chaque image ne montrerait jamais
	# autre chose que sa première pose.
	assert_int(animateur.attack_fires()).is_equal(1)
	animateur.tick_freeze(IMAGE)
	animateur.drive(acteur, Vector2.ZERO, Vector2(0.0, 1.0))
	assert_int(animateur.attack_fires()).is_equal(1)

	# Relance du MÊME coup : le dérouleur repart à zéro tick sans jamais passer
	# par `finished`, et l'identifiant, lui, ne bouge pas d'un iota. Seul
	# l'avancement le trahit.
	assert_bool(runner.start(lourd)).is_true()
	assert_int(runner.elapsed_ticks).is_equal(0)
	animateur.tick_freeze(IMAGE)
	animateur.drive(acteur, Vector2.ZERO, Vector2(0.0, 1.0))
	assert_int(animateur.attack_fires()) \
		.override_failure_message(
			"le meme coup relance n'a pas rejoue son geste") \
		.is_equal(2)
