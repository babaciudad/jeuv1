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
	body._paint_skin(rig, id)
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
			# La chair du cristallisé reste SOMBRE : c'est la croûte qui doit
			# être la seule chose claire de lui. Peint en blanc partout, il ne
			# lisait plus comme un homme pris par le sel mais comme une statue
			# de marbre.
			tone = DESSOUS.lerp(SEL_OMBRE, 0.34)
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
	lamp.light_energy = 0.30 * light_range
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
		_bande("lowerarm_" + side, "hand_" + side, 0.18, 0.058)
		_bande("lowerarm_" + side, "hand_" + side, 0.52, 0.052)
		_bande("lowerarm_" + side, "hand_" + side, 0.84, 0.048)
		_manchon("thigh_" + side, "calf_" + side, 0.02, 0.62,
			0.105, 0.090, color)
		_bande("calf_" + side, "foot_" + side, 0.22, 0.075)
		_bande("calf_" + side, "foot_" + side, 0.55, 0.068)
		_bande("calf_" + side, "foot_" + side, 0.84, 0.062)
		# Botte : lourde, carrée, posée devant la cheville.
		_add("foot_" + side, SkinPart.Shape.BOX,
			Vector3(0.135, 0.10, 0.27), Vector3(0.0, 0.03, 0.05),
			Vector3.ZERO, CUIR)

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
		largeur: float = 0.20) -> void:
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
	_add("pelvis", SkinPart.Shape.TORUS, Vector3(0.055, 0.0, 0.195),
		Vector3(0.0, 0.02, 0.0), Vector3.ZERO, CORDE)
	for loque: int in 4:
		var tour: float = -46.0 + float(loque) * 31.0
		var chute: float = 0.13 + float(loque % 3) * 0.08
		_add("pelvis", SkinPart.Shape.BOX,
			Vector3(0.042, chute, 0.014),
			Vector3(sin(deg_to_rad(tour)) * 0.20, -0.01 - chute * 0.5,
				cos(deg_to_rad(tour)) * 0.20),
			Vector3(0.0, tour, float(loque % 2) * 9.0 - 4.5), CORDE)

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
func _tete(lunettes: bool) -> void:
	# La calotte est SOMBRE. Elle était en toile claire, et sur un corps
	# désormais très sombre elle devenait la chose la plus lumineuse du
	# personnage : de dos, on ne voyait plus qu'un gros œuf pâle. Le seul
	# élément clair de la tête doit être la gaze du bas du visage, parce que
	# c'est elle qui dit où le personnage regarde.
	_add("head", SkinPart.Shape.ELLIPSOID, Vector3(0.205, 0.135, 0.21),
		Vector3(0.0, 0.115, 0.0), Vector3.ZERO, DESSOUS)
	_add("head", SkinPart.Shape.ELLIPSOID, Vector3(0.180, 0.100, 0.19),
		Vector3(0.0, -0.005, 0.030), Vector3(-12.0, 0.0, 0.0), TOILE_CLAIRE)
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

## LE SAUNIER — coupeur de sel. Lourd, épaulé, chapeau large, sac dans le dos.
## La plaque de sel sur l'épaule gauche est asymétrique : elle a poussé, elle
## n'a pas été forgée.
func _saunier() -> void:
	_vetement(TOILE)
	_tablier(ROUILLE, 0.56, 0.205)
	_pelerine(ROUILLE.darkened(0.22))
	_epaulieres(FER.lightened(0.12), 0.125)
	_tete(true)
	_chapeau(0.32, 0.13, TOILE_CLAIRE)
	_eclat("clavicle_l", Vector3(0.15, 0.13, 0.15),
		Vector3(0.06, 0.05, 0.0), Vector3(0.0, 0.0, -28.0))
	_eclat("clavicle_r", Vector3(0.09, 0.10, 0.09),
		Vector3(-0.05, 0.06, 0.03), Vector3(-14.0, -20.0, 22.0), SEL_OMBRE)
	# Sac de sel, porté haut : il dit le métier avant l'outil, et il donne une
	# masse au dos — un personnage vu de dos ne doit pas être plus pauvre.
	_add("spine_03", SkinPart.Shape.ELLIPSOID, Vector3(0.30, 0.34, 0.20),
		Vector3(0.0, 0.06, -0.20), Vector3(-8.0, 0.0, 4.0), TOILE_CLAIRE)
	_add("spine_03", SkinPart.Shape.TORUS, Vector3(0.10, 0.0, 0.14),
		Vector3(0.0, 0.21, -0.20), Vector3(90.0, 0.0, 0.0), CORDE)
	for bretelle: float in [-1.0, 1.0]:
		_add("spine_03", SkinPart.Shape.BOX, Vector3(0.05, 0.30, 0.02),
			Vector3(bretelle * 0.13, 0.05, 0.14),
			Vector3(0.0, 0.0, bretelle * 12.0), CUIR)
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

