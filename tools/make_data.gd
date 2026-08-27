## Génère res://data/skins/*.tres et res://data/decor/chapelle.tres.
##
## `godot --headless --path . -s tools/make_data.gd`
##
## POURQUOI un générateur et pas des ressources écrites à la main : un
## personnage fait une trentaine de pièces, la chapelle en fait deux cents.
## Les poser une par une dans l'inspecteur est faisable ; les tenir cohérentes
## ne l'est pas — huit colonnes doivent partager leur profil, six skins
## doivent partager leur ossature, et une torche doit ressembler à toutes les
## autres torches.
##
## LEQUEL FAIT FOI : les `.tres`. Ce sont eux que le jeu charge, eux qui sont
## versionnés, eux qu'on peut retoucher dans l'inspecteur pour essayer une
## valeur. Ce script les REGÉNÈRE INTÉGRALEMENT — un réglage fait à la main
## dans l'inspecteur et jugé bon doit être reporté ici, sinon la prochaine
## exécution l'écrase. C'est le seul piège de ce fichier ; il n'y en a pas
## d'autre.
extends SceneTree

# ---------------------------------------------------------------------------
# Raccourcis
# ---------------------------------------------------------------------------

const B: int = SkinPart.Shape.BOX
const C: int = SkinPart.Shape.CAPSULE
const S: int = SkinPart.Shape.SPHERE
const CY: int = SkinPart.Shape.CYLINDER
const CO: int = SkinPart.Shape.CONE
const PR: int = SkinPart.Shape.PRISM
const TO: int = SkinPart.Shape.TORUS

const R_STATIC: int = SkinPart.Role.STATIC
const R_HEAD: int = SkinPart.Role.HEAD
const R_AL: int = SkinPart.Role.ARM_L
const R_AR: int = SkinPart.Role.ARM_R
const R_FL: int = SkinPart.Role.FOREARM_L
const R_FR: int = SkinPart.Role.FOREARM_R
const R_TL: int = SkinPart.Role.THIGH_L
const R_TR: int = SkinPart.Role.THIGH_R
const R_SL: int = SkinPart.Role.SHIN_L
const R_SR: int = SkinPart.Role.SHIN_R

const M_PLAIN: int = SkinPart.Surface.PLAIN
const M_STONE: int = SkinPart.Surface.STONE
const M_WOOD: int = SkinPart.Surface.WOOD
const M_METAL: int = SkinPart.Surface.METAL
const M_CLOTH: int = SkinPart.Surface.CLOTH
const M_GLOW: int = SkinPart.Surface.GLOW

const DARK: Color = Color(0.13, 0.12, 0.15)
const IRON: Color = Color(0.19, 0.19, 0.23)
const STEEL: Color = Color(0.62, 0.64, 0.68)
const GOLD: Color = Color(0.78, 0.62, 0.28)
const LEATHER: Color = Color(0.28, 0.20, 0.14)
const SKIN_TONE: Color = Color(0.76, 0.60, 0.48)
## Bois. Il valait 0,25 : dehors, sur un sol de sel a 0,44 sous un ciel clair,
## toute piece en bois se lisait comme une decoupe NOIRE — un mat de grue, une
## fleche, un sechoir devenaient des rectangles suspendus qu'on prenait pour un
## bug de decor. Une charpente doit rester sombre, pas devenir une silhouette.
const WOOD: Color = Color(0.38, 0.28, 0.20)
## Palette du bassin. Le sel est la seule chose franchement claire, la saumure
## la seule couleur froide saturee, et la flamme la seule chaleur.
## Sel. Franchement BLEUTE-BLANC, et plus clair que tout le reste : au
## crepuscule, un tas de sel est la seule chose du niveau qui renvoie encore
## toute la lumiere, et c'est ce qui doit guider l'oeil.
const SALT: Color = Color(0.94, 0.95, 0.97)
const SALT_DARK: Color = Color(0.66, 0.68, 0.76)
## Saumure vive : le verre des sorts et des verrieres. La seule couleur
## franchement saturee du jeu, et elle doit le rester.
const BRINE: Color = Color(0.24, 0.86, 0.78)
## La saumure d'une vasque, vue de dessus : presque grise, a peine verte. Ce
## qui la signale, c'est qu'elle est LISSE au milieu d'une croute rugueuse.
## Nappe de saumure au repos. Presque NOIRE en propre : ce qu'on voit d'un
## bassin d'evaporation au couchant n'est pas sa couleur, c'est le ciel dedans.
const BRINE_WET: Color = Color(0.11, 0.21, 0.23)
const ROPE: Color = Color(0.72, 0.62, 0.42)
const STONE: Color = Color(0.44, 0.37, 0.31)
const STONE_PALE: Color = Color(0.60, 0.53, 0.44)
const FLAME: Color = Color(1.0, 0.52, 0.16)
const CANDLE: Color = Color(1.0, 0.80, 0.42)
const GLASS_BLUE: Color = Color(0.26, 0.48, 0.98)
const GLASS_GOLD: Color = Color(1.0, 0.78, 0.30)
const GLASS_RED: Color = Color(0.94, 0.26, 0.30)
const GLASS_GREEN: Color = Color(0.32, 0.86, 0.50)

func P(role: int, shape: int, size: Vector3, offset: Vector3,
		color: Color = STONE, tinted: bool = false, shift: float = 0.0,
		weapon: bool = false, unshaded: bool = false,
		rot: Vector3 = Vector3.ZERO, surface: int = M_PLAIN,
		light: float = 0.0) -> SkinPart:
	var part: SkinPart = SkinPart.new()
	part.role = role as SkinPart.Role
	part.shape = shape as SkinPart.Shape
	part.surface = surface as SkinPart.Surface
	part.size = size
	part.offset = offset
	part.color = color
	part.tinted = tinted
	part.tint_shift = shift
	part.is_weapon = weapon
	part.unshaded = unshaded
	part.rotation_degrees = rot
	part.light_range = light
	return part

## Pièce de décor : toujours statique, jamais une arme.
func D(shape: int, size: Vector3, offset: Vector3, color: Color,
		surface: int = M_STONE, rot: Vector3 = Vector3.ZERO,
		light: float = 0.0) -> SkinPart:
	return P(R_STATIC, shape, size, offset, color, false, 0.0, false, false,
		rot, surface, light)

## Taille reelle d'un modele du kit, en metres, mise en cache.
##
## Un `.glb` Quaternius porte son echelle SUR LE NOEUD, pas sur le maillage :
## le tonneau mesure 1,6 MILLIMETRE en donnees brutes, et c'est un facteur 100
## sur le `MeshInstance3D` qui en fait un objet de seize centimetres. Le lot de
## MultiMesh, lui, n'instancie que le maillage : il perd ce facteur. Un modele
## pose tel quel se rendait donc a deux millimetres, invisible.
##
## On mesure donc la boite brute une fois par modele, et on place ensuite en
## METRES — ce qui a l'avantage de ne dependre d'aucun nombre magique et de
## rester juste si un modele est remplace par un autre.
var _boites: Dictionary[String, Vector3] = {}
var _bas: Dictionary[String, float] = {}

func _mesurer(chemin: String) -> void:
	if _boites.has(chemin):
		return
	_boites[chemin] = Vector3.ONE
	_bas[chemin] = 0.0
	var scene: PackedScene = load(chemin) as PackedScene
	if scene == null:
		printerr("modele introuvable : %s" % chemin)
		return
	var root: Node = scene.instantiate()
	var maillage: MeshInstance3D = _premier_maillage(root)
	if maillage != null and maillage.mesh != null:
		var boite: AABB = maillage.mesh.get_aabb()
		_boites[chemin] = boite.size
		_bas[chemin] = boite.position.y
	root.queue_free()

func _premier_maillage(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var trouve: MeshInstance3D = _premier_maillage(child)
		if trouve != null:
			return trouve
	return null

## Piece tiree d'un MODELE, et non taillee dans les primitives.
##
## Le decor a longtemps ete fait de boites et de cylindres — c'etait le
## reproche numero un, et il etait juste : une caisse en boite reste une boite,
## quel que soit l'eclairage.
##
## `hauteur` est une HAUTEUR EN METRES, pas un facteur : le modele est mis a
## cette taille, et sa base est posee sur le `y` demande. Voir `_mesurer`.
##
## PROVENANCE DES MODELES. `models/kit/` contient des paquets Quaternius,
## domaine public (CC0), recuperes depuis un miroir GitHub tiers
## (`trebeljahr/quaternius-showcase`) parce que le reseau de la machine de
## developpement n'atteint ni kenney.nl ni quaternius.com. ATTENTION : ce
## miroir ne porte AUCUN fichier de licence — son `LICENSE` est un modele MIT
## sans rapport. Les paquets d'origine sont bien CC0 et les noms correspondent
## au catalogue public de Quaternius, mais avant toute publication
## commerciale il faut les retelecharger depuis Quaternius directement, pour
## avoir une provenance verifiable.
func M(chemin: String, at: Vector3, hauteur: float,
		angle: float = 0.0) -> SkinPart:
	var res: String = "res://models/kit/%s.glb" % chemin
	_mesurer(res)
	var boite: Vector3 = _boites[res]
	var facteur: float = 1.0
	if boite.y > 0.0000001:
		facteur = hauteur / boite.y
	var piece: SkinPart = SkinPart.new()
	piece.shape = SkinPart.Shape.MESH
	piece.mesh_path = res
	piece.size = Vector3.ONE * facteur
	# La base du modele se pose sur le y demande, quelle que soit l'origine
	# choisie par son auteur.
	piece.offset = at + Vector3(0.0, -_bas[res] * facteur, 0.0)
	piece.rotation_degrees = Vector3(0.0, angle, 0.0)
	return piece

func save(resource: Resource, path: String) -> void:
	var code: int = ResourceSaver.save(resource, path)
	if code != OK:
		printerr("échec %s : %d" % [path, code])
	else:
		print("écrit %s" % path)

# ---------------------------------------------------------------------------
# Personnages
# ---------------------------------------------------------------------------

## Membre : un tronc conique, une articulation sphérique à chaque bout.
##
## C'est le motif qui remplace la boîte partout sur les personnages. Une boîte
## laisse un coin vide quand le coude plie, et prend six aplats de lumière ;
## un cône entre deux sphères plie sans trou et s'éclaire d'un dégradé. Trois
## primitives au lieu d'une, pour un personnage qui ne ressemble plus à une
## pile de cageots.
func limb(out: Array[SkinPart], role: int, top_r: float, bottom_r: float,
		length: float, color: Color, tinted: bool = false, shift: float = 0.0,
		surface: int = M_CLOTH, cap_top: bool = true) -> void:
	if cap_top:
		out.append(P(role, S, Vector3(top_r, 0.0, 0.0), Vector3.ZERO,
			color, tinted, shift, false, false, Vector3.ZERO, surface))
	out.append(P(role, CY, Vector3(top_r, length, bottom_r),
		Vector3(0.0, -length * 0.5, 0.0), color, tinted, shift, false, false,
		Vector3.ZERO, surface))
	out.append(P(role, S, Vector3(bottom_r, 0.0, 0.0),
		Vector3(0.0, -length, 0.0), color, tinted, shift, false, false,
		Vector3.ZERO, surface))

## Humanoïde de base, mis à l'échelle. Toutes les classes en héritent : deux
## personnages qui ne partagent pas leur ossature ne se ressemblent jamais
## assez pour qu'on croie au même monde.
##
## Les proportions visent le registre sombre, pas le registre mignon : tête
## d'un huitième de la hauteur, épaules larges, jambes longues. Les volumes
## restent arrondis — un cône entre deux sphères plie sans trou et s'éclaire
## d'un dégradé, une boîte fait six aplats — mais rien n'est caricatural.
##
## Le visage est un creux d'ombre, jamais des yeux dessinés. C'est la
## convention du genre, et c'est aussi ce qui évite l'écueil du bonhomme
## rigolo : un heaume vide inquiète, deux gros yeux font sourire.
func humanoid(k: float, flesh: Color) -> SkinData:
	var skin: SkinData = SkinData.new()
	skin.neck = Vector3(0.0, 1.44 * k, 0.0)
	skin.shoulder = Vector3(0.33 * k, 1.32 * k, 0.0)
	skin.elbow_drop = 0.34 * k
	skin.hip = Vector3(0.17 * k, 0.86 * k, 0.0)
	skin.knee_drop = 0.42 * k
	skin.stride_degrees = 32.0
	skin.idle_bob = 0.018 * k

	var parts: Array[SkinPart] = []

	# Bassin et torse : deux ovoïdes qui se recouvrent, pas deux caisses
	# empilées. Le recouvrement est ce qui donne une taille.
	parts.append(P(R_STATIC, SkinPart.Shape.ELLIPSOID,
		Vector3(0.46, 0.38, 0.36) * k, Vector3(0, 0.88, 0) * k,
		Color.WHITE, true, -0.44, false, false, Vector3.ZERO, M_CLOTH))
	parts.append(P(R_STATIC, SkinPart.Shape.ELLIPSOID,
		Vector3(0.60, 0.68, 0.40) * k, Vector3(0, 1.20, 0) * k,
		Color.WHITE, true, -0.18, false, false, Vector3.ZERO, M_CLOTH))
	# Plastron : une plaque bombée, plus claire, qui accroche la lumière.
	parts.append(P(R_STATIC, SkinPart.Shape.ELLIPSOID,
		Vector3(0.44, 0.46, 0.40) * k, Vector3(0, 1.22, -0.05) * k,
		Color.WHITE, true, 0.10, false, false, Vector3.ZERO, M_METAL))
	# Ceinture et tassettes : trois plaques sur les hanches. C'est le détail
	# qui dit « armure » plutôt que « pyjama ».
	parts.append(P(R_STATIC, TO, Vector3(0.20, 0.0, 0.28) * k,
		Vector3(0, 0.94, 0) * k, LEATHER, false, 0.0, false, false,
		Vector3.ZERO, M_CLOTH))
	for plate: int in 3:
		var angle: float = -34.0 + 34.0 * float(plate)
		parts.append(P(R_STATIC, B, Vector3(0.19, 0.34, 0.06) * k,
			Vector3(sin(deg_to_rad(angle)) * 0.24, 0.76, -0.22) * k,
			Color.WHITE, true, -0.30, false, false,
			Vector3(6.0, angle, 0.0), M_METAL))
	# Col et gorgerin.
	parts.append(P(R_STATIC, CY, Vector3(0.11, 0.14, 0.13) * k,
		Vector3(0, 1.44, 0) * k, flesh, false, 0.0, false, false,
		Vector3.ZERO, M_PLAIN))
	parts.append(P(R_STATIC, TO, Vector3(0.13, 0.0, 0.21) * k,
		Vector3(0, 1.42, 0) * k, Color.WHITE, true, -0.36, false, false,
		Vector3.ZERO, M_METAL))

	# Tête : un ovoïde d'un huitième de la hauteur, mâchoire, et un creux
	# d'ombre à la place du visage.
	parts.append(P(R_HEAD, SkinPart.Shape.ELLIPSOID,
		Vector3(0.34, 0.39, 0.36) * k, Vector3(0, 0.20, 0) * k,
		flesh, false, 0.0, false, false, Vector3.ZERO, M_PLAIN))
	parts.append(P(R_HEAD, SkinPart.Shape.ELLIPSOID,
		Vector3(0.28, 0.16, 0.30) * k, Vector3(0, 0.09, -0.02) * k,
		flesh, false, 0.0, false, false, Vector3.ZERO, M_PLAIN))
	parts.append(P(R_HEAD, SkinPart.Shape.ELLIPSOID,
		Vector3(0.24, 0.11, 0.06) * k, Vector3(0, 0.22, -0.17) * k,
		Color(0.05, 0.05, 0.07), false, 0.0, false, false,
		Vector3.ZERO, M_PLAIN))

	# Bras : épaule, biceps conique, coude, avant-bras, main en moufle.
	for side: int in 2:
		var arm: int = R_AR if side == 0 else R_AL
		var fore: int = R_FR if side == 0 else R_FL
		limb(parts, arm, 0.105 * k, 0.078 * k, 0.34 * k, Color.WHITE, true, -0.26)
		limb(parts, fore, 0.078 * k, 0.064 * k, 0.30 * k, Color.WHITE, true, -0.36)
		# Brassard.
		parts.append(P(fore, TO, Vector3(0.075, 0.0, 0.115) * k,
			Vector3(0, -0.08, 0) * k, Color.WHITE, true, -0.10, false, false,
			Vector3.ZERO, M_METAL))
		parts.append(P(fore, SkinPart.Shape.ELLIPSOID,
			Vector3(0.13, 0.15, 0.13) * k, Vector3(0, -0.36, -0.01) * k,
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH))

	# Jambes : hanche, cuisse conique, genou, tibia, gros soulier.
	for side: int in 2:
		var thigh: int = R_TR if side == 0 else R_TL
		var shin: int = R_SR if side == 0 else R_SL
		limb(parts, thigh, 0.135 * k, 0.098 * k, 0.42 * k, Color.WHITE, true, -0.34)
		limb(parts, shin, 0.098 * k, 0.078 * k, 0.38 * k, Color.WHITE, true, -0.46)
		# Grève : une plaque sur le devant du tibia.
		parts.append(P(shin, SkinPart.Shape.ELLIPSOID,
			Vector3(0.13, 0.30, 0.13) * k, Vector3(0, -0.18, -0.03) * k,
			Color.WHITE, true, -0.16, false, false, Vector3.ZERO, M_METAL))
		parts.append(P(shin, SkinPart.Shape.ELLIPSOID,
			Vector3(0.16, 0.13, 0.31) * k, Vector3(0, -0.40, -0.05) * k,
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH))

	skin.parts = parts
	return skin

# ---------------------------------------------------------------------------
# Bâtons
# ---------------------------------------------------------------------------
#
# Un bâton se tient DROIT au repos, pas traîné par terre. Comme il est accroché
# à l'avant-bras, qui est lui-même incliné au repos, sa verticale n'est pas
# celle du monde : ces trois constantes font la conversion une fois pour
# toutes, plutôt que de laisser six pièces la refaire chacune de travers.

## Position de la main dans le repère de l'avant-bras.
const HAND: Vector3 = Vector3(0.0, -0.31, -0.01)
## Direction « verticale du monde » vue depuis l'avant-bras au repos, celui-ci
## étant incliné de ELBOW_REST_DEGREES (-18°).
const UP_IN_FOREARM: Vector3 = Vector3(0.0, 0.951, 0.309)
## Boîtes et tores ont tous leur axe long en Y : il suffit donc d'annuler
## l'inclinaison de l'avant-bras. Pendant un lancer le bras descend à -95° et
## le bâton part à l'horizontale avec lui, ce qui est le geste voulu.
const STAFF_PITCH: Vector3 = Vector3(18.0, 0.0, 0.0)

## Pièce posée sur un bâton tenu droit, à `distance` mètres au-dessus de la
## main. Le pommeau est donc à distance négative, l'orbe tout en haut.
func staff_part(shape: int, size: Vector3, distance: float, color: Color,
		surface: int = M_WOOD, weapon: bool = false,
		light: float = 0.0) -> SkinPart:
	return P(R_FR, shape, size, HAND + UP_IN_FOREARM * distance, color,
		false, 0.0, weapon, false, STAFF_PITCH, surface, light)

# ---------------------------------------------------------------------------
# Les six skins
# ---------------------------------------------------------------------------

func build_gardien() -> SkinData:
	var s: SkinData = humanoid(1.0, SKIN_TONE)
	s.id = &"gardien"
	s.stride_degrees = 29.0
	s.parts.append_array([
		# Heaume arrondi, à cimier et nasale. Un ovoïde posé sur la tête, pas
		# une caisse : un casque a une calotte.
		P(R_HEAD, SkinPart.Shape.ELLIPSOID, Vector3(0.47, 0.44, 0.47),
			Vector3(0, 0.30, 0), Color.WHITE, true, -0.16, false, false,
			Vector3.ZERO, M_METAL),
		P(R_HEAD, CY, Vector3(0.210, 0.086, 0.210), Vector3(0.000, 0.165, 0.000),
			STEEL, false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_HEAD, SkinPart.Shape.ELLIPSOID, Vector3(0.09, 0.26, 0.50),
			Vector3(0, 0.50, 0), Color.WHITE, true, 0.38, false, false,
			Vector3.ZERO, M_METAL),
		P(R_HEAD, B, Vector3(0.060, 0.206, 0.043), Vector3(0.000, 0.165, -0.180),
			STEEL, false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_HEAD, B, Vector3(0.258, 0.038, 0.026), Vector3(0.000, 0.243, -0.180),
			Color(1.0, 0.74, 0.36), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		# Spallières : deux calottes posées sur les épaules.
		P(R_AR, SkinPart.Shape.ELLIPSOID, Vector3(0.25, 0.19, 0.25),
			Vector3(0.03, 0.03, 0), Color.WHITE, true, 0.20, false, false,
			Vector3.ZERO, M_METAL),
		P(R_AL, SkinPart.Shape.ELLIPSOID, Vector3(0.25, 0.19, 0.25),
			Vector3(-0.03, 0.03, 0), Color.WHITE, true, 0.20, false, false,
			Vector3.ZERO, M_METAL),
		# Épée : poignée, pommeau rond, garde, lame, pointe.
		P(R_FR, CY, Vector3(0.045, 0.24, 0.045), Vector3(0, -0.36, -0.09),
			LEATHER, false, 0.0, false, false, Vector3(90, 0, 0), M_CLOTH),
		P(R_FR, S, Vector3(0.065, 0.0, 0.0), Vector3(0, -0.36, 0.04),
			GOLD, false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_FR, SkinPart.Shape.ELLIPSOID, Vector3(0.30, 0.09, 0.10),
			Vector3(0, -0.36, -0.22), GOLD, false, 0.0, false, false,
			Vector3.ZERO, M_METAL),
		P(R_FR, B, Vector3(0.115, 0.05, 1.00), Vector3(0, -0.36, -0.76),
			STEEL, false, 0.0, true, false, Vector3.ZERO, M_METAL),
		P(R_FR, PR, Vector3(0.115, 0.05, 0.24), Vector3(0, -0.36, -1.38),
			STEEL, false, 0.0, true, false, Vector3(-90, 0, 0), M_METAL),
		# Écu : un ovoïde aplati, sa bordure, son umbo, sa croix.
		P(R_FL, SkinPart.Shape.ELLIPSOID, Vector3(0.62, 0.82, 0.14),
			Vector3(-0.07, -0.26, -0.15), Color.WHITE, true, 0.08, false, false,
			Vector3.ZERO, M_WOOD),
		P(R_FL, TO, Vector3(0.26, 0.0, 0.33), Vector3(-0.07, -0.26, -0.21),
			IRON, false, 0.0, false, false, Vector3(90, 0, 0), M_METAL),
		P(R_FL, S, Vector3(0.11, 0.0, 0.0), Vector3(-0.07, -0.26, -0.22),
			IRON, false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_FL, B, Vector3(0.10, 0.64, 0.03), Vector3(-0.07, -0.26, -0.22),
			Color.WHITE, true, 0.45, false, false, Vector3.ZERO, M_CLOTH),
		P(R_FL, B, Vector3(0.44, 0.10, 0.03), Vector3(-0.07, -0.14, -0.22),
			Color.WHITE, true, 0.45, false, false, Vector3.ZERO, M_CLOTH),
		# Cape courte.
		P(R_STATIC, SkinPart.Shape.ELLIPSOID, Vector3(0.66, 0.80, 0.20),
			Vector3(0, 1.06, 0.22), Color.WHITE, true, -0.42, false, false,
			Vector3.ZERO, M_CLOTH),
	])
	return s

func build_mage() -> SkinData:
	var s: SkinData = humanoid(0.97, SKIN_TONE)
	s.id = &"mage"
	s.stride_degrees = 31.0
	s.parts.append_array([
		# Chapeau : bord large, cône mou, bandeau. Le cône est légèrement
		# penché — un chapeau parfaitement droit a l'air d'un cône, un chapeau
		# de travers a l'air d'un chapeau.
		P(R_HEAD, CY, Vector3(0.378, 0.043, 0.378), Vector3(0.000, 0.372, 0.000),
			Color.WHITE, true, -0.36, false, false, Vector3(0, 0, 5), M_CLOTH),
		P(R_HEAD, CO, Vector3(0.206, 0.464, 0.000), Vector3(0.026, 0.604, 0.000),
			Color.WHITE, true, -0.30, false, false, Vector3(0, 0, 8), M_CLOTH),
		P(R_HEAD, S, Vector3(0.043, 0.000, 0.000), Vector3(0.060, 0.844, 0.000),
			GOLD, false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_HEAD, CY, Vector3(0.210, 0.060, 0.210), Vector3(0.000, 0.397, 0.000),
			GOLD, false, 0.0, false, false, Vector3(0, 0, 5), M_METAL),
		# Barbe : deux ovoïdes, parce qu'un mage sans barbe n'est qu'un type
		# en robe.
		P(R_HEAD, SkinPart.Shape.ELLIPSOID, Vector3(0.26, 0.24, 0.22),
			Vector3(0, 0.10, -0.14), Color(0.86, 0.86, 0.88), false, 0.0,
			false, false, Vector3.ZERO, M_CLOTH),
		P(R_HEAD, SkinPart.Shape.ELLIPSOID, Vector3(0.16, 0.22, 0.16),
			Vector3(0, -0.03, -0.13), Color(0.86, 0.86, 0.88), false, 0.0,
			false, false, Vector3.ZERO, M_CLOTH),
		# Robe : jupe conique et son ourlet.
		P(R_STATIC, CY, Vector3(0.30, 0.66, 0.50), Vector3(0, 0.58, 0),
			Color.WHITE, true, -0.18, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, TO, Vector3(0.44, 0.0, 0.52), Vector3(0, 0.26, 0),
			Color.WHITE, true, -0.42, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.13, 0.74, 0.05), Vector3(0, 0.92, -0.21),
			GOLD, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, TO, Vector3(0.21, 0.0, 0.31), Vector3(0, 1.32, 0),
			Color.WHITE, true, -0.34, false, false, Vector3.ZERO, M_CLOTH),
		# Bâton tenu droit : pommeau, hampe, monture, orbe.
		staff_part(S, Vector3(0.055, 0.0, 0.0), -0.06, IRON, M_METAL),
		staff_part(CY, Vector3(0.035, 1.50, 0.045), 0.44, WOOD, M_WOOD),
		staff_part(TO, Vector3(0.11, 0.0, 0.20), 1.16, GOLD, M_METAL, true),
		staff_part(S, Vector3(0.125, 0.0, 0.0), 1.16,
			Color(0.66, 0.40, 1.0), M_GLOW, false, 5.0),
	])
	return s

func build_soigneur() -> SkinData:
	var s: SkinData = humanoid(0.98, SKIN_TONE)
	s.id = &"soigneur"
	s.stride_degrees = 31.0
	s.parts.append_array([
		# Capuche : une calotte qui enveloppe la tête, sa pointe, sa retombée.
		P(R_HEAD, SkinPart.Shape.ELLIPSOID, Vector3(0.50, 0.50, 0.52),
			Vector3(0, 0.27, 0.03), Color.WHITE, true, -0.26, false, false,
			Vector3.ZERO, M_CLOTH),
		P(R_HEAD, CO, Vector3(0.146, 0.223, 0.000), Vector3(0.000, 0.423, 0.129),
			Color.WHITE, true, -0.26, false, false, Vector3(58, 0, 0), M_CLOTH),
		P(R_HEAD, SkinPart.Shape.ELLIPSOID, Vector3(0.42, 0.42, 0.20),
			Vector3(0, 0.10, 0.22), Color.WHITE, true, -0.34, false, false,
			Vector3.ZERO, M_CLOTH),
		# Ombre du visage sous la capuche : c'est elle qui rend un moine
		# inquiétant plutôt que douillet.
		P(R_HEAD, SkinPart.Shape.ELLIPSOID, Vector3(0.30, 0.26, 0.10),
			Vector3(0, 0.25, -0.20), Color(0.05, 0.05, 0.07), false, 0.0,
			false, false, Vector3.ZERO, M_PLAIN),
		# Robe, étole, croix pectorale.
		P(R_STATIC, CY, Vector3(0.29, 0.64, 0.48), Vector3(0, 0.58, 0),
			Color.WHITE, true, -0.15, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, TO, Vector3(0.42, 0.0, 0.50), Vector3(0, 0.26, 0),
			Color.WHITE, true, -0.40, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, TO, Vector3(0.22, 0.0, 0.34), Vector3(0, 1.30, 0),
			Color(0.90, 0.84, 0.60), false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.10, 0.68, 0.04), Vector3(0.14, 0.98, -0.20),
			Color(0.90, 0.84, 0.60), false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.10, 0.68, 0.04), Vector3(-0.14, 0.98, -0.20),
			Color(0.90, 0.84, 0.60), false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.07, 0.26, 0.03), Vector3(0, 1.14, -0.21),
			Color(1.0, 0.94, 0.60), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		P(R_STATIC, B, Vector3(0.19, 0.07, 0.03), Vector3(0, 1.20, -0.21),
			Color(1.0, 0.94, 0.60), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		# Sceptre.
		staff_part(S, Vector3(0.05, 0.0, 0.0), -0.06, IRON, M_METAL),
		staff_part(CY, Vector3(0.032, 1.20, 0.042), 0.36, WOOD, M_WOOD),
		staff_part(TO, Vector3(0.115, 0.0, 0.21), 0.94, GOLD, M_METAL, true),
		staff_part(S, Vector3(0.125, 0.0, 0.0), 0.94,
			Color(0.36, 1.0, 0.54), M_GLOW, false, 5.0),
	])
	return s

