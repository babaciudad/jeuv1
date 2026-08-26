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

## Vitesses, en mètres par seconde, auxquelles la marche et la course ont été
## animées. Le mélangeur s'en sert pour caler la cadence sur la distance
## réellement parcourue.
const MARCHE: float = 1.45
const COURSE: float = 3.70

## Un personnage : identifiant, repos, marche, course, esquive, encaissement,
## chute, et le geste de chaque attaque.
const CAST: Array[Dictionary] = [
	{
		"id": "gardien",
		"repos": "Idle_Sword", "marche": "plus/Walk_Large", "course": "Jog",
		"chute": "Death_D", "chute_bis": "plus/Death_A",
		"gestes": {
			"gardien_lourd": "Sword_Regular_C",
			"gardien_rapide": "Sword_Regular_A",
		},
	},
	{
		"id": "archer",
		"repos": "Idle_A", "marche": "Walk", "course": "Jog",
		"chute": "plus/Death_B", "chute_bis": "Death_D",
		"gestes": {
			"archer_dague": "Sword_Regular_B",
			"archer_fleche": "plus/Bow Release",
		},
	},
	{
		"id": "mage",
		"repos": "Spell_Simple_Idle", "marche": "Walk", "course": "Jog",
		"chute": "plus/Death_C", "chute_bis": "plus/Death_B",
		"gestes": {
			"mage_baton": "Sword_Regular_B",
			"mage_trait": "Spell_Simple_Shoot",
		},
	},
	{
		"id": "soigneur",
		"repos": "Idle_A", "marche": "Walk_Formal", "course": "Jog",
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
		"course": "plus/Zombie_Walk_2",
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
		"repos": "plus/Fighting Idle", "marche": "plus/Walk_Large", "course": "Jog",
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
		model.walk_clip_speed = MARCHE
		model.run_clip_speed = COURSE
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
		print("%s : %d" % [id, code])
	if _faute:
		printerr("des clips manquent : modeles NON valides")
		quit(1)
		return
	quit(0)
