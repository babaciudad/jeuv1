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

const COLOR_FLOOR: Color = Color(0.43, 0.43, 0.43)
const COLOR_MORTAR: Color = Color(0.15, 0.14, 0.15)
const COLOR_WALL: Color = Color(0.50, 0.50, 0.49)
const COLOR_CEILING: Color = Color(0.31, 0.29, 0.29)
const COLOR_GATE: Color = Color(0.55, 0.40, 0.18)
const COLOR_BONFIRE: Color = Color(1.0, 0.50, 0.16)
const COLOR_SWITCH: Color = Color(0.42, 0.74, 1.0)
const COLOR_ASH: Color = Color(0.19, 0.18, 0.19)
const COLOR_LOG: Color = Color(0.23, 0.15, 0.10)
const COLOR_BLADE: Color = Color(0.58, 0.57, 0.55)
const COLOR_IRON: Color = Color(0.26, 0.25, 0.28)
const COLOR_EMBER: Color = Color(1.0, 0.72, 0.30)
const COLOR_STONE: Color = Color(0.44, 0.44, 0.45)
const COLOR_STONE_DARK: Color = Color(0.32, 0.32, 0.34)

var _gate: MeshInstance3D

func build(level: LevelData) -> void:
	for child: Node in get_children():
		child.queue_free()
	_build_shell(level)
	_build_obstacles(level)
	_build_decor(level)
	_gate = _build_gate(level)
	_build_ground_ring(level.bonfire_position, level.bonfire_radius, COLOR_BONFIRE)
	_build_bonfire(level.bonfire_position)
	_build_ground_ring(level.shortcut_switch_position,
		level.shortcut_switch_radius, COLOR_SWITCH)
	_build_lever(level.shortcut_switch_position)
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
	## Pans bouchant les décrochés de plafond, et le haut de chaque pan.
	var spandrels: Array[Vector3] = []
	var spandrel_tops: Array[float] = []
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
				# Là où une salle basse touche une salle haute, il reste une
				# bande de vide entre les deux plafonds. Sans ce pan, on voit
				# à travers le décor : c'est le mur qu'aurait toute vraie
				# maçonnerie au-dessus d'une arcade.
				var above: float = _tallest_neighbour(cell, level)
				if above > height + 0.05:
					spandrels.append(Vector3(x, height, z))
					spandrel_tops.append(above)
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

	# Le sol se pose en deux passes : un lit sombre pleine largeur, puis les
	# dalles, rétrécies de quatre centimètres. Ce sont ces quatre centimètres
	# qui font le joint de mortier — sans eux, quarante mètres de dallage sont
	# une seule surface lisse, et aucune texture ne rattrape ça.
	_add_slabs("FloorBed", floor_cells, -SLAB_THICKNESS * 0.5 - 0.035,
		COLOR_MORTAR)
	_add_slabs("Floor", floor_cells, -SLAB_THICKNESS * 0.5, COLOR_FLOOR, 0.09)
	_add_slabs("Ceiling", ceiling_cells, SLAB_THICKNESS * 0.5, COLOR_CEILING)
	_add_walls(wall_cells)
	_add_spandrels(spandrels, spandrel_tops)

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
		color: Color, joint: float = 0.0) -> void:
	if cells.is_empty():
		return
	var block: BoxMesh = BoxMesh.new()
	block.size = Vector3(CELL - joint, SLAB_THICKNESS, CELL - joint)
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = block
	# `use_colors` AVANT `instance_count` : dans l'autre ordre, Godot 4.7
	# refuse le changement et toutes les couleurs par instance sont perdues
	# en silence — le sol redevient un aplat sans que rien ne le signale.
	multimesh.use_colors = true
	multimesh.instance_count = cells.size()
	for index: int in cells.size():
		var cell: Vector3 = cells[index]
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY,
			Vector3(cell.x, cell.y + lift, cell.z)))
		multimesh.set_instance_color(index, _stone_tint(cell))
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
	# `use_colors` AVANT `instance_count` : dans l'autre ordre, Godot 4.7
	# refuse le changement et toutes les couleurs par instance sont perdues
	# en silence — le sol redevient un aplat sans que rien ne le signale.
	multimesh.use_colors = true
	multimesh.instance_count = cells.size()
	for index: int in cells.size():
		var cell: Vector3 = cells[index]
		var height: float = cell.y + SLAB_THICKNESS
		var basis: Basis = Basis.IDENTITY.scaled(Vector3(1.0, height, 1.0))
		multimesh.set_instance_transform(index, Transform3D(basis,
			Vector3(cell.x, height * 0.5, cell.z)))
		multimesh.set_instance_color(index, _stone_tint(cell))
	_attach_multimesh("Walls", multimesh, COLOR_WALL)

