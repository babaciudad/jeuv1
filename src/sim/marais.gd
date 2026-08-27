## Le marais : le terrain et son hydraulique, sans une ligne de rendu.
##
## Un marais salant ne pompe rien. L'eau entre par l'étier à marée haute et
## descend de bassin en bassin par gravité, en perdant de l'eau et en gagnant
## du sel. Toute l'ingénierie du lieu tient dans une pente de quelques
## centimètres sur des kilomètres — donc ici, dans des différences de niveau
## de l'ordre du centimètre, et un débit qui les suit.
##
## Le terrain est décrit en haut niveau par des POLYGONES de bassins, puis
## rasterisé sur une grille fine. Les talus sont ce qui reste entre les
## polygones : on ne les dessine pas, on les obtient. C'est exactement le
## rapport qu'ils ont au réel — la digue est le bord que l'argile a laissé.
##
## Invariant 2 : rien ici ne connaît la présentation. Le rendu interroge, il
## ne décide pas.
class_name Marais
extends RefCounted

## Côté d'une case, en mètres. Assez fin pour qu'un talus de soixante-dix
## centimètres fasse au moins deux cases et garde un bord lisible.
const PAS: float = 0.25

## Un bassin : une cuvette d'argile qui retient de l'eau.
class Bassin extends RefCounted:
	var nom: StringName = &""
	## Altitude du fond, en mètres. C'est la pente du marais.
	var fond: float = 0.0
	## Volume d'eau retenu, en mètres cubes.
	var volume: float = 0.0
	## Surface du bassin, en mètres carrés, déduite de la rasterisation.
	var surface: float = 0.0
	## Salinité, de 0 (eau de mer) à 1 (saturée, le sel cristallise).
	var salinite: float = 0.0

	## Niveau de la surface de l'eau, en mètres. C'est ce qu'on compare d'un
	## bassin à l'autre pour connaître le sens de l'écoulement.
	func niveau() -> float:
		if surface <= 0.0:
			return fond
		return fond + volume / surface

	func profondeur() -> float:
		return niveau() - fond

## Une vanne : le passage d'eau entre deux bassins, et le seul geste par lequel
## un paludier commande quoi que ce soit.
class Vanne extends RefCounted:
	var nom: StringName = &""
	var amont: int = -1
	var aval: int = -1
	var ouverte: bool = false
	## Position dans le monde, pour que la présentation sache où la poser et
	## le joueur où aller la chercher.
	var position: Vector2 = Vector2.ZERO
	## Débit du dernier tick, en mètres cubes par seconde. La présentation s'en
	## sert pour décider si l'eau coule à l'écran, et à quel point.
	var debit: float = 0.0

var bassins: Array[Bassin] = []
var vannes: Array[Vanne] = []

## Origine du coin bas-gauche de la grille, dans le monde.
var _origine: Vector2 = Vector2.ZERO
var _largeur: int = 0
var _hauteur: int = 0
## Indice du bassin de chaque case, ou -1 pour un talus.
var _case_bassin: PackedInt32Array = PackedInt32Array()
## Altitude du dessus du talus pour les cases de talus.
var _case_talus: PackedFloat32Array = PackedFloat32Array()

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

## Prépare une grille vide, entièrement en talus, couvrant l'étendue donnée.
func preparer(origine: Vector2, etendue: Vector2, altitude_talus: float) -> void:
	_origine = origine
	_largeur = int(ceilf(etendue.x / PAS))
	_hauteur = int(ceilf(etendue.y / PAS))
	var total: int = _largeur * _hauteur
	_case_bassin = PackedInt32Array()
	_case_bassin.resize(total)
	_case_bassin.fill(-1)
	_case_talus = PackedFloat32Array()
	_case_talus.resize(total)
	_case_talus.fill(altitude_talus)

