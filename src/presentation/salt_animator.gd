## Arbre d'animation d'un personnage : locomotion mélangée, actions par
## impulsion, mort définitive.
##
## Ce fichier remplace un `AnimationPlayer.play()` par état. Cette approche-là
## a un plafond très bas et on l'avait atteint :
##
##   — on ne peut pas mélanger deux clips, donc passer de la marche à la course
##     est une COUPURE, jamais une transition ;
##   — on ne peut pas reculer ni tourner autour d'un boss : le personnage
##     marche en avant en se déplaçant en arrière ;
##   — la cadence est celle du clip et non celle du déplacement réel, donc les
##     pieds patinent dès que la vitesse n'est pas exactement celle de l'auteur
##     du clip — et elle ne l'est jamais, puisqu'on a rallongé les jambes.
##
## L'arbre résout les trois. Sa forme :
##
##   sol (BlendSpace2D)  ->  cadence (TimeScale)
##       -> esquive (OneShot) -> coup (OneShot) -> douleur (OneShot)
##       -> mort (Transition)  ->  sortie
##
## Le mélange de sol prend deux axes : de face en Y, de côté en X, tous deux
## en mètres par seconde signés. Les trois impulsions se déclenchent et se
## rendent la main toutes seules. La mort est un aiguillage, pas une
## impulsion : on n'en revient pas.
##
## Invariant 2 : présentation pure. Rien ici ne décide d'une hitbox.
## Invariant 8 : ce mélangeur ne pilote QUE l'apparence. Les fenêtres de coup
## viennent d'AttackRunner, en ticks, et l'attaque affichée est ÉTIRÉE pour
## tomber dessus.
class_name SaltAnimator
extends RefCounted

## Fondus, en secondes. Les actions entrent vite et sortent lentement : un
## coup doit partir sec, mais revenir à la marche sans claquer.
const ACTION_IN: float = 0.06
const ACTION_OUT: float = 0.22
const DEATH_FADE: float = 0.14
## Sous cette vitesse, on est à l'arrêt. Assez haut pour qu'une correction
## réseau d'un centimètre ne déclenche pas un pas.
const STILL: float = 0.22

## DEMI-TOUR SUR PLACE.
##
## Demi-largeur d'appui, en mètres : la distance entre l'axe du corps et le
## pied qui balaie le sol. Un corps qui pivote ne translate pas, mais ses
## appuis, eux, parcourent du chemin — `ω × 0,18` mètre par seconde — et c'est
## exactement la grandeur que le mélange de sol attend sur son axe latéral. Les
## pas chassés, déjà posés à leur vitesse mesurée, deviennent alors un pivot
## sans qu'on ajoute ni clip ni point de mélange.
const TURN_STANCE: float = 0.18
## En dessous de ce régime, en radians par seconde, on ne pivote pas : c'est
## une correction de cap, pas un demi-tour. Un tour délibéré tourne à 12,6 rad/s
## (720 °/s), et 20 rad/s verrouillé — le seuil est donc très bas devant lui.
const TURN_MIN: float = 1.0
## Constante de lissage du régime de rotation, en secondes.
##
## `facing` avance par TICK, à 60 Hz, alors que ceci est piloté par IMAGE. Aux
## fréquences qui ne tombent pas juste, une image sur deux voit un cap immobile
## et la dérivée brute clignote entre zéro et le double. L'intégrateur à fuite
## rend la moyenne, quelle que soit la fréquence d'affichage.
const TURN_TAU: float = 0.09

## ARRÊT FRANC.
##
## Au-dessus de cette vitesse, en mètres par seconde, un arrêt se PLANTE au
## lieu de se fondre. En dessous, on s'arrêtait déjà de marcher : il n'y a rien
## à marquer.
const STOP_MIN: float = 1.8
## Temps d'arrêt proprement dit : la foulée se fige sur son dernier appui.
const STOP_PLANT: float = 0.10
## Puis le mélange retombe vers l'attente, sur cette durée.
const STOP_FALL: float = 0.15
## Décroissance du souvenir de vitesse, en mètres par seconde carrée.
##
## La simulation freine entre 25 et 60 m/s² : la vitesse ne saute pas de la
## course à zéro, elle TRAVERSE le seuil d'arrêt. Lire la vitesse de l'image
## précédente ne verrait donc jamais qu'un 0,2 m/s poussif et l'arrêt franc ne
## partirait jamais. On garde un maximum qui s'oublie, et c'est lui qui dit à
## quelle allure on courait il y a un dixième de seconde.
const STOP_MEMORY: float = 20.0

