## Fabrique le maillage du marais à partir de sa simulation.
##
## Le terrain n'est pas modélisé à la main : il est DÉDUIT des polygones de
## bassins. C'est la même idée que dans le réel — on creuse des bassins, et le
## talus est ce que l'argile laisse entre eux.
##
## Le profil d'un talus est celui d'une digue : la crête reste plate et à
## pleine hauteur, seuls les bords côté bassin s'adoucissent. Un lissage
## uniforme raserait un talus de soixante-dix centimètres, qui ne fait que
## trois cases de large — et ce talus est le terrain de jeu.
##
## Invariant 2 : cette classe LIT le marais et n'écrit jamais dedans.
class_name VueMarais
extends Node3D

## Passes de lissage appliquées aux seules cases de bassin.
const LISSAGES: int = 1
## Remontée maximale qu'un lissage peut infliger au fond d'un bassin, en mètres.
##
## Sans ce plafond, deux passes de moyenne suffisaient à relever tout le
## pourtour d'un œillet bien au-dessus de sa ligne d'eau : la nappe ne couvrait
## plus qu'un îlot central et le bassin paraissait sec. Un œillet réel a un
## fond PLAT et des bords francs ; ce qu'on veut adoucir, c'est la lèvre, pas
## la cuvette.
const REMONTEE_MAX: float = 0.055

var _marais: Marais = null
var _sol: MeshInstance3D = null
var _eaux: Array[MeshInstance3D] = []
var _materiau_eau: Array[ShaderMaterial] = []

func construire(marais: Marais, bruit: Texture2D) -> void:
	_marais = marais
	_batir_sol(bruit)
	_batir_eaux(bruit)

## Recopie l'état de l'eau dans la présentation. Appelé une fois par image :
## l'eau monte et descend, et c'est visible.
func rafraichir(vent: float) -> void:
	if _marais == null:
		return
	for i: int in range(_eaux.size()):
		if i >= _marais.bassins.size():
			break
		var bassin: Marais.Bassin = _marais.bassins[i]
		var vue: MeshInstance3D = _eaux[i]
		# Un bassin vide n'a pas de surface à montrer : on le cache plutôt que
		# de laisser une nappe d'épaisseur nulle scintiller contre le fond.
		var profondeur: float = bassin.profondeur()
		vue.visible = profondeur > 0.004
		vue.position = Vector3(0.0, bassin.niveau(), 0.0)
		var materiau: ShaderMaterial = _materiau_eau[i]
		materiau.set_shader_parameter(&"salinite", bassin.salinite)
		# La simulation sait l'épaisseur exacte de chaque nappe : le shader n'a
		# pas à la deviner dans le tampon de profondeur, il a juste à ne pas la
		# dépasser.
		materiau.set_shader_parameter(&"profondeur_nappe", profondeur)
		materiau.set_shader_parameter(&"vent", vent)
		# La pellicule affichée est EXACTEMENT celle que la simulation fait
		# pousser — pas une recomposition depuis la salinité et le vent. La
		# version recalculée blanchissait tous les bassins salés dès que le
		# vent tournait, y compris ceux où appuyer sur E ne donnait rien : le
		# rendu mentait sur la seule chose que l'étape demande de lire.
		materiau.set_shader_parameter(&"fleur",
			clampf(bassin.fleur / Reglages.FLEUR_PRISE, 0.0, 1.0))

# ---------------------------------------------------------------------------
# Le sol
# ---------------------------------------------------------------------------

func _batir_sol(bruit: Texture2D) -> void:
	var taille: Vector2i = _marais.dimensions()
	var hauteurs: PackedFloat32Array = _hauteurs_lissees(taille)

	var outils: SurfaceTool = SurfaceTool.new()
	outils.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origine: Vector2 = _marais.origine()
	var pas: float = Marais.PAS

	# Les sommets sont aux COINS des cases, pas en leur centre : c'est ce qui
	# fait qu'un bord de talus devient une pente et non une marche.
	for y: int in range(taille.y):
		for x: int in range(taille.x):
			var a: Vector3 = _sommet(hauteurs, taille, origine, pas, x, y)
			var b: Vector3 = _sommet(hauteurs, taille, origine, pas, x + 1, y)
			var c: Vector3 = _sommet(hauteurs, taille, origine, pas, x + 1, y + 1)
			var d: Vector3 = _sommet(hauteurs, taille, origine, pas, x, y + 1)
			var teinte: Color = _teinte_case(x, y)
			_triangle(outils, a, b, c, teinte)
			_triangle(outils, a, c, d, teinte)

	outils.generate_normals()
	outils.generate_tangents()

	var materiau: ShaderMaterial = ShaderMaterial.new()
	materiau.shader = load("res://shaders/argile.gdshader")
	materiau.set_shader_parameter(&"bruit", bruit)

	_sol = MeshInstance3D.new()
	_sol.name = "Argile"
	_sol.mesh = outils.commit()
	_sol.material_override = materiau
	_sol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_sol)

