## Habille un squelette animé d'un corps de saunier, taillé en primitives.
##
## Le problème que ce fichier résout : on a besoin d'un VRAI squelette animé —
## marche, course, roulade, coups, chute — et on n'a pas le droit d'afficher
## des personnages achetés sur étagère. La réponse est de séparer les deux :
##
##   — le mouvement vient d'une bibliothèque d'animations sous CC0 (le rig
##     KayKit et ses 76 à 95 clips), exactement comme on utiliserait Mixamo ;
##   — la GÉOMÉTRIE VISIBLE est intégralement fabriquée ici, primitive par
##     primitive, dans la direction artistique du sel.
##
## Aucun maillage importé n'est affiché : `dress()` cache tout ce que le .glb
## apporte et n'en garde que les os. Ce qu'on voit à l'écran n'existe dans
## aucun pack.
##
## Invariant 2 : présentation pure. Rien ici ne touche à une hitbox, à une
## portée ni à un rayon de collision.
class_name SaltBody
extends RefCounted

# ---------------------------------------------------------------------------
# Proportions
# ---------------------------------------------------------------------------

## Le rig d'origine est chibi : jambes deux fois trop courtes, torse trop long.
## On corrige en rallongeant les os, ce qui est possible parce que les clips
## n'animent la POSITION que de `root`, `hips`, des attaches d'épaule et de
## hanche et des os d'IK. Toute la chaîne déformante — cuisses, tibias,
## avant-bras, nuque — n'est animée qu'en ROTATION, donc sa longueur de repos
## nous appartient et une marche reste une marche après l'avoir changée.
##
## Mesuré : hanches à 46 % de la hauteur, épaules à 82 %, bras de 0,78 m pour
## un personnage de 1,78 m. Le pied, lui, n'est PAS rallongé — un pied deux
## fois trop long est le tell le plus voyant d'un personnage étiré.
const LEG: float = 2.10
const TORSO: float = 0.88
const ARM: float = 1.32

## Os dont la longueur de repos est réécrite, et par quel facteur. La longueur
## d'un os est la position de repos de son ENFANT : `lowerleg` porte donc la
## cuisse, `foot` le tibia, `wrist` l'avant-bras.
const STRETCH: Dictionary[String, float] = {
	"lowerleg.l": LEG, "lowerleg.r": LEG,
	"foot.l": LEG, "foot.r": LEG,
	"spine": TORSO, "chest": TORSO, "head": TORSO,
	"lowerarm.l": ARM, "lowerarm.r": ARM,
	"wrist.l": ARM, "wrist.r": ARM,
}

# ---------------------------------------------------------------------------
# Palette du sel
# ---------------------------------------------------------------------------

## Toile huilée : ce que tout le monde porte contre la brûlure du sel.
const TOILE: Color = Color(0.45, 0.43, 0.36)
const TOILE_CLAIRE: Color = Color(0.63, 0.61, 0.52)
## Croûte de sel. C'est la seule chose franchement claire d'un personnage :
## elle doit se lire de loin, parce qu'elle dit depuis combien de temps
## l'ennemi est mort.
const SEL: Color = Color(0.88, 0.90, 0.87)
const SEL_OMBRE: Color = Color(0.64, 0.68, 0.65)
const CUIR: Color = Color(0.31, 0.27, 0.21)
const CORDE: Color = Color(0.72, 0.66, 0.50)
## Verre de saumure : la seule couleur froide saturée du jeu.
const VERRE: Color = Color(0.40, 0.76, 0.68)
const FER: Color = Color(0.27, 0.29, 0.29)
const BRAISE: Color = Color(1.0, 0.55, 0.20)

# ---------------------------------------------------------------------------
# État
# ---------------------------------------------------------------------------

## Toutes les pièces bâties, dans l'ordre. ActorView les enregistre pour
## l'estompage et le clignotement d'arme.
var pieces: Array[MeshInstance3D] = []
var colors: Array[Color] = []
var weapons: Array[bool] = []
## Décalage vertical à appliquer au modèle pour que la cheville retombe où
## elle était avant l'allongement des jambes.
var lift: float = 0.0

var _skeleton: Skeleton3D = null
var _attachments: Dictionary[String, BoneAttachment3D] = {}

# ---------------------------------------------------------------------------
# Entrée
# ---------------------------------------------------------------------------

## Cache les maillages importés, corrige les proportions, et rebâtit un corps.
static func dress(rig: Node3D, id: StringName, _tint: Color) -> SaltBody:
	var body: SaltBody = SaltBody.new()
	body._skeleton = SaltBody._find_skeleton(rig)
	if body._skeleton == null:
		push_warning("Aucun squelette dans le rig %s : corps non bâti." % id)
		return body
	SaltBody._hide_imported(rig)
	body.lift = body._reproportion()
	body._build(id)
	return body

static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = SaltBody._find_skeleton(child)
		if found != null:
			return found
	return null