var _tree: AnimationTree = null
var _model: ModelData = null
var _player: AnimationPlayer = null
var _attack: AnimationNodeAnimation = null
var _roll: AnimationNodeAnimation = null
## Clip de roulade et clip de pas arrière, choisis au montage.
var _roll_clip: StringName = &""
var _step_clip: StringName = &""
var _hurt: AnimationNodeAnimation = null
var _death: AnimationNodeAnimation = null
## Vrai quand une impulsion est en cours : sert à ne la déclencher qu'une fois
## par action simulée, et non à chaque image.
var _attacking: bool = false
var _staggering: bool = false
var _dodging: bool = false
var _dead: bool = false
## Alterne les variantes d'encaissement et de chute.
var _flip: bool = false
## Vitesses au sol retenues pour les points de mélange, en mètres par seconde.
## Recopiées du modèle mais forcées strictement croissantes : deux points de
## mélange au même endroit rendent le mélange indéfini, et un mannequin dont
## tous les clips valent zéro suffit à provoquer le cas.
var _walk: float = 0.7
var _run: float = 4.8
var _back: float = 0.9
var _strafe: float = 0.7

## Durée de la dernière image, recopiée depuis `tick_freeze`.
##
## `drive` ne la reçoit pas, et sa signature est utilisée ailleurs. Or
## `tick_freeze` est appelé juste avant lui, à chaque image, avec le delta :
## on le retient au passage. Un appelant qui piloterait `_drive_ground` sans
## passer par `tick_freeze` — le banc de mesure des pas le fait — laisse ce
## delta à zéro, et ni le pivot ni l'arrêt franc ne s'arment. C'est voulu :
## ces deux-là mesurent une allure constante et n'ont rien à marquer.
var _delta: float = 0.0
## Cap de l'image précédente, pour en tirer le régime de rotation.
var _last_facing: Vector2 = Vector2.ZERO
## Régime de rotation lissé, en radians par seconde, signe déjà corrigé pour
## l'axe latéral du mélange : positif quand le personnage pivote vers sa droite.
var _turn_rate: float = 0.0
## Souvenir décroissant de la vitesse : à quelle allure courait-on juste avant
## de s'arrêter.
var _peak_speed: float = 0.0
## Temps restant de l'arrêt franc, en secondes.
var _stop_left: float = 0.0
## Mélange de sol au moment où l'arrêt s'est déclenché : c'est la foulée qu'on
## fige, et non une pose moyenne.
var _stop_blend: Vector2 = Vector2.ZERO
## Identité de l'attaque en cours, pour distinguer un ENCHAÎNEMENT d'une
## continuation. Voir `_drive_attack`.
var _attack_id: StringName = &""
var _attack_ticks: int = -1
## Dernier mélange de sol posé, et sa cadence. Voir `ground_blend`.
var _ground_blend: Vector2 = Vector2.ZERO
var _ground_scale: float = 1.0
## Nombre de gestes d'attaque déclenchés depuis le montage. Une combo de trois
## coups doit en compter trois : c'est par là que les tests distinguent un
## enchaînement d'une continuation, y compris quand les deux coups partagent le
## même clip et que le nom du geste ne bouge donc pas.
var _attack_fires: int = 0

