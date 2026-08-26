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
## Hauteur d'un muret bordant une zone à ciel ouvert. À hauteur de poitrine :
## il arrête, il ne cache pas.
const RAMPART_HEIGHT: float = 1.15
## Hauteur maximale de la grille du raccourci, en mètres. Une porte se franchit
## à pied ; elle n'a pas la taille d'un mur de nef.
const GATE_HEIGHT: float = 4.4

# Sol volontairement sombre : dehors, le sel est ce qu'il y a de blanc dans
# l'image. Un dallage a 0,62 passait au blanc pur sous le soleil et avalait
# et les tas de sel et la variation de teinte des dalles.
#
# TIÈDE, aussi. Il était neutre — 0,44 des trois côtés — et sous un soleil
# ambré un gris neutre ne devient pas chaud, il devient sale. Une pierre a une
# teinte propre, et c'est elle qui répond au bleu des ombres.
const COLOR_FLOOR: Color = Color(0.48, 0.41, 0.34)
const COLOR_WALL: Color = Color(0.56, 0.48, 0.40)
# Plafond FROID. C'est la seule grande surface d'un intérieur qui ne reçoit
# jamais le soleil : elle doit donc être de la couleur de ce qui reste quand
# le soleil n'est pas là — le ciel indigo — et non un gris neutre. C'est ce
# qui met du bleu au-dessus de la tête pendant que le sol est ambré.
const COLOR_CEILING: Color = Color(0.13, 0.15, 0.21)
const COLOR_GATE: Color = Color(0.40, 0.34, 0.24)
const COLOR_BONFIRE: Color = Color(1.0, 0.50, 0.16)
const COLOR_SWITCH: Color = Color(0.50, 0.86, 0.76)
const COLOR_ASH: Color = Color(0.20, 0.22, 0.22)
const COLOR_LOG: Color = Color(0.22, 0.18, 0.14)
const COLOR_BLADE: Color = Color(0.66, 0.68, 0.66)
const COLOR_IRON: Color = Color(0.24, 0.27, 0.27)
const COLOR_EMBER: Color = Color(1.0, 0.72, 0.30)
const COLOR_STONE: Color = Color(0.58, 0.59, 0.57)
const COLOR_STONE_DARK: Color = Color(0.40, 0.42, 0.41)

## Portée d'un FAISCEAU rapportée à celle d'une ampoule nue de même puissance.
## Une lampe qui envoie tout d'un côté porte bien plus loin que la même en
## boule : c'est ce facteur qui transforme la portée déclarée sur un panneau
## de verre — pensée pour une simple lueur autour de lui — en la longueur du
## rai qu'il jette dans la salle.
const BEAM_REACH: float = 4.6
## À quelle distance du panneau on va demander à la simulation ce qu'il y a
## des deux côtés. Assez loin pour sortir de l'épaisseur du mur, assez près
## pour rester dans la salle que le panneau éclaire.
const PANEL_PROBE: float = 1.4
## Charge d'air ajoutée dans une salle couverte. C'est ce qui donne un CORPS
## au rai : sans elle, on ne voit que l'ombre de la claire-voie posée sur le
## dallage, jamais le faisceau entre les deux.
const ROOM_HAZE: float = 0.048

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
	_build_rooms(level)

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
				# Dehors, pas de dalle : c'est tout l'intérêt.
				if not level.is_open(cell):
					ceiling_cells.append(Vector3(x, height, z))
				# Là où une salle basse touche une salle haute, il reste une
				# bande de vide entre les deux plafonds. Sans ce pan, on voit
				# à travers le décor : c'est le mur qu'aurait toute vraie
				# maçonnerie au-dessus d'une arcade.
				var above: float = _tallest_neighbour(cell, level)
				if above > height + 0.05 and not _borders_sky(cell, level):
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

	# Le sol se pose d'une seule passe, et les dalles se CHEVAUCHENT d'un
	# centimètre et demi. Ce n'est pas un détail : le joint creusé qu'on avait
	# avant exposait quatre faces verticales par dalle, et la passe d'encre
	# détoure toute face verticale. À une dalle par mètre, ça faisait du papier
	# millimétré sur cinquante mètres — le défaut le plus visible de l'image.
	# Ce qui distingue une dalle de sa voisine, désormais, c'est sa teinte
	# seule (`_stone_tint`), et le chevauchement garantit qu'aucune arête ne
	# peut réapparaître entre deux dalles coplanaires.
	_add_slabs("Floor", floor_cells, -SLAB_THICKNESS * 0.5, COLOR_FLOOR, -0.015)
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
		if not SimMath.point_is_free(probe, level.walkable, no_blockers):
			continue
		# Un muret borde le dehors, pas une muraille de vingt-quatre mètres.
		# C'est ce qui fait qu'on VOIT le bassin depuis la digue.
		if level.is_open(probe):
			best = maxf(best, RAMPART_HEIGHT)
		else:
			best = maxf(best, level.height_at(probe))
	return best