## Teinte d'une case, décidée par sa position. Deux dalles voisines ne sont
## jamais tout à fait de la même pierre : c'est ce qui empêche un sol de
## quarante mètres d'être un aplat, et c'est gratuit — aucune géométrie en
## plus, une couleur par instance.
##
## Déterministe, jamais tiré au hasard : deux joueurs doivent voir le même sol,
## et un niveau rechargé doit être identique au précédent.
func _stone_tint(cell: Vector3) -> Color:
	var wave: float = sin(cell.x * 1.7 + cell.z * 0.9) * 0.5 \
		+ sin(cell.x * 0.31 - cell.z * 2.3) * 0.5
	var shade: float = 1.0 + wave * 0.07
	# Une pointe de chaleur ou de froid selon la case, pas seulement du gris
	# plus ou moins clair : c'est la variation de teinte qui se voit, pas la
	# variation de luminosité.
	var warm: float = 1.0 + sin(cell.x * 0.7 + cell.z * 0.13) * 0.022
	return Color(shade * warm, shade, shade / warm, 1.0)

## Pans verticaux au-dessus d'un décroché de plafond. Une case, un pan, de la
## hauteur basse à la hauteur haute.
func _add_spandrels(cells: Array[Vector3], tops: Array[float]) -> void:
	if cells.is_empty():
		return
	var block: BoxMesh = BoxMesh.new()
	block.size = Vector3(CELL, 1.0, CELL)
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = block
	# `use_colors` AVANT `instance_count` : dans l'autre ordre, Godot 4.7
	# refuse le changement et toutes les couleurs par instance sont perdues
	# en silence — le sol redevient un aplat sans que rien ne le signale.
	multimesh.use_colors = true
	multimesh.instance_count = cells.size()
	for index: int in cells.size():
		var cell: Vector3 = cells[index]
		var span: float = tops[index] - cell.y + SLAB_THICKNESS
		var basis: Basis = Basis.IDENTITY.scaled(Vector3(1.0, span, 1.0))
		multimesh.set_instance_transform(index, Transform3D(basis,
			Vector3(cell.x, cell.y + span * 0.5, cell.z)))
		multimesh.set_instance_color(index, _stone_tint(cell))
	_attach_multimesh("Spandrels", multimesh, COLOR_WALL)