func ready() -> bool:
	return _tree != null

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Monte l'arbre sur le rig. Renvoie null si le modèle n'a pas de lecteur —
## le personnage restera figé, mais rien ne plantera.
static func build(rig: Node3D, model: ModelData) -> SaltAnimator:
	var animator: SaltAnimator = SaltAnimator.new()
	animator._model = model
	animator._player = SaltAnimator._find_player(rig)
	if animator._player == null:
		push_warning("Le modèle %s n'a pas d'AnimationPlayer : il sera figé."
			% model.id)
		return animator
	# Invariant 8 : ce lecteur ne peut atteindre ni AttackRunner ni World. Une
	# piste d'appel de méthode qu'un modèle importé apporterait ne trouverait
	# rien à appeler.
	animator._player.callback_mode_method = \
		AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_DEFERRED
	animator._graft(model)
	animator._assemble(rig)
	return animator

## Greffe la bibliotheque d'appoint sur le lecteur du corps. Le rig humain est
## livre en trois fichiers — un corps, deux paquets de gestes — qui partagent
## le meme squelette et les memes chemins de piste : la fusion se fait donc
## sans retargeting, et un clip d'appoint s'appelle `plus/Dodge_left`.
func _graft(model: ModelData) -> void:
	if model.extra_animations == null:
		return
	var extra: Node = model.extra_animations.instantiate()
	var source: AnimationPlayer = SaltAnimator._find_player(extra)
	if source == null:
		extra.free()
		return
	for name_: StringName in source.get_animation_library_list():
		var library: AnimationLibrary = source.get_animation_library(name_)
		if library == null or _player.has_animation_library(model.extra_prefix):
			continue
		_player.add_animation_library(model.extra_prefix, library)
	# `free` et non `queue_free` : cet exemplaire n'est JAMAIS entré dans
	# l'arbre, il n'a donc pas à attendre la fin de l'image pour disparaître.
	# Les bibliothèques qu'on lui a prises sont des ressources, elles survivent
	# très bien à sa destruction. En file d'attente, il restait un orphelin
	# jusqu'à l'image suivante — et dans un test, qui n'en joue aucune, il le
	# restait pour de bon.
	extra.free()

static func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = SaltAnimator._find_player(child)
		if found != null:
			return found
	return null

func _clip(name_: StringName, fallback: StringName) -> StringName:
	if name_ != &"" and _player.has_animation(name_):
		return name_
	return fallback

## Force un clip à boucler, et renvoie son nom.
##
## TOUS les clips du rig arrivent en `LOOP_NONE` : c'est ce que produit
## l'importateur glb par défaut, et rien ne le signale. Conséquence, en jeu :
## le personnage jouait UN pas, puis se figeait debout et traversait la salle
## en glissant sans bouger une jambe. Idem pour l'attente, qui tenait deux
## secondes puis restait plantée sur sa dernière image.
##
## Seule la locomotion et l'attente bouclent. Un coup, une esquive, un
## encaissement et une chute doivent finir — les faire boucler serait le défaut
## symétrique, et bien pire.
func _loop(name_: StringName, fallback: StringName) -> StringName:
	var chosen: StringName = _clip(name_, fallback)
	if not _player.has_animation(chosen):
		return chosen
	var clip: Animation = _player.get_animation(chosen)
	if clip != null and clip.loop_mode == Animation.LOOP_NONE:
		clip.loop_mode = Animation.LOOP_LINEAR
	return chosen

func _animation(name_: StringName) -> AnimationNodeAnimation:
	var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	node.animation = name_
	return node

