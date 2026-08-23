## Fabrique de primitives et de matériaux.
##
## Personnages, décor et effets tirent tous leurs formes d'ici. C'était trois
## copies du même `match` avant : une seule liste de formes garantit qu'un
## cône de sorcier et un cône de clocher sont taillés pareil.
class_name PrimitiveFactory
extends RefCounted

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
			capsule.radial_segments = 8
			capsule.rings = 3
			return capsule
		SkinPart.Shape.SPHERE:
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = part.size.x
			sphere.height = part.size.x * 2.0
			sphere.radial_segments = 8
			sphere.rings = 4
			return sphere
		SkinPart.Shape.CYLINDER:
			var cylinder: CylinderMesh = CylinderMesh.new()
			cylinder.top_radius = part.size.x
			cylinder.bottom_radius = part.size.z
			cylinder.height = part.size.y
			cylinder.radial_segments = 8
			cylinder.rings = 1
			return cylinder
		SkinPart.Shape.CONE:
			var cone: CylinderMesh = CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = part.size.x
			cone.height = part.size.y
			cone.radial_segments = 8
			cone.rings = 1
			return cone
		SkinPart.Shape.TORUS:
			var torus: TorusMesh = TorusMesh.new()
			torus.inner_radius = part.size.x
			torus.outer_radius = maxf(part.size.z, part.size.x + 0.02)
			torus.rings = 12
			torus.ring_segments = 5
			return torus
		_:
			return null

static func material_for(color: Color, unshaded: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	# Éclairage par sommet : c'est la direction artistique PS1/PS2 demandée,
	# et c'est aussi ce qui coûte le moins cher à afficher.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded \
		else BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
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
	instance.material_override = material_for(color, part.unshaded)
	instance.position = part.offset
	instance.rotation = Vector3(
		deg_to_rad(part.rotation_degrees.x),
		deg_to_rad(part.rotation_degrees.y),
		deg_to_rad(part.rotation_degrees.z))
	return instance

## Couleur finale d'une pièce, teinte de classe appliquée.
static func color_for(part: SkinPart, tint: Color) -> Color:
	if not part.tinted:
		return part.color
	if part.tint_shift >= 0.0:
		return tint.lightened(part.tint_shift)
	return tint.darkened(-part.tint_shift)