## Vrai si l'une des cases voisines est à ciel ouvert. Sert à ne pas dresser
## un pan de mur de vingt-quatre mètres au seuil d'une porte qui donne dehors.
func _borders_sky(cell: Vector2, level: LevelData) -> bool:
	var no_blockers: Array[Rect2] = []
	for offset: Vector2 in [Vector2(CELL, 0.0), Vector2(-CELL, 0.0),
			Vector2(0.0, CELL), Vector2(0.0, -CELL)]:
		var probe: Vector2 = cell + offset
		if SimMath.point_is_free(probe, level.walkable, no_blockers) \
				and level.is_open(probe):
			return true
	return false

## Dalles toutes identiques : `at.y` porte la hauteur, la boîte ne change pas.
## `joint` rétrécit la dalle ; une valeur NÉGATIVE l'élargit, et c'est ce qu'on
## veut au sol pour que deux dalles voisines se chevauchent au lieu de laisser
## une arête que la passe d'encre irait détourer.
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
	# GRAIN PAR DALLE, pas motif. La version précédente empilait deux sinus de
	# basse fréquence : sur quarante mètres ça ne fait pas du hasard, ça fait
	# un TARTAN — de grands carrés clairs et sombres qu'on lit comme un défaut
	# de rendu. Le bruit doit venir de la dalle elle-même.
	var grain: float = _hash(cell.x, cell.z) - 0.5
	# Et une dérive lente par-dessus, de très basse amplitude : elle empêche le
	# grain d'être uniforme sur toute la halle sans dessiner de figure.
	var drift: float = sin(cell.x * 0.083 + cell.z * 0.051) * 0.5 \
		+ sin(cell.x * 0.037 - cell.z * 0.061) * 0.5
	var shade: float = 1.0 + grain * 0.11 + drift * 0.05
	# Auréoles de saumure : la pierre d'une saline est tachée, et ces taches
	# sont FROIDES sur une pierre chaude. C'est le contraste de teinte qui
	# porte le sol, pas le contraste de valeur.
	var patch: float = _blob(cell.x, cell.z, 0.19) * 0.68 \
		+ _blob(cell.x, cell.z, 0.47) * 0.32
	var stain: float = clampf(patch * 1.7 - 0.72, 0.0, 1.0) * 0.30
	# Le VERT compte autant que le bleu. Une auréole qui ne fait que perdre du
	# rouge vire au bleu d'ombre, c'est-à-dire à la même couleur que tout ce
	# qui est déjà à l'ombre : elle disparaît. Poussée vers le TURQUOISE de la
	# saumure, elle devient le second pôle de teinte du niveau, présent jusque
	# sur le dallage, et il n'y a rien de moins cher qu'une couleur par
	# instance.
	return Color(shade * (1.0 - stain * 1.30), shade * (1.0 + stain * 0.12),
		shade * (1.0 + stain * 0.42), 1.0)

## Tache douce, entre 0 et 1 : la même table de hachage, mais INTERPOLÉE entre
## les quatre coins de sa maille au lieu d'être lue en escalier.
##
## Lire `_hash(floorf(x * k), floorf(z * k))` donne un DAMIER : chaque maille
## rend une valeur, plate d'un bord à l'autre, et les bords sont alignés sur
## les axes du monde comme les dalles. À k = 0,24 la maille fait 4,17 m, et le
## parvis se lisait comme un carrelage de grands carreaux roses et gris — le
## défaut le plus voyant de l'image, sur le sol qu'on regarde le plus.
##
## La maille est en plus TOURNÉE d'une vingtaine de degrés : alignée, même
## interpolée, elle laisserait des lignes de crête parallèles aux murs.
func _blob(x: float, z: float, scale: float) -> float:
	var rx: float = (x * 0.94 - z * 0.34) * scale
	var rz: float = (x * 0.34 + z * 0.94) * scale
	var x0: float = floorf(rx)
	var z0: float = floorf(rz)
	var fx: float = smoothstep(0.0, 1.0, rx - x0)
	var fz: float = smoothstep(0.0, 1.0, rz - z0)
	var bas: float = lerpf(_hash(x0, z0), _hash(x0 + 1.0, z0), fx)
	var haut: float = lerpf(_hash(x0, z0 + 1.0), _hash(x0 + 1.0, z0 + 1.0), fx)
	return lerpf(bas, haut, fz)

## Bruit reproductible sur deux coordonnées, entre 0 et 1.
func _hash(x: float, z: float) -> float:
	var v: float = sin(x * 127.1 + z * 311.7) * 43758.5453
	return v - floorf(v)

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
		_add_light(root, part, tone, level)
		# `mesh_path` FAIT PARTIE DE LA CLÉ : sans lui, un tonneau et un banc
		# importés partageraient un lot et sortiraient tous deux en tonneau.
		var key: String = "%d|%s|%d|%s|%d|%s" % [part.shape, part.size,
			part.surface, tone.to_html(), 1 if part.unshaded else 0,
			part.mesh_path]
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
			if part.shape == SkinPart.Shape.ELLIPSOID \
					or part.shape == SkinPart.Shape.MESH:
				basis = basis.scaled(part.size)
			multimesh.set_instance_transform(index,
				Transform3D(basis, part.offset))
		var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
		batch.multimesh = multimesh
		# Un maillage importé garde ses propres matières — voir
		# `PrimitiveFactory.instance_for`. Un `material_override` les
		# écraserait toutes d'un aplat, et deux cents tonneaux redeviendraient
		# deux cents blocs de la couleur du décor.
		if first.shape != SkinPart.Shape.MESH:
			batch.material_override = PrimitiveFactory.material_for(
				tone, first.unshaded, first.surface,
				0.0 if first.light_range <= 0.0
				else 1.15 + first.light_range * 0.13)
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
func _add_light(root: Node3D, part: SkinPart, tone: Color,
		level: LevelData) -> void:
	if part.light_range <= 0.0:
		return
	# Un PANNEAU n'est pas une ampoule. Voir `_panel_normal`.
	var beam: Vector3 = _panel_normal(part, level)
	if beam != Vector3.ZERO:
		_add_beam(root, part, tone, beam)
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

