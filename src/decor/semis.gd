## Sème la végétation du marais.
##
## Rien n'est placé à la main. Le marais sait déjà où sont ses bassins et ses
## talus : on en tire une carte de DISTANCE AU BORD, et chaque espèce dit à
## quelle distance de l'eau elle pousse. Les roseaux tiennent la rive, l'herbe
## rase tient les talus, les buissons et les souches ne viennent que sur les
## plateformes larges, et les arbres restent au loin.
##
## C'est le même principe que pour le terrain : on ne dessine pas le résultat,
## on décrit la règle et le lieu la produit. Un marais redessiné se repeuple
## tout seul.
##
## Tout est déterministe. Deux exécutions donnent le même marais, sinon deux
## captures ne seraient pas comparables et aucune mesure ne voudrait rien dire.
class_name Semis
extends Node3D

const DOSSIER: String = "res://models/marais/vegetation/"
const GRAINE: int = 4041

## Une espèce, et l'endroit où elle pousse.
class Espece extends RefCounted:
	var fichiers: PackedStringArray = PackedStringArray()
	## Fourchette de distance au bord d'un bassin, en mètres. Négatif = dans
	## l'eau, positif = sur le talus.
	var distance_min: float = 0.0
	var distance_max: float = 99.0
	## Probabilité d'occuper une case admissible.
	var densite: float = 0.2
	## HAUTEUR VISÉE, en mètres — et non un facteur d'échelle.
	##
	## C'est un choix de robustesse payé cher : `roseau_touffe.glb` mesure
	## VINGT-CINQ MÈTRES sur CENT SOIXANTE-DIX-NEUF dans son fichier, là où son
	## manifeste annonçait 1,79 m. Semé à l'échelle 1, il avalait la caméra et
	## la capture ne montrait plus qu'un aplat orange. On ne fait donc plus
	## confiance à l'échelle d'un fichier : on mesure sa boîte englobante et on
	## la ramène à la taille qu'une plante doit avoir. Un asset mal calibré ne
	## peut plus rien casser.
	var hauteur_min: float = 0.9
	var hauteur_max: float = 1.2
	## Profondeur d'eau maximale acceptée, en mètres.
	var eau_max: float = 0.0
	## Salinité maximale du bassin où l'espèce accepte de pousser.
	##
	## Règle de métier autant que de botanique : rien ne pousse dans une saumure
	## mûre, et un paludier tient ses œillets PROPRES — c'est là qu'il récolte.
	## Sans cette règle, les roseaux envahissaient toute la marqueterie et le
	## dessin des œillets, qui est le sujet du lieu, disparaissait sous eux.
	var salinite_max: float = 1.0

	static func neuve(noms: PackedStringArray, dmin: float, dmax: float,
			densite_: float, hmin: float, hmax: float, eau: float,
			sel: float = 1.0) -> Espece:
		var e: Espece = Espece.new()
		e.fichiers = noms
		e.distance_min = dmin
		e.distance_max = dmax
		e.densite = densite_
		e.hauteur_min = hmin
		e.hauteur_max = hmax
		e.eau_max = eau
		e.salinite_max = sel
		return e

var _maillages: Array[Mesh] = []
## Ce qui a été planté, et à quelle hauteur maximale, par espèce.
##
## Ce registre existe parce qu'on ne peut PAS relire un MultiMesh : en mode
## headless le serveur de rendu est factice et `get_instance_transform` rend
## l'identité, même après une écriture directe dans le tampon. Vérifié sur
## quatre montages différents, buffer compris. Sans ce registre, aucun test ne
## pourrait dire qu'une plante ne fait pas vingt mètres — et c'est exactement
## le défaut qu'on a laissé passer.
var hauteurs: Dictionary[String, float] = {}
var instances: Dictionary[String, int] = {}
var _niveau_lointain: float = Reglages.HAUTEUR_TALUS - 0.08

