## Une pièce d'un skin : une primitive posée sur un os du personnage.
##
## Présentation pure. La simulation ignore que ce type existe — un skin ne
## change ni une hitbox, ni une portée, ni un rayon de collision. Ce qu'on voit
## habille ce qui se joue, ça ne le remplace pas.
##
## Pas de modèle importé : la direction artistique PS1/PS2 se tient très bien
## en boîtes et en cônes, et un personnage entier coûte ici quelques dizaines
## de triangles. Ce qui fait un personnage plutôt qu'un tas de caisses, ce
## n'est pas le nombre de pièces : c'est `role`, qui les accroche à un pivot
## articulé.
class_name SkinPart
extends Resource

enum Shape {
	BOX,
	CAPSULE,
	SPHERE,
	CYLINDER,
	CONE,
	TORUS,
	PRISM,
}

## Os auquel la pièce est accrochée. STATIC reste solidaire du buste ; tous les
## autres suivent le pivot correspondant, qui tourne pendant la marche et
## l'attaque. Une pièce mal rôlée ne casse rien, elle ne bouge simplement pas.
enum Role {
	STATIC,
	HEAD,
	ARM_L,
	ARM_R,
	FOREARM_L,
	FOREARM_R,
	THIGH_L,
	THIGH_R,
	SHIN_L,
	SHIN_R,
}

@export var shape: Shape = Shape.BOX
@export var role: Role = Role.STATIC

## Dimensions, interprétées selon la forme :
##   BOX, PRISM : largeur, hauteur, profondeur
##   CAPSULE    : rayon, hauteur totale, —
##   SPHERE     : rayon, —, —
##   CYLINDER   : rayon du haut, hauteur, rayon du bas
##   CONE       : rayon de la base, hauteur, —
##   TORUS      : rayon intérieur, —, rayon extérieur
@export var size: Vector3 = Vector3.ONE

## Position RELATIVE AU PIVOT de son rôle, pas au sol. Pour une pièce STATIC le
## pivot est le sol du personnage, donc y = 0 au sol ; pour un bras, le pivot
## est l'épaule, et une pièce de bras a donc un y négatif — elle pend.
## -z est l'avant du personnage.
@export var offset: Vector3 = Vector3.ZERO
@export var rotation_degrees: Vector3 = Vector3.ZERO

## Couleur propre de la pièce. Ignorée si `tinted` vaut vrai.
@export var color: Color = Color(0.70, 0.70, 0.72)
## Prend la couleur de la classe ou de l'espèce, décalée par `tint_shift`.
## C'est ce qui fait qu'un même skin reste lisible quelle que soit la couleur.
@export var tinted: bool = false
@export_range(-1.0, 1.0) var tint_shift: float = 0.0
## Non éclairé : pour ce qui doit briller dans le noir du couloir.
@export var unshaded: bool = false

## Pièce d'arme. Elle change de couleur quand la hitbox est ouverte, et c'est
## le SEUL repère de rythme du jeu — le tutoriel l'enseigne explicitement.
## Un skin sans pièce d'arme rend son porteur illisible en combat.
@export var is_weapon: bool = false
