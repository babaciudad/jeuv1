## Géométrie de la simulation.
##
## Le monde est plat : la simulation raisonne dans le plan XZ et n'utilise que
## des Vector2. La hauteur est une affaire de présentation. Un souls-like en
## couloir n'a pas besoin de verticalité, et s'en passer supprime d'un coup la
## gravité, les pentes et les sauts.
class_name SimMath
extends RefCounted

## Nombre de points échantillonnés sur le pourtour d'un acteur pour tester si
## sa position tient dans la zone praticable. Huit suffit pour un couloir :
## un mur ne peut pas se faufiler entre deux échantillons sans être plus mince
## que le rayon d'un personnage.
const CONTACT_SAMPLES: int = 8

## Vrai si le disque de centre `center` et de rayon `radius` tient entièrement
## dans l'union des rectangles praticables, hors bloqueurs actifs.
static func disc_is_free(center: Vector2, radius: float,
		walkable: Array[Rect2], blockers: Array[Rect2]) -> bool:
	if not point_is_free(center, walkable, blockers):
		return false
	for i: int in CONTACT_SAMPLES:
		var angle: float = TAU * float(i) / float(CONTACT_SAMPLES)
		var sample: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		if not point_is_free(sample, walkable, blockers):
			return false
	return true

static func point_is_free(point: Vector2, walkable: Array[Rect2],
		blockers: Array[Rect2]) -> bool:
	for blocker: Rect2 in blockers:
		if blocker.has_point(point):
			return false
	for rect: Rect2 in walkable:
		if rect.has_point(point):
			return true
	return false

## Déplace un acteur de `from` vers `to` en glissant le long des murs.
## Essaie le mouvement complet, puis chaque axe séparément. Trois tests, pas de
## résolution de pénétration : un acteur ne peut jamais entrer dans un mur, il
## n'y a donc jamais à l'en sortir.
static func slide(from: Vector2, to: Vector2, radius: float,
		walkable: Array[Rect2], blockers: Array[Rect2]) -> Vector2:
	if disc_is_free(to, radius, walkable, blockers):
		return to
	var along_x: Vector2 = Vector2(to.x, from.y)
	if not is_equal_approx(along_x.x, from.x) and disc_is_free(along_x, radius, walkable, blockers):
		return along_x
	var along_y: Vector2 = Vector2(from.x, to.y)
	if not is_equal_approx(along_y.y, from.y) and disc_is_free(along_y, radius, walkable, blockers):
		return along_y
	return from

## Vrai si `target` est dans le cône de sommet `origin`, d'axe `facing`,
## de portée `range_meters` et de demi-angle `half_angle_degrees`.
## C'est la forme de toutes les hitboxes du jeu : une arme au corps-à-corps
## balaie un arc, pas une boîte.
static func cone_contains(origin: Vector2, facing: Vector2, range_meters: float,
		half_angle_degrees: float, target: Vector2, target_radius: float) -> bool:
	var offset: Vector2 = target - origin
	var distance: float = offset.length()
	if distance > range_meters + target_radius:
		return false
	if distance <= target_radius:
		return true
	var deviation: float = rad_to_deg(absf(facing.angle_to(offset)))
	# Un adversaire proche est plus facile à toucher de biais : on élargit le
	# cône du demi-angle sous-tendu par son rayon.
	var forgiveness: float = rad_to_deg(asin(clampf(target_radius / distance, 0.0, 1.0)))
	return deviation <= half_angle_degrees + forgiveness

## Fait pivoter `facing` vers `desired` d'au plus `max_degrees`.
## Sert au tracking des attaques (invariant 7 : la valeur vient de la donnée).
static func rotate_towards(facing: Vector2, desired: Vector2, max_degrees: float) -> Vector2:
	if desired.is_zero_approx():
		return facing
	var target: Vector2 = desired.normalized()
	var delta: float = facing.angle_to(target)
	var limit: float = deg_to_rad(max_degrees)
	if absf(delta) <= limit:
		return target
	return facing.rotated(signf(delta) * limit)