## Normale d'un panneau lumineux plat, tournée vers la salle qu'il éclaire.
## Zéro si la pièce n'est pas un panneau, ou si ses deux faces donnent sur le
## même genre d'espace.
##
## C'EST D'ICI QUE VIENNENT LES RAIS DE LUMIÈRE. Un verre de saumure est
## plaqué contre un mur ; il verse la lumière DEVANT lui, en un faisceau que
## la brume rend visible d'un bout à l'autre de la salle. Une omni au même
## endroit n'en fabrique aucun : elle éclaire autant le mur derrière elle que
## la nef, donc elle allume la brume de façon uniforme — et une brume
## uniformément allumée n'est pas un rai, c'est du lait.
##
## Le côté éclairé se DÉDUIT, il ne se déclare pas : c'est celui qui donne sur
## une salle couverte. Un panneau brille parce qu'il fait plus clair dehors
## que dedans ; c'est donc dedans qu'il faut verser la lumière. Poser ce choix
## à la main dans la donnée, c'est signer pour le jour où un mur bouge et où
## seize fenêtres éclairent le vide.
func _panel_normal(part: SkinPart, level: LevelData) -> Vector3:
	if part.shape != SkinPart.Shape.BOX or part.surface != SkinPart.Surface.GLOW:
		return Vector3.ZERO
	# Plat : mince sur son axe local Z devant ses deux autres côtés.
	if part.size.z > part.size.x * 0.35 or part.size.z > part.size.y * 0.35:
		return Vector3.ZERO
	var facing: Basis = Basis.from_euler(Vector3(
		deg_to_rad(part.rotation_degrees.x),
		deg_to_rad(part.rotation_degrees.y),
		deg_to_rad(part.rotation_degrees.z)))
	var axis: Vector3 = facing.z.normalized()
	var no_blockers: Array[Rect2] = []
	var toward: Vector3 = Vector3.ZERO
	for side: float in [1.0, -1.0]:
		var probe: Vector3 = part.offset + axis * side * PANEL_PROBE
		var flat: Vector2 = Vector2(probe.x, probe.z)
		if not SimMath.point_is_free(flat, level.walkable, no_blockers):
			continue
		if level.is_open(flat):
			continue
		# Les deux côtés sont des salles couvertes : ce n'est pas une fenêtre,
		# c'est une lanterne posée entre deux pièces. Elle garde son omni.
		if toward != Vector3.ZERO:
			return Vector3.ZERO
		toward = axis * side
	return toward

