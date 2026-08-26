## Un personnage en modèle importé, à la place des primitives.
##
## Résolu par identifiant : res://models/<id>.tres, où <id> est celui de la
## classe ou de l'espèce — la même convention que les skins. Si le fichier
## existe, il gagne ; sinon la vue retombe sur le skin en primitives. Aucune
## table dans le code, et le jeu reste jouable sans aucun modèle.
##
## Invariant 2 : présentation pure. La simulation ne sait pas qu'un modèle
## existe, et le jeu se joue exactement pareil avec ou sans.
##
## Invariant 8, et c'est le point délicat : **l'animation d'attaque du modèle
## est DÉCORATIVE**. Ce n'est jamais elle qui ouvre une hitbox — c'est
## AttackRunner, en ticks, avec ses pistes d'appel de méthode. L'animation
## importée est simplement ÉTIRÉE pour durer exactement le temps de l'attaque
## simulée, afin que le geste tombe au bon moment. Si un jour un modèle
## apportait ses propres pistes de hitbox, il faudrait les supprimer, pas les
## brancher.
class_name ModelData
extends Resource

@export var id: StringName = &""
## La scène importée. Un .glb déposé dans res://models/ est utilisable tel
## quel : Godot l'importe en PackedScene sans greffon.
@export var scene: PackedScene

## Bibliotheque d'animations supplementaire, greffee sur le lecteur du modele
## au montage. Le rig humain est livre en trois fichiers — un corps et deux
## paquets de gestes — et les fusionner ici evite de versionner un .glb de
## onze mega-octets par personnage pour six fois les memes clips.
@export var extra_animations: PackedScene
## Prefixe sous lequel la bibliotheque supplementaire est greffee. Un clip qui
## en vient s'ecrit donc `plus/Dodge_left`.
@export var extra_prefix: StringName = &"plus"

@export_group("Mise en place")
## Facteur d'échelle. Un modèle exporté en centimètres arrive cent fois trop
## grand ; celui-ci le remet à la taille du personnage.
@export var scale: float = 1.0
## Rotation à appliquer si le modèle ne regarde pas vers -Z, qui est l'avant
## dans ce projet.
@export var yaw_degrees: float = 0.0
## Décalage vertical, si les pieds du modèle ne sont pas à son origine.
@export var lift: float = 0.0

@export_group("Noms d'animations")
## Les noms tels qu'ils sont DANS le modèle. Vides : l'état correspondant
## réutilise l'animation de repos, ce qui est laid mais jamais bloquant.
@export var idle: StringName = &"Idle_A"
@export var walk: StringName = &"Walk"
@export var run: StringName = &"Jog"
@export var attack: StringName = &"Sword_Regular_A"
@export var dodge: StringName = &"Roll"
@export var hurt: StringName = &"Hit_Chest"
@export var death: StringName = &"Death_D"

@export_group("Locomotion dirigée")
## Marche et course de dos, et pas chassés. Un souls-like passe la moitié de
## son temps à reculer devant un boss ou à tourner autour : sans ces clips, le
## personnage recule en marchant en avant, ce qui est le défaut d'animation le
## plus visible du genre.
@export var walk_back: StringName = &"plus/Walk_Backwards"
@export var strafe_left: StringName = &"plus/Strafe_left"
@export var strafe_right: StringName = &"plus/Strafe_right"
## Vitesse, en mètres par seconde, à laquelle chaque clip a été ANIMÉ. Elle
## sert à caler la cadence sur la distance réellement parcourue : c'est la
## seule façon d'éviter le patinage, et elle change dès qu'on touche aux
## proportions du squelette.
@export var walk_clip_speed: float = 1.45
@export var run_clip_speed: float = 3.70

@export_group("Réactions")
## Deuxième encaissement et deuxième chute. Alternés d'une fois sur l'autre :
## un ennemi qui reçoit six coups et joue six fois la même secousse cesse
## d'avoir l'air vivant.
@export var hurt_alt: StringName = &"Hit_Head"
@export var death_alt: StringName = &"plus/Death_B"

@export_group("Gestes d'attaque")
## Clip par identifiant d'attaque. Un gardien qui abat une lame lourde et un
## gardien qui tranche vite ne font pas le même geste, et c'est ce qui rend
## une attaque lisible AVANT l'impact. Une attaque absente de la table retombe
## sur `attack`.
@export var attack_clips: Dictionary[StringName, StringName] = {}

@export_group("Réglages")
## Vitesse, en mètres par seconde, au-delà de laquelle on passe de la marche
## à la course.
@export var run_speed: float = 3.4
## Durée du fondu entre deux animations, en secondes.
@export var blend_time: float = 0.18
