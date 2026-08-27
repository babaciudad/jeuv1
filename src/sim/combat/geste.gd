## Un geste de travail, décrit en ticks et rien qu'en ticks.
##
## Invariant 7 : le combat est piloté par la donnée. Un geste est une ressource
## qu'on règle sans toucher au code.
## Invariant 8 : la fenêtre de coup est en TICKS, pas en secondes ni en pistes
## d'animation. L'animation affichée est étirée pour tomber dessus — jamais
## l'inverse. Une animation qui change de durée ne doit rien changer au combat.
class_name Geste
extends Resource

@export var nom: StringName = &"las_lourd"
## Durée totale du geste, en ticks.
@export var duree: int = 58
## Premier et dernier tick où le coup touche.
@export var debut_coup: int = 26
@export var fin_coup: int = 34
## Portée, en mètres, depuis le centre de l'acteur. Le las fait cinq mètres de
## manche : c'est une portée exceptionnelle, et c'est le sel de cette arme.
@export var portee: float = 4.6
## Demi-angle de l'arc balayé, en degrés. Le las balaie large.
@export var demi_angle: float = 62.0
@export var degats: float = 34.0
@export var cout_endurance: float = Reglages.ENDURANCE_COUP_LAS
## Déplacement imposé par le geste, en mètres par seconde, vers l'avant. Le
## paludier avance un peu en tirant : le las racle vers soi sur toute la
## longueur du bassin.
@export var poussee: float = 1.1

func coup_actif(tick: int) -> bool:
	return tick >= debut_coup and tick <= fin_coup
