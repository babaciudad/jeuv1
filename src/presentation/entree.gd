## Traduit le clavier et la souris en commandes.
##
## Invariant 3 : c'est le SEUL endroit du jeu qui lit une entrée. La simulation
## ne connaît que des commandes, ce qui la rend rejouable, testable sans
## fenêtre, et transportable sur un réseau le jour où on en voudra un.
##
## La direction est exprimée dans le repère du MONDE, pas dans celui de la
## caméra : c'est ici qu'on fait la conversion, parce que la caméra est de la
## présentation et que la simulation n'a pas le droit de la connaître
## (invariant 2).
class_name Entree
extends RefCounted

static func lire(cap_camera: float) -> Commande:
	var commande: Commande = Commande.new()
	var brut: Vector2 = Input.get_vector(
		&"move_left", &"move_right", &"move_forward", &"move_back")
	if brut.length_squared() > 0.0001:
		# L'avant de la caméra dans le plan, et sa droite.
		var avant: Vector2 = Vector2(sin(cap_camera), cos(cap_camera))
		var droite: Vector2 = Vector2(avant.y, -avant.x)
		# `get_vector` rend +Y quand on appuie sur « reculer » : on avance donc
		# selon -y.
		commande.direction = (droite * brut.x - avant * brut.y).limit_length(1.0)
	commande.cap = cap_camera
	commande.court = Input.is_action_pressed(&"sprint")
	commande.esquive = Input.is_action_just_pressed(&"dodge")
	commande.frappe = Input.is_action_just_pressed(&"attack")
	commande.interagit = Input.is_action_just_pressed(&"interact")
	return commande
