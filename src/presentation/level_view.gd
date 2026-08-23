## Géométrie visible du niveau, construite depuis LevelData.
##
## Invariant 2 : la présentation lit la donnée de simulation, elle ne la
## produit pas. Sol, plafond et murs sortent tous de la MÊME grille de cases,
## remplie par le même prédicat que celui contre lequel les personnages se
## cognent. Décrire séparément ce qu'on voit et ce qui bloque, c'est signer
## pour le jour où ils ne correspondront plus — et deux dalles posées au même
## endroit se battent pour le même pixel.
##
## Même règle pour le décor : ce qui arrête un personnage est déclaré dans
## LevelData.obstacles et dessiné à partir de là ; ce qui ne l'arrête pas vit
## dans res://data/decor/ et n'entre jamais dans la simulation.
class_name LevelView
extends Node3D

## Côté d'une case, en mètres. Les rectangles praticables ont des bornes
## entières : une grille au mètre les pave donc exactement, sans reste.
const CELL: float = 1.0
const SLAB_THICKNESS: float = 0.2
const PROBE_MARGIN: float = 2.0

const COLOR_FLOOR: Color = Color(0.26, 0.25, 0.29)
const COLOR_WALL: Color = Color(0.40, 0.37, 0.42)
const COLOR_CEILING: Color = Color(0.17, 0.16, 0.21)
const COLOR_GATE: Color = Color(0.55, 0.40, 0.18)
const COLOR_BONFIRE: Color = Color(0.90, 0.55, 0.18)
const COLOR_SWITCH: Color = Color(0.35, 0.65, 0.80)
const COLOR_STONE: Color = Color(0.47, 0.45, 0.44)
const COLOR_STONE_DARK: Color = Color(0.33, 0.32, 0.34)

var _gate: MeshInstance3D

func build(level: LevelData) -> void:
	for child: Node in get_children():
		child.queue_free()
	_build_shell(level)
	_build_obstacles(level)
	_build_decor(level)
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

	var floor_cells: Array[Vector3] = []
	var ceiling_cells: Array[Vector3] = []
	var wall_cells: Array[Vector3] = []
	var no_blockers: Array[Rect2] = []
	# Centres de case sur les demi-entiers : chaque case est émise une fois et
	# une seule, donc aucune dalle ne peut en recouvrir une autre.
	var x: float = floorf(bounds.position.x) + CELL * 0.5
	while x <= bounds.end.x:
		var z: float = floorf(bounds.position.y) + CELL * 0.5
		while z <= bounds.end.y:
			var cell: Vector2 = Vector2(x, z)
			if SimMath.point_is_free(cell, level.walkable, no_blockers):
				var height: float = level.height_at(cell)
				floor_cells.append(Vector3(x, 0.0, z))
				ceiling_cells.append(Vector3(x, height, z))
			else:
				# Une case pleine ne se dresse que si elle borde du vide, et
				# monte à la hauteur de la case la plus haute qu'elle borde :
				# c'est ce qui fait qu'un mur de nef n'a pas la taille d'un mur
				# de boyau, sans qu'on ait à le dire nulle part.
				var neighbour: float = _tallest_neighbour(cell, level)
				if neighbour > 0.0:
					wall_cells.append(Vector3(x, neighbour, z))
			z += CELL
		x += CELL

	_add_slabs("Floor", floor_cells, -SLAB_THICKNESS * 0.5, COLOR_FLOOR)
	_add_slabs("Ceiling", ceiling_cells, SLAB_THICKNESS * 0.5, COLOR_CEILING)
	_add_walls(wall_cells)

## Hauteur de la plus haute case praticable voisine, ou 0 si la case est
## enterrée. C'est ce qui fait apparaître les ouvertures toutes seules : là où
## une salle rejoint un couloir, il n'y a pas de case pleine à border.
func _tallest_neighbour(cell: Vector2, level: LevelData) -> float:
	var no_blockers: Array[Rect2] = []
	var offsets: Array[Vector2] = [
		Vector2(CELL, 0.0), Vector2(-CELL, 0.0),
		Vector2(0.0, CELL), Vector2(0.0, -CELL),
	]
	var best: float = 0.0
	for offset: Vector2 in offsets:
		var probe: Vector2 = cell + offset
		if SimMath.point_is_free(probe, level.walkable, no_blockers):
			best = maxf(best, level.height_at(probe))
	return best

