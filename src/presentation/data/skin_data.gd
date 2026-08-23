## Apparence d'un personnage, en pièces primitives.
##
## Résolu par identifiant : res://data/skins/<id>.tres, où <id> est celui de la
## classe ou de l'espèce. Aucune table dans le code — ajouter une classe et son
## skin ne demande de toucher à aucun fichier .gd.
##
## Vit dans la présentation, pas dans la simulation : PlayerData et EnemyData
## ne connaissent pas ce type, et la simulation tournerait à l'identique sans
## aucun skin.
class_name SkinData
extends Resource

@export var id: StringName = &""
@export var parts: Array[SkinPart] = []
