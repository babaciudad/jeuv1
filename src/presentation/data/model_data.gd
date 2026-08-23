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
@export var idle: StringName = &"idle"
@export var walk: StringName = &"walk"
@export var run: StringName = &"run"
@export var attack: StringName = &"attack"
@export var dodge: StringName = &"dodge"
@export var hurt: StringName = &"hurt"
@export var death: StringName = &"death"

@export_group("Réglages")
## Vitesse, en mètres par seconde, au-delà de laquelle on passe de la marche
## à la course.
@export var run_speed: float = 3.4
## Durée du fondu entre deux animations, en secondes.
@export var blend_time: float = 0.18
