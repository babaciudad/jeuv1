## L'arbre d'animation d'un corps : locomotion mélangée, gestes par impulsion,
## mort définitive.
##
## Ce fichier existe parce qu'un `AnimationPlayer.play()` par état a un plafond
## très bas :
##
##   — on ne peut pas mélanger deux clips, donc passer de la marche à la course
##     est une COUPURE et jamais une transition ;
##   — on ne peut ni reculer ni tourner autour d'un ennemi : le personnage
##     marche en avant tout en se déplaçant en arrière ;
##   — la cadence est celle du clip et non celle du déplacement réel, donc les
##     pieds patinent dès que la vitesse n'est pas exactement celle de l'auteur.
##
## L'arbre résout les trois. Sa forme :
##
##   sol (mélange 2D) → cadence (échelle de temps)
##     → esquive (impulsion) → geste (impulsion) → douleur (impulsion)
##     → mort (aiguillage) → sortie
##
## Le mélange de sol prend deux axes, en mètres par seconde SIGNÉS : de face en
## Y, de côté en X. Ses points sont placés aux vitesses RÉELLES des clips,
## mesurées par outils/mesurer_pas.gd. C'est ce qui fait qu'un personnage qui
## avance à 2 m/s joue Jog à sa cadence naturelle, sans patiner.
##
## Invariant 2 : présentation pure. Rien ici ne décide d'une hitbox.
## Invariant 8 : cet arbre ne pilote QUE l'apparence. Les fenêtres de coup
## viennent de la simulation, en ticks, et le geste affiché est ÉTIRÉ pour
## tomber dessus.
class_name Animateur
extends RefCounted

## Fondus des impulsions, en secondes. Un geste part sec et revient doucement :
## un coup doit claquer, mais sa reprise ne doit pas se voir.
const ENTREE: float = 0.06
const SORTIE: float = 0.24
const FONDU_MORT: float = 0.16

## En dessous de cette vitesse, en mètres par seconde, on est à l'arrêt. Assez
## haut pour qu'une correction d'un centimètre ne déclenche pas un pas.
const IMMOBILE: float = 0.22

## Demi-largeur d'appui, en mètres : la distance de l'axe du corps au pied qui
## balaie le sol. Un corps qui pivote ne se déplace pas, mais ses appuis, eux,
## parcourent du chemin — et c'est exactement ce que l'axe latéral du mélange
## attend. Les pas chassés deviennent alors un pivot, sans ajouter un seul clip.
const APPUI: float = 0.18
## En deçà de ce régime, en radians par seconde, on ne pivote pas : c'est une
## correction de cap, pas un demi-tour.
const PIVOT_MINIMAL: float = 1.0
## Lissage du régime de rotation, en secondes. Le cap avance par TICK et ceci
## est piloté par IMAGE : sans intégrateur à fuite, la dérivée brute clignote.
const PIVOT_TAU: float = 0.09

var _arbre: AnimationTree = null
var _lecteur: AnimationPlayer = null
var _geste_clip: AnimationNodeAnimation = null
var _geste_vitesse: AnimationNodeTimeScale = null
var _esquive_clip: AnimationNodeAnimation = null
var _douleur_clip: AnimationNodeAnimation = null
var _mort_clip: AnimationNodeAnimation = null

var _mort: bool = false
var _geste_en_cours: StringName = &""
var _tirs: int = 0
var _cap_precedent: float = 0.0
var _regime: float = 0.0
var _premier: bool = true

func pret() -> bool:
	return _arbre != null

## Nombre de gestes déclenchés depuis le montage. Une combinaison de trois coups
## doit en compter trois : c'est par là que les tests distinguent un
## ENCHAÎNEMENT d'une simple continuation, y compris quand les deux coups
## partagent le même clip.
func tirs() -> int:
	return _tirs

# ---------------------------------------------------------------------------
# Montage
# ---------------------------------------------------------------------------