## Hauteur par case, lissée du seul côté des bassins.
func _hauteurs_lissees(taille: Vector2i) -> PackedFloat32Array:
	var total: int = taille.x * taille.y
	var brutes: PackedFloat32Array = PackedFloat32Array()
	brutes.resize(total)
	for y: int in range(taille.y):
		for x: int in range(taille.x):
			brutes[y * taille.x + x] = _marais.hauteur_de_case(x, y)

	var courantes: PackedFloat32Array = brutes.duplicate()
	for _passe: int in range(LISSAGES):
		var suivantes: PackedFloat32Array = courantes.duplicate()
		for y: int in range(taille.y):
			for x: int in range(taille.x):
				# Une crête de talus ne se rabote pas : elle reste à sa hauteur.
				if _marais.bassin_de_case(x, y) == -1:
					continue
				var somme: float = 0.0
				var compte: int = 0
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						var vx: int = clampi(x + dx, 0, taille.x - 1)
						var vy: int = clampi(y + dy, 0, taille.y - 1)
						somme += courantes[vy * taille.x + vx]
						compte += 1
				var moyenne: float = somme / float(compte)
				var brute: float = brutes[y * taille.x + x]
				suivantes[y * taille.x + x] = minf(moyenne, brute + REMONTEE_MAX)
		courantes = suivantes
	return courantes

## Hauteur d'un COIN de case : la moyenne des cases qui s'y touchent.
func _sommet(hauteurs: PackedFloat32Array, taille: Vector2i, origine: Vector2,
		pas: float, nx: int, ny: int) -> Vector3:
	var somme: float = 0.0
	var compte: int = 0
	for dy: int in range(-1, 1):
		for dx: int in range(-1, 1):
			var cx: int = nx + dx
			var cy: int = ny + dy
			if cx < 0 or cx >= taille.x or cy < 0 or cy >= taille.y:
				continue
			somme += hauteurs[cy * taille.x + cx]
			compte += 1
	var hauteur: float = 0.0
	if compte > 0:
		hauteur = somme / float(compte)
	return Vector3(origine.x + float(nx) * pas, hauteur, origine.y + float(ny) * pas)

## Ce que le sol raconte de lui-même, porté par la couleur de sommet :
## rouge = mouillé, vert = croûte de sel.
func _teinte_case(x: int, y: int) -> Color:
	var b: int = _marais.bassin_de_case(x, y)
	if b == -1:
		return Color(0.06, 0.10, 0.0, 1.0)
	var bassin: Marais.Bassin = _marais.bassins[b]
	var mouille: float = clampf(0.55 + bassin.profondeur() * 2.4, 0.0, 1.0)
	# Le sel ne se voit que sur un bassin mûr ET qui sèche. Sous cinq
	# centimètres d'eau il n'y a rien à regarder — et c'est précisément ce qui
	# fait qu'un œillet prêt à récolter se reconnaît d'un coup d'œil.
	var mur: float = clampf((bassin.salinite - 0.55) / 0.45, 0.0, 1.0)
	var sec: float = clampf(1.0 - bassin.profondeur() / 0.13, 0.0, 1.0)
	return Color(mouille, mur * sec, 0.0, 1.0)

func _triangle(outils: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		teinte: Color) -> void:
	for sommet: Vector3 in [a, b, c]:
		outils.set_color(teinte)
		outils.set_uv(Vector2(sommet.x, sommet.z) * 0.25)
		outils.add_vertex(sommet)

# ---------------------------------------------------------------------------
# L'eau
# ---------------------------------------------------------------------------

