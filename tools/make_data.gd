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
const IRON: Color = Color(0.30, 0.29, 0.32)
const STEEL: Color = Color(0.62, 0.64, 0.68)
const GOLD: Color = Color(0.78, 0.62, 0.28)
const LEATHER: Color = Color(0.28, 0.20, 0.14)
const SKIN_TONE: Color = Color(0.76, 0.60, 0.48)
const WOOD: Color = Color(0.25, 0.17, 0.12)
const STONE: Color = Color(0.42, 0.42, 0.43)
const STONE_PALE: Color = Color(0.54, 0.54, 0.54)
const FLAME: Color = Color(1.0, 0.44, 0.13)
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

func save(resource: Resource, path: String) -> void:
	var code: int = ResourceSaver.save(resource, path)
	if code != OK:
		printerr("échec %s : %d" % [path, code])
	else:
		print("écrit %s" % path)

# ---------------------------------------------------------------------------
# Personnages
# ---------------------------------------------------------------------------

## Humanoïde de base, mis à l'échelle. Toutes les classes en héritent : deux
## personnages qui ne partagent pas leur ossature ne se ressemblent jamais
## assez pour qu'on croie au même monde.
func humanoid(k: float, flesh: Color) -> SkinData:
	var skin: SkinData = SkinData.new()
	skin.neck = Vector3(0.0, 1.46 * k, 0.0)
	skin.shoulder = Vector3(0.34 * k, 1.32 * k, 0.0)
	skin.elbow_drop = 0.34 * k
	skin.hip = Vector3(0.17 * k, 0.86 * k, 0.0)
	skin.knee_drop = 0.42 * k
	skin.stride_degrees = 34.0
	skin.idle_bob = 0.022 * k

	skin.parts = [
		# Buste : bassin, cage, plastron. Trois volumes plutôt qu'un, pour que
		# la taille se marque et que la silhouette ait un creux.
		P(R_STATIC, B, Vector3(0.42, 0.24, 0.29) * k, Vector3(0, 0.90, 0) * k,
			Color.WHITE, true, -0.38, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.36, 0.16, 0.26) * k, Vector3(0, 1.02, 0) * k,
			Color.WHITE, true, -0.30, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.53, 0.44, 0.32) * k, Vector3(0, 1.22, 0) * k,
			Color.WHITE, true, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.30, 0.34, 0.05) * k, Vector3(0, 1.24, -0.18) * k,
			Color.WHITE, true, 0.30, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.20, 0.10, 0.03) * k, Vector3(0, 1.40, -0.18) * k,
			Color.WHITE, true, -0.42, false, false, Vector3.ZERO, M_CLOTH),
		# Cou : sans lui la tête est posée sur les épaules comme un colis.
		P(R_STATIC, CY, Vector3(0.07, 0.10, 0.07) * k, Vector3(0, 1.44, 0) * k,
			flesh),
		# Tête : crâne, mâchoire, nez, yeux. Ce sont les yeux qui font qu'on
		# regarde un visage plutôt qu'un cube.
		P(R_HEAD, B, Vector3(0.26, 0.22, 0.27) * k, Vector3(0, 0.19, 0) * k,
			flesh),
		P(R_HEAD, B, Vector3(0.22, 0.10, 0.24) * k, Vector3(0, 0.06, -0.01) * k,
			flesh),
		P(R_HEAD, B, Vector3(0.05, 0.07, 0.05) * k, Vector3(0, 0.11, -0.14) * k,
			flesh),
		P(R_HEAD, B, Vector3(0.05, 0.035, 0.02) * k, Vector3(0.07, 0.19, -0.135) * k,
			Color(0.09, 0.09, 0.11)),
		P(R_HEAD, B, Vector3(0.05, 0.035, 0.02) * k, Vector3(-0.07, 0.19, -0.135) * k,
			Color(0.09, 0.09, 0.11)),
		# Bras : épaule, biceps.
		P(R_AR, B, Vector3(0.13, 0.32, 0.14) * k, Vector3(0, -0.16, 0) * k,
			Color.WHITE, true, -0.22, false, false, Vector3.ZERO, M_CLOTH),
		P(R_AL, B, Vector3(0.13, 0.32, 0.14) * k, Vector3(0, -0.16, 0) * k,
			Color.WHITE, true, -0.22, false, false, Vector3.ZERO, M_CLOTH),
		P(R_AR, C, Vector3(0.11, 0.20, 0.0) * k, Vector3(0.03, 0.02, 0) * k,
			Color.WHITE, true, 0.18, false, false, Vector3(0, 0, 78), M_METAL),
		P(R_AL, C, Vector3(0.11, 0.20, 0.0) * k, Vector3(-0.03, 0.02, 0) * k,
			Color.WHITE, true, 0.18, false, false, Vector3(0, 0, 78), M_METAL),
		# Avant-bras, brassard, main.
		P(R_FR, B, Vector3(0.11, 0.28, 0.12) * k, Vector3(0, -0.15, 0) * k,
			Color.WHITE, true, -0.34, false, false, Vector3.ZERO, M_CLOTH),
		P(R_FL, B, Vector3(0.11, 0.28, 0.12) * k, Vector3(0, -0.15, 0) * k,
			Color.WHITE, true, -0.34, false, false, Vector3.ZERO, M_CLOTH),
		P(R_FR, B, Vector3(0.13, 0.09, 0.14) * k, Vector3(0, -0.06, 0) * k,
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_FL, B, Vector3(0.13, 0.09, 0.14) * k, Vector3(0, -0.06, 0) * k,
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_FR, B, Vector3(0.11, 0.13, 0.13) * k, Vector3(0, -0.31, -0.01) * k,
			flesh),
		P(R_FL, B, Vector3(0.11, 0.13, 0.13) * k, Vector3(0, -0.31, -0.01) * k,
			flesh),
		# Jambes : cuisse, genou, tibia, botte.
		P(R_TR, B, Vector3(0.16, 0.40, 0.18) * k, Vector3(0, -0.19, 0) * k,
			Color.WHITE, true, -0.28, false, false, Vector3.ZERO, M_CLOTH),
		P(R_TL, B, Vector3(0.16, 0.40, 0.18) * k, Vector3(0, -0.19, 0) * k,
			Color.WHITE, true, -0.28, false, false, Vector3.ZERO, M_CLOTH),
		P(R_SR, B, Vector3(0.15, 0.09, 0.16) * k, Vector3(0, -0.01, -0.01) * k,
			Color.WHITE, true, 0.10, false, false, Vector3.ZERO, M_METAL),
		P(R_SL, B, Vector3(0.15, 0.09, 0.16) * k, Vector3(0, -0.01, -0.01) * k,
			Color.WHITE, true, 0.10, false, false, Vector3.ZERO, M_METAL),
		P(R_SR, B, Vector3(0.13, 0.38, 0.14) * k, Vector3(0, -0.21, 0) * k,
			Color.WHITE, true, -0.44, false, false, Vector3.ZERO, M_CLOTH),
		P(R_SL, B, Vector3(0.13, 0.38, 0.14) * k, Vector3(0, -0.21, 0) * k,
			Color.WHITE, true, -0.44, false, false, Vector3.ZERO, M_CLOTH),
		P(R_SR, B, Vector3(0.16, 0.12, 0.28) * k, Vector3(0, -0.39, -0.05) * k,
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_SL, B, Vector3(0.16, 0.12, 0.28) * k, Vector3(0, -0.39, -0.05) * k,
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
	]
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
		# Heaume fermé à crête et fente lumineuse.
		P(R_HEAD, B, Vector3(0.30, 0.30, 0.31), Vector3(0, 0.18, 0),
			Color.WHITE, true, -0.20, false, false, Vector3.ZERO, M_METAL),
		P(R_HEAD, B, Vector3(0.31, 0.12, 0.32), Vector3(0, 0.34, 0),
			STEEL, false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_HEAD, PR, Vector3(0.08, 0.20, 0.34), Vector3(0, 0.48, 0),
			Color.WHITE, true, 0.35, false, false, Vector3.ZERO, M_METAL),
		P(R_HEAD, B, Vector3(0.20, 0.030, 0.02), Vector3(0, 0.20, -0.16),
			Color(1.0, 0.72, 0.34), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		P(R_HEAD, B, Vector3(0.07, 0.18, 0.05), Vector3(0, 0.11, -0.15),
			STEEL, false, 0.0, false, false, Vector3.ZERO, M_METAL),
		# Épée longue : soie, garde, pommeau, lame, pointe.
		P(R_FR, B, Vector3(0.08, 0.08, 0.22), Vector3(0, -0.34, -0.09),
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_FR, S, Vector3(0.06, 0.0, 0.0), Vector3(0, -0.34, 0.03),
			GOLD, false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_FR, B, Vector3(0.28, 0.06, 0.08), Vector3(0, -0.34, -0.21),
			GOLD, false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_FR, B, Vector3(0.11, 0.045, 1.02), Vector3(0, -0.34, -0.76),
			STEEL, false, 0.0, true, false, Vector3.ZERO, M_METAL),
		P(R_FR, PR, Vector3(0.11, 0.045, 0.22), Vector3(0, -0.34, -1.38),
			STEEL, false, 0.0, true, false, Vector3(-90, 0, 0), M_METAL),
		# Écu : planche, bordure, boucle, croix peinte.
		P(R_FL, B, Vector3(0.58, 0.76, 0.07), Vector3(-0.06, -0.24, -0.16),
			Color.WHITE, true, 0.08, false, false, Vector3.ZERO, M_WOOD),
		P(R_FL, B, Vector3(0.62, 0.10, 0.09), Vector3(-0.06, 0.10, -0.16),
			IRON, false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_FL, S, Vector3(0.10, 0.0, 0.0), Vector3(-0.06, -0.24, -0.20),
			IRON, false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_FL, B, Vector3(0.11, 0.60, 0.03), Vector3(-0.06, -0.24, -0.21),
			Color.WHITE, true, 0.45, false, false, Vector3.ZERO, M_CLOTH),
		P(R_FL, B, Vector3(0.42, 0.11, 0.03), Vector3(-0.06, -0.12, -0.21),
			Color.WHITE, true, 0.45, false, false, Vector3.ZERO, M_CLOTH),
		# Cape courte.
		P(R_STATIC, B, Vector3(0.58, 0.62, 0.06), Vector3(0, 1.10, 0.19),
			Color.WHITE, true, -0.40, false, false, Vector3.ZERO, M_CLOTH),
	])
	return s

