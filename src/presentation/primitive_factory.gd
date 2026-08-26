## Fabrique de primitives, de matières et de matériaux.
##
## Personnages, décor et effets tirent tous leurs formes ET leurs matières
## d'ici. C'était trois copies du même `match` avant : une seule liste garantit
## qu'un cône de sorcier et un cône de clocher sont taillés pareil, et qu'une
## épée brille comme une grille.
##
## Les textures sont FABRIQUÉES, jamais chargées : le dépôt ne contient aucune
## image. Un bruit de Perlin projeté en triplanaire donne du grain à la pierre
## et au bois sans qu'aucun fichier ne soit versionné, sans dépliage UV sur des
## primitives qui n'en ont pas, et sans que l'échelle change quand une pièce
## change de taille.
class_name PrimitiveFactory
extends RefCounted

## Taille du motif, en mètres. Assez fin pour qu'un mur ne soit pas un aplat,
## assez large pour ne pas moirer à distance.
const GRAIN_METRES: float = 3.2

static var _albedo: Dictionary[int, NoiseTexture2D] = {}
static var _normals: Dictionary[int, NoiseTexture2D] = {}

static func mesh_for(part: SkinPart) -> Mesh:
	match part.shape:
		SkinPart.Shape.BOX:
			var box: BoxMesh = BoxMesh.new()
			box.size = part.size
			return box
		SkinPart.Shape.PRISM:
			var prism: PrismMesh = PrismMesh.new()
			prism.size = part.size
			return prism
		SkinPart.Shape.CAPSULE:
			var capsule: CapsuleMesh = CapsuleMesh.new()
			capsule.radius = part.size.x
			capsule.height = maxf(part.size.y, part.size.x * 2.0 + 0.01)
			capsule.radial_segments = 14
			capsule.rings = 6
			return capsule
		SkinPart.Shape.SPHERE:
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = part.size.x
			sphere.height = part.size.x * 2.0
			sphere.radial_segments = 16
			sphere.rings = 8
			return sphere
		SkinPart.Shape.ELLIPSOID:
			# Sphère unitaire ; l'étirement se fait par l'échelle de
			# l'instance, ce qui permet de partager le même maillage entre
			# une tête, un torse et un ventre.
			var blob: SphereMesh = SphereMesh.new()
			blob.radius = 0.5
			blob.height = 1.0
			blob.radial_segments = 16
			blob.rings = 8
			return blob
		SkinPart.Shape.CYLINDER:
			var cylinder: CylinderMesh = CylinderMesh.new()
			cylinder.top_radius = part.size.x
			cylinder.bottom_radius = part.size.z
			cylinder.height = part.size.y
			cylinder.radial_segments = 14
			cylinder.rings = 1
			return cylinder
		SkinPart.Shape.CONE:
			var cone: CylinderMesh = CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = part.size.x
			cone.height = part.size.y
			cone.radial_segments = 14
			cone.rings = 1
			return cone
		SkinPart.Shape.TORUS:
			var torus: TorusMesh = TorusMesh.new()
			torus.inner_radius = part.size.x
			torus.outer_radius = maxf(part.size.z, part.size.x + 0.02)
			torus.rings = 20
			torus.ring_segments = 8
			return torus
		_:
			return null

# ---------------------------------------------------------------------------
# Matières
# ---------------------------------------------------------------------------

## Grain d'une matière : fréquence du bruit, force du relief, contraste du
## grain sur la couleur. Trois nombres par matière, et rien d'autre à retenir.
##
## Le contraste reste FAIBLE, volontairement. Un bruit à pleine amplitude ne
## fait pas de la pierre, il fait du camouflage : on voit les taches et plus
## la forme. Le grain doit se deviner de près et disparaître de loin.
const GRAIN: Dictionary[int, Vector3] = {
	SkinPart.Surface.STONE: Vector3(5.0, 0.15, 0.16),
	SkinPart.Surface.WOOD: Vector3(2.2, 0.20, 0.22),
	SkinPart.Surface.METAL: Vector3(9.0, 0.06, 0.08),
	SkinPart.Surface.CLOTH: Vector3(7.0, 0.09, 0.11),
}

## Rugosité et métallicité par matière.
const FINISH: Dictionary[int, Vector2] = {
	SkinPart.Surface.PLAIN: Vector2(0.80, 0.0),
	SkinPart.Surface.STONE: Vector2(0.94, 0.0),
	SkinPart.Surface.WOOD: Vector2(0.86, 0.0),
	# Métallicité volontairement basse. À 0,9, un métal ne tire sa couleur QUE
	# de ce qu'il reflète — et cette scène n'a ni ciel ni sonde de réflexion,
	# donc il reflète du noir. Un heaume devenait une bille de plastique noir.
	# À 0,38 avec une réflexion spéculaire forte, il brille sans s'éteindre.
	SkinPart.Surface.METAL: Vector2(0.42, 0.38),
	SkinPart.Surface.CLOTH: Vector2(0.97, 0.0),
	SkinPart.Surface.GLOW: Vector2(1.0, 0.0),
	# Saumure : quasiment un miroir. Il y a désormais un ciel et une sonde de
	# radiance, donc une nappe lisse renvoie autre chose que du noir — et ce
	# qu'elle renvoie, au crépuscule, est la plus belle chose du niveau.
	# 0,06 faisait un MIROIR PARFAIT. Dehors c'est splendide ; dans une halle
	# couverte, un miroir parfait ne reflete rien du tout et les flaques
	# devenaient des trous noirs a lisere blanc — des bouches d'egout. A 0,22
	# le reflet s'etale assez pour attraper les torches.
	SkinPart.Surface.LIQUID: Vector2(0.30, 0.0),
}