## Monte l'arbre sur un rig déjà dans la scène. Renvoie un animateur inerte —
## et non null — si le rig n'a pas de lecteur : le personnage restera figé,
## mais rien ne plantera et le jeu reste jouable.
static func monter(rig: Node3D, cristallise: bool) -> Animateur:
	var animateur: Animateur = Animateur.new()
	animateur._lecteur = Animateur.trouver_lecteur(rig)
	if animateur._lecteur == null:
		push_warning("Rig sans AnimationPlayer : le corps sera figé.")
		return animateur
	# Invariant 8 : ce lecteur ne doit atteindre aucune règle de jeu. Une piste
	# d'appel de méthode qu'un modèle importé apporterait ne trouverait rien.
	animateur._lecteur.callback_mode_method = \
		AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_DEFERRED
	animateur._construire(rig, cristallise)
	return animateur

func _construire(rig: Node3D, cristallise: bool) -> void:
	var melange: AnimationNodeBlendTree = AnimationNodeBlendTree.new()

	var sol: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	sol.min_space = Vector2(-Allures.COTE * 1.15, -Allures.ARRIERE * 1.15)
	sol.max_space = Vector2(Allures.COTE * 1.15, Allures.COURSE * 1.05)
	sol.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	if cristallise:
		_point(sol, Allures.CLIP_CRISTALLISE_ATTENTE, Vector2.ZERO)
		_point(sol, Allures.CLIP_CRISTALLISE_MARCHE, Vector2(0.0, Allures.CRISTALLISE))
		_point(sol, Allures.CLIP_CRISTALLISE_MARCHE, Vector2(0.0, Allures.COURSE))
		_point(sol, Allures.CLIP_ARRIERE, Vector2(0.0, -Allures.ARRIERE))
		_point(sol, Allures.CLIP_COTE_GAUCHE, Vector2(-Allures.COTE, 0.0))
		_point(sol, Allures.CLIP_COTE_DROIT, Vector2(Allures.COTE, 0.0))
	else:
		_point(sol, Allures.CLIP_ATTENTE, Vector2.ZERO)
		_point(sol, Allures.CLIP_MARCHE, Vector2(0.0, Allures.MARCHE))
		_point(sol, Allures.CLIP_TROT, Vector2(0.0, Allures.TROT))
		_point(sol, Allures.CLIP_COURSE, Vector2(0.0, Allures.COURSE))
		_point(sol, Allures.CLIP_ARRIERE, Vector2(0.0, -Allures.ARRIERE))
		_point(sol, Allures.CLIP_COTE_GAUCHE, Vector2(-Allures.COTE, 0.0))
		_point(sol, Allures.CLIP_COTE_DROIT, Vector2(Allures.COTE, 0.0))
	melange.add_node(&"sol", sol, Vector2(0, 0))

	var cadence: AnimationNodeTimeScale = AnimationNodeTimeScale.new()
	melange.add_node(&"cadence", cadence, Vector2(260, 0))
	melange.connect_node(&"cadence", 0, &"sol")

	# L'esquive, le geste et la douleur sont des IMPULSIONS : elles se
	# déclenchent, jouent une fois et rendent la main toutes seules.
	_esquive_clip = _impulsion(melange, &"esquive", Allures.CLIP_ROULADE,
		Vector2(520, 0), &"cadence", false)
	_geste_clip = _impulsion(melange, &"geste", Allures.CLIP_LAS,
		Vector2(780, 0), &"esquive", true)
	_douleur_clip = _impulsion(melange, &"douleur", Allures.CLIP_DOULEUR,
		Vector2(1040, 0), &"geste", false)

	# La mort est un aiguillage et non une impulsion : on n'en revient pas.
	_mort_clip = AnimationNodeAnimation.new()
	_mort_clip.animation = Allures.CLIP_MORT
	melange.add_node(&"clip_mort", _mort_clip, Vector2(1040, 220))
	var mort: AnimationNodeTransition = AnimationNodeTransition.new()
	mort.input_count = 2
	mort.set_input_as_auto_advance(0, false)
	mort.set_input_as_auto_advance(1, false)
	mort.xfade_time = FONDU_MORT
	melange.add_node(&"mort", mort, Vector2(1300, 0))
	melange.connect_node(&"mort", 0, &"douleur")
	melange.connect_node(&"mort", 1, &"clip_mort")
	melange.connect_node(&"output", 0, &"mort")

	_arbre = AnimationTree.new()
	_arbre.name = "Animation"
	_arbre.tree_root = melange
	_arbre.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	rig.add_child(_arbre)
	_arbre.anim_player = _arbre.get_path_to(_lecteur)
	_arbre.active = true

