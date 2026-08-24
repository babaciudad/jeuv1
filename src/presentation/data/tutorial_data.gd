## Les runes d'un niveau, dans l'ordre où on les croise.
##
## Résolu par l'identifiant du niveau : res://data/tutorial/<id>.tres. Même
## convention que les skins et le décor — aucune table dans le code.
class_name TutorialData
extends Resource

@export var id: StringName = &""
@export var signs: Array[TutorialSign] = []
