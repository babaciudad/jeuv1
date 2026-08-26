## Mesure sur un clip d'animation : vitesse au sol, instant du contact.
##
## POURQUOI CETTE CLASSE EXISTE
##
## Le mélangeur de locomotion a besoin de savoir à quelle vitesse chaque clip a
## été animé, et le mélangeur d'attaque a besoin de savoir à quel instant le
## coup porte. Ces nombres étaient saisis à la main, et ils étaient tous faux :
## la marche déclarée à 1,45 m/s en produisait 0,69, les pas chassés déclarés à
## 3,70 en produisaient 0,73, et dix attaques sur onze montraient leur impact
## entre 350 ms trop tôt et 415 ms trop tard.
##
## Ils sont donc MESURÉS, ici, par un code que `make_models` utilise pour les
## écrire et que la suite de tests utilise pour vérifier qu'ils n'ont pas
## dérivé. Une fiche modifiée à la main, ou un clip changé sans régénérer, fait
## échouer les tests au lieu de passer inaperçu pendant des semaines.
##
## ON NE PASSE PAS PAR L'ANIMATIONPLAYER pour poser le squelette : hors boucle
## de rendu il ne pose rien du tout, et toutes les mesures sortent égales à la
## pose de repos sans qu'aucune erreur ne soit levée. La chaîne d'os est donc
## composée à la main depuis les pistes du clip.
##
## Invariant 2 : présentation pure. Rien ici ne lit ni n'écrit la simulation.
class_name ClipMeasure
extends RefCounted

## Tolérance d'appui, en mètres : un pied dont la hauteur dépasse le point le
## plus bas du clip de plus que ça est considéré en l'air.
const APPUI: float = 0.05
## Échantillons par clip. Assez fin pour qu'une phase d'appui de course, qui ne
## dure qu'un tiers du cycle, soit décrite par une soixantaine de points.
const PAS: int = 192

## Transformées globales de tous les os, pour un clip à un instant donné.
static func poses(skeleton: Skeleton3D, prefix: String, anim: Animation,
		time: float) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	out.resize(skeleton.get_bone_count())
	for index: int in skeleton.get_bone_count():
		var rest: Transform3D = skeleton.get_bone_rest(index)
		var track: NodePath = NodePath(
			prefix + ":" + skeleton.get_bone_name(index))
		var position: Vector3 = rest.origin
		var rotation: Quaternion = rest.basis.get_rotation_quaternion()
		var scaling: Vector3 = rest.basis.get_scale()
		var tp: int = anim.find_track(track, Animation.TYPE_POSITION_3D)
		var tr: int = anim.find_track(track, Animation.TYPE_ROTATION_3D)
		var ts: int = anim.find_track(track, Animation.TYPE_SCALE_3D)
		if tp >= 0:
			position = anim.position_track_interpolate(tp, time)
		if tr >= 0:
			rotation = anim.rotation_track_interpolate(tr, time)
		if ts >= 0:
			scaling = anim.scale_track_interpolate(ts, time)
		var local: Transform3D = Transform3D(
			Basis(rotation).scaled(scaling), position)
		var parent: int = skeleton.get_bone_parent(index)
		out[index] = local if parent < 0 else out[parent] * local
	return out

## Chemin de nœud du squelette relatif à la racine du lecteur : c'est le
## préfixe des pistes d'os dans les clips.
static func prefix_for(player: AnimationPlayer, skeleton: Skeleton3D) -> String:
	var root: Node = player.get_node_or_null(player.root_node)
	if root == null:
		return ""
	return String(root.get_path_to(skeleton))

## Vitesse au sol d'un clip de locomotion, en mètres par seconde.
##
## Un clip de locomotion est animé SUR PLACE : le personnage ne bouge pas, mais
## son pied d'appui recule sous lui, exactement à la vitesse à laquelle il est
## censé avancer. On intègre donc le recul du pied d'appui — et UNIQUEMENT
## pendant l'appui : pendant l'envol d'une foulée de course, le pied le plus bas
## revient vers l'avant, et le compter fausse la mesure d'un bon quart.
static func ground_speed(skeleton: Skeleton3D, prefix: String,
		anim: Animation, pelvis: int, left: int, right: int) -> float:
	if anim == null or pelvis < 0 or left < 0 or right < 0:
		return 0.0
	var length: float = anim.length
	if length <= 0.01:
		return 0.0
	var low: Array[Vector3] = []
	var hips: Array[Vector3] = []
	var support: Array[int] = []
	low.resize(PAS + 1)
	hips.resize(PAS + 1)
	support.resize(PAS + 1)
	var ground: float = 1e9
	for index: int in PAS + 1:
		var frame: Array[Transform3D] = ClipMeasure.poses(
			skeleton, prefix, anim, length * float(index) / float(PAS))
		var l: Vector3 = frame[left].origin
		var r: Vector3 = frame[right].origin
		support[index] = 0 if l.y <= r.y else 1
		low[index] = l if support[index] == 0 else r
		hips[index] = frame[pelvis].origin
		ground = minf(ground, low[index].y)
	var travel: float = 0.0
	var stance: float = 0.0
	var step: float = length / float(PAS)
	for index: int in range(1, PAS + 1):
		if support[index] != support[index - 1]:
			continue
		if low[index].y > ground + APPUI or low[index - 1].y > ground + APPUI:
			continue
		var before: Vector3 = low[index - 1] - hips[index - 1]
		var after: Vector3 = low[index] - hips[index]
		travel += Vector2(after.x - before.x, after.z - before.z).length()
		stance += step
	if stance <= 0.0001:
		return 0.0
	return travel / stance