func build_mage() -> SkinData:
	var s: SkinData = humanoid(0.97, SKIN_TONE)
	s.id = &"mage"
	s.stride_degrees = 31.0
	s.parts.append_array([
		# Chapeau pointu, à bord large et bandeau.
		P(R_HEAD, CY, Vector3(0.36, 0.04, 0.36), Vector3(0, 0.31, 0),
			Color.WHITE, true, -0.34, false, false, Vector3.ZERO, M_CLOTH),
		P(R_HEAD, CO, Vector3(0.20, 0.46, 0.0), Vector3(0, 0.55, 0),
			Color.WHITE, true, -0.30, false, false, Vector3.ZERO, M_CLOTH),
		P(R_HEAD, CY, Vector3(0.205, 0.06, 0.205), Vector3(0, 0.35, 0),
			GOLD, false, 0.0, false, false, Vector3.ZERO, M_METAL),
		# Robe : jupe conique, statique. Elle cache le haut des cuisses, ce qui
		# suffit à ne plus voir de cube au bassin.
		P(R_STATIC, CY, Vector3(0.26, 0.64, 0.46), Vector3(0, 0.60, 0),
			Color.WHITE, true, -0.18, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, CY, Vector3(0.47, 0.05, 0.47), Vector3(0, 0.30, 0),
			Color.WHITE, true, -0.42, false, false, Vector3.ZERO, M_CLOTH),
		# Étole brodée qui tombe devant.
		P(R_STATIC, B, Vector3(0.13, 0.72, 0.04), Vector3(0, 0.96, -0.20),
			GOLD, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.40, 0.09, 0.34), Vector3(0, 1.36, 0),
			Color.WHITE, true, -0.34, false, false, Vector3.ZERO, M_CLOTH),
		# Bâton tenu droit : pommeau, hampe, monture, orbe.
		staff_part(S, Vector3(0.05, 0.0, 0.0), -0.06, IRON, M_METAL),
		staff_part(B, Vector3(0.055, 1.50, 0.055), 0.44, WOOD, M_WOOD),
		staff_part(TO, Vector3(0.10, 0.0, 0.185), 1.16, GOLD, M_METAL, true),
		staff_part(S, Vector3(0.115, 0.0, 0.0), 1.16,
			Color(0.66, 0.40, 1.0), M_GLOW, false, 5.0),
	])
	return s

