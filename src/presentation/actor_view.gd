## Représentation visible d'un acteur, assemblée depuis un skin.
##
## Invariant 2 : lecture seule. Cette vue ne décide de rien, elle traduit un
## état de simulation en pose et en couleur.
##
## Un skin ne change RIEN au jeu : ni hitbox, ni portée, ni rayon de collision.
## Il habille un cylindre de simulation, il ne le remplace pas. C'est pourquoi
## il vit dans res://data/skins/ et non dans la fiche de classe.
class_name ActorView
extends Node3D

const COLOR_WEAPON_IDLE: Color = Color(0.62, 0.62, 0.66)
## Une hitbox ouverte doit se voir sans ambiguïté : c'est le seul repère de
## rythme du jeu, et le tutoriel l'enseigne explicitement.
const COLOR_WEAPON_ACTIVE: Color = Color(1.0, 0.85, 0.35)
## Anneau posé sous le personnage local. Les classes ayant chacune sa couleur,
## c'est le seul repère qui dise « c'est toi » sans la contredire.
const COLOR_SELF_RING: Color = Color(0.95, 0.92, 0.70)

## Un acteur situé entre la caméra et le personnage la bouche. On l'estompe
## plutôt que de reculer la caméra, ce qui est impossible quand un ennemi
## poursuit par derrière. Le seuil est relatif au personnage, pas absolu.
const FADE_MARGIN: float = 0.2
const FADE_FULL_AT: float = 1.2
## On n'efface jamais complètement : un ennemi invisible est pire qu'un
## ennemi gênant.
const FADE_FLOOR: float = 0.25

## Nœud portant toutes les pièces. La pose — chute, chancellement, roulade —
## s'applique à lui seul, jamais aux pièces une par une.
var _pose: Node3D
var _materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _weapon_flags: Array[bool] = []
var _stand_height: float = 0.0

func setup(actor: Actor, color: Color, is_local: bool, skin: SkinData) -> void:
	_stand_height = actor.radius * 2.0

	if is_local:
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = actor.radius * 1.05
		ring.outer_radius = actor.radius * 1.30
		ring.rings = 20
		ring.ring_segments = 5
		var marker: MeshInstance3D = MeshInstance3D.new()
		marker.mesh = ring
		marker.material_override = _make_material(COLOR_SELF_RING, false)
		marker.position = Vector3(0.0, 0.04, 0.0)
		add_child(marker)

	_pose = Node3D.new()
	_pose.name = "Pose"
	add_child(_pose)

	if skin != null and not skin.parts.is_empty():
		for part: SkinPart in skin.parts:
			_add_part(part, color)
	else:
		_add_fallback(actor, color)

func _add_part(part: SkinPart, tint: Color) -> void:
	var mesh: Mesh = _make_mesh(part)
	if mesh == null:
		return
	var color: Color = part.color
	if part.tinted:
		color = tint.lightened(part.tint_shift) if part.tint_shift >= 0.0 \
			else tint.darkened(-part.tint_shift)
	if part.is_weapon:
		color = COLOR_WEAPON_IDLE
	var material: StandardMaterial3D = _make_material(color, part.unshaded)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = part.offset
	instance.rotation = Vector3(
		deg_to_rad(part.rotation_degrees.x),
		deg_to_rad(part.rotation_degrees.y),
		deg_to_rad(part.rotation_degrees.z))
	_pose.add_child(instance)
	_materials.append(material)
	_base_colors.append(color)
	_weapon_flags.append(part.is_weapon)

## Silhouette de repli : un skin absent ne doit pas rendre un personnage
## invisible, seulement anonyme.
func _add_fallback(actor: Actor, color: Color) -> void:
	var body: SkinPart = SkinPart.new()
	body.shape = SkinPart.Shape.CAPSULE
	body.size = Vector3(actor.radius, actor.radius * 4.0, 0.0)
	body.offset = Vector3(0.0, actor.radius * 2.0, 0.0)
	body.tinted = true
	_add_part(body, color)
	var blade: SkinPart = SkinPart.new()
	blade.shape = SkinPart.Shape.BOX
	blade.size = Vector3(0.14, 0.14, actor.radius * 3.0)
	blade.offset = Vector3(actor.radius * 0.7, actor.radius * 1.8, -actor.radius * 1.4)
	blade.is_weapon = true
	_add_part(blade, color)

