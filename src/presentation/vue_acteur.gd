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

## L'outil dans la main. « Dans les Salines, on se bat avec ce qui sert à
## travailler. » Le las est un râteau de cinq mètres de manche : c'est l'arme du
## Saunier, et c'est le même objet qui traîne contre la ladure.
const LAS: String = "res://models/marais/props/rateau.glb"
## Os de la main droite dans le squelette du mannequin.
const OS_MAIN: StringName = &"hand_r"
## Longueur d'un vrai las, en mètres. « Une raclette de bois au bout d'un
## manche de cinq mètres. »
const LONGUEUR_LAS: float = 5.0
## Sous cette hauteur, dans le modèle source, on est dans la TÊTE de l'outil :
## elle ne s'étire pas. Étirer tout le modèle donnait des dents de quarante
## centimètres — un râteau de géant, pas un outil de précision.
const TETE_LAS: float = 0.15
## Distance entre la main et le bout du manche, en mètres : on tient un las
## près du bout, et la tête balaie à quatre mètres et demi devant — la portée
## simulée du geste (4,6 m) devient la portée VISIBLE de l'outil.
const PRISE_LAS: float = 0.55

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
	_armer()

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

## Met le las dans la main. Un attachement d'os, et non un enfant du corps :
## l'outil doit suivre la main à chaque image de l'animation, pas le tronc.
func _armer() -> void:
	var squelette: Skeleton3D = _squelette(_rig)
	if squelette == null:
		return
	var os: int = squelette.find_bone(OS_MAIN)
	if os < 0:
		push_warning("Pas d'os %s : le las restera au sol." % OS_MAIN)
		return
	if not ResourceLoader.exists(LAS):
		return
	var paquet: PackedScene = load(LAS) as PackedScene
	if paquet == null:
		return
	var attache: BoneAttachment3D = BoneAttachment3D.new()
	attache.name = "Main"
	squelette.add_child(attache)
	attache.bone_idx = os
	var outil: Node3D = paquet.instantiate() as Node3D
	if outil == null:
		return
	_allonger_le_manche(outil)
	# Posé dans la paume, manche vers l'avant, légèrement incliné : c'est la
	# façon dont on porte un outil à long manche quand on marche avec.
	outil.position = Vector3(0.0, 0.04, 0.02)
	outil.rotation = Vector3(deg_to_rad(-96.0), 0.0, deg_to_rad(14.0))
	attache.add_child(outil)

## Chirurgie de sommets : seul le MANCHE s'étire, la tête garde sa taille, et
## la prise en main se place près du bout — la tête pend alors à quatre mètres
## et demi de la main, ce qui est la portée du geste simulé.
static var _las_opere: Mesh = null

static func _allonger_le_manche(outil: Node3D) -> void:
	var instance: MeshInstance3D = _premier_maillage(outil)
	if instance == null or instance.mesh == null:
		return
	if _las_opere != null:
		instance.mesh = _las_opere
		return
	var source: Mesh = instance.mesh
	var haut: float = source.get_aabb().size.y
	if haut <= TETE_LAS + 0.05:
		return
	var facteur: float = (LONGUEUR_LAS - TETE_LAS) / (haut - TETE_LAS)
	var opere: ArrayMesh = ArrayMesh.new()
	for surface: int in range(source.get_surface_count()):
		var tableaux: Array = source.surface_get_arrays(surface)
		var positions: PackedVector3Array = tableaux[Mesh.ARRAY_VERTEX]
		for i: int in range(positions.size()):
			var p: Vector3 = positions[i]
			if p.y > TETE_LAS:
				p.y = TETE_LAS + (p.y - TETE_LAS) * facteur
			# La prise se place près du BOUT du manche : tout descend pour que
			# la main (l'origine) tienne l'outil à PRISE_LAS du sommet.
			p.y -= LONGUEUR_LAS - PRISE_LAS
			positions[i] = p
		tableaux[Mesh.ARRAY_VERTEX] = positions
		opere.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tableaux)
		opere.surface_set_material(surface, source.surface_get_material(surface))
	_las_opere = opere
	instance.mesh = opere

static func _premier_maillage(noeud: Node) -> MeshInstance3D:
	var instance: MeshInstance3D = noeud as MeshInstance3D
	if instance != null and instance.mesh != null:
		return instance
	for enfant: Node in noeud.get_children():
		var trouve: MeshInstance3D = VueActeur._premier_maillage(enfant)
		if trouve != null:
			return trouve
	return null

func _squelette(noeud: Node) -> Skeleton3D:
	var squelette: Skeleton3D = noeud as Skeleton3D
	if squelette != null:
		return squelette
	for enfant: Node in noeud.get_children():
		var trouve: Skeleton3D = _squelette(enfant)
		if trouve != null:
			return trouve
	return null

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