static func _noise(surface: SkinPart.Surface, bumpy: bool) -> NoiseTexture2D:
	var cache: Dictionary[int, NoiseTexture2D] = _normals if bumpy else _albedo
	if cache.has(surface):
		return cache[surface]
	var grain: Vector3 = GRAIN.get(surface, Vector3(1.0, 0.4, 0.2))
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.010 * grain.x
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.55
	# Le bois se lit en veines : un bruit étiré dans un seul axe, et non des
	# taches, sinon une poutre a l'air d'une éponge.
	if surface == SkinPart.Surface.WOOD:
		noise.domain_warp_enabled = true
		noise.domain_warp_amplitude = 60.0
	var texture: NoiseTexture2D = NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	if bumpy:
		texture.as_normal_map = true
		texture.bump_strength = grain.y * 16.0
	else:
		# Sans rampe, le bruit va de 0 à 1 : multiplié à la couleur, il la
		# divise par deux en moyenne ET la fait varier du simple au triple.
		# La rampe le comprime dans [1 - contraste, 1], ce qui en fait une
		# modulation et non un motif.
		texture.color_ramp = _ramp(1.0 - grain.z)
	cache[surface] = texture
	return texture

static func _ramp(floor_value: float) -> Gradient:
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(floor_value, floor_value, floor_value))
	ramp.set_color(1, Color.WHITE)
	return ramp

static func material_for(color: Color, unshaded: bool,
		surface: SkinPart.Surface = SkinPart.Surface.PLAIN,
		emission: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		return material

	# Éclairage par pixel. C'était par sommet : sur des boîtes de six faces,
	# cela revenait à peindre chaque face d'un aplat, ce qui donnait
	# exactement l'aspect de carton dont on voulait sortir.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	# LISERÉ DE BORD. Un objet vu à contre-jour n'est pas une découpe noire :
	# le bord de sa silhouette attrape toujours un peu de ciel. Sans ce terme,
	# tout ce qui n'est pas éclairé de face disparaît en aplat sombre, et à
	# contre-jour d'un soleil rasant c'est la moitié du décor.
	material.rim_enabled = true
	material.rim = 0.30
	material.rim_tint = 0.35
	var finish: Vector2 = FINISH.get(surface, Vector2(0.8, 0.0))
	material.roughness = finish.x
	material.metallic = finish.y
	# Le métal accroche des reflets nets ; le reste, non.
	material.metallic_specular = 0.85 if surface == SkinPart.Surface.METAL else 0.42
	if surface == SkinPart.Surface.LIQUID:
		# Réflexion franche, et pas de grain : une nappe d'eau salée au repos
		# n'a pas de matière propre, elle n'a qu'un reflet.
		material.metallic_specular = 1.0
		material.rim_enabled = true
		material.rim = 0.9
		material.rim_tint = 0.1
		return material

	if GRAIN.has(surface):
		var grain: Vector3 = GRAIN[surface]
		material.albedo_texture = _noise(surface, false)
		material.normal_enabled = true
		material.normal_texture = _noise(surface, true)
		material.normal_scale = grain.y
		# La rampe assombrit de `contraste / 2` en moyenne : on rend cela à la
		# couleur, pour que la teinte demandée dans le .tres soit celle qu'on
		# voit à l'écran.
		material.albedo_color = color.lightened(grain.z * 0.5)
		# Triplanaire : la primitive n'a pas de dépliage utile, et l'échelle
		# doit suivre le monde, pas la boîte. Une colonne de six mètres et un
		# pavé de un mètre partagent alors le même grain.
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE / GRAIN_METRES
		material.uv1_world_triplanar = true

	if surface == SkinPart.Surface.GLOW or emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission if emission > 0.0 else 1.15

	return material

## Instance posée à son offset et à sa rotation, matériau déjà appliqué.
## `color` est passée à part : une même pièce sert à quatre joueurs de quatre
## couleurs, la ressource ne peut donc pas porter la couleur finale.
static func instance_for(part: SkinPart, color: Color) -> MeshInstance3D:
	var mesh: Mesh = mesh_for(part)
	if mesh == null:
		return null
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	# Une pièce qui éclaire loin brille fort. Un seul nombre par pièce
	# lumineuse — sa portée — décide donc à la fois de sa lueur et de sa
	# lampe : un vitrail qui baigne la nef ne peut pas être terne, et une
	# bougie qui n'éclaire qu'elle-même ne peut pas éblouir.
	instance.material_override = material_for(color, part.unshaded, part.surface,
		0.0 if part.light_range <= 0.0 else 1.15 + part.light_range * 0.13)
	instance.position = part.offset
	instance.rotation = Vector3(
		deg_to_rad(part.rotation_degrees.x),
		deg_to_rad(part.rotation_degrees.y),
		deg_to_rad(part.rotation_degrees.z))
	if part.shape == SkinPart.Shape.ELLIPSOID:
		instance.scale = part.size
	# Une pièce émissive n'a pas à s'assombrir elle-même, et une pièce de
	# décor lointaine ne mérite pas le coût d'une ombre portée.
	if part.surface == SkinPart.Surface.GLOW or part.unshaded:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

## Couleur finale d'une pièce, teinte de classe appliquée.
static func color_for(part: SkinPart, tint: Color) -> Color:
	if not part.tinted:
		return part.color
	if part.tint_shift >= 0.0:
		return tint.lightened(part.tint_shift)
	return tint.darkened(-part.tint_shift)