func _assemble(rig: Node3D) -> void:
	var idle: StringName = _loop(_model.idle, &"Idle")
	var tree_root: AnimationNodeBlendTree = AnimationNodeBlendTree.new()

	var ground: AnimationNodeBlendSpace2D = AnimationNodeBlendSpace2D.new()
	ground.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
	# Les points sont posés en MÈTRES PAR SECONDE, à la vitesse MESURÉE de
	# chaque clip. C'est tout l'intérêt : quand la vitesse réelle vaut celle
	# d'un point, ce point est joué seul à sa cadence d'origine, et le pied ne
	# glisse pas d'un millimètre. Un nombre faux ici — et ils l'étaient tous,
	# jusqu'à un facteur cinq sur les pas chassés — traîne le personnage au sol
	# à une vitesse que ses jambes ne fabriquent pas.
	_walk = maxf(_model.walk_clip_speed, 0.25)
	_run = maxf(_model.run_clip_speed, _walk + 0.35)
	_back = maxf(_model.back_clip_speed, 0.25)
	_strafe = maxf(_model.strafe_clip_speed, 0.25)
	ground.min_space = Vector2(-_strafe * 1.2, -_back * 1.2)
	ground.max_space = Vector2(_strafe * 1.2, _run * 1.2)
	ground.add_blend_point(_animation(idle), Vector2.ZERO, -1, &"arret")
	ground.add_blend_point(_animation(_loop(_model.walk, idle)),
		Vector2(0.0, _walk), -1, &"marche")
	ground.add_blend_point(_animation(_loop(_model.run, idle)),
		Vector2(0.0, _run), -1, &"course")
	ground.add_blend_point(_animation(_loop(_model.walk_back, idle)),
		Vector2(0.0, -_back), -1, &"recul")
	ground.add_blend_point(_animation(_loop(_model.strafe_left, idle)),
		Vector2(-_strafe, 0.0), -1, &"gauche")
	ground.add_blend_point(_animation(_loop(_model.strafe_right, idle)),
		Vector2(_strafe, 0.0), -1, &"droite")
	tree_root.add_node(&"sol", ground, Vector2(0.0, 0.0))

	var cadence: AnimationNodeTimeScale = AnimationNodeTimeScale.new()
	tree_root.add_node(&"cadence", cadence, Vector2(240.0, 0.0))

	_attack = _animation(_clip(_model.attack, idle))
	tree_root.add_node(&"geste", _attack, Vector2(0.0, 160.0))
	var attack_rate: AnimationNodeTimeScale = AnimationNodeTimeScale.new()
	tree_root.add_node(&"tempo", attack_rate, Vector2(240.0, 160.0))

	_hurt = _animation(_clip(_model.hurt, idle))
	tree_root.add_node(&"choc", _hurt, Vector2(0.0, 280.0))
	_death = _animation(_clip(_model.death, idle))
	tree_root.add_node(&"chute", _death, Vector2(0.0, 400.0))

	tree_root.add_node(&"esquive", _one_shot(), Vector2(460.0, 0.0))
	tree_root.add_node(&"coup", _one_shot(), Vector2(680.0, 0.0))
	tree_root.add_node(&"douleur", _one_shot(), Vector2(900.0, 0.0))
	_roll = _animation(_clip(_model.dodge, idle))
	_roll_clip = _clip(_model.dodge, idle)
	_step_clip = _clip(_model.backstep, _roll_clip)
	tree_root.add_node(&"roulade", _roll, Vector2(0.0, 320.0))
	# Chercheur de temps : l'esquive n'est PAS jouée, elle est POSITIONNÉE.
	#
	# La roulade dure 1,83 s dans la bibliothèque ; l'esquive simulée en dure
	# 0,43 — vingt-six ticks. Lancée comme une impulsion, elle s'arrêtait au
	# quart et le personnage se redressait d'un coup au milieu du plongeon. En
	# la posant chaque image sur l'avancement réel de l'esquive, elle finit
	# toujours pile avec elle, quelle que soit la classe et quel que soit le
	# réglage — et si demain l'esquive passe à trente ticks, il n'y a rien à
	# retoucher ici.
	var seek: AnimationNodeTimeSeek = AnimationNodeTimeSeek.new()
	tree_root.add_node(&"temps_roulade", seek, Vector2(240.0, 320.0))
	tree_root.connect_node(&"temps_roulade", 0, &"roulade")

	var end: AnimationNodeTransition = AnimationNodeTransition.new()
	end.input_count = 2
	end.set_input_name(0, "vivant")
	end.set_input_name(1, "mort")
	end.xfade_time = DEATH_FADE
	# Sans cela, retomber sur « mort » depuis « mort » relancerait la chute.
	end.allow_transition_to_self = false
	tree_root.add_node(&"mort", end, Vector2(1120.0, 0.0))

	tree_root.connect_node(&"cadence", 0, &"sol")
	tree_root.connect_node(&"tempo", 0, &"geste")
	tree_root.connect_node(&"esquive", 0, &"cadence")
	tree_root.connect_node(&"esquive", 1, &"temps_roulade")
	tree_root.connect_node(&"coup", 0, &"esquive")
	tree_root.connect_node(&"coup", 1, &"tempo")
	tree_root.connect_node(&"douleur", 0, &"coup")
	tree_root.connect_node(&"douleur", 1, &"choc")
	tree_root.connect_node(&"mort", 0, &"douleur")
	tree_root.connect_node(&"mort", 1, &"chute")
	# Nœud de GEL, en toute fin de chaîne. Il ne sert qu'à une chose : figer le
	# personnage entier pendant quelques centièmes de seconde au moment où un
	# coup porte.
	var gel: AnimationNodeTimeScale = AnimationNodeTimeScale.new()
	tree_root.add_node(&"gel", gel, Vector2(1340.0, 0.0))
	tree_root.connect_node(&"gel", 0, &"mort")
	tree_root.connect_node(&"output", 0, &"gel")

	_tree = AnimationTree.new()
	_tree.name = "Sel_Animation"
	_tree.tree_root = tree_root
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	rig.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_player)
	_tree.active = true