func _make_mesh(part: SkinPart) -> Mesh:
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

func _make_material(color: Color, unshaded: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded \
		else BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material

# ---------------------------------------------------------------------------
# Rafraîchissement
# ---------------------------------------------------------------------------

func refresh(actor: Actor, camera_position: Vector3, is_local: bool,
		player_distance: float) -> void:
	position = Vector3(actor.position.x, 0.0, actor.position.y)
	if not actor.facing.is_zero_approx():
		var forward: Vector3 = Vector3(actor.facing.x, 0.0, actor.facing.y)
		look_at(position + forward, Vector3.UP)

	_apply_pose(actor)
	var open: bool = actor.runner != null and actor.runner.hitbox_open
	_apply_colors(actor, open, _fade_alpha(camera_position, is_local, player_distance))

## La pose s'applique au porte-pièces, jamais au nœud racine : celui-ci porte
## l'orientation du personnage, et la mort ne doit pas la faire tourner.
func _apply_pose(actor: Actor) -> void:
	match actor.state:
		Actor.State.DEAD:
			# Couché : la mort doit se lire d'un coup d'œil, de loin.
			_pose.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
			_pose.position = Vector3(0.0, _stand_height * 0.15, 0.0)
		Actor.State.STAGGERED:
			_pose.rotation = Vector3(0.22, 0.0, 0.0)
			_pose.position = Vector3.ZERO
		Actor.State.DODGING:
			# Ramassé au sol : la fenêtre d'invulnérabilité doit être visible.
			_pose.rotation = Vector3(-0.55, 0.0, 0.0)
			_pose.position = Vector3(0.0, -_stand_height * 0.28, 0.0)
		_:
			_pose.rotation = Vector3.ZERO
			_pose.position = Vector3.ZERO

func _fade_alpha(camera_position: Vector3, is_local: bool, player_distance: float) -> float:
	if is_local or player_distance <= 0.0:
		return 1.0
	var distance: float = global_position.distance_to(camera_position)
	# Positif quand l'acteur est devant le personnage vu de la caméra.
	var intrusion: float = player_distance - distance
	var hidden: float = clampf(
		inverse_lerp(FADE_MARGIN, FADE_FULL_AT, intrusion), 0.0, 1.0)
	return maxf(FADE_FLOOR, 1.0 - hidden)

func _apply_colors(actor: Actor, weapon_open: bool, alpha: float) -> void:
	var shift: float = 0.0
	match actor.state:
		Actor.State.DEAD:
			shift = -0.55
		Actor.State.STAGGERED:
			shift = 0.35
		Actor.State.DODGING:
			shift = 0.15
		_:
			shift = 0.0
	# Le mélange alpha ne s'active qu'en cas de besoin : laissé en permanence,
	# il imposerait un tri par profondeur à toute la scène pour rien.
	var mode: BaseMaterial3D.Transparency = BaseMaterial3D.TRANSPARENCY_DISABLED \
		if alpha >= 0.99 else BaseMaterial3D.TRANSPARENCY_ALPHA
	for index: int in _materials.size():
		var base: Color = _base_colors[index]
		if _weapon_flags[index]:
			base = COLOR_WEAPON_ACTIVE if weapon_open else COLOR_WEAPON_IDLE
		var tinted: Color = base
		if shift > 0.0:
			tinted = base.lightened(shift)
		elif shift < 0.0:
			tinted = base.darkened(-shift)
		tinted.a = alpha
		_materials[index].albedo_color = tinted
		_materials[index].transparency = mode
