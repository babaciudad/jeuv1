## Décor d'un niveau : des pièces posées, qui ne bloquent rien.
##
## Résolu par identifiant : res://data/decor/<id>.tres, où <id> est celui du
## niveau. Aucune table dans le code.
##
## Invariant 2 : décoration pure. Ce qui doit ARRÊTER un personnage n'a rien à
## faire ici — cela va dans LevelData.obstacles, que la simulation lit. Un
## banc de décor se traverse ; un pilier ne se traverse pas, et il est donc
## déclaré des deux côtés : sa forme ici, son emprise là-bas.
class_name DecorData
extends Resource

@export var id: StringName = &""
## Réutilise SkinPart : une colonne et un bras sont la même chose pour qui
## pose des primitives. Les champs `role` et `is_weapon` sont ignorés ici.
@export var parts: Array[SkinPart] = []