func build_archer() -> SkinData:
	var s: SkinData = humanoid(0.96, SKIN_TONE)
	s.id = &"archer"
	s.stride_degrees = 37.0
	s.parts.append_array([
		# Capuche courte à visière, foulard sur le bas du visage.
		P(R_HEAD, SkinPart.Shape.ELLIPSOID, Vector3(0.48, 0.40, 0.48),
			Vector3(0, 0.32, 0.02), Color.WHITE, true, -0.30, false, false,
			Vector3.ZERO, M_CLOTH),
		P(R_HEAD, SkinPart.Shape.ELLIPSOID, Vector3(0.42, 0.08, 0.30),
			Vector3(0, 0.31, -0.20), Color.WHITE, true, -0.42, false, false,
			Vector3(16, 0, 0), M_CLOTH),
		P(R_HEAD, SkinPart.Shape.ELLIPSOID, Vector3(0.36, 0.20, 0.34),
			Vector3(0, 0.08, -0.03), Color.WHITE, true, -0.46, false, false,
			Vector3.ZERO, M_CLOTH),
		# Carquois et flèches.
		P(R_STATIC, CY, Vector3(0.09, 0.48, 0.11), Vector3(0.18, 1.16, 0.20),
			LEATHER, false, 0.0, false, false, Vector3(-22, 0, 12), M_CLOTH),
		P(R_STATIC, CY, Vector3(0.012, 0.36, 0.012), Vector3(0.21, 1.48, 0.25),
			Color(0.82, 0.78, 0.66), false, 0.0, false, false, Vector3(-22, 0, 12), M_WOOD),
		P(R_STATIC, CY, Vector3(0.012, 0.36, 0.012), Vector3(0.15, 1.48, 0.23),
			Color(0.82, 0.78, 0.66), false, 0.0, false, false, Vector3(-22, 0, 12), M_WOOD),
		P(R_STATIC, CY, Vector3(0.012, 0.36, 0.012), Vector3(0.24, 1.47, 0.19),
			Color(0.82, 0.78, 0.66), false, 0.0, false, false, Vector3(-22, 0, 12), M_WOOD),
		# Baudrier, ceinture, bourse.
		P(R_STATIC, TO, Vector3(0.24, 0.0, 0.34), Vector3(0, 0.92, 0),
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.09, 0.54, 0.05), Vector3(0.07, 1.16, -0.19),
			LEATHER, false, 0.0, false, false, Vector3(0, 0, 22), M_CLOTH),
		P(R_STATIC, SkinPart.Shape.ELLIPSOID, Vector3(0.17, 0.19, 0.13),
			Vector3(-0.24, 0.86, 0.04), LEATHER, false, 0.0, false, false,
			Vector3.ZERO, M_CLOTH),
		# Arc et corde.
		P(R_FR, TO, Vector3(0.30, 0.0, 0.355), Vector3(0, -0.40, -0.13),
			WOOD, false, 0.0, true, false, Vector3(0, 0, 90), M_WOOD),
		P(R_FR, CY, Vector3(0.008, 0.66, 0.008), Vector3(0, -0.40, -0.10),
			Color(0.88, 0.86, 0.78), false, 0.0, true, false, Vector3(0, 0, 90), M_CLOTH),
		P(R_FR, CY, Vector3(0.035, 0.16, 0.035), Vector3(0, -0.40, -0.13),
			LEATHER, false, 0.0, false, false, Vector3(0, 0, 90), M_CLOTH),
	])
	return s