func _one_shot() -> AnimationNodeOneShot:
	var shot: AnimationNodeOneShot = AnimationNodeOneShot.new()
	shot.fadein_time = ACTION_IN
	shot.fadeout_time = ACTION_OUT
	shot.break_loop_at_end = true
	return shot

# ---------------------------------------------------------------------------
# Pilotage
# ---------------------------------------------------------------------------

## Traduit l'état simulé en paramètres d'arbre. `travel` est le déplacement
## réellement observé depuis la dernière image, en mètres par seconde et en
## coordonnées du monde ; `facing` l'orientation de l'acteur.
##
## On mesure le déplacement au lieu de lire `actor.velocity` : la vitesse d'un
## acteur distant est interpolée et ne veut rien dire ici, alors que la
## distance parcourue à l'écran est vraie pour tout le monde.
func drive(actor: Actor, travel: Vector2, facing: Vector2,
		dodge: float = 0.0) -> void:
	if _tree == null:
		return
	if _freeze_left > 0.0:
		# Pendant le gel on ne pilote plus rien : changer un mélange sous une
		# image figée la fait bouger, ce qui est exactement le contraire de ce
		# qu'on cherche.
		return
	if actor.state == Actor.State.DEAD:
		if not _dead:
			_dead = true
			_death.animation = _clip(
				_model.death_alt if _flip else _model.death, _model.death)
			_flip = not _flip
			_tree.set(&"parameters/mort/transition_request", &"mort")
		return
	if _dead:
		_dead = false
		_tree.set(&"parameters/mort/transition_request", &"vivant")

	_drive_ground(travel, facing)
	_drive_dodge(actor, dodge)
	_drive_attack(actor)
	_drive_hurt(actor)

## Mélange de sol. Le repère est celui du PERSONNAGE : Y devant, X à droite.
##
## Trois régimes, et non un seul :
##
##   — on se DÉPLACE : le mélange est posé à la vitesse réellement observée,
##     comme avant ;
##   — on vient de S'ARRÊTER après avoir couru : la foulée se fige sur son
##     dernier appui, puis retombe vers l'attente — c'est l'arrêt franc ;
##   — on est immobile mais on TOURNE : les pas chassés deviennent un pivot.
func _drive_ground(travel: Vector2, facing: Vector2) -> void:
	var speed: float = travel.length()
	var blend: Vector2 = Vector2.ZERO
	var scale: float = 1.0
	_suivre_cap(facing)
	if speed > STILL and not facing.is_zero_approx():
		var forward: Vector2 = facing.normalized()
		var right: Vector2 = Vector2(forward.y, -forward.x)
		blend = Vector2(travel.dot(right), travel.dot(forward))
		scale = clampf(speed / _capacite(blend), 1.0, 2.4)
		_stop_left = 0.0
		_stop_blend = blend
	elif _stop_left > 0.0 or _peak_speed > STOP_MIN:
		blend = _arret_franc()
		# Pendant le temps d'arrêt la cadence tombe presque à zéro : les
		# jambes tiennent leur dernier appui au lieu de continuer à pédaler.
		scale = 0.05 if _stop_left > STOP_FALL else 1.0
	else:
		blend = Vector2(_pivot(), 0.0)
		if absf(blend.x) > 0.001:
			scale = clampf(absf(blend.x) / _strafe, 1.0, 2.4)
			blend.x = clampf(blend.x, -_strafe, _strafe)
	_peak_speed = maxf(speed, _peak_speed - _delta * STOP_MEMORY)
	_ground_blend = blend
	_ground_scale = scale
	_tree.set(&"parameters/sol/blend_position", blend)
	_tree.set(&"parameters/cadence/scale", scale)