## Le faisceau d'un panneau. Sans ombre — c'est la géométrie du mur et de la
## charpente qui découpe déjà le rai, pas une carte d'ombre de plus — et avec
## une énergie de brume relevée : ce qu'on veut voir, c'est le CÔNE dans
## l'air, pas seulement la tache au sol.
func _add_beam(root: Node3D, part: SkinPart, tone: Color,
		toward: Vector3) -> void:
	var up: Vector3 = Vector3.UP
	if absf(toward.dot(up)) > 0.98:
		up = Vector3.FORWARD
	var beam: SpotLight3D = SpotLight3D.new()
	beam.transform = Transform3D(Basis.looking_at(toward, up),
		part.offset + toward * 0.25)
	beam.spot_range = part.light_range * BEAM_REACH
	# Assez large pour éclairer une travée, assez serré pour rester un rai.
	beam.spot_angle = 44.0
	beam.spot_angle_attenuation = 0.85
	beam.spot_attenuation = 1.25
	beam.light_energy = 0.22 * beam.spot_range
	# À PEINE désaturé, contrairement aux omnis. Il n'y en a qu'une poignée,
	# et c'est le SEUL froid franc qui entre dans une salle par ailleurs
	# ambrée : le désaturer comme une torche reviendrait à effacer la seule
	# opposition de teinte que le niveau ait à l'intérieur.
	beam.light_color = tone.lerp(Color(0.88, 1.0, 0.98), 0.20)
	beam.shadow_enabled = false
	beam.light_volumetric_fog_energy = 5.0
	root.add_child(beam)

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
	# UNE PORTE, PAS UNE MURAILLE. La hauteur venait de `height_at`, qui rend
	# le dégagement de ciel — vingt-quatre mètres — au-dessus d'une zone
	# ouverte. Le raccourci passant justement dehors, la grille était un
	# monolithe de vingt-quatre mètres planté devant l'arène, visible depuis la
	# moitié du niveau, et pris pour un défaut de décor pendant des jours.
	var height: float = minf(level.height_at(centre), GATE_HEIGHT)
	var gate: MeshInstance3D = _add_box(
		Vector3(rect.size.x, height, rect.size.y),
		Vector3(centre.x, height * 0.5, centre.y), COLOR_GATE,
		SkinPart.Surface.METAL)
	gate.name = "ShortcutGate"
	# Linteau : il pose la grille sous quelque chose, au lieu de la laisser
	# s'arrêter en l'air.
	var lintel: MeshInstance3D = _add_box(
		Vector3(rect.size.x + 0.8, 0.55, rect.size.y + 0.8),
		Vector3(centre.x, height + 0.28, centre.y), COLOR_STONE_DARK,
		SkinPart.Surface.STONE)
	lintel.name = "ShortcutLintel"
	for side: float in [-1.0, 1.0]:
		var post: MeshInstance3D = _add_box(
			Vector3(0.5, height + 0.55, rect.size.y + 0.8),
			Vector3(centre.x + side * (rect.size.x * 0.5 + 0.25),
				(height + 0.55) * 0.5, centre.y), COLOR_STONE,
			SkinPart.Surface.STONE)
		post.name = "ShortcutPost"
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
	# SOLEIL COUCHANT, TRÈS BAS. C'est le pivot de toute la direction
	# artistique du niveau, et ce qui a le plus manqué jusqu'ici.
	#
	# Le jeu était éclairé par un midi blanc sur des matières grises sous une
	# brume blanche : trois absences de couleur superposées. On peut soigner
	# les modèles autant qu'on veut, une image sans écart de teinte ET sans
	# écart de valeur ne peut pas être belle — il n'y a rien à regarder.
	#
	# Un soleil à seize degrés donne tout d'un coup : des ombres longues qui
	# dessinent le relief du sol, une lumière AMBRÉE contre des ombres BLEUES
	# — le seul contraste de teinte qui marche à tous les coups —, et un ciel
	# qui vaut la peine d'être reflété par les bassins.
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Soleil"
	# LE SOLEIL EST AU SUD, DEVANT LA GRANDE PORTE. C'est le changement qui
	# donne tout le reste, et il ne coûte que deux nombres.
	#
	# Il était au nord-ouest, DERRIÈRE la halle. Conséquence : aucune de ses
	# ouvertures n'en voyait un rayon. La halle a pourtant une porte de vingt
	# mètres sur sept, plein sud, et cette porte est barrée par les trois
	# sablières et les cinq poteaux du colombage du bassin — une claire-voie
	# faite exprès pour découper la lumière. Elle ne servait à rien : il n'y
	# avait rien à découper. On peut régler la brume tant qu'on veut, sans
	# lumière qui ENTRE il n'y a pas de rai.
	#
	# Au sud, le même soleil rasant traverse le bassin, franchit la porte et
	# pose sur le dallage de la nef une nappe barrée d'ombres, sur quinze
	# mètres. Et comme le niveau se parcourt du nord vers le sud, le joueur
	# marche vers le couchant du début à la fin : tout ce qu'il a devant lui
	# est à CONTRE-JOUR, ce qui est la seule façon d'obtenir de l'écart de
	# valeur sans peindre quoi que ce soit.
	sun.rotation = Vector3(deg_to_rad(-15.0), deg_to_rad(-22.0), 0.0)
	sun.light_energy = 3.4
	sun.light_color = Color(1.0, 0.72, 0.42)
	sun.shadow_enabled = true
	# RESSERRÉE. À cent vingt mètres, la première tranche d'ombre couvrait
	# assez de terrain pour qu'une sablière de vingt-six centimètres ne pèse
	# plus un texel : le rai passait, mais sans barreaux. Quatre-vingt-dix
	# mètres portent encore jusqu'au fond du parvis et rendent la claire-voie
	# lisible.
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_blend_splits = true
	# Sans ce biais, une ombre rasante se décolle de l'objet qui la porte — et
	# à quinze degrés, toutes les ombres sont rasantes. Mais il DÉPLACE le
	# point de test le long de la normale : à 1,6 il gommait purement et
	# simplement l'ombre des pièces minces, c'est-à-dire toute la charpente.
	sun.shadow_normal_bias = 0.8
	sun.shadow_bias = 0.035
	# La part du soleil DANS L'AIR se règle à part de sa part sur les
	# surfaces. À 1,0 il éclairait correctement le dallage sans jamais se voir
	# dans la brume : c'est le rai lui-même qui manquait, pas son ombre.
	sun.light_volumetric_fog_energy = 2.6
	add_child(sun)

	# Contre-jour froid, sans ombre. Il ne sert qu'à décoller les silhouettes
	# du fond du côté opposé au soleil : sans lui, tout ce qui n'est pas
	# éclairé de face devient une découpe noire, ce qui est exactement le
	# reproche qu'on faisait à l'image.
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "Contre-jour"
	# EXACTEMENT À L'OPPOSÉ DU SOLEIL, et franchement bleu. Le soleil étant
	# passé au sud, la face qu'on voit d'à peu près tout est celle qu'il
	# n'éclaire pas : c'est cette lampe-là qui décide de la couleur de la
	# moitié de l'image, et c'est pour ça qu'elle a le droit d'être saturée.
	fill.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(158.0), 0.0)
	fill.light_energy = 0.90
	fill.light_color = Color(0.16, 0.58, 1.0)
	fill.shadow_enabled = false
	# ELLE NE PEINT PAS DE SECOND SOLEIL. Un ciel procédural dessine un disque
	# pour CHAQUE lumière directionnelle qui l'y autorise : celle-ci en posait
	# un deuxième, bleu, à l'opposé du vrai. On ne le remarquait pas tant que
	# le ciel était uniformément rose ; il crève les yeux dès qu'il ne l'est
	# plus.
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)

	var holder: WorldEnvironment = WorldEnvironment.new()
	holder.name = "Atmosphere"
	holder.environment = _environment()
	holder.camera_attributes = _exposure()
	add_child(holder)