func build_gobelin() -> SkinData:
	var s: SkinData = humanoid(0.70, Color(0.44, 0.60, 0.34))
	s.id = &"gobelin"
	# Court et rapide : la foulée est plus ample que celle d'un homme, sinon un
	# gobelin qui court a l'air de glisser.
	s.stride_degrees = 46.0
	s.idle_bob = 0.032
	var hide: Color = Color(0.42, 0.56, 0.32)
	s.parts.append_array([
		# Grandes oreilles en pointe : c'est la silhouette qui doit dire
		# « gobelin » à vingt mètres, pas la couleur.
		P(R_HEAD, CO, Vector3(0.060, 0.258, 0.000), Vector3(0.164, 0.251, 0.017),
			hide, false, 0.0, false, false, Vector3(0, 0, -62), M_PLAIN),
		P(R_HEAD, CO, Vector3(0.060, 0.258, 0.000), Vector3(-0.164, 0.251, 0.017),
			hide, false, 0.0, false, false, Vector3(0, 0, 62), M_PLAIN),
		# Museau, crocs, yeux jaunes qui luisent dans le noir.
		P(R_HEAD, SkinPart.Shape.ELLIPSOID, Vector3(0.19, 0.15, 0.17),
			Vector3(0, 0.14, -0.21), hide, false, 0.0, false, false,
			Vector3.ZERO, M_PLAIN),
		P(R_HEAD, CO, Vector3(0.021, 0.068, 0.000), Vector3(0.043, 0.071, -0.189),
			Color(0.92, 0.90, 0.80), false, 0.0, false, false, Vector3(180, 0, 0), M_PLAIN),
		P(R_HEAD, CO, Vector3(0.021, 0.068, 0.000), Vector3(-0.043, 0.071, -0.189),
			Color(0.92, 0.90, 0.80), false, 0.0, false, false, Vector3(180, 0, 0), M_PLAIN),
		P(R_HEAD, S, Vector3(0.028, 0.000, 0.000), Vector3(0.060, 0.235, -0.137),
			Color(1.0, 0.86, 0.20), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		P(R_HEAD, S, Vector3(0.028, 0.000, 0.000), Vector3(-0.060, 0.235, -0.137),
			Color(1.0, 0.86, 0.20), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		# Pagne de peau, bandage au bras.
		P(R_STATIC, CY, Vector3(0.30, 0.28, 0.34), Vector3(0, 0.54, 0),
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, SkinPart.Shape.ELLIPSOID, Vector3(0.40, 0.20, 0.32),
			Vector3(0, 0.86, 0), LEATHER, false, 0.0, false, false,
			Vector3(0, 0, 9), M_CLOTH),
		P(R_FL, CY, Vector3(0.10, 0.14, 0.10), Vector3(0, -0.14, 0),
			Color(0.74, 0.72, 0.62), false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		# Couperet ébréché.
		P(R_FR, CY, Vector3(0.035, 0.18, 0.04), Vector3(0, -0.26, -0.06),
			LEATHER, false, 0.0, false, false, Vector3(90, 0, 0), M_CLOTH),
		P(R_FR, B, Vector3(0.15, 0.035, 0.46), Vector3(0, -0.26, -0.36),
			Color(0.58, 0.56, 0.52), false, 0.0, true, false, Vector3.ZERO, M_METAL),
		P(R_FR, PR, Vector3(0.15, 0.035, 0.16), Vector3(0, -0.26, -0.65),
			Color(0.58, 0.56, 0.52), false, 0.0, true, false, Vector3(-90, 0, 0), M_METAL),
	])
	return s

## Mannequin d'entraînement : bois, paille et corde. Pas de tête, pas d'yeux —
## il ne doit ressembler à personne, sinon on hésite à le frapper.
func build_mannequin() -> SkinData:
	var skin: SkinData = SkinData.new()
	skin.id = &"mannequin"
	skin.neck = Vector3(0.0, 1.40, 0.0)
	skin.shoulder = Vector3(0.30, 1.24, 0.0)
	skin.elbow_drop = 0.30
	skin.hip = Vector3(0.14, 0.90, 0.0)
	skin.knee_drop = 0.34
	# Il ne marche pas : foulée nulle, mais il oscille quand on le frappe.
	skin.stride_degrees = 6.0
	skin.idle_bob = 0.004
	var straw: Color = Color(0.72, 0.58, 0.28)
	skin.parts = [
		# Socle et mât.
		D(CY, Vector3(0.46, 0.16, 0.52), Vector3(0, 0.08, 0), STONE, M_STONE),
		D(CY, Vector3(0.09, 1.00, 0.11), Vector3(0, 0.58, 0), WOOD, M_WOOD),
		# Corps de paille sanglé.
		D(SkinPart.Shape.ELLIPSOID, Vector3(0.54, 0.72, 0.44),
			Vector3(0, 1.20, 0), straw, M_CLOTH),
		D(TO, Vector3(0.22, 0.0, 0.30), Vector3(0, 1.34, 0), LEATHER, M_CLOTH),
		D(TO, Vector3(0.20, 0.0, 0.28), Vector3(0, 1.06, 0), LEATHER, M_CLOTH),
		# Traverse : les deux bras du pantin, en une seule pièce.
		D(CY, Vector3(0.055, 1.30, 0.055), Vector3(0, 1.42, 0), WOOD, M_WOOD,
			Vector3(0, 0, 90)),
		D(SkinPart.Shape.ELLIPSOID, Vector3(0.22, 0.22, 0.22),
			Vector3(0.62, 1.42, 0), straw, M_CLOTH),
		D(SkinPart.Shape.ELLIPSOID, Vector3(0.22, 0.22, 0.22),
			Vector3(-0.62, 1.42, 0), straw, M_CLOTH),
		# Chapeau de paille, et la cible peinte au centre du torse.
		D(CO, Vector3(0.30, 0.30, 0.0), Vector3(0, 1.68, 0), straw, M_CLOTH),
		D(CY, Vector3(0.17, 0.03, 0.17), Vector3(0, 1.24, -0.21),
			Color(0.72, 0.22, 0.20), M_CLOTH, Vector3(90, 0, 0)),
		D(CY, Vector3(0.09, 0.035, 0.09), Vector3(0, 1.24, -0.22),
			Color(0.94, 0.90, 0.84), M_CLOTH, Vector3(90, 0, 0)),
		D(CY, Vector3(0.035, 0.04, 0.035), Vector3(0, 1.24, -0.23),
			Color(0.72, 0.22, 0.20), M_CLOTH, Vector3(90, 0, 0)),
	]
	return skin

func build_warden() -> SkinData:
	var s: SkinData = humanoid(1.30, Color(0.26, 0.22, 0.26))
	s.id = &"warden"
	# Lourd : foulée courte, buste presque immobile à l'arrêt. Un boss qui
	# gigote n'inspire rien.
	s.stride_degrees = 25.0
	s.idle_bob = 0.016
	var bone: Color = Color(0.78, 0.74, 0.60)
	s.parts.append_array([
		# Grand heaume clos, cornes, fente braise.
		P(R_HEAD, SkinPart.Shape.ELLIPSOID, Vector3(0.58, 0.60, 0.58),
			Vector3(0, 0.28, 0), Color(0.21, 0.20, 0.24), false, 0.0, false,
			false, Vector3.ZERO, M_METAL),
		P(R_HEAD, CY, Vector3(0.266, 0.086, 0.266), Vector3(0.000, 0.132, 0.000),
			Color(0.29, 0.27, 0.31), false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_HEAD, CO, Vector3(0.073, 0.464, 0.000), Vector3(0.223, 0.423, 0.026),
			bone, false, 0.0, false, false, Vector3(0, 0, 40), M_PLAIN),
		P(R_HEAD, CO, Vector3(0.073, 0.464, 0.000), Vector3(-0.223, 0.423, 0.026),
			bone, false, 0.0, false, false, Vector3(0, 0, -40), M_PLAIN),
		P(R_HEAD, B, Vector3(0.258, 0.038, 0.026), Vector3(0.000, 0.235, -0.249),
			Color(1.0, 0.36, 0.16), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		P(R_HEAD, B, Vector3(0.051, 0.240, 0.051), Vector3(0.000, 0.165, -0.240),
			Color(0.29, 0.27, 0.31), false, 0.0, false, false, Vector3.ZERO, M_METAL),
		# Spallières à pointe.
		P(R_AR, SkinPart.Shape.ELLIPSOID, Vector3(0.31, 0.23, 0.31),
			Vector3(0.04, 0.03, 0), Color.WHITE, true, 0.12, false, false,
			Vector3.ZERO, M_METAL),
		P(R_AL, SkinPart.Shape.ELLIPSOID, Vector3(0.31, 0.23, 0.31),
			Vector3(-0.04, 0.03, 0), Color.WHITE, true, 0.12, false, false,
			Vector3.ZERO, M_METAL),
		P(R_AR, CO, Vector3(0.08, 0.26, 0.0), Vector3(0.13, 0.09, 0),
			bone, false, 0.0, false, false, Vector3(0, 0, 56), M_PLAIN),
		P(R_AL, CO, Vector3(0.08, 0.26, 0.0), Vector3(-0.13, 0.09, 0),
			bone, false, 0.0, false, false, Vector3(0, 0, -56), M_PLAIN),
		# Cape lourde et son collet.
		P(R_STATIC, SkinPart.Shape.ELLIPSOID, Vector3(0.88, 1.30, 0.26),
			Vector3(0, 1.02, 0.26), Color.WHITE, true, -0.48, false, false,
			Vector3.ZERO, M_CLOTH),
		P(R_STATIC, TO, Vector3(0.30, 0.0, 0.48), Vector3(0, 1.52, 0.05),
			Color.WHITE, true, -0.30, false, false, Vector3.ZERO, M_CLOTH),
		# Braise du cœur : elle dit qu'il n'est pas humain.
		P(R_STATIC, S, Vector3(0.10, 0.0, 0.0), Vector3(0, 1.18, -0.22),
			Color(1.0, 0.34, 0.12), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		# Espadon.
		P(R_FR, CY, Vector3(0.05, 0.42, 0.055), Vector3(0, -0.44, -0.16),
			LEATHER, false, 0.0, false, false, Vector3(90, 0, 0), M_CLOTH),
		P(R_FR, S, Vector3(0.075, 0.0, 0.0), Vector3(0, -0.44, 0.07),
			Color(0.44, 0.40, 0.36), false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_FR, SkinPart.Shape.ELLIPSOID, Vector3(0.52, 0.11, 0.13),
			Vector3(0, -0.44, -0.39), Color(0.44, 0.40, 0.36), false, 0.0,
			false, false, Vector3.ZERO, M_METAL),
		P(R_FR, B, Vector3(0.18, 0.055, 1.66), Vector3(0, -0.44, -1.26),
			Color(0.68, 0.66, 0.64), false, 0.0, true, false, Vector3.ZERO, M_METAL),
		P(R_FR, B, Vector3(0.035, 0.045, 1.10), Vector3(0, -0.44, -1.10),
			Color(1.0, 0.42, 0.18), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		P(R_FR, PR, Vector3(0.18, 0.055, 0.32), Vector3(0, -0.44, -2.25),
			Color(0.68, 0.66, 0.64), false, 0.0, true, false, Vector3(-90, 0, 0), M_METAL),
	])
	return s

# ---------------------------------------------------------------------------
# Le niveau : les Salines de Marn
# ---------------------------------------------------------------------------
#
# Le niveau precedent tenait dans soixante metres sur quatre-vingts, entierement
# couvert : une nef, un boyau de six metres de large, une arene. On y etait a
# l'etroit partout, et on ne voyait jamais le ciel.
#
# Celui-ci fait 68 x 184 metres et la MOITIE est a ciel ouvert. Le parcours
# alterne : on sort d'une halle sombre sur un parvis eblouissant, on s'engage
# sur une digue etroite entre deux bassins vides, on debouche sur les tables
# d'evaporation — la plus grande surface du jeu, sans un toit ni un mur — puis
# on rentre sous l'arene du boss. C'est ce rythme qui fait qu'un espace parait
# grand : pas sa surface, mais le fait qu'il se resserre et s'ouvre.

## Couverts.
const HALLE: Rect2 = Rect2(-15, -34, 30, 36)
const BASSIN: Rect2 = Rect2(-10, 2, 20, 7)
const SEUIL: Rect2 = Rect2(-8, 104, 16, 8)
const ARENE: Rect2 = Rect2(-25, 112, 50, 38)
## A ciel ouvert.
const PARVIS: Rect2 = Rect2(-26, 9, 52, 27)
const DIGUE: Rect2 = Rect2(-7, 36, 14, 26)
const TABLES: Rect2 = Rect2(-30, 62, 54, 42)
const RACCOURCI: Rect2 = Rect2(26, 9, 7, 109)
const PASSAGE: Rect2 = Rect2(24, 112, 4, 6)

const H_HALLE: float = 15.5
const H_BASSIN: float = 7.0
const H_SEUIL: float = 6.0
const H_ARENE: float = 12.0

## Membrures de la halle : deux rangs, comme les cotes d'une coque retournee.
const MEMBRURES_X: Array = [-10.5, 10.5]
const MEMBRURES_Z: Array = [-30.0, -25.0, -20.0, -15.0, -10.0, -5.0]

## Cuve a saumure du fond : c'est l'autel de ce monde, et elle bloque.
const CUVE_BASSIN: Rect2 = Rect2(-8.8, 4.6, 4.0, 2.2)

## Murets des tables d'evaporation. Ce sont eux qui donnent leur forme aux
## bassins : une grille de vasques separees par des levees de sel, avec des
## PASSAGES menages — une grille pleine serait une prison, pas un paysage.
const LEVEE: float = 0.9
const MURET_H: float = 0.55

func levees() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for x: float in [-17.0, -4.0, 9.0]:
		out.append(Rect2(x, 63.0, LEVEE, 15.0))
		out.append(Rect2(x, 82.0, LEVEE, 20.0))
	for z: float in [75.0, 91.0]:
		out.append(Rect2(-29.0, z, 10.0, LEVEE))
		out.append(Rect2(-14.0, z, 18.0, LEVEE))
		out.append(Rect2(11.0, z, 12.0, LEVEE))
	return out

## Piles de sel taille, sur le parvis. Elles bloquent : c'est la seule
## couverture de toute la zone ouverte, et sans elles un archer y regne.
func piles() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for at: Vector2 in [Vector2(-19.0, 16.0), Vector2(15.0, 14.0),
			Vector2(-11.0, 28.0), Vector2(19.0, 27.0), Vector2(6.0, 21.0)]:
		out.append(Rect2(at.x - 1.4, at.y - 1.1, 2.8, 2.2))
	return out

## Futs de colonne brises, autour de l'arene. Le boss tourne autour.
func futs() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for at: Vector2 in [Vector2(-17.0, 120.0), Vector2(17.0, 120.0),
			Vector2(-19.0, 133.0), Vector2(19.0, 133.0),
			Vector2(-13.0, 145.0), Vector2(13.0, 145.0)]:
		out.append(Rect2(at.x - 1.1, at.y - 1.1, 2.2, 2.2))
	return out

## Hauteur de chacune des masses de `encombres`, dans le meme ordre. Elle sert
## deux fois — a la simulation, pour la hauteur declaree de l'obstacle, et au
## decor, pour le bloc qui l'habille — et les deux DOIVENT s'accorder : un
## eboulement dessine plus bas que ce qui arrete est un decor qui ment.
const ENCOMBRE_H: Array[float] = [1.75, 2.15, 1.65, 1.35]

## Ce qui encombre le raccourci.
##
## Cent-neuf metres de ligne droite se parcouraient sans que le pouce quitte
## l'avant : c'etait le seul endroit du jeu ou l'on ne decidait de rien. Quatre
## masses en travers, alternees d'un bord a l'autre, et le couloir se traverse
## desormais en zigzag — a deux joueurs, on n'y passe plus de front partout.
##
## Elles bloquent VRAIMENT : elles sont declarees a la simulation, pas
## seulement dessinees. Un eboulement qu'on traverse ne rythme rien du tout.
func encombres() -> Array[Rect2]:
	var out: Array[Rect2] = []
	# Une pile de l'arcade, tombee du cote est.
	out.append(Rect2(29.4, 25.0, 3.6, 1.6))
	# La voute effondree : deux blocs decales, qui obligent a changer de bord
	# deux fois de suite. C'est le seul vrai passage etroit du raccourci.
	out.append(Rect2(26.2, 57.0, 3.4, 2.6))
	out.append(Rect2(30.6, 61.5, 2.4, 2.2))
	# Un bloc de sel taille, abandonne la ou on le chargeait.
	out.append(Rect2(27.8, 92.0, 3.4, 1.8))
	return out

func build_level() -> LevelData:
	var level: LevelData = LevelData.new()
	level.id = &"salines"
	level.walkable = [HALLE, BASSIN, PARVIS, DIGUE, TABLES, SEUIL, ARENE,
		RACCOURCI, PASSAGE]
	level.ceiling_heights = [H_HALLE, H_BASSIN, 0.0, 0.0, 0.0, H_SEUIL,
		H_ARENE, 0.0, 0.0]
	level.open_sky = [false, false, true, true, true, false, false, true, true]
	level.default_ceiling = 6.0

	var solides: Array[Rect2] = []
	var hauteurs: Array[float] = []
	for x: float in MEMBRURES_X:
		for z: float in MEMBRURES_Z:
			solides.append(Rect2(x - 0.7, z - 0.7, 1.4, 1.4))
			hauteurs.append(0.0)
	for f: Rect2 in futs():
		solides.append(f)
		hauteurs.append(0.0)
	solides.append(CUVE_BASSIN)
	hauteurs.append(1.45)
	for muret: Rect2 in levees():
		solides.append(muret)
		hauteurs.append(MURET_H)
	for pile: Rect2 in piles():
		solides.append(pile)
		hauteurs.append(1.75)
	var genes: Array[Rect2] = encombres()
	for index: int in genes.size():
		solides.append(genes[index])
		hauteurs.append(ENCOMBRE_H[index])
	level.obstacles = solides
	level.obstacle_heights = hauteurs

	level.shortcut_gate = PASSAGE
	level.bonfire_position = Vector2(0.0, 4.0)
	level.bonfire_radius = 3.5
	level.shortcut_switch_position = Vector2(21.0, 116.0)
	level.shortcut_switch_radius = 2.5
	level.player_spawns = [
		Vector2(-2.2, -30.0), Vector2(2.2, -30.0),
		Vector2(-2.2, -26.5), Vector2(2.2, -26.5),
	]
	# Six ennemis au lieu de trois : la surface a plus que double, et trois
	# gobelins perdus dedans ne rencontraient plus personne.
	level.enemy_spawns = [
		Vector2(-9.0, 19.0), Vector2(10.0, 27.0), Vector2(0.0, 46.0),
		Vector2(-15.0, 72.0), Vector2(11.0, 85.0), Vector2(-6.0, 97.0),
	]
	level.training_dummy_position = Vector2(6.0, -20.0)
	level.boss_spawn = Vector2(0.0, 136.0)
	return level

# ---------------------------------------------------------------------------
# Motifs de decor
# ---------------------------------------------------------------------------

## Membrure : un arc, mais lu comme une cote de coque retournee. C'est le motif
## qui fait la halle — sans lui, une salle haute n'est qu'un couloir haut.
func arch(out: Array[SkinPart], centre: Vector3, radius: float, depth: float,
		steps: int, thickness: float, tone: Color) -> void:
	for step: int in steps:
		var angle: float = PI * (float(step) + 0.5) / float(steps)
		var at: Vector3 = centre + Vector3(cos(angle) * radius,
			sin(angle) * radius, 0.0)
		var piece: SkinPart = D(SkinPart.Shape.BOX,
			Vector3(thickness, PI * radius / float(steps) * 1.14, depth),
			Vector3(at.x, at.y, centre.z), tone, SkinPart.Surface.WOOD)
		piece.rotation_degrees = Vector3(0.0, 0.0, rad_to_deg(angle) - 90.0)
		out.append(piece)

## Lampe a huile murale. La seule chose chaude d'un monde blanc, donc la seule
## qu'on regarde : elle sert de balise autant que d'eclairage.
func torch(out: Array[SkinPart], at: Vector3, into: Vector3, reach: float) -> void:
	var bras: SkinPart = D(SkinPart.Shape.BOX, Vector3(0.09, 0.09, 0.46),
		at + into * 0.23, IRON, SkinPart.Surface.METAL)
	bras.rotation_degrees = Vector3(0.0, rad_to_deg(atan2(into.x, into.z)), 0.0)
	out.append(bras)
	out.append(D(SkinPart.Shape.CYLINDER, Vector3(0.19, 0.16, 0.13),
		at + into * 0.46, IRON, SkinPart.Surface.METAL))
	var flamme: SkinPart = D(SkinPart.Shape.CONE, Vector3(0.13, 0.34, 0.0),
		at + into * 0.46 + Vector3(0.0, 0.20, 0.0), FLAME, SkinPart.Surface.GLOW)
	flamme.light_range = reach
	out.append(flamme)

## Ratelier de lampes suspendu : il eclaire par en haut, ce que ne fait aucune
## lampe murale. `reach` est la portee de la lampe centrale, et elle doit
## depasser la hauteur de suspension : un ratelier accroche a huit metres avec
## une portee de cinq n'eclaire rien du tout, il se contente de briller. C'est
## exactement ce qui laissait l'arene dans le noir.
func chandelier(out: Array[SkinPart], at: Vector3, ceiling: float,
		reach: float = 16.0) -> void:
	out.append(D(SkinPart.Shape.CYLINDER, Vector3(0.05, ceiling - at.y, 0.05),
		Vector3(at.x, (at.y + ceiling) * 0.5, at.z), IRON,
		SkinPart.Surface.METAL))
	out.append(D(SkinPart.Shape.BOX, Vector3(1.7, 0.10, 0.10), at, IRON,
		SkinPart.Surface.METAL))
	# La lampe centrale porte la lumiere ; les quatre laterales ne sont que des
	# points brillants. Quatre omnis de longue portee au meme endroit coutent
	# quatre fois le prix d'une pour le meme resultat.
	var maitresse: SkinPart = D(SkinPart.Shape.ELLIPSOID,
		Vector3(0.24, 0.30, 0.24), Vector3(at.x, at.y - 0.36, at.z),
		CANDLE, SkinPart.Surface.GLOW)
	maitresse.light_range = reach
	out.append(maitresse)
	for index: int in 4:
		var x: float = at.x - 0.66 + float(index) * 0.44
		out.append(D(SkinPart.Shape.CYLINDER, Vector3(0.028, 0.22, 0.028),
			Vector3(x, at.y - 0.14, at.z), IRON, SkinPart.Surface.METAL))
		out.append(D(SkinPart.Shape.ELLIPSOID,
			Vector3(0.17, 0.22, 0.17), Vector3(x, at.y - 0.34, at.z),
			CANDLE, SkinPart.Surface.GLOW))

## Cuve a saumure : un bac cercle de fer. La halle en est pleine — c'est ce
## qu'on y fabriquait.
func cuve(out: Array[SkinPart], at: Vector3, rayon: float, hauteur: float) -> void:
	out.append(D(SkinPart.Shape.CYLINDER,
		Vector3(rayon, hauteur, rayon * 1.06),
		at + Vector3(0.0, hauteur * 0.5, 0.0), WOOD, SkinPart.Surface.WOOD))
	for cercle: int in 2:
		out.append(D(SkinPart.Shape.TORUS,
			Vector3(rayon * 0.96, 0.0, rayon * 1.10),
			at + Vector3(0.0, hauteur * (0.28 + float(cercle) * 0.45), 0.0),
			IRON, SkinPart.Surface.METAL))
	out.append(D(SkinPart.Shape.CYLINDER,
		Vector3(rayon * 0.92, 0.05, rayon * 0.92),
		at + Vector3(0.0, hauteur * 0.94, 0.0), BRINE.darkened(0.30),
		SkinPart.Surface.METAL))

## Tas de sel : un cone et deux plus petits. Le motif le plus repete du jeu,
## et celui qui dit le metier sans un mot.
func tas(out: Array[SkinPart], at: Vector3, rayon: float, hauteur: float) -> void:
	out.append(D(SkinPart.Shape.CONE, Vector3(rayon, hauteur, 0.0),
		at + Vector3(0.0, hauteur * 0.5, 0.0), SALT, SkinPart.Surface.STONE))
	out.append(D(SkinPart.Shape.CONE, Vector3(rayon * 0.52, hauteur * 0.55, 0.0),
		at + Vector3(rayon * 1.15, hauteur * 0.28, rayon * 0.35), SALT_DARK,
		SkinPart.Surface.STONE))
	out.append(D(SkinPart.Shape.CONE, Vector3(rayon * 0.38, hauteur * 0.40, 0.0),
		at + Vector3(-rayon * 0.95, hauteur * 0.20, -rayon * 0.55), SALT_DARK,
		SkinPart.Surface.STONE))

## Sechoir : quatre pieux et des lattes chargees de sel. De loin c'est une
## silhouette qu'on reconnait, et ca donne des reperes dans une etendue
## blanche ou tout se ressemble.
func sechoir(out: Array[SkinPart], at: Vector3, angle: float) -> void:
	var tourne: Vector3 = Vector3(0.0, angle, 0.0)
	var rot: float = deg_to_rad(angle)
	for cote: int in 4:
		var dx: float = -1.5 if cote % 2 == 0 else 1.5
		var dz: float = -0.55 if cote < 2 else 0.55
		out.append(D(SkinPart.Shape.CYLINDER, Vector3(0.075, 2.1, 0.085),
			at + Vector3(dx * cos(rot) - dz * sin(rot), 1.05,
				dx * sin(rot) + dz * cos(rot)), WOOD, SkinPart.Surface.WOOD))
	for latte: int in 3:
		var plateau: SkinPart = D(SkinPart.Shape.BOX, Vector3(3.4, 0.07, 0.30),
			at + Vector3(0.0, 1.05 + float(latte) * 0.42, 0.0), WOOD,
			SkinPart.Surface.WOOD)
		plateau.rotation_degrees = tourne
		out.append(plateau)
		var couche: SkinPart = D(SkinPart.Shape.BOX, Vector3(3.1, 0.11, 0.24),
			at + Vector3(0.0, 1.13 + float(latte) * 0.42, 0.0), SALT,
			SkinPart.Surface.STONE)
		couche.rotation_degrees = tourne
		out.append(couche)

## Bitte d'amarrage. Il n'y a plus de bateau a amarrer, et c'est exactement ce
## qu'elle raconte.
func bitte(out: Array[SkinPart], at: Vector3) -> void:
	out.append(D(SkinPart.Shape.CYLINDER, Vector3(0.26, 0.72, 0.32),
		at + Vector3(0.0, 0.36, 0.0), IRON, SkinPart.Surface.METAL))
	out.append(D(SkinPart.Shape.CYLINDER, Vector3(0.38, 0.14, 0.30),
		at + Vector3(0.0, 0.76, 0.0), IRON, SkinPart.Surface.METAL))
	out.append(D(SkinPart.Shape.TORUS, Vector3(0.30, 0.0, 0.42),
		at + Vector3(0.0, 0.20, 0.0), ROPE, SkinPart.Surface.CLOTH))

## Coque echouee : une quille et ses membrures, couchee sur le flanc. La piece
## qui dit « il y avait la mer » mieux que n'importe quelle inscription.
func coque(out: Array[SkinPart], at: Vector3, angle: float,
		longueur: float) -> void:
	var quille: SkinPart = D(SkinPart.Shape.BOX,
		Vector3(longueur, 0.45, 0.55), at + Vector3(0.0, 0.30, 0.0), WOOD,
		SkinPart.Surface.WOOD)
	quille.rotation_degrees = Vector3(0.0, angle, 4.0)
	out.append(quille)
	var cotes: int = int(longueur / 1.4)
	var rot: float = deg_to_rad(angle)
	for index: int in cotes:
		var t: float = (float(index) / float(maxi(1, cotes - 1)) - 0.5) * longueur
		var hauteur: float = 2.4 * (1.0 - pow(absf(t) / (longueur * 0.5), 2.0)) + 0.4
		var cote: SkinPart = D(SkinPart.Shape.BOX,
			Vector3(0.22, hauteur, 0.34),
			at + Vector3(t * cos(rot), hauteur * 0.5 + 0.2, t * sin(rot)),
			WOOD, SkinPart.Surface.WOOD)
		cote.rotation_degrees = Vector3(0.0, angle, 22.0)
		out.append(cote)

## Grue de quai : un mat, une fleche, un crochet. Elle penche.
func grue(out: Array[SkinPart], at: Vector3, angle: float) -> void:
	var mat: SkinPart = D(SkinPart.Shape.CYLINDER, Vector3(0.26, 6.4, 0.34),
		at + Vector3(0.0, 3.2, 0.0), WOOD, SkinPart.Surface.WOOD)
	mat.rotation_degrees = Vector3(0.0, 0.0, 5.0)
	out.append(mat)
	var rot: float = deg_to_rad(angle)
	var fleche: SkinPart = D(SkinPart.Shape.BOX, Vector3(5.6, 0.30, 0.34),
		at + Vector3(cos(rot) * 2.3, 5.9, sin(rot) * 2.3), WOOD,
		SkinPart.Surface.WOOD)
	fleche.rotation_degrees = Vector3(0.0, angle, -14.0)
	out.append(fleche)
	out.append(D(SkinPart.Shape.CYLINDER, Vector3(0.045, 3.2, 0.045),
		at + Vector3(cos(rot) * 4.7, 3.8, sin(rot) * 4.7), IRON,
		SkinPart.Surface.METAL))
	out.append(D(SkinPart.Shape.TORUS, Vector3(0.22, 0.0, 0.34),
		at + Vector3(cos(rot) * 4.7, 2.2, sin(rot) * 4.7), IRON,
		SkinPart.Surface.METAL))

## Gravats : des blocs de croute cassee. Ils ne bloquent pas, ils salissent.
func rubble(out: Array[SkinPart], at: Vector3, spread: float) -> void:
	var blocs: Array[String] = ["donjon/Rock1", "donjon/Rock2", "donjon/Rock3",
		"donjon/Rock4", "donjon/Rock5"]
	for index: int in blocs.size():
		var angle: float = TAU * float(index) / float(blocs.size()) + at.x
		out.append(M(blocs[index],
			at + Vector3(cos(angle) * spread, 0.0, sin(angle) * spread),
			0.62 + float(index % 3) * 0.34, rad_to_deg(angle) * 0.7))

## Panneau de verre de saumure : ce qui remplace le vitrail. Vert pale, il
## brille de lui-meme parce que dehors il fait plus clair que dedans.
func window(out: Array[SkinPart], at: Vector3, facing: float, tone: Color,
		largeur: float, hauteur: float) -> void:
	var cadre: SkinPart = D(SkinPart.Shape.BOX,
		Vector3(largeur + 0.30, hauteur + 0.30, 0.22), at, STONE_PALE,
		SkinPart.Surface.STONE)
	cadre.rotation_degrees = Vector3(0.0, facing, 0.0)
	out.append(cadre)
	var vitre: SkinPart = D(SkinPart.Shape.BOX,
		Vector3(largeur, hauteur, 0.10), at, tone, SkinPart.Surface.GLOW)
	vitre.rotation_degrees = Vector3(0.0, facing, 0.0)
	vitre.light_range = 3.4
	out.append(vitre)
	for barreau: int in 2:
		var barre: SkinPart = D(SkinPart.Shape.BOX,
			Vector3(largeur + 0.10, 0.07, 0.16),
			at + Vector3(0.0, -hauteur * 0.25 + float(barreau) * hauteur * 0.5,
				0.0), IRON, SkinPart.Surface.METAL)
		barre.rotation_degrees = Vector3(0.0, facing, 0.0)
		out.append(barre)

## Borne de saunier : un pieu et une plaque gravee. Elles jalonnent les tables,
## et ce sont elles qui empechent de se perdre dans le blanc.
func borne(out: Array[SkinPart], at: Vector3) -> void:
	out.append(D(SkinPart.Shape.CYLINDER, Vector3(0.09, 1.9, 0.10),
		at + Vector3(0.0, 0.95, 0.0), WOOD, SkinPart.Surface.WOOD))
	out.append(D(SkinPart.Shape.BOX, Vector3(0.52, 0.34, 0.06),
		at + Vector3(0.0, 1.75, 0.0), SALT, SkinPart.Surface.STONE))

# ---------------------------------------------------------------------------
# Le decor, zone par zone
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Exterieurs
# ---------------------------------------------------------------------------
#
# La coque du niveau ne fabrique que des murs droits : une zone fermee vue du
# dehors est une boite grise a trou noir, et c'est exactement ce qu'on voyait
# depuis le parvis en regardant la halle. Un batiment se lit d'abord a sa
# SILHOUETTE — un toit, une corniche, des contreforts — et rien de tout ca ne
# peut sortir d'un algorithme de murs.
#
# Ces pieces sont du decor : elles ne bloquent rien et ne sont jamais dans le
# champ de la collision, qui reste le rectangle praticable.

## Toit a deux pentes, faîtage dans le sens de la longueur.
##
## C'est la piece qui transforme une boite en batiment. Les deux pans debordent
## des murs : une couverture qui s'arrete pile au nu du mur ne se lit pas comme
## un toit, elle se lit comme un couvercle.
func toiture(out: Array[SkinPart], plan: Rect2, mur: float, montee: float,
		teinte: Color) -> void:
	var cx: float = plan.position.x + plan.size.x * 0.5
	var cz: float = plan.position.y + plan.size.y * 0.5
	var demi: float = plan.size.x * 0.5 + 1.2
	var pente: float = sqrt(demi * demi + montee * montee)
	var angle: float = rad_to_deg(atan2(montee, demi))
	for cote: float in [-1.0, 1.0]:
		var pan: SkinPart = D(B,
			Vector3(pente, 0.34, plan.size.y + 2.4),
			Vector3(cx + cote * demi * 0.5, mur + montee * 0.5, cz),
			teinte, M_WOOD)
		# Le signe compte : une rotation POSITIVE autour de Z leve l'extremite
		# +X. Avec `cote * angle`, les deux pans montaient vers l'exterieur et
		# le toit etait un V — deux ailes en travers du ciel au lieu d'une
		# couverture.
		pan.rotation_degrees = Vector3(0.0, 0.0, -cote * angle)
		out.append(pan)
	# Faîtiere : la ligne sombre au sommet, qui donne son arete au toit.
	out.append(D(B, Vector3(0.55, 0.42, plan.size.y + 2.6),
		Vector3(cx, mur + montee + 0.12, cz), teinte.darkened(0.35), M_WOOD))
	# Pignons : les deux triangles qui bouchent les extremites. Sans eux on
	# voit sous le toit depuis les bouts.
	for bout: float in [-1.0, 1.0]:
		var pignon: SkinPart = D(PR,
			Vector3(plan.size.x + 2.4, montee, 0.5),
			Vector3(cx, mur + montee * 0.5,
				cz + bout * (plan.size.y * 0.5 + 0.9)),
			teinte.darkened(0.18), M_STONE)
		out.append(pignon)

## Corniche : un bandeau qui deborde tout autour, au sommet des murs.
func corniche(out: Array[SkinPart], plan: Rect2, hauteur: float,
		teinte: Color) -> void:
	var cx: float = plan.position.x + plan.size.x * 0.5
	var cz: float = plan.position.y + plan.size.y * 0.5
	for cote: float in [-1.0, 1.0]:
		out.append(D(B, Vector3(0.9, 0.7, plan.size.y + 1.8),
			Vector3(cx + cote * (plan.size.x * 0.5 + 0.2), hauteur - 0.35, cz),
			teinte, M_STONE))
		out.append(D(B, Vector3(plan.size.x + 1.8, 0.7, 0.9),
			Vector3(cx, hauteur - 0.35,
				cz + cote * (plan.size.y * 0.5 + 0.2)), teinte, M_STONE))

## Contreforts : des piles talutees plaquees contre un mur, tous les `pas`.
## Elles rythment une longueur nue et disent que le mur porte quelque chose.
func contreforts(out: Array[SkinPart], plan: Rect2, hauteur: float,
		pas: float, teinte: Color) -> void:
	var z: float = plan.position.y + pas * 0.5
	while z < plan.end.y:
		for cote: float in [-1.0, 1.0]:
			var x: float = plan.position.x if cote < 0.0 else plan.end.x
			out.append(D(B, Vector3(1.5, hauteur * 0.72, 1.3),
				Vector3(x + cote * 0.65, hauteur * 0.36, z), teinte, M_STONE))
			var talus: SkinPart = D(PR, Vector3(1.5, 1.6, 1.3),
				Vector3(x + cote * 0.65, hauteur * 0.72 + 0.8, z),
				teinte.darkened(0.12), M_STONE)
			talus.rotation_degrees = Vector3(0.0, 0.0, 0.0 if cote > 0.0 else 180.0)
			out.append(talus)
		z += pas

## Cheminee d'evaporation : ce que fabrique vraiment une saline, c'est de la
## vapeur. Trois d'entre elles sur un toit disent le metier de loin.
func cheminee(out: Array[SkinPart], at: Vector3, hauteur: float) -> void:
	out.append(D(B, Vector3(1.6, hauteur, 1.6),
		at + Vector3(0.0, hauteur * 0.5, 0.0), STONE_PALE, M_STONE))
	out.append(D(B, Vector3(2.1, 0.45, 2.1),
		at + Vector3(0.0, hauteur + 0.2, 0.0), STONE, M_STONE))
	for coin: int in 4:
		var angle: float = 45.0 + float(coin) * 90.0
		out.append(D(SkinPart.Shape.CYLINDER, Vector3(0.10, 1.2, 0.10),
			at + Vector3(sin(deg_to_rad(angle)) * 0.85, hauteur + 0.9,
				cos(deg_to_rad(angle)) * 0.85), IRON, M_METAL))
	out.append(D(B, Vector3(2.4, 0.3, 2.4),
		at + Vector3(0.0, hauteur + 1.5, 0.0), IRON, M_METAL))

## Colombage : un quadrillage de bois plaque sur un mur.
##
## Trente metres de mur nu ne se lisent pas comme un mur, ils se lisent comme
## une absence. Un pan de bois donne d'un seul coup une echelle — on compte les
## travees, donc on sait quelle taille fait le batiment — et une trame de
## lignes chaudes sur un aplat froid.
##
## `axe` vaut 0 pour un mur perpendiculaire a X (on avance en Z), 1 pour
## l'inverse. `dedans` est le sens dans lequel decaler le bois pour qu'il se
## plaque contre le mur sans y entrer.
func colombage(out: Array[SkinPart], depart: Vector3, longueur: float,
		hauteur: float, axe: int, dedans: float, travee: float = 4.5) -> void:
	var pas: float = longueur / maxf(1.0, floorf(longueur / travee))
	var t: float = 0.0
	var epaisseur: float = 0.26
	while t <= longueur + 0.01:
		var at: Vector3 = depart
		if axe == 0:
			at += Vector3(dedans * epaisseur * 0.5, 0.0, t)
		else:
			at += Vector3(t, 0.0, dedans * epaisseur * 0.5)
		# Poteau
		var taille: Vector3 = Vector3(epaisseur, hauteur, 0.42) if axe == 0 \
			else Vector3(0.42, hauteur, epaisseur)
		out.append(D(B, taille, at + Vector3(0.0, hauteur * 0.5, 0.0), WOOD,
			M_WOOD))
		t += pas
	# Sablieres : basse, mediane, haute. Ce sont elles qui font la trame.
	for niveau: float in [0.5, hauteur * 0.52, hauteur - 0.7]:
		var centre: Vector3 = depart + Vector3(0.0, niveau, 0.0)
		if axe == 0:
			centre += Vector3(dedans * epaisseur * 0.5, 0.0, longueur * 0.5)
			out.append(D(B, Vector3(epaisseur, 0.34, longueur), centre, WOOD,
				M_WOOD))
		else:
			centre += Vector3(longueur * 0.5, 0.0, dedans * epaisseur * 0.5)
			out.append(D(B, Vector3(longueur, 0.34, epaisseur), centre, WOOD,
				M_WOOD))

## Fenetre a volets : un encadrement, deux vantaux ouverts, un appui.
## L'interieur du tableau est presque noir — un trou de fenetre qui rend la
## meme valeur que le mur n'est pas une fenetre, c'est un rectangle peint.
func volets(out: Array[SkinPart], at: Vector3, largeur: float, hauteur: float,
		axe: int, dedans: float) -> void:
	var e: float = 0.30
	var cadre: Vector3 = Vector3(e, hauteur + 0.5, largeur + 0.5) if axe == 0 \
		else Vector3(largeur + 0.5, hauteur + 0.5, e)
	out.append(D(B, cadre, at + Vector3(dedans * 0.10, 0.0, 0.0) if axe == 0 \
		else at + Vector3(0.0, 0.0, dedans * 0.10), STONE_PALE, M_STONE))
	var trou: Vector3 = Vector3(e * 0.5, hauteur, largeur) if axe == 0 \
		else Vector3(largeur, hauteur, e * 0.5)
	out.append(D(B, trou, at + Vector3(dedans * 0.22, 0.0, 0.0) if axe == 0 \
		else at + Vector3(0.0, 0.0, dedans * 0.22), DARK, M_PLAIN))
	for cote: float in [-1.0, 1.0]:
		var pos: Vector3 = at
		var vantail: Vector3
		var tourne: Vector3
		if axe == 0:
			pos += Vector3(dedans * 0.42, 0.0, cote * (largeur * 0.5 + 0.28))
			vantail = Vector3(0.7, hauteur, largeur * 0.55)
			tourne = Vector3(0.0, cote * 26.0, 0.0)
		else:
			pos += Vector3(cote * (largeur * 0.5 + 0.28), 0.0, dedans * 0.42)
			vantail = Vector3(largeur * 0.55, hauteur, 0.7)
			tourne = Vector3(0.0, -cote * 26.0, 0.0)
		var v: SkinPart = D(B, vantail, pos, WOOD, M_WOOD)
		v.rotation_degrees = tourne
		out.append(v)

## Banniere : une toile pendue a une hampe. C'est la seule chose du niveau qui
## ait une couleur franche sur un grand format, et c'est ce qui accroche l'oeil
## sur une facade.
func banniere(out: Array[SkinPart], at: Vector3, largeur: float,
		chute: float, teinte: Color, axe: int) -> void:
	var hampe: Vector3 = Vector3(0.14, 0.14, largeur + 0.9) if axe == 0 \
		else Vector3(largeur + 0.9, 0.14, 0.14)
	out.append(D(B, hampe, at, IRON, M_METAL))
	var toile: Vector3 = Vector3(0.07, chute, largeur) if axe == 0 \
		else Vector3(largeur, chute, 0.07)
	out.append(D(B, toile, at + Vector3(0.0, -chute * 0.5 - 0.1, 0.0), teinte,
		SkinPart.Surface.CLOTH))
	# Pointe : deux triangles qui font l'ourlet en V.
	var pointe: SkinPart = D(PR, Vector3(largeur, chute * 0.22, 0.07) \
		if axe == 1 else Vector3(0.07, chute * 0.22, largeur),
		at + Vector3(0.0, -chute - 0.1 - chute * 0.11, 0.0),
		teinte.darkened(0.22), SkinPart.Surface.CLOTH)
	pointe.rotation_degrees = Vector3(0.0, 0.0, 180.0)
	out.append(pointe)

## Chaine pendue avec sa charge : un crochet, des sacs de sel. Elle occupe la
## hauteur, qui est la dimension la plus vide d'une halle.
func chaine(out: Array[SkinPart], at: Vector3, longueur: float,
		sacs: int) -> void:
	out.append(D(CY, Vector3(0.05, longueur, 0.05),
		at + Vector3(0.0, -longueur * 0.5, 0.0), IRON, M_METAL))
	out.append(D(TO, Vector3(0.10, 0.0, 0.17),
		at + Vector3(0.0, -longueur, 0.0), IRON, M_METAL))
	for index: int in sacs:
		var y: float = -longueur - 0.35 - float(index) * 0.62
		var r: float = 0.36 - float(index) * 0.04
		out.append(D(SkinPart.Shape.ELLIPSOID, Vector3(r, r * 0.85, r * 0.92),
			at + Vector3(0.0, y, 0.0), ROPE, SkinPart.Surface.CLOTH))
		out.append(D(TO, Vector3(0.10, 0.0, r * 0.55),
			at + Vector3(0.0, y + r * 0.72, 0.0), ROPE,
			SkinPart.Surface.CLOTH))

## Flaque de saumure : une nappe posee au sol, qui renvoie le ciel. C'est ce
## qui empeche trente metres de dallage d'etre trente metres de dallage.
## `miroir` : vrai dehors, faux dedans. Une nappe lisse ne renvoie que ce qui
## est au-dessus d'elle ; sous un toit, c'est un plafond sombre, et la flaque
## devient un trou noir a lisere clair — une bouche d'egout au milieu de la
## nef. Dedans, on la traite donc comme de la pierre MOUILLEE, pas comme un
## miroir.
func flaque(out: Array[SkinPart], at: Vector3, rayon: float,
		miroir: bool = true) -> void:
	# La flaque miroir etait peinte de la couleur propre de la saumure, presque
	# noire, en comptant sur le reflet pour l'eclairer. A trente pour cent de
	# rugosite le reflet est flou : elle rendait un trou noir sur le parvis.
	var teinte: Color = BRINE_WET.lightened(0.38) if miroir \
		else BRINE_WET.lightened(0.18)
	var matiere: int = SkinPart.Surface.LIQUID if miroir else M_STONE
	out.append(D(CY, Vector3(rayon, 0.03, rayon),
		at + Vector3(0.0, 0.016, 0.0), teinte, matiere))
	# Le tore se decrit par son rayon INTERIEUR en x et son rayon EXTERIEUR en
	# z. Un rayon interieur de cinq centimetres ne fait pas un lisere, il fait
	# un disque plein — et six disques blancs de trois metres au milieu de la
	# nef ressemblaient a des beignets.
	out.append(D(TO, Vector3(rayon * 0.90, 0.0, rayon * 1.02),
		at + Vector3(0.0, 0.018, 0.0), SALT_DARK, M_STONE))

## Echafaudage : quatre montants, deux planchers, une echelle. De la structure
## verticale, qui manque partout.
func echafaud(out: Array[SkinPart], at: Vector3, largeur: float,
		hauteur: float) -> void:
	var demi: float = largeur * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			out.append(D(CY, Vector3(0.11, hauteur, 0.11),
				at + Vector3(sx * demi, hauteur * 0.5, sz * demi), WOOD,
				M_WOOD))
	for niveau: float in [hauteur * 0.45, hauteur * 0.92]:
		out.append(D(B, Vector3(largeur + 0.4, 0.14, largeur + 0.4),
			at + Vector3(0.0, niveau, 0.0), WOOD, M_WOOD))
	for barreau: int in 5:
		out.append(D(B, Vector3(0.5, 0.07, 0.07),
			at + Vector3(-demi - 0.3, 0.4 + float(barreau) * 0.42, 0.0),
			WOOD, M_WOOD))
	out.append(D(CY, Vector3(0.06, hauteur * 0.95, 0.06),
		at + Vector3(-demi - 0.52, hauteur * 0.48, 0.0), WOOD, M_WOOD))

# ---------------------------------------------------------------------------
# Motifs de relief : ce qui donne au niveau une deuxieme hauteur
# ---------------------------------------------------------------------------
#
# La collision de ce jeu est PLATE — des disques contre une union de Rect2 sur
# le plan XZ — et elle le restera. Il n'y a donc pas de hauteur JOUABLE, pas
# d'escalier qu'on monte, pas de saut.
#
# Ce n'est pas une raison pour que le niveau soit plat. Ce qui tient un
# souls-like debout, ce n'est pas qu'on grimpe : c'est qu'on VOIT au-dessus de
# soi. Une passerelle sous laquelle on passe, un pont qui enjambe le goulot,
# une galerie qui court sur les murs de la nef, une tour qui depasse tout le
# reste : neuf rectangles poses bout a bout au meme niveau zero ne racontent
# rien, les memes neuf rectangles sous une charpente de bois racontent une
# ville.
#
# REGLE, et elle n'a pas d'exception : rien de tout cela ne descend a hauteur
# d'homme dans le praticable. Une piece haute ne ment pas — on ne peut pas y
# monter, mais rien ne laisse croire qu'on le pourrait. Une piece basse posee
# dans un couloir, elle, mentirait a chaque pas.

## Terre-plein : une plaque de sol posee HORS du praticable.
##
## Le niveau ne dessine de sol que sous ce qui se marche, et un muret de
## poitrine autour de chaque zone a ciel ouvert. Par-dessus ce muret, on voyait
## donc LE VIDE : cinquante-deux metres de parvis a ciel ouvert, et pour
## horizon la couleur de fond. Ces plaques rendent au monde son sol, un cran
## sous celui qu'on foule — assez pour qu'on lise une berge, pas assez pour
## qu'on croie pouvoir y descendre.
func terreplein(out: Array[SkinPart], plan: Rect2, hauteur: float,
		teinte: Color, surface: int = M_STONE) -> void:
	out.append(D(B, Vector3(plan.size.x, 0.6, plan.size.y),
		Vector3(plan.position.x + plan.size.x * 0.5, hauteur - 0.3,
			plan.position.y + plan.size.y * 0.5), teinte, surface))

## Garde-corps : des poteaux et deux lisses.
##
## La piece a HAUTEUR D'HOMME qui manquait partout. On la longe, elle donne
## l'echelle d'un coup d'oeil — on compte les poteaux, donc on sait la
## longueur — et elle dit ou passe le chemin sans rien bloquer.
func barriere(out: Array[SkinPart], depart: Vector3, longueur: float,
		axe: int, hauteur: float = 1.10, teinte: Color = WOOD,
		travee: float = 3.0) -> void:
	var travees: int = maxi(1, int(roundf(longueur / travee)))
	var pas: float = longueur / float(travees)
	for index: int in travees + 1:
		var t: float = float(index) * pas
		var at: Vector3 = depart + (Vector3(0.0, 0.0, t) if axe == 0
			else Vector3(t, 0.0, 0.0))
		out.append(D(B, Vector3(0.17, hauteur, 0.17),
			at + Vector3(0.0, hauteur * 0.5, 0.0), teinte, M_WOOD))
	for niveau: float in [hauteur * 0.50, hauteur - 0.08]:
		var centre: Vector3 = depart + Vector3(0.0, niveau, 0.0)
		if axe == 0:
			out.append(D(B, Vector3(0.11, 0.15, longueur),
				centre + Vector3(0.0, 0.0, longueur * 0.5), teinte, M_WOOD))
		else:
			out.append(D(B, Vector3(longueur, 0.15, 0.11),
				centre + Vector3(longueur * 0.5, 0.0, 0.0), teinte, M_WOOD))

## Volee de marches. Elle ne se monte pas ; elle se REGARDE. Une volee qui
## part vers une terrasse dit qu'il y a un dessus, et c'est tout ce qu'on
## demande a un escalier de decor.
##
## `sens` vaut +1 ou -1 : le sens dans lequel la volee monte, sur l'axe donne.
func escalier(out: Array[SkinPart], bas: Vector3, largeur: float,
		marches: int, giron: float, contremarche: float, axe: int,
		sens: float, teinte: Color = STONE_PALE) -> void:
	var tapis: Vector3 = Vector3(largeur, 0.30, giron) if axe == 0 \
		else Vector3(giron, 0.30, largeur)
	var risque: Vector3 = Vector3(largeur, contremarche, 0.16) if axe == 0 \
		else Vector3(0.16, contremarche, largeur)
	for index: int in marches:
		var monte: float = contremarche * float(index + 1)
		var avance: float = sens * giron * (float(index) + 0.5)
		var glisse: Vector3 = Vector3(0.0, 0.0, avance) if axe == 0 \
			else Vector3(avance, 0.0, 0.0)
		out.append(D(B, tapis, bas + glisse + Vector3(0.0, monte - 0.15, 0.0),
			teinte, M_STONE))
		var nez: Vector3 = Vector3(0.0, 0.0, -sens * giron * 0.5) if axe == 0 \
			else Vector3(-sens * giron * 0.5, 0.0, 0.0)
		out.append(D(B, risque,
			bas + glisse + nez + Vector3(0.0, monte - contremarche * 0.5, 0.0),
			teinte.darkened(0.18), M_STONE))

## Echelle : deux montants et ses barreaux.
##
## Elle ne se grimpe pas non plus. Elle sert a EXPLIQUER une piece haute : une
## galerie sans acces visible est un decor qui flotte, la meme galerie avec
## une echelle au pied est un endroit ou quelqu'un monte tous les jours.
func echelle(out: Array[SkinPart], at: Vector3, hauteur: float,
		axe: int) -> void:
	for cote: float in [-1.0, 1.0]:
		var ecart: Vector3 = Vector3(0.0, 0.0, cote * 0.32) if axe == 1 \
			else Vector3(cote * 0.32, 0.0, 0.0)
		out.append(D(B, Vector3(0.12, hauteur, 0.12),
			at + ecart + Vector3(0.0, hauteur * 0.5, 0.0), WOOD, M_WOOD))
	var barreaux: int = maxi(2, int(hauteur / 0.42))
	var taille: Vector3 = Vector3(0.09, 0.09, 0.72) if axe == 1 \
		else Vector3(0.72, 0.09, 0.09)
	for index: int in barreaux:
		out.append(D(B, taille,
			at + Vector3(0.0, 0.4 + float(index) * 0.42, 0.0), WOOD, M_WOOD))

## Claveaux d'un arc, poses sur un cercle.
##
## `axe` vaut 1 pour un arc qui enjambe X, 0 pour un arc qui enjambe Z.
## `demi_angle` decide de la forme : PI/2 donne un plein cintre, une valeur
## plus petite un arc surbaisse. Un pont de vingt metres de portee dont le
## tablier est a six ne peut pas etre en plein cintre — il monterait a dix
## metres. C'est un arc de cercle tres ouvert, et il faut savoir le dire.
func voussoirs(out: Array[SkinPart], sommet: Vector3, rayon: float,
		demi_angle: float, claveaux: int, epaisseur: float,
		profondeur: float, axe: int, teinte: Color) -> void:
	var centre_y: float = sommet.y - rayon
	var corde: float = 2.0 * demi_angle * rayon / float(claveaux) * 1.14
	for index: int in claveaux:
		var angle: float = -demi_angle + (float(index) + 0.5) \
			* (2.0 * demi_angle / float(claveaux))
		var lateral: float = sin(angle) * rayon
		var y: float = centre_y + cos(angle) * rayon
		var at: Vector3 = Vector3(sommet.x + lateral, y, sommet.z) \
			if axe == 1 else Vector3(sommet.x, y, sommet.z - lateral)
		# La longue dimension d'un claveau est TANGENTE au cercle, et son
		# epaisseur radiale. Prises a l'envers, les pierres deviennent des
		# rayons de roue et l'arc se lit comme une charpente.
		var piece: SkinPart = D(B, Vector3(corde, epaisseur, profondeur), at,
			teinte, M_STONE)
		piece.rotation_degrees = Vector3(0.0, 0.0, -rad_to_deg(angle)) \
			if axe == 1 else Vector3(0.0, 90.0, -rad_to_deg(angle))
		out.append(piece)

## Pont : deux culees, un arc surbaisse, un tablier, deux parapets.
##
## Il enjambe X, parce que la digue et le raccourci — les deux seuls goulots
## du niveau — se traversent tous les deux dans ce sens. Ses culees se posent
## HORS du praticable : on passe dessous, on ne monte jamais dessus, et rien
## dans sa forme ne laisse croire le contraire.
func pont(out: Array[SkinPart], at: Vector3, portee: float, largeur: float,
		tablier: float, teinte: Color = STONE_PALE) -> void:
	var demi: float = portee * 0.5
	var naissance: float = 0.8
	var fleche: float = maxf(1.2, tablier - 0.9 - naissance)
	var rayon: float = (demi * demi + fleche * fleche) / (2.0 * fleche)
	var demi_angle: float = asin(clampf(demi / rayon, 0.0, 1.0))
	voussoirs(out, Vector3(at.x, at.y + tablier - 0.9, at.z), rayon,
		demi_angle, 11, 0.60, largeur, 1, teinte)
	for cote: float in [-1.0, 1.0]:
		out.append(D(B, Vector3(3.0, tablier + 0.6, largeur + 1.5),
			Vector3(at.x + cote * (demi + 1.5), at.y + (tablier + 0.6) * 0.5,
				at.z), teinte, M_STONE))
		# Tympan : le plein entre l'arc et le tablier. Sans lui on voit le
		# ciel entre les deux, et le pont devient une planche sur un cerceau.
		out.append(D(B, Vector3(demi * 0.44, tablier * 0.52, largeur),
			Vector3(at.x + cote * demi * 0.74, at.y + tablier * 0.28, at.z),
			teinte.darkened(0.14), M_STONE))
	out.append(D(B, Vector3(portee + 6.2, 0.55, largeur + 0.6),
		Vector3(at.x, at.y + tablier - 0.28, at.z), teinte.darkened(0.22),
		M_STONE))
	for cote: float in [-1.0, 1.0]:
		out.append(D(B, Vector3(portee + 6.2, 0.90, 0.34),
			Vector3(at.x, at.y + tablier + 0.45,
				at.z + cote * (largeur * 0.5 + 0.22)), teinte, M_STONE))

## Chevalet : deux pieux ecartes, une traverse, deux liens. C'est ce qui porte
## une passerelle, et c'est surtout ce qu'on voit d'en dessous quand on passe.
func chevalet(out: Array[SkinPart], at: Vector3, largeur: float,
		hauteur: float, axe: int) -> void:
	for cote: float in [-1.0, 1.0]:
		var ecart: Vector3 = Vector3(0.0, 0.0, cote * largeur * 0.44) \
			if axe == 1 else Vector3(cote * largeur * 0.44, 0.0, 0.0)
		var pieu: SkinPart = D(CY, Vector3(0.17, hauteur, 0.22),
			at + ecart + Vector3(0.0, hauteur * 0.5, 0.0), WOOD, M_WOOD)
		pieu.rotation_degrees = Vector3(-cote * 3.5, 0.0, 0.0) if axe == 1 \
			else Vector3(0.0, 0.0, cote * 3.5)
		out.append(pieu)
	var traverse: Vector3 = Vector3(0.26, 0.26, largeur + 0.6) if axe == 1 \
		else Vector3(largeur + 0.6, 0.26, 0.26)
	out.append(D(B, traverse, at + Vector3(0.0, hauteur - 0.45, 0.0), WOOD,
		M_WOOD))
	for cote: float in [-1.0, 1.0]:
		var pose: Vector3 = Vector3(0.0, hauteur - 1.25, cote * largeur * 0.28) \
			if axe == 1 else Vector3(cote * largeur * 0.28, hauteur - 1.25, 0.0)
		var lien: SkinPart = D(B, Vector3(0.16, 2.2, 0.16), at + pose, WOOD,
			M_WOOD)
		lien.rotation_degrees = Vector3(cote * 36.0, 0.0, 0.0) if axe == 1 \
			else Vector3(0.0, 0.0, -cote * 36.0)
		out.append(lien)

## Passerelle de bois sur chevalets. `depart.y` est la hauteur du TABLIER ;
## `appuis` donne, le long de la passerelle, les abscisses ou poser un
## chevalet — jamais au hasard : sur les tables, ils se posent sur les levees,
## qui sont les seules choses qui bloquent deja.
func passerelle(out: Array[SkinPart], depart: Vector3, longueur: float,
		largeur: float, axe: int, appuis: Array[float],
		garde: bool = true, travee: float = 4.2) -> void:
	var tablier: Vector3 = Vector3(longueur, 0.32, largeur) if axe == 1 \
		else Vector3(largeur, 0.32, longueur)
	var milieu: Vector3 = depart + (Vector3(longueur * 0.5, 0.0, 0.0) \
		if axe == 1 else Vector3(0.0, 0.0, longueur * 0.5))
	out.append(D(B, tablier, milieu + Vector3(0.0, -0.16, 0.0), WOOD, M_WOOD))
	for t: float in appuis:
		var pied: Vector3 = depart + (Vector3(t, 0.0, 0.0) if axe == 1
			else Vector3(0.0, 0.0, t))
		pied.y = 0.0
		chevalet(out, pied, largeur, depart.y - 0.32, axe)
	if not garde:
		return
	for cote: float in [-1.0, 1.0]:
		var bord: Vector3 = depart + (Vector3(0.0, 0.0, cote * largeur * 0.5) \
			if axe == 1 else Vector3(cote * largeur * 0.5, 0.0, 0.0))
		barriere(out, bord, longueur, axe, 1.00, WOOD, travee)

## Galerie : un plancher de bois plaque contre un mur, ses corbeaux et son
## garde-corps.
##
## C'est la piece qui donne un ETAGE a une salle. Une nef de trente metres sur
## trente-six avec quinze metres sous charpente et rien entre les deux n'est
## pas une nef, c'est un hangar : le regard monte, ne rencontre rien, et
## redescend. `dedans` est le sens dans lequel la galerie deborde du mur.
func galerie(out: Array[SkinPart], depart: Vector3, longueur: float,
		profondeur: float, axe: int, dedans: float) -> void:
	var vers: Vector3 = Vector3(dedans * profondeur * 0.5, 0.0, 0.0) \
		if axe == 0 else Vector3(0.0, 0.0, dedans * profondeur * 0.5)
	var milieu: Vector3 = depart + vers + (Vector3(0.0, 0.0, longueur * 0.5) \
		if axe == 0 else Vector3(longueur * 0.5, 0.0, 0.0))
	var plancher: Vector3 = Vector3(profondeur, 0.30, longueur) if axe == 0 \
		else Vector3(longueur, 0.30, profondeur)
	out.append(D(B, plancher, milieu + Vector3(0.0, -0.15, 0.0), WOOD, M_WOOD))
	# Poutre de rive : la ligne sombre sous le bord libre, celle qui fait
	# lire une epaisseur plutot qu'une planche posee sur rien.
	var rive: Vector3 = Vector3(0.30, 0.45, longueur) if axe == 0 \
		else Vector3(longueur, 0.45, 0.30)
	out.append(D(B, rive, milieu + vers + Vector3(0.0, -0.50, 0.0),
		WOOD.darkened(0.25), M_WOOD))
	var corbeaux: int = maxi(2, int(longueur / 4.5))
	for index: int in corbeaux + 1:
		var t: float = longueur * float(index) / float(corbeaux)
		var pied: Vector3 = depart + (Vector3(0.0, 0.0, t) if axe == 0
			else Vector3(t, 0.0, 0.0))
		var jambe: SkinPart = D(B, Vector3(0.24, profondeur * 1.5, 0.24),
			pied + vers * 0.55 + Vector3(0.0, -profondeur * 0.62, 0.0), WOOD,
			M_WOOD)
		jambe.rotation_degrees = Vector3(0.0, 0.0, dedans * 40.0) if axe == 0 \
			else Vector3(-dedans * 40.0, 0.0, 0.0)
		out.append(jambe)
	var bord: Vector3 = depart + vers * 2.0
	barriere(out, bord, longueur, axe, 1.00, WOOD, 3.6)

## Tour de guet ruinee.
##
## La seule piece du niveau qui depasse tout le reste. Posee hors du
## praticable, elle donne un point haut a viser depuis n'importe ou, et elle
## casse la ligne d'horizon d'une saline — qui est, par nature, parfaitement
## plate. Sa couronne est EBRECHEE : une couronne complete fait un chateau de
## carte postale, une couronne a laquelle il manque trois merlons fait une
## ruine.
const MERLONS: Array[Vector2] = [
	Vector2(-0.32, -1.0), Vector2(0.32, -1.0),
	Vector2(1.0, -0.32), Vector2(1.0, 0.32),
	Vector2(0.32, 1.0), Vector2(-0.32, 1.0),
	Vector2(-1.0, 0.32), Vector2(-1.0, -0.32),
]

func tour(out: Array[SkinPart], at: Vector3, cote: float, hauteur: float,
		lampe: bool) -> void:
	out.append(D(B, Vector3(cote + 1.0, 1.5, cote + 1.0),
		at + Vector3(0.0, 0.75, 0.0), STONE, M_STONE))
	out.append(D(B, Vector3(cote, hauteur, cote),
		at + Vector3(0.0, hauteur * 0.5, 0.0), STONE_PALE, M_STONE))
	out.append(D(B, Vector3(cote + 1.1, 0.60, cote + 1.1),
		at + Vector3(0.0, hauteur - 0.3, 0.0), STONE, M_STONE))
	var bord: float = (cote + 1.1) * 0.5 - 0.46
	for index: int in MERLONS.size():
		if index == 2 or index == 3 or index == 6:
			continue
		var m: Vector2 = MERLONS[index]
		out.append(D(B, Vector3(0.88, 1.05, 0.88),
			at + Vector3(m.x * bord, hauteur + 0.52, m.y * bord), STONE_PALE,
			M_STONE))
	# Meurtrieres : trois fentes noires. Un mur plein de douze metres n'a pas
	# d'echelle ; trois trous lui en donnent une.
	for niveau: float in [hauteur * 0.30, hauteur * 0.55, hauteur * 0.80]:
		out.append(D(B, Vector3(0.44, 1.6, cote + 0.14),
			at + Vector3(0.0, niveau, 0.0), DARK, M_PLAIN))
	if lampe:
		var feu: SkinPart = D(CO, Vector3(0.44, 1.05, 0.0),
			at + Vector3(0.0, hauteur + 0.95, 0.0), FLAME, M_GLOW)
		feu.light_range = 15.0
		out.append(feu)

## Roue d'epuisement : la grande roue a augets qui remonte la saumure d'une
## table dans la suivante. C'est la silhouette meme d'une saline, et il n'y en
## avait aucune dans un niveau qui s'appelle « les Salines de Marn ».
func roue(out: Array[SkinPart], at: Vector3, rayon: float) -> void:
	var axe_y: float = rayon + 0.6
	for cote: float in [-1.0, 1.0]:
		var jante: SkinPart = D(TO, Vector3(rayon - 0.24, 0.0, rayon),
			at + Vector3(0.0, axe_y, cote * 0.45), WOOD, M_WOOD)
		jante.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		out.append(jante)
	for index: int in 6:
		var rais: SkinPart = D(B, Vector3(0.16, rayon * 1.94, 0.16),
			at + Vector3(0.0, axe_y, 0.0), WOOD, M_WOOD)
		rais.rotation_degrees = Vector3(0.0, 0.0, 30.0 * float(index))
		out.append(rais)
	for index: int in 8:
		var angle: float = TAU * float(index) / 8.0
		var auget: SkinPart = D(B, Vector3(0.52, 0.36, 1.05),
			at + Vector3(sin(angle) * (rayon - 0.30), axe_y
				+ cos(angle) * (rayon - 0.30), 0.0), WOOD.darkened(0.20),
			M_WOOD)
		auget.rotation_degrees = Vector3(0.0, 0.0, -rad_to_deg(angle))
		out.append(auget)
	var arbre: SkinPart = D(CY, Vector3(0.24, 2.6, 0.24),
		at + Vector3(0.0, axe_y, 0.0), IRON, M_METAL)
	arbre.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	out.append(arbre)
	for cote: float in [-1.0, 1.0]:
		for sens: float in [-1.0, 1.0]:
			var jambe: SkinPart = D(B, Vector3(0.28, axe_y * 1.12, 0.28),
				at + Vector3(sens * axe_y * 0.22, axe_y * 0.5,
					cote * 1.35), WOOD, M_WOOD)
			jambe.rotation_degrees = Vector3(0.0, 0.0, -sens * 12.0)
			out.append(jambe)
	# L'auge ou la roue verse. Sans elle, la roue tourne pour rien.
	out.append(D(B, Vector3(1.2, 0.5, 4.4),
		at + Vector3(rayon * 0.75, axe_y * 0.55, 0.0), WOOD, M_WOOD))

## Arcade : une file d'arches sur piles, qui porte le conduit de saumure d'un
## bout du marais a l'autre. Elle marche en travers du paysage et donne une
## LIGNE HAUTE la ou il n'y en avait aucune.
func arcade(out: Array[SkinPart], depart: Vector3, travees: int,
		portee: float, hauteur: float, largeur: float, axe: int) -> void:
	var pile: Vector3 = Vector3(1.6, hauteur, largeur) if axe == 1 \
		else Vector3(largeur, hauteur, 1.6)
	for index: int in travees + 1:
		var t: float = float(index) * portee
		var pied: Vector3 = depart + (Vector3(t, 0.0, 0.0) if axe == 1
			else Vector3(0.0, 0.0, t))
		out.append(D(B, pile, pied + Vector3(0.0, hauteur * 0.5, 0.0),
			STONE_PALE, M_STONE))
	for index: int in travees:
		var t: float = (float(index) + 0.5) * portee
		var sommet: Vector3 = depart + (Vector3(t, 0.0, 0.0) if axe == 1
			else Vector3(0.0, 0.0, t)) + Vector3(0.0, hauteur - 0.45, 0.0)
		voussoirs(out, sommet, portee * 0.5 - 0.8, PI * 0.5, 7, 0.55,
			largeur * 0.9, axe, STONE)
	var longueur: float = float(travees) * portee
	var milieu: Vector3 = depart + (Vector3(longueur * 0.5, 0.0, 0.0) \
		if axe == 1 else Vector3(0.0, 0.0, longueur * 0.5))
	var table: Vector3 = Vector3(longueur + 1.6, 0.70, largeur + 0.7) \
		if axe == 1 else Vector3(largeur + 0.7, 0.70, longueur + 1.6)
	out.append(D(B, table, milieu + Vector3(0.0, hauteur + 0.35, 0.0), STONE,
		M_STONE))
	var conduit: Vector3 = Vector3(longueur + 1.6, 0.60, largeur * 0.45) \
		if axe == 1 else Vector3(largeur * 0.45, 0.60, longueur + 1.6)
	out.append(D(B, conduit, milieu + Vector3(0.0, hauteur + 1.0, 0.0),
		STONE_PALE, M_STONE))

## Pan de mur creve : deux jambages inegaux, ce qui reste d'une baie, et le
## tas au pied. Une ruine se lit a ce qu'il lui MANQUE — deux jambages de la
## meme hauteur font un portique, pas une ruine.
func ruine(out: Array[SkinPart], at: Vector3, largeur: float, hauteur: float,
		axe: int) -> void:
	for cote: float in [-1.0, 1.0]:
		var h: float = hauteur if cote < 0.0 else hauteur * 0.56
		var ecart: Vector3 = Vector3(0.0, 0.0, cote * largeur * 0.5) \
			if axe == 0 else Vector3(cote * largeur * 0.5, 0.0, 0.0)
		var jambage: Vector3 = Vector3(1.6, h, 1.1) if axe == 0 \
			else Vector3(1.1, h, 1.6)
		out.append(D(B, jambage, at + ecart + Vector3(0.0, h * 0.5, 0.0),
			STONE_PALE, M_STONE))
	voussoirs(out, at + Vector3(0.0, hauteur * 0.74, 0.0),
		largeur * 0.5 - 0.25, 1.15, 6, 0.55, 1.1, axe, STONE)
	for index: int in 2:
		var haut: SkinPart = D(B, Vector3(1.3, 0.9, 1.0),
			at + Vector3(0.0, hauteur + 0.3 - float(index) * 0.5, 0.0)
			+ (Vector3(0.0, 0.0, -largeur * (0.5 - float(index) * 0.22)) \
				if axe == 0
				else Vector3(-largeur * (0.5 - float(index) * 0.22), 0.0, 0.0)),
			STONE_PALE, M_STONE)
		haut.rotation_degrees = Vector3(0.0, 12.0 * float(index), 0.0)
		out.append(haut)
	rubble(out, at, largeur * 0.45)

## Caisses empilees. Trois fois la meme boite, une plus petite en travers.
##
## Le motif le moins cher du jeu et celui qui manquait le plus : quelque chose
## a HAUTEUR DE HANCHE qu'on longe. Une salle ne se lit pas par ses murs, elle
## se lit par ce qu'on frole en la traversant.
func caisses(out: Array[SkinPart], at: Vector3, angle: float) -> void:
	out.append(M("village/Crate", at, 0.78, angle))
	out.append(M("village/Crate", at + Vector3(0.16, 0.78, -0.14), 0.62,
		angle + 24.0))
	out.append(M("village/Barrel", at + Vector3(-1.02, 0.0, 0.38), 0.92,
		angle - 15.0))
	out.append(M("village/Package_1", at + Vector3(-0.96, 0.0, 1.10), 0.48,
		angle + 52.0))

## Etal de saunier : une planche sur quatre pieds, un tas de sel dessus, un
## seau, une pelle appuyee contre. C'est la trace de QUELQU'UN, et il n'y en
## avait nulle part dans une saline censee etre exploitee.
func etal(out: Array[SkinPart], at: Vector3, angle: float) -> void:
	out.append(M("village/MarketStand_1", at, 2.35, angle))
	# Le tas de sel dessus reste une primitive : c'est la marchandise du lieu,
	# et aucun modele du kit ne fait un tas de sel.
	out.append(D(CO, Vector3(0.42, 0.42, 0.0), at + Vector3(0.35, 1.05, 0.0),
		SALT, M_STONE))
	out.append(M("village/Barrel", at + Vector3(-1.35, 0.0, 0.5), 0.92,
		angle + 40.0))

## Sechoir a toiles : une chevre de bois et deux toiles qui pendent. La seule
## silhouette MOLLE d'un niveau qui n'en compte que des dures.
func filets(out: Array[SkinPart], at: Vector3, angle: float) -> void:
	for cote: float in [-1.0, 1.0]:
		var pieu: SkinPart = D(CY, Vector3(0.11, 2.5, 0.13),
			at + Vector3(cote * 1.5, 1.25, 0.0), WOOD, M_WOOD)
		pieu.rotation_degrees = Vector3(0.0, angle, -cote * 7.0)
		out.append(pieu)
	var barre: SkinPart = D(B, Vector3(3.4, 0.11, 0.11),
		at + Vector3(0.0, 2.42, 0.0), WOOD, M_WOOD)
	barre.rotation_degrees = Vector3(0.0, angle, 0.0)
	out.append(barre)
	for cote: float in [-1.0, 1.0]:
		var toile: SkinPart = D(B, Vector3(1.25, 1.75, 0.06),
			at + Vector3(cote * 0.72, 1.52, 0.06), ROPE, M_CLOTH)
		toile.rotation_degrees = Vector3(0.0, angle, cote * 3.0)
		out.append(toile)

## Herse levee : une grille remontee sous son arc, et ses deux chaines. Elle
## dit qu'on est passe SOUS quelque chose, et que ca peut retomber.
func herse(out: Array[SkinPart], at: Vector3, largeur: float) -> void:
	out.append(D(B, Vector3(largeur, 0.24, 0.30), at, IRON, M_METAL))
	for index: int in 5:
		var x: float = -largeur * 0.4 + largeur * 0.2 * float(index)
		out.append(D(B, Vector3(0.13, 1.5, 0.13),
			at + Vector3(x, -0.75, 0.0), IRON, M_METAL))
	out.append(D(B, Vector3(largeur * 0.9, 0.16, 0.20),
		at + Vector3(0.0, -1.35, 0.0), IRON, M_METAL))
	for cote: float in [-1.0, 1.0]:
		out.append(D(CY, Vector3(0.05, 1.6, 0.05),
			at + Vector3(cote * largeur * 0.42, 0.8, 0.0), IRON, M_METAL))

## Pieux d'un appontement noye. Rien ne s'y passe et rien n'y mene : c'est une
## ligne de fuite, et c'est ce qui empeche l'horizon d'etre une seule barre
## plate. On lit une distance parce que quelque chose de connu y devient petit.
##
## Le meme pieu partout, plus ou moins enfonce : la variete vient de
## l'enfoncement, jamais de la taille — sinon chaque pieu ferait son propre lot
## de rendu, et une rangee de neuf couterait neuf appels.
func pilotis(out: Array[SkinPart], depart: Vector3, avance: Vector3,
		nombre: int, ecart: float) -> void:
	for index: int in nombre:
		var enfonce: float = fmod(float(index) * 0.83 + absf(depart.x) * 0.11,
			1.45)
		out.append(D(CY, Vector3(0.22, 3.6, 0.26),
			depart + avance * (float(index) * ecart)
			+ Vector3(0.0, 1.8 - enfonce, 0.0), WOOD, M_WOOD))

## Lanterne sur pied. Elle balise un chemin, et de nuit c'est la seule chose
## qui dise ou il continue.
func lanterne(out: Array[SkinPart], at: Vector3, hauteur: float,
		portee: float) -> void:
	out.append(D(CY, Vector3(0.10, hauteur, 0.13),
		at + Vector3(0.0, hauteur * 0.5, 0.0), WOOD, M_WOOD))
	var feu: SkinPart = D(SkinPart.Shape.ELLIPSOID, Vector3(0.26, 0.32, 0.26),
		at + Vector3(0.0, hauteur + 0.22, 0.0), CANDLE, M_GLOW)
	feu.light_range = portee
	out.append(feu)
	out.append(D(PR, Vector3(0.46, 0.26, 0.46),
		at + Vector3(0.0, hauteur + 0.54, 0.0), IRON, M_METAL))

# ---------------------------------------------------------------------------
# Les abords
# ---------------------------------------------------------------------------
#
# Le niveau ne fabrique de sol que sous ce qui se marche. Par-dessus le muret
# d'une zone a ciel ouvert, on ne voyait donc pas un paysage : on voyait le
# DOME DU CIEL, sa moitie basse, une couleur unie. Les Salines flottaient dans
# le vide, et c'est la premiere raison pour laquelle elles paraissaient laides
# — aucun decor pose SUR le niveau ne repare un niveau pose sur rien.
#
# Une nappe unique, tres basse, fait le marais ; des plaques de sel, un cran
# sous le praticable, font les berges ; ce qui reste entre les deux fait les
# bassins vides. Douze pieces pour rendre au monde son sol.
func _abords(parts: Array[SkinPart]) -> void:
	# Le marais. Une seule nappe LIQUIDE sous tout le reste : au crepuscule ce
	# qu'on en voit n'est pas sa couleur, c'est le ciel dedans.
	terreplein(parts, Rect2(-64.0, -64.0, 128.0, 250.0), -1.9, BRINE_WET,
		SkinPart.Surface.LIQUID)
	# Les berges de sel, un demi-metre sous le pied. Assez pour qu'on lise une
	# marche, pas assez pour qu'on croie pouvoir y descendre.
	#
	# Elles PAVENT : chaque plaque touche ses voisines par un bord et n'en
	# recouvre aucune. Deux plaques coplanaires qui se chevauchent clignotent
	# des qu'on bouge la camera, et c'est le seul defaut de rendu qu'un joueur
	# remarque a coup sur. Elles s'arretent toutes a dix-huit metres du bord du
	# marais : cette bande d'eau franche est la seule chose qui dise que les
	# Salines sont AU MILIEU de quelque chose.
	for berge: Rect2 in [
			Rect2(-46.0, -52.0, 92.0, 18.0),   # au sud de la halle
			Rect2(-46.0, -34.0, 31.0, 35.0),   # flanc ouest de la halle
			Rect2(15.0, -34.0, 31.0, 35.0),    # flanc est de la halle
			Rect2(-26.0, 1.0, 16.0, 8.0),      # devant, a l'ouest du bassin
			Rect2(10.0, 1.0, 23.0, 8.0),       # devant, a l'est du bassin
			Rect2(-46.0, 1.0, 20.0, 105.0),    # tout le bord ouest
			Rect2(33.0, 1.0, 13.0, 167.0),     # tout le bord est
			Rect2(-26.0, 104.0, 18.0, 8.0),    # flanc ouest du seuil
			Rect2(8.0, 104.0, 18.0, 8.0),      # flanc est du seuil
			Rect2(-46.0, 106.0, 20.0, 44.0),   # a l'ouest de l'arene
			Rect2(25.0, 118.0, 8.0, 32.0),     # a l'est de l'arene
			Rect2(-46.0, 150.0, 79.0, 18.0),   # au nord de l'arene
			Rect2(24.0, 64.0, 2.0, 38.0)]:     # lisere tables / raccourci
		terreplein(parts, berge, -0.5, SALT_DARK)
	# Les deux bassins vides qui serrent la digue. Plus bas que les berges,
	# plus haut que le marais : c'est ce creux qui fait qu'une digue est une
	# digue et pas un chemin.
	for bassin: Rect2 in [Rect2(-26.0, 34.0, 19.0, 30.0),
			Rect2(7.0, 34.0, 19.0, 30.0)]:
		terreplein(parts, bassin, -1.25, SALT_DARK.darkened(0.22))
	# Le trait de cote. Les plaques ci-dessus pavent un RECTANGLE, et un
	# rectangle vu de haut se lit comme une table, pas comme une ile. Ces
	# quelques langues de sel debordent dans l'eau a contretemps : elles ne
	# coutent presque rien et elles cassent les quatre angles droits.
	for langue: Rect2 in [
			Rect2(-56.0, 22.0, 11.0, 14.0), Rect2(-53.0, 78.0, 8.0, 19.0),
			Rect2(46.0, 12.0, 9.0, 22.0), Rect2(46.0, 96.0, 13.0, 16.0),
			Rect2(-14.0, -62.0, 26.0, 11.0), Rect2(-8.0, 168.0, 30.0, 9.0)]:
		terreplein(parts, langue, -1.05, SALT_DARK.darkened(0.14))
	# Ce qui peuple le marais : des pieux, deux epaves, et rien d'autre. Le
	# large doit rester VIDE — c'est de son vide que le niveau tire sa taille.
	# Tout est plante DANS L'EAU, au-dela des berges : un pieu pose sur le sel
	# serait enterre jusqu'a la tete et ne se verrait pas du tout.
	pilotis(parts, Vector3(-49.0, -1.9, 16.0), Vector3(0.30, 0.0, 1.0), 7, 4.6)
	pilotis(parts, Vector3(49.0, -1.9, 44.0), Vector3(0.0, 0.0, 1.0), 7, 4.8)
	coque(parts, Vector3(-53.0, -1.9, 70.0), 24.0, 12.0)
	coque(parts, Vector3(52.0, -1.9, 128.0), 200.0, 10.0)

## Habille l'exterieur des trois volumes fermes du niveau.
func _exterieurs(parts: Array[SkinPart]) -> void:
	corniche(parts, HALLE, H_HALLE, STONE_PALE)
	contreforts(parts, HALLE, H_HALLE, 7.0, STONE)
	toiture(parts, HALLE, H_HALLE, 5.2, WOOD)
	for z: float in [-27.0, -18.0, -9.0]:
		cheminee(parts, Vector3(0.0, H_HALLE + 4.4, z), 3.4)
	# Pans de bois sur les deux longs cotes de la halle et sur son pignon sud,
	# qui est la facade qu'on regarde depuis tout le parvis.
	colombage(parts, Vector3(-15.0, 0.0, -34.0), 36.0, H_HALLE, 0, -1.0, 6.0)
	colombage(parts, Vector3(15.0, 0.0, -34.0), 36.0, H_HALLE, 0, 1.0, 6.0)
	# Le pan de bois du pignon sud s'ARRETE de part et d'autre de l'ouverture
	# du bassin. Il courait sur les trente metres, et sa trame tombait juste :
	# un poteau de quinze metres de haut plante en x = 0, exactement au milieu
	# du passage entre la nef et le feu de camp, plus une sabliere basse en
	# travers a hauteur de genou. Depuis le feu — l'endroit le plus regarde du
	# jeu — le poteau masquait le personnage.
	colombage(parts, Vector3(-15.0, 0.0, 2.0), 5.0, H_HALLE, 1, 1.0, 5.0)
	colombage(parts, Vector3(10.0, 0.0, 2.0), 5.0, H_HALLE, 1, 1.0, 5.0)
	for z: float in [-29.0, -21.0, -13.0]:
		volets(parts, Vector3(-15.1, 9.5, z), 3.0, 4.0, 0, -1.0)
		volets(parts, Vector3(15.1, 9.5, z), 3.0, 4.0, 0, 1.0)
	banniere(parts, Vector3(-8.0, 12.4, 2.3), 2.4, 6.0, BRINE.darkened(0.30), 1)
	banniere(parts, Vector3(8.0, 12.4, 2.3), 2.4, 6.0, BRINE.darkened(0.30), 1)
	echafaud(parts, Vector3(-17.5, 0.0, -6.0), 2.6, 9.0)

	corniche(parts, BASSIN, H_BASSIN, STONE_PALE)
	toiture(parts, BASSIN, H_BASSIN, 2.4, WOOD)
	colombage(parts, Vector3(-10.0, 0.0, 9.0), 20.0, H_BASSIN, 1, 1.0, 4.0)

	corniche(parts, ARENE, H_ARENE, STONE_PALE)
	contreforts(parts, ARENE, H_ARENE, 8.0, STONE)
	toiture(parts, ARENE, H_ARENE, 6.0, WOOD)
	cheminee(parts, Vector3(0.0, H_ARENE + 5.2, 124.0), 4.2)
	cheminee(parts, Vector3(0.0, H_ARENE + 5.2, 138.0), 4.2)
	# Facade sud de l'arene : c'est le BUT du niveau, elle doit se voir depuis
	# les tables et dire qu'on arrive quelque part.
	colombage(parts, Vector3(-25.0, 0.0, 112.0), 50.0, H_ARENE, 1, -1.0, 6.25)
	colombage(parts, Vector3(-25.0, 0.0, 112.0), 38.0, H_ARENE, 0, -1.0, 7.6)
	colombage(parts, Vector3(25.0, 0.0, 112.0), 38.0, H_ARENE, 0, 1.0, 7.6)
	for x: float in [-18.0, -11.0, 11.0, 18.0]:
		volets(parts, Vector3(x, 7.6, 111.9), 2.6, 3.6, 1, -1.0)
	for x: float in [-9.0, 9.0]:
		banniere(parts, Vector3(x, 10.6, 111.6), 2.8, 7.0,
			FLAME.darkened(0.42), 0)
	echafaud(parts, Vector3(-27.5, 0.0, 126.0), 2.8, 10.0)

	corniche(parts, SEUIL, H_SEUIL, STONE_PALE)
	toiture(parts, SEUIL, H_SEUIL, 1.8, WOOD)
	colombage(parts, Vector3(-8.0, 0.0, 104.0), 8.0, H_SEUIL, 0, -1.0, 4.0)
	colombage(parts, Vector3(8.0, 0.0, 104.0), 8.0, H_SEUIL, 0, 1.0, 4.0)

## Ce qui traine, et ce qui pousse. Deux choses qu'un decor taille dans des
## primitives ne sait pas faire, et dont l'absence se lit tout de suite : une
## saline exploitee est ENCOMBREE, et un marais a des arbres morts.
##
## Rien de ce qui est pose ici ne bloque : la collision est declaree ailleurs,
## et un obstacle qu'on voit sans qu'il arrete est un mensonge — mais un objet
## de moins d'un metre pose contre un mur ne se lit pas comme un obstacle.
func _props(parts: Array[SkinPart]) -> void:
	# Le long des murs et dans les angles, jamais au milieu d'un passage.
	var coins: Array[Vector3] = [
		Vector3(-12.5, 0.0, -30.0), Vector3(12.5, 0.0, -26.0),
		Vector3(-12.5, 0.0, -14.0), Vector3(12.5, 0.0, -8.0),
		Vector3(-22.0, 0.0, 22.0), Vector3(22.0, 0.0, 28.0),
		Vector3(-22.0, 0.0, 46.0), Vector3(27.0, 0.0, 62.0),
		Vector3(-22.0, 0.0, 84.0), Vector3(27.0, 0.0, 96.0),
		Vector3(-21.0, 0.0, 120.0), Vector3(21.0, 0.0, 132.0),
	]
	var choix: Array[String] = ["village/Barrel", "village/Crate",
		"village/Bench_1", "village/Cart", "village/Hay", "village/Cauldron",
		"village/Bags", "village/Bench_2"]
	var hauteurs: Array[float] = [0.92, 0.78, 0.55, 1.25, 1.05, 0.72, 0.45,
		0.55]
	for index: int in coins.size():
		var quoi: int = index % choix.size()
		parts.append(M(choix[quoi], coins[index], hauteurs[quoi],
			float(index) * 47.0))
		var voisin: int = (index + 3) % choix.size()
		parts.append(M(choix[voisin],
			coins[index] + Vector3(0.9, 0.0, -0.7), hauteurs[voisin] * 0.9,
			float(index) * 23.0 + 120.0))

	# Arbres morts sur les berges. Le marais avait des silhouettes lointaines
	# taillees dans des boites ; un arbre en boites reste une boite.
	var arbres: Array[String] = ["nature/CommonTree_Dead_1",
		"nature/CommonTree_Dead_2", "nature/CommonTree_Dead_3",
		"nature/CommonTree_Dead_4", "nature/CommonTree_Dead_5",
		"nature/BirchTree_Dead_1", "nature/BirchTree_Dead_2",
		"nature/BirchTree_Dead_3"]
	var plantes: Array[Vector3] = [
		Vector3(-40.0, -1.4, -46.0), Vector3(-33.0, -1.4, -40.0),
		Vector3(40.0, -1.4, -44.0), Vector3(30.0, -1.4, -50.0),
		Vector3(-41.0, -1.4, 14.0), Vector3(-38.0, -1.4, 38.0),
		Vector3(-42.0, -1.4, 66.0), Vector3(-39.0, -1.4, 92.0),
		Vector3(40.0, -1.4, 20.0), Vector3(42.0, -1.4, 52.0),
		Vector3(39.0, -1.4, 88.0), Vector3(41.0, -1.4, 118.0),
		Vector3(-43.0, -1.4, 130.0), Vector3(43.0, -1.4, 146.0),
		Vector3(-30.0, -1.4, 158.0), Vector3(28.0, -1.4, 162.0),
	]
	for index: int in plantes.size():
		parts.append(M(arbres[index % arbres.size()], plantes[index],
			5.2 + float(index % 4) * 1.7, float(index) * 61.0))
	for index: int in 10:
		var angle: float = TAU * float(index) / 10.0
		parts.append(M("nature/Bush_1" if index % 2 == 0 else "nature/Bush_2",
			Vector3(cos(angle) * 44.0, -1.4, 60.0 + sin(angle) * 70.0),
			1.1 + float(index % 3) * 0.35, float(index) * 37.0))

func build_decor() -> DecorData:
	var decor: DecorData = DecorData.new()
	decor.id = &"salines"
	var parts: Array[SkinPart] = []
	_abords(parts)
	_props(parts)
	_halle(parts)
	_bassin(parts)
	_parvis(parts)
	_digue(parts)
	_tables(parts)
	_seuil(parts)
	_arene(parts)
	_raccourci(parts)
	_exterieurs(parts)
	decor.parts = parts
	return decor

## LA HALLE AUX SAUMURES. Une coque retournee posee sur des murs de sel : les
## membrures montent en berceau, les panneaux de saumure eclairent par les
## cotes, et il y a des cuves partout parce que c'est une usine.
func _halle(parts: Array[SkinPart]) -> void:
	for z: float in MEMBRURES_Z:
		arch(parts, Vector3(0.0, 4.4, z), 10.6, 0.75, 20, 0.55, WOOD)
	for x: float in MEMBRURES_X:
		for z: float in MEMBRURES_Z:
			parts.append(D(SkinPart.Shape.CYLINDER, Vector3(0.80, 4.4, 0.95),
				Vector3(x, 2.2, z), STONE_PALE, SkinPart.Surface.STONE))
			# Sabliere : la piece qui pose la cote sur la pile. Sans elle, un
			# arc semble flotter au-dessus de son support.
			parts.append(D(SkinPart.Shape.BOX, Vector3(1.5, 0.34, 1.3),
				Vector3(x, 4.45, z), WOOD, SkinPart.Surface.WOOD))
	for z: float in [-29.0, -21.0, -13.0, -5.0]:
		window(parts, Vector3(-14.75, 5.4, z), 90.0, BRINE, 3.0, 5.0)
		window(parts, Vector3(14.75, 5.4, z), 90.0, BRINE, 3.0, 5.0)
	for z: float in [-27.0, -17.0, -7.0]:
		chandelier(parts, Vector3(0.0, 10.5, z), H_HALLE, 19.0)
	for z: float in [-31.0, -23.0, -15.0]:
		torch(parts, Vector3(-14.6, 2.8, z), Vector3(1.0, 0.0, 0.0), 9.0)
		torch(parts, Vector3(14.6, 2.8, z), Vector3(-1.0, 0.0, 0.0), 9.0)
	for at: Vector2 in [Vector2(-12.5, -28.0), Vector2(-12.5, -24.0),
			Vector2(12.5, -12.0), Vector2(12.5, -8.0), Vector2(-12.8, -6.0)]:
		cuve(parts, Vector3(at.x, 0.0, at.y), 1.15, 1.3)
	sechoir(parts, Vector3(-6.5, 0.0, -31.0), 0.0)
	sechoir(parts, Vector3(7.0, 0.0, -30.0), 12.0)
	sechoir(parts, Vector3(-7.5, 0.0, -3.5), 90.0)
	tas(parts, Vector3(9.5, 0.0, -25.0), 1.5, 1.5)
	tas(parts, Vector3(-9.0, 0.0, -12.0), 1.2, 1.2)
	rubble(parts, Vector3(4.0, 0.0, -33.0), 1.5)
	rubble(parts, Vector3(-4.5, 0.0, -2.0), 1.2)
	# LA NEF ETAIT VIDE. Trente metres sur trente-six de dallage nu : quel que
	# soit le soin mis a l'eclairage, un sol sans rien dessus se lit comme une
	# salle pas finie. Ce qui suit occupe le SOL, la HAUTEUR et les BORDS —
	# les trois manquaient.
	#
	# Flaques : elles renvoient le ciel de la grande porte au milieu du
	# dallage, et c'est le seul reflet qu'on ait a l'interieur.
	for at: Vector2 in [Vector2(-3.0, -20.0), Vector2(5.5, -16.0),
			Vector2(-7.0, -26.5), Vector2(2.0, -30.0), Vector2(8.0, -5.0),
			Vector2(-10.5, -17.5)]:
		flaque(parts, Vector3(at.x, 0.0, at.y), 0.85 + absf(at.x) * 0.05,
			false)
	# Chaines chargees de sacs, pendues aux membrures. C'est la hauteur de la
	# halle qui devient lisible.
	for at: Vector2 in [Vector2(-5.0, -24.0), Vector2(5.0, -18.0),
			Vector2(-6.0, -10.0), Vector2(4.5, -30.0)]:
		chaine(parts, Vector3(at.x, 9.4, at.y), 3.2, 3)
	# Deux echafauds contre les piles : on repare toujours une saline.
	echafaud(parts, Vector3(-11.0, 0.0, -20.0), 2.4, 7.5)
	echafaud(parts, Vector3(11.5, 0.0, -30.0), 2.2, 6.0)
	# Bordures : caisses empilees et cuves alignees le long des murs, la ou
	# personne ne se bat. Elles ferment la salle sans gener le combat.
	for z: float in [-32.0, -28.5, -19.0, -15.5]:
		borne(parts, Vector3(-13.6, 0.0, z))
		borne(parts, Vector3(13.6, 0.0, z + 1.8))
	for z: float in [-26.0, -22.0, -18.0]:
		cuve(parts, Vector3(13.2, 0.0, z), 1.0, 1.15)
	tas(parts, Vector3(-13.0, 0.0, -34.0 + 2.0), 2.0, 1.8)
	tas(parts, Vector3(12.6, 0.0, -3.4), 1.7, 1.6)
	sechoir(parts, Vector3(10.0, 0.0, -20.0), 90.0)
	sechoir(parts, Vector3(-10.5, 0.0, -33.0), 90.0)
	# QUINZE METRES SOUS CHARPENTE ET RIEN ENTRE DEUX. Le regard montait, ne
	# rencontrait rien, redescendait : une nef sans etage n'est pas une nef,
	# c'est un hangar. Deux galeries de bois plaquees sur les longs murs
	# coupent la hauteur en deux et donnent aux membrures quelque chose a
	# porter.
	galerie(parts, Vector3(14.7, 6.2, -30.0), 24.0, 2.6, 0, -1.0)
	echelle(parts, Vector3(13.2, 0.0, -5.4), 6.0, 0)
	caisses(parts, Vector3(-13.0, 0.0, -21.5), 88.0)
	etal(parts, Vector3(-11.4, 0.0, -27.5), 14.0)
	filets(parts, Vector3(11.8, 0.0, -33.0), 92.0)

## LE BASSIN. Le fond de la halle : une grande cuve, la braise, et rien
## d'autre. Le seul endroit chaud du niveau, donc aucun bruit visuel.
func _bassin(parts: Array[SkinPart]) -> void:
	# La grande cuve, repoussee contre le mur ouest : elle meuble sans barrer.
	parts.append(D(SkinPart.Shape.BOX, Vector3(4.0, 1.45, 2.2),
		Vector3(-6.8, 0.72, 5.7), STONE_PALE, SkinPart.Surface.STONE))
	parts.append(D(SkinPart.Shape.BOX, Vector3(3.5, 0.10, 1.8),
		Vector3(-6.8, 1.50, 5.7), BRINE_WET, SkinPart.Surface.LIQUID))
	for at: Vector2 in [Vector2(7.2, 5.4), Vector2(8.4, 7.6)]:
		cuve(parts, Vector3(at.x, 0.0, at.y), 1.15, 1.3)
	for cote: float in [-1.0, 1.0]:
		torch(parts, Vector3(cote * 9.6, 2.6, 5.0),
			Vector3(-cote, 0.0, 0.0), 9.0)
		bitte(parts, Vector3(cote * 7.4, 0.0, 3.0))
	window(parts, Vector3(0.0, 4.4, 8.85), 0.0, BRINE, 4.0, 2.8)
	caisses(parts, Vector3(8.5, 0.0, 3.4), -84.0)

## LE PARVIS. La premiere sortie. On passe d'une halle a neuf metres sous
## coque a cinquante-deux metres de large sans un toit : le seul moment du jeu
## ou l'espace doit gifler.
func _parvis(parts: Array[SkinPart]) -> void:
	for marche: int in 3:
		parts.append(D(SkinPart.Shape.BOX,
			Vector3(22.0 + float(marche) * 3.0, 0.22, 1.2),
			Vector3(0.0, 0.11, 9.6 + float(marche) * 1.2), STONE_PALE,
			SkinPart.Surface.STONE))
	grue(parts, Vector3(-22.0, 0.0, 20.0), 35.0)
	grue(parts, Vector3(21.0, 0.0, 32.0), 200.0)
	coque(parts, Vector3(-14.0, 0.0, 12.5), 18.0, 11.0)
	coque(parts, Vector3(17.0, 0.0, 20.0), 108.0, 8.0)
	for at: Vector2 in [Vector2(-19.0, 16.0), Vector2(15.0, 14.0),
			Vector2(-11.0, 28.0), Vector2(19.0, 27.0), Vector2(6.0, 21.0)]:
		for etage: int in 3:
			parts.append(D(SkinPart.Shape.BOX,
				Vector3(2.8 - float(etage) * 0.30, 0.58,
					2.2 - float(etage) * 0.24),
				Vector3(at.x, 0.29 + float(etage) * 0.58, at.y), SALT,
				SkinPart.Surface.STONE))
	for at: Vector2 in [Vector2(-24.0, 12.0), Vector2(-24.0, 24.0),
			Vector2(24.0, 12.0), Vector2(24.0, 24.0), Vector2(24.0, 34.0)]:
		bitte(parts, Vector3(at.x, 0.0, at.y))
	for at: Vector2 in [Vector2(-6.0, 32.0), Vector2(11.0, 34.0),
			Vector2(-20.0, 33.0)]:
		tas(parts, Vector3(at.x, 0.0, at.y), 1.8, 1.7)
	echafaud(parts, Vector3(-23.0, 0.0, 34.5), 2.4, 7.0)
	sechoir(parts, Vector3(-16.0, 0.0, 22.0), 74.0)
	sechoir(parts, Vector3(12.0, 0.0, 25.0), 100.0)
	rubble(parts, Vector3(2.0, 0.0, 16.0), 2.0)
	rubble(parts, Vector3(-8.0, 0.0, 34.0), 1.6)
	# Flaques de saumure a ciel ouvert. Dehors, elles renvoient le couchant :
	# ce sont les seules taches de ciel qu'on ait AU SOL, et elles cassent
	# cinquante metres de dallage mieux que n'importe quelle texture.
	for at: Vector2 in [Vector2(-13.0, 18.0), Vector2(4.0, 13.0),
			Vector2(-3.0, 26.0), Vector2(14.0, 31.0), Vector2(-21.0, 30.0),
			Vector2(9.0, 17.0), Vector2(-17.0, 11.5), Vector2(20.0, 20.0)]:
		flaque(parts, Vector3(at.x, 0.0, at.y), 1.1 + absf(at.y - 22.0) * 0.05)
	# Bannieres au bord du parvis : le seul aplat de couleur franche a hauteur
	# d'homme sur toute la place.
	for at: Vector2 in [Vector2(-25.0, 18.0), Vector2(25.0, 26.0)]:
		parts.append(D(CY, Vector3(0.13, 6.6, 0.13),
			Vector3(at.x, 3.3, at.y), IRON, M_METAL))
		banniere(parts, Vector3(at.x, 6.2, at.y), 1.9, 4.4,
			BRINE.darkened(0.34), 0)
	# LE PARVIS N'AVAIT PAS DE DESSUS. Cinquante-deux metres de large, deux
	# grues penchees, et pour tout le reste une ligne d'horizon parfaitement
	# droite. Ce qui suit la casse en quatre endroits, et aucun de ces quatre
	# n'est au meme etage que les autres.
	#
	# La passerelle prend appui d'un cote sur la berge, de l'autre SUR UNE PILE
	# DE SEL — qui est un obstacle declare. C'est la seule chose du praticable
	# ou l'on ait le droit de poser un pied.
	passerelle(parts, Vector3(-29.0, 5.2, 16.0), 11.0, 2.2, 1, [1.0, 10.0])
	# La volee s'arrete a un metre du chevalet : posee plus pres, ses marches
	# et les pieds de la passerelle se traversaient.
	escalier(parts, Vector3(-34.6, -0.5, 16.0), 2.6, 13, 0.36, 0.39, 1, 1.0)
	tour(parts, Vector3(-21.0, -0.5, -1.0), 3.8, 19.0, true)
	roue(parts, Vector3(-29.5, -0.5, 26.0), 3.2)
	ruine(parts, Vector3(-28.6, -0.5, 12.0), 7.0, 7.0, 0)
	barriere(parts, Vector3(-39.5, -0.5, 12.0), 20.0, 0, 1.05, WOOD, 3.4)
	for at: Vector2 in [Vector2(-24.4, 14.0), Vector2(24.4, 26.0)]:
		lanterne(parts, Vector3(at.x, 0.0, at.y), 2.8, 11.0)
	caisses(parts, Vector3(-23.2, 0.0, 21.0), 84.0)
	caisses(parts, Vector3(22.4, 0.0, 16.5), -78.0)
	filets(parts, Vector3(-13.0, 0.0, 34.0), 22.0)

## LA DIGUE. Quatorze metres entre deux bassins vides : apres le parvis, ca
## doit se resserrer. C'est la que les gobelins attendent.
func _digue(parts: Array[SkinPart]) -> void:
	for index: int in 9:
		var z: float = 37.0 + float(index) * 3.0
		borne(parts, Vector3(-6.4, 0.0, z))
		borne(parts, Vector3(6.4, 0.0, z))
	for z: float in [41.0, 51.0, 59.0]:
		lanterne(parts, Vector3(-6.0, 0.0, z), 3.2, 9.0)
	tas(parts, Vector3(4.0, 0.0, 45.0), 1.1, 1.1)
	tas(parts, Vector3(-3.5, 0.0, 55.0), 1.3, 1.2)
	rubble(parts, Vector3(0.0, 0.0, 48.0), 1.4)
	coque(parts, Vector3(0.0, 0.0, 61.0), 84.0, 6.0)
	# LE PONT. La digue etait un couloir de vingt-six metres a ciel ouvert avec
	# rien au-dessus. Un pont qui l'enjambe lui donne un dessous, une ombre en
	# travers, et un repere qu'on voit aussi bien depuis le parvis que depuis
	# les tables. Ses culees se posent dans les bassins vides, hors du chemin.
	pont(parts, Vector3(0.0, -1.25, 47.0), 20.0, 5.0, 8.45)
	passerelle(parts, Vector3(-9.4, 4.6, 57.0), 18.8, 2.0, 1, [1.1, 17.7])
	ruine(parts, Vector3(-11.0, -1.25, 53.0), 6.0, 5.5, 0)
	pilotis(parts, Vector3(-12.5, -1.25, 38.0), Vector3(0.0, 0.0, 1.0), 6, 3.6)
	pilotis(parts, Vector3(12.5, -1.25, 52.0), Vector3(0.0, 0.0, 1.0), 5, 3.4)
	caisses(parts, Vector3(-5.7, 0.0, 42.0), 88.0)
	filets(parts, Vector3(-5.4, 0.0, 52.0), 90.0)
	etal(parts, Vector3(5.2, 0.0, 49.0), -86.0)

## LES TABLES. La plus grande surface du jeu et la plus vide : une grille de
## vasques separees par des levees basses. On y voit loin, on y est vu de
## loin, et il n'y a nulle part ou se cacher.
func _tables(parts: Array[SkinPart]) -> void:
	for muret: Rect2 in levees():
		var centre: Vector3 = Vector3(muret.position.x + muret.size.x * 0.5,
			MURET_H * 0.5, muret.position.y + muret.size.y * 0.5)
		parts.append(D(SkinPart.Shape.BOX,
			Vector3(muret.size.x, MURET_H, muret.size.y), centre, SALT,
			SkinPart.Surface.STONE))
		parts.append(D(SkinPart.Shape.BOX,
			Vector3(muret.size.x * 0.94, 0.14, muret.size.y * 1.02),
			centre + Vector3(0.0, MURET_H * 0.5, 0.0), SALT_DARK,
			SkinPart.Surface.STONE))
	for at: Vector2 in [Vector2(-23.0, 69.0), Vector2(-10.0, 69.0),
			Vector2(3.0, 69.0), Vector2(16.0, 69.0),
			Vector2(-23.0, 83.0), Vector2(-10.0, 83.0), Vector2(16.0, 83.0),
			Vector2(-23.0, 97.0), Vector2(3.0, 97.0), Vector2(16.0, 97.0)]:
		# PAS de surface emissive ici : quatre-vingt-dix metres carres de
		# turquoise lumineux transformaient les tables en piscine de neon.
		# Une vasque, c'est une pellicule de saumure MOUILLEE — elle reflete,
		# elle ne brille pas.
		parts.append(D(SkinPart.Shape.BOX, Vector3(9.5, 0.05, 9.5),
			Vector3(at.x, 0.03, at.y), BRINE_WET, SkinPart.Surface.LIQUID))
	for at: Vector2 in [Vector2(-26.0, 65.0), Vector2(-2.0, 66.0),
			Vector2(18.0, 74.0), Vector2(-20.0, 88.0), Vector2(6.0, 92.0),
			Vector2(-8.0, 100.0), Vector2(20.0, 99.0)]:
		tas(parts, Vector3(at.x, 0.0, at.y), 2.1, 2.0)
	for at: Vector2 in [Vector2(-13.0, 73.0), Vector2(11.0, 79.0),
			Vector2(-25.0, 93.0), Vector2(1.0, 101.0)]:
		sechoir(parts, Vector3(at.x, 0.0, at.y),
			float(int(at.x * 7.0)) + 40.0)
	for at: Vector2 in [Vector2(-29.0, 76.0), Vector2(-18.5, 84.0),
			Vector2(9.5, 90.0), Vector2(22.0, 66.0), Vector2(-4.5, 96.0)]:
		borne(parts, Vector3(at.x, 0.0, at.y))
	for at: Vector2 in [Vector2(-16.0, 66.0), Vector2(8.0, 86.0),
			Vector2(-24.0, 102.0)]:
		rubble(parts, Vector3(at.x, 0.0, at.y), 1.8)
	# L'ESTACADE. Cinquante-quatre metres sur quarante-deux, tout plat, et rien
	# au-dessus du genou : les tables etaient la zone la plus vide du jeu, et
	# celle ou l'on se perdait. Une passerelle de bois les traverse d'un bord a
	# l'autre a quatre metres — on la voit de partout, donc on sait toujours ou
	# est le milieu.
	#
	# Ses chevalets se posent SUR LES LEVEES, qui sont les seules choses du
	# praticable qui bloquent deja. Les deux trouees de la levee se franchissent
	# sans appui : c'est la que la passerelle se lit comme un pont.
	passerelle(parts, Vector3(-28.0, 5.6, 75.45), 49.0, 2.4, 1,
		[1.0, 6.0, 21.0, 26.0, 41.0, 46.0], true, 6.2)
	escalier(parts, Vector3(-16.55, 0.55, 70.6), 1.0, 13, 0.36, 0.388, 0, 1.0)
	tour(parts, Vector3(-34.5, -0.5, 90.0), 3.4, 14.0, true)
	roue(parts, Vector3(-33.5, -0.5, 68.0), 3.0)
	ruine(parts, Vector3(-33.0, -0.5, 80.0), 6.5, 6.0, 0)
	barriere(parts, Vector3(-30.5, -0.5, 66.0), 26.0, 0, 1.05, WOOD, 3.4)
	for at: Vector2 in [Vector2(-16.5, 67.0), Vector2(-3.5, 99.0)]:
		lanterne(parts, Vector3(at.x, 0.0, at.y), 2.8, 11.0)
	caisses(parts, Vector3(-21.0, 0.0, 76.5), 12.0)
	caisses(parts, Vector3(6.5, 0.0, 92.0), -22.0)
	etal(parts, Vector3(-9.0, 0.0, 76.5), 4.0)

## L'ARENE DU GARDIEN. On rentre sous un toit de douze metres apres quarante
## metres de plein air : le contraste doit faire baisser la tete.
func _arene(parts: Array[SkinPart]) -> void:
	for f: Rect2 in futs():
		var centre: Vector3 = Vector3(f.position.x + f.size.x * 0.5, 0.0,
			f.position.y + f.size.y * 0.5)
		parts.append(D(SkinPart.Shape.CYLINDER, Vector3(1.05, H_ARENE, 1.2),
			centre + Vector3(0.0, H_ARENE * 0.5, 0.0), STONE_PALE,
			SkinPart.Surface.STONE))
		parts.append(D(SkinPart.Shape.TORUS, Vector3(1.05, 0.0, 1.35),
			centre + Vector3(0.0, 0.55, 0.0), STONE, SkinPart.Surface.STONE))
	# Huit braseros au lieu de quatre, et rentres dans la salle : a x = 21 ils
	# etaient contre le mur, hors de portee du centre, et l'arene se battait
	# dans le noir. Une arene de cinquante metres sur trente-huit se tient par
	# ses feux, pas par son plafond.
	for at: Vector2 in [Vector2(-21.0, 116.0), Vector2(21.0, 116.0),
			Vector2(-21.0, 147.0), Vector2(21.0, 147.0)]:
		parts.append(D(SkinPart.Shape.CYLINDER, Vector3(0.42, 1.5, 0.30),
			Vector3(at.x, 0.75, at.y), IRON, SkinPart.Surface.METAL))
		parts.append(D(SkinPart.Shape.CYLINDER, Vector3(1.0, 0.42, 0.55),
			Vector3(at.x, 1.66, at.y), IRON, SkinPart.Surface.METAL))
		var feu: SkinPart = D(SkinPart.Shape.CONE, Vector3(0.36, 0.9, 0.0),
			Vector3(at.x, 2.25, at.y), FLAME, SkinPart.Surface.GLOW)
		feu.light_range = 13.0
		parts.append(feu)
	window(parts, Vector3(-24.7, 6.5, 130.0), 90.0, BRINE, 4.0, 6.0)
	window(parts, Vector3(24.7, 6.5, 130.0), 90.0, BRINE, 4.0, 6.0)
	window(parts, Vector3(-24.7, 6.5, 142.0), 90.0, BRINE, 4.0, 6.0)
	window(parts, Vector3(24.7, 6.5, 142.0), 90.0, BRINE, 4.0, 6.0)
	for z: float in [118.0, 130.0, 142.0]:
		chandelier(parts, Vector3(0.0, 8.6, z), H_ARENE, 17.0)

	# LE CERCLE. L'arene etait une boite rose de cinquante metres avec des
	# feux dedans : rien ne disait ou avait lieu le combat, et le boss — qui
	# est la seule chose CHAUDE du jeu — se perdait dans une salle deja tiede
	# partout. Une arene se dessine au sol et se ferme par ses bords.
	var centre_z: float = 132.0
	# Estrade sombre, deux marches, treize metres de rayon.
	for marche: int in 2:
		var r: float = 15.0 - float(marche) * 1.6
		parts.append(D(CY, Vector3(r, 0.20, r),
			Vector3(0.0, 0.10 + float(marche) * 0.20, centre_z),
			STONE.darkened(0.55), M_STONE))
	# Anneau de sel INCRUSTE. Un tore se decrit par ses rayons interieur et
	# exterieur, et l'ecart entre les deux est l'epaisseur du boudin : a 12,1
	# contre 12,9 ca fait un tuyau de quatre-vingts centimetres pose sur le
	# sol — un boudin blanc, pas une incrustation. Vingt-cinq centimetres
	# d'ecart, et enfonce jusqu'a fleur de dalle.
	parts.append(D(TO, Vector3(12.50, 0.0, 12.75),
		Vector3(0.0, 0.46, centre_z), SALT, M_STONE))
	parts.append(D(TO, Vector3(5.90, 0.0, 6.10),
		Vector3(0.0, 0.46, centre_z), SALT_DARK, M_STONE))
	# Huit piles de sel autour du cercle, chacune coiffee d'une vasque. Elles
	# ferment l'arene sans la reduire, et elles portent le feu a hauteur de
	# regard au lieu de le laisser au sol.
	for index: int in 8:
		var angle: float = deg_to_rad(22.5 + float(index) * 45.0)
		var at: Vector3 = Vector3(sin(angle) * 16.5, 0.0,
			centre_z + cos(angle) * 15.0)
		parts.append(D(CY, Vector3(0.62, 4.4, 0.78),
			at + Vector3(0.0, 2.2, 0.0), SALT_DARK, M_STONE))
		parts.append(D(TO, Vector3(0.62, 0.0, 1.05),
			at + Vector3(0.0, 4.3, 0.0), IRON, M_METAL))
		# La flamme est PETITE. A 0,86 de rayon sur 1,7 de haut, un cone
		# emissif ne se lit pas comme un feu : c'est un triangle jaune plat,
		# et huit triangles jaunes plats font une guirlande de fanions.
		var vasque: SkinPart = D(CO, Vector3(0.40, 0.95, 0.0),
			at + Vector3(0.0, 4.85, 0.0), FLAME, M_GLOW)
		vasque.light_range = 17.0
		parts.append(vasque)
		parts.append(D(SkinPart.Shape.SPHERE, Vector3(0.26, 0.0, 0.0),
			at + Vector3(0.0, 4.52, 0.0), CANDLE, M_GLOW))
	# Chaines pendues du plafond tout autour : c'est la hauteur de l'arene qui
	# devient lisible, et ce qui fait qu'on leve les yeux en entrant.
	for index: int in 10:
		var angle: float = deg_to_rad(float(index) * 36.0)
		chaine(parts, Vector3(sin(angle) * 19.0, H_ARENE - 0.4,
			centre_z + cos(angle) * 17.0), 3.6 + float(index % 3) * 1.1, 2)
	# Deux grandes bannieres au fond, derriere le boss.
	for x: float in [-7.0, 7.0]:
		banniere(parts, Vector3(x, 11.0, 149.2), 3.2, 8.0,
			FLAME.darkened(0.48), 1)
	colombage(parts, Vector3(-25.0, 0.0, 112.0), 38.0, H_ARENE, 0, 1.0, 7.6)
	colombage(parts, Vector3(25.0, 0.0, 112.0), 38.0, H_ARENE, 0, -1.0, 7.6)
	# Les murs nus etaient le second defaut : trente-huit metres de gris plein
	# derriere le boss. On les habille de ce que la halle fabrique — sechoirs
	# ranges, cuves vides, tas de sel abandonnes.
	for at: Vector2 in [Vector2(-23.0, 121.0), Vector2(-23.0, 137.0),
			Vector2(23.0, 121.0), Vector2(23.0, 137.0)]:
		sechoir(parts, Vector3(at.x, 0.0, at.y), 90.0 if at.x < 0.0 else -90.0)
	for at: Vector2 in [Vector2(-22.0, 128.0), Vector2(22.0, 128.0),
			Vector2(-21.0, 146.0)]:
		cuve(parts, Vector3(at.x, 0.0, at.y), 1.3, 1.5)
	coque(parts, Vector3(-12.0, 0.0, 148.0), 20.0, 9.0)
	for at: Vector2 in [Vector2(8.0, 147.0), Vector2(-6.0, 116.0),
			Vector2(14.0, 122.0)]:
		rubble(parts, Vector3(at.x, 0.0, at.y), 2.2)
	for at: Vector2 in [Vector2(-16.0, 147.0), Vector2(19.0, 145.0),
			Vector2(-20.0, 114.0), Vector2(20.0, 114.0)]:
		tas(parts, Vector3(at.x, 0.0, at.y), 2.4, 2.3)
	# Une galerie sur le mur est, et la herse relevee au-dessus de l'entree.
	# Le boss se bat SOUS quelque chose : douze metres de plafond sans rien
	# dessous ne sont pas une hauteur, ce sont douze metres de vide.
	galerie(parts, Vector3(24.7, 7.0, 116.0), 26.0, 2.6, 0, -1.0)
	herse(parts, Vector3(0.0, 5.8, 112.4), 6.0)
	caisses(parts, Vector3(-23.0, 0.0, 142.0), 84.0)


## LE RACCOURCI. Sept metres de large sur cent-neuf de long, le long du bord.
##
## C'etait le pire morceau du niveau, et de tres loin : une ligne droite sans un
## seul evenement, qu'on parcourait le pouce colle en avant sans jamais rien
## decider. Un couloir de sept metres n'a AUCUN moyen d'etre interessant par son
## sol ; ses deux seules dimensions libres sont la HAUTEUR et le RYTHME.
##
## La hauteur : une arcade porte le conduit de saumure tout du long, hors du
## praticable, et jette une ombre en travers du chemin toutes les six travees.
## On sait ou l'on en est parce qu'on compte les arches. Deux passerelles
## l'enjambent, une galerie de bois couvre la derniere ligne droite, une tour
## depasse le tout.
##
## Le rythme : l'arcade est CASSEE au milieu. La voute est tombee en travers du
## couloir, et ce qui en reste oblige a changer de cote — ces quatre blocs sont
## declares a la simulation (voir `encombres`), et ce sont les seuls obstacles
## du niveau qu'on contourne en decidant par ou.
func _raccourci(parts: Array[SkinPart]) -> void:
	# L'arcade, en deux troncons. Ses piles se posent a x = 35,6 : le
	# praticable s'arrete a 33, elles sont donc DEHORS, et seule la masse de la
	# voute survole la tete.
	arcade(parts, Vector3(35.6, -0.55, 14.0), 6, 6.0, 7.55, 2.4, 0)
	arcade(parts, Vector3(35.6, -0.55, 70.0), 6, 6.0, 7.55, 2.4, 0)
	# LA RUPTURE. Une pile penchee, des claveaux tombes en travers du chemin,
	# la saumure qui s'en echappe depuis on ne sait quand. C'est le seul endroit
	# du raccourci ou l'on s'arrete pour regarder.
	var penchee: SkinPart = D(B, Vector3(2.4, 7.6, 1.6),
		Vector3(36.4, 3.35, 58.5), STONE_PALE, M_STONE)
	penchee.rotation_degrees = Vector3(0.0, 0.0, 14.0)
	parts.append(penchee)
	for index: int in 5:
		var claveau: SkinPart = D(B, Vector3(1.9, 0.55, 2.16),
			Vector3(33.4 - float(index) * 1.4, 0.4 + float(index % 2) * 0.5,
				55.6 + float(index) * 1.7), STONE, M_STONE)
		claveau.rotation_degrees = Vector3(float(index) * 22.0 - 44.0,
			float(index) * 14.0, 72.0)
		parts.append(claveau)
	# La roue a augets qui alimentait le conduit. Elle explique l'arcade — un
	# aqueduc sans machine au bout n'est qu'un pont pour personne.
	roue(parts, Vector3(39.5, -0.5, 59.0), 3.2)
	for at: Vector2 in [Vector2(30.0, 55.0), Vector2(28.4, 64.5)]:
		flaque(parts, Vector3(at.x, 0.0, at.y), 1.6)

	# Ce qui encombre. Chaque obstacle declare porte un bloc de decor qui
	# l'habille exactement : le rendu automatique d'un obstacle est une colonne,
	# et une colonne au milieu d'un eboulement ne raconte rien.
	var teintes: Array[Color] = [STONE_PALE, STONE, STONE, SALT]
	var epaisseurs: Array[float] = [1.75, 2.15, 1.65, 1.35]
	var genes: Array[Rect2] = encombres()
	for index: int in genes.size():
		var bloc: Rect2 = genes[index]
		var centre: Vector3 = Vector3(bloc.position.x + bloc.size.x * 0.5, 0.0,
			bloc.position.y + bloc.size.y * 0.5)
		var haut: float = epaisseurs[index]
		var masse: SkinPart = D(B,
			Vector3(bloc.size.x + 0.25, haut, bloc.size.y + 0.25),
			centre + Vector3(0.0, haut * 0.5, 0.0), teintes[index], M_STONE)
		masse.rotation_degrees = Vector3(0.0, float(index) * 5.0 - 7.0, 0.0)
		parts.append(masse)
		rubble(parts, centre, bloc.size.x * 0.66)

	# Les deux passerelles. Elles ne menent nulle part de jouable : elles
	# passent AU-DESSUS, et c'est tout ce qu'on leur demande. On les voit de
	# loin, on marche dessous, on lit d'un coup la hauteur du couloir.
	for z: float in [44.0, 88.0]:
		passerelle(parts, Vector3(24.2, 7.2, z), 12.0, 2.2, 1, [0.9, 11.1])
	# La galerie de bois de la derniere ligne droite : on finit le raccourci a
	# l'ombre, ce qui le distingue de tout ce qui precede.
	galerie(parts, Vector3(26.1, 4.6, 93.0), 18.0, 2.2, 0, 1.0)
	echelle(parts, Vector3(26.6, 0.0, 93.5), 4.4, 0)
	# Le portique, juste avant la grille. Un couloir qui s'arrete a une grille
	# sans rien annoncer s'arrete sans qu'on s'en apercoive.
	for x: float in [25.4, 33.6]:
		parts.append(D(B, Vector3(1.5, 4.5, 1.8), Vector3(x, 1.85, 110.0),
			STONE_PALE, M_STONE))
	voussoirs(parts, Vector3(29.5, 8.1, 110.0), 4.1, PI * 0.5, 8, 0.55, 1.8,
		1, STONE)
	# La tour. Elle se voit depuis les tables, depuis la digue et depuis le
	# parvis : c'est elle qui dit qu'il y a quelque chose de ce cote-la du
	# monde, bien avant qu'on sache que le raccourci existe.
	tour(parts, Vector3(41.0, -0.5, 70.0), 3.8, 16.0, true)
	# Deux pans creves sur le bord ouest : le cote qui n'a pas l'arcade a droit
	# a quelque chose lui aussi.
	ruine(parts, Vector3(24.9, 0.0, 70.0), 7.0, 6.5, 0)

	# A HAUTEUR D'HOMME. Tout ce qui suit se longe : ca colle aux deux
	# parapets et ca laisse la voie libre au milieu. C'est ce qui manquait le
	# plus — on longeait deux murs nus sur cent metres.
	for z: float in [17.0, 71.0, 106.0]:
		lanterne(parts, Vector3(26.6, 0.0, z), 2.7, 10.0)
	for at: Vector2 in [Vector2(32.0, 19.0), Vector2(31.9, 72.0)]:
		caisses(parts, Vector3(at.x, 0.0, at.y),
			90.0 if at.x < 29.5 else -90.0)
	etal(parts, Vector3(27.6, 0.0, 51.0), 88.0)
	filets(parts, Vector3(31.0, 0.0, 29.0), 96.0)
	filets(parts, Vector3(28.2, 0.0, 78.0), 84.0)
	for z: float in [24.0, 76.0]:
		borne(parts, Vector3(32.6, 0.0, z))
	for at: Vector2 in [Vector2(29.2, 21.0), Vector2(28.0, 103.0)]:
		flaque(parts, Vector3(at.x, 0.0, at.y), 1.3)
	# Garde-corps sur la berge est, la ou le sol tombe d'un cran vers le
	# marais. Il ne bloque rien ; il dit ou s'arrete le monde.
	for z: float in [16.0, 94.0]:
		barriere(parts, Vector3(33.6, -0.5, z), 20.0, 0, 1.05, WOOD, 3.2)

## LE SEUIL. Huit metres de large entre les tables et l'arene : le dernier
## goulot, et le seul endroit du niveau ou l'on sait deja qu'on va mourir.
##
## Il n'avait rien du tout — un toit a six metres et deux murs. Ce qui suit en
## fait une PORTE : un portique qu'on passe dessous, deux tours qui l'encadrent,
## deux feux. On doit voir de loin qu'on arrive quelque part.
func _seuil(parts: Array[SkinPart]) -> void:
	for x: float in [-9.2, 9.2]:
		parts.append(D(B, Vector3(1.6, 4.7, 2.0), Vector3(x, 1.85, 104.4),
			STONE_PALE, M_STONE))
	voussoirs(parts, Vector3(0.0, 12.4, 104.4), 8.4, PI * 0.5, 11, 0.62, 2.0,
		1, STONE)
	tour(parts, Vector3(-13.5, -0.5, 108.0), 3.2, 12.0, true)
	tour(parts, Vector3(13.5, -0.5, 108.0), 3.2, 12.0, true)
	for x: float in [-9.4, 9.4]:
		lanterne(parts, Vector3(x, -0.5, 110.5), 2.8, 11.0)
	caisses(parts, Vector3(-6.6, 0.0, 107.0), 84.0)
	etal(parts, Vector3(6.4, 0.0, 106.5), -80.0)
	flaque(parts, Vector3(0.0, 0.0, 108.5), 2.2, false)


# ---------------------------------------------------------------------------
# Les runes du tutoriel
# ---------------------------------------------------------------------------

const RUNE_WARM: Color = Color(1.0, 0.72, 0.30)
const RUNE_COLD: Color = Color(0.42, 0.74, 1.0)
const RUNE_BLOOD: Color = Color(1.0, 0.36, 0.30)

func rune(id: StringName, at: Vector2, radius: float, line: String,
		hint: String, condition: int, tone: Color = RUNE_WARM,
		read_seconds: float = 3.5) -> TutorialSign:
	var sign_: TutorialSign = TutorialSign.new()
	sign_.id = id
	sign_.position = at
	sign_.radius = radius
	sign_.line = line
	sign_.hint = hint
	sign_.condition = condition as TutorialSign.Condition
	sign_.tone = tone
	sign_.read_seconds = read_seconds
	return sign_

## Les runes suivent le chemin, dans l'ordre où on le parcourt. Chacune
## enseigne UNE chose, et s'éteint quand on l'a faite.
##
## L'ordre n'est pas un scénario : rien n'oblige à les croiser dans cet ordre,
## rien n'attend le joueur, et deux joueurs en coopération peuvent en être à
## des runes différentes. C'est le placement qui raconte, pas un compteur.
func build_tutorial() -> TutorialData:
	var data: TutorialData = TutorialData.new()
	# Le niveau s'appelle « salines » depuis la refonte, et le tutoriel se
	# charge par l'identifiant du niveau : un jeu de runes qui se croit encore
	# a la chapelle est une trace de l'ancien monde, rien de plus.
	data.id = &"salines"
	data.signs = [
		rune(&"regarder", Vector2(0.0, -29.0), 5.2,
			"Bouge la souris.",
			"La caméra ne sert pas à voir : elle décide où tu frappes.",
			TutorialSign.Condition.LOOK),
		rune(&"avancer", Vector2(0.0, -25.0), 4.6,
			"ZQSD pour marcher.",
			"Le déplacement suit la caméra, jamais le personnage.",
			TutorialSign.Condition.MOVE),
		rune(&"rouler", Vector2(0.0, -16.5), 4.2,
			"Espace pour rouler.",
			"Tu es invulnérable PENDANT la roulade. Pas avant, pas après.",
			TutorialSign.Condition.DODGE),
		rune(&"frapper", Vector2(3.0, -20.5), 4.0,
			"Ce mannequin ne rend pas les coups.",
			"Clic gauche. C'est le seul adversaire du jeu qui te laissera "
			+ "recommencer.",
			TutorialSign.Condition.ATTACK),
		rune(&"jaune", Vector2(6.0, -23.5), 4.0,
			"Ton arme vire au JAUNE au moment où elle blesse.",
			"Celle des ennemis aussi. C'est le seul repère de rythme du jeu — "
			+ "apprends-le ici, où ça ne coûte rien.",
			TutorialSign.Condition.HIT, RUNE_BLOOD),
		rune(&"seconde", Vector2(0.0, -8.0), 4.2,
			"Clic droit : ta seconde arme.",
			"Chaque classe a la sienne. Elle coûte plus d'endurance.",
			TutorialSign.Condition.SECOND),
		rune(&"feu", Vector2(0.0, 0.5), 4.2,
			"Entre dans l'anneau et appuie sur E.",
			"Le feu te rend ta vie — et replace tous les gobelins. "
			+ "C'est le marché.",
			TutorialSign.Condition.REST, RUNE_COLD),
		rune(&"couloir", Vector2(0.0, 12.4), 4.4,
			"Au-delà, plus rien ne pardonne.",
			"Ils sont six sur les salines. Attire-les un par un ; à deux, "
			+ "tu meurs.",
			TutorialSign.Condition.READ, RUNE_BLOOD, 5.0),
		# Les deux gestes qu'on ne devine pas. Ils sont poses ICI, dans les
		# quatre derniers metres avant le premier gobelin : une touche qu'on
		# apprend loin de ce qu'elle sert ne s'apprend pas.
		rune(&"verrou", Vector2(0.0, 15.6), 3.8,
			"Tab, ou le bouton du milieu : accroche-toi à lui.",
			"Verrouillé, tu lui restes de face. Tu recules, tu tournes "
			+ "autour, tu ne le perds plus.",
			TutorialSign.Condition.READ, RUNE_COLD, 5.5),
		rune(&"pas", Vector2(0.0, 18.2), 3.8,
			"Esquive sans toucher au déplacement : tu sautes en arrière.",
			"Moins d'endurance, moins loin, et tu ne lui tournes jamais le "
			+ "dos. C'est le pas qui sauve à bout portant.",
			TutorialSign.Condition.READ, RUNE_COLD, 5.5),
		rune(&"tuer", Vector2(0.0, 24.0), 4.6,
			"Attends le jaune, roule, PUIS frappe.",
			"Frapper en premier, c'est mourir en premier.",
			TutorialSign.Condition.KILL, RUNE_BLOOD),
		rune(&"endurance", Vector2(0.0, 40.0), 4.4,
			"La barre verte est ton endurance.",
			"À zéro, plus de roulade. C'est comme ça qu'on meurt, pas "
			+ "par manque de vie.",
			TutorialSign.Condition.READ, RUNE_COLD, 5.0),
		rune(&"raccourci", Vector2(19.0, 117.0), 5.0,
			"E sur le levier bleu.",
			"Le raccourci relie l'arène au feu, définitivement. "
			+ "C'est ta seule victoire acquise.",
			TutorialSign.Condition.SHORTCUT, RUNE_COLD),
	]
	return data

# ---------------------------------------------------------------------------

func _init() -> void:
	var skins: Array[SkinData] = [
		build_gardien(), build_mage(), build_soigneur(),
		build_archer(), build_gobelin(), build_warden(), build_mannequin(),
	]
	for skin: SkinData in skins:
		save(skin, "res://data/skins/%s.tres" % skin.id)
	save(build_level(), "res://data/level/vertical_slice.tres")
	var tutorial: TutorialData = build_tutorial()
	save(tutorial, "res://data/tutorial/salines.tres")
	print("tutoriel : %d runes" % tutorial.signs.size())
	var decor: DecorData = build_decor()
	save(decor, "res://data/decor/salines.tres")
	print("décor : %d pièces" % decor.parts.size())
	quit(0)
