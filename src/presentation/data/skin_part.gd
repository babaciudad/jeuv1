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

## Matière de la pièce. Ne change que son rendu : rugosité, métal, relief de
## surface. Un choix de matière plutôt que six réglages séparés, parce qu'on
## habille un personnage, on ne règle pas un moteur — et parce que deux pièces
## d'acier doivent briller pareil sans qu'on ait à s'en souvenir.
enum Surface {
	## Mat, sans relief. Le défaut, et ce qui convient à la chair.
	PLAIN,
	## Pierre : très rugueuse, grain visible en projection triplanaire.
	STONE,
	## Bois : rugueux, veiné.
	WOOD,
	## Métal : réfléchissant, poli.
	METAL,
	## Tissu et cuir : mat, légèrement duveteux.
	CLOTH,
	## Émissif : brille de sa propre couleur, et déborde dans le halo.
	GLOW,
}

@export var shape: Shape = Shape.BOX
@export var role: Role = Role.STATIC
@export var surface: Surface = Surface.PLAIN

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
## Non éclairé : la pièce ignore la lumière et garde sa couleur pleine.
## `Surface.GLOW` est presque toujours préférable — la pièce brille ET
## éclaire le halo, au lieu d'être un aplat mort au milieu d'une scène
## éclairée.
@export var unshaded: bool = false

## Portée, en mètres, de la lumière émise par une pièce `GLOW`. Zéro : la
## pièce brille sans éclairer autour d'elle.
##
## Il n'y a pas de liste de lampes à part dans ce projet : une lumière naît
## TOUJOURS d'une pièce qu'on voit briller. Une lampe sans source visible, ou
## une flamme qui n'éclaire pas, c'est exactement le genre d'incohérence qu'on
## ne remarque pas en la posant et qu'on ne s'explique plus six mois après.
@export var light_range: float = 0.0

## Pièce d'arme. Elle change de couleur quand la hitbox est ouverte, et c'est
## le SEUL repère de rythme du jeu — le tutoriel l'enseigne explicitement.
## Un skin sans pièce d'arme rend son porteur illisible en combat.
@export var is_weapon: bool = false