## LE HARPONNEUR — capuche rabattue, lunettes, rouleau de cordage à la
## ceinture. Sa signature dit ce qu'il fait.
func _harponneur() -> void:
	_vetement(SAUMURE.lightened(0.14))
	_tablier(SAUMURE.darkened(0.22), 0.46, 0.175)
	_epaulieres(SAUMURE.darkened(0.34), 0.10)
	_tete(true)
	_capuche(SAUMURE)
	for turn: int in 3:
		_add("pelvis", SkinPart.Shape.TORUS, Vector3(0.075, 0.0, 0.10),
			Vector3(0.20, 0.03 + float(turn) * 0.026, 0.07),
			Vector3(0.0, 0.0, 74.0), CORDE)
	for croc: int in 3:
		_add("pelvis", SkinPart.Shape.TORUS, Vector3(0.026, 0.0, 0.048),
			Vector3(-0.10 + float(croc) * 0.10, -0.01, 0.20),
			Vector3(0.0, 0.0, 24.0 - float(croc) * 20.0), FER,
			SkinPart.Surface.METAL)
	_eclat("clavicle_r", Vector3(0.10, 0.09, 0.10),
		Vector3(-0.05, 0.05, 0.0), Vector3(0.0, 0.0, 20.0), SEL_OMBRE)
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