## Instant du contact dans un clip d'attaque, en secondes : l'image où la main
## d'arme est le plus en AVANT, mesurée dans le repère du bassin.
##
## Trois façons de le trouver ont été comparées sur les huit clips d'attaque du
## jeu — pointe de vitesse, extension maximale, pic de freinage :
##
##   Sword_Regular_A      vitesse 96 %   extension 52 %   freinage 66 %
##   Sword_Regular_C      vitesse 38 %   extension 40 %   freinage 40 %
##   Attack_Ground_Pound  vitesse  6 %   extension 27 %   freinage  8 %
##
## La pointe de vitesse tombe sur le raccord de boucle des clips courts, et le
## freinage sur des secousses de départ. L'extension est juste sur six clips
## sur huit et jamais absurde. On la cherche dans les 80 premiers pour cent du
## clip : au-delà, on est dans le retour de garde, pas dans le coup.
static func contact_time(skeleton: Skeleton3D, prefix: String,
		anim: Animation, pelvis: int, hand: int) -> float:
	if anim == null or pelvis < 0 or hand < 0:
		return 0.0
	var length: float = anim.length
	if length <= 0.01:
		return 0.0
	var farthest: float = -1e9
	var when: float = length * 0.4
	var fastest: float = 0.0
	var quickest: float = length * 0.4
	var previous: Vector3 = Vector3.ZERO
	var last: int = int(float(PAS) * 0.8)
	for index: int in last + 1:
		var time: float = length * float(index) / float(PAS)
		var frame: Array[Transform3D] = ClipMeasure.poses(
			skeleton, prefix, anim, time)
		var reach: Vector3 = frame[hand].origin - frame[pelvis].origin
		if reach.z > farthest:
			farthest = reach.z
			when = time
		if index > 0:
			var speed: float = (reach - previous).length()
			if speed > fastest:
				fastest = speed
				quickest = time
		previous = reach
	# Un tir à l'arc n'a pas d'extension : la main d'arme part déjà tendue et
	# revient. Quand l'extension maximale tombe sur la toute première image,
	# c'est ce cas-là, et le coup part au moment où la main va le plus vite.
	if when < length * 0.05:
		return quickest
	return when

## Fin utile d'un clip d'esquive, en secondes : l'instant où le bassin est
## revenu à sa hauteur de départ après avoir plongé.
##
## Une roulade dure 1,83 s dans la bibliothèque, mais l'esquive simulée dure
## 0,43 s — vingt-six ticks. Jouée telle quelle, la roulade s'arrêtait au quart
## et le personnage se redressait d'un coup au milieu du plongeon. Jouée quatre
## fois trop vite, elle est illisible. En réalité le dernier tiers du clip est
## un temps mort où le personnage est déjà debout : on ne joue que la partie
## utile, et elle tient dans l'esquive à un peu plus du double de sa vitesse.
static func recovery_time(skeleton: Skeleton3D, prefix: String,
		anim: Animation, pelvis: int) -> float:
	if anim == null or pelvis < 0:
		return 0.0
	var length: float = anim.length
	if length <= 0.01:
		return 0.0
	var start: float = ClipMeasure.poses(
		skeleton, prefix, anim, 0.0)[pelvis].origin.y
	if start <= 0.01:
		return length
	var dipped: bool = false
	for index: int in PAS + 1:
		var time: float = length * float(index) / float(PAS)
		var height: float = ClipMeasure.poses(
			skeleton, prefix, anim, time)[pelvis].origin.y
		if height < start * 0.72:
			dipped = true
		elif dipped and height > start * 0.95:
			# Un peu de rab : on veut voir le personnage FINIR de se relever,
			# pas le couper à l'image où il repasse la barre.
			return minf(length, time + length * 0.06)
	return length
