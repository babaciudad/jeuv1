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
