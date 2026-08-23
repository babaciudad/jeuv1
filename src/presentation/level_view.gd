## Géométrie visible du niveau, construite depuis LevelData.
##
## Invariant 2 : la présentation lit la donnée de simulation, elle ne la
## produit pas. Les murs ne sont pas décrits à la main : ils sont déduits de la
## zone praticable, ce qui garantit que ce qu'on voit est exactement ce contre
## quoi on se cogne. Décrire les deux séparément, c'est signer pour un jour où
## ils ne correspondront plus.
class_name LevelView
extends Node3D

const WALL_HEIGHT: float = 3.4
const WALL_SEGMENT: float = 1.0
const FLOOR_THICKNESS: float = 0.2
const PROBE_MARGIN: float = 2.0

const COLOR_FLOOR: Color = Color(0.28, 0.27, 0.31)
const COLOR_WALL: Color = Color(0.42, 0.38, 0.45)
const COLOR_CEILING: Color = Color(0.16, 0.15, 0.19)
const COLOR_GATE: Color = Color(0.55, 0.40, 0.18)
const COLOR_BONFIRE: Color = Color(0.90, 0.55, 0.18)
const COLOR_SWITCH: Color = Color(0.35, 0.65, 0.80)

var _gate: MeshInstance3D

func build(level: LevelData) -> void:
	for child: Node in get_children():
		child.queue_free()
	_build_floor(level)
	_build_walls(level)
	_gate = _build_gate(level)
	_build_marker(level.bonfire_position, level.bonfire_radius, COLOR_BONFIRE, 0.9)
	_build_marker(level.shortcut_switch_position, level.shortcut_switch_radius,
		COLOR_SWITCH, 1.6)
	_build_atmosphere()

## Lumière et ambiance. Construites ici plutôt que posées dans la scène : ce
## sont des propriétés du niveau, elles suivront le niveau si un jour il y en a
## un second.
func _build_atmosphere() -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-38.0), 0.0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.94, 0.85)
	sun.shadow_enabled = false
	add_child(sun)

	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.045, 0.045, 0.06)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.46, 0.45, 0.55)
	environment.ambient_light_energy = 1.5
	# Brouillard : c'est ce qui donne sa profondeur à une scène sans texture,
	# et ce qui masque le bout du couloir. Assez dense pour cacher, assez
	# clair pour qu'on distingue un ennemi avant qu'il ne frappe.
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.10, 0.10, 0.14)
	environment.fog_density = 0.012

	var holder: WorldEnvironment = WorldEnvironment.new()
	holder.name = "Atmosphere"
	holder.environment = environment
	add_child(holder)

func set_shortcut_open(open: bool) -> void:
	if _gate != null:
		_gate.visible = not open

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	# Éclairage par sommet : c'est la direction artistique PS1/PS2 demandée,
	# et c'est aussi ce qui coûte le moins cher à afficher.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material

func _add_box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(color)
	instance.position = at
	add_child(instance)
	return instance

func _build_floor(level: LevelData) -> void:
	for rect: Rect2 in level.walkable:
		var center: Vector2 = rect.position + rect.size * 0.5
		_add_box(Vector3(rect.size.x, FLOOR_THICKNESS, rect.size.y),
			Vector3(center.x, -FLOOR_THICKNESS * 0.5, center.y), COLOR_FLOOR)
		# Plafond : sans lui, on voit le vide au-dessus des murs et le lieu ne
		# se lit plus comme un intérieur.
		_add_box(Vector3(rect.size.x, FLOOR_THICKNESS, rect.size.y),
			Vector3(center.x, WALL_HEIGHT, center.y), COLOR_CEILING)

## Place un bloc de mur sur chaque case non praticable qui touche une case
## praticable. Les ouvertures apparaissent toutes seules : là où le couloir
## rejoint une salle, il n'y a pas de case pleine à border.
func _build_walls(level: LevelData) -> void:
	if level.walkable.is_empty():
		return
	var bounds: Rect2 = level.walkable[0]
	for rect: Rect2 in level.walkable:
		bounds = bounds.merge(rect)
	bounds = bounds.grow(PROBE_MARGIN)

	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var block: BoxMesh = BoxMesh.new()
	block.size = Vector3(WALL_SEGMENT, WALL_HEIGHT, WALL_SEGMENT)
	multimesh.mesh = block

	var placements: Array[Vector2] = []
	var empty: Array[Rect2] = []
	var x: float = bounds.position.x
	while x <= bounds.end.x:
		var z: float = bounds.position.y
		while z <= bounds.end.y:
			var point: Vector2 = Vector2(x, z)
			if not SimMath.point_is_free(point, level.walkable, empty) \
					and _touches_walkable(point, level.walkable):
				placements.append(point)
			z += WALL_SEGMENT
		x += WALL_SEGMENT

	multimesh.instance_count = placements.size()
	for index: int in placements.size():
		var at: Vector2 = placements[index]
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY,
			Vector3(at.x, WALL_HEIGHT * 0.5, at.y)))

	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = "Walls"
	instance.multimesh = multimesh
	instance.material_override = _material(COLOR_WALL)
	add_child(instance)

func _touches_walkable(point: Vector2, walkable: Array[Rect2]) -> bool:
	var empty: Array[Rect2] = []
	var offsets: Array[Vector2] = [
		Vector2(WALL_SEGMENT, 0.0), Vector2(-WALL_SEGMENT, 0.0),
		Vector2(0.0, WALL_SEGMENT), Vector2(0.0, -WALL_SEGMENT),
	]
	for offset: Vector2 in offsets:
		if SimMath.point_is_free(point + offset, walkable, empty):
			return true
	return false

func _build_gate(level: LevelData) -> MeshInstance3D:
	var rect: Rect2 = level.shortcut_gate
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return null
	var center: Vector2 = rect.position + rect.size * 0.5
	var gate: MeshInstance3D = _add_box(
		Vector3(rect.size.x, WALL_HEIGHT, rect.size.y),
		Vector3(center.x, WALL_HEIGHT * 0.5, center.y), COLOR_GATE)
	gate.name = "ShortcutGate"
	return gate

## Repère au sol : un disque plat de la taille du rayon d'interaction, plus un
## bloc pour qu'on le voie de loin. Le joueur doit pouvoir juger à l'œil s'il
## est à portée, sans invite.
func _build_marker(at: Vector2, radius: float, color: Color, height: float) -> void:
	# Un anneau, pas un disque : le joueur doit voir la limite du rayon
	# d'interaction, pas une flaque de couleur sur le sol.
	var outline: TorusMesh = TorusMesh.new()
	outline.inner_radius = maxf(0.05, radius - 0.18)
	outline.outer_radius = radius
	outline.rings = 24
	outline.ring_segments = 6
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = outline
	ring.material_override = _material(color)
	ring.position = Vector3(at.x, 0.05, at.y)
	add_child(ring)
	_add_box(Vector3(0.5, height, 0.5), Vector3(at.x, height * 0.5, at.y), color)