func build_soigneur() -> SkinData:
	var s: SkinData = humanoid(0.98, SKIN_TONE)
	s.id = &"soigneur"
	s.stride_degrees = 31.0
	s.parts.append_array([
		# Capuche : calotte, pointe, retombée dans le dos.
		P(R_HEAD, B, Vector3(0.33, 0.30, 0.35), Vector3(0, 0.20, 0.03),
			Color.WHITE, true, -0.26, false, false, Vector3.ZERO, M_CLOTH),
		P(R_HEAD, PR, Vector3(0.30, 0.22, 0.30), Vector3(0, 0.38, 0.03),
			Color.WHITE, true, -0.26, false, false, Vector3.ZERO, M_CLOTH),
		P(R_HEAD, B, Vector3(0.28, 0.26, 0.10), Vector3(0, 0.06, 0.19),
			Color.WHITE, true, -0.34, false, false, Vector3.ZERO, M_CLOTH),
		# Ombre du visage sous la capuche : c'est elle qui rend un moine
		# inquiétant plutôt que douillet.
		P(R_HEAD, B, Vector3(0.22, 0.16, 0.03), Vector3(0, 0.16, -0.155),
			Color(0.05, 0.05, 0.07)),
		# Robe et étole.
		P(R_STATIC, CY, Vector3(0.25, 0.62, 0.44), Vector3(0, 0.60, 0),
			Color.WHITE, true, -0.15, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, CY, Vector3(0.45, 0.05, 0.45), Vector3(0, 0.30, 0),
			Color.WHITE, true, -0.40, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.40, 0.09, 0.36), Vector3(0, 1.34, 0),
			Color(0.90, 0.84, 0.60), false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.10, 0.66, 0.03), Vector3(0.13, 1.02, -0.19),
			Color(0.90, 0.84, 0.60), false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.10, 0.66, 0.03), Vector3(-0.13, 1.02, -0.19),
			Color(0.90, 0.84, 0.60), false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		# Croix pectorale, émissive : elle doit briller dans le couloir.
		P(R_STATIC, B, Vector3(0.06, 0.24, 0.03), Vector3(0, 1.20, -0.19),
			Color(1.0, 0.94, 0.60), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		P(R_STATIC, B, Vector3(0.17, 0.06, 0.03), Vector3(0, 1.25, -0.19),
			Color(1.0, 0.94, 0.60), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		# Sceptre : pommeau, hampe, monture, cristal.
		staff_part(S, Vector3(0.045, 0.0, 0.0), -0.06, IRON, M_METAL),
		staff_part(B, Vector3(0.05, 1.20, 0.05), 0.36, WOOD, M_WOOD),
		staff_part(TO, Vector3(0.11, 0.0, 0.20), 0.94, GOLD, M_METAL, true),
		staff_part(S, Vector3(0.115, 0.0, 0.0), 0.94,
			Color(0.36, 1.0, 0.54), M_GLOW, false, 5.0),
	])
	return s