## Ajoute un point de mélange, en ignorant silencieusement un clip absent : un
## modèle incomplet doit dégrader l'animation, jamais faire tomber le jeu.
func _point(sol: AnimationNodeBlendSpace2D, clip: StringName, ou: Vector2) -> void:
	if not _lecteur.has_animation(clip):
		push_warning("Clip absent du mélange au sol : %s" % clip)
		return
	var noeud: AnimationNodeAnimation = AnimationNodeAnimation.new()
	noeud.animation = clip
	sol.add_blend_point(noeud, ou, -1)
	sol.set_blend_point_name(sol.get_blend_point_count() - 1,
		StringName(String(clip).replace("/", "_")))

## Une impulsion : le clip passe par une échelle de temps quand il doit être
## étiré sur une durée imposée par la simulation.
func _impulsion(melange: AnimationNodeBlendTree, nom: StringName, clip: StringName,
		ou: Vector2, amont: StringName, etirable: bool) -> AnimationNodeAnimation:
	var noeud: AnimationNodeAnimation = AnimationNodeAnimation.new()
	noeud.animation = clip
	var nom_clip: StringName = StringName("clip_%s" % nom)
	melange.add_node(nom_clip, noeud, ou + Vector2(0, 220))

	var source: StringName = nom_clip
	if etirable:
		_geste_vitesse = AnimationNodeTimeScale.new()
		melange.add_node(&"geste_vitesse", _geste_vitesse, ou + Vector2(130, 220))
		melange.connect_node(&"geste_vitesse", 0, nom_clip)
		source = &"geste_vitesse"

	var impulsion: AnimationNodeOneShot = AnimationNodeOneShot.new()
	impulsion.fadein_time = ENTREE
	impulsion.fadeout_time = SORTIE
	impulsion.break_loop_at_end = true
	melange.add_node(nom, impulsion, ou)
	melange.connect_node(nom, 0, amont)
	melange.connect_node(nom, 1, source)
	return noeud

# ---------------------------------------------------------------------------
# Pilotage, une fois par image
# ---------------------------------------------------------------------------

## Recopie l'état simulé dans l'arbre. `duree_geste` est la durée voulue du
## geste en cours, EN SECONDES, dérivée de sa durée en ticks : c'est elle qui
## étire le clip pour qu'il tombe sur la fenêtre de coup.
func piloter(acteur: Acteur, duree_geste: float, delta: float) -> void:
	if _arbre == null:
		return
	_pivot(acteur, delta)
	_sol(acteur)
	_gestes(acteur, duree_geste)

func _sol(acteur: Acteur) -> void:
	# La vitesse passe dans le repère du corps : de face en Y, de côté en X.
	var avant: Vector2 = Vector2(sin(acteur.cap), cos(acteur.cap))
	var cote: Vector2 = Vector2(avant.y, -avant.x)
	var vitesse: Vector2 = acteur.vitesse
	if acteur.etat == Acteur.Etat.MORT:
		vitesse = Vector2.ZERO
	var melange: Vector2 = Vector2(vitesse.dot(cote), vitesse.dot(avant))
	# Un corps qui pivote sur place n'avance pas, mais ses appuis balaient le
	# sol : on le verse sur l'axe latéral et le pas chassé devient un pivot.
	if absf(_regime) > PIVOT_MINIMAL and melange.length() < IMMOBILE:
		melange.x += _regime * APPUI

	var etendue: float = maxf(Allures.COURSE, 0.001)
	var longueur: float = melange.length()
	var pose: Vector2 = melange
	var cadence: float = 1.0
	if longueur > etendue:
		# Au-delà du point le plus rapide, on ne peut plus mélanger : on presse
		# le clip. C'est la seule façon de ne pas patiner hors du domaine.
		pose = melange * (etendue / longueur)
		cadence = longueur / etendue
	elif longueur < IMMOBILE:
		pose = Vector2.ZERO
	_arbre.set(&"parameters/sol/blend_position", pose)
	_arbre.set(&"parameters/cadence/scale", cadence)