## Dernier mélange de sol appliqué, en mètres par seconde, et sa cadence.
##
## Relire le paramètre sur l'arbre rendrait un Variant, que le typage strict de
## ce projet refuse. On garde donc la valeur telle qu'elle a été posée : c'est
## par là que les tests vérifient le demi-tour et l'arrêt franc.
func ground_blend() -> Vector2:
	return _ground_blend

func ground_scale() -> float:
	return _ground_scale

## Clip d'attaque actuellement monté sur le geste. Sert à vérifier qu'un
## enchaînement change bien de geste.
func attack_clip() -> StringName:
	if _attack == null:
		return &""
	return _attack.animation

## Nombre de gestes d'attaque déclenchés depuis le montage.
func attack_fires() -> int:
	return _attack_fires

## Met à jour le régime de rotation à partir du cap.
##
## L'angle est SIGNÉ — le produit vectoriel en donne le sens — et son signe est
## retourné une fois pour toutes ici : l'axe latéral du mélange est positif
## vers la DROITE, alors qu'un angle positif tourne vers la gauche.
func _suivre_cap(facing: Vector2) -> void:
	if facing.is_zero_approx():
		return
	var cap: Vector2 = facing.normalized()
	if _last_facing.is_zero_approx() or _delta <= 0.0:
		_last_facing = cap
		return
	var angle: float = atan2(_last_facing.cross(cap), _last_facing.dot(cap))
	var brut: float = -angle / _delta
	_turn_rate += (brut - _turn_rate) * (1.0 - exp(-_delta / TURN_TAU))
	_last_facing = cap

## Vitesse latérale VIRTUELLE d'un demi-tour sur place, en mètres par seconde.
##
## Sans ça, un personnage verrouillé qui fait face à sa cible pivotait les deux
## pieds soudés au sol : le corps tournait, la pose ne bougeait pas. C'est le
## défaut qu'on remarque en premier dans un souls-like, parce qu'on y passe son
## temps à se replacer autour d'un boss sans avancer d'un mètre.
func _pivot() -> float:
	if absf(_turn_rate) < TURN_MIN:
		return 0.0
	return _turn_rate * TURN_STANCE

## Mélange de sol pendant l'arrêt franc, et décompte de celui-ci.
##
## Le passage de la course à l'attente était un simple retour du mélange à
## l'origine : la pose sautait de la foulée à l'attente en une image. Dans un
## souls-like on POSE le pied, on tient une fraction de seconde, puis on se
## redresse — c'est ce temps d'arrêt qui donne du poids à une course.
func _arret_franc() -> Vector2:
	if _stop_left <= 0.0:
		_stop_left = STOP_PLANT + STOP_FALL
	_stop_left = maxf(0.0, _stop_left - _delta)
	if _stop_left > STOP_FALL:
		# Temps d'arrêt : on tient la foulée là où elle s'est arrêtée.
		return _stop_blend
	if _stop_left <= 0.0:
		# Fini : plus rien à marquer avant la prochaine course.
		_peak_speed = 0.0
		return Vector2.ZERO
	# Puis on retombe vers l'attente, sans claquer.
	return _stop_blend * (_stop_left / STOP_FALL)

