## Habille un corps humain animé : vêtement, croûte de sel, arme.
##
## CE QUI A CHANGÉ, ET POURQUOI ÇA CHANGE TOUT
##
## La version précédente fabriquait le personnage ENTIER en primitives collées
## sur des os : un cylindre par bras, un ovoïde par segment de torse. Ça ne
## pouvait pas marcher, et ça n'a pas marché — un empilement de volumes reste
## un mannequin articulé, quelles que soient les proportions. On voyait les
## jonctions, les épaules ne se raccordaient pas, rien ne se pliait.
##
## Maintenant le corps est un VRAI MAILLAGE SKINNÉ — une surface continue de
## treize mille triangles, déformée par le squelette — et ce fichier ne fait
## plus que l'habiller. C'est l'ordre normal des choses : on ne sculpte pas un
## bras en assemblant des tuyaux, on met une manche sur un bras.
##
## Le corps et ses 162 animations viennent de Mesh2Motion (CC0). Le vêtement,
## la croûte de sel, les outils et toute la direction artistique sont bâtis
## ici. Un corps nu sous licence libre n'est pas plus un « asset flip » qu'un
## mannequin de couture n'est une robe.
##
## Invariant 2 : présentation pure. Rien ici ne touche à une hitbox, à une
## portée ni à un rayon de collision.
class_name SaltBody
extends RefCounted

# ---------------------------------------------------------------------------
# Palette du sel
# ---------------------------------------------------------------------------

## Toile huilée : ce que tout le monde porte contre la brûlure du sel. C'est
## la teinte du CORPS lui-même — dans ce monde on est emmailloté des pieds à
## la tête, donc le maillage nu se lit déjà comme un vêtement.
const TOILE: Color = Color(0.52, 0.49, 0.41)
const TOILE_CLAIRE: Color = Color(0.70, 0.67, 0.57)
## Croûte de sel. La seule chose franchement claire d'un personnage : elle se
## lit de loin, et elle dit depuis combien de temps l'ennemi est mort.
const SEL: Color = Color(0.89, 0.91, 0.88)
const SEL_OMBRE: Color = Color(0.66, 0.70, 0.67)
const CUIR: Color = Color(0.34, 0.30, 0.24)
const CORDE: Color = Color(0.73, 0.67, 0.51)
## Verre de saumure : la seule couleur froide saturée du jeu.
const VERRE: Color = Color(0.40, 0.76, 0.68)
const FER: Color = Color(0.27, 0.29, 0.29)
const BRAISE: Color = Color(1.0, 0.55, 0.20)

## COULEURS DE CLASSE. Les six personnages sortaient tous du même beige : à
## dix mètres on ne distinguait ni le soigneur du gardien, ni un joueur d'un
## ennemi. Une région blanche n'oblige pas à une distribution monochrome —
## elle oblige à des teintes SOURDES, ce qui n'est pas la même chose. Chacune
## est assez éloignée des autres en TON, pas seulement en nuance, pour tenir
## même en niveaux de gris.
## Toile huilée de saumure : le harponneur, vert-bleu très sombre.
const SAUMURE: Color = Color(0.17, 0.27, 0.27)
## Suie : le verrier et le lampiste, presque noirs.
const SUIE: Color = Color(0.16, 0.15, 0.17)
## Ocre de fond de cuve : la rinceuse.
const OCRE: Color = Color(0.56, 0.41, 0.21)
## Rouille des outils : le saunier.
const ROUILLE: Color = Color(0.42, 0.23, 0.16)

## SOUS-VÊTEMENT. Le corps importé était peint dans le même beige que la toile
## qu'on lui posait dessus : manches, bandes, croûte et chair rendaient la même
## valeur, et le personnage se lisait comme un mannequin d'atelier nu portant
## un tablier. Une seule chose répare ça — descendre le CORPS d'un cran, très
## bas, pour que tout ce qu'on lui ajoute se détache. C'est aussi ce que la
## direction artistique demandait depuis le début : le sel est la seule chose
## claire du monde, donc rien d'autre n'a le droit d'être clair.
const DESSOUS: Color = Color(0.22, 0.21, 0.19)

## STATURE. Les six personnages sortaient tous du même rig, donc tous de la
## même taille au centimètre près : de dos, à vingt mètres, on comptait six
## fois la même personne. Un souls-like se lit d'abord à la TAILLE — on sait
## si on peut encaisser avant de savoir qui on regarde.
##
## Le facteur est posé sur le PORTEUR du squelette, pas sur la racine du rig :
## `actor_view` écrase l'échelle de la racine avec celle du `ModelData`, et une
## échelle écrasée est une correction qu'on croit avoir faite. L'origine du
## squelette est au SOL — mesuré, le maillage démarre à y = -0,0004 — donc
## grandir ne décolle pas les pieds et ne demande aucun `lift`.
##
## Invariant 2 : ce facteur ne touche ni hitbox, ni portée, ni rayon de
## collision. Le gardien des braises frappe exactement où il frappait ; il a
## simplement enfin l'air de ce qu'il fait.
const STATURE: Dictionary[StringName, float] = {
	&"gardien": 1.05,
	&"archer": 1.04,
	&"mage": 1.01,
	&"soigneur": 0.92,
	&"gobelin": 0.87,
	&"warden": 1.36,
}

## Repère de PRISE, mesuré sur le rig : le +X de l'os de main pointe vers le
## haut du monde au repos, son +Z vers l'avant. Une arme « manche en bas, fer
## en haut » se décrit donc dans cette base. Mesuré, jamais deviné — c'est ce
## qui avait coûté deux versions sur le rig précédent.
const GRIP: Basis = Basis(
	Vector3(0.0, 0.0, 1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0))

# ---------------------------------------------------------------------------
# État
# ---------------------------------------------------------------------------

var pieces: Array[MeshInstance3D] = []
var colors: Array[Color] = []
var weapons: Array[bool] = []
## Le rig humain est déjà à l'échelle et posé au sol : plus rien à relever.
var lift: float = 0.0

var _skeleton: Skeleton3D = null
var _attachments: Dictionary[String, BoneAttachment3D] = {}

# ---------------------------------------------------------------------------
# Entrée
# ---------------------------------------------------------------------------

static func dress(rig: Node3D, id: StringName, _tint: Color) -> SaltBody:
	var body: SaltBody = SaltBody.new()
	body._skeleton = SaltBody._find_skeleton(rig)
	if body._skeleton == null:
		push_warning("Aucun squelette dans le rig %s : corps non bâti." % id)
		return body
	body._grandir(rig, id)
	body._paint_skin(rig, id)
	body._build(id)
	return body

## Donne sa taille au personnage, avant qu'on l'habille : les pièces sont
## décrites en mètres sur le rig de repos, et elles suivent l'échelle du
## porteur sans qu'aucune cote n'ait à être retouchée.
func _grandir(rig: Node3D, id: StringName) -> void:
	if not STATURE.has(id):
		return
	var facteur: float = STATURE[id]
	var porteur: Node3D = _skeleton
	var parent: Node = _skeleton.get_parent()
	# Le nœud « Armature » du glb, entre la racine et le squelette : le
	# scaler lui évite de toucher au rapport entre le maillage skinné et son
	# squelette, qui est la seule chose qu'on n'a pas le droit de casser.
	if parent is Node3D and parent != rig:
		porteur = parent as Node3D
	porteur.scale = Vector3.ONE * facteur

static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = SaltBody._find_skeleton(child)
		if found != null:
			return found
	return null

## Teinte le corps importé sans lui retirer sa matière.
##
## Il était repeint avec le bruit TRIPLANAIRE du décor : une projection en
## coordonnées du MONDE. Sur un mur, c'est parfait ; sur une peau qui se
## déplace, le grain glisse sur le corps à chaque pas. C'était l'une des
## raisons pour lesquelles le personnage ne se lisait pas comme une matière.
##
## On garde donc la texture du modèle — qui est dépliée sur ses UV, donc
## solidaire de la peau — et on ne fait que la TEINTER. Le personnage est
## emmailloté de toile huilée : sa couleur vient de la palette du sel, son
## grain vient de son propre dépliage.
func _paint_skin(rig: Node3D, id: StringName) -> void:
	var tone: Color = DESSOUS
	match id:
		&"gobelin":
			# La chair du cristallisé est plus SOMBRE que celle d'un joueur,
			# pas plus claire. Teintée d'un tiers vers le sel, elle sortait
			# grise et moyenne : de loin, un joueur pâle — exactement ce qu'un
			# ennemi n'a pas le droit d'être. Tout le contraste de la chose
			# doit venir de sa croûte, donc tout le reste doit être noir.
			tone = DESSOUS.darkened(0.40)
		&"warden":
			tone = SUIE
		&"archer":
			tone = DESSOUS.lerp(SAUMURE, 0.55)
		&"mage":
			tone = SUIE.lightened(0.04)
		&"soigneur":
			tone = DESSOUS.lightened(0.10)
	for node: Node in SaltBody._meshes(rig):
		var mesh: MeshInstance3D = node as MeshInstance3D
		mesh.material_override = _skin_material(mesh, tone)
		pieces.append(mesh)
		colors.append(tone)
		weapons.append(false)

