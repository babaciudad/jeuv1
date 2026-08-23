## Réglages d'un projectile. Invariant 7.
##
## Un projectile est entièrement déterminé par son origine, sa direction et son
## tick de départ : toutes les machines calculent donc la même trajectoire sans
## que l'hôte ait à la diffuser image par image. Seule la TOUCHE demande une
## autorité, et elle suit la règle des attaques au corps-à-corps — le tireur
## déclare, l'hôte confirme.
class_name ProjectileData
extends Resource

@export var speed: float = 18.0
@export var radius: float = 0.3
## Durée de vie, en ticks. Passé ce délai le projectile disparaît, même s'il
## n'a rien touché : sans cela un tir raté volerait indéfiniment.
@export var lifetime_ticks: int = 90
@export var color: Color = Color(0.85, 0.75, 0.45)