## Creuse un bassin en rasterisant un polygone. Renvoie son indice.
##
## Les cases déjà prises par un bassin précédent ne sont pas volées : deux
## bassins qui se chevauchent laisseraient une frontière indéfinie, et le
## premier arrivé a raison. C'est au niveau de dessiner des polygones qui ne
## se recouvrent pas — les talus sont censés les séparer.
func creuser(nom: StringName, polygone: PackedVector2Array, fond: float,
		profondeur_initiale: float, salinite: float) -> int:
	var bassin: Bassin = Bassin.new()
	bassin.nom = nom
	bassin.fond = fond
	bassin.salinite = salinite
	var indice: int = bassins.size()
	bassins.append(bassin)

	var cases: int = 0
	var boite: Rect2 = _boite(polygone)
	var x0: int = maxi(0, int(floorf((boite.position.x - _origine.x) / PAS)))
	var x1: int = mini(_largeur - 1, int(ceilf((boite.end.x - _origine.x) / PAS)))
	var y0: int = maxi(0, int(floorf((boite.position.y - _origine.y) / PAS)))
	var y1: int = mini(_hauteur - 1, int(ceilf((boite.end.y - _origine.y) / PAS)))
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var centre: Vector2 = _centre_case(x, y)
			if not Geometry2D.is_point_in_polygon(centre, polygone):
				continue
			var k: int = y * _largeur + x
			if _case_bassin[k] != -1:
				continue
			_case_bassin[k] = indice
			cases += 1

	bassin.surface = float(cases) * PAS * PAS
	bassin.volume = bassin.surface * maxf(0.0, profondeur_initiale)
	return indice

## Relie deux bassins par une vanne. L'amont doit être plus haut que l'aval :
## tout descend, rien ne remonte. On refuse le contraire plutôt que de le
## corriger en silence, parce qu'un niveau posé à l'envers est une erreur de
## conception du marais, pas un cas à rattraper.
func relier(nom: StringName, amont: int, aval: int, position: Vector2,
		ouverte: bool) -> int:
	assert(amont >= 0 and amont < bassins.size(), "vanne : amont inconnu")
	assert(aval >= 0 and aval < bassins.size(), "vanne : aval inconnu")
	assert(bassins[amont].fond >= bassins[aval].fond,
		"vanne %s : l'amont est plus bas que l'aval, l'eau ne remonte pas" % nom)
	var vanne: Vanne = Vanne.new()
	vanne.nom = nom
	vanne.amont = amont
	vanne.aval = aval
	vanne.position = position
	vanne.ouverte = ouverte
	vannes.append(vanne)
	return vannes.size() - 1

# ---------------------------------------------------------------------------
# Interrogation du terrain
# ---------------------------------------------------------------------------

func dans_la_grille(position: Vector2) -> bool:
	var c: Vector2i = _case_de(position)
	return c.x >= 0 and c.x < _largeur and c.y >= 0 and c.y < _hauteur

## Indice du bassin sous ce point, ou -1 si on est sur un talus (ou dehors).
func bassin_sous(position: Vector2) -> int:
	var c: Vector2i = _case_de(position)
	if c.x < 0 or c.x >= _largeur or c.y < 0 or c.y >= _hauteur:
		return -1
	return _case_bassin[c.y * _largeur + c.x]

## Altitude du sol dur : le dessus du talus, ou le fond d'un bassin.
func hauteur_sol(position: Vector2) -> float:
	var c: Vector2i = _case_de(position)
	if c.x < 0 or c.x >= _largeur or c.y < 0 or c.y >= _hauteur:
		return 0.0
	var k: int = c.y * _largeur + c.x
	var b: int = _case_bassin[k]
	if b == -1:
		return _case_talus[k]
	return bassins[b].fond

## Hauteur d'eau au-dessus du sol, en mètres. Zéro sur un talus.
func profondeur_eau(position: Vector2) -> float:
	var b: int = bassin_sous(position)
	if b == -1:
		return 0.0
	return maxf(0.0, bassins[b].profondeur())

## Altitude de la surface de l'eau, ou celle du sol s'il n'y a pas d'eau.
func niveau_eau(position: Vector2) -> float:
	var b: int = bassin_sous(position)
	if b == -1:
		return hauteur_sol(position)
	return bassins[b].niveau()