## Sème. `lointain` ajoute une frange au-delà du niveau, pour que l'horizon ne
## soit pas une ligne nue.
## `facteur` allège uniformément le semis. Le jeu tourne à 1 ; les captures de
## contrôle descendent plus bas, parce que ce conteneur rend en logiciel et
## qu'une image à quarante mille brins y coûte treize minutes.
func semer(marais: Marais, lointain: float, facteur: float = 1.0,
		niveau_lointain: float = Reglages.HAUTEUR_TALUS - 0.08) -> void:
	_niveau_lointain = niveau_lointain
	var taille: Vector2i = marais.dimensions()
	var distances: PackedFloat32Array = _distances_au_bord(marais, taille)
	var especes: Array[Espece] = _catalogue()

	for espece: Espece in especes:
		for fichier: String in espece.fichiers:
			var maille: Mesh = Maillage.au_vent(DOSSIER + fichier)
			if maille == null or not _utilisable(maille, fichier):
				continue
			var poses: Array[Transform3D] = _poses(marais, taille, distances,
				espece, fichier, _facteur(maille), facteur)
			if poses.is_empty():
				continue
			_planter(maille, poses, fichier)

	_franger(marais, lointain, facteur)

## Recopie la force du vent dans toute la végétation.
func souffler(vent: float) -> void:
	for maille: Mesh in _maillages:
		Maillage.souffler(maille, vent)

# ---------------------------------------------------------------------------

## Qui pousse où. Les fourchettes sont en mètres depuis le bord de l'eau.
func _catalogue() -> Array[Espece]:
	return [
		# Les roseaux tiennent la rive, un pied DANS l'eau — et pas un pas plus
		# loin. Une digue fait soixante-quinze centimètres : tolérer un roseau
		# à cinquante centimètres du bord, c'est en planter sur toute la
		# largeur du chemin, et le joueur marche alors dans un champ de tiges
		# qui lui montent aux épaules sans rien voir du marais. C'est ce qui
		# arrivait, et c'est la première chose qu'une capture a montrée.
		Espece.neuve(PackedStringArray(["roseau_touffe.glb", "roseau_grand.glb",
		# La bande est LARGE côté eau et NULLE côté berge : un roseau pousse les
		# pieds dans l'eau, jusqu'à un mètre du bord, et jamais sur le talus.
		# C'est ce qui fait un lit de roseaux au lieu d'une haie sur le chemin.
			"roseau_jeune.glb"]), -1.15, 0.05, 0.13, 0.90, 1.50, 0.085, 0.40),
		Espece.neuve(PackedStringArray(["jonc_haut.glb", "jonc_bas.glb"]),
			-0.85, 0.03, 0.10, 0.40, 0.74, 0.060, 0.45),
		# L'herbe rase tient les talus : c'est le tapis, il en faut partout.
		Espece.neuve(PackedStringArray(["herbe_rase_01.glb", "herbe_rase_02.glb",
			"herbe_rase_03.glb"]), 0.05, 4.0, 0.24, 0.09, 0.20, 0.0),
		Espece.neuve(PackedStringArray(["herbe_touffe_01.glb",
			"herbe_touffe_02.glb", "herbe_touffe_03.glb"]),
			0.10, 3.0, 0.12, 0.16, 0.34, 0.0),
		Espece.neuve(PackedStringArray(["herbe_pousse_01.glb",
			"herbe_pousse_02.glb", "herbe_plate_basse.glb"]),
			0.15, 5.0, 0.05, 0.24, 0.46, 0.0),
		# Buissons et souches : seulement là où l'argile est large, c'est-à-dire
		# sur la ladure et les bords du marais. Un talus de soixante-quinze
		# centimètres n'en porte pas — on y marche.
		Espece.neuve(PackedStringArray(["buisson_bas_01.glb", "buisson_bas_03.glb",
			"buisson_bas_05.glb"]), 1.30, 9.0, 0.055, 0.22, 0.44, 0.0),
		Espece.neuve(PackedStringArray(["souche_ronde.glb", "souche_vieille.glb"]),
			1.60, 9.0, 0.012, 0.20, 0.38, 0.0),
		Espece.neuve(PackedStringArray(["bois_flotte_01.glb", "bois_flotte_03.glb",
			"tronc_mort.glb"]), -0.20, 0.80, 0.010, 0.18, 0.32, 0.06, 0.60),
	]