func build_archer() -> SkinData:
	var s: SkinData = humanoid(0.96, SKIN_TONE)
	s.id = &"archer"
	s.stride_degrees = 37.0
	s.parts.append_array([
		# Capuche courte à visière, et masque de bouche.
		P(R_HEAD, B, Vector3(0.31, 0.19, 0.33), Vector3(0, 0.26, 0.02),
			Color.WHITE, true, -0.30, false, false, Vector3.ZERO, M_CLOTH),
		P(R_HEAD, B, Vector3(0.29, 0.05, 0.16), Vector3(0, 0.25, -0.16),
			Color.WHITE, true, -0.40, false, false, Vector3(14, 0, 0), M_CLOTH),
		P(R_HEAD, B, Vector3(0.20, 0.11, 0.20), Vector3(0, 0.07, -0.03),
			Color.WHITE, true, -0.46, false, false, Vector3.ZERO, M_CLOTH),
		# Carquois dans le dos, et ses flèches.
		P(R_STATIC, CY, Vector3(0.085, 0.46, 0.085), Vector3(0.17, 1.24, 0.19),
			LEATHER, false, 0.0, false, false, Vector3(-22, 0, 12), M_CLOTH),
		P(R_STATIC, B, Vector3(0.02, 0.34, 0.02), Vector3(0.20, 1.54, 0.24),
			Color(0.82, 0.78, 0.66), false, 0.0, false, false, Vector3(-22, 0, 12), M_WOOD),
		P(R_STATIC, B, Vector3(0.02, 0.34, 0.02), Vector3(0.14, 1.54, 0.22),
			Color(0.82, 0.78, 0.66), false, 0.0, false, false, Vector3(-22, 0, 12), M_WOOD),
		P(R_STATIC, B, Vector3(0.02, 0.34, 0.02), Vector3(0.23, 1.53, 0.18),
			Color(0.82, 0.78, 0.66), false, 0.0, false, false, Vector3(-22, 0, 12), M_WOOD),
		# Baudrier, ceinture, bourses.
		P(R_STATIC, B, Vector3(0.46, 0.08, 0.32), Vector3(0, 0.96, 0),
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.09, 0.52, 0.04), Vector3(0.06, 1.22, -0.17),
			LEATHER, false, 0.0, false, false, Vector3(0, 0, 22), M_CLOTH),
		P(R_STATIC, B, Vector3(0.14, 0.16, 0.10), Vector3(-0.22, 0.92, 0.04),
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		# Arc : deux branches et la corde.
		P(R_FR, TO, Vector3(0.42, 0.0, 0.48), Vector3(0, -0.33, -0.16),
			WOOD, false, 0.0, true, false, Vector3(0, 90, 0), M_WOOD),
		P(R_FR, B, Vector3(0.012, 0.92, 0.012), Vector3(0.03, -0.33, -0.16),
			Color(0.88, 0.86, 0.78), false, 0.0, true, false, Vector3.ZERO, M_CLOTH),
		P(R_FR, B, Vector3(0.05, 0.14, 0.05), Vector3(0, -0.33, -0.16),
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
	])
	return s

func build_gobelin() -> SkinData:
	var s: SkinData = humanoid(0.68, Color(0.42, 0.58, 0.32))
	s.id = &"gobelin"
	# Court et rapide : la foulée est plus ample que celle d'un homme, sinon un
	# gobelin qui court a l'air de glisser.
	s.stride_degrees = 46.0
	s.idle_bob = 0.030
	var hide: Color = Color(0.40, 0.54, 0.30)
	s.parts.append_array([
		# Grandes oreilles : c'est la silhouette qui doit dire « gobelin » à
		# vingt mètres, pas la couleur.
		P(R_HEAD, PR, Vector3(0.05, 0.22, 0.14), Vector3(0.13, 0.15, 0.02),
			hide, false, 0.0, false, false, Vector3(0, 0, -58)),
		P(R_HEAD, PR, Vector3(0.05, 0.22, 0.14), Vector3(-0.13, 0.15, 0.02),
			hide, false, 0.0, false, false, Vector3(0, 0, 58)),
		# Groin, crocs, yeux jaunes qui luisent dans le noir.
		P(R_HEAD, B, Vector3(0.10, 0.08, 0.09), Vector3(0, 0.10, -0.15), hide),
		P(R_HEAD, B, Vector3(0.02, 0.055, 0.02), Vector3(0.04, 0.045, -0.17),
			Color(0.90, 0.88, 0.76)),
		P(R_HEAD, B, Vector3(0.02, 0.055, 0.02), Vector3(-0.04, 0.045, -0.17),
			Color(0.90, 0.88, 0.76)),
		P(R_HEAD, S, Vector3(0.026, 0.0, 0.0), Vector3(0.06, 0.19, -0.13),
			Color(1.0, 0.86, 0.20), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		P(R_HEAD, S, Vector3(0.026, 0.0, 0.0), Vector3(-0.06, 0.19, -0.13),
			Color(1.0, 0.86, 0.20), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		# Capuche de peau, pagne, bandages.
		P(R_STATIC, B, Vector3(0.36, 0.24, 0.28), Vector3(0, 0.55, 0),
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.30, 0.14, 0.24), Vector3(0, 0.88, 0),
			LEATHER, false, 0.0, false, false, Vector3(0, 0, 8), M_CLOTH),
		P(R_FL, B, Vector3(0.13, 0.14, 0.14), Vector3(0, -0.14, 0),
			Color(0.72, 0.70, 0.60), false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		# Couperet ébréché.
		P(R_FR, B, Vector3(0.05, 0.05, 0.16), Vector3(0, -0.23, -0.06),
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_FR, B, Vector3(0.14, 0.035, 0.46), Vector3(0, -0.23, -0.36),
			Color(0.58, 0.56, 0.52), false, 0.0, true, false, Vector3.ZERO, M_METAL),
		P(R_FR, PR, Vector3(0.14, 0.035, 0.15), Vector3(0, -0.23, -0.65),
			Color(0.58, 0.56, 0.52), false, 0.0, true, false, Vector3(-90, 0, 0), M_METAL),
	])
	return s

func build_warden() -> SkinData:
	var s: SkinData = humanoid(1.28, Color(0.26, 0.22, 0.26))
	s.id = &"warden"
	# Lourd : foulée courte, buste presque immobile à l'arrêt. Un boss qui
	# gigote n'inspire rien.
	s.stride_degrees = 25.0
	s.idle_bob = 0.016
	var bone: Color = Color(0.76, 0.72, 0.58)
	s.parts.append_array([
		# Heaume cornu, fente braise.
		P(R_HEAD, B, Vector3(0.38, 0.38, 0.40), Vector3(0, 0.20, 0),
			Color(0.20, 0.19, 0.23), false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_HEAD, B, Vector3(0.40, 0.10, 0.42), Vector3(0, 0.40, 0),
			Color(0.28, 0.26, 0.30), false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_HEAD, CO, Vector3(0.07, 0.46, 0.0), Vector3(0.20, 0.40, 0.02),
			bone, false, 0.0, false, false, Vector3(0, 0, 36), M_PLAIN),
		P(R_HEAD, CO, Vector3(0.07, 0.46, 0.0), Vector3(-0.20, 0.40, 0.02),
			bone, false, 0.0, false, false, Vector3(0, 0, -36), M_PLAIN),
		P(R_HEAD, B, Vector3(0.24, 0.035, 0.03), Vector3(0, 0.20, -0.21),
			Color(1.0, 0.36, 0.16), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		P(R_HEAD, B, Vector3(0.05, 0.22, 0.06), Vector3(0, 0.12, -0.20),
			Color(0.28, 0.26, 0.30), false, 0.0, false, false, Vector3.ZERO, M_METAL),
		# Épaulières à pointes.
		P(R_AR, CO, Vector3(0.075, 0.22, 0.0), Vector3(0.10, 0.10, 0),
			bone, false, 0.0, false, false, Vector3(0, 0, 52), M_PLAIN),
		P(R_AL, CO, Vector3(0.075, 0.22, 0.0), Vector3(-0.10, 0.10, 0),
			bone, false, 0.0, false, false, Vector3(0, 0, -52), M_PLAIN),
		# Cape lourde et son collet.
		P(R_STATIC, B, Vector3(0.76, 1.14, 0.07), Vector3(0, 1.10, 0.24),
			Color.WHITE, true, -0.48, false, false, Vector3.ZERO, M_CLOTH),
		P(R_STATIC, B, Vector3(0.84, 0.14, 0.42), Vector3(0, 1.66, 0.06),
			Color.WHITE, true, -0.30, false, false, Vector3.ZERO, M_CLOTH),
		# Braise du cœur, sous le plastron : elle dit qu'il n'est pas humain.
		P(R_STATIC, S, Vector3(0.09, 0.0, 0.0), Vector3(0, 1.26, -0.20),
			Color(1.0, 0.34, 0.12), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		# Espadon : poignée, garde, lame, pointe.
		P(R_FR, B, Vector3(0.09, 0.09, 0.40), Vector3(0, -0.42, -0.16),
			LEATHER, false, 0.0, false, false, Vector3.ZERO, M_CLOTH),
		P(R_FR, B, Vector3(0.48, 0.08, 0.10), Vector3(0, -0.42, -0.38),
			Color(0.44, 0.40, 0.36), false, 0.0, false, false, Vector3.ZERO, M_METAL),
		P(R_FR, B, Vector3(0.17, 0.055, 1.66), Vector3(0, -0.42, -1.26),
			Color(0.68, 0.66, 0.64), false, 0.0, true, false, Vector3.ZERO, M_METAL),
		P(R_FR, B, Vector3(0.045, 0.06, 1.50), Vector3(0, -0.42, -1.20),
			Color(1.0, 0.34, 0.12), false, 0.0, false, false, Vector3.ZERO, M_GLOW),
		P(R_FR, PR, Vector3(0.17, 0.055, 0.30), Vector3(0, -0.42, -2.24),
			Color(0.68, 0.66, 0.64), false, 0.0, true, false, Vector3(-90, 0, 0), M_METAL),
	])
	return s

# ---------------------------------------------------------------------------
# Le niveau : la chapelle abandonnée
# ---------------------------------------------------------------------------

const NEF: Rect2 = Rect2(-9, -18, 18, 20)
const CHOEUR: Rect2 = Rect2(-6, 2, 12, 5)
const COULOIR: Rect2 = Rect2(0, 7, 6, 31)
const ARENE: Rect2 = Rect2(-18, 38, 32, 24)
const RACCOURCI: Rect2 = Rect2(-18, -6, 6, 44)
const PORTE: Rect2 = Rect2(-12, -6, 3, 3)

const H_NEF: float = 7.6
const H_CHOEUR: float = 5.8
const H_COULOIR: float = 3.6
const H_ARENE: float = 6.6

## Abscisse des deux rangs de colonnes de la nef, et leurs ordonnées.
const COLONNES_X: Array = [-6.5, 6.5]
const COLONNES_Z: Array = [-15.0, -11.0, -7.0, -3.0]

## Autel et braseros. Ils bloquent, donc ils sont déclarés ici et DESSINÉS à
## partir d'ici : le décor ne pose que ce qui se traverse.
const AUTEL: Rect2 = Rect2(-4.3, 4.85, 2.6, 1.5)
const BRASERO_G: Rect2 = Rect2(-5.42, 3.58, 0.84, 0.84)
const BRASERO_D: Rect2 = Rect2(4.58, 3.58, 0.84, 0.84)

func columns() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for x: float in COLONNES_X:
		for z: float in COLONNES_Z:
			out.append(Rect2(x - 0.6, z - 0.6, 1.2, 1.2))
	return out

func build_level() -> LevelData:
	var level: LevelData = LevelData.new()
	level.id = &"chapelle"
	level.walkable = [NEF, CHOEUR, COULOIR, ARENE, RACCOURCI, PORTE]
	level.ceiling_heights = [H_NEF, H_CHOEUR, H_COULOIR, H_ARENE,
		H_COULOIR, H_COULOIR]
	level.default_ceiling = H_COULOIR

	var solides: Array[Rect2] = columns()
	var hauteurs: Array[float] = []
	for _c: Rect2 in solides:
		hauteurs.append(0.0)
	solides.append_array([AUTEL, BRASERO_G, BRASERO_D])
	hauteurs.append_array([1.35, 1.30, 1.30])
	level.obstacles = solides
	level.obstacle_heights = hauteurs

	level.shortcut_gate = Rect2(-18, 36, 6, 4)
	level.bonfire_position = Vector2(-3, 3.4)
	level.bonfire_radius = 3.0
	level.shortcut_switch_position = Vector2(-15, 41)
	level.shortcut_switch_radius = 2.5
	level.player_spawns = [
		Vector2(-1.6, -12.0), Vector2(1.6, -12.0),
		Vector2(-1.6, -14.6), Vector2(1.6, -14.6),
	]
	level.enemy_spawns = [Vector2(3.0, 15.0), Vector2(1.8, 26.0), Vector2(4.2, 35.0)]
	level.boss_spawn = Vector2(0, 54)
	return level

# ---------------------------------------------------------------------------
# Motifs de décor
# ---------------------------------------------------------------------------

## Arc en plein cintre, approché par `steps` claveaux. C'est le motif qui fait
## une église : sans arcs, une nef n'est qu'un couloir haut.
func arch(out: Array[SkinPart], centre: Vector3, radius: float, depth: float,
		thickness: float, steps: int, tone: Color) -> void:
	for index: int in steps:
		var angle: float = PI * (float(index) + 0.5) / float(steps)
		var at: Vector3 = centre + Vector3(
			cos(angle) * radius, sin(angle) * radius, 0.0)
		# Corde du claveau : deux voisins doivent se toucher, jamais laisser
		# de fente — une fente dans un arc se voit de l'autre bout de la nef.
		var chord: float = PI * radius / float(steps) * 1.25
		# L'axe long de la boîte est Y ; tourné de l'angle du claveau, il
		# devient TANGENT au cercle, et son épaisseur devient radiale. Tourner
		# de l'angle moins 90° donnerait des lames en étoile, pas un arc.
		out.append(D(B, Vector3(thickness, chord, depth), at, tone, M_STONE,
			Vector3(0.0, 0.0, rad_to_deg(angle))))

## Torche murale : potence, coupe, flamme. La flamme porte la lumière — c'est
## la règle du projet, une lampe naît toujours d'une pièce qu'on voit.
func torch(out: Array[SkinPart], at: Vector3, into: Vector3, reach: float) -> void:
	var bowl: Vector3 = at + into * 0.34
	out.append(D(B, Vector3(0.08, 0.08, 0.40), at + into * 0.16, IRON, M_METAL,
		Vector3(0.0, rad_to_deg(atan2(into.x, into.z)), 0.0)))
	out.append(D(CY, Vector3(0.16, 0.20, 0.09), bowl, IRON, M_METAL))
	out.append(D(S, Vector3(0.075, 0.0, 0.0), bowl + Vector3(0.0, 0.16, 0.0),
		FLAME, M_GLOW, Vector3.ZERO, reach))
	out.append(D(CO, Vector3(0.055, 0.24, 0.0), bowl + Vector3(0.0, 0.27, 0.0),
		Color(1.0, 0.68, 0.26), M_GLOW))

## Lustre suspendu : chaîne, cercle, cierges. Il occupe le haut de la nef, qui
## sans lui est un grand vide noir au-dessus du joueur.
func chandelier(out: Array[SkinPart], at: Vector3, ceiling: float) -> void:
	var drop: float = ceiling - at.y
	out.append(D(B, Vector3(0.05, drop, 0.05),
		Vector3(at.x, at.y + drop * 0.5, at.z), IRON, M_METAL))
	out.append(D(TO, Vector3(0.62, 0.0, 0.74), at, IRON, M_METAL))
	out.append(D(TO, Vector3(0.30, 0.0, 0.38), at + Vector3(0, 0.16, 0),
		IRON, M_METAL))
	for index: int in 6:
		var angle: float = TAU * float(index) / 6.0
		var seat: Vector3 = at + Vector3(cos(angle) * 0.68, 0.10, sin(angle) * 0.68)
		out.append(D(CY, Vector3(0.045, 0.22, 0.045), seat,
			Color(0.88, 0.84, 0.70), M_PLAIN))
		out.append(D(S, Vector3(0.075, 0.0, 0.0), seat + Vector3(0, 0.16, 0),
			CANDLE, M_GLOW, Vector3.ZERO, 7.0 if index == 0 else 0.0))

## Banc renversé ou droit, selon l'inclinaison.
func pew(out: Array[SkinPart], at: Vector3, tilt: float) -> void:
	var turn: Vector3 = Vector3(0.0, tilt, 0.0)
	out.append(D(B, Vector3(3.0, 0.14, 0.48), at + Vector3(0, 0.48, 0), WOOD, M_WOOD, turn))
	out.append(D(B, Vector3(3.0, 0.52, 0.12), at + Vector3(0, 0.75, 0.22), WOOD, M_WOOD, turn))
	out.append(D(B, Vector3(2.9, 0.09, 0.10), at + Vector3(0, 0.30, 0.18), WOOD, M_WOOD, turn))
	for side: int in 2:
		var dx: float = -1.3 if side == 0 else 1.3
		out.append(D(B, Vector3(0.14, 0.48, 0.42), at + Vector3(dx, 0.24, 0), WOOD, M_WOOD, turn))
		out.append(D(B, Vector3(0.18, 0.10, 0.52), at + Vector3(dx, 0.05, 0), WOOD, M_WOOD, turn))

## Tas de gravats : quatre blocs de tailles décroissantes. Déterministe, pas
## tiré au hasard — deux joueurs doivent voir la même ruine.
func rubble(out: Array[SkinPart], at: Vector3, spread: float) -> void:
	for index: int in 5:
		var angle: float = 1.7 * float(index)
		var side: float = 0.62 - 0.09 * float(index)
		out.append(D(B, Vector3(side, side * 0.62, side * 0.86),
			at + Vector3(cos(angle) * spread, side * 0.30, sin(angle) * spread),
			STONE, M_STONE, Vector3(0.0, rad_to_deg(angle) * 0.6, 8.0 * float(index % 3))))

## Vitrail : piédroits, appui, linteau, meneaux, verre émissif.
##
## L'encadrement est fait de QUATRE pièces qui bordent l'ouverture, jamais d'un
## bloc plein posé devant : un bloc plein cache le verre depuis l'intérieur, et
## on se retrouve avec des fenêtres noires dans une église — précisément le
## contraire de ce pour quoi on met un vitrail.
func window(out: Array[SkinPart], at: Vector3, facing: float, tone: Color,
		height: float, reach: float) -> void:
	var turn: Vector3 = Vector3(0.0, facing, 0.0)
	const HALF: float = 0.75
	const JAMB: float = 0.34
	# Verre, légèrement en retrait dans l'épaisseur du mur.
	out.append(D(B, Vector3(0.14, height, HALF * 2.0), at, tone, M_GLOW, turn, reach))
	# Piédroits.
	for side: int in 2:
		var dz: float = -(HALF + JAMB * 0.5) if side == 0 else HALF + JAMB * 0.5
		out.append(D(B, Vector3(0.40, height + 0.7, JAMB),
			at + Vector3(0, 0, dz), STONE_PALE, M_STONE, turn))
	# Appui et linteau.
	out.append(D(B, Vector3(0.46, 0.26, HALF * 2.0 + JAMB * 2.0),
		at + Vector3(0, -height * 0.5 - 0.13, 0), STONE, M_STONE, turn))
	out.append(D(B, Vector3(0.46, 0.26, HALF * 2.0 + JAMB * 2.0),
		at + Vector3(0, height * 0.5 + 0.13, 0), STONE, M_STONE, turn))
	# Meneaux : sans eux le vitrail est une plaque de couleur, pas une fenêtre.
	out.append(D(B, Vector3(0.18, height, 0.07), at,
		Color(0.14, 0.13, 0.15), M_METAL, turn))
	for band: int in 2:
		var dy: float = height * (0.24 if band == 0 else -0.24)
		out.append(D(B, Vector3(0.18, 0.07, HALF * 2.0),
			at + Vector3(0, dy, 0), Color(0.14, 0.13, 0.15), M_METAL, turn))
	# Arc de décharge au-dessus.
	arch(out, at + Vector3(0, height * 0.5 + 0.26, 0), 0.92, 0.46, 0.30, 7,
		STONE_PALE)

## Statue dans une niche : socle, corps drapé, tête, bras croisés. Volontairement
## sommaire — une silhouette humaine immobile dans le noir se lit très bien.
func statue(out: Array[SkinPart], at: Vector3, facing: float) -> void:
	var turn: Vector3 = Vector3(0.0, facing, 0.0)
	out.append(D(B, Vector3(1.10, 0.34, 1.10), at + Vector3(0, 0.17, 0), STONE, M_STONE))
	out.append(D(B, Vector3(0.90, 0.16, 0.90), at + Vector3(0, 0.42, 0), STONE_PALE, M_STONE))
	out.append(D(CY, Vector3(0.26, 1.32, 0.42), at + Vector3(0, 1.16, 0), STONE_PALE, M_STONE, turn))
	out.append(D(B, Vector3(0.46, 0.50, 0.30), at + Vector3(0, 1.62, 0), STONE_PALE, M_STONE, turn))
	out.append(D(B, Vector3(0.26, 0.30, 0.26), at + Vector3(0, 1.98, 0), STONE_PALE, M_STONE, turn))
	out.append(D(B, Vector3(0.52, 0.14, 0.20), at + Vector3(0, 1.50, -0.14), STONE_PALE, M_STONE, turn))
	out.append(D(B, Vector3(0.14, 0.72, 0.14), at + Vector3(0, 1.70, -0.20), STONE, M_STONE, turn))

# ---------------------------------------------------------------------------
# Assemblage du décor
# ---------------------------------------------------------------------------

func build_decor() -> DecorData:
	var decor: DecorData = DecorData.new()
	decor.id = &"chapelle"
	var parts: Array[SkinPart] = []
	_nef(parts)
	_choeur(parts)
	_couloir(parts)
	_arene(parts)
	decor.parts = parts
	return decor

func _nef(parts: Array[SkinPart]) -> void:
	var glass: Array[Color] = [GLASS_BLUE, GLASS_GOLD, GLASS_RED,
		GLASS_GREEN, GLASS_GOLD]
	for side: int in 2:
		var sx: float = -8.6 if side == 0 else 8.6
		var facing: float = 90.0 if side == 0 else -90.0
		for index: int in 5:
			var z: float = -15.6 + float(index) * 3.4
			# Pilastre : base, fût, chapiteau.
			parts.append(D(B, Vector3(0.9, 0.5, 1.3), Vector3(sx, 0.25, z), STONE))
			parts.append(D(B, Vector3(0.7, 5.6, 1.1), Vector3(sx, 3.1, z), STONE_PALE))
			parts.append(D(B, Vector3(0.95, 0.4, 1.35), Vector3(sx, 6.1, z), STONE))
			window(parts, Vector3(sx, 4.4, z + 1.7), facing, glass[index], 2.6, 12.0)
			# Torche une travée sur deux : trop de torches, et le clair-obscur
			# disparaît.
			if index % 2 == 1:
				torch(parts, Vector3(sx, 2.5, z),
					Vector3(1.0 if side == 0 else -1.0, 0.0, 0.0), 11.0)

	# Rosace du fond, derrière les joueurs, avec ses rayons.
	parts.append(D(TO, Vector3(1.85, 0.0, 2.25), Vector3(0, 5.2, -17.6),
		STONE_PALE, M_STONE, Vector3(90, 0, 0)))
	parts.append(D(CY, Vector3(1.9, 0.14, 1.9), Vector3(0, 5.2, -17.55),
		GLASS_GOLD, M_GLOW, Vector3(90, 0, 0), 14.0))
	for index: int in 8:
		var angle: float = PI * float(index) / 8.0
		parts.append(D(B, Vector3(0.13, 3.7, 0.20), Vector3(0, 5.2, -17.5),
			Color(0.16, 0.15, 0.17), M_METAL,
			Vector3(0.0, 0.0, rad_to_deg(angle))))
	parts.append(D(S, Vector3(0.34, 0.0, 0.0), Vector3(0, 5.2, -17.5),
		GLASS_RED, M_GLOW))

	# Arcades entre les colonnes, et leur galerie au-dessus.
	for side: int in 2:
		var sx: float = -6.5 if side == 0 else 6.5
		for index: int in 3:
			var z: float = -13.0 + float(index) * 4.0
			arch(parts, Vector3(sx, 5.0, z), 1.95, 1.15, 0.46, 9, STONE_PALE)
			parts.append(D(B, Vector3(1.25, 0.34, 4.1), Vector3(sx, 7.2, z), STONE))
		# Poutre faîtière : le regard doit avoir quelque chose à suivre en
		# levant la tête.
		parts.append(D(B, Vector3(0.42, 0.42, 19.0), Vector3(sx, 7.35, -8.0),
			WOOD, M_WOOD))
	for index: int in 9:
		var z: float = -16.4 + float(index) * 2.1
		parts.append(D(B, Vector3(13.6, 0.30, 0.34), Vector3(0, 7.34, z),
			WOOD, M_WOOD, Vector3(0, 0, 0)))

	# Lustres.
	chandelier(parts, Vector3(0, 4.6, -13.4), H_NEF)
	chandelier(parts, Vector3(0, 4.6, -7.6), H_NEF)

	# Bannières pendues aux pilastres.
	for side: int in 2:
		var sx: float = -8.0 if side == 0 else 8.0
		for index: int in 2:
			var z: float = -12.2 + float(index) * 6.8
			var tone: Color = Color(0.56, 0.20, 0.22) if index == 0 \
				else Color(0.26, 0.32, 0.60)
			parts.append(D(B, Vector3(0.07, 2.9, 1.15), Vector3(sx, 4.0, z),
				tone, M_CLOTH))
			parts.append(D(PR, Vector3(0.07, 0.55, 1.15), Vector3(sx, 2.28, z),
				tone, M_CLOTH, Vector3(180, 0, 0)))
			parts.append(D(B, Vector3(0.13, 0.13, 1.35), Vector3(sx, 5.5, z),
				IRON, M_METAL))

	# Statues dans les bas-côtés.
	statue(parts, Vector3(-7.6, 0.0, -4.4), 90.0)
	statue(parts, Vector3(7.6, 0.0, -4.4), -90.0)

	# Bancs : deux rangées, dont plusieurs renversés.
	# x, z, inclinaison en degrés.
	var pews: Array[Vector3] = [
		Vector3(-3.6, -14.6, 0.0), Vector3(3.6, -14.6, 0.0),
		Vector3(-3.6, -12.0, 12.0), Vector3(3.6, -11.8, -6.0),
		Vector3(-3.4, -9.2, 0.0), Vector3(3.6, -9.2, 0.0),
		Vector3(-3.7, -6.6, -14.0), Vector3(3.4, -6.4, 9.0),
	]
	for entry: Vector3 in pews:
		pew(parts, Vector3(entry.x, 0.0, entry.y), entry.z)

	# Charpente effondrée et gravats.
	parts.append(D(B, Vector3(0.42, 0.42, 7.4), Vector3(-2.2, 0.6, -4.4),
		WOOD, M_WOOD, Vector3(0, 26, -16)))
	parts.append(D(B, Vector3(0.38, 0.38, 6.0), Vector3(4.4, 0.9, -8.6),
		WOOD, M_WOOD, Vector3(0, -38, 21)))
	parts.append(D(B, Vector3(0.34, 0.34, 5.2), Vector3(-5.6, 1.4, -10.2),
		WOOD, M_WOOD, Vector3(0, 64, 34)))
	rubble(parts, Vector3(-5.4, 0.0, -2.4), 0.85)
	rubble(parts, Vector3(5.9, 0.0, -4.8), 0.7)
	rubble(parts, Vector3(-1.0, 0.0, -16.4), 0.6)
	rubble(parts, Vector3(4.8, 0.0, -13.0), 0.75)

func _choeur(parts: Array[SkinPart]) -> void:
	# L'autel lui-même est un obstacle : il est dessiné par LevelView à partir
	# de son emprise. Ici, seulement ce qui se pose dessus.
	parts.append(D(B, Vector3(0.24, 1.8, 0.24), Vector3(-3.0, 2.15, 5.9), STONE_PALE))
	parts.append(D(B, Vector3(1.05, 0.24, 0.24), Vector3(-3.0, 2.55, 5.9), STONE_PALE))
	parts.append(D(S, Vector3(0.14, 0.0, 0.0), Vector3(-3.0, 3.02, 5.9),
		GLASS_GOLD, M_GLOW, Vector3.ZERO, 7.0))
	for index: int in 3:
		var cx: float = -3.9 + float(index) * 0.9
		parts.append(D(CY, Vector3(0.06, 0.44, 0.07), Vector3(cx, 1.57, 5.3),
			Color(0.90, 0.86, 0.72)))
		parts.append(D(S, Vector3(0.075, 0.0, 0.0), Vector3(cx, 1.85, 5.3),
			CANDLE, M_GLOW, Vector3.ZERO, 5.5))

	# Braseros : la coupe est dessinée par l'obstacle, la flamme est ici.
	for side: int in 2:
		var bx: float = -5.0 if side == 0 else 5.0
		parts.append(D(CY, Vector3(0.46, 0.30, 0.30), Vector3(bx, 1.45, 4.0),
			IRON, M_METAL))
		parts.append(D(S, Vector3(0.19, 0.0, 0.0), Vector3(bx, 1.60, 4.0),
			FLAME, M_GLOW, Vector3.ZERO, 13.0))
		parts.append(D(CO, Vector3(0.13, 0.46, 0.0), Vector3(bx, 1.88, 4.0),
			Color(1.0, 0.70, 0.28), M_GLOW))

	# Marches et abside.
	parts.append(D(B, Vector3(11.6, 0.18, 0.6), Vector3(0, 0.09, 2.3), STONE_PALE))
	parts.append(D(B, Vector3(11.6, 0.18, 0.6), Vector3(0, 0.27, 2.9), STONE_PALE))
	arch(parts, Vector3(0, 2.7, 2.1), 5.4, 1.0, 0.7, 13, STONE)
	window(parts, Vector3(-5.7, 3.4, 5.0), 90.0, GLASS_BLUE, 2.2, 8.0)
	window(parts, Vector3(5.7, 3.4, 5.0), -90.0, GLASS_BLUE, 2.2, 8.0)

	# Chambranle du couloir, gardé par deux torches.
	parts.append(D(B, Vector3(0.6, 3.6, 0.6), Vector3(0.3, 1.8, 7.0), STONE_PALE))
	parts.append(D(B, Vector3(0.6, 3.6, 0.6), Vector3(5.7, 1.8, 7.0), STONE_PALE))
	parts.append(D(B, Vector3(6.2, 0.5, 0.7), Vector3(3.0, 3.5, 7.0), STONE_PALE))
	torch(parts, Vector3(0.3, 2.4, 6.5), Vector3(0, 0, -1), 9.0)
	torch(parts, Vector3(5.7, 2.4, 6.5), Vector3(0, 0, -1), 9.0)
	rubble(parts, Vector3(-5.6, 0.0, 6.2), 0.5)

func _couloir(parts: Array[SkinPart]) -> void:
	# Arcs doubleaux tous les quatre mètres, et une torche entre deux. Sans
	# eux le couloir est un tube, et sans torches il est noir.
	for index: int in 8:
		var z: float = 9.0 + float(index) * 3.8
		arch(parts, Vector3(3.0, 1.9, z), 2.7, 0.55, 0.42, 9, STONE)
		var side: int = index % 2
		var sx: float = 0.34 if side == 0 else 5.66
		torch(parts, Vector3(sx, 2.25, z + 1.9),
			Vector3(1.0 if side == 0 else -1.0, 0.0, 0.0), 7.0)
	rubble(parts, Vector3(1.2, 0.0, 18.6), 0.5)
	rubble(parts, Vector3(4.6, 0.0, 30.2), 0.55)
	parts.append(D(B, Vector3(0.32, 0.32, 3.4), Vector3(2.4, 0.35, 23.0),
		WOOD, M_WOOD, Vector3(0, 72, 18)))

func _arene(parts: Array[SkinPart]) -> void:
	# Colonnes brisées le long des murs : elles disent que l'arène était une
	# salle, et donnent au joueur de quoi se repérer en tournant.
	# x, z, hauteur restante.
	var stumps: Array[Vector3] = [
		Vector3(-14.0, 42.0, 3.4), Vector3(-14.0, 50.0, 2.1), Vector3(-14.0, 58.0, 4.2),
		Vector3(10.0, 42.0, 2.6), Vector3(10.0, 50.0, 4.0), Vector3(10.0, 58.0, 2.2),
		Vector3(-6.0, 60.0, 3.1), Vector3(4.0, 60.0, 3.6),
	]
	for entry: Vector3 in stumps:
		var at: Vector3 = Vector3(entry.x, 0.0, entry.y)
		var height: float = entry.z
		parts.append(D(B, Vector3(1.5, 0.4, 1.5), at + Vector3(0, 0.2, 0), STONE))
		parts.append(D(CY, Vector3(0.52, height, 0.60),
			at + Vector3(0, 0.4 + height * 0.5, 0), STONE_PALE, M_STONE))
		parts.append(D(B, Vector3(1.1, 0.28, 1.1),
			at + Vector3(0, 0.4 + height, 0), STONE, M_STONE,
			Vector3(0, 14.0 * height, 0)))
		rubble(parts, at + Vector3(1.3, 0.0, 0.4), 0.6)

	# Estrade du boss, et le brasier qui l'éclaire par-derrière.
	parts.append(D(B, Vector3(13.0, 0.22, 9.0), Vector3(-2.0, 0.11, 54.0), STONE))
	parts.append(D(B, Vector3(12.0, 0.20, 8.0), Vector3(-2.0, 0.31, 54.0), STONE_PALE))
	for side: int in 2:
		var bx: float = -8.4 if side == 0 else 4.4
		parts.append(D(CY, Vector3(0.20, 1.5, 0.34), Vector3(bx, 0.75, 57.4), IRON, M_METAL))
		parts.append(D(CY, Vector3(0.52, 0.34, 0.34), Vector3(bx, 1.65, 57.4), IRON, M_METAL))
		parts.append(D(S, Vector3(0.21, 0.0, 0.0), Vector3(bx, 1.82, 57.4),
			Color(0.92, 0.30, 0.16), M_GLOW, Vector3.ZERO, 15.0))
		parts.append(D(CO, Vector3(0.15, 0.52, 0.0), Vector3(bx, 2.14, 57.4),
			Color(1.0, 0.48, 0.20), M_GLOW))

	# Braseros muraux : l'arène fait trente mètres sur vingt. Deux feux sur
	# l'estrade en font un décor joli et un combat illisible — on ne peut pas
	# esquiver ce qu'on ne voit pas arriver.
	var walls: Array[Vector3] = [
		Vector3(-17.4, 44.0, 1.0), Vector3(-17.4, 52.0, -1.0),
		Vector3(13.4, 44.0, -1.0), Vector3(13.4, 52.0, 1.0),
		Vector3(-11.0, 61.4, 0.0), Vector3(7.0, 61.4, 0.0),
	]
	for at: Vector3 in walls:
		var seat: Vector3 = Vector3(at.x, 2.30, at.y)
		var into: Vector3 = Vector3(at.z, 0.0, 0.0)
		if is_zero_approx(at.z):
			into = Vector3(0.0, 0.0, -1.0)
		torch(parts, seat, into, 15.0)

	# Torches d'entrée d'arène, et la grille du raccourci signalée par la sienne.
	torch(parts, Vector3(0.34, 2.4, 39.4), Vector3(1, 0, 0), 10.0)
	torch(parts, Vector3(5.66, 2.4, 39.4), Vector3(-1, 0, 0), 10.0)
	torch(parts, Vector3(-17.6, 2.4, 41.0), Vector3(1, 0, 0), 10.0)
	rubble(parts, Vector3(-9.0, 0.0, 45.0), 0.9)
	rubble(parts, Vector3(6.0, 0.0, 47.0), 0.8)
	rubble(parts, Vector3(-3.0, 0.0, 61.0), 0.7)

# ---------------------------------------------------------------------------

func _init() -> void:
	var skins: Array[SkinData] = [
		build_gardien(), build_mage(), build_soigneur(),
		build_archer(), build_gobelin(), build_warden(),
	]
	for skin: SkinData in skins:
		save(skin, "res://data/skins/%s.tres" % skin.id)
	save(build_level(), "res://data/level/vertical_slice.tres")
	var decor: DecorData = build_decor()
	save(decor, "res://data/decor/chapelle.tres")
	print("décor : %d pièces" % decor.parts.size())
	quit(0)