## Vrai si ce point est un talus praticable. C'est la question que pose le
## joueur à chaque pas, et le terrain qui fait ce jeu.
func est_talus(position: Vector2) -> bool:
	return bassin_sous(position) == -1 and dans_la_grille(position)

func bassin_nomme(nom: StringName) -> int:
	for i: int in range(bassins.size()):
		if bassins[i].nom == nom:
			return i
	return -1

func vanne_nommee(nom: StringName) -> int:
	for i: int in range(vannes.size()):
		if vannes[i].nom == nom:
			return i
	return -1

# ---------------------------------------------------------------------------
# Hydraulique
# ---------------------------------------------------------------------------

## Fait couler l'eau d'un tick. Rien d'autre ne modifie les volumes.
##
## Le débit suit la charge — la différence de niveau — et s'arrête quand elle
## descend sous le seuil. Un transfert ne peut ni vider l'amont sous son fond,
## ni faire monter l'aval au-dessus de l'amont dans le même tick : sans ces
## deux bornes, un pas de temps trop grand fait osciller les deux bassins.
func ecouler(duree: float) -> void:
	for vanne: Vanne in vannes:
		vanne.debit = 0.0
		if not vanne.ouverte:
			continue
		var amont: Bassin = bassins[vanne.amont]
		var aval: Bassin = bassins[vanne.aval]
		var charge: float = amont.niveau() - aval.niveau()
		if charge <= Reglages.CHARGE_MINIMALE:
			continue
		var debit: float = Reglages.DEBIT_VANNE * charge
		var transfert: float = debit * duree
		transfert = minf(transfert, amont.volume)
		# Ce qu'il faudrait pour égaliser les deux surfaces : on ne dépasse
		# jamais la moitié de cette quantité dans un tick.
		var egalisation: float = charge / (1.0 / maxf(amont.surface, 0.001)
			+ 1.0 / maxf(aval.surface, 0.001))
		transfert = minf(transfert, egalisation)
		if transfert <= 0.0:
			continue
		amont.volume -= transfert
		aval.volume += transfert
		vanne.debit = transfert / duree

		# Le sel voyage avec l'eau. L'aval reçoit une saumure, se mélange, puis
		# se concentre à l'évaporation : c'est toute la chaîne du marais, et
		# c'est ce qui fait qu'un œillet finit par cristalliser.
		if aval.volume > 0.0:
			var part: float = transfert / aval.volume
			aval.salinite = lerpf(aval.salinite, amont.salinite, clampf(part, 0.0, 1.0))

## Évapore, en mètres de hauteur d'eau par seconde. C'est l'été qui travaille.
## Le sel, lui, ne s'évapore pas : la salinité monte à mesure que l'eau baisse.
func evaporer(hauteur_par_seconde: float, duree: float) -> void:
	var perte: float = hauteur_par_seconde * duree
	for bassin: Bassin in bassins:
		if bassin.surface <= 0.0 or bassin.volume <= 0.0:
			continue
		var avant: float = bassin.volume
		bassin.volume = maxf(0.0, bassin.volume - perte * bassin.surface)
		if bassin.volume > 0.0:
			bassin.salinite = clampf(bassin.salinite * avant / bassin.volume, 0.0, 1.0)

# ---------------------------------------------------------------------------
# Interne
# ---------------------------------------------------------------------------

func _case_de(position: Vector2) -> Vector2i:
	return Vector2i(
		int(floorf((position.x - _origine.x) / PAS)),
		int(floorf((position.y - _origine.y) / PAS)))

func _centre_case(x: int, y: int) -> Vector2:
	return _origine + Vector2((float(x) + 0.5) * PAS, (float(y) + 0.5) * PAS)

func _boite(polygone: PackedVector2Array) -> Rect2:
	if polygone.is_empty():
		return Rect2()
	var boite: Rect2 = Rect2(polygone[0], Vector2.ZERO)
	for p: Vector2 in polygone:
		boite = boite.expand(p)
	return boite