## LE VERRIER — souffleur de verre de saumure. Capuche haute, silhouette
## étroite, et la seule chose colorée du groupe : la perle en fusion.
func _verrier() -> void:
	_vetement(SUIE.lightened(0.12))
	_redingote(SUIE, 0.74, 0.160, 0.235)
	_tete(false)
	_capuche(SUIE)
	for index: int in 4:
		_add("spine_03", SkinPart.Shape.PRISM, Vector3(0.055, 0.32, 0.018),
			Vector3(-0.09 + float(index) * 0.06, 0.08, -0.17),
			Vector3(26.0, 0.0, -28.0 + float(index) * 16.0), VERRE,
			SkinPart.Surface.GLOW)
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
	_redingote(OCRE, 0.70, 0.170, 0.245)
	_pelerine(OCRE.darkened(0.26))
	_tete(false)
	_chapeau(0.36, 0.04, TOILE_CLAIRE)
	_add("spine_03", SkinPart.Shape.ELLIPSOID, Vector3(0.25, 0.30, 0.17),
		Vector3(0.0, 0.03, -0.19), Vector3(-10.0, 0.0, 0.0), CUIR)
	for fiole: int in 4:
		var x: float = -0.13 + float(fiole) * 0.09
		_add("spine_02", SkinPart.Shape.CYLINDER, Vector3(0.024, 0.085, 0.028),
			Vector3(x, 0.02 + float(fiole % 2) * 0.02, 0.135),
			Vector3(12.0, 0.0, 0.0), VERRE, SkinPart.Surface.GLOW)
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
	_bande("lowerarm_r", "hand_r", 0.40, 0.055)
	_bande("calf_l", "foot_l", 0.45, 0.070)
	_bande("calf_r", "foot_r", 0.30, 0.072)
	_tablier(TOILE.darkened(0.45), 0.34, 0.150)
	_eclat("head", Vector3(0.14, 0.13, 0.14),
		Vector3(0.06, 0.07, -0.02), Vector3(18.0, 24.0, -32.0))
	_eclat("clavicle_r", Vector3(0.16, 0.15, 0.14),
		Vector3(-0.05, 0.04, 0.0), Vector3(0.0, 0.0, 28.0))
	_eclat("spine_03", Vector3(0.17, 0.15, 0.12),
		Vector3(0.05, 0.06, -0.12), Vector3(-16.0, 0.0, -18.0), SEL_OMBRE)
	_eclat("calf_l", Vector3(0.10, 0.13, 0.10),
		Vector3(0.0, -0.14, 0.02), Vector3(0.0, 12.0, 22.0), SEL_OMBRE)
	# Le bras gauche est entièrement pris : plus une croûte, un moulage. Le
	# détail qui dit que la chose n'est plus quelqu'un.
	_manchon("upperarm_l", "lowerarm_l", 0.0, 1.0, 0.085, 0.078, SEL,
		SkinPart.Surface.STONE)
	_manchon("lowerarm_l", "hand_l", 0.0, 0.9, 0.072, 0.062, SEL_OMBRE,
		SkinPart.Surface.STONE)
	_eclat("lowerarm_l", Vector3(0.09, 0.10, 0.09),
		Vector3(0.0, -0.08, 0.0), Vector3(14.0, 20.0, 28.0), SEL)
	# Éclat de sel tenu comme une lame : brut, jamais taillé.
	_prop(SkinPart.Shape.PRISM, Vector3(0.10, 0.56, 0.05),
		Vector3(0.0, 0.28, 0.0), Vector3(0.0, 0.0, 6.0), SEL,
		SkinPart.Surface.STONE, true)
	_prop(SkinPart.Shape.TORUS, Vector3(0.028, 0.0, 0.046),
		Vector3(0.0, 0.04, 0.0), Vector3.ZERO, CORDE)

## LE GARDIEN DES BRAISES — le boss. Il garde le dernier feu du bassin et il
## brûle en permanence : sa toile est huilée et allumée. La seule chose chaude
## d'une région entièrement blanche, et tout le propos du combat.
func _lampiste() -> void:
	_vetement(SUIE)
	_tablier(SUIE, 0.70, 0.225)
	_epaulieres(FER, 0.145)
	_tete(true)
	_capuche(SUIE)
	for index: int in 5:
		var y: float = -0.06 + float(index) * 0.07
		var side: float = -1.0 if index % 2 == 0 else 1.0
		_add("spine_02", SkinPart.Shape.BOX, Vector3(0.15, 0.024, 0.05),
			Vector3(side * 0.11, y, 0.15 + float(index % 3) * 0.015),
			Vector3(0.0, 0.0, side * (18.0 + float(index) * 9.0)), BRAISE,
			SkinPart.Surface.GLOW, false, 1.8)
	for side: String in ["l", "r"]:
		for loque: int in 2:
			_add("lowerarm_" + side, SkinPart.Shape.BOX,
				Vector3(0.05, 0.20 + float(loque) * 0.07, 0.014),
				Vector3(0.0, -0.09 - float(loque) * 0.05, 0.05),
				Vector3(0.0, float(loque) * 24.0, 0.0), BRAISE,
				SkinPart.Surface.GLOW, false, 1.4)
	_eclat("clavicle_l", Vector3(0.17, 0.14, 0.16),
		Vector3(0.07, 0.05, 0.0), Vector3(0.0, 0.0, -30.0))
	_eclat("clavicle_r", Vector3(0.14, 0.12, 0.13),
		Vector3(-0.06, 0.05, 0.0), Vector3(0.0, 0.0, 30.0), SEL_OMBRE)
	_ratelier()

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
			SkinPart.Surface.GLOW, true, 3.2)
