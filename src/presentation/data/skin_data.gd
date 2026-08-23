## Apparence d'un personnage : des pièces primitives, et le squelette sur
## lequel elles sont accrochées.
##
## Résolu par identifiant : res://data/skins/<id>.tres, où <id> est celui de la
## classe ou de l'espèce. Aucune table dans le code — ajouter une classe et son
## skin ne demande de toucher à aucun fichier .gd.
##
## Vit dans la présentation, pas dans la simulation : PlayerData et EnemyData
## ne connaissent pas ce type, et la simulation tournerait à l'identique sans
## aucun skin.
##
## Le squelette tient en six mesures. C'est volontaire : une hiérarchie d'os
## complète demanderait un outil pour être éditée, six nombres se règlent à la
## main et se relisent d'un coup d'œil.
class_name SkinData
extends Resource

@export var id: StringName = &""
@export var parts: Array[SkinPart] = []

## Épaule DROITE. La gauche en est le miroir en x — un personnage asymétrique
## se fait par ses pièces, pas par son squelette.
@export var shoulder: Vector3 = Vector3(0.34, 1.32, 0.0)
## Descente de l'épaule au coude, en mètres (valeur positive).
@export var elbow_drop: float = 0.34
## Hanche DROITE, miroir en x pour la gauche.
@export var hip: Vector3 = Vector3(0.17, 0.86, 0.0)
## Descente de la hanche au genou, en mètres (valeur positive).
@export var knee_drop: float = 0.42
## Base du cou : pivot de la tête.
@export var neck: Vector3 = Vector3(0.0, 1.46, 0.0)

## Amplitude de la foulée, en degrés, à pleine vitesse. Un gobelin trottine
## court et vite, un warden marche long et lourd.
@export var stride_degrees: float = 34.0
## Amplitude du balancement vertical du buste au repos, en mètres. C'est ce
## qui empêche un personnage à l'arrêt d'avoir l'air d'une statue.
@export var idle_bob: float = 0.022
