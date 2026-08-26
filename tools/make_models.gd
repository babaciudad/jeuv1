## Génère les fiches ModelData des personnages.
##
##   godot --headless --path . -s tools/make_models.gd
##
## Tous les personnages partagent UN SEUL corps et UNE SEULE bibliothèque de
## mouvements : le rig humain de Mesh2Motion (CC0), 66 os, 162 clips, un
## maillage skinné de treize mille triangles à proportions adultes. Ce qui les
## distingue est le COSTUME (bâti dans SaltBody) et le CHOIX DES CLIPS.
##
## C'est ce partage qui permet d'avoir six personnages pour onze mégaoctets,
## là où six modèles séparés en coûtaient vingt-quatre pour six squelettes
## identiques.
extends SceneTree

const CORPS: String = "res://models/humain/gestes_base.glb"
const GESTES_PLUS: String = "res://models/humain/gestes_plus.glb"


## Un personnage : identifiant, repos, marche, course, esquive, encaissement,
## chute, et le geste de chaque attaque.
const CAST: Array[Dictionary] = [
	{
		"id": "gardien",
		"repos": "Idle_Sword", "marche": "plus/Walk_Large",
		"course": "Jog",
		"chute": "Death_D", "chute_bis": "plus/Death_A",
		"gestes": {
			"gardien_lourd": "Sword_Regular_C",
			"gardien_rapide": "Sword_Regular_A",
		},
	},
	{
		"id": "archer",
		"repos": "Idle_A", "marche": "Walk",
		"course": "Sprint",
		"chute": "plus/Death_B", "chute_bis": "Death_D",
		"gestes": {
			"archer_dague": "Sword_Regular_B",
			"archer_fleche": "plus/Bow Release",
		},
	},
	{
		"id": "mage",
		"repos": "Spell_Simple_Idle", "marche": "Walk",
		"course": "Jog",
		"chute": "plus/Death_C", "chute_bis": "plus/Death_B",
		"gestes": {
			"mage_baton": "Sword_Regular_B",
			"mage_trait": "Spell_Simple_Shoot",
		},
	},
	{
		"id": "soigneur",
		"repos": "Idle_A", "marche": "Walk_Formal",
		"course": "plus/Run_Anime",
		"chute": "plus/Death_B", "chute_bis": "plus/Death_C",
		"gestes": {
			"soigneur_lame": "Sword_Regular_A",
			"soigneur_soin": "plus/Two-hand Blast",
		},
	},
	{
		# Le cristallisé ne marche pas comme un vivant : le rig apporte tout un
		# jeu de clips de mort-vivant, et c'est ce qui le sépare des joueurs
		# au premier coup d'œil, de loin, sans lire une barre de vie.
		"id": "gobelin",
		"repos": "Zombie_Idle", "marche": "Zombie_Walk",
		"course": "plus/Run_Female",
		"chute": "Death_D", "chute_bis": "plus/Death_C",
		"gestes": {
			"gobelin_coup": "Zombie_Scratch",
		},
	},
	{
		# Le mannequin d'entrainement etait reste en primitives : au milieu de
		# personnages a corps skinne, il ressortait comme un jouet oublie.
		"id": "mannequin",
		"repos": "plus/Rest Pose", "marche": "plus/Rest Pose",
		"course": "plus/Rest Pose",
		"chute": "plus/Death_B", "chute_bis": "Death_D",
		"gestes": {},
	},
	{
		"id": "warden",
		"repos": "plus/Fighting Idle", "marche": "plus/Walk_Large",
		"course": "plus/Run_Female",
		"chute": "plus/Death_A", "chute_bis": "Death_D",
		"gestes": {
			"boss_swing": "Sword_Regular_C",
			"boss_slam": "plus/Attack_Ground_Pound",
		},
	},
]

## Tous les noms de clips réellement disponibles : ceux de `gestes_base` tels
## quels, ceux de `gestes_plus` préfixés comme le fera `SaltAnimator._graft`.
##
## Cette table existe parce qu'on a livré pendant des jours un gardien et un
## boss SANS ANIMATION DE MARCHE : leur clip était noté `Walk_Large`, qui
## n'existe que dans la bibliothèque d'appoint et s'appelle donc
## `plus/Walk_Large`. Un nom de clip inconnu ne lève rien — ni à la
## génération, ni au chargement, ni à la lecture : `AnimationPlayer.play()`
## sur un nom absent se contente de ne rien faire. Le personnage glissait au
## sol en position de repos, et rien nulle part ne le disait.
##
## Désormais un nom inconnu arrête la génération.
var _connus: Dictionary[StringName, bool] = {}

