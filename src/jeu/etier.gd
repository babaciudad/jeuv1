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
## Côté d'un œillet : 8,25 m, soit 68 m², au plus près des soixante-dix mètres
## carrés du lore une fois calé sur la grille de rasterisation.
const COTE_OEILLET: float = 8.25
## Largeur d'un talus entre deux bassins.
##
## TOUTES les cotes de ce fichier sont des multiples de Marais.PAS et alignées
## sur ses bords de case. Ce n'est pas de la coquetterie : une case appartient
## au bassin dont le polygone contient son CENTRE, si bien qu'un intervalle de
## 0,80 m posé n'importe où en rendait 1,00 à la mesure. Le talus faisait un
## quart de plus que ce que le lore promet, et rien ne le disait. Trois cases
## font 0,75 m, c'est-à-dire la largeur d'un homme, et c'est ce qu'on veut.
const TALUS: float = 0.75

## Niveau de la mer à marée basse et à marée haute, en mètres.
const MAREE_BASSE: float = -0.55
const MAREE_HAUTE: float = 0.21

# ---------------------------------------------------------------------------
# Les lieux du tutoriel
#
# Ce ne sont pas des marqueurs posés sur un décor : ce sont les points où la
# géométrie du marais fait elle-même le travail. Le départ est sur un talus de
# quatre-vingts centimètres avec de l'eau des deux côtés — la première leçon
# est donnée par le terrain, sans une ligne de texte.
# ---------------------------------------------------------------------------

## L'axe de la digue nord-sud qui sépare l'étier de la vasière : trois cases,
## soit 0,75 m, et de l'eau des deux côtés.
const AXE_DIGUE: float = 9.125
## La chaussée est-ouest, qui coupe la vasière en deux.
const AXE_CHAUSSEE: float = 21.375