func _attach_multimesh(node_name: String, multimesh: MultiMesh, color: Color) -> void:
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	var material: StandardMaterial3D = PrimitiveFactory.material_for(
		color, false, SkinPart.Surface.STONE)
	# Sans cela, la couleur par instance est calculée puis jetée.
	material.vertex_color_use_as_albedo = true
	instance.material_override = material
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
			Vector3(centre.x, 0.14, centre.y), COLOR_STONE_DARK,
			SkinPart.Surface.STONE)
		_add_box(Vector3(span.x * 0.86, height - 0.62, span.z * 0.86),
			Vector3(centre.x, 0.28 + (height - 0.62) * 0.5, centre.y), COLOR_STONE,
			SkinPart.Surface.STONE)
		# Un tore au pied et sous le chapiteau : c'est la moulure qui fait
		# lire une colonne plutôt qu'un poteau.
		_add_ring(minf(span.x, span.z) * 0.50, Vector3(centre.x, 0.34, centre.y))
		_add_ring(minf(span.x, span.z) * 0.50,
			Vector3(centre.x, height - 0.40, centre.y))
		_add_box(Vector3(span.x, 0.34, span.z),
			Vector3(centre.x, height - 0.17, centre.y), COLOR_STONE_DARK,
			SkinPart.Surface.STONE)

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

	# Les pièces identiques sont REGROUPÉES en MultiMesh. La chapelle en compte
	# sept cents, et une par nœud faisait sept cents appels de rendu pour un
	# décor qui n'en vaut pas trente : seize torches partagent le même fût, huit
	# bancs la même planche, chaque arc treize claveaux identiques.
	#
	# La clé est la forme complète — maillage ET matière ET couleur : deux
	# pièces qui ne partagent pas les trois ne peuvent pas partager un lot.
	var groups: Dictionary[String, Array] = {}
	for part: SkinPart in decor.parts:
		var tone: Color = PrimitiveFactory.color_for(part, COLOR_STONE)
		_add_light(root, part, tone)
		var key: String = "%d|%s|%d|%s|%d" % [part.shape, part.size, part.surface,
			tone.to_html(), 1 if part.unshaded else 0]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(part)

	var lots: int = 0
	for key: String in groups.keys():
		var family: Array = groups[key]
		var first: SkinPart = family[0]
		var tone: Color = PrimitiveFactory.color_for(first, COLOR_STONE)
		if family.size() == 1:
			var single: MeshInstance3D = PrimitiveFactory.instance_for(first, tone)
			if single != null:
				root.add_child(single)
			continue
		var mesh: Mesh = PrimitiveFactory.mesh_for(first)
		if mesh == null:
			continue
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = family.size()
		for index: int in family.size():
			var part: SkinPart = family[index]
			var basis: Basis = Basis.from_euler(Vector3(
				deg_to_rad(part.rotation_degrees.x),
				deg_to_rad(part.rotation_degrees.y),
				deg_to_rad(part.rotation_degrees.z)))
			# L'ELLIPSOÏDE porte ses proportions dans son échelle, pas dans son
			# maillage : sans cela une tête et un torse partageraient le même
			# lot et sortiraient tous deux sphériques.
			if part.shape == SkinPart.Shape.ELLIPSOID:
				basis = basis.scaled(part.size)
			multimesh.set_instance_transform(index,
				Transform3D(basis, part.offset))
		var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
		batch.multimesh = multimesh
		batch.material_override = PrimitiveFactory.material_for(
			tone, first.unshaded, first.surface,
			0.0 if first.light_range <= 0.0 else 1.15 + first.light_range * 0.13)
		if first.surface == SkinPart.Surface.GLOW or first.unshaded:
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(batch)
		lots += 1
	print("[decor] %d pieces en %d noeuds (%d lots)"
		% [decor.parts.size(), root.get_child_count(), lots])

## Une pièce qui brille éclaire. Il n'y a pas de liste de lampes dans ce
## projet : une lumière naît toujours d'une pièce visible, et sa portée est
## déclarée sur cette pièce. Une lampe sans source visible est une incohérence
## qu'on ne s'explique plus six mois après.
func _add_light(root: Node3D, part: SkinPart, tone: Color) -> void:
	if part.light_range <= 0.0:
		return
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = part.offset
	lamp.omni_range = part.light_range
	# L'énergie suit la portée : une lampe qui porte loin sans être vive, ou
	# l'inverse, se règle deux fois et se dérègle une fois sur deux.
	lamp.light_energy = 0.30 * part.light_range
	# La lumière prend la teinte de la pièce, mais DÉSATURÉE. Une flamme est
	# rouge orangé ; ce qu'elle éclaire ne l'est pas — sinon un couloir de
	# seize torches vire au sang et plus rien n'a de couleur propre. C'est
	# aussi vrai des vitraux : un verre bleu profond jette une lueur pâle.
	lamp.light_color = tone.lerp(Color(1.0, 0.97, 0.92), 0.52)
	# Décroissance douce : à 1,0 une torche fait un disque net sur le mur.
	lamp.omni_attenuation = 1.6
	# Aucune ombre portée : une chapelle en compte une trentaine, et trente
	# cartes d'ombre coûtent plus que tout le reste de la scène réunie. La
	# lune, elle, porte les ombres (voir _build_atmosphere).
	lamp.shadow_enabled = false
	root.add_child(lamp)

