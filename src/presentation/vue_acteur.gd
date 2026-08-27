## Le corps visible d'un acteur simulé.
##
## Il ne décide de rien : il recopie, une fois par image, ce que la simulation a
## déjà décidé au tick. Sa position au sol vient de l'acteur, sa hauteur du
## terrain, son cap de l'acteur. C'est l'invariant 2 rendu littéral — si on
## supprimait ce fichier, le jeu continuerait de se jouer, on ne le verrait
## simplement plus.
class_name VueActeur
extends Node3D

## Le rig et ses deux paquets de gestes. Ils partagent le même squelette et les
## mêmes chemins de piste, donc la greffe se fait sans retargeting.
const RIG: String = "res://models/humain/gestes_base.glb"
const GESTES_PLUS: String = "res://models/humain/gestes_plus.glb"
const PREFIXE_PLUS: StringName = &"plus"

## Rotation à appliquer au modèle pour que son avant coïncide avec l'avant du
## jeu. Mesurée en regardant le personnage, pas devinée.
const ORIENTATION: float = PI

## Lissage de la hauteur, en secondes. Le sol du marais est en marches d'un
## quart de mètre : sans ce lissage, franchir un talus fait sauter le corps.
const TAU_HAUTEUR: float = 0.045

var acteur: Acteur = null

var _animateur: Animateur = null
var _rig: Node3D = null
var _hauteur: float = 0.0
var _amorce: bool = false

func monter(pour: Acteur, cristallise: bool) -> void:
	acteur = pour
	var paquet: PackedScene = load(RIG) as PackedScene
	if paquet == null:
		push_error("Rig introuvable : %s" % RIG)
		return
	_rig = paquet.instantiate() as Node3D
	if _rig == null:
		push_error("Le rig n'est pas un Node3D.")
		return
	_rig.rotation.y = ORIENTATION
	add_child(_rig)
	_greffer()
	_animateur = Animateur.monter(_rig, cristallise)

## Greffe la bibliothèque d'appoint sur le lecteur du rig. Un clip d'appoint
## s'appelle alors « plus/Dodge_left ».
func _greffer() -> void:
	var lecteur: AnimationPlayer = Animateur.trouver_lecteur(_rig)
	if lecteur == null or lecteur.has_animation_library(PREFIXE_PLUS):
		return
	var paquet: PackedScene = load(GESTES_PLUS) as PackedScene
	if paquet == null:
		return
	var source_rig: Node = paquet.instantiate()
	var source: AnimationPlayer = Animateur.trouver_lecteur(source_rig)
	if source == null:
		source_rig.free()
		return
	for nom: StringName in source.get_animation_library_list():
		var bibliotheque: AnimationLibrary = source.get_animation_library(nom)
		if bibliotheque != null and not lecteur.has_animation_library(PREFIXE_PLUS):
			lecteur.add_animation_library(PREFIXE_PLUS, bibliotheque)
	# `free` et non `queue_free` : cet exemplaire n'est jamais entré dans
	# l'arbre. Les bibliothèques qu'on lui a prises sont des ressources et
	# survivent très bien à sa disparition ; en file d'attente il resterait un
	# orphelin jusqu'à l'image suivante, et dans un test qui n'en joue aucune,
	# il resterait pour toujours.
	source_rig.free()

## Recopie l'état simulé. `sol` est l'altitude du terrain sous les pieds.
func suivre(sol: float, duree_geste: float, delta: float) -> void:
	if acteur == null:
		return
	if not _amorce:
		_hauteur = sol
		_amorce = true
	else:
		_hauteur = lerpf(_hauteur, sol, clampf(delta / TAU_HAUTEUR, 0.0, 1.0))
	position = Vector3(acteur.position.x, _hauteur, acteur.position.y)
	rotation.y = acteur.cap + ORIENTATION
	if _animateur != null and _animateur.pret():
		_animateur.piloter(acteur, duree_geste, delta)

func animateur() -> Animateur:
	return _animateur