## Rien de ce que le pack apporte n'est affiché. On ne garde que le mouvement.
static func _hide_imported(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = false
	for child: Node in node.get_children():
		SaltBody._hide_imported(child)

# ---------------------------------------------------------------------------
# Proportions
# ---------------------------------------------------------------------------

## Réécrit les longueurs de repos et renvoie de combien il faut relever le
## personnage. La référence est la CHEVILLE et non le point le plus bas : au
## repos le pied pend en pointe, et se caler dessus soulèverait le personnage
## de dix centimètres au-dessus du sol dès qu'il marche.
func _reproportion() -> float:
	var before: float = _ankle_height()
	for name_: String in STRETCH:
		var index: int = _skeleton.find_bone(name_)
		if index < 0:
			continue
		var rest: Transform3D = _skeleton.get_bone_rest(index)
		rest.origin *= STRETCH[name_]
		_skeleton.set_bone_rest(index, rest)
		_skeleton.set_bone_pose_position(index, rest.origin)
	return before - _ankle_height()

func _ankle_height() -> float:
	var index: int = _skeleton.find_bone("foot.l")
	if index < 0:
		return 0.0
	return _skeleton.get_bone_global_rest(index).origin.y

# ---------------------------------------------------------------------------
# Repères
# ---------------------------------------------------------------------------
#
# Tout le costume se décrit en coordonnées du MONDE — droite, haut, avant —
# et non dans le repère de l'os, dont l'orientation change d'un os à l'autre :
# le +Y d'un bras pointe vers le coude, celui d'une cuisse vers le sol, celui
# d'une main vers l'arrière. Décrire un chapeau dans ce repère-là, c'est
# écrire du code qu'on ne peut ni relire ni corriger.
#
# `_frame()` renvoie la base qui convertit une direction du monde en direction
# locale à l'os, prise sur la pose de REPOS. L'animation fait ensuite tourner
# l'os, et la pièce suit — exactement comme un chapeau suit une tête.

func _frame(bone: String) -> Basis:
	var index: int = _skeleton.find_bone(bone)
	if index < 0:
		return Basis.IDENTITY
	return _skeleton.get_bone_global_rest(index).basis.orthonormalized().inverse()

## Vecteur d'un os vers son enfant, dans le repère de l'os : c'est l'axe et la
## longueur du membre.
func _axis(child: String) -> Vector3:
	var index: int = _skeleton.find_bone(child)
	if index < 0:
		return Vector3(0.0, 0.2, 0.0)
	return _skeleton.get_bone_rest(index).origin

func _attach(bone: String) -> Node3D:
	if _attachments.has(bone):
		return _attachments[bone]
	var index: int = _skeleton.find_bone(bone)
	if index < 0:
		return _skeleton
	var node: BoneAttachment3D = BoneAttachment3D.new()
	node.name = "Sel_" + bone
	_skeleton.add_child(node)
	node.bone_idx = index
	_attachments[bone] = node
	return node

func _mesh(shape: SkinPart.Shape, size: Vector3, color: Color,
		surface: SkinPart.Surface, light_range: float) -> MeshInstance3D:
	var part: SkinPart = SkinPart.new()
	part.shape = shape
	part.size = size
	part.surface = surface
	part.light_range = light_range
	return PrimitiveFactory.instance_for(part, color)

func _register(bone: String, instance: MeshInstance3D, color: Color,
		weapon: bool, light_range: float) -> void:
	_attach(bone).add_child(instance)
	pieces.append(instance)
	colors.append(color)
	weapons.append(weapon)
	if light_range <= 0.0:
		return
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.omni_range = light_range
	lamp.light_energy = 0.30 * light_range
	lamp.light_color = color.lerp(Color(1.0, 0.94, 0.86), 0.4)
	lamp.shadow_enabled = false
	instance.add_child(lamp)

## Pose une primitive sur un os, décrite dans le repère du MONDE : `at` est un
## décalage (droite, haut, avant) en mètres depuis l'os, et la pièce est
## orientée comme le personnage debout.
func _add(bone: String, shape: SkinPart.Shape, size: Vector3, at: Vector3,
		tilt: Vector3, color: Color,
		surface: SkinPart.Surface = SkinPart.Surface.CLOTH,
		weapon: bool = false, light_range: float = 0.0) -> void:
	var instance: MeshInstance3D = _mesh(shape, size, color, surface, light_range)
	if instance == null:
		return
	var frame: Basis = _frame(bone)
	var spin: Basis = Basis.from_euler(Vector3(
		deg_to_rad(tilt.x), deg_to_rad(tilt.y), deg_to_rad(tilt.z)))
	instance.transform = Transform3D(frame * spin, frame * at)
	if shape == SkinPart.Shape.ELLIPSOID:
		instance.scale = size
	_register(bone, instance, color, weapon, light_range)

## Pose une primitive DANS L'AXE d'un membre : de l'os vers son enfant. `from`
## et `to` sont des fractions de la longueur du membre, ce qui rend la pièce
## indépendante des facteurs de proportion — changer LEG rhabille la jambe
## sans qu'aucun nombre de costume ne bouge.
func _limb(bone: String, child: String, shape: SkinPart.Shape,
		from: float, to: float, radius_top: float, radius_bottom: float,
		color: Color, surface: SkinPart.Surface = SkinPart.Surface.CLOTH,
		weapon: bool = false) -> void:
	var axis: Vector3 = _axis(child)
	var length: float = axis.length() * (to - from)
	if length <= 0.0001:
		return
	var size: Vector3 = Vector3(radius_top, length, radius_bottom)
	if shape == SkinPart.Shape.CAPSULE:
		size = Vector3(radius_top, length + radius_top * 2.0, 0.0)
	var instance: MeshInstance3D = _mesh(shape, size, color, surface, 0.0)
	if instance == null:
		return
	var direction: Vector3 = axis.normalized()
	instance.transform = Transform3D(
		Basis(Quaternion(Vector3.UP, direction)),
		axis * ((from + to) * 0.5))
	_register(bone, instance, color, weapon, 0.0)

## Bande de toile enroulée : un anneau plat autour d'un membre. C'est LE motif
## répété du costume — il dit « emmailloté » en une pièce, et il sépare
## l'avant-bras du bras sans ajouter de silhouette.
func _bande(bone: String, child: String, at: float, radius: float,
		color: Color = CORDE) -> void:
	var axis: Vector3 = _axis(child)
	var instance: MeshInstance3D = _mesh(SkinPart.Shape.TORUS,
		Vector3(radius, 0.0, radius + 0.020), color, SkinPart.Surface.CLOTH, 0.0)
	if instance == null:
		return
	# Le tore de Godot est à plat dans le plan XZ : son axe est +Y, donc la
	# même rotation que pour un membre le met d'aplomb autour de l'os.
	instance.transform = Transform3D(
		Basis(Quaternion(Vector3.UP, axis.normalized())), axis * at)
	_register(bone, instance, color, false, 0.0)

## Éclat de sel : une plaque cristalline qui a poussé sur le porteur. Toujours
## de travers, jamais symétrique — c'est ce qui distingue une croûte d'une
## armure.
func _eclat(bone: String, size: Vector3, at: Vector3, tilt: Vector3,
		color: Color = SEL) -> void:
	_add(bone, SkinPart.Shape.BOX, size, at, tilt, color,
		SkinPart.Surface.STONE)
	# Un deuxième bloc plus petit, décalé et retourné : une croûte est une
	# grappe, pas une plaque. C'est ce qui la distingue d'une armure.
	_add(bone, SkinPart.Shape.BOX, size * 0.58,
		at + Vector3(size.x * 0.30, size.y * 0.44, -size.z * 0.26),
		tilt + Vector3(26.0, 34.0, -18.0), color.lightened(0.10),
		SkinPart.Surface.STONE)

# ---------------------------------------------------------------------------
# Anatomie commune
# ---------------------------------------------------------------------------

## Membres : quatre segments par côté, resserrés vers les extrémités, et des
## bandes de corde aux jonctions. Le tibia est le plus serré : c'est là que la
## silhouette se pince, et c'est ce qui donne au corps sa forme de champignon.
func _membres(epaisseur: float, teinte: Color) -> void:
	for side: String in ["l", "r"]:
		_limb("upperarm." + side, "lowerarm." + side, SkinPart.Shape.CYLINDER,
			0.02, 1.0, epaisseur * 0.80, epaisseur * 0.98, teinte)
		_bande("upperarm." + side, "lowerarm." + side, 0.92, epaisseur * 0.82)

		_limb("lowerarm." + side, "wrist." + side, SkinPart.Shape.CYLINDER,
			0.0, 1.0, epaisseur * 0.60, epaisseur * 0.82, teinte)
		_bande("lowerarm." + side, "wrist." + side, 0.30, epaisseur * 0.74)
		_bande("lowerarm." + side, "wrist." + side, 0.68, epaisseur * 0.64)

		# Moufle : une main gantée est un volume, pas une gélule. La manchette
		# la sépare de l'avant-bras, sinon le bras se termine en pointe.
		_add("hand." + side, SkinPart.Shape.ELLIPSOID,
			Vector3(epaisseur * 1.30, epaisseur * 1.70, epaisseur * 1.05),
			Vector3.ZERO, Vector3.ZERO, CUIR)
		_bande("wrist." + side, "hand." + side, 0.94, epaisseur * 0.78,
			TOILE_CLAIRE)

		_limb("upperleg." + side, "lowerleg." + side, SkinPart.Shape.CYLINDER,
			0.0, 1.0, epaisseur * 0.98, epaisseur * 1.22, teinte)
		_limb("lowerleg." + side, "foot." + side, SkinPart.Shape.CYLINDER,
			0.0, 1.0, epaisseur * 0.66, epaisseur * 0.94, teinte)
		_bande("lowerleg." + side, "foot." + side, 0.24, epaisseur * 0.86)
		_bande("lowerleg." + side, "foot." + side, 0.54, epaisseur * 0.78)
		_bande("lowerleg." + side, "foot." + side, 0.82, epaisseur * 0.70)

		# Botte : lourde, carrée, posée à plat devant la cheville.
		_add("foot." + side, SkinPart.Shape.BOX,
			Vector3(epaisseur * 2.1, epaisseur * 1.5, epaisseur * 3.4),
			Vector3(0.0, epaisseur * 0.6, epaisseur * 0.9),
			Vector3.ZERO, CUIR)

## Tronc : trois segments enchaînés de la hanche à la nuque, sans trou, plus
## une ceinture de corde. Sans la ceinture, un tronc ovoïde reste un œuf : ce
## qui fait une taille, c'est la ligne qui la marque.
func _tronc(largeur: float, teinte: Color) -> void:
	# Le tronc se lit en V : large aux épaules, pincé à la taille. Les trois
	# volumes ont d'abord été de la même largeur, et le personnage avait du
	# ventre — c'est le défaut par défaut d'un corps fait d'ovoïdes empilés.
	_add("hips", SkinPart.Shape.ELLIPSOID,
		Vector3(largeur * 0.74, 0.24, largeur * 0.60),
		Vector3(0.0, 0.04, 0.0), Vector3.ZERO, teinte)
	var buste: float = _axis("chest").length()
	_add("spine", SkinPart.Shape.ELLIPSOID,
		Vector3(largeur * 0.70, buste * 1.20, largeur * 0.58),
		Vector3(0.0, buste * 0.40, 0.0), Vector3.ZERO, teinte)
	var nuque: float = _axis("head").length()
	_add("chest", SkinPart.Shape.ELLIPSOID,
		Vector3(largeur * 1.10, nuque * 1.45, largeur * 0.84),
		Vector3(0.0, nuque * 0.22, 0.0), Vector3.ZERO, teinte)
	# Redingote : un tronc de cône de la taille à mi-cuisse. C'est la pièce qui
	# fait passer le personnage d'un pantin articulé à quelqu'un d'habillé —
	# elle couvre la jonction hanche/cuisse, qui est toujours l'endroit où un
	# assemblage de primitives se trahit.
	_add("hips", SkinPart.Shape.CYLINDER,
		Vector3(largeur * 0.68, 0.42, largeur * 0.34),
		Vector3(0.0, -0.13, 0.0), Vector3.ZERO, teinte.darkened(0.34))
	# Épaules : deux bourrelets qui élargissent le haut. La silhouette du sel
	# est large en haut et effilée en bas ; c'est ici qu'elle se décide.
	for side: float in [-1.0, 1.0]:
		_add("chest", SkinPart.Shape.ELLIPSOID,
			Vector3(largeur * 0.52, largeur * 0.44, largeur * 0.60),
			Vector3(side * largeur * 0.56, nuque * 0.52, 0.0),
			Vector3(0.0, 0.0, side * -14.0), teinte)
	_add("hips", SkinPart.Shape.TORUS,
		Vector3(largeur * 0.44, 0.0, largeur * 0.54),
		Vector3(0.0, 0.14, 0.0), Vector3.ZERO, CORDE)

	# Nuque. Sans elle la tête est posée sur les épaules comme une bille sur
	# une étagère, et c'est ce qui trahit le plus un corps assemblé.
	_add("chest", SkinPart.Shape.CYLINDER,
		Vector3(largeur * 0.30, nuque * 0.60, largeur * 0.34),
		Vector3(0.0, nuque * 0.68, 0.0), Vector3(6.0, 0.0, 0.0),
		teinte.darkened(0.18))

	# Plis de la redingote : trois arêtes verticales. Une surface courbe nue
	# n'a aucune ombre propre sous une lumière douce ; trois arêtes suffisent
	# à en faire du tissu.
	for pli: int in 3:
		var angle: float = -34.0 + float(pli) * 34.0
		_add("hips", SkinPart.Shape.BOX,
			Vector3(0.022, 0.38, largeur * 0.16),
			Vector3(sin(deg_to_rad(angle)) * largeur * 0.50, -0.14,
				cos(deg_to_rad(angle)) * largeur * 0.40),
			Vector3(0.0, angle, 0.0), teinte.darkened(0.44))

	# Loques nouées à la ceinture. Elles pendent, elles suivent les hanches, et
	# c'est le seul endroit du costume où quelque chose bouge tout seul.
	for loque: int in 5:
		var tour: float = -58.0 + float(loque) * 29.0
		var longueur: float = 0.16 + float(loque % 3) * 0.08
		_add("hips", SkinPart.Shape.BOX,
			Vector3(0.05, longueur, 0.016),
			Vector3(sin(deg_to_rad(tour)) * largeur * 0.46,
				0.08 - longueur * 0.5,
				cos(deg_to_rad(tour)) * largeur * 0.46),
			Vector3(0.0, tour, float(loque % 2) * 8.0 - 4.0), CORDE)

## Tête emmaillotée : crâne, gaze sur le bas du visage, lunettes de verre. On
## ne voit JAMAIS d'yeux — c'est la règle de silhouette la plus utile du
## projet, parce qu'elle rend un personnage inquiétant sans rien modéliser.
## L'avant du personnage est +Z.
func _tete(rayon: float, teinte: Color, lunettes: bool) -> void:
	_add("head", SkinPart.Shape.ELLIPSOID,
		Vector3(rayon * 1.55, rayon * 2.0, rayon * 1.75),
		Vector3(0.0, rayon * 0.92, 0.0), Vector3.ZERO, teinte)
	_add("head", SkinPart.Shape.ELLIPSOID,
		Vector3(rayon * 1.25, rayon * 0.90, rayon * 1.05),
		Vector3(0.0, rayon * 0.60, rayon * 0.62), Vector3(-14.0, 0.0, 0.0),
		TOILE_CLAIRE)
	if not lunettes:
		return
	for side: float in [-1.0, 1.0]:
		_add("head", SkinPart.Shape.CYLINDER,
			Vector3(rayon * 0.38, rayon * 0.26, rayon * 0.38),
			Vector3(side * rayon * 0.46, rayon * 1.10, rayon * 0.72),
			Vector3(90.0, 0.0, 0.0), FER, SkinPart.Surface.METAL)
		_add("head", SkinPart.Shape.CYLINDER,
			Vector3(rayon * 0.27, rayon * 0.08, rayon * 0.27),
			Vector3(side * rayon * 0.46, rayon * 1.10, rayon * 0.86),
			Vector3(90.0, 0.0, 0.0), VERRE, SkinPart.Surface.GLOW)
	_add("head", SkinPart.Shape.BOX,
		Vector3(rayon * 0.36, rayon * 0.09, rayon * 0.09),
		Vector3(0.0, rayon * 1.10, rayon * 0.74), Vector3.ZERO, FER,
		SkinPart.Surface.METAL)
	# Bandeau de front : la bande de toile qui tient les lunettes. Elle ferme
	# le haut du visage, et c'est elle qui fait qu'on ne cherche pas d'yeux.
	_add("head", SkinPart.Shape.CYLINDER,
		Vector3(rayon * 0.86, rayon * 0.38, rayon * 0.92),
		Vector3(0.0, rayon * 1.14, 0.0), Vector3(90.0, 0.0, 0.0),
		TOILE_CLAIRE.darkened(0.22))

## Chapeau de saunier : un large disque plat et une calotte. C'est la pièce
## qui travaille le plus de tout le costume — elle donne au personnage sa
## silhouette large en haut, et elle se reconnaît de trente mètres.
## `rayon_tete` est celui passé à `_tete` : le chapeau se pose sur le crâne,
## il ne flotte pas au-dessus.
func _chapeau(rayon: float, hauteur: float, teinte: Color,
		rayon_tete: float) -> void:
	var haut: float = rayon_tete * 1.78
	_add("head", SkinPart.Shape.CYLINDER,
		Vector3(rayon * 0.42, 0.030, rayon),
		Vector3(0.0, haut, 0.0), Vector3(6.0, 0.0, 0.0), teinte)
	_add("head", SkinPart.Shape.CONE,
		Vector3(rayon * 0.50, hauteur + rayon_tete * 0.5, 0.0),
		Vector3(0.0, haut + (hauteur + rayon_tete * 0.5) * 0.42, 0.0),
		Vector3.ZERO, teinte)
	_add("head", SkinPart.Shape.TORUS,
		Vector3(rayon * 0.34, 0.0, rayon * 0.46),
		Vector3(0.0, haut + 0.022, 0.0), Vector3.ZERO, CORDE)

## Capuche : une calotte allongée qui déborde vers l'arrière, et une pèlerine
## posée sur les épaules.
func _capuche(rayon: float, teinte: Color) -> void:
	_add("head", SkinPart.Shape.ELLIPSOID,
		Vector3(rayon * 2.1, rayon * 2.3, rayon * 2.5),
		Vector3(0.0, rayon * 0.98, -rayon * 0.22), Vector3.ZERO, teinte)
	# Creux d'ombre : un volume presque noir juste derrière l'ouverture. Une
	# capuche éclairée à l'intérieur ne cache rien ; celle-ci fait un trou.
	_add("head", SkinPart.Shape.ELLIPSOID,
		Vector3(rayon * 1.5, rayon * 1.5, rayon * 1.1),
		Vector3(0.0, rayon * 1.02, rayon * 0.42), Vector3.ZERO,
		Color(0.05, 0.06, 0.06))
	_add("chest", SkinPart.Shape.CONE,
		Vector3(rayon * 2.2, rayon * 1.6, 0.0),
		Vector3(0.0, _axis("head").length() * 0.62, 0.0),
		Vector3(180.0, 0.0, 0.0), teinte)

# ---------------------------------------------------------------------------
# Armes
# ---------------------------------------------------------------------------
#
# Une arme tenue est décrite comme le reste : en coordonnées du monde, sur
# l'os `handslot.r`. Debout au repos, elle est donc verticale, poignée en bas.

## Repère de PRISE, dans les coordonnées de l'os de main.
##
## Mesuré à l'écran, pas déduit : `tools/planche.gd` sait tracer les trois axes
## de l'os de main (REPERES), et c'est le seul moyen fiable de savoir dans quel
## sens une arme tenue doit être décrite. Résultat : c'est le +Z de l'os qui
## monte, une hampe se pose donc le long de celui-là.
##
## Les deux premières versions tenaient le rabot à l'horizontale, pointé dans
## le dos, puis planté vers le sol. Une orientation d'os de main ne se devine
## pas.
const GRIP: Basis = Basis(
	Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(1.0, 0.0, 0.0))

## Pose une pièce d'arme dans la main droite. `at` et `tilt` s'entendent dans
## le repère de prise : +Y vers le fer, +Z vers l'avant.
func _prop(shape: SkinPart.Shape, size: Vector3, at: Vector3, tilt: Vector3,
		color: Color, surface: SkinPart.Surface = SkinPart.Surface.PLAIN,
		weapon: bool = false, light_range: float = 0.0) -> void:
	var instance: MeshInstance3D = _mesh(shape, size, color, surface, light_range)
	if instance == null:
		return
	var spin: Basis = Basis.from_euler(Vector3(
		deg_to_rad(tilt.x), deg_to_rad(tilt.y), deg_to_rad(tilt.z)))
	instance.transform = Transform3D(GRIP * spin, GRIP * at)
	if shape == SkinPart.Shape.ELLIPSOID:
		instance.scale = size
	_register("handslot.r", instance, color, weapon, light_range)

func _hampe(longueur: float, rayon: float, color: Color,
		surface: SkinPart.Surface) -> void:
	_prop(SkinPart.Shape.CYLINDER, Vector3(rayon, longueur, rayon * 1.14),
		Vector3(0.0, longueur * 0.28, 0.0), Vector3.ZERO, color, surface)

# ---------------------------------------------------------------------------
# Distribution
# ---------------------------------------------------------------------------

func _build(id: StringName) -> void:
	match id:
		&"archer":
			_harponneur()
		&"mage":
			_verrier()
		&"soigneur":
			_rinceuse()
		&"gobelin":
			_cristallise()
		&"warden":
			_lampiste()
		_:
			_saunier()

## LE SAUNIER — coupeur de sel. Lourd, épaulé, chapeau large. La plaque de sel
## sur l'épaule gauche est asymétrique : elle a poussé, elle n'a pas été
## forgée.
func _saunier() -> void:
	_tronc(0.42, TOILE)
	_membres(0.075, TOILE)
	_tete(0.090, TOILE_CLAIRE, true)
	_chapeau(0.31, 0.13, TOILE, 0.090)
	_eclat("chest", Vector3(0.15, 0.13, 0.15),
		Vector3(0.24, 0.17, 0.0), Vector3(0.0, 0.0, -28.0))
	_eclat("chest", Vector3(0.10, 0.11, 0.10),
		Vector3(0.29, 0.24, -0.05), Vector3(16.0, 30.0, -44.0), SEL_OMBRE)
	_eclat("chest", Vector3(0.09, 0.10, 0.09),
		Vector3(0.19, 0.24, 0.07), Vector3(-14.0, -20.0, -18.0), SEL)
	_eclat("chest", Vector3(0.09, 0.09, 0.08),
		Vector3(-0.13, 0.20, 0.12), Vector3(0.0, 0.0, 30.0), SEL_OMBRE)
	# Tablier de cuir : il ferme le bas du tronc et alourdit la silhouette.
	_add("hips", SkinPart.Shape.BOX, Vector3(0.26, 0.40, 0.04),
		Vector3(0.0, -0.14, 0.19), Vector3(5.0, 0.0, 0.0), CUIR)
	# Sac de sel, porté haut dans le dos. Il dit le métier avant l'outil, et
	# il donne au dos une masse — un personnage vu de dos ne doit pas être
	# plus pauvre que de face.
	_add("chest", SkinPart.Shape.ELLIPSOID, Vector3(0.30, 0.36, 0.22),
		Vector3(0.0, 0.14, -0.26), Vector3(-8.0, 0.0, 4.0), TOILE_CLAIRE)
	_add("chest", SkinPart.Shape.TORUS, Vector3(0.11, 0.0, 0.15),
		Vector3(0.0, 0.30, -0.26), Vector3(90.0, 0.0, 0.0), CORDE)
	for bretelle: float in [-1.0, 1.0]:
		_add("chest", SkinPart.Shape.BOX, Vector3(0.05, 0.34, 0.02),
			Vector3(bretelle * 0.15, 0.14, 0.20),
			Vector3(0.0, 0.0, bretelle * 12.0), CUIR)
	_rabot()

## Le rabot à sel : un manche long et une lame large montée de travers. Ce
## n'est pas une épée, et ça doit se voir au premier coup d'œil.
func _rabot() -> void:
	_hampe(0.92, 0.023, CUIR, SkinPart.Surface.WOOD)
	_prop(SkinPart.Shape.BOX, Vector3(0.30, 0.10, 0.06),
		Vector3(0.0, 0.60, 0.0), Vector3(0.0, 0.0, 8.0), FER,
		SkinPart.Surface.METAL, true)
	_prop(SkinPart.Shape.PRISM, Vector3(0.30, 0.16, 0.04),
		Vector3(0.0, 0.70, 0.0), Vector3(0.0, 0.0, 8.0), SEL,
		SkinPart.Surface.STONE, true)
	_prop(SkinPart.Shape.TORUS, Vector3(0.030, 0.0, 0.050),
		Vector3(0.0, 0.10, 0.0), Vector3.ZERO, CORDE)

## LE HARPONNEUR — pas de chapeau, capuche rabattue, lunettes. Rouleau de
## cordage à la ceinture : c'est sa signature, et elle dit ce qu'il fait.
func _harponneur() -> void:
	_tronc(0.36, TOILE)
	_membres(0.064, TOILE)
	_tete(0.084, TOILE_CLAIRE, true)
	_capuche(0.088, TOILE)
	for turn: int in 3:
		_add("hips", SkinPart.Shape.TORUS, Vector3(0.09, 0.0, 0.115),
			Vector3(0.16, 0.06 + float(turn) * 0.028, 0.09),
			Vector3(0.0, 0.0, 74.0), CORDE)
	_eclat("chest", Vector3(0.12, 0.11, 0.12),
		Vector3(-0.24, 0.12, 0.0), Vector3(0.0, 0.0, 20.0), SEL_OMBRE)
	# Crocs de quai pendus à la ceinture : trois crochets de fer qui cliquettent.
	for croc: int in 3:
		var x: float = -0.11 + float(croc) * 0.11
		_add("hips", SkinPart.Shape.TORUS, Vector3(0.030, 0.0, 0.055),
			Vector3(x, 0.02, 0.17), Vector3(0.0, 0.0, 24.0 - float(croc) * 20.0),
			FER, SkinPart.Surface.METAL)
	_harpon()

func _harpon() -> void:
	_hampe(1.34, 0.018, CUIR, SkinPart.Surface.WOOD)
	_prop(SkinPart.Shape.CONE, Vector3(0.040, 0.22, 0.0),
		Vector3(0.0, 0.86, 0.0), Vector3.ZERO, FER,
		SkinPart.Surface.METAL, true)
	for side: float in [-1.0, 1.0]:
		_prop(SkinPart.Shape.PRISM, Vector3(0.06, 0.13, 0.016),
			Vector3(side * 0.040, 0.78, 0.0), Vector3(0.0, 0.0, side * 152.0),
			FER, SkinPart.Surface.METAL, true)

## LE VERRIER — souffleur de verre de saumure. Capuche haute, silhouette
## étroite, et la seule chose colorée du groupe : la perle en fusion.
func _verrier() -> void:
	_tronc(0.34, CUIR)
	_membres(0.060, CUIR)
	_tete(0.082, TOILE_CLAIRE, false)
	_capuche(0.094, CUIR)
	# Éclats de verre portés dans le dos, comme un carquois.
	for index: int in 4:
		_add("chest", SkinPart.Shape.PRISM, Vector3(0.055, 0.34, 0.018),
			Vector3(-0.09 + float(index) * 0.06, 0.20, -0.20),
			Vector3(26.0, 0.0, -28.0 + float(index) * 16.0), VERRE,
			SkinPart.Surface.GLOW)
	_canne()

func _canne() -> void:
	_hampe(1.02, 0.016, FER, SkinPart.Surface.METAL)
	_prop(SkinPart.Shape.SPHERE, Vector3(0.068, 0.0, 0.0),
		Vector3(0.0, 0.70, 0.0), Vector3.ZERO, VERRE, SkinPart.Surface.GLOW,
		true, 3.4)
	_prop(SkinPart.Shape.TORUS, Vector3(0.024, 0.0, 0.042),
		Vector3(0.0, 0.09, 0.0), Vector3.ZERO, CORDE)

## LA RINCEUSE — celle qui lave le sel des autres. Chapeau plat et large,
## outre de saumure, goupillon. Rien de martial : sa silhouette doit dire
## « on vient vers elle », pas « on la fuit ».
func _rinceuse() -> void:
	_tronc(0.35, TOILE_CLAIRE)
	_membres(0.062, TOILE_CLAIRE)
	_tete(0.084, TOILE_CLAIRE, false)
	_chapeau(0.36, 0.03, TOILE_CLAIRE, 0.084)
	_add("chest", SkinPart.Shape.ELLIPSOID, Vector3(0.26, 0.32, 0.18),
		Vector3(0.0, 0.10, -0.22), Vector3(-10.0, 0.0, 0.0), CUIR)
	_add("chest", SkinPart.Shape.CYLINDER, Vector3(0.036, 0.11, 0.048),
		Vector3(0.11, 0.24, -0.19), Vector3(0.0, 0.0, -24.0), FER,
		SkinPart.Surface.METAL)
	# Fioles de saumure alignées sur la poitrine. C'est la seule couleur du
	# personnage, et elle dit ce qu'il donne.
	for fiole: int in 4:
		var x: float = -0.15 + float(fiole) * 0.10
		_add("chest", SkinPart.Shape.CYLINDER, Vector3(0.026, 0.09, 0.030),
			Vector3(x, 0.04 + float(fiole % 2) * 0.02, 0.17),
			Vector3(12.0, 0.0, 0.0), VERRE, SkinPart.Surface.GLOW)
		_add("chest", SkinPart.Shape.CYLINDER, Vector3(0.018, 0.03, 0.020),
			Vector3(x, 0.10 + float(fiole % 2) * 0.02, 0.17),
			Vector3(12.0, 0.0, 0.0), CUIR)
	_goupillon()

func _goupillon() -> void:
	_hampe(0.68, 0.018, CUIR, SkinPart.Surface.WOOD)
	_prop(SkinPart.Shape.ELLIPSOID, Vector3(0.15, 0.20, 0.15),
		Vector3(0.0, 0.44, 0.0), Vector3.ZERO, CORDE,
		SkinPart.Surface.CLOTH, true)
	_prop(SkinPart.Shape.SPHERE, Vector3(0.034, 0.0, 0.0),
		Vector3(0.0, 0.54, 0.0), Vector3.ZERO, VERRE, SkinPart.Surface.GLOW,
		false, 2.6)

## LE CRISTALLISÉ — l'ennemi de base. Un homme mort dans le bassin, que le sel
## a repris. Maigre, voûté, à moitié blanc. Plus il est ancien, plus il est
## clair : c'est la seule barre de vie dont on ait besoin.
func _cristallise() -> void:
	_tronc(0.31, TOILE)
	_membres(0.054, TOILE)
	_tete(0.078, SEL_OMBRE, true)
	# La croûte a mangé la moitié du crâne et l'épaule droite.
	_eclat("head", Vector3(0.16, 0.15, 0.16),
		Vector3(0.06, 0.12, -0.02), Vector3(18.0, 24.0, -32.0))
	_eclat("chest", Vector3(0.18, 0.17, 0.16),
		Vector3(-0.20, 0.12, 0.0), Vector3(0.0, 0.0, 28.0))
	_eclat("chest", Vector3(0.11, 0.13, 0.11),
		Vector3(-0.24, 0.24, -0.03), Vector3(20.0, 0.0, 42.0), SEL_OMBRE)
	_eclat("chest", Vector3(0.19, 0.17, 0.13),
		Vector3(0.05, 0.14, -0.14), Vector3(-16.0, 0.0, -18.0), SEL_OMBRE)
	_eclat("lowerleg.l", Vector3(0.11, 0.14, 0.11),
		Vector3(0.0, -0.16, 0.02), Vector3(0.0, 12.0, 22.0), SEL_OMBRE)
	# Le bras gauche est entierement pris : plus une croute, un moulage. C'est
	# le detail qui dit que la chose n'est plus quelqu'un.
	_limb("upperarm.l", "lowerarm.l", SkinPart.Shape.CYLINDER,
		0.10, 1.05, 0.075, 0.090, SEL, SkinPart.Surface.STONE)
	_limb("lowerarm.l", "wrist.l", SkinPart.Shape.CYLINDER,
		0.0, 1.05, 0.058, 0.078, SEL_OMBRE, SkinPart.Surface.STONE)
	_eclat("lowerarm.l", Vector3(0.09, 0.10, 0.09),
		Vector3(0.0, -0.10, 0.0), Vector3(14.0, 20.0, 28.0), SEL)
	# Éclat de sel tenu comme une lame : brut, jamais taillé.
	_prop(SkinPart.Shape.PRISM, Vector3(0.10, 0.58, 0.05),
		Vector3(0.0, 0.29, 0.0), Vector3(0.0, 0.0, 6.0), SEL,
		SkinPart.Surface.STONE, true)
	_prop(SkinPart.Shape.TORUS, Vector3(0.028, 0.0, 0.046),
		Vector3(0.0, 0.04, 0.0), Vector3.ZERO, CORDE)

## LE GARDIEN DES BRAISES — le boss. Il garde le dernier feu du bassin, et il
## brûle en permanence : sa toile est huilée et allumée. C'est la seule chose
## chaude d'une région entièrement blanche, et c'est tout le propos du combat.
func _lampiste() -> void:
	_tronc(0.50, CUIR)
	_membres(0.086, CUIR)
	_tete(0.098, CUIR, true)
	_capuche(0.108, CUIR)
	# Bandes de toile qui brûlent, en travers du tronc. Courtes et étroites :
	# trois anneaux pleins autour du corps ne se lisaient pas comme un homme
	# qui brûle mais comme une enseigne.
	for index: int in 5:
		var y: float = -0.06 + float(index) * 0.11
		var side: float = -1.0 if index % 2 == 0 else 1.0
		_add("chest", SkinPart.Shape.BOX, Vector3(0.16, 0.026, 0.05),
			Vector3(side * 0.13, y, 0.26 + float(index % 3) * 0.02),
			Vector3(0.0, 0.0, side * (18.0 + float(index) * 9.0)), BRAISE,
			SkinPart.Surface.GLOW, false, 1.8)
	_eclat("chest", Vector3(0.17, 0.14, 0.16),
		Vector3(0.29, 0.15, 0.0), Vector3(0.0, 0.0, -30.0))
	_eclat("chest", Vector3(0.14, 0.12, 0.13),
		Vector3(-0.29, 0.15, 0.0), Vector3(0.0, 0.0, 30.0), SEL_OMBRE)
	# Loques enflammees pendues aux bras : ce qui brule sur lui doit bouger
	# quand il frappe, sinon le feu a l'air peint.
	for cote: String in ["l", "r"]:
		for loque: int in 2:
			_add("lowerarm." + cote, SkinPart.Shape.BOX,
				Vector3(0.05, 0.22 + float(loque) * 0.07, 0.014),
				Vector3(0.0, -0.10 - float(loque) * 0.06, 0.05),
				Vector3(0.0, float(loque) * 24.0, 0.0), BRAISE,
				SkinPart.Surface.GLOW, false, 1.4)
	_ratelier()

## Un râtelier de lampes tenu comme une arme d'hast. Trois lampes qui pendent :
## ce sont elles qu'on regarde, donc ce sont elles qui annoncent le coup.
func _ratelier() -> void:
	_hampe(1.40, 0.028, FER, SkinPart.Surface.METAL)
	_prop(SkinPart.Shape.BOX, Vector3(0.58, 0.04, 0.04),
		Vector3(0.0, 0.92, 0.0), Vector3.ZERO, FER,
		SkinPart.Surface.METAL, true)
	for index: int in 3:
		var x: float = -0.22 + float(index) * 0.22
		_prop(SkinPart.Shape.CYLINDER, Vector3(0.010, 0.11, 0.010),
			Vector3(x, 0.86, 0.0), Vector3.ZERO, FER, SkinPart.Surface.METAL)
		_prop(SkinPart.Shape.ELLIPSOID, Vector3(0.11, 0.14, 0.11),
			Vector3(x, 0.74, 0.0), Vector3.ZERO, BRAISE,
			SkinPart.Surface.GLOW, true, 3.2)