## Vitesse maximale que le mélange de sol sait fabriquer DANS UNE DIRECTION
## donnée, en mètres par seconde.
##
## En dessous, la cadence reste à 1 : les points étant posés aux vitesses
## mesurées, le mélange produit déjà la bonne allure et la retoucher ne ferait
## que la casser. Au-dessus, il n'y a plus de clip assez rapide et il faut bien
## accélérer le film — c'est le cas normal, puisque les classes courent entre
## 4,2 et 5,3 m/s.
##
## Les trois plafonds — avant, arrière, côté — décrivent une ellipse, et la
## capacité dans une direction est son rayon dans cette direction. Prendre
## simplement le plafond avant ferait pédaler un personnage qui tourne autour
## d'un boss à sept fois la cadence de son pas chassé.
func _capacite(blend: Vector2) -> float:
	var direction: Vector2 = blend.normalized()
	if direction.is_zero_approx():
		return _run
	var avant: float = _run if direction.y >= 0.0 else _back
	var cote: float = _strafe
	var terme: float = pow(direction.x / cote, 2.0) \
		+ pow(direction.y / avant, 2.0)
	if terme <= 0.0001:
		return _run
	return 1.0 / sqrt(terme)

func _drive_dodge(actor: Actor, progress: float) -> void:
	var rolling: bool = actor.state == Actor.State.DODGING
	if rolling and not _dodging:
		# Le clip se choisit au DÉCLENCHEMENT : une roulade en avant et un pas
		# en arrière ne sont pas le même geste, et jouer une roulade à reculons
		# donne un personnage qui se vautre vers l'arrière.
		_roll.animation = _step_clip if actor.dodge_backstep else _roll_clip
	if rolling:
		# On repose la roulade à chaque image sur l'avancement de l'esquive
		# simulée. `dodge_span` coupe le temps mort de fin de clip, où le
		# personnage est déjà debout et ne fait plus rien.
		var length: float = 0.0
		if _player.has_animation(_roll.animation):
			length = _player.get_animation(_roll.animation).length
		var span: float = clampf(_model.backstep_span if actor.dodge_backstep
			else _model.dodge_span, 0.05, 1.0)
		_tree.set(&"parameters/temps_roulade/seek_request",
			clampf(progress, 0.0, 1.0) * length * span)
	if rolling == _dodging:
		return
	_dodging = rolling
	if rolling:
		_fire(&"esquive")

## Le geste d'attaque est CHOISI par identifiant d'attaque, puis accéléré ou
## ralenti pour que son CONTACT tombe sur l'ouverture de la hitbox.
##
## Il était simplement étiré pour durer aussi longtemps que l'attaque simulée.
## Ça aligne les DÉBUTS, pas les impacts, et ce n'est pas la même chose : sur
## les onze attaques du jeu, dix montraient le coup entre 350 ms trop tôt et
## 415 ms trop tard. Une demi-seconde d'écart, c'est la lame qui traverse
## l'ennemi sans rien faire puis les dégâts qui tombent après — le défaut qui
## rend un coup mou.
##
## Une seule vitesse de lecture ne peut aligner qu'un seul instant. On choisit
## le contact, parce que c'est le seul que le joueur regarde.
func _drive_attack(actor: Actor) -> void:
	var runner: AttackRunner = actor.runner
	var striking: bool = runner != null and not runner.finished \
		and runner.attack != null
	if not striking:
		_attacking = false
		_attack_id = &""
		_attack_ticks = -1
		return
	# UN ENCHAÎNEMENT N'EST PAS UNE CONTINUATION.
	#
	# Le geste ne se déclenchait que sur le front « ne frappait pas » ->
	# « frappe ». Or une fenêtre d'annulation laisse le deuxième coup partir
	# AVANT que le premier ait fini : le dérouleur ne repasse jamais par
	# `finished`, le front n'existe pas, et le deuxième coup continuait de
	# montrer l'animation du premier — au tempo du premier, donc avec un
	# contact aligné sur la mauvaise hitbox. Toute une combo ne jouait qu'un
	# seul geste, celui d'ouverture.
	#
	# On compare donc l'IDENTITÉ de l'attaque et son AVANCEMENT. L'identifiant
	# attrape l'enchaînement vers un autre coup ; le compte de ticks, qui
	# repart à zéro à chaque `start`, attrape le même coup relancé deux fois de
	# suite — que l'identifiant, lui, ne distingue pas.
	var id: StringName = runner.attack.id
	var ticks: int = runner.elapsed_ticks
	var nouveau: bool = not _attacking or id != _attack_id \
		or ticks < _attack_ticks
	_attacking = true
	_attack_id = id
	_attack_ticks = ticks
	if not nouveau:
		return
	var wanted: StringName = _model.attack_clips.get(id, _model.attack)
	_attack.animation = _clip(wanted, _model.attack)
	_tree.set(&"parameters/tempo/scale", _tempo(runner.attack))
	_attack_fires += 1
	_fire(&"coup")