func _skin_material(mesh: MeshInstance3D, tone: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = tone
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	# Toile huilée : mate, mais pas plate. Une rugosité à 1,0 tue le relief au
	# point qu'un corps rond se lit comme une découpe de papier.
	material.roughness = 0.86
	material.metallic = 0.0
	material.metallic_specular = 0.30
	# Le liseré de bord est ce qui décolle un personnage du fond. Sur un corps
	# volontairement très sombre, sous un soleil rasant, c'est lui — et lui
	# seul — qui empêche la silhouette de devenir un trou noir mobile.
	material.rim_enabled = true
	material.rim = 0.68
	material.rim_tint = 0.25
	if mesh.mesh == null:
		return material
	var source: Material = mesh.mesh.surface_get_material(0)
	if source is StandardMaterial3D:
		var base: StandardMaterial3D = source as StandardMaterial3D
		# On ne reprend PAS la texture d'albédo du modèle. Mesh2Motion livre
		# ses corps en livrée orange et blanche de mannequin d'atelier ; la
		# reprendre revenait à multiplier toute la palette du sel par de
		# l'orange vif, et les six personnages sortaient en terre cuite. Seule
		# la carte de normales est gardée : elle porte le relief sans imposer
		# de couleur.
		if base.normal_texture != null:
			material.normal_enabled = true
			material.normal_texture = base.normal_texture
			material.normal_scale = 0.7
	return material

static func _meshes(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	if node is MeshInstance3D:
		found.append(node)
	for child: Node in node.get_children():
		found.append_array(SaltBody._meshes(child))
	return found

# ---------------------------------------------------------------------------
# Repères
# ---------------------------------------------------------------------------
#
# Le costume se décrit en coordonnées du MONDE — droite, haut, avant — jamais
# dans le repère de l'os, dont l'orientation change d'un os à l'autre.
# `_frame()` convertit, sur la pose de repos ; l'animation fait ensuite tourner
# l'os et la pièce suit, comme un chapeau suit une tête.

func _frame(bone: String) -> Basis:
	var index: int = _skeleton.find_bone(bone)
	if index < 0:
		return Basis.IDENTITY
	return _skeleton.get_bone_global_rest(index).basis.orthonormalized().inverse()

## Vecteur d'un os vers son enfant, dans le repère de l'os : axe et longueur
## du membre.
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
	# Plafonnée. Le gardien des braises porte six sources chaudes à moins d'un
	# mètre de sa propre toile : à 0,30 × portée elles s'additionnaient en
	# trois unités d'orange sur lui, et le personnage le plus noir du jeu
	# sortait en terre cuite. Une braise doit ÉCLAIRER autour d'elle, pas
	# repeindre celui qui la porte.
	lamp.light_energy = minf(0.20 * light_range, 0.62)
	lamp.light_color = color.lerp(Color(1.0, 0.94, 0.86), 0.4)
	lamp.shadow_enabled = false
	instance.add_child(lamp)

## Pose une primitive sur un os, décrite dans le repère du MONDE : `at` est un
## décalage (droite, haut, avant) en mètres depuis l'os.
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

## Bande de toile enroulée autour d'un membre, posée à une fraction de sa
## longueur. C'est LE motif du costume : il dit « emmailloté » en une pièce, et
## il rythme un bras nu sans rien ajouter à la silhouette.
func _bande(bone: String, child: String, at: float, radius: float,
		color: Color = CORDE) -> void:
	var axis: Vector3 = _axis(child)
	var instance: MeshInstance3D = _mesh(SkinPart.Shape.TORUS,
		Vector3(radius, 0.0, radius + 0.022), color, SkinPart.Surface.CLOTH, 0.0)
	if instance == null:
		return
	instance.transform = Transform3D(
		Basis(Quaternion(Vector3.UP, axis.normalized())), axis * at)
	_register(bone, instance, color, false, 0.0)

## Manchon : un tronc de cône enfilé le long d'un membre, de `from` à `to` en
## fractions de sa longueur. Une manche, une jambière, un gantelet.
func _manchon(bone: String, child: String, from: float, to: float,
		radius_top: float, radius_bottom: float, color: Color,
		surface: SkinPart.Surface = SkinPart.Surface.CLOTH) -> void:
	var axis: Vector3 = _axis(child)
	var length: float = axis.length() * (to - from)
	if length <= 0.0001:
		return
	var instance: MeshInstance3D = _mesh(SkinPart.Shape.CYLINDER,
		Vector3(radius_top, length, radius_bottom), color, surface, 0.0)
	if instance == null:
		return
	instance.transform = Transform3D(
		Basis(Quaternion(Vector3.UP, axis.normalized())),
		axis * ((from + to) * 0.5))
	_register(bone, instance, color, false, 0.0)

## Éclat de sel : un bloc de travers, doublé d'un plus petit. Une croûte est
## une grappe, pas une plaque — c'est ce qui la distingue d'une armure.
func _eclat(bone: String, size: Vector3, at: Vector3, tilt: Vector3,
		color: Color = SEL) -> void:
	_add(bone, SkinPart.Shape.BOX, size, at, tilt, color, SkinPart.Surface.STONE)
	_add(bone, SkinPart.Shape.BOX, size * 0.58,
		at + Vector3(size.x * 0.30, size.y * 0.44, -size.z * 0.26),
		tilt + Vector3(26.0, 34.0, -18.0), color.lightened(0.10),
		SkinPart.Surface.STONE)

## Pièce d'arme, dans le repère de prise de la main droite.
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
	_register("hand_r", instance, color, weapon, light_range)

func _hampe(longueur: float, rayon: float, color: Color,
		surface: SkinPart.Surface) -> void:
	_prop(SkinPart.Shape.CYLINDER, Vector3(rayon, longueur, rayon * 1.14),
		Vector3(0.0, longueur * 0.30, 0.0), Vector3.ZERO, color, surface)

# ---------------------------------------------------------------------------
# Vêtement commun
# ---------------------------------------------------------------------------

## Manches et jambières : des manchons posés SUR le corps, jamais à la place.
## Ils s'arrêtent avant les articulations, sinon un coude qui plie fait sortir
## un bout de manche rigide du bras.
func _vetement(color: Color) -> void:
	_justaucorps(color)
	for side: String in ["l", "r"]:
		_manchon("upperarm_" + side, "lowerarm_" + side, 0.05, 0.78,
			0.075, 0.070, color)
		# BANDES : rayon INTÉRIEUR du tore, donc il doit être PLUS PETIT que le
		# membre pour mordre dedans. Mesuré sur le maillage : l'avant-bras fait
		# 0,053 de rayon moyen et le mollet 0,060. Les bandes étaient décrites
		# au rayon d'un bras HABILLÉ — jusqu'à 0,075 sur un mollet de 0,060 —
		# et se lisaient comme des cerceaux enfilés autour du personnage.
		_bande("lowerarm_" + side, "hand_" + side, 0.18, 0.048)
		_bande("lowerarm_" + side, "hand_" + side, 0.52, 0.045)
		_bande("lowerarm_" + side, "hand_" + side, 0.84, 0.042)
		_manchon("thigh_" + side, "calf_" + side, 0.02, 0.62,
			0.105, 0.090, color)
		_bande("calf_" + side, "foot_" + side, 0.22, 0.058)
		_bande("calf_" + side, "foot_" + side, 0.55, 0.052)
		_bande("calf_" + side, "foot_" + side, 0.84, 0.046)
		# BOTTE. Elle ne couvrait pas le pied — elle flottait au-dessus.
		#
		# Mesuré sur le rig : l'os de cheville `foot_l` est à y = 0,1037 et
		# l'orteil `ball_l` à y = 0,0152, soit huit centimètres et demi PLUS
		# BAS, et quinze centimètres en avant. La caisse faisait dix
		# centimètres de haut centrée trois centimètres au-dessus de la
		# cheville : son dessous s'arrêtait donc à sept centimètres au-dessus
		# de l'orteil. Sur toutes les images, le pied nu du maillage sortait
		# par-dessous et par-derrière — deux triangles sombres devant, un talon
		# nu derrière.
		#
		# Elle descend maintenant sous l'orteil et remonte derrière le talon.
		_add("foot_" + side, SkinPart.Shape.BOX,
			Vector3(0.145, 0.145, 0.30), Vector3(0.0, -0.028, 0.065),
			Vector3.ZERO, CUIR)
		_add("foot_" + side, SkinPart.Shape.BOX,
			Vector3(0.135, 0.105, 0.11), Vector3(0.0, -0.048, -0.062),
			Vector3.ZERO, CUIR.darkened(0.18))

## Redingote : un tronc de cône de la taille à mi-cuisse, plus des plis et des
## loques nouées à la ceinture. C'est la pièce qui porte la silhouette.
##
## Elle était montée À L'ENVERS : `size.x` est le rayon du HAUT et `size.z`
## celui du BAS, et elle valait (0,28 ; 0,205). Vingt-huit centimètres de rayon
## à la taille pour vingt à l'ourlet : un abat-jour, pas un vêtement. C'est ce
## qui donnait aux six personnages la même silhouette de tonneau, large aux
## hanches et étroite aux épaules — exactement l'inverse de la règle qu'on
## s'était donnée.
func _redingote(color: Color, longueur: float = 0.52,
		taille: float = 0.185, ourlet: float = 0.30) -> void:
	_add("pelvis", SkinPart.Shape.CYLINDER,
		Vector3(taille, longueur, ourlet),
		Vector3(0.0, -longueur * 0.42, 0.0), Vector3.ZERO, color)
	# Les plis suivent l'évasement : posés au rayon de la taille, ils
	# flottaient à cinq centimètres du tissu en bas.
	for pli: int in 6:
		var angle: float = -75.0 + float(pli) * 30.0
		var rayon: float = ourlet * 0.94
		_add("pelvis", SkinPart.Shape.BOX,
			Vector3(0.026, longueur * 0.82, 0.048),
			Vector3(sin(deg_to_rad(angle)) * rayon, -longueur * 0.50,
				cos(deg_to_rad(angle)) * rayon),
			Vector3(0.0, angle, 0.0), color.darkened(0.32))
	_add("pelvis", SkinPart.Shape.TORUS, Vector3(0.055, 0.0, taille + 0.035),
		Vector3(0.0, 0.02, 0.0), Vector3.ZERO, CORDE)
	for loque: int in 5:
		var tour: float = -60.0 + float(loque) * 30.0
		var chute: float = 0.14 + float(loque % 3) * 0.09
		_add("pelvis", SkinPart.Shape.BOX,
			Vector3(0.045, chute, 0.014),
			Vector3(sin(deg_to_rad(tour)) * (taille + 0.03),
				-0.01 - chute * 0.5,
				cos(deg_to_rad(tour)) * (taille + 0.03)),
			Vector3(0.0, tour, float(loque % 2) * 9.0 - 4.5), CORDE)

## Épaulières : une calotte posée sur le haut de chaque bras, et son rebord.
##
## Elles sont la moitié manquante de la règle de silhouette. La redingote
## remise à l'endroit a retiré la largeur des hanches ; sans rien pour élargir
## les épaules, on obtenait juste un personnage étroit. Une épaulière porte
## quinze centimètres de large de chaque côté, et c'est ce qui fait qu'une
## silhouette se lit de dos, de loin, en contre-jour.
##
## Posées sur `upperarm`, pas sur `clavicle` : la clavicule est au creux du
## cou, une pièce montée dessus flotte à quinze centimètres de l'épaule.
func _epaulieres(color: Color, rayon: float = 0.115) -> void:
	for side: String in ["l", "r"]:
		_add("upperarm_" + side, SkinPart.Shape.CYLINDER,
			Vector3(rayon * 0.52, rayon * 0.86, rayon),
			Vector3(0.0, 0.005, 0.0), Vector3.ZERO, color)
		_add("upperarm_" + side, SkinPart.Shape.ELLIPSOID,
			Vector3(rayon * 0.56, rayon * 0.46, rayon * 0.56),
			Vector3(0.0, rayon * 0.44, 0.0), Vector3.ZERO,
			color.lightened(0.10))
		_bande("upperarm_" + side, "lowerarm_" + side, 0.30,
			rayon * 0.66, color.darkened(0.30))

## Justaucorps : la coque de toile qui couvre le buste, du bas des côtes au
## haut de la poitrine, plus sa ceinture.
##
## Il manquait, purement et simplement. On posait des manches sur les bras, des
## jambières sur les jambes, un tablier sur les hanches — et le TORSE restait
## le maillage nu. Vu de face, le personnage était un mannequin d'atelier à qui
## on avait mis un tablier. C'est la pièce qui manquait, pas une de plus.
func _justaucorps(color: Color) -> void:
	_add("spine_02", SkinPart.Shape.ELLIPSOID, Vector3(0.205, 0.255, 0.150),
		Vector3(0.0, 0.025, 0.0), Vector3(-3.0, 0.0, 0.0), color)
	# Empiècement de poitrine, plus clair : il attrape la lumière de face et
	# c'est lui qui donne au buste son volume vu de loin.
	_add("spine_03", SkinPart.Shape.ELLIPSOID, Vector3(0.165, 0.115, 0.115),
		Vector3(0.0, -0.02, 0.075), Vector3(-14.0, 0.0, 0.0),
		color.lightened(0.13))
	# Ceinture basse, sur le pelvis et non sur le buste : elle doit rester en
	# place quand le torse se plie.
	_add("pelvis", SkinPart.Shape.CYLINDER, Vector3(0.180, 0.075, 0.190),
		Vector3(0.0, 0.075, 0.0), Vector3.ZERO, CUIR)
	_add("pelvis", SkinPart.Shape.BOX, Vector3(0.075, 0.060, 0.030),
		Vector3(0.0, 0.075, 0.180), Vector3.ZERO, FER,
		SkinPart.Surface.METAL)

## Tablier : un pan de toile devant, un derrière, fendus sur les côtés.
##
## C'est ce qui remplace la jupe pleine sur tout ce qui se bat. Une jupe
## fermée, même bien évasée, fait un tonneau : elle noie les jambes, donc elle
## efface le pas, donc l'animation ne se lit plus. Deux pans laissent voir la
## cuisse entre eux, et c'est cette fente qui rend la course lisible de loin.
func _tablier(color: Color, longueur: float = 0.54,
		largeur: float = 0.20, attaches: Color = CORDE) -> void:
	# DEUX PANS, ET RIEN ENTRE EUX. La première version gardait un tronc de
	# cône sous les pans « pour faire la doublure » : les deux se rejoignaient
	# en un fût plein, et on retrouvait le tonneau qu'on venait d'enlever, en
	# rouge. Un pan de tissu se décrit par sa LARGEUR et son épaisseur, jamais
	# par un rayon.
	for face: float in [1.0, -1.0]:
		_add("pelvis", SkinPart.Shape.BOX,
			Vector3(largeur * 1.80, longueur, 0.028),
			Vector3(0.0, -longueur * 0.46, face * 0.125),
			Vector3(face * -6.0, 0.0, 0.0), color)
		# Ourlet plus sombre : il ferme le bas du pan, qui autrement se termine
		# sur une arête vive de trois centimètres qu'on lit comme du carton.
		_add("pelvis", SkinPart.Shape.BOX,
			Vector3(largeur * 1.84, 0.045, 0.038),
			Vector3(0.0, -longueur * 0.94, face * 0.130),
			Vector3(face * -6.0, 0.0, 0.0), color.darkened(0.34))
	# Les hanches restent couvertes par deux pans courts sur les côtés, fendus
	# à mi-cuisse : de trois quarts, la silhouette reste fermée, mais la fente
	# laisse passer le pas.
	for cote: float in [1.0, -1.0]:
		_add("pelvis", SkinPart.Shape.BOX,
			Vector3(0.026, longueur * 0.56, largeur * 1.30),
			Vector3(cote * largeur * 0.86, -longueur * 0.30, 0.0),
			Vector3(0.0, 0.0, cote * 5.0), color.darkened(0.16))
	# La cordelette se teinte. Sur le gardien des braises, un anneau de corde
	# claire au creux des reins ressortait, contre la cape noire, comme une
	# écuelle pâle accrochée dans son dos.
	_add("pelvis", SkinPart.Shape.TORUS, Vector3(0.055, 0.0, 0.195),
		Vector3(0.0, 0.02, 0.0), Vector3.ZERO, attaches)
	for loque: int in 4:
		var tour: float = -46.0 + float(loque) * 31.0
		var chute: float = 0.13 + float(loque % 3) * 0.08
		_add("pelvis", SkinPart.Shape.BOX,
			Vector3(0.042, chute, 0.014),
			Vector3(sin(deg_to_rad(tour)) * 0.20, -0.01 - chute * 0.5,
				cos(deg_to_rad(tour)) * 0.20),
			Vector3(0.0, tour, float(loque % 2) * 9.0 - 4.5), attaches)

## Pèlerine sur les épaules : elle élargit le haut, ce qui est la règle de
## silhouette du sel — large en haut, effilé en bas.
func _pelerine(color: Color) -> void:
	_add("spine_03", SkinPart.Shape.CONE, Vector3(0.30, 0.27, 0.0),
		Vector3(0.0, 0.075, -0.01), Vector3(184.0, 0.0, 0.0), color)
	# Col roule : il ferme la peleine sur la nuque, sinon on voit le trou
	# entre le cone et le corps des qu'on regarde d'en haut.
	_add("spine_03", SkinPart.Shape.TORUS, Vector3(0.075, 0.0, 0.115),
		Vector3(0.0, 0.135, -0.01), Vector3(8.0, 0.0, 0.0), color.darkened(0.2))

## Tête emmaillotée : gaze sur le bas du visage, lunettes de verre. On ne voit
## JAMAIS d'yeux — la règle de silhouette la plus utile du projet, parce
## qu'elle rend un personnage inquiétant sans rien modéliser.
func _tete(lunettes: bool, gaze: Color = TOILE_CLAIRE) -> void:
	# La calotte est SOMBRE. Elle était en toile claire, et sur un corps
	# désormais très sombre elle devenait la chose la plus lumineuse du
	# personnage : de dos, on ne voyait plus qu'un gros œuf pâle. Le seul
	# élément clair de la tête doit être la gaze du bas du visage, parce que
	# c'est elle qui dit où le personnage regarde.
	_add("head", SkinPart.Shape.ELLIPSOID, Vector3(0.205, 0.135, 0.21),
		Vector3(0.0, 0.115, 0.0), Vector3.ZERO, DESSOUS)
	# La gaze ne couvre que le BAS DU VISAGE. Elle faisait 19 cm de profondeur,
	# soit toute la tête : vu de dos — c'est-à-dire pendant tout le jeu — le
	# personnage portait un gros œuf pâle en guise de crâne.
	_add("head", SkinPart.Shape.ELLIPSOID, Vector3(0.165, 0.085, 0.115),
		Vector3(0.0, -0.012, 0.080), Vector3(-14.0, 0.0, 0.0), gaze)
	# La gaze se teinte, parce que sur le gardien des braises elle sortait en
	# tache claire de vingt centimètres juste sous les cornes, et c'était la
	# deuxième chose la plus lumineuse du personnage après son brasier. Il n'y
	# a de place que pour UN point clair sur un boss.
	# Bande de serrage sur le front : elle sépare la calotte de la gaze,
	# sinon les deux ovoïdes se lisent comme une seule masse.
	_add("head", SkinPart.Shape.TORUS, Vector3(0.030, 0.0, 0.185),
		Vector3(0.0, 0.055, 0.005), Vector3(-6.0, 0.0, 0.0), CUIR)
	if not lunettes:
		return
	for side: float in [-1.0, 1.0]:
		_add("head", SkinPart.Shape.CYLINDER, Vector3(0.042, 0.030, 0.042),
			Vector3(side * 0.052, 0.062, 0.088), Vector3(90.0, 0.0, 0.0),
			FER, SkinPart.Surface.METAL)
		_add("head", SkinPart.Shape.CYLINDER, Vector3(0.030, 0.010, 0.030),
			Vector3(side * 0.052, 0.062, 0.104), Vector3(90.0, 0.0, 0.0),
			VERRE, SkinPart.Surface.GLOW)
	_add("head", SkinPart.Shape.BOX, Vector3(0.045, 0.012, 0.012),
		Vector3(0.0, 0.062, 0.090), Vector3.ZERO, FER, SkinPart.Surface.METAL)

## Chapeau de saunier : large disque plat et calotte. La pièce qui travaille
## le plus de tout le costume — on la reconnaît de trente mètres.
func _chapeau(rayon: float, hauteur: float, color: Color) -> void:
	_add("head", SkinPart.Shape.CYLINDER, Vector3(rayon * 0.40, 0.028, rayon),
		Vector3(0.0, 0.155, 0.0), Vector3(6.0, 0.0, 0.0), color)
	_add("head", SkinPart.Shape.CONE, Vector3(rayon * 0.46, hauteur, 0.0),
		Vector3(0.0, 0.155 + hauteur * 0.44, 0.0), Vector3.ZERO, color)
	_add("head", SkinPart.Shape.TORUS, Vector3(rayon * 0.32, 0.0, rayon * 0.42),
		Vector3(0.0, 0.175, 0.0), Vector3.ZERO, CORDE)

## Capuche : calotte allongée qui déborde en arrière, et un creux d'ombre
## presque noir derrière l'ouverture. Une capuche éclairée à l'intérieur ne
## cache rien ; celle-ci fait un trou.
func _capuche(color: Color) -> void:
	_add("head", SkinPart.Shape.ELLIPSOID, Vector3(0.27, 0.28, 0.31),
		Vector3(0.0, 0.075, -0.035), Vector3.ZERO, color)
	_add("head", SkinPart.Shape.ELLIPSOID, Vector3(0.19, 0.19, 0.14),
		Vector3(0.0, 0.075, 0.075), Vector3.ZERO, Color(0.05, 0.06, 0.06))
	_pelerine(color)

# ---------------------------------------------------------------------------
# Ce qui dépasse de la silhouette
# ---------------------------------------------------------------------------
#
# Tout ce qui suit sert une seule règle : une silhouette ne se distingue pas
# par ce qu'elle porte SUR le corps, elle se distingue par ce qui SORT de son
# contour. Une belle veste et une veste laide donnent le même trapèze noir à
# vingt mètres ; un cornet, un carquois, une hotte ou une corne donnent quatre
# contours qu'on ne confond jamais.

## Direction de l'axe d'une pièce inclinée, dans le repère du monde.
##
## Enchaîner deux cônes bout à bout en devinant où finit le premier, c'est la
## façon la plus sûre de fabriquer une pièce qui flotte à dix centimètres de
## celle qu'elle prolonge. On demande son axe à la même construction que
## `_add`, et le raccord tombe juste par construction.
func _sens(tilt: Vector3) -> Vector3:
	var spin: Basis = Basis.from_euler(Vector3(
		deg_to_rad(tilt.x), deg_to_rad(tilt.y), deg_to_rad(tilt.z)))
	return spin * Vector3.UP

## Plaque d'épaule : un pan large et incliné qui DÉBORDE du bras.
##
## Une calotte posée sur l'épaule suit l'épaule et n'élargit rien ; une plaque
## sort de vingt centimètres, et c'est ce débord — pas son épaisseur — qui se
## lit de dos, à vingt mètres, en contre-jour. Les deux côtés n'en portent
## jamais la même : une paire symétrique se lit comme un uniforme, une paire
## dépareillée se lit comme quelqu'un.
func _plaque_epaule(side: String, color: Color, largeur: float,
		longueur: float, pente: float) -> void:
	var sens: float = 1.0 if side == "l" else -1.0
	var bone: String = "upperarm_" + side
	_add(bone, SkinPart.Shape.BOX, Vector3(largeur, 0.040, longueur),
		Vector3(sens * largeur * 0.32, 0.060, 0.0),
		Vector3(0.0, 0.0, sens * -pente), color, SkinPart.Surface.METAL)
	# Rebord. Sans lui la plaque se termine sur une arête de quatre
	# centimètres, qu'on lit comme du carton découpé et non comme du fer.
	_add(bone, SkinPart.Shape.BOX,
		Vector3(largeur * 0.26, 0.085, longueur * 0.94),
		Vector3(sens * largeur * 0.60, 0.030, 0.0),
		Vector3(0.0, 0.0, sens * -pente), color.darkened(0.34),
		SkinPart.Surface.METAL)
	for rivet: int in 3:
		_add(bone, SkinPart.Shape.SPHERE, Vector3(0.017, 0.0, 0.0),
			Vector3(sens * largeur * 0.22, 0.078,
				longueur * (float(rivet) * 0.30 - 0.30)),
			Vector3.ZERO, color.lightened(0.24), SkinPart.Surface.METAL)

## Hotte : la caisse qu'on porte dans le dos, plus haute que la tête.
##
## Elle double la surface de la silhouette vue de dos — c'est-à-dire pendant
## tout le jeu — et elle dit le métier avant l'arme. Sa face avant mord dans
## le dos exprès : une caisse posée à trois centimètres du corps flotte, et on
## voit le jour passer dessous dès qu'on tourne autour.
func _hotte(color: Color, largeur: float, hauteur: float,
		profondeur: float) -> void:
	# Sanglée sur `spine_02`, pas sur `spine_03`. Une hotte est tenue au
	# MILIEU du dos ; montée sur la dernière vertèbre, elle prenait tout le
	# débattement du buste et partait en travers du crâne dès que l'attente
	# penchait le personnage en avant — et l'attente du saunier le penche de
	# cinquante degrés.
	var dos: String = "spine_02"
	var recul: float = -0.075 - profondeur * 0.5
	_add(dos, SkinPart.Shape.BOX, Vector3(largeur, hauteur, profondeur),
		Vector3(0.0, hauteur * 0.48, recul),
		Vector3(-7.0, 0.0, 0.0), color, SkinPart.Surface.WOOD)
	for cercle: int in 2:
		_add(dos, SkinPart.Shape.BOX,
			Vector3(largeur * 1.04, 0.035, profondeur * 1.06),
			Vector3(0.0, hauteur * (0.24 + float(cercle) * 0.44), recul),
			Vector3(-7.0, 0.0, 0.0), CUIR)
	for bretelle: float in [-1.0, 1.0]:
		_add(dos, SkinPart.Shape.BOX, Vector3(0.042, 0.34, 0.022),
			Vector3(bretelle * 0.120, 0.070, 0.112),
			Vector3(-6.0, 0.0, bretelle * 11.0), CUIR.darkened(0.20))
	# Ce qu'il y a dedans, et qui dépasse : la charge d'un porteur de sel se
	# voit, sinon la caisse est vide et le personnage n'a rien à faire.
	_eclat(dos, Vector3(0.19, 0.15, 0.16),
		Vector3(0.035, hauteur * 0.98 + 0.075, recul),
		Vector3(0.0, 22.0, -14.0))

## Carquois de harpons : un fourreau oblique dans le dos et des hampes qui
## dépassent largement du crâne.
##
## C'est la seule pièce de la distribution qui ajoute de la HAUTEUR à une
## silhouette sans grandir personne — et un éventail de pointes au-dessus
## d'une épaule ne ressemble à rien d'autre dans le jeu.
func _carquois(color: Color, nombre: int) -> void:
	var bouche: Vector3 = Vector3(0.150, 0.185, -0.145)
	_add("spine_03", SkinPart.Shape.CYLINDER, Vector3(0.072, 0.42, 0.088),
		Vector3(0.115, -0.015, -0.125), Vector3(8.0, 0.0, -16.0), color,
		SkinPart.Surface.CLOTH)
	_add("spine_03", SkinPart.Shape.TORUS, Vector3(0.070, 0.0, 0.092),
		bouche, Vector3(98.0, 0.0, -16.0), CUIR)
	for tige: int in nombre:
		var etale: float = -1.0
		if nombre > 1:
			etale = -1.0 + 2.0 * float(tige) / float(nombre - 1)
		var tilt: Vector3 = Vector3(-19.0 - etale * 4.0, 0.0,
			-11.0 - etale * 13.0)
		var axe: Vector3 = _sens(tilt)
		var longueur: float = 0.76 - absf(etale) * 0.06
		_add("spine_03", SkinPart.Shape.CYLINDER,
			Vector3(0.013, longueur, 0.015),
			bouche + axe * (longueur * 0.40), tilt, CUIR,
			SkinPart.Surface.WOOD)
		_add("spine_03", SkinPart.Shape.CONE, Vector3(0.030, 0.14, 0.0),
			bouche + axe * (longueur * 0.86 + 0.07), tilt, FER,
			SkinPart.Surface.METAL)

## Capuche à cornet : la capuche commune, prolongée d'une pointe qui part en
## arrière et retombe.
##
## La capuche seule fait une boule, et une boule sur des épaules ressemble à
## une tête nue de loin. C'est le cornet qui dit « encapuchonné » — et il n'a
## pas de pèlerine, exprès : elle appartient à ceux qu'on veut larges, pas à
## ceux qu'on veut étroits.
func _capuche_pointue(color: Color, hauteur: float, chute: float) -> void:
	_add("head", SkinPart.Shape.ELLIPSOID, Vector3(0.250, 0.285, 0.30),
		Vector3(0.0, 0.085, -0.030), Vector3.ZERO, color)
	_add("head", SkinPart.Shape.ELLIPSOID, Vector3(0.175, 0.180, 0.13),
		Vector3(0.0, 0.075, 0.082), Vector3.ZERO, Color(0.05, 0.06, 0.06))
	var pied: Vector3 = Vector3(0.0, 0.165, -0.050)
	var tilt: Vector3 = Vector3(-36.0, 0.0, 0.0)
	var axe: Vector3 = _sens(tilt)
	_add("head", SkinPart.Shape.CONE, Vector3(0.108, hauteur, 0.0),
		pied + axe * (hauteur * 0.5), tilt, color)
	# Le bout PEND. Un cornet qui pointe le ciel fait un bonnet de sorcier de
	# conte ; un cornet qui retombe fait un homme sous la pluie de sel.
	var bout: Vector3 = pied + axe * hauteur
	var tilt_bas: Vector3 = Vector3(-98.0, 0.0, 0.0)
	_add("head", SkinPart.Shape.CONE, Vector3(0.062, chute, 0.0),
		bout + _sens(tilt_bas) * (chute * 0.42), tilt_bas,
		color.darkened(0.24))
	# Col fermé, étroit : il raccorde la capuche au buste sans rien élargir.
	_add("spine_03", SkinPart.Shape.TORUS, Vector3(0.080, 0.0, 0.130),
		Vector3(0.0, 0.140, -0.010), Vector3(8.0, 0.0, 0.0),
		color.darkened(0.20))

## Cape qui traîne : trois pans accrochés à la nuque, qui dépassent les talons.
##
## Trois boîtes, et la silhouette double de surface. C'est le seul accessoire
## qui rende un personnage plus imposant quand il MARCHE, parce qu'il balaie
## derrière lui à chaque pas du buste.
func _cape(color: Color, longueur: float, largeur: float) -> void:
	# DEUX PANS, ET UNE FENTE ENTRE EUX. En un seul tenant, la cape faisait
	# une planche noire d'un mètre sur un mètre et demi qui effaçait d'un
	# coup les jambes, la jupe et la croûte du dos : un boss ne doit pas se
	# lire comme une porte. La fente laisse passer les bottes, donc le pas,
	# et c'est ce qu'on regarde pour esquiver.
	#
	# Un pan du milieu simplement plus court ne suffisait pas — posé devant
	# les deux autres, il se lisait comme un panneau collé par-dessus, pas
	# comme une ouverture.
	for cote: float in [1.0, -1.0]:
		var chute: float = longueur * (1.0 if cote > 0.0 else 0.94)
		var glisse: Vector3 = Vector3(cote * largeur * 0.30, 0.0, -0.130)
		var pente: Vector3 = Vector3(4.0, cote * -9.0, cote * 5.0)
		_add("spine_03", SkinPart.Shape.BOX,
			Vector3(largeur * 0.54, chute, 0.030),
			glisse + Vector3(0.0, 0.115 - chute * 0.46, 0.0), pente,
			color.darkened(0.10 - cote * 0.06))
		# Ourlet plus clair : il ferme le pan, et il donne au bas de la cape
		# une ligne qu'on suit des yeux quand la chose se déplace.
		_add("spine_03", SkinPart.Shape.BOX,
			Vector3(largeur * 0.56, 0.052, 0.042),
			glisse + Vector3(0.0, 0.115 - chute * 0.94, 0.0), pente,
			color.lightened(0.20))
	# Col d'attache. Sans lui la cape commence dans le vide à dix centimètres
	# de la nuque, et on voit le jour entre les deux dès qu'on regarde d'en
	# haut — le défaut exact que le col roulé de la pèlerine réparait déjà.
	_add("spine_03", SkinPart.Shape.BOX, Vector3(largeur * 0.98, 0.11, 0.13),
		Vector3(0.0, 0.150, -0.075), Vector3(18.0, 0.0, 0.0),
		color.lightened(0.12))

## Lanterne pendue à un anneau : chapeau de fer, verre allumé, socle.
##
## Elle pend sous l'os qui la porte, donc elle balance avec lui ; et une
## source qu'on VOIT briller est la seule espèce de lampe que ce projet
## s'autorise — une lumière sans lampe visible, on ne se l'explique plus six
## mois après.
func _lanterne(bone: String, ancre: Vector3, teinte: Color,
		portee: float) -> void:
	_add(bone, SkinPart.Shape.CYLINDER, Vector3(0.011, 0.085, 0.011),
		ancre + Vector3(0.0, 0.042, 0.0), Vector3.ZERO, FER,
		SkinPart.Surface.METAL)
	_add(bone, SkinPart.Shape.TORUS, Vector3(0.020, 0.0, 0.034),
		ancre + Vector3(0.0, 0.086, 0.0), Vector3(90.0, 0.0, 0.0), FER,
		SkinPart.Surface.METAL)
	_add(bone, SkinPart.Shape.CONE, Vector3(0.072, 0.055, 0.0),
		ancre + Vector3(0.0, -0.012, 0.0), Vector3.ZERO, FER,
		SkinPart.Surface.METAL)
	_add(bone, SkinPart.Shape.CYLINDER, Vector3(0.052, 0.125, 0.058),
		ancre + Vector3(0.0, -0.100, 0.0), Vector3.ZERO, teinte,
		SkinPart.Surface.GLOW, false, portee)
	_add(bone, SkinPart.Shape.CYLINDER, Vector3(0.064, 0.022, 0.064),
		ancre + Vector3(0.0, -0.172, 0.0), Vector3.ZERO, FER,
		SkinPart.Surface.METAL)

## Ceinture d'outils : des manches qui pendent en grappe sur une hanche.
##
## En grappe et sur UNE hanche, jamais réparties tout autour : une ceinture
## régulière se lit comme une jupe à franges, un paquet d'outils d'un seul
## côté se lit comme quelqu'un qui travaille et déséquilibre la silhouette.
func _ceinture_outils(color: Color, tour_base: float, nombre: int) -> void:
	for outil: int in nombre:
		var tour: float = tour_base + float(outil) * 23.0
		var chute: float = 0.16 + float((outil * 3) % 3) * 0.06
		# Au-delà du tablier, pas dessous : posés à dix-huit centimètres, les
		# outils disparaissaient derrière le pan latéral et on ne voyait
		# rien de la ceinture qu'on venait de coudre.
		var rayon: float = 0.250
		var pied: Vector3 = Vector3(sin(deg_to_rad(tour)) * rayon, 0.040,
			cos(deg_to_rad(tour)) * rayon)
		_add("pelvis", SkinPart.Shape.CYLINDER,
			Vector3(0.015, chute, 0.019),
			pied + Vector3(0.0, -chute * 0.5, 0.0),
			Vector3(0.0, tour, 7.0 - float(outil) * 4.0), CUIR,
			SkinPart.Surface.WOOD)
		_add("pelvis", SkinPart.Shape.BOX, Vector3(0.060, 0.055, 0.024),
			pied + Vector3(0.0, -chute - 0.018, 0.0),
			Vector3(0.0, tour, 0.0), color, SkinPart.Surface.METAL)

## Crête dorsale de sel : des lames plantées le long de la colonne, la plus
## haute au-dessus des épaules.
##
## C'est la pièce qui décide qu'un cristallisé est un ENNEMI. Vue de dos — le
## seul angle sous lequel on le voit arriver — elle casse la ligne du dos, et
## une ligne de dos cassée n'a jamais été celle d'un être humain.
func _crete_sel() -> void:
	var os: Array[String] = ["pelvis", "spine_01", "spine_02", "spine_03",
		"spine_03"]
	var hauteurs: Array[float] = [0.16, 0.22, 0.29, 0.37, 0.26]
	var eleves: Array[float] = [-0.010, 0.020, 0.045, 0.075, 0.185]
	for etage: int in os.size():
		var tilt: Vector3 = Vector3(-46.0 + float(etage) * 7.0,
			float(etage % 2) * 26.0 - 13.0, 0.0)
		var pied: Vector3 = Vector3(float(etage % 3) * 0.024 - 0.024,
			eleves[etage], -0.110)
		var teinte: Color = SEL if etage % 2 == 0 else SEL_OMBRE
		_add(os[etage], SkinPart.Shape.PRISM,
			Vector3(0.105, hauteurs[etage], 0.062),
			pied + _sens(tilt) * (hauteurs[etage] * 0.38), tilt, teinte,
			SkinPart.Surface.STONE)

## Couronne de sel : des lames plantées tout autour du crâne.
##
## La tête d'un cristallisé ne doit pas être une tête. C'est ce qui, en un
## dixième de seconde et de dos, sépare la chose du joueur pâle qu'on croyait
## voir arriver.
func _couronne_sel(nombre: int, longueur: float) -> void:
	for pointe: int in nombre:
		var angle: float = float(pointe) * (360.0 / float(nombre)) + 15.0
		var penche: float = 24.0 + float(pointe % 3) * 13.0
		var taille: float = longueur * (0.60 + float((pointe * 5) % 4) * 0.17)
		var pied: Vector3 = Vector3(sin(deg_to_rad(angle)) * 0.082, 0.150,
			cos(deg_to_rad(angle)) * 0.082)
		var tilt: Vector3 = Vector3(cos(deg_to_rad(angle)) * penche, angle,
			-sin(deg_to_rad(angle)) * penche)
		var teinte: Color = SEL if pointe % 2 == 0 else SEL_OMBRE
		_add("head", SkinPart.Shape.PRISM,
			Vector3(0.072, taille, 0.052),
			pied + _sens(tilt) * (taille * 0.40), tilt, teinte,
			SkinPart.Surface.STONE)

## Cornes : deux fers courbés qui sortent de la capuche, en deux tronçons dont
## le second se redresse.
##
## C'est la seule pièce de la distribution qui ne dit aucun métier — et c'est
## exactement pour ça qu'elle dit « boss ». Tous les autres portent des outils.
func _cornes(color: Color) -> void:
	for cote: float in [1.0, -1.0]:
		var pied: Vector3 = Vector3(cote * 0.100, 0.135, -0.015)
		var tilt: Vector3 = Vector3(-16.0, 0.0, cote * -36.0)
		var axe: Vector3 = _sens(tilt)
		_add("head", SkinPart.Shape.CONE, Vector3(0.055, 0.24, 0.0),
			pied + axe * 0.12, tilt, color, SkinPart.Surface.METAL)
		var coude: Vector3 = pied + axe * 0.235
		var tilt_haut: Vector3 = Vector3(-6.0, 0.0, cote * -7.0)
		_add("head", SkinPart.Shape.CONE, Vector3(0.036, 0.26, 0.0),
			coude + _sens(tilt_haut) * 0.13, tilt_haut,
			color.lightened(0.14), SkinPart.Surface.METAL)
		_add("head", SkinPart.Shape.TORUS, Vector3(0.030, 0.0, 0.050),
			coude, Vector3(0.0, 0.0, cote * 40.0), color.darkened(0.25),
			SkinPart.Surface.METAL)

# ---------------------------------------------------------------------------
# Distribution
# ---------------------------------------------------------------------------

func _build(id: StringName) -> void:
	match id:
		&"mannequin":
			_mannequin()
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

## LE SAUNIER — coupeur de sel. LARGE ET BAS : c'est le seul mot d'ordre de
## sa silhouette, et tout ce qu'il porte y sert.
##
## Il est le plus large de la distribution — plaques dépareillées aux épaules,
## hotte plus haute que sa tête, chapeau de trente-sept centimètres, tablier
## court et évasé — et le seul dont on voie les cuisses entre les pans. Un
## lourd ne se lit pas à sa taille : il se lit au rapport entre sa largeur et
## sa hauteur, et à la hauteur à laquelle sa masse est posée.
##
## La plaque de sel sur l'épaule gauche est asymétrique : elle a POUSSÉ, elle
## n'a pas été forgée — et c'est l'épaule qui porte la hotte.
func _saunier() -> void:
	_vetement(TOILE)
	_tablier(ROUILLE, 0.46, 0.240)
	_pelerine(ROUILLE.darkened(0.22))
	_epaulieres(FER.lightened(0.12), 0.120)
	_plaque_epaule("l", FER.lightened(0.06), 0.39, 0.35, 23.0)
	_plaque_epaule("r", FER.darkened(0.12), 0.26, 0.27, 31.0)
	_tete(true)
	# Chapeau HAUT et étroit. À trente-sept centimètres de bord il faisait le
	# même disque que celui de la rinceuse, et deux chapeaux larges dans une
	# distribution de six, c'est un chapeau de trop : la largeur du saunier
	# doit venir de ses épaules et de sa hotte, jamais de sa tête.
	_chapeau(0.28, 0.19, TOILE_CLAIRE)
	# Sur la plaque, pas sur la clavicule : la clavicule est au creux du cou —
	# mesuré, à dix-neuf millimètres de l'axe — et un bloc posé dessus se
	# retrouve à moitié enfoncé dans la poitrine.
	_eclat("upperarm_l", Vector3(0.18, 0.15, 0.17),
		Vector3(0.030, 0.105, 0.0), Vector3(0.0, 0.0, -22.0))
	_hotte(CUIR.lightened(0.12), 0.42, 0.62, 0.24)
	_ceinture_outils(FER, 104.0, 4)
	_rabot()

## Le rabot à sel : manche long, lame large montée de travers. Ce n'est pas
## une épée, et ça doit se voir au premier coup d'œil.
func _rabot() -> void:
	_hampe(0.94, 0.024, CUIR, SkinPart.Surface.WOOD)
	_prop(SkinPart.Shape.BOX, Vector3(0.30, 0.10, 0.06),
		Vector3(0.0, 0.62, 0.0), Vector3(0.0, 0.0, 8.0), FER,
		SkinPart.Surface.METAL, true)
	_prop(SkinPart.Shape.PRISM, Vector3(0.30, 0.16, 0.04),
		Vector3(0.0, 0.72, 0.0), Vector3(0.0, 0.0, 8.0), SEL,
		SkinPart.Surface.STONE, true)
	_prop(SkinPart.Shape.TORUS, Vector3(0.030, 0.0, 0.050),
		Vector3(0.0, 0.10, 0.0), Vector3.ZERO, CORDE)

## LE MANNEQUIN D'ENTRAINEMENT. Un corps de saunier mort empaille de toile et
## plante sur un pieu : dans ce monde on ne s'entraine pas sur un sac, on
## s'entraine sur un cristallise qu'on a redresse. C'est le premier chose que
## le joueur frappe, donc c'est la premiere chose qui doit dire ou il est.
func _mannequin() -> void:
	_manchon("upperarm_l", "lowerarm_l", 0.0, 1.0, 0.09, 0.085, TOILE_CLAIRE)
	_manchon("upperarm_r", "lowerarm_r", 0.0, 1.0, 0.09, 0.085, TOILE_CLAIRE)
	_manchon("lowerarm_l", "hand_l", 0.0, 1.0, 0.075, 0.065, TOILE_CLAIRE)
	_manchon("lowerarm_r", "hand_r", 0.0, 1.0, 0.075, 0.065, TOILE_CLAIRE)
	_manchon("thigh_l", "calf_l", 0.0, 1.0, 0.12, 0.10, TOILE_CLAIRE)
	_manchon("thigh_r", "calf_r", 0.0, 1.0, 0.12, 0.10, TOILE_CLAIRE)
	_manchon("calf_l", "foot_l", 0.0, 1.0, 0.095, 0.08, TOILE_CLAIRE)
	_manchon("calf_r", "foot_r", 0.0, 1.0, 0.095, 0.08, TOILE_CLAIRE)
	_add("spine_02", SkinPart.Shape.ELLIPSOID, Vector3(0.44, 0.52, 0.32),
		Vector3(0.0, 0.06, 0.0), Vector3.ZERO, TOILE_CLAIRE)
	# Tete : un sac de toile serre au cou. Pas de visage, pas de lunettes —
	# ce n'est plus quelqu'un.
	_add("head", SkinPart.Shape.ELLIPSOID, Vector3(0.24, 0.28, 0.25),
		Vector3(0.0, 0.05, 0.0), Vector3.ZERO, TOILE_CLAIRE)
	_add("head", SkinPart.Shape.TORUS, Vector3(0.075, 0.0, 0.11),
		Vector3(0.0, -0.07, 0.0), Vector3.ZERO, CORDE)
	for tour: int in 4:
		_bande("spine_02", "spine_03", 0.1 + float(tour) * 0.26, 0.24, CORDE)
	_eclat("clavicle_r", Vector3(0.13, 0.12, 0.12),
		Vector3(-0.05, 0.05, 0.0), Vector3(0.0, 0.0, 26.0), SEL_OMBRE)
	# Le pieu qui le tient debout : il sort du dos et se plante au sol.
	_add("pelvis", SkinPart.Shape.CYLINDER, Vector3(0.075, 2.4, 0.085),
		Vector3(0.0, -0.35, -0.26), Vector3(6.0, 0.0, 0.0), CUIR)

## LE HARPONNEUR — ÉTROIT ET HAUT, l'exact contraire du saunier.
##
## Rien sur les épaules : pas de pèlerine, des épaulières minuscules, un
## tablier de treize centimètres de large. Toute sa présence est au-dessus de
## sa tête — le cornet de sa capuche part en arrière, l'éventail de son
## carquois part en avant, et les deux se croisent au-dessus de son épaule.
## C'est le seul de la distribution dont le contour soit plus haut que large.
func _harponneur() -> void:
	_vetement(SAUMURE.lightened(0.14))
	_tablier(SAUMURE.darkened(0.22), 0.42, 0.135)
	_epaulieres(SAUMURE.darkened(0.34), 0.088)
	_tete(true)
	_capuche_pointue(SAUMURE, 0.40, 0.30)
	_carquois(SAUMURE.darkened(0.30), 4)
	# Rouleau de cordage sur la hanche OPPOSÉE au carquois : deux masses du
	# même côté font une bosse, deux masses en biais font une démarche.
	# Les tours s'empilent le long de l'AXE du rouleau, qui pointe vers
	# l'extérieur une fois la pièce basculée : empilés vers le haut, ils se
	# recouvraient et le rouleau sortait en disque plat de bouclier.
	for turn: int in 4:
		_add("pelvis", SkinPart.Shape.TORUS, Vector3(0.060, 0.0, 0.096),
			Vector3(-0.168 - float(turn) * 0.026, 0.010, 0.035),
			Vector3(0.0, 0.0, 78.0), CORDE.darkened(float(turn) * 0.05))
	for croc: int in 3:
		_add("pelvis", SkinPart.Shape.TORUS, Vector3(0.026, 0.0, 0.048),
			Vector3(-0.02 + float(croc) * 0.085, -0.02, 0.185),
			Vector3(0.0, 0.0, 24.0 - float(croc) * 20.0), FER,
			SkinPart.Surface.METAL)
	_eclat("upperarm_r", Vector3(0.105, 0.095, 0.105),
		Vector3(-0.020, 0.070, 0.0), Vector3(0.0, 0.0, 22.0), SEL_OMBRE)
	_harpon()

func _harpon() -> void:
	_hampe(1.32, 0.018, CUIR, SkinPart.Surface.WOOD)
	_prop(SkinPart.Shape.CONE, Vector3(0.040, 0.22, 0.0),
		Vector3(0.0, 0.90, 0.0), Vector3.ZERO, FER,
		SkinPart.Surface.METAL, true)
	for side: float in [-1.0, 1.0]:
		_prop(SkinPart.Shape.PRISM, Vector3(0.06, 0.13, 0.016),
			Vector3(side * 0.040, 0.82, 0.0), Vector3(0.0, 0.0, side * 152.0),
			FER, SkinPart.Surface.METAL, true)

## LE VERRIER — souffleur de verre de saumure. EFFILÉ : une colonne noire.
##
## Sa redingote descend aux chevilles et ne s'évase presque pas ; il ne porte
## ni pèlerine, ni plaque, ni chapeau. Ce qui le rend reconnaissable ne touche
## pas son corps : un cornet d'un demi-mètre en arrière, et la cheminée de son
## fourneau qui passe par-dessus l'épaule et fume plus haut que son crâne.
## Une perle en fusion qui brille sans four qui la chauffe, c'est exactement
## le genre d'incohérence qu'on ne remarque pas en la posant.
func _verrier() -> void:
	_vetement(SUIE.lightened(0.12))
	_redingote(SUIE, 0.86, 0.145, 0.205)
	_tete(false)
	_capuche_pointue(SUIE, 0.46, 0.34)
	# Le fourneau de dos.
	_add("spine_03", SkinPart.Shape.BOX, Vector3(0.235, 0.30, 0.165),
		Vector3(0.0, -0.030, -0.150), Vector3(-6.0, 0.0, 0.0), FER,
		SkinPart.Surface.METAL)
	# Sa gueule brille en VERT, pas en orange. Le gardien des braises est la
	# seule chose chaude de la région : lui laisser un four rouge, c'est lui
	# retirer ce qui fait qu'on le reconnaît au bout d'un couloir.
	_add("spine_03", SkinPart.Shape.BOX, Vector3(0.105, 0.085, 0.035),
		Vector3(0.0, -0.070, -0.238), Vector3(-6.0, 0.0, 0.0), VERRE,
		SkinPart.Surface.GLOW, false, 1.6)
	for sangle: float in [-1.0, 1.0]:
		_add("spine_03", SkinPart.Shape.BOX, Vector3(0.050, 0.32, 0.024),
			Vector3(sangle * 0.115, 0.045, 0.098),
			Vector3(-6.0, 0.0, sangle * 10.0), CUIR)
	# Sa cheminée : le seul trait du personnage qui sorte du contour.
	var pied: Vector3 = Vector3(-0.080, 0.105, -0.145)
	var tilt: Vector3 = Vector3(-7.0, 0.0, 23.0)
	var axe: Vector3 = _sens(tilt)
	_add("spine_03", SkinPart.Shape.CYLINDER, Vector3(0.032, 0.48, 0.038),
		pied + axe * 0.24, tilt, FER, SkinPart.Surface.METAL)
	_add("spine_03", SkinPart.Shape.CYLINDER, Vector3(0.064, 0.055, 0.050),
		pied + axe * 0.505, tilt, FER, SkinPart.Surface.METAL)
	_add("spine_03", SkinPart.Shape.CONE, Vector3(0.052, 0.15, 0.0),
		pied + axe * 0.605, tilt, VERRE, SkinPart.Surface.GLOW, false, 2.6)
	# Cannes de rechange plantées dans le fourneau, en éventail plat.
	for index: int in 3:
		var ecart: float = float(index) - 1.0
		var tilt_canne: Vector3 = Vector3(-30.0, 0.0, -8.0 + ecart * 17.0)
		_add("spine_03", SkinPart.Shape.CYLINDER,
			Vector3(0.011, 0.44, 0.013),
			Vector3(0.045, 0.100, -0.195) + _sens(tilt_canne) * 0.22,
			tilt_canne, FER, SkinPart.Surface.METAL)
	_canne()

func _canne() -> void:
	_hampe(1.04, 0.016, FER, SkinPart.Surface.METAL)
	_prop(SkinPart.Shape.SPHERE, Vector3(0.068, 0.0, 0.0),
		Vector3(0.0, 0.74, 0.0), Vector3.ZERO, VERRE, SkinPart.Surface.GLOW,
		true, 3.4)
	_prop(SkinPart.Shape.TORUS, Vector3(0.024, 0.0, 0.042),
		Vector3(0.0, 0.09, 0.0), Vector3.ZERO, CORDE)

## LA RINCEUSE — celle qui lave le sel des autres. Chapeau plat et large,
## outre de saumure, fioles. Rien de martial : sa silhouette doit dire
## « on vient vers elle », pas « on la fuit ».
func _rinceuse() -> void:
	_vetement(TOILE_CLAIRE)
	_redingote(OCRE, 0.66, 0.165, 0.265)
	_pelerine(OCRE.darkened(0.26))
	_tete(false)
	# QUARANTE-CINQ CENTIMÈTRES DE BORD. C'est la pièce la plus large de la
	# distribution, portée par la plus petite personne : un disque qui déborde
	# des épaules ne ressemble à rien d'autre, et c'est tout ce qu'il faut
	# pour la reconnaître de dos, à vingt mètres, en contre-jour.
	_chapeau(0.45, 0.035, TOILE_CLAIRE)
	# Outre de saumure, portée bas dans le dos : elle arrondit le bas de la
	# silhouette, ce qui achève de l'opposer aux deux silhouettes hautes.
	_add("pelvis", SkinPart.Shape.ELLIPSOID, Vector3(0.32, 0.30, 0.22),
		Vector3(0.0, 0.055, -0.190), Vector3(-12.0, 0.0, 0.0), CUIR)
	_add("pelvis", SkinPart.Shape.TORUS, Vector3(0.045, 0.0, 0.075),
		Vector3(0.0, 0.185, -0.180), Vector3(90.0, 0.0, 0.0), CORDE)
	for sangle: float in [-1.0, 1.0]:
		_add("spine_03", SkinPart.Shape.BOX, Vector3(0.048, 0.34, 0.024),
			Vector3(sangle * 0.115, 0.030, 0.100),
			Vector3(-6.0, 0.0, sangle * 11.0), CUIR)
	# La lanterne pend à la hanche, pas au-dessus de l'épaule : une potence
	# passerait au travers du bord du chapeau, et une pièce qui traverse une
	# autre pièce est le seul défaut qu'on ne pardonne jamais à un costume.
	_lanterne("pelvis", Vector3(0.215, 0.030, 0.060), VERRE, 3.2)
	for fiole: int in 5:
		var tour: float = -52.0 + float(fiole) * 26.0
		_add("spine_02", SkinPart.Shape.CYLINDER, Vector3(0.024, 0.085, 0.028),
			Vector3(sin(deg_to_rad(tour)) * 0.170,
				-0.030 + float(fiole % 2) * 0.022,
				cos(deg_to_rad(tour)) * 0.135),
			Vector3(12.0, tour, 0.0), VERRE, SkinPart.Surface.GLOW)
	_goupillon()

func _goupillon() -> void:
	_hampe(0.70, 0.018, CUIR, SkinPart.Surface.WOOD)
	_prop(SkinPart.Shape.ELLIPSOID, Vector3(0.15, 0.20, 0.15),
		Vector3(0.0, 0.48, 0.0), Vector3.ZERO, CORDE,
		SkinPart.Surface.CLOTH, true)
	_prop(SkinPart.Shape.SPHERE, Vector3(0.034, 0.0, 0.0),
		Vector3(0.0, 0.58, 0.0), Vector3.ZERO, VERRE, SkinPart.Surface.GLOW,
		false, 2.6)

## LE CRISTALLISÉ — l'ennemi de base. Un homme mort dans le bassin que le sel
## a repris. Il ne porte presque rien : la croûte a remplacé le vêtement, et
## plus elle est étendue, plus la chose est ancienne. C'est la seule barre de
## vie dont on ait besoin.
func _cristallise() -> void:
	_bande("lowerarm_r", "hand_r", 0.40, 0.055, CORDE.darkened(0.35))
	_bande("calf_l", "foot_l", 0.45, 0.070, CORDE.darkened(0.35))
	_bande("calf_r", "foot_r", 0.30, 0.072, CORDE.darkened(0.35))
	# PAS DE TABLIER. Il en portait un, court, de la même coupe que celui des
	# joueurs : c'est ce qui le faisait lire comme un joueur pâle. Un
	# cristallisé n'est plus habillé — ce qui lui reste autour des reins, ce
	# sont des loques, et la fente entre elles laisse voir sa marche.
	for loque: int in 7:
		var tour: float = float(loque) * 51.0 + 12.0
		var chute: float = 0.17 + float((loque * 3) % 4) * 0.07
		_add("pelvis", SkinPart.Shape.BOX, Vector3(0.072, chute, 0.016),
			Vector3(sin(deg_to_rad(tour)) * 0.150, -0.030 - chute * 0.5,
				cos(deg_to_rad(tour)) * 0.150),
			Vector3(0.0, tour, float(loque % 2) * 13.0 - 6.5),
			TOILE.darkened(0.58))
	_add("pelvis", SkinPart.Shape.TORUS, Vector3(0.048, 0.0, 0.170),
		Vector3(0.0, 0.010, 0.0), Vector3.ZERO, CORDE.darkened(0.40))
	# LE CRÂNE EST PRIS. Ni gaze, ni lunettes, ni calotte : la croûte a mangé
	# le haut du visage, et la couronne dit en un dixième de seconde que la
	# chose qui arrive n'a plus de tête.
	_add("head", SkinPart.Shape.ELLIPSOID, Vector3(0.215, 0.205, 0.205),
		Vector3(0.0, 0.100, -0.030), Vector3(-8.0, 0.0, 0.0), SEL_OMBRE,
		SkinPart.Surface.STONE)
	_couronne_sel(7, 0.30)
	_crete_sel()
	_eclat("upperarm_r", Vector3(0.17, 0.16, 0.15),
		Vector3(-0.030, 0.085, 0.0), Vector3(0.0, 0.0, 28.0))
	_eclat("calf_l", Vector3(0.10, 0.13, 0.10),
		Vector3(0.0, -0.14, 0.02), Vector3(0.0, 12.0, 22.0), SEL_OMBRE)
	_eclat("thigh_r", Vector3(0.12, 0.14, 0.12),
		Vector3(-0.025, -0.16, 0.010), Vector3(0.0, -18.0, -20.0), SEL_OMBRE)
	# Le bras gauche est entièrement pris, et il a DOUBLÉ. Plus une croûte :
	# un moulage, plus lourd que le reste du corps. C'est le déséquilibre —
	# un côté normal, un côté monstrueux — qui fait qu'on ne confond pas la
	# chose avec quelqu'un, même immobile, même de loin.
	_manchon("upperarm_l", "lowerarm_l", 0.0, 1.0, 0.128, 0.118, SEL,
		SkinPart.Surface.STONE)
	_manchon("lowerarm_l", "hand_l", 0.0, 0.92, 0.112, 0.095, SEL_OMBRE,
		SkinPart.Surface.STONE)
	_eclat("upperarm_l", Vector3(0.15, 0.15, 0.14),
		Vector3(0.040, 0.060, 0.0), Vector3(0.0, 0.0, -34.0), SEL)
	_eclat("lowerarm_l", Vector3(0.12, 0.13, 0.12),
		Vector3(0.0, -0.10, 0.0), Vector3(14.0, 20.0, 28.0), SEL)
	_eclat("hand_l", Vector3(0.09, 0.15, 0.09),
		Vector3(0.070, -0.010, 0.0), Vector3(0.0, 24.0, 74.0), SEL)
	# Éclat de sel tenu comme une lame : brut, jamais taillé.
	_prop(SkinPart.Shape.PRISM, Vector3(0.10, 0.56, 0.05),
		Vector3(0.0, 0.28, 0.0), Vector3(0.0, 0.0, 6.0), SEL,
		SkinPart.Surface.STONE, true)
	_prop(SkinPart.Shape.TORUS, Vector3(0.028, 0.0, 0.046),
		Vector3(0.0, 0.04, 0.0), Vector3.ZERO, CORDE)

## LE GARDIEN DES BRAISES — le boss. Il garde le dernier feu du bassin et il
## brûle en permanence. La seule chose chaude d'une région entièrement
## blanche, et tout le propos du combat.
##
## IL DOIT ÊTRE PLUS GRAND, ET ÇA NE SE NÉGOCIE PAS. Il sortait du même rig
## que les joueurs, donc à leur taille au centimètre près : le boss d'un
## souls-like qui a la carrure de son joueur ne fait pas peur, il fait duel.
## Trente-six pour cent de stature, des cornes qui montent encore de
## cinquante centimètres au-dessus, des plaques de quarante-cinq centimètres
## et une cape qui traîne au sol — deux mètres quatre-vingt-dix de haut sur
## un mètre trente de large, contre un joueur d'un mètre quatre-vingts.
##
## Et une SEULE chose chaude, grosse, au centre de la poitrine. Cinq lamelles
## orange éparpillées ne faisaient pas un feu : elles faisaient une tache, et
## six petites lampes autour d'un corps noir le repeignaient en terre cuite.
## Un brasier se regarde là où il est, il n'éclabousse pas.
func _lampiste() -> void:
	_vetement(SUIE)
	_tablier(SUIE, 0.64, 0.285, CORDE.darkened(0.52))
	_epaulieres(FER, 0.150)
	_plaque_epaule("l", FER.lightened(0.08), 0.45, 0.42, 21.0)
	_plaque_epaule("r", FER.darkened(0.14), 0.33, 0.36, 28.0)
	_tete(true, SUIE.lightened(0.14))
	_capuche(SUIE)
	_cornes(FER.lightened(0.05))
	_cape(SUIE.darkened(0.22), 1.44, 0.60)
	_brasier()
	# Lanternes pendues sous les plaques : elles balancent avec les épaules,
	# donc elles annoncent le pas avant que le pas ne se voie.
	# Elles BRILLENT sans éclairer. Six sources chaudes à moins d'un mètre
	# d'une toile de suie, et la chose la plus noire du jeu ressortait en
	# terre cuite : le brasier de poitrine est la seule qui ait le droit de
	# poser de la lumière sur son porteur.
	_lanterne("upperarm_l", Vector3(0.300, -0.030, 0.0), BRAISE, 0.0)
	_lanterne("upperarm_r", Vector3(-0.225, -0.055, 0.0), BRAISE, 0.0)
	# Loques allumées aux avant-bras. Elles GLOW mais n'éclairent plus : leur
	# lumière ne servait qu'à laver la toile qu'elles sont censées trouer.
	for side: String in ["l", "r"]:
		for loque: int in 2:
			_add("lowerarm_" + side, SkinPart.Shape.BOX,
				Vector3(0.05, 0.20 + float(loque) * 0.07, 0.014),
				Vector3(0.0, -0.09 - float(loque) * 0.05, 0.05),
				Vector3(0.0, float(loque) * 24.0, 0.0), BRAISE,
				SkinPart.Surface.GLOW)
	_eclat("upperarm_l", Vector3(0.20, 0.17, 0.19),
		Vector3(0.035, 0.130, 0.0), Vector3(0.0, 0.0, -30.0))
	_eclat("upperarm_r", Vector3(0.16, 0.14, 0.15),
		Vector3(-0.030, 0.110, 0.0), Vector3(0.0, 0.0, 30.0), SEL_OMBRE)
	_ratelier()

## Le brasier de poitrine : une cage de fer, une braise dedans, et rien
## d'autre d'allumé sur tout le buste. C'est le point qu'on vise, donc c'est
## le seul point qui a le droit de briller à cet endroit.
func _brasier() -> void:
	_add("spine_02", SkinPart.Shape.CYLINDER, Vector3(0.140, 0.020, 0.155),
		Vector3(0.0, 0.115, 0.110), Vector3(-8.0, 0.0, 0.0), FER,
		SkinPart.Surface.METAL)
	_add("spine_02", SkinPart.Shape.CYLINDER, Vector3(0.150, 0.024, 0.140),
		Vector3(0.0, -0.090, 0.120), Vector3(-8.0, 0.0, 0.0), FER,
		SkinPart.Surface.METAL)
	for barreau: int in 6:
		var tour: float = -66.0 + float(barreau) * 26.0
		_add("spine_02", SkinPart.Shape.CYLINDER,
			Vector3(0.010, 0.215, 0.010),
			Vector3(sin(deg_to_rad(tour)) * 0.140, 0.012,
				0.115 + cos(deg_to_rad(tour)) * 0.058),
			Vector3(-8.0, 0.0, 0.0), FER, SkinPart.Surface.METAL)
	_add("spine_02", SkinPart.Shape.SPHERE, Vector3(0.098, 0.0, 0.0),
		Vector3(0.0, 0.010, 0.120), Vector3.ZERO, BRAISE,
		SkinPart.Surface.GLOW, false, 3.2)

## Un râtelier de lampes tenu comme une arme d'hast. Trois lampes qui pendent :
## ce sont elles qu'on regarde, donc ce sont elles qui annoncent le coup.
func _ratelier() -> void:
	_hampe(1.42, 0.028, FER, SkinPart.Surface.METAL)
	_prop(SkinPart.Shape.BOX, Vector3(0.58, 0.04, 0.04),
		Vector3(0.0, 0.96, 0.0), Vector3.ZERO, FER,
		SkinPart.Surface.METAL, true)
	for index: int in 3:
		var x: float = -0.22 + float(index) * 0.22
		_prop(SkinPart.Shape.CYLINDER, Vector3(0.010, 0.11, 0.010),
			Vector3(x, 0.90, 0.0), Vector3.ZERO, FER, SkinPart.Surface.METAL)
		_prop(SkinPart.Shape.ELLIPSOID, Vector3(0.11, 0.14, 0.11),
			Vector3(x, 0.78, 0.0), Vector3.ZERO, BRAISE,
			SkinPart.Surface.GLOW, true, 1.7)