const DEPART: Vector2 = Vector2(AXE_DIGUE, 5.25)
## La porte de marée, dix mètres plus loin sur la même digue.
const PORTE_DE_MAREE: Vector2 = Vector2(AXE_DIGUE, 15.00)
## Le croisement où la digue rencontre la chaussée qui part vers l'est.
const CROISEE: Vector2 = Vector2(AXE_DIGUE, AXE_CHAUSSEE)
## La ladure : la plateforme d'argile où l'on entasse le sel. Point de repos.
const LADURE: Vector2 = Vector2(38.10, 12.00)
## Le centre de l'œillet qu'on ratisse — mûr, presque sec, contre la ladure.
const OEILLET_DU_SEL: Vector2 = Vector2(46.375, 8.125)
## L'œillet qui garde sa saumure : c'est là que la fleur prendra.
const OEILLET_DE_LA_FLEUR: Vector2 = Vector2(46.375, 26.125)
## Où le premier cristallisé se relève.
const LEVEE_DU_CRISTALLISE: Vector2 = Vector2(46.375, 17.125)

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
		rectangle(1.25, 1.5, 8.75, 42.5), -1.10, 1.31, 0.02)
	marais.bassins[etier].tenu_par_la_maree = true
	marais.bassins[etier].niveau_impose = MAREE_BASSE

	# LA CHAÎNE DESCEND, et c'est la règle centrale du lore : « l'eau entre à
	# marée haute par l'étier et commence une descente qui dure des semaines, de
	# bassin en bassin ». Les œillets sont donc le point le PLUS BAS du marais,
	# et la vasière le plus haut.
	#
	# Elle montait. Vasière à −0,38, œillets à +0,04 : l'eau ne pouvait pas
	# atteindre les œillets, et ouvrir la vanne d'un œillet le VIDAIT au lieu de
	# le remplir — ce qui rendait la fleur impossible et le tutoriel infinissable.
	# C'était une erreur de conception, pas un réglage.
	#
	# Deux contraintes tiennent ces chiffres, et elles sont mesurées par les
	# tests : les FONDS descendent (0,12 > 0,08 > 0,04 > 0,00 > −0,06) et les
	# NIVEAUX initiaux descendent aussi (0,13 > 0,11 > 0,09 > 0,06 > …) — sans
	# quoi l'eau refluerait vers l'amont au premier tick, puisque les vannes
	# suivent les niveaux et non les noms. La marée haute (0,21 m) domine tout :
	# c'est elle qui remplit la chaîne, et chaque bassin reste une lame d'eau
	# où l'on patauge sans jamais s'y noyer.
	# La vasière : vaste réserve où l'eau se repose et se réchauffe. Elle est
	# coupée en deux par une CHAUSSÉE de talus, et ce n'est pas un ornement :
	# c'est le chemin du joueur. Tout le tutoriel se marche sur des talus de
	# quatre-vingts centimètres, jamais sur une place.
	var vasiere: int = marais.creuser(&"vasiere_nord",
		rectangle(9.5, 4.0, 25.0, 21.0), 0.12, 0.01, 0.05)
	var vasiere_sud: int = marais.creuser(&"vasiere_sud",
		rectangle(9.5, 21.75, 25.0, 40.0), 0.11, 0.01, 0.06)

	# Le cobier, premier bassin d'évaporation, puis les fares où l'eau serpente.
	var cobier: int = marais.creuser(&"cobier",
		rectangle(25.75, 4.0, 34.0, 21.0), 0.08, 0.03, 0.34)
	var fares: int = marais.creuser(&"fares",
		rectangle(25.75, 21.75, 34.0, 40.0), 0.04, 0.05, 0.58)
	# Les adernes : les réserves de saumure mûre, gardées. Elles n'occupent que
	# le sud : au nord, l'argile reste pleine et forme la LADURE, la plateforme
	# où l'on entasse ce qu'on a tiré du fond.
	var adernes: int = marais.creuser(&"adernes",
		rectangle(34.75, 21.75, 41.5, 40.0), 0.00, 0.06, 0.76)

	# La marqueterie : six œillets, deux colonnes de trois. C'est là que tout
	# se joue, et c'est le seul bassin où le sel cristallise.
	var coin: Vector2 = Vector2(42.25, 4.0)
	var oeillets: PackedInt32Array = PackedInt32Array()
	var noms: Array[StringName] = [
		&"oeillet_nord_ouest", &"oeillet_nord_est",
		&"oeillet_centre_ouest", &"oeillet_centre_est",
		&"oeillet_sud_ouest", &"oeillet_sud_est"]
	# L'œillet du nord-ouest est celui qu'on ratisse : mûr et presque sec, son
	# sel a cristallisé au fond, et il touche la ladure. Le geste du las le tire
	# vers elle — exactement le geste réel.
	# Celui du centre-ouest garde sa saumure : c'est là que la fleur prendra.
	var salinites: PackedFloat32Array = PackedFloat32Array(
		[0.97, 0.88, 0.94, 0.86, 0.91, 0.84])
	var profondeurs: PackedFloat32Array = PackedFloat32Array(
		[0.004, 0.035, 0.031, 0.038, 0.028, 0.040])
	var k: int = 0
	for ligne: int in range(3):
		for colonne: int in range(2):
			# Le point le PLUS BAS du marais : c'est là que l'eau finit, et c'est
			# là que le sel cristallise. Tout le sens de la chaîne tient à ça.
			oeillets.append(marais.creuser(noms[k],
				oeillet(coin, colonne, ligne), -0.06,
				profondeurs[k], salinites[k]))
			k += 1

	# Les vannes. Celle de l'étier est une porte de marée : elle gronde. Les
	# autres suintent d'un bassin à l'autre.
	var _v0: int = marais.relier(&"porte_de_maree", etier, vasiere,
		PORTE_DE_MAREE, false, 9.0)
	var _v0b: int = marais.relier(&"vanne_chaussee", vasiere, vasiere_sud,
		Vector2(17.0, 21.375), true, 3.0)
	var _v1: int = marais.relier(&"vanne_cobier", vasiere, cobier,
		Vector2(25.4, 12.0), true, 2.0)
	var _v2: int = marais.relier(&"vanne_fares", cobier, fares,
		Vector2(29.9, 21.375), true, 1.6)
	var _v3: int = marais.relier(&"vanne_adernes", fares, adernes,
		Vector2(34.4, 30.0), true, 1.4)
	# L'œillet du sud-est est isolé : c'est celui qu'on rouvrira, et c'est là
	# que la fleur prendra.
	var _v4: int = marais.relier(&"vanne_oeillet", adernes, oeillets[4],
		Vector2(42.0, 26.0), false, 1.0)
	return marais