# ---------------------------------------------------------------------------
# Éléments singuliers
# ---------------------------------------------------------------------------

func _add_box(size: Vector3, at: Vector3, color: Color,
		surface: SkinPart.Surface = SkinPart.Surface.PLAIN,
		rotation_degrees_: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = PrimitiveFactory.material_for(color, false, surface)
	instance.position = at
	instance.rotation = Vector3(
		deg_to_rad(rotation_degrees_.x),
		deg_to_rad(rotation_degrees_.y),
		deg_to_rad(rotation_degrees_.z))
	add_child(instance)
	return instance

## Sphère émissive et sa lampe. Même règle que pour le décor : ce qui brille
## éclaire, et rien n'éclaire sans qu'on voie quoi.
func _add_glow(at: Vector3, size: Vector3, color: Color, reach: float) -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = size.x
	sphere.height = size.x * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = sphere
	instance.material_override = PrimitiveFactory.material_for(
		color, false, SkinPart.Surface.GLOW, 1.15 + reach * 0.13)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = at
	add_child(instance)

	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = at
	lamp.omni_range = reach
	lamp.light_energy = 0.30 * reach
	lamp.light_color = color.lerp(Color(1.0, 0.97, 0.92), 0.52)
	lamp.omni_attenuation = 1.6
	# Le feu de camp est la seule lampe du niveau à porter une ombre : c'est
	# le point de repos, on y reste, et une ombre projetée par son propre feu
	# vaut mieux que trente ombres qu'on ne regarde jamais.
	lamp.shadow_enabled = reach >= 14.0
	lamp.shadow_bias = 0.06
	add_child(lamp)

func _add_cone(at: Vector3, radius: float, height: float, color: Color) -> void:
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 12
	cone.rings = 1
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = cone
	instance.material_override = PrimitiveFactory.material_for(
		color, false, SkinPart.Surface.GLOW, 2.2)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = at
	add_child(instance)

func _add_ring(radius: float, at: Vector3) -> void:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + 0.09
	torus.rings = 16
	torus.ring_segments = 6
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = torus
	instance.material_override = PrimitiveFactory.material_for(
		COLOR_STONE_DARK, false, SkinPart.Surface.STONE)
	instance.position = at
	add_child(instance)

func _build_gate(level: LevelData) -> MeshInstance3D:
	var rect: Rect2 = level.shortcut_gate
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return null
	var centre: Vector2 = rect.position + rect.size * 0.5
	var height: float = level.height_at(centre)
	var gate: MeshInstance3D = _add_box(
		Vector3(rect.size.x, height, rect.size.y),
		Vector3(centre.x, height * 0.5, centre.y), COLOR_GATE,
		SkinPart.Surface.METAL)
	gate.name = "ShortcutGate"
	return gate

## Repère au sol : un anneau de la taille exacte du rayon d'interaction. Le
## joueur doit pouvoir juger à l'œil s'il est à portée, sans invite.
func _build_ground_ring(at: Vector2, radius: float, color: Color) -> void:
	var outline: TorusMesh = TorusMesh.new()
	outline.inner_radius = maxf(0.05, radius - 0.16)
	outline.outer_radius = radius
	outline.rings = 32
	outline.ring_segments = 6
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = outline
	# Émissif : le cercle de portée doit rester lisible même quand le joueur
	# est dedans et que sa propre ombre le recouvre.
	ring.material_override = PrimitiveFactory.material_for(
		color, false, SkinPart.Surface.GLOW, 0.9)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(at.x, 0.05, at.y)
	add_child(ring)

## Le feu de camp. C'est le point de repos, de réapparition et de soin : il
## doit se voir du fond de la nef et se reconnaître au premier coup d'œil.
## Une caisse de couleur ne fait pas ça — un cercle de pierres, un bûcher et
## une lame plantée, si.
func _build_bonfire(at: Vector2) -> void:
	var base: Vector3 = Vector3(at.x, 0.0, at.y)
	_add_box(Vector3(2.0, 0.10, 2.0), base + Vector3(0, 0.05, 0), COLOR_ASH,
		SkinPart.Surface.STONE)
	# Cercle de pierres.
	for index: int in 9:
		var angle: float = TAU * float(index) / 9.0
		var side: float = 0.30 + 0.06 * float(index % 3)
		_add_box(Vector3(side, side * 0.8, side * 1.2),
			base + Vector3(cos(angle) * 0.86, side * 0.4, sin(angle) * 0.86),
			COLOR_STONE, SkinPart.Surface.STONE,
			Vector3(0.0, rad_to_deg(angle), 0.0))
	# Bûcher : quatre bûches croisées.
	for index: int in 4:
		var angle: float = PI * float(index) / 4.0
		_add_box(Vector3(0.17, 0.17, 1.35),
			base + Vector3(0, 0.20 + 0.05 * float(index), 0), COLOR_LOG,
			SkinPart.Surface.WOOD,
			Vector3(0.0, rad_to_deg(angle), 6.0 * float(index)))
	# Lame plantée : la marque du genre, et un repère vertical qui dépasse des
	# bancs quand on regarde la nef de loin.
	_add_box(Vector3(0.10, 1.05, 0.03), base + Vector3(0, 0.85, 0),
		COLOR_BLADE, SkinPart.Surface.METAL, Vector3(6.0, 0.0, -9.0))
	_add_box(Vector3(0.34, 0.07, 0.07), base + Vector3(0.055, 1.30, 0),
		COLOR_BLADE, SkinPart.Surface.METAL, Vector3(6.0, 0.0, -9.0))
	_add_box(Vector3(0.07, 0.26, 0.07), base + Vector3(0.09, 1.44, 0),
		COLOR_LOG, SkinPart.Surface.CLOTH, Vector3(6.0, 0.0, -9.0))
	# Flamme, et la lumière qui va avec.
	_add_glow(base + Vector3(0, 0.48, 0), Vector3(0.42, 0.0, 0.0),
		COLOR_BONFIRE, 18.0)
	_add_cone(base + Vector3(0, 1.02, 0), 0.30, 1.05, COLOR_EMBER)

## Le levier du raccourci : une potence et une manette, avec sa veilleuse.
func _build_lever(at: Vector2) -> void:
	var base: Vector3 = Vector3(at.x, 0.0, at.y)
	_add_box(Vector3(0.9, 0.24, 0.9), base + Vector3(0, 0.12, 0), COLOR_STONE,
		SkinPart.Surface.STONE)
	_add_box(Vector3(0.18, 1.30, 0.18), base + Vector3(0, 0.85, 0), COLOR_IRON,
		SkinPart.Surface.METAL)
	_add_box(Vector3(0.10, 0.66, 0.10), base + Vector3(0.24, 1.55, 0),
		COLOR_IRON, SkinPart.Surface.METAL, Vector3(0.0, 0.0, -34.0))
	_add_glow(base + Vector3(0, 1.62, 0), Vector3(0.13, 0.0, 0.0),
		COLOR_SWITCH, 9.0)

## Lumière et ambiance. Construites ici plutôt que posées dans la scène : ce
## sont des propriétés du niveau, elles suivront le niveau si un jour il y en a
## un second.
##
## Le rendu est en Forward+ (voir project.godot). C'est ce qui donne les
## ombres portées, l'occlusion ambiante, le halo et le brouillard volumétrique.
## En `gl_compatibility`, tout ce bloc est ignoré en silence et la chapelle
## redevient un aplat gris — c'était l'état du jeu avant.
func _build_atmosphere() -> void:
	# Lune froide entrant par la toiture crevée. Faible : dans une chapelle en
	# ruine, ce sont les feux qui éclairent, pas le ciel. Mais elle porte les
	# ombres, et une scène sans ombre portée n'a pas de volume.
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation = Vector3(deg_to_rad(-58.0), deg_to_rad(-34.0), 0.0)
	moon.light_energy = 0.88
	moon.light_color = Color(0.54, 0.68, 1.0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	moon.directional_shadow_blend_splits = true
	# Sans ce biais, une ombre rasante se décolle de l'objet qui la porte.
	moon.shadow_normal_bias = 1.4
	add_child(moon)

	var holder: WorldEnvironment = WorldEnvironment.new()
	holder.name = "Atmosphere"
	holder.environment = _environment()
	holder.camera_attributes = _exposure()
	add_child(holder)

func _environment() -> Environment:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.020, 0.022, 0.034)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Ambiante très basse, et bleutée. Elle ne sert qu'à empêcher le noir
	# absolu ; tout le reste vient des feux, des cierges et des vitraux.
	environment.ambient_light_color = Color(0.30, 0.40, 0.66)
	environment.ambient_light_energy = 0.44

	# Halo : c'est lui qui fait qu'une flamme éblouit au lieu d'être un rond
	# orange. Seuil au-dessus de 1 pour que seules les pièces émissives
	# débordent, et pas les murs clairs.
	environment.glow_enabled = true
	environment.glow_intensity = 0.72
	environment.glow_bloom = 0.18
	environment.glow_hdr_threshold = 1.30
	environment.glow_hdr_scale = 2.2
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Les niveaux de halo ne sont pas exposés comme propriétés typées ; ils se
	# règlent par leur nom. Trois octaves : un liseré serré, un halo moyen, et
	# une lueur large qui remplit la nef.
	environment.set(&"glow_levels/3", 1.0)
	environment.set(&"glow_levels/5", 0.7)
	environment.set(&"glow_levels/7", 0.4)

	# Occlusion ambiante : elle noircit les angles, les joints et le dessous
	# des bancs. Sur une architecture faite de blocs, c'est ce qui sépare le
	# mur du sol sans qu'on ait à peindre une ligne.
	environment.ssao_enabled = true
	environment.ssao_radius = 1.4
	environment.ssao_intensity = 2.0
	environment.ssao_power = 1.35
	environment.ssao_detail = 0.6
	environment.ssao_light_affect = 0.15

	# Brouillard volumétrique : les rayons des vitraux et la lueur des braseros
	# deviennent visibles DANS l'air. C'est ce qui donne sa profondeur à une
	# scène sans texture, et ce qui masque le bout du couloir.
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.021
	environment.volumetric_fog_albedo = Color(0.58, 0.66, 0.90)
	environment.volumetric_fog_emission = Color(0.020, 0.022, 0.036)
	environment.volumetric_fog_gi_inject = 0.6
	environment.volumetric_fog_anisotropy = 0.32
	environment.volumetric_fog_length = 72.0
	environment.volumetric_fog_ambient_inject = 0.8

	environment.fog_enabled = true
	environment.fog_light_color = Color(0.10, 0.11, 0.17)
	environment.fog_density = 0.006
	environment.fog_sky_affect = 0.0

	# Contraste et saturation : sans cela, une palette de gris reste une
	# palette de gris, quelle que soit la qualité de l'éclairage.
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.16
	environment.adjustment_saturation = 1.10
	environment.adjustment_brightness = 1.02

	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 3.2
	return environment

## Exposition. Le rendu travaille en HDR : sans exposition explicite, une
## flamme à énergie 4 et un mur à énergie 0,3 sont écrasés dans la même plage.
func _exposure() -> CameraAttributesPractical:
	var attributes: CameraAttributesPractical = CameraAttributesPractical.new()
	attributes.exposure_multiplier = 1.05
	attributes.auto_exposure_enabled = false
	return attributes