## Une nappe par bassin, faite des cases de ce bassin exactement. Elle est
## construite à plat et déplacée en hauteur : c'est le niveau qui varie, jamais
## la forme.
func _batir_eaux(bruit: Texture2D) -> void:
	var taille: Vector2i = _marais.dimensions()
	var origine: Vector2 = _marais.origine()
	var pas: float = Marais.PAS

	for indice: int in range(_marais.bassins.size()):
		var outils: SurfaceTool = SurfaceTool.new()
		outils.begin(Mesh.PRIMITIVE_TRIANGLES)
		var cases: int = 0
		for y: int in range(taille.y):
			for x: int in range(taille.x):
				if _marais.bassin_de_case(x, y) != indice:
					continue
				cases += 1
				var x0: float = origine.x + float(x) * pas
				var z0: float = origine.y + float(y) * pas
				var x1: float = x0 + pas
				var z1: float = z0 + pas
				var a: Vector3 = Vector3(x0, 0.0, z0)
				var b: Vector3 = Vector3(x1, 0.0, z0)
				var c: Vector3 = Vector3(x1, 0.0, z1)
				var d: Vector3 = Vector3(x0, 0.0, z1)
				_triangle(outils, a, b, c, Color.WHITE)
				_triangle(outils, a, c, d, Color.WHITE)

		var materiau: ShaderMaterial = ShaderMaterial.new()
		materiau.shader = load("res://shaders/eau.gdshader")
		materiau.set_shader_parameter(&"bruit", bruit)
		materiau.set_shader_parameter(&"salinite", _marais.bassins[indice].salinite)

		var vue: MeshInstance3D = MeshInstance3D.new()
		vue.name = "Eau_%s" % _marais.bassins[indice].nom
		if cases > 0:
			outils.generate_normals()
			vue.mesh = outils.commit()
		# L'eau ne projette pas d'ombre : une nappe de trois centimètres qui
		## assombrirait son propre fond serait un contresens.
		vue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vue.material_override = materiau
		add_child(vue)
		_eaux.append(vue)
		_materiau_eau.append(materiau)

## Prolonge le marais jusqu'à l'horizon.
##
## Le lieu réel s'étend sur des kilomètres. Sans ce prolongement, le niveau
## flotte au-dessus du sol peint du ciel procédural et l'illusion tombe à la
## première ligne d'horizon. Ce n'est pas du décor : c'est ce qui fait qu'on
## croit être quelque part.
##
## On ne modélise pas de bassins au loin — la brume les mangerait. Une plaine
## d'argile suffit, posée juste sous la crête des talus pour qu'elle prolonge
## le niveau sans le trancher.
func prolonger(rayon: float, niveau: float, bruit: Texture2D) -> void:
	if _marais == null:
		return
	var emprise: Rect2 = _marais.etendue()
	# Un ANNEAU, et non un plan : un plan passerait sous nos propres bassins et
	# les noierait tous. L'anneau s'arrête au bord du niveau, exactement là où
	# les talus prennent le relais.
	var outils: SurfaceTool = SurfaceTool.new()
	outils.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0: float = emprise.position.x
	var z0: float = emprise.position.y
	var x1: float = emprise.end.x
	var z1: float = emprise.end.y
	var bx0: float = x0 - rayon
	var bz0: float = z0 - rayon
	var bx1: float = x1 + rayon
	var bz1: float = z1 + rayon
	var bandes: Array[PackedFloat32Array] = [
		PackedFloat32Array([bx0, bz0, bx1, z0]),
		PackedFloat32Array([bx0, z1, bx1, bz1]),
		PackedFloat32Array([bx0, z0, x0, z1]),
		PackedFloat32Array([x1, z0, bx1, z1])]
	for bande: PackedFloat32Array in bandes:
		var a: Vector3 = Vector3(bande[0], 0.0, bande[1])
		var b: Vector3 = Vector3(bande[2], 0.0, bande[1])
		var c: Vector3 = Vector3(bande[2], 0.0, bande[3])
		var d: Vector3 = Vector3(bande[0], 0.0, bande[3])
		_triangle(outils, a, b, c, Color.WHITE)
		_triangle(outils, a, c, d, Color.WHITE)
	outils.generate_normals()

	var materiau: ShaderMaterial = ShaderMaterial.new()
	materiau.shader = load("res://shaders/eau.gdshader")
	materiau.set_shader_parameter(&"bruit", bruit)
	materiau.set_shader_parameter(&"salinite", 0.25)
	# Le lointain est opaque : on ne veut pas y lire un fond, on veut un miroir.
	materiau.set_shader_parameter(&"profondeur_opaque", 0.05)
	materiau.set_shader_parameter(&"profondeur_nappe", 2.0)

	var lointain: MeshInstance3D = MeshInstance3D.new()
	lointain.name = "Lointain"
	lointain.mesh = outils.commit()
	lointain.material_override = materiau
	lointain.position = Vector3(0.0, niveau, 0.0)
	lointain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lointain)
	move_child(lointain, 0)