## Distance de chaque case au bord d'un bassin, en mètres, signée : négative
## dans l'eau, positive sur le talus.
##
## Deux passages de chanfrein plutôt qu'une recherche par case : la grille fait
## quarante-cinq mille cases, et chercher un voisin dans un rayon de six cases
## pour chacune ferait sept millions de tests à chaque démarrage.
func _distances_au_bord(marais: Marais, taille: Vector2i) -> PackedFloat32Array:
	var total: int = taille.x * taille.y
	var dedans: PackedByteArray = PackedByteArray()
	dedans.resize(total)
	for y: int in range(taille.y):
		for x: int in range(taille.x):
			dedans[y * taille.x + x] = 1 if marais.bassin_de_case(x, y) >= 0 else 0

	var vers_eau: PackedFloat32Array = _chanfrein(dedans, taille, 1)
	var vers_terre: PackedFloat32Array = _chanfrein(dedans, taille, 0)
	var signee: PackedFloat32Array = PackedFloat32Array()
	signee.resize(total)
	for i: int in range(total):
		signee[i] = -vers_terre[i] if dedans[i] == 1 else vers_eau[i]
	return signee

## Distance de chaque case à la case marquée la plus proche, en mètres.
func _chanfrein(marques: PackedByteArray, taille: Vector2i,
		cible: int) -> PackedFloat32Array:
	var grand: float = 9999.0
	var d: PackedFloat32Array = PackedFloat32Array()
	d.resize(taille.x * taille.y)
	for i: int in range(d.size()):
		d[i] = 0.0 if int(marques[i]) == cible else grand
	var droit: float = Marais.PAS
	var oblique: float = Marais.PAS * 1.41421356
	for y: int in range(taille.y):
		for x: int in range(taille.x):
			var i: int = y * taille.x + x
			if x > 0:
				d[i] = minf(d[i], d[i - 1] + droit)
			if y > 0:
				d[i] = minf(d[i], d[i - taille.x] + droit)
				if x > 0:
					d[i] = minf(d[i], d[i - taille.x - 1] + oblique)
				if x < taille.x - 1:
					d[i] = minf(d[i], d[i - taille.x + 1] + oblique)
	for y: int in range(taille.y - 1, -1, -1):
		for x: int in range(taille.x - 1, -1, -1):
			var i: int = y * taille.x + x
			if x < taille.x - 1:
				d[i] = minf(d[i], d[i + 1] + droit)
			if y < taille.y - 1:
				d[i] = minf(d[i], d[i + taille.x] + droit)
				if x < taille.x - 1:
					d[i] = minf(d[i], d[i + taille.x + 1] + oblique)
				if x > 0:
					d[i] = minf(d[i], d[i + taille.x - 1] + oblique)
	return d

## Facteur qui ramène un maillage à un mètre de haut. Renvoie zéro si la boîte
## englobante est dégénérée — un maillage plat n'a pas de hauteur à normaliser.
func _facteur(maille: Mesh) -> float:
	var boite: AABB = maille.get_aabb()
	var haut: float = maxf(boite.size.y, 0.0)
	if haut < 0.001:
		# Un décalque posé à plat : on se rabat sur sa plus grande dimension,
		# sinon on le multiplierait par mille.
		haut = maxf(maxf(boite.size.x, boite.size.z), 0.001)
	return 1.0 / haut

## Un modèle est-il utilisable comme plante ?
##
## Normaliser par la hauteur ne suffit pas. `roseau_touffe.glb` mesure
## 25 × 22,86 × 179 mètres : ramené à 1,75 m de haut, il reste long de TREIZE
## MÈTRES et couche des lames pâles en travers de tout le marais. On refuse
## donc ce qui est aberrant plutôt que de le rapetisser — un modèle vingt fois
## plus long que haut n'est pas une plante, c'est un fichier cassé.
const ANISOTROPIE_MAX: float = 7.0

func _utilisable(maille: Mesh, nom: String) -> bool:
	var t: Vector3 = maille.get_aabb().size
	var haut: float = maxf(t.y, 0.001)
	var large: float = maxf(t.x, t.z)
	if large / haut > ANISOTROPIE_MAX:
		push_warning(("%s écarté du semis : %.1f × %.1f × %.1f, soit %.0f fois "
			+ "plus large que haut. Ce n'est pas une plante.")
			% [nom, t.x, t.y, t.z, large / haut])
		return false
	return true