# ---------------------------------------------------------------------------
# Mesure de la vitesse au sol d'un clip
# ---------------------------------------------------------------------------
#
# Un clip de locomotion est animé SUR PLACE : le personnage ne bouge pas, mais
# son pied d'appui recule sous lui. La vitesse à laquelle il recule est
# exactement celle à laquelle le personnage est censé avancer. On la mesure
# donc directement sur le clip, au lieu de la saisir à la main — ce qui donnait
# des erreurs d'un facteur cinq et rendait les pas catastrophiques.
#
# On n'utilise pas l'AnimationPlayer pour poser le squelette : hors boucle de
# rendu il ne pose rien du tout, et toutes les mesures sortent égales à la pose
# de repos, sans le moindre signe que quelque chose cloche. On compose donc la
# chaîne d'os à la main, à partir des pistes du clip.

var _os: Skeleton3D = null
var _chemin: String = ""
var _bassin: int = -1
var _pieds: Array[int] = []

func _squelette(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _squelette(child)
		if found != null:
			return found
	return null

## Transformées globales de tous les os, pour un clip à un instant donné.
func _poses(anim: Animation, temps: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	out.resize(_os.get_bone_count())
	for index: int in _os.get_bone_count():
		var repos: Transform3D = _os.get_bone_rest(index)
		var voie: NodePath = NodePath(
			_chemin + ":" + _os.get_bone_name(index))
		var position: Vector3 = repos.origin
		var rotation: Quaternion = repos.basis.get_rotation_quaternion()
		var echelle: Vector3 = repos.basis.get_scale()
		var tp: int = anim.find_track(voie, Animation.TYPE_POSITION_3D)
		var tr: int = anim.find_track(voie, Animation.TYPE_ROTATION_3D)
		var te: int = anim.find_track(voie, Animation.TYPE_SCALE_3D)
		if tp >= 0:
			position = anim.position_track_interpolate(tp, temps)
		if tr >= 0:
			rotation = anim.rotation_track_interpolate(tr, temps)
		if te >= 0:
			echelle = anim.scale_track_interpolate(te, temps)
		var locale: Transform3D = Transform3D(
			Basis(rotation).scaled(echelle), position)
		var parent: int = _os.get_bone_parent(index)
		out[index] = locale if parent < 0 else out[parent] * locale
	return out

## Vitesse au sol d'un clip, en mètres par seconde. Zéro si le clip est absent
## ou n'a pas de pied d'appui identifiable.
func _vitesse(lecteur: AnimationPlayer, nom: String) -> float:
	if _os == null or _bassin < 0 or not lecteur.has_animation(nom):
		return 0.0
	var anim: Animation = lecteur.get_animation(nom)
	var duree: float = anim.length
	if duree <= 0.01:
		return 0.0
	const PAS: int = 192
	# Premier passage : où est le sol dans ce clip. On ne peut pas le supposer
	# à zéro — un cycle de course fait descendre le bassin, et la hauteur du
	# pied posé varie d'un clip à l'autre.
	var sol: float = 1e9
	var bas: Array[Vector3] = []
	var hauts: Array[Vector3] = []
	var bassins: Array[Vector3] = []
	bas.resize(PAS + 1)
	hauts.resize(PAS + 1)
	bassins.resize(PAS + 1)
	var appuis: Array[int] = []
	appuis.resize(PAS + 1)
	for index: int in PAS + 1:
		var poses: Array[Transform3D] = _poses(
			anim, duree * float(index) / float(PAS))
		var gauche: Vector3 = poses[_pieds[0]].origin
		var droite: Vector3 = poses[_pieds[1]].origin
		var porte: int = 0 if gauche.y <= droite.y else 1
		appuis[index] = porte
		bas[index] = gauche if porte == 0 else droite
		hauts[index] = droite if porte == 0 else gauche
		bassins[index] = poses[_bassin].origin
		sol = minf(sol, bas[index].y)
	# Second passage : on n'intègre QUE pendant l'appui.
	#
	# Sans ce filtre, la mesure est fausse d'un bon quart : pendant l'envol
	# d'une foulée de course, le pied « le plus bas » est en train de revenir
	# vers l'avant, et son déplacement se soustrait de ce qu'on veut mesurer.
	# La première version de cette fonction annonçait 5,01 m/s pour un clip qui
	# en produit 8,7 au sol.
	const MARGE: float = 0.05
	var total: float = 0.0
	var duree_appui: float = 0.0
	var pas: float = duree / float(PAS)
	for index: int in range(1, PAS + 1):
		if appuis[index] != appuis[index - 1]:
			continue
		if bas[index].y > sol + MARGE or bas[index - 1].y > sol + MARGE:
			continue
		var a: Vector3 = bas[index - 1] - bassins[index - 1]
		var b: Vector3 = bas[index] - bassins[index]
		total += Vector2(b.x - a.x, b.z - a.z).length()
		duree_appui += pas
	if duree_appui <= 0.0001:
		return 0.0
	return total / duree_appui

func _lecteur(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _lecteur(child)
		if found != null:
			return found
	return null

func _recenser(scene: PackedScene, prefix: String) -> void:
	var node: Node = scene.instantiate()
	get_root().add_child(node)
	var lecteur: AnimationPlayer = _lecteur(node)
	if lecteur != null:
		for nom: String in lecteur.get_animation_list():
			_connus[StringName(prefix + nom)] = true
	node.queue_free()

## Monte un exemplaire du corps, greffe la bibliothèque d'appoint dessus, et
## renvoie son lecteur : c'est sur lui qu'on mesure toutes les vitesses.
func _banc(corps: PackedScene, plus: PackedScene) -> AnimationPlayer:
	var node: Node = corps.instantiate()
	get_root().add_child(node)
	var lecteur: AnimationPlayer = _lecteur(node)
	if lecteur == null:
		return null
	var appoint: Node = plus.instantiate()
	var source: AnimationPlayer = _lecteur(appoint)
	if source != null:
		for nom: StringName in source.get_animation_library_list():
			lecteur.add_animation_library(&"plus",
				source.get_animation_library(nom))
			break
	_os = _squelette(node)
	if _os == null:
		return lecteur
	var racine: Node = lecteur.get_node(lecteur.root_node)
	_chemin = String(racine.get_path_to(_os))
	_bassin = _os.find_bone("pelvis")
	_pieds = [_os.find_bone("ball_l"), _os.find_bone("ball_r")]
	if _pieds[0] < 0 or _pieds[1] < 0:
		_pieds = [_os.find_bone("foot_l"), _os.find_bone("foot_r")]
	return lecteur

## Vérifie un nom et le renvoie. `quoi` sert au message d'erreur.
func _clip(nom: String, id: String, quoi: String) -> StringName:
	if not _connus.has(StringName(nom)):
		printerr("%s : clip inconnu pour %s : « %s »" % [id, quoi, nom])
		_faute = true
	return StringName(nom)

var _faute: bool = false

func _init() -> void:
	var corps: PackedScene = load(CORPS)
	var plus: PackedScene = load(GESTES_PLUS)
	if corps == null or plus == null:
		printerr("corps ou gestes absents")
		quit(1)
		return
	_recenser(corps, "")
	_recenser(plus, "plus/")
	print("clips disponibles : %d" % _connus.size())
	var banc: AnimationPlayer = _banc(corps, plus)
	if banc == null or _bassin < 0:
		printerr("banc de mesure indisponible : squelette ou lecteur absent")
		quit(1)
		return
	for entry: Dictionary in CAST:
		var id: String = entry["id"]
		var model: ModelData = ModelData.new()
		model.id = StringName(id)
		model.scene = corps
		model.extra_animations = plus
		model.extra_prefix = &"plus"
		model.scale = 1.0
		# Le rig humain regarde vers +Z ; l'avant du projet est -Z.
		model.yaw_degrees = 180.0
		model.lift = 0.0
		var repos: String = entry["repos"]
		var marche: String = entry["marche"]
		var course: String = entry["course"]
		var chute: String = entry["chute"]
		var chute_bis: String = entry["chute_bis"]
		model.idle = _clip(repos, id, "repos")
		model.walk = _clip(marche, id, "marche")
		model.run = _clip(course, id, "course")
		model.walk_back = _clip("plus/Walk_Backwards", id, "recul")
		model.strafe_left = _clip("plus/Strafe_left", id, "pas gauche")
		model.strafe_right = _clip("plus/Strafe_right", id, "pas droit")
		# Mesurées sur les clips eux-mêmes, jamais saisies.
		model.walk_clip_speed = _vitesse(banc, marche)
		model.run_clip_speed = _vitesse(banc, course)
		model.back_clip_speed = _vitesse(banc, "plus/Walk_Backwards")
		model.strafe_clip_speed = 0.5 * (
			_vitesse(banc, "plus/Strafe_left")
			+ _vitesse(banc, "plus/Strafe_right"))
		model.dodge = _clip("Roll", id, "esquive")
		model.hurt = _clip("Hit_Chest", id, "encaissement")
		model.hurt_alt = _clip("Hit_Head", id, "encaissement bis")
		model.death = _clip(chute, id, "chute")
		model.death_alt = _clip(chute_bis, id, "chute bis")
		var table: Dictionary = entry["gestes"]
		var gestes: Dictionary[StringName, StringName] = {}
		var premier: String = ""
		for cle: String in table:
			var valeur: String = table[cle]
			gestes[StringName(cle)] = _clip(valeur, id, "geste " + cle)
			if premier == "":
				premier = valeur
		model.attack_clips = gestes
		model.attack = StringName(premier) if premier != "" else &"Idle_A"
		model.run_speed = 3.0
		model.blend_time = 0.16
		var code: int = ResourceSaver.save(model, "res://models/%s.tres" % id)
		print("%-10s marche %.2f  course %.2f  recul %.2f  chasse %.2f  (%d)"
			% [id, model.walk_clip_speed, model.run_clip_speed,
				model.back_clip_speed, model.strafe_clip_speed, code])
	if _faute:
		printerr("des clips manquent : modeles NON valides")
		quit(1)
		return
	quit(0)