func _environment() -> Environment:
	var environment: Environment = Environment.new()
	# Un CIEL, pas un aplat. C'est lui qui fait qu'on sort d'un bâtiment au
	# lieu de passer d'une salle à une autre : au-dessus du bassin il n'y a
	# rien, et ce rien doit être éblouissant.
	environment.background_mode = Environment.BG_SKY
	environment.sky = _sky()
	environment.background_color = Color(0.026, 0.031, 0.034)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# L'ambiante vient du CIEL, presque entièrement. C'est ce qui rend les
	# ombres bleues sans qu'on ait à peindre quoi que ce soit : au crépuscule,
	# ce qui n'est pas touché par le soleil est éclairé par un demi-dôme
	# indigo, et c'est de là que vient le contraste chaud/froid.
	# Moitié ciel, moitié bleu déclaré. À 0,92 de ciel, l'ambiante prenait
	# l'ORANGE de l'horizon et les ombres devenaient brunes : on se retrouvait
	# avec une image d'une seule teinte, ce qui n'est pas mieux qu'une image
	# sans teinte du tout. La moitié déclarée garantit que ce qui est à l'ombre
	# est FROID, quoi que fasse le ciel.
	# Un tiers de ciel, c'était encore trop : le ciel d'un couchant est ambré
	# sur toute sa moitié basse, et c'est cette moitié-là qu'une surface voit.
	# L'ambiante prenait donc l'orange, les ombres devenaient brunes, et
	# l'image entière tenait sur une seule teinte — un saumon uniforme du
	# dallage au zénith. Le contre-pôle doit être DÉCLARÉ, sans quoi il n'y en
	# a pas.
	environment.ambient_light_sky_contribution = 0.22
	# TRÈS saturée, et ce n'est pas un excès. Le dallage a une teinte propre
	# TIÈDE (0,48 / 0,41 / 0,34) : une lumière bleue pâle multipliée par un
	# albédo tiède ne donne pas du bleu, elle donne du MAUVE — c'est ce que
	# l'image rendait, mesuré à 322° de teinte dans l'ombre du personnage,
	# c'est-à-dire du magenta. Il faut une ambiante franchement bleue pour
	# qu'une pierre chaude à l'ombre lise bleu.
	#
	# ET CYAN, PAS BLEU MARINE. Mesuré : avec une ambiante sans vert, l'ombre
	# du parvis sortait à 309° de teinte — du MAGENTA. Une lumière qui n'a que
	# du rouge et du bleu, posée sur une pierre tiède, ne peut rien donner
	# d'autre. Ce qui remplit l'ombre d'une saline au couchant, ce n'est pas un
	# bleu de nuit : c'est le zénith PLUS ce que la saumure renvoie, et la
	# saumure est turquoise. Le vert n'est pas une licence, c'est ce qui manque
	# pour que l'ombre soit froide au lieu d'être violette.
	environment.ambient_light_color = Color(0.10, 0.50, 1.0)
	environment.ambient_light_energy = 1.10
	# Réflexions du ciel sur tout ce qui est lisse. Sans cette ligne, les
	# nappes de saumure renvoient du noir et la surface LIQUID ne sert à rien.
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# ÉCLAIRAGE INDIRECT. C'est ce qui manquait pour de bon.
	#
	# Sans lui, une ambiante est un nombre unique appliqué partout : la monter
	# pour que le dehors respire inondait l'intérieur de la halle de la même
	# lumière et la halle devenait un hangar rose ; la baisser pour que la
	# halle soit sombre écrasait le dehors. Aucune valeur ne convient aux deux,
	# parce que le problème n'est pas la valeur — c'est qu'un toit ne bloquait
	# rien du tout.
	#
	# SDFGI occlut l'ambiante ET fait rebondir la lumière : le soleil rasant
	# frappe le sel du parvis, rebondit par la grande porte et remonte sous les
	# membrures. C'est de la lumière qu'aucun réglage manuel n'aurait produite.
	environment.sdfgi_enabled = true
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_read_sky_light = true
	environment.sdfgi_bounce_feedback = 0.6
	# Rendu à l'unité. À 1,35, le rebond du parvis — cinquante mètres de sel
	# ambré — repeignait tout l'intérieur de la halle de sa propre couleur et
	# reprenait d'une main l'écart de teinte que l'ambiante bleue donnait de
	# l'autre. Un rebond doit se deviner, pas décider.
	environment.sdfgi_energy = 0.75
	environment.sdfgi_cascades = 4
	environment.sdfgi_min_cell_size = 0.35
	environment.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT

	# Halo : c'est lui qui fait qu'une flamme éblouit au lieu d'être un rond
	# orange. Seuil au-dessus de 1 pour que seules les pièces émissives
	# débordent, et pas les murs clairs.
	environment.glow_enabled = true
	environment.glow_intensity = 0.60
	environment.glow_bloom = 0.14
	environment.glow_hdr_threshold = 1.20
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
	environment.ssao_intensity = 1.05
	environment.ssao_power = 1.35
	environment.ssao_detail = 0.6
	environment.ssao_light_affect = 0.15

	# Brouillard volumétrique : les rayons des vitraux et la lueur des braseros
	# deviennent visibles DANS l'air. C'est ce qui donne sa profondeur à une
	# scène sans texture, et ce qui masque le bout du couloir.
	# BRUME VOLUMÉTRIQUE. Elle était allumée et ne montrait rien ; les quatre
	# réglages ci-dessous se contredisaient l'un l'autre.
	#
	# 1. La DENSITÉ valait 0,010 quand le défaut du moteur est 0,05. Un rai
	#    n'est rien d'autre que de la matière éclairée : à un cinquième de
	#    matière, il n'y a qu'un cinquième de rai.
	#
	#    Mais la monter ICI la monte PARTOUT, et c'est une erreur qui a coûté
	#    une prise : à 0,055 uniformes, le parvis disparaissait derrière un
	#    mur de brume dorée — mesuré, l'ombre au sol y remontait à 0,25 de
	#    luminance et 5° de teinte, c'est-à-dire du rouge. Dehors, un couchant
	#    clair ne fait pas de rais ; il n'y a rien à charger. C'est l'air des
	#    salles COUVERTES qu'il faut charger, et c'est ce que fait
	#    `_build_rooms` avec un volume de brume par salle. Ici, il n'en reste
	#    qu'un souffle.
	#
	#    Un souffle et pas ZÉRO : la brume volumétrique doit rester allumée
	#    pour que les volumes de salle existent, et une densité nulle est une
	#    invitation à ce qu'une version du moteur saute la passe entière.
	#
	#    Mesuré aussi, et c'est la deuxième fois que la même erreur se paie :
	#    à 0,007 avec une anisotropie moyenne, la lumière du soleil diffusée
	#    dans TOUS les sens remontait l'ombre du parvis de 0,15 à 0,21 de
	#    luminance et sa teinte de 309° à 340° — c'est-à-dire qu'elle la
	#    reteintait en rose. Une brume éclairée par un soleil ambré ne peut pas
	#    servir à refroidir une ombre ; dehors, elle n'a rien à y faire.
	# 2. `gi_inject` à 1,0 versait tout l'éclairage indirect dans les froxels,
	#    Y COMPRIS CEUX QUI SONT À L'OMBRE. Or un rai n'est pas fait de
	#    lumière : il est fait du CONTRASTE entre l'air éclairé et l'air qui
	#    ne l'est pas. Remplir l'ombre, c'est effacer le rai — c'était le
	#    réglage le plus coûteux des quatre. Il en reste juste de quoi que
	#    l'air d'une salle fermée ne soit pas noir.
	# 3. `ambient_inject` à 0,5 faisait la même chose avec l'ambiante. Zéro.
	# 4. La LONGUEUR à 140 mètres étalait un tampon de résolution fixe sur
	#    tout le niveau : chaque tranche faisait plus de deux mètres
	#    d'épaisseur près de la caméra, et l'ombre d'une sablière de vingt-six
	#    centimètres se noyait dans la tranche. À 60 mètres, les tranches sont
	#    assez fines pour que la claire-voie se lise. Au-delà, c'est le
	#    brouillard de distance qui prend le relais — il est fait pour ça.
	environment.volumetric_fog_enabled = true
	# 0,032 posait déjà les barres de la claire-voie SUR LE SOL, mais l'air
	# entre elles restait vide : on voyait l'ombre du rai, pas le rai. Il faut
	# la densité par défaut du moteur pour que le faisceau ait un corps.
	environment.volumetric_fog_density = 0.0015
	# Albédo NEUTRE-FROID. Il était ambré : la brume teintait alors en orange
	# jusqu'à ce que les faisceaux de saumure éclairaient, et il n'y avait
	# plus une seule zone froide dans l'image.
	environment.volumetric_fog_albedo = Color(0.86, 0.89, 0.94)
	# Ce que l'air rend quand RIEN ne l'éclaire. Indigo : l'air d'une salle
	# fermée est bleu, celui d'un rai est ambré, et c'est ce couple-là qui
	# tient l'intérieur.
	environment.volumetric_fog_emission = Color(0.010, 0.017, 0.038)
	environment.volumetric_fog_gi_inject = 0.12
	# ANISOTROPIE MOYENNE, et c'est un choix contre la physique. Une brume
	# réelle diffuse vers l'avant : à 0,80 elle ne s'allume que si on regarde
	# à peu près DANS l'axe de la lumière. C'est juste, et c'est inutilisable
	# dans un jeu à la troisième personne — mesuré sur trois prises, le rai
	# tombé de la grande porte posait ses barres sur le dallage et restait
	# invisible dans l'air dès que la caméra le prenait de trois quarts, ce
	# qui est l'angle sous lequel on le voit tout le temps. À 0,42 le faisceau
	# a un corps depuis le côté, et il s'allume encore franchement quand on lui
	# fait face.
	environment.volumetric_fog_anisotropy = 0.42
	environment.volumetric_fog_length = 60.0
	environment.volumetric_fog_ambient_inject = 0.0
	# La reprojection converge en une dizaine d'images. À 0,9, une caméra qui
	# se pose quelque part traîne la brume de l'endroit d'avant pendant une
	# demi-seconde ; à 0,6 elle est en place presque tout de suite, au prix
	# d'un grain un peu plus visible dans les rais.
	environment.volumetric_fog_temporal_reprojection_amount = 0.6
	# ET ELLE NE TOUCHE PAS AU CIEL. Par défaut la brume volumétrique se
	# dépose aussi sur le fond, qui est à l'infini : le couchant y perdait sa
	# saturation d'un coup — mesuré, le haut du ciel est passé de 0,75 à 0,62
	# de saturation entre deux prises pour cette seule raison. Le brouillard de
	# distance, lui, a la même règle depuis toujours (`fog_sky_affect`).
	environment.volumetric_fog_sky_affect = 0.0

	environment.fog_enabled = true
	# Brume BLEUE de fond, qui se réchauffe vers le soleil. `fog_sun_scatter`
	# fait tout le travail : le lointain vire au bleu profond partout sauf
	# autour du soleil, où il vire à l'orange. Une brume d'une seule couleur —
	# et blanche par-dessus le marché — écrase la profondeur au lieu de la
	# fabriquer.
	environment.fog_light_color = Color(0.19, 0.30, 0.54)
	# La diffusion vers le soleil était à 0,65 : les trois quarts du lointain
	# repassaient à l'orange, y compris là où le soleil n'est pas. Rabattue,
	# elle ne réchauffe plus que ce qui est effectivement dans son axe.
	environment.fog_sun_scatter = 0.28
	environment.fog_density = 0.0030
	environment.fog_sky_affect = 0.0
	# La perspective aérienne délave les couleurs propres au profit de celle
	# de la brume. À 0,35 elle mangeait la moitié de la teinte de tout ce qui
	# est à plus de vingt mètres, ce qui, sur un niveau de cent quatre-vingts
	# mètres, veut dire presque tout.
	environment.fog_aerial_perspective = 0.11

	# Contraste et saturation : sans cela, une palette de gris reste une
	# palette de gris, quelle que soit la qualité de l'éclairage.
	environment.adjustment_enabled = true
	# Il y a enfin de la couleur à saturer. Sur la palette de gris d'avant,
	# monter la saturation ne faisait rien du tout ; c'était le signe qu'on
	# soignait le mauvais bout.
	environment.adjustment_contrast = 1.14
	environment.adjustment_saturation = 1.22
	environment.adjustment_brightness = 1.0

	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	# Le blanc valait 5,5 : tout le haut de la plage était comprimé dans le
	# dernier quart de l'échelle et l'image n'avait plus ni noir franc ni
	# blanc franc — un tapis de valeurs moyennes, ce qu'on lit comme du
	# délavé. À 4,2, le soleil brûle encore mais le reste respire.
	environment.tonemap_white = 4.2
	return environment