func _pivot(acteur: Acteur, delta: float) -> void:
	if _premier:
		_cap_precedent = acteur.cap
		_premier = false
		return
	if delta <= 0.0:
		return
	var brut: float = angle_difference(_cap_precedent, acteur.cap) / delta
	var poids: float = clampf(delta / PIVOT_TAU, 0.0, 1.0)
	_regime = lerpf(_regime, brut, poids)
	_cap_precedent = acteur.cap

func _gestes(acteur: Acteur, duree_geste: float) -> void:
	if acteur.etat == Acteur.Etat.MORT:
		if not _mort:
			_mort = true
			# « state_1 », et pas « 1 » : Godot nomme les entrées d'un
			# AnimationNodeTransition « state_%d », et une requête qui ne
			# correspond à aucun nom est IGNORÉE avec une erreur console.
			# Résultat mesuré : le joueur mourait debout, en pose d'attente,
			# puis se téléportait — le clip de mort n'était jamais joué.
			_arbre.set(&"parameters/mort/transition_request", &"state_1")
		return

	var attendu: StringName = acteur.geste
	if attendu == _geste_en_cours:
		return
	_geste_en_cours = attendu

	match acteur.etat:
		Acteur.Etat.ESQUIVE:
			_tirer(&"esquive")
		Acteur.Etat.TRAVAIL:
			_jouer_travail(acteur)
		Acteur.Etat.FRAPPE:
			if _geste_clip != null and _lecteur.has_animation(Allures.CLIP_LAS):
				_geste_clip.animation = Allures.CLIP_LAS
			if _geste_vitesse != null and duree_geste > 0.0:
				# Invariant 8, rendu mécanique : le clip s'étire sur la durée
				# décidée par la simulation. Si demain on rallonge le geste
				# d'un tick, l'animation suit — et le combat, lui, ne bouge pas.
				_arbre.set(&"parameters/geste_vitesse/scale",
					Allures.DUREE_LAS / duree_geste)
			_tirer(&"geste")
			_tirs += 1
		Acteur.Etat.DOULEUR:
			_tirer(&"douleur")

## Les clips du métier, par nom de geste simulé, avec la durée du clip source
## pour l'étirement. Ils étaient chargés dans le rig et jamais joués : on
## ouvrait une vanne sans bouger un doigt.
const TRAVAUX: Dictionary[StringName, Array] = {
	&"vanne": [Allures.CLIP_VANNE, Allures.DUREE_VANNE],
	&"cueillette": [Allures.CLIP_CUEILLIR, Allures.DUREE_CUEILLIR],
	&"levee": [Allures.CLIP_CRISTALLISE_LEVEE, Allures.DUREE_CRISTALLISE_LEVEE],
}

func _jouer_travail(acteur: Acteur) -> void:
	if not TRAVAUX.has(acteur.geste):
		return
	var infos: Array = TRAVAUX[acteur.geste]
	var clip: StringName = infos[0]
	var duree_clip: float = infos[1]
	if _geste_clip == null or not _lecteur.has_animation(clip):
		return
	_geste_clip.animation = clip
	if _geste_vitesse != null and acteur.ticks_etat > 0:
		# Invariant 8 : le clip s'étire sur la durée décidée par la simulation.
		var duree_sim: float = float(acteur.ticks_etat + acteur.ticks_geste) \
			/ float(Reglages.TICKS_PAR_SECONDE)
		_arbre.set(&"parameters/geste_vitesse/scale", duree_clip / maxf(duree_sim, 0.05))
	_tirer(&"geste")
	_tirs += 1

func _tirer(nom: StringName) -> void:
	_arbre.set(StringName("parameters/%s/request" % nom),
		AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

# ---------------------------------------------------------------------------

static func trouver_lecteur(noeud: Node) -> AnimationPlayer:
	var lecteur: AnimationPlayer = noeud as AnimationPlayer
	if lecteur != null:
		return lecteur
	for enfant: Node in noeud.get_children():
		var trouve: AnimationPlayer = Animateur.trouver_lecteur(enfant)
		if trouve != null:
			return trouve
	return null
