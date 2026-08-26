## Réglages d'une attaque.
##
## Invariant 7 : toutes les valeurs réglables sont ici, aucune dans le code.
## Invariant 8 : le CALENDRIER de l'attaque n'est pas ici — il vit dans
## `timeline`, une Animation dont les pistes d'appel de méthode ouvrent et
## ferment la hitbox. Cette séparation est volontaire : les nombres se règlent
## dans l'inspecteur, le rythme se règle dans l'éditeur d'animation, et aucun
## minuteur parallèle ne peut diverger de l'animation.
class_name AttackData
extends Resource

@export var id: StringName = &""
## Animation ne portant que des pistes d'appel de méthode. Méthodes appelées :
## open_hitbox(), close_hitbox(), allow_cancel(), finish().
##
## CONVENTION D'ÉCRITURE — une clé destinée au tick N se pose à (N - 0,5)/60
## seconde, pas à N/60. La simulation avance l'animation par pas de 1/60 s et
## le cumul en flottant ne tombe jamais exactement sur une borne : une clé
## posée pile sur le tick déclenche une fois sur deux au tick suivant. Poser
## la clé au milieu de l'intervalle précédent supprime le problème.
@export var timeline: Animation
@export_group("Coûts et dégâts")
@export var damage: int = 10
@export var poise_damage: int = 10
@export var stamina_cost: int = 20
@export_group("Portée")
@export var range_meters: float = 2.2
@export var half_angle_degrees: float = 60.0
## Décalage de l'axe du cône par rapport au cap, en degrés.
##
## Un cône symétrique ne sait pas décrire un coup DIAGONAL, et c'est pourtant
## ce que sont presque tous les gestes de la bibliothèque : mesuré en jeu,
## l'épée du gardien balaie de 0 à +63 degrés, c'est-à-dire entièrement d'un
## côté. Sans ce décalage, la moitié du cône touchait là où le fer ne passe
## jamais — le joueur voyait son coup partir à gauche et l'ennemi mourir à
## droite. Voir `tools/frappe.gd`, qui mesure le balayage réel du fer.
@export var arc_offset_degrees: float = 0.0
@export_group("Projectile")
## Non nul : l'attaque tire au lieu de balayer un arc. La portée et l'angle
## ci-dessus ne servent alors plus.
@export var projectile: ProjectileData

@export_group("Soin")
## Points de vie rendus à un allié touché. Une attaque qui soigne ne blesse
## personne : elle cherche des alliés, pas des ennemis.
@export var heal: int = 0

@export_group("Mouvement")
## Vitesse d'avancée pendant l'attaque, en mètres par seconde.
@export var forward_speed: float = 2.0
## Rotation maximale par tick tant que la hitbox n'est pas ouverte.
@export var tracking_degrees_per_tick: float = 4.0