## Exposition. Le rendu travaille en HDR : sans exposition explicite, une
## flamme à énergie 4 et un mur à énergie 0,3 sont écrasés dans la même plage.
## Ciel du bassin : blanc laiteux au zénith, plus dense à l'horizon, sans un
## soleil visible. Le sel renvoie tellement de lumière qu'on ne distingue plus
## où finit le sol et où commence l'air — c'est ce qu'on cherche.
func _sky() -> Sky:
	var material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	# Indigo au zénith, braise à l'horizon. Trois octaves de valeur entre les
	# deux : c'est ce dégradé que les bassins renvoient, et c'est lui qui donne
	# sa couleur à toutes les ombres du niveau, puisque l'ambiante vient du
	# ciel.
	# ZÉNITH FRANCHEMENT SOMBRE ET FROID. Il était clair et mauve : le dôme
	# entier tirait alors vers le rose, l'ambiante venue du ciel avec lui, et
	# tout ce que le bassin renvoyait aussi. Un ciel de couchant n'est pas
	# rose partout — il est rose SUR TROIS DOIGTS AU-DESSUS DE L'HORIZON, et
	# bleu de nuit au-dessus. C'est cet écart-là qu'on regarde.
	material.sky_top_color = Color(0.045, 0.085, 0.26)
	material.sky_horizon_color = Color(0.98, 0.50, 0.24)
	# Courbe SERRÉE. À 0,30, la bande chaude de l'horizon montait jusqu'au
	# zénith et le ciel n'était plus qu'un aplat saumon : c'est de là que
	# venait la teinte unique de toute l'image, puisque l'ambiante et les
	# reflets sortent d'ici. À 0,11, la braise reste une bande, l'indigo
	# occupe le dôme, et le dégradé entre les deux est le sujet du ciel.
	material.sky_curve = 0.11
	material.sky_energy_multiplier = 0.95
	material.ground_bottom_color = Color(0.035, 0.050, 0.090)
	material.ground_horizon_color = Color(0.52, 0.29, 0.19)
	material.ground_curve = 0.05
	material.ground_energy_multiplier = 0.7
	# Un DISQUE SOLAIRE, cette fois. Un ciel sans soleil n'a pas de direction,
	# et un couchant sans soleil n'est qu'un dégradé.
	# Disque SERRÉ, halo LARGE. À huit degrés le disque faisait un tiers du
	# ciel : ce n'était plus un soleil, c'était un projecteur, et le halo le
	# répandait sur tout le haut de l'image. Trois degrés et demi avec une
	# courbe molle donnent un vrai disque entouré de sa braise.
	material.sun_angle_max = 3.5
	material.sun_curve = 0.14
	var sky: Sky = Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	return sky