## Dalles toutes identiques : `at.y` porte la hauteur, la boîte ne change pas.
func _add_slabs(slab_name: String, cells: Array[Vector3], lift: float,
		color: Color) -> void:
	if cells.is_empty():
		return
	var block: BoxMesh = BoxMesh.new()
	block.size = Vector3(CELL, SLAB_THICKNESS, CELL)
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = block
	multimesh.instance_count = cells.size()
	for index: int in cells.size():
		var cell: Vector3 = cells[index]
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY,
			Vector3(cell.x, cell.y + lift, cell.z)))
	_attach_multimesh(slab_name, multimesh, color)

## Les murs n'ont pas tous la même hauteur : une seule boîte unitaire, mise à
## l'échelle par la base de chaque instance. Un MultiMesh par hauteur serait
## une dizaine de nœuds pour rien.
func _add_walls(cells: Array[Vector3]) -> void:
	if cells.is_empty():
		return
	var block: BoxMesh = BoxMesh.new()
	block.size = Vector3(CELL, 1.0, CELL)
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = block
	multimesh.instance_count = cells.size()
	for index: int in cells.size():
		var cell: Vector3 = cells[index]
		var height: float = cell.y + SLAB_THICKNESS
		var basis: Basis = Basis.IDENTITY.scaled(Vector3(1.0, height, 1.0))
		multimesh.set_instance_transform(index, Transform3D(basis,
			Vector3(cell.x, height * 0.5, cell.z)))
	_attach_multimesh("Walls", multimesh, COLOR_WALL)

func _attach_multimesh(node_name: String, multimesh: MultiMesh, color: Color) -> void:
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = _material(color)
	add_child(instance)

# ---------------------------------------------------------------------------
# Obstacles et décor
# ---------------------------------------------------------------------------

## Un obstacle déclaré dans la simulation se voit : base, fût, chapiteau. La
## forme est déduite de son emprise, jamais posée à la main — un pilier dessiné
## ailleurs que là où il bloque est le pire des bugs, celui qu'on accuse le
## réseau d'avoir causé.
func _build_obstacles(level: LevelData) -> void:
	for index: int in level.obstacles.size():
		var rect: Rect2 = level.obstacles[index]
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var centre: Vector2 = rect.position + rect.size * 0.5
		var height: float = level.obstacle_height(index)
		if height <= 0.0:
			height = level.default_ceiling
		var span: Vector3 = Vector3(rect.size.x, 1.0, rect.size.y)
		_add_box(Vector3(span.x, 0.28, span.z),
			Vector3(centre.x, 0.14, centre.y), COLOR_STONE_DARK)
		_add_box(Vector3(span.x * 0.82, height - 0.62, span.z * 0.82),
			Vector3(centre.x, 0.28 + (height - 0.62) * 0.5, centre.y), COLOR_STONE)
		_add_box(Vector3(span.x, 0.34, span.z),
			Vector3(centre.x, height - 0.17, centre.y), COLOR_STONE_DARK)

## Décor : purement visuel, chargé par l'identifiant du niveau. Absent, le
## niveau reste jouable — il est seulement nu.
func _build_decor(level: LevelData) -> void:
	if level.id == &"":
		return
	var path: String = "res://data/decor/%s.tres" % level.id
	if not ResourceLoader.exists(path):
		return
	var decor: DecorData = load(path) as DecorData
	if decor == null:
		return
	var root: Node3D = Node3D.new()
	root.name = "Decor"
	add_child(root)
	for part: SkinPart in decor.parts:
		var instance: MeshInstance3D = PrimitiveFactory.instance_for(
			part, PrimitiveFactory.color_for(part, COLOR_STONE))
		if instance != null:
			root.add_child(instance)

# ---------------------------------------------------------------------------
# Éléments singuliers
# ---------------------------------------------------------------------------

func _material(color: Color) -> StandardMaterial3D:
	return PrimitiveFactory.material_for(color, false)

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
	var centre: Vector2 = rect.position + rect.size * 0.5
	var height: float = level.height_at(centre)
	var gate: MeshInstance3D = _add_box(
		Vector3(rect.size.x, height, rect.size.y),
		Vector3(centre.x, height * 0.5, centre.y), COLOR_GATE)
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
