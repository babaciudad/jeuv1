## Le dessin de l'étier : la zone 1, celle du tutoriel.
##
## « L'étier — le chenal qui amène la mer. Zone 1, tutoriel. Tout commence
## ici. » Le niveau n'est pas modelé, il est DÉCRIT : des polygones de bassins
## et des vannes, exactement comme un paludier décrirait son marais. Le talus
## est ce qui reste entre eux, et c'est le terrain de jeu.
##
## Les œillets font huit mètres quarante de côté, soit soixante-dix mètres
## carrés — la mesure réelle. Les talus qui les séparent font quatre-vingts
## centimètres. On se bat dessus.
class_name Etier
extends RefCounted

## Emprise totale du niveau, en mètres.
const EMPRISE: Vector2 = Vector2(64.0, 44.0)
## Côté d'un œillet : soixante-dix mètres carrés, comme dans le lore.
const COTE_OEILLET: float = 8.37
## Largeur d'un talus entre deux œillets.
const TALUS: float = 0.80

## Niveau de la mer à marée basse et à marée haute, en mètres.
const MAREE_BASSE: float = -0.55
const MAREE_HAUTE: float = 0.21

static func rectangle(x0: float, z0: float, x1: float, z1: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)])

## Un œillet par sa case dans la marqueterie, en partant du coin donné.
static func oeillet(coin: Vector2, colonne: int, ligne: int) -> PackedVector2Array:
	var pas: float = COTE_OEILLET + TALUS
	var x0: float = coin.x + float(colonne) * pas
	var z0: float = coin.y + float(ligne) * pas
	return rectangle(x0, z0, x0 + COTE_OEILLET, z0 + COTE_OEILLET)

## Construit le marais de l'étier. Renvoie le marais prêt à simuler.
static func batir() -> Marais:
	var marais: Marais = Marais.new()
	marais.preparer(Vector2.ZERO, EMPRISE, Reglages.HAUTEUR_TALUS)

	# L'étier : le chenal qui amène la mer, le long du bord ouest. Son lit est
	# le point le plus bas de tout le marais, et pourtant c'est lui qui remplit
	# le reste — parce que c'est la marée qui monte, pas l'eau qui grimpe.
	var etier: int = marais.creuser(&"etier",
		rectangle(1.2, 1.5, 8.6, 42.5), -1.10, 1.31, 0.02)
	marais.bassins[etier].tenu_par_la_maree = true
	marais.bassins[etier].niveau_impose = MAREE_BASSE

	# La vasière : vaste réserve où l'eau se repose et se réchauffe.
	var vasiere: int = marais.creuser(&"vasiere",
		rectangle(9.4, 4.0, 25.0, 40.0), -0.38, 0.07, 0.05)

	# Le cobier, premier bassin d'évaporation, puis les fares où l'eau serpente.
	var cobier: int = marais.creuser(&"cobier",
		rectangle(25.8, 4.0, 34.0, 21.0), -0.18, 0.10, 0.34)
	var fares: int = marais.creuser(&"fares",
		rectangle(25.8, 21.8, 34.0, 40.0), -0.10, 0.09, 0.58)
	# Les adernes : les réserves de saumure mûre, gardées.
	var adernes: int = marais.creuser(&"adernes",
		rectangle(34.8, 21.8, 41.5, 40.0), -0.02, 0.08, 0.76)

	# La marqueterie : six œillets, deux colonnes de trois. C'est là que tout
	# se joue, et c'est le seul bassin où le sel cristallise.
	var coin: Vector2 = Vector2(42.6, 4.0)
	var oeillets: PackedInt32Array = PackedInt32Array()
	var noms: Array[StringName] = [
		&"oeillet_nord_ouest", &"oeillet_nord_est",
		&"oeillet_centre_ouest", &"oeillet_centre_est",
		&"oeillet_sud_ouest", &"oeillet_sud_est"]
	var salinites: PackedFloat32Array = PackedFloat32Array(
		[0.88, 0.97, 0.91, 0.86, 0.93, 0.84])
	var profondeurs: PackedFloat32Array = PackedFloat32Array(
		[0.035, 0.004, 0.030, 0.038, 0.028, 0.040])
	var k: int = 0
	for ligne: int in range(3):
		for colonne: int in range(2):
			oeillets.append(marais.creuser(noms[k],
				oeillet(coin, colonne, ligne), 0.04,
				profondeurs[k], salinites[k]))
			k += 1

	# Les vannes. Celle de l'étier est une porte de marée : elle gronde. Les
	# autres suintent d'un bassin à l'autre.
	var _v0: int = marais.relier(&"porte_de_maree", etier, vasiere,
		Vector2(9.0, 22.0), false, 9.0)
	var _v1: int = marais.relier(&"vanne_cobier", vasiere, cobier,
		Vector2(25.4, 12.0), true, 2.0)
	var _v2: int = marais.relier(&"vanne_fares", cobier, fares,
		Vector2(29.9, 21.4), true, 1.6)
	var _v3: int = marais.relier(&"vanne_adernes", fares, adernes,
		Vector2(34.4, 30.0), true, 1.4)
	# L'œillet du sud-est est isolé : c'est celui qu'on rouvrira, et c'est là
	# que la fleur prendra.
	var _v4: int = marais.relier(&"vanne_oeillet", adernes, oeillets[1],
		Vector2(42.2, 8.2), false, 1.0)
	return marais