func _exposure() -> CameraAttributesPractical:
	var attributes: CameraAttributesPractical = CameraAttributesPractical.new()
	# MESURÉ, pas estimé. À 1,0, le ciel du couchant sortait à (250,250,250)
	# — du blanc pur — et la brume du lointain à (254,243,191). Tout le haut
	# de l'image était donc écrêté, et ACES désature ce qu'il écrête : plus le
	# couchant montait, plus il devenait BLANC. On ne peut pas obtenir de
	# couleur d'une image qui touche le plafond.
	#
	# À 0,60 le même ciel garde son orange, les ombres descendent enfin dans
	# les basses valeurs, et le rapport entre les deux — qui est tout ce qui
	# fait une image — devient lisible.
	attributes.exposure_multiplier = 0.60
	# Exposition FIXE. Elle était automatique, et il le fallait tant que la
	# passe d'encre étalonnait entre un point noir et un point blanc figés :
	# sans elle, l'arène du boss tombait entièrement sous le point noir.
	#
	# Cette contrainte a disparu avec la posterisation, et l'auto-exposition
	# ne faisait plus que du mal : l'image s'assombrissait dès qu'on levait
	# les yeux vers le ciel et s'éclaircissait dès qu'on regardait un mur.
	# Une luminosité qui bouge quand on tourne la caméra, ça ne se lit pas
	# comme une caméra qui s'adapte — ça se lit comme un éclairage cassé.
	#
	# Elle est fixe, donc c'est à l'ÉCLAIRAGE d'être juste partout. C'est plus
	# exigeant, et c'est la seule façon d'obtenir une image stable.
	attributes.auto_exposure_enabled = false
	return attributes

