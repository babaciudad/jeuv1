## Géométrie visible du niveau, construite depuis LevelData.
##
## Invariant 2 : la présentation lit la donnée de simulation, elle ne la
## produit pas. Sol, plafond et murs sortent tous de la MÊME grille de cases,
## remplie par le même prédicat que celui contre lequel les personnages se
## cognent. Décrire séparément ce qu'on voit et ce qui bloque, c'est signer
## pour le jour où ils ne correspondront plus — et deux dalles posées au même
## endroit se battent pour le même pixel.
class_name LevelView
extends Node3D

## Côté d'une case, en mètres. Les rectangles praticables ont des bornes
## entières : une grille au mètre les pave donc exactement, sans reste.
const CELL: float = 1.0
const WALL_HEIGHT: float = 3.4
const SLAB_THICKNESS: float = 0.2
const PROBE_MARGIN: float = 2.0

const COLOR_FLOOR: Color = Color(0.28, 0.27, 0.31)
const COLOR_WALL: Color = Color(0.42, 0.38, 0.45)
const COLOR_CEILING: Color = Color(0.20, 0.19, 0.24)
const COLOR_GATE: Color = Color(0.55, 0.40, 0.18)
const COLOR_BONFIRE: Color = Color(0.90, 0.55, 0.18)
const COLOR_SWITCH: Color = Color(0.35, 0.65, 0.80)

var _gate: MeshInstance3D

func build(level: LevelData) -> void:
	for child: Node in get_children():
		child.queue_free()
	_build_shell(level)
	_gate = _build_gate(level)
	_build_marker(level.bonfire_position, level.bonfire_radius, COLOR_BONFIRE, 0.9)
	_build_marker(level.shortcut_switch_position, level.shortcut_switch_radius,
		COLOR_SWITCH, 1.6)
	_build_atmosphere()

func set_shortcut_open(open: bool) -> void:
	if _gate != null:
		_gate.visible = not open

# ---------------------------------------------------------------------------
# Coque : sol, plafond, murs
# ---------------------------------------------------------------------------

func _build_shell(level: LevelData) -> void:
	if level.walkable.is_empty():
		return
	var bounds: Rect2 = level.walkable[0]
	for rect: Rect2 in level.walkable:
		bounds = bounds.merge(rect)
	bounds = bounds.grow(PROBE_MARGIN)

	var open_cells: Array[Vector2] = []
	var wall_cells: Array[Vector2] = []
	var no_blockers: Array[Rect2] = []
	# Centres de case sur les demi-entiers : chaque case est émise une fois et
	# une seule, donc aucune dalle ne peut en recouvrir une autre.
	var x: float = floorf(bounds.position.x) + CELL * 0.5
	while x <= bounds.end.x:
		var z: float = floorf(bounds.position.y) + CELL * 0.5
		while z <= bounds.end.y:
			var cell: Vector2 = Vector2(x, z)
			if SimMath.point_is_free(cell, level.walkable, no_blockers):
				open_cells.append(cell)
			elif _touches_walkable(cell, level.walkable):
				wall_cells.append(cell)
			z += CELL
		x += CELL

	_add_grid("Floor", open_cells, Vector3(CELL, SLAB_THICKNESS, CELL),
		-SLAB_THICKNESS * 0.5, COLOR_FLOOR)
	_add_grid("Ceiling", open_cells, Vector3(CELL, SLAB_THICKNESS, CELL),
		WALL_HEIGHT + SLAB_THICKNESS * 0.5, COLOR_CEILING)
	_add_grid("Walls", wall_cells,
		Vector3(CELL, WALL_HEIGHT + SLAB_THICKNESS, CELL),
		(WALL_HEIGHT + SLAB_THICKNESS) * 0.5, COLOR_WALL)

## Vrai si la case touche une case praticable. C'est ce qui fait apparaître
## les ouvertures toutes seules : là où une salle rejoint un couloir, il n'y a
## pas de case pleine à border.
func _touches_walkable(cell: Vector2, walkable: Array[Rect2]) -> bool:
	var no_blockers: Array[Rect2] = []
	var offsets: Array[Vector2] = [
		Vector2(CELL, 0.0), Vector2(-CELL, 0.0),
		Vector2(0.0, CELL), Vector2(0.0, -CELL),
	]
	for offset: Vector2 in offsets:
		if SimMath.point_is_free(cell + offset, walkable, no_blockers):
			return true
	return false

func _add_grid(grid_name: String, cells: Array[Vector2], size: Vector3,
		height: float, color: Color) -> void:
	if cells.is_empty():
		return
	var block: BoxMesh = BoxMesh.new()
	block.size = size
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = block
	multimesh.instance_count = cells.size()
	for index: int in cells.size():
		var cell: Vector2 = cells[index]
		multimesh.set_instance_transform(index,
			Transform3D(Basis.IDENTITY, Vector3(cell.x, height, cell.y)))
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = grid_name
	instance.multimesh = multimesh
	instance.material_override = _material(color)
	add_child(instance)

# ---------------------------------------------------------------------------
# Éléments singuliers
# ---------------------------------------------------------------------------

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

## Repère au sol : un anneau de la taille du rayon d'interaction, plus un bloc
## pour qu'on le voie de loin. Le joueur doit pouvoir juger à l'œil s'il est à
## portée, sans invite.
func _build_marker(at: Vector2, radius: float, color: Color, height: float) -> void:
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
