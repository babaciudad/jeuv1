## Géométrie et points d'intérêt du niveau.
##
## Invariant 7 : la donnée vit dans res://data/, le code n'en contient pas.
## Le niveau est décrit comme une union de rectangles praticables dans le plan
## XZ. Pas de maillage de navigation, pas de physique : un couloir se décrit
## en cinq rectangles et se teste sans moteur.
class_name LevelData
extends Resource

## Identifiant du niveau. Sert à retrouver son décor :
## res://data/decor/<id>.tres. Aucune table dans le code.
@export var id: StringName = &""

## Rectangles praticables. Un acteur peut être partout dans leur union.
@export var walkable: Array[Rect2] = []
## Obstacles pleins À L'INTÉRIEUR du praticable : piliers, gravats, autel.
## Ils bloquent les déplacements ET les projectiles, exactement comme un mur —
## un décor qu'on traverse est un décor qui ment.
@export var obstacles: Array[Rect2] = []
## Hauteur de chaque obstacle, dans le MÊME ordre que `obstacles`. Zéro, ou
## valeur manquante : l'obstacle monte jusqu'au plafond, c'est un pilier.
## Une hauteur déclarée en fait un meuble — un autel, un brasero.
##
## C'est de la donnée de simulation bien qu'elle ne serve qu'à l'affichage :
## un obstacle est dessiné À PARTIR de son emprise, jamais posé à côté. Un
## meuble dessiné ailleurs que là où il bloque est le pire des bugs, celui
## qu'on met des heures à ne pas attribuer au réseau.
@export var obstacle_heights: Array[float] = []
## Hauteur sous plafond de chaque rectangle praticable, dans le MÊME ordre que
## `walkable`. Une nef à sept mètres et un boyau à trois mètres ne se
## ressemblent pas, et c'est ce qui fait qu'on sent qu'on entre quelque part.
## Un rectangle sans hauteur déclarée prend `default_ceiling`.
@export var ceiling_heights: Array[float] = []
@export var default_ceiling: float = 3.6
## Rectangles À CIEL OUVERT, dans le MÊME ordre que `walkable`. Un rectangle
## ouvert n'a pas de plafond, et ce qui le borde n'est pas une muraille mais
## un muret : c'est la différence entre traverser une salle et sortir dehors.
##
## C'est de la donnée de simulation bien qu'elle ne serve qu'à l'affichage —
## comme les hauteurs. La raison est la même : la caméra interroge `height_at`
## pour savoir si elle a la place de reculer, et il n'y a pas deux vérités.
@export var open_sky: Array[bool] = []

## Dégagement rendu par `height_at` au-dessus d'une zone ouverte. Assez haut
## pour qu'aucune caméra ne cherche à s'y cogner, assez fini pour rester un
## nombre.
const SKY_CLEARANCE: float = 24.0

## Vrai si le point est sous le ciel. Un point couvert par DEUX rectangles,
## l'un ouvert l'autre non, compte comme ouvert : c'est le seuil d'une porte,
## et un seuil appartient au dehors.
func is_open(point: Vector2) -> bool:
	for index: int in walkable.size():
		if index >= open_sky.size() or not open_sky[index]:
			continue
		if walkable[index].has_point(point):
			return true
	return false
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
## Position du mannequin d'entraînement. Zéro : pas de mannequin.
@export var training_dummy_position: Vector2 = Vector2.ZERO

## Position de départ du boss.
@export var boss_spawn: Vector2 = Vector2.ZERO

## Hauteur sous plafond au point donné. Le PLUS HAUT des rectangles qui le
## contiennent : deux salles qui se touchent partagent une bande de cases, et
## rogner le plafond de la grande sur celui du couloir ferait une marche.
func height_at(point: Vector2) -> float:
	var best: float = 0.0
	for index: int in walkable.size():
		if not walkable[index].has_point(point):
			continue
		if index < open_sky.size() and open_sky[index]:
			return SKY_CLEARANCE
		var height: float = default_ceiling
		if index < ceiling_heights.size() and ceiling_heights[index] > 0.0:
			height = ceiling_heights[index]
		best = maxf(best, height)
	return best if best > 0.0 else default_ceiling

## Hauteur de l'obstacle d'indice donné : celle qui est déclarée, sinon le
## plafond de l'endroit où il se trouve.
func obstacle_height(index: int) -> float:
	if index < obstacle_heights.size() and obstacle_heights[index] > 0.0:
		return obstacle_heights[index]
	var rect: Rect2 = obstacles[index]
	return height_at(rect.position + rect.size * 0.5)
