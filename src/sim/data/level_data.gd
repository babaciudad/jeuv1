## Géométrie et points d'intérêt du niveau.
##
## Invariant 7 : la donnée vit dans res://data/, le code n'en contient pas.
## Le niveau est décrit comme une union de rectangles praticables dans le plan
## XZ. Pas de maillage de navigation, pas de physique : un couloir se décrit
## en cinq rectangles et se teste sans moteur.
class_name LevelData
extends Resource

## Rectangles praticables. Un acteur peut être partout dans leur union.
@export var walkable: Array[Rect2] = []
## Rectangle occupé par le raccourci tant qu'il est fermé.
@export var shortcut_gate: Rect2 = Rect2()
## Position du feu de camp. Point de réapparition de tous les joueurs.
@export var bonfire_position: Vector2 = Vector2.ZERO
## Rayon dans lequel un joueur peut se reposer au feu.
@export var bonfire_radius: float = 3.0
## Position depuis laquelle le raccourci peut être ouvert, et son rayon.
@export var shortcut_switch_position: Vector2 = Vector2.ZERO
@export var shortcut_switch_radius: float = 2.5
## Positions de départ des joueurs, dans l'ordre des places.
@export var player_spawns: Array[Vector2] = []
## Positions de départ des ennemis de base.
@export var enemy_spawns: Array[Vector2] = []
## Position de départ du boss.
@export var boss_spawn: Vector2 = Vector2.ZERO