func _poses(marais: Marais, taille: Vector2i, distances: PackedFloat32Array,
		espece: Espece, graine: String, facteur: float,
		densite: float) -> Array[Transform3D]:
	var alea: RandomNumberGenerator = RandomNumberGenerator.new()
	alea.seed = int(hash(graine)) ^ GRAINE
	var poses: Array[Transform3D] = []
	for y: int in range(taille.y):
		for x: int in range(taille.x):
			var i: int = y * taille.x + x
			var d: float = distances[i]
			if d < espece.distance_min or d > espece.distance_max:
				continue
			if alea.randf() > espece.densite * densite:
				continue
			var centre: Vector2 = marais.centre_de_case(x, y)
			# On décale dans la case pour casser la grille : sans ça, la
			# végétation dessine un damier et le procédé se voit.
			var ou: Vector2 = centre + Vector2(
				alea.randf_range(-0.5, 0.5), alea.randf_range(-0.5, 0.5)) * Marais.PAS
			if marais.profondeur_eau(ou) > espece.eau_max:
				continue
			var bassin: int = marais.bassin_sous(ou)
			if bassin >= 0 and marais.bassins[bassin].salinite > espece.salinite_max:
				continue
			var hauteur: float = alea.randf_range(
				espece.hauteur_min, espece.hauteur_max)
			var base: Transform3D = Transform3D.IDENTITY
			base = base.scaled(Vector3.ONE * hauteur * facteur)
			base = base.rotated(Vector3.UP, alea.randf_range(0.0, TAU))
			base.origin = Vector3(ou.x, marais.hauteur_sol(ou) - 0.02, ou.y)
			poses.append(base)
	return poses

func _planter(maille: Mesh, poses: Array[Transform3D], nom: String) -> void:
	var plus_haute: float = 0.0
	var boite: AABB = maille.get_aabb()
	for pose: Transform3D in poses:
		plus_haute = maxf(plus_haute, boite.size.y * pose.basis.get_scale().y)
	hauteurs[nom] = plus_haute
	instances[nom] = poses.size()
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = maille
	multi.instance_count = poses.size()
	for i: int in range(poses.size()):
		multi.set_instance_transform(i, poses[i])

	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = "Semis_%s" % nom.get_basename()
	instance.multimesh = multi
	# Des milliers de brins qui projettent chacun leur ombre coûtent cher et
	# n'apportent rien : à cette échelle, l'ombre du tapis est déjà dans le sol.
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	if not _maillages.has(maille):
		_maillages.append(maille)

## Une frange au-delà du niveau : quelques roseaux et arbres maigres pour que
## l'horizon porte des silhouettes au lieu d'une ligne nue.
func _franger(marais: Marais, rayon: float, densite: float) -> void:
	if rayon <= 0.0:
		return
	var emprise: Rect2 = marais.etendue()
	var alea: RandomNumberGenerator = RandomNumberGenerator.new()
	alea.seed = GRAINE + 7
	var lointains: PackedStringArray = PackedStringArray([
		"roseau_grand.glb", "arbre_tordu_01.glb", "arbre_tordu_02.glb",
		"arbre_maigre.glb", "arbre_mort_moyen.glb", "buisson_bas_02.glb"])
	for fichier: String in lointains:
		var maille: Mesh = Maillage.au_vent(DOSSIER + fichier)
		if maille == null or not _utilisable(maille, fichier):
			continue
		var facteur: float = _facteur(maille)
		var haut: bool = fichier.begins_with("arbre")
		var poses: Array[Transform3D] = []
		for _i: int in range(int(160.0 * densite)):
			var ou: Vector2 = Vector2(
				alea.randf_range(emprise.position.x - rayon, emprise.end.x + rayon),
				alea.randf_range(emprise.position.y - rayon, emprise.end.y + rayon))
			if emprise.grow(3.0).has_point(ou):
				continue
			var hauteur: float = alea.randf_range(2.0, 4.4) if haut \
				else alea.randf_range(0.8, 1.9)
			var base: Transform3D = Transform3D.IDENTITY
			base = base.scaled(Vector3.ONE * hauteur * facteur)
			base = base.rotated(Vector3.UP, alea.randf_range(0.0, TAU))
			# Plantée SUR le plan du lointain : elle poussait deux centimètres
			# SOUS le miroir d'eau qui fait l'horizon.
			base.origin = Vector3(ou.x, _niveau_lointain + 0.01, ou.y)
			poses.append(base)
		if not poses.is_empty():
			_planter(maille, poses, "lointain_" + fichier.get_basename())