## Vitesse de lecture qui fait tomber le contact du clip sur l'ouverture de la
## hitbox. Retombe sur l'ancien étirement de durée si l'un des deux instants
## n'est pas connu.
func _tempo(attack: AttackData) -> float:
	if not _player.has_animation(_attack.animation):
		return 1.0
	var clip: float = _player.get_animation(_attack.animation).length
	var simulated: float = 0.0
	if attack.timeline != null:
		simulated = attack.timeline.length
	var contact: float = 0.0
	if _model.attack_contact.has(_attack.animation):
		contact = _model.attack_contact[_attack.animation]
	var opening: float = SaltAnimator._hitbox_opening(attack)
	if contact > 0.001 and opening > 0.001:
		return clampf(contact / opening, 0.25, 4.0)
	if simulated > 0.01:
		return clampf(clip / simulated, 0.25, 4.0)
	return 1.0

## Instant, en secondes, où la ligne de temps d'une attaque ouvre sa hitbox.
## Négatif si elle n'en ouvre pas — un soin, par exemple.
static func _hitbox_opening(attack: AttackData) -> float:
	if attack == null or attack.timeline == null:
		return -1.0
	var timeline: Animation = attack.timeline
	for track: int in timeline.get_track_count():
		if timeline.track_get_type(track) != Animation.TYPE_METHOD:
			continue
		for key: int in timeline.track_get_key_count(track):
			var value: Dictionary = timeline.track_get_key_value(track, key)
			if str(value.get("method", "")) == "open_hitbox":
				return timeline.track_get_key_time(track, key)
	return -1.0

func _drive_hurt(actor: Actor) -> void:
	var hit: bool = actor.state == Actor.State.STAGGERED
	if hit == _staggering:
		return
	_staggering = hit
	if not hit:
		return
	_hurt.animation = _clip(
		_model.hurt_alt if _flip else _model.hurt, _model.hurt)
	_flip = not _flip
	_fire(&"douleur")

## ARRÊT SUR IMAGE. Le geste se fige quelques centièmes de seconde à l'instant
## où le coup porte, des deux côtés.
##
## C'est le seul moyen de faire peser un coup sans toucher aux dégâts. Sans
## lui, une arme traverse un corps sans que rien ne marque le contact : on voit
## une barre de vie descendre, on ne SENT rien. Un souls-like se reconnaît à ce
## dixième de seconde.
##
## Invariant 1 : ceci ne touche PAS la simulation. Le personnage continue de se
## déplacer, la hitbox continue de vivre en ticks — seule l'image de son geste
## s'arrête. Une pause qui suspendrait le monde serait une désynchronisation.
const FREEZE_SECONDS: float = 0.085

var _freeze_left: float = 0.0

func freeze() -> void:
	_freeze_left = FREEZE_SECONDS

## À appeler chaque image. Rend la main au temps normal quand le gel est fini.
##
## C'est aussi ici qu'on retient la durée de l'image : `drive` ne la reçoit pas,
## et le demi-tour comme l'arrêt franc en ont besoin. Les deux sont appelés
## dans la même passe, celui-ci en premier.
func tick_freeze(delta: float) -> void:
	if _tree == null:
		return
	_delta = delta
	if _freeze_left <= 0.0:
		return
	_freeze_left -= delta
	_tree.set(&"parameters/gel/scale", 0.0 if _freeze_left > 0.0 else 1.0)

func _fire(node: StringName) -> void:
	_tree.set("parameters/%s/request" % node,
		AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