## CE QU'UNE SALLE COUVERTE A DE PLUS QUE LE DEHORS : de l'air chargé, et un
## reflet. Les deux se déduisent de la donnée du niveau — jamais posés à la
## main : un volume placé ailleurs que la salle qu'il décrit est un bug qu'on
## met des heures à ne pas attribuer à l'éclairage.
##
## L'AIR D'ABORD. Un rai de lumière se voit parce que l'air d'une halle est
## chargé de poussière et d'embrun ; celui d'un parvis au couchant ne l'est
## pas. Une seule densité pour tout le niveau ne peut donc satisfaire ni l'un
## ni l'autre : montée pour la halle, elle noie le parvis ; baissée pour le
## parvis, elle vide la halle. Un volume de brume par salle règle les deux à
## la fois, et il tombe pile là où il faut puisque c'est le rectangle
## praticable lui-même qui le dessine.
##
## LE REFLET ENSUITE.
##
## Dehors, une nappe de saumure renvoie le ciel du couchant, et c'est ce que le
## niveau a de plus beau. Sous un toit, elle n'avait RIEN à renvoyer : la
## réflexion vient du ciel, et une salle fermée n'en voit pas. La cuve du
## bassin était donc un trou noir à liseré blanc au milieu de la seule pièce
## chaude du niveau. La sonde lui rend ce qu'il y a autour d'elle : la grande
## porte, le feu, la charpente.
##
## Rendues UNE FOIS, et sans toucher à l'ambiante : elles n'ont le droit de
## fournir que du reflet. C'est SDFGI qui décide de l'éclairage indirect, et
## deux réponses à la même question, c'est la garantie qu'elles divergeront.
func _build_rooms(level: LevelData) -> void:
	for index: int in level.walkable.size():
		if index < level.open_sky.size() and level.open_sky[index]:
			continue
		var rect: Rect2 = level.walkable[index]
		var centre: Vector2 = rect.position + rect.size * 0.5
		var height: float = level.height_at(centre)

		var haze: FogMaterial = FogMaterial.new()
		# S'AJOUTE au voile de fond, elle ne le remplace pas.
		haze.density = ROOM_HAZE
		haze.albedo = Color(0.86, 0.89, 0.94)
		# Fondu sur les bords : sans lui, l'air se coupe net au seuil de la
		# porte et on voit l'arête du volume en travers de l'image.
		haze.edge_fade = 0.30
		var air: FogVolume = FogVolume.new()
		air.name = "Air_%d" % index
		air.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		air.size = Vector3(rect.size.x, height, rect.size.y)
		air.position = Vector3(centre.x, height * 0.5, centre.y)
		air.material = haze
		add_child(air)

		var probe: ReflectionProbe = ReflectionProbe.new()
		probe.name = "Sonde_%d" % index
		probe.size = Vector3(rect.size.x, height, rect.size.y)
		probe.position = Vector3(centre.x, height * 0.5, centre.y)
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		# Pas de ciel dans une salle couverte : sinon la sonde rend le dôme
		# ambré à travers le toit et la cuve reflète un couchant qu'elle ne
		# voit pas.
		probe.interior = true
		probe.box_projection = true
		probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
		probe.max_distance = 100.0
		add_child(probe)
